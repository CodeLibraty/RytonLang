from dataclasses import dataclass
from typing import List, Dict, Set
import re

@dataclass
class SyntaxError:
    message: str
    line: int
    code: str

class RytonSyntaxValidator:
    def __init__(self):
        self.errors: List[SyntaxError] = []
        self.scope_stack = []
        self.defined_names = set()
        self.current_line = 0
        
        # Паттерны синтаксиса Ryton
        self.patterns = {
            'pack': r'^pack\s+([A-Z]\w*)\s*(?:\|\s*([A-Z]\w*))?\s*(?:!([\w|]+))?\s*{',
            'func': r'^func\s+([a-z]\w*)\s*\(([\w\s,]*)\)(?:\s*->\s*(\w+))?\s*{',
            'init': r'^init\s*:',
            'guard': r'^guard\s+(.+?)\s+else\s*{',
            'contract': r'^contract\s+(\w+)\s*:\s*{',
            'event': r'^event\s+(\w+)\s*->\s*(\w+)\s*{',
            'defer': r'^defer\s*{',
            'thread': r'^thread\s+(\w+)\s*{',
            'table': r'^table\s+(\w+)\s*(?:{|=)',
            'lazy': r'^lazy\s+(\w+)\s*=',
            'import': r'^module\s+import\s*{',
            'pylib': r'^pylib:\s*([\w.]+)',
            'jvmlib': r'^jvmlib:\s*([\w.]+)\s+as\s+(\w+)',
            'macro': r'^macro\s+@(\w+)',
            'hyperfunc': r'^hyperfunc\s+(\w+)\s*::\s*([\w|]+)',
        }
        
        # Правила валидации для каждого типа
        self.validators = {
            'pack': self._validate_pack,
            'func': self._validate_func,
            'import': self._validate_import,
            # и т.д.
        }
        
    def validate(self, code: str) -> bool:
        self.errors = []
        self.scope_stack = []
        self.defined_names.clear()
        
        lines = code.split('\n')
        brace_count = 0
        
        for i, line in enumerate(lines, 1):
            self.current_line = i
            line = line.strip()
            
            if not line or line.startswith('#'):
                continue
                
            # Проверяем скобки
            brace_count += line.count('{') - line.count('}')
            if brace_count < 0:
                self._add_error("Unexpected closing brace", i, line)
                
            # Проверяем синтаксис
            matched = False
            for pattern_name, pattern in self.patterns.items():
                match = re.match(pattern, line)
                if match:
                    matched = True
                    if pattern_name in self.validators:
                        self.validators[pattern_name](match, line)
                    break
                    
            if not matched and line and not line.startswith((')', '}', '}')):
                self._add_error("Invalid syntax", i, line)
                
        if brace_count != 0:
            self._add_error("Unmatched braces", len(lines), "")
            
        if self.errors:
            self._print_errors()
            return False
        return True
        
    def _validate_pack(self, match, line):
        name = match.group(1)
        parent = match.group(2) if len(match.groups()) > 1 else None
        modifiers = match.group(3).split('|') if match.group(3) else []
        
        if name in self.defined_names:
            self._add_error(f"Pack {name} already defined", self.current_line, line)
            
        if parent and parent not in self.defined_names:
            self._add_error(f"Parent pack {parent} not defined", self.current_line, line)
            
        valid_modifiers = {'final', 'abstract', 'sealed'}
        for mod in modifiers:
            if mod not in valid_modifiers:
                self._add_error(f"Invalid modifier {mod}", self.current_line, line)
                
        self.defined_names.add(name)
        self.scope_stack.append(('pack', name))
        
    def _validate_func(self, match, line):
        name = match.group(1)
        args = match.group(2)
        ret_type = match.group(3) if len(match.groups()) > 2 else None
        
        if not self.scope_stack:
            self._add_error("Function defined outside pack", self.current_line, line)
            
        # Check arguments
        if args:
            for arg in args.split(','):
                arg = arg.strip()
                if arg and not re.match(r'^[a-z]\w*(?:\s*:\s*\w+)?$', arg):
                    self._add_error(f"Invalid argument syntax: {arg}", self.current_line, line)
                    
        self.scope_stack.append(('func', name))
        
    def _validate_import(self, match, line):
        if self.scope_stack:
            self._add_error("Import must be at top level", self.current_line, line)
            
    def _add_error(self, message: str, line: int, code: str):
        self.errors.append(SyntaxError(message, line, code))
        
    def _print_errors(self):
        print("\nRyton Syntax Errors:")
        print("-" * 50)
        for error in self.errors:
            print(f"Line {error.line}: {error.message}")
            if error.code:
                print(f"  {error.code}")
            print()

def integrate_with_core(core_instance):
    validator = RytonSyntaxValidator()
    core_instance.syntax_analyzer = validator
