# =============================================================================
# fix-docker-network.ps1
# Исправление проблем с Docker сетью и портами
# =============================================================================

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Fixing Docker Network Issues" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Создать custom bridge network
Write-Host "1. Creating custom Docker network..." -ForegroundColor Yellow
$networkExists = docker network ls --filter "name=cicd-network" --format "{{.Name}}"

if ($networkExists -eq "cicd-network") {
    Write-Host "   [OK] Network already exists" -ForegroundColor Green
} else {
    docker network create cicd-network
    Write-Host "   [OK] Network 'cicd-network' created" -ForegroundColor Green
}

Write-Host ""
Write-Host "2. Checking port conflicts..." -ForegroundColor Yellow

# Проверка локального PostgreSQL
$localPostgres = Get-Process -Name postgres -ErrorAction SilentlyContinue
if ($localPostgres) {
    Write-Host "   [WARN] Local PostgreSQL is running on default port 5432" -ForegroundColor Yellow
    Write-Host "   [INFO] Container will use port 5433 to avoid conflict" -ForegroundColor Cyan
    $pgPort = "5433"
} else {
    Write-Host "   [OK] No local PostgreSQL detected, using port 5432" -ForegroundColor Green
    $pgPort = "5432"
}

Write-Host ""
Write-Host "3. Recreating containers in cicd-network..." -ForegroundColor Yellow

# Остановка всех контейнеров
Write-Host "   Stopping containers..." -ForegroundColor Gray
docker stop postgres_unified redmine sonarqube gitlab 2>$null | Out-Null
docker rm postgres_unified redmine sonarqube gitlab 2>$null | Out-Null

Write-Host ""
Write-Host "   [Step 1/4] Starting PostgreSQL on port $pgPort..." -ForegroundColor Gray

docker run -d `
  --name postgres_unified `
  --network cicd-network `
  -p "${pgPort}:5432" `
  -e POSTGRES_PASSWORD=postgres_admin_123 `
  -v "C:\docker\postgres\data:/var/lib/postgresql/data" `
  --restart unless-stopped `
  postgres:14

Start-Sleep -Seconds 5

# Создание баз данных
Write-Host "   Creating databases..." -ForegroundColor Gray
docker exec postgres_unified psql -U postgres -c "CREATE DATABASE sonar WITH ENCODING='UTF8';" 2>$null | Out-Null
docker exec postgres_unified psql -U postgres -c "CREATE USER sonar WITH PASSWORD 'sonar';" 2>$null | Out-Null
docker exec postgres_unified psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE sonar TO sonar;" 2>$null | Out-Null
docker exec postgres_unified psql -U postgres -d sonar -c "GRANT ALL ON SCHEMA public TO sonar;" 2>$null | Out-Null

docker exec postgres_unified psql -U postgres -c "CREATE DATABASE redmine WITH ENCODING='UTF8';" 2>$null | Out-Null
docker exec postgres_unified psql -U postgres -c "CREATE USER redmine WITH PASSWORD 'redmine';" 2>$null | Out-Null
docker exec postgres_unified psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE redmine TO redmine;" 2>$null | Out-Null
docker exec postgres_unified psql -U postgres -d redmine -c "GRANT ALL ON SCHEMA public TO redmine;" 2>$null | Out-Null

Write-Host "   [OK] PostgreSQL ready" -ForegroundColor Green

Write-Host ""
Write-Host "   [Step 2/4] Starting Redmine..." -ForegroundColor Gray

docker run -d `
  --name redmine `
  --network cicd-network `
  -p 3000:3000 `
  -e REDMINE_DB_POSTGRES=postgres_unified `
  -e REDMINE_DB_PORT=5432 `
  -e REDMINE_DB_DATABASE=redmine `
  -e REDMINE_DB_USERNAME=redmine `
  -e REDMINE_DB_PASSWORD=redmine `
  --restart unless-stopped `
  redmine:5

Write-Host "   [OK] Redmine started" -ForegroundColor Green

Write-Host ""
Write-Host "   [Step 3/4] Starting SonarQube..." -ForegroundColor Gray

docker run -d `
  --name sonarqube `
  --network cicd-network `
  -p 9000:9000 `
  -e SONAR_JDBC_URL="jdbc:postgresql://postgres_unified:5432/sonar" `
  -e SONAR_JDBC_USERNAME=sonar `
  -e SONAR_JDBC_PASSWORD=sonar `
  -v "C:\docker\sonarqube\data:/opt/sonarqube/data" `
  -v "C:\docker\sonarqube\logs:/opt/sonarqube/logs" `
  -v "C:\docker\sonarqube\extensions:/opt/sonarqube/extensions" `
  --restart unless-stopped `
  sonarqube:10.3-community

Write-Host "   [OK] SonarQube started" -ForegroundColor Green

Write-Host ""
Write-Host "   [Step 4/4] Starting GitLab..." -ForegroundColor Gray

$hostname = $env:COMPUTERNAME

docker run -d `
  --name gitlab `
  --network cicd-network `
  --hostname $hostname `
  -p 8929:80 `
  -p 2224:22 `
  -e GITLAB_ROOT_PASSWORD=Gitlab123Admin! `
  -e "GITLAB_OMNIBUS_CONFIG=external_url 'http://${hostname}:8929'; gitlab_rails['gitlab_shell_ssh_port'] = 2224;" `
  -v "C:\docker\gitlab\config:/etc/gitlab" `
  -v "C:\docker\gitlab\logs:/var/log/gitlab" `
  -v "C:\docker\gitlab\data:/var/opt/gitlab" `
  --shm-size 256m `
  --restart unless-stopped `
  gitlab/gitlab-ce:latest

Write-Host "   [OK] GitLab started (will take 3-5 min to initialize)" -ForegroundColor Green

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host ""
Write-Host "[SUCCESS] All containers recreated in cicd-network" -ForegroundColor Green
Write-Host ""
Write-Host "Container connections:" -ForegroundColor Yellow
Write-Host "  PostgreSQL:  localhost:$pgPort (external)" -ForegroundColor Gray
Write-Host "               postgres_unified:5432 (internal)" -ForegroundColor Gray
Write-Host "  GitLab:      http://localhost:8929" -ForegroundColor Gray
Write-Host "  SonarQube:   http://localhost:9000" -ForegroundColor Gray
Write-Host "  Redmine:     http://localhost:3000" -ForegroundColor Gray
Write-Host ""
Write-Host "Note: Services will take a few minutes to fully initialize" -ForegroundColor Gray
Write-Host "Use: .\ci\scripts\wait-for-services.ps1 to monitor readiness" -ForegroundColor Gray
Write-Host ""

# Сохранение конфигурации
$config = @{
    network = "cicd-network"
    postgresPort = $pgPort
    services = @{
        postgres = "postgres_unified"
        gitlab = "gitlab"
        sonarqube = "sonarqube"  
        redmine = "redmine"
    }
} | ConvertTo-Json

$config | Out-File "build/audit/docker-network-config.json" -Encoding UTF8
Write-Host "[INFO] Configuration saved to build/audit/docker-network-config.json" -ForegroundColor Gray

