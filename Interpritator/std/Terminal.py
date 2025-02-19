from rich.progress import track, Progress
from rich.prompt import Prompt, Confirm
from rich.markdown import Markdown
from rich.console import Console
from rich.syntax import Syntax
from rich.layout import Layout
from rich.table import Table
from rich.panel import Panel
from rich.tree import Tree
from rich.live import Live

from typing import Tuple, Optional

import subprocess
import platform
import pyfiglet
import shutil
import sys
import os


class Terminal:
    def __init__(self):
        self.console = Console()
        self.emojis = {
            # Статусы и уведомления
            'success': '✅',
            'error': '❌',
            'info': 'i',
            'warning': '⚠️',
            'debug': '🔍',

            # Языки и страны
            'Russian': '🇷🇺',
            'English': '🇺🇸',
            'Chinese': '🇨🇳',
            'Japanese': '🇯🇵',
            'Korean': '🇰🇷',
            'French': '🇫🇷',
            'Spanish': '🇪🇸',
            'German': '🇩🇪',
            'Italian': '🇮🇹',
            'Portuguese': '🇧🇷',

            # Действия
            'save': '💾',
            'edit': '✏️',
            'delete': '🗑️',
            'search': '🔎',
            'settings': '⚙️',
            'reload': '🔄',
            'lock': '🔒',
            'unlock': '🔓',
            
            # Файлы и папки
            'file': '📄',
            'folder': '📁',
            'open_folder': '📂',
            'zip': '🗜️',
            
            # Разработка
            'bug': '',
            'code': '👨‍💻',
            'rocket': '🚀',
            'fire': '🔥',
            'spark': '✨',
            'hammer': '🔨',
            'computer': '💻',

            # Медиа
            'music': '🎵',
            'video': '🎥',
            'camera': '📷',
            'film': '🎬',

            # Сообщения
            'message': '💬',
            'chat': '🗨️',
            'comment': '👁️‍🗨️',
            
            # Время
            'clock': '🕐',
            'hourglass': '⌛',
            'calendar': '📅',
            'time': '🕒',
            
            # Коммуникация
            'mail': '📧',
            'bell': '🔔',
            'phone': '📱',
            
            # Другие
            'wine': '🍷',
            'star': '⭐',
            'heart': '❤️',
            'check': '✔️',
            'cross': '✖️',
            'question': '❓',
            'light': '💡'
        }

        self.symbols = {
            # Стрелки
            'arrow_right': '→',
            'arrow_left': '←',
            'arrow_up': '↑',
            'arrow_down': '↓',
            'arrow_double': '↔',
            
            # Математические
            'infinity': '∞',
            'not_equal': '≠',
            'approx': '≈',
            'plus_minus': '±',
            'multiply': '×',
            'divide': '÷',
            'sum': '∑',
            'sqrt': '√',
            
            # Логические
            'and': '∧',
            'or': '∨',
            'xor': '⊕',
            'forall': '∀',
            'exists': '∃',
            
            # Разделители
            'bullet': '•',
            'diamond': '◆',
            'square': '■',
            'circle': '●',
            'triangle': '▲',
            
            # Рамки
            'box_h': '─',
            'box_v': '│',
            'box_dr': '┌',
            'box_dl': '┐',
            'box_ur': '└',
            'box_ul': '┘',
            
            # Статусы
            'check': '✓',
            'cross': '✗',
            'star': '★',
            'note': '♪',
            'warning': '⚠',
            
            # Управление
            'enter': '⏎',
            'escape': '⎋',
            'command': '⌘',
            'option': '⌥',
            'shift': '⇧',
            'ctrl': '⌃',
            
            # Углы
            'corner_dr': '╭',
            'corner_dl': '╮',
            'corner_ur': '╰',
            'corner_ul': '╯',
            
            # Линии
            'line_h': '─',
            'line_h_bold': '━',
            'line_v': '│',
            'line_v_bold': '┃',
            
            # Т-образные
            'line_t_up': '┴',
            'line_t_down': '┬',
            'line_t_right': '├',
            'line_t_left': '┤',
            
            # Двойные линии
            'double_h': '═',
            'double_v': '║',
            'double_dr': '╔',
            'double_dl': '╗',
            'double_ur': '╚', 
            'double_ul': '╝',
            
            # Закругленные углы
            'round_dr': '╭',
            'round_dl': '╮',
            'round_ur': '╰',
            'round_ul': '╯',
            
            # Пунктир
            'dash_h': '┄',
            'dash_v': '┆',
            'dash_h_bold': '┅',
            'dash_v_bold': '┇',
            
            # Пересечения
            'cross': '┼',
            'cross_bold': '╋',
            'cross_double': '╬'
        }

    def symbol(self, name):
        """Получить специальный символ по имени"""
        return self.symbols.get(name, '')
    
    def add_symbol(self, name, symbol):
        """Добавить новый символ в словарь"""
        self.symbols[name] = symbol

    @staticmethod
    def get_size() -> Tuple[int, int]:
        """Получение размера терминала"""
        return shutil.get_terminal_size()

    @staticmethod
    def set_title(title: str) -> None:
        """Установка заголовка окна терминала"""
        if platform.system() == 'Windows':
            os.system(f'title {title}')
        else:
            sys.stdout.write(f'\x1b]2;{title}\x07')

    @staticmethod
    def move_cursor(x: int, y: int) -> None:
        """Перемещение курсора"""
        print(f'\033[{y};{x}H', end='')

    @staticmethod
    def save_cursor() -> None:
        """Сохранение позиции курсора"""
        print('\033[s', end='')

    @staticmethod
    def restore_cursor() -> None:
        """Восстановление позиции курсора"""
        print('\033[u', end='')

    @staticmethod
    def hide_cursor() -> None:
        """Скрытие курсора"""
        print('\033[?25l', end='')

    @staticmethod
    def show_cursor() -> None:
        """Показ курсора"""
        print('\033[?25h', end='')

    @staticmethod
    def box(width: int, height: int, title: Optional[str] = None) -> None:
        """Создание рамки в терминале"""
        horizontal = '─' * (width - 2)
        print(f'┌{horizontal}┐')
        
        if title:
            title = f' {title} '
            pad_left = (width - len(title)) // 2
            print(f'│{" " * pad_left}{title}{" " * (width - pad_left - len(title) - 2)}│')
            print(f'├{horizontal}┤')
            
        for _ in range(height - (3 if title else 2)):
            print(f'│{" " * (width - 2)}│')
        print(f'└{horizontal}┘')

    @staticmethod
    def set_buffer_size(columns: int, lines: int) -> None:
        """Установка размера буфера терминала"""
        if platform.system() == 'Windows':
            os.system(f'mode con: cols={columns} lines={lines}')

    @staticmethod
    def enable_alternative_buffer() -> None:
        """Включение альтернативного буфера"""
        print('\033[?1049h', end='')

    @staticmethod
    def disable_alternative_buffer() -> None:
        """Выключение альтернативного буфера"""
        print('\033[?1049l', end='')

    @staticmethod
    def set_scrolling_region(top: int, bottom: int) -> None:
        """Установка области прокрутки"""
        print(f'\033[{top};{bottom}r', end='')

    @staticmethod
    def enable_line_wrap() -> None:
        """Включение переноса строк"""
        print('\033[?7h', end='')

    @staticmethod
    def disable_line_wrap() -> None:
        """Выключение переноса строк"""
        print('\033[?7l', end='')

    @staticmethod
    def terminal_info() -> dict:
        """Получение информации о терминале"""
        return {
            'size': shutil.get_terminal_size(),
            'type': os.environ.get('TERM'),
            'encoding': sys.stdout.encoding,
            'platform': platform.system(),
            'is_interactive': sys.stdout.isatty()
        }

    def emoji(self, name):
        """Получить эмодзи по названию"""
        return self.emojis.get(name, '')
    
    def add_emoji(self, name, emoji_symbol):
        """Добавить новый эмодзи в словарь"""
        self.emojis[name] = emoji_symbol

    def paint(self, text, style=None):
        """Улучшенный print с цветами и стилями"""
        self.console.print(text, style=style)
    
    def success(self, text):
        """Быстрый вывод успешных сообщений"""
        self.paint(f"✅ {text}", style="green")
    
    def error(self, text):
        """Быстрый вывод ошибок"""
        self.paint(f"❌ {text}", style="red bold")
    
    def info(self, text):
        """Информационные сообщения"""
        self.paint(f"ℹ️ {text}", style="blue")
    
    def warning(self, text):
        """Предупреждения"""
        self.paint(f"⚠️ {text}", style="yellow")

    def table(self, headers, rows, title=None):
        """Расширенное создание таблиц"""
        table = Table(title=title, show_header=True, header_style="bold magenta")
        for header in headers:
            table.add_column(header)
        for row in rows:
            table.add_row(*row)
        self.console.print(table)
    
    def progress(self, items):
        """Упрощённый прогресс-бар"""
        return track(items, description="Processing...")
    
    def advanced_progress(self):
        """Расширенный прогресс-бар с множеством задач"""
        return Progress()
    
    def code(self, code, language="python"):
        """Подсветка синтаксиса кода"""
        syntax = Syntax(code, language, theme="monokai")
        self.console.print(syntax)
    
    def panel(self, content, title=None):
        """Создание панелей с рамкой"""
        panel = Panel(content, title=title)
        self.console.print(panel)
    
    def markdown(self, markdown_text):
        """Рендеринг Markdown"""
        md = Markdown(markdown_text)
        self.console.print(md)
    
    def tree(self, name):
        """Создание древовидной структуры"""
        return Tree(name)
    
    def input(self, prompt, password=False):
        """Улучшенный ввод с подсказкой"""
        return Prompt.ask(prompt, password=password)

    def print_ascii(self, text='text', font='standard', width=80):
        fig = pyfiglet.Figlet(font=font, width=width)
        return fig.renderText(text)

    def confirm(self, question):
        """Запрос подтверждения действия"""
        return Confirm.ask(question)
    
    def layout(self):
        """Создание разделённого экрана"""
        return Layout()
    
    def live(self):
        """Живое обновление контента"""
        return Live()
    
    def clear(self):
        """Очистка экрана"""
        self.console.clear()

    def rule(self, title=None):
        """Горизонтальная линия с заголовком"""
        self.console.rule(title)

    def status(self, text):
        """Статус выполнения с спиннером"""
        return self.console.status(text)
