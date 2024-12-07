import os
import sys
import subprocess
import webbrowser
import importlib
import platform
import inspect
import time
import json
from typing import Any

def clear(cmd='auto'):
    if cmd == 'auto':
        if platform.system() == 'Windows':
            os.system('cls')
        elif platform.system() == 'Linux':
            os.system('clear')
        elif platform.system() == 'Darwin':
            os.system('clear')
    else:
        if cmd in ['winows', 'nt', 'win32']:
            os.system('cls')

        elif cmd in ['linux', 'unix', 'macos', 'osx', 'darwin']:
            os.system('clear')

        else:
            print(f"os {os} not found")
            sys.exit(2)

def web_open(link=False):
    if link == False:
        pass
    else:
        webbrowser.open(link)

@staticmethod
def print_json(data: Any, indent: int = 2, sort_keys: bool = False):
    # Криво выводит данные в формате JSON.

    print(json.dumps(data, indent=indent, sort_keys=sort_keys, ensure_ascii=False))

@staticmethod
def print_dict(data: dict, indent: int = 0):
    # Красиво выводит словарь с отступами
    
    for key, value in data.items():
        print(' ' * indent + str(key) + ':', end=' ')
        if isinstance(value, dict):
            print()
            PrettyPrinter.print_dict(value, indent + 4)
        else:
            print(value)

@staticmethod
def print_list(data: list, indent: int = 0):
    for item in data:
        if isinstance(item, dict):
            PrettyPrinter.print_dict(item, indent)
        elif isinstance(item, list):
            PrettyPrinter.print_list(item, indent + 2)
        else:
            print(' ' * indent + str(item))

@staticmethod
def print_table(data: list, headers: list = None):
    """
    Выводит данные в виде таблицы.
    """
    if not data:
        return

    if headers is None:
        headers = list(data[0].keys()) if isinstance(data[0], dict) else [f"Column {i+1}" for i in range(len(data[0]))]

    # Определяем максимальную ширину для каждого столбца
    col_widths = [max(len(str(row.get(h, '') if isinstance(row, dict) else row[i])) for row in data) for i, h in enumerate(headers)]
    col_widths = [max(col_widths[i], len(h)) for i, h in enumerate(headers)]

    # Выводим заголовки
    header_str = " | ".join(h.ljust(col_widths[i]) for i, h in enumerate(headers))
    print(header_str)
    print("-" * len(header_str))

    # Выводим данные
    for row in data:
        if isinstance(row, dict):
            print(" | ".join(str(row.get(h, '')).ljust(col_widths[i]) for i, h in enumerate(headers)))
        else:
            print(" | ".join(str(item).ljust(col_widths[i]) for i, item in enumerate(row)))


# Not works
class pack:
    @staticmethod
    def delete(pack_name):
        try:
            # Удаляем пакет из sys.modules
            if pack_name in sys.modules:
                del sys.modules[pack_name]
            
            # Удаляем файлы пакета
            pack_path = pack_name.replace('.', os.path.sep)
            if os.path.exists(pack_path):
                for root, dirs, files in os.walk(pack_path, topdown=False):
                    for name in files:
                        os.remove(os.path.join(root, name))
                    for name in dirs:
                        os.rmdir(os.path.join(root, name))
                os.rmdir(pack_path)
        except Exception as e:
            print(f"Error: {pack_name}: {e}")

    @staticmethod
    def rename(old_name, new_name):
        try:
            old_path = old_name.replace('.', os.path.sep)
            new_path = new_name.replace('.', os.path.sep)
            if os.path.exists(old_path):
                os.rename(old_path, new_path)
            else:
                pass
        except Exception as e:
            print(f"Error: {old_name}: {e}")

    @staticmethod
    def add_func(pack_name, func_name, func_code):
        try:
            # Создаем или открываем файл пакета
            pack_path = pack_name.replace('.', os.path.sep) + '.py'
            os.makedirs(os.path.dirname(pack_path), exist_ok=True)
            with open(pack_path, 'a') as f:
                f.write(f"\n\ndef {func_name}:\n{func_code}\n")
        except Exception as e:
            print(f"Error: {pack_name}: {e}")

class func:
    @staticmethod
    def delete(module_name, func_name):
        try:
            module = importlib.import_module(module_name)
            if hasattr(module, func_name):
                delattr(module, func_name)
            else:
                pass
        except Exception as e:
            print(f"Error: {func_name}: {e}")

    @staticmethod
    def rename(module_name, old_name, new_name):
        try:
            module = importlib.import_module(module_name)
            if hasattr(module, old_name):
                setattr(module, new_name, getattr(module, old_name))
                delattr(module, old_name)
            else:
                pass
        except Exception as e:
            print(f"Error: {old_name}: {e}")

    @staticmethod
    def info(module_name, func_name):
        try:
            module = importlib.import_module(module_name)
            if hasattr(module, func_name):
                func = getattr(module, func_name)
                print(f"info {func_name}:")
                print(inspect.getdoc(func))
                print(f"args: {inspect.signature(func)}")
            else:
                print(f"func {func_name} not found in module {module_name}")
        except Exception as e:
            print(f"Error: {func_name}: {e}")
