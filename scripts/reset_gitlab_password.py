#!/usr/bin/env python3
"""
Сброс пароля root в GitLab через SQL
"""
import subprocess
import bcrypt

# Новый пароль
new_password = "Admin123!"
print(f"Новый пароль: {new_password}")

# Хеширование пароля (GitLab использует bcrypt)
password_hash = bcrypt.hashpw(new_password.encode(), bcrypt.gensalt()).decode()
print(f"Hash: {password_hash[:30]}...")

# SQL команда для обновления пароля
sql = f"UPDATE users SET encrypted_password = '{password_hash}' WHERE username='root';"

print("\nОбновление пароля в базе данных...")

# Выполнение через docker
cmd = ['docker', 'exec', 'postgres_cicd', 'psql', '-U', 'postgres', '-d', 'gitlab', '-c', sql]
result = subprocess.run(cmd, capture_output=True, text=True)

if result.returncode == 0:
    print("[OK] Пароль обновлен")
    print(result.stdout)
    print(f"\nТеперь можно войти:")
    print(f"  URL: http://localhost:8929")
    print(f"  Username: root")
    print(f"  Password: {new_password}")
else:
    print(f"[FAIL] Ошибка: {result.stderr}")
