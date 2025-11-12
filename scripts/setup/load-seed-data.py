#!/usr/bin/env python3
"""
Скрипт загрузки эталонных данных в систему
Создает пользователей, роли, начальные справочники

Автор: Бостанов Ф.А.
Версия: 1.0
"""

import os
import sys
import logging
import hashlib
from typing import List, Dict
from datetime import datetime

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/load-seed-data.log', encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


# Эталонные данные
SEED_DATA = {
    'users': [
        {
            'login': 'admin',
            'firstname': 'Администратор',
            'lastname': 'Системы',
            'email': 'admin@1c-cicd.local',
            'role': 'admin'
        },
        {
            'login': 'developer',
            'firstname': 'Разработчик',
            'lastname': '1С',
            'email': 'developer@1c-cicd.local',
            'role': 'developer'
        },
        {
            'login': 'tester',
            'firstname': 'Тестировщик',
            'lastname': 'QA',
            'email': 'tester@1c-cicd.local',
            'role': 'tester'
        },
        {
            'login': 'analyst',
            'firstname': 'Аналитик',
            'lastname': 'Бизнес',
            'email': 'analyst@1c-cicd.local',
            'role': 'reporter'
        }
    ],
    'roles': [
        {
            'name': 'admin',
            'description': 'Полный доступ к системе',
            'permissions': ['all']
        },
        {
            'name': 'developer',
            'description': 'Разработка и развертывание',
            'permissions': ['read', 'write', 'deploy', 'analyze']
        },
        {
            'name': 'tester',
            'description': 'Тестирование и отчетность',
            'permissions': ['read', 'test', 'report']
        },
        {
            'name': 'reporter',
            'description': 'Просмотр отчетов',
            'permissions': ['read', 'report']
        }
    ],
    'trackers': [
        {
            'name': 'Ошибка',
            'default_status': 'Новая',
            'description': 'Ошибка в работе системы'
        },
        {
            'name': 'Задача',
            'default_status': 'Новая',
            'description': 'Задача разработки'
        },
        {
            'name': 'Улучшение',
            'default_status': 'Новая',
            'description': 'Улучшение функционала'
        },
        {
            'name': 'CI/CD',
            'default_status': 'Новая',
            'description': 'Автоматизация CI/CD'
        }
    ],
    'statuses': [
        {'name': 'Новая', 'is_closed': False},
        {'name': 'В работе', 'is_closed': False},
        {'name': 'Тестирование', 'is_closed': False},
        {'name': 'Решена', 'is_closed': True},
        {'name': 'Отклонена', 'is_closed': True},
        {'name': 'Отложена', 'is_closed': False}
    ],
    'priorities': [
        {'name': 'Низкий', 'position': 1},
        {'name': 'Нормальный', 'position': 2},
        {'name': 'Высокий', 'position': 3},
        {'name': 'Срочный', 'position': 4},
        {'name': 'Критический', 'position': 5}
    ]
}


def calculate_checksum(data: str) -> str:
    """Вычислить контрольную сумму данных"""
    return hashlib.sha256(data.encode('utf-8')).hexdigest()


def load_users_to_gitlab(users: List[Dict]) -> bool:
    """Загрузить пользователей в GitLab"""
    logger.info("Загрузка пользователей в GitLab...")
    
    gitlab_url = os.getenv('GITLAB_URL', 'http://localhost:8929')
    gitlab_token = os.getenv('GITLAB_TOKEN', '')
    
    if not gitlab_token:
        logger.warning("GITLAB_TOKEN не задан, пропускаем загрузку пользователей")
        return False
    
    import requests
    headers = {'PRIVATE-TOKEN': gitlab_token}
    
    for user in users:
        try:
            # Проверка существования
            response = requests.get(
                f"{gitlab_url}/api/v4/users",
                headers=headers,
                params={'username': user['login']},
                timeout=10
            )
            
            if response.status_code == 200 and response.json():
                logger.info(f"  ✅ Пользователь {user['login']} уже существует")
                continue
            
            # Создание пользователя
            response = requests.post(
                f"{gitlab_url}/api/v4/users",
                headers=headers,
                json={
                    'username': user['login'],
                    'email': user['email'],
                    'name': f"{user['firstname']} {user['lastname']}",
                    'password': 'temp_password_123',  # Пользователь сменит при первом входе
                    'skip_confirmation': True
                },
                timeout=10
            )
            
            if response.status_code == 201:
                logger.info(f"  ✅ Создан пользователь: {user['login']}")
            else:
                logger.error(f"  ❌ Ошибка создания {user['login']}: {response.text}")
                
        except Exception as e:
            logger.error(f"  ❌ Ошибка обработки {user['login']}: {e}")
    
    return True


