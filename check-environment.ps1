# =============================================================================
# check-environment.ps1
# Comprehensive CI/CD Environment Check
# =============================================================================

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  CI/CD Environment Check for 1C" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = 'Continue'

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "1. Development Tools Check" -ForegroundColor Cyan
Write-Host ""

# 1C Platform
Write-Host "Checking: 1C Platform 8.3.12.1714" -ForegroundColor Yellow
$1cPath = "C:\Program Files\1cv8\8.3.12.1714\bin\1cv8.exe"
if (Test-Path $1cPath) {
    Write-Host "  [OK] 1C Platform found: $1cPath" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] 1C Platform not found" -ForegroundColor Red
}

# Git
Write-Host "Checking: Git" -ForegroundColor Yellow
try {
    $gitVer = git --version 2>$null
    Write-Host "  [OK] $gitVer" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Git not found" -ForegroundColor Red
}

# Docker
Write-Host "Checking: Docker" -ForegroundColor Yellow
try {
    $dockerVer = docker --version 2>$null
    Write-Host "  [OK] $dockerVer" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Docker not found" -ForegroundColor Red
}

# SonarScanner
Write-Host "Checking: SonarScanner" -ForegroundColor Yellow
$sonarPath = "C:\Tools\sonar-scanner\bin\sonar-scanner.bat"
if (Test-Path $sonarPath) {
    Write-Host "  [OK] SonarScanner found: $sonarPath" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] SonarScanner not found" -ForegroundColor Red
}

# GitLab Runner
Write-Host "Checking: GitLab Runner" -ForegroundColor Yellow
$runnerPath = "C:\Tools\gitlab-runner\gitlab-runner.exe"
if (Test-Path $runnerPath) {
    Write-Host "  [OK] GitLab Runner found: $runnerPath" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] GitLab Runner not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "2. Docker Containers Check" -ForegroundColor Cyan
Write-Host ""

$containers = @("postgres_unified", "gitlab", "sonarqube", "redmine")
foreach ($container in $containers) {
    $status = docker ps -a --filter "name=$container" --format "{{.Status}}" 2>$null
    if ($status -match "Up") {
        Write-Host "  [OK] $container : Running" -ForegroundColor Green
    } elseif ($status) {
        Write-Host "  [WARN] $container : Stopped" -ForegroundColor Yellow
    } else {
        Write-Host "  [FAIL] $container : Not found" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "3. Services Accessibility Check" -ForegroundColor Cyan
Write-Host ""

# GitLab
Write-Host "Checking: GitLab (http://localhost:8929)" -ForegroundColor Yellow
try {
    $null = Invoke-WebRequest -Uri "http://localhost:8929/-/health" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    Write-Host "  [OK] GitLab accessible" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] GitLab not accessible" -ForegroundColor Red
}

# SonarQube
Write-Host "Checking: SonarQube (http://localhost:9000)" -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:9000/api/system/status" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    $status = ($response.Content | ConvertFrom-Json).status
    Write-Host "  [OK] SonarQube status: $status" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] SonarQube not accessible" -ForegroundColor Red
}

# Redmine
Write-Host "Checking: Redmine (http://localhost:3000)" -ForegroundColor Yellow
try {
    $null = Invoke-WebRequest -Uri "http://localhost:3000" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    Write-Host "  [OK] Redmine accessible" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Redmine not accessible" -ForegroundColor Red
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "4. PATH Environment Check" -ForegroundColor Cyan
Write-Host ""

$pathsToCheck = @{
    "1C Platform" = "C:\Program Files\1cv8\8.3.12.1714\bin"
    "SonarScanner" = "C:\Tools\sonar-scanner\bin"
    "GitLab Runner" = "C:\Tools\gitlab-runner"
}

$pathMissing = 0
foreach ($entry in $pathsToCheck.GetEnumerator()) {
    $toolName = $entry.Key
    $toolPath = $entry.Value
    $inPath = $env:Path -split ';' | Where-Object { $_ -eq $toolPath }
    
    if ($inPath) {
        Write-Host "  [OK] $toolName in PATH" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $toolName NOT in PATH" -ForegroundColor Red
        $pathMissing++
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "RECOMMENDATIONS" -ForegroundColor Cyan
Write-Host ""

if ($pathMissing -gt 0) {
    Write-Host "[ACTION REQUIRED] Add tools to PATH:" -ForegroundColor Yellow
    Write-Host "  Run as Administrator:" -ForegroundColor Gray
    Write-Host "  .\fix-path-run-as-admin.bat" -ForegroundColor White
    Write-Host ""
}

if (-not (Test-Path $1cPath)) {
    Write-Host "[ACTION REQUIRED] Install 1C Platform 8.3.12.1714" -ForegroundColor Yellow
    Write-Host "  Download from 1C portal and install to standard path" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "Additional scripts available:" -ForegroundColor Cyan
Write-Host "  .\ci\scripts\install-bsl-plugin.ps1   - Install BSL plugin for SonarQube" -ForegroundColor Gray
Write-Host "  .\ci\scripts\wait-for-services.ps1    - Wait for services to be ready" -ForegroundColor Gray
Write-Host "  .\ci\scripts\backup-configs.ps1       - Backup configurations" -ForegroundColor Gray
Write-Host "  .\ci\scripts\register-runner-auto.ps1 - Register GitLab Runner" -ForegroundColor Gray
Write-Host ""

Write-Host "Check complete!" -ForegroundColor Green
