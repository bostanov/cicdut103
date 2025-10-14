# setup-all.ps1 - Полная автоматическая настройка CI/CD
param(
    [switch]$SkipWait = $false
)

$ErrorActionPreference = 'Continue'

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ПОЛНАЯ АВТОМАТИЧЕСКАЯ НАСТРОЙКА CI/CD" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Добавление инструментов в PATH
Write-Host "`n[Шаг 1] Настройка окружения..." -ForegroundColor Yellow
$env:Path += ";C:\Tools\sonar-scanner\bin;C:\Tools\gitlab-runner"
Write-Host "OK Инструменты добавлены в PATH" -ForegroundColor Green

# Проверка Docker контейнеров
Write-Host "`n[Шаг 2] Проверка Docker контейнеров..." -ForegroundColor Yellow
$containers = docker ps --format "{{.Names}}"
$required = @("postgres_unified", "gitlab", "sonarqube", "redmine")

foreach ($container in $required) {
    if ($containers -contains $container) {
        Write-Host "  ✓ $container" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $container - НЕ ЗАПУЩЕН" -ForegroundColor Red
    }
}

# Ожидание готовности сервисов (если не пропущено)
if (-not $SkipWait) {
    Write-Host "`n[Шаг 3] Ожидание готовности сервисов (может занять 2-3 минуты)..." -ForegroundColor Yellow
    
    # SonarQube
    Write-Host "  Ожидание SonarQube..." -ForegroundColor Gray
    $ready = $false
    for ($i = 1; $i -le 40; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:9000/api/system/status" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            $status = ($response.Content | ConvertFrom-Json).status
            if ($status -eq "UP") {
                Write-Host "  ✓ SonarQube готов" -ForegroundColor Green
                $ready = $true
                break
            }
        } catch {}
        Start-Sleep -Seconds 3
    }
    if (-not $ready) {
        Write-Host "  ⚠ SonarQube не готов, пропускаем..." -ForegroundColor Yellow
    }
    
    # Redmine
    Write-Host "  Ожидание Redmine..." -ForegroundColor Gray
    $ready = $false
    for ($i = 1; $i -le 20; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:3000" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Host "  ✓ Redmine готов" -ForegroundColor Green
                $ready = $true
                break
            }
        } catch {}
        Start-Sleep -Seconds 3
    }
    if (-not $ready) {
        Write-Host "  ⚠ Redmine не готов, пропускаем..." -ForegroundColor Yellow
    }
    
    # GitLab
    Write-Host "  Ожидание GitLab..." -ForegroundColor Gray
    $ready = $false
    for ($i = 1; $i -le 30; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8929" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
            if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 302) {
                Write-Host "  ✓ GitLab готов" -ForegroundColor Green
                $ready = $true
                break
            }
        } catch {}
        Start-Sleep -Seconds 5
    }
    if (-not $ready) {
        Write-Host "  ⚠ GitLab не готов, может потребоваться больше времени" -ForegroundColor Yellow
    }
}

# Запуск скриптов настройки
Write-Host "`n[Шаг 4] Автоматическая настройка сервисов..." -ForegroundColor Yellow

Write-Host "`n--- SonarQube ---" -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File ci/scripts/setup-sonarqube.ps1

Write-Host "`n--- Redmine ---" -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File ci/scripts/setup-redmine.ps1

Write-Host "`n--- GitLab ---" -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File ci/scripts/setup-gitlab.ps1

# Финальный отчет
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  НАСТРОЙКА ЗАВЕРШЕНА" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

Write-Host "`nДоступ к сервисам:" -ForegroundColor Yellow
Write-Host "  GitLab:    http://localhost:8929 (root / Gitlab123Admin!)" -ForegroundColor Gray
Write-Host "  SonarQube: http://localhost:9000 (admin / admin123)" -ForegroundColor Gray
Write-Host "  Redmine:   http://localhost:3000 (admin / admin)" -ForegroundColor Gray

Write-Host "`nИнструменты в PATH:" -ForegroundColor Yellow
Write-Host "  SonarScanner: C:\Tools\sonar-scanner\bin" -ForegroundColor Gray
Write-Host "  GitLab Runner: C:\Tools\gitlab-runner" -ForegroundColor Gray

Write-Host "`nКонфигурационные файлы:" -ForegroundColor Yellow
Write-Host "  build/audit/sonarqube-setup.json" -ForegroundColor Gray
Write-Host "  build/audit/redmine-setup.json" -ForegroundColor Gray
Write-Host "  build/audit/gitlab-setup.json" -ForegroundColor Gray

Write-Host "`nСледующие шаги:" -ForegroundColor Yellow
Write-Host "  1. Откройте GitLab и создайте проект 'ut103'" -ForegroundColor Gray
Write-Host "  2. Зарегистрируйте GitLab Runner (см. gitlab-setup.json)" -ForegroundColor Gray
Write-Host "  3. Отправьте репозиторий: git push origin master" -ForegroundColor Gray
Write-Host "  4. Настройте интеграцию с Redmine API" -ForegroundColor Gray

Write-Host "`nДокументация: docs/CI-CD/DEPLOYMENT-SUMMARY.md" -ForegroundColor Cyan

