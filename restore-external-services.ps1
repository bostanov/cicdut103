# Скрипт восстановления внешних сервисов CI/CD
# Восстанавливает последние работоспособные версии GitLab, Redmine, SonarQube, PostgreSQL

Write-Host "========================================" -ForegroundColor Green
Write-Host "Восстановление внешних сервисов CI/CD" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Проверка Docker
Write-Host "Проверка Docker..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version
    Write-Host "✓ Docker доступен: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker не найден. Установите Docker Desktop." -ForegroundColor Red
    exit 1
}

# Проверка существующих контейнеров
Write-Host "`nПроверка существующих контейнеров..." -ForegroundColor Yellow
docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"

# Остановка существующих контейнеров
Write-Host "`nОстановка существующих контейнеров..." -ForegroundColor Yellow
$containersToStop = @("gitlab", "redmine", "sonarqube")
foreach ($container in $containersToStop) {
    try {
        docker stop $container 2>$null
        docker rm $container 2>$null
        Write-Host "✓ Контейнер $container остановлен и удален" -ForegroundColor Green
    } catch {
        Write-Host "- Контейнер $container не найден" -ForegroundColor Gray
    }
}

# Создание сети
Write-Host "`nСоздание сети cicd-network..." -ForegroundColor Yellow
try {
    docker network create cicd-network 2>$null
    Write-Host "✓ Сеть cicd-network создана" -ForegroundColor Green
} catch {
    Write-Host "- Сеть cicd-network уже существует" -ForegroundColor Gray
}

# Проверка наличия файла docker-compose
if (-not (Test-Path "docker-compose-external-services.yml")) {
    Write-Host "✗ Файл docker-compose-external-services.yml не найден!" -ForegroundColor Red
    exit 1
}

# Запуск сервисов
Write-Host "`nЗапуск внешних сервисов..." -ForegroundColor Yellow
try {
    docker-compose -f docker-compose-external-services.yml up -d
    Write-Host "✓ Сервисы запущены" -ForegroundColor Green
} catch {
    Write-Host "✗ Ошибка запуска сервисов" -ForegroundColor Red
    exit 1
}

# Ожидание запуска
Write-Host "`nОжидание запуска сервисов (60 секунд)..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

# Проверка статуса
Write-Host "`nПроверка статуса сервисов..." -ForegroundColor Yellow
docker-compose -f docker-compose-external-services.yml ps

# Проверка health checks
Write-Host "`nПроверка health checks..." -ForegroundColor Yellow
$services = @("postgres_unified", "gitlab", "redmine", "sonarqube")
foreach ($service in $services) {
    $health = docker inspect --format='{{.State.Health.Status}}' $service 2>$null
    if ($health) {
        $color = if ($health -eq "healthy") { "Green" } else { "Yellow" }
        Write-Host "  $service`: $health" -ForegroundColor $color
    } else {
        Write-Host "  $service`: no health check" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Проверка доступности сервисов:" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "PostgreSQL: localhost:5433" -ForegroundColor Cyan
Write-Host "  - Пользователь: postgres" -ForegroundColor Gray
Write-Host "  - Пароль: postgres_admin_123" -ForegroundColor Gray
Write-Host ""
Write-Host "GitLab: http://localhost:8929" -ForegroundColor Cyan
Write-Host "  - Пользователь: root" -ForegroundColor Gray
Write-Host "  - Пароль: gitlab_root_password" -ForegroundColor Gray
Write-Host ""
Write-Host "Redmine: http://localhost:3000" -ForegroundColor Cyan
Write-Host "  - Пользователь: admin" -ForegroundColor Gray
Write-Host "  - Пароль: admin" -ForegroundColor Gray
Write-Host ""
Write-Host "SonarQube: http://localhost:9000" -ForegroundColor Cyan
Write-Host "  - Пользователь: admin" -ForegroundColor Gray
Write-Host "  - Пароль: admin" -ForegroundColor Gray
Write-Host ""

Write-Host "Полезные команды:" -ForegroundColor Yellow
Write-Host "  Просмотр логов: docker-compose -f docker-compose-external-services.yml logs -f [service_name]" -ForegroundColor Gray
Write-Host "  Остановка: docker-compose -f docker-compose-external-services.yml down" -ForegroundColor Gray
Write-Host "  Перезапуск: docker-compose -f docker-compose-external-services.yml restart [service_name]" -ForegroundColor Gray
Write-Host ""

Write-Host "✓ Восстановление завершено!" -ForegroundColor Green
Write-Host ""
Write-Host "Примечание: GitLab может потребовать до 10 минут для полной инициализации." -ForegroundColor Yellow
Write-Host "Проверьте доступность сервисов через несколько минут." -ForegroundColor Yellow