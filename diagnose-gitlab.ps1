# Quick GitLab diagnostics
Write-Host "GitLab Diagnostics" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan
Write-Host ""

# Status
Write-Host "1. Container Status:" -ForegroundColor Yellow
docker ps -a --filter "name=gitlab" --format "  Status: {{.Status}}" --no-trunc
docker inspect gitlab --format "  Exit Code: {{.State.ExitCode}}, Restarts: {{.RestartCount}}"
Write-Host ""

# Last lines of log
Write-Host "2. Last log entries:" -ForegroundColor Yellow
docker logs gitlab --tail 20 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
Write-Host ""

# Resources
Write-Host "3. Resource Usage:" -ForegroundColor Yellow
docker stats gitlab --no-stream --format "  CPU: {{.CPUPerc}}  Memory: {{.MemUsage}}"
Write-Host ""

# Volumes
Write-Host "4. Volumes:" -ForegroundColor Yellow
docker inspect gitlab --format '{{range .Mounts}}  {{.Source}} -> {{.Destination}}{{"\n"}}{{end}}'
Write-Host ""

Write-Host "Recommendation:" -ForegroundColor Cyan
Write-Host "  GitLab требует минимум 4GB RAM и может долго инициализироваться." -ForegroundColor Gray
Write-Host "  Если продолжает падать - используйте Docker volumes вместо bind mounts" -ForegroundColor Gray


