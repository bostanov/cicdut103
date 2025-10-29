#!/bin/bash

# PreCommit1C контейнер - точка входа
set -e

echo "Starting PreCommit1C container..."
echo "Redmine URL: $REDMINE_URL"
echo "Check Interval: $CHECK_INTERVAL seconds"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Инициализация Git репозитория
init_git_repo() {
    log "Initializing Git repository..."
    
    if [ ! -d ".git" ]; then
        git init
        git config user.name "PreCommit1C Service"
        git config user.email "precommit1c@ci.local"
        
        if [ -n "$GIT_REPO_URL" ]; then
            git remote add origin "$GIT_REPO_URL"
            
            # Попытка клонирования существующего репозитория
            if git ls-remote origin &>/dev/null; then
                git fetch origin
                git checkout -b master origin/master || git checkout master
            fi
        fi
    fi
    
    log "Git repository initialized"
}

# Проверка доступности Redmine
check_redmine() {
    log "Checking Redmine accessibility..."
    
    if ! curl -s "$REDMINE_URL" > /dev/null; then
        log "WARNING: Redmine is not accessible at $REDMINE_URL"
        return 1
    fi
    
    log "Redmine is accessible"
    return 0
}

# Основной цикл мониторинга
monitor_loop() {
    log "Starting monitoring loop..."
    
    while true; do
        log "Checking for new external files..."
        
        # Запуск Python скрипта мониторинга
        if python3 /usr/local/bin/monitor-redmine.py; then
            log "Monitoring cycle completed successfully"
        else
            log "ERROR: Monitoring cycle failed with exit code $?"
        fi
        
        log "Waiting $CHECK_INTERVAL seconds before next check..."
        sleep "$CHECK_INTERVAL"
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
    log "PreCommit1C container starting..."
    
    # Проверки
    check_redmine || log "WARNING: Continuing without Redmine connectivity"
    
    # Инициализация
    cd "$WORKSPACE" || cd /workspace
    init_git_repo
    
    # Запуск цикла мониторинга
    monitor_loop
}

# Запуск
main "$@"