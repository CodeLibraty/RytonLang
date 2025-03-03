from .sprite_render import SpriteRenderer
import pymunk

class Scene:
    def __init__(self, window):
        self.window = window 
        self.objects = []
        self.space = pymunk.Space()
        self.space.gravity = (0.0, -900.0)
        self.graphics = None
        
    def add(self, game_object):
        game_object.scene = self
        self.objects.append(game_object)
        return game_object

    def draw(self):
        for obj in self.objects:
            sprite_renderer = obj.get_component(SpriteRenderer)
            if sprite_renderer:
                sprite_renderer.draw()

    def get_component(self, component_type):
        for obj in self.objects:
            component = obj.get_component(component_type)
            if component:
                return component
        return None

    def update(self, dt):
        self.space.step(dt)
        for obj in self.objects:
            obj.update(dt)
