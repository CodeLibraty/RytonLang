import os
import sys

# Добавляем корневую директорию проекта в PYTHONPATH
root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(root_dir)

from RytonBinaryVM.RBVM import RytonBinaryVM

def run_bundle(bundle_path: str):
    vm = RytonBinaryVM()
    vm.load_bundle(bundle_path)
    vm.execute()

if __name__ == '__main__':
    import sys
    run_bundle(sys.argv[1])
