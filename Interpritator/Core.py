# Необхадимые модули для работы языка
from importlib import import_module
from functools import lru_cache
from collections import deque

import subprocess
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

# Kомпоненты языка
from .ErrorHandler import *

from .Effects import * 
from .Pragma import *  

#from .SyntaxAnalyzer import *
from .SyntaxTransformer import *

from .RGC import RytonGC

from .PackageSystem import PackageSystem
from .PythonImportManager import UserDirLoader

# Предкомпиляция и кэширование регулярных выражений
TRASH_CLEANER_RE  = re.compile(r'trash_cleaner\s*=\s*(true|false)')

#                  INFO:                  #
#  Project   - Ryton Progarming Language  #
#  Version   - 0.1.0                      #
#  team      - Code Libraty               #
#  Developer - RejziDich                  #
#  License   - ROS License 1.0            #
#  Arch      - Simple and Fast Approach   #

class SharpyLang:
    __slots__ = (
        'globals', 'effect_registry', 'pragma_handler',
        'error_handler', 'static_typing', 'syntax_analyzer',
        'compiled_functions', 'package_system', 'dsls',
        'imported_libs', 'user_vars', 'gc', 'LangConfig',
        'transformation_cache', 'IMPORT_RE', 'compiled_cache', 
        'memory_manager', 'trash_cleaner', 'module_mapping',
        'src_dir', 'tracer', 'ryton_root', 'py_module_import'
    )

    def __init__(self, src_dir_project, ryton_root="./"):
        self.transformation_cache = {}
        self.compiled_functions   = {}
        self.compiled_cache       = {}
        self.user_vars            = {}
        self.globals              = {}
        self.dsls                 = {}

        self.imported_libs = set()

        self.IMPORT_RE = re.compile(r'module\s+import\s*\{([\s\S]*?)\}')

        self.src_dir = src_dir_project
        self.ryton_root = ryton_root

        self.LangConfig = {
            'gc': {
                'algorithm': "MarkSweep",
                'heap_size': 16 * 1024 * 1024,  # 16MB
                'threshold': 10000
            }
        }

        self.py_module_import = UserDirLoader(ryton_root)
        self.error_handler    = RytonErrorHandler()
        self.tracer           = ExecutionTracer()
        self.effect_registry  = EffectRegistry()
        #self.syntax_analyzer  = RytonSyntaxValidator()
        self.pragma_handler   = PragmaHandler()
        self.package_system   = PackageSystem()
        self.gc               = RytonGC()
        self.module_mapping = {
            'ZigLang': 'ZigLang',   'ZigLang.Bridge': 'ZigLang.Bridge',
            'std':   'std',

            'std.RyTable':          'std.RyTable',
            'std.RuVix.Effects':    'std.RuVix.Effects',
            'std.RuVix.App':        'std.RuVix.App,pygame',

            'std.DrawGL':            'std.DrawGL',
            'std.DrawGL.window':     'std.DrawGL.window',
            'std.DrawGL.graphics':   'std.DrawGL.graphics',
            'std.DrawGL.colors':     'std.DrawGL.colors',
            'std.DrawGL.text':       'std.DrawGL.text',
            'std.DrawGL.shaders':    'std.DrawGL.shaders',

            'std.MetaEngine':        'std.MetaEngine',
            'std.QuantUI':           'std.QuantUI',
            'std.Ryora':             'std.Ryora',

            'std.KeyBinder':   'std.KeyBinder',    'std.DeviceTools': 'std.DeviceTools',
            'std.lib':         'std.lib',          'std.DSL':         'std.DSL',
            'std.PowerAPI':    'std.PowerAPI',     'std.RuVix':       'std.RuVix',
            'std.UpIO':        'std.UpIO',         'std.Rask':        'std.Rask',
            'std.Math':        'std.Math',         'std.RandoMizer':  'std.RandoMizer',
            'std.RytonDB':     'std.RytonDB',      'std.Terminal':    'std.Terminal',
            'std.Path':        'std.Path',         'std.Files':       'std.Files',
            'std.ReGex':       'std.ReGex',        'std.DateTime':    'std.DateTime',
            'std.Archive':     'std.Archive',      'std.DeBugger':    'std.DeBugger',
            'std.ErroRize':    'std.ErroRize',     'std.RuVixCore':   'std.RuvVixCore',
            'std.Algorithm':   'std.Algorithm',    'std.System':      'std.System',
            'std.DocTools':    'std.DocTools',     'std.MatplotUp':   'std.MatplotUp',
            'std.NeuralNet':   'std.NeuralNet',    'std.Media':       'std.Media',
            'std.NetWorker':   'std.NetWorker',    'std.TUIX':        'std.TUIX',
            'std.MetaTable':   'std.MetaTable',    'std.ProgRessing': 'std.ProgRessing',
            'std.ColoRize':    'std.ColoRize',     'std.RunTimer':    'std.RunTimer',
        }

        # Настройки сборщика мусора
        if self.LangConfig['gc']['algorithm']:
            self.gc = RytonGC(
                algorithm=self.LangConfig['gc']['algorithm'],
                heap_size=self.LangConfig['gc']['heap_size'],
                threshold=self.LangConfig['gc']['threshold']
            )
        else:
            gc.enable()

    class ContractError(Exception):
        pass

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

    def currect_src_dir(self):
        return self.src_dir

    @lru_cache(maxsize=128)
    def transform_syntax(self, code):
        protected_code, raw_blocks = transform_defer(code)

        # Обработка импортов библиотек
        code = protected_code
        code = self.IMPORT_RE.sub(self.process_imports, code)

        # Кэширование трансформаций
        code_hash = hash(code)
        if code_hash in self.transformation_cache:
            return self.transformation_cache[code_hash]

        # Замены синтаксиса
        replacements = {
            '} else {':  '}\nelse {',
            '} elerr ':  '}\nelerr ',
            '} elif ':   '}\nelif '
        }
        for old, new in replacements.items():
            code = code.replace(old, new)

        code = transform(code, raw_blocks)

        return code

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
from ZigLang.Bridge import ZigBridge
from std.MetaTable import MetaTable
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
            'Core': self,
        }
        
        # Выполняем байткод
        exec(bytecode, globals_dict)
        self.globals.update(globals_dict)

    def run(self, code):
        try:
            # Валидация синтаксиса

            # Трансформируем синтаксис перед парсингом
            transformed_code = self.transform_syntax(code)

            imports = f'''
import os as osystem
import sys as system
import time as timexc

from asyncio import *
from functools import *
from typing import *

import dataclasses, threading

from py4j.java_gateway import JavaGateway
from cffi import FFI
from ZigLang.Bridge import ZigBridge
from std.MetaTable import MetaTable
import ctypes.util

from stdFunction import *
from UpIO import *
from DataTypes import *

osystem.chdir("{self.src_dir}")

gateway = JavaGateway()
parallel = Parallel().parallel()
'''

            call_main = '\nMain()'

            transformed_code = self.optimize_string_concat(imports, transformed_code, call_main)

            # Добавляем вывод кода с номерами строк
            lines = transformed_code.split('\n')
            for i, line in enumerate(lines, 1):
                print(f"{i:3d} │ {line}")

            # Выполняем скомпилированный код
            globals_dict = {
                'gc': gc,
                'Core': self,
                'SRC': self.src_dir,
            }

            # Сохраняем во временный файл
            with open(f"{self.ryton_root}/Interpritator/temp.ry", "w") as f:
                f.write(transformed_code)
            
            try:
                self.error_handler.start_tracing()
                subprocess.run([f"{self.ryton_root}/Interpritator/PyPyLang/bin/pypy3.11", f"{self.ryton_root}/Interpritator/temp.ry"])
            except Exception as error:
                self.error_handler.stop_tracing()
                self.error_handler.handle_error(error, code, transformed_code)
            finally:
                self.error_handler.stop_tracing()

            self.globals.update(globals_dict)


        except Exception as e:
            self.tracer.execution_log
            self.error_handler.stop_tracing()
            self.error_handler.handle_error(e, code, transformed_code)
            print(f'• This Error \033[36m\033[1m-perhaps-\033[0m of a bug in the language\n Please report it on GitHub :: \033[34m\033[4mhttps://github.com/CodeLibraty/RytonLang/issues\033[0m')
