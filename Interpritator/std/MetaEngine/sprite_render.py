import pyglet
from .camera import Camera

class SpriteRenderer:
    def __init__(self, sprite_path):
        self.sprite = pyglet.image.load(sprite_path)
        self.sprite.anchor_x = self.sprite.width // 2
        self.sprite.anchor_y = self.sprite.height // 2
        self.sprite_obj = None
        
    def start(self):
        # Добавляем спрайт в основной батч для отрисовки
        self.sprite_obj = pyglet.sprite.Sprite(
            self.sprite,
            x=self.game_object.x,
            y=self.game_object.y,
            batch=self.game_object.scene.window.graphics.batch  # Важно!
        )
        
    def update(self, dt):
        if self.sprite_obj:
            camera = self.game_object.scene.get_component(Camera)
            if camera:
                screen_x, screen_y = camera.world_to_screen(self.game_object.x, self.game_object.y)
                self.sprite_obj.x = screen_x
                self.sprite_obj.y = screen_y
                self.sprite_obj.scale = camera.zoom

    def draw(self):
        if self.sprite_obj:
            self.sprite_obj.draw()
