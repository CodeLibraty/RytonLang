class CompileTimeMacro:
    def __init__(self):
        self.generators = {}
    
    def register(self, name, generator):
        self.generators[name] = generator
        
    def apply(self, target_type, macro_name):
        if macro_name in self.generators:
            return self.generators[macro_name](target_type)
        return None