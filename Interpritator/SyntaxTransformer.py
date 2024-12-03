from functools import lru_cache

import re
import random

from .Effects import *
from .Pragma import *

from .ErrorHandler import *

# Предкомпиляция некоторых трансформаций синтаксиса
PROGRAMM_CLEANUP_RE = re.compile(r'programm\.cleanup\s*\{([\s\S]*?)\}')
GROUPED_ARGS_RE     = re.compile(r'func\s+(\w+)\s*\(\s*(.*?->.*?)\s*\)\s*:', re.DOTALL)

GUARD_RE   = re.compile(r'guard\s+(.*?)\s+else\s*\{([\s\S]*?)\}')
IMPORT_RE  = re.compile(r'module\s+import\s*\{([\s\S]*?)\}')
EVENT_RE   = re.compile(r'event\s+(\w+)\s*\{([\s\S]*?)\}')
MATCH_RE   = re.compile(r'match\s+(\w+)\s*\{([\s\S]*?)\}')
WITH_RE    = re.compile(r'with\s+(\w+)\s*\{([\s\S]*?)\}')
DEFER_RE   = re.compile(r'defer\s*\{([\s\S]*?)\}')
LAZY_RE    = re.compile(r'lazy\s+(\w+)\s*=\s*(.*)')


def transform_thread(self, code):
    return re.sub(r'thread\s+(\w+)\s*\{([\s\S]*?)\}', self.create_thread, code)

def create_thread(self, match):
    thread_name = match.group(1)
    thread_code = match.group(2)
    return f"""
def {thread_name}_func():
    {thread_code}

thread = threading.Thread(target={thread_name}_func)
thread.start()
"""

def transform_range_syntax(self, code):
    code = re.sub(r'(\d+)\.\.\.(\d+)', r'range(\1, \2)', code)
    code = re.sub(r'(\d+)\.\.(\d+)', r'range(\1, \2 + 1)', code)
    return code

def transform_comm_syntax(self, code):
    return re.sub(r'</\s*(.*?)\s*/>', r'', code, flags=re.DOTALL)

def transform_decorator_syntax(self, code):
    return re.sub(r'<\s*(\w+)\s*>\n', r'@\1\n', code, flags=re.DOTALL)

def transform_type_syntax(self, code):
    def replace_type(match):
        indent = match.group(1)
        type = match.group(2)
        func = match.group(3)
        return f"{indent}{type}({func})"

    return re.sub(r'([ \t]*)\s*(bool|int|str)\s*:\s*(.*?)\s*\n', replace_type, '\n\n', code)

def transform_dots_syntax(self, code):
    def replace(match):
        indent = match.group(1)
        operator = match.group(2)
        operator2 = match.group(3)
        return f"\n{indent}{operator}\n{indent}{operator2}"

    return re.sub(r'([ \t]*)\s*(.*?)\s* :: \s*(.*?)\s*', replace, code)

def transform_pipe_operator(self, code):
    return re.sub(r'(\w+)\s*\|>\s*(\w+)', r'\2(\1)', code)

def transform_spaceship_operator(self, code):
    return re.sub(r'(\w+)\s*<=>\s*(\w+)', r'((\1 > \2) - (\1 < \2))', code)

def transform_function_composition(self, code):
    return re.sub(r'(\w+)\s*>>\s*(\w+)', r'(lambda x: \2(\1(x)))', code)

def transform_unpacking(self, code):
    return re.sub(r'(\w+(?:\s*,\s*\w+)*)\s*\*=\s*(.+)', r'\1 = (\2) if isinstance(\2, tuple) else tuple(\2)', code)

def transform_default_assignment(self, code):
    return re.sub(r'(\w+)\s*\?=\s*(.+)', r'\1 = \1 if "\1" in locals() and \1 is not None else (\2)', code)

def transform_elif(self, code):
    return re.sub(r'} elif \s*(.*?)\s* :', r'elif \1:', code)

def transform_elerr3(self, code):
    return re.sub(r'elerr \s*(.*?)\s* :', r'except \1:', code)

def transform_elerr4(self, code):
    return re.sub(r'elerr :', r'except :', code)

