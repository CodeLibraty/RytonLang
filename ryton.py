import os
import sys
from pathlib import Path
from tools.UIProfiler import RytonProfiler, runprofile
from Interpritator.Core import SharpyLang

def setup_ryton_environment():
    if getattr(sys, 'frozen', False):
        base_path = os.path.dirname(sys.executable)
    else:
        base_path = os.path.dirname(__file__)

    #base_path = './' #str(Path.home()) + '/.local/lib/ryton/'

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

def main():
    setup_ryton_environment()
    ryton = SharpyLang(os.getcwd(), os.path.dirname(__file__))
    
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

    elif command == "run-profile":
        from threading import Thread
        profiler = RytonProfiler()
        Thread(target=lambda: runprofile(), daemon=True).start()

        with open(filename, 'r', encoding='utf-8') as f:
            code = f.read()
            ryton.run(code)

        input("enter for exit from program > ") 

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
