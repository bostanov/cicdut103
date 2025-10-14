# CI/CD Usage Guide

Руководство по использованию CI/CD для разработки конфигурации 1С

## Ежедневная работа

### Workflow разработчика

1. **Работа в конфигураторе 1С**
   - Откройте конфигурацию из хранилища 1С обычным образом
   - Внесите изменения
   - Зафиксируйте изменения в хранилище 1С (Ctrl+Shift+K)

2. **Синхронизация с Git**
   - Откройте GitLab: http://localhost:8929
   - Перейдите в проект → CI/CD → Pipelines
   - Нажмите "Run pipeline"
   - Выберите переменную `RUN_SCRIPT` = `sync`
   - Запустите pipeline

3. **Автоматическая проверка**
   - После sync автоматически запустится полный pipeline:
     - Lint (проверка синтаксиса)
     - Build (компиляция)
     - SonarQube analysis
     - Quality Gate

4. **Просмотр результатов**
   - Статус pipeline: GitLab → CI/CD → Pipelines
   - Детали анализа: SonarQube → http://localhost:9000
   - Задачи: Redmine → http://localhost:3000

## Branching Strategy

### Основные ветки

- **main** - production (защищена)
- **develop** - integration (защищена)
- **feature/** - разработка функций
- **hotfix/** - срочные исправления

### Создание feature-ветки

```bash
# Создайте ветку от develop
git checkout develop
git pull
git checkout -b feature/TASK-123-new-report

# Синхронизируйте из хранилища
# (Run pipeline with RUN_SCRIPT=sync)

# Работайте в конфигураторе...

# После завершения создайте Merge Request
git push origin feature/TASK-123-new-report
```

### Merge Request

1. Откройте GitLab
2. Создайте Merge Request из feature-ветки в develop
3. Pipeline запустится автоматически
4. Дождитесь прохождения всех проверок
5. Запросите Code Review
6. После одобрения - Merge

## CI/CD Jobs

### Доступные job'ы

| Job | Этап | Описание | Триггер |
|-----|------|----------|---------|
| sync | sync | Синхронизация из хранилища 1С | Manual, RUN_SCRIPT=sync |
| dump-externals | dump-externals | Распаковка внешних обработок | Auto при push |
| lint-bsl | lint-bsl | Проверка синтаксиса BSL | Auto при изменении config-src/ |
| lint-externals | lint-externals | Проверка внешних обработок | Auto при изменении externals/ |
| build-compile | build-compile | Компиляция конфигурации | Auto при push |
| sonar | sonar | Анализ в SonarQube | Auto при push |
| quality-gate | quality-gate | Проверка Quality Gate | Auto после sonar |
| package | package | Создание пакета развертывания | Auto на main/develop |
| notify | notify | Уведомления в Redmine | Auto всегда |

### Ручной запуск job'ов

Через переменную `RUN_SCRIPT`:

```
# В GitLab: CI/CD → Pipelines → Run pipeline
RUN_SCRIPT = sync          # Только синхронизация
RUN_SCRIPT = lint          # Только проверка синтаксиса  
RUN_SCRIPT = build         # Только компиляция
RUN_SCRIPT = sonar         # Только SonarQube
RUN_SCRIPT = quality-gate  # Только Quality Gate
RUN_SCRIPT = package       # Только упаковка
```

## Quality Gates

### Критерии качества

SonarQube проверяет:
- **Coverage** - покрытие кода (целевое: >80%)
- **Duplications** - дублирование кода (< 3%)
- **Maintainability** - техдолг (рейтинг A)
- **Reliability** - баги (0 критических)
- **Security** - уязвимости (0 критических)

### Что делать при FAIL

1. **Откройте SonarQube**
   ```
   http://localhost:9000/dashboard?id=ut103
   ```

2. **Изучите проблемы**
   - Перейдите в Issues
   - Отфильтруйте по Severity
   - Прочитайте описание проблем

3. **Исправьте код**
   - Внесите изменения в конфигураторе
   - Зафиксируйте в хранилище
   - Запустите sync + pipeline снова

4. **Если проблема ложная**
   - Отметьте issue как "Won't Fix" или "False Positive" в SonarQube
   - Добавьте комментарий с обоснованием

## Уведомления

### Интеграция с Redmine

Pipeline автоматически добавляет комментарии к задачам Redmine, если в commit message есть номер задачи:

```bash
# Формат: #123, refs #456, issue-789
git commit -m "Добавлен новый отчет #123"
git commit -m "Исправлена ошибка refs #456"
git commit -m "Оптимизация issue-789"
```

Комментарий включает:
- Статус pipeline (success/failed)
- Ссылку на pipeline
- Commit SHA
- Сообщение коммита

## Переменные окружения

### Обязательные (GitLab CI Variables)

```
REPO_PWD          - Пароль от хранилища 1С
SONAR_HOST_URL    - http://localhost:9000
SONAR_TOKEN       - Токен SonarQube
REDMINE_URL       - http://localhost:3000
REDMINE_API_KEY   - API ключ Redmine
```

### Опциональные

```
GIT_STRATEGY              - fetch (по умолчанию)
GIT_SUBMODULE_STRATEGY    - none (по умолчанию)
RUN_SCRIPT                - Ручной запуск конкретного job
```

## Артефакты

### Что сохраняется

- **config-src/** - Исходники конфигурации (1 день)
- **externals-src/** - Исходники внешних обработок (1 день)
- **build/cf/** - Скомпилированный CF файл (7 дней)
- **build/reports/** - Отчеты lint/compile (7 дней)
- **build/package/** - Пакет развертывания (30 дней, только main/develop)

### Скачивание артефактов

1. Откройте pipeline в GitLab
2. Справа от job нажмите кнопку скачивания
3. Или используйте GitLab API:
   ```bash
   curl -H "PRIVATE-TOKEN: <your-token>" \
     "http://localhost:8929/api/v4/projects/1/jobs/123/artifacts" \
     -o artifacts.zip
   ```

## Troubleshooting

### Pipeline упал на sync

**Причины:**
- Неверный пароль хранилища → проверьте `REPO_PWD`
- Недоступно хранилище → проверьте путь в `ci/config/ci-settings.json`
- Нет прав у ci_1c → проверьте права пользователя

### Pipeline упал на lint

**Причины:**
- Синтаксические ошибки в коде → исправьте в конфигураторе
- precommit1c не установлен → запустите `ci/scripts/install-tools.ps1`

### Pipeline упал на build-compile

**Причины:**
- Ошибки компиляции → проверьте лог в build/reports/compile/check_modules.log
- Недоступна платформа 1С → проверьте путь в ci/config/ci-settings.json

### Quality Gate FAILED

**Причины:**
- Не соблюдены критерии качества → откройте SonarQube и исправьте проблемы
- SonarQube недоступен → проверьте `docker logs sonarqube`

### Runner не подхватывает job'ы

**Причины:**
- Runner не запущен → `gitlab-runner status`
- Неверные теги → проверьте теги в `.gitlab-ci.yml` и у Runner
- Runner не зарегистрирован → `gitlab-runner verify`

## Best Practices

1. **Всегда работайте в feature-ветках**
2. **Делайте частые коммиты с понятными сообщениями**
3. **Указывайте номер задачи в commit message**
4. **Не игнорируйте Quality Gate**
5. **Регулярно синхронизируйте из хранилища**
6. **Проверяйте результаты pipeline перед Merge**
7. **Используйте Code Review**

## Дополнительные ресурсы

- [Installation Guide](INSTALLATION-GUIDE.md)
- [Changing Repository Path](CHANGING-REPOSITORY-PATH.md)
- [GitLab CI/CD Docs](https://docs.gitlab.com/ee/ci/)
- [SonarQube BSL Rules](https://github.com/1c-syntax/bsl-language-server)

