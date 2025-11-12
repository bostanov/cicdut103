#!/usr/bin/env python3
"""
Скрипт для создания Personal Access Token в GitLab
"""
import subprocess
import sys
import time

def run_command(cmd):
    """Выполнить команду и вернуть результат"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=120
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except subprocess.TimeoutExpired:
        return "", "Timeout", 1

def create_token():
    """Создать токен через GitLab Rails"""
    print("🔧 Создание Personal Access Token...")
    
    # Ruby код для создания токена
    ruby_code = """
user = User.find_by(username: 'root')
if user.nil?
  puts 'ERROR: User root not found'
  exit 1
end

# Удаляем старые токены с таким же именем
user.personal_access_tokens.where(name: 'API Token').destroy_all

# Создаем новый токен
token = user.personal_access_tokens.create!(
  name: 'API Token',
  scopes: [:api, :read_repository, :write_repository],
  expires_at: nil
)

puts 'SUCCESS'
puts token.token
"""
    
    # Сохраняем Ruby код во временный файл
    with open('temp_create_token.rb', 'w') as f:
        f.write(ruby_code)
    
    # Копируем файл в контейнер
    print("📋 Копирование скрипта в контейнер...")
    stdout, stderr, code = run_command(
        "docker cp temp_create_token.rb gitlab-cicd:/tmp/create_token.rb"
    )
    
    if code != 0:
        print(f"❌ Ошибка копирования: {stderr}")
        return None
    
    # Выполняем скрипт
    print("⚙️  Выполнение скрипта (это может занять до 2 минут)...")
    stdout, stderr, code = run_command(
        "docker exec gitlab-cicd gitlab-rails runner /tmp/create_token.rb"
    )
    
    # Очищаем временный файл
    run_command("del temp_create_token.rb")
    
    if code != 0:
        print(f"❌ Ошибка выполнения: {stderr}")
        return None
    
    # Парсим результат
    lines = stdout.split('\n')
    if len(lines) >= 2 and lines[0] == 'SUCCESS':
        token = lines[1].strip()
        print(f"✅ Токен создан успешно!")
        print(f"📝 Токен: {token}")
        
        # Сохраняем токен в файл
        with open('.env.gitlab', 'w') as f:
            f.write(f"GITLAB_TOKEN={token}\n")
            f.write(f"GITLAB_URL=http://localhost:8929\n")
        
        print(f"💾 Токен сохранен в файл .env.gitlab")
        return token
    else:
        print(f"❌ Неожиданный ответ: {stdout}")
        return None

def test_token(token):
    """Проверить токен"""
    print("\n🧪 Тестирование токена...")
    
    stdout, stderr, code = run_command(
        f'curl.exe -s -H "PRIVATE-TOKEN: {token}" http://localhost:8929/api/v4/user'
    )
    
    if code == 0 and 'username' in stdout:
        print("✅ Токен работает!")
        return True
    else:
        print(f"❌ Токен не работает: {stderr}")
        return False

if __name__ == "__main__":
    print("=" * 60)
    print("GitLab Personal Access Token Creator")
    print("=" * 60)
    
    token = create_token()
    
    if token:
        time.sleep(2)
        test_token(token)
        print("\n✅ Настройка завершена!")
        sys.exit(0)
    else:
        print("\n❌ Не удалось создать токен")
        sys.exit(1)
