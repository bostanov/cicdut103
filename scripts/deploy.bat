@echo off
setlocal enabledelayedexpansion

REM Скрипт развертывания контейнеризованной CI/CD системы для 1С

echo === Развертывание 1C CI/CD системы ===

REM Функция логирования
set "timestamp="
for /f "tokens=1-4 delims=/ " %%a in ('date /t') do set "timestamp=%%d-%%b-%%c"
for /f "tokens=1-2 delims=: " %%a in ('time /t') do set "timestamp=!timestamp! %%a:%%b"

REM Проверка требований
echo [%timestamp%] Проверка системных требований...

REM Проверка Docker
docker --version >nul 2>&1
if errorlevel 1 (
    echo ОШИБКА: Docker не установлен
    exit /b 1
)

REM Проверка Docker Compose
docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo ОШИБКА: Docker Compose не установлен
    exit /b 1
)

REM Проверка прав доступа к Docker
docker ps >nul 2>&1
if errorlevel 1 (
    echo ОШИБКА: Нет прав доступа к Docker. Запустите от имени администратора
    exit /b 1
)

echo [%timestamp%] Системные требования выполнены

REM Создание необходимых директорий
echo [%timestamp%] Создание необходимых директорий...

REM Создание директории для хранилища 1С (если не существует)
if not exist "C:\1crepository" (
    echo ВНИМАНИЕ: Директория C:\1crepository не существует
    echo Создание тестовой директории...
    mkdir "C:\1crepository"
    echo Тестовое хранилище 1С > "C:\1crepository\test.txt"
)

REM Создание директорий для логов
if not exist "logs" mkdir logs

echo [%timestamp%] Директории созданы

REM Сборка Docker образов
echo [%timestamp%] Сборка Docker образов...

docker-compose -f docker-compose-ci-cd.yml build --no-cache ci-cd-service
if errorlevel 1 (
    echo ОШИБКА: Не удалось собрать Docker образы
    exit /b 1
)

echo [%timestamp%] Docker образы собраны

REM Запуск сервисов
echo [%timestamp%] Запуск сервисов...

REM Остановка существующих контейнеров
docker-compose -f docker-compose-ci-cd.yml down

REM Запуск всех сервисов
docker-compose -f docker-compose-ci-cd.yml up -d
if errorlevel 1 (
    echo ОШИБКА: Не удалось запустить сервисы
    exit /b 1
)

echo [%timestamp%] Сервисы запущены

REM Проверка состояния сервисов
echo [%timestamp%] Проверка состояния сервисов...

REM Ожидание запуска сервисов
timeout /t 30 /nobreak >nul

REM Проверка CI/CD контейнера
docker ps | findstr "1c-ci-cd" >nul
if errorlevel 1 (
    echo ✗ CI/CD контейнер не запущен
    goto :error
) else (
    echo ✓ CI/CD контейнер запущен
)

REM Проверка health check
set /a attempt=1
set /a max_attempts=10

:health_check_loop
curl -f http://localhost:8080/health >nul 2>&1
if not errorlevel 1 (
    echo ✓ Health check прошел успешно
    goto :health_check_done
)

echo Попытка !attempt!/!max_attempts!: Health check не прошел, ожидание...
timeout /t 10 /nobreak >nul
set /a attempt+=1

if !attempt! leq !max_attempts! goto :health_check_loop

echo ✗ Health check не прошел после !max_attempts! попыток
goto :error

:health_check_done

REM Проверка других сервисов
docker ps | findstr "gitlab-ci" >nul
if not errorlevel 1 echo ✓ gitlab-ci запущен

docker ps | findstr "redmine-ci" >nul
if not errorlevel 1 echo ✓ redmine-ci запущен

docker ps | findstr "sonarqube-ci" >nul
if not errorlevel 1 echo ✓ sonarqube-ci запущен

echo [%timestamp%] Проверка состояния завершена

REM Отображение информации о доступе
echo === Информация о доступе к сервисам ===
echo.
echo CI/CD Health Check: http://localhost:8080/health
echo CI/CD Metrics:      http://localhost:8080/metrics
echo GitLab:             http://localhost:8929
echo Redmine:            http://localhost:3000
echo SonarQube:          http://localhost:9000
echo.
echo Логи CI/CD контейнера:
echo   docker logs 1c-ci-cd
echo.
echo Мониторинг всех контейнеров:
echo   docker-compose -f docker-compose-ci-cd.yml logs -f
echo.

echo ✓ Развертывание завершено успешно!
goto :end

:error
echo ✗ Развертывание завершено с ошибками
echo Проверьте логи контейнеров для диагностики
exit /b 1

:end
endlocal