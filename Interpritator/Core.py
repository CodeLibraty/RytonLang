from importlib import import_module
from functools import lru_cache
from collections import deque

import contextlib
import threading
import traceback
import inspect
import difflib
import pstats
import random

import types
import time
import dis
import sys
import re
import io
import os
import gc

from .ErrorHandler import *

from .Effects import *
from .Pragma import *

from .SyntaxAnalyzer import *
from .SyntaxTransformer import *
from .MemoryManager import MemoryManager
from .PackageSystem import PackageSystem


# Предкомпиляция и кэширование регулярных выражений
TRASH_CLEANER_RE  = re.compile(r'trash_cleaner\s*=\s*(true|false)')


class SharpyLang:
    __slots__ = (
        'globals', 'effect_registry', 'pragma_handler',
        'error_handler', 'static_typing', 'syntax_analyzer',
        'compiled_functions', 'package_system', 'dsls',
        'PACKAGE_IMPORT_RE', 'imported_libs', 'user_vars',
        'transformation_cache', 'IMPORT_RE', 'compiled_cache', 
        'memory_manager', 'trash_cleaner', 'module_mapping'
    )

    def __init__(self):
        self.imported_libs = set()
        self.transformation_cache = {}
        self.compiled_functions   = {}
        self.compiled_cache       = {}
        self.user_vars            = {}
        self.globals              = {}
        self.dsls                 = {}

        self.static_typing = False
        self.trash_cleaner = True

        self.IMPORT_RE         = re.compile(r'module\s+import\s*\{([\s\S]*?)\}')
        self.PACKAGE_IMPORT_RE = re.compile(r'package\s+import\s*\{([\s\S]*?)\}')

        self.error_handler    = RytonErrorHandler()
        self.effect_registry  = EffectRegistry()
        self.syntax_analyzer  = SyntaxAnalyzer()
        self.pragma_handler   = PragmaHandler()
        self.package_system   = PackageSystem()
        self.memory_manager   = MemoryManager()
        self.module_mapping   = {
            'ZigLang': 'ZigLang',       'ZigLang.Bridge': 'ZigLang.Bridge',
            'std':   'std',

            'std.HyperConfigFormat':   'std.HyperConfigFormat',
            'std.RuVix.Effects':       'std.RuVix.Effects',
            'std.RuVix.App':           'std.RuVix.App,pygame',

            'TrixD':           'TrixD',
            'std.lib':         'std.lib',          'std.DSL':         'std.DSL',
            'std.UpIO':        'std.UpIO',         'std.Rask':        'std.Rask',
            'std.Math':        'std.Math',         'std.RandoMizer':  'std.RandoMizer',
            'std.RytonDB':     'std.RytonDB',      'std.Terminal':    'std.Terminal',
            'std.JITCompiler': 'std.JITCompiler',  'std.RuVix':       'std.RuVix',
            'std.Path':        'std.Path',         'std.Files':       'std.Files',
            'std.String':      'std.String',       'std.DateTime':    'std.DateTime',
            'std.Archive':     'std.Archive',      'std.DeBugger':    'std.DeBugger',
            'std.ErroRize':    'std.ErroRize',     'std.RuVixCore':   'std.RuvVixCore',
            'std.Algorithm':   'std.Algorithm',    'std.System':      'std.System',
            'std.DocTools':    'std.DocTools',     'std.MatplotUp':   'std.MatplotUp',
            'std.NeuralNet':   'std.NeuralNet',    'std.Media':       'std.Media',
            'std.NetWorker':   'std.NetWorker',    'std.Tuix':        'std.Tuix',
            'std.MetaTable':   'std.MetaTable',    'std.ProgRessing': 'std.ProgRessing',
            'std.ColoRize':    'std.ColoRize',     'std.RunTimer':    'std.RunTimer',
        }

        # Настройки сборщика мусора
        gc.enable()
        gc.set_threshold(1000, 15, 10)

    class ContractError(Exception):
        pass

    def process_package_import(self, package_name, specific_imports=None):
        try:
            package_exports = self.package_system.load_package(package_name, self)
            if specific_imports:
                for item in specific_imports:
                    if item in package_exports:
                        self.globals[item] = package_exports[item]
                    else:
                        raise ImportError(f"'{item}' not found in package '{package_name}'")
            else:
                self.globals.update(package_exports)
        except ImportError as e:
            print(f"Import Error: {e}")

    @lru_cache(maxsize=128)
    def compile_to_bytecode(self, func_name, func_code):
        try:
            # Трансформируем код функции
            transformed_code = self.transform_syntax(func_code)
            
            # Компилируем в байткод
            code_object = compile(transformed_code, f'<{func_name}>', 'exec')
            
            # Извлекаем функцию из скомпилированного кода
            namespace = {}
            exec(code_object, namespace)
            compiled_func = namespace[func_name]
            
            # Создаем новую функцию с байткодом
            new_func = types.FunctionType(compiled_func.__code__, compiled_func.__globals__, name=func_name)
            
            # Оптимизируем байткод
            optimized_code = self.optimize_bytecode(new_func.__code__)
            optimized_func = types.FunctionType(optimized_code, new_func.__globals__, name=func_name)
            
            # Сохраняем скомпилированную функцию
            self.compiled_functions[func_name] = optimized_func
            
            return optimized_func
        except Exception as e:
            raise RytonError(f"Error compiling function '{func_name}': {str(e)}")

    @staticmethod
    @lru_cache(maxsize=128)
    def optimize_bytecode(code):
        # Пример простой оптимизации: удаление NOP инструкций
        instructions = list(dis.get_instructions(code))
        optimized_instructions = [instr for instr in instructions if instr.opname != 'NOP']
        
        # Пересоздаем код-объект с оптимизированными инструкциями
        new_code = types.CodeType(
            code.co_argcount, code.co_posonlyargcount,
            code.co_kwonlyargcount, code.co_nlocals,
            code.co_stacksize, code.co_flags,
            dis.Bytecode(optimized_instructions).codeobj.co_code,
            code.co_consts, code.co_names, code.co_varnames,
            code.co_filename, code.co_name, code.co_firstlineno,
            code.co_lnotab, code.co_freevars, code.co_cellvars
        )
        return new_code

    @lru_cache(maxsize=128)
    def call_compiled_function(self, func_name, *args, **kwargs):
        if func_name in self.compiled_functions:
            start_time = time.time()
            self.profiler.enable()
            result = self.compiled_functions[func_name](*args, **kwargs)
            self.profiler.disable()
            end_time = time.time()
            print(f"Execution time of '{func_name}': {end_time - start_time:.6f} seconds")
            return result
        else:
            raise RytonError(f"Compiled function '{func_name}' not found")

    def compile_to_bytecode_decorator(self, func_name):
        def decorator(func):
            compiled_func = self.compile_to_bytecode(func_name, inspect.getsource(func))
            return compiled_func
        return decorator

    def protect_raw_blocks(self, code):
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

    def restore_language_blocks(self, code, preserved_blocks):
        # Восстанавливаем сохраненные блоки
        for key, block in preserved_blocks.items():
            code = code.replace(key, block)
        return code

    @lru_cache(maxsize=128)
    def transform_syntax(self, code):
        # Следом Обработка меж-языковых тегов и импортов
        code = transform_zig_tags(self, code)
        # Сохраняем блоки кода других языков
        protected_code, raw_blocks = self.protect_raw_blocks(code)

        # Потом Уже проверяем синтаксис
        self.syntax_analyzer.analyze(code)
    
        # Обработка импортов библиотек
        code = protected_code
        code = self.IMPORT_RE.sub(self.process_imports, code)
        code = self.PACKAGE_IMPORT_RE.sub(self.process_package_imports, code)

        # Кэширование трансформаций
        code_hash = hash(code)
        if code_hash in self.transformation_cache:
            return self.transformation_cache[code_hash]

        # Обработка static_typing
        match = re.search(r'static_typing\s*=\s*(true|false)', code)
        if match:
            self.static_typing = match.group(1) == 'true'
            code = re.sub(r'static_typing\s*=\s*(true|false)', '', code)

        # Обработка trash_cleaner
        match = TRASH_CLEANER_RE.search(code)
        if match:
            self.trash_cleaner = match.group(1) == 'true'
            code = TRASH_CLEANER_RE.sub('', code)

        # Замены синтаксиса
        replacements = {
            '} else {':  '}\nelse {',
            '} elerr ':  '}\nelerr ',
            '} elif ':   '}\nelif ',
            '} func':    '}\nfunc',

            '\n})':   '})',
            ', {\n':  ', {',
            '({\n':   '({',
            ': {\n':  ': {'
        }
        for old, new in replacements.items():
            code = code.replace(old, new)

        code = re.sub(r'\n\}\)', r'\}\)', code)

        code = transform_macro(self, code)
        code = transform_state_machine(self, code)
        code = transform_intercept(self, code)
