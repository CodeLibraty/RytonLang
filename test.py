import re
from functools import lru_cache

class ClassTransformer:
    def transform_slots(self, code):
        def replace_slots(match):
            fields = match.group(1)
            return f"{{.packed.}}"
        return re.sub(r'slots \{([\s\S]*?)\}', replace_slots, code)

    def OOP_Transformation(self, code):
        # Гипер Функции
        hyperfunc_patterns = [
            r'hyperfunc\s+(\w+)\s*::\s*([\w\s\|]+)\s*' 
        ]

        for pattern in hyperfunc_patterns:
            matches = re.finditer(pattern, code)
            for match in matches:
                legacy = match.group(2).replace('|', ',')
                name = match.group(1)
                template = f"type {name}* = object of {legacy}"
                code = re.sub(re.escape(match.group(0)), template, code)

        # Классы с/без наследования и метамодификаторов
        class_patterns = [
            r'pack\s+(\w+)\s+\:\:\s+(\w+)\s*!(.*?)\s* \{',    
            r'pack\s+(\w+)\s+\:\:\s+(\w+)',             
            r'pack\s+(\w+)\s*!(.*?)\s* \{',             
            r'pack\s+(\w+)\s*'                   
        ]
        
        for pattern in class_patterns:
            matches = re.finditer(pattern, code)
            for match in matches:
                groups = match.groups()
                if len(groups) == 3:  # С наследованием и модификатором
                    name, parent, mod = groups
                    template = f'type {name}* = object of {parent} {{.{mod}.}}'
                elif len(groups) == 2:
                    if '::' in match.group(0):  # Только наследование
                        name, parent = groups
                        template = f'type {name}* = object of {parent}'
                    else:  # Только модификатор
                        name, mod = groups
                        template = f'type {name}* = object {{.{mod}.}}'
                else:  # Только имя
                    name = groups[0]
                    template = f'type {name}* = object'

                code = re.sub(re.escape(match.group(0)), template, code)

        # Функции с/без аргументов и метамодификаторов
        func_patterns = [
            r'func\s+(\w+)\s*\((.*?)\)\s*!(.*?)\s* \{',  
            r'func\s+(\w+)\s*\((.*?)\)\s* \{',           
            r'func\s+(\w+)\s*!(.*?)\s* \{',                
            r'func\s+(\w+)\s* \{'                          
        ]

        for pattern in func_patterns:
            matches = re.finditer(pattern, code)
            for match in matches:
                groups = match.groups()
                if len(groups) == 3:  # С аргументами и модификатором
                    name, args, mod = groups
                    mods = list(mod.split('|'))
                    modificators = ''
                    for mod in mods:
                        modificators += f'{{.{mod}.}}'
                    template = f'\nproc {name}*({args}) {modificators} ='

                elif len(groups) == 2:
                    if '(' in match.group(0):  # Только аргументы
                        name, args = groups
                        template = f'\nproc {name}*({args}) ='
                    else:  # Только модификатор
                        name, mod = groups
                        mods = list(mod.split('|'))
                        modificators = ''
                        for mod in mods:
                            modificators += f'{{.{mod}.}}'
                        template = f'\nproc {name}*() {modificators} ='
                else:  # Без аргументов и модификаторов
                    name = groups[0]
                    template = f'\nproc {name}*() ='
                
                code = re.sub(re.escape(match.group(0)), template, code)

        return code


class FunctionTransformer:
    @lru_cache(maxsize=128)
    def transform_func(self, code):
        return re.sub(r'func \s*(\w+)\s*\(\s*(.*?)\s*\) :', 
                     r'proc \1(\2) =', code)

    @lru_cache(maxsize=128)
    def transform_func2(self, code):
        return re.sub(r'func \s*(\w+)\s* :', 
                     r'proc \1() =', code)

    @lru_cache(maxsize=128)
    def transform_func3(self, code):
        return re.sub(r'func \s*(\w+)\s*\(\s*(.*?)\s*\) -> \s*(.*?)\s*:', 
                     r'proc \1(\2): \3 =', code)

