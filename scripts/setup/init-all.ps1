# Полная инициализация CI/CD системы
# Выполняет все шаги первоначального заполнения
# Автор: Бостанов Ф.А.
# Версия: 1.0

param(
    [switch]$SkipDockerStart,
    [switch]$SkipTokenCheck,
    [switch]$SkipProjects,
    [switch]$SkipSeedData,
    [switch]$SkipRunner
)

$ErrorActionPreference = "Stop"

$ColorHeader = "Cyan"
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError = "Red"
$ColorInfo = "White"

function Write-StepHeader {
    param([string]$Step, [string]$Description)
    Write-Host "`n$('=' * 80)" -ForegroundColor $ColorHeader
    Write-Host "[$Step] $Description" -ForegroundColor $ColorHeader
    Write-Host "$('=' * 80)" -ForegroundColor $ColorHeader
}

function Write-Status {
    param(
        [string]$Message,
        [string]$Status = "info"
    )
    
    $color = switch ($Status) {
        "success" { $ColorSuccess }
        "warning" { $ColorWarning }
        "error" { $ColorError }
        default { $ColorInfo }
    }
    
    $prefix = switch ($Status) {
        "success" { "✅" }
        "warning" { "⚠️ " }
        "error" { "❌" }
        default { "ℹ️ " }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

# Проверка Python
Write-StepHeader "0" "Проверка зависимостей"

try {
    $pythonVersion = python --version 2>&1
    Write-Status "Python установлен: $pythonVersion" "success"
} catch {
    Write-Status "Python не установлен" "error"
    exit 1
}

try {
    $dockerVersion = docker --version
    Write-Status "Docker установлен: $dockerVersion" "success"
} catch {
    Write-Status "Docker не установлен" "error"
    exit 1
}

# Создание директорий
Write-Status "Создание структуры директорий..." "info"
$directories = @("logs", "secrets", "tests", "workspace/external-reports", "docs")
foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Status "  Создана: $dir" "success"
    } else {
        Write-Status "  Существует: $dir" "info"
    }
}

# Шаг 1: Запуск Docker контейнеров
if (-not $SkipDockerStart) {
    Write-StepHeader "1" "Запуск Docker контейнеров"
    
    # Проверка docker-compose файла
    if (-not (Test-Path "docker-compose-full-stack.yml")) {
        Write-Status "docker-compose-full-stack.yml не найден" "error"
        exit 1
    }
    
    # Проверка/создание сети
    $networkExists = docker network ls --filter "name=cicd-network" --format "{{.Name}}"
    if (-not $networkExists) {
        Write-Status "Создание Docker сети cicd-network..." "info"
        docker network create cicd-network
    }
    
    # Запуск контейнеров
    Write-Status "Запуск Docker Compose..." "info"
    docker-compose -f docker-compose-full-stack.yml up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Status "Контейнеры запущены" "success"
    } else {
        Write-Status "Ошибка запуска контейнеров" "error"
        exit 1
    }
    
    # Ожидание инициализации
    Write-Status "Ожидание инициализации сервисов (60 секунд)..." "info"
    Start-Sleep -Seconds 60
    
    # Проверка статуса
    Write-Status "Проверка статуса контейнеров..." "info"
    docker ps --filter "name=gitlab" --filter "name=redmine" --filter "name=sonarqube" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
} else {
    Write-Status "Шаг 1 пропущен (-SkipDockerStart)" "warning"
}

# Шаг 2: Проверка токенов
if (-not $SkipTokenCheck) {
    Write-StepHeader "2" "Проверка токенов доступа"
    
    $tokensOk = $true
    
    # Проверка GitLab token
    if (Test-Path "secrets/gitlab_token.txt") {
        $gitlabToken = Get-Content "secrets/gitlab_token.txt" -Raw
        if ($gitlabToken.Trim().Length -gt 0) {
            Write-Status "GitLab token найден" "success"
            [Environment]::SetEnvironmentVariable("GITLAB_TOKEN", $gitlabToken.Trim())
        } else {
            Write-Status "GitLab token пустой" "warning"
            $tokensOk = $false
        }
    } else {
        Write-Status "GitLab token не найден в secrets/gitlab_token.txt" "warning"
        Write-Status "  Получите token: http://localhost:8929/-/profile/personal_access_tokens" "info"
        $tokensOk = $false
    }
    
    # Проверка Redmine API key
    if (Test-Path "secrets/redmine_api_key.txt") {
        $redmineKey = Get-Content "secrets/redmine_api_key.txt" -Raw
        if ($redmineKey.Trim().Length -gt 0) {
            Write-Status "Redmine API key найден" "success"
            [Environment]::SetEnvironmentVariable("REDMINE_API_KEY", $redmineKey.Trim())
        } else {
            Write-Status "Redmine API key пустой" "warning"
            $tokensOk = $false
        }
    } else {
        Write-Status "Redmine API key не найден в secrets/redmine_api_key.txt" "warning"
        Write-Status "  Получите key: http://localhost:3000/my/account (API access key)" "info"
        $tokensOk = $false
    }
    
    # Проверка SonarQube token
    if (Test-Path "secrets/sonarqube_token.txt") {
        $sonarToken = Get-Content "secrets/sonarqube_token.txt" -Raw
        if ($sonarToken.Trim().Length -gt 0) {
            Write-Status "SonarQube token найден" "success"
            [Environment]::SetEnvironmentVariable("SONARQUBE_TOKEN", $sonarToken.Trim())
        } else {
            Write-Status "SonarQube token пустой (будет использован admin)" "warning"
        }
    } else {
        Write-Status "SonarQube token не найден (будет использован admin)" "warning"
        Write-Status "  Создайте token: http://localhost:9000/account/security" "info"
    }
    
    if (-not $tokensOk) {
        Write-Host "`n" -NoNewline
        Write-Status "Не все токены настроены. Продолжить? (y/n)" "warning"
        $response = Read-Host
        if ($response -ne 'y') {
            Write-Status "Прервано пользователем" "error"
            exit 1
        }
    }
    
} else {
    Write-Status "Шаг 2 пропущен (-SkipTokenCheck)" "warning"
}

