# Восстановление внешних сервисов CI/CD

## Обзор

Данный документ описывает процесс восстановления последних работоспособных версий внешних сервисов CI/CD системы для 1С:
- PostgreSQL 14 (база данных)
- GitLab CE latest (Git репозиторий и CI/CD)
- Redmine latest (управление задачами)
- SonarQube Community (анализ качества кода)

## Анализ текущего состояния

### Найденные работоспособные версии:
- **PostgreSQL**: `postgres:14` - стабильно работает 8 дней
- **GitLab**: `gitlab/gitlab-ce:latest` - последняя стабильная версия
- **Redmine**: `redmine:latest` - последняя стабильная версия  
- **SonarQube**: `sonarqube:community` - community версия

### Существующие данные:
- ✅ PostgreSQL данные сохранены в volume `postgres_data`
- ✅ GitLab конфигурация в volumes `gitlab_config`, `gitlab_data`, `gitlab_logs`
- ✅ Redmine данные в volumes `redmine_data`, `redmine_logs`, `redmine_plugins`
- ✅ SonarQube данные в volumes `sonarqube_data`, `sonarqube_logs`, `sonarqube_extensions`
- ✅ Сеть `cicd-network` существует

## Быстрое восстановление

### Вариант 1: Автоматический скрипт (рекомендуется)

```powershell
# PowerShell (рекомендуется)
.\restore-external-services.ps1
```

```batch
# Batch файл
restore-external-services.bat
```

### Вариант 2: Ручное восстановление

```bash
# 1. Создание сети (если не существует)
docker network create cicd-network

# 2. Запуск всех сервисов
docker-compose -f docker-compose-external-services.yml up -d

# 3. Проверка статуса
docker-compose -f docker-compose-external-services.yml ps
```

## Проверка работоспособности

### Доступность сервисов:

| Сервис | URL | Учетные данные | Порт |
|--------|-----|----------------|------|
| PostgreSQL | localhost:5433 | postgres / postgres_admin_123 | 5433 |
| GitLab | http://localhost:8929 | root / gitlab_root_password | 8929 |
| Redmine | http://localhost:3000 | admin / admin | 3000 |
| SonarQube | http://localhost:9000 | admin / admin | 9000 |

### Команды проверки:

```bash
# Проверка статуса контейнеров
docker-compose -f docker-compose-external-services.yml ps

# Проверка health checks
docker inspect --format='{{.State.Health.Status}}' postgres_unified
docker inspect --format='{{.State.Health.Status}}' gitlab
docker inspect --format='{{.State.Health.Status}}' redmine
docker inspect --format='{{.State.Health.Status}}' sonarqube

# Проверка логов
docker-compose -f docker-compose-external-services.yml logs -f postgres_unified
docker-compose -f docker-compose-external-services.yml logs -f gitlab
docker-compose -f docker-compose-external-services.yml logs -f redmine
docker-compose -f docker-compose-external-services.yml logs -f sonarqube
```

### Тестирование подключений:

```bash
# PostgreSQL
docker exec postgres_unified psql -U postgres -c "SELECT version();"

# GitLab API
curl -f http://localhost:8929/-/health

# Redmine
curl -f http://localhost:3000

# SonarQube
curl -f http://localhost:9000/api/system/status
```

## Особенности конфигурации

### PostgreSQL
- **Версия**: 14 (стабильная)
- **Порт**: 5433 (чтобы не конфликтовать с локальным PostgreSQL)
- **Базы данных**: postgres, gitlab, redmine, sonarqube, cicd
- **Кодировка**: UTF-8 для поддержки русского языка

### GitLab
- **Внешний URL**: http://gitlab.local:8929
- **SSH порт**: 2224
- **Использует внешний PostgreSQL**
- **Отключены**: встроенный PostgreSQL, Prometheus, Grafana
- **Оптимизация**: уменьшены worker_processes и sidekiq concurrency

### Redmine
- **Использует внешний PostgreSQL**
- **Поддержка плагинов**: включена
- **Миграции**: автоматические

### SonarQube
- **Версия**: Community Edition
- **Использует внешний PostgreSQL**
- **Память**: оптимизирована для стабильной работы
- **Аутентификация**: отключена для упрощения интеграции

## Время запуска

| Сервис | Время запуска | Примечания |
|--------|---------------|------------|
| PostgreSQL | 30-60 секунд | Быстрый запуск |
| Redmine | 2-3 минуты | Зависит от миграций |
| SonarQube | 3-5 минут | Инициализация Elasticsearch |
| GitLab | 5-10 минут | Самый долгий запуск |

## Устранение проблем

### PostgreSQL не запускается
```bash
# Проверка логов
docker logs postgres_unified

# Проверка прав на volume
docker volume inspect postgres_data

# Пересоздание контейнера
docker-compose -f docker-compose-external-services.yml down
docker-compose -f docker-compose-external-services.yml up -d postgres_unified
```

### GitLab долго запускается
```bash
# Проверка процесса инициализации
docker logs -f gitlab

# GitLab может потребовать до 10 минут для полной инициализации
# Проверьте доступность через health check
curl -f http://localhost:8929/-/health
```

### Redmine не подключается к PostgreSQL
```bash
# Проверка подключения к базе
docker exec redmine rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').first"

# Проверка миграций
docker exec redmine rake db:migrate:status
```

### SonarQube не запускается
```bash
# Проверка логов
docker logs sonarqube

# Проверка системных требований
docker exec sonarqube cat /proc/meminfo | grep MemTotal

# SonarQube требует минимум 2GB RAM
```

## Управление сервисами

### Остановка всех сервисов:
```bash
docker-compose -f docker-compose-external-services.yml down
```

### Перезапуск отдельного сервиса:
```bash
docker-compose -f docker-compose-external-services.yml restart [service_name]
```

### Обновление сервиса:
```bash
docker-compose -f docker-compose-external-services.yml pull [service_name]
docker-compose -f docker-compose-external-services.yml up -d [service_name]
```

### Резервное копирование данных:
```bash
# PostgreSQL
docker exec postgres_unified pg_dumpall -U postgres > backup_$(date +%Y%m%d).sql

# Volumes
docker run --rm -v postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_data_$(date +%Y%m%d).tar.gz -C /data .
```

## Интеграция с CI/CD контейнером

После восстановления внешних сервисов можно запускать CI/CD контейнер:

```bash
# Запуск только CI/CD сервиса
docker-compose -f docker-compose-cicd-only.yml up -d

# Или полный стек (если внешние сервисы уже запущены)
docker-compose -f docker-compose-full-stack.yml up -d cicd-service
```

## Мониторинг

### Проверка ресурсов:
```bash
# Использование CPU и памяти
docker stats postgres_unified gitlab redmine sonarqube

# Использование дискового пространства
docker system df
```

### Логирование:
```bash
# Все логи
docker-compose -f docker-compose-external-services.yml logs -f

# Логи конкретного сервиса
docker-compose -f docker-compose-external-services.yml logs -f gitlab
```

## Заключение

Данная конфигурация восстанавливает последние работоспособные версии всех внешних сервисов с сохранением существующих данных. Все сервисы настроены для стабильной работы и интеграции друг с другом через единую сеть `cicd-network` и общую базу данных PostgreSQL.

После успешного восстановления внешних сервисов можно переходить к восстановлению и настройке CI/CD контейнера согласно задачам в спецификации.