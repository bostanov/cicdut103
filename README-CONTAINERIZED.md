# Контейнеризованная CI/CD система для 1С

Данный проект представляет собой полностью контейнеризованное решение для автоматизации CI/CD процессов в проекте 1С УТ 10.3, заменяющее проблемные Windows службы на надежную Docker-based архитектуру.

## Архитектура решения

### Объединенный CI/CD контейнер
- **GitSync Service**: Автоматическая синхронизация хранилища 1С с Git репозиторием
- **PreCommit1C Service**: Мониторинг Redmine и обработка внешних файлов (.epf, .erf)
- **Health Check Service**: Мониторинг состояния всех компонентов
- **Git Lock Coordinator**: Координация доступа к Git репозиторию

### Внешние сервисы
- **GitLab**: Git репозиторий и CI/CD пайплайны
- **Redmine**: Управление задачами и вложениями
- **SonarQube**: Анализ качества кода
- **MySQL**: База данных для Redmine
- **PostgreSQL**: База данных для SonarQube

## Быстрый старт

### Предварительные требования
- Docker 20.10+
- Docker Compose 2.0+
- Windows 10/11 или Windows Server 2019/2022
- 8GB RAM (рекомендуется 16GB)
- 50GB свободного места на диске

### Установка

1. **Клонирование репозитория**
   ```bash
   git clone <repository-url>
   cd 1C-CI-CD
   ```

2. **Настройка секретов**
   
   Отредактируйте файлы в директории `secrets/`:
   - `gitsync_password.txt` - пароль пользователя хранилища 1С
   - `gitlab_token.txt` - токен доступа к GitLab
   - `redmine_password.txt` - пароль пользователя Redmine

3. **Настройка путей**
   
   В файле `docker-compose-ci-cd.yml` измените путь к хранилищу 1С:
   ```yaml
   volumes:
     - /path/to/your/1crepository:/1c-storage:ro
   ```

4. **Запуск системы**
   ```bash
   # Windows
   scripts\deploy.bat
   
   # Linux/macOS
   ./scripts/deploy.sh
   ```

### Проверка работоспособности

После запуска проверьте доступность сервисов:

- **Health Check**: http://localhost:8080/health
- **Metrics**: http://localhost:8080/metrics
- **GitLab**: http://localhost:8929 (admin/[см. переменную GITLAB_ROOT_PASSWORD])
- **Redmine**: http://localhost:3000 (admin/admin)
- **SonarQube**: http://localhost:9000 (admin/admin)

## Конфигурация

### Переменные окружения

#### GitSync настройки
- `GITSYNC_STORAGE_PATH`: Путь к хранилищу 1С (по умолчанию: `file:///1c-storage`)
- `GITSYNC_STORAGE_USER`: Пользователь хранилища (по умолчанию: `gitsync`)
- `GITSYNC_SYNC_INTERVAL`: Интервал синхронизации в секундах (по умолчанию: `600`)
- `GITLAB_URL`: URL GitLab репозитория

#### PreCommit1C настройки
- `REDMINE_URL`: URL Redmine сервера (по умолчанию: `http://redmine:3000`)
- `REDMINE_USERNAME`: Пользователь Redmine (по умолчанию: `admin`)
- `CHECK_INTERVAL`: Интервал проверки в секундах (по умолчанию: `300`)

#### Общие настройки
- `LOG_LEVEL`: Уровень логирования (DEBUG, INFO, WARNING, ERROR)
- `WORKSPACE_PATH`: Рабочая директория (по умолчанию: `/workspace`)

### Volumes

- `ci_workspace`: Рабочая директория Git репозитория
- `ci_logs`: Логи всех сервисов
- `ci_temp`: Временные файлы
- `/1c-storage`: Хранилище конфигурации 1С (read-only)

## Мониторинг и логирование

### Health Check
Endpoint: `http://localhost:8080/health`

Возвращает JSON с информацией о состоянии:
- Статус GitSync и PreCommit1C сервисов
- Доступность внешних сервисов
- Системные метрики
- Статус Git блокировки

### Prometheus метрики
Endpoint: `http://localhost:8080/metrics`

Доступные метрики:
- `ci_cd_uptime_seconds`: Время работы контейнера
- `ci_cd_cpu_usage_percent`: Использование CPU
- `ci_cd_memory_usage_percent`: Использование памяти
- `ci_cd_disk_usage_percent`: Использование диска

### Логи

Все логи структурированы в JSON формате и содержат:
- Временную метку
- Уровень логирования
- Имя сервиса и компонента
- Сообщение и детали
- Correlation ID для трассировки

**Просмотр логов:**
```bash
# Все сервисы
docker-compose -f docker-compose-ci-cd.yml logs -f

# Только CI/CD контейнер
docker logs 1c-ci-cd -f

# Конкретный сервис внутри контейнера
docker exec 1c-ci-cd tail -f /logs/gitsync.log
```

## Управление

### Основные команды

```bash
# Запуск всех сервисов
docker-compose -f docker-compose-ci-cd.yml up -d

# Остановка всех сервисов
docker-compose -f docker-compose-ci-cd.yml down

# Перезапуск CI/CD контейнера
docker-compose -f docker-compose-ci-cd.yml restart ci-cd-service

# Просмотр статуса
docker-compose -f docker-compose-ci-cd.yml ps

# Пересборка образа
docker-compose -f docker-compose-ci-cd.yml build --no-cache ci-cd-service
```

### Управление сервисами внутри контейнера

```bash
# Подключение к контейнеру
docker exec -it 1c-ci-cd bash

# Управление через supervisord
supervisorctl status
supervisorctl restart gitsync
supervisorctl restart precommit1c
supervisorctl stop all
```

