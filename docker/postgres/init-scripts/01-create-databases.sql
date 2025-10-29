-- Скрипт создания всех баз данных для CI/CD системы
-- Выполняется при первом запуске PostgreSQL контейнера

-- Создание пользователей и баз данных для всех сервисов

-- GitLab database
CREATE USER gitlab WITH PASSWORD 'gitlab_password';
CREATE DATABASE gitlab OWNER gitlab;
GRANT ALL PRIVILEGES ON DATABASE gitlab TO gitlab;

-- Redmine database  
CREATE USER redmine WITH PASSWORD 'redmine_password';
CREATE DATABASE redmine OWNER redmine;
GRANT ALL PRIVILEGES ON DATABASE redmine TO redmine;

-- SonarQube database
CREATE USER sonarqube WITH PASSWORD 'sonarqube_password';
CREATE DATABASE sonarqube OWNER sonarqube;
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonarqube;

-- CI/CD metadata database
CREATE USER cicd WITH PASSWORD 'cicd_password';
CREATE DATABASE cicd OWNER cicd;
GRANT ALL PRIVILEGES ON DATABASE cicd TO cicd;

-- Настройка кодировки и локали для всех баз данных
ALTER DATABASE gitlab SET timezone TO 'UTC';
ALTER DATABASE redmine SET timezone TO 'UTC';
ALTER DATABASE sonarqube SET timezone TO 'UTC';
ALTER DATABASE cicd SET timezone TO 'UTC';

-- Логирование создания баз данных
DO $$
BEGIN
    RAISE NOTICE 'All databases created successfully:';
    RAISE NOTICE '- GitLab database: gitlab (user: gitlab)';
    RAISE NOTICE '- Redmine database: redmine (user: redmine)';
    RAISE NOTICE '- SonarQube database: sonarqube (user: sonarqube)';
    RAISE NOTICE '- CI/CD database: cicd (user: cicd)';
END $$;