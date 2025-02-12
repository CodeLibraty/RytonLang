import re
from typing import List, Optional, Dict, Pattern, Match, Iterator

# Common regex patterns
PATTERNS = {
    'email': r'[\w\.-]+@[\w\.-]+\.\w+',
    'url': r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+',
    'phone': r'\+?\d{1,4}?[-.\s]?\(?\d{1,3}?\)?[-.\s]?\d{1,4}[-.\s]?\d{1,4}[-.\s]?\d{1,9}',
    'date': r'\d{4}-\d{2}-\d{2}',
    'time': r'\d{2}:\d{2}(:\d{2})?',
    'ip': r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b',
    'word': r'\b\w+\b',
    'number': r'-?\d*\.?\d+',
    'hex_color': r'#(?:[0-9a-fA-F]{3}){1,2}',
    'username': r'^[a-zA-Z0-9_]{3,16}',
    'password': r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}'
}


class Regex:
    """Powerful regular expression helper"""
    
    @staticmethod
    def compile(pattern: str, flags: int = 0) -> Pattern:
        """Compile regex pattern with flags"""
        return re.compile(pattern, flags)
        
    @staticmethod
    def match_all(pattern: str, text: str) -> List[Match]:
        """Find all matches in text"""
        return list(re.finditer(pattern, text))
    
    @staticmethod
    def extract_groups(pattern: str, text: str) -> List[tuple]:
        """Extract all groups from matches"""
        return re.findall(pattern, text)
        
    @staticmethod
    def split_by_pattern(pattern: str, text: str, maxsplit: int = 0) -> List[str]:
        """Split text by regex pattern"""
        return re.split(pattern, text, maxsplit)
        
    @staticmethod
    def replace_all(pattern: str, repl: str, text: str) -> str:
        """Replace all matches with replacement"""
        return re.sub(pattern, repl, text)
        
    @staticmethod
    def find_first(pattern: str, text: str) -> Optional[Match]:
        """Find first match in text"""
        return re.search(pattern, text)

    @staticmethod
    def validate(pattern: str, text: str) -> bool:
        """Check if entire text matches pattern"""
        return bool(re.fullmatch(pattern, text))
        
    @staticmethod
    def find_between(start: str, end: str, text: str) -> List[str]:
        """Find all text between start and end patterns"""
        pattern = f"{start}(.*?){end}"
        return re.findall(pattern, text, re.DOTALL)
        
    @staticmethod
    def remove_matches(pattern: str, text: str) -> str:
        """Remove all pattern matches from text"""
        return re.sub(pattern, '', text)
        
    @staticmethod 
    def count_matches(pattern: str, text: str) -> int:
        """Count pattern matches in text"""
        return len(re.findall(pattern, text))

    def replace(text: str, word: str, replacement: str) -> str:
        """Replace word with replacement in text"""
        return text.replace(word, replacement)

    def replace_regex(text: str, pattern: str, replacement: str) -> str:
        """Replace using regex pattern"""
        return re.sub(pattern, replacement, text)

    def split(text: str, delimiter: str = " ") -> List[str]:
        """Split text into list by delimiter"""
        return text.split(delimiter)

def create_pattern(*parts: str) -> str:
    """Combine pattern parts into single regex"""
    return ''.join(parts)

def escape_pattern(text: str) -> str:
    """Escape special regex characters in text"""
    return re.escape(text)

def join(items: List[str], delimiter: str = "") -> str:
    """Join list of strings with delimiter"""
    return delimiter.join(items)

def trim(text: str) -> str:
    """Remove whitespace from start and end"""
    return text.strip()

def contains(text: str, substring: str) -> bool:
    """Check if text contains substring"""
    return substring in text

def starts_with(text: str, prefix: str) -> bool:
    """Check if text starts with prefix"""
    return text.startswith(prefix)

def ends_with(text: str, suffix: str) -> bool:
    """Check if text ends with suffix"""
    return text.endswith(suffix)

def to_upper(text: str) -> str:
    """Convert text to uppercase"""
    return text.upper()

def to_lower(text: str) -> str:
    """Convert text to lowercase"""
    return text.lower()

def capitalize(text: str) -> str:
    """Capitalize first letter"""
    return text.capitalize()

def reverse(text: str) -> str:
    """Reverse string"""
    return text[::-1]

def count_words(text: str) -> int:
    """Count words in text"""
    return len(text.split())

def find_all(text: str, substring: str) -> List[int]:
    """Find all occurrences of substring"""
    return [m.start() for m in re.finditer(re.escape(substring), text)]

def extract_numbers(text: str) -> List[str]:
    """Extract all numbers from text"""
    return re.findall(r'\d+', text)

def extract_emails(text: str) -> List[str]:
    """Extract email addresses from text"""
    return re.findall(r'[\w\.-]+@[\w\.-]+\.\w+', text)

def extract_urls(text: str) -> List[str]:
    """Extract URLs from text"""
    return re.findall(r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+', text)

def is_palindrome(text: str) -> bool:
    """Check if text is palindrome"""
    text = ''.join(c.lower() for c in text if c.isalnum())
    return text == text[::-1]

def levenshtein_distance(s1: str, s2: str) -> int:
    """Calculate Levenshtein distance between strings"""
    if len(s1) < len(s2):
        return levenshtein_distance(s2, s1)
    if len(s2) == 0:
        return len(s1)
    previous_row = range(len(s2) + 1)
    for i, c1 in enumerate(s1):
        current_row = [i + 1]
        for j, c2 in enumerate(s2):
            insertions = previous_row[j + 1] + 1
            deletions = current_row[j] + 1
            substitutions = previous_row[j] + (c1 != c2)
            current_row.append(min(insertions, deletions, substitutions))
        previous_row = current_row
    return previous_row[-1]

def format_template(template: str, **kwargs) -> str:
    """Format string template with named arguments"""
    return template.format(**kwargs)

def truncate(text: str, length: int, suffix: str = "...") -> str:
    """Truncate text to length with suffix"""
    if len(text) <= length:
        return text
    return text[:length - len(suffix)] + suffix

def wrap(text: str, width: int) -> List[str]:
    """Wrap text to specified width"""
    return [text[i:i+width] for i in range(0, len(text), width)]

def remove_punctuation(text: str) -> str:
    """Remove all punctuation from text"""
    return re.sub(r'[^\w\s]', '', text)

def slugify(text: str) -> str:
    """Convert text to URL-friendly slug"""
    text = text.lower()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[-\s]+', '-', text)
    return text.strip('-')

def is_anagram(text1: str, text2: str) -> bool:
    """Check if strings are anagrams"""
    return sorted(text1.lower()) == sorted(text2.lower())

def count_chars(text: str) -> Dict[str, int]:
    """Count occurrences of each character"""
    return {char: text.count(char) for char in set(text)}



