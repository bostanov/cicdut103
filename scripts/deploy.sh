#!/bin/bash

# Скрипт развертывания контейнеризованной CI/CD системы для 1С

set -e

echo "=== Развертывание 1C CI/CD системы ==="

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Проверка требований
check_requirements() {
    log "Проверка системных требований..."
    
    # Проверка Docker
    if ! command -v docker &> /dev/null; then
        echo "ОШИБКА: Docker не установлен"
        exit 1
    fi
    
    # Проверка Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo "ОШИБКА: Docker Compose не установлен"
        exit 1
    fi
    
    # Проверка прав доступа к Docker
    if ! docker ps &> /dev/null; then
        echo "ОШИБКА: Нет прав доступа к Docker. Запустите от имени администратора или добавьте пользователя в группу docker"
        exit 1
    fi
    
    log "Системные требования выполнены"
}

# Создание необходимых директорий
create_directories() {
    log "Создание необходимых директорий..."
    
    # Создание директории для хранилища 1С (если не существует)
    if [ ! -d "/host/1crepository" ]; then
        log "ВНИМАНИЕ: Директория /host/1crepository не существует"
        log "Создание тестовой директории..."
        sudo mkdir -p /host/1crepository
        sudo chown $(whoami):$(whoami) /host/1crepository
        echo "Тестовое хранилище 1С" > /host/1crepository/test.txt
    fi
    
    # Создание директорий для логов
    mkdir -p logs
    
    log "Директории созданы"
}

# Сборка Docker образов
build_images() {
    log "Сборка Docker образов..."
    
    docker-compose -f docker-compose-ci-cd.yml build --no-cache ci-cd-service
    
    log "Docker образы собраны"
}

# Запуск сервисов
start_services() {
    log "Запуск сервисов..."
    
    # Остановка существующих контейнеров
    docker-compose -f docker-compose-ci-cd.yml down
    
    # Запуск всех сервисов
    docker-compose -f docker-compose-ci-cd.yml up -d
    
    log "Сервисы запущены"
}

# Проверка состояния сервисов
check_services() {
    log "Проверка состояния сервисов..."
    
    # Ожидание запуска сервисов
    sleep 30
    
    # Проверка CI/CD контейнера
    if docker ps | grep -q "1c-ci-cd"; then
        log "✓ CI/CD контейнер запущен"
    else
        log "✗ CI/CD контейнер не запущен"
        return 1
    fi
    
    # Проверка health check
    max_attempts=10
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f http://localhost:8080/health &> /dev/null; then
            log "✓ Health check прошел успешно"
            break
        else
            log "Попытка $attempt/$max_attempts: Health check не прошел, ожидание..."
            sleep 10
            ((attempt++))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log "✗ Health check не прошел после $max_attempts попыток"
        return 1
    fi
    
    # Проверка других сервисов
    services=("gitlab-ci" "redmine-ci" "sonarqube-ci")
    for service in "${services[@]}"; do
        if docker ps | grep -q "$service"; then
            log "✓ $service запущен"
        else
            log "✗ $service не запущен"
        fi
    done
    
    log "Проверка состояния завершена"
}

# Отображение информации о доступе
show_access_info() {
    log "=== Информация о доступе к сервисам ==="
    echo ""
    echo "CI/CD Health Check: http://localhost:8080/health"
    echo "CI/CD Metrics:      http://localhost:8080/metrics"
    echo "GitLab:             http://localhost:8929"
    echo "Redmine:            http://localhost:3000"
    echo "SonarQube:          http://localhost:9000"
    echo ""
    echo "Логи CI/CD контейнера:"
    echo "  docker logs 1c-ci-cd"
    echo ""
    echo "Мониторинг всех контейнеров:"
    echo "  docker-compose -f docker-compose-ci-cd.yml logs -f"
    echo ""
}

# Основная функция
main() {
    log "Начало развертывания..."
    
    check_requirements
    create_directories
    build_images
    start_services
    
    if check_services; then
        log "✓ Развертывание завершено успешно!"
        show_access_info
    else
        log "✗ Развертывание завершено с ошибками"
        log "Проверьте логи контейнеров для диагностики"
        exit 1
    fi
}

# Обработка аргументов командной строки
case "${1:-}" in
    "stop")
        log "Остановка сервисов..."
        docker-compose -f docker-compose-ci-cd.yml down
        log "Сервисы остановлены"
        ;;
    "restart")
        log "Перезапуск сервисов..."
        docker-compose -f docker-compose-ci-cd.yml restart
        log "Сервисы перезапущены"
        ;;
    "logs")
        docker-compose -f docker-compose-ci-cd.yml logs -f
        ;;
    "status")
        docker-compose -f docker-compose-ci-cd.yml ps
        ;;
    *)
        main
        ;;
esac