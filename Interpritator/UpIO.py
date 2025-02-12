from typing import Any, Union, Callable
import time
import sys

@staticmethod
def sep(*values: Any, sep: str = " → ", end: str = "\n") -> None:
    """Расширенный вывод с кастомным разделителем"""
    builtins.print(*values, sep=sep, end=end)
    
@staticmethod
def ask(prompt: str, validator: Callable = None) -> str:
    """Ввод с валидацией"""
    while True:
        value = builtins.input(prompt)
        if validator is None or validator(value):
            return value
        
@staticmethod
def write_stream(*values: Any, stream: str = "stdout", flush: bool = True) -> None:
    """Прямая запись в потоки вывода"""
    stream_obj = getattr(sys, stream)
    for value in values:
        stream_obj.write(str(value))
    if flush:
        stream_obj.flush()
        
@staticmethod
def read_stream(size: int = -1, stream: str = "stdin") -> str:
    """Прямое чтение из потоков ввода"""
    return getattr(sys, stream).read(size)

@staticmethod
def write_bytes(data: bytes, stream: str = "stdout") -> None:
    """Запись байтов напрямую в поток"""
    getattr(sys, stream).buffer.write(data)
    
@staticmethod
def read_bytes(size: int = -1, stream: str = "stdin") -> bytes:
    """Чтение байтов напрямую из потока"""
    return getattr(sys, stream).buffer.read(size)
    
@staticmethod
def echo_timed(*values: Any, interval: float = 0.05) -> None:
    """Вывод с задержкой между символами"""
    for value in values:
        for char in str(value):
            builtins.print(char, end='', flush=True)
            time.sleep(interval)
        builtins.print(end=' ')
    builtins.print()
    
@staticmethod
def read_until(terminator: str = "", stream: str = "stdin") -> str:
    """Чтение до определенного символа"""
    result = []
    while True:
        char = getattr(sys, stream).read(1)
        if not char or char == terminator:
            break
        result.append(char)
    return ''.join(result)
    
@staticmethod
def echo(value: Any, count: int = 1, sep: str = "") -> None:
    """Повторяющийся вывод"""
    builtins.print(*([value] * count), sep=sep)

