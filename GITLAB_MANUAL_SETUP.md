# Ручная настройка GitLab

## Статус
GitLab запущен и доступен по адресу: http://localhost:8929

## Шаг 1: Вход в систему

1. Откройте браузер и перейдите по адресу: http://localhost:8929
2. Войдите используя:
   - **Username**: `root`
   - **Password**: `gitlab_root_password`

## Шаг 2: Создание Personal Access Token

1. После входа нажмите на аватар в правом верхнем углу
2. Выберите **Edit profile** (или **Preferences**)
3. В левом меню выберите **Access Tokens**
4. Создайте новый токен:
   - **Name**: `CI/CD Integration Token`
   - **Expires at**: оставьте пустым (без срока действия)
   - **Scopes**: отметьте:
     - ✅ `api`
     - ✅ `read_repository`
     - ✅ `write_repository`
5. Нажмите **Create personal access token**
6. **ВАЖНО**: Скопируйте токен (он показывается только один раз!)

## Шаг 3: Сохранение токена

Сохраните токен в файл:
```powershell
"ВАШ_ТОКЕН" | Out-File -FilePath secrets/gitlab_token.txt -Encoding ASCII -NoNewline
```

Или вручную создайте файл `secrets/gitlab_token.txt` и вставьте токен.

## Шаг 4: Проверка токена

```powershell
$token = Get-Content secrets/gitlab_token.txt
$headers = @{"PRIVATE-TOKEN"=$token}
Invoke-RestMethod -Uri "http://localhost:8929/api/v4/version" -Headers $headers
```

Должен вернуться JSON с версией GitLab.

## Шаг 5: Создание проектов

После получения токена запустите:
```powershell
$env:GITLAB_TOKEN = Get-Content secrets/gitlab_token.txt
python scripts/init_gitlab.py
```

Это создаст проекты:
- `ut103-ci` - основная конфигурация 1С
- `ut103-external-files` - внешние файлы

## Альтернатива: Создание проектов вручную

Если скрипт не работает, создайте проекты вручную:

1. Нажмите **New project** (или **Create a project**)
2. Выберите **Create blank project**
3. Заполните:
   - **Project name**: `UT-103 CI`
   - **Project URL**: `ut103-ci`
   - **Visibility Level**: `Private`
   - ✅ **Initialize repository with a README**
4. Нажмите **Create project**
5. Повторите для второго проекта:
   - **Project name**: `UT-103 External Files`
   - **Project URL**: `ut103-external-files`

## Следующие шаги

После создания проектов:
1. Настроить CI/CD пайплайны
2. Добавить переменные окружения
3. Настроить webhooks
4. Интегрировать с Redmine и SonarQube
