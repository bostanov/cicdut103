#!/usr/bin/env python3
"""
Обновление переменных SonarQube в GitLab проектах
"""
import requests
import sys

GITLAB_URL = "http://localhost:8929"
GITLAB_TOKEN = "YOUR_GITLAB_TOKEN_HERE"
SONARQUBE_URL = "http://sonarqube:9000"
SONARQUBE_TOKEN = "YOUR_SONARQUBE_TOKEN_HERE"

def update_project_variables(project_id, project_key):
    """Обновление переменных для проекта"""
    print(f"\nОбновление переменных для проекта ID {project_id}...")
    
    headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}
    
    variables = [
        {
            "key": "SONARQUBE_URL",
            "value": SONARQUBE_URL,
            "protected": False,
            "masked": False
        },
        {
            "key": "SONARQUBE_TOKEN",
            "value": SONARQUBE_TOKEN,
            "protected": True,
            "masked": True
        },
        {
            "key": "SONARQUBE_PROJECT_KEY",
            "value": project_key,
            "protected": False,
            "masked": False
        }
    ]
    
    for var in variables:
        # Попробуем обновить существующую переменную
        response = requests.put(
            f"{GITLAB_URL}/api/v4/projects/{project_id}/variables/{var['key']}",
            headers=headers,
            json=var
        )
        
        if response.status_code == 200:
            print(f"  ✅ Обновлена: {var['key']}")
        elif response.status_code == 404:
            # Переменная не существует, создадим
            response = requests.post(
                f"{GITLAB_URL}/api/v4/projects/{project_id}/variables",
                headers=headers,
                json=var
            )
            if response.status_code == 201:
                print(f"  ✅ Создана: {var['key']}")
            else:
                print(f"  ❌ Ошибка создания {var['key']}: {response.status_code}")
        else:
            print(f"  ❌ Ошибка обновления {var['key']}: {response.status_code}")

def main():
    print("="*60)
    print("ОБНОВЛЕНИЕ ПЕРЕМЕННЫХ SONARQUBE В GITLAB")
    print("="*60)
    
    projects = [
        (1, "ut103-ci"),
        (2, "ut103-external-files")
    ]
    
    for project_id, project_key in projects:
        update_project_variables(project_id, project_key)
    
    print("\n" + "="*60)
    print("✅ ОБНОВЛЕНИЕ ЗАВЕРШЕНО")
    print("="*60)

if __name__ == "__main__":
    main()
