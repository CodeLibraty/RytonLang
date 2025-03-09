import time
import csv
import rich
import threading
from rich.table import Table as RichTable
from rich.console import Console
from functools import lru_cache
from PackageSystem import PackageSystem
from ErrorHandler import RytonTypeError
from DataTypes import *
from typing import *
from functools import partial, wraps
import threading
import inspect
import psutil
import re

# MODIFICATORS
def readonly(cls):
    original_setattr = cls.__setattr__
    
    def __setattr__(self, name, value):
        if hasattr(self, name):
            raise RytonError(f"attribute readonly: {name}")
        original_setattr(self, name, value)
        
    cls.__setattr__ = __setattr__
    return cls

def elerr(func):
    def wrapper(*args, **kwargs):
        try:
            result = func(*args, **kwargs)
            return result
        except Exception as e:
            print(f"Error in function {func.__name__}: {type(e).__name__}: {str(e)}")
    return wrapper

def thread(code):

    thread = threading.Thread(target=code, args=args, kwargs=kwargs)
    thread.start()
    return thread

def event(item1, item2, code):
    while True:
        if item1 == item2:
            exec(code)
            break
        else:
            time.sleep(0.05)

def start_event(item1, item2, code):
    thread = threading.Thread(target=event(item1, item2, code))
    thread.start()

def hyperfunc(*bases):
    def decorator(cls):
        # Собираем все базовые классы и функции
        class_bases = tuple(base for base in bases if isinstance(base, type))
        func_bases = tuple(base for base in bases if callable(base) and not isinstance(base, type))
        
        # Создаём новый класс с множественным наследованием
        class HyperFunction(*class_bases):
            def __init__(self, *args, **kwargs):
                super().__init__(*args, **kwargs)
                self._func_bases = func_bases
            
            def __call__(self, *args, **kwargs):
                # Логика вызова как функции
                result = self.process(*args, **kwargs)
                return result
                
            def process(self, *args, **kwargs):
                # Здесь можно использовать функции из func_bases
                return cls.process(self, *args, **kwargs)
                
        return HyperFunction
    try:
        return decorator
    except Exception as e:
        print(e)

def typing(expected_type):
    def decorator(func):
        def wrapper(*args, **kwargs):
            result = func(*args, **kwargs)
            type_map = {
                "None": None,
                "String": str,
                "Int": int,
                "Float": float,
                "Bool": bool,
                "List": list,
                "Dict": dict,
                "Set": set,
                "Tuple": tuple,
                "Money": Money,
                "Time": Time,
                "Range": Range,
                "Version": Version,
                "Color": Color,
                "URL": URL,
                "Path": Path,
                "BigInt": BigInt,
                "Decimal": Decimal,
                "Vector": Vector,
                "Matrix": Matrix,
                "Email": Email,
                "PhoneNumber": PhoneNumber,
                "UUID": UUID,
                "IPAddress": IPAddress,
                "Temperature": Temperature,
                "GeoPoint": GeoPoint
            }
            
            if not isinstance(result, type_map[expected_type]):
                raise TypeError(f"Function {func.__name__} must return {expected_type}, got {type(result)}")
            return result
        return wrapper
    return decorator

def limit_calls(max_calls):
    def decorator(func):
        func._call_count = 0
        def wrapper(*args, **kwargs):
            if func._call_count >= max_calls:
                raise RuntimeError(f"Function {func.__name__} exceeded maximum calls of {max_calls}")
            func._call_count += 1
            return func(*args, **kwargs)
        return wrapper
    return decorator

def timeout(seconds):
    def decorator(func):
        def wrapper(*args, **kwargs):
            import signal
            def handler(signum, frame):
                raise TimeoutError(f"Function {func.__name__} timed out after {seconds} seconds")
            signal.signal(signal.SIGALRM, handler)
            signal.alarm(seconds)
            try:
                result = func(*args, **kwargs)
            finally:
                signal.alarm(0)
            return result
        return wrapper
    return decorator