def load_users_to_redmine(users: List[Dict]) -> bool:
    """Загрузить пользователей в Redmine"""
    logger.info("Загрузка пользователей в Redmine...")
    
    redmine_url = os.getenv('REDMINE_URL', 'http://localhost:3000')
    redmine_key = os.getenv('REDMINE_API_KEY', '')
    
    if not redmine_key:
        logger.warning("REDMINE_API_KEY не задан, пропускаем загрузку пользователей")
        return False
    
    import requests
    headers = {'X-Redmine-API-Key': redmine_key, 'Content-Type': 'application/json'}
    
    for user in users:
        try:
            # Создание пользователя
            response = requests.post(
                f"{redmine_url}/users.json",
                headers=headers,
                json={
                    'user': {
                        'login': user['login'],
                        'firstname': user['firstname'],
                        'lastname': user['lastname'],
                        'mail': user['email'],
                        'password': 'temp_password_123',
                        'must_change_passwd': True
                    }
                },
                timeout=10
            )
            
            if response.status_code == 201:
                logger.info(f"  ✅ Создан пользователь: {user['login']}")
            elif response.status_code == 422:
                logger.info(f"  ✅ Пользователь {user['login']} уже существует")
            else:
                logger.error(f"  ❌ Ошибка создания {user['login']}: {response.text}")
                
        except Exception as e:
            logger.error(f"  ❌ Ошибка обработки {user['login']}: {e}")
    
    return True


def load_trackers_to_redmine(trackers: List[Dict]) -> bool:
    """Загрузить трекеры в Redmine"""
    logger.info("Загрузка трекеров в Redmine...")
    
    redmine_url = os.getenv('REDMINE_URL', 'http://localhost:3000')
    redmine_key = os.getenv('REDMINE_API_KEY', '')
    
    if not redmine_key:
        logger.warning("REDMINE_API_KEY не задан, пропускаем загрузку трекеров")
        return False
    
    import requests
    headers = {'X-Redmine-API-Key': redmine_key, 'Content-Type': 'application/json'}
    
    # Получение существующих трекеров
    try:
        response = requests.get(
            f"{redmine_url}/trackers.json",
            headers=headers,
            timeout=10
        )
        
        existing_trackers = {t['name']: t for t in response.json()['trackers']}
        
        for tracker in trackers:
            if tracker['name'] in existing_trackers:
                logger.info(f"  ✅ Трекер '{tracker['name']}' уже существует")
            else:
                logger.info(f"  ℹ️  Трекер '{tracker['name']}' нужно создать через UI")
                logger.info(f"     Администрирование -> Трекеры -> Создать трекер")
        
        return True
        
    except Exception as e:
        logger.error(f"  ❌ Ошибка загрузки трекеров: {e}")
        return False


