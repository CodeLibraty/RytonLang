import os
import sys
from Interpritator.Core import SharpyLang

def setup_ryton_environment():
    if getattr(sys, 'frozen', False):
        base_path = os.path.dirname(sys.executable)
    else:
        base_path = os.path.dirname(__file__)
        
    # Устанавливаем переменные окружения Ryton
    os.environ['RYTON_HOME'] = base_path
    os.environ['RYTON_STDLIB'] = os.path.join(base_path, 'Interpritator/std')
    
    # Добавляем пути для поиска модулей
    sys.path.insert(0, os.path.join(base_path, 'Interpritator'))
    sys.path.insert(0, os.path.join(base_path, 'Interpritator/std'))

def main():
    setup_ryton_environment()
    ryton = SharpyLang()
    
    if len(sys.argv) > 1:
        with open(sys.argv[1], 'r') as f:
            code = f.read()
            ryton.execute(code)
    else:
        print("Укажите файл для выполнения")

if __name__ == '__main__':
    main()
