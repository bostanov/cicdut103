"""
Health Check сервис для мониторинга состояния CI/CD контейнера
"""
import os
import time
import requests
import subprocess
import psutil
from datetime import datetime
from flask import Flask, jsonify
from typing import Dict, Any
import sys
sys.path.append('/app')

from shared.logger import get_logger
from shared.git_lock import get_git_coordinator


app = Flask(__name__)
logger = get_logger("health-check")


class HealthChecker:
    """Класс для проверки состояния системы"""
    
    def __init__(self):
        self.start_time = time.time()
        self.git_coordinator = get_git_coordinator()
    
    def check_gitsync_health(self) -> Dict[str, Any]:
        """Проверка состояния GitSync сервиса"""
        try:
            # Проверка процесса через supervisord
            result = subprocess.run(
                ['supervisorctl', 'status', 'gitsync'],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
                timeout=10
            )
            
            if result.returncode == 0 and 'RUNNING' in result.stdout:
                return {
                    "status": "healthy",
                    "message": "GitSync service is running",
                    "details": {"supervisor_status": result.stdout.strip()}
                }
            else:
                return {
                    "status": "unhealthy",
                    "message": "GitSync service is not running",
                    "details": {"supervisor_status": result.stdout.strip()}
                }
        
        except Exception as e:
            return {
                "status": "unhealthy",
                "message": f"Error checking GitSync: {str(e)}",
                "details": {"error": str(e)}
            }
    
    def check_precommit1c_health(self) -> Dict[str, Any]:
        """Проверка состояния PreCommit1C сервиса"""
        try:
            # Проверка процесса через supervisord
            result = subprocess.run(
                ['supervisorctl', 'status', 'precommit1c'],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
                timeout=10
            )
            
            if result.returncode == 0 and 'RUNNING' in result.stdout:
                return {
                    "status": "healthy",
                    "message": "PreCommit1C service is running",
                    "details": {"supervisor_status": result.stdout.strip()}
                }
            else:
                return {
                    "status": "unhealthy",
                    "message": "PreCommit1C service is not running",
                    "details": {"supervisor_status": result.stdout.strip()}
                }
        
        except Exception as e:
            return {
                "status": "unhealthy",
                "message": f"Error checking PreCommit1C: {str(e)}",
                "details": {"error": str(e)}
            }
    
    def check_gitlab_connectivity(self) -> Dict[str, Any]:
        """Проверка доступности GitLab"""
        gitlab_url = os.getenv('GITLAB_URL', '')
        
        if not gitlab_url:
            return {
                "status": "unknown",
                "message": "GitLab URL not configured"
            }
        
        try:
            # Извлечение базового URL
            base_url = gitlab_url.split('/')[0:3]  # http://host:port
            base_url = '/'.join(base_url)
            
            response = requests.get(base_url, timeout=10)
            
            if response.status_code < 400:
                return {
                    "status": "healthy",
                    "message": "GitLab is accessible",
                    "details": {"status_code": response.status_code}
                }
            else:
                return {
                    "status": "unhealthy",
                    "message": f"GitLab returned status {response.status_code}",
                    "details": {"status_code": response.status_code}
                }
        
        except Exception as e:
            return {
                "status": "unhealthy",
                "message": f"Cannot connect to GitLab: {str(e)}",
                "details": {"error": str(e)}
            }
    
    def check_redmine_connectivity(self) -> Dict[str, Any]:
        """Проверка доступности Redmine"""
        redmine_url = os.getenv('REDMINE_URL', '')
        
        if not redmine_url:
            return {
                "status": "unknown",
                "message": "Redmine URL not configured"
            }
        
        try:
            response = requests.get(redmine_url, timeout=10)
            
            if response.status_code < 400:
                return {
                    "status": "healthy",
                    "message": "Redmine is accessible",
                    "details": {"status_code": response.status_code}
                }
            else:
                return {
                    "status": "unhealthy",
                    "message": f"Redmine returned status {response.status_code}",
                    "details": {"status_code": response.status_code}
                }
        
        except Exception as e:
            return {
                "status": "unhealthy",
                "message": f"Cannot connect to Redmine: {str(e)}",
                "details": {"error": str(e)}
            }
    
    def check_1c_storage_access(self) -> Dict[str, Any]:
        """Проверка доступа к хранилищу 1С"""
        storage_path = "/1c-storage"
        
        try:
            if not os.path.exists(storage_path):
                return {
                    "status": "unhealthy",
                    "message": "1C storage path does not exist",
                    "details": {"path": storage_path}
                }
            
            if not os.path.isdir(storage_path):
                return {
                    "status": "unhealthy",
                    "message": "1C storage path is not a directory",
                    "details": {"path": storage_path}
                }
            
            # Проверка прав на чтение
            if not os.access(storage_path, os.R_OK):
                return {
                    "status": "unhealthy",
                    "message": "No read access to 1C storage",
                    "details": {"path": storage_path}
                }
            
            return {
                "status": "healthy",
                "message": "1C storage is accessible",
                "details": {"path": storage_path}
            }
        
        except Exception as e:
            return {
                "status": "unhealthy",
                "message": f"Error checking 1C storage: {str(e)}",
                "details": {"error": str(e), "path": storage_path}
            }
    
    def get_system_metrics(self) -> Dict[str, Any]:
        """Получение системных метрик"""
        try:
            # CPU и память
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage('/workspace')
            
            return {
                "uptime_seconds": int(time.time() - self.start_time),
                "cpu_usage_percent": cpu_percent,
                "memory_usage_percent": memory.percent,
                "memory_used_mb": memory.used // (1024 * 1024),
                "memory_total_mb": memory.total // (1024 * 1024),
                "disk_usage_percent": disk.percent,
                "disk_used_gb": disk.used // (1024 * 1024 * 1024),
                "disk_total_gb": disk.total // (1024 * 1024 * 1024)
            }
        
        except Exception as e:
            logger.error("Error getting system metrics", 
                        component="metrics", 
                        details={"error": str(e)})
            return {"error": str(e)}
    
    def get_git_lock_status(self) -> Dict[str, Any]:
        """Получение статуса Git блокировки"""
        return self.git_coordinator.get_lock_status()


