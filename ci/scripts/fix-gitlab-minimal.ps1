# =============================================================================
# fix-gitlab-minimal.ps1
# Исправление GitLab с минимальной конфигурацией
# =============================================================================

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Fixing GitLab with Minimal Configuration" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Очистка существующих контейнеров
Write-Host "1. Cleaning up existing containers..." -ForegroundColor Yellow
docker stop gitlab 2>$null | Out-Null
docker rm gitlab 2>$null | Out-Null
Write-Host "   [OK] Existing containers cleaned" -ForegroundColor Green

# 2. Удаление старой конфигурации
Write-Host ""
Write-Host "2. Removing old configuration..." -ForegroundColor Yellow
$configFile = "C:\docker\gitlab\config\gitlab.rb"
if (Test-Path $configFile) {
    Remove-Item $configFile -Force
    Write-Host "   [OK] Old configuration removed" -ForegroundColor Green
}

# 3. Создание минимальной конфигурации
Write-Host ""
Write-Host "3. Creating minimal configuration..." -ForegroundColor Yellow

$minimalConfig = @"
# Minimal GitLab configuration
external_url 'http://$env:COMPUTERNAME:8929'
gitlab_rails['gitlab_shell_ssh_port'] = 2224

# Basic performance settings
postgresql['shared_buffers'] = "256MB"
postgresql['max_connections'] = 200

# Puma settings
puma['worker_processes'] = 2
puma['worker_timeout'] = 60

# Sidekiq settings
sidekiq['max_concurrency'] = 20
"@

$minimalConfig | Out-File -FilePath $configFile -Encoding UTF8
Write-Host "   [OK] Minimal configuration created" -ForegroundColor Green

# 4. Очистка данных для чистого запуска
Write-Host ""
Write-Host "4. Cleaning data for fresh start..." -ForegroundColor Yellow
$dataDir = "C:\docker\gitlab\data"
if (Test-Path $dataDir) {
    # Удаляем только проблемные директории, оставляем основные
    $problemDirs = @(
        "$dataDir\git-data",
        "$dataDir\gitlab-rails"
    )
    
    foreach ($dir in $problemDirs) {
        if (Test-Path $dir) {
            Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "   Removed: $dir" -ForegroundColor Gray
        }
    }
}
Write-Host "   [OK] Data cleaned" -ForegroundColor Green

# 5. Запуск GitLab с минимальной конфигурацией
Write-Host ""
Write-Host "5. Starting GitLab with minimal configuration..." -ForegroundColor Yellow

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
  --shm-size 512m `
  --restart unless-stopped `
  gitlab/gitlab-ce:latest

Write-Host "   [OK] GitLab started with minimal configuration" -ForegroundColor Green

# 6. Мониторинг запуска
Write-Host ""
Write-Host "6. Monitoring GitLab startup..." -ForegroundColor Yellow
Write-Host "   This may take 5-10 minutes for full initialization" -ForegroundColor Gray

$maxWait = 600 # 10 минут
$waitTime = 0
$checkInterval = 30

while ($waitTime -lt $maxWait) {
    Start-Sleep -Seconds $checkInterval
    $waitTime += $checkInterval
    
    $status = docker ps --filter "name=gitlab" --format "{{.Status}}" 2>$null
    if ($status -like "*Up*") {
        Write-Host "   [INFO] GitLab is running (waited $waitTime seconds)" -ForegroundColor Green
        
        # Проверяем логи на критические ошибки
        $errorCheck = docker logs gitlab --tail 20 2>&1 | Select-String -Pattern "FATAL|ERROR.*reconfigure|Exception.*reconfigure" | Select-Object -First 3
        if ($errorCheck) {
            Write-Host "   [WARN] Still seeing configuration errors:" -ForegroundColor Yellow
            $errorCheck | ForEach-Object { Write-Host "     $_" -ForegroundColor Red }
        } else {
            Write-Host "   [SUCCESS] No critical configuration errors detected" -ForegroundColor Green
            break
        }
    } else {
        Write-Host "   [INFO] Waiting for GitLab to start... ($waitTime/$maxWait seconds)" -ForegroundColor Gray
    }
}

# 7. Финальная проверка
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "FINAL STATUS" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

$finalStatus = docker ps --filter "name=gitlab" --format "{{.Status}}" 2>$null
if ($finalStatus -like "*Up*") {
    Write-Host "[SUCCESS] GitLab is running!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Access GitLab at: http://localhost:8929" -ForegroundColor Cyan
    Write-Host "Username: root" -ForegroundColor Gray
    Write-Host "Password: Gitlab123Admin!" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To monitor logs: docker logs gitlab --follow" -ForegroundColor Gray
    Write-Host "To check health: docker ps --filter name=gitlab" -ForegroundColor Gray
} else {
    Write-Host "[ERROR] GitLab failed to start properly" -ForegroundColor Red
    Write-Host ""
    Write-Host "Check logs: docker logs gitlab" -ForegroundColor Yellow
    Write-Host "Configuration file: C:\docker\gitlab\config\gitlab.rb" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Minimal Configuration Fix Complete" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

