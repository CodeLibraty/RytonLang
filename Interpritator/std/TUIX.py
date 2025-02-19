from typing import Any, Union, Callable
import contextlib
import builtins
import termios
import time
import tty
import sys
import os
import re

emojis = {
    # Статусы и уведомления
    'success': '✅',
    'error': '❌',       'info': 'i',
    'warning': '⚠️',     'debug': '🔍',

    # Языки и страны
    'Russian': '🇷🇺',     'English': '🇺🇸',
    'Chinese': '🇨🇳',     'Japanese': '🇯🇵',
    'Korean': '🇰🇷',      'French': '🇫🇷',
    'Spanish': '🇪🇸',     'German': '🇩🇪',
    'Italian': '🇮🇹',     'Portuguese': '🇧🇷',

    # Действия
    'save': '💾',         'edit': '✏️',
    'delete': '🗑️',       'search': '🔎',
    'settings': '⚙️',     'reload': '🔄',
    'lock': '🔒',         'unlock': '🔓',
    
    # Файлы и папки
    'file': '📄',         'folder': '📁',
    'open_folder': '📂',  'zip': '🗜️',
    
    # Разработка
    'bug': '',
    'code': '👨‍💻',        'rocket': '🚀',
    'fire': '🔥',         'spark': '✨',
    'hammer': '🔨',       'computer': '💻',

    # Медиа
    'music': '🎵',        'video': '🎥',
    'camera': '📷',       'film': '🎬',

    # Сообщения
    'message': '💬',
    'chat': '🗨️',
    'comment': '👁️‍🗨️',
    
    # Время
    'clock': '🕐',        'hourglass': '⌛',
    'calendar': '📅',      'time': '🕒',
    
    # Коммуникация
    'mail': '📧',
    'bell': '🔔',
    'phone': '📱',
    
    # Другие
    'wine': '🍷',
    'star': '⭐',          'heart': '❤️',
    'check': '✔️',         'cross': '✖️',
    'question': '❓',      'light': '💡',

    # Стрелки
    'arrow_right': '→',
    'arrow_left': '←',     'arrow_up': '↑',
    'arrow_down': '↓',     'arrow_double': '↔',
    
    # Математические
    'infinity': '∞',       'not_equal': '≠',
    'approx': '≈',         'plus_minus': '±',
    'multiply': '×',       'divide': '÷',
    'sum': '∑',            'sqrt': '√',
    
    # Логические
    'and': '∧',
    'or': '∨',             'xor': '⊕',
    'forall': '∀',         'exists': '∃',
    
    # Разделители
    'bullet': '•',
    'diamond': '◆',        'square': '■',
    'circle': '●',          'triangle': '▲',
    
    # Рамки
    'box_h': '─',          'box_v': '│',
    'box_dr': '┌',         'box_dl': '┐',
    'box_ur': '└',         'box_ul': '┘',
    
    # Статусы
    'check': '✓',
    'cross': '✗',           'star': '★',
    'note': '♪',            'warning': '⚠',
    
    # Управление
    'enter': '⏎',          'escape': '⎋',
    'command': '⌘',        'option': '⌥',
    'shift': '⇧',          'ctrl': '⌃',
    
    # Углы
    'corner_dr': '╭',      'corner_dl': '╮',
    'corner_ur': '╰',      'corner_ul': '╯',
    
    # Линии
    'line_h': '─',         'line_h_bold': '━',
    'line_v': '│',         'line_v_bold': '┃',
    
    # Т-образные
    'line_t_up': '┴',      'line_t_down': '┬',
    'line_t_right': '├',   'line_t_left': '┤',
    
    # Двойные линии
    'double_h': '═',       'double_v': '║',
    'double_dr': '╔',      'double_dl': '╗',
    'double_ur': '╚',      'double_ul': '╝',
    
    # Закругленные углы
    'round_dr': '╭',       'round_dl': '╮',
    'round_ur': '╰',       'round_ul': '╯',

    # Пунктир
    'dash_h': '┄',         'dash_v': '┆',
    'dash_h_bold':  '┅',   'dash_v_bold': '┇',
    
    # Пересечения
    'cross': '┼',
    'cross_bold': '╋',     'cross_double': '╬'
}

