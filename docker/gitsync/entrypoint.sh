#!/bin/bash

# GitSync контейнер - точка входа
set -e

echo "Starting GitSync container..."
echo "Storage Path: $GITSYNC_STORAGE_PATH"
echo "Working Directory: $GITSYNC_WORKDIR"
echo "Sync Interval: $GITSYNC_SYNC_INTERVAL seconds"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Инициализация Git репозитория
init_git_repo() {
    log "Initializing Git repository..."
    
    if [ ! -d ".git" ]; then
        git init
        git config user.name "GitSync Service"
        git config user.email "gitsync@ci.local"
        
        if [ -n "$GIT_REPO_URL" ]; then
            git remote add origin "$GIT_REPO_URL"
        fi
    fi
    
    log "Git repository initialized"
}

# Проверка доступности хранилища 1С
check_1c_storage() {
    log "Checking 1C storage accessibility..."
    
    if [ ! -d "/1c-storage" ]; then
        log "ERROR: 1C storage not mounted at /1c-storage"
        exit 1
    fi
    
    log "1C storage is accessible"
}

# Основной цикл синхронизации
sync_loop() {
    log "Starting synchronization loop..."
    
    while true; do
        log "Starting synchronization cycle..."
        
        # Выполнение GitSync
        if gitsync sync -R -F -P -G -l 5; then
            log "Synchronization completed successfully"
        else
            log "ERROR: Synchronization failed with exit code $?"
        fi
        
        log "Waiting $GITSYNC_SYNC_INTERVAL seconds before next sync..."
        sleep "$GITSYNC_SYNC_INTERVAL"
    done
}

# Обработка сигналов для graceful shutdown
cleanup() {
    log "Received shutdown signal, cleaning up..."
    exit 0
}

trap cleanup SIGTERM SIGINT

# Основная логика
main() {
    log "GitSync container starting..."
    
    # Проверки
    check_1c_storage
    
    # Инициализация
    cd "$GITSYNC_WORKDIR"
    init_git_repo
    
    # Запуск цикла синхронизации
    sync_loop
}

# Запуск
main "$@"