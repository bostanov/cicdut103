"""
Тесты интеграций CI/CD системы
"""
import unittest
import os
import sys
from unittest.mock import Mock, patch, MagicMock

# Добавление пути к модулям приложения
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from integrations import (
    PostgreSQLClient, GitLabClient, SonarQubeClient, 
    RedmineClient, SystemInitializer
)


class TestPostgreSQLClient(unittest.TestCase):
    """Тесты PostgreSQL клиента"""
    
    def setUp(self):
        self.mock_connection = Mock()
        self.mock_cursor = Mock()
        self.mock_connection.cursor.return_value.__enter__.return_value = self.mock_cursor
    
    @patch('integrations.postgres_client.psycopg2.connect')
    def test_connection(self, mock_connect):
        """Тест подключения к базе данных"""
        mock_connect.return_value = self.mock_connection
        
        client = PostgreSQLClient()
        self.assertIsNotNone(client.connection)
        mock_connect.assert_called_once()
    
    @patch('integrations.postgres_client.psycopg2.connect')
    def test_create_pipeline(self, mock_connect):
        """Тест создания пайплайна"""
        mock_connect.return_value = self.mock_connection
        self.mock_cursor.fetchall.return_value = [{'id': 1}]
        
        client = PostgreSQLClient()
        pipeline_id = client.create_pipeline(
            pipeline_type="test",
            project_name="test-project"
        )
        
        self.assertEqual(pipeline_id, 1)


class TestGitLabClient(unittest.TestCase):
    """Тесты GitLab клиента"""
    
    def setUp(self):
        self.client = GitLabClient(base_url="http://test-gitlab", token="test-token")
    
    @patch('integrations.gitlab_client.requests.Session.request')
    def test_create_project(self, mock_request):
        """Тест создания проекта"""
        mock_response = Mock()
        mock_response.status_code = 201
        mock_response.json.return_value = {'id': 1, 'name': 'test-project'}
        mock_request.return_value = mock_response
        
        # Мокаем проверку существования проекта
        with patch.object(self.client, 'get_project_by_name', return_value=None):
            project = self.client.create_project("test-project", "Test Description")
        
        self.assertIsNotNone(project)
        self.assertEqual(project['name'], 'test-project')


class TestSonarQubeClient(unittest.TestCase):
    """Тесты SonarQube клиента"""
    
    def setUp(self):
        self.client = SonarQubeClient(base_url="http://test-sonar", token="test-token")
    
    @patch('integrations.sonarqube_client.requests.Session.request')
    def test_create_project(self, mock_request):
        """Тест создания проекта"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_request.return_value = mock_response
        
        # Мокаем проверку существования проекта
        with patch.object(self.client, 'get_project_info', return_value=None):
            result = self.client.create_project("test-key", "Test Project")
        
        self.assertTrue(result)


class TestRedmineClient(unittest.TestCase):
    """Тесты Redmine клиента"""
    
    def setUp(self):
        self.client = RedmineClient(
            base_url="http://test-redmine", 
            username="admin", 
            password="admin"
        )
    
    @patch('integrations.redmine_client.requests.Session.request')
    def test_create_project(self, mock_request):
        """Тест создания проекта"""
        mock_response = Mock()
        mock_response.status_code = 201
        mock_response.json.return_value = {
            'project': {'id': 1, 'identifier': 'test-project'}
        }
        mock_request.return_value = mock_response
        
        # Мокаем проверку существования проекта
        with patch.object(self.client, 'get_project_by_identifier', return_value=None):
            project = self.client.create_project(
                "test-project", "Test Project", "Test Description"
            )
        
        self.assertIsNotNone(project)
        self.assertEqual(project['identifier'], 'test-project')


class TestSystemInitializer(unittest.TestCase):
    """Тесты системного инициализатора"""
    
    def setUp(self):
        self.initializer = SystemInitializer()
    
    @patch('integrations.init_integrations.requests.get')
    def test_wait_for_service_ready(self, mock_get):
        """Тест ожидания готовности сервиса"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_get.return_value = mock_response
        
        result = self.initializer.wait_for_service_ready(
            "test-service", "http://test-service", max_attempts=1
        )
        
        self.assertTrue(result)
    
    @patch.object(SystemInitializer, 'wait_for_service_ready')
    def test_wait_for_all_services(self, mock_wait):
        """Тест ожидания всех сервисов"""
        mock_wait.return_value = True
        
        result = self.initializer.wait_for_all_services()
        
        self.assertTrue(result)
        # Проверяем что вызывается для всех 4 сервисов
        self.assertEqual(mock_wait.call_count, 4)


if __name__ == '__main__':
    unittest.main()