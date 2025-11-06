# Полная проверка гибридной CI/CD системы
# Автор: Бостанов Ф.А.

$ErrorActionPreference = "Continue"

Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "    ПРОВЕРКА ГИБРИДНОЙ CI/CD СИСТЕМЫ" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$allOk = $true

# 1. Компоненты на хост-машине
Write-Host "1. КОМПОНЕНТЫ НА ХОСТ-МАШИНЕ WINDOWS" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────" -ForegroundColor Gray

# OneScript
try {
    $oscriptVersion = & oscript -version 2>&1
    Write-Host "  ✅ OneScript: $oscriptVersion" -ForegroundColor Green
} catch {
    Write-Host "  ❌ OneScript НЕ УСТАНОВЛЕН" -ForegroundColor Red
    $allOk = $false
}

# OPM
try {
    $opmVersion = & opm version 2>&1
    Write-Host "  ✅ OPM: $opmVersion" -ForegroundColor Green
} catch {
    Write-Host "  ❌ OPM НЕ УСТАНОВЛЕН" -ForegroundColor Red
    $allOk = $false
}

# GitSync
try {
    $gitsyncTest = & gitsync --version 2>&1
    if ($LASTEXITCODE -eq 1) {
        Write-Host "  ✅ GitSync: установлен" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  GitSync: возможно не полностью настроен" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ❌ GitSync НЕ УСТАНОВЛЕН" -ForegroundColor Red
    $allOk = $false
}

# PreCommit1C
try {
    $precommitTest = & precommit1c --help 2>&1
    Write-Host "  ✅ PreCommit1C: установлен" -ForegroundColor Green
} catch {
    Write-Host "  ❌ PreCommit1C НЕ УСТАНОВЛЕН" -ForegroundColor Red
    $allOk = $false
}

Write-Host ""

# 2. Платформа 1С
Write-Host "2. ПЛАТФОРМА 1С" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────" -ForegroundColor Gray

$v8Path = "C:\Program Files\1cv8\8.3.12.1714\bin\1cv8c.exe"
if (Test-Path $v8Path) {
    Write-Host "  ✅ Платформа 1С: $v8Path" -ForegroundColor Green
} else {
    Write-Host "  ❌ Платформа 1С НЕ НАЙДЕНА: $v8Path" -ForegroundColor Red
    $allOk = $false
}

Write-Host ""

# 3. Хранилище 1С
Write-Host "3. ХРАНИЛИЩЕ 1С" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────" -ForegroundColor Gray

$storagePath = "C:\1crepository"
if (Test-Path $storagePath) {
    $storageFiles = Get-ChildItem $storagePath -ErrorAction SilentlyContinue
    Write-Host "  ✅ Хранилище: $storagePath" -ForegroundColor Green
    Write-Host "     Файлов: $($storageFiles.Count)" -ForegroundColor Gray
    
    # Проверка файла базы
    $dbFile = Join-Path $storagePath "1cv8ddb.1CD"
    if (Test-Path $dbFile) {
        $dbSize = [math]::Round((Get-Item $dbFile).Length / 1MB, 2)
        Write-Host "     База данных: $dbSize MB" -ForegroundColor Gray
    }
} else {
    Write-Host "  ❌ Хранилище НЕ НАЙДЕНО: $storagePath" -ForegroundColor Red
    $allOk = $false
}

Write-Host ""

# 4. Рабочая директория GitSync
Write-Host "4. РАБОЧАЯ ДИРЕКТОРИЯ GITSYNC" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────" -ForegroundColor Gray

$workDir = "C:\1C-CI-CD\workspace"
if (Test-Path $workDir) {
    Write-Host "  ✅ Рабочая директория: $workDir" -ForegroundColor Green
    
    # Проверка файлов
    $files = @(
        @{Name="gitsync.json"; Required=$true},
        @{Name="AUTHORS"; Required=$true},
        @{Name="VERSION"; Required=$true},
        @{Name=".git"; Required=$true; IsDir=$true}
    )
    
    foreach ($file in $files) {
        $filePath = Join-Path $workDir $file.Name
        if (Test-Path $filePath) {
            Write-Host "     ✅ $($file.Name)" -ForegroundColor Green
        } else {
            Write-Host "     ❌ $($file.Name) НЕ НАЙДЕН" -ForegroundColor Red
            $allOk = $false
        }
    }
} else {
    Write-Host "  ❌ Рабочая директория НЕ НАЙДЕНА" -ForegroundColor Red
    $allOk = $false
}

Write-Host ""

# 5. Git конфигурация
Write-Host "5. GIT КОНФИГУРАЦИЯ" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────" -ForegroundColor Gray

try {
    $gitUser = git config user.name
    $gitEmail = git config user.email
    Write-Host "  ✅ Git User: $gitUser" -ForegroundColor Green
    Write-Host "  ✅ Git Email: $gitEmail" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Git НЕ НАСТРОЕН" -ForegroundColor Red
    $allOk = $false
}

Write-Host ""

# 6. Docker
Write-Host "6. DOCKER КОНТЕЙНЕРЫ" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────" -ForegroundColor Gray

try {
    $dockerVersion = docker --version
    Write-Host "  ✅ Docker: $dockerVersion" -ForegroundColor Green
    
    # Проверка контейнеров
    $containers = @(
        "postgres_cicd",
        "gitlab",
        "redmine",
        "sonarqube",
        "cicd-service-final"
    )
    
    foreach ($containerName in $containers) {
        $container = docker ps --filter "name=$containerName" --format "{{.Names}}" 2>$null
        if ($container) {
            $status = docker ps --filter "name=$containerName" --format "{{.Status}}" 2>$null
            Write-Host "     ✅ $containerName : $status" -ForegroundColor Green
        } else {
            $containerStopped = docker ps -a --filter "name=$containerName" --format "{{.Names}}" 2>$null
            if ($containerStopped) {
                Write-Host "     ⚠️  $containerName : ОСТАНОВЛЕН" -ForegroundColor Yellow
            } else {
                Write-Host "     ❌ $containerName : НЕ НАЙДЕН" -ForegroundColor Red
            }
        }
    }
} catch {
    Write-Host "  ❌ Docker НЕ ЗАПУЩЕН" -ForegroundColor Red
    $allOk = $false
}

Write-Host ""

# 7. Задача планировщика
Write-Host "7. ЗАДАЧА ПЛАНИРОВЩИКА WINDOWS" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────" -ForegroundColor Gray

$task = Get-ScheduledTask -TaskName "GitSync-1C-Sync" -TaskPath "\CI-CD\" -ErrorAction SilentlyContinue
if ($task) {
    Write-Host "  ✅ Задача GitSync: $($task.State)" -ForegroundColor Green
    Write-Host "     Последний запуск: $($task.LastRunTime)" -ForegroundColor Gray
    Write-Host "     Следующий запуск: $($task.NextRunTime)" -ForegroundColor Gray
} else {
    Write-Host "  ⚠️  Задача GitSync НЕ УСТАНОВЛЕНА" -ForegroundColor Yellow
    Write-Host "     Запустите: .\gitsync-install-task.ps1" -ForegroundColor Cyan
}

Write-Host ""

# 8. Доступность сервисов
Write-Host "8. ДОСТУПНОСТЬ СЕРВИСОВ" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────" -ForegroundColor Gray

$services = @(
    @{Name="GitLab"; Url="http://localhost:8929"},
    @{Name="Redmine"; Url="http://localhost:3000"},
    @{Name="SonarQube"; Url="http://localhost:9000"},
    @{Name="Coordinator"; Url="http://localhost:8085/health"}
)

foreach ($service in $services) {
    try {
        $response = Invoke-WebRequest -Uri $service.Url -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        Write-Host "  ✅ $($service.Name): доступен ($($response.StatusCode))" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ $($service.Name): недоступен ($($service.Url))" -ForegroundColor Red
    }
}

Write-Host ""

# 9. Скрипты управления
Write-Host "9. СКРИПТЫ УПРАВЛЕНИЯ" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────" -ForegroundColor Gray

$scripts = @(
    "gitsync-run.ps1",
    "gitsync-test.ps1",
    "gitsync-install-task.ps1",
    "start-hybrid-system.ps1",
    "docker-compose-hybrid.yml"
)

foreach ($script in $scripts) {
    if (Test-Path $script) {
        Write-Host "  ✅ $script" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $script НЕ НАЙДЕН" -ForegroundColor Red
        $allOk = $false
    }
}

Write-Host ""

# ИТОГ
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
if ($allOk) {
    Write-Host "    ✅ ВСЕ КОМПОНЕНТЫ СИСТЕМЫ ГОТОВЫ К РАБОТЕ!" -ForegroundColor Green
} else {
    Write-Host "    ⚠️  ОБНАРУЖЕНЫ ПРОБЛЕМЫ - ТРЕБУЕТСЯ НАСТРОЙКА" -ForegroundColor Yellow
}
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "СЛЕДУЮЩИЕ ШАГИ:" -ForegroundColor Yellow
Write-Host "  1. Тестирование GitSync: .\gitsync-test.ps1" -ForegroundColor Cyan
Write-Host "  2. Установка автозапуска: .\gitsync-install-task.ps1" -ForegroundColor Cyan
Write-Host "  3. Запуск системы: .\start-hybrid-system.ps1" -ForegroundColor Cyan
Write-Host ""

