#!/usr/bin/env python3
"""
Тест входа в GitLab и создание токена
"""
import requests
from bs4 import BeautifulSoup
import re

GITLAB_URL = "http://localhost:8929"
USERNAME = "root"
PASSWORD = "Admin123!"

print("="*80)
print("АВТОМАТИЧЕСКАЯ НАСТРОЙКА GITLAB")
print("="*80)

session = requests.Session()

# 1. Получение страницы входа
print("\n1. Получение страницы входа...")
try:
    response = session.get(f"{GITLAB_URL}/users/sign_in", timeout=10)
    if response.status_code != 200:
        print(f"[FAIL] Страница входа недоступна: {response.status_code}")
        exit(1)
    print("[OK] Страница входа получена")
except Exception as e:
    print(f"[FAIL] Ошибка: {e}")
    exit(1)

# 2. Извлечение CSRF токена
print("\n2. Извлечение CSRF токена...")
csrf_match = re.search(r'name="authenticity_token" value="([^"]+)"', response.text)
if not csrf_match:
    print("[FAIL] CSRF токен не найден")
    exit(1)

csrf_token = csrf_match.group(1)
print(f"[OK] CSRF токен: {csrf_token[:20]}...")

# 3. Вход в систему
print(f"\n3. Вход в систему (username: {USERNAME})...")
login_data = {
    'user[login]': USERNAME,
    'user[password]': PASSWORD,
    'authenticity_token': csrf_token
}

try:
    response = session.post(f"{GITLAB_URL}/users/sign_in", data=login_data, allow_redirects=True, timeout=10)
    
    if 'Invalid Login or password' in response.text or 'Invalid login or password' in response.text:
        print("[FAIL] Неверный логин или пароль")
        print("Попробуем создать root пользователя...")
        exit(1)
    
    if response.status_code == 200:
        print("[OK] Вход выполнен успешно!")
    else:
        print(f"[WARN] Статус: {response.status_code}")
        
except Exception as e:
    print(f"[FAIL] Ошибка входа: {e}")
    exit(1)

# 4. Создание Personal Access Token
print("\n4. Создание Personal Access Token...")
try:
    # Получение страницы токенов
    response = session.get(f"{GITLAB_URL}/-/user_settings/personal_access_tokens", timeout=10)
    
    if response.status_code != 200:
        print(f"[FAIL] Не удалось получить страницу токенов: {response.status_code}")
        exit(1)
    
    # Извлечение CSRF токена
    csrf_match = re.search(r'name="authenticity_token" value="([^"]+)"', response.text)
    if not csrf_match:
        print("[FAIL] CSRF токен не найден на странице токенов")
        exit(1)
    
    csrf_token = csrf_match.group(1)
    
    # Создание токена
    token_data = {
        'personal_access_token[name]': 'CI/CD Integration Token',
        'personal_access_token[expires_at]': '',
        'personal_access_token[scopes][]': ['api', 'read_repository', 'write_repository'],
        'authenticity_token': csrf_token
    }
    
    response = session.post(
        f"{GITLAB_URL}/-/user_settings/personal_access_tokens",
        data=token_data,
        allow_redirects=True,
        timeout=10
    )
    
    # Поиск токена в ответе
    token_match = re.search(r'data-clipboard-text="([^"]+)"', response.text)
    if not token_match:
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
        
        # Проверка токена
        print("\n5. Проверка токена через API...")
        headers = {'PRIVATE-TOKEN': token}
        response = requests.get(f"{GITLAB_URL}/api/v4/version", headers=headers, timeout=10)
        
        if response.status_code == 200:
            version = response.json().get('version')
            print(f"[OK] Токен работает! GitLab version: {version}")
            
            print("\n" + "="*80)
            print("[OK] GITLAB ПОЛНОСТЬЮ НАСТРОЕН!")
            print("="*80)
            print(f"\nToken: {token}")
            print(f"\nТеперь можно создавать проекты:")
            print(f"  python scripts/create_gitlab_projects.py")
        else:
            print(f"[WARN] API вернул статус {response.status_code}")
    else:
        print("[WARN] Токен не найден в ответе")
        print("Возможно токен уже существует, проверьте веб-интерфейс")
        
except Exception as e:
    print(f"[FAIL] Ошибка создания токена: {e}")
    import traceback
    traceback.print_exc()
