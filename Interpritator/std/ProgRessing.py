import sys
import time
import threading
from enum import Enum

class Style(Enum):
    BAR = "█"
    BLOCK = "■"
    DOT = "●"
    ARROW = "→"
    WAVE = "∼"
    PULSE = "⋮"

class CircleLoader:
    def __init__(self, message="Loading...", delay=0.1):
        self.message = message
        self.delay = delay
        self.symbols = ['◜', '◠', '◝', '◞', '◡', '◟']
        self.done = False
        self.spinner_thread = None

    def spin(self):
        while not self.done:
            for symbol in self.symbols:
                sys.stdout.write(f'\r{symbol} {self.message}')
                sys.stdout.flush()
                time.sleep(self.delay)

    def _spin(self):
        while not self.done:
            for symbol in self.pattern:
                if self.done:
                    break
                elapsed = time.time() - self._start_time
                print(f'\r{symbol} {self.message} ({elapsed:.1f}s)', end='', flush=True)
                time.sleep(self.speed)

    def start(self):
        self._start_time = time.time()
        self.thread = threading.Thread(target=self._spin)
        self.thread.start()
        return self

    def stop(self, message="Done!"):
        self.done = True
        if self.thread:
            self.thread.join()
        elapsed = time.time() - self._start_time
        print(f'\r✓ {message} ({elapsed:.1f}s)')

class MatrixLoader:
    def __init__(self, message="Loading...", delay=0.1):
        self.message = message
        self.delay = delay
        self.symbols = ['⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷']
        self.done = False
        self.spinner_thread = None

    def _spin(self):
        while not self.done:
            for symbol in self.pattern:
                if self.done:
                    break
                elapsed = time.time() - self._start_time
                print(f'\r{symbol} {self.message} ({elapsed:.1f}s)', end='', flush=True)
                time.sleep(self.speed)

    def start(self):
        self._start_time = time.time()
        self.thread = threading.Thread(target=self._spin)
        self.thread.start()
        return self

    def stop(self, message="Done!"):
        self.done = True
        if self.thread:
            self.thread.join()
        elapsed = time.time() - self._start_time
        print(f'\r✓ {message} ({elapsed:.1f}s)')

class BoxLoader:
    def __init__(self, message="Loading...", delay=0.1):
        self.message = message
        self.delay = delay
        self.symbols = ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█', '▇', '▆', '▅', '▄', '▃', '▁']
        self.done = False
        self.spinner_thread = None

    def _spin(self):
        while not self.done:
            for symbol in self.pattern:
                if self.done:
                    break
                elapsed = time.time() - self._start_time
                print(f'\r{symbol} {self.message} ({elapsed:.1f}s)', end='', flush=True)
                time.sleep(self.speed)

    def start(self):
        self._start_time = time.time()
        self.thread = threading.Thread(target=self._spin)
        self.thread.start()
        return self

    def stop(self, message="Done!"):
        self.done = True
        if self.thread:
            self.thread.join()
        elapsed = time.time() - self._start_time
        print(f'\r✓ {message} ({elapsed:.1f}s)')

class BrainLoader:
    def __init__(self, message="Thinking...", delay=0.1):
        self.message = message
        self.delay = delay
        self.symbols = ['🧠', '⚡', '💭', '✨', '🔮']
        self.done = False
        self.spinner_thread = None

    def _spin(self):
        while not self.done:
            for symbol in self.pattern:
                if self.done:
                    break
                elapsed = time.time() - self._start_time
                print(f'\r{symbol} {self.message} ({elapsed:.1f}s)', end='', flush=True)
                time.sleep(self.speed)

    def start(self):
        self._start_time = time.time()
        self.thread = threading.Thread(target=self._spin)
        self.thread.start()
        return self

    def stop(self, message="Done!"):
        self.done = True
        if self.thread:
            self.thread.join()
        elapsed = time.time() - self._start_time
        print(f'\r✓ {message} ({elapsed:.1f}s)')

