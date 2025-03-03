import os
import shutil

def pwd():
    return os.getcwd()

def ls():
    return os.listdir()

def get_home():
    """Получение домашней директории пользователя"""
    return os.path.expanduser('~')

def cd(path):
    if path in ['Home', '~'] or not path:
        path = os.path.expanduser('~')

    return os.chdir(path)

def mkdir(dir):
    return os.makedirs(dir, exist_ok=True)

def mv(old_name, new_name):
    return os.rename(old_name, new_name)

def cp(source_file, dest_file):
    return shutil.copy(source_file, dest_file)

def remove(path):
    return os.remove(path)

def rmdir(path):
    return os.rmdir(path)

