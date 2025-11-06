# Объединенная CI/CD система для 1С

## Обзор

Данная конфигурация объединяет все компоненты CI/CD системы в единый docker-compose файл для удобного запуска и управления всей системой одной командой.

## Архитектура системы

```
┌─────────────────────────────────────────────────────────────┐
│                 Объединенная CI/CD система                  │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ PostgreSQL  │  │   GitLab    │  │   Redmine   │         │
│  │ (Database)  │  │ (Git+CI/CD) │  │ (Tasks+Files)│        │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│  ┌─────────────┐  ┌─────────────────────────────────────┐   │
│  │  SonarQube  │  │         CI/CD Service               │   │
│  │(Code Quality)│  │  (GitSync + PreCommit1C)           │   │
│  └─────────────┘  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ 1С Хранилище    │
                    │ (Host FS)       │
                    └─────────────────┘
```

## Включенные сервисы

### 1. PostgreSQL 14
- **Назначение**: Единая база данных для всех сервисов
- **Порт**: 5433
- **Базы данных**: postgres, gitlab, redmine, sonarqube, cicd
- **Учетные данные**: postgres / postgres_admin_123

### 2. GitLab CE
- **Назначение**: Git репозиторий и CI/CD пайплайны
- **Порт**: 8929 (HTTP), 8443 (HTTPS), 2224 (SSH)
- **URL**: http://localhost:8929
- **Учетные данные**: root / gitlab_root_password

### 3. Redmine
- **Назначение**: Управление задачами и внешними файлами
- **Порт**: 3000
- **URL**: http://localhost:3000
- **Учетные данные**: admin / admin

### 4. SonarQube Community
- **Назначение**: Анализ качества кода
- **Порт**: 9000
- **URL**: http://localhost:9000
- **Учетные данные**: admin / admin

### 5. CI/CD Service
- **Назначение**: GitSync + PreCommit1C интеграция
- **Порт**: 8080 (Health Check API)
- **URL**: http://localhost:8080/health
- **Функции**: Синхронизация 1С, обработка внешних файлов

## Быстрый запуск

### Автоматический запуск (рекомендуется)

```powershell
# PowerShell
.\start-unified-system.ps1
```

```batch
# Batch
start-unified-system.bat
```

### Ручной запуск

```bash
# 1. Создание сети
docker network create cicd-network

# 2. Запуск всех сервисов
docker-compose -f docker-compose-unified.yml up -d

# 3. Проверка статуса
docker-compose -f docker-compose-unified.yml ps
```

## Порядок запуска сервисов

Система автоматически соблюдает правильный порядок запуска:

1. **PostgreSQL** (30 секунд) - база данных
2. **GitLab, Redmine, SonarQube** (параллельно, после PostgreSQL)
   - Redmine: 2-3 минуты
   - SonarQube: 5-7 минут  
   - GitLab: 10-15 минут
3. **CI/CD Service** (после готовности всех внешних сервисов)

## Конфигурация

### Переменные окружения CI/CD Service

```yaml
# PostgreSQL подключение
POSTGRES_HOST: postgres_unified
POSTGRES_PORT: 5432
POSTGRES_DB: cicd
POSTGRES_USER: postgres
POSTGRES_PASSWORD: postgres_admin_123

# GitSync настройки
GITSYNC_STORAGE_PATH: file:///1c-storage
GITSYNC_STORAGE_USER: gitsync
GITSYNC_STORAGE_PASSWORD: "123"
GITSYNC_SYNC_INTERVAL: 600  # 10 минут

# Интеграции
GITLAB_URL: http://gitlab
REDMINE_URL: http://redmine:3000
SONARQUBE_URL: http://sonarqube:9000

# Автоинициализация
AUTO_INIT_SERVICES: "true"
WAIT_FOR_SERVICES: "true"
INIT_TIMEOUT: 1800  # 30 минут
```

### Настройка хранилища 1С

По умолчанию система ожидает хранилище 1С по пути `C:\1crepository`. 

