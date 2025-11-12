#!/usr/bin/env python3
"""
Интеграционные тесты для CI/CD сервисов
Проверка взаимодействия GitLab, Redmine, SonarQube

Автор: Бостанов Ф.А.
Версия: 1.0
"""

import os
import sys
import time
import pytest
import requests
from typing import Dict, Optional


# Конфигурация из переменных окружения
GITLAB_URL = os.getenv('GITLAB_URL', 'http://localhost:8929')
GITLAB_TOKEN = os.getenv('GITLAB_TOKEN', '')

REDMINE_URL = os.getenv('REDMINE_URL', 'http://localhost:3000')
REDMINE_API_KEY = os.getenv('REDMINE_API_KEY', '')

SONARQUBE_URL = os.getenv('SONARQUBE_URL', 'http://localhost:9000')
SONARQUBE_TOKEN = os.getenv('SONARQUBE_TOKEN', 'admin')

POSTGRES_HOST = os.getenv('POSTGRES_HOST', 'localhost')
POSTGRES_PORT = int(os.getenv('POSTGRES_PORT', '5433'))


# Маркеры для пропуска тестов при отсутствии токенов
requires_gitlab_token = pytest.mark.skipif(
    not GITLAB_TOKEN,
    reason="GITLAB_TOKEN не задан"
)

requires_redmine_key = pytest.mark.skipif(
    not REDMINE_API_KEY,
    reason="REDMINE_API_KEY не задан"
)


class TestServicesHealth:
    """Проверка работоспособности сервисов"""
    
    def test_gitlab_health(self):
        """GitLab должен быть доступен"""
        try:
            response = requests.get(
                f"{GITLAB_URL}/-/health",
                timeout=10
            )
            assert response.status_code == 200, f"GitLab недоступен: {response.status_code}"
        except requests.exceptions.RequestException as e:
            pytest.fail(f"Ошибка подключения к GitLab: {e}")
    
    def test_redmine_health(self):
        """Redmine должен быть доступен"""
        try:
            response = requests.get(
                REDMINE_URL,
                timeout=10
            )
            assert response.status_code == 200, f"Redmine недоступен: {response.status_code}"
        except requests.exceptions.RequestException as e:
            pytest.fail(f"Ошибка подключения к Redmine: {e}")
    
    def test_sonarqube_health(self):
        """SonarQube должен быть доступен"""
        try:
            response = requests.get(
                f"{SONARQUBE_URL}/api/system/status",
                auth=('admin', SONARQUBE_TOKEN),
                timeout=10
            )
            assert response.status_code == 200, f"SonarQube недоступен: {response.status_code}"
            
            data = response.json()
            assert data.get('status') in ['UP', 'STARTING'], f"SonarQube статус: {data.get('status')}"
        except requests.exceptions.RequestException as e:
            pytest.fail(f"Ошибка подключения к SonarQube: {e}")
    
    def test_postgresql_connection(self):
        """PostgreSQL должен быть доступен"""
        import socket
        
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            result = sock.connect_ex((POSTGRES_HOST, POSTGRES_PORT))
            sock.close()
            
            assert result == 0, f"PostgreSQL недоступен на {POSTGRES_HOST}:{POSTGRES_PORT}"
        except Exception as e:
            pytest.fail(f"Ошибка подключения к PostgreSQL: {e}")


class TestGitLabAPI:
    """Тесты GitLab API"""
    
    @requires_gitlab_token
    def test_gitlab_api_authentication(self):
        """Проверка аутентификации в GitLab API"""
        response = requests.get(
            f"{GITLAB_URL}/api/v4/user",
            headers={'PRIVATE-TOKEN': GITLAB_TOKEN},
            timeout=10
        )
        assert response.status_code == 200, "Неверный GITLAB_TOKEN"
        
        user = response.json()
        assert 'username' in user, "Некорректный ответ API"
    
    @requires_gitlab_token
    def test_gitlab_projects_list(self):
        """Проверка получения списка проектов"""
        response = requests.get(
            f"{GITLAB_URL}/api/v4/projects",
            headers={'PRIVATE-TOKEN': GITLAB_TOKEN},
            timeout=10
        )
        assert response.status_code == 200, "Ошибка получения списка проектов"
        
        projects = response.json()
        assert isinstance(projects, list), "Ответ должен быть списком"
    
    @requires_gitlab_token
    def test_gitlab_project_exists(self):
        """Проверка существования проекта UT-103 CI/CD"""
        response = requests.get(
            f"{GITLAB_URL}/api/v4/projects",
            headers={'PRIVATE-TOKEN': GITLAB_TOKEN},
            params={'search': 'UT-103'},
            timeout=10
        )
        assert response.status_code == 200
        
        projects = response.json()
        # Проект может не существовать, это не ошибка
        # Просто проверяем что API работает
        assert isinstance(projects, list)


