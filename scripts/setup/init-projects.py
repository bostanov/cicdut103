#!/usr/bin/env python3
"""
Скрипт первоначального заполнения систем CI/CD
Создает проекты в GitLab, Redmine, SonarQube и настраивает интеграции

Автор: Бостанов Ф.А.
Версия: 1.0
"""

import os
import sys
import time
import logging
import requests
from typing import Dict, Optional
from urllib.parse import urljoin

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/init-projects.log', encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


class RetrySession:
    """HTTP сессия с повторными попытками"""
    
    def __init__(self, retries=3, backoff_factor=2):
        self.retries = retries
        self.backoff_factor = backoff_factor
        self.session = requests.Session()
    
    def request(self, method, url, **kwargs):
        """Выполнить запрос с повторными попытками"""
        for attempt in range(self.retries):
            try:
                response = self.session.request(method, url, **kwargs)
                response.raise_for_status()
                return response
            except requests.exceptions.RequestException as e:
                if attempt == self.retries - 1:
                    logger.error(f"Ошибка после {self.retries} попыток: {e}")
                    raise
                wait_time = self.backoff_factor ** attempt
                logger.warning(f"Попытка {attempt + 1} не удалась, ждем {wait_time}с...")
                time.sleep(wait_time)


class GitLabInitializer:
    """Инициализация проектов в GitLab"""
    
    def __init__(self, url: str, token: str):
        self.url = url.rstrip('/')
        self.token = token
        self.session = RetrySession()
        self.headers = {'PRIVATE-TOKEN': token}
    
    def create_project(self, name: str, description: str) -> Optional[Dict]:
        """Создать проект в GitLab"""
        logger.info(f"Создание проекта '{name}' в GitLab...")
        
        # Проверка существования
        try:
            response = self.session.request(
                'GET',
                f"{self.url}/api/v4/projects",
                headers=self.headers,
                params={'search': name}
            )
            
            projects = response.json()
            for project in projects:
                if project['name'] == name:
                    logger.info(f"Проект '{name}' уже существует (ID: {project['id']})")
                    return project
        except Exception as e:
            logger.warning(f"Ошибка проверки существования проекта: {e}")
        
        # Создание нового проекта
        try:
            response = self.session.request(
                'POST',
                f"{self.url}/api/v4/projects",
                headers=self.headers,
                json={
                    'name': name,
                    'description': description,
                    'visibility': 'private',
                    'initialize_with_readme': True,
                    'builds_enabled': True,
                    'wiki_enabled': True,
                    'issues_enabled': True
                }
            )
            
            project = response.json()
            logger.info(f"✅ Проект '{name}' создан (ID: {project['id']})")
            return project
            
        except Exception as e:
            logger.error(f"❌ Ошибка создания проекта '{name}': {e}")
            return None
    
    def create_webhook(self, project_id: int, url: str, token: str) -> bool:
        """Создать webhook для проекта"""
        logger.info(f"Создание webhook для проекта {project_id}...")
        
        try:
            response = self.session.request(
                'POST',
                f"{self.url}/api/v4/projects/{project_id}/hooks",
                headers=self.headers,
                json={
                    'url': url,
                    'token': token,
                    'push_events': True,
                    'merge_requests_events': True,
                    'tag_push_events': True,
                    'issues_events': True,
                    'enable_ssl_verification': False
                }
            )
            
            webhook = response.json()
            logger.info(f"✅ Webhook создан (ID: {webhook['id']})")
            return True
            
        except Exception as e:
            logger.error(f"❌ Ошибка создания webhook: {e}")
            return False
    
    def create_runner_token(self, project_id: int) -> Optional[str]:
        """Создать токен для GitLab Runner"""
        logger.info(f"Создание runner token для проекта {project_id}...")
        
        try:
            # Получение существующих runners
            response = self.session.request(
                'GET',
                f"{self.url}/api/v4/projects/{project_id}/runners",
                headers=self.headers
            )
            
            runners = response.json()
            if runners:
                logger.info(f"Runner уже зарегистрирован (ID: {runners[0]['id']})")
                return None
            
            # В GitLab 16+ используется новый подход с токенами
            logger.info("Используйте GitLab UI для создания Project Access Token")
            logger.info(f"Settings -> CI/CD -> Runners -> New project runner")
            return None
            
        except Exception as e:
            logger.error(f"❌ Ошибка работы с runner: {e}")
            return None


