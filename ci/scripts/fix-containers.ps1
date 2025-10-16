# =============================================================================
# fix-containers.ps1
# Исправление проблем с контейнерами
# =============================================================================

param(
    [switch]$CheckOnly,
    [switch]$Verbose
)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Container Health Check and Fix" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$issues = @()
$fixes = @()

# Проверка PostgreSQL
Write-Host "Checking PostgreSQL..." -ForegroundColor Yellow
$pgStatus = docker ps -a --filter "name=postgres_unified" --format "{{.Status}}"
if ($pgStatus -match "Up") {
    Write-Host "  [OK] PostgreSQL running" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] PostgreSQL not running: $pgStatus" -ForegroundColor Red
    $issues += "PostgreSQL not running"
    $fixes += "docker start postgres_unified"
}

# Проверка Redmine
Write-Host "Checking Redmine..." -ForegroundColor Yellow
$redmineStatus = docker ps -a --filter "name=redmine" --format "{{.Status}}"
if ($redmineStatus -match "Up") {
    Write-Host "  [OK] Redmine running" -ForegroundColor Green
    
    # Проверка логов на ошибки подключения к БД
    $redmineLogs = docker logs redmine --tail 50 2>&1 | Select-String "password authentication failed"
    if ($redmineLogs) {
        Write-Host "  [WARN] Redmine has database connection issues" -ForegroundColor Yellow
        $issues += "Redmine database authentication"
        $fixes += @"
# Fix Redmine database connection:
docker exec postgres_unified psql -U postgres -c "ALTER USER redmine WITH PASSWORD 'redmine';"
docker restart redmine
"@
    }
} elseif ($redmineStatus -match "Restarting") {
    Write-Host "  [FAIL] Redmine is restarting (likely database issue)" -ForegroundColor Red
    $issues += "Redmine constantly restarting"
    $fixes += @"
# Fix Redmine:
docker stop redmine
docker rm redmine
docker run -d --name redmine -p 3000:3000 \
  -e REDMINE_DB_POSTGRES=postgres_unified \
  -e REDMINE_DB_PORT=5432 \
  -e REDMINE_DB_DATABASE=redmine \
  -e REDMINE_DB_USERNAME=redmine \
  -e REDMINE_DB_PASSWORD=redmine \
  --restart unless-stopped \
  redmine:5
"@
} else {
    Write-Host "  [FAIL] Redmine not running: $redmineStatus" -ForegroundColor Red
    $issues += "Redmine not running"
    $fixes += "docker start redmine"
}

# Проверка GitLab
Write-Host "Checking GitLab..." -ForegroundColor Yellow
$gitlabStatus = docker ps -a --filter "name=gitlab" --format "{{.Status}}"
if ($gitlabStatus -match "Up") {
    Write-Host "  [OK] GitLab running" -ForegroundColor Green
    
    # Проверка health status
    if ($gitlabStatus -match "health: starting") {
        Write-Host "  [INFO] GitLab still initializing (this is normal, takes 3-5 min)" -ForegroundColor Gray
    } elseif ($gitlabStatus -match "unhealthy") {
        Write-Host "  [WARN] GitLab is unhealthy" -ForegroundColor Yellow
        $issues += "GitLab unhealthy"
    }
    
    # Проверка ошибок прав доступа
    $gitlabLogs = docker logs gitlab --tail 100 2>&1 | Select-String "FATAL.*permission"
    if ($gitlabLogs) {
        Write-Host "  [WARN] GitLab has permission issues (may resolve automatically)" -ForegroundColor Yellow
        $issues += "GitLab permission issues"
        $fixes += @"
# Fix GitLab permissions (if persistent):
docker exec gitlab gitlab-ctl reconfigure
"@
    }
} else {
    Write-Host "  [FAIL] GitLab not running: $gitlabStatus" -ForegroundColor Red
    $issues += "GitLab not running"
    $fixes += "docker start gitlab"
}

# Проверка SonarQube
Write-Host "Checking SonarQube..." -ForegroundColor Yellow
$sonarStatus = docker ps -a --filter "name=sonarqube" --format "{{.Status}}"
if ($sonarStatus -match "Up") {
    Write-Host "  [OK] SonarQube running" -ForegroundColor Green
    
    # Проверка статуса через API
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9000/api/system/status" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        $status = ($response.Content | ConvertFrom-Json).status
        if ($status -eq "UP") {
            Write-Host "  [OK] SonarQube API status: UP" -ForegroundColor Green
        } else {
            Write-Host "  [INFO] SonarQube API status: $status" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  [INFO] SonarQube API not responding yet (still starting)" -ForegroundColor Gray
    }
} else {
    Write-Host "  [FAIL] SonarQube not running: $sonarStatus" -ForegroundColor Red
    $issues += "SonarQube not running"
    $fixes += "docker start sonarqube"
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host ""

if ($issues.Count -eq 0) {
    Write-Host "[SUCCESS] All containers are healthy!" -ForegroundColor Green
} else {
    Write-Host "[ISSUES FOUND] $($issues.Count) problem(s) detected:" -ForegroundColor Yellow
    $issues | ForEach-Object {
        Write-Host "  • $_" -ForegroundColor Yellow
    }
}

Write-Host ""

if ($fixes.Count -gt 0 -and -not $CheckOnly) {
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "RECOMMENDED FIXES" -ForegroundColor Cyan
    Write-Host ""
    
    $fixes | ForEach-Object {
        Write-Host $_ -ForegroundColor Gray
        Write-Host ""
    }
    
    $apply = Read-Host "Apply automatic fixes? (y/n)"
    if ($apply -eq 'y') {
        Write-Host ""
        Write-Host "Applying fixes..." -ForegroundColor Yellow
        
        # Применение базовых фиксов (запуск остановленных контейнеров)
        foreach ($fix in $fixes) {
            if ($fix -like "docker start*" -or $fix -like "docker restart*") {
                Write-Host "  Running: $fix" -ForegroundColor Gray
                Invoke-Expression $fix
            }
        }
        
        Write-Host ""
        Write-Host "[DONE] Basic fixes applied. Check complex fixes manually." -ForegroundColor Green
    }
} elseif ($CheckOnly) {
    Write-Host "[INFO] Check-only mode. No fixes applied." -ForegroundColor Gray
}

Write-Host ""
Write-Host "For detailed logs, run:" -ForegroundColor Cyan
Write-Host "  docker logs [container_name] --tail 100" -ForegroundColor Gray
Write-Host ""

