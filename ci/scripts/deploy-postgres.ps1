# deploy-postgres.ps1 - Deploy PostgreSQL in Docker
param(
    [string]$ContainerName = "postgres_unified",
    [int]$Port = 5432,
    [string]$DataPath = "C:\docker\postgres\data",
    [string]$PostgresPassword = "postgres_admin_123",
    [string]$SonarDb = "sonar",
    [string]$SonarUser = "sonar",
    [string]$SonarPassword = "sonar",
    [string]$RedmineDb = "redmine",
    [string]$RedmineUser = "redmine",
    [string]$RedminePassword = "redmine"
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Stage 2: PostgreSQL Deployment ===" -ForegroundColor Cyan

# 1. Check if container already exists
Write-Host "`n1. Checking existing container..." -ForegroundColor Yellow
$existing = docker ps -a --filter "name=$ContainerName" --format "{{.Names}}" 2>$null
if ($existing -eq $ContainerName) {
    Write-Host "Container $ContainerName already exists. Removing..." -ForegroundColor Yellow
    docker stop $ContainerName 2>$null | Out-Null
    docker rm $ContainerName 2>$null | Out-Null
    Write-Host "OK Container removed" -ForegroundColor Green
}

# 2. Create data directory
Write-Host "`n2. Creating data directory..." -ForegroundColor Yellow
if (-not (Test-Path $DataPath)) {
    New-Item -ItemType Directory -Path $DataPath -Force | Out-Null
    Write-Host "OK Directory created: $DataPath" -ForegroundColor Green
} else {
    Write-Host "OK Directory already exists: $DataPath" -ForegroundColor Green
}

# 3. Pull PostgreSQL image
Write-Host "`n3. Pulling PostgreSQL image..." -ForegroundColor Yellow
$pullResult = docker pull postgres:14 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Could not pull image: $pullResult" -ForegroundColor Red
    exit 1
}
Write-Host "OK Image pulled: postgres:14" -ForegroundColor Green

# 4. Run PostgreSQL container
Write-Host "`n4. Starting PostgreSQL container..." -ForegroundColor Yellow
$cmd = @(
    "run", "-d",
    "--name", $ContainerName,
    "-p", "${Port}:5432",
    "-e", "POSTGRES_PASSWORD=$PostgresPassword",
    "-v", "${DataPath}:/var/lib/postgresql/data",
    "--restart", "unless-stopped",
    "postgres:14"
)

$containerId = docker @cmd 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Could not start container: $containerId" -ForegroundColor Red
    exit 1
}
Write-Host "OK PostgreSQL container started: $ContainerName" -ForegroundColor Green
Write-Host "   Container ID: $containerId" -ForegroundColor Gray

# 5. Wait for PostgreSQL to be ready
Write-Host "`n5. Waiting for PostgreSQL to be ready..." -ForegroundColor Yellow
$maxAttempts = 30
$attempt = 0
$ready = $false

while ($attempt -lt $maxAttempts -and -not $ready) {
    Start-Sleep -Seconds 2
    $attempt++
    
    $result = docker exec $ContainerName pg_isready -U postgres 2>&1
    if ($LASTEXITCODE -eq 0) {
        $ready = $true
        Write-Host "OK PostgreSQL is ready (attempt $attempt)" -ForegroundColor Green
    } else {
        Write-Host "  Waiting... (attempt $attempt/$maxAttempts)" -ForegroundColor Gray
    }
}

if (-not $ready) {
    Write-Host "FAILED: PostgreSQL did not start in time" -ForegroundColor Red
    exit 1
}

# 6. Create databases and users
Write-Host "`n6. Creating databases and users..." -ForegroundColor Yellow

# Create SonarQube database
Write-Host "  Creating database: $SonarDb" -ForegroundColor Gray
docker exec $ContainerName psql -U postgres -c "CREATE DATABASE $SonarDb WITH ENCODING='UTF8';" 2>&1 | Out-Null
docker exec $ContainerName psql -U postgres -c "CREATE USER $SonarUser WITH PASSWORD '$SonarPassword';" 2>&1 | Out-Null
docker exec $ContainerName psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE $SonarDb TO $SonarUser;" 2>&1 | Out-Null
docker exec $ContainerName psql -U postgres -d $SonarDb -c "GRANT ALL ON SCHEMA public TO $SonarUser;" 2>&1 | Out-Null
Write-Host "  OK Database $SonarDb created" -ForegroundColor Green

# Create Redmine database
Write-Host "  Creating database: $RedmineDb" -ForegroundColor Gray
docker exec $ContainerName psql -U postgres -c "CREATE DATABASE $RedmineDb WITH ENCODING='UTF8';" 2>&1 | Out-Null
docker exec $ContainerName psql -U postgres -c "CREATE USER $RedmineUser WITH PASSWORD '$RedminePassword';" 2>&1 | Out-Null
docker exec $ContainerName psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE $RedmineDb TO $RedmineUser;" 2>&1 | Out-Null
docker exec $ContainerName psql -U postgres -d $RedmineDb -c "GRANT ALL ON SCHEMA public TO $RedmineUser;" 2>&1 | Out-Null
Write-Host "  OK Database $RedmineDb created" -ForegroundColor Green

# 7. Verify databases
Write-Host "`n7. Verifying databases..." -ForegroundColor Yellow

$sonarCheck = docker exec $ContainerName psql -U $SonarUser -d $SonarDb -c "SELECT 1;" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK SonarQube database accessible" -ForegroundColor Green
} else {
    Write-Host "  WARNING: SonarQube database check failed" -ForegroundColor Yellow
}

$redmineCheck = docker exec $ContainerName psql -U $RedmineUser -d $RedmineDb -c "SELECT 1;" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK Redmine database accessible" -ForegroundColor Green
} else {
    Write-Host "  WARNING: Redmine database check failed" -ForegroundColor Yellow
}

# 8. Save configuration
Write-Host "`n8. Saving configuration..." -ForegroundColor Yellow
$config = @{
    generatedAt = (Get-Date).ToString('s')
    container = $ContainerName
    host = "localhost"
    port = $Port
    adminPassword = $PostgresPassword
    databases = @(
        @{
            name = $SonarDb
            user = $SonarUser
            password = $SonarPassword
        },
        @{
            name = $RedmineDb
            user = $RedmineUser
            password = $RedminePassword
        }
    )
} | ConvertTo-Json -Depth 5

$auditDir = "build/audit"
if (-not (Test-Path $auditDir)) {
    New-Item -ItemType Directory -Path $auditDir -Force | Out-Null
}

$config | Out-File -FilePath "$auditDir/postgres-config.json" -Encoding UTF8 -Force
Write-Host "OK Configuration saved to: $auditDir/postgres-config.json" -ForegroundColor Green

Write-Host "`n=== Stage 2 completed ===" -ForegroundColor Cyan
Write-Host "PostgreSQL container: $ContainerName" -ForegroundColor Gray
Write-Host "Port: $Port" -ForegroundColor Gray
Write-Host "Databases: $SonarDb, $RedmineDb" -ForegroundColor Gray
Write-Host "Data path: $DataPath" -ForegroundColor Gray
Write-Host "`nConnection strings:" -ForegroundColor Gray
Write-Host "  SonarQube: jdbc:postgresql://localhost:$Port/$SonarDb (user: $SonarUser)" -ForegroundColor Gray
Write-Host "  Redmine: postgresql://localhost:$Port/$RedmineDb (user: $RedmineUser)" -ForegroundColor Gray

