# Dockerfile для CI/CD координатора (без GitSync)
# Только интеграции: GitLab, Redmine, SonarQube

FROM python:3.11-slim

LABEL maintainer="CI/CD Team"
LABEL description="CI/CD Coordinator - Integration service (без GitSync)"

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Создание рабочих директорий
RUN mkdir -p /app /workspace /logs

# Копирование файлов приложения
COPY app/ /app/

# Установка Python зависимостей
WORKDIR /app
RUN pip install --no-cache-dir \
    requests \
    python-gitlab \
    psycopg2-binary \
    flask

# Создание пользователя
RUN useradd -m -u 1000 cicd && \
    chown -R cicd:cicd /app /workspace /logs

USER cicd

# Переменные окружения
ENV PYTHONUNBUFFERED=1
ENV LOG_LEVEL=INFO

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8085/health || exit 1

# Точка входа
ENTRYPOINT ["python", "/app/coordinator.py"]

