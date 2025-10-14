# 🚀 Быстрый старт CI/CD для 1C УТ 10.3

## 📊 Текущий статус

### ✅ Установлено и работает:

**Docker контейнеры:**
- ✅ PostgreSQL (port 5432) - БД для SonarQube и Redmine
- ✅ GitLab CE (ports 8929, 2224) - Git + CI/CD
- ✅ SonarQube (port 9000) - Анализ качества кода
- ✅ Redmine (port 3000) - Управление задачами

**Инструменты:**
- ✅ Git 2.43.0
- ✅ Docker 28.5.1
- ✅ SonarScanner (C:\Tools\sonar-scanner)
- ✅ GitLab Runner (C:\Tools\gitlab-runner)
- ✅ Python 3.11.7

**Репозиторий:**
- ✅ Git инициализирован
- ✅ CI/CD пайплайн настроен (.gitlab-ci.yml)
- ✅ Скрипты автоматизации созданы

---

## 🎯 Команды для автоматической настройки

### 1. Проверка статуса

```powershell
# Быстрая проверка всей инфраструктуры
docker ps --format "table {{.Names}}\t{{.Status}}"

# Проверка инструментов
C:\Tools\sonar-scanner\bin\sonar-scanner.bat -v
C:\Tools\gitlab-runner\gitlab-runner.exe --version
git --version
```

### 2. Автоматическая настройка (когда сервисы готовы)

```powershell
# Полная автоматическая настройка всех сервисов
# ВАЖНО: Запускать после того, как все контейнеры полностью инициализированы
powershell -ExecutionPolicy Bypass -File ci/scripts/setup-all.ps1

# Или по отдельности:

# SonarQube (создание проекта, токена, настройка Quality Gate)
powershell -ExecutionPolicy Bypass -File ci/scripts/setup-sonarqube.ps1

# Redmine (инструкции по настройке API)
powershell -ExecutionPolicy Bypass -File ci/scripts/setup-redmine.ps1

# GitLab (инструкции по созданию проекта и регистрации Runner)
powershell -ExecutionPolicy Bypass -File ci/scripts/setup-gitlab.ps1
```

### 3. Ожидание готовности сервисов

GitLab и SonarQube требуют 2-5 минут для инициализации после запуска контейнеров.

```powershell
# Проверка готовности GitLab
docker logs gitlab | Select-String "gitlab Reconfigured!"

# Проверка готовности SonarQube
Invoke-WebRequest -Uri "http://localhost:9000/api/system/status" -UseBasicParsing

# Проверка готовности Redmine
Invoke-WebRequest -Uri "http://localhost:3000" -UseBasicParsing
```

### 4. Добавление инструментов в PATH (текущая сессия)

```powershell
$env:Path += ";C:\Tools\sonar-scanner\bin;C:\Tools\gitlab-runner"
```

### 5. Регистрация GitLab Runner (после настройки GitLab)

```powershell
# 1. Откройте http://localhost:8929
# 2. Войдите как: root / Gitlab123Admin!
# 3. Создайте проект: ut103
# 4. Settings -> CI/CD -> Runners -> скопируйте registration token
# 5. Зарегистрируйте runner:

C:\Tools\gitlab-runner\gitlab-runner.exe register `
  --url http://localhost:8929 `
  --registration-token YOUR_TOKEN_HERE `
  --name "1C-CI-CD-Runner" `
  --executor shell `
  --tag-list "windows,1c"

# 6. Установите как сервис (опционально):
# C:\Tools\gitlab-runner\gitlab-runner.exe install --user "ci_1c" --password "YOUR_PASSWORD"
# C:\Tools\gitlab-runner\gitlab-runner.exe start
```

---

## 🌐 Доступ к сервисам

| Сервис | URL | Логин | Пароль |
|--------|-----|-------|---------|
| **GitLab** | http://localhost:8929 | root | Gitlab123Admin! |
| **SonarQube** | http://localhost:9000 | admin | admin |
| **Redmine** | http://localhost:3000 | admin | admin |

---

## 📋 Рекомендуемый порядок действий

### Первый запуск (выполнено):

1. ✅ Развернуть Docker контейнеры
2. ✅ Установить инструменты
3. ✅ Инициализировать Git репозиторий
4. ✅ Создать CI/CD конфигурацию

### Сейчас нужно сделать:

1. **Подождать 2-3 минуты** пока сервисы полностью инициализируются
2. **Запустить автоматическую настройку:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File ci/scripts/setup-all.ps1
   ```
3. **Настроить GitLab:**
   - Открыть http://localhost:8929
   - Войти (root / Gitlab123Admin!)
   - Создать проект `ut103`
   - Зарегистрировать Runner
4. **Отправить код в GitLab:**
   ```powershell
   git remote add origin http://localhost:8929/root/ut103.git
   git push -u origin master
   ```

---

## 🔧 Управление контейнерами

```powershell
# Остановить все
docker stop gitlab sonarqube redmine postgres_unified

# Запустить все
docker start postgres_unified gitlab sonarqube redmine

# Перезапустить конкретный сервис
docker restart gitlab

# Просмотр логов
docker logs -f gitlab
docker logs -f sonarqube
docker logs -f redmine

# Очистка (ВНИМАНИЕ: удалит все данные!)
docker stop gitlab sonarqube redmine postgres_unified
docker rm gitlab sonarqube redmine postgres_unified
docker volume rm postgres_data
```

---

## 📖 Дополнительная документация

- **Полный отчет:** `docs/CI-CD/DEPLOYMENT-SUMMARY.md`
- **Руководство по установке:** `docs/CI-CD/INSTALLATION-GUIDE.md`
- **Руководство пользователя:** `docs/CI-CD/USAGE-GUIDE.md`

---

## ❓ Частые проблемы

### GitLab не отвечает
- Подождите 5-10 минут после запуска
- Проверьте: `docker logs gitlab`

### SonarQube не запускается
- Проверьте подключение к PostgreSQL
- Проверьте: `docker logs sonarqube`

### Инструменты не найдены в PATH
```powershell
# Добавить в текущую сессию:
$env:Path += ";C:\Tools\sonar-scanner\bin;C:\Tools\gitlab-runner"

# Добавить постоянно (требует прав администратора):
# [Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path", "Machine") + ";C:\Tools\sonar-scanner\bin;C:\Tools\gitlab-runner", "Machine")
```

---

## 🎉 Готово!

После выполнения всех шагов у вас будет полностью функциональная CI/CD инфраструктура для разработки 1С конфигураций.

