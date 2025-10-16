# =============================================================================
# fix-gitlab-restart.ps1
# Диагностика и исправление проблем с перезагрузкой GitLab контейнера
# =============================================================================

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  GitLab Container Restart Fix" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Проверка текущего состояния
Write-Host "1. Checking current container status..." -ForegroundColor Yellow
$gitlabStatus = docker ps -a --filter "name=gitlab" --format "{{.Status}}"
Write-Host "   GitLab Status: $gitlabStatus" -ForegroundColor Gray

if ($gitlabStatus -like "*Up*") {
    Write-Host "   [INFO] GitLab is running" -ForegroundColor Green
} else {
    Write-Host "   [WARN] GitLab is not running" -ForegroundColor Yellow
}

# 2. Проверка использования ресурсов
Write-Host ""
Write-Host "2. Checking resource usage..." -ForegroundColor Yellow
$stats = docker stats gitlab --no-stream --format "{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}}" 2>$null
if ($stats) {
    $cpu, $mem, $memPerc = $stats -split ","
    Write-Host "   CPU Usage: $cpu" -ForegroundColor Gray
    Write-Host "   Memory Usage: $mem ($memPerc)" -ForegroundColor Gray
    
    # Проверка критических значений
    $cpuValue = [double]($cpu -replace "%", "")
    $memPercValue = [double]($memPerc -replace "%", "")
    
    if ($cpuValue -gt 200) {
        Write-Host "   [WARN] High CPU usage detected" -ForegroundColor Yellow
    }
    if ($memPercValue -gt 80) {
        Write-Host "   [WARN] High memory usage detected" -ForegroundColor Yellow
    }
}

# 3. Проверка логов на ошибки
Write-Host ""
Write-Host "3. Analyzing logs for errors..." -ForegroundColor Yellow
$errorLogs = docker logs gitlab --tail 200 2>&1 | Select-String -Pattern "error|Error|ERROR|fail|Fail|FAIL|exception|Exception|EXCEPTION" | Select-Object -First 10
if ($errorLogs) {
    Write-Host "   [WARN] Found potential errors in logs:" -ForegroundColor Yellow
    $errorLogs | ForEach-Object { Write-Host "     $_" -ForegroundColor Red }
} else {
    Write-Host "   [OK] No critical errors found in recent logs" -ForegroundColor Green
}

# 4. Проверка доступности портов
Write-Host ""
Write-Host "4. Checking port availability..." -ForegroundColor Yellow
$port8929 = Get-NetTCPConnection -LocalPort 8929 -ErrorAction SilentlyContinue
$port2224 = Get-NetTCPConnection -LocalPort 2224 -ErrorAction SilentlyContinue

if ($port8929) {
    Write-Host "   [OK] Port 8929 is in use (GitLab HTTP)" -ForegroundColor Green
} else {
    Write-Host "   [WARN] Port 8929 is not in use" -ForegroundColor Yellow
}

if ($port2224) {
    Write-Host "   [OK] Port 2224 is in use (GitLab SSH)" -ForegroundColor Green
} else {
    Write-Host "   [WARN] Port 2224 is not in use" -ForegroundColor Yellow
}

# 5. Проверка дискового пространства
Write-Host ""
Write-Host "5. Checking disk space..." -ForegroundColor Yellow
$diskSpace = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'" | Select-Object Size, FreeSpace
$freeSpaceGB = [math]::Round($diskSpace.FreeSpace / 1GB, 2)
$totalSpaceGB = [math]::Round($diskSpace.Size / 1GB, 2)
$usedSpacePercent = [math]::Round((($diskSpace.Size - $diskSpace.FreeSpace) / $diskSpace.Size) * 100, 2)

Write-Host "   Free Space: $freeSpaceGB GB / $totalSpaceGB GB ($usedSpacePercent% used)" -ForegroundColor Gray

if ($freeSpaceGB -lt 5) {
    Write-Host "   [WARN] Low disk space detected!" -ForegroundColor Yellow
} else {
    Write-Host "   [OK] Sufficient disk space available" -ForegroundColor Green
}

# 6. Проверка Docker сети
Write-Host ""
Write-Host "6. Checking Docker network..." -ForegroundColor Yellow
$networkExists = docker network ls --filter "name=cicd-network" --format "{{.Name}}"
if ($networkExists -eq "cicd-network") {
    Write-Host "   [OK] cicd-network exists" -ForegroundColor Green
} else {
    Write-Host "   [WARN] cicd-network not found" -ForegroundColor Yellow
}

# 7. Проверка зависимостей (PostgreSQL)
Write-Host ""
Write-Host "7. Checking dependencies..." -ForegroundColor Yellow
$postgresStatus = docker ps --filter "name=postgres_unified" --format "{{.Status}}"
if ($postgresStatus -like "*Up*") {
    Write-Host "   [OK] PostgreSQL is running" -ForegroundColor Green
} else {
    Write-Host "   [ERROR] PostgreSQL is not running!" -ForegroundColor Red
    Write-Host "   [INFO] GitLab requires PostgreSQL to function" -ForegroundColor Cyan
}

# 8. Рекомендации по исправлению
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "DIAGNOSTIC SUMMARY" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

$issues = @()

if ($freeSpaceGB -lt 5) {
    $issues += "Low disk space"
}

if ($memPercValue -gt 80) {
    $issues += "High memory usage"
}

if ($cpuValue -gt 200) {
    $issues += "High CPU usage"
}

if ($postgresStatus -notlike "*Up*") {
    $issues += "PostgreSQL not running"
}

if ($issues.Count -eq 0) {
    Write-Host "[SUCCESS] No critical issues detected" -ForegroundColor Green
    Write-Host ""
    Write-Host "GitLab should be working normally. If it's still restarting:" -ForegroundColor Cyan
    Write-Host "1. Wait 5-10 minutes for full initialization" -ForegroundColor Gray
    Write-Host "2. Check logs: docker logs gitlab --follow" -ForegroundColor Gray
    Write-Host "3. Access GitLab at: http://localhost:8929" -ForegroundColor Gray
} else {
    Write-Host "[WARN] Issues detected:" -ForegroundColor Yellow
    $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host ""
    Write-Host "RECOMMENDED ACTIONS:" -ForegroundColor Cyan
    
    if ($issues -contains "Low disk space") {
        Write-Host "1. Free up disk space (at least 5GB recommended)" -ForegroundColor Gray
    }
    
    if ($issues -contains "PostgreSQL not running") {
        Write-Host "2. Start PostgreSQL: docker start postgres_unified" -ForegroundColor Gray
    }
    
    if ($issues -contains "High memory usage" -or $issues -contains "High CPU usage") {
        Write-Host "3. Restart GitLab with more resources:" -ForegroundColor Gray
        Write-Host "   docker stop gitlab" -ForegroundColor Gray
        Write-Host "   docker rm gitlab" -ForegroundColor Gray
        Write-Host "   .\ci\scripts\fix-docker-network.ps1" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Diagnostic Complete" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
