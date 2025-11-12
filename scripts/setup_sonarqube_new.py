#!/usr/bin/env python3
"""
Автоматическая настройка SonarQube для CI/CD системы
"""
import requests
import time
import json
import sys

class SonarQubeSetup:
    def __init__(self):
        self.base_url = "http://localhost:9000"
        self.default_user = "admin"
        self.default_password = "admin"
        self.new_password = "SonarAdmin123!"
        self.session = requests.Session()
        self.token = None
        
    def check_status(self):
        """Проверка статуса SonarQube"""
        print("\n" + "="*60)
        print("Проверка статуса SonarQube...")
        print("="*60)
        
        try:
            response = requests.get(f"{self.base_url}/api/system/status", timeout=5)
            if response.status_code == 200:
                data = response.json()
                print(f"✅ SonarQube работает")
                print(f"   Версия: {data.get('version', 'unknown')}")
                print(f"   Статус: {data.get('status', 'unknown')}")
                return True
        except Exception as e:
            print(f"❌ Ошибка: {e}")
            return False
    
    def change_default_password(self):
        """Смена пароля по умолчанию"""
        print("\n" + "="*60)
        print("Смена пароля администратора...")
        print("="*60)
        
        # Сначала проверим, работает ли новый пароль
        try:
            test_response = requests.get(
                f"{self.base_url}/api/authentication/validate",
                auth=(self.default_user, self.new_password)
            )
            
            if test_response.status_code == 200:
                print(f"ℹ️  Пароль уже был изменен ранее")
                self.session.auth = (self.default_user, self.new_password)
                return True
        except:
            pass
        
        # Попробуем войти с дефолтным паролем и сменить
        try:
            response = requests.post(
                f"{self.base_url}/api/users/change_password",
                auth=(self.default_user, self.default_password),
                data={
                    'login': self.default_user,
                    'password': self.new_password,
                    'previousPassword': self.default_password
                }
            )
            
            if response.status_code == 204:
                print(f"✅ Пароль успешно изменен")
                self.session.auth = (self.default_user, self.new_password)
                return True
            else:
                print(f"❌ Ошибка смены пароля: {response.status_code}")
                print(f"   {response.text}")
                # Попробуем использовать новый пароль
                self.session.auth = (self.default_user, self.new_password)
                return True
        except Exception as e:
            print(f"❌ Ошибка: {e}")
            self.session.auth = (self.default_user, self.new_password)
            return True
    
    def create_token(self):
        """Создание токена для API"""
        print("\n" + "="*60)
        print("Создание токена для API...")
        print("="*60)
        
        token_name = "cicd-integration-token"
        
        try:
            # Попробуем создать токен
            response = self.session.post(
                f"{self.base_url}/api/user_tokens/generate",
                auth=self.session.auth,
                data={
                    'name': token_name
                }
            )
            
            if response.status_code == 200:
                data = response.json()
                self.token = data.get('token')
                print(f"✅ Токен создан: {self.token}")
                
                # Сохраним токен в файл
                with open('secrets/sonarqube_token.txt', 'w') as f:
                    f.write(self.token)
                print(f"✅ Токен сохранен в secrets/sonarqube_token.txt")
                return True
            else:
                print(f"❌ Ошибка создания токена: {response.status_code}")
                print(f"   {response.text}")
                return False
        except Exception as e:
            print(f"❌ Ошибка: {e}")
            return False
    
    def create_project(self, project_key, project_name):
        """Создание проекта в SonarQube"""
        print(f"\nСоздание проекта: {project_name} ({project_key})")
        
        try:
            response = self.session.post(
                f"{self.base_url}/api/projects/create",
                auth=self.session.auth,
                data={
                    'project': project_key,
                    'name': project_name
                }
            )
            
            if response.status_code == 200:
                print(f"✅ Проект {project_name} создан")
                return True
            elif response.status_code == 400 and 'already exists' in response.text:
                print(f"ℹ️  Проект {project_name} уже существует")
                return True
            else:
                print(f"❌ Ошибка создания проекта: {response.status_code}")
                print(f"   {response.text}")
                return False
        except Exception as e:
            print(f"❌ Ошибка: {e}")
            return False
    
    def setup_quality_gate(self, project_key):
        """Настройка Quality Gate для проекта"""
        print(f"\nНастройка Quality Gate для {project_key}")
        
        try:
            # Получим ID дефолтного Quality Gate
            response = self.session.get(
                f"{self.base_url}/api/qualitygates/list",
                auth=self.session.auth
            )
            
            if response.status_code == 200:
                gates = response.json().get('qualitygates', [])
                default_gate = next((g for g in gates if g.get('isDefault')), None)
                
                if default_gate:
                    gate_id = default_gate.get('id')
                    print(f"✅ Используется Quality Gate: {default_gate.get('name')}")
                    return True
            
            print(f"ℹ️  Quality Gate настроен по умолчанию")
            return True
        except Exception as e:
            print(f"❌ Ошибка: {e}")
            return False
    
    def run(self):
        """Запуск полной настройки"""
        print("\n" + "="*60)
        print("НАСТРОЙКА SONARQUBE")
        print("="*60)
        
        # 1. Проверка статуса
        if not self.check_status():
            print("\n❌ SonarQube недоступен")
            return False
        
        # 2. Смена пароля
        if not self.change_default_password():
            print("\n❌ Не удалось сменить пароль")
            return False
        
        # 3. Создание токена
        if not self.create_token():
            print("\n❌ Не удалось создать токен")
            return False
        
        # 4. Создание проектов
        print("\n" + "="*60)
        print("Создание проектов...")
        print("="*60)
        
        projects = [
            ('ut103-ci', 'UT103 Configuration'),
            ('ut103-external-files', 'UT103 External Files')
        ]
        
        for project_key, project_name in projects:
            if not self.create_project(project_key, project_name):
                print(f"\n❌ Не удалось создать проект {project_name}")
                return False
            self.setup_quality_gate(project_key)
        
        # 5. Итоговая информация
        print("\n" + "="*60)
        print("✅ НАСТРОЙКА ЗАВЕРШЕНА")
        print("="*60)
        print(f"\nДанные для доступа:")
        print(f"  URL: {self.base_url}")
        print(f"  Логин: {self.default_user}")
        print(f"  Пароль: {self.new_password}")
        print(f"  Токен: {self.token}")
        print(f"\nПроекты:")
        for project_key, project_name in projects:
            print(f"  - {project_name} ({project_key})")
            print(f"    {self.base_url}/dashboard?id={project_key}")
        
        return True

if __name__ == "__main__":
    setup = SonarQubeSetup()
    success = setup.run()
    sys.exit(0 if success else 1)
