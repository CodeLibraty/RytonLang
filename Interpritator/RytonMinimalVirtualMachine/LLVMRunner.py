from llvmlite import binding
import LLVMCompiler

def compile_to_executable(ir_code, output_name):
    # Инициализация LLVM
    binding.initialize()
    binding.initialize_native_target()
    binding.initialize_native_asmprinter()
    
    # Создаем модуль из IR
    mod = binding.parse_assembly(ir_code)
    
    # Создаем движок для компиляции
    target = binding.Target.from_default_triple()
    target_machine = target.create_target_machine()
    
    # Компилируем в объектный файл
    obj_bin = target_machine.emit_object(mod)
    
    # Сохраняем объектный файл
    with open(f"{output_name}.o", "wb") as f:
        f.write(obj_bin)
    
    # Линкуем в исполняемый файл
    import os
    os.system(f"gcc {output_name}.o -o {output_name}")

# Использование:
compiler = LLVMCompiler.RytonBytecodeToLLVM()
ir_code = compiler.compile("↑2↓↑x◈⏎")
compile_to_executable(ir_code, "rython_program")
