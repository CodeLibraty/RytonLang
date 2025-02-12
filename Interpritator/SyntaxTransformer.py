from functools import lru_cache
from textwrap import dedent

import re
import random

from .Effects import *
from .Pragma import *

from .ErrorHandler import *

# Предкомпиляция некоторых трансформаций синтаксиса
PROGRAMM_CLEANUP_RE = re.compile(r'programm\.cleanup\s*\{([\s\S]*?)\}')
GROUPED_ARGS_RE     = re.compile(r'func\s+(\w+)\s*\(\s*(.*?->.*?)\s*\)\s*:', re.DOTALL)

IMPORT_RE  = re.compile(r'module\s+import\s*\{([\s\S]*?)\}')
EVENT_RE   = re.compile(r'event\s+(\w+)\s*\{([\s\S]*?)\}')
WITH_RE    = re.compile(r'with\s+(\w+)\s*\{([\s\S]*?)\}')
LAZY_RE    = re.compile(r'lazy\s+(\w+)\s*=\s*(.*)')

class ClassTransformer:
    @lru_cache(maxsize=128)
    def transform_pack(self, code):
        return re.sub(r'pack \s*(\w+)\s*\(\s*(.*?)\s*\) :', r'class \1(\2):', code)

    @lru_cache(maxsize=128)
    def transform_pack2(self, code):
        return re.sub(r'pack \s*(\w+)\s* :', r'class \1:', code)

    @lru_cache(maxsize=128)
    def transform_init(self, code):
        def replace_init(match):
            indent = match.group(1)
            return f"{indent}def __init__(self):\n{indent}    "

        return re.sub(r'([ \t]*)init\s*:', replace_init, code)

    def transform_slots(self, code):
        def replace_slots(match):
            fields = match.group(1)
            return f"__slots__ = ({fields})"
        return re.sub(r'slots \{([\s\S]*?)\}', replace_slots, code)

    def transform_legasy_pack(self, code):
        def replace_children_pack(match):
            indent = match.group(1)
            name = match.group(2)
            super_class = match.group(3)
            meta_modifer = match.group(4) or ''

            return f"{indent}pack {name}({super_class}) {meta_modifer} :"
            
        return re.sub(r'([ \t]*)pack \s*(\w+)\s*\|(.*?)(?:\s+(.*?))? :', replace_children_pack, code)

    @lru_cache(maxsize=128)
    def transform_contracts_body(self, code):
        return re.sub(r'([ \t]*)body {\s*(.*?)\s*}', r'\n\1body {\2}', code)

    def transform_user_self(self, code):
        # Ищем все классы
        matches = list(re.finditer(r'pack\s+(\w+)\s*{', code))
        
        # Идем с конца, чтобы не сбить позиции при замене
        for match in reversed(matches):
            class_name = match.group(1)
            start = match.start()
            
            # Находим закрывающую скобку для этого класса
            bracket_count = 1
            pos = start + match.group(0).count('{')
            
            while bracket_count > 0 and pos < len(code):
                if code[pos] == '{':
                    bracket_count += 1
                elif code[pos] == '}':
                    bracket_count -= 1
                pos += 1
                
            # Заменяем this в найденном блоке
            class_block = code[start:pos]
            new_block = class_block.replace('this', class_name)
            code = code[:start] + new_block + code[pos:]
        
        return code

    def OOP_Transformation(self, code):
        # Гипер Функции
        hyperfunc_patterns = [
            r'hyperfunc\s+(\w+)\s*::\s*([\w\s\|]+)\s*' # hyperfunc name :: legacy|args
        ]

        for pattern in hyperfunc_patterns:
            matches = re.finditer(pattern, code)
            
            for match in matches:
                groups = match.groups()
                legacy = match.group(2).replace('|', ',')
                name = match.group(1)
                if len(groups) == 2:
                    template = f"@hyperfunc({legacy})\nclass {name}"
                
                code = re.sub(re.escape(match.group(0)), template, code)

        # Классы: с/без наследования, с/без метамодификаторов
        class_patterns = [
            r'pack\s+(\w+)\s+\:\:\s+(\w+)\s*!(.*?)\s* \{',    # pack Name::Parent !mod
            r'pack\s+(\w+)\s+\:\:\s+(\w+)',             # pack Name::Parent
            r'pack\s+(\w+)\s*!(.*?)\s* \{',             # pack Name !mod
            r'pack\s+(\w+)\s*',                   # pack Name
        ]
        
        for pattern in class_patterns:
            matches = re.finditer(pattern, code)
            for match in matches:
                groups = match.groups()
                if len(groups) == 3:  # С наследованием и модификатором
                    name, parent, mod = groups
                    template = f'@{mod}\nclass {name}({parent}) {'{'}'
                elif len(groups) == 2:
                    if '::' in match.group(0):  # Только наследование
                        name, parent = groups
                        template = f'class {name}({parent})'
                    else:  # Только модификатор
                        name, mod = groups
                        template = f'@{mod}\nclass {name} {'{'}'
                else:  # Только имя
                    name = groups[0]
                    template = f'class {name}'

                code = re.sub(re.escape(match.group(0)), template, code)

        # Функции: с/без аргументов, с/без метамодификаторов
        func_patterns = [
            r'func\s+(\w+)\s*\((.*?)\)\s*!(.*?)\s* \{',  # func name(args) !mod:
            r'func\s+(\w+)\s*\((.*?)\)\s* \{',           # func name(args):
            r'func\s+(\w+)\s*!(.*?)\s* \{',                # func name !mod:
            r'func\s+(\w+)\s* \{'                          # func name:
        ]

        for pattern in func_patterns:
            matches = re.finditer(pattern, code)
            for match in matches:
                groups = match.groups()
                if len(groups) == 3:  # С аргументами и модификатором
                    name, args, mod = groups
                    mods = list(mod.split('|'))
                    modificators = ''
                    for mod in mods:
                        modificators += f'@{mod}\n'
                    template = f'\n{modificators}def {name}({args}) {"{"}'

                elif len(groups) == 2:
                    if '(' in match.group(0):  # Только аргументы
                        name, args = groups
                        template = f'\ndef {name}({args}) {"{"}'
                    else:  # Только модификатор
                        name, mod = groups
                        mods = list(mod.split('|'))
                        modificators = ''
                        for mod in mods:
                            modificators += f'@{mod}\n'
                        template = f'\n{modificators}def {name}() {"{"}'
                elif len(groups) == 1:  # Без аргументов и модификаторов
                    name = groups[0]
                    template = f'\ndef {name}() {"{"}'
                
                code = re.sub(re.escape(match.group(0)), template, code)

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



    def transform_data(self, code):
        def replace_data(match):
            name = match.group(1)
            fields = match.group(2)

            return f"@dataclass\npack {name} {'{'}{fields}{'}'}"
        return re.sub(r'data (\w+) \{([\s\S]*?)\}', replace_data, code)

    def transform_read(self, code):
        def replace_read(match):
            indent = match.group(1)
            obj1 = match.group(2)
            obj2 = match.group(3)
            name = match.group(4)
            return f"{indent}@readonly\n{indent}{obj2} {name}"
        return re.sub(r'([ \t]*)(read|validate) (func|pack) (.*?)', replace_read, code)

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

    def transform_with(self, code):
        def replace_with(match):
            resource = match.group(1)
            body = match.group(2)
            return f"with {resource}:\n{body}"
        return WITH_RE.sub(replace_with, code)



class FunctionTransformer:
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

    def transform_contracts(self, code):
        def replace_contract(match):
            contract_name = match.group(1)
            body = match.group(2)
            
            result = [f"class {contract_name}(Contract):"]
            
            for line in body.split('\n'):
                line = line.strip()
                if line.startswith('pre:'):
                    condition = line[4:].strip()
                    result.append(f"    @Contract.pre_condition(lambda *args: {condition})")
                elif line.startswith('post:'):
                    condition = line[5:].strip()
                    result.append(f"    @Contract.post_condition(lambda result: {condition})")
                elif line.startswith('invariant:'):
                    condition = line[10:].strip()
                    result.append(f"    @Contract.invariant(lambda: {condition})")

            # Добавляем метод validate, который будет декорирован условиями
            result.append("    def validate(self):")
            result.append("        return True")

            return '\n'.join(result)

        return re.sub(r'contract\s+(\w+)\s*:\s*([\s\S]*?)(?=\n\S|$)', replace_contract, code)

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

    def transform_lambda(self, code):
        def replace_lambda(match):
            params = match.group(1)
            body = match.group(2)
            body = body.replace('\n', '')

            return f"lambda {params}: {body}"
        return re.sub(r'func\s*\((.*?)\)\s*\{([\s\S]*?)\}', replace_lambda, code)

    def transform_func_oneline(self, code):
        def replace_func(match):
            indent = match.group(1)
            name = match.group(2)
            params = match.group(3)
            body = match.group(4)

            return f"{indent}func {name}({params}) :\n{indent}    {body}\n"
        return re.sub(r'([ \t]*)func\s*(\w+)\s*\((.*?)\)\s* => ([\s\S]*?)\n', replace_func, code)

    @lru_cache(maxsize=128)
    def transform_func(self, code):
        return re.sub(r'func \s*(\w+)\s*\(\s*(.*?)\s*\) :', r'def \1(\2): ', code)

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

        code = re.sub(r'\n<\s*(.*?)\s*>',
                    r'\n@\1', code)

        return code

    @lru_cache(maxsize=128)
    def transform_func3(self, code):
        return re.sub(r'func \s*(\w+)\s*\(\s*(.*?)\s*\) -> \s*(.*?)\s*:', r'def \1(\2) -> \3:', code)

    # Трансформация вызова функции с массивом
    def transform_func_massive(self, code):
        code = re.sub(r'(\w+)\[(.*?)\]', r'\1(*[\2])', code)
        return code


    def transform_meta_modifiers(self, code):
        # Словарь соответствия модификаторов и декораторов
        META_MODIFIERS = {
            # Для классов (pack)
            'slots':     '@dataclasses.dataclass(slots=True)',
            'frozen':    '@dataclasses.dataclass(frozen=True)',
            'final':     '@final',
            'singleton': '@singleton',
            'interface': '@abc.abstractmethod',
            'immutable': '@immutable',
            
            # Для функций (func)
            'async':       '@asyncio.coroutine',
            'pure':        '@pure_function',
            'deprecated':  '@deprecated',
            'timeout':     '@timeout(seconds=5)',
            'retry':       '@retry(attempts=3)',
            'trace':       '@trace_calls',
            'validate':    'validate_params',
            'cached':      'cached(maxsize=128)',
            'profile':     'profile',
            'logged':      'logged',
            'metrics':     'metrics',
            'retry':       'retry(attempts=3)',
            'safe':        'safe_execution',
            'transaction': 'transactional',
            'limit':       'resource_limit',

            # Для типизации функций
            'String':  'typing("String")',
            'Int':     'typing("Int")',
            'Float':   'typing("Float")',
            'Boolean': 'typing("Boolean")',
            'List':    'typing("List")',
            'Dict':    'typing("Dict")',
            'Tuple':   'typing("Tuple")',
            'Set':     'typing("Set")',
            'Union':   'typing("Union")',
        }
        
        def replace_modifier(match):
            modifier = match.group(1)
            
            if modifier in META_MODIFIERS:
                modifer = META_MODIFIERS[modifier]
                return f"@{modifer}\n"
                
            return match.group(0)
        
        return re.sub(r'\@(.*?)\n', replace_modifier, code)

    def transform_hyperfunc(self, code: str) -> str:
        # Паттерн для поиска объявления гиперфункции
        pattern = r'hyperfunc\s+(\w+)\s*:\s*([\w\s|]+)\s*{([^}]*)}'
        
        def transform_match(match):
            name = match.group(1)
            bases = [b.strip() for b in match.group(2).split(',')]
            body = match.group(3)
            
            # Формируем Python код
            return f"""@hyperfunc({', '.join(bases)})
    class {name} {'{'}\n{body}{'}'}"""

        # Заменяем все найденные гиперфункции
        return re.sub(pattern, transform_match, code)

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

    def transform_decorator_syntax(self, code):
        return re.sub(r'\n<\s*(\w+)\s*>\nfunc', r'\n@\1\nfunc', code, flags=re.DOTALL)

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



class ControlFlowTransformer:
    @lru_cache(maxsize=128)
    def transform_parallel_sub(self, code):
        return re.sub(r'([ \t]*)parallel {\s*([\s\S]*?)\s*}', r'\n\1parallel(\2)', code)

    def transform_switch(self, code):
        def replace_match(match):
            value = match.group(1)
            cases = match.group(2)

            result = f"def _pattern_match():\n"
            result += f"    _value = {value}\n"

            for case in cases.strip().split('\n'):
                if not case.strip():
                    continue

                if case.startswith('|'):
                    pattern = case.split('=>')[0].replace('|', '').strip()
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
                elif case.startswith('else'):
                    action = case.split('=>')[1].strip()
                    result += f"    else:\n        return {action}\n"

            result += "_pattern_match()"
            return result

        return re.sub(r'switch\s+(.+?)\s*\{([\s\S]*?)\}', replace_match, code)

    def transform_reactive(self, code):
        def replace_stream(match):
            indent = match.group(1)
            stream_var = match.group(2)
            operations = match.group(3)
            target = match.group(4)
            
            stream_code = f"{indent}{stream_var}.stream()"
            
            for line in operations.split('\n'):
                line = line.strip()
                if line.startswith('filter'):
                    cond = line[7:-1]  # Убираем filter()
                    stream_code += f".filter(lambda e: {cond})"
                elif line.startswith('transform'):
                    trans = line[10:-1]  # Убираем transform()
                    stream_code += f".map(lambda e: {trans})"
            
            stream_code += f".subscribe({target})"
            return stream_code

        return re.sub(r'([ \t]*)(\w+)\.stream\s*\{([\s\S]*?)\}\s*->\s*(\w+)', replace_stream, code)

    @lru_cache(maxsize=128)
    def transform_elerr(self, code):
        return re.sub(r'try {\s*(.*?)\s*} elerr {\s*(.*?)\s*}', r'try: \1 except: \2', code)

    @lru_cache(maxsize=128)
    def transform_elerr2(self, code):
        return re.sub(r'try {\s*(.*?)\s*} elerr \s*(.*?)\s* {\s*(.*?)\s*}', r'try: \1 except \2: \3', code)

    def transform_repeat(self, code):
        def replace_repeat(match):
            indent = match.group(1)
            count = match.group(2)
            delay = match.group(3)
            return f"{indent}for _ in range({count}):\n{indent}    timexc.sleep({delay})\n{indent}    "

        return re.sub(r'([ \t]*)repeat\s*(.*?)\s* \s*(.*?)\s* :', replace_repeat, code)

    def transform_debug_blocks(self, code):
        def replace_block(match):
            block_name = match.group(1)
            start_line = code[:match.start()].count('\n') + 1
            return f'Core.error_handler.register_block("{block_name}", {start_line})\n'

        return re.sub(r'#block\(([^)]+)\)', replace_block, code)

    def transform_block_end(self, code):
        def replace_end(match):
            end_line = code[:match.start()].count('\n') + 1
            return f'Core.error_handler.end_block({end_line})\n'

        return re.sub(r'#end_block', replace_end, code)

    def transform_event(self, code):
        def replace_event(match):
            indent = match.group(1)
            item1 = match.group(2)
            item2 = match.group(3)
            code = match.group(4)

            result = f"start_event({item1}, {item2}, {code})\n"
            return result

        return re.sub(r'([ \t]*)event \s*(.*?)\s* -> \s*(.*?)\s* {\s*([\s\S]*?)\s*}', replace_event, code)

    def transform_infinit(self, code):
        def replace_infinit(match):
            indent = match.group(1)
            delay = match.group(2)
            return f"{indent}while True: \n{indent}    timexc.sleep({delay})\n{indent}    "

        return re.sub(r'([ \t]*)infinit\s*(.*?)\s*:', replace_infinit, code)

    def transform_elif(self, code):
        return re.sub(r'} elif \s*(.*?)\s* :', r'elif \1:', code)

    def transform_elerr3(self, code):
        return re.sub(r'elerr \s*(.*?)\s* :', r'except \1:', code)

    def transform_elerr4(self, code):
        return re.sub(r'elerr :', r'except :', code)

    def transform_one_line_try_elerr(self, code):
        return re.sub(r'([ \t]*)try\s*{([^}]*?)}\s*elerr\s*(.*?)\s*{([^}]*?)}', r'\1try:\1    \2\n\1except \3:\n\1   \4', code)

    def transform_one_line_try(self, code):
        return re.sub(r'([ \t]*)try\s*{([^}]*?)}', r'\1try: \2\n\1except:\n\1    pass', code)

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



class ModuleTransformer:
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

    def transform_package_import(self, code):
        pattern = r'package\s+import\s*{([^}]*)}'
        
        def process_imports(match):
            imports = match.group(1).strip()
            result = []
            
            for line in imports.split('\n'):
                line = line.strip()
                if not line:
                    continue
                    
                if line.startswith('ziglib:'):
                    pkg = line.split('ziglib:')[1].strip()
                    result.append(f'{pkg} = ZigBridge(Core.currect_src_dir() / "module" / "zig").import_zig_module(module_name="{pkg}")')
                else:
                    # Default Ryton package import
                    result.append(f'{line} = Core.import_package("{line}")')
                    
            return '\n'.join(result)
        
        return re.sub(pattern, process_imports, code)

    @lru_cache(maxsize=128)
    def transform_pylib(self, code):
        return re.sub(r'pylib: \s*(\w+)\s*', r'import \1\n', code)

    def transform_jvmlib(self, code):
        def replace_jvmlib(match):
            module_path = match.group(1)
            alias = match.group(2)
            return f"""
{alias} = gateway.jvm.{module_path}
    """
        return re.sub(r'jvmlib:\s*([^\s]+)\s+as\s+(\w+)', replace_jvmlib, code)

    def transform_zig_tags(self, code):
        pattern = r'#Zig\(start\)([\s\S]*?)#Zig\(end:\s*([^)]*)\)'
        
        def replace(match):
            base_indent = "    "  # Base indentation level
            zig_code = match.group(1).strip()
            return_var = match.group(2).strip()
            
            result = [
                f"# zig code start",
                f"{base_indent}#raw(start)",
                f"{base_indent}zig_bridge = ZigBridge()",
                f"{base_indent}{return_var} = zig_bridge.compile_and_run(",
                f"{base_indent}    zig_code='''\n{zig_code}''',mode='run',cache=True",
                f"{base_indent})\n"
                f"{base_indent}#raw(end)",
            ]
            
            return '\n'.join(result)

        return re.sub(pattern, replace, code)

    def transform_zig_export(self, code):
        def process_zig_block(match):
            base_indent = match.group(1)
            zig_code = match.group(2)
            module_name = match.group(3)
            
            # Добавляем export для C ABI
            exports = []
            for fn_match in re.finditer(r'pub fn (\w+)\((.*?)\)(.*?){', zig_code):
                fn_name = fn_match.group(1)
                
            modified_code = zig_code.replace(f'pub fn', 'export fn') + "\n" + "\n".join(exports)

            result = [
                f"# zig code start",
                f"{base_indent}#raw(start)",
                f"{base_indent}zig_bridge = ZigBridge(Core.currect_src_dir())",
                f"{base_indent}{module_name} = zig_bridge.load_functions('''{modified_code}''', '{module_name}')",
                f"{base_indent}#raw(end)",
            ]

            return '\n'.join(result)

        return re.sub(r'([ \t]*)#ZigModule\(([\s\S]*?)\)\s*->\s*(\w+)', process_zig_block, code)



class ExpressionTransformer:
    def transform_range_syntax(self, code):
        code = re.sub(r'(\d+)\.\.\.(\d+)', r'range(\1, \2)', code)
        code = re.sub(r'(\d+)\.\.(\d+)', r'range(\1, \2 + 1)', code)
        return code

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



class DataTransformer:
    def transform_lazy(self, code):
        def replace_lazy(match):
            var_name = match.group(1)
            expression = match.group(2)
            return f"{var_name} = lambda: {expression}"
        return LAZY_RE.sub(replace_lazy, code)

    def transform_metatable(self, code):
        return re.sub(r'table\s+([\s\S]*?)\s*<\{([\s\S]*?)\}>', 
                    lambda m: f"{m.group(1)} = MetaTable({{{m.group(2)}}})", code)

    @lru_cache(maxsize=128)
    def transform_table(self, code):
        def replace_table(match):
            table_name = match.group(1)
            table_body = match.group(2)
            print(table_body)
            
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
            return f"#raw(start)\n{table_name} = MetaTable({{{table_content}}})\n#raw(end)"

        return re.sub(r'table\s+([\s\S]*?)\s*\{\s*([\s\S]*?)\s*\}', replace_table, code)

    @lru_cache(maxsize=128)
    def protect_tables(self, code):
        def pack_table(match):
            table_name = match.group(1)
            content = match.group(2)
            
            # Просто убираем переносы строк, сохраняя всю структуру
            single_line = content.replace('\n', '').strip()
            
            return f"{table_name} = {{{single_line}}}"
        
        return re.sub(r'table\s+(\w+)\s*=\s*\{([\s\S]*?)\}', pack_table, code)

    def transform_config_blocks(self, code):
        def parse_config_section(lines, indent=0):
            result = {}
            i = 0
            while i < len(lines):
                line = lines[i].strip()
                if not line:
                    i += 1
                    continue
                    
                if '{' in line and ':' not in line:
                    section_name = line.replace('{', '').strip()
                    section_content = []
                    brace_count = 1
                    i += 1
                    
                    while i < len(lines) and brace_count > 0:
                        if '{' in lines[i]: brace_count += 1
                        if '}' in lines[i]: brace_count -= 1
                        if brace_count > 0:
                            section_content.append(lines[i])
                        i += 1
                        
                    result[section_name] = parse_config_section(section_content)
                elif ':' in line:
                    key, value = line.split(':', 1)
                    result[key.strip()] = value.strip().rstrip(',')
                i += 1
            return result

        def format_dict(d, indent=1):
            lines = ['{']
            for key, value in d.items():
                if isinstance(value, dict):
                    dict_str = format_dict(value, indent + 1)
                    lines.append(f"{'    ' * indent}'{key}': {dict_str},")
                else:
                    lines.append(f"{'    ' * indent}'{key}': {value},")
            lines.append('    ' * (indent-1) + '}')
            return '\n'.join(lines)

        def replace_config(match):
            config_name = match.group(1)
            config_body = match.group(2)
            
            # Парсим конфигурацию в словарь
            config_dict = parse_config_section(config_body.split('\n'))
            
            # Форматируем MetaTable
            config_str = format_dict(config_dict)
            
            return f"""#raw(start)
{config_name} = MetaTable({config_str})
    #raw(end)
    class {config_name} {'{'}
        _instance = None
        _config = _{config_name}_CONFIG
        
        @classmethod
        def get(cls, key=None) {'{'}
            if key {'{'}
                return cls._config[key]
            {'}'}
            return cls._config
        {'}'}
            
        @classmethod
        def __getattr__(cls, key) {'{'}
            return cls._config[key]
        {'}'}
    {'}'}"""

        return re.sub(r'config\s+(\w+)\s*\{([\s\S]*?)\}', replace_config, code)



class Comments:
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

    def transform_comm_syntax(self, code):
        return re.sub(r'</\s*(.*?)\s*/>', r'', code, flags=re.DOTALL)


comments = Comments()
data = DataTransformer()
expression = ExpressionTransformer()
module = ModuleTransformer()
controlflow = ControlFlowTransformer()
Function = FunctionTransformer()
Class = ClassTransformer()

def protect_raw_blocks(code):
    preserved_blocks = {}
    counter = 0
    
    raw_pattern = r'#raw\(start\)(.*?)#raw\(end\)'
    
    matches = list(re.finditer(raw_pattern, code, re.DOTALL))
    for match in matches:
        key = f'RAWBLOCK_{counter}_ENDRAW'
        content = match.group(1)
        preserved_blocks[key] = content
        start = match.start()
        end = match.end()
        code = code[:start] + key + code[end:]
        counter += 1
        
    return code, preserved_blocks

def restore_language_blocks(code, preserved_blocks):
    # Восстанавливаем сохраненные блоки
    for key, block in preserved_blocks.items():
        code = code.replace(key, block)
    return code

def transform_defer(code):
    # Следом Обработка меж-языковых тегов и импортов
    code = module.transform_zig_tags(code)
    code = module.transform_zig_export(code)
    code = data.transform_config_blocks(code)

    # Сохраняем блоки кода других языков
    protected_code, raw_blocks = protect_raw_blocks(code)

    return protected_code, raw_blocks

def transform(code, raw_blocks):
    # Вызываем методы из классов

    code = Function.transform_macro(code)
    code = Class.transform_user_self(code)
    code = Class.OOP_Transformation(code)
    code = Function.transform_meta_modifiers(code)
    code = controlflow.transform_reactive(code)
    code = Function.transform_lambda(code)
    code = expression.transform_special_operators(code)
    code = controlflow.transform_event(code)
    code = expression.transform_dots_syntax(code)
    code = Class.transform_contracts_body(code)
    code = Class.transform_struct(code)
    code = module.transform_package_import(code)
    code = data.protect_tables(code)

    code = controlflow.transform_switch(code)

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

    replacements2 = {
        'noop': 'pass',
        '&':    'and',
        '//':   '#',
    }

    for old, new in replacements2.items():
        code = code.replace(old, new)

    code = Function.transform_decorators(code)

    # Трансформация синтаксиса с правильными вызовами
    
    #code = data.transform_metatable(code)
    #code = data.transform_table(code)
    code = module.transform_import_modules(code)
    code = Function.transform_grouped_args(code)
    code = comments.transform_doc_comments(code)
    code = Function.transform_contracts(code)
    code = controlflow.transform_debug_blocks(code)
    code = controlflow.transform_block_end(code)
    code = Function.process_decorators(code)
    code = module.transform_jvmlib(code)
    code = Function.transform_contracts(code)
    code = Class.transform_data(code)
    code = Class.transform_private(code)
    code = data.transform_lazy(code)

    code = controlflow.transform_one_line_try_elerr(code)
    code = controlflow.transform_one_line_try(code)
    code = controlflow.transform_elerr(code)
    code = controlflow.transform_elerr2(code)
    code = controlflow.transform_elerr3(code)
    code = controlflow.transform_elerr4(code)
    code = module.transform_pylib(code)
    code = Class.transform_read(code)
    code = Function.transform_func_oneline(code)
    code = Function.transform_func3(code)
    code = Function.transform_func2(code)
    code = Class.transform_pack2(code)
    code = Function.transform_func(code)
    code = Class.transform_pack(code)
    code = Class.transform_slots(code)
    code = Class.transform_legasy_pack(code)
    code = Class.transform_init(code)
    code = controlflow.transform_infinit(code)
    code = controlflow.transform_repeat(code)
    code = expression.transform_default_assignment(code)
    code = expression.transform_range_syntax(code)
    code = comments.transform_comm_syntax(code)
    code = Function.transform_decorator_syntax(code)
    code = expression.transform_pipe_operator(code)
    code = expression.transform_spaceship_operator(code)
    code = expression.transform_function_composition(code)
    code = expression.transform_unpacking(code)
    code = controlflow.transform_elif(code)

    # Теперь восстанавливаем raw блоки        
    for key, content in raw_blocks.items():
        code = code.replace(key, content)

    return code