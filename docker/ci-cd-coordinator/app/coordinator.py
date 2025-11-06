#!/usr/bin/env python3
"""
CI/CD Coordinator - Integration service
Координирует интеграцию между GitLab, Redmine, SonarQube
GitSync работает на хост-машине Windows
"""

import os
import sys
import time
import logging
import requests
from flask import Flask, jsonify
from threading import Thread

# Настройка логирования
logging.basicConfig(
    level=os.getenv('LOG_LEVEL', 'INFO'),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Flask app для health checks и API
app = Flask(__name__)

class CICDCoordinator:
    """Координатор CI/CD интеграций"""
    
    def __init__(self):
        self.gitlab_url = os.getenv('GITLAB_URL', 'http://gitlab')
        self.gitlab_token = os.getenv('GITLAB_TOKEN', '')
        self.gitlab_project_id = os.getenv('GITLAB_PROJECT_ID', '1')
        
        self.redmine_url = os.getenv('REDMINE_URL', 'http://redmine:3000')
        self.redmine_username = os.getenv('REDMINE_USERNAME', 'admin')
        self.redmine_password = os.getenv('REDMINE_PASSWORD', 'admin')
        
        self.sonarqube_url = os.getenv('SONARQUBE_URL', 'http://sonarqube:9000')
        self.sonarqube_token = os.getenv('SONARQUBE_TOKEN', '')
        
        self.check_interval = int(os.getenv('CHECK_INTERVAL', '300'))
        self.running = True
        
    def check_services(self):
        """Проверка доступности сервисов"""
        services = {
            'gitlab': self.gitlab_url,
            'redmine': self.redmine_url,
            'sonarqube': self.sonarqube_url
        }
        
        results = {}
        for name, url in services.items():
            try:
                response = requests.get(f"{url}", timeout=10)
                results[name] = {
                    'status': 'healthy' if response.status_code < 500 else 'unhealthy',
                    'code': response.status_code
                }
            except Exception as e:
                results[name] = {'status': 'unhealthy', 'error': str(e)}
                
        return results
        
    def sync_loop(self):
        """Основной цикл синхронизации"""
        logger.info("CI/CD Coordinator started")
        logger.info("GitSync работает на хост-машине Windows")
        
        while self.running:
            try:
                # Проверка сервисов
                services = self.check_services()
                logger.info(f"Services status: {services}")
                
                # Здесь можно добавить логику интеграций
                # Например, синхронизация задач между Redmine и GitLab
                
                time.sleep(self.check_interval)
                
            except Exception as e:
                logger.error(f"Error in sync loop: {e}")
                time.sleep(60)
                
    def start(self):
        """Запуск координатора"""
        sync_thread = Thread(target=self.sync_loop, daemon=True)
        sync_thread.start()
        
        # Запуск Flask для health checks
        app.run(host='0.0.0.0', port=8085, debug=False)

# Flask routes
@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'cicd-coordinator',
        'gitsync_location': 'Windows host machine'
    })

@app.route('/status')
def status():
    """Статус сервисов"""
    coordinator = CICDCoordinator()
    services = coordinator.check_services()
    return jsonify({
        'coordinator': 'running',
        'services': services
    })

if __name__ == '__main__':
    coordinator = CICDCoordinator()
    coordinator.start()

