#!/usr/bin/env python3
"""
Скрипт проверки готовности всей CI/CD системы
"""
import os
import sys
import requests
import time
from datetime import datetime
from typing import Dict, Any, List

# Добавление пути к модулям приложения
sys.path.insert(0, os.path.dirname(__file__))


class SystemReadinessChecker:
    """Проверка готовности всей системы"""
    
    def __init__(self):
        self.services = {
            'postgres': {
                'name': 'PostgreSQL',
                'check_method': self._check_postgres,
                'required': True
            },
            'gitlab': {
                'name': 'GitLab',
                'check_method': self._check_gitlab,
                'required': True
            },
            'redmine': {
                'name': 'Redmine',
                'check_method': self._check_redmine,
                'required': True
            },
            'sonarqube': {
                'name': 'SonarQube',
                'check_method': self._check_sonarqube,
                'required': True
            },
            'cicd_service': {
                'name': 'CI/CD Service',
                'check_method': self._check_cicd_service,
                'required': True
            }
        }
        
        self.results = {}
    
    def _check_postgres(self) -> Dict[str, Any]:
        """Проверка PostgreSQL"""
        try:
            from integrations import get_postgres_client
            postgres_client = get_postgres_client()
            
            # Проверка подключения
            result = postgres_client.execute_query("SELECT version()", fetch=True)
            version = result[0]['version'] if result else "Unknown"
            
            # Проверка таблиц интеграции
            tables_result = postgres_client.execute_query("""
                SELECT table_name FROM information_schema.tables 
                WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
            """, fetch=True)
            
            tables = [row['table_name'] for row in tables_result]
            required_tables = ['pipelines', 'sonar_analysis', 'external_files', 
                             'redmine_notifications', 'integration_config']
            
            missing_tables = [t for t in required_tables if t not in tables]
            
            return {
                'status': 'healthy' if not missing_tables else 'degraded',
                'details': {
                    'version': version,
                    'tables_count': len(tables),
                    'missing_tables': missing_tables
                }
            }
            
        except Exception as e:
            return {
                'status': 'unhealthy',
                'error': str(e)
            }
    
    def _check_gitlab(self) -> Dict[str, Any]:
        """Проверка GitLab"""
        try:
            gitlab_url = os.getenv('GITLAB_URL', 'http://gitlab')
            
            # Проверка доступности
            response = requests.get(f"{gitlab_url}/-/health", timeout=10)
            
            if response.status_code == 200:
                # Проверка API
                try:
                    from integrations import get_gitlab_client
                    gitlab_client = get_gitlab_client()
                    
                    # Попытка получить проекты
                    main_project = gitlab_client.get_project_by_name("ut103-ci")
                    external_project = gitlab_client.get_project_by_name("ut103-external-files")
                    
                    return {
                        'status': 'healthy',
                        'details': {
                            'main_project_exists': main_project is not None,
                            'external_project_exists': external_project is not None,
                            'api_accessible': True
                        }
                    }
                except Exception as api_error:
                    return {
                        'status': 'degraded',
                        'details': {
                            'web_accessible': True,
                            'api_error': str(api_error)
                        }
                    }
            else:
                return {
                    'status': 'unhealthy',
                    'error': f"HTTP {response.status_code}"
                }
                
        except Exception as e:
            return {
                'status': 'unhealthy',
                'error': str(e)
            }
    
    def _check_redmine(self) -> Dict[str, Any]:
        """Проверка Redmine"""
        try:
            redmine_url = os.getenv('REDMINE_URL', 'http://redmine:3000')
            
            # Проверка доступности
            response = requests.get(redmine_url, timeout=10)
            
            if response.status_code == 200:
                # Проверка API
                try:
                    from integrations import get_redmine_client
                    redmine_client = get_redmine_client()
                    
                    # Попытка получить проект
                    main_project = redmine_client.get_project_by_identifier("ut103-ci")
                    
                    return {
                        'status': 'healthy',
                        'details': {
                            'main_project_exists': main_project is not None,
                            'api_accessible': True
                        }
                    }
                except Exception as api_error:
                    return {
                        'status': 'degraded',
                        'details': {
                            'web_accessible': True,
                            'api_error': str(api_error)
                        }
                    }
            else:
                return {
                    'status': 'unhealthy',
                    'error': f"HTTP {response.status_code}"
                }
                
        except Exception as e:
            return {
                'status': 'unhealthy',
                'error': str(e)
            }
    
    def _check_sonarqube(self) -> Dict[str, Any]:
        """Проверка SonarQube"""
        try:
            sonar_url = os.getenv('SONARQUBE_URL', 'http://sonarqube:9000')
            
            # Проверка статуса системы
            response = requests.get(f"{sonar_url}/api/system/status", timeout=10)
            
            if response.status_code == 200:
                status_data = response.json()
                system_status = status_data.get('status', 'UNKNOWN')
                
                if system_status == 'UP':
                    # Проверка проектов
                    try:
                        from integrations import get_sonarqube_client
                        sonar_client = get_sonarqube_client()
                        
                        main_project = sonar_client.get_project_info("ut103-ci")
                        external_project = sonar_client.get_project_info("ut103-external-files")
                        
                        return {
                            'status': 'healthy',
                            'details': {
                                'system_status': system_status,
                                'main_project_exists': main_project is not None,
                                'external_project_exists': external_project is not None
                            }
                        }
                    except Exception as api_error:
                        return {
                            'status': 'degraded',
                            'details': {
                                'system_status': system_status,
                                'api_error': str(api_error)
                            }
                        }
                else:
                    return {
                        'status': 'unhealthy',
                        'error': f"System status: {system_status}"
                    }
            else:
                return {
                    'status': 'unhealthy',
                    'error': f"HTTP {response.status_code}"
                }
                
        except Exception as e:
            return {
                'status': 'unhealthy',
                'error': str(e)
            }
    
    def _check_cicd_service(self) -> Dict[str, Any]:
        """Проверка CI/CD сервиса"""
        try:
            # Проверка API сервера
            response = requests.get("http://localhost:8080/health", timeout=10)
            
            if response.status_code == 200:
                health_data = response.json()
                
                # Проверка Pipeline Coordinator
                try:
                    from pipeline_coordinator import get_pipeline_coordinator
                    coordinator = get_pipeline_coordinator()
                    
                    active_pipelines = coordinator.get_active_pipelines_status()
                    
                    return {
                        'status': 'healthy',
                        'details': {
                            'api_server': health_data.get('status'),
                            'active_pipelines': active_pipelines['active_count'],
                            'coordinator_running': True
                        }
                    }
                except Exception as coord_error:
                    return {
                        'status': 'degraded',
                        'details': {
                            'api_server': health_data.get('status'),
                            'coordinator_error': str(coord_error)
                        }
                    }
            else:
                return {
                    'status': 'unhealthy',
                    'error': f"API server HTTP {response.status_code}"
                }
                
        except Exception as e:
            return {
                'status': 'unhealthy',
                'error': str(e)
            }
    
    def check_all_services(self) -> Dict[str, Any]:
        """Проверка всех сервисов"""
        print("🔍 Checking system readiness...")
        print("=" * 60)
        
        for service_id, service_info in self.services.items():
            print(f"Checking {service_info['name']}...", end=" ")
            
            try:
                result = service_info['check_method']()
                self.results[service_id] = result
                
                status = result['status']
                if status == 'healthy':
                    print("✅ Healthy")
                elif status == 'degraded':
                    print("⚠️  Degraded")
                else:
                    print("❌ Unhealthy")
                    
                # Показать детали если есть ошибки
                if 'error' in result:
                    print(f"   Error: {result['error']}")
                elif 'details' in result and status != 'healthy':
                    print(f"   Details: {result['details']}")
                    
            except Exception as e:
                self.results[service_id] = {
                    'status': 'unhealthy',
                    'error': f"Check failed: {str(e)}"
                }
                print(f"❌ Check failed: {e}")
        
        return self.results
    
    def generate_summary(self) -> Dict[str, Any]:
        """Генерация сводки готовности"""
        healthy_count = sum(1 for r in self.results.values() if r['status'] == 'healthy')
        degraded_count = sum(1 for r in self.results.values() if r['status'] == 'degraded')
        unhealthy_count = sum(1 for r in self.results.values() if r['status'] == 'unhealthy')
        
        total_services = len(self.services)
        
        if unhealthy_count == 0 and degraded_count == 0:
            overall_status = "READY"
            status_emoji = "✅"
        elif unhealthy_count == 0:
            overall_status = "PARTIALLY_READY"
            status_emoji = "⚠️"
        else:
            overall_status = "NOT_READY"
            status_emoji = "❌"
        
        return {
            'overall_status': overall_status,
            'status_emoji': status_emoji,
            'healthy_count': healthy_count,
            'degraded_count': degraded_count,
            'unhealthy_count': unhealthy_count,
            'total_services': total_services,
            'readiness_percentage': (healthy_count / total_services) * 100,
            'timestamp': datetime.utcnow().isoformat() + "Z"
        }


def main():
    """Главная функция проверки готовности"""
    print("🚀 CI/CD System Readiness Check")
    print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    checker = SystemReadinessChecker()
    results = checker.check_all_services()
    summary = checker.generate_summary()
    
    print()
    print("=" * 60)
    print("📊 System Readiness Summary")
    print("=" * 60)
    
    print(f"Overall Status: {summary['status_emoji']} {summary['overall_status']}")
    print(f"Readiness: {summary['readiness_percentage']:.1f}%")
    print(f"Services: {summary['healthy_count']}/{summary['total_services']} healthy")
    
    if summary['degraded_count'] > 0:
        print(f"Degraded: {summary['degraded_count']} services")
    
    if summary['unhealthy_count'] > 0:
        print(f"Unhealthy: {summary['unhealthy_count']} services")
    
    print()
    
    if summary['overall_status'] == "READY":
        print("🎉 System is ready for production use!")
        return 0
    elif summary['overall_status'] == "PARTIALLY_READY":
        print("⚠️  System is partially ready - some features may be limited")
        return 1
    else:
        print("❌ System is not ready - critical issues need to be resolved")
        return 2


if __name__ == '__main__':
    exit_code = main()
    sys.exit(exit_code)