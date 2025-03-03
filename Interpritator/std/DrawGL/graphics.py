import pyglet
from pyglet import gl
from .shaders import Shaders
from .animation import Animation

class ShapeGroup:
    def __init__(self, batch):
        self.shapes = []
        self.batch = batch
        self.x = 0
        self.y = 0
        self.rotation = 0
        self.scale = 1.0
        
    def add(self, *shapes):
        self.shapes.extend(shapes)
        # Пересчитываем центр группы
        points = []
        for shape in shapes:
            points.append((shape.x, shape.y))
        self.x = sum(x for x,y in points) / len(points)
        self.y = sum(y for x,y in points) / len(points)
        
    def move_to(self, x, y):
        dx = x - self.x
        dy = y - self.y
        for shape in self.shapes:
            shape.move_to(shape.x + dx, shape.y + dy)
        self.x = x
        self.y = y
        
    def rotate(self, angle):
        self.rotation = angle
        for shape in self.shapes:
            shape.rotate(angle)
            
    def scale_to(self, scale):
        self.scale = scale
        for shape in self.shapes:
            shape.scale_to(scale)

class PolygonShape:
    def __init__(self, points, color, batch):
        self.original_points = points
        self.color = color
        self.batch = batch
        self.x = sum(x for x,y in points) / len(points)
        self.y = sum(y for x,y in points) / len(points)
        self.rotation = 0
        self.scale = 1.0
        self.lines = []
        self._update_lines()
        
    def _update_lines(self):
        # Удаляем старые линии
        for line in self.lines:
            line.delete()
        self.lines.clear()
        
        # Находим центр фигуры
        center_x = sum(x for x,y in self.original_points) / len(self.original_points)
        center_y = sum(y for x,y in self.original_points) / len(self.original_points)
        
        transformed_points = []
        import math
        
        for px, py in self.original_points:
            # Смещение относительно центра фигуры
            dx = px - center_x
            dy = py - center_y
            
            # Масштабирование относительно центра
            dx *= self.scale
            dy *= self.scale
            
            # Вращение вокруг центра фигуры
            rad = math.radians(self.rotation)
            new_x = dx * math.cos(rad) - dy * math.sin(rad)
            new_y = dx * math.sin(rad) + dy * math.cos(rad)
            
            # Возвращаем в абсолютные координаты и учитываем текущую позицию
            transformed_points.append((
                new_x + center_x + (self.x - center_x),
                new_y + center_y + (self.y - center_y)
            ))
        
        # Создаем новые линии
        for i in range(len(transformed_points)):
            x1, y1 = transformed_points[i]
            x2, y2 = transformed_points[(i + 1) % len(transformed_points)]
            line = pyglet.shapes.Line(x1, y1, x2, y2, color=self.color, batch=self.batch)
            self.lines.append(line)

    
    def move_to(self, x, y):
        self.x = x
        self.y = y
        self._update_lines()
        
    def rotate(self, angle):
        self.rotation = angle
        self._update_lines()
        
    def scale_to(self, scale):
        self.scale = scale
        self._update_lines()

class Graphics:
    def __init__(self, window):
        self.window = window
        self.batch = pyglet.graphics.Batch()
        self.objects = []
        self.animations = []
        
        # Включаем все нужные OpenGL фичи
        gl.glEnable(gl.GL_BLEND)
        gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA)

        # Матрица трансформации как список списков
        self.transform_matrix = [
            [1.0, 0.0, 0.0],
            [0.0, 1.0, 0.0],
            [0.0, 0.0, 1.0]
        ]
        self.matrix_stack = []

        @window.event
        def on_draw():
            window.clear()
            self.batch.draw()
            
        def update(dt):
            for anim in self.animations:
                anim.update(dt)
                
        pyglet.clock.schedule_interval(update, 1/60.0)

    def animate(self, object):
        animation = Animation(object)
        self.animations.append(animation)
        return animation

    def circle(self, x, y, radius, color):
        shape = pyglet.shapes.Circle(x, y, radius, color=color, batch=self.batch)
        self.objects.append(shape)
        return shape
        
    def rectangle(self, x, y, width, height, color):
        shape = pyglet.shapes.Rectangle(x, y, width, height, color=color, batch=self.batch)
        self.objects.append(shape)
        return shape
        
    def text(self, text, x, y, size=32, color=(255,255,255)):
        label = pyglet.text.Label(text, x=x, y=y, font_size=size, color=color, batch=self.batch)
        self.objects.append(label)
        return label

    def line(self, x1, y1, x2, y2, width=1, color=(255,255,255)):
        shape = pyglet.shapes.Line(x1, y1, x2, y2, width=width, color=color, batch=self.batch)
        self.objects.append(shape)
        return shape

    def triangle(self, x1, y1, x2, y2, x3, y3, color=(255,255,255)):
        shape = pyglet.shapes.Triangle(x1, y1, x2, y2, x3, y3, color=color, batch=self.batch)
        self.objects.append(shape)
        return shape

    def polygon(self, points, color=(255,255,255)):
        shape = PolygonShape(points, color, self.batch)
        self.objects.append(shape)
        return shape

    def ellipse(self, x, y, width, height, color=(255,255,255)):
        shape = pyglet.shapes.Ellipse(x, y, width/2, height/2, color=color, batch=self.batch)
        self.objects.append(shape)
        return shape
        
    def push_matrix(self):
        # Копируем текущую матрицу в стек
        self.matrix_stack.append([row[:] for row in self.transform_matrix])

    def pop_matrix(self):
        if self.matrix_stack:
            self.transform_matrix = self.matrix_stack.pop()

    def rotate(self, angle):
        import math
        c = math.cos(math.radians(angle))
        s = math.sin(math.radians(angle))
        
        rotation = [
            [c, -s, 0],
            [s, c, 0],
            [0, 0, 1]
        ]
        self.transform_matrix = self._multiply_matrices(self.transform_matrix, rotation)

    def scale(self, x, y):
        scale_matrix = [
            [x, 0, 0],
            [0, y, 0],
            [0, 0, 1]
        ]
        self.transform_matrix = self._multiply_matrices(self.transform_matrix, scale_matrix)

    def translate(self, x, y):
        translation = [
            [1, 0, x],
            [0, 1, y],
            [0, 0, 1]
        ]
        self.transform_matrix = self._multiply_matrices(self.transform_matrix, translation)

    def _multiply_matrices(self, a, b):
        result = [[0 for _ in range(3)] for _ in range(3)]
        for i in range(3):
            for j in range(3):
                for k in range(3):
                    result[i][j] += a[i][k] * b[k][j]
        return result

    def group(self):
        group = ShapeGroup(self.batch)
        self.objects.append(group)
        return group

    def draw(self):
        self.batch.draw()
