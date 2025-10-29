#!/usr/bin/env python3
"""
Скрипт запуска тестов CI/CD системы
"""
import os
import sys
import unittest
import subprocess
from datetime import datetime

# Добавление пути к модулям приложения
sys.path.insert(0, os.path.dirname(__file__))


def run_unit_tests():
    """Запуск unit тестов"""
    print("=" * 60)
    print("🧪 Running Unit Tests")
    print("=" * 60)
    
    # Поиск и запуск всех тестов
    loader = unittest.TestLoader()
    start_dir = os.path.join(os.path.dirname(__file__), 'tests')
    suite = loader.discover(start_dir, pattern='test_*.py')
    
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    return result.wasSuccessful()


def run_integration_tests():
    """Запуск интеграционных тестов"""
    print("=" * 60)
    print("🔗 Running Integration Tests")
    print("=" * 60)
    
    try:
        # Проверка доступности PostgreSQL
        from integrations import get_postgres_client
        postgres_client = get_postgres_client()
        postgres_client.execute_query("SELECT 1", fetch=True)
        print("✅ PostgreSQL connection test passed")
        
        # Проверка создания тестового пайплайна
        pipeline_id = postgres_client.create_pipeline(
            pipeline_type="test",
            project_name="integration-test",
            triggered_by="test_runner"
        )
        print(f"✅ Test pipeline created with ID: {pipeline_id}")
        
        # Обновление статуса пайплайна
        postgres_client.update_pipeline_status(pipeline_id, "success", duration_seconds=1)
        print("✅ Pipeline status update test passed")
        
        return True
        
    except Exception as e:
        print(f"❌ Integration test failed: {e}")
        return False


def run_system_tests():
    """Запуск системных тестов"""
    print("=" * 60)
    print("🏗️ Running System Tests")
    print("=" * 60)
    
    try:
        # Проверка структуры файлов
        required_files = [
            'integrations/__init__.py',
            'integrations/postgres_client.py',
            'integrations/gitlab_client.py',
            'integrations/sonarqube_client.py',
            'integrations/redmine_client.py',
            'integrations/init_integrations.py',
            'pipeline_coordinator.py',
            'api_server.py',
            'supervisord.conf'
        ]
        
        missing_files = []
        for file_path in required_files:
            full_path = os.path.join(os.path.dirname(__file__), file_path)
            if not os.path.exists(full_path):
                missing_files.append(file_path)
        
        if missing_files:
            print(f"❌ Missing required files: {missing_files}")
            return False
        
        print("✅ All required files present")
        
        # Проверка импортов
        try:
            from integrations import (
                PostgreSQLClient, GitLabClient, SonarQubeClient, 
                RedmineClient, SystemInitializer
            )
            from pipeline_coordinator import PipelineCoordinator
            print("✅ All modules import successfully")
        except ImportError as e:
            print(f"❌ Import error: {e}")
            return False
        
        return True
        
    except Exception as e:
        print(f"❌ System test failed: {e}")
        return False


def main():
    """Главная функция запуска тестов"""
    print("🚀 CI/CD System Test Suite")
    print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    results = []
    
    # Запуск системных тестов
    system_result = run_system_tests()
    results.append(("System Tests", system_result))
    
    # Запуск unit тестов
    unit_result = run_unit_tests()
    results.append(("Unit Tests", unit_result))
    
    # Запуск интеграционных тестов (только если доступна база данных)
    if os.getenv('RUN_INTEGRATION_TESTS', 'false').lower() == 'true':
        integration_result = run_integration_tests()
        results.append(("Integration Tests", integration_result))
    else:
        print("⏸️  Integration tests skipped (set RUN_INTEGRATION_TESTS=true to enable)")
    
    # Сводка результатов
    print("=" * 60)
    print("📊 Test Results Summary")
    print("=" * 60)
    
    all_passed = True
    for test_name, result in results:
        status = "✅ PASSED" if result else "❌ FAILED"
        print(f"{test_name}: {status}")
        if not result:
            all_passed = False
    
    print()
    if all_passed:
        print("🎉 All tests passed!")
        return 0
    else:
        print("💥 Some tests failed!")
        return 1


if __name__ == '__main__':
    exit_code = main()
    sys.exit(exit_code)