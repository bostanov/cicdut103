#!/usr/bin/env python3
"""
Скрипт для замены text=True на universal_newlines=True для Python 3.6
"""
import os
import re

def fix_text_param_in_file(filepath):
    """Исправление text параметра в одном файле"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Замена text=True на universal_newlines=True
        content = re.sub(r'text=True,', 'universal_newlines=True,', content)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
            
        print(f"Fixed text param in: {filepath}")
        
    except Exception as e:
        print(f"Error fixing {filepath}: {e}")

def main():
    """Основная функция"""
    app_dir = "docker/ci-cd/app"
    
    for root, dirs, files in os.walk(app_dir):
        for file in files:
            if file.endswith('.py'):
                filepath = os.path.join(root, file)
                fix_text_param_in_file(filepath)

if __name__ == "__main__":
    main()