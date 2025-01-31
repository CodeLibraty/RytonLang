import ast
import os

IGNORE_METHODS = {
    'init', '__init__', 'main',
    'run', 'setup', 'quit',
    'delete', 'load'
}

def extract_methods(directory="Interpritator/std/"):
    methods_doc = {}
    
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.py'):
                module_path = os.path.join(root, file)
                module_name = module_path.replace('/', '.')[:-3]
                
                with open(module_path) as f:
                    tree = ast.parse(f.read())
                    
                methods = []
                for node in ast.walk(tree):
                    if isinstance(node, ast.FunctionDef):
                        if node.name not in IGNORE_METHODS:
                            args = [arg.arg for arg in node.args.args]
                            methods.append({
                                'name': node.name,
                                'args': args,
                                'returns': ast.unparse(node.returns) if node.returns else None,
                                'module': module_name
                            })
                            
                if methods:
                    methods_doc[module_name] = sorted(methods, key=lambda x: x['name'])
                    
    return methods_doc

methods = extract_methods()

with open('methods.md', 'w') as f:
    for module, funcs in methods.items():
        f.write(f"\n# {module}\n")
        for func in funcs:
            f.write(f"## {func['name']}({', '.join(func['args'])})\n")
            if func['returns']:
                f.write(f"Returns: {func['returns']}\n")
            f.write("\n")