"""
GitLab Client для автоматической настройки и управления проектами CI/CD
"""
import os
import sys
import requests
import time
import base64
from datetime import datetime
from typing import Dict, Any, List, Optional
import json

# Добавление пути к shared модулям
sys.path.append('/app')

from shared.logger import get_logger, log_operation_start, log_operation_success, log_operation_error


class GitLabClient:
    """Клиент для работы с GitLab API"""
    
    def __init__(self, base_url: str = None, token: str = None):
        self.logger = get_logger("gitlab_client")
        
        self.base_url = (base_url or os.getenv('GITLAB_URL', 'http://gitlab')).rstrip('/')
        self.token = token or os.getenv('GITLAB_TOKEN', '')
        
        # Настройка сессии для API запросов
        self.session = requests.Session()
        if self.token:
            self.session.headers.update({
                'Authorization': f'Bearer {self.token}',
                'Content-Type': 'application/json'
            })
        
        self.logger.info("GitLab client initialized", 
                        component="init",
                        details={
                            "base_url": self.base_url,
                            "has_token": bool(self.token)
                        })
    
    def _make_request(self, method: str, endpoint: str, data: Dict = None, 
                     params: Dict = None, timeout: int = 30) -> requests.Response:
        """Выполнение HTTP запроса к GitLab API"""
        url = f"{self.base_url}/api/v4/{endpoint.lstrip('/')}"
        
        try:
            response = self.session.request(
                method=method,
                url=url,
                json=data,
                params=params,
                timeout=timeout
            )
            
            # Логирование запроса
            self.logger.debug("GitLab API request", 
                            component="api_request",
                            details={
                                "method": method,
                                "endpoint": endpoint,
                                "status_code": response.status_code
                            })
            
            return response
            
        except requests.exceptions.RequestException as e:
            self.logger.error("GitLab API request failed", 
                            component="api_request",
                            details={
                                "method": method,
                                "endpoint": endpoint,
                                "error": str(e)
                            })
            raise
    
    def wait_for_gitlab_ready(self, max_attempts: int = 30, delay: int = 10) -> bool:
        """Ожидание готовности GitLab"""
        correlation_id = log_operation_start("gitlab_client", "wait_for_ready")
        
        for attempt in range(max_attempts):
            try:
                # Проверяем API версию вместо health endpoint
                headers = {}
                if self.token:
                    headers['Authorization'] = f'Bearer {self.token}'
                response = requests.get(f"{self.base_url}/api/v4/version", headers=headers, timeout=10)
                if response.status_code == 200:
                    log_operation_success("gitlab_client", "wait_for_ready", correlation_id,
                                        {"attempts": attempt + 1})
                    return True
                    
            except Exception as e:
                self.logger.debug("GitLab not ready yet", 
                                component="readiness_check",
                                details={"attempt": attempt + 1, "error": str(e)})
            
            if attempt < max_attempts - 1:
                time.sleep(delay)
        
        log_operation_error("gitlab_client", "wait_for_ready", correlation_id, 
                          Exception(f"GitLab not ready after {max_attempts} attempts"))
        return False
    
    def create_root_token(self, username: str = "root", password: str = "gitlab_root_password") -> str:
        """Создание root токена при первом запуске GitLab"""
        correlation_id = log_operation_start("gitlab_client", "create_root_token")
        
        try:
            # Сначала нужно получить CSRF токен
            session = requests.Session()
            
            # Получение страницы входа
            login_page = session.get(f"{self.base_url}/users/sign_in", timeout=30)
            login_page.raise_for_status()
            
            # Поиск CSRF токена в HTML (упрощенный вариант)
            csrf_token = None
            for line in login_page.text.split('\n'):
                if 'csrf-token' in line and 'content=' in line:
                    start = line.find('content="') + 9
                    end = line.find('"', start)
                    csrf_token = line[start:end]
                    break
            
            if not csrf_token:
                raise Exception("CSRF token not found")
            
            # Вход в систему
            login_data = {
                'user[login]': username,
                'user[password]': password,
                'authenticity_token': csrf_token
            }
            
            login_response = session.post(
                f"{self.base_url}/users/sign_in",
                data=login_data,
                timeout=30,
                allow_redirects=True
            )
            
            if 'dashboard' not in login_response.url and login_response.status_code != 200:
                raise Exception("Login failed")
            
            # Получение страницы создания токена
            token_page = session.get(f"{self.base_url}/-/profile/personal_access_tokens", timeout=30)
            token_page.raise_for_status()
            
            # Поиск нового CSRF токена
            csrf_token = None
            for line in token_page.text.split('\n'):
                if 'csrf-token' in line and 'content=' in line:
                    start = line.find('content="') + 9
                    end = line.find('"', start)
                    csrf_token = line[start:end]
                    break
            
            # Создание токена
            token_data = {
                'personal_access_token[name]': 'CI/CD Integration Token',
                'personal_access_token[scopes][]': ['api', 'read_user', 'read_repository', 'write_repository'],
                'authenticity_token': csrf_token
            }
            
            token_response = session.post(
                f"{self.base_url}/-/profile/personal_access_tokens",
                data=token_data,
                timeout=30
            )
            
            # Извлечение токена из ответа (упрощенный парсинг)
            if 'personal-access-token' in token_response.text:
                # Поиск токена в HTML
                for line in token_response.text.split('\n'):
                    if 'data-clipboard-text=' in line:
                        start = line.find('data-clipboard-text="') + 21
                        end = line.find('"', start)
                        token = line[start:end]
                        if token and len(token) > 10:  # Проверка что это похоже на токен
                            self.token = token
                            self.session.headers.update({
                                'Authorization': f'Bearer {self.token}',
                                'Content-Type': 'application/json'
                            })
                            
                            log_operation_success("gitlab_client", "create_root_token", correlation_id)
                            return token
            
            raise Exception("Token not found in response")
            
        except Exception as e:
            log_operation_error("gitlab_client", "create_root_token", correlation_id, e)
            raise
    
    def create_project(self, name: str, description: str = "", visibility: str = "internal",
                      initialize_with_readme: bool = True) -> Dict[str, Any]:
        """Создание проекта в GitLab"""
        correlation_id = log_operation_start("gitlab_client", "create_project", {"name": name})
        
        try:
            # Проверка существования проекта
            existing_project = self.get_project_by_name(name)
            if existing_project:
                self.logger.info("Project already exists", 
                               component="project_management",
                               details={"name": name, "id": existing_project['id']})
                return existing_project
            
            project_data = {
                'name': name,
                'description': description,
                'visibility': visibility,
                'initialize_with_readme': initialize_with_readme,
                'issues_enabled': True,
                'merge_requests_enabled': True,
                'wiki_enabled': True,
                'snippets_enabled': True,
                'builds_enabled': True,
                'container_registry_enabled': False
            }
            
            response = self._make_request('POST', '/projects', data=project_data)
            response.raise_for_status()
            
            project = response.json()
            
            log_operation_success("gitlab_client", "create_project", correlation_id,
                                {"project_id": project['id'], "name": name})
            
            return project
            
        except Exception as e:
            log_operation_error("gitlab_client", "create_project", correlation_id, e)
            raise
    
    def get_project_by_name(self, name: str) -> Optional[Dict[str, Any]]:
        """Получение проекта по имени"""
        try:
            response = self._make_request('GET', '/projects', params={'search': name})
            response.raise_for_status()
            
            projects = response.json()
            for project in projects:
                if project['name'] == name:
                    return project
            
            return None
            
        except Exception as e:
            self.logger.error("Failed to get project by name", 
                            component="project_management",
                            details={"name": name, "error": str(e)})
            return None
    
    def create_ci_pipeline_config(self, project_id: int, pipeline_type: str = "main") -> str:
        """Создание конфигурации CI/CD пайплайна"""
        if pipeline_type == "main":
            gitlab_ci_content = """# GitLab CI/CD конфигурация для основного проекта 1С
stages:
  - validate
  - analyze
  - notify

variables:
  SONAR_PROJECT_KEY: "ut103-ci"
  REDMINE_PROJECT_ID: "ut103-ci"
  GIT_DEPTH: 10

# Валидация структуры 1С
validate_1c_structure:
  stage: validate
  image: ubuntu:22.04
  before_script:
    - apt-get update && apt-get install -y curl
  script:
    - echo "Validating 1C structure..."
    - find . -name "*.xml" | head -10
    - echo "Structure validation completed"
  rules:
    - if: $CI_PIPELINE_SOURCE == "push"
    - if: $CI_PIPELINE_SOURCE == "api"

# Анализ качества кода в SonarQube
sonarqube_analysis:
  stage: analyze
  image: sonarsource/sonar-scanner-cli:latest
  variables:
    SONAR_USER_HOME: "${CI_PROJECT_DIR}/.sonar"
    GIT_DEPTH: "0"
  cache:
    key: "${CI_JOB_NAME}"
    paths:
      - .sonar/cache
  script:
    - sonar-scanner
      -Dsonar.projectKey=$SONAR_PROJECT_KEY
      -Dsonar.sources=.
      -Dsonar.host.url=$SONARQUBE_URL
      -Dsonar.login=$SONARQUBE_TOKEN
      -Dsonar.exclusions="**/*.bak,**/*.tmp"
      -Dsonar.sourceEncoding=UTF-8
  dependencies:
    - validate_1c_structure
  rules:
    - if: $CI_PIPELINE_SOURCE == "push"
    - if: $CI_PIPELINE_SOURCE == "api"

# Уведомление в Redmine о результатах
notify_redmine:
  stage: notify
  image: curlimages/curl:latest
  script:
    - |
      curl -X POST "$CICD_SERVICE_URL/api/pipeline-completed" \
        -H "Content-Type: application/json" \
        -d "{
          \"pipeline_id\": \"$CI_PIPELINE_ID\",
          \"project_name\": \"$CI_PROJECT_NAME\",
          \"commit_hash\": \"$CI_COMMIT_SHA\",
          \"status\": \"$CI_JOB_STATUS\",
          \"pipeline_url\": \"$CI_PIPELINE_URL\"
        }"
  dependencies:
    - sonarqube_analysis
  rules:
    - if: $CI_PIPELINE_SOURCE == "push"
    - if: $CI_PIPELINE_SOURCE == "api"
  when: always
"""
        else:  # external files pipeline
            gitlab_ci_content = """# GitLab CI/CD конфигурация для внешних файлов 1С
stages:
  - validate
  - analyze
  - notify

variables:
  SONAR_PROJECT_KEY: "ut103-external-files"
  GIT_DEPTH: 10

# Валидация внешнего файла
validate_external_file:
  stage: validate
  image: ubuntu:22.04
  script:
    - echo "Validating external file structure..."
    - find . -name "*.bsl" -o -name "*.os" | head -10
    - echo "External file validation completed"
  rules:
    - if: $CI_PIPELINE_SOURCE == "push"
    - if: $CI_PIPELINE_SOURCE == "api"

# Анализ внешнего файла в SonarQube
sonarqube_external_analysis:
  stage: analyze
  image: sonarsource/sonar-scanner-cli:latest
  variables:
    SONAR_USER_HOME: "${CI_PROJECT_DIR}/.sonar"
    GIT_DEPTH: "0"
  cache:
    key: "${CI_JOB_NAME}"
    paths:
      - .sonar/cache
  script:
    - sonar-scanner
      -Dsonar.projectKey=$SONAR_PROJECT_KEY
      -Dsonar.sources=.
      -Dsonar.host.url=$SONARQUBE_URL
      -Dsonar.login=$SONARQUBE_TOKEN
      -Dsonar.exclusions="**/*.epf,**/*.erf,**/*.efd"
      -Dsonar.inclusions="**/*.bsl,**/*.os"
      -Dsonar.sourceEncoding=UTF-8
  dependencies:
    - validate_external_file
  rules:
    - if: $CI_PIPELINE_SOURCE == "push"
    - if: $CI_PIPELINE_SOURCE == "api"

# Уведомление в Redmine о результатах анализа внешнего файла
notify_redmine_external:
  stage: notify
  image: curlimages/curl:latest
  script:
    - |
      curl -X POST "$CICD_SERVICE_URL/api/external-file-analyzed" \
        -H "Content-Type: application/json" \
        -d "{
          \"pipeline_id\": \"$CI_PIPELINE_ID\",
          \"project_name\": \"$CI_PROJECT_NAME\",
          \"commit_hash\": \"$CI_COMMIT_SHA\",
          \"branch_name\": \"$CI_COMMIT_REF_NAME\",
          \"status\": \"$CI_JOB_STATUS\",
          \"pipeline_url\": \"$CI_PIPELINE_URL\"
        }"
  dependencies:
    - sonarqube_external_analysis
  rules:
    - if: $CI_PIPELINE_SOURCE == "push"
    - if: $CI_PIPELINE_SOURCE == "api"
  when: always
"""
        
        return gitlab_ci_content
    
    def setup_project_ci_pipeline(self, project_id: int, pipeline_type: str = "main") -> bool:
        """Настройка CI/CD пайплайна для проекта"""
        correlation_id = log_operation_start("gitlab_client", "setup_ci_pipeline", 
                                           {"project_id": project_id, "type": pipeline_type})
        
        try:
            # Создание .gitlab-ci.yml файла
            gitlab_ci_content = self.create_ci_pipeline_config(project_id, pipeline_type)
            
            # Кодирование содержимого в base64
            content_encoded = base64.b64encode(gitlab_ci_content.encode()).decode()
            
            file_data = {
                'branch': 'main',
                'content': gitlab_ci_content,
                'commit_message': f'Add .gitlab-ci.yml for {pipeline_type} pipeline',
                'encoding': 'text'
            }
            
            # Создание файла через API
            response = self._make_request(
                'POST', 
                f'/projects/{project_id}/repository/files/.gitlab-ci.yml',
                data=file_data
            )
            
            if response.status_code in [201, 400]:  # 400 может означать что файл уже существует
                log_operation_success("gitlab_client", "setup_ci_pipeline", correlation_id)
                return True
            else:
                response.raise_for_status()
                
        except Exception as e:
            log_operation_error("gitlab_client", "setup_ci_pipeline", correlation_id, e)
            return False
    
    def create_project_variables(self, project_id: int, variables: Dict[str, str]) -> bool:
        """Создание переменных окружения для проекта"""
        correlation_id = log_operation_start("gitlab_client", "create_project_variables", 
                                           {"project_id": project_id})
        
        try:
            success_count = 0
            
            for key, value in variables.items():
                var_data = {
                    'key': key,
                    'value': value,
                    'protected': False,
                    'masked': key.lower() in ['token', 'password', 'secret']
                }
                
                response = self._make_request(
                    'POST',
                    f'/projects/{project_id}/variables',
                    data=var_data
                )
                
                if response.status_code in [201, 400]:  # 400 - переменная уже существует
                    success_count += 1
                else:
                    self.logger.warning("Failed to create variable", 
                                      component="project_variables",
                                      details={"key": key, "status": response.status_code})
            
            log_operation_success("gitlab_client", "create_project_variables", correlation_id,
                                {"variables_created": success_count})
            
            return success_count == len(variables)
            
        except Exception as e:
            log_operation_error("gitlab_client", "create_project_variables", correlation_id, e)
            return False
    
    def trigger_pipeline(self, project_id: int, ref: str = "main", 
                        variables: Dict[str, str] = None) -> Optional[Dict[str, Any]]:
        """Запуск пайплайна"""
        correlation_id = log_operation_start("gitlab_client", "trigger_pipeline", 
                                           {"project_id": project_id, "ref": ref})
        
        try:
            pipeline_data = {
                'ref': ref
            }
            
            if variables:
                pipeline_data['variables'] = [
                    {'key': k, 'value': v} for k, v in variables.items()
                ]
            
            response = self._make_request(
                'POST',
                f'/projects/{project_id}/pipeline',
                data=pipeline_data
            )
            response.raise_for_status()
            
            pipeline = response.json()
            
            log_operation_success("gitlab_client", "trigger_pipeline", correlation_id,
                                {"pipeline_id": pipeline['id']})
            
            return pipeline
            
        except Exception as e:
            log_operation_error("gitlab_client", "trigger_pipeline", correlation_id, e)
            return None
    
    def get_pipeline_status(self, project_id: int, pipeline_id: int) -> Optional[Dict[str, Any]]:
        """Получение статуса пайплайна"""
        try:
            response = self._make_request('GET', f'/projects/{project_id}/pipelines/{pipeline_id}')
            response.raise_for_status()
            
            return response.json()
            
        except Exception as e:
            self.logger.error("Failed to get pipeline status", 
                            component="pipeline_management",
                            details={"project_id": project_id, "pipeline_id": pipeline_id, "error": str(e)})
            return None
    
    def create_webhook(self, project_id: int, url: str, events: List[str] = None) -> bool:
        """Создание webhook для проекта"""
        correlation_id = log_operation_start("gitlab_client", "create_webhook", 
                                           {"project_id": project_id})
        
        try:
            if events is None:
                events = ['push_events', 'merge_requests_events', 'pipeline_events']
            
            webhook_data = {
                'url': url,
                'push_events': 'push_events' in events,
                'merge_requests_events': 'merge_requests_events' in events,
                'pipeline_events': 'pipeline_events' in events,
                'enable_ssl_verification': False
            }
            
            response = self._make_request(
                'POST',
                f'/projects/{project_id}/hooks',
                data=webhook_data
            )
            
            if response.status_code in [201, 422]:  # 422 - webhook уже существует
                log_operation_success("gitlab_client", "create_webhook", correlation_id)
                return True
            else:
                response.raise_for_status()
                
        except Exception as e:
            log_operation_error("gitlab_client", "create_webhook", correlation_id, e)
            return False
    
    def setup_full_project(self, name: str, description: str, pipeline_type: str = "main") -> Optional[Dict[str, Any]]:
        """Полная настройка проекта с CI/CD"""
        correlation_id = log_operation_start("gitlab_client", "setup_full_project", {"name": name})
        
        try:
            # 1. Создание проекта
            project = self.create_project(name, description)
            project_id = project['id']
            
            # Ожидание готовности проекта
            time.sleep(5)
            
            # 2. Настройка CI/CD пайплайна
            self.setup_project_ci_pipeline(project_id, pipeline_type)
            
            # 3. Создание переменных окружения
            variables = {
                'SONARQUBE_URL': os.getenv('SONARQUBE_URL', 'http://sonarqube:9000'),
                'SONARQUBE_TOKEN': os.getenv('SONARQUBE_TOKEN', ''),
                'CICD_SERVICE_URL': 'http://cicd-service:8080',
                'REDMINE_URL': os.getenv('REDMINE_URL', 'http://redmine:3000')
            }
            
            self.create_project_variables(project_id, variables)
            
            # 4. Создание webhook
            webhook_url = f"http://cicd-service:8080/api/gitlab-webhook"
            self.create_webhook(project_id, webhook_url)
            
            log_operation_success("gitlab_client", "setup_full_project", correlation_id,
                                {"project_id": project_id, "name": name})
            
            return project
            
        except Exception as e:
            log_operation_error("gitlab_client", "setup_full_project", correlation_id, e)
            return None
    
    def get_project_info(self, project_id: int) -> Optional[Dict[str, Any]]:
        """Получение информации о проекте"""
        try:
            response = self._make_request('GET', f'/projects/{project_id}')
            response.raise_for_status()
            
            return response.json()
            
        except Exception as e:
            self.logger.error("Failed to get project info", 
                            component="project_management",
                            details={"project_id": project_id, "error": str(e)})
            return None


# Глобальный экземпляр клиента
_gitlab_client = None


def get_gitlab_client() -> GitLabClient:
    """Получение глобального экземпляра GitLab клиента"""
    global _gitlab_client
    if _gitlab_client is None:
        _gitlab_client = GitLabClient()
    return _gitlab_client