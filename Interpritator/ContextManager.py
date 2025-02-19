class Context:
    def __init__(self, name):
        self.name = name
        self.variables = {}
        self.functions = {}

class ContextManager:
    def __init__(self):
        self.contexts = {}
        self.context_stack = []
        self.current_context = None

    def create_context(self, name):
        self.contexts[name] = Context(name)
        
    def context(self, *names):
        for name in names:
            if name in self.contexts:
                self.context_stack.append(self.current_context)
                self.current_context = self.contexts[name]
            
    def context_off(self):
        self.current_context = None
        self.context_stack.clear()
        
    def context_back(self):
        if self.context_stack:
            self.current_context = self.context_stack.pop()
            
    def get_variable(self, name):
        if self.current_context:
            return self.current_context.variables.get(name)
        return None
        
    def set_variable(self, name, value):
        if self.current_context:
            self.current_context.variables[name] = value
