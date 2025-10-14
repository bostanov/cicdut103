param(
    [string]$OutputPath = "build/audit/tools.json"
)

# Ensure output directory exists
$auditDir = Split-Path $OutputPath -Parent
if (!(Test-Path $auditDir)) {
    New-Item -ItemType Directory -Path $auditDir -Force | Out-Null
}

$audit = @{}

# Check 1C 8.3.12.1714
try {
    $1cPath = "C:\Program Files\1cv8\8.3.12.1714\bin\1cv8.exe"
    if (Test-Path $1cPath) {
        $version = & $1cPath -v 2>&1
        $audit.'1c' = @{ 
            present = $LASTEXITCODE -eq 0
            version = $version -join " "
            path = $1cPath
        }
    } else {
        $audit.'1c' = @{ 
            present = $false
            error = "1C 8.3.12.1714 not found at $1cPath"
        }
    }
} catch {
    $audit.'1c' = @{ 
        present = $false
        error = $_.Exception.Message
    }
}

# Check Git
try {
    $git = git --version 2>&1
    $audit.git = @{ 
        present = $LASTEXITCODE -eq 0
        version = $git -join " "
    }
} catch {
    $audit.git = @{ 
        present = $false
        error = $_.Exception.Message
    }
}

# Check Docker
try {
    $docker = docker --version 2>&1
    $audit.docker = @{ 
        present = $LASTEXITCODE -eq 0
        version = $docker -join " "
    }
} catch {
    $audit.docker = @{ 
        present = $false
        error = $_.Exception.Message
    }
}

# Check GitLab Runner
try {
    $runner = gitlab-runner --version 2>&1
    $audit.gitlab_runner = @{ 
        present = $LASTEXITCODE -eq 0
        version = $runner -join " "
    }
} catch {
    $audit.gitlab_runner = @{ 
        present = $false
        error = $_.Exception.Message
    }
}

# Check OneScript
try {
    $oscript = oscript -v 2>&1
    $audit.oscript = @{ 
        present = $LASTEXITCODE -eq 0
        version = $oscript -join " "
    }
} catch {
    $audit.oscript = @{ 
        present = $false
        error = $_.Exception.Message
    }
}

# Check precommit1c
try {
    $precommit = precommit1c --version 2>&1
    $audit.precommit1c = @{ 
        present = $LASTEXITCODE -eq 0
        version = $precommit -join " "
    }
} catch {
    $audit.precommit1c = @{ 
        present = $false
        error = $_.Exception.Message
    }
}

# Check GitSync3
try {
    $gitsync = gitsync3.exe /? 2>&1
    $audit.gitsync3 = @{ 
        present = $LASTEXITCODE -eq 0
        version = $gitsync -join " "
    }
} catch {
    $audit.gitsync3 = @{ 
        present = $false
        error = $_.Exception.Message
    }
}

# Check SonarScanner
try {
    $sonar = sonar-scanner -v 2>&1
    $audit.sonar_scanner = @{ 
        present = $LASTEXITCODE -eq 0
        version = $sonar -join " "
    }
} catch {
    $audit.sonar_scanner = @{ 
        present = $false
        error = $_.Exception.Message
    }
}

# Save results
$audit | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath -Encoding utf8

Write-Host "=== TOOL AUDIT RESULTS ==="
$audit.GetEnumerator() | ForEach-Object {
    $status = if ($_.Value.present) { "PRESENT" } else { "MISSING" }
    Write-Host "$($_.Key): $status"
    if ($_.Value.version) { Write-Host "  Version: $($_.Value.version)" }
    if ($_.Value.error) { Write-Host "  Error: $($_.Value.error)" }
}

return $audit

