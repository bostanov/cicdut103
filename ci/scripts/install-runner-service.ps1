# GitLab Runner Service Script
param(
    [string]$Action = "start"
)

$ServiceName = "GitLab-Runner-1C"
$ServiceDisplayName = "GitLab Runner 1C CI/CD Service"
$ServiceDescription = "GitLab Runner for 1C CI/CD pipeline execution"
$RunnerPath = "C:\Tools\gitlab-runner\gitlab-runner.exe"
$ConfigPath = "C:\Tools\gitlab-runner\config.toml"

# Service configuration
$ServiceConfig = @{
    Name = $ServiceName
    DisplayName = $ServiceDisplayName
    Description = $ServiceDescription
    BinaryPathName = "`"$RunnerPath`" run --config `"$ConfigPath`""
    StartType = "Automatic"
    ServiceType = "OwnProcess"
    ErrorControl = "Normal"
}

switch ($Action.ToLower()) {
    "install" {
        Write-Host "Installing GitLab Runner Service..." -ForegroundColor Yellow
        try {
            # Stop existing runner processes
            Get-Process | Where-Object { $_.ProcessName -like "*gitlab*" -or $_.ProcessName -like "*runner*" } | Stop-Process -Force -ErrorAction SilentlyContinue
            
            # Install as Windows Service
            $CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            Write-Host "Installing for user: $CurrentUser" -ForegroundColor Gray
            
            & $RunnerPath install --service $ServiceConfig.Name --user $CurrentUser --password "" --config $ConfigPath
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✓ GitLab Runner Service installed successfully" -ForegroundColor Green
            } else {
                Write-Host "Failed to install GitLab Runner Service" "ERROR"
            }
        }
        catch {
            Write-Host "Error installing service: $_" -ForegroundColor Red
        }
    }
    "uninstall" {
        Write-Host "Uninstalling GitLab Runner Service..." -ForegroundColor Yellow
        try {
            & $RunnerPath uninstall --service $ServiceConfig.Name
            Write-Host "✓ GitLab Runner Service uninstalled" -ForegroundColor Green
        }
        catch {
            Write-Host "Error uninstalling service: $_" -ForegroundColor Red
        }
    }
    "start" {
        Write-Host "Starting GitLab Runner Service..." -ForegroundColor Yellow
        try {
            Start-Service -Name $ServiceConfig.Name
            Write-Host "✓ GitLab Runner Service started" -ForegroundColor Green
        }
        catch {
            Write-Host "Error starting service: $_" -ForegroundColor Red
        }
    }
    "stop" {
        Write-Host "Stopping GitLab Runner Service..." -ForegroundColor Yellow
        try {
            Stop-Service -Name $ServiceConfig.Name -Force
            Write-Host "✓ GitLab Runner Service stopped" -ForegroundColor Green
        }
        catch {
            Write-Host "Error stopping service: $_" -ForegroundColor Red
        }
    }
    "status" {
        try {
            $service = Get-Service -Name $ServiceConfig.Name -ErrorAction SilentlyContinue
            if ($service) {
                Write-Host "GitLab Runner Service Status: $($service.Status)" -ForegroundColor Cyan
            } else {
                Write-Host "GitLab Runner Service not found" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "Error checking service status: $_" -ForegroundColor Red
        }
    }
    "restart" {
        Write-Host "Restarting GitLab Runner Service..." -ForegroundColor Yellow
        try {
            Restart-Service -Name $ServiceConfig.Name -Force
            Write-Host "✓ GitLab Runner Service restarted" -ForegroundColor Green
        }
        catch {
            Write-Host "Error restarting service: $_" -ForegroundColor Red
        }
    }
}
