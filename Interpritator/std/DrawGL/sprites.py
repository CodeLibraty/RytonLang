import pyglet

class Sprites:
    def __init__(self, batch=pyglet.graphics.Batch()):
        self.batch = batch
        self.sprites = {}
        
    def load_image(self, path):
        image = pyglet.image.load(path)
        return image
        
    def sprite(self, image, x, y, scale=1.0, rotation=0):
        sprite = pyglet.sprite.Sprite(
            image, x=x, y=y, batch=self.batch
        )
        sprite.scale = scale
        sprite.rotation = rotation
        return sprite
        
    def sprite_sheet(self, image, frame_width, frame_height):
        image_grid = pyglet.image.ImageGrid(
            image, 
            image.height // frame_height,
            image.width // frame_width
        )
        return image_grid
        
    def animated_sprite(self, frames, x, y, fps=30):
        animation = pyglet.image.Animation.from_image_sequence(
            frames, 1.0/fps, loop=True
        )
        sprite = pyglet.sprite.Sprite(
            animation, x=x, y=y, batch=self.batch
        )
        return sprite
