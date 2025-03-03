import pymunk

class PhysicsProperties:
    def __init__(self):
        self.mass = 0
        self.gravity_scale = 0
        self.gravity_direction = (0, -1)
        self.gravity_strength = 0  # Increased for more visible effect
        self.air_density = 0.0   # Reduced for less resistance
        self.drag_coefficient = 0   # Reduced for faster movement
        self.min_velocity = 0
        self.terminal_velocity = 0

class Collider:
    def __init__(self, collider_type="box", size=(50,50)):
        self.type = collider_type
        self.size = size
        self.offset = (0, 0)
        self.is_trigger = False
        self.layer = 0
        
    def get_bounds(self, position):
        x, y = position
        if self.shape_type == "box":
            w, h = self.size
            return (x-w/2, y-h/2, x+w/2, y+h/2)
        elif self.shape_type == "circle":
            radius = self.size[0]
            return (x-radius, y-radius, x+radius, y+radius)

class Physics:
    def __init__(self):
        self.game_object = None
        self.velocity = [0, 0]
        self.acceleration = [0, 0]
        self.forces = []
        self.properties = PhysicsProperties()
        self.collider = None
        self.properties = PhysicsProperties()
        self.body = None
        self.shape = None
        

    def set_collider(self, collider):
        self.collider = collider
        
    def add_force(self, force, duration=-1):
        self.forces.append({"vector": force, "duration": duration})
        
    def set_gravity_direction(self, angle):
        import math
        rad = math.radians(angle)
        self.properties.gravity_direction = (math.sin(rad), math.cos(rad))

    def check_bounds_intersection(self, bounds1, bounds2):
        return not (bounds1[2] < bounds2[0] or
                   bounds1[0] > bounds2[2] or
                   bounds1[3] < bounds2[1] or
                   bounds1[1] > bounds2[3])
                   
    def handle_collision(self, other):
        # Простой отскок
        self.velocity[0] *= -self.properties.elasticity
        self.velocity[1] *= -self.properties.elasticity

    def start(self):
        self.body = pymunk.Body(1.0, 100.0)
        self.body.position = (self.game_object.x, self.game_object.y)
        
        if self.collider:
            if self.collider.type == "circle":
                self.shape = pymunk.Circle(self.body, self.collider.size[0])
            elif self.collider.type == "box":
                self.shape = pymunk.Poly.create_box(self.body, self.collider.size)
                
            # Важные параметры для коллизий
            self.shape.collision_type = 1
            self.shape.friction = 0.7
            self.shape.elasticity = 0.5
            
            # Добавляем обработчик коллизий
            handler = self.game_object.scene.space.add_collision_handler(1, 1)
            handler.separate = self.on_separate
            
            self.game_object.scene.space.add(self.body, self.shape)

    def on_separate(self, arbiter, space, data):
        # Отталкиваем объекты при столкновении
        for shape in arbiter.shapes:
            body = shape.body
            body.position += arbiter.normal * arbiter.penetration
        return True

    def check_collision(self, x, y, other):
        # AABB коллизия
        my_left = x - self.collider.size[0]/2
        my_right = x + self.collider.size[0]/2
        my_top = y + self.collider.size[1]/2
        my_bottom = y - self.collider.size[1]/2
        
        other_left = other.x - other.physics.collider.size[0]/2
        other_right = other.x + other.physics.collider.size[0]/2
        other_top = other.y + other.physics.collider.size[1]/2
        other_bottom = other.y - other.physics.collider.size[1]/2
        
        return (my_right > other_left and
                my_left < other_right and
                my_top > other_bottom and
                my_bottom < other_top)
                
    def update(self, dt):
        if not self.collider:
            return
            
        # Сохраняем старую позицию
        old_x = self.game_object.x
        old_y = self.game_object.y
        
        # Пробуем новую позицию
        new_x = old_x + self.velocity[0] * dt
        new_y = old_y + self.velocity[1] * dt
        
        # Проверяем коллизии
        for obj in self.game_object.scene.objects:
            if obj == self.game_object or not hasattr(obj, 'physics') or not obj.physics.collider:
                continue
                
            if self.check_collision(new_x, new_y, obj):
                # При коллизии остаемся на старом месте
                return
                
        # Если коллизий нет - двигаемся
        self.game_object.x = new_x
        self.game_object.y = new_y

    def get_bounds(self):
        x, y = self.game_object.x, self.game_object.y
        if self.collider.type == "circle":
            r = self.collider.size[0]
            return [x - r, y - r, x + r, y + r]
        else:
            w, h = self.collider.size
            return [x - w/2, y - h/2, x + w/2, y + h/2]

    def intersects(self, other):
        if self.collider.type == "circle" and other.physics.collider.type == "circle":
            # Круг-круг коллизия
            dx = self.game_object.x - other.x
            dy = self.game_object.y - other.y
            r1 = self.collider.size[0]
            r2 = other.physics.collider.size[0]
            return (dx * dx + dy * dy) <= (r1 + r2) * (r1 + r2)
        else:
            # AABB коллизия для остальных случаев
            a = self.get_bounds()
            b = other.physics.get_bounds()
            return not (a[2] < b[0] or a[0] > b[2] or a[3] < b[1] or a[1] > b[3])

    def try_move(self, dx, dy):
        old_x = self.game_object.x
        old_y = self.game_object.y
        
        self.game_object.x += dx
        self.game_object.y += dy
        
        for obj in self.game_object.scene.objects:
            if obj != self.game_object and hasattr(obj, 'physics') and obj.physics.collider:
                if self.intersects(obj):
                    self.game_object.x = old_x
                    self.game_object.y = old_y
                    return False
        return True