@echo off
echo ========================================
echo Восстановление внешних сервисов CI/CD
echo ========================================
echo.

echo Проверка существующих контейнеров...
docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
echo.

echo Остановка существующих контейнеров (если есть)...
docker stop gitlab redmine sonarqube 2>nul
docker rm gitlab redmine sonarqube 2>nul
echo.

echo Создание сети cicd-network (если не существует)...
docker network create cicd-network 2>nul
echo.

echo Запуск внешних сервисов...
docker-compose -f docker-compose-external-services.yml up -d

echo.
echo Ожидание запуска сервисов...
timeout /t 30 /nobreak >nul

echo.
echo Проверка статуса сервисов...
docker-compose -f docker-compose-external-services.yml ps

echo.
echo ========================================
echo Проверка доступности сервисов:
echo ========================================
echo PostgreSQL: localhost:5433
echo GitLab: http://localhost:8929 (admin / gitlab_root_password)
echo Redmine: http://localhost:3000 (admin / admin)
echo SonarQube: http://localhost:9000 (admin / admin)
echo.

echo Для просмотра логов используйте:
echo docker-compose -f docker-compose-external-services.yml logs -f [service_name]
echo.

echo Восстановление завершено!
pause