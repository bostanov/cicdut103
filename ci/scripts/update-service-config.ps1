# Configuration Update Script
param(
    [string]$ConfigPath = "ci\config\ci-settings.json"
)

Write-Host "Updating CI/CD configuration..." -ForegroundColor Yellow

# Load current configuration
if (Test-Path $ConfigPath) {
    $Config = Get-Content $ConfigPath | ConvertFrom-Json
} else {
    Write-Host "Configuration file not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

# Update service configurations
$Config | Add-Member -NotePropertyName "services" -NotePropertyValue @{
    "gitsync" = @{
        "enabled" = $true
        "syncIntervalMinutes" = 5
        "logFile" = "C:\1C-CI-CD\logs\gitsync-service.log"
        "serviceName" = "GitSync-1C-Service"
    }
    "precommit1c" = @{
        "enabled" = $true
        "checkIntervalSeconds" = 30
        "logFile" = "C:\1C-CI-CD\logs\precommit1c-service.log"
        "serviceName" = "Precommit1C-Service"
        "externalFilesDir" = "C:\1C-CI-CD\externals"
        "processedFilesDir" = "C:\1C-CI-CD\externals\processed"
        "sourcesDir" = "C:\1C-CI-CD\externals\sources"
    }
    "runner" = @{
        "enabled" = $true
        "serviceName" = "GitLab-Runner-1C"
        "configFile" = "C:\Tools\gitlab-runner\config.toml"
    }
    "sonar" = @{
        "enabled" = $true
        "projectKey" = "ut103-ci"
        "logFile" = "C:\1C-CI-CD\logs\sonar-analysis.log"
        "autoTrigger" = $true
    }
} -Force

# Save updated configuration
$Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8

Write-Host "✓ Configuration updated with service settings" -ForegroundColor Green
Write-Host ""
Write-Host "Service Configuration Summary:" -ForegroundColor Cyan
Write-Host "  GitSync: $($Config.services.gitsync.enabled) (Interval: $($Config.services.gitsync.syncIntervalMinutes) min)" -ForegroundColor Gray
Write-Host "  Precommit1C: $($Config.services.precommit1c.enabled) (Interval: $($Config.services.precommit1c.checkIntervalSeconds) sec)" -ForegroundColor Gray
Write-Host "  Runner: $($Config.services.runner.enabled)" -ForegroundColor Gray
Write-Host "  SonarQube: $($Config.services.sonar.enabled) (Auto-trigger: $($Config.services.sonar.autoTrigger))" -ForegroundColor Gray