def retry(attempts=3, delay=1):
    def decorator(func):
        def wrapper(*args, **kwargs):
            for attempt in range(attempts):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    if attempt == attempts - 1:
                        raise e
                    time.sleep(delay)
        return wrapper
    return decorator

def validate_params(func):
    def wrapper(*args, **kwargs):
        sig = inspect.signature(func)
        bound = sig.bind(*args, **kwargs)
        bound.apply_defaults()
        
        type_validators = {
            String: str,
            Int: int,
            Bool: bool,
            Float: float,
            List: list,
            Dict: dict,
            Set: set,
            Tuple: tuple,
            Money: Money,
            Time: Time,
            Range: Range,
            Version: Version,
            Color: Color,
            URL: URL,
            Path: Path,
            BigInt: BigInt,
            Decimal: Decimal,
            Vector: Vector,
            Matrix: Matrix,
            Email: Email,
            PhoneNumber: PhoneNumber,
            UUID: UUID,
            IPAddress: IPAddress,
            Temperature: Temperature,
            GeoPoint: GeoPoint
        }

        for name, value in bound.arguments.items():
            expected_type = func.__annotations__.get(name)
            if expected_type in type_validators:
                validator = type_validators[expected_type]
                if not isinstance(value, validator):
                    raise TypeError(f"Argument '{name}' must be {expected_type.__name__}, got {type(value).__name__}")
                
                # Специальные проверки для некоторых типов
                if expected_type == Email:
                    if '@' not in value.address:
                        raise ValueError(f"Invalid email format for argument '{name}'")
                elif expected_type == IPAddress:
                    if len(value.octets) != 4:
                        raise ValueError(f"Invalid IP address format for argument '{name}'")
                elif expected_type == Money:
                    if value.amount < 0:
                        raise ValueError(f"Money amount cannot be negative for argument '{name}'")
                elif expected_type == Temperature:
                    if value.celsius < -273.15:
                        raise ValueError(f"Temperature cannot be below absolute zero for argument '{name}'")
                        
        return func(*args, **kwargs)
    return wrapper


def logged(func: Callable) -> Callable:
    def wrapper(*args, **kwargs):
        print(f"[LOG] Calling {func.__name__}")
        print(f"[LOG] Arguments: {args}, {kwargs}")
        try:
            result = func(*args, **kwargs)
            print(f"[LOG] {func.__name__} returned: {result}")
            return result
        except Exception as e:
            print(f"[LOG] {func.__name__} failed: {str(e)}")
            raise
    return wrapper

def profile(func: Callable) -> Callable:
    def wrapper(*args, **kwargs):
        start_time = time.time()
        start_memory = psutil.Process().memory_info().rss
        result = func(*args, **kwargs)
        end_time = time.time()
        end_memory = psutil.Process().memory_info().rss
        print(f"[PROFILE] {func.__name__}")
        print(f"[PROFILE] Execution time: {end_time - start_time:.4f} seconds")
        print(f"[PROFILE] Memory used: {(end_memory - start_memory) / 1024 / 1024:.2f} MB")
        return result
    return wrapper

def autothis(cls):
    # Получаем все методы класса
    methods = [name for name, value in cls.__dict__.items() 
              if callable(value) and not name.startswith('__')]
              
    # Модифицируем методы
    for method_name in methods:
        original = getattr(cls, method_name)
        
        # Создаем обертку с правильной передачей self
        def make_wrapper(method):
            def wrapper(self, *args, **kwargs):
                # Делаем self доступным в замыкании метода
                method.__globals__['self'] = self
                result = method(*args, **kwargs)
                # Убираем self из глобальных после вызова
                del method.__globals__['self']
                return result
            return wrapper
            
        # Заменяем метод
        setattr(cls, method_name, make_wrapper(original))
        
    return cls

