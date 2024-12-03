import re
from typing import Any, Dict, List, Union

# Hyper Config Format

class hcf:
    @staticmethod
    def load(file_path: str) -> Dict[str, Any]:
        with open(file_path, 'r') as file:
            content = file.read()
        return hcf._parse(content)

    @staticmethod
    def dump(data: Dict[str, Any], file_path: str) -> None:
        content = hcf._serialize(data)
        with open(file_path, 'w') as file:
            file.write(content)

    @staticmethod
    def _parse(content: str) -> Dict[str, Any]:
        lines = content.split('\n')
        return hcf._parse_block(lines, 0, 0)[0]

    @staticmethod
    def _parse_block(lines: List[str], start: int, indent: int) -> tuple[Dict[str, Any], int]:
        result = {}
        i = start
        while i < len(lines):
            line = lines[i].strip()
            if not line or line.startswith('#'):
                i += 1
                continue

            current_indent = len(lines[i]) - len(lines[i].lstrip())
            if current_indent < indent:
                break

            if ':' in line:
                key, value = line.split(':', 1)
                key = key.strip()
                value = value.strip()

                if value:
                    result[key] = hcf._parse_value(value)
                else:
                    sub_block, i = hcf._parse_block(lines, i + 1, current_indent + 2)
                    result[key] = sub_block
            i += 1
        return result, i

    @staticmethod
    def _parse_value(value: str) -> Union[str, int, float, bool, List[Any], Dict[str, Any]]:
        if value.startswith('"') and value.endswith('"'):
            return value[1:-1]
        elif value.lower() in ('true', 'yes'):
            return True
        elif value.lower() in ('false', 'no'):
            return False
        elif value.replace('.', '').isdigit():
            return float(value) if '.' in value else int(value)
        elif value.startswith('[') and value.endswith(']'):
            return [hcf._parse_value(v.strip()) for v in value[1:-1].split(',')]
        else:
            return value

    @staticmethod
    def _serialize(data: Dict[str, Any], indent: int = 0) -> str:
        result = []
        for key, value in data.items():
            if isinstance(value, dict):
                result.append(f"{' ' * indent}{key}:")
                result.append(hcf._serialize(value, indent + 2))
            elif isinstance(value, list):
                result.append(f"{' ' * indent}{key}: [{', '.join(map(str, value))}]")
            elif isinstance(value, str):
                result.append(f'{" " * indent}{key}: "{value}"')
            else:
                result.append(f"{' ' * indent}{key}: {value}")
        return '\n'.join(result)


#data = {
#    "name": "John Doe",
#    "age": 30,
#    "is_student": False,
#    "hobbies": ["reading", "swimming", "coding"],
#    "address": {
#        "street": "123 Main St",
#        "city": "New York",
#        "country": "USA"
#    }
#}

# Сохранение данных в файл
#hcf.dump(data, "example.hcf")
# Чтение данных из файла
#loaded_data = hcf.load("example.hcf")

#print(loaded_data)