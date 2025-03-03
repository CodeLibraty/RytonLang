from .sprite_render import SpriteRenderer
import pyglet

class Animator:
    image_cache = {}
    def __init__(self):
        self.animations = {}
        self.current_animation = None
        self.frame_time = 0
        self.current_frame = 0
        self.game_object = None

    def start(self):
        # Initialize animator when component starts
        self.sprite_renderer = self.game_object.get_component(SpriteRenderer)
    
    def add_animation(self, name, frames, fps=12):
        images = []
        for frame in frames:
            # Используем кэш если изображение уже загружено
            if frame in self.image_cache:
                img = self.image_cache[frame]
            else:
                img = pyglet.image.load(frame)
                img.anchor_x = img.width // 2
                img.anchor_y = img.height // 2
                self.image_cache[frame] = img
            images.append(img)
            
        self.animations[name] = {
            'frames': images,
            'duration': 1.0 / fps
        }

    def play(self, name, loop=True):
        if name in self.animations:
            self.current_animation = name
            self.current_frame = 0
            self.frame_time = 0
            
    def update(self, dt):
        if not self.current_animation:
            return
            
        anim = self.animations[self.current_animation]
        self.frame_time += dt
        
        if self.frame_time >= anim['duration']:
            self.frame_time = 0
            self.current_frame += 1
            if self.current_frame >= len(anim['frames']):
                self.current_frame = 0
                
            sprite_renderer = self.game_object.get_component(SpriteRenderer)
            if sprite_renderer and sprite_renderer.sprite_obj:
                sprite_renderer.sprite_obj.image = anim['frames'][self.current_frame]
