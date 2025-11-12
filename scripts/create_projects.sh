#!/bin/bash
# Создание проектов в GitLab через API внутри контейнера

TOKEN="YOUR_GITLAB_TOKEN_HERE"
API_URL="http://localhost/api/v4"

echo "Creating project: ut103-ci"
docker exec gitlab-cicd curl -s -X POST \
  -H "PRIVATE-TOKEN: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ut103-ci",
    "description": "Основной проект 1С:Предприятие",
    "visibility": "private",
    "initialize_with_readme": true
  }' \
  "$API_URL/projects"

echo ""
echo "Creating project: ut103-external-files"
docker exec gitlab-cicd curl -s -X POST \
  -H "PRIVATE-TOKEN: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ut103-external-files",
    "description": "Внешние файлы и обработки 1С",
    "visibility": "private",
    "initialize_with_readme": true
  }' \
  "$API_URL/projects"

echo ""
echo "Projects created successfully!"
