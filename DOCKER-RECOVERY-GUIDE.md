# Руководство по восстановлению Docker Desktop

**Дата**: 5 ноября 2025  
**Проблема**: Поврежденный VHDX файл Docker Desktop  
**Ошибка**: 0x80070570 - "Файл или папка повреждены. Чтение невозможно."

---

## 🚨 Проблема

Docker Desktop не запускается из-за повреждения виртуального диска:
```
C:\ProgramData\DockerDesktop\vm-data\DockerDesktop.vhdx
```

**Симптомы**:
- Docker не запускается
- Ошибка Hyper-V: "status code not OK but 500"
- Сообщение: "Файл или папка повреждены"

---

## ✅ Решение

### Автоматическое восстановление (рекомендуется)

Запустите скрипт с правами администратора:
```powershell
# Из директории проекта
.\fix-docker-vhdx.ps1
```

Скрипт выполнит:
1. Остановку всех процессов Docker
2. Остановку Hyper-V VM
3. Удаление поврежденных файлов
4. Очистку кэша
5. Запуск Docker Desktop (по запросу)

---

### Ручное восстановление

Если автоматический скрипт не сработал:

#### Шаг 1: Остановить Docker Desktop

```powershell
# Остановить процессы
Stop-Process -Name "Docker Desktop" -Force
Get-Process | Where-Object {$_.Name -like "*docker*"} | Stop-Process -Force

# Остановить Hyper-V VM
Stop-VM -Name "DockerDesktopVM" -Force -TurnOff
```

#### Шаг 2: Удалить поврежденные файлы

```powershell
# Требуются права администратора!
$vmDataPath = "C:\ProgramData\DockerDesktop\vm-data"
Remove-Item -Path $vmDataPath -Recurse -Force

# Или удалить только VHDX
Remove-Item "C:\ProgramData\DockerDesktop\vm-data\DockerDesktop.vhdx" -Force
```

#### Шаг 3: Очистить кэш

```powershell
# Очистка локальных данных
Remove-Item "$env:LOCALAPPDATA\Docker\wsl\data\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:APPDATA\Docker\*" -Recurse -Force -ErrorAction SilentlyContinue
```

#### Шаг 4: Запустить Docker Desktop

```powershell
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
```

Подождите 60-90 секунд для полной инициализации.

---

## 🔄 После восстановления

### 1. Проверка работоспособности

```powershell
# Проверка версии
docker version

# Проверка контейнеров (будет пусто)
docker ps -a

# Проверка образов (будет пусто)
docker images

# Проверка volumes (должны сохраниться!)
docker volume ls
```

### 2. Восстановление сети

```powershell
# Создать сеть для CI/CD
docker network create cicd-network
```

### 3. Восстановление внешних сервисов

```powershell
# Запустить PostgreSQL, GitLab, Redmine, SonarQube
docker-compose -f docker-compose-external-services.yml up -d

# Проверить статус
docker-compose -f docker-compose-external-services.yml ps
```

### 4. Восстановление полного стека

```powershell
# Запустить все сервисы включая CI/CD Service
docker-compose -f docker-compose-full-stack.yml up -d

# Проверить логи
docker-compose -f docker-compose-full-stack.yml logs -f
```

---

## 📊 Что сохраняется, что теряется

### ✅ Сохраняется (в Docker volumes)

- **PostgreSQL данные**: `postgres_data` volume
- **GitLab конфигурация**: `gitlab_config`, `gitlab_data`, `gitlab_logs` volumes
- **Redmine данные**: `redmine_data`, `redmine_logs`, `redmine_plugins` volumes
- **SonarQube данные**: `sonarqube_data`, `sonarqube_logs`, `sonarqube_extensions` volumes
- **CI/CD workspace**: `cicd_workspace`, `cicd_logs` volumes

### ❌ Теряется

- **Контейнеры**: Все контейнеры будут удалены (пересоздаются из docker-compose)
- **Образы**: Все Docker images (будут скачаны заново)
- **Сети**: Все Docker networks (пересоздаются)
- **Временные данные**: Любые данные не в volumes

---

## 🧪 Тестирование после восстановления

### 1. Базовая проверка Docker

```powershell
# Docker работает?
docker version

# Контейнеры запускаются?
docker run hello-world

# Volumes доступны?
docker volume inspect postgres_data
```

