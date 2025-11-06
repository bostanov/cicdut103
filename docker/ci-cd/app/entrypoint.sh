#!/bin/bash
set -e

echo "Starting 1C CI/CD Container..."

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Проверка переменных окружения
check_environment() {
    log "Checking environment variables..."
    
    # Обязательные переменные
    required_vars=(
        "GITSYNC_STORAGE_PATH"
        "GITSYNC_STORAGE_USER"
        "WORKSPACE_PATH"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log "ERROR: Required environment variable $var is not set"
            exit 1
        fi
    done
    
    log "Environment variables check passed"
}

# Инициализация Git репозитория
init_git_repo() {
    log "Initializing Git repository..."
    
    cd "$WORKSPACE_PATH"
    
    if [ ! -d ".git" ]; then
        git init
        git config user.name "CI/CD Service"
        git config user.email "cicd@1c.local"
        
        if [ -n "$GITLAB_URL" ]; then
            git remote add origin "$GITLAB_URL"
            log "Added GitLab remote: $GITLAB_URL"
        fi
        
        log "Git repository initialized"
    else
        log "Git repository already exists"
    fi
}

# Проверка доступности хранилища 1С
check_1c_storage() {
    log "Checking 1C storage accessibility..."
    
    if [ ! -d "/1c-storage" ]; then
        log "WARNING: 1C storage not mounted at /1c-storage"
        log "Container will continue but GitSync may not work properly"
    else
        log "1C storage is accessible at /1c-storage"
    fi
}

# Создание необходимых директорий
create_directories() {
    log "Creating necessary directories..."
    
    mkdir -p "$WORKSPACE_PATH/external-files"
    mkdir -p "/logs"
    mkdir -p "/tmp/1c"
    
    log "Directories created successfully"
}

# Обработка сигналов для graceful shutdown
cleanup() {
    log "Received shutdown signal, cleaning up..."
    
    # Остановка supervisord
    if [ -f "/tmp/supervisord.pid" ]; then
        kill -TERM $(cat /tmp/supervisord.pid)
    fi
    
    log "Cleanup completed"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Запуск виртуального дисплея для 1С
start_xvfb() {
    log "Starting virtual display (Xvfb)..."
    
    # Запуск Xvfb в фоне
    Xvfb :99 -screen 0 1024x768x24 -ac +extension GLX +render -noreset &
    export DISPLAY=:99
    
    # Ждем немного для инициализации
    sleep 2
    
    log "Virtual display started on :99"
}

# Основная логика
main() {
    log "1C CI/CD Container starting..."
    
    # Проверки и инициализация
    check_environment
    create_directories
    check_1c_storage
    start_xvfb
    init_git_repo
    
    # Запуск инициализации интеграций если включена
    if [ "${AUTO_INIT_SERVICES:-true}" = "true" ]; then
        log "Starting system integrations initialization..."
        python3 /app/integrations/init_integrations.py
        
        if [ $? -eq 0 ]; then
            log "System integrations initialized successfully"
        else
            log "WARNING: System integrations initialization failed, but continuing..."
        fi
    else
        log "Auto-initialization disabled, skipping integrations setup"
    fi
    
    log "Starting supervisord..."
    
    # Запуск supervisord
    exec /usr/bin/supervisord -c /app/supervisord.conf
}

# Запуск
main "$@"