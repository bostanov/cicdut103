"""
Централизованная система логирования для CI/CD контейнера
"""
import json
import logging
import logging.handlers
import os
import sys
from datetime import datetime
from typing import Dict, Any, Optional
import uuid


class StructuredFormatter(logging.Formatter):
    """Форматтер для структурированных JSON логов"""
    
    def __init__(self, service_name: str):
        super().__init__()
        self.service_name = service_name
    
    def format(self, record: logging.LogRecord) -> str:
        log_entry = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "service": self.service_name,
            "component": getattr(record, 'component', 'unknown'),
            "message": record.getMessage(),
            "correlation_id": getattr(record, 'correlation_id', None)
        }
        
        # Добавление дополнительных данных
        if hasattr(record, 'details'):
            log_entry["details"] = record.details
        
        # Добавление информации об ошибке
        if record.exc_info and record.exc_info[0] is not None:
            log_entry["error"] = {
                "type": record.exc_info[0].__name__,
                "message": str(record.exc_info[1]),
                "traceback": self.formatException(record.exc_info)
            }
        
        return json.dumps(log_entry, ensure_ascii=False)


class CILogger:
    """Централизованный логгер для CI/CD системы"""
    
    def __init__(self, service_name: str, log_level: str = "INFO"):
        self.service_name = service_name
        self.logger = logging.getLogger(service_name)
        self.logger.setLevel(getattr(logging, log_level.upper()))
        
        # Очистка существующих обработчиков
        self.logger.handlers.clear()
        
        # Настройка обработчиков
        self._setup_handlers()
    
    def _setup_handlers(self):
        """Настройка обработчиков логов"""
        
        # Консольный обработчик
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setFormatter(StructuredFormatter(self.service_name))
        self.logger.addHandler(console_handler)
        
        # Файловый обработчик с ротацией
        log_dir = "/logs"
        if not os.path.exists(log_dir):
            os.makedirs(log_dir, exist_ok=True)
        
        log_file = os.path.join(log_dir, f"{self.service_name}.log")
        file_handler = logging.handlers.RotatingFileHandler(
            log_file,
            maxBytes=10 * 1024 * 1024,  # 10MB
            backupCount=5,
            encoding='utf-8'
        )
        file_handler.setFormatter(StructuredFormatter(self.service_name))
        self.logger.addHandler(file_handler)
    
    def _log_with_context(self, level: int, message: str, component: str = None, 
                         details: Dict[str, Any] = None, correlation_id: str = None):
        """Логирование с контекстом"""
        extra = {
            'component': component or 'main',
            'correlation_id': correlation_id or str(uuid.uuid4())[:8]
        }
        
        if details:
            extra['details'] = details
        
        self.logger.log(level, message, extra=extra)
    
    def info(self, message: str, component: str = None, details: Dict[str, Any] = None, 
             correlation_id: str = None):
        """Информационное сообщение"""
        self._log_with_context(logging.INFO, message, component, details, correlation_id)
    
    def warning(self, message: str, component: str = None, details: Dict[str, Any] = None, 
                correlation_id: str = None):
        """Предупреждение"""
        self._log_with_context(logging.WARNING, message, component, details, correlation_id)
    
    def error(self, message: str, component: str = None, details: Dict[str, Any] = None, 
              correlation_id: str = None, exc_info: bool = False):
        """Ошибка"""
        extra = {
            'component': component or 'main',
            'correlation_id': correlation_id or str(uuid.uuid4())[:8]
        }
        
        if details:
            extra['details'] = details
        
        self.logger.error(message, extra=extra, exc_info=exc_info)
    
    def debug(self, message: str, component: str = None, details: Dict[str, Any] = None, 
              correlation_id: str = None):
        """Отладочное сообщение"""
        self._log_with_context(logging.DEBUG, message, component, details, correlation_id)


# Глобальные экземпляры логгеров
_loggers: Dict[str, CILogger] = {}


def get_logger(service_name: str, log_level: str = None) -> CILogger:
    """Получение логгера для сервиса"""
    if service_name not in _loggers:
        level = log_level or os.getenv('LOG_LEVEL', 'INFO')
        _loggers[service_name] = CILogger(service_name, level)
    
    return _loggers[service_name]


# Удобные функции для быстрого логирования
def log_operation_start(service: str, operation: str, details: Dict[str, Any] = None) -> str:
    """Логирование начала операции"""
    correlation_id = str(uuid.uuid4())[:8]
    logger = get_logger(service)
    logger.info(f"Starting {operation}", 
                component="operation", 
                details=details, 
                correlation_id=correlation_id)
    return correlation_id


def log_operation_success(service: str, operation: str, correlation_id: str, 
                         details: Dict[str, Any] = None):
    """Логирование успешного завершения операции"""
    logger = get_logger(service)
    logger.info(f"Completed {operation} successfully", 
                component="operation", 
                details=details, 
                correlation_id=correlation_id)


def log_operation_error(service: str, operation: str, correlation_id: str, 
                       error: Exception, details: Dict[str, Any] = None):
    """Логирование ошибки операции"""
    logger = get_logger(service)
    error_details = details or {}
    error_details.update({
        "error_type": type(error).__name__,
        "error_message": str(error)
    })
    
    logger.error(f"Failed {operation}", 
                component="operation", 
                details=error_details, 
                correlation_id=correlation_id, 
                exc_info=True)