def transform_neural(self, code):
    def replace_neural(match):
        indent = match.group(1)
        name = match.group(2)
        layers = match.group(3)
        body = match.group(4)

        transformed = f"{indent}{name} = NeuralNet.create_neural_network([{layers}])\n"
        for line in body.strip().split('\n'):
            line = line.strip()
            if line.startswith('compile'):
                _, optimizer, loss, metrics = line.split(maxsplit=3)
                transformed += f"{indent}NeuralNet.compile_network({name}, optimizer='{optimizer}', loss='{loss}', metrics={metrics})\n"
            elif line.startswith('train'):
                _, data, labels, epochs, batch_size, val_split = line.split()
                transformed += f"{indent}history = NeuralNet.train_network({name}, {data}, {labels}, {epochs}, {batch_size}, {val_split})\n"
            elif line.startswith('predict'):
                _, input_data = line.split()
                transformed += f"{indent}prediction = NeuralNet.predict({name}, {input_data})\n"
            elif line.startswith('evaluate'):
                _, test_data, test_labels = line.split()
                transformed += f"{indent}evaluation = NeuralNet.evaluate_network({name}, {test_data}, {test_labels})\n"
            elif line.startswith('save'):
                _, filepath = line.split()
                transformed += f"{indent}NeuralNet.save_network({name}, {filepath})\n"
            elif line.startswith('load'):
                _, filepath = line.split()
                transformed += f"{indent}{name} = NeuralNet.load_network({filepath})\n"

        return transformed

    return re.sub(r'([ \t]*)neural\s+(\w+)\s*\((\d+(?:,\s*\d+)*)\)\s*\:([\s\S]*?)', replace_neural, code)

def transform_with(self, code):
    def replace_with(match):
        resource = match.group(1)
        body = match.group(2)
        return f"with {resource}:\n{body}"
    return WITH_RE.sub(replace_with, code)

def transform_event(self, code):
    def replace_event(match):
        indent = match.group(1)
        var1 = match.group(2)
        var2 = match.group(3)
        event_code = match.group(4)
        event_id = f'event_{random.randint(1000, 9999)}'

        return f"""
{indent}def {event_id}():
{indent}    whlo = True
{indent}    while whlo:
{indent}        if {var1} == {var2}:
{indent}            {event_code}
{indent}            break
{indent}        else:
{indent}            timexc.sleep(0.05)

{indent}thread = threading.Thread(target={event_id})
{indent}thread.start()\n\n
"""
    return re.sub(r'([\t]*)event \s*(.*?)\s* -> \s*(.*?)\s* {\s*(.*?)\s*}', replace_event, code)

def transform_guard(self, code):
    def replace_guard(match):
        condition = match.group(1)
        body = match.group(2)
        return f"if not ({condition}):\n{body}\n    return"
    return GUARD_RE.sub(replace_guard, code)

def transform_defer(self, code):
    def replace_defer(match):
        body = match.group(1)
        return f"@contextlib.contextmanager\ndef _defer_context():\n    try:\n        yield\n    finally:\n{body}\nwith _defer_context():"
    return DEFER_RE.sub(replace_defer, code)

def transform_lazy(self, code):
    def replace_lazy(match):
        var_name = match.group(1)
        expression = match.group(2)
        return f"{var_name} = lambda: {expression}"
    return LAZY_RE.sub(replace_lazy, code)

def transform_programm_cleanup(self, code):
    def replace_programm_cleanup(match):
        body = match.group(1)
        return f"import atexit\n@atexit.register\ndef _cleanup():\n{body}"
    return PROGRAMM_CLEANUP_RE.sub(replace_programm_cleanup, code)

def transform_infinit(self, code):
    def replace_infinit(match):
        indent = match.group(1)
        delay = match.group(2)
        return f"{indent}while True: \n{indent}    timexc.sleep({delay})\n{indent}    "

    return re.sub(r'([ \t]*)infinit\s*(.*?)\s*:', replace_infinit, code)

def transform_metatable(self, code):
    return re.sub(r'table\s+(\w+)\s*<\{([\s\S]*?)\}>', 
                 lambda m: f"{m.group(1)} = MetaTable({{{m.group(2)}}})", code)