class ControlFlowTransformer:
    def transform_infinit(self, code):
        def replace_infinit(match):
            indent = match.group(1)
            delay = match.group(2)
            return f"{indent}while true:\n{indent}  sleep({delay})"
        return re.sub(r'([ \t]*)infinit\s*(.*?)\s*:', replace_infinit, code)

    def transform_repeat(self, code):
        def replace_repeat(match):
            indent = match.group(1)
            count = match.group(2)
            delay = match.group(3)
            return f"{indent}for _ in 0..<{count}:\n{indent}  sleep({delay})"
        return re.sub(r'([ \t]*)repeat\s*(.*?)\s* \s*(.*?)\s* :', 
                     replace_repeat, code)

class DataTransformer:
    def transform_table(self, code):
        def replace_table(match):
            table_name = match.group(1)
            table_body = match.group(2)
            
            result = [f"var {table_name} = newTable[string, any]()"]
            for line in table_body.strip().split('\n'):
                if ':=' in line:
                    key, expr = line.split(':=')
                    result.append(
                        f"{table_name}[\"{key.strip()}\"] = proc(): auto = {expr.strip()}"
                    )
                elif ':' in line:
                    key, value = line.split(':')
                    result.append(
                        f"{table_name}[\"{key.strip()}\"] = {value.strip()}"
                    )
            return '\n'.join(result)
            
        return re.sub(r'table\s+([\s\S]*?)\s*\{\s*([\s\S]*?)\s*\}', 
                     replace_table, code)

class EventTransformer:
    def transform_event(self, code):
        def replace_event(match):
            indent = match.group(1)
            item1 = match.group(2)
            item2 = match.group(3)
            code = match.group(4)
            return f"""
{indent}proc {item1}() {{.event.}} =
{indent}  if {item2}:
{indent}    {code}
"""
        return re.sub(r'([ \t]*)event \s*(.*?)\s* -> \s*(.*?)\s* {\s*([\s\S]*?)\s*}', 
                     replace_event, code)

class ImportTransformer:
    def transform_import_modules(self, code):
        def replace_module(match):
            module = match.group(1)
            sub = match.group(2)
            sub_modules = match.group(3)

            sub_modules = re.sub(r'\|', ',', sub_modules)
            sub_modules = re.sub(r'/', '.', sub_modules)

            if ':' in sub_modules:
                imports = []
                for item in sub_modules.split(','):
                    if ':' in item:
                        name, alias = item.strip().split(':')
                        imports.append(f"from {name.strip()} import {alias.strip()}")
                    else:
                        imports.append(f"import {item.strip()}")
                sub_modules = '\n'.join(imports)
            
            if '.' in sub:
                return f'from {module}.{".".join(sub.split("."))} import {sub_modules}'
                
            if '*' in sub_modules:
                return f'from {module}.{sub} import *'
                
            return f'from {module}.{sub} import {sub_modules}'

        return re.sub(r'from \s*(.*?)\s* import \s*(\w+)\s*\[\s*([\s\S]*?)\s*\]', 
                     replace_module, code)

    def transform_pylib(self, code):
        return re.sub(r'pylib: \s*(\w+)\s*', 
                     r'let \1 = pyImport("\1")', code)

    def transform_jvmlib(self, code):
        def replace_jvmlib(match):
            module_path = match.group(1)
            alias = match.group(2)
            return f'let {alias} = jvmImport("{module_path}")'
        return re.sub(r'jvmlib:\s*([^\s]+)\s+as\s+(\w+)', 
                     replace_jvmlib, code)

class MetaModTransformer:
    def transform_meta_modifiers(self, code):
        META_MODIFIERS = {
            'slots':     '{.packed.}',
            'frozen':    '{.frozen.}',
            'final':     '{.final.}',
            'singleton': '{.singleton.}',
            'interface': '{.pure.}',
            'immutable': '{.immutable.}',
            
            'async':     '{.async.}',
            'pure':      '{.pure.}',
            'cached':    '{.memoized.}',
            'timeout':   '{.timeout.}',
            'retry':     '{.retry.}',
            'trace':     '{.trace.}',
            'validate':  '{.validate.}',
            'profile':   '{.profile.}',
            'logged':    '{.logged.}',
            'metrics':   '{.metrics.}'
        }
        
        def replace_modifier(match):
            modifier = match.group(1)
            if modifier in META_MODIFIERS:
                return META_MODIFIERS[modifier]
            return match.group(0)
        
        return re.sub(r'\@(.*?)\n', replace_modifier, code)

