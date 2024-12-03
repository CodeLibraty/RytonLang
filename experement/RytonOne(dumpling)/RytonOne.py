import re
import gc
from functools import lru_cache
import sys
import os
from lupa import LuaRuntime
import sqlite3
import importlib.util

try:
    import cython
    CYTHON_AVAILABLE = True
except ImportError:
    CYTHON_AVAILABLE = False
    def cython_decorator(func):
        return func
    class cython:
        @staticmethod
        def ccall(func):
            return func

# Предкомпиляция и кэширование регулярных выражений
LANG_BLOCK_RE = re.compile(r'lang (\w+)\(\)\s*<\{([\s\S]*?)\}>')
IMPORT_RE = re.compile(r'module\s+import\s*\{([\s\S]*?)\}')
TRASH_CLEANER_RE = re.compile(r'trash_cleaner\s*=\s*(true|false)')
FUNCTION_DEF_RE = re.compile(r'\bfunc\s+(\w+)\s*\((.*?)\)\s*\{')
VARIABLE_DECLARATION_RE = re.compile(r'\b(var|let|const)\s+')
SEMICOLON_RE = re.compile(r';')


class SyntaxError(Exception):
    pass

class RytonError(Exception):
    def __init__(self, message, line_number=None, column=None, line_content=None):
        self.message = message
        self.line_number = line_number
        self.column = column
        self.line_content = line_content

    def __str__(self):
        error_msg = f"Ryton Error: {self.message}"
        if self.line_number is not None:
            error_msg += f"\nAt line {self.line_number}"
            if self.column is not None:
                error_msg += f", column {self.column}"
        if self.line_content:
            error_msg += f"\n{self.line_content}\n{' ' * (self.column - 1)}^"
        return error_msg

class MemoryManager:
    __slots__ = ('objects', 'total_allocated')

    def __init__(self):
        self.objects = {}
        self.total_allocated = 0

    def allocate(self, name, value):
        self.objects[name] = value
        self.total_allocated += sys.getsizeof(value)

    def free(self, name):
        if name in self.objects:
            self.total_allocated -= sys.getsizeof(self.objects[name])
            del self.objects[name]

    def get(self, name):
        return self.objects.get(name)

    def memory_usage(self):
        return self.total_allocated

    def object_count(self):
        return len(self.objects)

