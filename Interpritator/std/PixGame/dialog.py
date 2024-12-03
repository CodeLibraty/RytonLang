import arcade

class DialogSystem:
    def __init__(self, font_size: int = 24):
        self.font_size = font_size
        self.current_dialog = ""
        self.dialog_speed = 0.05
        self.current_char_index = 0

    def show_dialog(self, text: str):
        """Показ диалога с постепенным появлением текста"""
        self.current_dialog = text
        self.current_char_index = 0

    def update_dialog(self, delta_time):
        """Обновление текста диалога"""
        if self.current_char_index < len(self.current_dialog):
            self.current_char_index += 1

    def draw_dialog(self, x: int, y: int):
        """Отрисовка диалога"""
        visible_text = self.current_dialog[:self.current_char_index]
        arcade.draw_text(
            visible_text, 
            x, y, 
            arcade.color.WHITE, 
            self.font_size
        )