class ErrorHandlingTransformer:
    def transform_elerr(self, code):
        return re.sub(r'try {\s*(.*?)\s*} elerr {\s*(.*?)\s*}', 
                     r'try:\n  \1\nexcept:\n  \2', code)

    def transform_elerr2(self, code):
        return re.sub(r'try {\s*(.*?)\s*} elerr \s*(.*?)\s* {\s*(.*?)\s*}', 
                     r'try:\n  \1\nexcept \2:\n  \3', code)

    def transform_elerr3(self, code):
        return re.sub(r'elerr \s*(.*?)\s* :', 
                     r'except \1:', code)

    def transform_elerr4(self, code):
        return re.sub(r'elerr :', 
                     r'except:', code)

class ContractTransformer:
    def transform_contracts(self, code):
        def replace_contracts(match):
            func_name = match.group(1)
            return_type = match.group(2)
            requires = match.group(3)
            ensures = match.group(4)
            body = match.group(6)

            result = f"""proc {func_name}(): {return_type} =
  assert {requires}, "Precondition failed"
  let result = {body.strip()}
  assert {ensures}, "Postcondition failed"
  result"""
            return result

        return re.sub(r'func\s+(\w+)\s*\((.*?)\)\s*:\s*(\w+)\s*:\s*require\s+(.*?)\s*ensure\s+(.*?)\s*body\s*{\s*(.*?)\s*}', 
                     replace_contracts, code)

class DSLTransformer:
    def transform_dsl(self, code):
        def replace_dsl(match):
            dsl_name = match.group(1)
            dsl_body = match.group(2)
            return f"""macro {dsl_name}*(body: untyped): untyped =
  result = quote do:
    {dsl_body}"""
        return re.sub(r'dsl\s+(\w+)\s*{\s*([\s\S]*?)\s*}', 
                     replace_dsl, code)

class OperatorTransformer:
    def transform_pipe_operator(self, code):
        return re.sub(r'(\w+)\s*\|>\s*(\w+)', 
                     r'\2(\1)', code)

    def transform_spaceship_operator(self, code):
        return re.sub(r'(\w+)\s*<=>\s*(\w+)', 
                     r'cmp(\1, \2)', code)

    def transform_function_composition(self, code):
        return re.sub(r'(\w+)\s*>>\s*(\w+)', 
                     r'proc(x: auto): auto = \2(\1(x))', code)

class StructTransformer:
    def transform_struct(self, code):
        def replace_struct(match):
            struct_name = match.group(1)
            fields = match.group(2)

            result = [f"type {struct_name} = object"]
            
            for field in fields.strip().split('\n'):
                if not field.strip():
                    continue

                name, type_info = field.split(':')
                name = name.strip()
                type_info = type_info.strip()

                if '(' in type_info:
                    type_name = type_info.split('(')[0]
                    constraints = type_info.split('(')[1].split(')')[0]
                    result.append(f"  {name}*: {type_name}")
                    
                    for constraint in constraints.split(','):
                        key = constraint.split('=')
                        value = constraint.split('=')
                        result.append(f"  {name}Constraint{key}* = {value}")
                else:
                    result.append(f"  {name}*: {type_info}")

            return '\n'.join(result)

        return re.sub(r'struct\s+(\w+)\s*\{([\s\S]*?)\}', replace_struct, code)

class ConfigTransformer:
    def transform_config_blocks(self, code):
        def parse_config_section(lines, indent=0):
            result = {}
            i = 0
            while i < len(lines):
                line = lines[i].strip()
                if not line:
                    i += 1
                    continue
                    
                if '{' in line and ':' not in line:
                    section_name = line.replace('{', '').strip()
                    section_content = []
                    brace_count = 1
                    i += 1
                    
                    while i < len(lines) and brace_count > 0:
                        if '{' in lines[i]: brace_count += 1
                        if '}' in lines[i]: brace_count -= 1
                        if brace_count > 0:
                            section_content.append(lines[i])
                        i += 1
                        
                    result[section_name] = parse_config_section(section_content)
                elif ':' in line:
                    key, value = line.split(':', 1)
                    result[key.strip()] = value.strip().rstrip(',')
                i += 1
            return result

        def format_table(d, indent=1):
            lines = [f"var configTable = newTable[string, auto]()"]
            for key, value in d.items():
                if isinstance(value, dict):
                    sub_table = format_table(value, indent + 1)
                    lines.append(f"configTable[\"{key}\"] = {sub_table}")
                else:
                    lines.append(f"configTable[\"{key}\"] = {value}")
            return '\n'.join(lines)

        def replace_config(match):
            config_name = match.group(1)
            config_body = match.group(2)
            
            config_dict = parse_config_section(config_body.split('\n'))
            config_str = format_table(config_dict)
            
            return f"""type {config_name}* = object
  config: TableRef[string, auto]

proc new{config_name}*(): {config_name} =
  {config_str}
  result = {config_name}(config: configTable)

proc get*[T](self: {config_name}, key: string): T =
  self.config[key].to(T)
"""

        return re.sub(r'config\s+(\w+)\s*\{([\s\S]*?)\}', replace_config, code)

