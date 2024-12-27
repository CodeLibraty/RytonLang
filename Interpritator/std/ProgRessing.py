import sys
import time
import threading

class ProgressBar:
    def __init__(self, total, prefix='', suffix='', decimals=1, length=50, fill='█', print_end="\r"):
        self.total = total
        self.prefix = prefix
        self.suffix = suffix
        self.decimals = decimals
        self.length = length
        self.fill = fill
        self.print_end = print_end
        self.iteration = 0

    def print(self, iteration):
        self.iteration = iteration
        percent = ("{0:." + str(self.decimals) + "f}").format(100 * (iteration / float(self.total)))
        filled_length = int(self.length * iteration // self.total)
        bar = self.fill * filled_length + '-' * (self.length - filled_length)
        print(f'\r{self.prefix} |{bar}| {percent}% {self.suffix}', end=self.print_end)
        if iteration == self.total:
            print()

    def increment(self):
        self.print(self.iteration + 1)


class Line1:
    def __init__(self, message="Loading...", delay=0.2):
        self.message = message
        self.delay = delay
        self.symbols = ['██   ', '███  ', '████ ', '█████', '████ ', '███  ', '██   ', '█    ']
        self.done = False
        self.spinner_thread = None

    def spin(self):
        while not self.done:
            for symbol in self.symbols:
                sys.stdout.write(f'{symbol} \r{self.message}')
                sys.stdout.flush()
                time.sleep(self.delay)

    def start(self):
        self.spinner_thread = threading.Thread(target=self.spin)
        self.spinner_thread.start()

    def stop(self):
        self.done = True
        if self.spinner_thread:
            self.spinner_thread.join()
        sys.stdout.write('\r' + ' ' * (len(self.message) + 2) + '\r')
        sys.stdout.flush()

class Line2:
    def __init__(self, message="Loading...", delay=0.2):
        self.message = message
        self.delay = delay
        self.symbols = ['[--=--]', '[---=-]', '[----=]', '[---=-]', 
                        '[--=--]', '[-=---]', '[=----]', '[-=---]']
        self.done = False
        self.spinner_thread = None

    def spin(self):
        while not self.done:
            for symbol in self.symbols:
                sys.stdout.write(f'\r{symbol} {self.message}')
                sys.stdout.flush()
                time.sleep(self.delay)

    def start(self):
        self.spinner_thread = threading.Thread(target=self.spin)
        self.spinner_thread.start()

    def stop(self):
        self.done = True
        if self.spinner_thread:
            self.spinner_thread.join()
        sys.stdout.write('\r' + ' ' * (len(self.message) + 2) + '\r')
        sys.stdout.flush()

class Line3:
    def __init__(self, message="Loading...", delay=0.2):
        self.message = message
        self.delay = delay
        self.symbols = ['█████', '██ ██', '█   █', '     ', '  █  ', ' ███ ']
        self.done = False
        self.spinner_thread = None

    def spin(self):
        while not self.done:
            for symbol in self.symbols:
                sys.stdout.write(f'\r{symbol} {self.message}')
                sys.stdout.flush()
                time.sleep(self.delay)

    def start(self):
        self.spinner_thread = threading.Thread(target=self.spin)
        self.spinner_thread.start()

    def stop(self):
        self.done = True
        if self.spinner_thread:
            self.spinner_thread.join()
        sys.stdout.write('\r' + ' ' * (len(self.message) + 2) + '\r')
        sys.stdout.flush()

class Spinner:
    def __init__(self, message="Loading...", delay=0.1):
        self.message = message
        self.delay = delay
        self.symbols = ['|', '/', '-', '\\']
        self.done = False
        self.spinner_thread = None

    def spin(self):
        while not self.done:
            for symbol in self.symbols:
                sys.stdout.write(f'\r{self.message} {symbol}')
                sys.stdout.flush()
                time.sleep(self.delay)

    def start(self):
        self.spinner_thread = threading.Thread(target=self.spin)
        self.spinner_thread.start()

    def stop(self):
        self.done = True
        if self.spinner_thread:
            self.spinner_thread.join()
        sys.stdout.write('\r' + ' ' * (len(self.message) + 2) + '\r')
        sys.stdout.flush()


class Spinner2:
    def __init__(self, message="Loading...", delay=0.1):
        self.message = message
        self.delay = delay
        self.symbols = ['×', '+']
        self.done = False
        self.spinner_thread = None

    def spin(self):
        while not self.done:
            for symbol in self.symbols:
                sys.stdout.write(f'\r{self.message} {symbol}')
                sys.stdout.flush()
                time.sleep(self.delay)

    def start(self):
        self.spinner_thread = threading.Thread(target=self.spin)
        self.spinner_thread.start()

    def stop(self):
        self.done = True
        if self.spinner_thread:
            self.spinner_thread.join()
        sys.stdout.write('\r' + ' ' * (len(self.message) + 2) + '\r')
        sys.stdout.flush()
