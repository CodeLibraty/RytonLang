from pyglet import graphics

class Camera:
    def __init__(self):
        self.x = 0
        self.y = 0
        self.zoom = 1.0
        self.target = None
        self.smooth_speed = 0.1
        
    def start(self):
        self.window = self.game_object.scene.window.window
        
    def follow(self, target):
        self.target = target
        
    def world_to_screen(self, world_x, world_y):
        screen_x = world_x + self.x
        screen_y = world_y + self.y
        return screen_x, screen_y

    def update(self, dt):
        if self.target:
            # Инвертируем направление движения камеры
            target_x = -(self.target.x - self.window.width/2)
            target_y = -(self.target.y - self.window.height/2)
            
            self.x += (target_x - self.x) * self.smooth_speed
            self.y += (target_y - self.y) * self.smooth_speed
