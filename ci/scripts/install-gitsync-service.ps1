# GitSync Service Script
param(
    [string]$Action = "start"
)

$ServiceName = "GitSync-1C-Service"
$ServiceDisplayName = "GitSync 1C Synchronization Service"
$ServiceDescription = "Automatically synchronizes 1C storage with Git repository"
$ScriptPath = "C:\1C-CI-CD\ci\scripts\gitsync-service.ps1"

# Service configuration
$ServiceConfig = @{
    Name = $ServiceName
    DisplayName = $ServiceDisplayName
    Description = $ServiceDescription
    BinaryPathName = "powershell.exe -ExecutionPolicy Bypass -File `"$ScriptPath`""
    StartType = "Automatic"
    ServiceType = "OwnProcess"
    ErrorControl = "Normal"
}

switch ($Action.ToLower()) {
    "install" {
        Write-Host "Installing GitSync Service..." -ForegroundColor Yellow
        try {
            # Create service
            New-Service -Name $ServiceConfig.Name -BinaryPathName $ServiceConfig.BinaryPathName -DisplayName $ServiceConfig.DisplayName -Description $ServiceConfig.Description -StartupType $ServiceConfig.StartType
            Write-Host "✓ GitSync Service installed successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "Error installing service: $_" -ForegroundColor Red
        }
    }
    "uninstall" {
        Write-Host "Uninstalling GitSync Service..." -ForegroundColor Yellow
        try {
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Remove-Service -Name $ServiceName -ErrorAction SilentlyContinue
            Write-Host "✓ GitSync Service uninstalled" -ForegroundColor Green
        }
        catch {
            Write-Host "Error uninstalling service: $_" -ForegroundColor Red
        }
    }
    "start" {
        Write-Host "Starting GitSync Service..." -ForegroundColor Yellow
        try {
            Start-Service -Name $ServiceName
            Write-Host "✓ GitSync Service started" -ForegroundColor Green
        }
        catch {
            Write-Host "Error starting service: $_" -ForegroundColor Red
        }
    }
    "stop" {
        Write-Host "Stopping GitSync Service..." -ForegroundColor Yellow
        try {
            Stop-Service -Name $ServiceName -Force
            Write-Host "✓ GitSync Service stopped" -ForegroundColor Green
        }
        catch {
            Write-Host "Error stopping service: $_" -ForegroundColor Red
        }
    }
    "status" {
        try {
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($service) {
                Write-Host "GitSync Service Status: $($service.Status)" -ForegroundColor Cyan
            } else {
                Write-Host "GitSync Service not found" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "Error checking service status: $_" -ForegroundColor Red
        }
    }
}
