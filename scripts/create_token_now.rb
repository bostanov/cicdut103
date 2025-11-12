# Создание Personal Access Token
user = User.find_by(username: 'root')

if user.nil?
  puts "ERROR: Root user not found"
  exit 1
end

puts "Found user: #{user.username}"

# Удаляем старые токены
old_tokens = user.personal_access_tokens.where(name: 'API Token')
if old_tokens.any?
  puts "Removing #{old_tokens.count} old tokens..."
  old_tokens.destroy_all
end

# Создаем новый токен (срок действия 1 год)
token = user.personal_access_tokens.create(
  name: 'API Token',
  scopes: [:api, :read_repository, :write_repository],
  expires_at: 1.year.from_now
)

if token.persisted?
  puts "SUCCESS"
  puts token.token
else
  puts "ERROR: #{token.errors.full_messages.join(', ')}"
end
