"""
API Server для CI/CD системы - обработка webhook'ов и управление
"""
import os
import sys
from flask import Flask, request, jsonify
from datetime import datetime

# Добавление пути к shared модулям
sys.path.append('/app')

from shared.logger import get_logger
from pipeline_coordinator import get_pipeline_coordinator
from integrations import get_postgres_client

app = Flask(__name__)
logger = get_logger("api_server")

# Инициализация клиентов (отложенная)
coordinator = None
postgres_client = None

def get_clients():
    """Получение клиентов с отложенной инициализацией"""
    global coordinator, postgres_client
    if coordinator is None:
        try:
            coordinator = get_pipeline_coordinator()
        except Exception as e:
            logger.warning(f"Failed to initialize pipeline coordinator: {e}")
    
    if postgres_client is None:
        try:
            postgres_client = get_postgres_client()
        except Exception as e:
            logger.warning(f"Failed to initialize postgres client: {e}")
    
    return coordinator, postgres_client


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    try:
        coordinator, postgres_client = get_clients()
        
        # Проверка подключения к базе данных (если доступна)
        db_status = "unknown"
        if postgres_client:
            try:
                postgres_client.execute_query("SELECT 1", fetch=True)
                db_status = "healthy"
            except Exception as e:
                db_status = f"error: {str(e)}"
        
        return jsonify({
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "service": "ci-cd-api",
            "database": db_status
        })
    except Exception as e:
        return jsonify({
            "status": "unhealthy",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "error": str(e)
        }), 500


@app.route('/api/gitlab-webhook', methods=['POST'])
def gitlab_webhook():
    """Обработка webhook'ов от GitLab"""
    try:
        data = request.get_json()
        event_type = request.headers.get('X-Gitlab-Event')
        
        logger.info("Received GitLab webhook", 
                   component="webhook_handler",
                   details={"event_type": event_type})
        
        if event_type == 'Pipeline Hook':
            # Обработка событий пайплайна
            pipeline_id = data.get('object_attributes', {}).get('id')
            status = data.get('object_attributes', {}).get('status')
            
            logger.info("Pipeline webhook received", 
                       component="webhook_handler",
                       details={"pipeline_id": pipeline_id, "status": status})
        
        return jsonify({"status": "received"}), 200
        
    except Exception as e:
        logger.error("Error processing GitLab webhook", 
                    component="webhook_handler",
                    details={"error": str(e)})
        return jsonify({"error": str(e)}), 500


@app.route('/api/sonarqube-webhook', methods=['POST'])
def sonarqube_webhook():
    """Обработка webhook'ов от SonarQube"""
    try:
        data = request.get_json()
        
        logger.info("Received SonarQube webhook", 
                   component="webhook_handler",
                   details={"project": data.get('project', {}).get('key')})
        
        return jsonify({"status": "received"}), 200
        
    except Exception as e:
        logger.error("Error processing SonarQube webhook", 
                    component="webhook_handler",
                    details={"error": str(e)})
        return jsonify({"error": str(e)}), 500


@app.route('/status', methods=['GET'])
def system_status():
    """Статус всей системы"""
    try:
        from integrations import get_gitlab_client, get_redmine_client, get_sonarqube_client
        
        status = {
            "system": "1C CI/CD Integration Platform",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "services": {},
            "integrations": {},
            "statistics": {}
        }
        
        # Проверка PostgreSQL
        try:
            coordinator, postgres_client = get_clients()
            if postgres_client:
                result = postgres_client.execute_query("SELECT COUNT(*) as count FROM integration_config", fetch=True)
                status["services"]["postgresql"] = {
                    "status": "healthy",
                    "config_entries": result[0]['count'] if result else 0
                }
            else:
                status["services"]["postgresql"] = {"status": "not_initialized"}
        except Exception as e:
            status["services"]["postgresql"] = {"status": "error", "error": str(e)}
        
        # Проверка GitLab
        try:
            gitlab_client = get_gitlab_client()
            projects = gitlab_client.get_projects()
            status["services"]["gitlab"] = {
                "status": "healthy",
                "projects_count": len(projects) if projects else 0
            }
        except Exception as e:
            status["services"]["gitlab"] = {"status": "error", "error": str(e)}
        
        # Проверка Redmine
        try:
            redmine_client = get_redmine_client()
            projects = redmine_client.get_projects()
            status["services"]["redmine"] = {
                "status": "healthy",
                "projects_count": len(projects) if projects else 0
            }
        except Exception as e:
            status["services"]["redmine"] = {"status": "error", "error": str(e)}
        
        # Проверка SonarQube
        try:
            sonarqube_client = get_sonarqube_client()
            ready = sonarqube_client.wait_for_sonarqube_ready()
            status["services"]["sonarqube"] = {
                "status": "healthy" if ready else "not_ready"
            }
        except Exception as e:
            status["services"]["sonarqube"] = {"status": "error", "error": str(e)}
        
        # Статистика пайплайнов
        try:
            result = postgres_client.execute_query(
                "SELECT COUNT(*) as count FROM pipelines WHERE DATE(triggered_at) = CURRENT_DATE", 
                fetch=True
            )
            status["statistics"]["pipelines_today"] = result[0]['count'] if result else 0
        except:
            status["statistics"]["pipelines_today"] = 0
        
        return jsonify(status), 200
        
    except Exception as e:
        return jsonify({
            "status": "error",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "error": str(e)
        }), 500


