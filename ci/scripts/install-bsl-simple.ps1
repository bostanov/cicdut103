# Install BSL Plugin for SonarQube
param(
    [string]$Version = "1.9.1",
    [string]$ExtensionsPath = "C:\docker\sonarqube\extensions\plugins"
)

Write-Host "Installing BSL Plugin for SonarQube..." -ForegroundColor Cyan

$pluginUrl = "https://github.com/1c-syntax/sonar-bsl-plugin-community/releases/download/v${Version}/sonar-bsl-plugin-community-${Version}.jar"
$pluginFile = "$ExtensionsPath\sonar-bsl-plugin-community-${Version}.jar"

Write-Host "Version: $Version" -ForegroundColor Gray
Write-Host "Download URL: $pluginUrl" -ForegroundColor Gray
Write-Host "Install path: $pluginFile" -ForegroundColor Gray

# Create directory if not exists
if (-not (Test-Path $ExtensionsPath)) {
    Write-Host "Creating directory: $ExtensionsPath" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $ExtensionsPath -Force | Out-Null
}

# Download plugin
Write-Host "Downloading BSL plugin..." -ForegroundColor Yellow
try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $pluginUrl -OutFile $pluginFile
    Write-Host "Plugin downloaded successfully!" -ForegroundColor Green
    
    $fileInfo = Get-Item $pluginFile
    Write-Host "File size: $([Math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Gray
    
} catch {
    Write-Host "Download failed: $_" -ForegroundColor Red
    exit 1
}

# Restart SonarQube
Write-Host "Restarting SonarQube..." -ForegroundColor Yellow
docker restart sonarqube
Write-Host "SonarQube is restarting. Wait 2-3 minutes for full startup." -ForegroundColor Green

Write-Host "BSL Plugin installation completed!" -ForegroundColor Green
