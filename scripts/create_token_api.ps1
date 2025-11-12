# Создание Personal Access Token через GitLab API
$gitlabUrl = "http://localhost:8929"
$username = "root"
$password = "rootpassword123"

Write-Host "Попытка входа в GitLab..." -ForegroundColor Cyan

# Получаем CSRF token
try {
    $loginPage = Invoke-WebRequest -Uri "$gitlabUrl/users/sign_in" -SessionVariable session -UseBasicParsing
    $csrfToken = ($loginPage.Content | Select-String -Pattern 'name="authenticity_token" value="([^"]+)"').Matches[0].Groups[1].Value
    
    Write-Host "CSRF token получен: $($csrfToken.Substring(0,20))..." -ForegroundColor Green
    
    # Выполняем вход
    $loginData = @{
        'utf8' = '✓'
        'authenticity_token' = $csrfToken
        'user[login]' = $username
        'user[password]' = $password
        'user[remember_me]' = '0'
    }
    
    $loginResponse = Invoke-WebRequest -Uri "$gitlabUrl/users/sign_in" -Method Post -Body $loginData -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue
    
    Write-Host "Вход выполнен успешно!" -ForegroundColor Green
    Write-Host "Теперь создайте токен вручную через веб-интерфейс:" -ForegroundColor Yellow
    Write-Host "1. Откройте http://localhost:8929" -ForegroundColor White
    Write-Host "2. Войдите как root / rootpassword123" -ForegroundColor White
    Write-Host "3. Перейдите в Settings -> Access Tokens" -ForegroundColor White
    Write-Host "4. Создайте токен с правами: api, read_repository, write_repository" -ForegroundColor White
    
} catch {
    Write-Host "Ошибка: $($_.Exception.Message)" -ForegroundColor Red
}
