user = User.find_by(username: 'root')
if user.nil?
  puts "User 'root' not found"
  exit 1
end

token = user.personal_access_tokens.create(
  name: 'CI/CD Integration Token',
  scopes: ['api', 'read_user', 'read_repository', 'write_repository'],
  expires_at: 1.year.from_now
)

if token.persisted?
  puts "Token created: #{token.token}"
else
  puts "Failed to create token: #{token.errors.full_messages}"
end