class MacroTransformer:
    def transform_macro(self, code):
        def replace_macro(match):
            macro_name = match.group(1)
            params = match.group(2).split(',')
            body = match.group(3)
            
            return f"""macro {macro_name}*({', '.join(f'{p}: untyped' for p in params)}): untyped =
  result = quote do:
    {body}"""
            
        return re.sub(r'macro\s+(\w+)\s*\((.*?)\)\s*\{([\s\S]*?)\}', replace_macro, code)

class ReactiveTransformer:
    def transform_reactive(self, code):
        def replace_stream(match):
            indent = match.group(1)
            stream_var = match.group(2)
            operations = match.group(3)
            target = match.group(4)
            
            stream_code = f"{indent}var stream = newStream[auto]()"
            
            for line in operations.split('\n'):
                line = line.strip()
                if line.startswith('filter'):
                    cond = line[7:-1]
                    stream_code += f"\n{indent}stream.filter(proc(x: auto): bool = {cond})"
                elif line.startswith('transform'):
                    trans = line[10:-1]
                    stream_code += f"\n{indent}stream.map(proc(x: auto): auto = {trans})"
            
            stream_code += f"\n{indent}stream.subscribe({target})"
            return stream_code

        return re.sub(r'([ \t]*)(\w+)\.stream\s*\{([\s\S]*?)\}\s*->\s*(\w+)', 
                     replace_stream, code)

class ProtectTransformer:
    def transform_protect(self, code):
        def replace_protect(match):
            name = match.group(1)
            body = match.group(2)
            
            return f"""type {name}Protected = object
  value: ref object
  owner: typedesc

proc get(self: {name}Protected): auto =
  self.value[]

proc set(self: var {name}Protected, val: auto) =
  if self.owner.isNil:
    self.owner = typeof(self)
  if self.owner == typeof(self):
    self.value = new(typeof(val))
    self.value[] = val
  else:
    raise newException(AccessDefect, "Protected access denied")

{body}"""

        return re.sub(r'protect\s+(\w+)\s*{([\s\S]*?)}', replace_protect, code)


class DocTransformer:
    def transform_doc_comments(self, code):
        def replace_doc(match):
            indent = match.group(1)
            content = match.group(2)
            return f'{indent}## \n{indent}## {content}\n{indent}##'

        return re.sub(
            r'^([ \t]*?)/!/\s*([\s\S]*?)/!/',
            replace_doc,
            code,
            flags=re.MULTILINE
        )

class ZigTransformer:
    def transform_zig_tags(self, code):
        pattern = r'#Zig\(start\)([\s\S]*?)#Zig\(end:\s*([^)]*)\)'
        
        def replace(match):
            zig_code = match.group(1).strip()
            return_var = match.group(2).strip()
            
            return f"""
const zig = ZigCompiler.new()
var {return_var} = zig.compileAndRun('''
{zig_code}
''')
"""
        return re.sub(pattern, replace, code)

    def transform_zig_export(self, code):
        def process_zig_block(match):
            zig_code = match.group(2)
            module_name = match.group(3)
            
            exports = []
            for fn_match in re.finditer(r'pub fn (\w+)\((.*?)\)(.*?){', zig_code):
                fn_name = fn_match.group(1)
                
            modified_code = zig_code.replace('pub fn', 'export fn')

            return f"""
const zig = ZigCompiler.new()
var {module_name} = zig.loadModule('''
{modified_code}
''')
"""

        return re.sub(r'([ \t]*)#ZigModule\(([\s\S]*?)\)\s*->\s*(\w+)', 
                     process_zig_block, code)

class MainTransformer:
    def transform_init(self, code):
        def replace_init(match):
            indent = match.group(1)
            return f"{indent}proc init*() ="

        return re.sub(r'([ \t]*)init\s*:', replace_init, code)