def inherit(*bases):
    def decorator(cls):
        class Enhanced:
            def __new__(cls, *args, **kwargs):
                # Создаем инстанс
                instance = super().__new__(cls)
                
                # Инициализируем все базовые классы
                for base in bases:
                    base.__init__(instance)
                    
                # Копируем все методы из базовых классов
                for base in bases:
                    for name, method in base.__dict__.items():
                        if not name.startswith('__'):
                            setattr(instance, name, method.__get__(instance, cls))
                
                return instance
                
            def __init__(self, *args, **kwargs):
                # Вызываем инициализацию текущего класса
                if hasattr(cls, '__init__'):
                    cls.__init__(self, *args, **kwargs)
                    
        # Копируем методы декорируемого класса
        for name, method in cls.__dict__.items():
            if not name.startswith('__'):
                setattr(Enhanced, name, method)
                
        return Enhanced
    return decorator

def metrics(func: Callable) -> Callable:
    def wrapper(*args, **kwargs):
        start = time.time()
        start_mem = psutil.Process().memory_info().rss
        result = func(*args, **kwargs)
        end = time.time()
        end_mem = psutil.Process().memory_info().rss
        
        print(f"[METRICS] {func.__name__}")
        print(f"[METRICS] Time: {end - start:.4f}s")
        print(f"[METRICS] Memory: {(end_mem - start_mem) / 1024 / 1024:.2f}MB")
        print(f"[METRICS] CPU: {psutil.cpu_percent()}%")
        return result
    return wrapper

def cached(maxsize=128):
    def decorator(func):
        return lru_cache(maxsize=maxsize)(func)
    return decorator

def connect_with_retry(max_attempts=5):
    import rpyc
    import time
    
    for attempt in range(max_attempts):
        try:
            return rpyc.connect("localhost", 18861)
        except ConnectionRefusedError:
            if attempt < max_attempts - 1:
                time.sleep(0.5)  # Ждем пока сервер запустится
            else:
                raise

# Используем в декораторе
def qui(cls):
    conn = connect_with_retry()
    
    def wrapper(*args, **kwargs):
        instance = cls(*args, **kwargs)
        instance.qui = conn.root
        return instance
        
    return wrapper

# ClASSES
class switch:
    def __init__(self, value, context=None):
        self.value = value
        self.cases = []
        self.default = None
        self.context = context
        self.matched = False
        
    def case(self, pattern, action):
        if not self.matched and self.value.startswith(pattern):
            self.matched = True
            if self.context:
                action(self.context)
        return self # Всегда возвращаем self
        

    def when(self, condition, action):
        if not self.matched and condition:
            self.matched = True
            return action(self.value)
        return self
        
    def else_(self, action):
        if not self.matched:
            if self.context:
                action(self.context, self.value)
        return self # Всегда возвращаем self

class struct:
    def __init__(self, name):
        self.name = name
        self._fields = {}
        self._instance = None
        
    def field(self, name, type_cls):
        self._fields[name] = type_cls
        return self
        
    def __call__(self, **values):
        for name, value in values.items():
            setattr(self, name, self._fields[name](value))
        return self
        
    def String(self, min_len=None, max_len=None, pattern=None):
        def validate(value):
            if not isinstance(value, str): 
                raise TypeError(f"Must be String")
            if min_len and len(value) < min_len:
                raise ValueError(f"Min length: {min_len}")
            if max_len and len(value) > max_len:
                raise ValueError(f"Max length: {max_len}")
            if pattern and not re.match(pattern, value):
                raise ValueError(f"Must match pattern: {pattern}")
            return value
        return validate
        
    def Int(self, min_val=None, max_val=None, range=None):
        def validate(value):
            if not isinstance(value, int):
                raise TypeError("Must be Int")
            if min_val and value < min_val:
                raise ValueError(f"Min value: {min_val}")
            if max_val and value > max_val:
                raise ValueError(f"Max value: {max_val}")
            if range and value not in range:
                raise ValueError(f"Must be in range: {range}")
            return value
        return validate

    def Email(self):
        return lambda x: Email(x)
        
    def URL(self):
        return lambda x: URL(x)
        
    def Money(self, currency="USD"):
        return lambda x: Money(x, currency)
        
    def Time(self):
        return lambda x: Time(*x)
        
    def Color(self):
        return lambda x: Color(*x)
        
    def Version(self):
        return lambda x: Version(x)

    def validate(self):
        if not self._instance:
            raise ValueError("No data to validate")
        for field, validator in self.fields.items():
            value = getattr(self._instance, field)
            setattr(self._instance, field, validator(value))
        return True

    def to_json(self):
        return json.dumps(self._instance.__dict__)
        
    def from_json(self, json_str):
        data = json.loads(json_str)
        return self(**data)
        
    def copy(self):
        return deepcopy(self._instance)
        
    def merge(self, other):
        for field, value in other.__dict__.items():
            setattr(self._instance, field, value)
        return self

