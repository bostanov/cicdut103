# deploy-gitlab.ps1 - Deploy GitLab CE in Docker
param(
    [string]$ContainerName = "gitlab",
    [int]$HttpPort = 8929,
    [int]$SshPort = 2224,
    [string]$DataPath = "C:\docker\gitlab",
    [string]$RootPassword = "Gitlab123Admin!"
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Stage 3: GitLab CE Deployment ===" -ForegroundColor Cyan

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
    "$DataPath\config",
    "$DataPath\logs",
    "$DataPath\data"
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

# 3. Pull GitLab image
Write-Host "`n3. Pulling GitLab CE image (this may take 10-15 minutes)..." -ForegroundColor Yellow
Write-Host "   Image size: ~3GB" -ForegroundColor Gray
$pullResult = docker pull gitlab/gitlab-ce:latest 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Could not pull image: $pullResult" -ForegroundColor Red
    exit 1
}
Write-Host "OK Image pulled: gitlab/gitlab-ce:latest" -ForegroundColor Green

# 4. Run GitLab container
Write-Host "`n4. Starting GitLab container..." -ForegroundColor Yellow
Write-Host "   NOTE: GitLab takes 2-5 minutes to fully initialize" -ForegroundColor Gray

$hostname = $env:COMPUTERNAME.ToLower()
$cmd = @(
    "run", "-d",
    "--name", $ContainerName,
    "--hostname", $hostname,
    "-p", "${HttpPort}:80",
    "-p", "${SshPort}:22",
    "-v", "${DataPath}/config:/etc/gitlab",
    "-v", "${DataPath}/logs:/var/log/gitlab",
    "-v", "${DataPath}/data:/var/opt/gitlab",
    "-e", "GITLAB_ROOT_PASSWORD=$RootPassword",
    "-e", "GITLAB_OMNIBUS_CONFIG=external_url 'http://${hostname}:${HttpPort}'; gitlab_rails['gitlab_shell_ssh_port'] = ${SshPort};",
    "--restart", "unless-stopped",
    "--shm-size", "256m",
    "gitlab/gitlab-ce:latest"
)

$containerId = docker @cmd 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Could not start container: $containerId" -ForegroundColor Red
    exit 1
}
Write-Host "OK GitLab container started: $ContainerName" -ForegroundColor Green
Write-Host "   Container ID: $containerId" -ForegroundColor Gray

# 5. Wait for GitLab to be ready
Write-Host "`n5. Waiting for GitLab to be ready (this takes 2-5 minutes)..." -ForegroundColor Yellow
Write-Host "   You can check logs with: docker logs -f gitlab" -ForegroundColor Gray

$maxAttempts = 60
$attempt = 0
$ready = $false

while ($attempt -lt $maxAttempts -and -not $ready) {
    Start-Sleep -Seconds 10
    $attempt++
    
    # Check if GitLab is responding
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:${HttpPort}" -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 302) {
            $ready = $true
            Write-Host "OK GitLab is ready (attempt $attempt)" -ForegroundColor Green
        }
    } catch {
        Write-Host "  Waiting... (attempt $attempt/$maxAttempts)" -ForegroundColor Gray
    }
}

if (-not $ready) {
    Write-Host "WARNING: GitLab did not respond in time, but container is running" -ForegroundColor Yellow
    Write-Host "         Check status with: docker logs gitlab" -ForegroundColor Yellow
}

# 6. Save configuration
Write-Host "`n6. Saving configuration..." -ForegroundColor Yellow
$config = @{
    generatedAt = (Get-Date).ToString('s')
    container = $ContainerName
    hostname = $hostname
    httpPort = $HttpPort
    sshPort = $SshPort
    httpUrl = "http://localhost:${HttpPort}"
    sshUrl = "ssh://git@localhost:${SshPort}"
    rootPassword = $RootPassword
    dataPath = $DataPath
} | ConvertTo-Json -Depth 5

$auditDir = "build/audit"
if (-not (Test-Path $auditDir)) {
    New-Item -ItemType Directory -Path $auditDir -Force | Out-Null
}

$config | Out-File -FilePath "$auditDir/gitlab-config.json" -Encoding UTF8 -Force
Write-Host "OK Configuration saved to: $auditDir/gitlab-config.json" -ForegroundColor Green

Write-Host "`n=== Stage 3 completed ===" -ForegroundColor Cyan
Write-Host "GitLab container: $ContainerName" -ForegroundColor Gray
Write-Host "HTTP URL: http://localhost:${HttpPort}" -ForegroundColor Gray
Write-Host "SSH URL: ssh://git@localhost:${SshPort}" -ForegroundColor Gray
Write-Host "Root username: root" -ForegroundColor Gray
Write-Host "Root password: $RootPassword" -ForegroundColor Gray
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Access GitLab at http://localhost:${HttpPort}" -ForegroundColor Gray
Write-Host "2. Login as 'root' with password from above" -ForegroundColor Gray
Write-Host "3. Create a personal access token for GitLab Runner" -ForegroundColor Gray

