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

class Linux:
    def __init__(self):
        self.user = os.getenv('USER')
        self.home = os.path.expanduser('~')
        
    def service(self, name):
        return ServiceManager(name)
        
    def process(self, name=None, pid=None):
        return ProcessManager(name, pid)
        
    def network(self):
        return NetworkManager()
        
    def disk(self):
        return DiskManager()

class ServiceManager:
    def start(self, service): 
        return os.system(f"systemctl start {service}")
        
    def stop(self, service):
        return os.system(f"systemctl stop {service}")
        
    def status(self, service):
        return os.system(f"systemctl status {service}")

class ProcessManager:
    def kill(self, signal="SIGTERM"):
        os.kill(self.pid, getattr(signal, signal))
        
    def priority(self, nice):
        os.nice(nice)

    def process_id():
        return os.getpid()
        
    def children(self):
        return psutil.Process(self.pid).children()

class NetworkManager:
    def interfaces(self):
        return psutil.net_if_addrs()
        
    def connections(self):
        return psutil.net_connections()
        
    def stats(self):
        return psutil.net_io_counters()

class DiskManager:
    def mount(self, device, path):
        os.system(f"mount {device} {path}")
        
    def unmount(self, path):
        os.system(f"umount {path}")
        
    def usage(self):
        return psutil.disk_usage('/')

def os_info():
    return {
        "system":    platform.system(),
        "release":   platform.release(),
        "version":   platform.version(),
        "machine":   platform.machine(),
        "processor": platform.processor(),
    }

def exit():
    sys.exit(0)

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

def kill_process(pid):
    os.kill(pid, 9)

def login_name():
    return os.getlogin()

def system_load():
    return os.getloadavg()
