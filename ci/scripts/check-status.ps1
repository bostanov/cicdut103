# check-status.ps1 - Быстрая проверка статуса CI/CD инфраструктуры
$ErrorActionPreference = 'Continue'

Write-Host "=== Статус CI/CD инфраструктуры ===" -ForegroundColor Cyan

# Docker контейнеры
Write-Host "`nDocker контейнеры:" -ForegroundColor Yellow
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Проверка доступности сервисов
Write-Host "`nДоступность сервисов:" -ForegroundColor Yellow

# PostgreSQL
$result = docker exec postgres_unified pg_isready -U postgres 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ PostgreSQL: Работает" -ForegroundColor Green
} else {
    Write-Host "  ✗ PostgreSQL: Недоступен" -ForegroundColor Red
}

# SonarQube
try {
    $response = Invoke-WebRequest -Uri "http://localhost:9000/api/system/status" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    $status = ($response.Content | ConvertFrom-Json).status
    Write-Host "  ✓ SonarQube: $status (http://localhost:9000)" -ForegroundColor Green
} catch {
    Write-Host "  ✗ SonarQube: Недоступен" -ForegroundColor Red
}

# Redmine
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3000" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    Write-Host "  ✓ Redmine: Работает (http://localhost:3000)" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Redmine: Недоступен" -ForegroundColor Red
}

# GitLab
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8929" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  ✓ GitLab: Работает (http://localhost:8929)" -ForegroundColor Green
} catch {
    Write-Host "  ⚠ GitLab: Инициализируется или недоступен" -ForegroundColor Yellow
}

# Инструменты
Write-Host "`nУстановленные инструменты:" -ForegroundColor Yellow

if (Test-Path "C:\Tools\sonar-scanner\bin\sonar-scanner.bat") {
    Write-Host "  ✓ SonarScanner: C:\Tools\sonar-scanner" -ForegroundColor Green
} else {
    Write-Host "  ✗ SonarScanner: Не найден" -ForegroundColor Red
}

if (Test-Path "C:\Tools\gitlab-runner\gitlab-runner.exe") {
    Write-Host "  ✓ GitLab Runner: C:\Tools\gitlab-runner" -ForegroundColor Green
} else {
    Write-Host "  ✗ GitLab Runner: Не найден" -ForegroundColor Red
}

$gitVersion = git --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Git: $gitVersion" -ForegroundColor Green
} else {
    Write-Host "  ✗ Git: Не найден" -ForegroundColor Red
}

$dockerVersion = docker --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Docker: $dockerVersion" -ForegroundColor Green
} else {
    Write-Host "  ✗ Docker: Не найден" -ForegroundColor Red
}

$pythonVersion = python --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Python: $pythonVersion" -ForegroundColor Green
} else {
    Write-Host "  ✗ Python: Не найден" -ForegroundColor Red
}

# Git репозиторий
Write-Host "`nGit репозиторий:" -ForegroundColor Yellow
$branch = git branch --show-current 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Текущая ветка: $branch" -ForegroundColor Gray
    $commits = git log --oneline -3 2>&1
    Write-Host "  Последние коммиты:" -ForegroundColor Gray
    $commits | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
} else {
    Write-Host "  Не является Git репозиторием" -ForegroundColor Yellow
}

Write-Host "`n=== Конец проверки ===" -ForegroundColor Cyan
