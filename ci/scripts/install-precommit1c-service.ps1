# Precommit1C Service Script
param(
    [string]$Action = "start"
)

$ServiceName = "Precommit1C-Service"
$ServiceDisplayName = "Precommit1C External Files Monitor Service"
$ServiceDescription = "Monitors external files directory and processes new files automatically"
$ScriptPath = "C:\1C-CI-CD\ci\scripts\precommit1c-service.ps1"

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
        Write-Host "Installing Precommit1C Service..." -ForegroundColor Yellow
        try {
            # Create service
            New-Service -Name $ServiceConfig.Name -BinaryPathName $ServiceConfig.BinaryPathName -DisplayName $ServiceConfig.DisplayName -Description $ServiceConfig.Description -StartupType $ServiceConfig.StartType
            Write-Host "✓ Precommit1C Service installed successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "Error installing service: $_" -ForegroundColor Red
        }
    }
    "uninstall" {
        Write-Host "Uninstalling Precommit1C Service..." -ForegroundColor Yellow
        try {
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Remove-Service -Name $ServiceName -ErrorAction SilentlyContinue
            Write-Host "✓ Precommit1C Service uninstalled" -ForegroundColor Green
        }
        catch {
            Write-Host "Error uninstalling service: $_" -ForegroundColor Red
        }
    }
    "start" {
        Write-Host "Starting Precommit1C Service..." -ForegroundColor Yellow
        try {
            Start-Service -Name $ServiceName
            Write-Host "✓ Precommit1C Service started" -ForegroundColor Green
        }
        catch {
            Write-Host "Error starting service: $_" -ForegroundColor Red
        }
    }
    "stop" {
        Write-Host "Stopping Precommit1C Service..." -ForegroundColor Yellow
        try {
            Stop-Service -Name $ServiceName -Force
            Write-Host "✓ Precommit1C Service stopped" -ForegroundColor Green
        }
        catch {
            Write-Host "Error stopping service: $_" -ForegroundColor Red
        }
    }
    "status" {
        try {
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($service) {
                Write-Host "Precommit1C Service Status: $($service.Status)" -ForegroundColor Cyan
            } else {
                Write-Host "Precommit1C Service not found" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "Error checking service status: $_" -ForegroundColor Red
        }
    }
}
