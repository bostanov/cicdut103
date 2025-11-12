#!/usr/bin/env python3
"""
Быстрая инициализация Redmine через прямые API вызовы
"""
import requests
import json

API_KEY = "3bd281756c90fae4a2b5c8d9e0f1a2b3c4d5e6f7"
BASE_URL = "http://localhost:3000"
HEADERS = {
    "X-Redmine-API-Key": API_KEY,
    "Content-Type": "application/json"
}

print("="*80)
print("БЫСТРАЯ ИНИЦИАЛИЗАЦИЯ REDMINE")
print("="*80)

# 1. Создание проекта
print("\n1. Создание проекта ut103-ci...")
project_data = {
    "project": {
        "name": "UT-103 CI/CD",
        "identifier": "ut103-ci",
        "description": "Проект автоматизации CI/CD для конфигурации 1С UT-103",
        "is_public": False
    }
}

response = requests.post(f"{BASE_URL}/projects.json", headers=HEADERS, json=project_data)
if response.status_code == 201:
    print("   [OK] Проект создан")
elif response.status_code == 422:
    print("   [OK] Проект уже существует")
else:
    print(f"   [FAIL] Ошибка: {response.status_code} - {response.text}")

# 2. Проверка результата
print("\n2. Проверка проекта...")
response = requests.get(f"{BASE_URL}/projects/ut103-ci.json", headers=HEADERS)
if response.status_code == 200:
    project = response.json()['project']
    print(f"   [OK] Проект найден: ID={project['id']}, Name={project['name']}")
else:
    print(f"   [FAIL] Проект не найден: {response.status_code}")

print("\n" + "="*80)
print("[OK] ИНИЦИАЛИЗАЦИЯ ЗАВЕРШЕНА")
print("="*80)
print(f"\nRedmine URL: {BASE_URL}")
print(f"Проект: ut103-ci")
print(f"API Key: {API_KEY[:20]}...")
