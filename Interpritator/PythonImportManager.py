import sys
import os

class UserDirLoader:
    def __init__(self, user_dir):
        self.user_dir = user_dir
        
    def load_module(self, name):
        module_path = os.path.join(self.user_dir, f"{name}.py")
        if os.path.exists(module_path):
            with open(module_path) as f:
                code = f.read()
            module = type(name, (), {})
            exec(code, module.__dict__)
            sys.modules[name] = module
            return module
        return None