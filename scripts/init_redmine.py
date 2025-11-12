#!/usr/bin/env python3
"""
Скрипт полной инициализации Redmine для CI/CD системы
Выполняет все необходимые настройки согласно требованиям
"""
import sys
import os
import requests
import json
import time
from typing import Dict, Any, List, Optional

# Конфигурация Redmine
REDMINE_URL = os.getenv('REDMINE_URL', 'http://localhost:3000')
REDMINE_USER = os.getenv('REDMINE_USERNAME', 'admin')
REDMINE_PASS = os.getenv('REDMINE_PASSWORD', 'admin')
REDMINE_API_KEY = os.getenv('REDMINE_API_KEY', '3bd281756c90fae4a2b5c8d9e0f1a2b3c4d5e6f7')

class RedmineInitializer:
    """Класс для инициализации Redmine"""
    
    def __init__(self):
        self.base_url = REDMINE_URL.rstrip('/')
        self.session = requests.Session()
        self.api_key = REDMINE_API_KEY
        if self.api_key:
            self.session.headers.update({
                'Content-Type': 'application/json',
                'X-Redmine-API-Key': self.api_key
            })
        else:
            self.session.auth = (REDMINE_USER, REDMINE_PASS)
            self.session.headers.update({'Content-Type': 'application/json'})
        
    def log(self, message: str, level: str = "INFO"):
        """Логирование"""
        # Удаляем emoji для совместимости с Windows console
        message = message.replace("✅", "[OK]").replace("❌", "[FAIL]").replace("⚠️", "[WARN]")
        print(f"[{level}] {message}")
    
    def wait_for_redmine(self, max_attempts: int = 30) -> bool:
        """Ожидание готовности Redmine"""
        self.log("Ожидание готовности Redmine...")
        
        for attempt in range(max_attempts):
            try:
                response = requests.get(self.base_url, timeout=10)
                if response.status_code == 200:
                    self.log(f"✅ Redmine готов (попытка {attempt + 1})")
                    return True
            except Exception as e:
                self.log(f"Попытка {attempt + 1}/{max_attempts}: {str(e)}", "DEBUG")
            
            if attempt < max_attempts - 1:
                time.sleep(10)
        
        self.log("❌ Redmine не готов", "ERROR")
        return False
    
    def get_api_key(self) -> Optional[str]:
        """Получение API ключа"""
        try:
            response = self.session.get(f"{self.base_url}/users/current.json")
            if response.status_code == 200:
                user_data = response.json()
                api_key = user_data.get('user', {}).get('api_key')
                if api_key:
                    self.api_key = api_key
                    self.session.headers['X-Redmine-API-Key'] = api_key
                    if hasattr(self.session, 'auth'):
                        del self.session.auth
                    self.log(f"[OK] API ключ получен: {api_key[:10]}...")
                    return api_key
            return None
        except Exception as e:
            self.log(f"Ошибка получения API ключа: {e}", "ERROR")
            return None
    
    def create_issue_status(self, name: str, is_closed: bool = False) -> Optional[Dict]:
        """Создание статуса задачи"""
        try:
            # Проверка существования
            response = self.session.get(f"{self.base_url}/issue_statuses.json")
            if response.status_code == 200:
                statuses = response.json().get('issue_statuses', [])
                for status in statuses:
                    if status.get('name') == name:
                        self.log(f"  Статус '{name}' уже существует (ID: {status['id']})")
                        return status
            
            # Создание нового статуса
            data = {
                'issue_status': {
                    'name': name,
                    'is_closed': is_closed
                }
            }
            
            response = self.session.post(f"{self.base_url}/issue_statuses.json", json=data)
            if response.status_code == 201:
                status = response.json()['issue_status']
                self.log(f"  ✅ Создан статус '{name}' (ID: {status['id']})")
                return status
            else:
                self.log(f"  ⚠️  Не удалось создать статус '{name}': {response.status_code}", "WARN")
                return None
                
        except Exception as e:
            self.log(f"  ❌ Ошибка создания статуса '{name}': {e}", "ERROR")
            return None
    
    def create_tracker(self, name: str, description: str = "") -> Optional[Dict]:
        """Создание трекера"""
        try:
            # Проверка существования
            response = self.session.get(f"{self.base_url}/trackers.json")
            if response.status_code == 200:
                trackers = response.json().get('trackers', [])
                for tracker in trackers:
                    if tracker.get('name') == name:
                        self.log(f"  Трекер '{name}' уже существует (ID: {tracker['id']})")
                        return tracker
            
            # Создание нового трекера
            data = {
                'tracker': {
                    'name': name,
                    'description': description,
                    'default_status_id': 1,
                    'is_in_chlog': True,
                    'is_in_roadmap': True
                }
            }
            
            response = self.session.post(f"{self.base_url}/trackers.json", json=data)
            if response.status_code == 201:
                tracker = response.json()['tracker']
                self.log(f"  ✅ Создан трекер '{name}' (ID: {tracker['id']})")
                return tracker
            else:
                self.log(f"  ⚠️  Не удалось создать трекер '{name}': {response.status_code}", "WARN")
                return None
                
        except Exception as e:
            self.log(f"  ❌ Ошибка создания трекера '{name}': {e}", "ERROR")
            return None
    
    def create_custom_field(self, name: str, field_format: str, 
                           possible_values: List[str] = None, description: str = "") -> Optional[Dict]:
        """Создание пользовательского поля"""
        try:
            # Проверка существования
            response = self.session.get(f"{self.base_url}/custom_fields.json")
            if response.status_code == 200:
                fields = response.json().get('custom_fields', [])
                for field in fields:
                    if field.get('name') == name:
                        self.log(f"  Поле '{name}' уже существует (ID: {field['id']})")
                        return field
            
            # Создание нового поля
            data = {
                'custom_field': {
                    'name': name,
                    'field_format': field_format,
                    'description': description,
                    'is_required': False,
                    'is_for_all': True,
                    'is_filter': True,
                    'searchable': True,
                    'customized_type': 'issue'
                }
            }
            
            if possible_values and field_format == 'list':
                data['custom_field']['possible_values'] = possible_values
            
            response = self.session.post(f"{self.base_url}/custom_fields.json", json=data)
            if response.status_code == 201:
                field = response.json()['custom_field']
                self.log(f"  ✅ Создано поле '{name}' (ID: {field['id']})")
                return field
            else:
                self.log(f"  ⚠️  Не удалось создать поле '{name}': {response.status_code}", "WARN")
                return None
                
        except Exception as e:
            self.log(f"  ❌ Ошибка создания поля '{name}': {e}", "ERROR")
            return None
    
    def create_project(self, identifier: str, name: str, description: str) -> Optional[Dict]:
        """Создание проекта"""
        try:
            # Проверка существования
            response = self.session.get(f"{self.base_url}/projects/{identifier}.json")
            if response.status_code == 200:
                project = response.json()['project']
                self.log(f"  Проект '{identifier}' уже существует (ID: {project['id']})")
                return project
            
            # Создание нового проекта
            data = {
                'project': {
                    'name': name,
                    'identifier': identifier,
                    'description': description,
                    'is_public': False,
                    'enabled_module_names': [
                        'issue_tracking', 'time_tracking', 'news',
                        'documents', 'files', 'wiki', 'repository', 'boards'
                    ]
                }
            }
            
            response = self.session.post(f"{self.base_url}/projects.json", json=data)
            if response.status_code == 201:
                project = response.json()['project']
                self.log(f"  ✅ Создан проект '{identifier}' (ID: {project['id']})")
                return project
            else:
                self.log(f"  ⚠️  Не удалось создать проект '{identifier}': {response.status_code}", "WARN")
                return None
                
        except Exception as e:
            self.log(f"  ❌ Ошибка создания проекта '{identifier}': {e}", "ERROR")
            return None
    
    def create_user(self, login: str, firstname: str, lastname: str, 
                   mail: str, password: str) -> Optional[Dict]:
        """Создание пользователя"""
        try:
            # Создание пользователя
            data = {
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
            
            response = self.session.post(f"{self.base_url}/users.json", json=data)
            if response.status_code == 201:
                user = response.json()['user']
                self.log(f"  ✅ Создан пользователь '{login}' (ID: {user['id']})")
                return user
            elif response.status_code == 422:
                self.log(f"  Пользователь '{login}' уже существует")
                return {'login': login}
            else:
                self.log(f"  ⚠️  Не удалось создать пользователя '{login}': {response.status_code}", "WARN")
                return None
                
        except Exception as e:
            self.log(f"  ❌ Ошибка создания пользователя '{login}': {e}", "ERROR")
            return None
    
    def run_full_initialization(self) -> bool:
        """Полная инициализация Redmine"""
        self.log("="*80)
        self.log("ИНИЦИАЛИЗАЦИЯ REDMINE ДЛЯ CI/CD СИСТЕМЫ")
        self.log("="*80)
        
        # 1. Ожидание готовности
        if not self.wait_for_redmine():
            return False
        
        # 2. Получение API ключа
        self.log("\n1. Получение API ключа...")
        self.get_api_key()
        
        # 3. Создание кастомных статусов
        self.log("\n2. Создание кастомных статусов...")
        statuses = [
            ("На проверке", False),
            ("Проверка пройдена", False),
            ("Есть замечания", False)
        ]
        
        for status_name, is_closed in statuses:
            self.create_issue_status(status_name, is_closed)
        
        # 4. Создание трекеров
        self.log("\n3. Создание трекеров...")
        trackers = [
            ("Доработка конфигурации", "Задачи на доработку конфигурации 1С"),
            ("Внешний файл", "Разработка внешних отчетов и обработок"),
            ("Анализ кода", "Результаты анализа качества кода SonarQube"),
            ("CI/CD", "Задачи автоматизации и настройки пайплайнов")
        ]
        
        for tracker_name, tracker_desc in trackers:
            self.create_tracker(tracker_name, tracker_desc)
        
        # 5. Создание пользовательских полей
        self.log("\n4. Создание пользовательских полей...")
        custom_fields = [
            ("GitLab Commit", "string", None, "Хеш коммита в GitLab"),
            ("GitLab Pipeline ID", "string", None, "ID пайплайна в GitLab"),
            ("GitLab Pipeline URL", "string", None, "Ссылка на пайплайн в GitLab"),
            ("SonarQube Project", "string", None, "Ключ проекта в SonarQube"),
            ("SonarQube Analysis URL", "string", None, "Ссылка на анализ в SonarQube"),
            ("Quality Gate Status", "list", ["PASSED", "FAILED", "PENDING", "ERROR"], "Статус Quality Gate"),
            ("Bugs Count", "int", None, "Количество найденных ошибок"),
            ("Vulnerabilities Count", "int", None, "Количество уязвимостей"),
            ("Code Smells Count", "int", None, "Количество code smells"),
            ("Coverage Percent", "float", None, "Процент покрытия кода"),
            ("External File Type", "list", [".epf", ".erf", ".efd"], "Тип внешнего файла"),
            ("External File Path", "string", None, "Путь к разобранному файлу в Git")
        ]
        
        for field_name, field_format, possible_values, field_desc in custom_fields:
            self.create_custom_field(field_name, field_format, possible_values, field_desc)
        
        # 6. Создание проекта
        self.log("\n5. Создание проекта...")
        project = self.create_project(
            "ut103-ci",
            "UT-103 CI/CD",
            "Проект автоматизации CI/CD для конфигурации 1С UT-103"
        )
        
        # 7. Создание пользователей для интеграции
        self.log("\n6. Создание пользователей для интеграции...")
        users = [
            ("gitsync", "GitSync", "Service", "gitsync@ci.local", "gitsync_password_123"),
            ("precommit1c", "PreCommit1C", "Service", "precommit1c@ci.local", "precommit1c_password_123"),
            ("pipeline", "Pipeline", "Coordinator", "pipeline@ci.local", "pipeline_password_123")
        ]
        
        for login, firstname, lastname, mail, password in users:
            self.create_user(login, firstname, lastname, mail, password)
        
        # 8. Итоговая информация
        self.log("\n" + "="*80)
        self.log("✅ ИНИЦИАЛИЗАЦИЯ ЗАВЕРШЕНА УСПЕШНО")
        self.log("="*80)
        self.log(f"\nRedmine URL: {self.base_url}")
        self.log(f"Проект: ut103-ci")
        self.log(f"API Key: {self.api_key[:20] if self.api_key else 'Не получен'}...")
        self.log("\nСозданные статусы:")
        self.log("  - На проверке")
        self.log("  - Проверка пройдена")
        self.log("  - Есть замечания")
        self.log("\nСозданные трекеры:")
        self.log("  - Доработка конфигурации")
        self.log("  - Внешний файл")
        self.log("  - Анализ кода")
        self.log("  - CI/CD")
        self.log("\nСозданные пользователи:")
        self.log("  - gitsync")
        self.log("  - precommit1c")
        self.log("  - pipeline")
        
        return True


if __name__ == '__main__':
    initializer = RedmineInitializer()
    success = initializer.run_full_initialization()
    sys.exit(0 if success else 1)
