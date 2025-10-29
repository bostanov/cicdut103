# PreCommit1C контейнер для обработки внешних файлов
FROM ubuntu:22.04

# Установка базовых пакетов
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    unzip \
    python3 \
    python3-pip \
    software-properties-common \
    ca-certificates \
    gnupg \
    lsb-release \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Установка OneScript
RUN wget -qO - https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g @onescript/cli

# Установка PreCommit1C и связанных инструментов
RUN oscript -install precommit1c \
    && oscript -install v8unpack \
    && oscript -install v8reader

# Установка рабочей директории
WORKDIR /workspace

# Копирование скриптов
COPY docker/precommit1c/monitor-redmine.py /usr/local/bin/monitor-redmine.py
COPY docker/precommit1c/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /usr/local/bin/monitor-redmine.py

# Создание пользователя для безопасности
RUN useradd -m -s /bin/bash precommit
RUN chown -R precommit:precommit /workspace

USER precommit

# Переменные окружения
ENV REDMINE_URL=""
ENV REDMINE_USERNAME=""
ENV REDMINE_PASSWORD=""
ENV CHECK_INTERVAL="300"
ENV GIT_REPO_URL=""
ENV GIT_USERNAME=""
ENV GIT_PASSWORD=""

# Точка входа
ENTRYPOINT ["/entrypoint.sh"]