# CI/CD Installation Guide for 1C:UT 10.3

Полное руководство по развертыванию CI/CD инфраструктуры для 1С:Управление торговлей 10.3

## Содержание

1. [Архитектура решения](#архитектура)
2. [Системные требования](#требования)
3. [Пошаговая установка](#установка)
4. [Проверка работоспособности](#проверка)
5. [Первый запуск pipeline](#первый-запуск)
6. [Troubleshooting](#troubleshooting)

## Архитектура

### Компоненты

- **GitLab CE** (Docker) - Git-сервер и CI/CD оркестратор
  - Порты: 8929 (HTTP), 2224 (SSH)
- **PostgreSQL** (Docker) - База данных для SonarQube и Redmine
  - Порт: 5433 (5432 занят локальной установкой)
- **SonarQube** (Docker) - Анализ качества кода 1С
  - Порт: 9000, с BSL plugin
- **Redmine** (Docker) - Управление задачами
  - Порт: 3000
- **GitLab Runner** (Windows Service) - Исполнитель CI/CD задач
  - Теги: `windows`, `1c`

### Инструменты на Windows

- 1C:Enterprise 8.3.12+
- Git for Windows
- Docker Desktop (WSL2)
- OneScript
- GitSync3
- Python 3.8+ + precommit1c
- SonarScanner CLI

## Требования

### Минимальные системные требования

- **ОС**: Windows 10/11 Pro (64-bit) или Windows Server 2019+
- **CPU**: 4 cores
- **RAM**: 16 GB (рекомендуется 32 GB)
- **Диск**: 100 GB свободного места (SSD рекомендуется)
- **Сеть**: доступ к Internet для загрузки образов и пакетов

### Предустановленное ПО

- 1C:Enterprise 8.3.12.1714 или выше
- Docker Desktop с WSL2
- PowerShell 5.1 или выше

## Установка

### Stage A: Аудит инструментов

Проверьте, какие компоненты уже установлены:

```powershell
cd C:\1C-CI-CD
powershell -ExecutionPolicy Bypass -File ci/scripts/audit-tools.ps1
```

Результат сохраняется в `build/audit/tools.json`.

### Stage 0: Пререквизиты ОС (требуется Administrator)

Создайте пользователя `ci_1c` и настройте права:

```powershell
# Запустите PowerShell от имени Администратора
powershell -ExecutionPolicy Bypass -File ci/scripts/prep-os.ps1
```

Или выполните вручную (см. `docs/CI-CD/MANUAL-STAGE-0.md`).

### Stage 2: PostgreSQL

Разверните PostgreSQL в Docker:

```powershell
powershell -ExecutionPolicy Bypass -File ci/scripts/deploy-postgres.ps1
```

Проверка:
```powershell
docker ps | findstr postgres
# Должен показать контейнер postgres_unified на порту 5433
```

### Stage 3: GitLab CE

Разверните GitLab CE в Docker:

```powershell
powershell -ExecutionPolicy Bypass -File ci/scripts/deploy-gitlab.ps1
```

**Важно**: Первый запуск GitLab занимает 3-5 минут. 

Проверка:
- Откройте http://localhost:8929
- Войдите как `root` с паролем из `build/audit/gitlab-config.json`

### Stage 4: GitLab Runner

Установите и зарегистрируйте Runner:

```powershell
# 1. Установка (если не установлен)
powershell -ExecutionPolicy Bypass -File ci/scripts/install-tools.ps1 -GitLabRunner

# 2. Регистрация
cd C:\Tools\gitlab-runner
.\gitlab-runner.exe register

# При регистрации укажите:
# GitLab URL: http://localhost:8929
# Registration token: (получите в GitLab: Settings > CI/CD > Runners)
# Description: windows-1c-runner
# Tags: windows,1c
# Executor: shell
```

### Stage 5: SonarQube

Разверните SonarQube в Docker:

```powershell
powershell -ExecutionPolicy Bypass -File ci/scripts/deploy-sonarqube.ps1
```

Проверка:
- Откройте http://localhost:9000
- Войдите как `admin` / `admin` (измените пароль при первом входе)
- Создайте проект `ut103` и токен

### Stage 6: Redmine

Разверните Redmine в Docker:

```powershell
# Скрипт создается позже или используйте docker-compose
docker run -d --name redmine -p 3000:3000 \
  -e REDMINE_DB_POSTGRES=host.docker.internal \
  -e REDMINE_DB_PORT=5433 \
  -e REDMINE_DB_DATABASE=redmine \
  -e REDMINE_DB_USERNAME=redmine \
  -e REDMINE_DB_PASSWORD=redmine \
  redmine:5.0-alpine
```

### Stage 8: Инструменты

Установите недостающие инструменты:

```powershell
powershell -ExecutionPolicy Bypass -File ci/scripts/install-tools.ps1
```

### Stage 9: Экспорт из хранилища

Экспортируйте конфигурацию 1С в Git:

```powershell
# Настройте переменную среды с паролем
$env:REPO_PWD = "your-storage-password"

# Выполните экспорт
powershell -ExecutionPolicy Bypass -File ci/scripts/export-from-storage.ps1
```

## Проверка

### Проверка всех компонентов

```powershell
powershell -ExecutionPolicy Bypass -File ci/scripts/check-status.ps1
```

### Ручная проверка

1. **Docker контейнеры**:
   ```powershell
   docker ps
   # Должны быть запущены: postgres_unified, gitlab, sonarqube, redmine
   ```

2. **Сервисы доступны**:
   - GitLab: http://localhost:8929
   - SonarQube: http://localhost:9000
   - Redmine: http://localhost:3000

3. **GitLab Runner**:
   ```powershell
   gitlab-runner verify
   ```

## Первый запуск

### 1. Создайте проект в GitLab

- Войдите в GitLab (http://localhost:8929)
- Создайте группу `1c-projects`
- Создайте проект `ut103`
- Добавьте в Settings > CI/CD > Variables:
  - `REPO_PWD`: пароль от хранилища 1С
  - `SONAR_HOST_URL`: `http://localhost:9000`
  - `SONAR_TOKEN`: токен из SonarQube
  - `REDMINE_URL`: `http://localhost:3000`
  - `REDMINE_API_KEY`: API ключ из Redmine

### 2. Загрузите код в GitLab

```bash
cd C:\1C-CI-CD
git init
git remote add origin http://localhost:8929/1c-projects/ut103.git
git add .
git commit -m "Initial commit: CI/CD infrastructure"
git push -u origin main
```

### 3. Запустите первый pipeline

- Откройте проект в GitLab
- Перейдите в CI/CD > Pipelines
- Нажмите "Run pipeline"
- Pipeline автоматически выполнит все этапы

## Troubleshooting

### Docker контейнер не запускается

```powershell
# Проверьте логи
docker logs <container-name>

# Перезапустите контейнер
docker restart <container-name>
```

### GitLab не отвечает

GitLab требует 2-5 минут для инициализации после запуска.

```powershell
# Проверьте статус
docker logs -f gitlab
```

### SonarQube не запускается

Проверьте, что PostgreSQL доступен:

```powershell
docker exec postgres_unified psql -U sonar -d sonar -c "SELECT 1;"
```

### GitLab Runner не видит задачи

Убедитесь, что:
1. Runner зарегистрирован: `gitlab-runner list`
2. Runner имеет теги `windows` и `1c`
3. В `.gitlab-ci.yml` используются те же теги

### Ошибка прав доступа к хранилищу 1С

Убедитесь, что:
1. Переменная `REPO_PWD` установлена в GitLab CI Variables
2. Пользователь `ci_1c` имеет права на хранилище
3. Путь к хранилищу верный в `ci/config/ci-settings.json`

## Дополнительные ресурсы

- [Изменение пути к хранилищу](CHANGING-REPOSITORY-PATH.md)
- [Ручная настройка Stage 0](MANUAL-STAGE-0.md)
- [GitLab CI/CD документация](https://docs.gitlab.com/ee/ci/)
- [SonarQube BSL plugin](https://github.com/1c-syntax/sonar-bsl-plugin-community)

## Поддержка

При возникновении проблем:
1. Проверьте логи: `docker logs <container-name>`
2. Запустите проверку статуса: `ci/scripts/check-status.ps1`
3. Проверьте документацию компонентов
4. Создайте issue в проекте с подробным описанием проблемы

