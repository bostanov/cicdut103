"""
PreCommit1C Service - сервис мониторинга Redmine и обработки внешних файлов 1С
"""
import os
import time
import signal
import sys
import requests
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, List, Optional
from urllib.parse import urljoin

# Добавление пути к shared модулям
sys.path.append('/app')

from shared.logger import get_logger, log_operation_start, log_operation_success, log_operation_error
from shared.git_lock import get_git_coordinator


class PreCommit1CService:
    """Сервис мониторинга Redmine и обработки внешних файлов"""
    
    def __init__(self):
        self.logger = get_logger("precommit1c")
        self.git_coordinator = get_git_coordinator()
        self.running = True
        
        # Конфигурация из переменных окружения
        self.redmine_url = os.getenv('REDMINE_URL', 'http://redmine:3000')
        self.redmine_username = os.getenv('REDMINE_USERNAME', 'admin')
        self.redmine_password = self._get_secret('REDMINE_PASSWORD')
        self.check_interval = int(os.getenv('CHECK_INTERVAL', '300'))  # 5 минут
        self.workspace_path = os.getenv('WORKSPACE_PATH', '/workspace')
        self.external_files_path = os.getenv('EXTERNAL_FILES_PATH', '/workspace/external-files')
        
        # Отслеживание обработанных файлов
        self.processed_attachments = set()
        
        # Настройка обработчиков сигналов
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)
        
        self.logger.info("PreCommit1C service initialized", 
                        component="init",
                        details={
                            "redmine_url": self.redmine_url,
                            "redmine_username": self.redmine_username,
                            "check_interval": self.check_interval,
                            "workspace_path": self.workspace_path,
                            "external_files_path": self.external_files_path
                        })
    
    def _get_secret(self, env_var: str) -> str:
        """Получение секрета из переменной окружения или файла"""
        # Сначала пробуем получить из переменной окружения
        value = os.getenv(env_var)
        if value:
            return value
        
        # Затем пробуем прочитать из файла секрета
        secret_file = os.getenv(f"{env_var}_FILE")
        if secret_file and os.path.exists(secret_file):
            with open(secret_file, 'r') as f:
                return f.read().strip()
        
        # Возвращаем пустую строку если секрет не найден
        self.logger.warning(f"Secret {env_var} not found", component="config")
        return ""
    
    def _signal_handler(self, signum, frame):
        """Обработчик сигналов для graceful shutdown"""
        self.logger.info(f"Received signal {signum}, shutting down gracefully", 
                        component="signal_handler")
        self.running = False
    
    def _get_redmine_auth(self) -> Dict[str, str]:
        """Получение заголовков аутентификации для Redmine"""
        import base64
        
        if self.redmine_username and self.redmine_password:
            credentials = f"{self.redmine_username}:{self.redmine_password}"
            encoded_credentials = base64.b64encode(credentials.encode()).decode()
            return {
                "Authorization": f"Basic {encoded_credentials}",
                "Content-Type": "application/json"
            }
        else:
            return {"Content-Type": "application/json"}
    
    def _check_redmine_connectivity(self) -> bool:
        """Проверка доступности Redmine"""
        try:
            response = requests.get(self.redmine_url, timeout=10)
            return response.status_code < 400
        except Exception as e:
            self.logger.warning("Redmine connectivity check failed", 
                              component="connectivity",
                              details={"error": str(e)})
            return False
    
    def _get_redmine_issues(self) -> List[Dict[str, Any]]:
        """Получение открытых задач из Redmine"""
        correlation_id = log_operation_start("precommit1c", "get_redmine_issues")
        
        try:
            headers = self._get_redmine_auth()
            url = urljoin(self.redmine_url, "/issues.json")
            params = {
                "status_id": "open",
                "limit": 100
            }
            
            response = requests.get(url, headers=headers, params=params, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            issues = data.get("issues", [])
            
            log_operation_success("precommit1c", "get_redmine_issues", correlation_id, 
                                {"issues_count": len(issues)})
            
            return issues
            
        except Exception as e:
            log_operation_error("precommit1c", "get_redmine_issues", correlation_id, e)
            return []
    
    def _get_issue_attachments(self, issue_id: int) -> List[Dict[str, Any]]:
        """Получение вложений задачи"""
        try:
            headers = self._get_redmine_auth()
            url = urljoin(self.redmine_url, f"/issues/{issue_id}.json")
            params = {"include": "attachments"}
            
            response = requests.get(url, headers=headers, params=params, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            attachments = data.get("issue", {}).get("attachments", [])
            
            return attachments
            
        except Exception as e:
            self.logger.error("Failed to get issue attachments", 
                            component="redmine_api",
                            details={"issue_id": issue_id, "error": str(e)})
            return []
    
    def _is_1c_file(self, filename: str) -> bool:
        """Проверка, является ли файл внешним файлом 1С"""
        extensions = ['.epf', '.erf', '.efd']
        return any(filename.lower().endswith(ext) for ext in extensions)
    
    def _download_attachment(self, attachment: Dict[str, Any], output_path: str) -> bool:
        """Скачивание вложения из Redmine"""
        correlation_id = log_operation_start("precommit1c", "download_attachment", 
                                           {"filename": attachment.get("filename")})
        
        try:
            headers = self._get_redmine_auth()
            content_url = attachment.get("content_url")
            
            if not content_url:
                self.logger.error("No content URL in attachment", 
                                component="download",
                                details={"attachment": attachment},
                                correlation_id=correlation_id)
                return False
            
            # Полный URL для скачивания
            download_url = urljoin(self.redmine_url, content_url)
            
            response = requests.get(download_url, headers=headers, timeout=120)
            response.raise_for_status()
            
            # Создание директории если не существует
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            
            # Сохранение файла
            with open(output_path, 'wb') as f:
                f.write(response.content)
            
            log_operation_success("precommit1c", "download_attachment", correlation_id, 
                                {"output_path": output_path, "size": len(response.content)})
            
            return True
            
        except Exception as e:
            log_operation_error("precommit1c", "download_attachment", correlation_id, e)
            return False
    
    def _create_version_directory(self, issue_id: int, version: str = "v1.0") -> str:
        """Создание структуры каталогов для внешнего файла"""
        issue_dir = os.path.join(self.external_files_path, f"task-{issue_id}")
        version_dir = os.path.join(issue_dir, version)
        
        os.makedirs(version_dir, exist_ok=True)
        
        return version_dir
    
    def _decomp_1c_file(self, file_path: str, output_dir: str) -> bool:
        """Разбор файла 1С с помощью PreCommit1C"""
        correlation_id = log_operation_start("precommit1c", "decomp_1c_file", 
                                           {"file_path": file_path})
        
        try:
            # Создание директории для разобранных файлов
            decompiled_dir = os.path.join(output_dir, "decompiled")
            os.makedirs(decompiled_dir, exist_ok=True)
            
            # Команда для разбора файла
            cmd = ['precommit1c', '--decompile', file_path, decompiled_dir]
            
            self.logger.info("Decompiling 1C file", 
                           component="decomp",
                           details={"command": ' '.join(cmd)},
                           correlation_id=correlation_id)
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=300  # 5 минут таймаут
            )
            
            if result.returncode == 0:
                log_operation_success("precommit1c", "decomp_1c_file", correlation_id, 
                                    {"output_dir": decompiled_dir})
                return True
            else:
                self.logger.error("Failed to decompile 1C file", 
                                component="decomp",
                                details={
                                    "exit_code": result.returncode,
                                    "stderr": result.stderr,
                                    "stdout": result.stdout
                                },
                                correlation_id=correlation_id)
                return False
                
        except subprocess.TimeoutExpired:
            self.logger.error("Decompilation timed out", 
                            component="decomp",
                            correlation_id=correlation_id)
            return False
            
        except Exception as e:
            log_operation_error("precommit1c", "decomp_1c_file", correlation_id, e)
            return False
    
    def _commit_to_git(self, file_path: str, issue_id: int) -> Optional[str]:
        """Коммит обработанного файла в Git"""
        correlation_id = log_operation_start("precommit1c", "commit_to_git", 
                                           {"issue_id": issue_id})
        
        try:
            os.chdir(self.workspace_path)
            
            # Создание ветки для внешнего файла
            branch_name = f"external-file-{issue_id}"
            
            # Проверка существования ветки
            result = subprocess.run(['git', 'branch', '--list', branch_name], 
                                  capture_output=True, text=True, timeout=30)
            
            if not result.stdout.strip():
                # Создание новой ветки
                subprocess.run(['git', 'checkout', '-b', branch_name], check=True, timeout=30)
            else:
                # Переключение на существующую ветку
                subprocess.run(['git', 'checkout', branch_name], check=True, timeout=30)
            
            # Добавление файлов в Git
            git_path = f"external-files/task-{issue_id}/"
            subprocess.run(['git', 'add', git_path], check=True, timeout=30)
            
            # Проверка наличия изменений
            result = subprocess.run(['git', 'status', '--porcelain'], 
                                  capture_output=True, text=True, timeout=30)
            
            if not result.stdout.strip():
                self.logger.info("No changes to commit", 
                               component="git_commit",
                               correlation_id=correlation_id)
                # Получение текущего коммита
                result = subprocess.run(['git', 'rev-parse', 'HEAD'], 
                                      capture_output=True, text=True, timeout=30)
                return result.stdout.strip() if result.returncode == 0 else None
            
            # Создание коммита
            commit_message = f"[#{issue_id}] Added external file: {os.path.basename(file_path)}"
            subprocess.run(['git', 'commit', '-m', commit_message], 
                         check=True, timeout=30)
            
            # Получение хеша коммита
            result = subprocess.run(['git', 'rev-parse', 'HEAD'], 
                                  capture_output=True, text=True, timeout=30)
            commit_hash = result.stdout.strip() if result.returncode == 0 else None
            
            # Отправка в remote (если настроен)
            try:
                subprocess.run(['git', 'push', 'origin', branch_name], 
                             check=True, timeout=60)
                
                log_operation_success("precommit1c", "commit_to_git", correlation_id, 
                                    {"commit_message": commit_message, "commit_hash": commit_hash})
                return commit_hash
                
            except subprocess.CalledProcessError:
                self.logger.warning("Failed to push to remote, commit created locally", 
                                  component="git_commit",
                                  correlation_id=correlation_id)
                return commit_hash
                
        except Exception as e:
            log_operation_error("precommit1c", "commit_to_git", correlation_id, e)
            return None
    
    def _process_external_file(self, attachment: Dict[str, Any], issue_id: int):
        """Обработка внешнего файла 1С"""
        filename = attachment.get("filename", "unknown")
        attachment_id = attachment.get("id")
        file_size = attachment.get("filesize", 0)
        
        correlation_id = log_operation_start("precommit1c", "process_external_file", 
                                           {"filename": filename, "issue_id": issue_id})
        
        try:
            self.logger.info("Processing external 1C file", 
                           component="file_processing",
                           details={
                               "filename": filename,
                               "issue_id": issue_id,
                               "attachment_id": attachment_id
                           },
                           correlation_id=correlation_id)
            
            # Создание записи в базе данных
            try:
                from integrations import get_postgres_client
                postgres_client = get_postgres_client()
                
                file_type = filename.split('.')[-1].lower() if '.' in filename else 'unknown'
                
                external_file_id = postgres_client.create_external_file_record(
                    redmine_issue_id=issue_id,
                    redmine_attachment_id=attachment_id,
                    filename=filename,
                    file_type=file_type,
                    file_size_bytes=file_size
                )
                
            except Exception as e:
                self.logger.error("Failed to create external file record", 
                                component="file_processing",
                                details={"error": str(e)},
                                correlation_id=correlation_id)
                return
            
            # Создание структуры каталогов
            version_dir = self._create_version_directory(issue_id)
            
            # Путь для сохранения файла
            file_path = os.path.join(version_dir, filename)
            
            # Скачивание файла
            if not self._download_attachment(attachment, file_path):
                postgres_client.update_external_file_status(external_file_id, "failed")
                self.logger.error("Failed to download attachment", 
                                component="file_processing",
                                correlation_id=correlation_id)
                return
            
            # Обновление пути к файлу
            postgres_client.update_external_file_status(
                external_file_id, 
                "processing",
                file_path=file_path
            )
            
            # Разбор файла с помощью PreCommit1C
            decompiled_path = os.path.join(version_dir, "decompiled")
            if not self._decomp_1c_file(file_path, version_dir):
                postgres_client.update_external_file_status(external_file_id, "failed")
                self.logger.error("Failed to decompile file", 
                                component="file_processing",
                                correlation_id=correlation_id)
                return
            
            # Коммит в Git с блокировкой
            with self.git_coordinator.acquire_lock("precommit1c", timeout=300):
                commit_hash = self._commit_to_git(file_path, issue_id)
                if commit_hash:
                    # Обновление записи с информацией о коммите
                    postgres_client.update_external_file_status(
                        external_file_id,
                        "completed",
                        decompiled_path=decompiled_path,
                        git_commit_hash=commit_hash,
                        git_branch=f"external-file-{issue_id}"
                    )
                    
                    # Запуск пайплайна через Pipeline Coordinator
                    try:
                        from pipeline_coordinator import get_pipeline_coordinator
                        coordinator = get_pipeline_coordinator()
                        
                        file_info = {
                            "filename": filename,
                            "file_type": file_type,
                            "file_size": file_size,
                            "attachment_id": attachment_id
                        }
                        
                        pipeline_id = coordinator.trigger_precommit_pipeline(
                            redmine_issue_id=issue_id,
                            file_info=file_info,
                            external_file_id=external_file_id
                        )
                        
                        if pipeline_id:
                            self.logger.info("Pipeline triggered successfully", 
                                           component="file_processing",
                                           details={"pipeline_id": pipeline_id},
                                           correlation_id=correlation_id)
                        
                    except Exception as e:
                        self.logger.error("Failed to trigger pipeline", 
                                        component="file_processing",
                                        details={"error": str(e)},
                                        correlation_id=correlation_id)
                    
                    # Отметка файла как обработанного
                    self.processed_attachments.add(attachment_id)
                    
                    log_operation_success("precommit1c", "process_external_file", 
                                        correlation_id, {"filename": filename})
                else:
                    postgres_client.update_external_file_status(external_file_id, "failed")
                    self.logger.error("Failed to commit to Git", 
                                    component="file_processing",
                                    correlation_id=correlation_id)
                    
        except Exception as e:
            log_operation_error("precommit1c", "process_external_file", correlation_id, e)
    
    def _monitor_cycle(self):
        """Один цикл мониторинга Redmine"""
        cycle_id = log_operation_start("precommit1c", "monitor_cycle")
        
        try:
            # Проверка доступности Redmine
            if not self._check_redmine_connectivity():
                self.logger.warning("Redmine is not accessible, skipping cycle", 
                                  component="monitor_cycle",
                                  correlation_id=cycle_id)
                return
            
            # Получение открытых задач
            issues = self._get_redmine_issues()
            
            processed_files_count = 0
            
            for issue in issues:
                issue_id = issue.get("id")
                if not issue_id:
                    continue
                
                # Получение вложений задачи
                attachments = self._get_issue_attachments(issue_id)
                
                for attachment in attachments:
                    attachment_id = attachment.get("id")
                    filename = attachment.get("filename", "")
                    
                    # Проверка, что файл еще не обработан
                    if attachment_id in self.processed_attachments:
                        continue
                    
                    # Проверка, что это файл 1С
                    if self._is_1c_file(filename):
                        self._process_external_file(attachment, issue_id)
                        processed_files_count += 1
            
            log_operation_success("precommit1c", "monitor_cycle", cycle_id, {
                "issues_checked": len(issues),
                "files_processed": processed_files_count
            })
            
        except Exception as e:
            log_operation_error("precommit1c", "monitor_cycle", cycle_id, e)
    
    def run(self):
        """Основной цикл работы сервиса"""
        self.logger.info("Starting PreCommit1C service", component="main")
        
        # Создание директории для внешних файлов
        os.makedirs(self.external_files_path, exist_ok=True)
        
        self.logger.info("PreCommit1C service started successfully", 
                        component="main",
                        details={"check_interval": self.check_interval})
        
        # Основной цикл
        while self.running:
            try:
                self._monitor_cycle()
                
                # Ожидание до следующего цикла
                for _ in range(self.check_interval):
                    if not self.running:
                        break
                    time.sleep(1)
                    
            except KeyboardInterrupt:
                self.logger.info("Received keyboard interrupt", component="main")
                break
            except Exception as e:
                self.logger.error("Unexpected error in main loop", 
                                component="main",
                                exc_info=True)
                time.sleep(60)  # Ожидание перед повторной попыткой
        
        self.logger.info("PreCommit1C service stopped", component="main")
        return 0


if __name__ == '__main__':
    service = PreCommit1CService()
    exit_code = service.run()
    sys.exit(exit_code)