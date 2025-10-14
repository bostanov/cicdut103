# Project Summary: 1C CI/CD Infrastructure

## Что реализовано

Полная инфраструктура CI/CD для 1С:Управление торговлей 10.3 на Windows с использованием Docker и GitLab.

## Архитектура

### Docker Контейнеры

| Контейнер | Порт | Описание |
|-----------|------|----------|
| postgres_unified | 5433 | PostgreSQL 14 для SonarQube и Redmine |
| gitlab | 8929, 2224 | GitLab CE - Git-сервер и CI/CD |
| sonarqube | 9000 | SonarQube с BSL plugin для анализа кода |
| redmine | 3000 | Redmine для управления задачами |

**Примечание:** Порт 5433 используется для PostgreSQL, т.к. 5432 занят локальной установкой.

### Инструменты Windows

- **1C:Enterprise** 8.3.12.1714 - платформа 1С
- **Git** 2.43.0 - система контроля версий
- **Docker** 28.5.1 - контейнеризация
- **GitLab Runner** - исполнитель CI/CD (теги: windows, 1c)
- **OneScript** - автоматизация задач 1С
- **GitSync3** - синхронизация хранилища 1С с Git
- **precommit1c** - проверка синтаксиса BSL
- **SonarScanner** - клиент для SonarQube

## Структура проекта

```
C:\1C-CI-CD\
├── config-src/          # Исходники конфигурации 1С (XML)
├── externals/           # Внешние обработки/отчеты (epf/erf)
├── externals-src/       # Исходники внешних обработок (XML)
├── ci/
│   ├── config/
│   │   ├── ci-settings.json      # Конфигурация путей и параметров
│   │   └── precommit1c.json      # Настройки precommit1c
│   └── scripts/
│       ├── audit-tools.ps1       # Аудит установленных инструментов
│       ├── check-status.ps1      # Проверка статуса инфраструктуры
│       ├── prep-os.ps1           # Подготовка ОС (пользователь, права)
│       ├── deploy-postgres.ps1   # Развертывание PostgreSQL
│       ├── deploy-gitlab.ps1     # Развертывание GitLab
│       ├── deploy-sonarqube.ps1  # Развертывание SonarQube
│       ├── install-tools.ps1     # Установка инструментов
│       ├── export-from-storage.ps1  # Экспорт из хранилища 1С
│       ├── dump-externals.ps1    # Распаковка внешних обработок
│       ├── lint-bsl.ps1          # Проверка синтаксиса BSL
│       ├── build-compile.ps1     # Компиляция конфигурации
│       ├── quality-gate.ps1      # Проверка Quality Gate
│       └── notify-redmine.ps1    # Уведомления в Redmine
├── docs/
│   └── CI-CD/
│       ├── INSTALLATION-GUIDE.md  # Руководство по установке
│       ├── USAGE-GUIDE.md         # Руководство по использованию
│       ├── CHANGING-REPOSITORY-PATH.md  # Смена пути хранилища
│       ├── MANUAL-STAGE-0.md      # Ручная настройка Stage 0
│       └── PROJECT-SUMMARY.md     # Этот файл
├── build/
│   ├── audit/                    # Результаты аудита и конфигурации
│   │   ├── tools.json           # Статус установленных инструментов
│   │   ├── postgres-config.json # Параметры PostgreSQL
│   │   ├── gitlab-config.json   # Параметры GitLab (создается при развертывании)
│   │   └── sonarqube-config.json  # Параметры SonarQube (создается при развертывании)
│   ├── cf/                      # Скомпилированные CF файлы
│   ├── reports/                 # Отчеты lint/compile
│   └── ib/                      # Временные информационные базы
├── .gitlab-ci.yml               # CI/CD Pipeline
├── .gitignore                   # Исключения для Git
├── sonar-project.properties     # Конфигурация SonarQube
└── README.md                    # Главный README проекта
```

## CI/CD Pipeline

### Stages

1. **sync** - Синхронизация из хранилища 1С в Git
2. **dump-externals** - Распаковка внешних обработок в XML
3. **lint-bsl** - Проверка синтаксиса BSL (precommit1c)
4. **lint-externals** - Проверка внешних обработок
5. **build-compile** - Компиляция конфигурации + проверка модулей
6. **sonar** - Анализ качества кода в SonarQube
7. **quality-gate** - Проверка соответствия критериям качества
8. **package** - Создание пакета развертывания (для main/develop)
9. **notify** - Уведомления в Redmine

### Автоматические триггеры