class RedmineInitializer:
    """Инициализация проектов в Redmine"""
    
    def __init__(self, url: str, api_key: str):
        self.url = url.rstrip('/')
        self.api_key = api_key
        self.session = RetrySession()
        self.headers = {'X-Redmine-API-Key': api_key, 'Content-Type': 'application/json'}
    
    def create_project(self, identifier: str, name: str, description: str) -> Optional[Dict]:
        """Создать проект в Redmine"""
        logger.info(f"Создание проекта '{name}' в Redmine...")
        
        # Проверка существования
        try:
            response = self.session.request(
                'GET',
                f"{self.url}/projects/{identifier}.json",
                headers=self.headers
            )
            
            project = response.json()['project']
            logger.info(f"Проект '{name}' уже существует (ID: {project['id']})")
            return project
            
        except requests.exceptions.HTTPError as e:
            if e.response.status_code != 404:
                logger.error(f"Ошибка проверки проекта: {e}")
                return None
        
        # Создание нового проекта
        try:
            response = self.session.request(
                'POST',
                f"{self.url}/projects.json",
                headers=self.headers,
                json={
                    'project': {
                        'name': name,
                        'identifier': identifier,
                        'description': description,
                        'is_public': False,
                        'enabled_module_names': [
                            'issue_tracking',
                            'time_tracking',
                            'wiki',
                            'files',
                            'repository'
                        ]
                    }
                }
            )
            
            project = response.json()['project']
            logger.info(f"✅ Проект '{name}' создан (ID: {project['id']})")
            return project
            
        except Exception as e:
            logger.error(f"❌ Ошибка создания проекта '{name}': {e}")
            return None
    
    def create_webhook(self, project_id: int, url: str) -> bool:
        """Создать webhook для проекта (требует плагина)"""
        logger.info(f"Webhook для Redmine требует плагин 'redmine_webhook'")
        logger.info("Настройте через UI: Администрирование -> Плагины -> Webhooks")
        return True
    
    def create_issue_tracker_link(self, project_id: int, gitlab_url: str) -> bool:
        """Создать связь с GitLab issue tracker"""
        logger.info(f"Создание связи с GitLab для проекта {project_id}...")
        
        try:
            response = self.session.request(
                'PUT',
                f"{self.url}/projects/{project_id}.json",
                headers=self.headers,
                json={
                    'project': {
                        'custom_fields': [
                            {
                                'id': 1,
                                'name': 'GitLab Project URL',
                                'value': gitlab_url
                            }
                        ]
                    }
                }
            )
            
            logger.info(f"✅ Связь с GitLab создана")
            return True
            
        except Exception as e:
            logger.warning(f"Ошибка создания связи: {e}")
            return False


class SonarQubeInitializer:
    """Инициализация проектов в SonarQube"""
    
    def __init__(self, url: str, token: Optional[str] = None):
        self.url = url.rstrip('/')
        self.token = token or 'admin'
        self.session = RetrySession()
        self.auth = ('admin', self.token)
    
    def create_project(self, key: str, name: str) -> Optional[Dict]:
        """Создать проект в SonarQube"""
        logger.info(f"Создание проекта '{name}' в SonarQube...")
        
        # Проверка существования
        try:
            response = self.session.request(
                'GET',
                f"{self.url}/api/projects/search",
                auth=self.auth,
                params={'projects': key}
            )
            
            projects = response.json()
            if projects['components']:
                project = projects['components'][0]
                logger.info(f"Проект '{name}' уже существует (Key: {project['key']})")
                return project
                
        except Exception as e:
            logger.warning(f"Ошибка проверки проекта: {e}")
        
        # Создание нового проекта
        try:
            response = self.session.request(
                'POST',
                f"{self.url}/api/projects/create",
                auth=self.auth,
                params={
                    'project': key,
                    'name': name,
                    'visibility': 'private'
                }
            )
            
            project = response.json()['project']
            logger.info(f"✅ Проект '{name}' создан (Key: {project['key']})")
            return project
            
        except Exception as e:
            logger.error(f"❌ Ошибка создания проекта '{name}': {e}")
            return None
    
    def create_token(self, name: str) -> Optional[str]:
        """Создать токен для анализа"""
        logger.info(f"Создание токена '{name}' в SonarQube...")
        
        try:
            response = self.session.request(
                'POST',
                f"{self.url}/api/user_tokens/generate",
                auth=self.auth,
                params={'name': name}
            )
            
            token_data = response.json()
            token = token_data['token']
            logger.info(f"✅ Токен создан")
            logger.info(f"⚠️  Сохраните токен: {token}")
            return token
            
        except Exception as e:
            logger.error(f"❌ Ошибка создания токена: {e}")
            return None
    
    def create_webhook(self, name: str, url: str) -> bool:
        """Создать webhook для проекта"""
        logger.info(f"Создание webhook '{name}' в SonarQube...")
        
        try:
            response = self.session.request(
                'POST',
                f"{self.url}/api/webhooks/create",
                auth=self.auth,
                params={
                    'name': name,
                    'url': url
                }
            )
            
            webhook = response.json()['webhook']
            logger.info(f"✅ Webhook создан (Key: {webhook['key']})")
            return True
            
        except Exception as e:
            logger.error(f"❌ Ошибка создания webhook: {e}")
            return False


