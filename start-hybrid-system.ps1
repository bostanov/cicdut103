# Запуск гибридной CI/CD системы
# GitSync и PreCommit1C на хост-машине Windows
# GitLab, Redmine, SonarQube в Docker

$ErrorActionPreference = "Stop"

Write-Host "=== Запуск гибридной CI/CD системы ===" -ForegroundColor Green

# 1. Проверка Docker
Write-Host "`n1. Проверка Docker..." -ForegroundColor Cyan
try {
    $dockerVersion = docker --version
    Write-Host "✅ $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker не запущен!" -ForegroundColor Red
    exit 1
}

# 2. Проверка PostgreSQL контейнера
Write-Host "`n2. Проверка PostgreSQL контейнера..." -ForegroundColor Cyan
$postgresContainer = docker ps --filter "name=postgres_cicd" --format "{{.Names}}"
if ($postgresContainer) {
    Write-Host "✅ PostgreSQL контейнер работает: $postgresContainer" -ForegroundColor Green
} else {
    Write-Host "❌ PostgreSQL контейнер не найден!" -ForegroundColor Red
    Write-Host "Запустите сначала PostgreSQL контейнер" -ForegroundColor Yellow
    exit 1
}

# 3. Остановка старого контейнера cicd-service
Write-Host "`n3. Остановка старого контейнера cicd-service..." -ForegroundColor Cyan
$oldContainer = docker ps -a --filter "name=cicd-service-final" --format "{{.Names}}"
if ($oldContainer) {
    Write-Host "Остановка и удаление $oldContainer..." -ForegroundColor Yellow
    docker stop cicd-service-final 2>$null
    docker rm cicd-service-final 2>$null
    Write-Host "✅ Старый контейнер удален" -ForegroundColor Green
} else {
    Write-Host "Старый контейнер не найден (это нормально)" -ForegroundColor Gray
}

# 4. Запуск гибридной системы
Write-Host "`n4. Запуск гибридной системы..." -ForegroundColor Cyan
Write-Host "Используется файл: docker-compose-hybrid.yml" -ForegroundColor Gray

try {
    docker-compose -f docker-compose-hybrid.yml up -d
    Write-Host "✅ Контейнеры запущены" -ForegroundColor Green
} catch {
    Write-Host "❌ Ошибка запуска: $_" -ForegroundColor Red
    exit 1
}

# 5. Проверка контейнеров
Write-Host "`n5. Проверка запущенных контейнеров..." -ForegroundColor Cyan
Start-Sleep -Seconds 5
docker ps --filter "network=postgres_network" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 6. Статус GitSync на хосте
Write-Host "`n6. Статус GitSync (хост-машина)..." -ForegroundColor Cyan
$gitsyncTask = Get-ScheduledTask -TaskName "GitSync-1C-Sync" -TaskPath "\CI-CD\" -ErrorAction SilentlyContinue
if ($gitsyncTask) {
    Write-Host "✅ Задача планировщика установлена" -ForegroundColor Green
    Write-Host "  Состояние: $($gitsyncTask.State)" -ForegroundColor Gray
    Write-Host "  Последний запуск: $($gitsyncTask.LastRunTime)" -ForegroundColor Gray
    Write-Host "  Следующий запуск: $($gitsyncTask.NextRunTime)" -ForegroundColor Gray
} else {
    Write-Host "⚠️  Задача планировщика НЕ установлена" -ForegroundColor Yellow
    Write-Host "Запустите: .\gitsync-install-task.ps1" -ForegroundColor Cyan
}

Write-Host "`n=== Система запущена ===" -ForegroundColor Green

Write-Host "`nСервисы доступны по адресам:" -ForegroundColor Yellow
Write-Host "  GitLab:    http://localhost:8929" -ForegroundColor Cyan
Write-Host "  Redmine:   http://localhost:3000" -ForegroundColor Cyan
Write-Host "  SonarQube: http://localhost:9000" -ForegroundColor Cyan
Write-Host "  Coordinator: http://localhost:8085/health" -ForegroundColor Cyan

Write-Host "`nДля просмотра логов GitSync:" -ForegroundColor Yellow
Write-Host "  Get-Content C:\1C-CI-CD\logs\gitsync-$(Get-Date -Format 'yyyyMMdd').log -Tail 50 -Wait" -ForegroundColor Cyan

Write-Host "`nДля ручного запуска GitSync:" -ForegroundColor Yellow
Write-Host "  .\gitsync-run.ps1" -ForegroundColor Cyan

