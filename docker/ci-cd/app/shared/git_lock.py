"""
Git Lock Coordinator - координация доступа к Git репозиторию между сервисами
"""
import fcntl
import time
import os
from contextlib import contextmanager
from typing import Generator
from shared.logger import get_logger


class GitLockCoordinator:
    """Координатор блокировок Git операций"""
    
    def __init__(self, lock_file_path: str = "/tmp/git.lock"):
        self.lock_file_path = lock_file_path
        self.logger = get_logger("git-coordinator")
    
    @contextmanager
    def acquire_lock(self, service_name: str, timeout: int = 300) -> Generator[None, None, None]:
        """
        Получение блокировки Git репозитория
        
        Args:
            service_name: Имя сервиса, запрашивающего блокировку
            timeout: Таймаут ожидания блокировки в секундах
        
        Yields:
            None: Блокировка получена
        
        Raises:
            TimeoutError: Не удалось получить блокировку в течение таймаута
        """
        lock_file = None
        start_time = time.time()
        
        try:
            # Создание файла блокировки если не существует
            os.makedirs(os.path.dirname(self.lock_file_path), exist_ok=True)
            lock_file = open(self.lock_file_path, 'w')
            
            self.logger.info(f"Attempting to acquire Git lock", 
                           component="lock_coordinator",
                           details={"service": service_name, "timeout": timeout})
            
            # Попытка получения блокировки с таймаутом
            while time.time() - start_time < timeout:
                try:
                    fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                    
                    # Запись информации о владельце блокировки
                    lock_file.write(f"{service_name}:{int(time.time())}")
                    lock_file.flush()
                    
                    self.logger.info(f"Git lock acquired successfully", 
                                   component="lock_coordinator",
                                   details={
                                       "service": service_name, 
                                       "wait_time": time.time() - start_time
                                   })
                    
                    yield
                    return
                    
                except IOError:
                    # Блокировка занята, ждем
                    time.sleep(1)
            
            # Таймаут истек
            elapsed_time = time.time() - start_time
            self.logger.error(f"Failed to acquire Git lock within timeout", 
                            component="lock_coordinator",
                            details={
                                "service": service_name, 
                                "timeout": timeout,
                                "elapsed_time": elapsed_time
                            })
            
            raise TimeoutError(f"Could not acquire Git lock for {service_name} within {timeout} seconds")
            
        except Exception as e:
            self.logger.error(f"Error acquiring Git lock", 
                            component="lock_coordinator",
                            details={"service": service_name, "error": str(e)},
                            exc_info=True)
            raise
            
        finally:
            if lock_file:
                try:
                    # Освобождение блокировки
                    fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
                    lock_file.close()
                    
                    self.logger.info(f"Git lock released", 
                                   component="lock_coordinator",
                                   details={"service": service_name})
                    
                except Exception as e:
                    self.logger.error(f"Error releasing Git lock", 
                                    component="lock_coordinator",
                                    details={"service": service_name, "error": str(e)})
    
    def get_lock_status(self) -> dict:
        """
        Получение статуса блокировки
        
        Returns:
            dict: Информация о текущей блокировке
        """
        try:
            if not os.path.exists(self.lock_file_path):
                return {"locked": False, "owner": None, "timestamp": None}
            
            # Попытка получения неблокирующей блокировки для проверки статуса
            with open(self.lock_file_path, 'r') as f:
                try:
                    fcntl.flock(f.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                    # Блокировка свободна
                    return {"locked": False, "owner": None, "timestamp": None}
                except IOError:
                    # Блокировка занята, читаем информацию о владельце
                    content = f.read().strip()
                    if ':' in content:
                        owner, timestamp = content.split(':', 1)
                        return {
                            "locked": True, 
                            "owner": owner, 
                            "timestamp": int(timestamp)
                        }
                    else:
                        return {"locked": True, "owner": "unknown", "timestamp": None}
        
        except Exception as e:
            self.logger.error(f"Error checking lock status", 
                            component="lock_coordinator",
                            details={"error": str(e)})
            return {"locked": "unknown", "owner": None, "timestamp": None, "error": str(e)}
    
    def force_unlock(self, service_name: str) -> bool:
        """
        Принудительное освобождение блокировки (использовать с осторожностью)
        
        Args:
            service_name: Имя сервиса, выполняющего принудительное освобождение
        
        Returns:
            bool: True если блокировка была освобождена
        """
        try:
            if os.path.exists(self.lock_file_path):
                os.remove(self.lock_file_path)
                
                self.logger.warning(f"Git lock forcefully removed", 
                                  component="lock_coordinator",
                                  details={"service": service_name})
                return True
            else:
                self.logger.info(f"No lock file to remove", 
                               component="lock_coordinator",
                               details={"service": service_name})
                return False
                
        except Exception as e:
            self.logger.error(f"Error force unlocking", 
                            component="lock_coordinator",
                            details={"service": service_name, "error": str(e)})
            return False


# Глобальный экземпляр координатора
_git_coordinator = None


def get_git_coordinator() -> GitLockCoordinator:
    """Получение глобального экземпляра Git координатора"""
    global _git_coordinator
    if _git_coordinator is None:
        _git_coordinator = GitLockCoordinator()
    return _git_coordinator