class SharpyLang:
    __slots__ = ('globals', 'lua', 'sql_connection', 'sql_cursor', 'imported_libs', 
                 'transformation_cache', 'compiled_cache', 'memory_manager', 'trash_cleaner', 
                 'module_mapping', 'loaded_modules')

    def __init__(self):
        self.globals = {}
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.sql_connection = sqlite3.connect(':memory:')
        self.sql_cursor = self.sql_connection.cursor()
        self.imported_libs = set()
        self.transformation_cache = {}
        self.compiled_cache = {}
        self.memory_manager = MemoryManager()
        self.trash_cleaner = True
        self.module_mapping = {
            'Algorithm': 'Algorithm',
            'RySystem': 'RySystem',
            'DocTools': 'DocTools',
            'RyGame': 'RyGame, pygame',
            'CreateAI': 'CreateAI',
            'RyMedia': 'RyMedia',
            'NetWorker': 'NetWorker',
            'multiproc': 'concurrent.futures'
        }
        self.loaded_modules = {}  # Инициализация loaded_modules
        
        # Настройки сборщика мусора
        gc.enable()
        gc.set_threshold(1000, 15, 10)

    def import_ryton_module(self, module_name):
        if module_name in self.loaded_modules:
            return self.loaded_modules[module_name]

        for ext in ['.ry', '.ryton', '.ryt']:
            module_path = f"{module_name}{ext}"
            if os.path.exists(module_path):
                with open(module_path, 'r') as file:
                    module_code = file.read()
                
                # Создаем новый экземпляр SharpyLang для модуля
                module_instance = SharpyLang()
                
                # Создаем пространство имен для модуля
                module_namespace = {}
                
                # Выполняем код модуля в его собственном пространстве имен
                transformed_code = module_instance.transform_syntax(module_code)
                exec(compile(transformed_code, module_path, 'exec'), module_namespace)
                
                # Создаем объект модуля
                class ModuleType:
                    pass
                module_object = ModuleType()
                
                # Добавляем все определения из пространства имен модуля в объект модуля
                for name, value in module_namespace.items():
                    setattr(module_object, name, value)
                
                # Сохраняем модуль в словаре загруженных модулей
                self.loaded_modules[module_name] = module_object
                
                return module_object

        raise ImportError(f"No module named '{module_name}' found")

    def process_imports(self, match):
        imports = match.group(1).split()
        python_imports = []
        for imp in imports:
            imp = imp.strip()
            if imp in self.module_mapping:
                python_module = self.module_mapping[imp]
                python_imports.append(f"import {python_module}\n")
                self.imported_libs.add(imp)
            else:
                # Пробуем импортировать как Ryton-модуль
                try:
                    module_globals = self.import_ryton_module(imp)
                    self.globals.update(module_globals)
                    python_imports.append(f"# Ryton module '{imp}' imported\n")
                except ImportError:
                    python_imports.append(f"# Failed to import '{imp}'\n")
        return self.optimize_string_concat(*python_imports)


    def handle_error(self, error, original_code):
	    lines = original_code.split('\n')
	    if isinstance(error, SyntaxError):
	        line_number = error.lineno
	        column = error.offset
	        message = f"Syntax error: {error.msg}"
	    else:
	        tb = error.__traceback__
	        while tb.tb_next:
	            tb = tb.tb_next
	        line_number = tb.tb_lineno
	        column = None
	        message = f"Runtime error: {str(error)}"
	
	    if 0 <= line_number - 1 < len(lines):
	        error_line = lines[line_number - 1]
	        raise RytonError(message, line_number, column, error_line)
	    else:
	        raise RytonError(message)
	
    @cython.ccall
    def check_syntax(self, code):
	    lines = code.split('\n')
	    for i, line in enumerate(lines, 1):
	        # Check for 'var', 'let', 'const'
	        match = VARIABLE_DECLARATION_RE.search(line)
	        if match:
	            col = match.start() + 1
	            raise RytonError(f"Use of '{match.group(1)}' is not allowed", i, col, line)
	
	        # Check for semicolons
	        match = SEMICOLON_RE.search(line)
	        if match:
	            col = match.start() + 1
	            raise RytonError("Use of semicolons is not allowed", i, col, line)
	
	    # Check function declarations
	    for match in FUNCTION_DEF_RE.finditer(code):
	        func_name, params = match.groups()
	        if not func_name.isidentifier():
	            line_number = code[:match.start()].count('\n') + 1
	            line = lines[line_number - 1]
	            col = match.start() - sum(len(l) + 1 for l in lines[:line_number - 1])
	            raise RytonError(f"Invalid function name: {func_name}", line_number, col, line)
	        
	        for param in params.split(','):
	            param = param.strip()
	            if param and not param.isidentifier():
	                line_number = code[:match.start()].count('\n') + 1
	                line = lines[line_number - 1]
	                col = line.index(param) + 1
	                raise RytonError(f"Invalid parameter name in function {func_name}: {param}", line_number, col, line)
	
	    # Check brace balance
	    open_braces = code.count('{')
	    close_braces = code.count('}')
	    if open_braces != close_braces:
	        raise RytonError("Mismatched braces in the code")
	
	    # Check for trash_cleaner
	    if not TRASH_CLEANER_RE.search(code):
	        raise RytonError("Missing required 'trash_cleaner' declaration\nexemple code:\n trash_cleaner = true // auto clear memory")
	
    @cython.ccall
    def transform_syntax(self, code):
        # Сначала проверяем синтаксис
        self.check_syntax(code)

        # Кэширование трансформаций
        code_hash = hash(code)
        if code_hash in self.transformation_cache:
            return self.transformation_cache[code_hash]

        # Защита блоков lang
        protected_blocks = []
        def protect_lang_block(match):
            protected_blocks.append(match.group(0))
            return f"LANG_BLOCK_{len(protected_blocks) - 1}"
        
        code = LANG_BLOCK_RE.sub(protect_lang_block, code)

        # Обработка импортов библиотек
        code = IMPORT_RE.sub(self.process_imports, code)

        # Обработка trash_cleaner
        match = TRASH_CLEANER_RE.search(code)
        if match:
            self.trash_cleaner = match.group(1) == 'true'
            code = TRASH_CLEANER_RE.sub('', code)

        # Замены синтаксиса
        replacements = {
        	'skip': 'pass',
            'lib': 'import',
            'func': 'def',
            'true': 'True',
            'false': 'False',
            '&&': 'and',
            'and': 'and',
            '||': 'or',
            'or': 'or',
            '!!': 'not',
            'not': 'not',
            '//': '#',
            '\\': '#',
        }
        for old, new in replacements.items():
            code = code.replace(old, new)

        # Обработка фигурных скобок и отступов
        lines = code.split('\n')
        transformed_lines = []
        indent_level = 0
        for line in lines:
            stripped = line.strip()
            
            if stripped.endswith('{'):
                transformed_lines.append('    ' * indent_level + stripped[:-1] + ':')
                indent_level += 1
            elif stripped.startswith('}'):
                indent_level = max(0, indent_level - 1)
            else:
                transformed_lines.append('    ' * indent_level + stripped)

        code = '\n'.join(transformed_lines)

        # Восстанавливаем защищенные блоки lang
        for i, block in enumerate(protected_blocks):
            code = code.replace(f"LANG_BLOCK_{i}", block)

        self.transformation_cache[code_hash] = code
        return code

    @staticmethod
    @lru_cache(maxsize=128)
    def optimize_string_concat(*strings):
        return ''.join(strings)


    @cython.ccall
    def process_imports(self, match):
        imports = match.group(1).split()
        python_imports = []
        for imp in imports:
            imp = imp.strip()
            if imp in self.module_mapping:
                python_module = self.module_mapping[imp]
                python_imports.append(f"import {python_module}\n")
                self.imported_libs.add(imp)
            else:
                # Пробуем импортировать как Ryton-модуль
                try:
                    module_object = self.import_ryton_module(imp)
                    python_imports.append(f"{imp} = sharpy.import_ryton_module('{imp}')\n")
                except ImportError:
                    python_imports.append(f"# Failed to import '{imp}'\n")
                    raise RytonError(f"Failed to import module '{imp}'. Make sure the file '{imp}.ry', '{imp}.ryton' or '{imp}.ryt' exists.")
        return self.optimize_string_concat(*python_imports)


    @cython.ccall
    def execute(self, code):
        # Трансформируем синтаксис перед парсингом
        transformed_code = self.transform_syntax(code)
        
        # функции для управления памятью и сборщиком мусора
        memory_functions = """
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
"""
        transformed_code = self.optimize_string_concat(memory_functions, transformed_code)
        
        # Добавляем функцию для импорта модулей Ryton
        import_function = """
def import_ryton(module_name):
    module = sharpy.import_ryton_module(module_name)
    globals()[module_name] = module
    return module
"""
        transformed_code = self.optimize_string_concat(import_function, transformed_code)

        # Обработка блоков кода на других языках
        def execute_lang_block(match):
            lang = match.group(1)
            code_block = match.group(2)
            if lang == 'lua':
                result = self.run_lua(code_block)
                return f"print({result!r})"
            elif lang == 'sql':
                result = self.run_sql(code_block)
                return f"print({result!r})"
            else:
                return f"print('Unsupported language: {lang}')"

        transformed_code = LANG_BLOCK_RE.sub(execute_lang_block, transformed_code)

        # Кэширование скомпилированного кода
        code_hash = hash(transformed_code)
        if code_hash not in self.compiled_cache:
            self.compiled_cache[code_hash] = compile(transformed_code, '<string>', 'exec')

        # Выполняем скомпилированный код
        try:
            exec(self.compiled_cache[code_hash], {'sharpy': self, 'gc': gc})
        except RytonError as e:
            print(e)  # или используйте self.handle_error(e, code)
        except Exception as e:
            self.handle_error(e, code)

        # Автоматическая очистка памяти, если trash_cleaner == True
        if self.trash_cleaner:
            self.memory_manager.objects.clear()
            gc.collect()

    @cython.ccall
    def run_lua(self, lua_code):
	    try:
	        result = self.lua.execute(lua_code)
	        return str(result) if result is not None else "None"
	    except Exception as e:
	        raise RytonError(f"Lua Error: {e}")
	
    @cython.ccall
    def run_sql(self, sql_code):
	    try:
	        self.sql_cursor.executescript(sql_code)
	        result = self.sql_cursor.fetchall()
	        return str(result)
	    except Exception as e:
	        raise RytonError(f"SQL Error: {e}")

if __name__ == '__main__': 
    RytonOne = SharpyLang()
    
    test_code = """
    module import {
    	multiproc
    	sas
    }
    
    trash_cleaner = true
    
    s = sas.sas(1, 1, 99)
    
    print(s)
    """
    
    try:
        RytonOne.execute(test_code)
    except RytonError as e:
        print(e)
