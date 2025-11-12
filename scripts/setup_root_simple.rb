# Простая настройка root пользователя
puts "Checking for root user..."

user = User.where(username: 'root').first_or_initialize do |u|
  u.email = 'admin@example.com'
  u.name = 'Administrator'
  u.admin = true
  u.projects_limit = 100000
end

if user.persisted?
  puts "Root user exists: #{user.username} (#{user.email})"
  
  # Сбрасываем пароль
  password = 'Xk8mP2nQ9vL5wR3t'
  user.password = password
  user.password_confirmation = password
  user.password_automatically_set = false
  
  if user.save(validate: false)
    puts "Password reset successful"
    puts "Username: root"
    puts "Password: #{password}"
  else
    puts "Failed to reset password: #{user.errors.full_messages}"
  end
else
  puts "Creating new root user..."
  user.password = 'Xk8mP2nQ9vL5wR3t'
  user.password_confirmation = 'Xk8mP2nQ9vL5wR3t'
  user.confirmed_at = Time.now
  
  if user.save(validate: false)
    puts "Root user created successfully"
    puts "Username: root"
    puts "Password: Xk8mP2nQ9vL5wR3t"
  else
    puts "Failed to create user: #{user.errors.full_messages}"
  end
end
