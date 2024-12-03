from core import PixelGameEngine, PixelScene, PixelSprite
from dialog import DialogSystem
import arcade

class MyGame(PixelScene):
    def __init__(self):
        super().__init__()

        # Создаем главного персонажа
        self.player = PixelSprite("player.png", scale=0.2)
        self.bg = PixelSprite("bg.jpg", scale=0.5)
        self.player.center_x = 400
        self.player.center_y = 300
        self.bg.center_x = 400
        self.bg.center_y = 300
        self.add_sprite(self.bg)
        self.add_sprite(self.player)

        # Создаем систему диалогов
        self.dialog_system = DialogSystem()

    def on_key_press(self, key, modifiers):
        if key == arcade.key.LEFT:
            self.player.move(-30, 0)
        elif key == arcade.key.RIGHT:
            self.player.move(30, 0)
        elif key == arcade.key.UP:
            self.player.move(0, 30)
        elif key == arcade.key.DOWN:
            self.player.move(0, -30)

        # Пример вызова диалога
        if key == arcade.key.SPACE:
            self.dialog_system.show_dialog("Привет, это моя первая игра!")
            self.dialog_system.update_dialog(10)

    def on_update(self, delta_time):
        self.dialog_system.update_dialog(delta_time)

    def on_draw(self):
        super().on_draw()
        # Рисуем диалог
        self.dialog_system.draw_dialog(50, 50)

def main():
    game_engine = PixelGameEngine()
    game_engine.create_window()

    game_scene = MyGame()
    game_engine.set_scene(game_scene)
    game_engine.run()

if __name__ == "__main__":
    main()