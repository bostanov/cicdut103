# Скрипт настройки GitLab Runner для проекта
# Автор: Бостанов Ф.А.
# Версия: 1.0

param(
    [string]$GitLabUrl = "http://localhost:8929",
    [string]$RunnerToken = "",
    [string]$RunnerName = "1c-cicd-runner",
    [string[]]$RunnerTags = @("1c-tests", "sonar", "deploy")
)

$ErrorActionPreference = "Stop"

Write-Host "=" -ForegroundColor Cyan -NoNewline
Write-Host (" Настройка GitLab Runner " * 3) -ForegroundColor Cyan
Write-Host "=" -ForegroundColor Cyan

# Проверка наличия Docker
Write-Host "`n[1/5] Проверка Docker..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version
    Write-Host "✅ Docker установлен: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker не установлен или не запущен" -ForegroundColor Red
    exit 1
}

# Проверка доступности GitLab
Write-Host "`n[2/5] Проверка доступности GitLab..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$GitLabUrl/-/health" -Method GET -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ GitLab доступен: $GitLabUrl" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ GitLab недоступен: $GitLabUrl" -ForegroundColor Red
    Write-Host "   Убедитесь что GitLab запущен: docker ps | grep gitlab" -ForegroundColor Yellow
    exit 1
}

# Получение runner token из GitLab UI
if (-not $RunnerToken) {
    Write-Host "`n[3/5] Получение runner token..." -ForegroundColor Yellow
    Write-Host "⚠️  Runner token не указан" -ForegroundColor Yellow
    Write-Host "`nПолучите token из GitLab UI:" -ForegroundColor Cyan
    Write-Host "  1. Откройте: $GitLabUrl/admin/runners" -ForegroundColor White
    Write-Host "  2. Нажмите: New instance runner" -ForegroundColor White
    Write-Host "  3. Выберите теги: $($RunnerTags -join ', ')" -ForegroundColor White
    Write-Host "  4. Скопируйте token и запустите снова:" -ForegroundColor White
    Write-Host "     .\init-runner.ps1 -RunnerToken 'YOUR_TOKEN_HERE'" -ForegroundColor Green
    exit 0
}

Write-Host "✅ Runner token получен" -ForegroundColor Green

# Проверка существующих runners
Write-Host "`n[4/5] Проверка существующих runners..." -ForegroundColor Yellow
$existingRunners = docker ps -a --filter "name=gitlab-runner" --format "{{.Names}}"
if ($existingRunners) {
    Write-Host "⚠️  Найдены существующие runners:" -ForegroundColor Yellow
    $existingRunners | ForEach-Object { Write-Host "   - $_" -ForegroundColor White }
    
    $response = Read-Host "`nУдалить существующие runners? (y/n)"
    if ($response -eq 'y') {
        docker rm -f $existingRunners
        Write-Host "✅ Существующие runners удалены" -ForegroundColor Green
    }
}

# Запуск GitLab Runner
Write-Host "`n[5/5] Запуск GitLab Runner..." -ForegroundColor Yellow

$runnerConfig = @{
    Name = $RunnerName
    Network = "cicd-network"
    Image = "gitlab/gitlab-runner:latest"
    Volume = "gitlab-runner-config:/etc/gitlab-runner"
    GitLabUrl = $GitLabUrl
    Token = $RunnerToken
    Tags = $RunnerTags -join ','
    Executor = "docker"
    DefaultImage = "ubuntu:18.04"
}

# Создание контейнера runner
Write-Host "Создание контейнера $($runnerConfig.Name)..." -ForegroundColor Cyan
docker run -d `
    --name $runnerConfig.Name `
    --network $runnerConfig.Network `
    --restart unless-stopped `
    -v /var/run/docker.sock:/var/run/docker.sock `
    -v $runnerConfig.Volume `
    $runnerConfig.Image

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Контейнер создан" -ForegroundColor Green
} else {
    Write-Host "❌ Ошибка создания контейнера" -ForegroundColor Red
    exit 1
}

# Регистрация runner
Write-Host "`nРегистрация runner в GitLab..." -ForegroundColor Cyan
Start-Sleep -Seconds 5  # Ждем запуска контейнера

docker exec $runnerConfig.Name gitlab-runner register `
    --non-interactive `
    --url $runnerConfig.GitLabUrl `
    --registration-token $runnerConfig.Token `
    --executor $runnerConfig.Executor `
    --docker-image $runnerConfig.DefaultImage `
    --description "$($runnerConfig.Name)" `
    --tag-list "$($runnerConfig.Tags)" `
    --run-untagged="false" `
    --locked="false" `
    --docker-network-mode="cicd-network" `
    --docker-volumes="/var/run/docker.sock:/var/run/docker.sock" `
    --docker-privileged="false"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Runner зарегистрирован" -ForegroundColor Green
} else {
    Write-Host "❌ Ошибка регистрации runner" -ForegroundColor Red
    Write-Host "Проверьте логи: docker logs $($runnerConfig.Name)" -ForegroundColor Yellow
    exit 1
}

# Проверка статуса
Write-Host "`nПроверка статуса runner..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

docker exec $runnerConfig.Name gitlab-runner verify

Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
Write-Host "✅ GitLab Runner настроен и запущен" -ForegroundColor Green
Write-Host ("=" * 80) -ForegroundColor Cyan

Write-Host "`nИнформация о runner:" -ForegroundColor Yellow
Write-Host "  Имя:        $($runnerConfig.Name)" -ForegroundColor White
Write-Host "  URL:        $($runnerConfig.GitLabUrl)" -ForegroundColor White
Write-Host "  Теги:       $($runnerConfig.Tags)" -ForegroundColor White
Write-Host "  Executor:   $($runnerConfig.Executor)" -ForegroundColor White
Write-Host "  Network:    $($runnerConfig.Network)" -ForegroundColor White

Write-Host "`nПолезные команды:" -ForegroundColor Yellow
Write-Host "  Статус:     docker exec $($runnerConfig.Name) gitlab-runner status" -ForegroundColor White
Write-Host "  Логи:       docker logs -f $($runnerConfig.Name)" -ForegroundColor White
Write-Host "  Перезапуск: docker restart $($runnerConfig.Name)" -ForegroundColor White
Write-Host "  Остановка:  docker stop $($runnerConfig.Name)" -ForegroundColor White

Write-Host "`n✅ Готово! Проверьте runner в GitLab UI: $GitLabUrl/admin/runners" -ForegroundColor Green

