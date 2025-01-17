from functools import lru_cache
import re
from typing import Dict, Set, List, Tuple
from .ErrorHandler import *

class SyntaxAnalyzer:
    def __init__(self):
        self.error_handler = RytonErrorHandler()
        
        # Кэшированные регулярные выражения
        self.patterns = {
            'trash_cleaner': re.compile(r'trash_cleaner\s*=\s*(true|false)'),
            'function_def': re.compile(r'\bfunc\s+(\w+)\s*\((.*?)\)\s*\{'),
            'lang_block': re.compile(r'lang (\w+)\(\)\s*<\{([\s\S]*?)\}>'),
            'keywords': re.compile(r'\b(func|pack|noop|pylib:|thread|neural|protect|event)\b'),
            'identifier': re.compile(r'^[a-zA-Z_][a-zA-Z0-9_]*$'),
            'semicolon': re.compile(r';'),
            'variable_decl': re.compile(r'\b(var|let|const)\s+'),
            'imports': re.compile(r'(module|package)\s+import\s*\{'),
            'blocks': re.compile(r'\b(if|while|for|match|guard)\s*\{'),
            'strings': re.compile(r'(".*?"|\'.*?\')')
        }
        
        self.block_stack: List[Tuple[str, int]] = []
        self.scope_depth = 0
        self.current_line = 1

        self.code = ''
        
        # Расширенный набор запрещенных ключевых слов
        self.forbidden_keywords: Set[str] = {
            'def', 'class', 'pass'
        }

    def code_init(self, code):
        self.code = code

    def analyze(self, pycode: str, rycode: str) -> None:
        """Улучшенный анализ с поддержкой многопроходной проверки"""
        try:
            # First pass - basic checks
            self._check_basic_syntax(rycode)
            
            # Second pass - structural analysis 
            self._analyze_structure(rycode)
            
            # Third pass - semantic analysis
            self._analyze_semantics(rycode)
            
        except Exception as e:
            self.error_handler.handle_error(str(e), pycode, rycode)

    def _check_basic_syntax(self, code: str) -> None:
        """Базовые проверки синтаксиса"""
        self._check_trash_cleaner(code)
        self._check_forbidden_keywords(code)
        self._check_braces_balance(code)
        self._check_basic_patterns(code)

    def _analyze_structure(self, code: str) -> None:
        """Анализ структуры кода"""
        lines = code.split('\n')
        self.block_stack.clear()
        self.scope_depth = 0
        
        for line_num, line in enumerate(lines, 1):
            self.current_line = line_num
            self._analyze_line_structure(line)
            self._check_block_consistency(line)
            self._validate_identifiers(line)

    def _analyze_semantics(self, code: str) -> None:
        """Семантический анализ"""
        # Проверка корректности импортов
        self._validate_imports(code)
        
        # Проверка объявлений функций
        self._validate_functions(code)
        
        # Проверка использования переменных
        self._validate_variables(code)
        
        # Проверка типов данных если включена статическая типизация
        if 'static_typing = true' in code:
            self._validate_types(code)

    @lru_cache(maxsize=128)
    def _validate_functions(self, code: str) -> None:
        """Улучшенная валидация функций"""
        for match in self.patterns['function_def'].finditer(code):
            func_name, params = match.groups()
            if not self.patterns['identifier'].match(func_name):
                self._raise_error(f"Invalid function name: {func_name}")
                
            if params:
                self._validate_function_params(params, func_name)

    def _validate_function_params(self, params: str, func_name: str) -> None:
        """Проверка параметров функции"""
        for param in params.split(','):
            param = param.strip()
            if param and not self.patterns['identifier'].match(param):
                self._raise_error(f"Invalid parameter '{param}' in function {func_name}")

    @lru_cache(maxsize=128)
    def _check_braces_balance(self, code: str) -> None:
        """Улучшенная проверка баланса скобок"""
        stack = []
        brace_pairs = {'{': '}', '(': ')', '[': ']'}
        
        for i, char in enumerate(code):
            if char in brace_pairs:
                stack.append((char, i))
            elif char in brace_pairs.values():
                if not stack or brace_pairs[stack[-1][0]] != char:
                    self._raise_error("Mismatched braces", i)
                stack.pop()
                
        if stack:
            self._raise_error("Unclosed braces", stack[-1][1])

    def _check_trash_cleaner(self, code: str) -> None:
        """Проверка наличия и корректности trash_cleaner"""
        match = self.patterns['trash_cleaner'].search(code)
        if not match:
            self._raise_error("Missing required 'trash_cleaner' declaration")

    def _check_forbidden_keywords(self, code: str) -> None:
        """Проверка запрещенных ключевых слов"""
        for keyword in self.forbidden_keywords:
            if re.search(rf'\b{keyword}\b', code):
                self._raise_error(f"Use of keyword '{keyword}' is not allowed")

    def _check_basic_patterns(self, code: str) -> None:
        """Проверка базовых паттернов кода"""
        # Проверка корректности блоков
        for match in self.patterns['blocks'].finditer(code):
            if '{' not in code[match.end():]:
                self._raise_error("Missing block opening brace")

        # Проверка строк
        for match in self.patterns['strings'].finditer(code):
            if match.group(1)[0] != match.group(1)[-1]:
                self._raise_error("Mismatched string quotes")

    def _analyze_line_structure(self, line: str) -> None:
        """Анализ структуры отдельной строки"""
        line = line.strip()
        if line:
            if line.endswith('{'):
                self.block_stack.append(('block', self.current_line))
                self.scope_depth += 1
            elif line.startswith('}'):
                if not self.block_stack:
                    self._raise_error("Unexpected closing brace")
                self.block_stack.pop()
                self.scope_depth -= 1

    def _check_block_consistency(self, line: str) -> None:
        """Проверка согласованности блоков"""
        if self.scope_depth < 0:
            self._raise_error("Invalid block structure")

    def _validate_identifiers(self, line: str) -> None:
        """Проверка корректности идентификаторов"""
        words = re.findall(r'\b\w+\b', line)
        for word in words:
            if word.isidentifier() and not self.patterns['identifier'].match(word):
                self._raise_error(f"Invalid identifier: {word}")

    def _validate_imports(self, code: str) -> None:
        """Проверка корректности импортов"""
        for match in self.patterns['imports'].finditer(code):
            if '{' not in code[match.end():]:
                self._raise_error("Invalid import statement")

    def _validate_variables(self, code: str) -> None:
        """Проверка использования переменных"""
        declarations = self.patterns['variable_decl'].finditer(code)
        for decl in declarations:
            var_name = code[decl.end():].split()[0]
            if not self.patterns['identifier'].match(var_name):
                self._raise_error(f"Invalid variable name: {var_name}")

    def _validate_types(self, code: str) -> None:
        """Проверка типов при статической типизации"""
        # Базовая проверка аннотаций типов
        type_annotations = re.finditer(r'\b\w+\s*:\s*\w+', code)
        for annotation in type_annotations:
            if not re.match(r'\w+\s*:\s*(int|str|bool|float|\w+)', annotation.group(0)):
                self._raise_error(f"Invalid type annotation: {annotation.group(0)}")

    def _raise_error(self, message: str, position: int = None) -> None:
        """Улучшенная генерация ошибок"""
        line = self.current_line
        col = position - self.code.rfind('\n', 0, position) if position else None
        raise RytonSyntaxError(message, line, col, self.code.split('\n')[line-1])

    def check_syntax(self, code: str) -> None:
        """Сохраняем старый API"""
        self.analyze(code)

    def check_python_keywords(self, code: str) -> None:
        """Сохраняем старый API"""
        self._check_forbidden_keywords(code)

    def check_indentation(self, code: str) -> None:
        """Сохраняем старый API"""
        self._check_indentation_rules(code)

    def check_colons(self, code: str) -> None:
        """Сохраняем старый API"""
        self._validate_block_syntax(code)
