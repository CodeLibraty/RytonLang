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

class RytonErrorHandler:
    def __init__(self):
        # New functionality 
        self.blocks: Dict[str, CodeBlock] = {}
        self.current_blocks = []
        self.error_history  = []
        self.block_stack    = []
        self.max_history = 10
        self.current_file = None
        self.traceback    = False
        self.pycode       = False

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
        python_lines = python_code.splitlines()
        ryton_lines = ryton_code.splitlines()
        
        # Создаем маппинг на основе схожести строк
        line_mapping = {}
        for py_idx, py_line in enumerate(python_lines, 1):
            max_similarity = 0
            best_match = 1
            
            for ry_idx, ry_line in enumerate(ryton_lines, 1):
                # Используем difflib для поиска похожих строк
                similarity = difflib.SequenceMatcher(None, 
                    py_line.strip(), ry_line.strip()).ratio()
                if similarity > max_similarity:
                    max_similarity = similarity
                    best_match = ry_idx
                    
            line_mapping[py_idx] = best_match
        
        return line_mapping.get(python_line, 1)

    def format_error_location(self, error, ryton_code: str, python_code: str) -> str:
        exc_type, exc_value, exc_tb = sys.exc_info()
        frames = inspect.getinnerframes(exc_tb)
        
        frame = None
        for f in frames:
            if 'ryton' in f.filename.lower():
                frame = f
                break


        if frame:
            # Находим соответствующую строку в Ryton коде
            ryton_line = self.map_python_to_ryton_line(
                frame.lineno, 
                python_code,
                ryton_code
            )
            
            # Показываем контекст из исходного Ryton кода
            lines = ryton_code.splitlines()
            start = max(0, ryton_line - 3)
            end = min(len(lines), ryton_line + 3)
            
            context = '\n'.join(
                f"{i+1}: {line}" 
                for i, line in enumerate(lines[start:end])
            )
            
            # Добавляем маркер ошибки
            error_marker = ' ' * (len(str(ryton_line)) + 2) + '^' * len(lines[ryton_line-1].lstrip())

        terminal_size = shutil.get_terminal_size().columns
        terminal_size_down = terminal_size - 2
        terminal_size_up = terminal_size - 13
        block = self.find_block_for_line(frame.lineno, frame.filename)
        lines = ryton_code.splitlines()
        start = max(0, frame.lineno - 3)
        end = min(len(lines), frame.lineno + 3)
        context = '\n'.join(f"{i+1}: {line}" for i, line in enumerate(lines[start:end]))

        err_type        = f"ERROR TYPE: {exc_type.__name__}"
        message         = f"MESSAGE: {str(error)}"
        file            = f"FILE: {os.path.basename(frame.filename)}"
        line            = f"LINE: {frame.lineno}"
        block_info      = f"BLOCK: {block.name if block else 'global scope'}"
        block_hierarchy = f"BLOCK HIERARCHY: {self.get_block_hierarchy(block) if block else 'None'}"

        indent_err_type        = ' ' * (terminal_size_down - len(err_type))
        indent_message         = ' ' * (terminal_size_down - len(message))
        indent_file            = ' ' * (terminal_size_down - len(file))
        indent_line            = ' ' * (terminal_size_down - len(line))
        indent_block_info      = ' ' * (terminal_size_down - len(block_info))
        indent_block_hierarchy = ' ' * (terminal_size_down - len(block_hierarchy))

        error_msg = f"""
{'╭'+'────\033[31m⚠ Error\033[0m'+'─'*terminal_size_up+'╮'}
│{err_type}{indent_err_type}│
│{message}{indent_message}│
│{file}{indent_file}│
│{line}{indent_line}│
│{block_info}{indent_block_info}│
│{block_hierarchy}{indent_block_hierarchy}│
{'╰'+'─'*terminal_size_down+'╯'}
        """
        self.error_history.append(error_msg)
        if len(self.error_history) > self.max_history:
            self.error_history.pop(0)
        return error_msg

    def print_traceback(self):
        pass

    def handle_error(self, error, code: str, transformed_code: str):
        # Original functionality
        block_name = self.get_current_block()

        # New detailed error info
        print(self.format_error_location(error, code, transformed_code))

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

