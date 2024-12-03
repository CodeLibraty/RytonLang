class DSL:
    def __init__(self, name):
        self.name = name
        self.keywords = {}

    def add_keyword(self, keyword, function):
        self.keywords[keyword] = function

    def parse(self, code):
        lines = code.strip().split('\n')
        result = []
        for line in lines:
            words = line.strip().split()
            if words and words[0] in self.keywords:
                result.append(self.keywords[words[0]](words[1:]))
        return result

def create_dsl(name):
    return DSL(name)

class DSLContext:
    def __init__(self, dsl):
        self.dsl = dsl

    def __enter__(self):
        return self.dsl

    def __exit__(self, exc_type, exc_val, exc_tb):
        pass

def use_dsl(dsl):
    return DSLContext(dsl)