def transform_special_operators(self, code):
    def replace_in_string(match):
        string_content = match.group(1)
        # Замены внутри строки
        string_content = string_content.replace('$N', '\\n')
        string_content = string_content.replace('$T', '\\t')
        string_content = string_content.replace('$R', '\\r')
        string_content = string_content.replace('$V', '\\v')
        string_content = string_content.replace('$F', '\\f')
        string_content = string_content.replace('$B', '\\a')
        string_content = string_content.replace('$BS', '\\b')
        string_content = string_content.replace('$0', '\\0')
        return f'"{string_content}"'

    # Обработка строк в двойных кавычках
    code = re.sub(r'"([^"]*)"', replace_in_string, code)
    
    # Обработка строк в одинарных кавычках
    code = re.sub(r"'([^']*)'", replace_in_string, code)
    
    return code

def transform_private(self, code):
    # Приватные элементы внутри пакетов
    def replace_pack_private(match):
        pack_name = match.group(1)
        content = match.group(2)
        
        # Находим private поля и методы
        private_items = re.findall(r'private\s+(\w+)(?:\s*:\s*(.+?))?(?:\s*{(.*?)})?', content)
        
        result = []
        for name, type_hint, impl in private_items:
            private_name = f"_{pack_name}_{name}"
            if impl:
                result.append(f"{private_name} = {impl}")
            else:
                result.append(f"{private_name} = {type_hint}")
                
        return '\n'.join(result)

    # Обработка приватных элементов внутри пакетов    
    code = re.sub(r'pack\s+(\w+)\s*\{(.*?)\}', replace_pack_private, code)
    
    # Приватные переменные
    code = re.sub(r'private\s+(\w+)\s*=\s*(.+)', r'_\1 = \2', code)
    
    # Приватные функции
    code = re.sub(r'private\s+func\s+(\w+)', r'func _\1', code)
    
    # Приватные пакеты
    code = re.sub(r'private\s+pack\s+(\w+)', r'pack _\1', code)
    
    return code


# Обработка создания DSL
def create_dsl_replacement(match):
    dsl_name = match.group(1)
    dsl_body = match.group(2)
    result = f"sharpy.dsls['{dsl_name}'] = dsl.create_dsl('{dsl_name}')\n"
    for line in dsl_body.strip().split('\n'):
        keyword, func = line.strip().split('->')
        result += f"sharpy.dsls['{dsl_name}'].add_keyword('{keyword.strip()}', {func.strip()})\n"
    return result

# Обработка использования DSL
def use_dsl_replacement(match):
    dsl_name = match.group(1)
    dsl_code = match.group(2)
    return f"sharpy.dsls['{dsl_name}'].parse('''{dsl_code}''')\n"

# Трансформация свойств и методов класса
def transform_prop(self, code):
    code = re.sub(r'(\w+)\s*:\s*(\w+)\s*$', r'\1: \2', code)  # Для аннотаций типов
    code = re.sub(r'(\w+)\s*\((.*?)\)\s*=>\s*(.*?)$', r'def \1(self, \2):\n        return \3', code)
    code = re.sub(r'@property\s*\n\s*(\w+)\s*=>\s*(.*?)$', r'@property\ndef \1(self):\n        return \2', code)
    return code

def transform_debug_blocks(self, code):
    def replace_block(match):
        block_name = match.group(1)
        start_line = code[:match.start()].count('\n') + 1
        return f'self.error_handler.register_block("{block_name}", {start_line})\n'

    return re.sub(r'#block\(([^)]+)\)', replace_block, code)

def transform_block_end(self, code):
    def replace_end(match):
        end_line = code[:match.start()].count('\n') + 1
        return f'self.error_handler.end_block({end_line})\n'

    return re.sub(r'#end_block', replace_end, code)

# Трансформация вызова функции с массивом
def transform_func_massive(self, code):
    code = re.sub(r'(\w+)\[(.*?)\]', r'\1(*[\2])', code)
    return code

@lru_cache(maxsize=128)
def transform_init(self, code):
    def replace_init(match):
        indent = match.group(1)
        return f"{indent}def __init__(self):\n{indent}    "

    return re.sub(r'([ \t]*)init\s*:', replace_init, code)

@lru_cache(maxsize=128)
def transform_start_programm(self, code):
    return re.sub(r'programm.start :\s*(.*?)\s*', r'if __name__ == "__main__": \n    \1', code)

def transform_info_programm(self, code):
    return re.sub(r'programm.info :\s*(.*?)\s*', r'def programm_info(): \n\1    ', code)