class RytonToNimTransformer:
    def __init__(self):
        self.class_transformer = ClassTransformer()
        self.function_transformer = FunctionTransformer()
        self.control_flow_transformer = ControlFlowTransformer()
        self.data_transformer = DataTransformer()
        self.event_transformer = EventTransformer()
        self.import_transformer = ImportTransformer()
        self.meta_mod_transformer = MetaModTransformer()
        self.error_transformer = ErrorHandlingTransformer()
        self.contract_transformer = ContractTransformer()
        self.dsl_transformer = DSLTransformer()
        self.operator_transformer = OperatorTransformer()
        self.struct_transformer = StructTransformer()
        self.config_transformer = ConfigTransformer()
        self.macro_transformer = MacroTransformer()
        self.reactive_transformer = ReactiveTransformer()
        self.protect_transformer = ProtectTransformer()
        self.doc_transformer = DocTransformer()
        self.zig_transformer = ZigTransformer()
        self.main_transformer = MainTransformer()

    def transform_to_nim(self, code):
        # Базовые замены
        replacements = {
            'noop': 'discard',
            '&': 'and',
            '//': '#',
            'this': 'self'
        }
        for old, new in replacements.items():
            code = code.replace(old, new)

        # Применяем все трансформации
        transformations = [
            self.zig_transformer.transform_zig_tags,
            self.zig_transformer.transform_zig_export,
            self.doc_transformer.transform_doc_comments,
            self.import_transformer.transform_import_modules,
            self.macro_transformer.transform_macro,
            self.struct_transformer.transform_struct,
            self.config_transformer.transform_config_blocks,
            self.meta_mod_transformer.transform_meta_modifiers,
            self.reactive_transformer.transform_reactive,
            self.protect_transformer.transform_protect,
            self.event_transformer.transform_event,
            self.contract_transformer.transform_contracts,
            self.data_transformer.transform_table,
            self.class_transformer.OOP_Transformation,
            self.class_transformer.transform_slots,
            self.function_transformer.transform_func3,
            self.function_transformer.transform_func2,
            self.function_transformer.transform_func,
            self.control_flow_transformer.transform_infinit,
            self.control_flow_transformer.transform_repeat,
            self.error_transformer.transform_elerr,
            self.error_transformer.transform_elerr2,
            self.error_transformer.transform_elerr3,
            self.error_transformer.transform_elerr4,
            self.operator_transformer.transform_pipe_operator,
            self.operator_transformer.transform_spaceship_operator,
            self.operator_transformer.transform_function_composition,
            self.main_transformer.transform_init
        ]

        for transform in transformations:
            code = transform(code)

        return code

ryton_code = """
module import {
    std.lib
    std.Math[sin|cos]
    pandas:pd
}

trash_cleaner = true

// Контракты и функции
func calculate(x: Int) !Int {
    require x > 0
    ensure result > x 
    body {
        return x * 2
    }
}

// Пакеты и наследование
pack BaseProcessor {
    data: any
}

pack DataProcessor :: BaseProcessor !cached|async {
    config: Config
    
    func process() !void {
        infinit 1.0 {
            this.data |> transform |> save
        }
    }
}

// Таблицы с вычисляемыми полями
table Config {
    theme := get_system_theme()
    max_items: 1000
    active := check_status()
}

// Структуры с валидацией
struct UserData {
    name: str(min=2, max=50)
    age: int(min=0, max=150)
    email: str(pattern="^[a-z]+@[a-z]+\.[a-z]{2,}$")
}

// События
event data_ready -> status == "ready" {
    process_data()
}

// Защищенные блоки
protect SecureData {
    private key: str
    func access() !str {
        return this.key
    }
}


// Макросы
macro debug(expr) {
    print(f"Debug: {expr} = {eval(expr)}")
}

// Интеграция с Zig
#ZigModule(
    fn fast_calc(x: i32) i32 {
        return x * 2;
    }
) -> math_utils

// Конфигурация
config AppConfig {
    server {
        host: "localhost"
        port: 8080
    }
    database {
        url: "postgres://localhost:5432"
        pool_size: 10
    }
}

// Главная функция
func main() !void {
    processor = DataProcessor()
    processor.process()
    
    repeat 5 1.0 {
        result = calculate(10) >> transform >> output
        debug(result)
    }
}

main()

"""

transformer = RytonToNimTransformer()
nim_code = transformer.transform_to_nim(ryton_code)
print(nim_code)