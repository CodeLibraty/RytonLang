import os
import shutil
import glob

def list_dir(path="."):
    return os.listdir(path)

def create_dir(path):
    os.makedirs(path, exist_ok=True)

def remove_dir(path):
    shutil.rmtree(path)

def copy_file(src, dst):
    shutil.copy2(src, dst)

def move_file(src, dst):
    shutil.move(src, dst)

def delete_file(path):
    os.remove(path)

def file_info(path):
    stat_info = os.stat(path)
    return {
        "size": stat_info.st_size,
        "created": time.ctime(stat_info.st_ctime),
        "modified": time.ctime(stat_info.st_mtime),
        "accessed": time.ctime(stat_info.st_atime),
        "mode": stat.filemode(stat_info.st_mode),
    }

def read_file(path):
    with open(path, 'r') as f:
        return f.read()

def write_file(path, content):
    with open(path, 'w') as f:
        f.write(content)

def append_to_file(path, content):
    with open(path, 'a') as f:
        f.write(content)

def find_files(pattern):
    return glob.glob(pattern)

def file_perm(path):
    return oct(os.stat(path).st_mode)[-3:]

def set_file_perm(path, permissions):
    os.chmod(path, int(str(permissions), 8))

def is_file(path):
    return os.path.isfile(path)

def is_directory(path):
    return os.path.isdir(path)

def file_size(path):
    return os.path.getsize(path)

def absolute_path(path):
    return os.path.abspath(path)

def join_paths(*paths):
    return os.path.join(*paths)

def split_path(path):
    return os.path.split(path)

def file_exten(path):
    return os.path.splitext(path)[1]

def rename_file(old_name, new_name):
    os.rename(old_name, new_name)

def file_creation_time(path):
    return os.path.getctime(path)

def file_modification_time(path):
    return os.path.getmtime(path)

def file_access_time(path):
    return os.path.getatime(path)