### 2. Проверка сервисов

```powershell
# PostgreSQL
docker exec postgres_cicd pg_isready -U postgres

# GitLab
curl http://localhost:8929/-/health

# Redmine
curl http://localhost:3000

# SonarQube
curl http://localhost:9000/api/system/status
```

### 3. Проверка данных

```powershell
# Проверить базы данных в PostgreSQL
docker exec postgres_cicd psql -U postgres -c "\l"

# Проверить GitLab проекты
# Откройте http://localhost:8929

# Проверить SonarQube проекты
# Откройте http://localhost:9000
```

---

## 🔧 Альтернативные методы

### Метод 1: Factory Reset через интерфейс

1. Запустите Docker Desktop (если возможно)
2. Settings → Troubleshoot → Reset to factory defaults
3. Подтвердите сброс

**Недостаток**: Удалит ВСЕ volumes (потеря данных!)

### Метод 2: Переустановка Docker Desktop

1. Удалите Docker Desktop через "Программы и компоненты"
2. Удалите папки вручную:
   - `C:\ProgramData\DockerDesktop`
   - `C:\Program Files\Docker`
   - `%APPDATA%\Docker`
   - `%LOCALAPPDATA%\Docker`
3. Скачайте и установите новую версию

**Недостаток**: Требует больше времени

### Метод 3: Восстановление VHDX

```powershell
# Попытка исправить VHDX (может не сработать)
Optimize-VHD -Path "C:\ProgramData\DockerDesktop\vm-data\DockerDesktop.vhdx" -Mode Full
```

---

## ⚠️ Предотвращение проблем в будущем

### 1. Регулярные резервные копии

```powershell
# Экспорт volumes
docker run --rm -v postgres_data:/data -v C:/backup:/backup alpine tar czf /backup/postgres_data.tar.gz /data

# Экспорт GitLab
docker exec gitlab gitlab-backup create

# Экспорт конфигураций
docker-compose -f docker-compose-full-stack.yml config > backup/docker-compose-backup.yml
```

### 2. Мониторинг здоровья

```powershell
# Создать скрипт для проверки состояния
# check-docker-health.ps1
docker system df
docker system events --since 1h
```

### 3. Избегайте жестких остановок

- Всегда используйте `docker-compose down` вместо kill
- Graceful shutdown контейнеров
- Не выключайте компьютер во время работы Docker

### 4. Обновляйте Docker Desktop

- Регулярно проверяйте обновления
- Текущая стабильная версия: 4.x
- Читайте changelog перед обновлением

---

## 📞 Дополнительная помощь

### Логи для диагностики

```powershell
# Docker Desktop логи
Get-Content "$env:LOCALAPPDATA\Docker\log.txt" -Tail 100

# Hyper-V логи
Get-WinEvent -LogName "Microsoft-Windows-Hyper-V-*" -MaxEvents 50 | Format-List

# Windows Event Viewer
Get-EventLog -LogName Application -Source Docker -Newest 20
```

### Полезные команды

```powershell
# Проверка Hyper-V
Get-VM
Get-VMSwitch

# Проверка WSL (если используется)
wsl --list --verbose
wsl --status

# Системная информация
systeminfo | findstr /C:"Hyper-V"
```

---

## ✅ Чеклист восстановления

- [ ] Остановлен Docker Desktop
- [ ] Остановлена Hyper-V VM
- [ ] Удален поврежденный VHDX
- [ ] Очищен кэш Docker
- [ ] Запущен Docker Desktop
- [ ] Проверена работоспособность (`docker version`)
- [ ] Создана сеть `cicd-network`
- [ ] Восстановлены volumes (проверены)
- [ ] Запущены внешние сервисы (PostgreSQL, GitLab, Redmine, SonarQube)
- [ ] Протестированы все endpoints
- [ ] Проверены данные в базах
- [ ] Запущен полный стек CI/CD

---

**Примечание**: Этот процесс **НЕ удаляет volumes**, поэтому все важные данные (БД, конфигурации) должны сохраниться. Будут потеряны только контейнеры и образы, которые легко восстановить из docker-compose.

**Время восстановления**: 10-20 минут (зависит от скорости интернета для скачивания образов)

