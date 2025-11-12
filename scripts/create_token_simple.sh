#!/bin/bash
# Простой скрипт создания токена

docker exec -it gitlab-cicd gitlab-rails runner "
user = User.find_by(username: 'root')
if user
  token = user.personal_access_tokens.create(
    name: 'API Token',
    scopes: [:api, :read_repository, :write_repository]
  )
  if token.persisted?
    puts 'TOKEN:'
    puts token.token
  else
    puts 'ERROR: ' + token.errors.full_messages.join(', ')
  end
else
  puts 'ERROR: User not found'
end
"
