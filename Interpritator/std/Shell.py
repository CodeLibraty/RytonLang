import subprocess
import shlex
import signal
import psutil
import shutil
import time
import sys
import os


class InteractiveSession:
    def __init__(self, command):
        self.process = subprocess.Popen(
            command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True,
            text=True
        )
        
    def execute(self, command):
        self.process.stdin.write(f"{command}\n")
        self.process.stdin.flush()
        return self.process.stdout.readline()
        
    def close(self):
        self.process.terminate()

class Shell:
    def __init__(self):
        self.processes = {}
        self.aliases = {}
        self.env = os.environ.copy()

    def rt_run(self, cmd, shell=False, env=None, cwd=None):
        """Запуск команды с выводом в реальном времени"""
        try:
            if shell:
                process = subprocess.Popen(
                    cmd,
                    shell=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                    universal_newlines=True,
                    env=os.environ.copy(),
                    cwd=cwd
                )
            else:
                args = shlex.split(cmd)
                process = subprocess.Popen(
                    args,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                    universal_newlines=True,
                    env=os.environ.copy(),
                    cwd=cwd
                )

            while True:
                line = process.stdout.readline()
                if line:
                    print(line.rstrip(), flush=True)
                if process.poll() is not None:
                    break
            
            return None

        except Exception as e:
            error_msg = f"Error: {str(e)}"
            print(error_msg, flush=True)
            return error_msg


    def run(self, cmd, capture=True, shell=False, env=None, cwd=None):
        """Простой запуск команды с возвратом результата"""
        try:
            if shell:
                result = subprocess.run(cmd, shell=True, capture_output=capture, 
                                     text=True, env=os.environ.copy(), cwd=cwd)
            else:
                args = shlex.split(cmd)
                result = subprocess.run(args, capture_output=capture,
                                     text=True, env=os.environ.copy(), cwd=cwd)
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
                                   env=os.environ.copy())
            else:
                p = subprocess.Popen(shlex.split(cmd),
                                   stdin=procs[-1].stdout,
                                   stdout=subprocess.PIPE, 
                                   env=os.environ.copy())
            procs.append(p)
        
        return procs[-1].communicate()[0].decode()

    def bg(self, cmd, name=None):
        """Запуск в фоне с именем процесса"""
        proc = subprocess.Popen(shlex.split(cmd),
                              start_new_session=True,
                              env=os.environ.copy())
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
        return shutil.which(cmd, path=env.get('PATH'))

    def setenv(self, key, value):
        """Установить переменную окружения"""
        env[key] = value

    def getenv(self, key, default=None):
        """Получить переменную окружения"""
        return env.get(key, default)

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

    def create_interactive(self, command):
        """Создает интерактивную сессию с процессом"""
        return InteractiveSession(command)