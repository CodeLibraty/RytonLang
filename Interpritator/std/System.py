import os
import shutil
import platform
import psutil
import subprocess
import tempfile
import time
import glob
import stat
import sys

def os_info():
    return {
        "system":    platform.system(),
        "release":   platform.release(),
        "version":   platform.version(),
        "machine":   platform.machine(),
        "processor": platform.processor(),
    }

def stop():
    sys.exit(2)

def exit():
    sys.exit(1)

def environment_variable(name):
    return os.environ.get(name)

def set_environment_variable(name, value):
    os.environ[name] = value

def disk_usage(path="/"):
    return shutil.disk_usage(path)

def cpu_count():
    return os.cpu_count()

def memory_info():
    return psutil.virtual_memory()._asdict()

def process_list():
    return [p.info for p in psutil.process_iter(['pid', 'name', 'status'])]

def create_symlink(src, dst):
    os.symlink(src, dst)

def symlink_target(path):
    return os.readlink(path)

def process_id():
    return os.getpid()

def kill_process(pid):
    os.kill(pid, 9)

def login_name():
    return os.getlogin()

def system_load():
    return os.getloadavg()
