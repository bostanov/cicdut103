#!/usr/bin/env python3
"""
Скрипт инициализации GitLab для CI/CD системы
"""
import sys
import os
import requests
import time
import json

GITLAB_URL = os.getenv('GITLAB_URL', 'http://localhost:8929')
GITLAB_TOKEN = os.getenv('GITLAB_TOKEN', '')

class GitLabInitializer:
    """Класс для инициализации GitLab"""
    
    def __init__(self):
        self.base_url = GITLAB_URL.rstrip('/')
        self.token = GITLAB_TOKEN
        self.headers = {}
        if self.token:
            self.headers = {'PRIVATE-TOKEN': self.token}
    
    def log(self, message: str, level: str = "INFO"):
        """Логирование"""
        message = message.replace("✅", "[OK]").replace("❌", "[FAIL]").replace("⚠️", "[WARN]")
        print(f"[{level}] {message}")
    
    def wait_for_gitlab(self, max_attempts: int = 60) -> bool:
        """Ожидание готовности GitLab"""
        self.log("Ожидание готовности GitLab (может занять 5-10 минут)...")
        
        for attempt in range(max_attempts):
            try:
                response = requests.get(f"{self.base_url}/api/v4/version", timeout=10)
                if response.status_code == 200:
                    version = response.json()
                    self.log(f"[OK] GitLab готов (версия {version.get('version', 'unknown')})")
                    return True
            except Exception as e:
                if attempt % 10 == 0:
                    self.log(f"Попытка {attempt + 1}/{max_attempts}...", "DEBUG")
            
            if attempt < max_attempts - 1:
                time.sleep(10)
        
        self.log("[FAIL] GitLab не готов", "ERROR")
        return False
    
    def get_root_password(self) -> str:
        """Получение начального пароля root"""
        self.log("Получение начального пароля root...")
        
        # Пароль задан в docker-compose
        password = "gitlab_root_password"
        self.log(f"[OK] Используется пароль из конфигурации")
        return password
    
    def create_access_token(self) -> str:
        """Создание Personal Access Token"""
        self.log("Создание Personal Access Token...")
        
        # Для создания токена нужно использовать веб-интерфейс или API с аутентификацией
        # Пока используем временное решение
        self.log("[WARN] Токен нужно создать вручную через веб-интерфейс")
        self.log("  1. Откройте http://localhost:8929")
        self.log("  2. Войдите как root / gitlab_root_password")
        self.log("  3. Перейдите в Settings -> Access Tokens")
        self.log("  4. Создайте токен с правами: api, read_repository, write_repository")
        self.log("  5. Сохраните токен в secrets/gitlab_token.txt")
        
        return ""
    
    def create_project(self, name: str, path: str, description: str) -> dict:
        """Создание проекта"""
        if not self.token:
            self.log(f"[WARN] Токен не установлен, пропускаем создание проекта {name}")
            return None
        
        self.log(f"Создание проекта {name}...")
        
        # Проверка существования
        try:
            response = requests.get(
                f"{self.base_url}/api/v4/projects/{path}",
                headers=self.headers,
                timeout=30
            )
            if response.status_code == 200:
                project = response.json()
                self.log(f"  Проект {name} уже существует (ID: {project['id']})")
                return project
        except:
            pass
        
        # Создание проекта
        data = {
            'name': name,
            'path': path,
            'description': description,
            'visibility': 'private',
            'initialize_with_readme': True
        }
        
        try:
            response = requests.post(
                f"{self.base_url}/api/v4/projects",
                headers=self.headers,
                json=data,
                timeout=30
            )
            
            if response.status_code == 201:
                project = response.json()
                self.log(f"  [OK] Проект {name} создан (ID: {project['id']})")
                return project
            else:
                self.log(f"  [FAIL] Ошибка создания проекта: {response.status_code}", "ERROR")
                return None
        except Exception as e:
            self.log(f"  [FAIL] Ошибка: {e}", "ERROR")
            return None
    
    def run_initialization(self) -> bool:
        """Полная инициализация"""
        self.log("="*80)
        self.log("ИНИЦИАЛИЗАЦИЯ GITLAB ДЛЯ CI/CD СИСТЕМЫ")
        self.log("="*80)
        
        # 1. Ожидание готовности
        if not self.wait_for_gitlab():
            return False
        
        # 2. Получение пароля
        self.log("\n1. Получение пароля root...")
        password = self.get_root_password()
        
        # 3. Создание токена
        self.log("\n2. Создание Access Token...")
        if not self.token:
            self.create_access_token()
            self.log("\n[WARN] Продолжение требует токена. Создайте токен и запустите скрипт снова с:")
            self.log("  export GITLAB_TOKEN=<your_token>")
            self.log("  python scripts/init_gitlab.py")
            return True
        
        # 4. Создание проектов
        self.log("\n3. Создание проектов...")
        projects = [
            ("UT-103 CI", "ut103-ci", "Основная конфигурация 1С"),
            ("UT-103 External Files", "ut103-external-files", "Внешние отчеты и обработки")
        ]
        
        for name, path, desc in projects:
            self.create_project(name, path, desc)
        
        # 5. Итог
        self.log("\n" + "="*80)
        self.log("[OK] ИНИЦИАЛИЗАЦИЯ ЗАВЕРШЕНА")
        self.log("="*80)
        self.log(f"\nGitLab URL: {self.base_url}")
        self.log(f"Root password: gitlab_root_password")
        if self.token:
            self.log(f"Token: {self.token[:20]}...")
        
        return True

if __name__ == '__main__':
    initializer = GitLabInitializer()
    success = initializer.run_initialization()
    sys.exit(0 if success else 1)
