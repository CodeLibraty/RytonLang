from functools import lru_cache

class MetaTable:
    """Модуль мета таблиц вдохновлёный Lua"""
    def __init__(self, data=None):
        self._data = data or {}
        self._metatable = None

    @lru_cache(maxsize=128)
    def __getitem__(self, key):
        if key in self._data:
            return self._data[key]
        elif self._metatable and '__index' in self._metatable:
            return self._metatable['__index'](self, key)
        raise KeyError(key)

    @lru_cache(maxsize=128)
    def __setitem__(self, key, value):
        if self._metatable and '__newindex' in self._metatable:
            self._metatable['__newindex'](self, key, value)
        else:
            self._data[key] = value

    @lru_cache(maxsize=128)
    def __call__(self, *args, **kwargs):
        if self._metatable and '__call' in self._metatable:
            return self._metatable['__call'](self, *args, **kwargs)
        raise TypeError("'MetaTable' object is not callable")

    def __str__(self):
        if self._metatable and '__tostring' in self._metatable:
            return self._metatable['__tostring'](self)
        return str(self._data)

    def __repr__(self):
        return f"MetaTable({self._data})"

    def __len__(self):
        if self._metatable and '__len' in self._metatable:
            return self._metatable['__len'](self)
        return len(self._data)

    def __iter__(self):
        if self._metatable and '__iter' in self._metatable:
            return self._metatable['__iter'](self)
        return iter(self._data)

    @lru_cache(maxsize=128)
    def __add__(self, other):
        if self._metatable and '__add' in self._metatable:
            return self._metatable['__add'](self, other)
        raise TypeError(f"unsupported operand type(s) for +: 'MetaTable' and '{type(other).__name__}'")

    @lru_cache(maxsize=128)
    def __sub__(self, other):
        if self._metatable and '__sub' in self._metatable:
            return self._metatable['__sub'](self, other)
        raise TypeError(f"unsupported operand type(s) for -: 'MetaTable' and '{type(other).__name__}'")

    @lru_cache(maxsize=128)
    def set_metatable(self, metatable):
        if not isinstance(metatable, dict):
            raise TypeError("Metatable must be a dictionary")
        self._metatable = metatable

    @lru_cache(maxsize=128)
    def get_metatable(self):
        return self._metatable

def metatable(cls):
    """Декоратор для сздания метатаблицы из класса"""
    mt = {}
    for name, method in cls.__dict__.items():
        if not name.startswith('__'):
            mt[f'__{name}'] = method
    return mt

def table(*args, **kwargs):
    """Функция для создания MetaTable с начальными данными"""
    if len(args) == 1 and isinstance(args[0], dict):
        return MetaTable(args[0])
    return MetaTable(kwargs)
