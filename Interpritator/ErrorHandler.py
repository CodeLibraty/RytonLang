from dataclasses import dataclass
from typing import Optional, List, Dict
import traceback
import inspect
import shutil
import difflib
import sys
import os

@dataclass
class CodeBlock:
    name: str
    start_line: int
    end_line: int
    file: str
    parent: Optional['CodeBlock'] = None
    children: List['CodeBlock'] = None

@dataclass
class ErrorTrace:
    file: str
    line: int
    function: str
    code: str

class ExecutionTracer:
    def __init__(self):
        self.call_stack = []
        self.error_methods = set()
        self.execution_log = []
        
    def __call__(self, frame, event, arg):
        if event == 'call':
            func_name = frame.f_code.co_name
            if func_name != '<module>':  # Пропускаем системные вызовы
                self.execution_log.append(f"Called: {func_name}")
                
        elif event == 'exception':
            exc_type, exc_value, _ = arg
            func_name = frame.f_code.co_name
            if func_name != '<module>':
                self.error_methods.add(func_name)
                self.execution_log.append(f"Error in {func_name}: {exc_type.__name__}")
                
        return self

    def get_trace_report(self):
        report = []
        if self.error_methods:
            report.extend([
                "Problematic Methods:",
                *[f"• {method}" for method in self.error_methods],
                ""
            ])
        if self.execution_log:
            report.extend([
                "Execution Path:",
                *[f"→ {entry}" for entry in self.execution_log]
            ])
        return report

