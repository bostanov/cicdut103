# deploy-sonarqube.ps1 - Deploy SonarQube in Docker with BSL plugin
param(
    [string]$ContainerName = "sonarqube",
    [int]$Port = 9000,
    [string]$DataPath = "C:\docker\sonarqube",
    [string]$PostgresHost = "host.docker.internal",
    [int]$PostgresPort = 5433,
    [string]$PostgresDb = "sonar",
    [string]$PostgresUser = "sonar",
    [string]$PostgresPassword = "sonar",
    [string]$BslPluginVersion = "1.9.1"
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Stage 5: SonarQube Deployment ===" -ForegroundColor Cyan

# 1. Check if container already exists
Write-Host "`n1. Checking existing container..." -ForegroundColor Yellow
$existing = docker ps -a --filter "name=$ContainerName" --format "{{.Names}}" 2>$null
if ($existing -eq $ContainerName) {
    Write-Host "Container $ContainerName already exists. Removing..." -ForegroundColor Yellow
    docker stop $ContainerName 2>$null | Out-Null
    docker rm $ContainerName 2>$null | Out-Null
    Write-Host "OK Container removed" -ForegroundColor Green
}

# 2. Create data directories
Write-Host "`n2. Creating data directories..." -ForegroundColor Yellow
$dirs = @(
    "$DataPath\data",
    "$DataPath\logs",
    "$DataPath\extensions",
    "$DataPath\temp"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  Created: $dir" -ForegroundColor Gray
    } else {
        Write-Host "  Exists: $dir" -ForegroundColor Gray
    }
}
Write-Host "OK Directories configured" -ForegroundColor Green

# 3. Download BSL plugin
Write-Host "`n3. Downloading BSL Language Server plugin..." -ForegroundColor Yellow
$pluginUrl = "https://github.com/1c-syntax/sonar-bsl-plugin-community/releases/download/v${BslPluginVersion}/sonar-bsl-plugin-community-${BslPluginVersion}.jar"
$pluginPath = "$DataPath\extensions\sonar-bsl-plugin-community-${BslPluginVersion}.jar"

if (Test-Path $pluginPath) {
    Write-Host "OK Plugin already downloaded: $pluginPath" -ForegroundColor Green
} else {
    try {
        Write-Host "  Downloading from: $pluginUrl" -ForegroundColor Gray
        Invoke-WebRequest -Uri $pluginUrl -OutFile $pluginPath -UseBasicParsing
        Write-Host "OK Plugin downloaded: $pluginPath" -ForegroundColor Green
    } catch {
        Write-Host "FAILED: Could not download plugin: $_" -ForegroundColor Red
        Write-Host "  You can download manually from GitHub and place in $DataPath\extensions" -ForegroundColor Yellow
    }
}

# 4. Check if SonarQube image exists, pull if needed
Write-Host "`n4. Checking SonarQube image..." -ForegroundColor Yellow
$imageExists = docker images sonarqube:10.3-community --format "{{.Repository}}" 2>$null
if ($imageExists -eq "sonarqube") {
    Write-Host "OK Image already exists: sonarqube:10.3-community" -ForegroundColor Green
} else {
    Write-Host "  Pulling image..." -ForegroundColor Gray
    $pullResult = docker pull sonarqube:10.3-community 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: Could not pull image: $pullResult" -ForegroundColor Red
        exit 1
    }
    Write-Host "OK Image pulled: sonarqube:10.3-community" -ForegroundColor Green
}

# 5. Run SonarQube container
Write-Host "`n5. Starting SonarQube container..." -ForegroundColor Yellow
Write-Host "   NOTE: SonarQube takes 1-2 minutes to initialize" -ForegroundColor Gray

$jdbcUrl = "jdbc:postgresql://${PostgresHost}:${PostgresPort}/${PostgresDb}"

