# Скрипт запуска объединенной CI/CD системы
# Запускает все сервисы: PostgreSQL, GitLab, Redmine, SonarQube, CI/CD Service

Write-Host "========================================" -ForegroundColor Green
Write-Host "Запуск объединенной CI/CD системы для 1С" -ForegroundColor Green
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

# Проверка Docker Compose
try {
    $composeVersion = docker-compose --version
    Write-Host "✓ Docker Compose доступен: $composeVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker Compose не найден." -ForegroundColor Red
    exit 1
}

# Проверка наличия файла конфигурации
if (-not (Test-Path "docker-compose-unified.yml")) {
    Write-Host "✗ Файл docker-compose-unified.yml не найден!" -ForegroundColor Red
    exit 1
}

# Проверка наличия хранилища 1С
if (-not (Test-Path "C:\1crepository")) {
    Write-Host "⚠ Внимание: Хранилище 1С не найдено по пути C:\1crepository" -ForegroundColor Yellow
    Write-Host "  Убедитесь, что путь к хранилищу 1С указан правильно в docker-compose-unified.yml" -ForegroundColor Yellow
}

# Остановка существующих контейнеров
Write-Host "`nОстановка существующих контейнеров..." -ForegroundColor Yellow
try {
    docker-compose -f docker-compose-unified.yml down 2>$null
    Write-Host "✓ Существующие контейнеры остановлены" -ForegroundColor Green
} catch {
    Write-Host "- Нет запущенных контейнеров для остановки" -ForegroundColor Gray
}

# Создание сети
Write-Host "`nСоздание сети cicd-network..." -ForegroundColor Yellow
try {
    docker network create cicd-network 2>$null
    Write-Host "✓ Сеть cicd-network создана" -ForegroundColor Green
} catch {
    Write-Host "- Сеть cicd-network уже существует" -ForegroundColor Gray
}

# Сборка CI/CD образа (если нужно)
Write-Host "`nПроверка CI/CD образа..." -ForegroundColor Yellow
$cicdImage = docker images -q "1c-ci-cd-cicd-service:latest"
if (-not $cicdImage) {
    Write-Host "Сборка CI/CD образа..." -ForegroundColor Yellow
    try {
        docker-compose -f docker-compose-unified.yml build cicd-service
        Write-Host "✓ CI/CD образ собран" -ForegroundColor Green
    } catch {
        Write-Host "✗ Ошибка сборки CI/CD образа" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✓ CI/CD образ найден" -ForegroundColor Green
}

# Запуск всех сервисов
Write-Host "`nЗапуск всех сервисов..." -ForegroundColor Yellow
Write-Host "Это может занять несколько минут..." -ForegroundColor Gray

try {
    docker-compose -f docker-compose-unified.yml up -d
    Write-Host "✓ Все сервисы запущены" -ForegroundColor Green
} catch {
    Write-Host "✗ Ошибка запуска сервисов" -ForegroundColor Red
    Write-Host "Проверьте логи: docker-compose -f docker-compose-unified.yml logs" -ForegroundColor Red
    exit 1
}

# Ожидание запуска
Write-Host "`nОжидание инициализации сервисов..." -ForegroundColor Yellow
Write-Host "PostgreSQL: ~30 секунд" -ForegroundColor Gray
Write-Host "Redmine: ~2-3 минуты" -ForegroundColor Gray
Write-Host "SonarQube: ~5-7 минут" -ForegroundColor Gray
Write-Host "GitLab: ~10-15 минут" -ForegroundColor Gray
Write-Host "CI/CD Service: ~2-3 минуты (после готовности других сервисов)" -ForegroundColor Gray

Start-Sleep -Seconds 60

# Проверка статуса контейнеров
Write-Host "`nПроверка статуса контейнеров..." -ForegroundColor Yellow
docker-compose -f docker-compose-unified.yml ps

# Проверка health checks
Write-Host "`nПроверка health checks..." -ForegroundColor Yellow
$services = @("postgres_unified", "gitlab", "redmine", "sonarqube", "cicd-service")
foreach ($service in $services) {
    $health = docker inspect --format='{{.State.Health.Status}}' $service 2>$null
    if ($health) {
        $color = switch ($health) {
            "healthy" { "Green" }
            "starting" { "Yellow" }
            "unhealthy" { "Red" }
            default { "Gray" }
        }
        Write-Host "  $service`: $health" -ForegroundColor $color
    } else {
        $status = docker inspect --format='{{.State.Status}}' $service 2>$null
        if ($status) {
            $color = if ($status -eq "running") { "Green" } else { "Red" }
            Write-Host "  $service`: $status (no health check)" -ForegroundColor $color
        } else {
            Write-Host "  $service`: not found" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Доступность сервисов:" -ForegroundColor Green
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
Write-Host "CI/CD Service: http://localhost:8080/health" -ForegroundColor Cyan
Write-Host "  - Health Check и API endpoint" -ForegroundColor Gray
Write-Host ""

Write-Host "Полезные команды:" -ForegroundColor Yellow
Write-Host "  Просмотр логов всех сервисов: docker-compose -f docker-compose-unified.yml logs -f" -ForegroundColor Gray
Write-Host "  Просмотр логов конкретного сервиса: docker-compose -f docker-compose-unified.yml logs -f [service_name]" -ForegroundColor Gray
Write-Host "  Остановка всех сервисов: docker-compose -f docker-compose-unified.yml down" -ForegroundColor Gray
Write-Host "  Перезапуск сервиса: docker-compose -f docker-compose-unified.yml restart [service_name]" -ForegroundColor Gray
Write-Host "  Проверка статуса: docker-compose -f docker-compose-unified.yml ps" -ForegroundColor Gray
Write-Host ""

Write-Host "✓ Объединенная система запущена!" -ForegroundColor Green
Write-Host ""
Write-Host "Примечания:" -ForegroundColor Yellow
Write-Host "- GitLab может потребовать до 15 минут для полной инициализации" -ForegroundColor Yellow
Write-Host "- SonarQube инициализируется 5-7 минут" -ForegroundColor Yellow
Write-Host "- CI/CD Service начнет работу после готовности всех внешних сервисов" -ForegroundColor Yellow
Write-Host "- Проверьте доступность сервисов через несколько минут" -ForegroundColor Yellow