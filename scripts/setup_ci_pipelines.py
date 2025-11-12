#!/usr/bin/env python3
"""
Настройка CI/CD пайплайнов в GitLab проектах
"""
import subprocess
import json
import base64

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

def create_file(project_id, file_path, content, commit_message):
    """Создать файл в проекте"""
    print(f"Creating file: {file_path}")
    
    data = {
        "branch": "main",
        "content": content,
        "commit_message": commit_message
    }
    
    response = run_curl("POST", f"/projects/{project_id}/repository/files/{file_path.replace('/', '%2F')}", data)
    
    try:
        result = json.loads(response)
        if "file_path" in result:
            print(f"✅ File created: {result['file_path']}")
            return True
        else:
            print(f"❌ Error: {response}")
            return False
    except json.JSONDecodeError:
        print(f"❌ Invalid response: {response}")
        return False

def setup_main_project():
    """Настроить основной проект"""
    print("\n" + "=" * 60)
    print("Setting up ut103-ci project")
    print("=" * 60)
    
    # Читаем шаблон CI/CD
    with open('templates/.gitlab-ci-main.yml', 'r', encoding='utf-8') as f:
        ci_content = f.read()
    
    # Создаем .gitlab-ci.yml
    create_file(1, ".gitlab-ci.yml", ci_content, "Add CI/CD configuration")
    
    # Создаем README
    readme = """# ut103-ci

Основной проект 1С:Предприятие с автоматической CI/CD интеграцией.

## Возможности

- Автоматическая синхронизация с хранилищем 1С
- Анализ качества кода в SonarQube
- Интеграция с Redmine для отслеживания задач
- Автоматические уведомления о изменениях

## CI/CD Pipeline

Pipeline автоматически запускается при каждом коммите и выполняет:

1. **sync** - Синхронизация с хранилищем 1С
2. **analyze** - Анализ качества кода
3. **notify** - Уведомление в Redmine

## Настройка

См. документацию в корне проекта.
"""
    
    create_file(1, "README.md", readme, "Update README")

def setup_external_project():
    """Настроить проект внешних файлов"""
    print("\n" + "=" * 60)
    print("Setting up ut103-external-files project")
    print("=" * 60)
    
    # Читаем шаблон CI/CD
    with open('templates/.gitlab-ci-external.yml', 'r', encoding='utf-8') as f:
        ci_content = f.read()
    
    # Создаем .gitlab-ci.yml
    create_file(2, ".gitlab-ci.yml", ci_content, "Add CI/CD configuration")
    
    # Создаем README
    readme = """# ut103-external-files

Внешние файлы и обработки 1С:Предприятие.

## Структура

- `/external/` - Внешние обработки и отчеты
- `/scripts/` - Скрипты для автоматизации
- `/docs/` - Документация

## CI/CD Pipeline

Pipeline выполняет:

1. **validate** - Проверка синтаксиса файлов
2. **analyze** - Анализ качества кода
3. **notify** - Уведомление в Redmine

## Использование

Добавляйте внешние файлы в соответствующие папки и коммитьте изменения.
"""
    
    create_file(2, "README.md", readme, "Update README")

def main():
    print("=" * 60)
    print("GitLab CI/CD Pipeline Setup")
    print("=" * 60)
    
    setup_main_project()
    setup_external_project()
    
    print("\n" + "=" * 60)
    print("✅ CI/CD pipelines configured successfully!")
    print("=" * 60)
    print("\nNext steps:")
    print("1. Configure CI/CD variables in GitLab")
    print("2. Set up webhooks for Redmine integration")
    print("3. Test the pipelines")

if __name__ == "__main__":
    main()