def transform_repeat(self, code):
    def replace_repeat(match):
        indent = match.group(1)
        count = match.group(2)
        delay = match.group(3)
        return f"{indent}for _ in range({count}):\n{indent}    timexc.sleep({delay})\n{indent}    "

    return re.sub(r'([ \t]*)repeat\s*(.*?)\s* \s*(.*?)\s* :', replace_repeat, code)

def transform_run_lang(self, code):
    return re.sub(r'lang \s*(\w+)\s* : \s*(.*?)\s*', r'langs.Run.\1("""\2""")', code)

def transform_void(self, code):
    return re.sub(r'void \s*(pack|func)\s* \s*(\w+)\s*(\s*(.*?)\s*)', r'\1 \2(\3) :\n    pass\n \n#', code)

def transform_pack_slots(self, code):
    def replace_pack_slots(match):
        indent = match.group(1)
        pack_name = match.group(2)
        inheritance = match.group(3) or ''
        body = match.group(4)
        
        init_match = re.search(r'init\s*:\s*{([\s\S]*?)}', body)
        if init_match:
            init_body = init_match.group(1)
            slots = re.findall(r'self\.(\w+)\s*=', init_body)
            
            result = [
                f"{indent}class {pack_name}{inheritance}:",
                f"{indent}    __slots__ = ({', '.join(repr(slot) for slot in slots)})",
                "",
                f"{indent}    def __init__(self, {', '.join(slots)}):",
            ]
            
            # Добавляем тело init с правильными отступами
            for line in init_body.strip().split('\n'):
                result.append(f"{indent}        {line.strip()}")
            
            # Добавляем остальные методы
            other_methods = re.sub(r'init\s*:\s*{[\s\S]*?}', '', body).strip()
            for line in other_methods.split('\n'):
                if line.strip():
                    result.append(f"{indent}    {line.strip()}")
            
            return '\n'.join(result)
            
        return f"{indent}class {pack_name}{inheritance}:\n{indent}{body}"

    return re.sub(r'([ \t]*)pack\s+(\w+)(\(.*?\))?\s*!slots\s*{([\s\S]*?)}', replace_pack_slots, code)

@lru_cache(maxsize=128)
def transform_pack(self, code):
    return re.sub(r'pack \s*(\w+)\s*\(\s*(.*?)\s*\) :', r'class \1(\2):', code)

@lru_cache(maxsize=128)
def transform_pack2(self, code):
    return re.sub(r'pack \s*(\w+)\s* :', r'class \1:', code)

@lru_cache(maxsize=128)
def transform_func(self, code):
    return re.sub(r'func \s*(\w+)\s*(\s*(.*?)\s*) :', r'def \1\2: ', code)

@lru_cache(maxsize=128)
def transform_func2(self, code):
    return re.sub(r'func \s*(\w+)\s* :', r'def \1():', code)

@lru_cache(maxsize=128)
def transform_decorators(self, code):
    code = re.sub(r'<TimeCache\(seconds=(\d+)\)>', 
                  r'@TimeCache(seconds=\1)', code)
    
    code = re.sub(r'<JitCompile\(mode=[\'"](numba|cython)[\'"]\)>', 
                  '@JitCompile(mode=\1)', code)
    
    code = re.sub(r'<cache\(\s*(.*?)\s*\)>',
                  r'@lru_cache(maxsize=\1)', code)

    return code

@lru_cache(maxsize=128)
def transform_func3(self, code):
    return re.sub(r'func \s*(\w+)\s*\(\s*(.*?)\s*\) -> \s*(.*?)\s*:', r'def \1(\2) -> \3:', code)

@lru_cache(maxsize=128)
def transform_pylib(self, code):
    return re.sub(r'pylib: \s*(\w+)\s*', r'import \1\n', code)

@lru_cache(maxsize=128)
def transform_elerr(self, code):
    return re.sub(r'try {\s*(.*?)\s*} elerr {\s*(.*?)\s*}', r'try: \1 except: \2', code)

@lru_cache(maxsize=128)
def transform_elerr2(self, code):
    return re.sub(r'try {\s*(.*?)\s*} elerr \s*(.*?)\s* {\s*(.*?)\s*}', r'try: \1 except \2: \3', code)

