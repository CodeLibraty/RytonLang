from kivy.graphics import Color, Rectangle, Line, Ellipse
from kivy.animation import Animation

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
            Color(*glow_color)
            self.glow = Ellipse(pos=(widget.x - glow_size, widget.y - glow_size),
                                size=(widget.width + glow_size * 2, widget.height + glow_size * 2))
        widget.bind(pos=self.update_glow, size=self.update_glow)

    def update_glow(self, instance, value):
        self.glow.pos = (instance.x - 5, instance.y - 5)
        self.glow.size = (instance.width + 10, instance.height + 10)

    def add_fade_animation(self, widget, duration=1):
        anim = Animation(opacity=0, duration=duration) + Animation(opacity=1, duration=duration)
        anim.repeat = True
        anim.start(widget)

    def add_move_animation(self, widget, pos, duration=1):
        Animation(pos=pos, duration=duration).start(widget)

def init(ruvix_instance):
    return RuVixEffects(ruvix_instance)
