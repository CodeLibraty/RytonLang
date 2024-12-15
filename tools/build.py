import os
import sys

# Добавляем корневую директорию проекта в PYTHONPATH
root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(root_dir)

from Interpritator.BundleBuilder import build_project

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Использование: python build.py путь/к/проекту")
        sys.exit(1)

    build_project(sys.argv[1])