@lru_cache(maxsize=128)
def transform_table(self, code):
    def replace_table(match):
        table_name = match.group(1)
        table_body = match.group(2)
        
        # Преобразуем многострочное тело в однострочное
        entries = []
        for line in table_body.strip().split('\n'):
            line = line.strip()
            if not line: continue
            
            if ':=' in line:  # Computed properties
                key, expr = line.split(':=')
                entries.append(f"{key.strip()}: lambda self: {expr.strip()}")
            elif '>>' in line:  # Methods
                name, body = line.split('>>')
                entries.append(f"{name.strip()}: lambda self: {body.strip()}")
            elif '::' in line:  # Validators
                key, validator = line.split('::')
                entries.append(f"'{key.strip()}': lambda x: {validator.strip()}")
            else:  # Regular key-value
                entries.append(line.rstrip(','))
                
        # Собираем однострочную таблицу
        table_content = ', '.join(entries)
        return f"{table_name} = MetaTable({{{table_content}}})"

    return re.sub(r'table\s+(\w+)\s*\{\s*([\s\S]*?)\s*\}', replace_table, code)

@lru_cache(maxsize=128)
def protect_tables(self, code):
    def pack_table(match):
        table_name = match.group(1)
        content = match.group(2)
        
        # Просто убираем переносы строк, сохраняя всю структуру
        single_line = content.replace('\n', '').strip()
        
        return f"{table_name} = {{{single_line}}}"
    
    return re.sub(r'table\s+(\w+)\s*=\s*\{([\s\S]*?)\}', pack_table, code)



@lru_cache(maxsize=128)
def transform_contracts_body(self, code):
    return re.sub(r'([ \t]*)body {\s*(.*?)\s*}', r'\n\1body {\2}', code)

@lru_cache(maxsize=128)
def transform_parallel_sub(self, code):
    return re.sub(r'([ \t]*)parallel {\s*([\s\S]*?)\s*}', r'\n\1parallel {\2}', code)

#    return re.sub(r'([ \t]*)event \s*(\w+)\s* -> \s*(\w+)\s* {\s*([\s\S]*?)\s*}', r'\n\1event \2 -> \3 {\4}', code)

@lru_cache(maxsize=128)
def transform_import_modules(self, code):
    def replace_module(match):
        module = match.group(1)
        sub = match.group(2)
        sub_modules = match.group(3)
        
        # Обработка множественных подмодулей
        sub_modules = re.sub(r'\|', ',', sub_modules)
        sub_modules = re.sub(r'/', '.', sub_modules)
        
        # Обработка алиасов
        if ':' in sub_modules:
            imports = []
            for item in sub_modules.split(','):
                if ':' in item:
                    name, alias = item.strip().split(':')
                    imports.append(f"{name.strip()} as {alias.strip()}")
                else:
                    imports.append(item.strip())
            sub_modules = ', '.join(imports)
            
        # Обработка вложенных импортов
        if '.' in sub:
            sub_parts = sub.split('.')
            return f'from {module}.{".".join(sub_parts)} import {sub_modules}'
            
        # Обработка импорта с фильтрацией
        if '*' in sub_modules:
            return f'from {module}.{sub} import *'
            
        # Обработка условного импорта
        if '?' in sub_modules:
            modules = sub_modules.replace('?', '').split(',')
            result = []
            for mod in modules:
                result.append(f"""
try:
    from {module}.{sub} import {mod.strip()}
except ImportError:
    pass""")
            return '\n'.join(result)
        
        return f'from {module}.{sub} import {sub_modules}'

    # Обработка множественных импортов в одной строке
    code = re.sub(r'from \s*(.*?)\s* import \s*(\w+)\s*\[\s*([\s\S]*?)\s*\]', replace_module, code)
    
    # Обработка импорта всего модуля
    code = re.sub(r'import \s*(.*?)\s* as \s*(\w+)', r'import \1 as \2', code)
    
    # Обработка относительных импортов
    code = re.sub(r'from \.\s*import', r'from . import', code)
    
    return code

def transform_contracts(self, code):
    def replace_contracts(match):
        func_name = match.group(1)
        return_type = match.group(2)
        requires = match.group(3)
        ensures = match.group(4)
        body = match.group(6)

        result = f"def {func_name}(*args, **kwargs):\n"
        result += f"    if not ({requires}):\n"
        result += f"        raise ContractError('Предусловие нарушено')\n"
        result += f"    result = {body.strip()}\n"
        result += f"    if not ({ensures.replace('result', 'result')}):\n"
        result += f"        raise ContractError('Постусловие нарушено')\n"
        result += f"    return result \n"

        return result

    return re.sub(r'func\s+(\w+)\s*\((.*?)\)\s*:\s*(\w+)\s*\:\s*require\s+(.*?)\s*ensure\s+(.*?)\s*body\s*{\s*(.*?)\s*}', 
                replace_contracts, code)

