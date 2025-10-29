"""
PostgreSQL Client для управления данными интеграции CI/CD системы
"""
import os
import sys
import psycopg2
import psycopg2.extras
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional, Union
import json

# Добавление пути к shared модулям
sys.path.append('/app')

from shared.logger import get_logger, log_operation_start, log_operation_success, log_operation_error


class PostgreSQLClient:
    """Клиент для работы с PostgreSQL базой данных интеграций"""
    
    def __init__(self, host: str = None, port: int = None, database: str = None, 
                 user: str = None, password: str = None):
        self.logger = get_logger("postgres_client")
        
        # Параметры подключения из переменных окружения или параметров
        self.connection_params = {
            'host': host or os.getenv('POSTGRES_HOST', 'postgres'),
            'port': port or int(os.getenv('POSTGRES_PORT', '5432')),
            'database': database or os.getenv('POSTGRES_DB', 'cicd'),
            'user': user or os.getenv('POSTGRES_USER', 'cicd_service'),
            'password': password or os.getenv('POSTGRES_PASSWORD', 'cicd_service_password')
        }
        
        self.connection = None
        self._connect()
        
        self.logger.info("PostgreSQL client initialized", 
                        component="init",
                        details={
                            "host": self.connection_params['host'],
                            "port": self.connection_params['port'],
                            "database": self.connection_params['database'],
                            "user": self.connection_params['user']
                        })
    
    def _connect(self):
        """Установка соединения с базой данных"""
        try:
            self.connection = psycopg2.connect(**self.connection_params)
            self.connection.autocommit = True
            
            # Настройка для работы с JSON
            psycopg2.extras.register_uuid()
            
            self.logger.info("Connected to PostgreSQL", component="connection")
            
            # Создание схемы базы данных при первом подключении
            self._create_schema()
            
        except Exception as e:
            self.logger.error("Failed to connect to PostgreSQL", 
                            component="connection",
                            details={"error": str(e)})
            raise
    
    def _create_schema(self):
        """Создание схемы базы данных"""
        try:
            with self.connection.cursor() as cursor:
                # Создание таблицы конфигурации интеграций
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS integration_config (
                        id SERIAL PRIMARY KEY,
                        service_name VARCHAR(50) NOT NULL,
                        config_key VARCHAR(100) NOT NULL,
                        config_value TEXT,
                        is_secret BOOLEAN DEFAULT FALSE,
                        description TEXT,
                        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                        UNIQUE(service_name, config_key)
                    )
                """)
                
                # Создание таблицы метрик системы
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS system_metrics (
                        id SERIAL PRIMARY KEY,
                        metric_name VARCHAR(100) NOT NULL,
                        metric_value NUMERIC NOT NULL,
                        metric_unit VARCHAR(20),
                        service_name VARCHAR(50),
                        metadata JSONB,
                        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                    )
                """)
                
                # Создание таблицы логов операций
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS operation_logs (
                        id SERIAL PRIMARY KEY,
                        operation_type VARCHAR(50) NOT NULL,
                        service_name VARCHAR(50) NOT NULL,
                        status VARCHAR(20) NOT NULL,
                        details JSONB,
                        duration_seconds NUMERIC,
                        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                    )
                """)
                
                # Создание таблицы пайплайнов
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS pipelines (
                        id SERIAL PRIMARY KEY,
                        pipeline_id VARCHAR(100) UNIQUE NOT NULL,
                        pipeline_type VARCHAR(50) NOT NULL,
                        project_name VARCHAR(100) NOT NULL,
                        commit_hash VARCHAR(40),
                        branch_name VARCHAR(100),
                        status VARCHAR(20) DEFAULT 'pending',
                        triggered_by VARCHAR(100),
                        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                        triggered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                        started_at TIMESTAMP WITH TIME ZONE,
                        completed_at TIMESTAMP WITH TIME ZONE,
                        duration_seconds INTEGER,
                        metadata JSONB
                    )
                """)
                
                # Создание таблицы анализа SonarQube
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS sonar_analysis (
                        id SERIAL PRIMARY KEY,
                        pipeline_id INTEGER REFERENCES pipelines(id),
                        project_key VARCHAR(100) NOT NULL,
                        analysis_key VARCHAR(100) NOT NULL,
                        quality_gate_status VARCHAR(20) NOT NULL,
                        bugs INTEGER DEFAULT 0,
                        vulnerabilities INTEGER DEFAULT 0,
                        code_smells INTEGER DEFAULT 0,
                        coverage_percent NUMERIC(5,2),
                        duplicated_lines_percent NUMERIC(5,2),
                        lines_of_code INTEGER,
                        technical_debt_minutes INTEGER,
                        analysis_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                        dashboard_url TEXT,
                        report_data JSONB
                    )
                """)
                
                # Создание таблицы внешних файлов
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS external_files (
                        id SERIAL PRIMARY KEY,
                        redmine_issue_id INTEGER NOT NULL,
                        redmine_attachment_id INTEGER NOT NULL,
                        filename VARCHAR(255) NOT NULL,
                        file_type VARCHAR(50) NOT NULL,
                        file_size_bytes BIGINT,
                        file_path TEXT,
                        version VARCHAR(20) DEFAULT 'v1.0',
                        processing_status VARCHAR(20) DEFAULT 'pending',
                        decompiled_path TEXT,
                        git_commit_hash VARCHAR(40),
                        git_branch VARCHAR(100),
                        pipeline_id INTEGER REFERENCES pipelines(id),
                        sonar_analysis_id INTEGER REFERENCES sonar_analysis(id),
                        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                        processed_at TIMESTAMP WITH TIME ZONE
                    )
                """)
                
                # Создание таблицы уведомлений Redmine
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS redmine_notifications (
                        id SERIAL PRIMARY KEY,
                        redmine_issue_id INTEGER NOT NULL,
                        notification_type VARCHAR(50) NOT NULL,
                        message_title VARCHAR(255) NOT NULL,
                        message_body TEXT NOT NULL,
                        notification_status VARCHAR(20) DEFAULT 'pending',
                        pipeline_id INTEGER REFERENCES pipelines(id),
                        sonar_analysis_id INTEGER REFERENCES sonar_analysis(id),
                        external_file_id INTEGER REFERENCES external_files(id),
                        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                        sent_at TIMESTAMP WITH TIME ZONE,
                        retry_count INTEGER DEFAULT 0,
                        error_message TEXT
                    )
                """)
                
                # Создание индексов для производительности
                cursor.execute("""
                    CREATE INDEX IF NOT EXISTS idx_integration_config_service 
                    ON integration_config(service_name)
                """)
                
                cursor.execute("""
                    CREATE INDEX IF NOT EXISTS idx_system_metrics_name_time 
                    ON system_metrics(metric_name, created_at)
                """)
                
                cursor.execute("""
                    CREATE INDEX IF NOT EXISTS idx_operation_logs_service_time 
                    ON operation_logs(service_name, created_at)
                """)
                
                # Индексы для новых таблиц
                cursor.execute("""
                    CREATE INDEX IF NOT EXISTS idx_pipelines_type_status 
                    ON pipelines(pipeline_type, status)
                """)
                
                cursor.execute("""
                    CREATE INDEX IF NOT EXISTS idx_pipelines_project_triggered 
                    ON pipelines(project_name, triggered_at)
                """)
                
                cursor.execute("""
                    CREATE INDEX IF NOT EXISTS idx_sonar_analysis_project_date 
                    ON sonar_analysis(project_key, analysis_date)
                """)
                
                cursor.execute("""
                    CREATE INDEX IF NOT EXISTS idx_external_files_status 
                    ON external_files(processing_status)
                """)
                
                cursor.execute("""
                    CREATE INDEX IF NOT EXISTS idx_redmine_notifications_status 
                    ON redmine_notifications(notification_status)
                """)
                
                self.logger.info("Database schema created successfully", component="schema")
                
        except Exception as e:
            self.logger.error("Failed to create database schema", 
                            component="schema",
                            details={"error": str(e)})
            raise
    
    def _ensure_connection(self):
        """Проверка и восстановление соединения"""
        try:
            if self.connection.closed:
                self._connect()
            else:
                # Проверка соединения простым запросом
                with self.connection.cursor() as cursor:
                    cursor.execute("SELECT 1")
        except Exception:
            self._connect()
    
    def execute_query(self, query: str, params: tuple = None, fetch: bool = False) -> Optional[List[Dict]]:
        """Выполнение SQL запроса"""
        correlation_id = log_operation_start("postgres_client", "execute_query")
        
        try:
            self._ensure_connection()
            
            with self.connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute(query, params)
                
                if fetch:
                    result = [dict(row) for row in cursor.fetchall()]
                    log_operation_success("postgres_client", "execute_query", correlation_id,
                                        {"rows_returned": len(result)})
                    return result
                else:
                    log_operation_success("postgres_client", "execute_query", correlation_id,
                                        {"rows_affected": cursor.rowcount})
                    return None
                    
        except Exception as e:
            log_operation_error("postgres_client", "execute_query", correlation_id, e)
            raise
    
    # === Управление пайплайнами ===
    
    def create_pipeline(self, pipeline_type: str, project_name: str, 
                       commit_hash: str = None, branch_name: str = None,
                       triggered_by: str = None, metadata: Dict = None) -> int:
        """Создание записи о пайплайне"""
        query = """
        INSERT INTO pipelines (pipeline_type, project_name, commit_hash, branch_name, 
                              triggered_by, metadata, pipeline_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        RETURNING id
        """
        
        # Генерация уникального pipeline_id
        pipeline_id = f"{pipeline_type}_{project_name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        params = (
            pipeline_type, project_name, commit_hash, branch_name,
            triggered_by, json.dumps(metadata) if metadata else None,
            pipeline_id
        )
        
        result = self.execute_query(query, params, fetch=True)
        db_id = result[0]['id']
        
        self.logger.info("Pipeline created", 
                        component="pipeline_management",
                        details={
                            "db_id": db_id,
                            "pipeline_id": pipeline_id,
                            "type": pipeline_type,
                            "project": project_name
                        })
        
        return db_id
    
    def update_pipeline_status(self, pipeline_id: Union[int, str], status: str, 
                              duration_seconds: int = None, metadata: Dict = None):
        """Обновление статуса пайплайна"""
        # Определяем, передан ли ID базы данных или pipeline_id
        if isinstance(pipeline_id, int):
            where_clause = "id = %s"
        else:
            where_clause = "pipeline_id = %s"
        
        query = f"""
        UPDATE pipelines 
        SET status = %s, 
            completed_at = CASE WHEN %s IN ('success', 'failed', 'canceled') THEN NOW() ELSE completed_at END,
            started_at = CASE WHEN %s = 'running' AND started_at IS NULL THEN NOW() ELSE started_at END,
            duration_seconds = %s,
            metadata = COALESCE(%s::jsonb, metadata)
        WHERE {where_clause}
        """
        
        params = (
            status, status, status, duration_seconds,
            json.dumps(metadata) if metadata else None,
            pipeline_id
        )
        
        self.execute_query(query, params)
        
        self.logger.info("Pipeline status updated", 
                        component="pipeline_management",
                        details={
                            "pipeline_id": pipeline_id,
                            "status": status,
                            "duration_seconds": duration_seconds
                        })
    
    def get_pipeline_info(self, pipeline_id: Union[int, str]) -> Optional[Dict]:
        """Получение информации о пайплайне"""
        if isinstance(pipeline_id, int):
            where_clause = "id = %s"
        else:
            where_clause = "pipeline_id = %s"
        
        query = f"""
        SELECT * FROM pipelines WHERE {where_clause}
        """
        
        result = self.execute_query(query, (pipeline_id,), fetch=True)
        return result[0] if result else None
    
    def get_recent_pipelines(self, limit: int = 50, pipeline_type: str = None) -> List[Dict]:
        """Получение последних пайплайнов"""
        where_clause = ""
        params = []
        
        if pipeline_type:
            where_clause = "WHERE pipeline_type = %s"
            params.append(pipeline_type)
        
        query = f"""
        SELECT * FROM pipelines 
        {where_clause}
        ORDER BY triggered_at DESC 
        LIMIT %s
        """
        params.append(limit)
        
        return self.execute_query(query, tuple(params), fetch=True)
    
    # === Управление анализом SonarQube ===
    
    def save_sonar_analysis(self, pipeline_id: int, project_key: str, analysis_key: str,
                           quality_gate_status: str, bugs: int = 0, vulnerabilities: int = 0,
                           code_smells: int = 0, coverage_percent: float = None,
                           duplicated_lines_percent: float = None, lines_of_code: int = None,
                           technical_debt_minutes: int = None, dashboard_url: str = None,
                           report_data: Dict = None) -> int:
        """Сохранение результатов анализа SonarQube"""
        query = """
        INSERT INTO sonar_analysis (
            pipeline_id, project_key, analysis_key, quality_gate_status,
            bugs, vulnerabilities, code_smells, coverage_percent,
            duplicated_lines_percent, lines_of_code, technical_debt_minutes,
            analysis_date, dashboard_url, report_data
        ) VALUES (
            %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW(), %s, %s
        ) RETURNING id
        """
        
        params = (
            pipeline_id, project_key, analysis_key, quality_gate_status,
            bugs, vulnerabilities, code_smells, coverage_percent,
            duplicated_lines_percent, lines_of_code, technical_debt_minutes,
            dashboard_url, json.dumps(report_data) if report_data else None
        )
        
        result = self.execute_query(query, params, fetch=True)
        analysis_id = result[0]['id']
        
        self.logger.info("SonarQube analysis saved", 
                        component="sonar_management",
                        details={
                            "analysis_id": analysis_id,
                            "pipeline_id": pipeline_id,
                            "project_key": project_key,
                            "quality_gate_status": quality_gate_status
                        })
        
        return analysis_id
    
    def get_sonar_analysis_by_pipeline(self, pipeline_id: int) -> Optional[Dict]:
        """Получение анализа SonarQube по ID пайплайна"""
        query = """
        SELECT * FROM sonar_analysis 
        WHERE pipeline_id = %s 
        ORDER BY analysis_date DESC 
        LIMIT 1
        """
        
        result = self.execute_query(query, (pipeline_id,), fetch=True)
        return result[0] if result else None
    
    def get_sonar_trends(self, project_key: str, days_back: int = 30) -> List[Dict]:
        """Получение трендов качества кода"""
        query = """
        SELECT 
            DATE(analysis_date) as analysis_date,
            AVG(bugs) as avg_bugs,
            AVG(vulnerabilities) as avg_vulnerabilities,
            AVG(code_smells) as avg_code_smells,
            AVG(coverage_percent) as avg_coverage
        FROM sonar_analysis 
        WHERE project_key = %s 
          AND analysis_date >= NOW() - INTERVAL '%s days'
        GROUP BY DATE(analysis_date)
        ORDER BY analysis_date
        """
        
        return self.execute_query(query, (project_key, days_back), fetch=True)
    
    # === Управление внешними файлами ===
    
    def create_external_file_record(self, redmine_issue_id: int, redmine_attachment_id: int,
                                   filename: str, file_type: str, file_size_bytes: int = None,
                                   file_path: str = None, version: str = "v1.0") -> int:
        """Создание записи о внешнем файле"""
        query = """
        INSERT INTO external_files (
            redmine_issue_id, redmine_attachment_id, filename, file_type,
            file_size_bytes, file_path, version
        ) VALUES (%s, %s, %s, %s, %s, %s, %s)
        RETURNING id
        """
        
        params = (
            redmine_issue_id, redmine_attachment_id, filename, file_type,
            file_size_bytes, file_path, version
        )
        
        result = self.execute_query(query, params, fetch=True)
        file_id = result[0]['id']
        
        self.logger.info("External file record created", 
                        component="external_files",
                        details={
                            "file_id": file_id,
                            "redmine_issue_id": redmine_issue_id,
                            "filename": filename,
                            "file_type": file_type
                        })
        
        return file_id
    
    def update_external_file_status(self, file_id: int, processing_status: str,
                                   decompiled_path: str = None, git_commit_hash: str = None,
                                   git_branch: str = None, pipeline_id: int = None,
                                   sonar_analysis_id: int = None):
        """Обновление статуса обработки внешнего файла"""
        query = """
        UPDATE external_files 
        SET processing_status = %s,
            decompiled_path = COALESCE(%s, decompiled_path),
            git_commit_hash = COALESCE(%s, git_commit_hash),
            git_branch = COALESCE(%s, git_branch),
            pipeline_id = COALESCE(%s, pipeline_id),
            sonar_analysis_id = COALESCE(%s, sonar_analysis_id),
            processed_at = CASE WHEN %s IN ('completed', 'failed') THEN NOW() ELSE processed_at END
        WHERE id = %s
        """
        
        params = (
            processing_status, decompiled_path, git_commit_hash, git_branch,
            pipeline_id, sonar_analysis_id, processing_status, file_id
        )
        
        self.execute_query(query, params)
        
        self.logger.info("External file status updated", 
                        component="external_files",
                        details={
                            "file_id": file_id,
                            "processing_status": processing_status
                        })
    
    def get_external_file_by_attachment(self, redmine_attachment_id: int) -> Optional[Dict]:
        """Получение записи внешнего файла по ID вложения Redmine"""
        query = """
        SELECT * FROM external_files 
        WHERE redmine_attachment_id = %s 
        ORDER BY created_at DESC 
        LIMIT 1
        """
        
        result = self.execute_query(query, (redmine_attachment_id,), fetch=True)
        return result[0] if result else None
    
    def get_pending_external_files(self) -> List[Dict]:
        """Получение файлов, ожидающих обработки"""
        query = """
        SELECT * FROM external_files 
        WHERE processing_status = 'pending'
        ORDER BY created_at ASC
        """
        
        return self.execute_query(query, fetch=True)
    
    # === Управление уведомлениями ===
    
    def create_notification(self, redmine_issue_id: int, notification_type: str,
                           message_title: str, message_body: str,
                           pipeline_id: int = None, sonar_analysis_id: int = None,
                           external_file_id: int = None) -> int:
        """Создание уведомления для Redmine"""
        query = """
        INSERT INTO redmine_notifications (
            redmine_issue_id, notification_type, message_title, message_body,
            pipeline_id, sonar_analysis_id, external_file_id
        ) VALUES (%s, %s, %s, %s, %s, %s, %s)
        RETURNING id
        """
        
        params = (
            redmine_issue_id, notification_type, message_title, message_body,
            pipeline_id, sonar_analysis_id, external_file_id
        )
        
        result = self.execute_query(query, params, fetch=True)
        notification_id = result[0]['id']
        
        self.logger.info("Notification created", 
                        component="notifications",
                        details={
                            "notification_id": notification_id,
                            "redmine_issue_id": redmine_issue_id,
                            "type": notification_type
                        })
        
        return notification_id
    
    def update_notification_status(self, notification_id: int, status: str, error_message: str = None):
        """Обновление статуса уведомления"""
        query = """
        UPDATE redmine_notifications 
        SET notification_status = %s,
            sent_at = CASE WHEN %s = 'sent' THEN NOW() ELSE sent_at END,
            error_message = %s,
            retry_count = CASE WHEN %s = 'failed' THEN retry_count + 1 ELSE retry_count END
        WHERE id = %s
        """
        
        params = (status, status, error_message, status, notification_id)
        self.execute_query(query, params)
    
    def get_pending_notifications(self, limit: int = 100) -> List[Dict]:
        """Получение уведомлений, ожидающих отправки"""
        query = """
        SELECT * FROM redmine_notifications 
        WHERE notification_status = 'pending' 
           OR (notification_status = 'failed' AND retry_count < 3)
        ORDER BY created_at ASC
        LIMIT %s
        """
        
        return self.execute_query(query, (limit,), fetch=True)
    
    # === Управление конфигурацией ===
    
    def get_config_value(self, service_name: str, config_key: str) -> Optional[str]:
        """Получение значения конфигурации"""
        query = """
        SELECT config_value FROM integration_config 
        WHERE service_name = %s AND config_key = %s
        """
        
        result = self.execute_query(query, (service_name, config_key), fetch=True)
        return result[0]['config_value'] if result else None
    
    def set_config_value(self, service_name: str, config_key: str, config_value: str,
                        is_secret: bool = False, description: str = None):
        """Установка значения конфигурации"""
        query = """
        INSERT INTO integration_config (service_name, config_key, config_value, is_secret, description)
        VALUES (%s, %s, %s, %s, %s)
        ON CONFLICT (service_name, config_key) 
        DO UPDATE SET 
            config_value = EXCLUDED.config_value,
            is_secret = EXCLUDED.is_secret,
            description = COALESCE(EXCLUDED.description, integration_config.description),
            updated_at = NOW()
        """
        
        params = (service_name, config_key, config_value, is_secret, description)
        self.execute_query(query, params)
        
        self.logger.info("Configuration updated", 
                        component="config_management",
                        details={
                            "service_name": service_name,
                            "config_key": config_key,
                            "is_secret": is_secret
                        })
    
    def get_service_config(self, service_name: str) -> Dict[str, str]:
        """Получение всей конфигурации сервиса"""
        query = """
        SELECT config_key, config_value FROM integration_config 
        WHERE service_name = %s AND is_secret = FALSE
        """
        
        result = self.execute_query(query, (service_name,), fetch=True)
        return {row['config_key']: row['config_value'] for row in result}
    
    # === Метрики системы ===
    
    def save_metric(self, metric_name: str, metric_value: float, metric_unit: str = None,
                   service_name: str = None, metadata: Dict = None):
        """Сохранение метрики системы"""
        query = """
        INSERT INTO system_metrics (metric_name, metric_value, metric_unit, service_name, metadata)
        VALUES (%s, %s, %s, %s, %s)
        """
        
        params = (
            metric_name, metric_value, metric_unit, service_name,
            json.dumps(metadata) if metadata else None
        )
        
        self.execute_query(query, params)
    
    def get_metrics(self, metric_name: str = None, service_name: str = None,
                   hours_back: int = 24, limit: int = 1000) -> List[Dict]:
        """Получение метрик системы"""
        where_conditions = ["timestamp >= NOW() - INTERVAL '%s hours'"]
        params = [hours_back]
        
        if metric_name:
            where_conditions.append("metric_name = %s")
            params.append(metric_name)
        
        if service_name:
            where_conditions.append("service_name = %s")
            params.append(service_name)
        
        params.append(limit)
        
        query = f"""
        SELECT * FROM system_metrics 
        WHERE {' AND '.join(where_conditions)}
        ORDER BY timestamp DESC
        LIMIT %s
        """
        
        return self.execute_query(query, tuple(params), fetch=True)
    
    # === Статистика и отчеты ===
    
    def get_pipeline_statistics(self, days_back: int = 7) -> Dict:
        """Получение статистики пайплайнов"""
        query = """
        SELECT 
            COUNT(*) as total_pipelines,
            COUNT(CASE WHEN status = 'success' THEN 1 END) as successful_pipelines,
            COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_pipelines,
            COUNT(CASE WHEN status = 'running' THEN 1 END) as running_pipelines,
            ROUND(AVG(duration_seconds) / 60.0, 2) as avg_duration_minutes,
            ROUND(
                COUNT(CASE WHEN status = 'success' THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 
                2
            ) as success_rate
        FROM pipelines 
        WHERE triggered_at >= NOW() - INTERVAL '%s days'
        """
        
        result = self.execute_query(query, (days_back,), fetch=True)
        return result[0] if result else {}
    
    def get_quality_gate_summary(self, days_back: int = 30) -> Dict:
        """Получение сводки по Quality Gates"""
        query = """
        SELECT 
            project_key,
            COUNT(*) as total_analyses,
            COUNT(CASE WHEN quality_gate_status = 'PASSED' THEN 1 END) as passed_count,
            COUNT(CASE WHEN quality_gate_status = 'FAILED' THEN 1 END) as failed_count,
            AVG(bugs) as avg_bugs,
            AVG(vulnerabilities) as avg_vulnerabilities,
            AVG(code_smells) as avg_code_smells,
            AVG(coverage_percent) as avg_coverage
        FROM sonar_analysis 
        WHERE analysis_date >= NOW() - INTERVAL '%s days'
        GROUP BY project_key
        """
        
        return self.execute_query(query, (days_back,), fetch=True)
    
    def close(self):
        """Закрытие соединения с базой данных"""
        if self.connection and not self.connection.closed:
            self.connection.close()
            self.logger.info("PostgreSQL connection closed", component="connection")


# Глобальный экземпляр клиента
_postgres_client = None


def get_postgres_client() -> PostgreSQLClient:
    """Получение глобального экземпляра PostgreSQL клиента"""
    global _postgres_client
    if _postgres_client is None:
        _postgres_client = PostgreSQLClient()
    return _postgres_client