def confirm(message: str) -> bool:
    """Запрос подтверждения действия"""
    return builtins.input(f"{message} (y/n): ").lower().startswith('y')

def print(*args, clr=None, style=None, sep=' ', end='\n'):
    text = sep.join(str(arg) for arg in args)
        
    # Эмодзи должны обрабатываться первыми
    for emoji_name, emoji_symbol in emojis.items():
        text = text.replace(f'<{emoji_name}>', emoji_symbol)

    colors = {
        'red': '\033[31m',
        'green': '\033[32m',
        'blue': '\033[34m',
        'yellow': '\033[33m',
        'magenta': '\033[35m',
        'cyan': '\033[36m',
        'white': '\033[37m'
    }
    
    style_dict = {
        'bold': '\033[1m',
        'italic': '\033[3m',
        'underline': '\033[4m'
    }
    
    # Обработка комбинированных тегов
    combined_pattern = r'<(.*?)\|(.*?)>'
    for match in re.finditer(combined_pattern, text):
        full_tag = match.group(0)
        tag_styles = match.group(1).split('|')
        codes = []
        for tag_style in tag_styles:
            if tag_style in colors:
                codes.append(colors[tag_style])
            if tag_style in style_dict:
                codes.append(style_dict[tag_style])
        text = text.replace(full_tag, ''.join(codes))

    # Парсинг эмодзи тегов
    for name, emoji in emojis.items():
        text = text.replace(f'<{name}>', emoji)
    
    # Остальной парсинг
    for tag, code in colors.items():
        text = text.replace(f'<{tag}>', code)
        text = text.replace(f'</{tag}>', '\033[0m')
    
    for tag, code in style_dict.items():
        text = text.replace(f'<{tag}>', code)
        text = text.replace(f'</{tag}>', '\033[0m')

    if clr in colors:
        text = f"{colors[clr]}{text}\033[0m"
    
    if style in style_dict:
        text = f"{styles[style]}{text}\033[0m"

    builtins.print(text, end=end)

def paint(image_data, palette=None):
    default_palette = {
        'dark': '░',
        'medium': '▒',
        'light': '▓',
        'full': '█',
        'dot': '•',
        'star': '★',
        'square': '■',
        'circle': '●'
    }
    
    palette = palette or default_palette
    
    # Поддержка многострочных изображений
    if isinstance(image_data, str):
        lines = image_data.strip().split('\n')
    else:
        lines = image_data
        
    result = []
    for line in lines:
        # Замена символов на элементы палитры
        for char, symbol in palette.items():
            line = line.replace(char, symbol)
        result.append(line)
        
    return '\n'.join(result)

def get_char():
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        return sys.stdin.read(1)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)

def input(prompt="", clr=None, style=None, default=None, validate=None):
    # Форматируем prompt с теми же правилами что и в print
    colors = {
        'red': '\033[31m',
        'green': '\033[32m',
        'blue': '\033[34m',
        'yellow': '\033[33m',
        'magenta': '\033[35m',
        'cyan': '\033[36m',
        'white': '\033[37m'
    }
    
    style_dict = {
        'bold': '\033[1m',
        'italic': '\033[3m',
        'underline': '\033[4m'
    }

    # Обработка тегов в prompt
    combined_pattern = r'<(.*?)\|(.*?)>'
    for match in re.finditer(combined_pattern, prompt):
        full_tag = match.group(0)
        tag_styles = match.group(1).split('|')
        codes = []
        for tag_style in tag_styles:
            if tag_style in colors:
                codes.append(colors[tag_style])
            if tag_style in style_dict:
                codes.append(style_dict[tag_style])
        prompt = prompt.replace(full_tag, ''.join(codes))

    # Добавляем значение по умолчанию
    if default:
        prompt += f" ({default})"

    buffer = []
    cursor_pos = 0
    
    sys.stdout.write(prompt)
    sys.stdout.flush()
    
    def redraw():
        # Очищаем текущую строку
        sys.stdout.write('\r' + prompt)
        # Выводим весь буфер
        sys.stdout.write(''.join(buffer))
        # Возвращаем курсор на нужную позицию
        sys.stdout.write('\r' + prompt + ''.join(buffer[:cursor_pos]))
        sys.stdout.flush()
    
    while True:
        char = get_char()
        
        if char == '\x1b':
            next1, next2 = get_char(), get_char()
            if next1 == '[':
                if next2 == 'D' and cursor_pos > 0:  # Влево
                    cursor_pos -= 1
                    redraw()
                elif next2 == 'C' and cursor_pos < len(buffer):  # Вправо
                    cursor_pos += 1
                    redraw()

        elif char == '\r':
            sys.stdout.write('\n')
            break
            
        elif char == '\x7f' and cursor_pos > 0:  # Backspace
            cursor_pos -= 1
            buffer.pop(cursor_pos)
            redraw()
            
        elif char.isprintable():
            buffer.insert(cursor_pos, char)
            cursor_pos += 1
            redraw()
    
    return ''.join(buffer)

