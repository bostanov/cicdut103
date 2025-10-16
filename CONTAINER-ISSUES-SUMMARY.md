# Проблемы с контейнерами - Резюме

**Дата:** 2025-10-15  
**Проблема:** Конфликты портов и сетевых настроек

---

## 🔴 Обнаруженные проблемы

### 1. Локальный PostgreSQL конфликтует с контейнером
- **Проблема:** Локальный PostgreSQL использует порт 5432
- **Эффект:** Контейнер PostgreSQL не может использовать тот же порт
- **Решение:** Контейнер PostgreSQL переназначен на порт **5433**

### 2. Контейнеры в разных сетях
- **Проблема:** Контейнеры не видят друг друга по имени
- **Причина:** Использовали стандартную сеть `bridge`
- **Решение:** Создана новая сеть `cicd-network`

### 3. Проблема прав доступа PostgreSQL
- **Проблема:** "FATAL: data directory has invalid permissions"
- **Причина:** Windows NTFS не совместима с правами Linux
- **Решение:** Использовать Docker volume вместо bind mount

---

## ✅ Примененные исправления

### Создана сеть cicd-network
```powershell
docker network create cicd-network
```

### PostgreSQL на порту 5433 с Docker volume
```powershell
docker volume create postgres_data

docker run -d \
  --name postgres_unified \
  --network cicd-network \
  -p 5433:5432 \
  -e POSTGRES_PASSWORD=postgres_admin_123 \
  -v postgres_data:/var/lib/postgresql/data \
  --restart unless-stopped \
  postgres:14
```

### Redmine в cicd-network
```powershell
docker run -d \
  --name redmine \
  --network cicd-network \
  -p 3000:3000 \
  -e REDMINE_DB_POSTGRES=postgres_unified \
  -e REDMINE_DB_PORT=5432 \
  -e REDMINE_DB_DATABASE=redmine \
  -e REDMINE_DB_USERNAME=redmine \
  -e REDMINE_DB_PASSWORD=redmine \
  --restart unless-stopped \
  redmine:5
```

### SonarQube в cicd-network
```powershell
docker run -d \
  --name sonarqube \
  --network cicd-network \
  -p 9000:9000 \
  -e SONAR_JDBC_URL="jdbc:postgresql://postgres_unified:5432/sonar" \
  -e SONAR_JDBC_USERNAME=sonar \
  -e SONAR_JDBC_PASSWORD=sonar \
  -v C:\docker\sonarqube\data:/opt/sonarqube/data \
  -v C:\docker\sonarqube\logs:/opt/sonarqube/logs \
  -v C:\docker\sonarqube\extensions:/opt/sonarqube/extensions \
  --restart unless-stopped \
  sonarqube:10.3-community
```

### GitLab в cicd-network
```powershell
docker run -d \
  --name gitlab \
  --network cicd-network \
  --hostname $env:COMPUTERNAME \
  -p 8929:80 \
  -p 2224:22 \
  -e GITLAB_ROOT_PASSWORD=Gitlab123Admin! \
  -e "GITLAB_OMNIBUS_CONFIG=external_url 'http://$env:COMPUTERNAME:8929'; gitlab_rails['gitlab_shell_ssh_port'] = 2224;" \
  -v C:\docker\gitlab\config:/etc/gitlab \
  -v C:\docker\gitlab\logs:/var/log/gitlab \
  -v C:\docker\gitlab\data:/var/opt/gitlab \
  --shm-size 256m \
  --restart unless-stopped \
  gitlab/gitlab-ce:latest
```

---

## 📝 Новая схема подключений

### Внешний доступ (с хоста)
- PostgreSQL:  `localhost:5433`
- GitLab:      `http://localhost:8929`
- SonarQube:   `http://localhost:9000`
- Redmine:     `http://localhost:3000`

### Внутренний доступ (между контейнерами)
- PostgreSQL:  `postgres_unified:5432`
- GitLab:      `gitlab:80`
- SonarQube:   `sonarqube:9000`
- Redmine:     `redmine:3000`

---

## ⚙️ Создание баз данных

После запуска PostgreSQL нужно создать базы:

```powershell
# Подождать готовности
docker exec postgres_unified pg_isready -U postgres

# Создать базу SonarQube
docker exec postgres_unified psql -U postgres -c "CREATE DATABASE sonar WITH ENCODING='UTF8';"
docker exec postgres_unified psql -U postgres -c "CREATE USER sonar WITH PASSWORD 'sonar';"
docker exec postgres_unified psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE sonar TO sonar;"
docker exec postgres_unified psql -U postgres -d sonar -c "GRANT ALL ON SCHEMA public TO sonar;"

# Создать базу Redmine
docker exec postgres_unified psql -U postgres -c "CREATE DATABASE redmine WITH ENCODING='UTF8';"
docker exec postgres_unified psql -U postgres -c "CREATE USER redmine WITH PASSWORD 'redmine';"
docker exec postgres_unified psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE redmine TO redmine;"
docker exec postgres_unified psql -U postgres -d redmine -c "GRANT ALL ON SCHEMA public TO redmine;"

# Перезапустить зависимые контейнеры
docker restart redmine sonarqube
```

---

## 🔧 Скрипты для автоматизации

### ci/scripts/fix-docker-network.ps1
Автоматически пересоздает все контейнеры в правильной сети

### ci/scripts/fix-containers.ps1  
Проверяет и исправляет проблемы с контейнерами

### check-environment.ps1
Комплексная проверка окружения

---

## ❗ Важно

1. **Локальный PostgreSQL должен быть остановлен**  
   Или используйте порт 5433 для контейнера

2. **Все контейнеры должны быть в cicd-network**  
   Иначе они не увидят друг друга

3. **Используйте Docker volumes для PostgreSQL**  
   Не используйте Windows папки - будут проблемы с правами

---

## 📊 Текущий статус

После всех исправлений статус должен быть:
- postgres_unified: Up, port 5433
- redmine: Up, port 3000
- sonarqube: Up, port 9000  
- gitlab: Up (health: starting), ports 8929, 2224

Инициализация GitLab займет 3-5 минут.

