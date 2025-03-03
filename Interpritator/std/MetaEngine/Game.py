from std.DrawGL import Window
from .scene import Scene 
import pyglet


class Game:
    def __init__(self, width, height, title):
        self.window = Window(width, height, title)
        self.graphics = self.window.graphics
        self.current_scene = Scene(self.window)  # Pass window to Scene
        self.current_scene.graphics = self.graphics
        
        def update(dt):
            # Update physics and game logic
            self.current_scene.update(dt)
            self.current_scene.draw()
            # Clear and redraw
            self.window.window.clear()  # Use underlying pyglet window
            self.graphics.draw()
            
        # Schedule updates at 60 FPS
        pyglet.clock.schedule_interval(update, 1/60.0)
            
    def run(self):
        self.window.run()