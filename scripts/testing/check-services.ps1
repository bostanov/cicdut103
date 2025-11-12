# Простая проверка доступности сервисов
# Автор: Бостанов Ф.А.

param(
    [int]$TimeoutSec = 5
)

$services = @{
    "PostgreSQL" = @{ Host = "localhost"; Port = 5433 }
    "Redmine"    = @{ Url = "http://localhost:3000" }
    "GitLab"     = @{ Url = "http://localhost:8929/-/health" }
    "SonarQube"  = @{ Url = "http://localhost:9000/api/system/status" }
}

Write-Host "`n=== ПРОВЕРКА ДОСТУПНОСТИ СЕРВИСОВ ===" -ForegroundColor Cyan
Write-Host "Время ожидания: $TimeoutSec секунд`n" -ForegroundColor Gray

$results = @{}

foreach ($name in $services.Keys | Sort-Object) {
    $service = $services[$name]
    
    Write-Host "[$name] " -NoNewline
    
    try {
        if ($service.Url) {
            # HTTP проверка
            $response = Invoke-WebRequest -Uri $service.Url -TimeoutSec $TimeoutSec -UseBasicParsing -ErrorAction Stop
            Write-Host "✅ Доступен (HTTP $($response.StatusCode))" -ForegroundColor Green
            $results[$name] = $true
        }
        elseif ($service.Port) {
            # TCP проверка
            $connection = Test-NetConnection -ComputerName $service.Host -Port $service.Port -WarningAction SilentlyContinue -ErrorAction Stop
            if ($connection.TcpTestSucceeded) {
                Write-Host "✅ Доступен (Port $($service.Port))" -ForegroundColor Green
                $results[$name] = $true
            } else {
                Write-Host "❌ Недоступен (Port $($service.Port))" -ForegroundColor Red
                $results[$name] = $false
            }
        }
    }
    catch {
        Write-Host "❌ Недоступен" -ForegroundColor Red
        $results[$name] = $false
    }
}

Write-Host "`n=== ИТОГО ===" -ForegroundColor Cyan
$available = ($results.Values | Where-Object { $_ -eq $true }).Count
$total = $results.Count
$percentage = [math]::Round(($available / $total) * 100, 0)

Write-Host "Доступно: $available из $total ($percentage%)" -ForegroundColor $(if ($percentage -ge 75) { "Green" } elseif ($percentage -ge 50) { "Yellow" } else { "Red" })

return $results