class ClockLoader:
    def __init__(self, message="Time processing...", delay=0.1):
        self.message = message
        self.delay = delay
        self.symbols = ['🕐','🕑','🕒','🕓','🕔','🕕','🕖','🕗','🕘','🕙','🕚','🕛']
        self.done = False
        self.spinner_thread = None

    def _spin(self):
        while not self.done:
            for symbol in self.pattern:
                if self.done:
                    break
                elapsed = time.time() - self._start_time
                print(f'\r{symbol} {self.message} ({elapsed:.1f}s)', end='', flush=True)
                time.sleep(self.speed)

    def start(self):
        self._start_time = time.time()
        self.thread = threading.Thread(target=self._spin)
        self.thread.start()
        return self

    def stop(self, message="Done!"):
        self.done = True
        if self.thread:
            self.thread.join()
        elapsed = time.time() - self._start_time
        print(f'\r✓ {message} ({elapsed:.1f}s)')

class WeatherLoader:
    def __init__(self, message="Loading...", delay=0.2):
        self.message = message
        self.delay = delay
        self.symbols = ['🌤','⛅','🌥','☁️','🌧','⛈','🌩','🌨','🌧','🌦','🌥']
        self.done = False
        self.spinner_thread = None

    def _spin(self):
        while not self.done:
            for symbol in self.pattern:
                if self.done:
                    break
                elapsed = time.time() - self._start_time
                print(f'\r{symbol} {self.message} ({elapsed:.1f}s)', end='', flush=True)
                time.sleep(self.speed)

    def start(self):
        self._start_time = time.time()
        self.thread = threading.Thread(target=self._spin)
        self.thread.start()
        return self

    def stop(self, message="Done!"):
        self.done = True
        if self.thread:
            self.thread.join()
        elapsed = time.time() - self._start_time
        print(f'\r✓ {message} ({elapsed:.1f}s)')

class MoonLoader:
    def __init__(self, message="Loading...", delay=0.2):
        self.message = message
        self.delay = delay
        self.symbols = ['🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘']
        self.done = False
        self.spinner_thread = None

    def _spin(self):
        while not self.done:
            for symbol in self.pattern:
                if self.done:
                    break
                elapsed = time.time() - self._start_time
                print(f'\r{symbol} {self.message} ({elapsed:.1f}s)', end='', flush=True)
                time.sleep(self.speed)

    def start(self):
        self._start_time = time.time()
        self.thread = threading.Thread(target=self._spin)
        self.thread.start()
        return self

    def stop(self, message="Done!"):
        self.done = True
        if self.thread:
            self.thread.join()
        elapsed = time.time() - self._start_time
        print(f'\r✓ {message} ({elapsed:.1f}s)')

class DNALoader:
    def __init__(self, message="Processing...", delay=0.1):
        self.message = message
        self.delay = delay
        self.symbols = ['⟳', '⟲', '↺', '↻', '⥀', '⥁']
        self.done = False
        self.spinner_thread = None

    def _spin(self):
        while not self.done:
            for symbol in self.pattern:
                if self.done:
                    break
                elapsed = time.time() - self._start_time
                print(f'\r{symbol} {self.message} ({elapsed:.1f}s)', end='', flush=True)
                time.sleep(self.speed)

    def start(self):
        self._start_time = time.time()
        self.thread = threading.Thread(target=self._spin)
        self.thread.start()
        return self

    def stop(self, message="Done!"):
        self.done = True
        if self.thread:
            self.thread.join()
        elapsed = time.time() - self._start_time
        print(f'\r✓ {message} ({elapsed:.1f}s)')

class WaveLoader:
    def __init__(self, message="Loading...", delay=0.1):
        self.message = message
        self.delay = delay
        self.symbols = ['≋', '≈', '≋', '≈', '≋']
        self.done = False
        self.spinner_thread = None

    def _spin(self):
        while not self.done:
            for symbol in self.pattern:
                if self.done:
                    break
                elapsed = time.time() - self._start_time
                print(f'\r{symbol} {self.message} ({elapsed:.1f}s)', end='', flush=True)
                time.sleep(self.speed)

    def start(self):
        self._start_time = time.time()
        self.thread = threading.Thread(target=self._spin)
        self.thread.start()
        return self

    def stop(self, message="Done!"):
        self.done = True
        if self.thread:
            self.thread.join()
        elapsed = time.time() - self._start_time
        print(f'\r✓ {message} ({elapsed:.1f}s)')