$cmd = @(
    "run", "-d",
    "--name", $ContainerName,
    "-p", "${Port}:9000",
    "-e", "SONAR_JDBC_URL=$jdbcUrl",
    "-e", "SONAR_JDBC_USERNAME=$PostgresUser",
    "-e", "SONAR_JDBC_PASSWORD=$PostgresPassword",
    "-v", "${DataPath}/data:/opt/sonarqube/data",
    "-v", "${DataPath}/logs:/opt/sonarqube/logs",
    "-v", "${DataPath}/extensions:/opt/sonarqube/extensions",
    "-v", "${DataPath}/temp:/opt/sonarqube/temp",
    "--restart", "unless-stopped",
    "sonarqube:10.3-community"
)

$containerId = docker @cmd 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Could not start container: $containerId" -ForegroundColor Red
    exit 1
}
Write-Host "OK SonarQube container started: $ContainerName" -ForegroundColor Green
Write-Host "   Container ID: $containerId" -ForegroundColor Gray

# 6. Wait for SonarQube to be ready
Write-Host "`n6. Waiting for SonarQube to be ready (this takes 1-2 minutes)..." -ForegroundColor Yellow

$maxAttempts = 40
$attempt = 0
$ready = $false

while ($attempt -lt $maxAttempts -and -not $ready) {
    Start-Sleep -Seconds 5
    $attempt++
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:${Port}/api/system/status" -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
        $status = ($response.Content | ConvertFrom-Json).status
        if ($status -eq "UP") {
            $ready = $true
            Write-Host "OK SonarQube is ready (attempt $attempt)" -ForegroundColor Green
        }
    } catch {
        Write-Host "  Waiting... (attempt $attempt/$maxAttempts)" -ForegroundColor Gray
    }
}

if (-not $ready) {
    Write-Host "WARNING: SonarQube did not respond in time, but container is running" -ForegroundColor Yellow
    Write-Host "         Check status with: docker logs sonarqube" -ForegroundColor Yellow
}

# 7. Check BSL plugin installation
Write-Host "`n7. Checking BSL plugin installation..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

try {
    $pluginsResponse = Invoke-WebRequest -Uri "http://localhost:${Port}/api/plugins/installed" -UseBasicParsing -ErrorAction SilentlyContinue
    $plugins = ($pluginsResponse.Content | ConvertFrom-Json).plugins
    $bslPlugin = $plugins | Where-Object { $_.key -eq "communitybsl" }
    
    if ($bslPlugin) {
        Write-Host "OK BSL plugin installed: version $($bslPlugin.version)" -ForegroundColor Green
    } else {
        Write-Host "WARNING: BSL plugin not detected" -ForegroundColor Yellow
        Write-Host "         Plugin should be in: $DataPath\extensions" -ForegroundColor Yellow
        Write-Host "         Restart container after placing plugin: docker restart sonarqube" -ForegroundColor Yellow
    }
} catch {
    Write-Host "WARNING: Could not check plugins: $_" -ForegroundColor Yellow
}

# 8. Save configuration
Write-Host "`n8. Saving configuration..." -ForegroundColor Yellow
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
    bslPlugin = @{
        version = $BslPluginVersion
        path = $pluginPath
    }
} | ConvertTo-Json -Depth 5

$auditDir = "build/audit"
if (-not (Test-Path $auditDir)) {
    New-Item -ItemType Directory -Path $auditDir -Force | Out-Null
}

$config | Out-File -FilePath "$auditDir/sonarqube-config.json" -Encoding UTF8 -Force
Write-Host "OK Configuration saved to: $auditDir/sonarqube-config.json" -ForegroundColor Green

Write-Host "`n=== Stage 5 completed ===" -ForegroundColor Cyan
Write-Host "SonarQube container: $ContainerName" -ForegroundColor Gray
Write-Host "URL: http://localhost:${Port}" -ForegroundColor Gray
Write-Host "Default login: admin / admin (change on first login)" -ForegroundColor Gray
Write-Host "BSL plugin version: $BslPluginVersion" -ForegroundColor Gray
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Access SonarQube at http://localhost:${Port}" -ForegroundColor Gray
Write-Host "2. Login as 'admin' / 'admin'" -ForegroundColor Gray
Write-Host "3. Change admin password when prompted" -ForegroundColor Gray
Write-Host "4. Create a project and token for scanning" -ForegroundColor Gray