- **Push** в любую ветку → полный pipeline (кроме sync)
- **Изменения в config-src/** → lint-bsl
- **Изменения в externals/** → lint-externals
- **main/develop** → package

### Ручные триггеры

Через переменную `RUN_SCRIPT`:
- `sync` - только синхронизация
- `lint` - только проверка синтаксиса
- `build` - только компиляция
- `sonar` - только SonarQube
- `quality-gate` - только Quality Gate
- `package` - только упаковка

## Статус выполнения (Progress)

### ✅ Завершено

- [x] Stage A: Аудит инструментов
- [x] Stage 1: Docker Desktop
- [x] Stage 2: PostgreSQL в Docker (порт 5433)
- [x] Stage 7: Структура монорепозитория
- [x] Stage 10: CI/CD Pipeline (.gitlab-ci.yml)
- [x] Stage 11: Интеграция с Redmine
- [x] Stage 13: Документация

### 🔄 В процессе

- [ ] Stage 3: GitLab CE (образ загружен, требуется запуск контейнера)
- [ ] Stage 5: SonarQube (образ загружается)
- [ ] Stage 8: Установка инструментов (скрипты готовы)

### ⏳ Требуется выполнить

- [ ] Stage 0: Пререквизиты ОС (требует прав администратора)
- [ ] Stage 4: GitLab Runner (установка и регистрация)
- [ ] Stage 6: Redmine в Docker
- [ ] Stage 9: Первый экспорт из хранилища 1С
- [ ] Stage 12: Scripts Web UI (опционально)

## Следующие шаги

### 1. Завершить развертывание Docker контейнеров

```powershell
# Проверить статус загрузки образов
docker images

# Запустить GitLab (если образ загружен)
powershell -ExecutionPolicy Bypass -File ci/scripts/deploy-gitlab.ps1

# Запустить SonarQube (когда образ загрузится)
powershell -ExecutionPolicy Bypass -File ci/scripts/deploy-sonarqube.ps1
```

### 2. Установить инструменты

```powershell
powershell -ExecutionPolicy Bypass -File ci/scripts/install-tools.ps1
```

### 3. Настроить GitLab

1. Дождаться запуска GitLab (3-5 минут)
2. Открыть http://localhost:8929
3. Войти как root (пароль в build/audit/gitlab-config.json)
4. Создать группу и проект
5. Настроить CI/CD Variables

### 4. Зарегистрировать Runner

```powershell
cd C:\Tools\gitlab-runner
.\gitlab-runner.exe register
# Tags: windows,1c
# Executor: shell
```

### 5. Первый sync

```powershell
$env:REPO_PWD = "your-password"
powershell -ExecutionPolicy Bypass -File ci/scripts/export-from-storage.ps1
git add config-src/
git commit -m "Initial configuration export"
git push
```

## Конфигурационные файлы

### ci/config/ci-settings.json

```json
{
  "oneC": {
    "binPath": "C:/Program Files/1cv8/8.3.12.1714/bin",
    "tempIB": "C:/1C-CI-CD/build/ib"
  },
  "repository": {
    "url": "file://C:/1crepository",
    "user": "ci_1c",
    "passwordEnv": "REPO_PWD"
  },
  "tools": {
    "gitSync3": "C:/Tools/GitSync3/gitsync3.exe",
    "precommit1c": "C:/Python311/Scripts/precommit1c.exe",
    "sonarScanner": "C:/Tools/sonar-scanner/bin/sonar-scanner.bat",
    "oscript": "C:/Program Files/OneScript/oscript.exe"
  }
}
```

### GitLab CI Variables (настроить в GitLab)

```
REPO_PWD=<password>
SONAR_HOST_URL=http://localhost:9000
SONAR_TOKEN=<token>
REDMINE_URL=http://localhost:3000
REDMINE_API_KEY=<api-key>
```

## Порты и доступ

| Сервис | URL | Логин | Пароль |
|--------|-----|-------|--------|
| GitLab | http://localhost:8929 | root | См. build/audit/gitlab-config.json |
| SonarQube | http://localhost:9000 | admin | admin (изменить при первом входе) |
| Redmine | http://localhost:3000 | admin | admin |
| PostgreSQL | localhost:5433 | postgres | postgres_admin_123 |

## Полезные команды

### Проверка статуса

```powershell
# Статус всей инфраструктуры
powershell -ExecutionPolicy Bypass -File ci/scripts/check-status.ps1

# Docker контейнеры
docker ps

# GitLab Runner
gitlab-runner status
gitlab-runner verify
```

### Логи

```powershell
# Логи контейнеров
docker logs gitlab
docker logs sonarqube
docker logs postgres_unified
docker logs redmine

# Следить за логами в реальном времени
docker logs -f gitlab
```

### Перезапуск сервисов

```powershell
# Перезапустить контейнер
docker restart gitlab

# Остановить все
docker stop gitlab sonarqube redmine postgres_unified

# Запустить все
docker start postgres_unified gitlab sonarqube redmine
```

## Ресурсы

- [Installation Guide](INSTALLATION-GUIDE.md) - Полное руководство по установке
- [Usage Guide](USAGE-GUIDE.md) - Руководство по использованию
- [Changing Repository Path](CHANGING-REPOSITORY-PATH.md) - Смена пути к хранилищу
- [Manual Stage 0](MANUAL-STAGE-0.md) - Ручная настройка пререквизитов

## Контакты и поддержка

При возникновении вопросов:
1. Проверьте документацию в `docs/CI-CD/`
2. Запустите проверку статуса: `ci/scripts/check-status.ps1`
3. Проверьте логи соответствующего сервиса
4. Создайте issue в GitLab с описанием проблемы

---

**Дата создания:** 2025-10-14  
**Версия:** 1.0  
**Автор:** CI/CD Infrastructure Setup

