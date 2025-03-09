class BaseValidator:
    def __init__(self):
        self.patterns = {}
        self.rules = {}
        
    def add_pattern(self, name, pattern, rules=None):
        self.patterns[name] = re.compile(pattern)
        if rules:
            self.rules[name] = rules
            
    def validate(self, code, pattern_name):
        pattern = self.patterns[pattern_name]
        rules = self.rules.get(pattern_name, [])
        
        for match in pattern.finditer(code):
            for rule in rules:
                rule(match)

class RytonValidator(BaseValidator):
    def __init__(self):
        super().__init__()
        
        # Паки
        self.add_pattern('pack', 
            r'pack\s+(\w+)(?:\s*::\s*(\w+))?\s*\{',
            [
                lambda m: self._check_capitalized(m.group(1), "Pack"),
                lambda m: self._check_capitalized(m.group(2), "Parent") if m.group(2) else None
            ]
        )
        
        # Функции
        self.add_pattern('func',
            r'func\s+(\w+)\s*\((.*?)\)\s*(?:!([\w\|]+))?\s*\{',
            [
                lambda m: self._check_args(m.group(2)),
                lambda m: self._check_modifiers(m.group(3))
            ]
        )
        
    def _check_capitalized(self, name, type):
        if not name[0].isupper():
            raise SyntaxError(f"{type} must be capitalized: {name}")
            
    def _check_args(self, args):
        if args and ':' not in args:
            raise SyntaxError(f"Missing type annotation: {args}")
            
    def _check_modifiers(self, mods):
        if mods:
            valid = {'async', 'cached', 'validate'}
            for mod in mods.split('|'):
                if mod not in valid:
                    raise SyntaxError(f"Invalid modifier: {mod}")
