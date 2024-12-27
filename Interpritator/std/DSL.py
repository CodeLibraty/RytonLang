class DSL:
    def __init__(self, name):
        self.name = name
        self.commands = {}
        self.variables = {}
        self.functions = {}
        
    def add_command(self, name, executor):
        """Добавляет команду в DSL"""
        self.commands[name] = executor
        
    def add_variable(self, name, value):
        """Добавляет переменную в область видимости DSL"""
        self.variables[name] = value
        
    def add_function(self, name, func):
        """Добавляет функцию в DSL"""
        self.functions[name] = func
        
    def execute(self, code):
        """Выполняет код на этом DSL"""
        tokens = self.tokenize(code)
        return self.process_tokens(tokens)
        
    def tokenize(self, code):
        """Разбивает код на токены"""
        return [line.split() for line in code.strip().split('\n') if line.strip()]
        
    def process_tokens(self, tokens):
        """Обрабатывает токены и выполняет команды"""
        results = []
        for token_line in tokens:
            if token_line:
                command = token_line[0]
                args = token_line[1:]
                if command in self.commands:
                    result = self.commands[command](args, self.variables, self.functions)
                    results.append(result)
        return results

def create_dsl(name):
    return DSL(name)



class DSLContext:
    def __init__(self, dsl):
        self.dsl = dsl
        self.previous_context = None

    def __enter__(self):
        self.previous_context = dict(self.dsl.context)
        return self.dsl

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.dsl.context = self.previous_context

def use_dsl(dsl):
    return DSLContext(dsl)