class RytonErrorHandler:
    def __init__(self):
        self.blocks = {}
        self.current_blocks = []
        self.error_history = []
        self.block_stack = []
        self.max_history = 10
        self.current_file = None
        self.traceback = True  # Включаем по умолчанию
        self.pycode = False
        self.trace_stack = []
        self.tracer = ExecutionTracer()
        self.is_handling_error = False
        self.recursion_limit = 100
        self.current_recursion = 0
        self.RED = "\033[31m"
        self.RESET = "\033[0m"
        self.terminal_size = shutil.get_terminal_size().columns

    def start_tracing(self):
        sys.settrace(self.tracer)
        
    def stop_tracing(self):
        sys.settrace(None)
        
    def get_error_methods(self):
        return list(self.tracer.error_methods)
        
    def get_execution_log(self):
        return self.tracer.execution_log

    def _create_error_box(self, lines: list, width: int, type: str) -> str:
        # Создаем красивую рамку с цветным выделением
        box_lines = ['├' + '─'*4 +f'{self.RED}{type}{self.RESET}' + '─' * (width - len(type) - 6) + '╮']
        
        for line in lines:
            # Добавляем отступы и вертикальные линии
            padding = ' ' * (width - len(line) - 3)
            box_lines.append(f'│ {line}{padding}│')
        
        # Закрываем рамку
        box_lines.append('├' + '─' * (width - 2) + '╯')
        
        return '\n'.join(box_lines)

    def print_trace_report(self):
        report = [
            "Problematic Methods:",
            *[f"• {method}" for method in self.get_error_methods()],
            "",
            "Execution Log:",
#            *[f"→ {entry}" for entry in self.get_execution_log()]
        ]
        
        print(self._create_error_box(report, self.terminal_size, "⏎ RyBack Trace"))

    def enter_block(self, block_name):
        self.current_blocks.append(block_name)
        
    def exit_block(self):
        if self.current_blocks:
            self.current_blocks.pop()
            
    def get_current_block(self):
        return self.current_blocks[-1] if self.current_blocks else None

    def register_block(self, name: str, start_line: int):
        parent = self.block_stack[-1] if self.block_stack else None
        block = CodeBlock(
            name=name,
            start_line=start_line,
            end_line=None,
            file=self.current_file,
            parent=parent,
            children=[]
        )
        if parent:
            parent.children.append(block)
        self.blocks[name] = block
        self.block_stack.append(block)

    def end_block(self, end_line: int):
        if self.block_stack:
            block = self.block_stack.pop()
            block.end_line = end_line

    def find_block_for_line(self, line: int, filename: str) -> Optional[CodeBlock]:
        for block in self.blocks.values():
            if (block.file == filename and block.start_line <= line <= block.end_line):
                return block
        return None

    def get_block_hierarchy(self, block: CodeBlock) -> str:
        hierarchy = []
        current = block
        while current:
            hierarchy.append(current.name)
            current = current.parent
        return ' -> '.join(reversed(hierarchy))

    def map_python_to_ryton_line(self, python_line: int, python_code: str, ryton_code: str) -> int:
        # Получаем стек вызовов
        stack = traceback.extract_stack()
        
        # Находим фрейм с ошибкой
        error_frame = None
        for frame in stack:
            if 'ryton' in frame.filename.lower():
                error_frame = frame
                break
        
        if error_frame:
            # Берем реальный номер строки из стека
            return error_frame.lineno
            
        # Если не нашли в стеке - используем прямое сопоставление кода
        py_lines = python_code.splitlines()
        ry_lines = ryton_code.splitlines()
        
        # Ищем строку с ошибкой в исходном коде
        error_line = py_lines[python_line - 1].strip()
        
        # Проходим по коду Ryton и ищем эту же строку
        for i, line in enumerate(ry_lines):
            if error_line in line:
                return i + 1
                
        return python_line


    def format_error_location(self, error, ryton_code: str, python_code: str) -> str:
        exc_type, exc_value, exc_tb = sys.exc_info()
        frames = inspect.getinnerframes(exc_tb)

        # Ищем реальное место ошибки
        original_line = None
        for frame in frames:
            if 'test.ry' in frame.filename:  # Ищем исходный файл Ryton
                original_line = frame.lineno
                break

        # Добавляем вывод фрагмента Ryton кода с подсветкой проблемной строки
        ryton_lines = ryton_code.splitlines()
        error_line = self.map_python_to_ryton_line(frame.lineno, python_code, ryton_code)
        
        context = []
        for i in range(max(0, error_line - 2), min(len(ryton_lines), error_line + 3)):
            prefix = '>> ' if i + 1 == error_line else '   '
            context.append(f"{prefix}{i+1:4d} | {ryton_lines[i]}")
            
            if i + 1 == error_line:
                context.append('     ' + ' ' * len(str(i+1)) + ' | ' + '^' * len(ryton_lines[i].lstrip()))
                
        code_context = '\n'.join(context)

        block = self.find_block_for_line(frame.lineno, frame.filename)
        lines = ryton_code.splitlines()
        start = max(0, frame.lineno - 3)
        end = min(len(lines), frame.lineno + 3)
        context = '\n'.join(f"{i+1}: {line}" for i, line in enumerate(lines[start:end]))

        file = f"RYTON FILE: {os.path.basename(self.current_file)}" if self.current_file else "FILE: <string>"
        err_type        = f"ERROR TYPE: {exc_type.__name__}"
        message         = f"MESSAGE: {str(error)}"
        file            = f"FILE: {os.path.basename(frame.filename)}"
        line            = f"LINE: {frame.lineno}"
        block_info      = f"BLOCK: {block.name if block else 'global scope'}"
        block_hierarchy = f"BLOCK HIERARCHY: {self.get_block_hierarchy(block) if block else 'None'}"

        ERROR = "⚠ Error"

        error_msg = [
            f"{err_type}",
            f"{message}",
            f"{file}",
            f"{line}",
            f"{block_info}",
            f"{block_hierarchy}"
        ]

        err_out = self._create_error_box(error_msg, self.terminal_size, ERROR)


        self.error_history.append(err_out)
        if len(self.error_history) > self.max_history:
            self.error_history.pop(0)
        return err_out

    def print_traceback(self):
        pass

    def handle_error(self, error, code, transformed_code):
        # Защита от рекурсии
        if self.is_handling_error:
            return
            
        self.is_handling_error = True
        try:
            self.current_recursion += 1
            if self.current_recursion > self.recursion_limit:
                print("Превышен лимит рекурсии при обработке ошибок")
                return

            # Выводим отчет
            print("\n╭ Program Error")
            self.print_trace_report()
            print(self.format_error_location(error, code, transformed_code))

        finally:
            self.is_handling_error = False
            self.current_recursion -= 1

class RytonError(Exception):
    def __init__(self, message, line_number=None, column=None, block_name=None):
        self.message = message
        self.line_number = line_number
        self.column = column
        self.block_name = block_name
        super().__init__(message)

class RytonSyntaxError(RytonError):
    pass

class RytonNameError(RytonError):
    pass

class RytonTypeError(RytonError):
    pass

class RytonRuntimeError(RytonError):
    pass

