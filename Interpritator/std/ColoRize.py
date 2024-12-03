from functools import lru_cache

class TerminalColors:
    RESET = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    
    # Foreground colors
    BLACK = '\033[30m'
    RED = '\033[31m'
    GREEN = '\033[32m'
    YELLOW = '\033[33m'
    BLUE = '\033[34m'
    MAGENTA = '\033[35m'
    CYAN = '\033[36m'
    WHITE = '\033[37m'
    
    # Background colors
    BG_BLACK = '\033[40m'
    BG_RED = '\033[41m'
    BG_GREEN = '\033[42m'
    BG_YELLOW = '\033[43m'
    BG_BLUE = '\033[44m'
    BG_MAGENTA = '\033[45m'
    BG_CYAN = '\033[46m'
    BG_WHITE = '\033[47m'

def set_all(color=None, bg_color=None, bold=False, underline=False):
    result = ""
    if bold:
        result += TerminalColors.BOLD
    if underline:
        result += TerminalColors.UNDERLINE
    if color:
        result += getattr(TerminalColors, color.upper(), '')
    if bg_color:
        result += getattr(TerminalColors, f'BG_{bg_color.upper()}', '')

    print(result)

def reset_color():
    print('\033[0m')

@lru_cache(maxsize=128)
def colorize(text, color=None, bg_color=None, bold=False, underline=False):
    result = ""
    if bold:
        result += TerminalColors.BOLD
    if underline:
        result += TerminalColors.UNDERLINE
    if color:
        result += getattr(TerminalColors, color.upper(), '')
    if bg_color:
        result += getattr(TerminalColors, f'BG_{bg_color.upper()}', '')
    
    result += text + TerminalColors.RESET
    return result
