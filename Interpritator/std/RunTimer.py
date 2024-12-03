import time
from functools import wraps

class RunTimer:
    def __init__(self, name=None):
        self.name = name
        self.start_time = None

    def __enter__(self):
        self.start_time = time.time()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        end_time = time.time()
        elapsed_time = end_time - self.start_time
        if self.name:
            print(f"{self.name} took {elapsed_time:.6f} seconds")
        else:
            print(f"Code block took {elapsed_time:.6f} seconds")

def timeit(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        start_time = time.time()
        result = func(*args, **kwargs)
        end_time = time.time()
        print(f"{func.__name__} took {end_time - start_time:.6f} seconds")
        return result
    return wrapper

# Примеры использования
if __name__ == "__main__":
    # Использование как контекстного менеджера
    with RunTimer("Test loop"):
        for _ in range(1000000):
            pass

    # Использование как декоратора
    @timeit
    def slow_function():
        time.sleep(1)

    slow_function()
