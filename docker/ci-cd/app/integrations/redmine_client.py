"""
Redmine Client для автоматической настройки и управления задачами
"""
import os
import sys
import requests
import time
from datetime import datetime
from typing import Dict, Any, List, Optional
import json

# Добавление пути к shared модулям
sys.path.append('/app')

from shared.logger import get_logger, log_operation_start, log_operation_success, log_operation_error


class RedmineClient:
    """Клиент для работы с Redmine API"""
    
    def __init__(self, base_url: str = None, username: str = None, password: str = None, api_key: str = None):
        self.logger = get_logger("redmine_client")
        
        self.base_url = (base_url or os.getenv('REDMINE_URL', 'http://redmine:3000')).rstrip('/')
        self.username = username or os.getenv('REDMINE_USERNAME', 'admin')
        self.password = password or os.getenv('REDMINE_PASSWORD', 'admin')
        self.api_key = api_key or os.getenv('REDMINE_API_KEY', '')
        
        # Настройка сессии для API запросов
        self.session = requests.Session()
        
        # Используем API ключ если доступен, иначе базовую аутентификацию
        if self.api_key:
            self.session.headers.update({
                'Content-Type': 'application/json',
                'X-Redmine-API-Key': self.api_key
            })
        else:
            self.session.auth = (self.username, self.password)
            self.session.headers.update({
                'Content-Type': 'application/json'
            })
        
        self.logger.info("Redmine client initialized", 
                        component="init",
                        details={
                            "base_url": self.base_url,
                            "username": self.username
                        })
    
    def _make_request(self, method: str, endpoint: str, data: Dict = None, 
                     params: Dict = None, timeout: int = 30) -> requests.Response:
        """Выполнение HTTP запроса к Redmine API"""
        url = f"{self.base_url}/{endpoint.lstrip('/')}"
        
        try:
            response = self.session.request(
                method=method,
                url=url,
                json=data,
                params=params,
                timeout=timeout
            )
            
            # Логирование запроса
            self.logger.debug("Redmine API request", 
                            component="api_request",
                            details={
                                "method": method,
                                "endpoint": endpoint,
                                "status_code": response.status_code
                            })
            
            return response
            
        except requests.exceptions.RequestException as e:
            self.logger.error("Redmine API request failed", 
                            component="api_request",
                            details={
                                "method": method,
                                "endpoint": endpoint,
                                "error": str(e)
                            })
            raise
    
    def wait_for_redmine_ready(self, max_attempts: int = 30, delay: int = 10) -> bool:
        """Ожидание готовности Redmine"""
        correlation_id = log_operation_start("redmine_client", "wait_for_ready")
        
        for attempt in range(max_attempts):
            try:
                response = requests.get(self.base_url, timeout=10)
                if response.status_code == 200:
                    log_operation_success("redmine_client", "wait_for_ready", correlation_id,
                                        {"attempts": attempt + 1})
                    return True
                    
            except Exception as e:
                self.logger.debug("Redmine not ready yet", 
                                component="readiness_check",
                                details={"attempt": attempt + 1, "error": str(e)})
            
            if attempt < max_attempts - 1:
                time.sleep(delay)
        
        log_operation_error("redmine_client", "wait_for_ready", correlation_id, 
                          Exception(f"Redmine not ready after {max_attempts} attempts"))
        return False
    
    def get_api_key(self) -> Optional[str]:
        """Получение API ключа пользователя"""
        correlation_id = log_operation_start("redmine_client", "get_api_key")
        
        try:
            # Получение информации о текущем пользователе
            response = self._make_request('GET', '/users/current.json')
            
            if response.status_code == 200:
                user_data = response.json()
                api_key = user_data.get('user', {}).get('api_key')
                
                if api_key:
                    # Обновляем заголовки для использования API ключа
                    self.session.headers['X-Redmine-API-Key'] = api_key
                    log_operation_success("redmine_client", "get_api_key", correlation_id)
                    return api_key
            
            self.logger.warning("API key not found in user data", 
                              component="api_key_retrieval")
            return None
            
        except Exception as e:
            log_operation_error("redmine_client", "get_api_key", correlation_id, e)
            return None
    
    def create_project(self, identifier: str, name: str, description: str = "", 
                      is_public: bool = False) -> Optional[Dict[str, Any]]:
        """Создание проекта в Redmine"""
        correlation_id = log_operation_start("redmine_client", "create_project", 
                                           {"identifier": identifier})
        
        try:
            # Проверка существования проекта
            existing_project = self.get_project_by_identifier(identifier)
            if existing_project:
                self.logger.info("Project already exists", 
                               component="project_management",
                               details={"identifier": identifier, "id": existing_project['id']})
                return existing_project
            
            project_data = {
                'project': {
                    'name': name,
                    'identifier': identifier,
                    'description': description,
                    'is_public': is_public,
                    'enabled_module_names': [
                        'issue_tracking', 'time_tracking', 'news', 
                        'documents', 'files', 'wiki', 'repository'
                    ]
                }
            }
            
            response = self._make_request('POST', '/projects.json', data=project_data)
            
            if response.status_code == 201:
                project = response.json()['project']
                log_operation_success("redmine_client", "create_project", correlation_id,
                                    {"project_id": project['id'], "identifier": identifier})
                return project
            else:
                response.raise_for_status()
                
        except Exception as e:
            log_operation_error("redmine_client", "create_project", correlation_id, e)
            return None
    
    def get_project_by_identifier(self, identifier: str) -> Optional[Dict[str, Any]]:
        """Получение проекта по идентификатору"""
        try:
            response = self._make_request('GET', f'/projects/{identifier}.json')
            
            if response.status_code == 200:
                return response.json()['project']
            
            return None
            
        except Exception as e:
            self.logger.error("Failed to get project by identifier", 
                            component="project_management",
                            details={"identifier": identifier, "error": str(e)})
            return None
    
    def create_tracker(self, name: str, description: str = "") -> Optional[Dict[str, Any]]:
        """Создание трекера"""
        correlation_id = log_operation_start("redmine_client", "create_tracker", {"name": name})
        
        try:
            # Проверка существования трекера
            existing_trackers = self.get_trackers()
            for tracker in existing_trackers:
                if tracker.get('name') == name:
                    self.logger.info("Tracker already exists", 
                                   component="tracker_management",
                                   details={"name": name, "id": tracker['id']})
                    return tracker
            
            tracker_data = {
                'tracker': {
                    'name': name,
                    'description': description,
                    'default_status_id': 1,  # Новая
                    'is_in_chlog': True,
                    'is_in_roadmap': True
                }
            }
            
            response = self._make_request('POST', '/trackers.json', data=tracker_data)
            
            if response.status_code == 201:
                tracker = response.json()['tracker']
                log_operation_success("redmine_client", "create_tracker", correlation_id,
                                    {"tracker_id": tracker['id'], "name": name})
                return tracker
            else:
                response.raise_for_status()
                
        except Exception as e:
            log_operation_error("redmine_client", "create_tracker", correlation_id, e)
            return None
    
    def get_trackers(self) -> List[Dict[str, Any]]:
        """Получение списка трекеров"""
        try:
            response = self._make_request('GET', '/trackers.json')
            
            if response.status_code == 200:
                return response.json().get('trackers', [])
            
            return []
            
        except Exception as e:
            self.logger.error("Failed to get trackers", 
                            component="tracker_management",
                            details={"error": str(e)})
            return []
    
    def create_custom_field(self, name: str, field_format: str, possible_values: List[str] = None,
                           description: str = "") -> Optional[Dict[str, Any]]:
        """Создание пользовательского поля"""
        correlation_id = log_operation_start("redmine_client", "create_custom_field", {"name": name})
        
        try:
            # Проверка существования поля
            existing_fields = self.get_custom_fields()
            for field in existing_fields:
                if field.get('name') == name:
                    self.logger.info("Custom field already exists", 
                                   component="custom_field_management",
                                   details={"name": name, "id": field['id']})
                    return field
            
            field_data = {
                'custom_field': {
                    'name': name,
                    'field_format': field_format,
                    'description': description,
                    'is_required': False,
                    'is_for_all': True,
                    'is_filter': True,
                    'searchable': True
                }
            }
            
            if possible_values and field_format == 'list':
                field_data['custom_field']['possible_values'] = possible_values
            
            response = self._make_request('POST', '/custom_fields.json', data=field_data)
            
            if response.status_code == 201:
                field = response.json()['custom_field']
                log_operation_success("redmine_client", "create_custom_field", correlation_id,
                                    {"field_id": field['id'], "name": name})
                return field
            else:
                response.raise_for_status()
                
        except Exception as e:
            log_operation_error("redmine_client", "create_custom_field", correlation_id, e)
            return None
    
    def get_custom_fields(self) -> List[Dict[str, Any]]:
        """Получение списка пользовательских полей"""
        try:
            response = self._make_request('GET', '/custom_fields.json')
            
            if response.status_code == 200:
                return response.json().get('custom_fields', [])
            
            return []
            
        except Exception as e:
            self.logger.error("Failed to get custom fields", 
                            component="custom_field_management",
                            details={"error": str(e)})
            return []
    
    def create_issue(self, project_id: str, subject: str, description: str = "",
                    tracker_id: int = 1, priority_id: int = 2, status_id: int = 1,
                    assigned_to_id: int = None, custom_fields: List[Dict] = None) -> Optional[Dict[str, Any]]:
        """Создание задачи"""
        correlation_id = log_operation_start("redmine_client", "create_issue", {"subject": subject})
        
        try:
            issue_data = {
                'issue': {
                    'project_id': project_id,
                    'subject': subject,
                    'description': description,
                    'tracker_id': tracker_id,
                    'priority_id': priority_id,
                    'status_id': status_id
                }
            }
            
            if assigned_to_id:
                issue_data['issue']['assigned_to_id'] = assigned_to_id
            
            if custom_fields:
                issue_data['issue']['custom_fields'] = custom_fields
            
            response = self._make_request('POST', '/issues.json', data=issue_data)
            
            if response.status_code == 201:
                issue = response.json()['issue']
                log_operation_success("redmine_client", "create_issue", correlation_id,
                                    {"issue_id": issue['id'], "subject": subject})
                return issue
            else:
                response.raise_for_status()
                
        except Exception as e:
            log_operation_error("redmine_client", "create_issue", correlation_id, e)
            return None
    
    def update_issue(self, issue_id: int, updates: Dict[str, Any]) -> bool:
        """Обновление задачи"""
        correlation_id = log_operation_start("redmine_client", "update_issue", {"issue_id": issue_id})
        
        try:
            issue_data = {'issue': updates}
            
            response = self._make_request('PUT', f'/issues/{issue_id}.json', data=issue_data)
            
            if response.status_code in [200, 204]:
                log_operation_success("redmine_client", "update_issue", correlation_id)
                return True
            else:
                response.raise_for_status()
                
        except Exception as e:
            log_operation_error("redmine_client", "update_issue", correlation_id, e)
            return False
    
    def add_comment_to_issue(self, issue_id: int, comment: str, private: bool = False) -> bool:
        """Добавление комментария к задаче"""
        correlation_id = log_operation_start("redmine_client", "add_comment", {"issue_id": issue_id})
        
        try:
            update_data = {
                'notes': comment,
                'private_notes': private
            }
            
            return self.update_issue(issue_id, update_data)
            
        except Exception as e:
            log_operation_error("redmine_client", "add_comment", correlation_id, e)
            return False
    
    def get_issues(self, project_id: str = None, status_id: str = "open", 
                  limit: int = 100, offset: int = 0) -> List[Dict[str, Any]]:
        """Получение списка задач"""
        try:
            params = {
                'limit': limit,
                'offset': offset,
                'status_id': status_id
            }
            
            if project_id:
                params['project_id'] = project_id
            
            response = self._make_request('GET', '/issues.json', params=params)
            
            if response.status_code == 200:
                return response.json().get('issues', [])
            
            return []
            
        except Exception as e:
            self.logger.error("Failed to get issues", 
                            component="issue_management",
                            details={"project_id": project_id, "error": str(e)})
            return []
    
    def get_issue_attachments(self, issue_id: int) -> List[Dict[str, Any]]:
        """Получение вложений задачи"""
        try:
            response = self._make_request('GET', f'/issues/{issue_id}.json', 
                                        params={'include': 'attachments'})
            
            if response.status_code == 200:
                issue_data = response.json()['issue']
                return issue_data.get('attachments', [])
            
            return []
            
        except Exception as e:
            self.logger.error("Failed to get issue attachments", 
                            component="attachment_management",
                            details={"issue_id": issue_id, "error": str(e)})
            return []
    
    def download_attachment(self, attachment_id: int, output_path: str) -> bool:
        """Скачивание вложения"""
        correlation_id = log_operation_start("redmine_client", "download_attachment", 
                                           {"attachment_id": attachment_id})
        
        try:
            # Получение информации о вложении
            response = self._make_request('GET', f'/attachments/{attachment_id}.json')
            
            if response.status_code != 200:
                response.raise_for_status()
            
            attachment_info = response.json()['attachment']
            content_url = attachment_info.get('content_url')
            
            if not content_url:
                raise Exception("Content URL not found in attachment info")
            
            # Скачивание файла
            download_response = self.session.get(f"{self.base_url}{content_url}", timeout=120)
            download_response.raise_for_status()
            
            # Создание директории если не существует
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            
            # Сохранение файла
            with open(output_path, 'wb') as f:
                f.write(download_response.content)
            
            log_operation_success("redmine_client", "download_attachment", correlation_id,
                                {"output_path": output_path, "size": len(download_response.content)})
            return True
            
        except Exception as e:
            log_operation_error("redmine_client", "download_attachment", correlation_id, e)
            return False
    
    def setup_full_project(self, identifier: str, name: str, description: str) -> Optional[Dict[str, Any]]:
        """Полная настройка проекта в Redmine"""
        correlation_id = log_operation_start("redmine_client", "setup_full_project", 
                                           {"identifier": identifier})
        
        try:
            # 1. Создание проекта
            project = self.create_project(identifier, name, description)
            if not project:
                return None
            
            # 2. Создание трекеров для разных типов задач
            trackers = [
                {"name": "Внешний файл", "description": "Обработка внешних файлов .epf/.erf/.efd"},
                {"name": "Анализ кода", "description": "Результаты анализа SonarQube"},
                {"name": "CI/CD", "description": "Задачи автоматизации и пайплайнов"}
            ]
            
            for tracker_info in trackers:
                self.create_tracker(tracker_info["name"], tracker_info["description"])
            
            # 3. Создание пользовательских полей для интеграции
            custom_fields = [
                {
                    "name": "GitLab Commit",
                    "field_format": "string",
                    "description": "Хеш коммита в GitLab"
                },
                {
                    "name": "SonarQube Project",
                    "field_format": "string",
                    "description": "Ключ проекта в SonarQube"
                },
                {
                    "name": "Quality Gate Status",
                    "field_format": "list",
                    "possible_values": ["PASSED", "FAILED", "PENDING"],
                    "description": "Статус Quality Gate в SonarQube"
                },
                {
                    "name": "Pipeline ID",
                    "field_format": "string",
                    "description": "ID пайплайна GitLab"
                }
            ]
            
            for field_info in custom_fields:
                possible_values = field_info.pop("possible_values", None)
                self.create_custom_field(possible_values=possible_values, **field_info)
            
            log_operation_success("redmine_client", "setup_full_project", correlation_id,
                                {"project_id": project['id'], "identifier": identifier})
            
            return project
            
        except Exception as e:
            log_operation_error("redmine_client", "setup_full_project", correlation_id, e)
            return None
    
    def create_integration_user(self, login: str, firstname: str, lastname: str, 
                               mail: str, password: str) -> Optional[Dict[str, Any]]:
        """Создание пользователя для интеграции"""
        correlation_id = log_operation_start("redmine_client", "create_integration_user", 
                                           {"login": login})
        
        try:
            user_data = {
                'user': {
                    'login': login,
                    'firstname': firstname,
                    'lastname': lastname,
                    'mail': mail,
                    'password': password,
                    'must_change_passwd': False,
                    'generate_password': False
                }
            }
            
            response = self._make_request('POST', '/users.json', data=user_data)
            
            if response.status_code == 201:
                user = response.json()['user']
                log_operation_success("redmine_client", "create_integration_user", correlation_id,
                                    {"user_id": user['id'], "login": login})
                return user
            elif response.status_code == 422:
                # Пользователь уже существует
                self.logger.info("User already exists", 
                               component="user_management",
                               details={"login": login})
                return {"login": login}  # Возвращаем минимальную информацию
            else:
                response.raise_for_status()
                
        except Exception as e:
            log_operation_error("redmine_client", "create_integration_user", correlation_id, e)
            return None


# Глобальный экземпляр клиента
_redmine_client = None


def get_redmine_client() -> RedmineClient:
    """Получение глобального экземпляра Redmine клиента"""
    global _redmine_client
    if _redmine_client is None:
        _redmine_client = RedmineClient(
            api_key=os.getenv('REDMINE_API_KEY', '')
        )
    return _redmine_client