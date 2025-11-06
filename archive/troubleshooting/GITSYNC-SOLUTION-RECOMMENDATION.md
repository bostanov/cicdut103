# GitSync3 - Рекомендации по решению проблемы

**Дата**: 6 ноября 2025, 11:50
**Проблема**: `System.Xml.XmlException: Data at the root level is invalid. Line 1, position 1`
**Местоположение**: МенеджерСинхронизации.os:1460

---

## Анализ проблемы

### Что мы выяснили:
1. ✅ Хранилище НЕ пустое (подтверждено пользователем)
2. ✅ Учетные данные верны (подтверждено пользователем)
3. ✅ GitSync 3.6.1 установлен и запускается
4. ✅ Платформа 1С 8.3.12.1714 установлена
5. ❌ При синхронизации платформа 1С зависает или возвращает некорректные данные
6. ❌ GitSync не может распарсить ответ от платформы 1С

### Основная причина:
GitSync пытается получить список пользователей или версий из хранилища через платформу 1С, но получает некорректный XML или пустой ответ, что приводит к ошибке парсинга.

---

## Решение проблемы

### ✅ РЕШЕНИЕ #1: Изменить монтирование хранилища на read-write (РЕКОМЕНДУЕТСЯ)

**Проблема**: Хранилище смонтировано как read-only, платформа 1С не может создавать lock-файлы (.cfl)

**Решение**:
1. Остановить все контейнеры
2. Изменить `docker-compose-full-stack.yml`:
   ```yaml
   volumes:
     # Было:
     - C:/1crepository:/1c-storage:ro
     # Должно быть:
     - C:/1crepository:/1c-storage
   ```
3. Перезапустить Docker Desktop
4. Запустить контейнеры заново

**Команды**:
```powershell
# Остановить Docker Desktop
Get-Process "*Docker Desktop*" | Stop-Process -Force

# Дождаться остановки, затем запустить
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Дождаться запуска Docker (1-2 минуты)
Start-Sleep -Seconds 60

# Очистить старые контейнеры
docker ps -a | Select-String "cicd-service" | ForEach-Object {
    $id = ($_ -split '\s+')[0]
    docker rm -f $id
}

# Запустить новый контейнер
cd C:\1C-CI-CD
docker-compose -f docker-compose-full-stack.yml up -d cicd-service

# Проверить логи
docker logs -f cicd-service-final
```

---

### ✅ РЕШЕНИЕ #2: Создать файл AUTHORS вручную

**Проблема**: GitSync не может получить список пользователей из хранилища

**Решение**: Создать файл `/workspace/AUTHORS` с пользователями хранилища вручную

**Как узнать пользователей**:
1. Открыть хранилище через 1С Конфигуратор (Windows)
2. Конфигурация → Хранилище конфигурации → Администрирование
3. Посмотреть список пользователей

**Формат файла AUTHORS**:
```
gitsync = GitSync User <gitsync@localhost>
admin = Administrator <admin@localhost>
developer = Developer Name <developer@localhost>
```

**Команды**:
```powershell
# После запуска контейнера
docker exec cicd-service-final bash -c "cat > /workspace/AUTHORS << 'EOF'
gitsync = GitSync User <gitsync@localhost>
admin = Administrator <admin@localhost>
EOF"

# Проверить
docker exec cicd-service-final cat /workspace/AUTHORS
```

---

### ✅ РЕШЕНИЕ #3: Отключить плагин check-authors

**Проблема**: Плагин check-authors пытается проверить пользователей и вызывает ошибку

**Решение**: Убедиться что плагин отключен в конфигурации

**Проверка текущей конфигурации**:
```powershell
docker exec cicd-service-final cat /workspace/gitsync.json
```

**Должно быть**:
```json
{
  "plugins": {
    "check-authors": {
      "enable": false
    }
  }
}
```

---

### ✅ РЕШЕНИЕ #4: Альтернативный путь - работа с cf-файлами (если остальное не помогло)

**Идея**: Вместо синхронизации напрямую с хранилищем, использовать cf-файлы

**Шаги**:
1. **На Windows через 1С Конфигуратор**:
   - Подключиться к хранилищу
   - Выгрузить последнюю версию в cf-файл: `Файл → Сохранить конфигурацию в файл`
   - Сохранить как `C:\1C-CI-CD\config\1cv8.cf`

2. **Использовать v8unpack для разборки cf-файла**:
   ```powershell
   docker exec cicd-service-final bash -c "
   cd /workspace
   v8unpack /config/1cv8.cf ./src
   git add .
   git commit -m 'Initial configuration from cf-file'
   git push origin master
   "
   ```

3. **Настроить периодическую выгрузку**:
   - Создать задачу Windows для еженедельной выгрузки cf-файла
   - Контейнер будет автоматически разбирать cf и коммитить изменения

---

## Пошаговый план действий

### Шаг 1: Перезапуск Docker с правильной конфигурацией (5 минут)
```powershell
# 1. Остановить Docker
Get-Process "*Docker Desktop*" | Stop-Process -Force
Start-Sleep -Seconds 10

# 2. Запустить Docker
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
Start-Sleep -Seconds 60

# 3. Очистить контейнеры
docker rm -f cicd-service-final
docker rm -f e0eeae54c2a8

# 4. Запустить новый контейнер
cd C:\1C-CI-CD
docker-compose -f docker-compose-full-stack.yml up -d cicd-service
```

### Шаг 2: Создать файл AUTHORS (2 минуты)
```powershell
# Дождаться запуска контейнера
Start-Sleep -Seconds 30

# Создать AUTHORS (замените на реальных пользователей!)
docker exec cicd-service-final bash -c "cat > /workspace/AUTHORS << 'EOF'
gitsync = GitSync User <gitsync@localhost>
admin = Administrator <admin@localhost>
EOF"
```

### Шаг 3: Проверить синхронизацию (1 минута)
```powershell
# Проверить логи
docker logs cicd-service-final 2>&1 | Select-String "gitsync" | Select-Object -Last 20

# Если ошибки продолжаются, попробовать ручной запуск
docker exec cicd-service-final bash -c "
export GITSYNC_STORAGE_PATH='file:///1c-storage'
export GITSYNC_STORAGE_USER='gitsync'
export GITSYNC_STORAGE_PASSWORD='123'
export DISPLAY=:99
cd /workspace
gitsync sync 2>&1 | head -50
"
```

---

## Если проблема сохраняется

### Диагностика:
```powershell
# 1. Проверить доступ к хранилищу
docker exec cicd-service-final ls -la /1c-storage/

# 2. Проверить права
docker exec cicd-service-final touch /1c-storage/test-write.txt
docker exec cicd-service-final rm /1c-storage/test-write.txt

# 3. Проверить платформу 1С
docker exec cicd-service-final /opt/1C/v8.3/x86_64/1cv8c -version
```

### Получить детальные логи:
```powershell
docker exec cicd-service-final bash -c "
export GITSYNC_VERBOSE=true
export DISPLAY=:99
cd /workspace
gitsync sync 2>&1 | tee /tmp/gitsync-debug.log
"

# Посмотреть логи
docker exec cicd-service-final cat /tmp/gitsync-debug.log
```

---

## Контакты для помощи

- [GitSync GitHub Issues](https://github.com/oscript-library/gitsync/issues)
- [Infostart форум по GitSync](https://infostart.ru/1c/articles/1157400/)
- [Telegram группа по 1С DevOps](https://t.me/onescript_community)

---

**Создано**: 6 ноября 2025, 11:50
**Полный лог попыток**: см. `GITSYNC-TROUBLESHOOTING-LOG.md`

