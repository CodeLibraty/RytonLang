import subprocess
import shlex
import signal
import psutil
import shutil
import time
import sys
import os

class Shell:
    def __init__(self):
        self.processes = {}
        self.aliases = {}
        self.env = os.environ.copy()
        
    def run(self, cmd, capture=True, shell=False, env=None, cwd=None):
        """Простой запуск команды с возвратом результата"""
        try:
            if shell:
                result = subprocess.run(cmd, shell=True, capture_output=capture, 
                                     text=True, env=env or self.env, cwd=cwd)
            else:
                args = shlex.split(cmd)
                result = subprocess.run(args, capture_output=capture,
                                     text=True, env=env or self.env, cwd=cwd)
            return result.stdout
        except Exception as e:
            return f"Error: {str(e)}"

    def pipe(self, *commands):
        """Конвейер команд через пайпы"""
        procs = []
        for cmd in commands:
            if not procs:
                p = subprocess.Popen(shlex.split(cmd), 
                                   stdout=subprocess.PIPE,
                                   env=self.env)
            else:
                p = subprocess.Popen(shlex.split(cmd),
                                   stdin=procs[-1].stdout,
                                   stdout=subprocess.PIPE, 
                                   env=self.env)
            procs.append(p)
        
        return procs[-1].communicate()[0].decode()

    def bg(self, cmd, name=None):
        """Запуск в фоне с именем процесса"""
        proc = subprocess.Popen(shlex.split(cmd),
                              start_new_session=True,
                              env=self.env)
        name = name or f"proc_{proc.pid}"
        self.processes[name] = proc
        return name

    def kill(self, name):
        """Убить процесс по имени"""
        if name in self.processes:
            self.processes[name].kill()
            del self.processes[name]
            return True
        return False

    def ps(self):
        """Список активных процессов"""
        result = {}
        for name, proc in self.processes.items():
            if proc.poll() is None:
                result[name] = proc.pid
            else:
                del self.processes[name]
        return result

    def alias(self, name, cmd):
        """Создать алиас команды"""
        self.aliases[name] = cmd

    def unalias(self, name):
        """Удалить алиас"""
        if name in self.aliases:
            del self.aliases[name]

    def expand_alias(self, cmd):
        """Раскрыть алиасы в команде"""
        parts = shlex.split(cmd)
        if parts[0] in self.aliases:
            return self.aliases[parts[0]] + ' ' + ' '.join(parts[1:])
        return cmd

    def which(self, cmd):
        """Поиск команды в PATH"""
        return shutil.which(cmd, path=self.env.get('PATH'))

    def setenv(self, key, value):
        """Установить переменную окружения"""
        self.env[key] = value

    def getenv(self, key, default=None):
        """Получить переменную окружения"""
        return self.env.get(key, default)

    def cd(self, path):
        """Сменить директорию"""
        try:
            os.chdir(os.path.expanduser(path))
            self.env['PWD'] = os.getcwd()
            return True
        except:
            return False

    def pwd(self):
        """Текущая директория"""
        return os.getcwd()

    def system(self, cmd):
        """Выполнить команду через system()"""
        return os.system(cmd)

    def interactive(self):
        """Запустить интерактивную оболочку"""
        while True:
            try:
                cmd = input(f"{self.pwd()}> ")
                if cmd == "exit":
                    break
                if cmd:
                    cmd = self.expand_alias(cmd)
                    print(self.run(cmd))
            except KeyboardInterrupt:
                print("\nCtrl+C pressed")
            except EOFError:
                break
