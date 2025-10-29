"""
SonarQube Client для автоматической настройки и анализа качества кода
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


class SonarQubeClient:
    """Клиент для работы с SonarQube API"""
    
    def __init__(self, base_url: str = None, token: str = None):
        self.logger = get_logger("sonarqube_client")
        
        self.base_url = (base_url or os.getenv('SONARQUBE_URL', 'http://sonarqube:9000')).rstrip('/')
        self.token = token or os.getenv('SONARQUBE_TOKEN', '')
        
        # Настройка сессии для API запросов
        self.session = requests.Session()
        if self.token:
            self.session.auth = (self.token, '')
        else:
            # Используем дефолтные учетные данные admin/admin
            self.session.auth = ('admin', 'admin')
        
        self.session.headers.update({
            'Content-Type': 'application/x-www-form-urlencoded'
        })
        
        self.logger.info("SonarQube client initialized", 
                        component="init",
                        details={
                            "base_url": self.base_url,
                            "has_token": bool(self.token)
                        })
    
    def _make_request(self, method: str, endpoint: str, data: Dict = None, 
                     params: Dict = None, timeout: int = 30) -> requests.Response:
        """Выполнение HTTP запроса к SonarQube API"""
        url = f"{self.base_url}/api/{endpoint.lstrip('/')}"
        
        try:
            response = self.session.request(
                method=method,
                url=url,
                data=data,
                params=params,
                timeout=timeout
            )
            
            # Логирование запроса
            self.logger.debug("SonarQube API request", 
                            component="api_request",
                            details={
                                "method": method,
                                "endpoint": endpoint,
                                "status_code": response.status_code
                            })
            
            return response
            
        except requests.exceptions.RequestException as e:
            self.logger.error("SonarQube API request failed", 
                            component="api_request",
                            details={
                                "method": method,
                                "endpoint": endpoint,
                                "error": str(e)
                            })
            raise
    
    def wait_for_sonarqube_ready(self, max_attempts: int = 30, delay: int = 10) -> bool:
        """Ожидание готовности SonarQube"""
        correlation_id = log_operation_start("sonarqube_client", "wait_for_ready")
        
        for attempt in range(max_attempts):
            try:
                response = requests.get(f"{self.base_url}/api/system/status", timeout=10)
                if response.status_code == 200:
                    status_data = response.json()
                    if status_data.get('status') == 'UP':
                        log_operation_success("sonarqube_client", "wait_for_ready", correlation_id,
                                            {"attempts": attempt + 1})
                        return True
                    
            except Exception as e:
                self.logger.debug("SonarQube not ready yet", 
                                component="readiness_check",
                                details={"attempt": attempt + 1, "error": str(e)})
            
            if attempt < max_attempts - 1:
                time.sleep(delay)
        
        log_operation_error("sonarqube_client", "wait_for_ready", correlation_id, 
                          Exception(f"SonarQube not ready after {max_attempts} attempts"))
        return False
    
    def change_default_password(self, new_password: str = "sonar_admin_password") -> bool:
        """Изменение пароля по умолчанию"""
        correlation_id = log_operation_start("sonarqube_client", "change_default_password")
        
        try:
            # Проверяем, нужно ли менять пароль
            response = self._make_request('GET', '/users/search', params={'q': 'admin'})
            
            if response.status_code != 200:
                # Пароль уже изменен или есть другие проблемы
                log_operation_success("sonarqube_client", "change_default_password", correlation_id,
                                    {"message": "Password already changed or not needed"})
                return True
            
            # Изменение пароля
            password_data = {
                'login': 'admin',
                'password': new_password,
                'previousPassword': 'admin'
            }
            
            response = self._make_request('POST', '/users/change_password', data=password_data)
            
            if response.status_code in [200, 204]:
                # Обновляем аутентификацию
                self.session.auth = ('admin', new_password)
                log_operation_success("sonarqube_client", "change_default_password", correlation_id)
                return True
            else:
                self.logger.warning("Password change returned unexpected status", 
                                  component="password_change",
                                  details={"status_code": response.status_code})
                return True  # Возможно пароль уже изменен
                
        except Exception as e:
            log_operation_error("sonarqube_client", "change_default_password", correlation_id, e)
            return False
    
    def create_user_token(self, username: str = "admin", token_name: str = "CI/CD Integration Token") -> Optional[str]:
        """Создание токена пользователя"""
        correlation_id = log_operation_start("sonarqube_client", "create_user_token")
        
        try:
            token_data = {
                'name': token_name
            }
            
            response = self._make_request('POST', '/user_tokens/generate', data=token_data)
            
            if response.status_code == 200:
                token_info = response.json()
                token = token_info.get('token')
                
                if token:
                    # Обновляем аутентификацию для использования токена
                    self.token = token
                    self.session.auth = (token, '')
                    
                    log_operation_success("sonarqube_client", "create_user_token", correlation_id)
                    return token
            
            self.logger.warning("Token creation failed", 
                              component="token_creation",
                              details={"status_code": response.status_code})
            return None
            
        except Exception as e:
            log_operation_error("sonarqube_client", "create_user_token", correlation_id, e)
            return None
    
    def create_project(self, project_key: str, project_name: str, visibility: str = "public") -> bool:
        """Создание проекта в SonarQube"""
        correlation_id = log_operation_start("sonarqube_client", "create_project", 
                                           {"project_key": project_key})
        
        try:
            # Проверка существования проекта
            existing_project = self.get_project_info(project_key)
            if existing_project:
                self.logger.info("Project already exists", 
                               component="project_management",
                               details={"project_key": project_key})
                return True
            
            project_data = {
                'project': project_key,
                'name': project_name,
                'visibility': visibility
            }
            
            response = self._make_request('POST', '/projects/create', data=project_data)
            
            if response.status_code in [200, 400]:  # 400 может означать что проект уже существует
                log_operation_success("sonarqube_client", "create_project", correlation_id,
                                    {"project_key": project_key})
                return True
            else:
                response.raise_for_status()
                
        except Exception as e:
            log_operation_error("sonarqube_client", "create_project", correlation_id, e)
            return False
    
    def get_project_info(self, project_key: str) -> Optional[Dict[str, Any]]:
        """Получение информации о проекте"""
        try:
            response = self._make_request('GET', '/projects/search', params={'projects': project_key})
            
            if response.status_code == 200:
                data = response.json()
                components = data.get('components', [])
                for component in components:
                    if component.get('key') == project_key:
                        return component
            
            return None
            
        except Exception as e:
            self.logger.error("Failed to get project info", 
                            component="project_management",
                            details={"project_key": project_key, "error": str(e)})
            return None
    
    def create_quality_gate(self, name: str, conditions: List[Dict] = None) -> bool:
        """Создание Quality Gate"""
        correlation_id = log_operation_start("sonarqube_client", "create_quality_gate", {"name": name})
        
        try:
            # Проверка существования Quality Gate
            existing_gates = self.get_quality_gates()
            for gate in existing_gates:
                if gate.get('name') == name:
                    self.logger.info("Quality Gate already exists", 
                                   component="quality_gate_management",
                                   details={"name": name})
                    return True
            
            # Создание Quality Gate
            gate_data = {'name': name}
            response = self._make_request('POST', '/qualitygates/create', data=gate_data)
            
            if response.status_code != 200:
                response.raise_for_status()
            
            gate_info = response.json()
            gate_id = gate_info.get('id')
            
            # Добавление условий по умолчанию для 1С проектов
            if conditions is None:
                conditions = [
                    {'metric': 'bugs', 'op': 'GT', 'error': '0'},
                    {'metric': 'vulnerabilities', 'op': 'GT', 'error': '0'},
                    {'metric': 'code_smells', 'op': 'GT', 'error': '10'},
                    {'metric': 'coverage', 'op': 'LT', 'error': '80'},
                    {'metric': 'duplicated_lines_density', 'op': 'GT', 'error': '3'}
                ]
            
            # Добавление условий
            for condition in conditions:
                condition_data = {
                    'gateId': gate_id,
                    'metric': condition['metric'],
                    'op': condition['op'],
                    'error': condition['error']
                }
                
                self._make_request('POST', '/qualitygates/create_condition', data=condition_data)
            
            log_operation_success("sonarqube_client", "create_quality_gate", correlation_id,
                                {"gate_id": gate_id})
            return True
            
        except Exception as e:
            log_operation_error("sonarqube_client", "create_quality_gate", correlation_id, e)
            return False
    
    def get_quality_gates(self) -> List[Dict[str, Any]]:
        """Получение списка Quality Gates"""
        try:
            response = self._make_request('GET', '/qualitygates/list')
            
            if response.status_code == 200:
                data = response.json()
                return data.get('qualitygates', [])
            
            return []
            
        except Exception as e:
            self.logger.error("Failed to get quality gates", 
                            component="quality_gate_management",
                            details={"error": str(e)})
            return []
    
    def set_project_quality_gate(self, project_key: str, gate_name: str) -> bool:
        """Назначение Quality Gate проекту"""
        correlation_id = log_operation_start("sonarqube_client", "set_project_quality_gate",
                                           {"project_key": project_key, "gate_name": gate_name})
        
        try:
            # Поиск Quality Gate по имени
            gates = self.get_quality_gates()
            gate_id = None
            
            for gate in gates:
                if gate.get('name') == gate_name:
                    gate_id = gate.get('id')
                    break
            
            if not gate_id:
                self.logger.error("Quality Gate not found", 
                                component="quality_gate_assignment",
                                details={"gate_name": gate_name})
                return False
            
            # Назначение Quality Gate проекту
            assignment_data = {
                'projectKey': project_key,
                'gateId': gate_id
            }
            
            response = self._make_request('POST', '/qualitygates/select', data=assignment_data)
            
            if response.status_code in [200, 204]:
                log_operation_success("sonarqube_client", "set_project_quality_gate", correlation_id)
                return True
            else:
                response.raise_for_status()
                
        except Exception as e:
            log_operation_error("sonarqube_client", "set_project_quality_gate", correlation_id, e)
            return False
    
    def get_project_analysis_status(self, project_key: str) -> Optional[Dict[str, Any]]:
        """Получение статуса анализа проекта"""
        try:
            response = self._make_request('GET', '/qualitygates/project_status', 
                                        params={'projectKey': project_key})
            
            if response.status_code == 200:
                return response.json()
            
            return None
            
        except Exception as e:
            self.logger.error("Failed to get project analysis status", 
                            component="analysis_status",
                            details={"project_key": project_key, "error": str(e)})
            return None
    
    def get_project_measures(self, project_key: str, metrics: List[str] = None) -> Dict[str, Any]:
        """Получение метрик проекта"""
        if metrics is None:
            metrics = [
                'bugs', 'vulnerabilities', 'code_smells', 'coverage',
                'duplicated_lines_density', 'ncloc', 'sqale_index'
            ]
        
        try:
            params = {
                'component': project_key,
                'metricKeys': ','.join(metrics)
            }
            
            response = self._make_request('GET', '/measures/component', params=params)
            
            if response.status_code == 200:
                data = response.json()
                measures = data.get('component', {}).get('measures', [])
                
                result = {}
                for measure in measures:
                    metric = measure.get('metric')
                    value = measure.get('value')
                    if metric and value is not None:
                        # Преобразование значений в числа где возможно
                        try:
                            if '.' in value:
                                result[metric] = float(value)
                            else:
                                result[metric] = int(value)
                        except ValueError:
                            result[metric] = value
                
                return result
            
            return {}
            
        except Exception as e:
            self.logger.error("Failed to get project measures", 
                            component="project_measures",
                            details={"project_key": project_key, "error": str(e)})
            return {}
    
    def create_webhook(self, name: str, url: str) -> bool:
        """Создание webhook"""
        correlation_id = log_operation_start("sonarqube_client", "create_webhook", {"name": name})
        
        try:
            webhook_data = {
                'name': name,
                'url': url
            }
            
            response = self._make_request('POST', '/webhooks/create', data=webhook_data)
            
            if response.status_code in [200, 400]:  # 400 может означать что webhook уже существует
                log_operation_success("sonarqube_client", "create_webhook", correlation_id)
                return True
            else:
                response.raise_for_status()
                
        except Exception as e:
            log_operation_error("sonarqube_client", "create_webhook", correlation_id, e)
            return False
    
    def setup_full_project(self, project_key: str, project_name: str, 
                          quality_gate_name: str = "1C Quality Gate") -> bool:
        """Полная настройка проекта в SonarQube"""
        correlation_id = log_operation_start("sonarqube_client", "setup_full_project", 
                                           {"project_key": project_key})
        
        try:
            # 1. Создание проекта
            if not self.create_project(project_key, project_name):
                return False
            
            # 2. Создание Quality Gate для 1С проектов
            self.create_quality_gate(quality_gate_name)
            
            # 3. Назначение Quality Gate проекту
            self.set_project_quality_gate(project_key, quality_gate_name)
            
            # 4. Создание webhook для уведомлений
            webhook_url = "http://cicd-service:8080/api/sonarqube-webhook"
            self.create_webhook(f"{project_key}-webhook", webhook_url)
            
            log_operation_success("sonarqube_client", "setup_full_project", correlation_id,
                                {"project_key": project_key})
            return True
            
        except Exception as e:
            log_operation_error("sonarqube_client", "setup_full_project", correlation_id, e)
            return False
    
    def get_analysis_history(self, project_key: str, limit: int = 10) -> List[Dict[str, Any]]:
        """Получение истории анализов проекта"""
        try:
            params = {
                'component': project_key,
                'ps': limit
            }
            
            response = self._make_request('GET', '/project_analyses/search', params=params)
            
            if response.status_code == 200:
                data = response.json()
                return data.get('analyses', [])
            
            return []
            
        except Exception as e:
            self.logger.error("Failed to get analysis history", 
                            component="analysis_history",
                            details={"project_key": project_key, "error": str(e)})
            return []


# Глобальный экземпляр клиента
_sonarqube_client = None


def get_sonarqube_client() -> SonarQubeClient:
    """Получение глобального экземпляра SonarQube клиента"""
    global _sonarqube_client
    if _sonarqube_client is None:
        _sonarqube_client = SonarQubeClient()
    return _sonarqube_client