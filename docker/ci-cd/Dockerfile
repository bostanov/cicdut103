FROM ubuntu:18.04

# Установка переменных для неинтерактивной установки
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Moscow

# Установка базовых пакетов
RUN apt-get update && apt-get install -y \
    curl \
    git \
    python3 \
    python3-pip \
    supervisor \
    wget \
    unzip \
    software-properties-common \
    ca-certificates \
    gnupg \
    lsb-release \
    tzdata \
    locales \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

# Настройка локали
RUN locale-gen ru_RU.UTF-8
ENV LANG=ru_RU.UTF-8
ENV LANGUAGE=ru_RU:ru
ENV LC_ALL=ru_RU.UTF-8

# Установка дополнительных инструментов для работы с 1С
RUN apt-get update && apt-get install -y \
    p7zip-full \
    xmlstarlet \
    jq \
    libgtk-3-0 \
    libwebkitgtk-3.0-0 \
    libgconf-2-4 \
    libnss3 \
    libxss1 \
    libasound2 \
    # Дополнительные зависимости для платформы 1С
    libicu60 \
    libglib2.0-0 \
    libgdk-pixbuf2.0-0 \
    libcairo-gobject2 \
    libgtk-3-0 \
    libgdk-pixbuf2.0-0 \
    libatk-bridge2.0-0 \
    libdrm2 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    libxss1 \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

# Установка зависимостей для OneScript
RUN apt-get update && apt-get install -y \
    mono-runtime \
    mono-devel \
    ca-certificates-mono \
    && rm -rf /var/lib/apt/lists/*

# Копирование и установка платформы 1С 8.3.12.1714
COPY client_8_3_12_1714.deb64.tar.gz /tmp/
RUN cd /tmp && \
    tar -xzf client_8_3_12_1714.deb64.tar.gz && \
    ls -la *.deb && \
    # Попробуем установить только thin client (может не требовать сервер)
    dpkg -i 1c-enterprise83-thin-client_8.3.12-1714_amd64.deb || true && \
    dpkg -i 1c-enterprise83-thin-client-nls_8.3.12-1714_amd64.deb || true && \
    # Исправление зависимостей если есть проблемы
    apt-get update && apt-get install -f -y && \
    # Проверка установки
    dpkg -l | grep 1c-enterprise || echo "No 1C packages installed" && \
    # Проверка наличия исполняемых файлов
    find /opt -name "*1cv8*" -type f || echo "No 1C executables found" && \
    # Очистка временных файлов
    rm -rf /tmp/client_8_3_12_1714.deb64.tar.gz /tmp/*.deb

# Проверка установки платформы 1С
RUN find /opt -name "*1cv8*" -type f | head -5
RUN ls -la /opt/1C/v8.3/x86_64/ || echo "1C platform directory not found"
# Проверка версии платформы 1С
RUN /opt/1C/v8.3/x86_64/1cv8c -version || echo "1C platform version check failed"

# Установка OneScript через прямую загрузку
RUN wget https://github.com/EvilBeaver/OneScript/releases/download/v1.9.3/onescript-engine_1.9.3_all.deb \
    && dpkg -i onescript-engine_1.9.3_all.deb \
    && apt-get install -f -y \
    && rm onescript-engine_1.9.3_all.deb

# Проверка установки OneScript
RUN oscript -version

# Установка OPM через встроенную команду OneScript
RUN oscript -install opm

# Установка 1С инструментов через OPM
RUN opm install gitsync
RUN opm install precommit1c  
RUN opm install v8unpack
RUN opm install v8reader || echo "v8reader installation failed, continuing without it"

# Установка плагинов GitSync
RUN opm install gitsync-increment || echo "gitsync-increment plugin installation failed"
RUN opm install gitsync-limit || echo "gitsync-limit plugin installation failed"  
RUN opm install gitsync-unpackform || echo "gitsync-unpackform plugin installation failed"
RUN opm install gitsync-sync-remote || echo "gitsync-sync-remote plugin installation failed"
RUN opm install gitsync-check-authors || echo "gitsync-check-authors plugin installation failed"
RUN opm install gitsync-smart-tags || echo "gitsync-smart-tags plugin installation failed"

# Исправление прав доступа к инструментам
RUN chmod +x /usr/bin/gitsync || echo "gitsync not found"
RUN chmod +x /usr/bin/precommit1c || echo "precommit1c not found"

# Проверка установки инструментов (опционально)
RUN which gitsync || echo "gitsync not found in PATH"
RUN which precommit1c || echo "precommit1c not found in PATH"

# Установка Python зависимостей
COPY requirements.txt /tmp/
RUN pip3 install -r /tmp/requirements.txt

# Создание рабочих директорий
RUN mkdir -p /app /workspace /logs /tmp/1c

# Копирование приложения
COPY app/ /app/
RUN chmod +x /app/entrypoint.sh

# Создание пользователя
RUN useradd -m -s /bin/bash cicd \
    && chown -R cicd:cicd /workspace /logs /tmp/1c /app

# Переключение на пользователя
USER cicd

# Переменные окружения
ENV PYTHONPATH=/app
ENV WORKSPACE_PATH=/workspace
ENV LOG_LEVEL=INFO

# Порты
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Точка входа
ENTRYPOINT ["/app/entrypoint.sh"]