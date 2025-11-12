# Создание root пользователя в GitLab
user = User.find_by(username: 'root')

if user
  puts "Root user already exists"
  puts "Username: #{user.username}"
  puts "Email: #{user.email}"
  puts "ID: #{user.id}"
else
  puts "Creating root user..."
  
  # Используем сервис для создания пользователя
  password = 'Xk8mP2nQ9vL5wR3t'  # Случайный сложный пароль
  
  params = {
    name: 'Administrator',
    username: 'root',
    email: 'admin@example.com',
    password: password,
    password_automatically_set: false,
    skip_confirmation: true,
    admin: true,
    projects_limit: 100000
  }
  
  result = Users::CreateService.new(nil, params).execute
  
  if result[:status] == :success
    user = result[:user]
    puts "SUCCESS: Root user created"
    puts "Username: root"
    puts "Password: #{password}"
    puts "Email: admin@example.com"
    puts "ID: #{user.id}"
  else
    puts "ERROR: #{result[:message]}"
  end
end
