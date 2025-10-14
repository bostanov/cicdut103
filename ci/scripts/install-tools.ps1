# install-tools.ps1 - Install required CI/CD tools
param(
    [switch]$OneScript = $true,
    [switch]$GitSync3 = $true,
    [switch]$Precommit1c = $true,
    [switch]$SonarScanner = $true,
    [switch]$GitLabRunner = $true,
    [string]$InstallPath = "C:\Tools"
)

$ErrorActionPreference = 'Continue'

Write-Host "=== Stage 8: Installing CI/CD Tools ===" -ForegroundColor Cyan

# Create install directory
if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}

$results = @()

# 1. OneScript
if ($OneScript) {
    Write-Host "`n1. Installing OneScript..." -ForegroundColor Yellow
    $oneScriptPath = "C:\Program Files\OneScript"
    
    if (Test-Path "$oneScriptPath\oscript.exe") {
        Write-Host "OK OneScript already installed" -ForegroundColor Green
        $results += @{tool="OneScript"; status="Already installed"; path=$oneScriptPath}
    } else {
        Write-Host "  Downloading OneScript installer..." -ForegroundColor Gray
        try {
            # Download latest release
            $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/EvilBeaver/OneScript/releases/latest"
            $msiAsset = $latestRelease.assets | Where-Object { $_.name -like "*.msi" } | Select-Object -First 1
            
            $msiPath = "$env:TEMP\onescript-setup.msi"
            Invoke-WebRequest -Uri $msiAsset.browser_download_url -OutFile $msiPath -UseBasicParsing
            
            Write-Host "  Installing OneScript..." -ForegroundColor Gray
            Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /norestart" -Wait -NoNewWindow
            
            Remove-Item $msiPath -Force
            Write-Host "OK OneScript installed" -ForegroundColor Green
            $results += @{tool="OneScript"; status="Installed"; path=$oneScriptPath}
        } catch {
            Write-Host "FAILED: $_" -ForegroundColor Red
            Write-Host "  Download manually from: https://github.com/EvilBeaver/OneScript/releases" -ForegroundColor Yellow
            $results += @{tool="OneScript"; status="Failed"; error=$_.Exception.Message}
        }
    }
}

# 2. GitSync3
if ($GitSync3) {
    Write-Host "`n2. Installing GitSync3..." -ForegroundColor Yellow
    $gitSync3Path = "$InstallPath\GitSync3"
    
    if (Test-Path "$gitSync3Path\gitsync3.exe") {
        Write-Host "OK GitSync3 already installed" -ForegroundColor Green
        $results += @{tool="GitSync3"; status="Already installed"; path=$gitSync3Path}
    } else {
        Write-Host "  Downloading GitSync3..." -ForegroundColor Gray
        try {
            # Download latest release
            $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/oscript-library/gitsync/releases/latest"
            $zipAsset = $latestRelease.assets | Where-Object { $_.name -like "*windows*.zip" } | Select-Object -First 1
            
            $zipPath = "$env:TEMP\gitsync3.zip"
            Invoke-WebRequest -Uri $zipAsset.browser_download_url -OutFile $zipPath -UseBasicParsing
            
            # Extract
            if (-not (Test-Path $gitSync3Path)) {
                New-Item -ItemType Directory -Path $gitSync3Path -Force | Out-Null
            }
            
            Expand-Archive -Path $zipPath -DestinationPath $gitSync3Path -Force
            Remove-Item $zipPath -Force
            
            Write-Host "OK GitSync3 installed to: $gitSync3Path" -ForegroundColor Green
            $results += @{tool="GitSync3"; status="Installed"; path=$gitSync3Path}
        } catch {
            Write-Host "FAILED: $_" -ForegroundColor Red
            Write-Host "  Download manually from: https://github.com/oscript-library/gitsync/releases" -ForegroundColor Yellow
            $results += @{tool="GitSync3"; status="Failed"; error=$_.Exception.Message}
        }
    }
}

# 3. precommit1c (Python package)
if ($Precommit1c) {
    Write-Host "`n3. Installing precommit1c..." -ForegroundColor Yellow
    
    # Check if Python is installed
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) {
        Write-Host "SKIP: Python not found. Install Python 3.8+ first." -ForegroundColor Yellow
        Write-Host "      Download from: https://www.python.org/downloads/" -ForegroundColor Yellow
        $results += @{tool="precommit1c"; status="Skipped"; reason="Python not installed"}
    } else {
        $pythonVersion = (python --version 2>&1) -replace "Python ", ""
        Write-Host "  Found Python: $pythonVersion" -ForegroundColor Gray
        
        try {
            # Check if already installed
            $precommit1cCheck = python -m pip show precommit1c 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "OK precommit1c already installed" -ForegroundColor Green
                $results += @{tool="precommit1c"; status="Already installed"}
            } else {
                Write-Host "  Installing via pip..." -ForegroundColor Gray
                python -m pip install precommit1c --upgrade --quiet
                Write-Host "OK precommit1c installed" -ForegroundColor Green
                $results += @{tool="precommit1c"; status="Installed"}
            }
        } catch {
            Write-Host "FAILED: $_" -ForegroundColor Red
            $results += @{tool="precommit1c"; status="Failed"; error=$_.Exception.Message}
        }
    }
}