class BlockLoader:
    def __init__(self, message="Loading...", delay=0.1):
        self.message = message
        self.delay = delay
        self.symbols = [
            '▰▱▱▱▱▱▱', '▰▰▱▱▱▱▱', '▰▰▰▱▱▱▱',
            '▰▰▰▰▱▱▱', '▰▰▰▰▰▱▱', '▰▰▰▰▰▰▱',
            '▰▰▰▰▰▰▰'
        ]
        self.done = False
        self.spinner_thread = None

    def _spin(self):
        while not self.done:
            for symbol in self.pattern:
                if self.done:
                    break
                elapsed = time.time() - self._start_time
                print(f'\r{symbol} {self.message} ({elapsed:.1f}s)', end='', flush=True)
                time.sleep(self.speed)

    def start(self):
        self._start_time = time.time()
        self.thread = threading.Thread(target=self._spin)
        self.thread.start()
        return self

    def stop(self, message="Done!"):
        self.done = True
        if self.thread:
            self.thread.join()
        elapsed = time.time() - self._start_time
        print(f'\r✓ {message} ({elapsed:.1f}s)')


class ProgressBar:
    def __init__(self, total, style=Style.BAR, width=50, title=""):
        self.total = total
        self.width = width
        self.style = style.value
        self.title = title
        self.current = 0
        self._speed = 0
        self._start_time = time.time()

    def update(self, amount=1):
        self.current += amount
        self._speed = self.current / (time.time() - self._start_time)
        self._draw()

    def _draw(self):
        percent = self.current / self.total
        filled = int(self.width * percent)
        bar = self.style * filled + '-' * (self.width - filled)
        eta = (self.total - self.current) / self._speed if self._speed > 0 else 0
        
        print(f'\r{self.title} |{bar}| {percent:.1%} [{self._speed:.1f} it/s] ETA: {eta:.1f}s', 
              end='', flush=True)
        
        if self.current >= self.total:
            print()

class Spinner:
    PATTERNS = {
        'dots': ['⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏'],
        'pulse': ['█■■■','■█■■','■■█■','■■■█'],
        'line': ['|', '/', '-', '\\'],
        'bounce': ['⠁','⠂','⠄','⠂'],
        'wave': ['⎺','⎻','⎼','⎽','⎼','⎻']
    }

    def __init__(self, message="", pattern='dots', speed=0.1):
        self.message = message
        self.pattern = self.PATTERNS[pattern]
        self.speed = speed
        self.done = False
        self.thread = None
        self._start_time = None

    def _spin(self):
        while not self.done:
            for symbol in self.pattern:
                if self.done:
                    break
                elapsed = time.time() - self._start_time
                print(f'\r{symbol} {self.message} ({elapsed:.1f}s)', end='', flush=True)
                time.sleep(self.speed)

    def start(self):
        self._start_time = time.time()
        self.thread = threading.Thread(target=self._spin)
        self.thread.start()
        return self

    def stop(self, message="Done!"):
        self.done = True
        if self.thread:
            self.thread.join()
        elapsed = time.time() - self._start_time
        print(f'\r✓ {message} ({elapsed:.1f}s)')

class LoadingBar:
    def __init__(self, steps, title="Loading"):
        self.steps = steps
        self.current = 0
        self.title = title
        self.bar = ProgressBar(steps, title=title)
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type is None:
            self.bar.update(self.steps - self.current)
    
    def step(self):
        self.current += 1
        self.bar.update()

def loading(message="Processing", pattern='dots'):
    """Декоратор для отображения спиннера во время выполнения функции"""
    def decorator(func):
        def wrapper(*args, **kwargs):
            spinner = Spinner(message, pattern).start()
            try:
                result = func(*args, **kwargs)
                spinner.stop()
                return result
            except Exception as e:
                spinner.stop("Failed!")
                raise e
        return wrapper
    return decorator

