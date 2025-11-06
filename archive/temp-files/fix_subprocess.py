#!/usr/bin/env python3
"""
Скрипт для исправления subprocess.run с capture_output на stdout/stderr для Python 3.6
"""
import os
import re

def fix_subprocess_in_file(filepath):
    """Исправление subprocess в одном файле"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Замена capture_output=True на stdout=subprocess.PIPE, stderr=subprocess.PIPE
        content = re.sub(
            r'capture_output=True,\s*\n\s*text=True,',
            'stdout=subprocess.PIPE,\n                stderr=subprocess.PIPE,\n                text=True,',
            content
        )
        
        # Простая замена для однострочных случаев
        content = re.sub(
            r'capture_output=True, text=True,',
            'stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,',
            content
        )
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
            
        print(f"Fixed subprocess in: {filepath}")
        
    except Exception as e:
        print(f"Error fixing {filepath}: {e}")

def main():
    """Основная функция"""
    app_dir = "docker/ci-cd/app"
    
    for root, dirs, files in os.walk(app_dir):
        for file in files:
            if file.endswith('.py'):
                filepath = os.path.join(root, file)
                fix_subprocess_in_file(filepath)

if __name__ == "__main__":
    main()