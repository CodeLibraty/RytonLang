from pyglet.window import key
import pymunk

class InputHandler:
    def __init__(self, speed=300, dt=1/60):
        self.game_object = None
        self.keys = key.KeyStateHandler()
        self.speed = speed * dt
        self.damping = 0.9
        
    def start(self):
        self.game_object.scene.window.pyglet_window.push_handlers(self.keys)
        # Set body properties for better control
        self.game_object.physics.body.moment = 1
        self.game_object.physics.body.damping = self.damping
            
    def update(self, dt):
        self.dt = dt
        if self.keys[key.LEFT] or self.keys[key.A]:
            self.game_object.physics.try_move(-self.speed, 0)
        if self.keys[key.RIGHT] or self.keys[key.D]:
            self.game_object.physics.try_move(self.speed, 0)
        if self.keys[key.UP] or self.keys[key.W]:
            self.game_object.physics.try_move(0, self.speed)
        if self.keys[key.DOWN] or self.keys[key.S]:
            self.game_object.physics.try_move(0, -self.speed)