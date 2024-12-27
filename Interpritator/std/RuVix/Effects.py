from kivy.graphics import Color, Rectangle, Line, Ellipse, Mesh
from kivy.animation import Animation
import math

class RuVixEffects:
    def __init__(self, ruvix_instance):
        self.ruvix = ruvix_instance

    def add_color_effect(self, widget, rgb):
        with widget.canvas:
            Color(*rgb)
            self.rect = Rectangle(pos=widget.pos, size=widget.size)
        widget.bind(pos=self.update_rect, size=self.update_rect)

    def update_rect(self, instance, value):
        self.rect.pos = instance.pos
        self.rect.size = instance.size

    def add_glow_effect(self, widget, glow_size=5, glow_color=(1, 1, 1, 0.5)):
        with widget.canvas.before:
            # Внешний слой свечения
            Color(glow_color[0], glow_color[1], glow_color[2], glow_color[3] * 0.3)
            self.glow_outer = Ellipse(pos=(widget.x - glow_size*1.5, widget.y - glow_size*1.5),
                                    size=(widget.width + glow_size*3, widget.height + glow_size*3))
            
            # Средний слой
            Color(glow_color[0], glow_color[1], glow_color[2], glow_color[3] * 0.5)
            self.glow_middle = Ellipse(pos=(widget.x - glow_size, widget.y - glow_size),
                                    size=(widget.width + glow_size*2, widget.height + glow_size*2))
            
            # Внутренний слой
            Color(*glow_color)
            self.glow_inner = Ellipse(pos=(widget.x - glow_size*0.5, widget.y - glow_size*0.5),
                                    size=(widget.width + glow_size, widget.height + glow_size))
                                    
        widget.bind(pos=self.update_glow, size=self.update_glow)

    def update_glow(self, instance, value):
        glow_size = 6  # базовый размер свечения
        self.glow_outer.pos = (instance.x - glow_size*1.5, instance.y - glow_size*1.5)
        self.glow_outer.size = (instance.width + glow_size*3, instance.height + glow_size*3)
        
        self.glow_middle.pos = (instance.x - glow_size, instance.y - glow_size)
        self.glow_middle.size = (instance.width + glow_size*2, instance.height + glow_size*2)
        
        self.glow_inner.pos = (instance.x - glow_size*0.5, instance.y - glow_size*0.5)
        self.glow_inner.size = (instance.width + glow_size, instance.height + glow_size)

    def add_fade_animation(self, widget, duration=1):
        anim = Animation(opacity=0, duration=duration) + Animation(opacity=1, duration=duration)
        anim.repeat = True
        anim.start(widget)

    def add_move_animation(self, widget, pos, duration=1):
        Animation(pos=pos, duration=duration).start(widget)

def init(ruvix_instance):
    return RuVixEffects(ruvix_instance)
