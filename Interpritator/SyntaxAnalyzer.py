from functools import lru_cache

import cython
import re

from .ErrorHandler import *


# Предкомпиляция и кэширование регулярных выражений
TRASH_CLEANER_RE  = re.compile(r'trash_cleaner\s*=\s*(true|false)')

FUNCTION_DEF_RE  = re.compile(r'\bfunc\s+(\w+)\s*\((.*?)\)\s*\{')
LANG_BLOCK_RE    = re.compile(r'lang (\w+)\(\)\s*<\{([\s\S]*?)\}>')
KEYWORD_RE       = re.compile(r'\b(func|pack|skip|pylib:)\b')

IDENTIFIER_RE  = re.compile(r'^[a-zA-Z_][a-zA-Z0-9_]*$')
SEMICOLON_RE   = re.compile(r';')

# Ключивые слова для обработки ошибок
VARIABLE_DECLARATION_RE  = re.compile(r'\b(var|let|const)\s+')
NOTALLOWED_KEYWORDS      = set(['def', 'class', 'pass', 'import', 'except'])


class SyntaxAnalyzer:
    def __init__(self):
        self.error_handler = RytonErrorHandler()
        
    def analyze(self, code):
        self.check_syntax(code)
        self.check_python_keywords(code) 
        self.check_colons(code)

    def handle_error(self, error, original_code):
        try:
            lines = original_code.split('\n')
            print(f"Error: Number of lines in original code: {len(lines)}")

            if isinstance(error, SyntaxError):
                print(f"Error: SyntaxError detected")
                line_number = getattr(error, 'lineno', None)
                column = getattr(error, 'offset', None)
                message = getattr(error, 'msg', str(error))
                print(f"Error: line_number={line_number}, column={column}")
            else:
                print(f"Error: Non-SyntaxError detected")
                tb = error.__traceback__
                while tb.tb_next:
                    tb = tb.tb_next
                line_number = getattr(tb, 'tb_lineno', None)
                column = None
                message = str(error)
                print(f"Error: line_number={line_number}")

            if line_number is not None and isinstance(line_number, int) and 1 <= line_number <= len(lines):
                line_content = lines[line_number - 1]
                print(f"Error: line_content='{line_content}'")
            else:
                line_content = None
                print(f"Error: Invalid line_number or out of range")

            error_class = {
                SyntaxError: RytonSyntaxError,
                NameError: RytonNameError,
                TypeError: RytonTypeError
            }.get(type(error), RytonRuntimeError)

            raise error_class(message, line_number, column, line_content)

        except Exception as e:
    #            print(f"Error: Exception in handle_error: {type(e)} - {str(e)}")
            self.error_handler.handle_error( str(e), original_code)

    @cython.ccall
    def check_syntax(self, code):
        try:
            self.check_keywords(code)
            self.check_brace_balance(code)
            self.check_identifiers(code)
            lines = code.split('\n')
        except Exception as e:
            self.error_handler.handle_error( str(e), code)
        
        self.check_python_keywords(code)
    #        self.check_indentation(code)
        self.check_colons(code)

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
            raise RytonError("Missing required 'trash_cleaner' declaration")

    def check_python_keywords(self, code):
        python_keywords = set(['def', 'class', 'except'])
        for keyword in python_keywords:
            if re.search(r'\b' + keyword + r'\b', code):
                raise RytonSyntaxError(f"Use of keyword '{keyword}' is not allowed")

    def check_indentation(self, code):
        lines = code.split('\n')
        for line in lines:
            if line.strip() and line[0] == ' ':
                raise RytonSyntaxError("Indentation with spaces is not allowed. Use '{' and '}' for blocks")

    def check_colons(self, code):
        # Сначала удаляем содержимое строк, заменяя их placeholder'ами
        no_strings = re.sub(r'"[^"]*"', '""', code)  # Удаляем двойные кавычки
        no_strings = re.sub(r"'[^']*'", "''", no_strings)  # Удаляем одинарные кавычки
        
        # Теперь проверяем двоеточия только в коде вне строк
        if re.search(r'\(\s*(.*?)\s*\):', no_strings):
            raise RytonSyntaxError("Use of ':' is not allowed. Use '{' to start a block")

    def check_keywords(self, code):
        for match in KEYWORD_RE.finditer(code):
            keyword = match.group(1)
            if keyword in NOTALLOWED_KEYWORDS:
                line_number = code[:match.start()].count('\n') + 1
                line = code.split('\n')[line_number - 1]
                col = match.start() - sum(len(l) + 1 for l in code.split('\n')[:line_number - 1])
                raise RytonSyntaxError(f"Invalid keyword: {keyword}", line_number, col, line)

    @lru_cache(maxsize=128)
    def check_brace_balance(self, code):
        stack = []
        for i, char in enumerate(code):
            if char == '{':
                stack.append((char, i))
            elif char == '}':
                if not stack or stack[-1][0] != '{':
                    line_number = code[:i].count('\n') + 1
                    line = code.split('\n')[line_number - 1]
                    col = i - code.rfind('\n', 0, i)
                    raise RytonSyntaxError("Mismatched closing brace", line_number, col, line)
                stack.pop()
        if stack:
            char, i = stack[-1]
            line_number = code[:i].count('\n') + 1
            line = code.split('\n')[line_number - 1]
            col = i - code.rfind('\n', 0, i)
            raise RytonSyntaxError("Unclosed opening brace", line_number, col, line)

    def check_comm_balance(self, code):
        stack = []
        for i, char in enumerate(code):
            if char == '</':
                stack.append((char, i))
            elif char == '/>':
                if not stack or stack[-1][0] != '</':
                    line_number = code[:i].count('\n') + 1
                    line = code.split('\n')[line_number - 1]
                    col = i - code.rfind('\n', 0, i)
                    raise RytonSyntaxError("Mismatched closing commintaries", col, line)
                stack.pop()
        if stack:
            char, i = stack[-1]
            line_number = code[:i].count('\n') + 1
            line = code.split('\n')[line_number - 1]
            col = i - code.rfind('\n', 0, i)
            raise RytonSyntaxError("Unclosed opening commintaries", col, line)

    def check_identifiers(self, code):
        for match in re.finditer(r'\b(\w+)\b', code):
            identifier = match.group(1)
            if not IDENTIFIER_RE.match(identifier) and identifier in NOTALLOWED_KEYWORDS:
                line_number = code[:match.start()].count('\n') + 1
                line = code.split('\n')[line_number - 1]
                col = match.start() - sum(len(l) + 1 for l in code.split('\n')[:line_number - 1])
                raise RytonSyntaxError(f"Invalid identifier: {identifier}", line_number, col, line)
