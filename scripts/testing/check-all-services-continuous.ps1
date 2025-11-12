# Непрерывная проверка всех сервисов до полной готовности
# Автор: Бостанов Ф.А.

param(
    [int]$CheckIntervalSec = 10,
    [int]$MaxWaitMinutes = 15
)

$startTime = Get-Date
$maxWaitTime = $startTime.AddMinutes($MaxWaitMinutes)
$iteration = 0

Write-Host "=== НЕПРЕРЫВНАЯ ПРОВЕРКА СЕРВИСОВ ===" -ForegroundColor Cyan
Write-Host "Интервал проверки: $CheckIntervalSec секунд" -ForegroundColor Yellow
Write-Host "Максимальное время ожидания: $MaxWaitMinutes минут`n" -ForegroundColor Yellow

$allReady = $false

while ((Get-Date) -lt $maxWaitTime) {
    $iteration++
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
    
    Write-Host "[$elapsed мин] Проверка #$iteration" -ForegroundColor Cyan
    Write-Host ("-" * 60) -ForegroundColor Gray
    
    $results = @{}
    
    # PostgreSQL
    try {
        $pg = Test-NetConnection -ComputerName localhost -Port 5433 -WarningAction SilentlyContinue -ErrorAction Stop
        $results["PostgreSQL"] = $pg.TcpTestSucceeded
        Write-Host "[PostgreSQL] $(if ($pg.TcpTestSucceeded) { '✅' } else { '❌' })" -ForegroundColor $(if ($pg.TcpTestSucceeded) { 'Green' } else { 'Red' })
    } catch {
        $results["PostgreSQL"] = $false
        Write-Host "[PostgreSQL] ❌" -ForegroundColor Red
    }
    
    # Redmine
    try {
        $rm = Invoke-WebRequest -Uri "http://localhost:3000" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        $results["Redmine"] = $true
        Write-Host "[Redmine] ✅ HTTP $($rm.StatusCode)" -ForegroundColor Green
    } catch {
        $results["Redmine"] = $false
        Write-Host "[Redmine] ⏳ Инициализация" -ForegroundColor Yellow
    }
    
    # GitLab
    try {
        $gl = Invoke-WebRequest -Uri "http://localhost:8929/-/health" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        $results["GitLab"] = $true
        Write-Host "[GitLab] ✅ HTTP $($gl.StatusCode)" -ForegroundColor Green
    } catch {
        $results["GitLab"] = $false
        Write-Host "[GitLab] ⏳ Инициализация" -ForegroundColor Yellow
    }
    
    # SonarQube
    try {
        $sq = Invoke-WebRequest -Uri "http://localhost:9000/api/system/status" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        $results["SonarQube"] = $true
        Write-Host "[SonarQube] ✅ HTTP $($sq.StatusCode)" -ForegroundColor Green
    } catch {
        $results["SonarQube"] = $false
        Write-Host "[SonarQube] ⏳ Инициализация" -ForegroundColor Yellow
    }
    
    # Итоги
    $ready = ($results.Values | Where-Object { $_ -eq $true }).Count
    $total = $results.Count
    $percentage = [math]::Round(($ready / $total) * 100, 0)
    
    Write-Host ("-" * 60) -ForegroundColor Gray
    Write-Host "Готово: $ready из $total ($percentage%)" -ForegroundColor $(if ($percentage -eq 100) { 'Green' } elseif ($percentage -ge 75) { 'Yellow' } else { 'Red' })
    
    if ($ready -eq $total) {
        Write-Host "`n✅ ВСЕ СЕРВИСЫ ГОТОВЫ!" -ForegroundColor Green
        $allReady = $true
        break
    }
    
    Write-Host "Следующая проверка через $CheckIntervalSec секунд...`n" -ForegroundColor Gray
    Start-Sleep -Seconds $CheckIntervalSec
}

if (-not $allReady) {
    Write-Host "`n⚠️  Не все сервисы готовы после $MaxWaitMinutes минут" -ForegroundColor Yellow
    Write-Host "Проверьте логи: docker logs <container-name>" -ForegroundColor Yellow
    return $false
}

return $true

