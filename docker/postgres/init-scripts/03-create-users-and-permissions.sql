-- Скрипт создания дополнительных пользователей и настройки прав доступа

\c cicd;

-- Создание пользователя для CI/CD сервиса с полными правами на базу cicd
CREATE USER cicd_service WITH PASSWORD 'cicd_service_password';
GRANT ALL PRIVILEGES ON DATABASE cicd TO cicd_service;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO cicd_service;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO cicd_service;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO cicd_service;

-- Создание пользователя только для чтения (для мониторинга)
CREATE USER cicd_readonly WITH PASSWORD 'cicd_readonly_password';
GRANT CONNECT ON DATABASE cicd TO cicd_readonly;
GRANT USAGE ON SCHEMA public TO cicd_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO cicd_readonly;

-- Создание пользователя для метрик (может писать только в system_metrics)
CREATE USER cicd_metrics WITH PASSWORD 'cicd_metrics_password';
GRANT CONNECT ON DATABASE cicd TO cicd_metrics;
GRANT USAGE ON SCHEMA public TO cicd_metrics;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO cicd_metrics;
GRANT INSERT, UPDATE ON system_metrics TO cicd_metrics;
GRANT USAGE ON SEQUENCE system_metrics_id_seq TO cicd_metrics;

-- Настройка прав по умолчанию для новых таблиц
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO cicd_service;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO cicd_service;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO cicd_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO cicd_metrics;

-- Создание ролей для группировки прав
CREATE ROLE cicd_admin;
GRANT ALL PRIVILEGES ON DATABASE cicd TO cicd_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO cicd_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO cicd_admin;

CREATE ROLE cicd_reader;
GRANT CONNECT ON DATABASE cicd TO cicd_reader;
GRANT USAGE ON SCHEMA public TO cicd_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO cicd_reader;

CREATE ROLE cicd_writer;
GRANT CONNECT ON DATABASE cicd TO cicd_writer;
GRANT USAGE ON SCHEMA public TO cicd_writer;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO cicd_writer;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO cicd_writer;

-- Назначение ролей пользователям
GRANT cicd_admin TO cicd_service;
GRANT cicd_reader TO cicd_readonly;
GRANT cicd_writer TO cicd_metrics;

-- Настройка connection limits для пользователей
ALTER USER cicd_service CONNECTION LIMIT 20;
ALTER USER cicd_readonly CONNECTION LIMIT 10;
ALTER USER cicd_metrics CONNECTION LIMIT 5;

-- Настройка параметров для оптимизации производительности
ALTER DATABASE cicd SET shared_preload_libraries = 'pg_stat_statements';
ALTER DATABASE cicd SET log_statement = 'mod';
ALTER DATABASE cicd SET log_min_duration_statement = 1000;

-- Создание представлений для удобного мониторинга
CREATE OR REPLACE VIEW pipeline_summary AS
SELECT 
    pipeline_type,
    status,
    COUNT(*) as count,
    AVG(duration_seconds) as avg_duration_seconds,
    MIN(triggered_at) as first_pipeline,
    MAX(triggered_at) as last_pipeline
FROM pipelines 
GROUP BY pipeline_type, status;

CREATE OR REPLACE VIEW sonar_quality_summary AS
SELECT 
    sa.project_key,
    COUNT(*) as total_analyses,
    COUNT(CASE WHEN sa.quality_gate_status = 'PASSED' THEN 1 END) as passed_count,
    COUNT(CASE WHEN sa.quality_gate_status = 'FAILED' THEN 1 END) as failed_count,
    AVG(sa.bugs) as avg_bugs,
    AVG(sa.vulnerabilities) as avg_vulnerabilities,
    AVG(sa.code_smells) as avg_code_smells,
    AVG(sa.coverage_percent) as avg_coverage
FROM sonar_analysis sa
GROUP BY sa.project_key;

CREATE OR REPLACE VIEW external_files_summary AS
SELECT 
    file_type,
    processing_status,
    COUNT(*) as count,
    AVG(file_size_bytes) as avg_file_size,
    MIN(created_at) as first_file,
    MAX(created_at) as last_file
FROM external_files
GROUP BY file_type, processing_status;

CREATE OR REPLACE VIEW notification_summary AS
SELECT 
    notification_type,
    notification_status,
    COUNT(*) as count,
    AVG(retry_count) as avg_retry_count,
    MIN(created_at) as first_notification,
    MAX(created_at) as last_notification
FROM redmine_notifications
GROUP BY notification_type, notification_status;

-- Предоставление прав на представления
GRANT SELECT ON pipeline_summary TO cicd_reader, cicd_service;
GRANT SELECT ON sonar_quality_summary TO cicd_reader, cicd_service;
GRANT SELECT ON external_files_summary TO cicd_reader, cicd_service;
GRANT SELECT ON notification_summary TO cicd_reader, cicd_service;

-- Создание функций для получения статистики
CREATE OR REPLACE FUNCTION get_pipeline_stats(days_back INTEGER DEFAULT 7)
RETURNS TABLE(
    total_pipelines BIGINT,
    successful_pipelines BIGINT,
    failed_pipelines BIGINT,
    avg_duration_minutes NUMERIC,
    success_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_pipelines,
        COUNT(CASE WHEN status = 'success' THEN 1 END) as successful_pipelines,
        COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_pipelines,
        ROUND(AVG(duration_seconds) / 60.0, 2) as avg_duration_minutes,
        ROUND(
            COUNT(CASE WHEN status = 'success' THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 
            2
        ) as success_rate
    FROM pipelines 
    WHERE triggered_at >= NOW() - INTERVAL '1 day' * days_back;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_sonar_trends(days_back INTEGER DEFAULT 30)
RETURNS TABLE(
    analysis_date DATE,
    avg_bugs NUMERIC,
    avg_vulnerabilities NUMERIC,
    avg_code_smells NUMERIC,
    avg_coverage NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        DATE(sa.analysis_date) as analysis_date,
        ROUND(AVG(sa.bugs), 2) as avg_bugs,
        ROUND(AVG(sa.vulnerabilities), 2) as avg_vulnerabilities,
        ROUND(AVG(sa.code_smells), 2) as avg_code_smells,
        ROUND(AVG(sa.coverage_percent), 2) as avg_coverage
    FROM sonar_analysis sa
    WHERE sa.analysis_date >= NOW() - INTERVAL '1 day' * days_back
    GROUP BY DATE(sa.analysis_date)
    ORDER BY analysis_date;
END;
$$ LANGUAGE plpgsql;

-- Предоставление прав на функции
GRANT EXECUTE ON FUNCTION get_pipeline_stats(INTEGER) TO cicd_reader, cicd_service;
GRANT EXECUTE ON FUNCTION get_sonar_trends(INTEGER) TO cicd_reader, cicd_service;

-- Логирование создания пользователей и прав
DO $$
BEGIN
    RAISE NOTICE 'Users and permissions created successfully:';
    RAISE NOTICE '- cicd_service: Full access to cicd database';
    RAISE NOTICE '- cicd_readonly: Read-only access for monitoring';
    RAISE NOTICE '- cicd_metrics: Write access to metrics table';
    RAISE NOTICE 'Roles created: cicd_admin, cicd_reader, cicd_writer';
    RAISE NOTICE 'Views created: pipeline_summary, sonar_quality_summary, external_files_summary, notification_summary';
    RAISE NOTICE 'Functions created: get_pipeline_stats(), get_sonar_trends()';
END $$;