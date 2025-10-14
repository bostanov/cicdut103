# 1C CI/CD Monorepo

Монорепозиторий для непрерывной интеграции и доставки конфигурации 1С:Управление торговлей 10.3

## Структура проекта

```
.
├── config-src/          # Исходники конфигурации 1С (XML)
├── externals/           # Внешние обработки и отчеты (выгружены)
├── externals-src/       # Исходники внешних обработок (XML)
├── ci/                  # CI/CD инструменты и конфигурация
│   ├── config/          # Конфигурационные файлы
│   └── scripts/         # PowerShell скрипты для автоматизации
├── docs/                # Документация проекта
│   └── CI-CD/           # Документация по CI/CD
├── build/               # Артефакты сборки (не в Git)
│   ├── audit/           # Результаты аудита
│   ├── ib/              # Временная информационная база
│   └── cf/              # Собранные cf-файлы
├── .gitlab-ci.yml       # GitLab CI/CD Pipeline
└── sonar-project.properties  # Конфигурация SonarQube
```

## Инфраструктура

### Docker контейнеры

- **PostgreSQL** (port 5432) - База данных для SonarQube и Redmine
- **GitLab CE** (ports 8929, 2224) - Git-сервер и CI/CD
- **SonarQube** (port 9000) - Анализ качества кода 1С (с BSL plugin)
- **Redmine** (port 3000) - Управление задачами

### Установленные инструменты

- **1C:Enterprise 8.3** - Платформа 1С
- **Git** - Система контроля версий
- **Docker** - Контейнеризация
- **GitLab Runner** - Запуск CI/CD задач
- **OneScript** - Скриптовый движок для автоматизации
- **GitSync3** - Синхронизация хранилища 1С с Git
- **precommit1c** - Pre-commit хуки для 1С
- **SonarScanner** - Клиент для SonarQube

## Быстрый старт

### 1. Предварительные требования

- Windows 10/11
- Docker Desktop
- 1C:Enterprise 8.3.12+
- PowerShell 5.1+

### 2. Начальная настройка

```powershell
# 1. Клонировать репозиторий
git clone <repository-url>
cd 1C-CI-CD

# 2. Запустить аудит инструментов
powershell -ExecutionPolicy Bypass -File ci/scripts/audit-tools.ps1

# 3. Настроить пререквизиты ОС (требует прав администратора)
# См. docs/CI-CD/MANUAL-STAGE-0.md

# 4. Развернуть Docker контейнеры
powershell -ExecutionPolicy Bypass -File ci/scripts/deploy-postgres.ps1
powershell -ExecutionPolicy Bypass -File ci/scripts/deploy-gitlab.ps1
powershell -ExecutionPolicy Bypass -File ci/scripts/deploy-sonarqube.ps1
```

### 3. Доступ к сервисам

- **GitLab**: http://localhost:8929 (root / см. build/audit/gitlab-config.json)
- **SonarQube**: http://localhost:9000 (admin / admin)
- **Redmine**: http://localhost:3000

## CI/CD Pipeline

Pipeline автоматически выполняет:

1. **Validate** - Проверка синтаксиса конфигурации 1С
2. **Build** - Сборка cf-файла
3. **Test** - Синтаксический анализ через SonarQube
4. **Deploy** - Развертывание на тестовую базу (опционально)

См. `.gitlab-ci.yml` для деталей.

## Разработка

### Экспорт из хранилища 1С

```powershell
# Экспорт всей конфигурации
powershell -ExecutionPolicy Bypass -File ci/scripts/export-from-storage.ps1
```

### Коммит изменений

```bash
git add config-src/
git commit -m "Описание изменений"
git push origin main
```

### Анализ качества

После push GitLab CI автоматически запустит анализ в SonarQube.
Результаты доступны в: http://localhost:9000

## Документация

- [Сводка развертывания](docs/CI-CD/DEPLOYMENT-SUMMARY.md) - Текущий статус развертывания
- [Изменение пути к хранилищу](docs/CI-CD/CHANGING-REPOSITORY-PATH.md)
- [Настройка Stage 0 (ручная)](docs/CI-CD/MANUAL-STAGE-0.md)
- [Полное руководство по установке](docs/CI-CD/INSTALLATION-GUIDE.md)
- [Руководство пользователя](docs/CI-CD/USAGE-GUIDE.md)

## Техническая поддержка

Для вопросов и проблем создайте issue в GitLab или Redmine.

## Лицензия

Внутренний проект. Все права защищены.

