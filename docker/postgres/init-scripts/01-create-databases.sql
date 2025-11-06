-- Скрипт инициализации баз данных для всех сервисов
-- Выполняется при первом запуске PostgreSQL контейнера

-- Создание базы данных для GitLab
CREATE DATABASE gitlab;
GRANT ALL PRIVILEGES ON DATABASE gitlab TO postgres;

-- Создание базы данных для Redmine  
CREATE DATABASE redmine;
GRANT ALL PRIVILEGES ON DATABASE redmine TO postgres;

-- Создание базы данных для SonarQube
CREATE DATABASE sonarqube;
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO postgres;

-- Создание базы данных для CI/CD метаданных
CREATE DATABASE cicd;
GRANT ALL PRIVILEGES ON DATABASE cicd TO postgres;

-- Настройка кодировки для корректной работы с русским языком
ALTER DATABASE gitlab SET client_encoding TO 'utf8';
ALTER DATABASE redmine SET client_encoding TO 'utf8';
ALTER DATABASE sonarqube SET client_encoding TO 'utf8';
ALTER DATABASE cicd SET client_encoding TO 'utf8';

-- Логирование успешного создания
\echo 'Databases created successfully: gitlab, redmine, sonarqube, cicd'