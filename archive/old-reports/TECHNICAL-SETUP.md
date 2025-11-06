# Техническая документация по настройке системы 1C-CI/CD

## Системные требования

### Минимальные требования
- **ОС**: Windows 10/11 или Windows Server 2019/2022
- **RAM**: 8 GB
- **Диск**: 50 GB свободного места
- **Процессор**: 4 ядра

### Рекомендуемые требования
- **ОС**: Windows Server 2022
- **RAM**: 16 GB
- **Диск**: 100 GB SSD
- **Процессор**: 8 ядер

## Установленные компоненты

### 1. 1С:Предприятие 8.3.12.1714
- **Путь**: `C:\Program Files\1cv8\8.3.12.1714\`
- **Хранилище**: `C:\1crepository`
- **Пользователь**: `gitsync`
- **Пароль**: `123`

### 2. OneScript 1.9.3.15
- **Путь**: `C:\Program Files\OneScript\`
- **Исполняемый файл**: `oscript.exe`

### 3. GitSync 3.6.1
- **Установлен через**: OneScript
- **Конфигурация**: `gitsync.json`

### 4. PreCommit1C 2.3.0
- **Установлен через**: OneScript
- **Git hooks**: Настроены автоматически

## Конфигурация сервисов

### GitSync Service
- **Тип**: Scheduled Task
- **Имя**: `GitSync-Sync`
- **Интервал**: 10 минут
- **Скрипт**: `ci\scripts\gitsync-service-working.ps1`

### Redmine Monitoring
- **Тип**: Scheduled Task
- **Имя**: `Redmine-Monitoring`
- **Интервал**: 5 минут
- **Скрипт**: `redmine-monitoring-service.ps1`

### SonarQube
- **URL**: http://localhost:9000
- **Проект**: `ut103-ci`
- **Токен**: `squ_f30f3b6a2e0e685fa10673c317194ab4aec4aa12`

### Redmine
- **URL**: http://localhost:3000
- **Пользователь**: `admin`
- **Пароль**: `admin`

### GitLab
- **URL**: http://localhost:8929
- **Проект**: `root/ut103-ci.git`

## Структура каталогов

```
C:\1C-CI-CD\
├── ci\scripts\                    # Скрипты служб
│   ├── gitsync-service-working.ps1
│   └── gitsync-service.cmd
├── logs\                          # Логи системы
│   ├── gitsync-service-working.log
│   ├── redmine-monitoring.log
│   ├── service-monitoring.log
│   └── centralized.log
├── external-files\                # Внешние файлы
│   └── task-{ID}\
│       └── v1.0\
├── src\                          # Исходный код конфигурации
├── .gitlab-ci.yml                # CI/CD конфигурация
├── sonar-project.properties      # Настройки SonarQube
└── gitsync.json                  # Конфигурация GitSync
```

## Переменные окружения

### GitSync
- `GITSYNC_STORAGE_PATH`: `file://C:/1crepository`
- `GITSYNC_WORKDIR`: `C:\1C-CI-CD`
- `GITSYNC_STORAGE_USER`: `gitsync`
- `GITSYNC_STORAGE_PASSWORD`: `123`
- `GITSYNC_V8_PATH`: `C:/Program Files/1cv8/8.3.12.1714/bin/1cv8.exe`
- `GITSYNC_RENAME_MODULE`: `true`
- `GITSYNC_RENAME_FORM`: `true`
- `GITSYNC_PROJECT_NAME`: `ut103-ci`
- `GITSYNC_WORKSPACE_LOCATION`: `C:/1C-CI-CD`
- `GITSYNC_LIMIT`: `5`

## Порты и сеть

| Сервис | Порт | Протокол | Описание |
|--------|------|----------|----------|
| SonarQube | 9000 | HTTP | Веб-интерфейс анализа кода |
| Redmine | 3000 | HTTP | Система управления задачами |
| GitLab | 8929 | HTTP | Git репозиторий и CI/CD |

## Резервное копирование

### Критически важные данные
1. **Хранилище конфигурации**: `C:\1crepository`
2. **Git репозиторий**: `C:\1C-CI-CD\.git`
3. **Конфигурационные файлы**: `C:\1C-CI-CD\*.json`, `C:\1C-CI-CD\*.yml`
4. **Логи**: `C:\1C-CI-CD\logs\`

### Автоматическое резервное копирование
```powershell
# Скрипт резервного копирования
$backupDir = "C:\Backup\1C-CI-CD\$(Get-Date -Format 'yyyy-MM-dd')"
New-Item -ItemType Directory -Path $backupDir -Force

# Копирование хранилища
Copy-Item "C:\1crepository" -Destination "$backupDir\repository" -Recurse

# Копирование проекта
Copy-Item "C:\1C-CI-CD" -Destination "$backupDir\project" -Recurse -Exclude "logs"
```

## Мониторинг производительности

### Ключевые метрики
- **Время синхронизации GitSync**: < 5 минут
- **Время анализа SonarQube**: < 10 минут
- **Время обработки файлов Redmine**: < 2 минут
- **Использование CPU**: < 80%
- **Использование RAM**: < 80%

### Алерты
- Служба не отвечает более 15 минут
- Ошибки в логах
- Недоступность веб-сервисов
- Превышение лимитов ресурсов

## Обновление системы

### Обновление GitSync
```powershell
# Остановка службы
Stop-ScheduledTask -TaskName "GitSync-Sync"

# Обновление через OneScript
opm update gitsync

# Перезапуск службы
Start-ScheduledTask -TaskName "GitSync-Sync"
```

### Обновление PreCommit1C
```powershell
# Обновление через OneScript
opm update precommit1c

# Переустановка Git hooks
precommit1c --install
```

## Безопасность

### Рекомендации
1. **Измените пароли по умолчанию**
2. **Настройте SSL для веб-сервисов**
3. **Ограничьте доступ к файлам конфигурации**
4. **Регулярно обновляйте компоненты**
5. **Мониторьте логи на предмет подозрительной активности**

### Права доступа
- **Службы**: Запуск от имени SYSTEM
- **Файлы конфигурации**: Только для администраторов
- **Логи**: Чтение для всех пользователей
- **Хранилище 1С**: Только для пользователя gitsync

## Устранение неполадок

### Диагностика проблем
1. **Проверка логов**: Всегда начинайте с анализа логов
2. **Проверка сервисов**: Убедитесь, что все службы запущены
3. **Проверка сети**: Проверьте доступность веб-сервисов
4. **Проверка прав**: Убедитесь в корректности прав доступа

### Частые проблемы
- **GitSync не синхронизирует**: Проверьте подключение к хранилищу 1С
- **SonarQube не анализирует**: Проверьте токен и настройки проекта
- **Redmine не обрабатывает файлы**: Проверьте API доступность
- **Высокое использование ресурсов**: Оптимизируйте интервалы проверок

## Контакты поддержки

- **Техническая поддержка**: [контакты]
- **Документация**: [ссылка на документацию]
- **Репозиторий**: [ссылка на GitLab]

