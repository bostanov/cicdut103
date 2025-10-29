"""
Pipeline Coordinator Service - сервис для мониторинга и координации пайплайнов
"""
import os
import sys
import time
import signal
from datetime import datetime

# Добавление пути к shared модулям
sys.path.append('/app')

from shared.logger import get_logger
from pipeline_coordinator import get_pipeline_coordinator


class PipelineCoordinatorService:
    """Сервис Pipeline Coordinator"""
    
    def __init__(self):
        self.logger = get_logger("pipeline_coordinator_service")
        self.coordinator = get_pipeline_coordinator()
        self.running = True
        
        # Настройка обработчиков сигналов
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)
        
        self.logger.info("Pipeline Coordinator Service initialized", component="init")
    
    def _signal_handler(self, signum, frame):
        """Обработчик сигналов для graceful shutdown"""
        self.logger.info(f"Received signal {signum}, shutting down gracefully", 
                        component="signal_handler")
        self.running = False
    
    def run(self):
        """Основной цикл работы сервиса"""
        self.logger.info("Starting Pipeline Coordinator Service", component="main")
        
        while self.running:
            try:
                # Мониторинг активных пайплайнов
                self.coordinator.monitor_active_pipelines()
                
                # Ожидание до следующего цикла
                for _ in range(self.coordinator.monitoring_interval):
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
        
        self.logger.info("Pipeline Coordinator Service stopped", component="main")
        return 0


if __name__ == '__main__':
    service = PipelineCoordinatorService()
    exit_code = service.run()
    sys.exit(exit_code)