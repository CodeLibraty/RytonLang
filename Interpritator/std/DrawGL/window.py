import pyglet
from .graphics import Graphics

class Window:
    def __init__(self, width: int, height: int, title: str):
        self.window = pyglet.window.Window(width, height, title)
        self.graphics = Graphics(self.window)
        
        @self.window.event
        def on_draw():
            self.window.clear()
            self.graphics.batch.draw()
            
    def run(self):
        pyglet.app.run()
        
    # Add access to the underlying pyglet window
    @property
    def pyglet_window(self):
        return self.window
