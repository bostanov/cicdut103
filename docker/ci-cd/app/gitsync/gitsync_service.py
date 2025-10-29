"""
GitSync Service - сервис синхронизации хранилища 1С с Git репозиторием
"""
import os
import time
import subprocess
import signal
import sys
from datetime import datetime
from typing import Dict, Any, Optional
from pathlib import Path

# Добавление пути к shared модулям
sys.path.append('/app')

from shared.logger import get_logger, log_operation_start, log_operation_success, log_operation_error
from shared.git_lock import get_git_coordinator


class GitSyncService:
    """Сервис синхронизации GitSync"""
    
    def __init__(self):
        self.logger = get_logger("gitsync")
        self.git_coordinator = get_git_coordinator()
        self.running = True
        
        # Конфигурация из переменных окружения
        self.storage_path = os.getenv('GITSYNC_STORAGE_PATH', 'file:///1c-storage')
        self.storage_user = os.getenv('GITSYNC_STORAGE_USER', 'gitsync')
        self.storage_password = self._get_secret('GITSYNC_STORAGE_PASSWORD')
        self.sync_interval = int(os.getenv('GITSYNC_SYNC_INTERVAL', '600'))  # 10 минут
        self.workspace_path = os.getenv('WORKSPACE_PATH', '/workspace')
        self.gitlab_url = os.getenv('GITLAB_URL', '')
        self.gitlab_token = self._get_secret('GITLAB_TOKEN')
        
        # Настройка обработчиков сигналов
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)
        
        self.logger.info("GitSync service initialized", 
                        component="init",
                        details={
                            "storage_path": self.storage_path,
                            "storage_user": self.storage_user,
                            "sync_interval": self.sync_interval,
                            "workspace_path": self.workspace_path,
                            "gitlab_url": self.gitlab_url
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
    
    def _setup_environment(self):
        """Настройка переменных окружения для GitSync"""
        env_vars = {
            'GITSYNC_STORAGE_PATH': self.storage_path,
            'GITSYNC_STORAGE_USER': self.storage_user,
            'GITSYNC_STORAGE_PASSWORD': self.storage_password,
            'GITSYNC_WORKDIR': self.workspace_path,
        }
        
        for key, value in env_vars.items():
            if value:
                os.environ[key] = value
        
        # Обновление конфигурационного файла GitSync
        self._update_gitsync_config()
        
        self.logger.debug("Environment variables set for GitSync", 
                         component="environment")
    
    def _update_gitsync_config(self):
        """Обновление конфигурационного файла GitSync"""
        try:
            import json
            
            config_path = os.path.join(self.workspace_path, 'gitsync.json')
            
            # Базовая конфигурация
            config = {
                "storage": {
                    "path": self.storage_path,
                    "user": self.storage_user,
                    "password": self.storage_password
                },
                "workdir": self.workspace_path,
                "v8": {
                    "version": "8.3.12.1714",
                    "path": "/opt/1C/v8.3/x86_64/1cv8c"
                },
                "plugins": {
                    "increment": {
                        "enable": True
                    },
                    "unpackForm": {
                        "enable": True,
                        "renameModule": True,
                        "renameForm": True
                    },
                    "limit": {
                        "enable": True,
                        "limit": 5
                    },
                    "sync-remote": {
                        "enable": True,
                        "remote": "origin",
                        "branch": "master"
                    },
                    "check-authors": {
                        "enable": True
                    },
                    "smart-tags": {
                        "enable": True,
                        "skipExistsTags": True,
                        "numerator": True
                    }
                },
                "sync": {
                    "remote": True,
                    "push": True,
                    "pull": True
                }
            }
            
            # Сохранение конфигурации
            with open(config_path, 'w', encoding='utf-8') as f:
                json.dump(config, f, indent=2, ensure_ascii=False)
            
            self.logger.info("GitSync configuration updated", 
                           component="config",
                           details={"config_path": config_path})
            
        except Exception as e:
            self.logger.error("Failed to update GitSync configuration", 
                            component="config",
                            details={"error": str(e)})
    
    def _check_prerequisites(self) -> bool:
        """Проверка предварительных условий"""
        correlation_id = log_operation_start("gitsync", "prerequisites_check")
        
        try:
            # Проверка доступности GitSync
            result = subprocess.run(['gitsync', '--version'], 
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, timeout=30)
            
            if result.returncode != 0:
                self.logger.error("GitSync not available", 
                                component="prerequisites",
                                details={"error": result.stderr},
                                correlation_id=correlation_id)
                return False
            
            # Проверка рабочей директории
            workspace = Path(self.workspace_path)
            if not workspace.exists():
                workspace.mkdir(parents=True, exist_ok=True)
                self.logger.info("Created workspace directory", 
                               component="prerequisites",
                               details={"path": self.workspace_path},
                               correlation_id=correlation_id)
            
            # Проверка доступа к хранилищу 1С
            storage_local_path = "/1c-storage"
            if not os.path.exists(storage_local_path):
                self.logger.warning("1C storage not mounted", 
                                  component="prerequisites",
                                  details={"path": storage_local_path},
                                  correlation_id=correlation_id)
            
            log_operation_success("gitsync", "prerequisites_check", correlation_id)
            return True
            
        except Exception as e:
            log_operation_error("gitsync", "prerequisites_check", correlation_id, e)
            return False
    
    def _initialize_git_repo(self) -> bool:
        """Инициализация Git репозитория"""
        correlation_id = log_operation_start("gitsync", "git_init")
        
        try:
            os.chdir(self.workspace_path)
            
            # Проверка существования .git
            if not os.path.exists('.git'):
                subprocess.run(['git', 'init'], check=True, timeout=30)
                subprocess.run(['git', 'config', 'user.name', 'GitSync Service'], 
                             check=True, timeout=30)
                subprocess.run(['git', 'config', 'user.email', 'gitsync@ci.local'], 
                             check=True, timeout=30)
                
                self.logger.info("Git repository initialized", 
                               component="git_init",
                               correlation_id=correlation_id)
            
            # Настройка remote для GitLab
            if self.gitlab_url:
                try:
                    # Проверка существования remote
                    result = subprocess.run(['git', 'remote', 'get-url', 'origin'], 
                                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, timeout=30)
                    
                    if result.returncode != 0:
                        # Добавление remote
                        subprocess.run(['git', 'remote', 'add', 'origin', self.gitlab_url], 
                                     check=True, timeout=30)
                        self.logger.info("Added GitLab remote", 
                                       component="git_init",
                                       details={"url": self.gitlab_url},
                                       correlation_id=correlation_id)
                    else:
                        # Обновление существующего remote
                        subprocess.run(['git', 'remote', 'set-url', 'origin', self.gitlab_url], 
                                     check=True, timeout=30)
                        self.logger.info("Updated GitLab remote", 
                                       component="git_init",
                                       details={"url": self.gitlab_url},
                                       correlation_id=correlation_id)
                
                except subprocess.CalledProcessError as e:
                    self.logger.warning("Failed to setup GitLab remote", 
                                      component="git_init",
                                      details={"error": str(e)},
                                      correlation_id=correlation_id)
            
            log_operation_success("gitsync", "git_init", correlation_id)
            return True
            
        except Exception as e:
            log_operation_error("gitsync", "git_init", correlation_id, e)
            return False
    
    def _execute_gitsync(self):
        """Выполнение синхронизации GitSync"""
        correlation_id = log_operation_start("gitsync", "sync_execution")
        
        try:
            # Команда GitSync с использованием переменных окружения
            cmd = ['gitsync', 'sync']
            
            self.logger.info("Executing GitSync command", 
                           component="sync_execution",
                           details={"command": ' '.join(cmd)},
                           correlation_id=correlation_id)
            
            start_time = time.time()
            
            # Выполнение команды
            result = subprocess.run(
                cmd,
                cwd=self.workspace_path,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
                timeout=300  # 5 минут таймаут
            )
            
            duration = time.time() - start_time
            
            sync_result = {
                "success": result.returncode == 0,
                "exit_code": result.returncode,
                "duration": duration,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "timestamp": datetime.utcnow().isoformat()
            }
            
            if sync_result["success"]:
                log_operation_success("gitsync", "sync_execution", correlation_id, 
                                    {"duration": duration})
            else:
                self.logger.error("GitSync execution failed", 
                                component="sync_execution",
                                details=sync_result,
                                correlation_id=correlation_id)
            
            return sync_result
            
        except subprocess.TimeoutExpired:
            error_msg = "GitSync execution timed out"
            self.logger.error(error_msg, 
                            component="sync_execution",
                            correlation_id=correlation_id)
            return {
                "success": False,
                "error": error_msg,
                "timestamp": datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            log_operation_error("gitsync", "sync_execution", correlation_id, e)
            return {
                "success": False,
                "error": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
    
    def _push_to_gitlab(self):
        """Отправка изменений в GitLab"""
        if not self.gitlab_url:
            self.logger.info("GitLab URL not configured, skipping push", 
                           component="git_push")
            return True, ""
        
        correlation_id = log_operation_start("gitsync", "git_push")
        
        try:
            os.chdir(self.workspace_path)
            
            # Проверка наличия изменений для отправки
            result = subprocess.run(['git', 'status', '--porcelain'], 
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, timeout=30)
            
            if not result.stdout.strip():
                # Проверка неотправленных коммитов
                result = subprocess.run(['git', 'log', 'origin/master..HEAD', '--oneline'], 
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, timeout=30)
                
                if not result.stdout.strip():
                    self.logger.debug("No changes to push", 
                                    component="git_push",
                                    correlation_id=correlation_id)
                    return True, ""
            
            # Получение текущего коммита
            commit_result = subprocess.run(['git', 'rev-parse', 'HEAD'], 
                                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, timeout=30)
            commit_hash = commit_result.stdout.strip() if commit_result.returncode == 0 else ""
            
            # Отправка в GitLab
            push_cmd = ['git', 'push', 'origin', 'master']
            
            result = subprocess.run(
                push_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
                timeout=120
            )
            
            if result.returncode == 0:
                log_operation_success("gitsync", "git_push", correlation_id)
                return True, commit_hash
            else:
                self.logger.error("Failed to push to GitLab", 
                                component="git_push",
                                details={
                                    "exit_code": result.returncode,
                                    "stderr": result.stderr
                                },
                                correlation_id=correlation_id)
                return False, commit_hash
                
        except Exception as e:
            log_operation_error("gitsync", "git_push", correlation_id, e)
            return False, ""
    
    def _sync_cycle(self):
        """Один цикл синхронизации"""
        cycle_id = log_operation_start("gitsync", "sync_cycle")
        
        try:
            # Получение блокировки Git репозитория
            with self.git_coordinator.acquire_lock("gitsync", timeout=300):
                
                # Выполнение GitSync
                sync_result = self._execute_gitsync()
                
                if sync_result["success"]:
                    # Отправка в GitLab при успешной синхронизации
                    push_success, commit_hash = self._push_to_gitlab()
                    
                    if push_success and commit_hash:
                        # Запуск пайплайна через Pipeline Coordinator
                        try:
                            from pipeline_coordinator import get_pipeline_coordinator
                            coordinator = get_pipeline_coordinator()
                            
                            # Подготовка информации об изменениях
                            changes_info = [
                                {
                                    "type": "gitsync_sync",
                                    "timestamp": sync_result.get("timestamp"),
                                    "duration": sync_result.get("duration")
                                }
                            ]
                            
                            pipeline_id = coordinator.trigger_gitsync_pipeline(
                                commit_hash=commit_hash,
                                changes_info=changes_info
                            )
                            
                            if pipeline_id:
                                self.logger.info("Pipeline triggered successfully", 
                                               component="sync_cycle",
                                               details={"pipeline_id": pipeline_id},
                                               correlation_id=cycle_id)
                            
                        except Exception as e:
                            self.logger.error("Failed to trigger pipeline", 
                                            component="sync_cycle",
                                            details={"error": str(e)},
                                            correlation_id=cycle_id)
                    
                    log_operation_success("gitsync", "sync_cycle", cycle_id, {
                        "sync_duration": sync_result.get("duration"),
                        "push_success": push_success,
                        "commit_hash": commit_hash
                    })
                else:
                    self.logger.error("Sync cycle failed", 
                                    component="sync_cycle",
                                    details=sync_result,
                                    correlation_id=cycle_id)
                    
        except Exception as e:
            log_operation_error("gitsync", "sync_cycle", cycle_id, e)
    
    def run(self):
        """Основной цикл работы сервиса"""
        self.logger.info("Starting GitSync service", component="main")
        
        # Проверка предварительных условий
        if not self._check_prerequisites():
            self.logger.error("Prerequisites check failed, exiting", component="main")
            return 1
        
        # Настройка окружения
        self._setup_environment()
        
        # Инициализация Git репозитория
        if not self._initialize_git_repo():
            self.logger.error("Git repository initialization failed, exiting", component="main")
            return 1
        
        self.logger.info("GitSync service started successfully", 
                        component="main",
                        details={"sync_interval": self.sync_interval})
        
        # Основной цикл
        while self.running:
            try:
                self._sync_cycle()
                
                # Ожидание до следующего цикла
                for _ in range(self.sync_interval):
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
        
        self.logger.info("GitSync service stopped", component="main")
        return 0


if __name__ == '__main__':
    service = GitSyncService()
    exit_code = service.run()
    sys.exit(exit_code)