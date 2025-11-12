#!/usr/bin/env python3
"""
Создание проектов в GitLab через docker exec
"""
import subprocess
import json

TOKEN = "YOUR_GITLAB_TOKEN_HERE"
API_URL = "http://localhost/api/v4"

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

def create_project(name, description):
    """Создать проект"""
    print(f"Creating project: {name}")
    
    data = {
        "name": name,
        "description": description,
        "visibility": "private",
        "initialize_with_readme": True
    }
    
    response = run_curl("POST", "/projects", data)
    
    try:
        project = json.loads(response)
        if "id" in project:
            print(f"✅ Project created: {project['name']} (ID: {project['id']})")
            print(f"   URL: {project['web_url']}")
            return project
        else:
            print(f"❌ Error: {response}")
            return None
    except json.JSONDecodeError:
        print(f"❌ Invalid response: {response}")
        return None

def main():
    print("=" * 60)
    print("GitLab Projects Creator")
    print("=" * 60)
    
    # Создаем проекты
    projects = [
        ("ut103-ci", "Основной проект 1С:Предприятие"),
        ("ut103-external-files", "Внешние файлы и обработки 1С")
    ]
    
    created = []
    for name, desc in projects:
        project = create_project(name, desc)
        if project:
            created.append(project)
        print()
    
    print("=" * 60)
    print(f"Created {len(created)} projects")
    print("=" * 60)
    
    # Сохраняем информацию о проектах
    with open('.env.gitlab', 'a') as f:
        for project in created:
            f.write(f"\nGITLAB_PROJECT_{project['name'].upper().replace('-', '_')}_ID={project['id']}")
    
    print("Project IDs saved to .env.gitlab")

if __name__ == "__main__":
    main()
