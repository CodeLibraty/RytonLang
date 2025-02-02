from pathlib import Path
import subprocess
import hashlib
import ctypes
import os

class ZigBridge:
    def __init__(self, src_dir='./'):
        self.cache_dir = Path(".zig_cache")
        self.cache_dir.mkdir(exist_ok=True)
        self.export_path = Path(src_dir)

    def _run_binary(self, binary_path):
        result = subprocess.run(
            str(binary_path), 
            capture_output=True, 
            text=True
        )
        return result.stdout

    def compile_shared(self, zig_code, module_name):
        # Сохраняем текущую директорию
        current_dir = os.getcwd()

        try:
            # Переходим в директорию компиляции
            os.chdir(self.export_path)

            # Компилируем Zig код в разделяемую библиотеку
            with open(f"{module_name}.zig", "w") as f:
                f.write(zig_code)

            os.system(f"./Interpritator/ZigLang/zig build-lib {module_name}.zig -dynamic")
        finally:
            # Возвращаемся в исходную директорию
            os.chdir(current_dir)

    def import_zig_module(self, module_name):
        """Import Zig module from project directory"""
        # Check for existing .so file
        so_path = f"{self.export_path}/lib{module_name}.so"
        
        if os.path.exists(so_path):
            return ctypes.CDLL(so_path)
            
        # If no .so exists, compile from .zig
        module_path = os.path.join(self.export_path, f"{module_name}.zig")
        if not os.path.exists(module_path):
            raise ImportError(f"Zig module '{module_name}' not found at {module_path}")
            
        with open(module_path, 'r') as f:
            zig_code = f.read()
        
        self.compile_shared(zig_code, module_name)
        return ctypes.CDLL(so_path)

    def load_functions(self, zig_code, module_name):
        # Загружаем функции из скомпилированной библиотеки
        self.compile_shared(zig_code, module_name)
        lib = ctypes.CDLL(f"{self.export_path}/lib{module_name}.so")
        return lib

    def compile_and_run(self, zig_code: str, mode="bin", cache=True):
        if cache:
            code_hash = hashlib.md5(zig_code.encode()).hexdigest()
            cache_path = self.cache_dir / f"{code_hash}.exe"
            if cache_path.exists():
                return self._run_binary(cache_path)
        
        return self._compile_and_execute(zig_code, mode)

    def _create_build_zig(self):
        build_content = """
    const std = @import("std");

    pub fn build(b: *std.build.Builder) void {
        const target = b.standardTargetOptions(.{});
        const optimize = b.standardOptimizeOption(.{});
        
        const exe = b.addExecutable(.{
            .name = "temp",
            .root_source_file = .{ .path = "./zig/src/temp.zig" },
            .target = target,
            .optimize = optimize,
        });
        
        b.installArtifact(exe);
    }
    """
        Path("zig/build.zig").write_text(build_content)

    def _compile_and_execute(self, code, mode):
        self._create_build_zig()
        temp_file = Path("zig/src/temp.zig")
        temp_file.write_text(code)
        
        if mode == "run":
            result = subprocess.run(["./Interpritator/ZigLang/zig",
                                     "run",
                                     "zig/src/temp.zig"]) 
        elif mode == "obj":
            subprocess.run(["./Interpritator/ZigLang/zig", "build-obj", "temp.zig"])
            result = Path("temp.o")
        elif mode == "lib":
            subprocess.run(["./Interpritator/ZigLang/zig", "build-lib", "temp.zig"])
            result = Path("temp.lib")
            
        return result
