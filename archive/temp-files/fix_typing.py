#!/usr/bin/env python3
"""
Скрипт для исправления типизации Python 3.9+ на совместимую с Python 3.6
"""
import os
import re

def fix_typing_in_file(filepath):
    """Исправление типизации в одном файле"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Замена tuple[type, type] на просто tuple
        content = re.sub(r'tuple\[[^\]]+\]', 'tuple', content)
        
        # Замена list[type] на List[type] 
        content = re.sub(r'list\[([^\]]+)\]', r'List[\1]', content)
        
        # Замена dict[type, type] на Dict[type, type]
        content = re.sub(r'dict\[([^\]]+)\]', r'Dict[\1]', content)
        
        # Удаление сложных типизаций возвращаемых значений
        content = re.sub(r'-> (tuple|list|dict)\[[^\]]+\]:', r':', content)
        content = re.sub(r'-> Optional\[(tuple|list|dict)\[[^\]]+\]\]:', r':', content)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
            
        print(f"Fixed: {filepath}")
        
    except Exception as e:
        print(f"Error fixing {filepath}: {e}")

def main():
    """Основная функция"""
    app_dir = "docker/ci-cd/app"
    
    for root, dirs, files in os.walk(app_dir):
        for file in files:
            if file.endswith('.py'):
                filepath = os.path.join(root, file)
                fix_typing_in_file(filepath)

if __name__ == "__main__":
    main()