#        code = transform_chain(self, code)

        code = transform_reactive(self, code)
        code = transform_lambda(self, code)
        code = transform_special_operators(self, code)
        code = transform_user_self(self, code)
        code = transform_event(self, code)
        code = transform_guard(self, code)
        code = transform_defer(self, code)
        code = transform_dots_syntax(self, code)
        code = transform_contracts_body(self, code)
        code = transform_struct(self, code)
        code = protect_tables(self, code)
        code = transform_metatable(self, code)
        code = transform_table(self, code)

        # Обычная обработка скобок
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

        code = transform_decorators(self, code)

        # Быстрая трансформация
        code = re.sub(r'\buntil\s*\((.*?)\)\s* :', r'while not (\1):', code)
        code = re.sub(r'\bforeach\s*(\w+)\s*in\s*(\w+)\s* :', r'for \1 in \2:', code)
        code = re.sub(r'\bswitch\s*\((.*?)\)\s* :', r'match \1:', code)
        code = re.sub(r'\bcase\s*(.*?) :', r'case \1:', code)
        code = re.sub(r'use\s+(\w+)\s*\{([\s\S]*?)\}', use_dsl_replacement, code)
        code = re.sub(r'create_dsl\s+(\w+)\s*\{([\s\S]*?)\}', create_dsl_replacement, code)

        # Трансформация синтаксиса
        code = transform_import_modules(self, code)
        code = transform_grouped_args(self, code)
        code = transform_doc_comments(self, code)
        code = transform_contracts(self, code)
        code = transform_debug_blocks(self, code)
        code = transform_block_end(self, code)
        code = process_decorators(self, code)
        code = transform_clib(self, code)
        code = transform_jvmlib(self, code)
        code = transform_contracts(self, code)
        code = transform_match(self, code)
        code = transform_neural(self, code)
        code = transform_with(self, code)
        code = transform_data(self, code)
        code = transform_prop(self, code)
        code = transform_private(self, code)
        code = transform_void(self, code)
        code = transform_func_massive(self, code)
        code = transform_lazy(self, code)
        code = transform_match(self, code)
        code = transform_programm_cleanup(self, code)
        code = transform_run_lang(self, code)
        code = transform_elerr(self, code)
        code = transform_elerr2(self, code)
        code = transform_elerr3(self, code)
        code = transform_elerr4(self, code)
        code = transform_pylib(self, code)
        code = transform_protect(self, code)
        code = transform_read(self, code)
        code = transform_func_oneline(self, code)
        code = transform_func3(self, code)
        code = transform_func2(self, code)
        code = transform_pack2(self, code)
        code = transform_func(self, code)
        code = transform_pack(self, code)
        code = transform_slots(self, code)
        code = transform_meta_modifiers(self, code)
        code = transform_info_programm(self, code)
        code = transform_start_programm(self, code)
        code = transform_init(self, code)
        code = transform_infinit(self, code)
        code = transform_repeat(self, code)
        code = transform_default_assignment(self, code)
        code = transform_range_syntax(self, code)
        code = transform_comm_syntax(self, code)
        code = transform_decorator_syntax(self, code)
        code = transform_pipe_operator(self, code)
        code = transform_spaceship_operator(self, code)
        code = transform_function_composition(self, code)
        code = transform_unpacking(self, code)
        code = transform_elif(self, code)

        # Теперь восстанавливаем raw блоки        
        for key, content in raw_blocks.items():
            code = code.replace(key, content)

        self.transformation_cache[code_hash] = code

        return code

    def check_types(self, func_name, args, annotations):
        if not self.static_typing:
            return
        for arg_name, arg_value in args.items():
            if arg_name in annotations:
                expected_type = annotations[arg_name]
                if not isinstance(arg_value, expected_type):
                    raise RytonTypeError(f"Argument '{arg_name}' in function '{func_name}' expected {expected_type}, but got {type(arg_value)}")

    @staticmethod
    @lru_cache(maxsize=128)
    def optimize_string_concat(*strings):
        return ''.join(strings)

    def import_package(self, package_name):
        exports = self.package_system.load_package(package_name, self)
        module = type('Package', (), exports)
        # Создаём модуль и сразу возвращаем его
        return module

    @lru_cache(maxsize=128)
    def process_imports(self, match):
        imports = match.group(1).split()
        python_imports = ['']

        for imp in imports:
            imp = imp.strip()
            if ':' in imp:
                ryton_module, alias = imp.split(':', 1)
                ryton_module = ryton_module.strip()
                alias = alias.strip()
            else:
                ryton_module = imp
                alias = None

            # Разделяем путь к модулю и имя импортируемого объекта
            module_parts = ryton_module.split('.')
            module_path = '.'.join(module_parts[:-1])
            import_name = module_parts[-1]

            if module_path in self.module_mapping:
                python_module = self.module_mapping[module_path]

                if '.' in python_module:
                    module, submodule = python_module.split('.', 1)
                    if alias:
                        python_imports.append(f"from {module} import {submodule} as {alias}\n")
                    else:
                        if import_name != submodule:
                            python_imports.append(f"from {python_module} import {import_name}\n")

                elif '.' in python_module:
                    module, submodule = python_module.split('.', range(2, 99))
                    if alias:
                        python_imports.append(f"from {module} import {submodule} as {alias}\n")
                    else:
                        if import_name != submodule:
                            python_imports.append(f"from {python_module} import {import_name}\n")

                else:
                    if alias:
                        python_imports.append(f"from {python_module} import {import_name} as {alias}\n")
                    else:
                        python_imports.append(f"from {python_module} import {import_name}\n")

                self.imported_libs.add(module_path)
            else:

                print(f"ModuleError: Module '{module_path}' not found")
                sys.exit(1)

        return ''.join(python_imports)

    def process_package_imports(self, match):
        imports = match.group(1).split()
        python_imports = ['system.path.insert(0, osystem.getcwd())\n']

        for imp in imports:
            imp = imp.strip()
            if ':' in imp:
                ryton_module, alias = imp.split(':', 1)
                ryton_module = ryton_module.strip()
                alias = alias.strip()
            else:
                ryton_module = imp
                alias = None

            module_parts = ryton_module.split('.')
            module_path = '.'.join(module_parts[:-1])
            import_name = module_parts[-1]

            if '.' in module_path:
                module, submodule = module_path.split('.', 1)
                if alias:
                    python_imports.append(f"from {module} import {submodule} as {alias}\n")
                else:
                    if import_name != submodule:
                        python_imports.append(f"from {module_path} import {import_name}\n")
            else:
                if alias:
                    python_imports.append(f"from {module_path} import {import_name} as {alias}\n")
                else:
                    python_imports.append(f"from {module_path} import {import_name}\n")

        return ''.join(python_imports)

    def compile(self, code, output_file):
        # Трансформируем синтаксис
        transformed_code = self.transform_syntax(code)
        
        # Добавляем необходимые импорты
        imports = '''
from functools import *
from typing import *
from stdFunction import *

from jpype import *
from cffi import FFI
import ctypes.util

import os as osystem
import sys as system
import time as timexc
import threading
from asyncio import *

parallel = Parallel().parallel()
        '''
        
        final_code = imports + transformed_code + '\nMain()'
        
        # Компилируем в байткод
        bytecode = compile(final_code, output_file, 'exec')
        
        # Сохраняем байткод в файл
        import marshal
        with open(output_file + '.ryc', 'wb') as f:
            marshal.dump(bytecode, f)

    def exec(self, bytecode_file):
        import marshal
        
        # Загружаем байткод
        with open(bytecode_file, 'rb') as f:
            bytecode = marshal.load(f)
        
        # Создаем глобальное окружение
        globals_dict = {
            'gc': gc,
            'compile_to_bytecode': self.compile_to_bytecode_decorator,
            'self': self,
        }
        
        # Выполняем байткод
        exec(bytecode, globals_dict)
        self.globals.update(globals_dict)

    def run(self, code):
        try:
            # Трансформируем синтаксис перед парсингом
            transformed_code = self.transform_syntax(code)
                
            imports = '''
from functools import *
from typing import *
from stdFunction import *

from jpype import *
from cffi import FFI
import ctypes.util

import os as osystem
import sys as system
import time as timexc
import threading
from asyncio import *

parallel = Parallel().parallel()
            '''

            call_main = '\nMain()'

            transformed_code = self.optimize_string_concat(imports, transformed_code, call_main)

            # Добавляем вывод кода с номерами строк
            lines = transformed_code.split('\n')
            for i, line in enumerate(lines, 1):
                print(f"{i:3d} | {line}")

            # Кэширование скомпилированного кода
            code_hash = hash(transformed_code)
            if code_hash not in self.compiled_cache:
                self.compiled_cache[code_hash] = compile(transformed_code, '<string>', 'exec')

            # Выполняем скомпилированный код
            globals_dict = {
                'gc': gc,
                'compile_to_bytecode': self.compile_to_bytecode_decorator,
                'self': self,
            }

            try:
                exec(self.compiled_cache[code_hash], globals_dict)
            except SyntaxError as e:
                # Обрабатываем ошибки синтаксиса отдельно
                error = RytonSyntaxError(str(e), e.lineno, e.offset, code)
                self.error_handler.handle_error(error, code, transformed_code)
            except Exception as e:
                # Обрабатываем все остальные ошибки
                if hasattr(e, 'lineno'):
                    error = RytonError(str(e), e.lineno, getattr(e, 'offset', None), code)
                else:
                    error = RytonError(str(e), None, None, code)
                self.error_handler.handle_error(error, code, transformed_code)

            self.globals.update(globals_dict)

            if self.static_typing:
                # Добавляем проверку типов перед выполнением функции
                original_func = namespace[func_name]
                def type_checked_func(*args, **kwargs):
                    bound_args = inspect.signature(original_func).bind(*args, **kwargs)
                    self.check_types(func_name, bound_args.arguments, original_func.__annotations__)
                    return original_func(*args, **kwargs)
                namespace[func_name] = type_checked_func

            # Автоматическая очистка памяти, если trash_cleaner == True
            if self.trash_cleaner:
                self.memory_manager.objects.clear()
                gc.collect()

        except traceback as e:
            print(f'• {e}\n This Error \033[36m\033[1mbecause\033[0m of a bug in the language\n Please report it on GitHub :: \033[34m\033[4mhttps://github.com/CodeLibraty/RytonLang/issues\033[0m')

if __name__ == '__main__':
    RytonOne = SharpyLang()

    test_code = '''
module import {
    std.lib
}

trash_cleaner = true

jvmlib: java.util as jutil

func main {
    list = jutil.ArrayList()
}

main()
    '''

    try:
        RytonOne.execute(test_code)
    except Exception as e:
        print(e)
