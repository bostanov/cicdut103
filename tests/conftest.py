#!/usr/bin/env python3
"""
Конфигурация pytest для тестов CI/CD системы
Определение фикстур, маркеров, хуков

Автор: Бостанов Ф.А.
Версия: 1.0
"""

import os
import sys
import pytest
import logging


# Добавление путей для импорта модулей проекта
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(project_root, 'scripts', 'setup'))
sys.path.insert(0, os.path.join(project_root, 'docker', 'ci-cd'))


# Настройка логирования для тестов
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/pytest.log', encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)


def pytest_configure(config):
    """Конфигурация pytest"""
    
    # Регистрация пользовательских маркеров
    config.addinivalue_line(
        "markers", "integration: тесты интеграции (требуют запущенные сервисы)"
    )
    config.addinivalue_line(
        "markers", "slow: медленные тесты"
    )
    config.addinivalue_line(
        "markers", "unit: быстрые unit тесты"
    )
    config.addinivalue_line(
        "markers", "requires_gitlab: требует GitLab token"
    )
    config.addinivalue_line(
        "markers", "requires_redmine: требует Redmine API key"
    )
    config.addinivalue_line(
        "markers", "requires_sonar: требует SonarQube"
    )


def pytest_collection_modifyitems(config, items):
    """Модификация собранных тестов"""
    
    # Автоматическое добавление маркера unit для не помеченных тестов
    for item in items:
        if not any(mark.name in ['integration', 'slow'] for mark in item.iter_markers()):
            item.add_marker(pytest.mark.unit)


# Фикстуры для переменных окружения
@pytest.fixture(scope='session')
def gitlab_url():
    """URL GitLab сервиса"""
    return os.getenv('GITLAB_URL', 'http://localhost:8929')


@pytest.fixture(scope='session')
def gitlab_token():
    """GitLab API token"""
    token = os.getenv('GITLAB_TOKEN', '')
    if not token:
        pytest.skip("GITLAB_TOKEN не задан")
    return token


@pytest.fixture(scope='session')
def redmine_url():
    """URL Redmine сервиса"""
    return os.getenv('REDMINE_URL', 'http://localhost:3000')


@pytest.fixture(scope='session')
def redmine_api_key():
    """Redmine API key"""
    key = os.getenv('REDMINE_API_KEY', '')
    if not key:
        pytest.skip("REDMINE_API_KEY не задан")
    return key


@pytest.fixture(scope='session')
def sonarqube_url():
    """URL SonarQube сервиса"""
    return os.getenv('SONARQUBE_URL', 'http://localhost:9000')


@pytest.fixture(scope='session')
def sonarqube_token():
    """SonarQube token"""
    return os.getenv('SONARQUBE_TOKEN', 'admin')


@pytest.fixture(scope='session')
def project_config():
    """Конфигурация тестового проекта"""
    return {
        'name': os.getenv('PROJECT_NAME', 'UT-103 CI/CD'),
        'identifier': os.getenv('PROJECT_IDENTIFIER', 'ut103-ci'),
        'description': 'Проект автоматизации CI/CD для 1С:Предприятие 8.3.12'
    }


@pytest.fixture
def temp_workspace(tmp_path):
    """Временная рабочая директория для тестов"""
    workspace = tmp_path / "workspace"
    workspace.mkdir()
    return workspace


@pytest.fixture
def mock_gitlab_response():
    """Mock ответа GitLab API"""
    return {
        'id': 1,
        'name': 'Test Project',
        'path': 'test-project',
        'web_url': 'http://localhost:8929/root/test-project',
        'description': 'Test project description',
        'visibility': 'private'
    }


@pytest.fixture
def mock_redmine_response():
    """Mock ответа Redmine API"""
    return {
        'project': {
            'id': 1,
            'name': 'Test Project',
            'identifier': 'test-project',
            'description': 'Test project description',
            'status': 1,
            'is_public': False
        }
    }


@pytest.fixture
def mock_sonarqube_response():
    """Mock ответа SonarQube API"""
    return {
        'project': {
            'key': 'test-project',
            'name': 'Test Project',
            'qualifier': 'TRK',
            'visibility': 'private'
        }
    }


# Хуки для отчетности
def pytest_report_header(config):
    """Добавление информации в заголовок отчета"""
    return [
        f"GitLab URL: {os.getenv('GITLAB_URL', 'http://localhost:8929')}",
        f"Redmine URL: {os.getenv('REDMINE_URL', 'http://localhost:3000')}",
        f"SonarQube URL: {os.getenv('SONARQUBE_URL', 'http://localhost:9000')}",
        f"Project: {os.getenv('PROJECT_IDENTIFIER', 'ut103-ci')}"
    ]


def pytest_runtest_makereport(item, call):
    """Кастомизация отчета о тестах"""
    if call.when == 'call':
        if call.excinfo is not None:
            # Логирование информации об упавших тестах
            logger = logging.getLogger(__name__)
            logger.error(f"Test failed: {item.nodeid}")
            logger.error(f"Error: {call.excinfo.value}")


# Пропуск тестов при отсутствии сервисов
def pytest_runtest_setup(item):
    """Проверка доступности сервисов перед тестами"""
    import requests
    
    # Проверка для integration тестов
    if 'integration' in [mark.name for mark in item.iter_markers()]:
        services_ok = True
        
        # Проверка GitLab
        if os.getenv('GITLAB_TOKEN'):
            try:
                response = requests.get(
                    f"{os.getenv('GITLAB_URL', 'http://localhost:8929')}/-/health",
                    timeout=5
                )
                if response.status_code != 200:
                    services_ok = False
            except:
                services_ok = False
        
        # Проверка Redmine
        if os.getenv('REDMINE_API_KEY'):
            try:
                response = requests.get(
                    os.getenv('REDMINE_URL', 'http://localhost:3000'),
                    timeout=5
                )
                if response.status_code != 200:
                    services_ok = False
            except:
                services_ok = False
        
        if not services_ok:
            pytest.skip("Один или несколько сервисов недоступны")


# Автоматическая очистка после тестов
@pytest.fixture(scope='session', autouse=True)
def cleanup(request):
    """Очистка после всех тестов"""
    def finalizer():
        logger = logging.getLogger(__name__)
        logger.info("Завершение тестов, очистка...")
        # Здесь можно добавить логику очистки
    
    request.addfinalizer(finalizer)