# Глобальный экземпляр health checker
health_checker = HealthChecker()


@app.route('/health')
def health_check():
    """Основной endpoint для проверки здоровья"""
    try:
        status = {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "services": {},
            "external": {},
            "system": {},
            "git_lock": {}
        }
        
        # Проверка сервисов
        status["services"]["gitsync"] = health_checker.check_gitsync_health()
        status["services"]["precommit1c"] = health_checker.check_precommit1c_health()
        
        # Проверка внешних сервисов
        status["external"]["gitlab"] = health_checker.check_gitlab_connectivity()
        status["external"]["redmine"] = health_checker.check_redmine_connectivity()
        status["external"]["1c_storage"] = health_checker.check_1c_storage_access()
        
        # Системные метрики
        status["system"] = health_checker.get_system_metrics()
        
        # Статус Git блокировки
        status["git_lock"] = health_checker.get_git_lock_status()
        
        # Определение общего статуса
        service_statuses = [s.get("status") for s in status["services"].values()]
        if "unhealthy" in service_statuses:
            status["status"] = "unhealthy"
        elif "unknown" in service_statuses:
            status["status"] = "degraded"
        
        # Логирование health check
        logger.debug("Health check completed", 
                    component="health_endpoint",
                    details={"overall_status": status["status"]})
        
        return jsonify(status)
    
    except Exception as e:
        logger.error("Error in health check", 
                    component="health_endpoint",
                    exc_info=True)
        
        return jsonify({
            "status": "error",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "error": str(e)
        }), 500


@app.route('/metrics')
def metrics():
    """Endpoint для Prometheus метрик"""
    try:
        system_metrics = health_checker.get_system_metrics()
        
        # Простой формат метрик для Prometheus
        metrics_text = f"""# HELP ci_cd_uptime_seconds Container uptime in seconds
# TYPE ci_cd_uptime_seconds counter
ci_cd_uptime_seconds {system_metrics.get('uptime_seconds', 0)}

# HELP ci_cd_cpu_usage_percent CPU usage percentage
# TYPE ci_cd_cpu_usage_percent gauge
ci_cd_cpu_usage_percent {system_metrics.get('cpu_usage_percent', 0)}

# HELP ci_cd_memory_usage_percent Memory usage percentage
# TYPE ci_cd_memory_usage_percent gauge
ci_cd_memory_usage_percent {system_metrics.get('memory_usage_percent', 0)}

# HELP ci_cd_disk_usage_percent Disk usage percentage
# TYPE ci_cd_disk_usage_percent gauge
ci_cd_disk_usage_percent {system_metrics.get('disk_usage_percent', 0)}
"""
        
        return metrics_text, 200, {'Content-Type': 'text/plain; charset=utf-8'}
    
    except Exception as e:
        logger.error("Error generating metrics", 
                    component="metrics_endpoint",
                    exc_info=True)
        return f"# Error generating metrics: {str(e)}", 500


if __name__ == '__main__':
    logger.info("Starting Health Check service", component="main")
    
    # Запуск Flask приложения
    app.run(
        host='0.0.0.0',
        port=8085,
        debug=False,
        threaded=True
    )