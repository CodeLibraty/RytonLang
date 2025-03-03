from .physic import Physics
from .render import ShapeRenderer


class GameObject:
    def __init__(self, x=0, y=0):
        self.x = float(x)
        self.y = float(y)
        self.components = []
        self.scene = None
        
    def add_component(self, component):
        component.game_object = self
        self.components.append(component)
        if isinstance(component, Physics):
            self.physics = component
        elif isinstance(component, ShapeRenderer):
            self.renderer = component
        component.start()
        return component

    def get_component(self, component_type):
        for component in self.components:
            if isinstance(component, component_type):
                return component
        return None

    def update(self, dt):
        # Обновляем все компоненты
        for component in self.components:
            component.update(dt)
            # После обновления физики применяем новые координаты
            if hasattr(component, 'velocity'):
                self.x += component.velocity[0] * dt
                self.y += component.velocity[1] * dt