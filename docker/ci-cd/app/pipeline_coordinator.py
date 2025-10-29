"""
Pipeline Coordinator - координация выполнения пайплайнов и управление очередью
"""
import os
import sys
import time
import json
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional

# Добавление пути к shared модулям
sys.path.append('/app')

from shared.logger import get_logger, log_operation_start, log_operation_success, log_operation_error
from integrations import (
    get_postgres_client, get_gitlab_client, 
    get_sonarqube_client, get_redmine_client
)


class PipelineCoordinator:
    """Координатор выполнения пайплайнов"""
    
    def __init__(self):
        self.logger = get_logger("pipeline_coordinator")
        
        # Клиенты интеграции
        self.postgres_client = get_postgres_client()
        self.gitlab_client = get_gitlab_client()
        self.sonarqube_client = get_sonarqube_client()
        self.redmine_client = get_redmine_client()
        
        # Активные пайплайны
        self.active_pipelines = {}
        
        # Конфигурация
        self.monitoring_interval = int(os.getenv('PIPELINE_MONITORING_INTERVAL', '30'))  # 30 секунд
        
        self.logger.info("Pipeline coordinator initialized", 
                        component="init",
                        details={"monitoring_interval": self.monitoring_interval})
    
    def trigger_gitsync_pipeline(self, commit_hash: str, changes_info: List[Dict], 
                                project_name: str = "ut103-ci") -> Optional[int]:
        """Запуск пайплайна после GitSync"""
        correlation_id = log_operation_start("pipeline_coordinator", "trigger_gitsync_pipeline",
                                           {"commit_hash": commit_hash, "project": project_name})
        
        try:
            # Создание записи в базе данных
            pipeline_db_id = self.postgres_client.create_pipeline(
                pipeline_type="gitsync",
                project_name=project_name,
                commit_hash=commit_hash,
                triggered_by="gitsync_service",
                metadata={
                    "changes_count": len(changes_info),
                    "changes": changes_info[:10]  # Ограничиваем количество для логов
                }
            )
            
            # Получение ID проекта GitLab
            gitlab_project_id = self.postgres_client.get_config_value('gitlab', 'main_project_id')
            if not gitlab_project_id:
                raise Exception("GitLab main project ID not found in configuration")
            
            # Запуск пайплайна в GitLab
            pipeline_variables = {
                'PIPELINE_TYPE': 'gitsync',
                'COMMIT_HASH': commit_hash,
                'CHANGES_COUNT': str(len(changes_info)),
                'DB_PIPELINE_ID': str(pipeline_db_id)
            }
            
            gitlab_pipeline = self.gitlab_client.trigger_pipeline(
                project_id=int(gitlab_project_id),
                ref='main',
                variables=pipeline_variables
            )
            
            if gitlab_pipeline:
                # Обновление записи с ID GitLab пайплайна
                self.postgres_client.update_pipeline_status(
                    pipeline_db_id, 
                    "running",
                    metadata={
                        "gitlab_pipeline_id": gitlab_pipeline['id'],
                        "gitlab_pipeline_url": gitlab_pipeline.get('web_url')
                    }
                )
                
                # Добавление в список активных пайплайнов
                self.active_pipelines[pipeline_db_id] = {
                    "gitlab_project_id": int(gitlab_project_id),
                    "gitlab_pipeline_id": gitlab_pipeline['id'],
                    "type": "gitsync",
                    "started_at": datetime.now(timezone.utc)
                }
                
                log_operation_success("pipeline_coordinator", "trigger_gitsync_pipeline", correlation_id,
                                    {"db_pipeline_id": pipeline_db_id, "gitlab_pipeline_id": gitlab_pipeline['id']})
                
                return pipeline_db_id
            else:
                raise Exception("Failed to trigger GitLab pipeline")
                
        except Exception as e:
            log_operation_error("pipeline_coordinator", "trigger_gitsync_pipeline", correlation_id, e)
            
            # Обновление статуса на failed
            if 'pipeline_db_id' in locals():
                self.postgres_client.update_pipeline_status(pipeline_db_id, "failed")
            
            return None
    
    def trigger_precommit_pipeline(self, redmine_issue_id: int, file_info: Dict[str, Any],
                                  external_file_id: int) -> Optional[int]:
        """Запуск пайплайна для внешнего файла"""
        correlation_id = log_operation_start("pipeline_coordinator", "trigger_precommit_pipeline",
                                           {"redmine_issue_id": redmine_issue_id, "file_id": external_file_id})
        
        try:
            # Создание записи в базе данных
            pipeline_db_id = self.postgres_client.create_pipeline(
                pipeline_type="precommit1c",
                project_name="ut103-external-files",
                branch_name=f"external-file-{redmine_issue_id}",
                triggered_by="precommit1c_service",
                metadata={
                    "redmine_issue_id": redmine_issue_id,
                    "external_file_id": external_file_id,
                    "file_info": file_info
                }
            )
            
            # Получение ID проекта GitLab для внешних файлов
            gitlab_project_id = self.postgres_client.get_config_value('gitlab', 'external_project_id')
            if not gitlab_project_id:
                raise Exception("GitLab external files project ID not found in configuration")
            
            # Запуск пайплайна в GitLab
            branch_name = f"external-file-{redmine_issue_id}"
            pipeline_variables = {
                'PIPELINE_TYPE': 'precommit1c',
                'REDMINE_ISSUE_ID': str(redmine_issue_id),
                'EXTERNAL_FILE_ID': str(external_file_id),
                'FILE_NAME': file_info.get('filename', 'unknown'),
                'DB_PIPELINE_ID': str(pipeline_db_id)
            }
            
            gitlab_pipeline = self.gitlab_client.trigger_pipeline(
                project_id=int(gitlab_project_id),
                ref=branch_name,
                variables=pipeline_variables
            )
            
            if gitlab_pipeline:
                # Обновление записи с ID GitLab пайплайна
                self.postgres_client.update_pipeline_status(
                    pipeline_db_id, 
                    "running",
                    metadata={
                        "gitlab_pipeline_id": gitlab_pipeline['id'],
                        "gitlab_pipeline_url": gitlab_pipeline.get('web_url'),
                        "redmine_issue_id": redmine_issue_id,
                        "external_file_id": external_file_id
                    }
                )
                
                # Обновление статуса внешнего файла
                self.postgres_client.update_external_file_status(
                    external_file_id,
                    "processing",
                    pipeline_id=pipeline_db_id
                )
                
                # Добавление в список активных пайплайнов
                self.active_pipelines[pipeline_db_id] = {
                    "gitlab_project_id": int(gitlab_project_id),
                    "gitlab_pipeline_id": gitlab_pipeline['id'],
                    "type": "precommit1c",
                    "redmine_issue_id": redmine_issue_id,
                    "external_file_id": external_file_id,
                    "started_at": datetime.now(timezone.utc)
                }
                
                log_operation_success("pipeline_coordinator", "trigger_precommit_pipeline", correlation_id,
                                    {"db_pipeline_id": pipeline_db_id, "gitlab_pipeline_id": gitlab_pipeline['id']})
                
                return pipeline_db_id
            else:
                raise Exception("Failed to trigger GitLab pipeline")
                
        except Exception as e:
            log_operation_error("pipeline_coordinator", "trigger_precommit_pipeline", correlation_id, e)
            
            # Обновление статуса на failed
            if 'pipeline_db_id' in locals():
                self.postgres_client.update_pipeline_status(pipeline_db_id, "failed")
                if 'external_file_id' in locals():
                    self.postgres_client.update_external_file_status(external_file_id, "failed")
            
            return None
    
    def monitor_active_pipelines(self):
        """Мониторинг активных пайплайнов"""
        correlation_id = log_operation_start("pipeline_coordinator", "monitor_pipelines")
        
        try:
            completed_pipelines = []
            
            for pipeline_db_id, pipeline_info in self.active_pipelines.items():
                try:
                    # Получение статуса пайплайна из GitLab
                    gitlab_status = self.gitlab_client.get_pipeline_status(
                        pipeline_info["gitlab_project_id"],
                        pipeline_info["gitlab_pipeline_id"]
                    )
                    
                    if gitlab_status and gitlab_status.get('status') in ['success', 'failed', 'canceled']:
                        # Пайплайн завершен
                        self.handle_pipeline_completion(pipeline_db_id, pipeline_info, gitlab_status)
                        completed_pipelines.append(pipeline_db_id)
                    
                except Exception as e:
                    self.logger.error("Error monitoring pipeline", 
                                    component="pipeline_monitoring",
                                    details={"pipeline_db_id": pipeline_db_id, "error": str(e)})
            
            # Удаление завершенных пайплайнов из активных
            for pipeline_db_id in completed_pipelines:
                del self.active_pipelines[pipeline_db_id]
            
            if completed_pipelines:
                log_operation_success("pipeline_coordinator", "monitor_pipelines", correlation_id,
                                    {"completed_count": len(completed_pipelines)})
            
        except Exception as e:
            log_operation_error("pipeline_coordinator", "monitor_pipelines", correlation_id, e)
    
    def handle_pipeline_completion(self, pipeline_db_id: int, pipeline_info: Dict, gitlab_status: Dict):
        """Обработка завершения пайплайна"""
        correlation_id = log_operation_start("pipeline_coordinator", "handle_completion",
                                           {"pipeline_db_id": pipeline_db_id})
        
        try:
            status = gitlab_status.get('status')
            duration = gitlab_status.get('duration')
            
            # Обновление статуса в базе данных
            self.postgres_client.update_pipeline_status(
                pipeline_db_id, 
                status,
                duration_seconds=duration,
                metadata={
                    "gitlab_status": gitlab_status,
                    "completed_at": datetime.now(timezone.utc).isoformat()
                }
            )
            
            if pipeline_info["type"] == "gitsync":
                self.handle_gitsync_completion(pipeline_db_id, pipeline_info, gitlab_status)
            elif pipeline_info["type"] == "precommit1c":
                self.handle_precommit_completion(pipeline_db_id, pipeline_info, gitlab_status)
            
            log_operation_success("pipeline_coordinator", "handle_completion", correlation_id,
                                {"status": status, "duration": duration})
            
        except Exception as e:
            log_operation_error("pipeline_coordinator", "handle_completion", correlation_id, e)
    
    def handle_gitsync_completion(self, pipeline_db_id: int, pipeline_info: Dict, gitlab_status: Dict):
        """Обработка завершения GitSync пайплайна"""
        correlation_id = log_operation_start("pipeline_coordinator", "handle_gitsync_completion",
                                           {"pipeline_db_id": pipeline_db_id})
        
        try:
            status = gitlab_status.get('status')
            
            if status == 'success':
                # Получение результатов анализа SonarQube
                try:
                    sonar_status = self.sonarqube_client.get_project_analysis_status("ut103-ci")
                    sonar_measures = self.sonarqube_client.get_project_measures("ut103-ci")
                    
                    if sonar_status and sonar_measures:
                        # Сохранение результатов анализа
                        analysis_id = self.postgres_client.save_sonar_analysis(
                            pipeline_id=pipeline_db_id,
                            project_key="ut103-ci",
                            analysis_key=sonar_status.get('projectStatus', {}).get('analysisId', ''),
                            quality_gate_status=sonar_status.get('projectStatus', {}).get('status', 'UNKNOWN'),
                            bugs=sonar_measures.get('bugs', 0),
                            vulnerabilities=sonar_measures.get('vulnerabilities', 0),
                            code_smells=sonar_measures.get('code_smells', 0),
                            coverage_percent=sonar_measures.get('coverage'),
                            duplicated_lines_percent=sonar_measures.get('duplicated_lines_density'),
                            lines_of_code=sonar_measures.get('ncloc'),
                            technical_debt_minutes=sonar_measures.get('sqale_index'),
                            dashboard_url=f"{self.sonarqube_client.base_url}/dashboard?id=ut103-ci"
                        )
                        
                        # Создание уведомления в Redmine
                        self.create_gitsync_notification(pipeline_db_id, sonar_status, sonar_measures)
                        
                except Exception as e:
                    self.logger.error("Failed to process SonarQube results", 
                                    component="gitsync_completion",
                                    details={"error": str(e)})
            
            log_operation_success("pipeline_coordinator", "handle_gitsync_completion", correlation_id)
            
        except Exception as e:
            log_operation_error("pipeline_coordinator", "handle_gitsync_completion", correlation_id, e)
    
    def handle_precommit_completion(self, pipeline_db_id: int, pipeline_info: Dict, gitlab_status: Dict):
        """Обработка завершения PreCommit1C пайплайна"""
        correlation_id = log_operation_start("pipeline_coordinator", "handle_precommit_completion",
                                           {"pipeline_db_id": pipeline_db_id})
        
        try:
            status = gitlab_status.get('status')
            redmine_issue_id = pipeline_info.get("redmine_issue_id")
            external_file_id = pipeline_info.get("external_file_id")
            
            # Обновление статуса внешнего файла
            file_status = "completed" if status == "success" else "failed"
            self.postgres_client.update_external_file_status(
                external_file_id,
                file_status,
                pipeline_id=pipeline_db_id
            )
            
            if status == 'success':
                # Получение результатов анализа SonarQube для внешних файлов
                try:
                    sonar_status = self.sonarqube_client.get_project_analysis_status("ut103-external-files")
                    sonar_measures = self.sonarqube_client.get_project_measures("ut103-external-files")
                    
                    if sonar_status and sonar_measures:
                        # Сохранение результатов анализа
                        analysis_id = self.postgres_client.save_sonar_analysis(
                            pipeline_id=pipeline_db_id,
                            project_key="ut103-external-files",
                            analysis_key=sonar_status.get('projectStatus', {}).get('analysisId', ''),
                            quality_gate_status=sonar_status.get('projectStatus', {}).get('status', 'UNKNOWN'),
                            bugs=sonar_measures.get('bugs', 0),
                            vulnerabilities=sonar_measures.get('vulnerabilities', 0),
                            code_smells=sonar_measures.get('code_smells', 0),
                            coverage_percent=sonar_measures.get('coverage'),
                            duplicated_lines_percent=sonar_measures.get('duplicated_lines_density'),
                            lines_of_code=sonar_measures.get('ncloc'),
                            technical_debt_minutes=sonar_measures.get('sqale_index'),
                            dashboard_url=f"{self.sonarqube_client.base_url}/dashboard?id=ut103-external-files"
                        )
                        
                        # Обновление внешнего файла с результатами анализа
                        self.postgres_client.update_external_file_status(
                            external_file_id,
                            file_status,
                            sonar_analysis_id=analysis_id
                        )
                        
                        # Создание уведомления в Redmine
                        self.create_precommit_notification(redmine_issue_id, pipeline_db_id, 
                                                         sonar_status, sonar_measures, gitlab_status)
                        
                except Exception as e:
                    self.logger.error("Failed to process SonarQube results for external file", 
                                    component="precommit_completion",
                                    details={"error": str(e)})
            else:
                # Создание уведомления об ошибке
                self.create_precommit_error_notification(redmine_issue_id, pipeline_db_id, gitlab_status)
            
            log_operation_success("pipeline_coordinator", "handle_precommit_completion", correlation_id)
            
        except Exception as e:
            log_operation_error("pipeline_coordinator", "handle_precommit_completion", correlation_id, e)
    
    def create_gitsync_notification(self, pipeline_db_id: int, sonar_status: Dict, sonar_measures: Dict):
        """Создание уведомления о результатах GitSync анализа"""
        try:
            pipeline_info = self.postgres_client.get_pipeline_info(pipeline_db_id)
            if not pipeline_info:
                return
            
            quality_gate_status = sonar_status.get('projectStatus', {}).get('status', 'UNKNOWN')
            status_emoji = "✅" if quality_gate_status == "OK" else "❌"
            
            message_title = f"Анализ кода - {pipeline_info['commit_hash'][:8]} {status_emoji}"
            
            message_body = f"""## Результаты автоматического анализа кода

**Коммит**: `{pipeline_info['commit_hash']}`
**Дата**: {pipeline_info['completed_at']}
**Пайплайн**: [#{pipeline_info['pipeline_id']}]({pipeline_info.get('metadata', {}).get('gitlab_pipeline_url', '#')})

### Метрики качества кода:
- **Статус Quality Gate**: {quality_gate_status} {status_emoji}
- **Ошибки**: {sonar_measures.get('bugs', 0)}
- **Уязвимости**: {sonar_measures.get('vulnerabilities', 0)}
- **Code Smells**: {sonar_measures.get('code_smells', 0)}
- **Покрытие тестами**: {sonar_measures.get('coverage', 'N/A')}%
- **Дублирование кода**: {sonar_measures.get('duplicated_lines_density', 'N/A')}%
- **Строк кода**: {sonar_measures.get('ncloc', 0)}

[📊 Подробный отчет в SonarQube]({self.sonarqube_client.base_url}/dashboard?id=ut103-ci)
"""
            
            # Создание системной задачи в Redmine
            self.redmine_client.create_issue(
                project_id="ut103-ci",
                subject=message_title,
                description=message_body,
                tracker_id=2,  # Анализ кода
                priority_id=2   # Нормальный приоритет
            )
            
        except Exception as e:
            self.logger.error("Failed to create GitSync notification", 
                            component="notification_creation",
                            details={"error": str(e)})
    
    def create_precommit_notification(self, redmine_issue_id: int, pipeline_db_id: int,
                                    sonar_status: Dict, sonar_measures: Dict, gitlab_status: Dict):
        """Создание уведомления о результатах анализа внешнего файла"""
        try:
            pipeline_info = self.postgres_client.get_pipeline_info(pipeline_db_id)
            if not pipeline_info:
                return
            
            quality_gate_status = sonar_status.get('projectStatus', {}).get('status', 'UNKNOWN')
            status_emoji = "✅" if quality_gate_status == "OK" else "❌"
            
            file_info = pipeline_info.get('metadata', {}).get('file_info', {})
            filename = file_info.get('filename', 'unknown')
            
            message_body = f"""## Результаты анализа внешнего файла {status_emoji}

**Файл**: `{filename}`
**Статус обработки**: {'✅ Успешно' if gitlab_status.get('status') == 'success' else '❌ Ошибка'}
**Пайплайн**: [#{pipeline_info['pipeline_id']}]({pipeline_info.get('metadata', {}).get('gitlab_pipeline_url', '#')})

### Анализ качества кода:
- **Статус Quality Gate**: {quality_gate_status} {status_emoji}
- **Ошибки**: {sonar_measures.get('bugs', 0)}
- **Уязвимости**: {sonar_measures.get('vulnerabilities', 0)}
- **Code Smells**: {sonar_measures.get('code_smells', 0)}
- **Строк кода**: {sonar_measures.get('ncloc', 0)}

[📊 Подробный отчет в SonarQube]({self.sonarqube_client.base_url}/dashboard?id=ut103-external-files)

Разобранный код сохранен в Git: [Просмотр изменений]({pipeline_info.get('metadata', {}).get('gitlab_pipeline_url', '#')})
"""
            
            self.redmine_client.add_comment_to_issue(redmine_issue_id, message_body)
            
        except Exception as e:
            self.logger.error("Failed to create PreCommit notification", 
                            component="notification_creation",
                            details={"error": str(e)})
    
    def create_precommit_error_notification(self, redmine_issue_id: int, pipeline_db_id: int, gitlab_status: Dict):
        """Создание уведомления об ошибке обработки внешнего файла"""
        try:
            pipeline_info = self.postgres_client.get_pipeline_info(pipeline_db_id)
            if not pipeline_info:
                return
            
            file_info = pipeline_info.get('metadata', {}).get('file_info', {})
            filename = file_info.get('filename', 'unknown')
            
            message_body = f"""## Ошибка обработки внешнего файла ❌

**Файл**: `{filename}`
**Статус**: Ошибка обработки
**Пайплайн**: [#{pipeline_info['pipeline_id']}]({pipeline_info.get('metadata', {}).get('gitlab_pipeline_url', '#')})

Произошла ошибка при обработке внешнего файла. Проверьте логи пайплайна для получения подробной информации.

Возможные причины:
- Неподдерживаемый формат файла
- Ошибка при разборе файла
- Проблемы с анализом кода

Обратитесь к администратору системы для решения проблемы.
"""
            
            self.redmine_client.add_comment_to_issue(redmine_issue_id, message_body)
            
        except Exception as e:
            self.logger.error("Failed to create PreCommit error notification", 
                            component="notification_creation",
                            details={"error": str(e)})
    
    def get_active_pipelines_status(self) -> Dict[str, Any]:
        """Получение статуса активных пайплайнов"""
        return {
            "active_count": len(self.active_pipelines),
            "pipelines": [
                {
                    "db_id": db_id,
                    "type": info["type"],
                    "gitlab_pipeline_id": info["gitlab_pipeline_id"],
                    "started_at": info["started_at"].isoformat(),
                    "duration_minutes": (datetime.now(timezone.utc) - info["started_at"]).total_seconds() / 60
                }
                for db_id, info in self.active_pipelines.items()
            ]
        }


# Глобальный экземпляр координатора
_pipeline_coordinator = None


def get_pipeline_coordinator() -> PipelineCoordinator:
    """Получение глобального экземпляра Pipeline Coordinator"""
    global _pipeline_coordinator
    if _pipeline_coordinator is None:
        _pipeline_coordinator = PipelineCoordinator()
    return _pipeline_coordinator