#!/usr/bin/env python3
"""
Создание токена через GitLab OAuth
"""
import requests
import sys
from urllib.parse import urljoin

GITLAB_URL = "http://localhost:8929"
USERNAME = "root"
PASSWORD = "rootpassword123"

def get_csrf_token(session):
    """Получить CSRF токен со страницы входа"""
    print("📋 Получение CSRF токена...")
    try:
        response = session.get(f"{GITLAB_URL}/users/sign_in", timeout=10)
        response.raise_for_status()
        
        # Ищем токен в HTML
        import re
        match = re.search(r'name="authenticity_token" value="([^"]+)"', response.text)
        if match:
            token = match.group(1)
            print(f"✅ CSRF токен получен: {token[:20]}...")
            return token
        else:
            print("❌ CSRF токен не найден в HTML")
            return None
    except Exception as e:
        print(f"❌ Ошибка получения CSRF токена: {e}")
        return None

def login(session, csrf_token):
    """Выполнить вход в GitLab"""
    print("🔐 Выполнение входа...")
    try:
        data = {
            'utf8': '✓',
            'authenticity_token': csrf_token,
            'user[login]': USERNAME,
            'user[password]': PASSWORD,
            'user[remember_me]': '0'
        }
        
        response = session.post(
            f"{GITLAB_URL}/users/sign_in",
            data=data,
            allow_redirects=True,
            timeout=10
        )
        
        if response.status_code == 200 and 'sign_in' not in response.url:
            print("✅ Вход выполнен успешно!")
            return True
        else:
            print(f"❌ Ошибка входа: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Ошибка входа: {e}")
        return False

def create_token_via_ui(session):
    """Создать токен через веб-интерфейс"""
    print("🔧 Попытка создания токена через UI...")
    
    # Получаем страницу создания токена
    try:
        response = session.get(f"{GITLAB_URL}/-/profile/personal_access_tokens", timeout=10)
        if response.status_code != 200:
            print(f"❌ Не удалось открыть страницу токенов: {response.status_code}")
            return None
        
        # Ищем CSRF токен на странице
        import re
        match = re.search(r'name="authenticity_token" value="([^"]+)"', response.text)
        if not match:
            print("❌ CSRF токен не найден на странице токенов")
            return None
        
        csrf_token = match.group(1)
        print(f"✅ CSRF токен для создания токена получен")
        
        # Создаем токен
        data = {
            'utf8': '✓',
            'authenticity_token': csrf_token,
            'personal_access_token[name]': 'API Token',
            'personal_access_token[expires_at]': '',
            'personal_access_token[scopes][]': ['api', 'read_repository', 'write_repository']
        }
        
        response = session.post(
            f"{GITLAB_URL}/-/profile/personal_access_tokens",
            data=data,
            allow_redirects=True,
            timeout=10
        )
        
        if response.status_code == 200:
            # Ищем токен в ответе
            match = re.search(r'data-clipboard-text="([^"]+)"', response.text)
            if match:
                token = match.group(1)
                print(f"✅ Токен создан: {token}")
                return token
            else:
                print("❌ Токен не найден в ответе")
                # Попробуем найти другим способом
                match = re.search(r'glpat-[a-zA-Z0-9_-]+', response.text)
                if match:
                    token = match.group(0)
                    print(f"✅ Токен найден альтернативным способом: {token}")
                    return token
        
        print(f"❌ Не удалось создать токен: {response.status_code}")
        return None
        
    except Exception as e:
        print(f"❌ Ошибка создания токена: {e}")
        return None

def test_token(token):
    """Проверить токен"""
    print("\n🧪 Тестирование токена...")
    try:
        headers = {'PRIVATE-TOKEN': token}
        response = requests.get(f"{GITLAB_URL}/api/v4/user", headers=headers, timeout=10)
        
        if response.status_code == 200:
            user_data = response.json()
            print(f"✅ Токен работает! Пользователь: {user_data.get('username')}")
            return True
        else:
            print(f"❌ Токен не работает: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Ошибка проверки токена: {e}")
        return False

def main():
    print("=" * 60)
    print("GitLab Token Creator (OAuth Method)")
    print("=" * 60)
    
    session = requests.Session()
    session.headers.update({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    })
    
    # Получаем CSRF токен
    csrf_token = get_csrf_token(session)
    if not csrf_token:
        print("\n❌ Не удалось получить CSRF токен")
        print("💡 Попробуйте создать токен вручную:")
        print("   1. Откройте http://localhost:8929")
        print("   2. Войдите как root / rootpassword123")
        print("   3. Settings -> Access Tokens -> Create token")
        sys.exit(1)
    
    # Выполняем вход
    if not login(session, csrf_token):
        print("\n❌ Не удалось войти в систему")
        sys.exit(1)
    
    # Создаем токен
    token = create_token_via_ui(session)
    if not token:
        print("\n❌ Не удалось создать токен автоматически")
        print("💡 Создайте токен вручную (см. GITLAB_TOKEN_MANUAL.md)")
        sys.exit(1)
    
    # Сохраняем токен
    with open('.env.gitlab', 'w') as f:
        f.write(f"GITLAB_TOKEN={token}\n")
        f.write(f"GITLAB_URL={GITLAB_URL}\n")
    print(f"💾 Токен сохранен в .env.gitlab")
    
    # Проверяем токен
    if test_token(token):
        print("\n✅ Настройка завершена успешно!")
        sys.exit(0)
    else:
        print("\n❌ Токен создан, но не работает")
        sys.exit(1)

if __name__ == "__main__":
    main()
