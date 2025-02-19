import os
import json
import struct

def pack_ryx_project(project_dir: str, output_name: str):
    # Магическое число
    MAGIC = b'RYX1'
    
    # Собираем метаданные из project.ryton
    metadata = {
        "name": "app_name",
        "version": "1.0",
        "autor": "name",
        "License": "ROS-License + Mit", 
        "RytonRunTimeVersion": "0.1.1"
    }
    
    # Собираем файлы
    file_contents = []
    for root, dirs, files in os.walk(project_dir):
        for file in files:
            full_path = os.path.join(root, file)
            rel_path = os.path.relpath(full_path, project_dir)
            
            with open(full_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            file_contents.append({
                "info": [
                    {"dir": os.path.dirname(rel_path)},
                    {"file": os.path.basename(rel_path)}
                ],
                "content": content
            })

    # Формируем .ryx файл
    with open(output_name, 'wb') as ryx:
        # Записываем магическое число
        ryx.write(MAGIC)
        
        # Записываем метаданные
        metadata_bytes = json.dumps(metadata).encode('utf-8')
        ryx.write(struct.pack('<I', len(metadata_bytes)))
        ryx.write(metadata_bytes)
        
        # Записываем содержимое файлов
        ryx.write(json.dumps(file_contents).encode('utf-8'))
