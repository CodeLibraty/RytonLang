from pathlib import Path
import subprocess
import shutil
import sys
import os

class RytonBundleBuilder:
    def __init__(self, project_path: str):
        self.project_path = Path(project_path)
        self.build_dir = self.project_path / "build"
        self.bundle_dir = self.project_path / "bundle"
        self.ryton_core_cache = Path("cache/ryton_core")  # Кэш для ядра
        self.root_dir = Path(__file__).parent.parent
        self.build_script = self.root_dir / "build.sh"

    def convert_to_utf8(self, src_path):
        # Конвертируем все .ry файлы в UTF-8
        for file in src_path.glob('**/*.ry'):
            with open(file, 'rb') as f:
                content = f.read()
            for encoding in ['cp1251', 'latin1', 'utf-8']:
                try:
                    text = content.decode(encoding)
                    with open(file, 'w', encoding='utf-8') as f:
                        f.write(text)
                    break
                except UnicodeDecodeError:
                    continue

    def build_ryton_core(self):
        if self.ryton_core_cache.exists():
            print("[1/3] Используем готовое ядро Райтона из кэша...")
            return

        print("[1/3] Первичная сборка ядра Райтона...")
        self.ryton_core_cache.parent.mkdir(parents=True, exist_ok=True)

        current_dir = os.getcwd()
        os.chdir(str(self.root_dir))

        # Используем pip из виртуального окружения с флагом --break-system-packages
        venv_pip = Path(sys.prefix) / "bin" / "pip"
        subprocess.run([
            str(venv_pip), 
            "install", 
            "-r", "requirements.txt",
            "--break-system-packages"
        ], check=True)

        nuitka_options = "--jobs=3 --follow-imports --include-package=Interpritator --include-data-file=Interpritator/stdFunction.py=Interpritator/stdFunction.py  --nofollow-import-to=numpy --nofollow-import-to=numba --nofollow-import-to=cython --nofollow-import-to=dask --nofollow-import-to=ray --include-module=ray --include-module=dask --output-dir=dist --standalone"

        subprocess.run([
            './ryton_venv/bin/python3',
            "-m", "nuitka"
        ] + nuitka_options.split() + ["ryton_launcher.py"], check=True)

        os.chdir(current_dir)

        # Сохраняем в кэш
        shutil.copytree(
            "dist/ryton_launcher.dist",
            self.ryton_core_cache,
            dirs_exist_ok=True
        )
        print("[✓] Ядро собрано и сохранено в кэш")

    def build_user_project(self):
        print("[2/3] Сборка пользовательского проекта...")

        # Выведем содержимое проблемного файла
        src_file = self.project_path / "src" / "main.ry"
        print(f"Содержимое {src_file}:")
        with open(src_file, "rb") as f:
            content = f.read()
        print(f"Байты: {content}")
        print(f"Hex: {content.hex()}")

        # Создаём структуру
        user_build = self.build_dir / "user_project"
        user_build.mkdir(parents=True, exist_ok=True)
        
        # Копируем исходники пользователя
        shutil.copytree(
            self.project_path / "src",
            user_build / "src",
            dirs_exist_ok=True
        )
        
        # Создаём точку входа
        entry_code = """
from ryton_launcher import execute_ryton
import sys, os

def main():
    try:
        with open("debug.log", "w") as log:
            log.write("Запуск программы\\n")
            
            project_dir = os.path.dirname(os.path.abspath(__file__))
            log.write(f"Директория: {project_dir}\\n")
            
            os.chdir(project_dir)
            with open('../user/src/main.ry', 'r', encoding='utf-8') as f:
                code = f.read()
                log.write(f"Код: {code}\\n")
                
            log.write("Начало выполнения\\n")
            execute_ryton(code)
            log.write("Конец выполнения\\n")
            
    except Exception as e:
        with open("error.log", "w") as log:
            log.write(f"ОШИБКА: {str(e)}\\n")

if __name__ == '__main__':
    main()
"""
        with open(user_build / "user_launcher.py", "w", encoding='utf-8') as f:
            f.write(entry_code)

        user_src = self.build_dir / "user_project" / "src"
        shutil.copytree(self.project_path / "src", user_src, dirs_exist_ok=True)
        self.convert_to_utf8(user_src)

        # Собираем через Nuitka
        nuitka_options = [
            "--follow-imports",
            "--standalone",
            "--output-dir=" + str(self.build_dir / "user_dist"),
            str(user_build / "user_launcher.py")
        ]
        
        subprocess.run(["./ryton_venv/bin/python3", "-m", "nuitka"] + nuitka_options, check=True)
        print("[✓] Проект собран")
        
    def merge_bundles(self):
        print("[3/3] Объединение бандлов...")
        self.bundle_dir.mkdir(parents=True, exist_ok=True)
        
        # Копируем ядро из кэша
        shutil.copytree(
            self.ryton_core_cache,
            self.bundle_dir / "ryton",
            dirs_exist_ok=True
        )

        # Копируем пользовательский проект
        shutil.copytree(
            self.build_dir / "user_dist",
            self.bundle_dir / "user",
            dirs_exist_ok=True
        )
        
        # Создаём запускающий скрипт
        launcher = """
#!/bin/bash
cd "$(dirname "$0")"
./ryton/ryton_launcher.bin ./user/user_launcher.dist/user_launcher.bin
"""
        launcher_path = self.bundle_dir / "run.sh"
        with open(launcher_path, "w") as f:
            f.write(launcher)
        launcher_path.chmod(0o755)
        
        # Создаём архив
        shutil.make_archive(
            self.project_path / f"ryton_bundle_{os.name}",
            "zip",
            self.bundle_dir
        )
        
        print("[✓] Бандл создан успешно!")

def build_project(project_path: str):
    builder = RytonBundleBuilder(project_path)
    builder.build_ryton_core()
    builder.build_user_project()
    builder.merge_bundles()
