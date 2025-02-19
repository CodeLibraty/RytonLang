import os
import shutil
import json
import csv
import xml.etree.ElementTree as ET
import pickle

# 4. Чтение JSON файла
def read_json(file_path):
    with open(file_path, 'r', encoding='utf-8') as file:
        return json.load(file)

# 5. Запись в JSON файл
def write_json(file_path, data):
    with open(file_path, 'w', encoding='utf-8') as file:
        json.dump(data, file, ensure_ascii=False, indent=4)

# 6. Чтение CSV файла
def read_csv(file_path):
    with open(file_path, 'r', newline='', encoding='utf-8') as file:
        reader = csv.reader(file)
        return list(reader)

# 7. Запись в CSV файл
def write_csv(file_path, data):
    with open(file_path, 'w', newline='', encoding='utf-8') as file:
        writer = csv.writer(file)
        writer.writerows(data)

# 8. Чтение XML файла
def read_xml(file_path):
    tree = ET.parse(file_path)
    return tree.getroot()

# 9. Запись в XML файл
def write_xml(file_path, root):
    tree = ET.ElementTree(root)
    tree.write(file_path, encoding='utf-8', xml_declaration=True)

# 14. Сериализация объекта в файл
def serialize_object(obj, file_path):
    with open(file_path, 'wb') as file:
        pickle.dump(obj, file)

# 15. Десериализация объекта из файла
def deserialize_object(file_path):
    with open(file_path, 'rb') as file:
        return pickle.load(file)
