import os
import pyglet

class ResourceManager:
    def __init__(self, base_path="assets"):
        self.base_path = os.path.abspath(base_path)
        self.textures = {}
        self.animations = {}
        self.sounds = {}
        #self.animation_parser = AnimationParser()

    def load_texture(self, name):
        if name not in self.textures:
            path = f"{self.base_path}/{name}.png"
            self.textures[name] = pyglet.image.load(path)
        return self.textures[name]
        
    def load_animation(self, name):
#        if name not in self.animations:
#            path = f"{self.base_path}/{name}.anim"
#            frames, fps = self.animation_parser.load_animation(path)
#            self.animations[name] = {
#                'frames': frames,
#                'fps': fps
#            }
#        return self.animations[name]
        pass
        
    def load_sound(self, name):
        if name not in self.sounds:
            path = f"{self.base_path}/{name}.wav"
            self.sounds[name] = pyglet.media.load(path, streaming=False)
        return self.sounds[name]

    def preload_directory(self, directory):
        for file in os.listdir(directory):
            path = os.path.join(directory, file)
            name = os.path.splitext(file)[0]
            
            if file.endswith('.png'):
                self.textures[name] = pyglet.image.load(path)
            elif file.endswith('.anim'):
                pass
#                frames, fps = self.animation_parser.load_animation(path)
#                self.animations[name] = {
#                    'frames': frames,
#                    'fps': fps
#                }
            elif file.endswith('.wav'):
                self.sounds[name] = pyglet.media.load(path, streaming=False)
