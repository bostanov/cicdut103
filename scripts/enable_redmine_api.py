#!/usr/bin/env python3
"""
Скрипт для включения API и получения API ключа в Redmine
"""
import sys
import os
import requests
from bs4 import BeautifulSoup
import time

REDMINE_URL = os.getenv('REDMINE_URL', 'http://localhost:3000')
REDMINE_USER = 'admin'
REDMINE_PASS = 'admin'

def enable_api_and_get_key():
    """Включение API и получение ключа"""
    session = requests.Session()
    
    print("[INFO] Подключение к Redmine...")
    
    # 1. Получение страницы логина
    login_page = session.get(f"{REDMINE_URL}/login")
    soup = BeautifulSoup(login_page.text, 'html.parser')
    
    # Получение CSRF токена
    csrf_token = soup.find('input', {'name': 'authenticity_token'})
    if not csrf_token:
        print("[ERROR] CSRF токен не найден")
        return None
    
    csrf_value = csrf_token.get('value')
    print(f"[INFO] CSRF токен получен: {csrf_value[:20]}...")
    
    # 2. Логин
    login_data = {
        'username': REDMINE_USER,
        'password': REDMINE_PASS,
        'authenticity_token': csrf_value,
        'back_url': f"{REDMINE_URL}/"
    }
    
    login_response = session.post(f"{REDMINE_URL}/login", data=login_data)
    
    if 'Invalid user or password' in login_response.text:
        print("[ERROR] Неверный логин или пароль")
        return None
    
    print("[INFO] Успешный вход в систему")
    
    # 3. Получение страницы настроек API
    api_page = session.get(f"{REDMINE_URL}/my/api_key")
    soup = BeautifulSoup(api_page.text, 'html.parser')
    
    # Поиск API ключа
    api_key_input = soup.find('input', {'id': 'api-key'})
    if api_key_input:
        api_key = api_key_input.get('value')
        print(f"[OK] API ключ получен: {api_key}")
        
        # Сохранение в файл
        os.makedirs('secrets', exist_ok=True)
        with open('secrets/redmine_api_key.txt', 'w') as f:
            f.write(api_key)
        print("[OK] API ключ сохранен в secrets/redmine_api_key.txt")
        
        return api_key
    else:
        # API ключ не сгенерирован, нужно сгенерировать
        print("[INFO] API ключ не найден, генерация...")
        
        # Получение CSRF токена со страницы
        csrf_token = soup.find('input', {'name': 'authenticity_token'})
        if csrf_token:
            csrf_value = csrf_token.get('value')
            
            # Генерация API ключа
            generate_response = session.post(
                f"{REDMINE_URL}/my/api_key/reset",
                data={'authenticity_token': csrf_value}
            )
            
            # Повторное получение страницы
            api_page = session.get(f"{REDMINE_URL}/my/api_key")
            soup = BeautifulSoup(api_page.text, 'html.parser')
            api_key_input = soup.find('input', {'id': 'api-key'})
            
            if api_key_input:
                api_key = api_key_input.get('value')
                print(f"[OK] API ключ сгенерирован: {api_key}")
                
                # Сохранение в файл
                os.makedirs('secrets', exist_ok=True)
                with open('secrets/redmine_api_key.txt', 'w') as f:
                    f.write(api_key)
                print("[OK] API ключ сохранен в secrets/redmine_api_key.txt")
                
                return api_key
    
    print("[ERROR] Не удалось получить API ключ")
    return None

if __name__ == '__main__':
    print("="*80)
    print("ПОЛУЧЕНИЕ API КЛЮЧА REDMINE")
    print("="*80)
    
    api_key = enable_api_and_get_key()
    
    if api_key:
        print("\n" + "="*80)
        print("[OK] УСПЕШНО!")
        print("="*80)
        print(f"\nAPI Key: {api_key}")
        print(f"Сохранен в: secrets/redmine_api_key.txt")
        print(f"\nИспользуйте переменную окружения:")
        print(f"  export REDMINE_API_KEY={api_key}")
        sys.exit(0)
    else:
        print("\n" + "="*80)
        print("[FAIL] ОШИБКА!")
        print("="*80)
        sys.exit(1)
