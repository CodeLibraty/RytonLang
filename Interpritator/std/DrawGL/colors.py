class Colors:
    # Базовые цвета
    WHITE = (255, 255, 255)
    GRAY = (128, 128, 128)
    BLACK = (0, 0, 0)
    RED = (255, 0, 0)
    GREEN = (0, 255, 0)
    BLUE = (0, 0, 255)
    YELLOW = (255, 255, 0)
    ORANGE = (255, 165, 0)
    PURPLE = (255, 0, 255)
    CYAN = (0, 255, 255)
    
    @staticmethod
    def rgb(r: int, g: int, b: int):
        return (r, g, b)
    
    @staticmethod 
    def rgba(r: int, g: int, b: int, a: int):
        return (r, g, b, a)
