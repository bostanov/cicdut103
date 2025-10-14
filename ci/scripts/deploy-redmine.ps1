# deploy-redmine.ps1 - Deploy Redmine in Docker
param(
    [string]$ContainerName = "redmine",
    [int]$Port = 3000,
    [string]$PostgresHost = "host.docker.internal",
    [int]$PostgresPort = 5432,
    [string]$PostgresDb = "redmine",
    [string]$PostgresUser = "redmine",
    [string]$PostgresPassword = "redmine"
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Stage 6: Redmine Deployment ===" -ForegroundColor Cyan

# 1. Check if container already exists
Write-Host "`n1. Checking existing container..." -ForegroundColor Yellow
$existing = docker ps -a --filter "name=$ContainerName" --format "{{.Names}}" 2>$null
if ($existing -eq $ContainerName) {
    Write-Host "Container $ContainerName already exists. Removing..." -ForegroundColor Yellow
    docker stop $ContainerName 2>$null | Out-Null
    docker rm $ContainerName 2>$null | Out-Null
    Write-Host "OK Container removed" -ForegroundColor Green
}

# 2. Pull Redmine image
Write-Host "`n2. Pulling Redmine image..." -ForegroundColor Yellow
$pullResult = docker pull redmine:5 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Could not pull image: $pullResult" -ForegroundColor Red
    exit 1
}
Write-Host "OK Image pulled: redmine:5" -ForegroundColor Green

# 3. Run Redmine container
Write-Host "`n3. Starting Redmine container..." -ForegroundColor Yellow
Write-Host "   NOTE: Redmine takes 1-2 minutes to initialize database" -ForegroundColor Gray

$cmd = @(
    "run", "-d",
    "--name", $ContainerName,
    "-p", "${Port}:3000",
    "-e", "REDMINE_DB_POSTGRES=$PostgresHost",
    "-e", "REDMINE_DB_PORT=$PostgresPort",
    "-e", "REDMINE_DB_DATABASE=$PostgresDb",
    "-e", "REDMINE_DB_USERNAME=$PostgresUser",
    "-e", "REDMINE_DB_PASSWORD=$PostgresPassword",
    "--restart", "unless-stopped",
    "redmine:5"
)

$containerId = docker @cmd 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Could not start container: $containerId" -ForegroundColor Red
    exit 1
}
Write-Host "OK Redmine container started: $ContainerName" -ForegroundColor Green
Write-Host "   Container ID: $containerId" -ForegroundColor Gray

# 4. Wait for Redmine to be ready
Write-Host "`n4. Waiting for Redmine to be ready (this takes 1-2 minutes)..." -ForegroundColor Yellow

$maxAttempts = 40
$attempt = 0
$ready = $false

while ($attempt -lt $maxAttempts -and -not $ready) {
    Start-Sleep -Seconds 5
    $attempt++
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:${Port}" -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            $ready = $true
            Write-Host "OK Redmine is ready (attempt $attempt)" -ForegroundColor Green
        }
    } catch {
        Write-Host "  Waiting... (attempt $attempt/$maxAttempts)" -ForegroundColor Gray
    }
}

if (-not $ready) {
    Write-Host "WARNING: Redmine did not respond in time, but container is running" -ForegroundColor Yellow
    Write-Host "         Check status with: docker logs redmine" -ForegroundColor Yellow
}

# 5. Save configuration
Write-Host "`n5. Saving configuration..." -ForegroundColor Yellow
$config = @{
    generatedAt = (Get-Date).ToString('s')
    container = $ContainerName
    url = "http://localhost:${Port}"
    port = $Port
    adminUsername = "admin"
    adminPassword = "admin"
    database = @{
        host = $PostgresHost
        port = $PostgresPort
        name = $PostgresDb
        user = $PostgresUser
    }
} | ConvertTo-Json -Depth 5

$auditDir = "build/audit"
if (-not (Test-Path $auditDir)) {
    New-Item -ItemType Directory -Path $auditDir -Force | Out-Null
}

$config | Out-File -FilePath "$auditDir/redmine-config.json" -Encoding UTF8 -Force
Write-Host "OK Configuration saved to: $auditDir/redmine-config.json" -ForegroundColor Green

Write-Host "`n=== Stage 6 completed ===" -ForegroundColor Cyan
Write-Host "Redmine container: $ContainerName" -ForegroundColor Gray
Write-Host "URL: http://localhost:${Port}" -ForegroundColor Gray
Write-Host "Default login: admin / admin" -ForegroundColor Gray
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Access Redmine at http://localhost:${Port}" -ForegroundColor Gray
Write-Host "2. Login as 'admin' / 'admin'" -ForegroundColor Gray
Write-Host "3. Change admin password in account settings" -ForegroundColor Gray
Write-Host "4. Enable REST API: Administration -> Settings -> API -> Enable REST web service" -ForegroundColor Gray
Write-Host "5. Generate API key: My account -> API access key -> Show" -ForegroundColor Gray


