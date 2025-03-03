from std.DrawGL import Colors

class ShapeRenderer:
    def __init__(self, shape_type, color=Colors.WHITE, size=50):
        self.game_object = None
        self.shape_type = shape_type
        self.color = color
        self.size = size
        self.shape = None
        
    def start(self):
        graphics = self.game_object.scene.graphics
        if self.shape_type == "circle":
            self.shape = graphics.circle(self.game_object.x, self.game_object.y, self.size, self.color)
        elif self.shape_type == "rectangle":
            self.shape = graphics.rectangle(self.game_object.x, self.game_object.y, self.size, self.size, self.color)
        elif self.shape_type == "triangle":
            # Вершины треугольника
            x1 = self.game_object.x
            y1 = self.game_object.y + self.size
            x2 = self.game_object.x - self.size/2
            y2 = self.game_object.y - self.size/2
            x3 = self.game_object.x + self.size/2
            y3 = self.game_object.y - self.size/2
            
            self.shape = graphics.triangle(x1, y1, x2, y2, x3, y3, self.color)

    def update(self, dt):
        # Обновляем позицию фигуры
        self.shape.x = self.game_object.x
        self.shape.y = self.game_object.y

