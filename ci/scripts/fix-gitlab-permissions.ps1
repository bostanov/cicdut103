# =============================================================================
# fix-gitlab-permissions.ps1
# Исправление проблем с правами доступа GitLab
# =============================================================================

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Fixing GitLab Permissions" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Остановка GitLab контейнера
Write-Host "1. Stopping GitLab container..." -ForegroundColor Yellow
docker stop gitlab 2>$null | Out-Null
Write-Host "   [OK] GitLab stopped" -ForegroundColor Green

# 2. Удаление контейнера
Write-Host ""
Write-Host "2. Removing GitLab container..." -ForegroundColor Yellow
docker rm gitlab 2>$null | Out-Null
Write-Host "   [OK] GitLab container removed" -ForegroundColor Green

# 3. Проверка и создание директорий
Write-Host ""
Write-Host "3. Preparing GitLab directories..." -ForegroundColor Yellow

$gitlabDirs = @(
    "C:\docker\gitlab\config",
    "C:\docker\gitlab\logs", 
    "C:\docker\gitlab\data"
)

foreach ($dir in $gitlabDirs) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "   Created: $dir" -ForegroundColor Gray
    } else {
        Write-Host "   Exists: $dir" -ForegroundColor Gray
    }
}

# 4. Создание временного контейнера для исправления прав
Write-Host ""
Write-Host "4. Creating temporary container to fix permissions..." -ForegroundColor Yellow

# Запускаем временный контейнер с теми же volume'ами
docker run -d --name gitlab-temp `
  --network cicd-network `
  --hostname $env:COMPUTERNAME `
  -e GITLAB_ROOT_PASSWORD=Gitlab123Admin! `
  -e "GITLAB_OMNIBUS_CONFIG=external_url 'http://${env:COMPUTERNAME}:8929'; gitlab_rails['gitlab_shell_ssh_port'] = 2224;" `
  -v "C:\docker\gitlab\config:/etc/gitlab" `
  -v "C:\docker\gitlab\logs:/var/log/gitlab" `
  -v "C:\docker\gitlab\data:/var/opt/gitlab" `
  --shm-size 256m `
  gitlab/gitlab-ce:latest

Start-Sleep -Seconds 10

# 5. Исправление прав доступа
Write-Host ""
Write-Host "5. Fixing permissions..." -ForegroundColor Yellow

# Выполняем команду update-permissions внутри контейнера
$permissionResult = docker exec gitlab-temp update-permissions 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   [OK] Permissions updated successfully" -ForegroundColor Green
} else {
    Write-Host "   [WARN] Permission update had issues, but continuing..." -ForegroundColor Yellow
    Write-Host "   Output: $permissionResult" -ForegroundColor Gray
}

# 6. Остановка временного контейнера
Write-Host ""
Write-Host "6. Cleaning up temporary container..." -ForegroundColor Yellow
docker stop gitlab-temp 2>$null | Out-Null
docker rm gitlab-temp 2>$null | Out-Null
Write-Host "   [OK] Temporary container removed" -ForegroundColor Green

# 7. Запуск GitLab с исправленными правами
Write-Host ""
Write-Host "7. Starting GitLab with fixed permissions..." -ForegroundColor Yellow

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

Write-Host "   [OK] GitLab started with fixed permissions" -ForegroundColor Green

# 8. Мониторинг запуска
Write-Host ""
Write-Host "8. Monitoring GitLab startup..." -ForegroundColor Yellow
Write-Host "   This may take 3-5 minutes for full initialization" -ForegroundColor Gray

$maxWait = 300 # 5 минут
$waitTime = 0
$checkInterval = 10

while ($waitTime -lt $maxWait) {
    Start-Sleep -Seconds $checkInterval
    $waitTime += $checkInterval
    
    $status = docker ps --filter "name=gitlab" --format "{{.Status}}" 2>$null
    if ($status -like "*Up*") {
        Write-Host "   [INFO] GitLab is running (waited $waitTime seconds)" -ForegroundColor Green
        
        # Проверяем логи на ошибки
        $errorCheck = docker logs gitlab --tail 20 2>&1 | Select-String -Pattern "FATAL|ERROR|Exception" | Select-Object -First 3
        if ($errorCheck) {
            Write-Host "   [WARN] Still seeing errors in logs:" -ForegroundColor Yellow
            $errorCheck | ForEach-Object { Write-Host "     $_" -ForegroundColor Red }
        } else {
            Write-Host "   [SUCCESS] No critical errors in recent logs" -ForegroundColor Green
            break
        }
    } else {
        Write-Host "   [INFO] Waiting for GitLab to start... ($waitTime/$maxWait seconds)" -ForegroundColor Gray
    }
}

# 9. Финальная проверка
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
} else {
    Write-Host "[ERROR] GitLab failed to start properly" -ForegroundColor Red
    Write-Host ""
    Write-Host "Check logs: docker logs gitlab" -ForegroundColor Yellow
    Write-Host "Try manual fix: docker exec -it gitlab update-permissions" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Permission Fix Complete" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

