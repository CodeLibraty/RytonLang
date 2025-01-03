import os
import sys
import shutil
import requests
import tarfile
from pathlib import Path

class RytonPackageManager:
    def __init__(self):
        self.base_path = Path.cwd()
        self.cst_path = self.base_path / "cst"
        self.python_path = self.cst_path / "py"
        self.ryton_path = self.cst_path / "ryton"
        self.zig_path = self.base_path / "ZigLang/lib"
        self.java_path = self.base_path / "JavaLang/lib"
        
        self.create_directory_structure()
        
    def create_directory_structure(self):
        self.python_path.mkdir(parents=True, exist_ok=True)
        self.ryton_path.mkdir(parents=True, exist_ok=True)
        self.zig_path.mkdir(parents=True, exist_ok=True)
        self.java_path.mkdir(parents=True, exist_ok=True)

    def _install_python_package(self, package_name: str):
        """Установка Python пакета напрямую из PyPI в локальную директорию"""
        # Получаем информацию о пакете с PyPI
        pypi_url = f"https://pypi.org/pypi/{package_name}/json"
        response = requests.get(pypi_url)
        package_info = response.json()
        
        # Получаем URL последней версии
        download_url = package_info['urls'][0]['url']
        
        # Скачиваем архив
        package_archive = self.python_path / f"{package_name}.tar.gz"
        response = requests.get(download_url)
        with open(package_archive, 'wb') as f:
            f.write(response.content)
            
        # Распаковываем в директорию пакета
        with tarfile.open(package_archive) as tar:
            tar.extractall(path=self.python_path / package_name)
            
        # Удаляем архив
        package_archive.unlink()
        
        # Создаем файл метаданных
        with open(self.python_path / f"{package_name}.meta", 'w') as f:
            f.write(f"version={package_info['info']['version']}\n")
            f.write(f"dependencies={package_info['info']['requires_dist']}\n")

    def install_package(self, package_name: str, package_type: str):
        if package_type == "python":
            self._install_python_package(package_name)
        elif package_type == "ryton":
            self._install_ryton_package(package_name)
        elif package_type == "zig":
            self._install_zig_package(package_name)
        elif package_type == "java":
            self._install_java_package(package_name)

    def list_installed_packages(self):
        packages = {
            "python": [p.name for p in self.python_path.glob("*") if p.is_dir()],
            "ryton": [p.name for p in self.ryton_path.glob("*") if p.is_dir()],
            "zig": [p.name for p in self.zig_path.glob("*") if p.is_dir()],
            "java": [p.name for p in self.java_path.glob("*") if p.is_dir()]
        }
        return packages

    def remove_package(self, package_name: str, package_type: str):
        if package_type == "python":
            shutil.rmtree(self.python_path / package_name)
            (self.python_path / f"{package_name}.meta").unlink()