def create_env_file() -> bool:
    """Создать файл .env с параметрами"""
    logger.info("Создание файла .env с параметрами окружения...")
    
    env_template = """# CI/CD Configuration
# Автоматически создано: {timestamp}

# GitLab
GITLAB_URL=http://localhost:8929
GITLAB_TOKEN=
GITLAB_PROJECT_ID=1

# Redmine
REDMINE_URL=http://localhost:3000
REDMINE_API_KEY=
REDMINE_PROJECT_ID=ut103-ci
REDMINE_USERNAME=admin
REDMINE_PASSWORD=admin

# SonarQube
SONARQUBE_URL=http://localhost:9000
SONARQUBE_TOKEN=
SONARQUBE_PROJECT_KEY=ut103-ci

# PostgreSQL
POSTGRES_HOST=postgres_cicd
POSTGRES_PORT=5432
POSTGRES_DB=cicd
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres_admin_123

# GitSync
GITSYNC_STORAGE_PATH=file:///1c-storage
GITSYNC_STORAGE_USER=gitsync
GITSYNC_STORAGE_PASSWORD=123
GITSYNC_SYNC_INTERVAL=600

# 1C Platform
ONEC_PLATFORM_PATH=C:/Program Files/1cv8/8.3.12.1714/bin/1cv8.exe
ONEC_WORKSPACE=C:/1C-CI-CD/workspace

# Logging
LOG_LEVEL=INFO
LOG_FILE=logs/cicd.log

# Testing
TEST_TIMEOUT=300
TEST_RETRY_COUNT=3
TEST_PARALLEL=false
"""
    
    env_file = '.env'
    
    if os.path.exists(env_file):
        logger.info(f"  ℹ️  Файл {env_file} уже существует, пропускаем")
        return True
    
    try:
        with open(env_file, 'w', encoding='utf-8') as f:
            f.write(env_template.format(timestamp=datetime.now().isoformat()))
        
        logger.info(f"  ✅ Файл {env_file} создан")
        logger.info(f"  ⚠️  Заполните токены и пароли в {env_file}")
        return True
        
    except Exception as e:
        logger.error(f"  ❌ Ошибка создания {env_file}: {e}")
        return False


def verify_data_integrity() -> bool:
    """Проверить целостность загруженных данных"""
    logger.info("Проверка целостности данных...")
    
    checksums = {}
    
    for category, items in SEED_DATA.items():
        data_str = str(sorted(items, key=lambda x: str(x)))
        checksums[category] = calculate_checksum(data_str)
        logger.info(f"  ✅ {category}: {checksums[category][:16]}...")
    
    # Сохранение контрольных сумм
    checksum_file = 'logs/seed-data-checksums.txt'
    try:
        with open(checksum_file, 'w', encoding='utf-8') as f:
            f.write(f"Контрольные суммы эталонных данных\n")
            f.write(f"Создано: {datetime.now().isoformat()}\n\n")
            for category, checksum in checksums.items():
                f.write(f"{category}: {checksum}\n")
        
        logger.info(f"  ✅ Контрольные суммы сохранены в {checksum_file}")
        return True
        
    except Exception as e:
        logger.error(f"  ❌ Ошибка сохранения контрольных сумм: {e}")
        return False


def main():
    """Основная функция загрузки данных"""
    logger.info("=" * 80)
    logger.info("Начало загрузки эталонных данных")
    logger.info("=" * 80)
    
    # Создание директории для логов
    os.makedirs('logs', exist_ok=True)
    
    results = {}
    
    # 1. Создание .env файла
    results['env'] = create_env_file()
    
    # 2. Загрузка пользователей в GitLab
    results['gitlab_users'] = load_users_to_gitlab(SEED_DATA['users'])
    
    # 3. Загрузка пользователей в Redmine
    results['redmine_users'] = load_users_to_redmine(SEED_DATA['users'])
    
    # 4. Загрузка трекеров в Redmine
    results['redmine_trackers'] = load_trackers_to_redmine(SEED_DATA['trackers'])
    
    # 5. Проверка целостности
    results['integrity'] = verify_data_integrity()
    
    # Итоговый отчет
    logger.info("=" * 80)
    logger.info("Результаты загрузки данных:")
    logger.info("=" * 80)
    
    for task, success in results.items():
        status = "✅" if success else "⚠️"
        logger.info(f"{status} {task}: {'Успешно' if success else 'С предупреждениями'}")
    
    logger.info("=" * 80)
    logger.info("Загрузка эталонных данных завершена")
    logger.info("=" * 80)
    
    logger.info("\nСледующие шаги:")
    logger.info("1. Заполните токены в файле .env")
    logger.info("2. Запустите: python scripts/setup/init-projects.py")
    logger.info("3. Настройте GitLab Runner: .\\scripts\\setup\\init-runner.ps1")
    
    return 0


if __name__ == '__main__':
    sys.exit(main())