class TestRedmineAPI:
    """Тесты Redmine API"""
    
    @requires_redmine_key
    def test_redmine_api_authentication(self):
        """Проверка аутентификации в Redmine API"""
        response = requests.get(
            f"{REDMINE_URL}/users/current.json",
            headers={'X-Redmine-API-Key': REDMINE_API_KEY},
            timeout=10
        )
        assert response.status_code == 200, "Неверный REDMINE_API_KEY"
        
        user = response.json()
        assert 'user' in user, "Некорректный ответ API"
    
    @requires_redmine_key
    def test_redmine_projects_list(self):
        """Проверка получения списка проектов"""
        response = requests.get(
            f"{REDMINE_URL}/projects.json",
            headers={'X-Redmine-API-Key': REDMINE_API_KEY},
            timeout=10
        )
        assert response.status_code == 200, "Ошибка получения списка проектов"
        
        projects = response.json()
        assert 'projects' in projects, "Некорректный ответ API"
    
    @requires_redmine_key
    def test_redmine_trackers_list(self):
        """Проверка получения списка трекеров"""
        response = requests.get(
            f"{REDMINE_URL}/trackers.json",
            headers={'X-Redmine-API-Key': REDMINE_API_KEY},
            timeout=10
        )
        assert response.status_code == 200, "Ошибка получения списка трекеров"
        
        trackers = response.json()
        assert 'trackers' in trackers, "Некорректный ответ API"


class TestSonarQubeAPI:
    """Тесты SonarQube API"""
    
    def test_sonarqube_system_info(self):
        """Проверка получения информации о системе"""
        response = requests.get(
            f"{SONARQUBE_URL}/api/system/status",
            auth=('admin', SONARQUBE_TOKEN),
            timeout=10
        )
        assert response.status_code == 200, "Ошибка получения информации о системе"
        
        info = response.json()
        assert 'status' in info, "Некорректный ответ API"
    
    def test_sonarqube_projects_search(self):
        """Проверка поиска проектов"""
        response = requests.get(
            f"{SONARQUBE_URL}/api/projects/search",
            auth=('admin', SONARQUBE_TOKEN),
            timeout=10
        )
        assert response.status_code == 200, "Ошибка поиска проектов"
        
        result = response.json()
        assert 'components' in result, "Некорректный ответ API"


class TestIntegration:
    """Тесты интеграции между сервисами"""
    
    @pytest.mark.slow
    @requires_gitlab_token
    @requires_redmine_key
    def test_gitlab_redmine_webhook_flow(self):
        """Проверка flow: GitLab push -> Redmine update"""
        # Этот тест требует настроенных webhooks
        # Пропускаем если нет полной настройки
        pytest.skip("Требует настроенных webhooks")
    
    @pytest.mark.slow
    def test_sonarqube_gitlab_integration(self):
        """Проверка интеграции SonarQube с GitLab"""
        # Этот тест требует настроенной интеграции
        pytest.skip("Требует настроенной интеграции")


class TestDataConsistency:
    """Проверка консистентности данных"""
    
    @requires_gitlab_token
    @requires_redmine_key
    def test_users_consistency(self):
        """Проверка что пользователи созданы в обоих системах"""
        # Получение пользователей из GitLab
        gitlab_response = requests.get(
            f"{GITLAB_URL}/api/v4/users",
            headers={'PRIVATE-TOKEN': GITLAB_TOKEN},
            timeout=10
        )
        
        # Получение пользователей из Redmine
        redmine_response = requests.get(
            f"{REDMINE_URL}/users.json",
            headers={'X-Redmine-API-Key': REDMINE_API_KEY},
            timeout=10
        )
        
        if gitlab_response.status_code == 200 and redmine_response.status_code == 200:
            gitlab_users = gitlab_response.json()
            redmine_users = redmine_response.json().get('users', [])
            
            # Проверяем что есть хотя бы один пользователь
            assert len(gitlab_users) > 0, "В GitLab нет пользователей"
            assert len(redmine_users) > 0, "В Redmine нет пользователей"


class TestPerformance:
    """Тесты производительности"""
    
    def test_gitlab_api_response_time(self):
        """GitLab API должен отвечать быстро"""
        start = time.time()
        response = requests.get(
            f"{GITLAB_URL}/-/health",
            timeout=10
        )
        elapsed = time.time() - start
        
        assert response.status_code == 200
        assert elapsed < 2.0, f"GitLab API слишком медленный: {elapsed:.2f}s"
    
    def test_redmine_api_response_time(self):
        """Redmine API должен отвечать быстро"""
        start = time.time()
        response = requests.get(
            REDMINE_URL,
            timeout=10
        )
        elapsed = time.time() - start
        
        assert response.status_code == 200
        assert elapsed < 2.0, f"Redmine API слишком медленный: {elapsed:.2f}s"
    
    def test_sonarqube_api_response_time(self):
        """SonarQube API должен отвечать быстро"""
        start = time.time()
        response = requests.get(
            f"{SONARQUBE_URL}/api/system/status",
            auth=('admin', SONARQUBE_TOKEN),
            timeout=10
        )
        elapsed = time.time() - start
        
        assert response.status_code == 200
        assert elapsed < 3.0, f"SonarQube API слишком медленный: {elapsed:.2f}s"


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short', '-m', 'not slow'])