### Отладка

```bash
# Проверка health check
curl http://localhost:8080/health | jq

# Проверка метрик
curl http://localhost:8080/metrics

# Просмотр логов конкретного сервиса
docker exec 1c-ci-cd tail -f /logs/gitsync-output.log
docker exec 1c-ci-cd tail -f /logs/precommit1c-output.log

# Проверка Git блокировки
docker exec 1c-ci-cd python3 -c "
from app.shared.git_lock import get_git_coordinator
print(get_git_coordinator().get_lock_status())
"
```

## Интеграция с существующими системами

### GitLab
1. Создайте проект в GitLab
2. Получите токен доступа
3. Обновите `secrets/gitlab_token.txt`
4. Настройте URL в переменной `GITLAB_URL`

### Redmine
1. Убедитесь, что Redmine API включен
2. Создайте пользователя с правами на просмотр задач
3. Обновите учетные данные в секретах

### SonarQube
1. Настройте проект для анализа кода 1С
2. Установите плагин BSL (1С:Enterprise)
3. Настройте правила качества кода

## Безопасность

### Управление секретами
- Все пароли и токены хранятся в Docker secrets
- Файлы секретов не должны попадать в Git
- Используйте сильные пароли для всех сервисов

### Сетевая безопасность
- Все контейнеры работают в изолированной сети
- Только необходимые порты открыты наружу
- Внутренняя связь через DNS имена контейнеров

### Права доступа
- CI/CD контейнер работает от непривилегированного пользователя
- Хранилище 1С монтируется в режиме только чтения
- Минимальные необходимые права для каждого компонента

## Устранение неполадок

### Частые проблемы

**1. Контейнер не запускается**
```bash
# Проверка логов
docker logs 1c-ci-cd

# Проверка образа
docker images | grep ci-cd

# Пересборка образа
docker-compose -f docker-compose-ci-cd.yml build --no-cache
```

**2. GitSync не синхронизирует**
```bash
# Проверка доступа к хранилищу 1С
docker exec 1c-ci-cd ls -la /1c-storage

# Проверка логов GitSync
docker exec 1c-ci-cd tail -f /logs/gitsync-output.log

# Ручной запуск синхронизации
docker exec 1c-ci-cd gitsync sync -R -F
```

**3. PreCommit1C не обрабатывает файлы**
```bash
# Проверка доступности Redmine
curl http://localhost:3000

# Проверка логов PreCommit1C
docker exec 1c-ci-cd tail -f /logs/precommit1c-output.log

# Проверка API Redmine
curl -u admin:admin http://localhost:3000/issues.json
```

**4. Health check не проходит**
```bash
# Проверка состояния сервисов
docker exec 1c-ci-cd supervisorctl status

# Ручная проверка health check
curl -v http://localhost:8080/health

# Перезапуск health check сервиса
docker exec 1c-ci-cd supervisorctl restart health-check
```

### Диагностические команды

```bash
# Системная информация
docker exec 1c-ci-cd python3 -c "
import psutil
print(f'CPU: {psutil.cpu_percent()}%')
print(f'Memory: {psutil.virtual_memory().percent}%')
print(f'Disk: {psutil.disk_usage(\"/workspace\").percent}%')
"

# Проверка Git репозитория
docker exec 1c-ci-cd git -C /workspace status

# Проверка OneScript инструментов
docker exec 1c-ci-cd oscript -version
docker exec 1c-ci-cd gitsync --version
docker exec 1c-ci-cd precommit1c --version
```

## Обновление

### Обновление контейнера
```bash
# Остановка сервисов
docker-compose -f docker-compose-ci-cd.yml down

# Пересборка образа
docker-compose -f docker-compose-ci-cd.yml build --no-cache ci-cd-service

# Запуск обновленных сервисов
docker-compose -f docker-compose-ci-cd.yml up -d
```

### Обновление конфигурации
```bash
# Перезагрузка конфигурации без перезапуска
docker-compose -f docker-compose-ci-cd.yml kill -s HUP ci-cd-service

# Или полный перезапуск
docker-compose -f docker-compose-ci-cd.yml restart ci-cd-service
```

## Резервное копирование

### Важные данные для резервного копирования
- Git репозиторий: volume `ci_workspace`
- Логи: volume `ci_logs`
- Конфигурации GitLab: volume `gitlab_data`
- Данные Redmine: volume `redmine_data`
- Данные SonarQube: volume `sonarqube_data`

### Создание резервной копии
```bash
# Создание резервной копии всех volumes
docker run --rm -v ci_workspace:/source -v $(pwd)/backup:/backup alpine tar czf /backup/ci_workspace.tar.gz -C /source .
docker run --rm -v ci_logs:/source -v $(pwd)/backup:/backup alpine tar czf /backup/ci_logs.tar.gz -C /source .
```

### Восстановление из резервной копии
```bash
# Восстановление workspace
docker run --rm -v ci_workspace:/target -v $(pwd)/backup:/backup alpine tar xzf /backup/ci_workspace.tar.gz -C /target
```

## Поддержка

Для получения поддержки:
1. Проверьте логи контейнеров
2. Убедитесь, что все сервисы запущены
3. Проверьте health check endpoint
4. Обратитесь к разделу "Устранение неполадок"

## Лицензия

Данный проект использует следующие компоненты:
- GitSync (MIT License)
- PreCommit1C (MIT License)
- Docker и Docker Compose
- GitLab CE (MIT License)
- Redmine (GPL v2)
- SonarQube Community Edition