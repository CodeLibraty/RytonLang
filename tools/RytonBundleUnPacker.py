import os
import json
import struct

def unpack_ryx(ryx_path: str, extract_dir: str):
    with open(ryx_path, 'rb') as ryx:
        # Проверяем магическое число
        magic = ryx.read(4)
        if magic != b'RYX1':
            raise ValueError("Invalid RYX file format")
            
        # Читаем метаданные
        metadata_size = struct.unpack('<I', ryx.read(4))[0]
        metadata = json.loads(ryx.read(metadata_size))
        
        # Читаем содержимое файлов
        content_data = json.loads(ryx.read().decode('utf-8'))
        
        # Создаем директорию для распаковки
        os.makedirs(extract_dir, exist_ok=True)
        
        # Распаковываем файлы
        for file_entry in content_data:
            # Получаем путь и имя файла
            dir_path = file_entry["info"][0]["dir"]
            filename = file_entry["info"][1]["file"]
            content = file_entry["content"]
            
            # Создаем поддиректории
            full_dir = os.path.join(extract_dir, dir_path)
            os.makedirs(full_dir, exist_ok=True)
            
            # Записываем файл
            full_path = os.path.join(full_dir, filename)
            with open(full_path, 'w', encoding='utf-8') as f:
                f.write(content)
                
        return metadata