@echo off
echo ========================================
echo Запуск объединенной CI/CD системы для 1С
echo ========================================
echo.

echo Проверка Docker...
docker --version >nul 2>&1
if errorlevel 1 (
    echo ✗ Docker не найден. Установите Docker Desktop.
    pause
    exit /b 1
)
echo ✓ Docker доступен

echo.
echo Проверка файла конфигурации...
if not exist "docker-compose-unified.yml" (
    echo ✗ Файл docker-compose-unified.yml не найден!
    pause
    exit /b 1
)
echo ✓ Файл конфигурации найден

echo.
echo Проверка хранилища 1С...
if not exist "C:\1crepository" (
    echo ⚠ Внимание: Хранилище 1С не найдено по пути C:\1crepository
    echo   Убедитесь, что путь указан правильно в docker-compose-unified.yml
)

echo.
echo Остановка существующих контейнеров...
docker-compose -f docker-compose-unified.yml down 2>nul
echo ✓ Существующие контейнеры остановлены

echo.
echo Создание сети cicd-network...
docker network create cicd-network 2>nul
echo ✓ Сеть создана или уже существует

echo.
echo Запуск всех сервисов...
echo Это может занять несколько минут...
docker-compose -f docker-compose-unified.yml up -d

if errorlevel 1 (
    echo ✗ Ошибка запуска сервисов
    echo Проверьте логи: docker-compose -f docker-compose-unified.yml logs
    pause
    exit /b 1
)

echo ✓ Все сервисы запущены

echo.
echo Ожидание инициализации сервисов (60 секунд)...
timeout /t 60 /nobreak >nul

echo.
echo Проверка статуса контейнеров...
docker-compose -f docker-compose-unified.yml ps

echo.
echo ========================================
echo Доступность сервисов:
echo ========================================
echo PostgreSQL: localhost:5433 (postgres / postgres_admin_123)
echo GitLab: http://localhost:8929 (root / gitlab_root_password)
echo Redmine: http://localhost:3000 (admin / admin)
echo SonarQube: http://localhost:9000 (admin / admin)
echo CI/CD Service: http://localhost:8080/health
echo.

echo Полезные команды:
echo   Просмотр логов: docker-compose -f docker-compose-unified.yml logs -f
echo   Остановка: docker-compose -f docker-compose-unified.yml down
echo   Перезапуск: docker-compose -f docker-compose-unified.yml restart [service_name]
echo.

echo ✓ Объединенная система запущена!
echo.
echo Примечания:
echo - GitLab может потребовать до 15 минут для полной инициализации
echo - SonarQube инициализируется 5-7 минут
echo - CI/CD Service начнет работу после готовности всех внешних сервисов
echo.

pause