# Шаг 3: Загрузка эталонных данных
if (-not $SkipSeedData) {
    Write-StepHeader "3" "Загрузка эталонных данных"
    
    # Установка переменных окружения
    [Environment]::SetEnvironmentVariable("GITLAB_URL", "http://localhost:8929")
    [Environment]::SetEnvironmentVariable("REDMINE_URL", "http://localhost:3000")
    [Environment]::SetEnvironmentVariable("SONARQUBE_URL", "http://localhost:9000")
    [Environment]::SetEnvironmentVariable("PROJECT_NAME", "UT-103 CI/CD")
    [Environment]::SetEnvironmentVariable("PROJECT_IDENTIFIER", "ut103-ci")
    
    Write-Status "Запуск скрипта загрузки данных..." "info"
    python scripts/setup/load-seed-data.py
    
    if ($LASTEXITCODE -eq 0) {
        Write-Status "Эталонные данные загружены" "success"
    } else {
        Write-Status "Ошибка загрузки данных (код: $LASTEXITCODE)" "warning"
    }
    
} else {
    Write-Status "Шаг 3 пропущен (-SkipSeedData)" "warning"
}

# Шаг 4: Создание проектов
if (-not $SkipProjects) {
    Write-StepHeader "4" "Создание проектов в сервисах"
    
    Write-Status "Запуск скрипта инициализации проектов..." "info"
    python scripts/setup/init-projects.py
    
    if ($LASTEXITCODE -eq 0) {
        Write-Status "Проекты созданы" "success"
    } else {
        Write-Status "Ошибка создания проектов (код: $LASTEXITCODE)" "warning"
    }
    
} else {
    Write-Status "Шаг 4 пропущен (-SkipProjects)" "warning"
}

# Шаг 5: Настройка GitLab Runner
if (-not $SkipRunner) {
    Write-StepHeader "5" "Настройка GitLab Runner"
    
    Write-Status "Для настройки GitLab Runner выполните:" "info"
    Write-Host "  1. Получите registration token: http://localhost:8929/admin/runners" -ForegroundColor $ColorInfo
    Write-Host "  2. Запустите: .\scripts\setup\init-runner.ps1 -RunnerToken 'YOUR_TOKEN'" -ForegroundColor $ColorInfo
    
    Write-Host "`nНастроить runner сейчас? (y/n): " -NoNewline -ForegroundColor $ColorWarning
    $response = Read-Host
    
    if ($response -eq 'y') {
        Write-Host "Введите registration token: " -NoNewline -ForegroundColor $ColorInfo
        $runnerToken = Read-Host
        
        if ($runnerToken.Trim().Length -gt 0) {
            & ".\scripts\setup\init-runner.ps1" -RunnerToken $runnerToken
            
            if ($LASTEXITCODE -eq 0) {
                Write-Status "GitLab Runner настроен" "success"
            } else {
                Write-Status "Ошибка настройки runner" "warning"
            }
        } else {
            Write-Status "Token не введен, пропускаем настройку runner" "warning"
        }
    } else {
        Write-Status "Настройка runner пропущена" "warning"
    }
    
} else {
    Write-Status "Шаг 5 пропущен (-SkipRunner)" "warning"
}

# Итоговый отчет
Write-StepHeader "ГОТОВО" "Первоначальное заполнение завершено"

Write-Status "Проверьте статус сервисов:" "info"
Write-Host "  GitLab:    http://localhost:8929" -ForegroundColor $ColorInfo
Write-Host "  Redmine:   http://localhost:3000" -ForegroundColor $ColorInfo
Write-Host "  SonarQube: http://localhost:9000" -ForegroundColor $ColorInfo

Write-Host "`n"
Write-Status "Следующие шаги:" "info"
Write-Host "  1. Запустите автоматизированное тестирование:" -ForegroundColor $ColorInfo
Write-Host "     .\scripts\testing\run-automated-tests.ps1" -ForegroundColor $ColorSuccess
Write-Host "`n  2. Ознакомьтесь с руководством по тестированию:" -ForegroundColor $ColorInfo
Write-Host "     docs\TESTING-GUIDE.md" -ForegroundColor $ColorSuccess
Write-Host "`n  3. Создайте задачу для ручного тестирования в Redmine" -ForegroundColor $ColorInfo

Write-Host "`n$('=' * 80)" -ForegroundColor $ColorHeader
Write-Status "✅ Система готова к работе!" "success"
Write-Host "$('=' * 80)" -ForegroundColor $ColorHeader

