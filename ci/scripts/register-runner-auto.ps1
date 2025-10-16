# =============================================================================
# register-runner-auto.ps1
# Автоматическая регистрация GitLab Runner через API
# =============================================================================

param(
    [string]$GitLabUrl = "http://localhost:8929",
    [string]$RootPassword = "Gitlab123Admin!",
    [string]$ProjectName = "ut103",
    [string]$RunnerName = "1C-CI-CD-Runner",
    [string]$RunnerTags = "windows,1c,shell",
    [string]$RunnerExecutor = "shell"
)

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Автоматическая регистрация GitLab Runner                  ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "Параметры:" -ForegroundColor Yellow
Write-Host "  GitLab URL:    $GitLabUrl" -ForegroundColor Gray
Write-Host "  Проект:        $ProjectName" -ForegroundColor Gray
Write-Host "  Runner:        $RunnerName" -ForegroundColor Gray
Write-Host "  Теги:          $RunnerTags" -ForegroundColor Gray
Write-Host "  Executor:      $RunnerExecutor" -ForegroundColor Gray
Write-Host ""

# Проверка доступности GitLab
Write-Host "Проверка доступности GitLab..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$GitLabUrl/-/health" -UseBasicParsing -TimeoutSec 5
    if ($response.StatusCode -eq 200) {
        Write-Host "✓ GitLab доступен" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ GitLab недоступен: $_" -ForegroundColor Red
    Write-Host "Убедитесь, что GitLab запущен: docker ps" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Шаг 1: Получение Personal Access Token" -ForegroundColor Cyan
Write-Host ""

# Получение токена через API (упрощенный метод)
Write-Host "Попытка входа как root..." -ForegroundColor Yellow

try {
    # Создание Personal Access Token через REST API
    # Примечание: для production рекомендуется использовать pre-created token
    
    Write-Host "⚠ Для автоматической регистрации требуется Personal Access Token" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Вариант 1 (Рекомендуемый): Создать token вручную" -ForegroundColor Yellow
    Write-Host "  1. Откройте: $GitLabUrl/-/profile/personal_access_tokens" -ForegroundColor Gray
    Write-Host "  2. Войдите как root / $RootPassword" -ForegroundColor Gray
    Write-Host "  3. Создайте token с правами: api, read_repository, write_repository" -ForegroundColor Gray
    Write-Host "  4. Скопируйте token и запустите:" -ForegroundColor Gray
    Write-Host "     .\ci\scripts\register-runner-auto.ps1 -AccessToken 'ваш_token'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Вариант 2: Использовать registration token проекта" -ForegroundColor Yellow
    Write-Host "  1. Откройте: $GitLabUrl/$ProjectName/-/settings/ci_cd" -ForegroundColor Gray
    Write-Host "  2. Раздел 'Runners' -> 'Specific runners'" -ForegroundColor Gray
    Write-Host "  3. Скопируйте registration token" -ForegroundColor Gray
    Write-Host ""
    
    $token = Read-Host "Введите Personal Access Token или Registration Token"
    
    if ([string]::IsNullOrWhiteSpace($token)) {
        Write-Host "✗ Token не введен" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "✗ Ошибка: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Шаг 2: Проверка существования проекта" -ForegroundColor Cyan
Write-Host ""

try {
    # Попытка получить информацию о проекте
    $headers = @{
        "PRIVATE-TOKEN" = $token
    }
    
    $projects = Invoke-RestMethod -Uri "$GitLabUrl/api/v4/projects?search=$ProjectName" `
        -Headers $headers `
        -Method GET
    
    if ($projects.Count -eq 0) {
        Write-Host "⚠ Проект '$ProjectName' не найден" -ForegroundColor Yellow
        Write-Host "Создайте проект в GitLab: $GitLabUrl/projects/new" -ForegroundColor Yellow
        exit 1
    }
    
    $project = $projects[0]
    Write-Host "✓ Проект найден: $($project.name) (ID: $($project.id))" -ForegroundColor Green
    Write-Host "  URL: $($project.web_url)" -ForegroundColor Gray
    
} catch {
    Write-Host "⚠ Не удалось проверить проект через API: $_" -ForegroundColor Yellow
    Write-Host "Возможно, введен registration token (это нормально)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Шаг 3: Регистрация Runner" -ForegroundColor Cyan
Write-Host ""

# Проверка наличия gitlab-runner
$runnerPath = "C:\Tools\gitlab-runner\gitlab-runner.exe"
if (-not (Test-Path $runnerPath)) {
    Write-Host "✗ GitLab Runner не найден: $runnerPath" -ForegroundColor Red
    Write-Host "Установите GitLab Runner: .\ci\scripts\install-tools.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "Регистрация runner..." -ForegroundColor Yellow

try {
    # Регистрация runner
    & $runnerPath register `
        --non-interactive `
        --url $GitLabUrl `
        --registration-token $token `
        --name $RunnerName `
        --executor $RunnerExecutor `
        --tag-list $RunnerTags `
        --run-untagged="true" `
        --locked="false"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Runner успешно зарегистрирован!" -ForegroundColor Green
    } else {
        Write-Host "✗ Ошибка регистрации runner (код: $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "✗ Ошибка при регистрации: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Шаг 4: Установка и запуск службы" -ForegroundColor Cyan
Write-Host ""

# Проверка прав администратора для установки службы
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-Host "Установка службы GitLab Runner..." -ForegroundColor Yellow
    
    try {
        # Проверка существования службы
        $service = Get-Service -Name "gitlab-runner" -ErrorAction SilentlyContinue
        
        if ($service) {
            Write-Host "  Служба уже установлена, перезапуск..." -ForegroundColor Gray
            & $runnerPath stop
            & $runnerPath start
        } else {
            Write-Host "  Установка новой службы..." -ForegroundColor Gray
            & $runnerPath install
            & $runnerPath start
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Служба GitLab Runner запущена" -ForegroundColor Green
        } else {
            Write-Host "⚠ Ошибка запуска службы (код: $LASTEXITCODE)" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "⚠ Ошибка установки службы: $_" -ForegroundColor Yellow
        Write-Host "Runner зарегистрирован, но служба не установлена" -ForegroundColor Gray
    }
} else {
    Write-Host "⚠ Для установки службы требуются права администратора" -ForegroundColor Yellow
    Write-Host "Запустите от имени администратора:" -ForegroundColor Yellow
    Write-Host "  cd $runnerPath" -ForegroundColor Gray
    Write-Host "  .\gitlab-runner.exe install" -ForegroundColor Gray
    Write-Host "  .\gitlab-runner.exe start" -ForegroundColor Gray
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Проверка статуса Runner" -ForegroundColor Cyan
Write-Host ""

try {
    & $runnerPath verify
    & $runnerPath list
} catch {
    Write-Host "⚠ Не удалось проверить статус" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✓ Регистрация завершена!" -ForegroundColor Green
Write-Host ""
Write-Host "Следующие шаги:" -ForegroundColor Yellow
Write-Host "  1. Проверьте runner в GitLab: $GitLabUrl/admin/runners" -ForegroundColor Gray
Write-Host "  2. Запустите тестовый pipeline в проекте $ProjectName" -ForegroundColor Gray
Write-Host "  3. Проверьте логи runner: docker logs -f gitlab-runner" -ForegroundColor Gray
Write-Host ""

