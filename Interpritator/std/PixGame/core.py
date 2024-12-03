import arcade
import typing

class PixelGameEngine:
    def __init__(
        self, 
        width: int = 800, 
        height: int = 600, 
        title: str = "Pixel Game"
    ):
        self.width = width
        self.height = height
        self.title = title
        self.window = None
        self.current_scene = None

    def create_window(self):
        """Создание основного окна игры"""
        self.window = arcade.Window(
            self.width, 
            self.height, 
            self.title
        )

    def set_scene(self, scene):
        """Установка текущей сцены"""
        self.current_scene = scene
        self.window.show_view(scene)

    def run(self):
        """Запуск игрового цикла"""
        arcade.run()

class PixelScene(arcade.View):
    def __init__(self):
        super().__init__()
        self.sprites = arcade.SpriteList()

    def on_draw(self):
        """Отрисовка сцены"""
        arcade.start_render()
        self.sprites.draw()

    def add_sprite(self, sprite):
        """Добавление спрайта на сцену"""
        self.sprites.append(sprite)

class PixelSprite(arcade.Sprite):
    def __init__(
        self, 
        filename: str, 
        scale: float = 1.0
    ):
        super().__init__(filename, scale)

    def move(self, dx: float, dy: float):
        """Перемещение спрайта"""
        self.center_x += dx
        self.center_y += dy
