from dataclasses import dataclass
from typing import Optional, List, Dict
import traceback
import inspect
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
        # Original functionality
        self.current_blocks = []
        
        # New functionality 
        self.blocks: Dict[str, CodeBlock] = {}
        self.current_file = None
        self.block_stack = []
        self.error_history = []
        self.max_history = 10

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

    def format_error_location(self, error, code: str) -> str:
        exc_type, exc_value, exc_tb = sys.exc_info()
        frames = inspect.getinnerframes(exc_tb)
        
        frame = None
        for f in frames:
            if 'ryton' in f.filename.lower():
                frame = f
                break
        
        if not frame:
            return str(error)

        block = self.find_block_for_line(frame.lineno, frame.filename)
        lines = code.splitlines()
        start = max(0, frame.lineno - 3)
        end = min(len(lines), frame.lineno + 3)
        context = '\n'.join(f"{i+1}: {line}" for i, line in enumerate(lines[start:end]))

        error_msg = f"""
{'='*50}
ERROR TYPE: {exc_type.__name__}
MESSAGE: {str(error)}
FILE: {os.path.basename(frame.filename)}
LINE: {frame.lineno}
BLOCK: {block.name if block else 'global scope'}
BLOCK HIERARCHY: {self.get_block_hierarchy(block) if block else 'None'}

CODE CONTEXT:
{context}

STACK TRACE:
{traceback.format_exc()}
{'='*50}
"""
        self.error_history.append(error_msg)
        if len(self.error_history) > self.max_history:
            self.error_history.pop(0)
        return error_msg

    def handle_error(self, error, code: str):
        # Original functionality
        block_name = self.get_current_block()
        basic_error = f"""
Error: {str(error)}
File:  {error.filename if hasattr(error, 'filename') else 'unknown'}
Line:  {error.line_number if hasattr(error, 'line_number') else 'unknown'}
Block: {block_name if block_name else 'global scope'}
"""
        print(basic_error)

        # New detailed error info
        print(self.format_error_location(error, code))

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

