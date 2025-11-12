# Создание токена через SQL
$token = -join ((48..57) + (97..102) | Get-Random -Count 20 | ForEach-Object {[char]$_})
$tokenHash = $token # В реальности нужно хешировать

Write-Host "Генерация токена..." -ForegroundColor Cyan

$sql = @"
INSERT INTO personal_access_tokens (user_id, name, scopes, created_at, updated_at, token_digest)
SELECT id, 'API Token', '---
- api
- read_repository
- write_repository
', NOW(), NOW(), '$token'
FROM users WHERE username = 'root'
RETURNING token_digest;
"@

Write-Host "SQL запрос подготовлен" -ForegroundColor Green
Write-Host "Выполнение через docker..." -ForegroundColor Yellow

docker exec postgres_cicd psql -U postgres -d gitlab -c "$sql"