class Contract:
    def __init__(self):
        self.pre_conditions = []
        self.post_conditions = []
        self.invariants = []

    @staticmethod
    def pre_condition(condition):
        def decorator(func):
            def wrapper(*args, **kwargs):
                if not condition(*args, **kwargs):
                    raise ContractError("Pre-condition failed")
                return func(*args, **kwargs)
            return wrapper
        return decorator

    @staticmethod
    def post_condition(condition):
        def decorator(func):
            def wrapper(*args, **kwargs):
                result = func(*args, **kwargs)
                if not condition(result):
                    raise ContractError("Post-condition failed")
                return result
            return wrapper
        return decorator

    @staticmethod
    def invariant(condition):
        def decorator(func):
            def wrapper(*args, **kwargs):
                if not condition():
                    raise ContractError("Invariant failed")
                result = func(*args, **kwargs)
                if not condition():
                    raise ContractError("Invariant failed after execution")
                return result
            return wrapper
        return decorator

class Reactive:
    def __init__(self):
        self.subscribers = {}
        self.state = {}
        
    def observe(self, key):
        def decorator(func):
            if key not in self.subscribers:
                self.subscribers[key] = []
            self.subscribers[key].append(func)
            return func
        return decorator
        
    def set_state(self, key, value):
        self.state[key] = value
        if key in self.subscribers:
            for subscriber in self.subscribers[key]:
                subscriber(value)
                
    def get_state(self, key):
        return self.state.get(key)

    def stream(self):
        return ReactiveStream(self)

class ReactiveStream:
    def __init__(self, reactive):
        self.reactive = reactive
        self.operations = []
        
    def filter(self, condition):
        self.operations.append(('filter', condition))
        return self
        
    def map(self, transform):
        self.operations.append(('map', transform))
        return self
        
    def subscribe(self, callback):
        def process_value(value):
            for op_type, op in self.operations:
                if op_type == 'filter':
                    if not op(value):
                        return
                elif op_type == 'map':
                    value = op(value)
            callback(value)
        return process_value

