-- Скрипт создания таблиц для интеграции между сервисами
-- Подключаемся к базе данных cicd

\c cicd;

-- Таблица для отслеживания пайплайнов
CREATE TABLE IF NOT EXISTS pipelines (
    id SERIAL PRIMARY KEY,
    pipeline_type VARCHAR(50) NOT NULL, -- 'gitsync' или 'precommit1c'
    gitlab_project_id INTEGER,
    gitlab_pipeline_id INTEGER,
    redmine_issue_id INTEGER,
    sonarqube_project_key VARCHAR(255),
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'running', 'success', 'failed'
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details JSONB
);

-- Таблица для отслеживания синхронизации GitSync
CREATE TABLE IF NOT EXISTS sync_history (
    id SERIAL PRIMARY KEY,
    sync_type VARCHAR(50) NOT NULL DEFAULT 'gitsync',
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    status VARCHAR(20) NOT NULL, -- 'running', 'completed', 'failed'
    changes_count INTEGER DEFAULT 0,
    files_processed INTEGER DEFAULT 0,
    git_commit_hash VARCHAR(40),
    details JSONB,
    pipeline_id INTEGER REFERENCES pipelines(id)
);

-- Таблица для отслеживания анализа SonarQube
CREATE TABLE IF NOT EXISTS sonar_analysis (
    id SERIAL PRIMARY KEY,
    project_key VARCHAR(255) NOT NULL,
    analysis_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    quality_gate_status VARCHAR(20),
    bugs INTEGER DEFAULT 0,
    vulnerabilities INTEGER DEFAULT 0,
    code_smells INTEGER DEFAULT 0,
    coverage DECIMAL(5,2),
    duplicated_lines_density DECIMAL(5,2),
    gitlab_commit_hash VARCHAR(40),
    redmine_issue_id INTEGER,
    pipeline_id INTEGER REFERENCES pipelines(id)
);

-- Таблица для отслеживания внешних файлов
CREATE TABLE IF NOT EXISTS external_files (
    id SERIAL PRIMARY KEY,
    redmine_issue_id INTEGER NOT NULL,
    redmine_attachment_id INTEGER NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_size BIGINT,
    processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'downloaded', -- 'downloaded', 'decompiled', 'analyzed', 'committed'
    gitlab_commit_hash VARCHAR(40),
    gitlab_branch VARCHAR(255),
    sonarqube_analysis_id INTEGER REFERENCES sonar_analysis(id),
    pipeline_id INTEGER REFERENCES pipelines(id),
    details JSONB
);

-- Таблица для отслеживания уведомлений
CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    notification_type VARCHAR(50) NOT NULL, -- 'pipeline_completed', 'analysis_failed', etc.
    target_service VARCHAR(50) NOT NULL, -- 'redmine', 'gitlab'
    target_id INTEGER NOT NULL, -- issue_id или project_id
    message TEXT NOT NULL,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'sent', 'failed'
    pipeline_id INTEGER REFERENCES pipelines(id),
    details JSONB
);

-- Индексы для производительности
CREATE INDEX IF NOT EXISTS idx_pipelines_type_status ON pipelines(pipeline_type, status);
CREATE INDEX IF NOT EXISTS idx_pipelines_created_at ON pipelines(created_at);
CREATE INDEX IF NOT EXISTS idx_sync_history_status ON sync_history(status);
CREATE INDEX IF NOT EXISTS idx_sync_history_started_at ON sync_history(started_at);
CREATE INDEX IF NOT EXISTS idx_sonar_analysis_project_date ON sonar_analysis(project_key, analysis_date);
CREATE INDEX IF NOT EXISTS idx_external_files_issue_status ON external_files(redmine_issue_id, status);
CREATE INDEX IF NOT EXISTS idx_external_files_processed_at ON external_files(processed_at);
CREATE INDEX IF NOT EXISTS idx_notifications_target ON notifications(target_service, target_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON notifications(status);

-- Логирование успешного создания
\echo 'Integration tables created successfully in cicd database';