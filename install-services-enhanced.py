#!/usr/bin/env python3
"""
Master Service Installer - Installs all CI/CD services
Enhanced Python implementation with direct Windows service management
"""

import os
import sys
import subprocess
import json
import time
import argparse
from pathlib import Path

# Service configurations
SERVICES = [
    {
        "name": "GitSync-1C-Service",
        "display_name": "GitSync 1C Synchronization Service",
        "description": "Automatically synchronizes 1C storage with Git repository",
        "binary_path": r'powershell.exe -ExecutionPolicy Bypass -File "C:\1C-CI-CD\ci\scripts\gitsync-service.ps1"'
    },
    {
        "name": "Precommit1C-Service", 
        "display_name": "Precommit1C External Files Monitor Service",
        "description": "Monitors external files directory and processes new files automatically",
        "binary_path": r'powershell.exe -ExecutionPolicy Bypass -File "C:\1C-CI-CD\ci\scripts\precommit1c-service.ps1"'
    },
    {
        "name": "GitLab-Runner-1C",
        "display_name": "GitLab Runner 1C CI/CD Service", 
        "description": "GitLab Runner for 1C CI/CD pipeline execution",
        "binary_path": r'"C:\Tools\gitlab-runner\gitlab-runner.exe" run --config "C:\Tools\gitlab-runner\config.toml"'
    }
]

def print_header(title, color="cyan"):
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

def is_admin():
    """Check if running as administrator"""
    try:
        import ctypes
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except:
        return False

def run_sc_command(args):
    """Run Windows sc command"""
    try:
        cmd = ["sc"] + args
        result = subprocess.run(cmd, capture_output=True, text=True, shell=True)
        return result.returncode == 0, result.stdout, result.stderr
    except Exception as e:
        return False, "", str(e)

def install_service(service):
    """Install a Windows service directly"""
    print(f"Installing {service['display_name']}...")
    
    try:
        # Create service using sc command
        success, stdout, stderr = run_sc_command([
            "create", service['name'],
            f"binPath= {service['binary_path']}",
            f"DisplayName= {service['display_name']}",
            f"Description= {service['description']}",
            "start= auto"
        ])
        
        if success:
            print_success(f"{service['display_name']} installed")
            return True
        else:
            if "already exists" in stderr.lower():
                print_warning(f"{service['display_name']} already exists")
                return True
            else:
                print_error(f"Failed to install {service['display_name']}: {stderr}")
                return False
                
    except Exception as e:
        print_error(f"Error installing {service['display_name']}: {e}")
        return False

def uninstall_service(service):
    """Uninstall a Windows service"""
    print(f"Uninstalling {service['display_name']}...")
    
    try:
        # Stop service first
        run_sc_command(["stop", service['name']])
        time.sleep(2)
        
        # Delete service
        success, stdout, stderr = run_sc_command(["delete", service['name']])
        
        if success:
            print_success(f"{service['display_name']} uninstalled")
            return True
        else:
            if "does not exist" in stderr.lower():
                print_warning(f"{service['display_name']} not found")
                return True
            else:
                print_error(f"Failed to uninstall {service['display_name']}: {stderr}")
                return False
                
    except Exception as e:
        print_error(f"Error uninstalling {service['display_name']}: {e}")
        return False

def get_service_status(service):
    """Get service status"""
    try:
        success, stdout, stderr = run_sc_command(["query", service['name']])
        
        if not success:
            return "Not Installed"
        
        # Parse status from output
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

def install_all_services():
    """Install all CI/CD services"""
    print_header("INSTALLING ALL CI/CD SERVICES")
    
    if not is_admin():
        print_error("Administrator privileges required for service installation")
        print_info("Please run this script as Administrator")
        return False
    
    success_count = 0
    for service in SERVICES:
        if install_service(service):
            success_count += 1
    
    print(f"\nStarting all services...")
    for service in SERVICES:
        start_service(service)
    
    print_header("INSTALLATION COMPLETED")
    print(f"Successfully installed: {success_count}/{len(SERVICES)} services")
    return success_count == len(SERVICES)

def uninstall_all_services():
    """Uninstall all CI/CD services"""
    print_header("UNINSTALLING ALL CI/CD SERVICES", "red")
    
    if not is_admin():
        print_error("Administrator privileges required for service uninstallation")
        print_info("Please run this script as Administrator")
        return False
    
    success_count = 0
    for service in SERVICES:
        if uninstall_service(service):
            success_count += 1
    
    print_header("UNINSTALLATION COMPLETED", "red")
    print(f"Successfully uninstalled: {success_count}/{len(SERVICES)} services")
    return success_count == len(SERVICES)

def show_service_status():
    """Show status of all services"""
    print_header("CI/CD SERVICES STATUS")
    
    for service in SERVICES:
        status = get_service_status(service)
        status_color = {
            "Running": "GREEN",
            "Stopped": "RED", 
            "Starting": "YELLOW",
            "Stopping": "YELLOW",
            "Not Installed": "RED"
        }.get(status.split(":")[0], "GRAY")
        
        print(f"{service['display_name']}: {status}")

def start_service(service):
    """Start a service"""
    try:
        success, stdout, stderr = run_sc_command(["start", service['name']])
        if success:
            print_success(f"{service['display_name']} started")
            return True
        else:
            if "already running" in stderr.lower():
                print_info(f"{service['display_name']} already running")
                return True
            else:
                print_error(f"Failed to start {service['display_name']}: {stderr}")
                return False
    except Exception as e:
        print_error(f"Error starting {service['display_name']}: {e}")
        return False

def stop_service(service):
    """Stop a service"""
    try:
        success, stdout, stderr = run_sc_command(["stop", service['name']])
        if success:
            print_success(f"{service['display_name']} stopped")
            return True
        else:
            if "not running" in stderr.lower():
                print_info(f"{service['display_name']} already stopped")
                return True
            else:
                print_error(f"Failed to stop {service['display_name']}: {stderr}")
                return False
    except Exception as e:
        print_error(f"Error stopping {service['display_name']}: {e}")
        return False

def start_all_services():
    """Start all services"""
    print("Starting all CI/CD services...")
    for service in SERVICES:
        start_service(service)

def stop_all_services():
    """Stop all services"""
    print("Stopping all CI/CD services...")
    for service in SERVICES:
        stop_service(service)

def restart_all_services():
    """Restart all services"""
    print("Restarting all CI/CD services...")
    stop_all_services()
    time.sleep(3)
    start_all_services()

def main():
    """Main function"""
    parser = argparse.ArgumentParser(description="CI/CD Services Manager - Enhanced Python Version")
    parser.add_argument("action", choices=["install", "uninstall", "status", "start", "stop", "restart"], 
                       help="Action to perform")
    
    args = parser.parse_args()
    
    # Execute action
    if args.action == "install":
        install_all_services()
    elif args.action == "uninstall":
        uninstall_all_services()
    elif args.action == "status":
        show_service_status()
    elif args.action == "start":
        start_all_services()
    elif args.action == "stop":
        stop_all_services()
    elif args.action == "restart":
        restart_all_services()

if __name__ == "__main__":
    main()