Для изменения пути отредактируйте в `docker-compose-unified.yml`:

```yaml
volumes:
  - C:/path/to/your/1c/repository:/1c-storage:ro
```

## Управление системой

### Просмотр статуса

```bash
# Статус всех контейнеров
docker-compose -f docker-compose-unified.yml ps

# Подробная информация
docker-compose -f docker-compose-unified.yml ps --services
```

### Просмотр логов

```bash
# Логи всех сервисов
docker-compose -f docker-compose-unified.yml logs -f

# Логи конкретного сервиса
docker-compose -f docker-compose-unified.yml logs -f postgres
docker-compose -f docker-compose-unified.yml logs -f gitlab
docker-compose -f docker-compose-unified.yml logs -f redmine
docker-compose -f docker-compose-unified.yml logs -f sonarqube
docker-compose -f docker-compose-unified.yml logs -f cicd-service
```

### Перезапуск сервисов

```bash
# Перезапуск всех сервисов
docker-compose -f docker-compose-unified.yml restart

# Перезапуск конкретного сервиса
docker-compose -f docker-compose-unified.yml restart [service_name]
```

### Остановка системы

```bash
# Остановка всех сервисов
docker-compose -f docker-compose-unified.yml down

# Остановка с удалением volumes (ОСТОРОЖНО!)
docker-compose -f docker-compose-unified.yml down -v
```

## Проверка работоспособности

### Health Checks

```bash
# Проверка health checks всех сервисов
docker inspect --format='{{.State.Health.Status}}' postgres_unified
docker inspect --format='{{.State.Health.Status}}' gitlab
docker inspect --format='{{.State.Health.Status}}' redmine
docker inspect --format='{{.State.Health.Status}}' sonarqube
docker inspect --format='{{.State.Health.Status}}' cicd-service
```

### Тестирование подключений

```bash
# PostgreSQL
docker exec postgres_unified psql -U postgres -c "SELECT version();"

# GitLab
curl -f http://localhost:8929/-/health

# Redmine
curl -f http://localhost:3000

# SonarQube
curl -f http://localhost:9000/api/system/status

# CI/CD Service
curl -f http://localhost:8080/health
```

## Мониторинг ресурсов

### Использование ресурсов

```bash
# CPU и память всех контейнеров
docker stats postgres_unified gitlab redmine sonarqube cicd-service

# Использование дискового пространства
docker system df
```

### Рекомендуемые ресурсы

| Компонент | CPU | RAM | Диск |
|-----------|-----|-----|------|
| PostgreSQL | 0.5 cores | 512MB | 2GB |
| GitLab | 2 cores | 2GB | 10GB |
| Redmine | 0.5 cores | 512MB | 1GB |
| SonarQube | 1 core | 1GB | 5GB |
| CI/CD Service | 1 core | 1GB | 2GB |
| **Итого** | **5 cores** | **5GB** | **20GB** |

## Сетевая архитектура

Все сервисы подключены к единой сети `cicd-network`:

```
cicd-network (bridge)
├── postgres_unified:5432
├── gitlab:80,443,22
├── redmine:3000
├── sonarqube:9000
└── cicd-service:8080
```

### Внутренние подключения

- CI/CD Service → PostgreSQL: `postgres_unified:5432`
- CI/CD Service → GitLab: `http://gitlab`
- CI/CD Service → Redmine: `http://redmine:3000`
- CI/CD Service → SonarQube: `http://sonarqube:9000`
- GitLab/Redmine/SonarQube → PostgreSQL: `postgres_unified:5432`

## Volumes и данные

### Постоянные данные

```
postgres_data          # База данных PostgreSQL
gitlab_config          # Конфигурация GitLab
gitlab_logs            # Логи GitLab
gitlab_data            # Данные GitLab
redmine_data           # Файлы Redmine
redmine_logs           # Логи Redmine
redmine_plugins        # Плагины Redmine
sonarqube_data         # Данные SonarQube
sonarqube_logs         # Логи SonarQube
sonarqube_extensions   # Расширения SonarQube
sonarqube_temp         # Временные файлы SonarQube
cicd_workspace         # Рабочая директория CI/CD
cicd_logs              # Логи CI/CD
cicd_temp              # Временные файлы CI/CD
```