def menu(title, options, clr="white", select_clr="green", hint_clr="blue", cursor="> "):
    cursor_pos = 0
    RESET = '\033[0m'
    
    # Разделяем текст, функции и подсказки
    texts = []
    funcs = []
    hints = []
    
    for opt in options:
        if isinstance(opt, tuple):
            if len(opt) == 3:  # текст, функция, подсказка
                texts.append(opt[0])
                funcs.append(opt[1])
                hints.append(opt[2])
            else:  # текст, функция
                texts.append(opt[0])
                funcs.append(opt[1])
                hints.append("")
        else:  # просто текст
            texts.append(opt)
            funcs.append(None)
            hints.append("")
    
    def draw_menu():
        print("\033[H\033[J")  # Очистка экрана
        print(f"<{clr}|bold>{title}</{clr}|bold>\n")
        
        # Отрисовка пунктов
        for idx, text in enumerate(texts):
            if idx == cursor_pos:
                print(f"<{select_clr}|bold>{cursor} {text}</{select_clr}|bold>{RESET}")
                if hints[idx]:  # Показываем подсказку для выбранного пункта
                    print(f"  <{hint_clr}|italic>{hints[idx]}</{hint_clr}|italic>{RESET}")
            else:
                print(f"  {text}{RESET}")
    
    while True:
        draw_menu()
        char = get_char()
        
        if char == '\x1b':
            next1, next2 = get_char(), get_char()
            if next1 == '[':
                if next2 == 'A' and cursor_pos > 0:  # Вверх
                    cursor_pos -= 1
                elif next2 == 'B' and cursor_pos < len(texts) - 1:  # Вниз
                    cursor_pos += 1
                    
        elif char == '\r':  # Enter
            if funcs[cursor_pos]:
                funcs[cursor_pos]()
            return cursor_pos

class Form:
    def __init__(self, fields):
        self.fields = fields
        self.current = 0
        self.submit_button = SubmitButton("Подтвердить")
        
    def show(self):
        while True:
            print("\033[H\033[J")
            # Рисуем поля
            for i, field in enumerate(self.fields):
                if i == self.current:
                    field.draw_active()
                else:
                    field.draw()
            
            # Рисуем кнопку подтверждения
            if self.current == len(self.fields):
                self.submit_button.draw_active()
            else:
                self.submit_button.draw()
            
            char = get_char()
            if char == '\x1b':
                next1, next2 = get_char(), get_char()
                if next1 == '[':
                    if next2 == 'A': 
                        self.current = max(0, self.current - 1)
                    if next2 == 'B': 
                        self.current = min(len(self.fields), self.current + 1)
            elif char == '\r':
                if self.current == len(self.fields):
                    # Возвращаем словарь с данными
                    return {field.label: field.get_value() for field in self.fields}
                else:
                    self.fields[self.current].activate()

class SubmitButton:
    def __init__(self, label):
        self.label = label
        
    def draw_active(self):
        print(f"\n<green|bold>> [{self.label}]</green|bold>")
        
    def draw(self):
        print(f"\n  [{self.label}]")

