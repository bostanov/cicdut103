# check-status.ps1 - Check CI/CD infrastructure status
$ErrorActionPreference = 'Continue'

Write-Host "=== CI/CD Infrastructure Status Check ===" -ForegroundColor Cyan
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# 1. Docker Images
Write-Host "1. Docker Images:" -ForegroundColor Yellow
try {
    $images = docker images --format "{{.Repository}}:{{.Tag}}" 2>$null
    $requiredImages = @("postgres:14", "gitlab/gitlab-ce:latest", "sonarqube:10.3-community")
    
    foreach ($img in $requiredImages) {
        $exists = $images -contains $img
        $status = if ($exists) { "OK" } else { "MISSING" }
        $color = if ($exists) { "Green" } else { "Red" }
        Write-Host "  $img : $status" -ForegroundColor $color
    }
} catch {
    Write-Host "  ERROR: Could not check Docker images" -ForegroundColor Red
}

# 2. Docker Containers
Write-Host "`n2. Docker Containers:" -ForegroundColor Yellow
try {
    $containers = docker ps -a --format "{{.Names}}\t{{.Status}}" 2>$null
    $requiredContainers = @("postgres_unified", "gitlab", "sonarqube")
    
    foreach ($name in $requiredContainers) {
        $status = ($containers | Select-String $name) -replace "$name\s+", ""
        if ($status) {
            $running = $status -match "Up"
            $color = if ($running) { "Green" } else { "Yellow" }
            Write-Host "  $name : $status" -ForegroundColor $color
        } else {
            Write-Host "  $name : NOT CREATED" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "  ERROR: Could not check containers" -ForegroundColor Red
}

# 3. Services
Write-Host "`n3. Service Endpoints:" -ForegroundColor Yellow
$endpoints = @(
    @{Name="PostgreSQL"; Url="localhost"; Port=5433},
    @{Name="GitLab"; Url="http://localhost:8929"; Port=8929},
    @{Name="SonarQube"; Url="http://localhost:9000"; Port=9000}
)

foreach ($ep in $endpoints) {
    try {
        $result = Test-NetConnection -ComputerName localhost -Port $ep.Port -WarningAction SilentlyContinue -InformationLevel Quiet -ErrorAction SilentlyContinue
        $status = if ($result) { "LISTENING" } else { "NOT AVAILABLE" }
        $color = if ($result) { "Green" } else { "Red" }
        Write-Host "  $($ep.Name) (port $($ep.Port)) : $status" -ForegroundColor $color
    } catch {
        Write-Host "  $($ep.Name) : ERROR" -ForegroundColor Red
    }
}

# 4. Tools
Write-Host "`n4. Installed Tools:" -ForegroundColor Yellow
$auditFile = "build/audit/tools.json"
if (Test-Path $auditFile) {
    $audit = Get-Content $auditFile | ConvertFrom-Json
    foreach ($tool in $audit.tools) {
        $status = if ($tool.present) { "INSTALLED" } else { "NOT INSTALLED" }
        $color = if ($tool.present) { "Green" } else { "Yellow" }
        Write-Host "  $($tool.name) : $status" -ForegroundColor $color
        if ($tool.version) {
            Write-Host "    Version: $($tool.version)" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "  Audit file not found. Run: ci/scripts/audit-tools.ps1" -ForegroundColor Red
}

# 5. Configuration Files
Write-Host "`n5. Configuration Files:" -ForegroundColor Yellow
$configs = @(
    "build/audit/postgres-config.json",
    "build/audit/gitlab-config.json",
    "build/audit/sonarqube-config.json",
    "ci/config/ci-settings.json",
    ".gitlab-ci.yml"
)

foreach ($cfg in $configs) {
    $exists = Test-Path $cfg
    $status = if ($exists) { "EXISTS" } else { "MISSING" }
    $color = if ($exists) { "Green" } else { "Yellow" }
    Write-Host "  $cfg : $status" -ForegroundColor $color
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "- If containers are not running, use deploy scripts in ci/scripts/" -ForegroundColor Gray
Write-Host "- If tools are missing, run: ci/scripts/install-tools.ps1" -ForegroundColor Gray
Write-Host "- Check detailed logs: docker logs <container-name>" -ForegroundColor Gray

