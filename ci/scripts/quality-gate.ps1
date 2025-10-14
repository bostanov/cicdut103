# quality-gate.ps1 - Check SonarQube Quality Gate
param(
    [string]$SonarUrl = "http://localhost:9000",
    [string]$SonarToken,
    [string]$ProjectKey = "ut103",
    [int]$TimeoutSeconds = 300,
    [int]$PollIntervalSeconds = 10
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Checking SonarQube Quality Gate ===" -ForegroundColor Cyan

# Prepare authentication
$base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${SonarToken}:"))
$headers = @{
    Authorization = "Basic $base64Auth"
}

# Wait for analysis to complete
Write-Host "Waiting for analysis to complete..." -ForegroundColor Yellow
$startTime = Get-Date
$analysisComplete = $false

while (-not $analysisComplete -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
    try {
        $response = Invoke-RestMethod -Uri "$SonarUrl/api/ce/component?component=$ProjectKey" -Headers $headers -Method Get
        
        if ($response.queue.Count -eq 0 -or $response.current.status -eq "SUCCESS") {
            $analysisComplete = $true
            Write-Host "Analysis completed" -ForegroundColor Green
        } elseif ($response.current.status -eq "FAILED") {
            throw "SonarQube analysis failed"
        } else {
            Write-Host "  Analysis in progress... ($($response.current.status))" -ForegroundColor Gray
            Start-Sleep -Seconds $PollIntervalSeconds
        }
    } catch {
        Write-Host "  Waiting for analysis to start..." -ForegroundColor Gray
        Start-Sleep -Seconds $PollIntervalSeconds
    }
}

if (-not $analysisComplete) {
    throw "Timeout waiting for analysis to complete"
}

# Get Quality Gate status
Write-Host "Fetching Quality Gate status..." -ForegroundColor Yellow

try {
    $qgResponse = Invoke-RestMethod -Uri "$SonarUrl/api/qualitygates/project_status?projectKey=$ProjectKey" -Headers $headers -Method Get
    
    $qgStatus = $qgResponse.projectStatus.status
    Write-Host "Quality Gate Status: $qgStatus" -ForegroundColor $(if ($qgStatus -eq "OK") { "Green" } else { "Red" })
    
    if ($qgResponse.projectStatus.conditions) {
        Write-Host "`nConditions:" -ForegroundColor Yellow
        foreach ($condition in $qgResponse.projectStatus.conditions) {
            $symbol = if ($condition.status -eq "OK") { "✓" } else { "✗" }
            $color = if ($condition.status -eq "OK") { "Green" } else { "Red" }
            Write-Host "  $symbol $($condition.metricKey): $($condition.actualValue) (threshold: $($condition.errorThreshold))" -ForegroundColor $color
        }
    }
    
    Write-Host "`nDashboard: $SonarUrl/dashboard?id=$ProjectKey" -ForegroundColor Gray
    
    if ($qgStatus -ne "OK") {
        throw "Quality Gate failed: $qgStatus"
    }
    
    Write-Host "=== Quality Gate PASSED ===" -ForegroundColor Green
    
} catch {
    Write-Host "=== Quality Gate FAILED ===" -ForegroundColor Red
    throw $_
}

