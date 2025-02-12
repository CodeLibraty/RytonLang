import sys
import threading
import select
import time
import os

class KeyBindings:
    def __init__(self):
        self.bindings = {}
        self.active = True
        
    def bind(self, key, callback):
        self.bindings[key] = callback
        
    def _listener(self):
        # Отключаем буферизацию
        os.system('stty -icanon')
        
        while self.active:
            if sys.stdin in select.select([sys.stdin], [], [], 0)[0]:
                char = sys.stdin.read(1)
                if char in self.bindings:
                    self.bindings[char]()
                    sys.stdout.flush()  # Принудительный вывод
                    
    def start(self):
        thread = threading.Thread(target=self._listener)
        thread.daemon = True
        thread.start()

keys = KeyBindings()

def on_key(key):
    def decorator(func):
        keys.bind(key, func)
        return func
    return decorator
