from zipfile import ZipFile
import subprocess
import os

class RytonPacker:
    def pack_project(self, src_dir: str, output_name: str):
        with ZipFile(f"{output_name}.pack", 'w') as pack:
            for root, _, files in os.walk(src_dir):
                for file in files:
                    full_path = os.path.join(root, file)
                    rel_path = os.path.relpath(full_path, src_dir)
                    
                    if file.endswith('.ry'):
                        # Транслируем в Python
                        python_code = subprocess.run(['ryton', 'translate', full_path], stdout=subprocess.PIPE).stdout.decode('utf-8')
                        
                        # Записываем .py прямо в zip
                        py_path = rel_path[:-3] + '.py'
                        pack.writestr(py_path, python_code)
                    elif file.endswith('.pack'):
                        pass
                    else:
                        # Копируем остальные файлы как есть
                        pack.write(full_path, rel_path)


