#!/usr/bin/env python3
"""
Simple Service Manager - Works without admin rights
Manages existing services and provides easy control
"""

import os
import sys
import subprocess
import time
import argparse

# Service configurations
SERVICES = [
    "GitSync-1C-Service",
    "Precommit1C-Service", 
    "GitLab-Runner-1C"
]

def print_header(title):
    """Print a formatted header"""
    border = "╔" + "═" * 58 + "╗"
    middle = "║" + title.center(58) + "║"
    print(f"\n{border}")
    print(f"{middle}")
    print(f"{border}")

def print_success(message):
    """Print success message"""
    print(f"✓ {message}")

def print_error(message):
    """Print error message"""
    print(f"✗ {message}")

def print_warning(message):
    """Print warning message"""
    print(f"⚠ {message}")

def print_info(message):
    """Print info message"""
    print(f"ℹ {message}")

def run_command(cmd):
    """Run a command and return result"""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, shell=True)
        return result.returncode == 0, result.stdout, result.stderr
    except Exception as e:
        return False, "", str(e)

def get_service_status(service_name):
    """Get service status"""
    try:
        success, stdout, stderr = run_command(f'sc query "{service_name}"')
        
        if not success:
            return "Not Found"
        
        if "RUNNING" in stdout:
            return "Running"
        elif "STOPPED" in stdout:
            return "Stopped"
        elif "START_PENDING" in stdout:
            return "Starting"
        elif "STOP_PENDING" in stdout:
            return "Stopping"
        else:
            return "Unknown"
            
    except Exception as e:
        return f"Error: {e}"

def start_service(service_name):
    """Start a service"""
    try:
        success, stdout, stderr = run_command(f'sc start "{service_name}"')
        
        if success:
            print_success(f"{service_name} started")
            return True
        else:
            if "already running" in stderr.lower():
                print_info(f"{service_name} already running")
                return True
            else:
                print_error(f"Failed to start {service_name}: {stderr.strip()}")
                return False
    except Exception as e:
        print_error(f"Error starting {service_name}: {e}")
        return False

def stop_service(service_name):
    """Stop a service"""
    try:
        success, stdout, stderr = run_command(f'sc stop "{service_name}"')
        
        if success:
            print_success(f"{service_name} stopped")
            return True
        else:
            if "not running" in stderr.lower():
                print_info(f"{service_name} already stopped")
                return True
            else:
                print_error(f"Failed to stop {service_name}: {stderr.strip()}")
                return False
    except Exception as e:
        print_error(f"Error stopping {service_name}: {e}")
        return False

def restart_service(service_name):
    """Restart a service"""
    print(f"Restarting {service_name}...")
    stop_service(service_name)
    time.sleep(2)
    start_service(service_name)

def show_status():
    """Show status of all services"""
    print_header("CI/CD SERVICES STATUS")
    
    for service in SERVICES:
        status = get_service_status(service)
        
        if status == "Running":
            print(f"{service}: {status} ✓")
        elif status == "Stopped":
            print(f"{service}: {status} ⚠")
        elif status == "Not Found":
            print(f"{service}: {status} ✗")
        else:
            print(f"{service}: {status}")

def start_all():
    """Start all services"""
    print("Starting all CI/CD services...")
    for service in SERVICES:
        start_service(service)

def stop_all():
    """Stop all services"""
    print("Stopping all CI/CD services...")
    for service in SERVICES:
        stop_service(service)

def restart_all():
    """Restart all services"""
    print("Restarting all CI/CD services...")
    stop_all()
    time.sleep(3)
    start_all()

def install_services():
    """Install services (requires admin)"""
    print_header("SERVICE INSTALLATION")
    print_warning("Service installation requires Administrator privileges")
    print_info("Please run this script as Administrator for installation")
    print("")
    print("For manual installation, use these commands in Administrator PowerShell:")
    print("")
    
    for service in SERVICES:
        if service == "GitSync-1C-Service":
            binary_path = r'powershell.exe -ExecutionPolicy Bypass -File "C:\1C-CI-CD\ci\scripts\gitsync-service.ps1"'
        elif service == "Precommit1C-Service":
            binary_path = r'powershell.exe -ExecutionPolicy Bypass -File "C:\1C-CI-CD\ci\scripts\precommit1c-service.ps1"'
        elif service == "GitLab-Runner-1C":
            binary_path = r'"C:\Tools\gitlab-runner\gitlab-runner.exe" run --config "C:\Tools\gitlab-runner\config.toml"'
        
        print(f'sc create "{service}" binPath= "{binary_path}" start= auto')
    
    print("")

def run_services_manually():
    """Run services manually without Windows Service"""
    print_header("MANUAL SERVICE EXECUTION")
    print_info("Running services in manual mode (not as Windows Services)")
    print("")
    
    # Check if service scripts exist
    scripts = [
        ("GitSync Service", r"ci\scripts\gitsync-service.ps1"),
        ("Precommit1C Service", r"ci\scripts\precommit1c-service.ps1")
    ]
    
    for name, script_path in scripts:
        if os.path.exists(script_path):
            print(f"Starting {name} manually...")
            try:
                cmd = f'powershell -ExecutionPolicy Bypass -File "{script_path}"'
                subprocess.Popen(cmd, shell=True)
                print_success(f"{name} started in background")
            except Exception as e:
                print_error(f"Failed to start {name}: {e}")
        else:
            print_warning(f"Script not found: {script_path}")
    
    print("")
    print_info("Services are running in background processes")
    print_info("Use 'tasklist | findstr powershell' to see running processes")

def main():
    """Main function"""
    parser = argparse.ArgumentParser(description="Simple CI/CD Services Manager")
    parser.add_argument("action", choices=["status", "start", "stop", "restart", "install", "manual"], 
                       help="Action to perform")
    
    args = parser.parse_args()
    
    if args.action == "status":
        show_status()
    elif args.action == "start":
        start_all()
    elif args.action == "stop":
        stop_all()
    elif args.action == "restart":
        restart_all()
    elif args.action == "install":
        install_services()
    elif args.action == "manual":
        run_services_manually()

if __name__ == "__main__":
    main()
