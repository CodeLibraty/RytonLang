import sys
import os
import argparse
from Interpritator.Core import SharpyLang

def create_parser():
    parser = argparse.ArgumentParser(description='Ryton Language CLI')
    parser.add_argument('file', nargs='?', help='Path to Ryton source file')
    parser.add_argument('-r', '--run', help='Execute Ryton code directly')
    parser.add_argument('-v', '--version', action='version', version='Ryton 1.0')
    parser.add_argument('-c', '--check', action='store_true', help='Check syntax only')
    parser.add_argument('-o', '--optimize', action='store_true', help='Enable optimizations')
    return parser

def read_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.read()

def main():
    parser = create_parser()
    args = parser.parse_args()
    
    ryton = SharpyLang()

    if args.run:
        # Выполнение кода напрямую из командной строки
        ryton.execute(args.run)
        return

    if not args.file:
        print("Error: No input file specified")
        parser.print_help()
        return

    if not os.path.exists(args.file):
        print(f"Error: File {args.file} not found")
        return

    try:
        code = read_file(args.file)
        
        if args.check:
            # Только проверка синтаксиса
            ryton.check_syntax(code)
            print("Syntax check passed successfully")
            return
            
        if args.optimize:
            # Включаем оптимизации
            ryton.trash_cleaner = True
            
        # Выполняем код
        ryton.execute(code)
        
    except Exception as e:
        print(f"Error: {str(e)}")
        sys.exit(1)

if __name__ == '__main__':
    main()
