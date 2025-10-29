"""
Скрипт полной инициализации всех интеграций CI/CD системы
"""
import os
import sys
import time
import requests
from datetime import datetime
from typing import Dict, Any, List

# Добавление пути к shared модулям
sys.path.append('/app')

from shared.logger import get_logger, log_operation_start, log_operation_success, log_operation_error
from integrations.postgres_client import get_postgres_client
from integrations.gitlab_client import get_gitlab_client
from integrations.sonarqube_client import get_sonarqube_client
from integrations.redmine_client import get_redmine_client


class SystemInitializer:
    """Класс для инициализации всей CI/CD системы"""
    
    def __init__(self):
        self.logger = get_logger("system_initializer")
        
        # Клиенты интеграции
        self.postgres_client = None
        self.gitlab_client = None
        self.sonarqube_client = None
        self.redmine_client = None
        
        # Конфигурация сервисов
        self.services_config = {
            'postgres': {
                'url': f"postgresql://{os.getenv('POSTGRES_HOST', 'postgres')}:{os.getenv('POSTGRES_PORT', '5432')}",
                'timeout': 300
            },
            'gitlab': {
                'url': os.getenv('GITLAB_URL', 'http://gitlab'),
                'timeout': 600
            },
            'redmine': {
                'url': os.getenv('REDMINE_URL', 'http://redmine:3000'),
                'timeout': 300
            },
            'sonarqube': {
                'url': os.getenv('SONARQUBE_URL', 'http://sonarqube:9000'),
                'timeout': 300
            }
        }
        
        self.logger.info("System initializer created", component="init")
    
    def wait_for_service_ready(self, service_name: str, check_url: str, 
                              max_attempts: int = 30, delay: int = 10) -> bool:
        """Ожидание готовности сервиса"""
        correlation_id = log_operation_start("system_initializer", "wait_for_service", 
                                           {"service": service_name})
        
        self.logger.info(f"Waiting for {service_name} to be ready...", 
                        component="service_readiness",
                        details={"service": service_name, "url": check_url})
        
        for attempt in range(max_attempts):
            try:
                if service_name == 'postgres':
                    # Специальная проверка для PostgreSQL
                    import psycopg2
                    conn = psycopg2.connect(
                        host=os.getenv('POSTGRES_HOST', 'postgres'),
                        port=int(os.getenv('POSTGRES_PORT', '5432')),
                        database='postgres',
                        user='postgres',
                        password=os.getenv('POSTGRES_PASSWORD', 'postgres_root_password')
                    )
                    conn.close()
                    ready = True
                elif service_name == 'sonarqube':
                    # Проверка статуса SonarQube
                    response = requests.get(check_url, timeout=10)
                    ready = response.status_code == 200 and response.json().get('status') == 'UP'
                else:
                    # Обычная HTTP проверка
                    response = requests.get(check_url, timeout=10)
                    ready = response.status_code < 400
                
                if ready:
                    log_operation_success("system_initializer", "wait_for_service", correlation_id,
                                        {"service": service_name, "attempts": attempt + 1})
                    return True
                    
            except Exception as e:
                self.logger.debug(f"{service_name} not ready yet", 
                                component="service_readiness",
                                details={"attempt": attempt + 1, "error": str(e)})
            
            if attempt < max_attempts - 1:
                time.sleep(delay)
        
        log_operation_error("system_initializer", "wait_for_service", correlation_id,
                          Exception(f"{service_name} not ready after {max_attempts} attempts"))
        return False
    
    def wait_for_all_services(self) -> bool:
        """Ожидание готовности всех сервисов"""
        correlation_id = log_operation_start("system_initializer", "wait_for_all_services")
        
        try:
            services_to_check = [
                ('postgres', f"postgresql://{os.getenv('POSTGRES_HOST', 'postgres')}:{os.getenv('POSTGRES_PORT', '5432')}"),
                ('gitlab', os.getenv('GITLAB_URL', 'http://gitlab')),
                ('redmine', os.getenv('REDMINE_URL', 'http://redmine:3000')),
                ('sonarqube', f"{os.getenv('SONARQUBE_URL', 'http://sonarqube:9000')}/api/system/status")
            ]
            
            for service_name, check_url in services_to_check:
                if not self.wait_for_service_ready(service_name, check_url):
                    self.logger.error(f"Service {service_name} failed to start", 
                                    component="service_readiness")
                    return False
            
            log_operation_success("system_initializer", "wait_for_all_services", correlation_id)
            return True
            
        except Exception as e:
            log_operation_error("system_initializer", "wait_for_all_services", correlation_id, e)
            return False
    
    def initialize_postgres(self) -> bool:
        """Инициализация PostgreSQL"""
        correlation_id = log_operation_start("system_initializer", "initialize_postgres")
        
        try:
            self.logger.info("Initializing PostgreSQL integration...", component="postgres_init")
            
            # Создание клиента PostgreSQL
            self.postgres_client = get_postgres_client()
            
            # Проверка подключения
            test_query = "SELECT 1 as test"
            result = self.postgres_client.execute_query(test_query, fetch=True)
            
            if not result or result[0]['test'] != 1:
                raise Exception("PostgreSQL connection test failed")
            
            # Сохранение начальной конфигурации
            config_items = [
                ('gitlab', 'base_url', os.getenv('GITLAB_URL', 'http://gitlab')),
                ('gitlab', 'main_project_name', 'ut103-ci'),
                ('gitlab', 'external_files_project_name', 'ut103-external-files'),
                ('redmine', 'base_url', os.getenv('REDMINE_URL', 'http://redmine:3000')),
                ('redmine', 'main_project_identifier', 'ut103-ci'),
                ('sonarqube', 'base_url', os.getenv('SONARQUBE_URL', 'http://sonarqube:9000')),
                ('sonarqube', 'main_project_key', 'ut103-ci'),
                ('sonarqube', 'external_files_project_key', 'ut103-external-files')
            ]
            
            for service_name, config_key, config_value in config_items:
                self.postgres_client.set_config_value(service_name, config_key, config_value)
            
            log_operation_success("system_initializer", "initialize_postgres", correlation_id)
            return True
            
        except Exception as e:
            log_operation_error("system_initializer", "initialize_postgres", correlation_id, e)
            return False
    
    def initialize_gitlab(self) -> bool:
        """Инициализация GitLab"""
        correlation_id = log_operation_start("system_initializer", "initialize_gitlab")
        
        try:
            self.logger.info("Initializing GitLab integration...", component="gitlab_init")
            
            # Создание клиента GitLab
            self.gitlab_client = get_gitlab_client()
            
            # Ожидание готовности GitLab
            if not self.gitlab_client.wait_for_gitlab_ready():
                raise Exception("GitLab not ready for initialization")
            
            # Создание root токена если не существует
            if not self.gitlab_client.token:
                token = self.gitlab_client.create_root_token()
                if token:
                    # Сохранение токена в конфигурации
                    self.postgres_client.set_config_value('gitlab', 'root_token', token, is_secret=True)
            
            # Создание основного проекта
            main_project = self.gitlab_client.setup_full_project(
                name="ut103-ci",
                description="1C UT 10.3 Main CI/CD Project",
                pipeline_type="main"
            )
            
            if main_project:
                self.postgres_client.set_config_value('gitlab', 'main_project_id', str(main_project['id']))
                self.logger.info("Main GitLab project created", 
                               component="gitlab_init",
                               details={"project_id": main_project['id']})
            
            # Создание проекта для внешних файлов
            external_project = self.gitlab_client.setup_full_project(
                name="ut103-external-files",
                description="1C External Files Repository",
                pipeline_type="external"
            )
            
            if external_project:
                self.postgres_client.set_config_value('gitlab', 'external_project_id', str(external_project['id']))
                self.logger.info("External files GitLab project created", 
                               component="gitlab_init",
                               details={"project_id": external_project['id']})
            
            log_operation_success("system_initializer", "initialize_gitlab", correlation_id)
            return True
            
        except Exception as e:
            log_operation_error("system_initializer", "initialize_gitlab", correlation_id, e)
            return False
    
    def initialize_sonarqube(self) -> bool:
        """Инициализация SonarQube"""
        correlation_id = log_operation_start("system_initializer", "initialize_sonarqube")
        
        try:
            self.logger.info("Initializing SonarQube integration...", component="sonarqube_init")
            
            # Создание клиента SonarQube
            self.sonarqube_client = get_sonarqube_client()
            
            # Ожидание готовности SonarQube
            if not self.sonarqube_client.wait_for_sonarqube_ready():
                raise Exception("SonarQube not ready for initialization")
            
            # Изменение пароля по умолчанию
            self.sonarqube_client.change_default_password()
            
            # Создание токена пользователя
            token = self.sonarqube_client.create_user_token()
            if token:
                self.postgres_client.set_config_value('sonarqube', 'admin_token', token, is_secret=True)
            
            # Создание основного проекта
            if self.sonarqube_client.setup_full_project("ut103-ci", "1C UT 10.3 Main Project"):
                self.logger.info("Main SonarQube project created", component="sonarqube_init")
            
            # Создание проекта для внешних файлов
            if self.sonarqube_client.setup_full_project("ut103-external-files", "1C External Files Project"):
                self.logger.info("External files SonarQube project created", component="sonarqube_init")
            
            log_operation_success("system_initializer", "initialize_sonarqube", correlation_id)
            return True
            
        except Exception as e:
            log_operation_error("system_initializer", "initialize_sonarqube", correlation_id, e)
            return False
    
    def initialize_redmine(self) -> bool:
        """Инициализация Redmine"""
        correlation_id = log_operation_start("system_initializer", "initialize_redmine")
        
        try:
            self.logger.info("Initializing Redmine integration...", component="redmine_init")
            
            # Создание клиента Redmine
            self.redmine_client = get_redmine_client()
            
            # Ожидание готовности Redmine
            if not self.redmine_client.wait_for_redmine_ready():
                raise Exception("Redmine not ready for initialization")
            
            # Получение API ключа
            api_key = self.redmine_client.get_api_key()
            if api_key:
                self.postgres_client.set_config_value('redmine', 'admin_api_key', api_key, is_secret=True)
            
            # Создание основного проекта
            main_project = self.redmine_client.setup_full_project(
                identifier="ut103-ci",
                name="1C UT 10.3 CI/CD Project",
                description="Основной проект для управления разработкой 1С"
            )
            
            if main_project:
                self.postgres_client.set_config_value('redmine', 'main_project_id', str(main_project['id']))
                self.logger.info("Main Redmine project created", 
                               component="redmine_init",
                               details={"project_id": main_project['id']})
            
            # Создание пользователей для интеграции
            integration_users = [
                {
                    "login": "gitlab_integration",
                    "firstname": "GitLab",
                    "lastname": "Integration",
                    "mail": "gitlab@ci.local",
                    "password": "gitlab_integration_password"
                },
                {
                    "login": "sonarqube_integration",
                    "firstname": "SonarQube",
                    "lastname": "Integration",
                    "mail": "sonarqube@ci.local",
                    "password": "sonarqube_integration_password"
                }
            ]
            
            for user_info in integration_users:
                user = self.redmine_client.create_integration_user(**user_info)
                if user:
                    self.logger.info("Integration user created", 
                                   component="redmine_init",
                                   details={"login": user_info["login"]})
            
            log_operation_success("system_initializer", "initialize_redmine", correlation_id)
            return True
            
        except Exception as e:
            log_operation_error("system_initializer", "initialize_redmine", correlation_id, e)
            return False
    
    def verify_integrations(self) -> bool:
        """Проверка всех интеграций"""
        correlation_id = log_operation_start("system_initializer", "verify_integrations")
        
        try:
            self.logger.info("Verifying all integrations...", component="integration_verification")
            
            verification_results = {}
            
            # Проверка PostgreSQL
            try:
                result = self.postgres_client.execute_query("SELECT COUNT(*) as count FROM pipelines", fetch=True)
                verification_results['postgres'] = result is not None
            except Exception as e:
                verification_results['postgres'] = False
                self.logger.error("PostgreSQL verification failed", 
                                component="integration_verification",
                                details={"error": str(e)})
            
            # Проверка GitLab
            try:
                main_project = self.gitlab_client.get_project_by_name("ut103-ci")
                verification_results['gitlab'] = main_project is not None
            except Exception as e:
                verification_results['gitlab'] = False
                self.logger.error("GitLab verification failed", 
                                component="integration_verification",
                                details={"error": str(e)})
            
            # Проверка SonarQube
            try:
                # Просто проверяем доступность API SonarQube
                status = self.sonarqube_client.wait_for_sonarqube_ready()
                verification_results['sonarqube'] = status
            except Exception as e:
                verification_results['sonarqube'] = False
                self.logger.error("SonarQube verification failed", 
                                component="integration_verification",
                                details={"error": str(e)})
            
            # Проверка Redmine
            try:
                main_project = self.redmine_client.get_project_by_identifier("ut103-ci")
                verification_results['redmine'] = main_project is not None
            except Exception as e:
                verification_results['redmine'] = False
                self.logger.error("Redmine verification failed", 
                                component="integration_verification",
                                details={"error": str(e)})
            
            # Общий результат
            all_verified = all(verification_results.values())
            
            if all_verified:
                log_operation_success("system_initializer", "verify_integrations", correlation_id,
                                    {"verification_results": verification_results})
            else:
                self.logger.error("Some integrations failed verification", 
                                component="integration_verification",
                                details={"results": verification_results})
            
            return all_verified
            
        except Exception as e:
            log_operation_error("system_initializer", "verify_integrations", correlation_id, e)
            return False
    
    def create_initial_test_data(self) -> bool:
        """Создание начальных тестовых данных"""
        correlation_id = log_operation_start("system_initializer", "create_test_data")
        
        try:
            self.logger.info("Creating initial test data...", component="test_data_creation")
            
            # Создание тестового пайплайна в базе данных
            pipeline_id = self.postgres_client.create_pipeline(
                pipeline_type="system_init",
                project_name="ut103-ci",
                triggered_by="system_initializer",
                metadata={"description": "Initial system setup pipeline"}
            )
            
            # Обновление статуса пайплайна
            self.postgres_client.update_pipeline_status(pipeline_id, "success", duration_seconds=0)
            
            # Создание тестовой задачи в Redmine
            test_issue = self.redmine_client.create_issue(
                project_id="ut103-ci",
                subject="Система CI/CD успешно инициализирована",
                description=f"""Система CI/CD была успешно инициализирована {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}.

Созданы следующие компоненты:
- GitLab проекты: ut103-ci, ut103-external-files
- SonarQube проекты: ut103-ci, ut103-external-files  
- Redmine проект: ut103-ci
- PostgreSQL база данных с таблицами интеграции

Система готова к работе!""",
                tracker_id=3,  # CI/CD трекер
                priority_id=2   # Нормальный приоритет
            )
            
            if test_issue:
                self.logger.info("Test issue created", 
                               component="test_data_creation",
                               details={"issue_id": test_issue['id']})
            
            log_operation_success("system_initializer", "create_test_data", correlation_id)
            return True
            
        except Exception as e:
            log_operation_error("system_initializer", "create_test_data", correlation_id, e)
            return False
    
    def run_full_initialization(self) -> bool:
        """Запуск полной инициализации системы"""
        start_time = time.time()
        correlation_id = log_operation_start("system_initializer", "full_initialization")
        
        try:
            self.logger.info("🚀 Starting full system initialization...", component="main")
            
            # 1. Ожидание готовности всех сервисов
            self.logger.info("=== Step 1: Waiting for services ===", component="main")
            if not self.wait_for_all_services():
                raise Exception("Not all services are ready")
            
            # 2. Инициализация PostgreSQL
            self.logger.info("=== Step 2: Initializing PostgreSQL ===", component="main")
            if not self.initialize_postgres():
                raise Exception("PostgreSQL initialization failed")
            
            # 3. Инициализация GitLab
            self.logger.info("=== Step 3: Initializing GitLab ===", component="main")
            if not self.initialize_gitlab():
                raise Exception("GitLab initialization failed")
            
            # 4. Инициализация SonarQube
            self.logger.info("=== Step 4: Initializing SonarQube ===", component="main")
            if not self.initialize_sonarqube():
                raise Exception("SonarQube initialization failed")
            
            # 5. Инициализация Redmine
            self.logger.info("=== Step 5: Initializing Redmine ===", component="main")
            if not self.initialize_redmine():
                raise Exception("Redmine initialization failed")
            
            # 6. Проверка интеграций
            self.logger.info("=== Step 6: Verifying integrations ===", component="main")
            if not self.verify_integrations():
                raise Exception("Integration verification failed")
            
            # 7. Создание тестовых данных
            self.logger.info("=== Step 7: Creating test data ===", component="main")
            if not self.create_initial_test_data():
                self.logger.warning("Test data creation failed, but continuing...", component="main")
            
            duration = time.time() - start_time
            
            log_operation_success("system_initializer", "full_initialization", correlation_id,
                                {"duration_seconds": duration})
            
            self.logger.info("✅ Full system initialization completed successfully!", 
                           component="main",
                           details={"duration_seconds": duration})
            
            self.logger.info("🎉 System is ready for production use!", component="main")
            
            return True
            
        except Exception as e:
            duration = time.time() - start_time
            log_operation_error("system_initializer", "full_initialization", correlation_id, e,
                              {"duration_seconds": duration})
            
            self.logger.error("❌ System initialization failed", 
                            component="main",
                            details={"error": str(e), "duration_seconds": duration})
            
            return False


def main():
    """Главная функция инициализации"""
    print("=" * 80)
    print("🚀 1C CI/CD System Initialization")
    print("=" * 80)
    
    # Проверка переменных окружения
    auto_init = os.getenv('AUTO_INIT_SERVICES', 'true').lower() == 'true'
    
    if not auto_init:
        print("⏸️  Auto-initialization is disabled (AUTO_INIT_SERVICES=false)")
        print("✅ Skipping initialization")
        return True
    
    # Создание инициализатора
    initializer = SystemInitializer()
    
    # Запуск инициализации
    success = initializer.run_full_initialization()
    
    if success:
        print("=" * 80)
        print("✅ INITIALIZATION COMPLETED SUCCESSFULLY")
        print("🎉 System is ready for production use!")
        print("=" * 80)
        return True
    else:
        print("=" * 80)
        print("❌ INITIALIZATION FAILED")
        print("🔧 Check logs for details")
        print("=" * 80)
        return False


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)