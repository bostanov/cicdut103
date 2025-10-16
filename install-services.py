#!/usr/bin/env python3
"""
Master Service Installer - Installs all CI/CD services
Alternative Python implementation for Windows service management
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
        "installer_script": r"ci\scripts\install-gitsync-service.ps1"
    },
    {
        "name": "Precommit1C-Service", 
        "display_name": "Precommit1C External Files Monitor Service",
        "description": "Monitors external files directory and processes new files automatically",
        "installer_script": r"ci\scripts\install-precommit1c-service.ps1"
    },
    {
        "name": "GitLab-Runner-1C",
        "display_name": "GitLab Runner 1C CI/CD Service", 
        "description": "GitLab Runner for 1C CI/CD pipeline execution",
        "installer_script": r"ci\scripts\install-runner-service.ps1"
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

def run_powershell_script(script_path, action):
    """Run a PowerShell script with given action"""
    try:
        cmd = ["powershell", "-ExecutionPolicy", "Bypass", "-File", script_path, action]
        result = subprocess.run(cmd, capture_output=True, text=True, cwd=os.getcwd())
        
        if result.returncode == 0:
            return True, result.stdout
        else:
            return False, result.stderr
    except Exception as e:
        return False, str(e)

def install_all_services():
    """Install all CI/CD services"""
    print_header("INSTALLING ALL CI/CD SERVICES")
    
    for service in SERVICES:
        print(f"\nInstalling {service['display_name']}...")
        
        # Check if script exists
        script_path = Path(service['installer_script'])
        if not script_path.exists():
            print_error(f"Installer script not found: {script_path}")
            continue
        
        # Run installer script
        success, output = run_powershell_script(script_path, "install")
        
        if success:
            print_success(f"{service['display_name']} installed")
        else:
            print_error(f"Failed to install {service['display_name']}: {output}")
    
    print("\nStarting all services...")
    for service in SERVICES:
        try:
            # Try to start the service
            cmd = ["sc", "start", service['name']]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                print_success(f"{service['display_name']} started")
            else:
                print_warning(f"Could not start {service['display_name']} (may not be installed)")
        except Exception as e:
            print_error(f"Failed to start {service['display_name']}: {e}")
    
    print_header("ALL SERVICES INSTALLED SUCCESSFULLY", "green")

def uninstall_all_services():
    """Uninstall all CI/CD services"""
    print_header("UNINSTALLING ALL CI/CD SERVICES", "red")
    
    for service in SERVICES:
        print(f"\nUninstalling {service['display_name']}...")
        
        # Check if script exists
        script_path = Path(service['installer_script'])
        if not script_path.exists():
            print_error(f"Installer script not found: {script_path}")
            continue
        
        # Run uninstaller script
        success, output = run_powershell_script(script_path, "uninstall")
        
        if success:
            print_success(f"{service['display_name']} uninstalled")
        else:
            print_error(f"Failed to uninstall {service['display_name']}: {output}")
    
    print_header("ALL SERVICES UNINSTALLED SUCCESSFULLY", "red")

def show_service_status():
    """Show status of all services"""
    print_header("CI/CD SERVICES STATUS")
    
    for service in SERVICES:
        try:
            # Check service status using sc command
            cmd = ["sc", "query", service['name']]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                # Parse service status from output
                output = result.stdout
                if "RUNNING" in output:
                    status = "Running"
                    status_color = "GREEN"
                elif "STOPPED" in output:
                    status = "Stopped" 
                    status_color = "RED"
                elif "START_PENDING" in output:
                    status = "Starting"
                    status_color = "YELLOW"
                elif "STOP_PENDING" in output:
                    status = "Stopping"
                    status_color = "YELLOW"
                else:
                    status = "Unknown"
                    status_color = "GRAY"
                
                print(f"{service['display_name']}: {status}")
            else:
                print(f"{service['display_name']}: Not Installed")
                
        except Exception as e:
            print(f"{service['display_name']}: Error - {e}")

def start_all_services():
    """Start all services"""
    print("Starting all CI/CD services...")
    
    for service in SERVICES:
        try:
            cmd = ["sc", "start", service['name']]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                print_success(f"{service['display_name']} started")
            else:
                print_error(f"Failed to start {service['display_name']}: {result.stderr}")
        except Exception as e:
            print_error(f"Failed to start {service['display_name']}: {e}")

def stop_all_services():
    """Stop all services"""
    print("Stopping all CI/CD services...")
    
    for service in SERVICES:
        try:
            cmd = ["sc", "stop", service['name']]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                print_success(f"{service['display_name']} stopped")
            else:
                print_error(f"Failed to stop {service['display_name']}: {result.stderr}")
        except Exception as e:
            print_error(f"Failed to stop {service['display_name']}: {e}")

def restart_all_services():
    """Restart all services"""
    print("Restarting all CI/CD services...")
    stop_all_services()
    time.sleep(5)
    start_all_services()

def main():
    """Main function"""
    parser = argparse.ArgumentParser(description="CI/CD Services Manager")
    parser.add_argument("action", choices=["install", "uninstall", "status", "start", "stop", "restart"], 
                       help="Action to perform")
    
    args = parser.parse_args()
    
    # Check if running as administrator
    try:
        is_admin = os.getuid() == 0
    except AttributeError:
        # Windows - check if running as administrator
        import ctypes
        is_admin = ctypes.windll.shell32.IsUserAnAdmin() != 0
    
    if not is_admin and args.action in ["install", "uninstall"]:
        print_warning("Administrator privileges required for install/uninstall operations")
        print_info("Please run this script as Administrator")
        return
    
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
