import pyglet

class Text:
    def __init__(self, batch):
        self.batch = batch
        
    def label(self, text: str, x: int, y: int, size: int = 12, color=(255,255,255)):
        return pyglet.text.Label(
            text,
            font_size=size,
            x=x, y=y,
            color=color,
            batch=self.batch
        )
        
    def multiline(self, text: str, x: int, y: int, width: int, size: int = 12, color=(255,255,255)):
        return pyglet.text.Label(
            text,
            font_size=size,
            x=x, y=y,
            width=width,
            multiline=True,
            color=color, 
            batch=self.batch
        )