### Резервное копирование

```bash
# Создание backup всех volumes
docker run --rm -v postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_backup.tar.gz -C /data .
docker run --rm -v gitlab_data:/data -v $(pwd):/backup alpine tar czf /backup/gitlab_backup.tar.gz -C /data .
docker run --rm -v redmine_data:/data -v $(pwd):/backup alpine tar czf /backup/redmine_backup.tar.gz -C /data .
docker run --rm -v sonarqube_data:/data -v $(pwd):/backup alpine tar czf /backup/sonarqube_backup.tar.gz -C /data .
docker run --rm -v cicd_workspace:/data -v $(pwd):/backup alpine tar czf /backup/cicd_backup.tar.gz -C /data .
```

## Устранение проблем

### Общие проблемы

#### 1. Контейнеры не запускаются
```bash
# Проверка логов
docker-compose -f docker-compose-unified.yml logs

# Проверка ресурсов
docker system df
docker system prune  # Очистка неиспользуемых ресурсов
```

#### 2. GitLab долго инициализируется
```bash
# Проверка процесса инициализации
docker logs -f gitlab

# GitLab может потребовать до 15 минут
# Проверьте доступность через health check
curl -f http://localhost:8929/-/health
```

#### 3. SonarQube не запускается
```bash
# Проверка логов
docker logs sonarqube

# SonarQube требует минимум 2GB RAM
# Проверка системных требований
docker exec sonarqube cat /proc/meminfo | grep MemTotal
```

#### 4. CI/CD Service не подключается к сервисам
```bash
# Проверка сетевого подключения
docker exec cicd-service ping postgres_unified
docker exec cicd-service ping gitlab
docker exec cicd-service ping redmine
docker exec cicd-service ping sonarqube

# Проверка переменных окружения
docker exec cicd-service env | grep -E "(POSTGRES|GITLAB|REDMINE|SONAR)"
```

### Диагностические команды

```bash
# Проверка сети
docker network inspect cicd-network

# Проверка volumes
docker volume ls | grep -E "(postgres|gitlab|redmine|sonar|cicd)"

# Проверка образов
docker images | grep -E "(postgres|gitlab|redmine|sonar|1c-ci-cd)"

# Проверка портов
netstat -an | grep -E "(5433|8929|3000|9000|8080)"
```

## Интеграция и автоматизация

### Автоматическая инициализация

CI/CD Service автоматически:
1. Ожидает готовности всех внешних сервисов
2. Создает проекты в GitLab и SonarQube
3. Настраивает интеграции между сервисами
4. Запускает мониторинг хранилища 1С и Redmine

### Рабочие процессы

1. **GitSync Workflow**:
   - Мониторинг хранилища 1С каждые 10 минут
   - Синхронизация изменений с GitLab
   - Запуск CI/CD пайплайнов
   - Анализ кода в SonarQube
   - Уведомления в Redmine

2. **PreCommit1C Workflow**:
   - Мониторинг Redmine на внешние файлы каждые 5 минут
   - Скачивание и разбор файлов .epf/.erf/.efd
   - Создание веток в GitLab
   - Анализ кода в SonarQube
   - Обновление задач в Redmine

## Заключение

Объединенная система предоставляет:

✅ **Единый запуск** всех компонентов одной командой  
✅ **Автоматическое управление зависимостями** между сервисами  
✅ **Централизованное логирование** и мониторинг  
✅ **Простое управление** через docker-compose команды  
✅ **Полную интеграцию** всех компонентов CI/CD  
✅ **Готовность к production** использованию  

Система готова к работе сразу после запуска и не требует дополнительной настройки интеграций между сервисами.