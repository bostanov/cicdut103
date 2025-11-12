#!/usr/bin/env python3
"""
Создание GitLab токена через прямую вставку в БД
"""
import subprocess
import hashlib
import secrets
import string

# Генерация токена
def generate_token():
    alphabet = string.ascii_letters + string.digits
    return 'glpat-' + ''.join(secrets.choice(alphabet) for _ in range(20))

token = generate_token()
print(f"Generated token: {token}")

# Хеширование токена (GitLab использует SHA256)
token_digest = hashlib.sha256(token.encode()).hexdigest()
print(f"Token digest: {token_digest[:20]}...")

# SQL команда для вставки токена
sql = f"""
INSERT INTO personal_access_tokens 
(user_id, name, token_digest, scopes, expires_at, created_at, updated_at, revoked) 
VALUES 
(1, 'CI/CD Integration Token', '{token_digest}', '{{api,read_repository,write_repository}}', NULL, NOW(), NOW(), false)
RETURNING id, name;
"""

print("\nВставка токена в базу данных...")

# Выполнение через docker (используем внешний PostgreSQL)
cmd = ['docker', 'exec', 'postgres_cicd', 'psql', '-U', 'postgres', '-d', 'gitlab', '-c', sql]
result = subprocess.run(cmd, capture_output=True, text=True)

if result.returncode == 0:
    print("[OK] Токен создан в базе данных")
    print(result.stdout)
    
    # Сохранение токена
    import os
    os.makedirs('secrets', exist_ok=True)
    with open('secrets/gitlab_token.txt', 'w') as f:
        f.write(token)
    print(f"\n[OK] Токен сохранен в secrets/gitlab_token.txt")
    print(f"\nToken: {token}")
else:
    print(f"[FAIL] Ошибка: {result.stderr}")
    exit(1)

# Проверка токена
print("\nПроверка токена через API...")
import requests
headers = {'PRIVATE-TOKEN': token}
try:
    response = requests.get('http://localhost:8929/api/v4/version', headers=headers, timeout=10)
    if response.status_code == 200:
        print(f"[OK] Токен работает! GitLab version: {response.json().get('version')}")
    else:
        print(f"[WARN] API вернул статус {response.status_code}")
        print("Токен создан, но может потребоваться перезапуск GitLab")
except Exception as e:
    print(f"[WARN] Не удалось проверить токен: {e}")
    print("Токен создан в БД, попробуйте использовать его через несколько секунд")
