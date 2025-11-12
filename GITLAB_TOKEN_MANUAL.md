# Создание Personal Access Token в GitLab (Ручной способ)

## Проблема
Автоматическое создание токена через Rails console занимает слишком много времени из-за медленной инициализации Rails окружения.

## Решение: Создание токена через веб-интерфейс

### Шаг 1: Откройте GitLab
Откройте браузер и перейдите по адресу: http://localhost:8929

### Шаг 2: Войдите в систему
- **Username:** root
- **Password:** rootpassword123

### Шаг 3: Перейдите в настройки токенов
1. Нажмите на аватар в правом верхнем углу
2. Выберите **"Edit profile"** или **"Settings"**
3. В левом меню выберите **"Access Tokens"**

### Шаг 4: Создайте новый токен
1. Нажмите **"Add new token"**
2. Заполните форму:
   - **Token name:** API Token
   - **Expiration date:** оставьте пустым (токен без срока действия)
   - **Select scopes:** отметьте следующие права:
     - ✅ **api** - полный доступ к API
     - ✅ **read_repository** - чтение репозиториев
     - ✅ **write_repository** - запись в репозитории
3. Нажмите **"Create personal access token"**

### Шаг 5: Сохраните токен
1. GitLab покажет токен **ТОЛЬКО ОДИН РАЗ**
2. Скопируйте токен
3. Создайте файл `.env.gitlab` в корне проекта:
   ```
   GITLAB_TOKEN=ваш_токен_здесь
   GITLAB_URL=http://localhost:8929
   ```

### Шаг 6: Проверьте токен
Выполните команду для проверки:
```powershell
$token = Get-Content .env.gitlab | Select-String "GITLAB_TOKEN" | ForEach-Object { $_.ToString().Split('=')[1] }
curl.exe -H "PRIVATE-TOKEN: $token" http://localhost:8929/api/v4/user
```

Если токен работает, вы увидите JSON с информацией о пользователе root.

## Альтернативный способ: Использование существующего токена

Если у вас уже есть токен, просто создайте файл `.env.gitlab`:
```
GITLAB_TOKEN=glpat-xxxxxxxxxxxxxxxxxxxx
GITLAB_URL=http://localhost:8929
```

## Следующие шаги

После создания токена:
1. Запустите скрипт инициализации: `python scripts/init_gitlab.py`
2. Создайте тестовый проект
3. Настройте CI/CD pipeline
