import os
import sys
import argparse
from pathlib import Path
import subprocess

from Interpritator.Core import SharpyLang
from tools.Packer import RytonPacker

def setup_ryton_environment():
    if getattr(sys, 'frozen', False):
        base_path = os.path.dirname(sys.executable)
    else:
        base_path = os.path.dirname(__file__)

    #base_path = str(Path.home()) + '/.local/lib/ryton/'

    os.environ['RYTON_HOME'] = base_path
    os.environ['RYTON_STDLIB'] = os.path.join(base_path, 'Interpritator/std')
    os.environ['RYTON_STDFUNCTION'] = os.path.join(base_path, 'Interpritator/stdFunction.py')
    
    sys.path.insert(0, os.path.join(base_path, 'Interpritator'))
    sys.path.insert(0, os.path.join(base_path, 'Interpritator/std'))
    
    current_dir = os.getcwd()
    os.environ['RYTON_PACKAGES'] = current_dir
    sys.path.insert(0, current_dir)

def update_metrics(self):
    process = psutil.Process()
    
    # CPU time used by Ryton process
    self.metrics['cpu'].append(process.cpu_percent())
    
    # Memory used by Ryton process
    self.metrics['memory'].append(process.memory_percent())
    
    # Disk IO by Ryton process
    disk_io = process.io_counters()
    self.metrics['disk'].append((disk_io.read_bytes + disk_io.write_bytes) / 1024 / 1024)
    
    # Network IO by Ryton process
    net_io = process.connections()
    self.metrics['network'].append(len(net_io))
    
    # Active threads in Ryton process
    self.metrics['threads'].append(len(process.threads()))
    
    self.drawing_area.queue_draw()
    return True

def run(ryton, file):
    with open(file, 'r', encoding='utf-8') as f:
        code = f.read()
        ryton.run(code)

def main():
    setup_ryton_environment()
    ryton = SharpyLang(os.getcwd(), os.path.dirname(__file__))
    
    parser = argparse.ArgumentParser(description='Ryton Programming Language [RRE & Translator]')
    
    parser.add_argument('command', choices=['run', 'rungui', 'compile', 'exec', 'translate', 'pack'])
    parser.add_argument('file', help='Source file to process')
    parser.add_argument('--guiService', choices=['QuantUI'], 
                      help='Enable GUI service with specified framework')
    parser.add_argument('--pySource', 
                      help='Enable GUI service with specified framework')

    args = parser.parse_args()

    if args.command == "rungui":
        # Запускаем GUI сервер в главном потоке
        service_module = f"std.{args.guiService}.{args.guiService}Service"
        
        # Запускаем транслятор в отдельном потоке
        import threading
        translator_thread = threading.Thread(target=lambda: runGUISupport(ryton, args.file), daemon=True)
        translator_thread.start()

        # Qt должен быть в главном потоке
        __import__(service_module, fromlist=[service_module]).startService()

    elif args.command == "run":
        if args.guiService:
            # Запускаем GUI сервер в главном потоке
            service_module = f"std.{args.guiService}.{args.guiService}Service"

            # Запускаем транслятор в отдельном потоке
            import threading
            translator_thread = threading.Thread(target=lambda: run(ryton, args.file), daemon=True)
            translator_thread.start()

            # Qt должен быть в главном потоке
            __import__(service_module, fromlist=[service_module]).startService()
        else:
            run(ryton, args.file)

    elif args.command == "translate":
        with open(args.file, 'r', encoding='utf-8') as f:
            code = f.read()
            python_code = ryton.transform_syntax(code)
            print(python_code)

    elif args.command == "pack":
        packer = RytonPacker()
        project_dir = os.path.dirname(args.file)
        output_name = os.path.splitext(args.file)[0]
        os.makedirs(f"{project_dir}/build_pack", exist_ok=True)
        output_name = f"{project_dir}/build_pack/lib"
        packer.pack_project(project_dir, output_name)

    elif args.command == "compile":
        with open(args.file, 'r', encoding='utf-8') as f:
            code = f.read()
            output = os.path.splitext(args.file)[0]
            ryton.compile(code, output)

    elif args.command == "exec":
        ryton.exec(args.file)

if __name__ == '__main__':
    main()
