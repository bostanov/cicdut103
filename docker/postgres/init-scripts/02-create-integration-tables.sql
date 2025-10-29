-- Скрипт создания таблиц для интеграции между сервисами
-- Подключение к базе данных cicd

\c cicd;

-- Таблица для отслеживания пайплайнов
CREATE TABLE IF NOT EXISTS pipelines (
    id SERIAL PRIMARY KEY,
    pipeline_id VARCHAR(255) NOT NULL,
    pipeline_type VARCHAR(50) NOT NULL, -- 'gitsync', 'precommit1c', 'manual'
    project_name VARCHAR(255) NOT NULL,
    commit_hash VARCHAR(255),
    branch_name VARCHAR(255),
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- 'pending', 'running', 'success', 'failed', 'canceled'
    triggered_by VARCHAR(255),
    triggered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    duration_seconds INTEGER,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Таблица для результатов анализа SonarQube
CREATE TABLE IF NOT EXISTS sonar_analysis (
    id SERIAL PRIMARY KEY,
    pipeline_id INTEGER REFERENCES pipelines(id),
    project_key VARCHAR(255) NOT NULL,
    analysis_key VARCHAR(255) NOT NULL,
    quality_gate_status VARCHAR(50), -- 'PASSED', 'FAILED', 'PENDING'
    bugs INTEGER DEFAULT 0,
    vulnerabilities INTEGER DEFAULT 0,
    code_smells INTEGER DEFAULT 0,
    coverage_percent DECIMAL(5,2),
    duplicated_lines_percent DECIMAL(5,2),
    lines_of_code INTEGER,
    technical_debt_minutes INTEGER,
    analysis_date TIMESTAMP WITH TIME ZONE,
    dashboard_url TEXT,
    report_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Таблица для отслеживания внешних файлов
CREATE TABLE IF NOT EXISTS external_files (
    id SERIAL PRIMARY KEY,
    redmine_issue_id INTEGER NOT NULL,
    redmine_attachment_id INTEGER NOT NULL,
    filename VARCHAR(255) NOT NULL,
    file_type VARCHAR(10) NOT NULL, -- 'epf', 'erf', 'efd'
    file_size_bytes BIGINT,
    file_path TEXT,
    decompiled_path TEXT,
    git_commit_hash VARCHAR(255),
    git_branch VARCHAR(255),
    processing_status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'failed'
    pipeline_id INTEGER REFERENCES pipelines(id),
    sonar_analysis_id INTEGER REFERENCES sonar_analysis(id),
    version VARCHAR(50) DEFAULT 'v1.0',
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Таблица для уведомлений в Redmine
CREATE TABLE IF NOT EXISTS redmine_notifications (
    id SERIAL PRIMARY KEY,
    redmine_issue_id INTEGER NOT NULL,
    notification_type VARCHAR(50) NOT NULL, -- 'pipeline_result', 'sonar_analysis', 'file_processed'
    pipeline_id INTEGER REFERENCES pipelines(id),
    sonar_analysis_id INTEGER REFERENCES sonar_analysis(id),
    external_file_id INTEGER REFERENCES external_files(id),
    message_title VARCHAR(255),
    message_body TEXT,
    notification_status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'sent', 'failed'
    sent_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Таблица для конфигурации интеграций
CREATE TABLE IF NOT EXISTS integration_config (
    id SERIAL PRIMARY KEY,
    service_name VARCHAR(50) NOT NULL UNIQUE, -- 'gitlab', 'redmine', 'sonarqube'
    config_key VARCHAR(100) NOT NULL,
    config_value TEXT,
    is_secret BOOLEAN DEFAULT FALSE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(service_name, config_key)
);

-- Таблица для метрик системы
CREATE TABLE IF NOT EXISTS system_metrics (
    id SERIAL PRIMARY KEY,
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL(15,4),
    metric_unit VARCHAR(20),
    service_name VARCHAR(50),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB
);

-- Создание индексов для производительности
CREATE INDEX IF NOT EXISTS idx_pipelines_status ON pipelines(status);
CREATE INDEX IF NOT EXISTS idx_pipelines_type ON pipelines(pipeline_type);
CREATE INDEX IF NOT EXISTS idx_pipelines_triggered_at ON pipelines(triggered_at);
CREATE INDEX IF NOT EXISTS idx_pipelines_project_name ON pipelines(project_name);

CREATE INDEX IF NOT EXISTS idx_sonar_analysis_pipeline_id ON sonar_analysis(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_sonar_analysis_project_key ON sonar_analysis(project_key);
CREATE INDEX IF NOT EXISTS idx_sonar_analysis_quality_gate ON sonar_analysis(quality_gate_status);

CREATE INDEX IF NOT EXISTS idx_external_files_redmine_issue ON external_files(redmine_issue_id);
CREATE INDEX IF NOT EXISTS idx_external_files_status ON external_files(processing_status);
CREATE INDEX IF NOT EXISTS idx_external_files_pipeline_id ON external_files(pipeline_id);

CREATE INDEX IF NOT EXISTS idx_redmine_notifications_issue_id ON redmine_notifications(redmine_issue_id);
CREATE INDEX IF NOT EXISTS idx_redmine_notifications_status ON redmine_notifications(notification_status);
CREATE INDEX IF NOT EXISTS idx_redmine_notifications_type ON redmine_notifications(notification_type);

CREATE INDEX IF NOT EXISTS idx_integration_config_service ON integration_config(service_name);
CREATE INDEX IF NOT EXISTS idx_system_metrics_name_timestamp ON system_metrics(metric_name, timestamp);

-- Создание функции для автоматического обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Создание триггеров для автоматического обновления updated_at
CREATE TRIGGER update_pipelines_updated_at BEFORE UPDATE ON pipelines
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_external_files_updated_at BEFORE UPDATE ON external_files
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_integration_config_updated_at BEFORE UPDATE ON integration_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Вставка начальных данных конфигурации
INSERT INTO integration_config (service_name, config_key, config_value, description) VALUES
('gitlab', 'base_url', 'http://gitlab', 'GitLab base URL'),
('gitlab', 'main_project_name', 'ut103-ci', 'Main 1C project name'),
('gitlab', 'external_files_project_name', 'ut103-external-files', 'External files project name'),
('redmine', 'base_url', 'http://redmine:3000', 'Redmine base URL'),
('redmine', 'main_project_identifier', 'ut103-ci', 'Main project identifier in Redmine'),
('sonarqube', 'base_url', 'http://sonarqube:9000', 'SonarQube base URL'),
('sonarqube', 'main_project_key', 'ut103-ci', 'Main project key in SonarQube'),
('sonarqube', 'external_files_project_key', 'ut103-external-files', 'External files project key in SonarQube')
ON CONFLICT (service_name, config_key) DO NOTHING;

-- Логирование создания таблиц
DO $$
BEGIN
    RAISE NOTICE 'Integration tables created successfully:';
    RAISE NOTICE '- pipelines: Pipeline tracking and metadata';
    RAISE NOTICE '- sonar_analysis: SonarQube analysis results';
    RAISE NOTICE '- external_files: External file processing tracking';
    RAISE NOTICE '- redmine_notifications: Notification queue for Redmine';
    RAISE NOTICE '- integration_config: Service configuration storage';
    RAISE NOTICE '- system_metrics: System performance metrics';
    RAISE NOTICE 'All indexes and triggers created successfully';
END $$;