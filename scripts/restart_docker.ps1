# Скрипт перезапуска Docker Desktop
Write-Host "🔄 Перезапуск Docker Desktop..." -ForegroundColor Cyan

# Останавливаем Docker Desktop
Write-Host "Остановка Docker Desktop..." -ForegroundColor Yellow
Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 5

# Запускаем Docker Desktop
Write-Host "Запуск Docker Desktop..." -ForegroundColor Yellow
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

Write-Host "Ожидание запуска Docker (60 секунд)..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

# Проверяем статус
Write-Host "Проверка статуса..." -ForegroundColor Cyan
docker ps

Write-Host "✅ Docker Desktop перезапущен" -ForegroundColor Green