def load_config() -> Dict:
    """Загрузить конфигурацию из переменных окружения"""
    config = {
        'gitlab': {
            'url': os.getenv('GITLAB_URL', 'http://localhost:8929'),
            'token': os.getenv('GITLAB_TOKEN', ''),
        },
        'redmine': {
            'url': os.getenv('REDMINE_URL', 'http://localhost:3000'),
            'api_key': os.getenv('REDMINE_API_KEY', ''),
        },
        'sonarqube': {
            'url': os.getenv('SONARQUBE_URL', 'http://localhost:9000'),
            'token': os.getenv('SONARQUBE_TOKEN', 'admin'),
        },
        'project': {
            'name': os.getenv('PROJECT_NAME', 'UT-103 CI/CD'),
            'identifier': os.getenv('PROJECT_IDENTIFIER', 'ut103-ci'),
            'description': os.getenv('PROJECT_DESCRIPTION', 
                'Проект автоматизации CI/CD для 1С:Предприятие 8.3.12')
        }
    }
    
    return config


def main():
    """Основная функция инициализации"""
    logger.info("=" * 80)
    logger.info("Начало первоначального заполнения систем CI/CD")
    logger.info("=" * 80)
    
    # Загрузка конфигурации
    config = load_config()
    project_name = config['project']['name']
    project_id = config['project']['identifier']
    project_desc = config['project']['description']
    
    # Проверка необходимых параметров
    if not config['gitlab']['token']:
        logger.warning("⚠️  GITLAB_TOKEN не задан. Используйте токен из GitLab UI:")
        logger.warning("   User Settings -> Access Tokens -> Create personal access token")
        logger.warning("   Scope: api, read_repository, write_repository")
    
    if not config['redmine']['api_key']:
        logger.warning("⚠️  REDMINE_API_KEY не задан. Получите ключ из Redmine UI:")
        logger.warning("   My account -> API access key -> Show")
    
    results = {
        'gitlab': None,
        'redmine': None,
        'sonarqube': None
    }
    
    # Инициализация GitLab
    if config['gitlab']['token']:
        try:
            gitlab = GitLabInitializer(
                config['gitlab']['url'],
                config['gitlab']['token']
            )
            
            project = gitlab.create_project(project_name, project_desc)
            if project:
                results['gitlab'] = project
                
                # Создание webhook для Redmine
                if config['redmine']['url']:
                    webhook_url = f"{config['redmine']['url']}/gitlab_webhook"
                    gitlab.create_webhook(project['id'], webhook_url, 'webhook_token_123')
                
                # Информация о runner
                gitlab.create_runner_token(project['id'])
        
        except Exception as e:
            logger.error(f"Ошибка инициализации GitLab: {e}")
    
    # Инициализация Redmine
    if config['redmine']['api_key']:
        try:
            redmine = RedmineInitializer(
                config['redmine']['url'],
                config['redmine']['api_key']
            )
            
            project = redmine.create_project(project_id, project_name, project_desc)
            if project:
                results['redmine'] = project
                
                # Создание связи с GitLab
                if results['gitlab']:
                    gitlab_url = results['gitlab']['web_url']
                    redmine.create_issue_tracker_link(project['id'], gitlab_url)
        
        except Exception as e:
            logger.error(f"Ошибка инициализации Redmine: {e}")
    
    # Инициализация SonarQube
    try:
        sonar = SonarQubeInitializer(
            config['sonarqube']['url'],
            config['sonarqube']['token']
        )
        
        project = sonar.create_project(project_id, project_name)
        if project:
            results['sonarqube'] = project
            
            # Создание токена для анализа
            token = sonar.create_token(f'{project_id}-token')
            if token:
                logger.info(f"⚠️  Добавьте токен в CI/CD переменные:")
                logger.info(f"   SONARQUBE_TOKEN={token}")
            
            # Создание webhook для GitLab
            if results['gitlab'] and config['gitlab']['url']:
                webhook_url = f"{config['gitlab']['url']}/api/v4/projects/{results['gitlab']['id']}/statuses/{{SHA}}"
                sonar.create_webhook('GitLab Integration', webhook_url)
    
    except Exception as e:
        logger.error(f"Ошибка инициализации SonarQube: {e}")
    
    # Итоговый отчет
    logger.info("=" * 80)
    logger.info("Результаты инициализации:")
    logger.info("=" * 80)
    
    if results['gitlab']:
        logger.info(f"✅ GitLab: Проект создан (ID: {results['gitlab']['id']})")
        logger.info(f"   URL: {results['gitlab']['web_url']}")
    else:
        logger.warning("⚠️  GitLab: Проект не создан")
    
    if results['redmine']:
        logger.info(f"✅ Redmine: Проект создан (ID: {results['redmine']['id']})")
        logger.info(f"   URL: {config['redmine']['url']}/projects/{project_id}")
    else:
        logger.warning("⚠️  Redmine: Проект не создан")
    
    if results['sonarqube']:
        logger.info(f"✅ SonarQube: Проект создан (Key: {results['sonarqube']['key']})")
        logger.info(f"   URL: {config['sonarqube']['url']}/dashboard?id={project_id}")
    else:
        logger.warning("⚠️  SonarQube: Проект не создан")
    
    logger.info("=" * 80)
    logger.info("Первоначальное заполнение завершено")
    logger.info("=" * 80)
    
    return 0 if all(results.values()) else 1


if __name__ == '__main__':
    sys.exit(main())