def transform_match(self, code):
    def replace_match(match):
        value = match.group(1)
        cases = match.group(2)

        result = f"def _pattern_match():\n"
        result += f"    _value = {value}\n"

        for case in cases.strip().split('\n'):
            if not case.strip():
                continue

            if 'case' in case:
                pattern = case.split('=>')[0].replace('case', '').strip()
                action = case.split('=>')[1].strip()

                if '(' in pattern:
                    type_name = pattern.split('(')[0].strip()
                    vars = pattern.split('(')[1].split(')')[0].strip()
                    result += f"    if isinstance(_value, {type_name}):\n"
                    result += f"        {vars} = _value.data\n"
                    result += f"        return {action}\n"
                else:
                    result += f"    if _value == {pattern}:\n"
                    result += f"        return {action}\n"

        result += "    raise ValueError('No matching pattern')\n"
        result += "_pattern_match()"
        return result

    return re.sub(r'match\s+(.+?)\s*\ :([\s\S]*?)', replace_match, code)

def process_decorators(self, code: str) -> str:
    effects = re.findall(r'<effect\((.*?)\)>\n', code)
    pragmas = re.findall(r'<pragma\((.*?)\)>\n', code)

    for effect in effects:
        if self.effect_registry.validate(effect):
            code = code.replace(f'<effect({effect})>', f'@effect("{effect}")')

    for pragma in pragmas:
        handler = getattr(self.pragma_handler, pragma, None)
        if handler:
            code = code.replace(f'<pragma({pragma})>', handler(code))

    return code

def transform_struct(self, code):
    def replace_struct(match):
        struct_name = match.group(1)
        fields = match.group(2)

        result = f"class {struct_name}:\n"
        result += "    def __init__(self, **kwargs):\n"

        validators = []
        for field in fields.strip().split('\n'):
            if not field.strip():
                continue

            name, type_info = field.split(':')
            name = name.strip()
            type_info = type_info.strip()

            if '(' in type_info:
                type_name = type_info.split('(')[0]
                constraints = type_info.split('(')[1].split(')')[0]

                result += f"        self.{name} = kwargs.get('{name}')\n"

                for constraint in constraints.split(','):
                    key, value = constraint.split('=')
                    validators.append(f"        if not self._validate_{key}(self.{name}, {value}): "
                                f"raise ValueError(f'{name} failed {key} validation')")
            else:
                result += f"        self.{name} = kwargs.get('{name}')\n"

        if validators:
            result += "\n    def validate(self):\n"
            result += '\n'.join(validators)
            result += "\n        return True\n"

        result += """
    @staticmethod
    def _validate_min(value, min_val):
        return len(str(value)) >= min_val if isinstance(value, str) else value >= min_val

    @staticmethod
    def _validate_max(value, max_val):
        return len(str(value)) <= max_val if isinstance(value, str) else value <= max_val

    @staticmethod
    def _validate_pattern(value, pattern):
        import re
        return bool(re.match(pattern, str(value)))
    """

        return result

    return re.sub(r'struct\s+(\w+)\s*\{([\s\S]*?)\}', replace_struct, code, flags=re.MULTILINE)

def transform_clib_import(self, code):
    def replace_clib(match):
        lib_name = match.group(1)
        return f"""
result = CythonBridge.compile_inline('''
cdef extern from "{lib_name}.h":
    pass
''')
"""

    return re.sub(r'clib: \s*(\w+)\s*', replace_clib, code)

def transform_chain(self, code):
    def replace_chain(match):
        chain_name = match.group(1)
        methods = match.group(2)
        
        return f"""
class {chain_name}:
    def __init__(self):
        self._result = None
        
    def __getattr__(self, name):
        def wrapper(*args):
            self._result = getattr(self, f'_{name}')(*args)
            return self
        return wrapper
"""

    return re.sub(r'chain\s+(\w+)\s*\{([\s\S]*?)\}', replace_chain, code)
from textwrap import dedent

