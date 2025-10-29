# GitSync контейнер с 1С платформой
FROM ubuntu:22.04

# Установка базовых пакетов
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    unzip \
    software-properties-common \
    ca-certificates \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Установка OneScript
RUN wget -qO - https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g @onescript/cli

# Установка 1С платформы (демо версия или через volume)
# ВНИМАНИЕ: Требуется лицензия 1С для продакшена
RUN mkdir -p /opt/1cv8/bin

# Установка GitSync через OneScript
RUN oscript -install gitsync

# Установка рабочей директории
WORKDIR /workspace

# Копирование конфигурации GitSync
COPY gitsync.json /workspace/gitsync.json

# Копирование скрипта запуска
COPY docker/gitsync/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Создание пользователя для безопасности
RUN useradd -m -s /bin/bash gitsync
RUN chown -R gitsync:gitsync /workspace

USER gitsync

# Переменные окружения
ENV GITSYNC_STORAGE_PATH=""
ENV GITSYNC_STORAGE_USER=""
ENV GITSYNC_STORAGE_PASSWORD=""
ENV GITSYNC_WORKDIR="/workspace"
ENV GITSYNC_V8_PATH="/opt/1cv8/bin/1cv8"
ENV GITSYNC_SYNC_INTERVAL="600"

# Порты (если нужны)
EXPOSE 8080

# Точка входа
ENTRYPOINT ["/entrypoint.sh"]