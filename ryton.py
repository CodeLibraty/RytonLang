import os
import sys
from pathlib import Path
from Interpritator.Core import SharpyLang

def setup_ryton_environment():
    if getattr(sys, 'frozen', False):
        base_path = os.path.dirname(sys.executable)
    else:
        base_path = os.path.dirname(__file__)

    base_path = str(Path.home()) + '/.local/lib/ryton/'

    os.environ['RYTON_HOME'] = base_path
    os.environ['RYTON_STDLIB'] = os.path.join(base_path, 'Interpritator/std')
    os.environ['RYTON_STDFUNCTION'] = os.path.join(base_path, 'Interpritator/stdFunction.py')
    
    sys.path.insert(0, os.path.join(base_path, 'Interpritator'))
    sys.path.insert(0, os.path.join(base_path, 'Interpritator/std'))
    
    current_dir = os.getcwd()
    os.environ['RYTON_PACKAGES'] = current_dir
    sys.path.insert(0, current_dir)

def main():
    setup_ryton_environment()
    ryton = SharpyLang(os.getcwd())
    
    if len(sys.argv) < 2:
        print("Using:")
        print("ryton run file.ry - run file")
        print("ryton compile file.ry - compile to bitecode")
        print("ryton exec file.ryc - execute bytecode file")
        return

    command = sys.argv[1]
    if len(sys.argv) < 3:
        print("Enter File")
        return

    filename = sys.argv[2]

    if command == "run":
        with open(filename, 'r', encoding='utf-8') as f:
            code = f.read()
            ryton.run(code)

    elif command == "compile":
        with open(filename, 'r', encoding='utf-8') as f:
            code = f.read()
            output = os.path.splitext(filename)[0]
            ryton.compile(code, output)

    elif command == "exec":
        ryton.exec(filename)

    else:
        print(f"Command Not Found: {command}")

if __name__ == '__main__':
    main()
