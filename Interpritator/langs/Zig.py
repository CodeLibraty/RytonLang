import subprocess
import tempfile
import os

class ZigRun:
    def __init__(self):
        self.zig_path = "./langs/!ZigEnv/zig"
        self.temp_dir = tempfile.mkdtemp()
        
    def run_code(self, code: str) -> str:
        # Создаем временный файл с кодом
        temp_file = os.path.join(self.temp_dir, "temp.zig")
        with open(temp_file, "w") as f:
            f.write(code)
            
        # Сразу запускаем через zig run
        result = subprocess.run(
            [self.zig_path, "run", temp_file],
            capture_output=True,
            text=True
        )
        
        # Чистим за собой
        os.remove(temp_file)
        
        return result.stdout

    def compile_lib(self, code: str) -> str:
        temp_file = os.path.join(self.temp_dir, "lib.zig") 
        with open(temp_file, "w") as f:
            f.write(code)
            
        subprocess.run([self.zig_path, "build-lib", temp_file, "-dynamic"], 
                      check=True)
        
        return os.path.join(".", "lib")
