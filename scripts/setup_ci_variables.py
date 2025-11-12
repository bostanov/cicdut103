#!/usr/bin/env python3
"""
Настройка CI/CD переменных в GitLab проектах
"""
import subprocess
import json

TOKEN = "YOUR_GITLAB_TOKEN_HERE"
API_URL = "http://localhost/api/v4"
REDMINE_API_KEY = "YOUR_REDMINE_API_KEY_HERE"

def run_curl(method, endpoint, data=None):
    """Выполнить curl команду внутри контейнера"""
    cmd = [
        "docker", "exec", "gitlab-cicd", "curl", "-s",
        "-X", method,
        "-H", f"PRIVATE-TOKEN: {TOKEN}",
        "-H", "Content-Type: application/json"
    ]
    
    if data:
        cmd.extend(["-d", json.dumps(data)])
    
    cmd.append(f"{API_URL}{endpoint}")
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.stdout

def create_variable(project_id, key, value, protected=False, masked=True):
    """Создать CI/CD переменную"""
    print(f"Creating variable: {key}")
    
    data = {
        "key": key,
        "value": value,
        "protected": protected,
        "masked": masked
    }
    
    response = run_curl("POST", f"/projects/{project_id}/variables", data)
    
    try:
        result = json.loads(response)
        if "key" in result:
            print(f"✅ Variable created: {result['key']}")
            return True
        elif "message" in result and "already exists" in result["message"]:
            print(f"⚠️  Variable already exists: {key}")
            return True
        else:
            print(f"❌ Error: {response}")
            return False
    except json.JSONDecodeError:
        print(f"❌ Invalid response: {response}")
        return False

def setup_project_variables(project_id, project_name):
    """Настроить переменные для проекта"""
    print("\n" + "=" * 60)
    print(f"Setting up variables for {project_name}")
    print("=" * 60)
    
    variables = [
        ("REDMINE_URL", "http://redmine-cicd:3000", False, False),
        ("REDMINE_API_KEY", REDMINE_API_KEY, False, True),
        ("REDMINE_PROJECT_ID", "1", False, False),
        ("SONARQUBE_URL", "http://sonarqube:9000", False, False),
        ("CI_SERVICE_URL", "http://cicd-service:8090", False, False),
    ]
    
    for key, value, protected, masked in variables:
        create_variable(project_id, key, value, protected, masked)

def main():
    print("=" * 60)
    print("GitLab CI/CD Variables Setup")
    print("=" * 60)
    
    setup_project_variables(1, "ut103-ci")
    setup_project_variables(2, "ut103-external-files")
    
    print("\n" + "=" * 60)
    print("✅ CI/CD variables configured successfully!")
    print("=" * 60)
    print("\nConfigured variables:")
    print("- REDMINE_URL: http://redmine-cicd:3000")
    print("- REDMINE_API_KEY: *** (masked)")
    print("- REDMINE_PROJECT_ID: 1")
    print("- SONARQUBE_URL: http://sonarqube:9000")
    print("- CI_SERVICE_URL: http://cicd-service:8090")

if __name__ == "__main__":
    main()