@app.route('/dashboard', methods=['GET'])
def dashboard():
    """HTML Dashboard для мониторинга"""
    try:
        # Получаем статус системы
        from integrations import get_gitlab_client, get_redmine_client, get_sonarqube_client
        
        # Проверяем все сервисы
        services_status = {}
        
        # PostgreSQL
        try:
            coordinator, postgres_client = get_clients()
            if postgres_client:
                postgres_client.execute_query("SELECT 1", fetch=True)
                services_status["postgresql"] = "✅ Healthy"
            else:
                services_status["postgresql"] = "⏳ Initializing"
        except:
            services_status["postgresql"] = "❌ Error"
        
        # GitLab
        try:
            gitlab_client = get_gitlab_client()
            projects = gitlab_client.get_projects()
            services_status["gitlab"] = f"✅ Healthy ({len(projects) if projects else 0} projects)"
        except:
            services_status["gitlab"] = "❌ Error"
        
        # Redmine
        try:
            redmine_client = get_redmine_client()
            services_status["redmine"] = "✅ Healthy"
        except:
            services_status["redmine"] = "❌ Error"
        
        # SonarQube
        try:
            sonarqube_client = get_sonarqube_client()
            services_status["sonarqube"] = "✅ Healthy"
        except:
            services_status["sonarqube"] = "❌ Error"
        
        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>1C CI/CD System Dashboard</title>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }}
                .container {{ max-width: 1200px; margin: 0 auto; }}
                .header {{ background: #2c3e50; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }}
                .services {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }}
                .service-card {{ background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
                .service-card h3 {{ margin-top: 0; color: #2c3e50; }}
                .status {{ font-size: 18px; font-weight: bold; }}
                .links {{ margin-top: 20px; }}
                .links a {{ display: inline-block; margin: 5px 10px 5px 0; padding: 8px 16px; background: #3498db; color: white; text-decoration: none; border-radius: 4px; }}
                .links a:hover {{ background: #2980b9; }}
                .refresh {{ text-align: center; margin: 20px 0; }}
                .refresh button {{ padding: 10px 20px; background: #27ae60; color: white; border: none; border-radius: 4px; cursor: pointer; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🚀 1C CI/CD Integration Platform</h1>
                    <p>Система автоматической интеграции и развертывания для 1С</p>
                    <p><strong>Время обновления:</strong> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
                </div>
                
                <div class="services">
                    <div class="service-card">
                        <h3>🗄️ PostgreSQL Database</h3>
                        <div class="status">{services_status.get('postgresql', '❓ Unknown')}</div>
                        <p>Центральная база данных для хранения конфигураций и метаданных</p>
                        <div class="links">
                            <a href="http://localhost:5433" target="_blank">Database (Port 5433)</a>
                        </div>
                    </div>
                    
                    <div class="service-card">
                        <h3>🦊 GitLab Repository</h3>
                        <div class="status">{services_status.get('gitlab', '❓ Unknown')}</div>
                        <p>Git репозиторий и CI/CD пайплайны для 1С проектов</p>
                        <div class="links">
                            <a href="http://localhost:8929" target="_blank">GitLab Web UI</a>
                            <a href="http://localhost:8929/ut103-ci" target="_blank">Main Project</a>
                        </div>
                    </div>
                    
                    <div class="service-card">
                        <h3>📋 Redmine Project Management</h3>
                        <div class="status">{services_status.get('redmine', '❓ Unknown')}</div>
                        <p>Управление задачами и внешними файлами</p>
                        <div class="links">
                            <a href="http://localhost:3000" target="_blank">Redmine Web UI</a>
                            <a href="http://localhost:3000/projects/ut103-ci" target="_blank">Main Project</a>
                        </div>
                    </div>
                    
                    <div class="service-card">
                        <h3>🔍 SonarQube Code Analysis</h3>
                        <div class="status">{services_status.get('sonarqube', '❓ Unknown')}</div>
                        <p>Анализ качества кода и безопасности</p>
                        <div class="links">
                            <a href="http://localhost:9000" target="_blank">SonarQube Web UI</a>
                            <a href="http://localhost:9000/dashboard?id=ut103-ci" target="_blank">Project Dashboard</a>
                        </div>
                    </div>
                    
                    <div class="service-card">
                        <h3>⚙️ CI/CD Integration Service</h3>
                        <div class="status">✅ Running</div>
                        <p>Основной сервис интеграции и координации</p>
                        <div class="links">
                            <a href="http://localhost:8080/health" target="_blank">Health Check</a>
                            <a href="http://localhost:8080/status" target="_blank">Status API</a>
                        </div>
                    </div>
                </div>
                
                <div class="refresh">
                    <button onclick="location.reload()">🔄 Обновить статус</button>
                </div>
            </div>
            
            <script>
                // Автообновление каждые 30 секунд
                setTimeout(function(){{ location.reload(); }}, 30000);
            </script>
        </body>
        </html>
        """
        
        return html, 200
        
    except Exception as e:
        return f"<h1>Error</h1><p>{str(e)}</p>", 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8090, debug=False)