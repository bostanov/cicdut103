user = User.find_by(username: 'root')
if user.nil?
  puts "ERROR: User 'root' not found"
  exit 1
end

token = user.personal_access_tokens.create(
  name: 'CI/CD Integration Token',
  scopes: ['api', 'read_repository', 'write_repository'],
  expires_at: nil
)

if token.persisted?
  puts "Token created successfully:"
  puts token.token
else
  puts "ERROR: Failed to create token"
  puts token.errors.full_messages.join(", ")
end