# 4. SonarScanner
if ($SonarScanner) {
    Write-Host "`n4. Installing SonarScanner..." -ForegroundColor Yellow
    $sonarScannerPath = "$InstallPath\sonar-scanner"
    
    if (Test-Path "$sonarScannerPath\bin\sonar-scanner.bat") {
        Write-Host "OK SonarScanner already installed" -ForegroundColor Green
        $results += @{tool="SonarScanner"; status="Already installed"; path=$sonarScannerPath}
    } else {
        Write-Host "  Downloading SonarScanner CLI..." -ForegroundColor Gray
        try {
            $version = "5.0.1.3006"
            $zipUrl = "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${version}-windows.zip"
            $zipPath = "$env:TEMP\sonar-scanner.zip"
            
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
            
            # Extract
            Expand-Archive -Path $zipPath -DestinationPath $InstallPath -Force
            
            # Rename extracted directory
            $extractedDir = "$InstallPath\sonar-scanner-${version}-windows"
            if (Test-Path $extractedDir) {
                if (Test-Path $sonarScannerPath) {
                    Remove-Item $sonarScannerPath -Recurse -Force
                }
                Rename-Item $extractedDir $sonarScannerPath
            }
            
            Remove-Item $zipPath -Force
            Write-Host "OK SonarScanner installed to: $sonarScannerPath" -ForegroundColor Green
            $results += @{tool="SonarScanner"; status="Installed"; path=$sonarScannerPath}
        } catch {
            Write-Host "FAILED: $_" -ForegroundColor Red
            Write-Host "  Download manually from: https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/" -ForegroundColor Yellow
            $results += @{tool="SonarScanner"; status="Failed"; error=$_.Exception.Message}
        }
    }
}

# 5. GitLab Runner
if ($GitLabRunner) {
    Write-Host "`n5. Installing GitLab Runner..." -ForegroundColor Yellow
    $runnerPath = "$InstallPath\gitlab-runner"
    $runnerExe = "$runnerPath\gitlab-runner.exe"
    
    if (Test-Path $runnerExe) {
        Write-Host "OK GitLab Runner already installed" -ForegroundColor Green
        $results += @{tool="GitLab Runner"; status="Already installed"; path=$runnerPath}
    } else {
        Write-Host "  Downloading GitLab Runner..." -ForegroundColor Gray
        try {
            $runnerUrl = "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-windows-amd64.exe"
            
            if (-not (Test-Path $runnerPath)) {
                New-Item -ItemType Directory -Path $runnerPath -Force | Out-Null
            }
            
            Invoke-WebRequest -Uri $runnerUrl -OutFile $runnerExe -UseBasicParsing
            
            Write-Host "OK GitLab Runner downloaded to: $runnerExe" -ForegroundColor Green
            Write-Host "   NOTE: Registration requires GitLab URL and token (see Stage 4)" -ForegroundColor Yellow
            $results += @{tool="GitLab Runner"; status="Downloaded"; path=$runnerPath; note="Requires registration"}
        } catch {
            Write-Host "FAILED: $_" -ForegroundColor Red
            Write-Host "  Download manually from: https://docs.gitlab.com/runner/install/windows.html" -ForegroundColor Yellow
            $results += @{tool="GitLab Runner"; status="Failed"; error=$_.Exception.Message}
        }
    }
}

# Summary
Write-Host "`n=== Stage 8 completed ===" -ForegroundColor Cyan
Write-Host "Installation summary:" -ForegroundColor Yellow
$results | ForEach-Object {
    $status = $_.status
    $color = switch ($status) {
        "Installed" { "Green" }
        "Already installed" { "Green" }
        "Downloaded" { "Cyan" }
        "Skipped" { "Yellow" }
        "Failed" { "Red" }
        default { "Gray" }
    }
    Write-Host "  $($_.tool): $status" -ForegroundColor $color
    if ($_.path) {
        Write-Host "    Path: $($_.path)" -ForegroundColor Gray
    }
    if ($_.note) {
        Write-Host "    Note: $($_.note)" -ForegroundColor Gray
    }
}

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "- Run audit again: ci/scripts/audit-tools.ps1" -ForegroundColor Gray
Write-Host "- Add tools to PATH if needed" -ForegroundColor Gray
Write-Host "- Register GitLab Runner (Stage 4)" -ForegroundColor Gray

