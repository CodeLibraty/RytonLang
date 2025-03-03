from dataclasses import dataclass
from typing import Any, Dict, List
import re

@dataclass 
class RytValue:
    raw: str
    parsed: Any
    type: str

class RyTable:
    def parse_meta(self, content: str) -> Dict[str, str]:
        meta = {}
        if match := re.search(r'#meta\s*{([^}]*)}', content, re.DOTALL):
            for line in match.group(1).splitlines():
                if '=' in line:
                    k, v = line.split('=', 1)
                    meta[k.strip()] = v.strip()
        return meta

    def parse_vars(self, content: str) -> Dict[str, str]:
        vars = {}
        if match := re.search(r'\$vars\s*{([^}]*)}', content, re.DOTALL):
            for line in match.group(1).splitlines():
                if '->' in line:
                    k, v = line.split('->', 1)
                    # Сохраняем чистое значение без кавычек
                    vars[k.strip()] = v.strip().strip('"')
        return vars

    def parse_sections(self, content: str, vars: Dict[str, str]) -> Dict[str, Dict[str, RytValue]]:
        sections = {}
        for match in re.finditer(r'\*(\w+)\s*{([^}]*)}', content, re.DOTALL):
            name = match.group(1)
            section = {}
            
            for line in match.group(2).splitlines():
                line = line.strip()
                if '=' in line:
                    k, v = line.split('=', 1)
                    k = k.strip()
                    raw = v.strip()
                    
                    # Обработка диапазонов
                    if range_match := re.match(r'\[([\d]+)\.\.([\d]+)\]', raw):
                        start, end = map(int, range_match.groups())
                        section[k] = RytValue(raw, list(range(start, end + 1)), 'range')
                        
                    # Обработка enum
                    elif enum_match := re.match(r'<([^>]+)>', raw):
                        values = [x.strip() for x in enum_match.group(1).split('|')]
                        section[k] = RytValue(raw, values, 'enum')
                        
                    # Обработка строк с переменными
                    else:
                        result = raw
                        for var_k, var_v in vars.items():
                            placeholder = f'${{{var_k}}}'
                            if placeholder in result:
                                result = result.replace(placeholder, var_v)
                        section[k] = RytValue(raw, result, 'string')
            
            sections[name] = section
        return sections

    def parse_validators(self, content: str) -> Dict[str, str]:
        validators = {}
        if match := re.search(r'\+validators\s*{([^}]*)}', content, re.DOTALL):
            for line in match.group(1).splitlines():
                if '->' in line:
                    k, v = line.split('->', 1)
                    validators[k.strip()] = v.strip()
        return validators

    def parse_rules(self, content: str) -> List[str]:
        rules = []
        if match := re.search(r'\?rules\s*{([^}]*)}', content, re.DOTALL):
            rules = [r.strip() for r in match.group(1).splitlines() if r.strip()]
        return rules

    def parse(self, content: str) -> Dict[str, Any]:
        if not content.startswith('@RYT1'):
            raise ValueError("Invalid RYT format - missing @RYT1 header")

        # Убираем комментарии
        content = re.sub(r'//.*$', '', content, flags=re.MULTILINE)
        
        # Парсим все блоки
        vars = self.parse_vars(content)
        
        return {
            'meta': self.parse_meta(content),
            'vars': vars,
            'sections': self.parse_sections(content, vars),
            'validators': self.parse_validators(content),
            'rules': self.parse_rules(content)
        }