class TextField:
    def __init__(self, label, value=""):
        self.label = label
        self.value = value
        
    def get_value(self):
        return self.value
        
    def draw_active(self):
        print(f"<cyan|bold>> {self.label}: {self.value}_</cyan|bold>")
        
    def draw(self):
        print(f"  {self.label}: {self.value}")
        
    def activate(self):
        self.value = input(f"{self.label}: ", default=self.value)

class Checkbox:
    def __init__(self, label, checked=False):
        self.label = label
        self.checked = checked
        
    def get_value(self):
        return self.checked
        
    def draw_active(self):
        mark = "✓" if self.checked else " "
        print(f"<cyan|bold>> [{mark}] {self.label}</cyan|bold>")
        
    def draw(self):
        mark = "✓" if self.checked else " "
        print(f"  [{mark}] {self.label}")
        
    def activate(self):
        self.checked = not self.checked

def pick_date():
    import calendar
    import datetime
    
    current = datetime.datetime.now()
    
    while True:
        print("\033[H\033[J")
        print(calendar.month(current.year, current.month))
        
        char = get_char()
        if char == '\x1b':
            next1, next2 = get_char(), get_char()
            if next1 == '[':
                if next2 == 'D': current = current.replace(month=max(1, current.month-1))
                if next2 == 'C': current = current.replace(month=min(12, current.month+1))
        elif char == '\r':
            return current

def choose_color():
    colors = [
        ("red", "Красный"),
        ("green", "Зеленый"),
        ("blue", "Синий"),
        ("yellow", "Желтый"),
        ("magenta", "Пурпурный"),
        ("cyan", "Голубой")
    ]
    
    current = 0
    
    while True:
        print("\033[H\033[J")
        for i, (code, name) in enumerate(colors):
            if i == current:
                print(f"<{code}|bold>> {name}</{code}|bold>")
            else:
                print(f"<{code}>  {name}</{code}>")
                
        char = get_char()
        if char == '\x1b':
            next1, next2 = get_char(), get_char()
            if next1 == '[':
                if next2 == 'A': current = max(0, current-1)
                if next2 == 'B': current = min(len(colors)-1, current+1)
        elif char == '\r':
            return colors[current][0]

def floating_list(items, title="Выберите", position="center"):
    current = 0
    visible_items = 5
    RESET = '\033[0m'
    
    def draw_list():
        print("\033[H\033[J")
        print(f"<cyan|bold>{title}</cyan|bold>{RESET}\n")
        
        start = max(0, current - visible_items//2)
        end = min(len(items), start + visible_items)
        
        for i in range(start, end):
            if i == current:
                print(f"<green|bold>> {items[i]}</green|bold>{RESET}")
            else:
                print(f"  {items[i]}")
    
    while True:
        draw_list()
        char = get_char()
        
        if char == '\x1b':
            next1, next2 = get_char(), get_char()
            if next1 == '[':
                if next2 == 'A': current = max(0, current-1)
                if next2 == 'B': current = min(len(items)-1, current+1)
        elif char == '\r':
            return items[current]

@contextlib.contextmanager 
def cursor_at(x, y):
    """Move cursor to position"""
    print(f"\033[{y};{x}H", end='')
    try:
        yield
    finally:
        print("\033[0m", end='')

def split_screen():
    """Добавляет разделитель посередине экрана"""
    width = os.get_terminal_size().columns
    height = os.get_terminal_size().lines
    
    # Вертикальная линия
    separator = emojis['line_v']
    mid = width // 2
    
    for i in range(height):
        with cursor_at(mid, i):
            print(separator)
            
    return mid

def clear_side(side='left'):
    """Очищает левую или правую часть экрана"""
    width = os.get_terminal_size().columns
    height = os.get_terminal_size().lines
    mid = width // 2
    
    clear = ' ' * (mid - 1 if side == 'left' else mid)
    for i in range(height):
        with cursor_at(0 if side == 'left' else mid + 1, i):
            print(clear)