def transform_intercept(self, code):
    def replace_intercept(match):
        target = match.group(1)
        before = match.group(2)
        after = match.group(3)
        
        return f"""
def intercept_{target}(func):
    def wrapper(*args, **kwargs):
        {before}(*args, **kwargs)
        result = func(*args, **kwargs)
        {after}(result)
        return result
    return wrapper
        """

    return re.sub(r'intercept\s+(\w+)\s*\{\s*before:\s*(.*?)\s*after:\s*(.*?)\s*\}', 
                 replace_intercept, code)

def transform_state_machine(self, code):
    def replace_state(match):
        name = match.group(1)
        transitions = match.group(2)
        
        states = {}
        for trans in transitions.split('\n'):
            if '->' in trans:
                src, rest = trans.split('->')
                dst, action = rest.split(':')
                states[src.strip()] = (dst.strip(), action.strip())
                
        return f"""
class {name}:
    def __init__(self):
        self.state = None
        self.transitions = {states}
    
    def transition(self, action):
        if self.state in self.transitions:
            next_state, valid_action = self.transitions[self.state]
            if action == valid_action:
                self.state = next_state
                return True
        return False
"""

    return re.sub(r'state_machine\s+(\w+)\s*\{([\s\S]*?)\}', replace_state, code)

def transform_macro(self, code):
    macro_pattern = r'macro\s+(\w+)\s*\((.*?)\)\s*\{([\s\S]*?)\}'
    macros = {}
    
    def replace_macro(match):
        macro_name = match.group(1)
        params = match.group(2).split(',')
        body = match.group(3)
        macros[macro_name] = (params, body)
        return ''
        
    # Сначала собираем все макросы
    code = re.sub(macro_pattern, replace_macro, code)
    
    # Затем раскрываем их вызовы
    for macro_name, (params, body) in macros.items():
        def expand_this_macro(match):
            args = match.group(1).split(',')
            expanded = body
            for param, arg in zip(params, args):
                expanded = expanded.replace(f'${param.strip()}', arg.strip())
            return expanded
            
        code = re.sub(rf'{macro_name}\((.*?)\)', expand_this_macro, code)
        
    return code

def transform_language_tags(self, code):
    def replace_zig_block(match):
        indent = match.group(1)
        zig_code = match.group(2)
        return_expr = match.group(3)
        
        result = f"{indent}_zig = ZigRun()\n{indent}_result = _zig.run_code('''{zig_code}''')\n{indent}{return_expr}"
        return result

    return re.sub(
        r'^([ \t]*?)#Zig\(start\)([\s\S]*?)#Zig\(end:\s*(.*?)\)', 
        replace_zig_block, 
        code,
        flags=re.MULTILINE
    )

def transform_doc_comments(self, code):
    def replace_doc(match):
        indent = match.group(1)
        content = match.group(2)
        return f'{indent}"""\n{indent}{content}\n{indent}"""'

    return re.sub(
        r'^([ \t]*?)/!/\s*([\s\S]*?)/!/',
        replace_doc,
        code,
        flags=re.MULTILINE
    )

def transform_grouped_args(self, code):
    def replace_args(match):
        func_name = match.group(1)
        args_block = match.group(2)
        
        # Разбираем блок аргументов
        args = [arg.strip() for arg in args_block.split(',')]
        new_args = []
        
        for arg in args:
            if '->' in arg:
                name, type_block = arg.split('->')
                name = name.strip()
                # Извлекаем параметры из скобок
                params = type_block.strip()[1:-1]  # Убираем ( )
                new_args.append(f"{name}: dict")
        
        return f"def {func_name}({', '.join(new_args)}):"

    return GROUPED_ARGS_RE.sub(replace_args, code)


PROTECT_RE = re.compile(r'protect\s+(\w+)\s*{([\s\S]*?)}')

def transform_protect(self, code):
    def replace_protect(match):
        name = match.group(1)
        body = match.group(2)
        
        return f"""
class _{name}Protected:
    def __init__(self):
        self._protected_data = None
        
    def __get__(self, obj, objtype=None):
        if obj is None:
            return self
        return self._protected_data
        
    def __set__(self, obj, value):
        if not hasattr(obj, '_owner'):
            obj._owner = obj.__class__
        if obj._owner == obj.__class__:
            self._protected_data = value
        else:
            raise AttributeError('Protected attribute access denied')

{body}
"""
    
    return PROTECT_RE.sub(replace_protect, code)
