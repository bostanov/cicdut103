#!/usr/bin/env python3
"""
Скрипт для создания Personal Access Token в GitLab через API
"""
import requests
import json

GITLAB_URL = "http://localhost:8929"
ROOT_USER = "root"
ROOT_PASS = "gitlab_root_password"

print("="*80)
print("СОЗДАНИЕ GITLAB TOKEN")
print("="*80)

# 1. Получение CSRF токена
print("\n1. Получение CSRF токена...")
session = requests.Session()
response = session.get(f"{GITLAB_URL}/users/sign_in")

if response.status_code != 200:
    print(f"[FAIL] Не удалось получить страницу входа: {response.status_code}")
    exit(1)

# Извлечение CSRF токена из HTML
import re
csrf_match = re.search(r'name="authenticity_token" value="([^"]+)"', response.text)
if not csrf_match:
    print("[FAIL] CSRF токен не найден")
    exit(1)

csrf_token = csrf_match.group(1)
print(f"[OK] CSRF токен получен: {csrf_token[:20]}...")

# 2. Вход в систему
print("\n2. Вход в систему...")
login_data = {
    'user[login]': ROOT_USER,
    'user[password]': ROOT_PASS,
    'authenticity_token': csrf_token
}

response = session.post(f"{GITLAB_URL}/users/sign_in", data=login_data, allow_redirects=True)

if 'Invalid Login or password' in response.text:
    print("[FAIL] Неверный логин или пароль")
    exit(1)

print("[OK] Вход выполнен успешно")

# 3. Получение страницы создания токена
print("\n3. Получение страницы создания токена...")
response = session.get(f"{GITLAB_URL}/-/user_settings/personal_access_tokens")

if response.status_code != 200:
    print(f"[FAIL] Не удалось получить страницу токенов: {response.status_code}")
    exit(1)

# Извлечение нового CSRF токена
csrf_match = re.search(r'name="authenticity_token" value="([^"]+)"', response.text)
if not csrf_match:
    print("[FAIL] CSRF токен не найден на странице токенов")
    exit(1)

csrf_token = csrf_match.group(1)
print(f"[OK] CSRF токен обновлен")

# 4. Создание токена
print("\n4. Создание Personal Access Token...")
token_data = {
    'personal_access_token[name]': 'CI/CD Integration Token',
    'personal_access_token[expires_at]': '',  # Без срока действия
    'personal_access_token[scopes][]': ['api', 'read_repository', 'write_repository'],
    'authenticity_token': csrf_token
}

response = session.post(
    f"{GITLAB_URL}/-/user_settings/personal_access_tokens",
    data=token_data,
    allow_redirects=True
)

# Поиск токена в ответе
token_match = re.search(r'data-clipboard-text="([^"]+)"', response.text)
if not token_match:
    # Попробуем другой паттерн
    token_match = re.search(r'id="created-personal-access-token"[^>]*value="([^"]+)"', response.text)

if token_match:
    token = token_match.group(1)
    print(f"[OK] Токен создан: {token}")
    
    # Сохранение токена
    import os
    os.makedirs('secrets', exist_ok=True)
    with open('secrets/gitlab_token.txt', 'w') as f:
        f.write(token)
    print("[OK] Токен сохранен в secrets/gitlab_token.txt")
    
    print("\n" + "="*80)
    print("[OK] УСПЕШНО!")
    print("="*80)
    print(f"\nGitLab Token: {token}")
    print(f"\nИспользуйте:")
    print(f"  export GITLAB_TOKEN={token}")
else:
    print("[WARN] Токен не найден в ответе")
    print("[INFO] Создайте токен вручную:")
    print(f"  1. Откройте {GITLAB_URL}/-/user_settings/personal_access_tokens")
    print("  2. Создайте токен с правами: api, read_repository, write_repository")
    print("  3. Сохраните токен в secrets/gitlab_token.txt")
