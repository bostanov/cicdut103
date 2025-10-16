# =============================================================================
# wait-for-services.ps1
# Wait for all CI/CD services to be ready
# =============================================================================

param(
    [int]$TimeoutMinutes = 10,
    [switch]$Verbose
)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Waiting for CI/CD Services" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

function Wait-ForService {
    param(
        [string]$Name,
        [string]$Url,
        [scriptblock]$HealthCheck,
        [int]$TimeoutMinutes
    )
    
    Write-Host "Checking $Name ..." -ForegroundColor Yellow
    if ($Verbose) {
        Write-Host "  URL: $Url" -ForegroundColor Gray
    }
    
    $timeout = (Get-Date).AddMinutes($TimeoutMinutes)
    $attempts = 0
    
    while ((Get-Date) -lt $timeout) {
        $attempts++
        
        try {
            $result = & $HealthCheck
            if ($result) {
                Write-Host "[OK] $Name is ready (attempts: $attempts)" -ForegroundColor Green
                return $true
            }
        } catch {
            if ($Verbose) {
                Write-Host "  Attempt $attempts : $_" -ForegroundColor DarkGray
            }
        }
        
        if (($attempts % 3) -eq 0) {
            $elapsed = [Math]::Round(((Get-Date) - $timeout.AddMinutes($TimeoutMinutes)).TotalSeconds)
            Write-Host "  Waiting... (${elapsed}s elapsed, attempts: $attempts)" -ForegroundColor Gray
        }
        
        Start-Sleep -Seconds 10
    }
    
    Write-Host "[FAIL] $Name not ready after $TimeoutMinutes minutes (attempts: $attempts)" -ForegroundColor Red
    return $false
}

# Check Docker
Write-Host "Checking Docker..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version
    Write-Host "[OK] Docker running: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Docker not available!" -ForegroundColor Red
    exit 1
}
Write-Host ""

# PostgreSQL
Write-Host "================================================================" -ForegroundColor Cyan
$postgresReady = Wait-ForService -Name "PostgreSQL" -Url "localhost:5432" -TimeoutMinutes $TimeoutMinutes -HealthCheck {
    $result = docker exec postgres_unified pg_isready -U postgres 2>&1
    return $result -match "accepting connections"
}

Write-Host ""

# GitLab
Write-Host "================================================================" -ForegroundColor Cyan
$gitlabReady = Wait-ForService -Name "GitLab" -Url "http://localhost:8929" -TimeoutMinutes $TimeoutMinutes -HealthCheck {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8929/-/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

Write-Host ""

# SonarQube
Write-Host "================================================================" -ForegroundColor Cyan
$sonarReady = Wait-ForService -Name "SonarQube" -Url "http://localhost:9000" -TimeoutMinutes $TimeoutMinutes -HealthCheck {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9000/api/system/status" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        $status = ($response.Content | ConvertFrom-Json).status
        return $status -eq "UP"
    } catch {
        return $false
    }
}

Write-Host ""

# Redmine
Write-Host "================================================================" -ForegroundColor Cyan
$redmineReady = Wait-ForService -Name "Redmine" -Url "http://localhost:3000" -TimeoutMinutes $TimeoutMinutes -HealthCheck {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3000" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan

# Summary
$allReady = $postgresReady -and $gitlabReady -and $sonarReady -and $redmineReady

if ($allReady) {
    Write-Host ""
    Write-Host "[SUCCESS] All services are ready!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Available services:" -ForegroundColor Cyan
    Write-Host "  PostgreSQL:  localhost:5432" -ForegroundColor Gray
    Write-Host "  GitLab:      http://localhost:8929" -ForegroundColor Gray
    Write-Host "  SonarQube:   http://localhost:9000" -ForegroundColor Gray
    Write-Host "  Redmine:     http://localhost:3000" -ForegroundColor Gray
    Write-Host ""
    exit 0
} else {
    Write-Host ""
    Write-Host "[FAIL] Not all services are ready!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Services status:" -ForegroundColor Yellow
    Write-Host "  PostgreSQL: $(if ($postgresReady) {'[OK]'} else {'[FAIL]'})" -ForegroundColor $(if ($postgresReady) {'Green'} else {'Red'})
    Write-Host "  GitLab:     $(if ($gitlabReady) {'[OK]'} else {'[FAIL]'})" -ForegroundColor $(if ($gitlabReady) {'Green'} else {'Red'})
    Write-Host "  SonarQube:  $(if ($sonarReady) {'[OK]'} else {'[FAIL]'})" -ForegroundColor $(if ($sonarReady) {'Green'} else {'Red'})
    Write-Host "  Redmine:    $(if ($redmineReady) {'[OK]'} else {'[FAIL]'})" -ForegroundColor $(if ($redmineReady) {'Green'} else {'Red'})
    Write-Host ""
    Write-Host "Check container logs:" -ForegroundColor Yellow
    Write-Host "  docker logs postgres_unified" -ForegroundColor Gray
    Write-Host "  docker logs gitlab" -ForegroundColor Gray
    Write-Host "  docker logs sonarqube" -ForegroundColor Gray
    Write-Host "  docker logs redmine" -ForegroundColor Gray
    Write-Host ""
    exit 1
}
