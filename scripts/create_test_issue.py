#!/usr/bin/env python3
import requests

API_KEY = "3bd281756c90fae4a2b5c8d9e0f1a2b3c4d5e6f7"
BASE_URL = "http://localhost:3000"
HEADERS = {
    "X-Redmine-API-Key": API_KEY,
    "Content-Type": "application/json"
}

issue_data = {
    "issue": {
        "project_id": 1,
        "subject": "Тестовая задача для проверки CI/CD",
        "description": "Это тестовая задача для проверки интеграции GitSync, PreCommit1C и SonarQube",
        "tracker_id": 1,
        "priority_id": 2,
        "status_id": 1
    }
}

response = requests.post(f"{BASE_URL}/issues.json", headers=HEADERS, json=issue_data)
if response.status_code == 201:
    issue = response.json()['issue']
    print(f"[OK] Задача создана: #{issue['id']} - {issue['subject']}")
    print(f"URL: {BASE_URL}/issues/{issue['id']}")
else:
    print(f"[FAIL] Ошибка: {response.status_code}")
    print(response.text)