class Table:
    def __init__(self):
        self.rows = []
        self.headers = []
        self.styles = {}
        self.console = Console()

    def create(self, headers: List[str]) -> 'Table':
        self.headers = headers
        return self

    def add_row(self, row: List[Any]) -> None:
        self.rows.append(row)

    def add_rows(self, rows: List[List[Any]]) -> None:
        self.rows.extend(rows)

    def style(self, options: Dict[str, str]) -> None:
        self.styles = {
            'border': options.get('border', '│'),
            'header_color': options.get('header_color', 'blue'),
            'row_color': options.get('row_color', 'white'),
            'alignment': options.get('alignment', 'left')
        }

    def from_csv(self, filepath: str) -> None:
        with open(filepath, 'r', encoding='utf-8') as file:
            reader = csv.reader(file)
            self.headers = next(reader)
            self.rows = list(reader)

    def to_csv(self, filepath: str) -> None:
        with open(filepath, 'w', encoding='utf-8', newline='') as file:
            writer = csv.writer(file)
            writer.writerow(self.headers)
            writer.writerows(self.rows)

    def filter(self, column: str, condition: Callable) -> None:
        col_index = self.headers.index(column)
        self.rows = [row for row in self.rows if condition(row[col_index])]

    def sort(self, column: str, reverse: bool = False) -> None:
        col_index = self.headers.index(column)
        self.rows.sort(key=lambda x: x[col_index], reverse=reverse)

    def get_column(self, column: str) -> List[Any]:
        col_index = self.headers.index(column)
        return [row[col_index] for row in self.rows]

    def update_column(self, column: str, values: List[Any]) -> None:
        col_index = self.headers.index(column)
        for i, value in enumerate(values):
            self.rows[i][col_index] = value

    def add_column(self, name: str, values: List[Any]) -> None:
        self.headers.append(name)
        for i, row in enumerate(self.rows):
            row.append(values[i])

    def remove_column(self, column: str) -> None:
        col_index = self.headers.index(column)
        self.headers.pop(col_index)
        for row in self.rows:
            row.pop(col_index)

    def aggregate(self, column: str, func: Callable) -> Any:
        return func(self.get_column(column))

    def display(self) -> None:
        table = RichTable(show_header=True)
        
        for header in self.headers:
            table.add_column(header, style=self.styles.get('header_color'))
        
        for row in self.rows:
            table.add_row(*[str(cell) for cell in row], style=self.styles.get('row_color'))
        
        self.console.print(table)

    def to_html(self, filepath: str) -> None:
        html = ["<table border='1'>", "<tr>"]
        
        html.extend(f"<th>{header}</th>" for header in self.headers)
        html.append("</tr>")
        
        for row in self.rows:
            html.append("<tr>")
            html.extend(f"<td>{cell}</td>" for cell in row)
            html.append("</tr>")
        
        html.append("</table>")
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write('\n'.join(html))

    def merge(self, other_table: 'Table', on: str) -> None:
        self_col_index = self.headers.index(on)
        other_col_index = other_table.headers.index(on)
        
        new_headers = self.headers + [h for h in other_table.headers if h != on]
        new_rows = []
        
        for self_row in self.rows:
            key = self_row[self_col_index]
            for other_row in other_table.rows:
                if other_row[other_col_index] == key:
                    new_row = self_row + [cell for i, cell in enumerate(other_row) if other_table.headers[i] != on]
                    new_rows.append(new_row)
        
        self.headers = new_headers
        self.rows = new_rows

    def stats(self, column: str) -> Dict[str, Any]:
        values = [float(x) for x in self.get_column(column) if str(x).replace('.','').isdigit()]
        if not values:
            return {'mean': 0, 'min': 0, 'max': 0, 'count': 0}
        return {
            'mean': sum(values) / len(values),
            'min': min(values),
            'max': max(values),
            'count': len(values)
        }

class Parallel:
    def parallel(self, *funcs):
        threads = []
        results = {}
        
        def wrapper(func_name, func):
            results[func_name] = func()
        
        for func in funcs:
            thread = threading.Thread(target=wrapper, args=(func.__name__, func))
            threads.append(thread)
            thread.start()
            
        for thread in threads:
            thread.join()
            
        return results

class Memory:
    def allocate(name, value):
        sharpy.memory_manager.allocate(name, value)

    def free(name):
        sharpy.memory_manager.free(name)

    def get_obj(name):
        return sharpy.memory_manager.get(name)

    def mem_usage():
        return sharpy.memory_manager.memory_usage()

    def obj_count():
        return sharpy.memory_manager.object_count()

    def gc_collect():
        return gc.collect()

    def set_gc_threshold(threshold0, threshold1=None, threshold2=None):
        if threshold1 is None and threshold2 is None:
            gc.set_threshold(threshold0)
        elif threshold2 is None:
            gc.set_threshold(threshold0, threshold1)
        else:
            gc.set_threshold(threshold0, threshold1, threshold2)

    def get_gc_threshold():
        return gc.get_threshold()

    def enable_gc():
        gc.enable()

    def disable_gc():
        gc.disable()

    def is_gc_enabled():
        return gc.isenabled()