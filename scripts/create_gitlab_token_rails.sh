#!/bin/bash
# Создание Personal Access Token через GitLab Rails console

docker exec gitlab-cicd gitlab-rails runner "
user = User.find_by(username: 'root')
token = user.personal_access_tokens.create(
  name: 'CI/CD Integration Token',
  scopes: ['api', 'read_repository', 'write_repository'],
  expires_at: nil
)
puts token.token
"
