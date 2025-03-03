import random
import pyglet
from pyglet import shapes

class Particle:
    def __init__(self, x, y, color, lifetime=1.0):
        self.x = x
        self.y = y
        self.velocity_x = random.uniform(-100, 100)
        self.velocity_y = random.uniform(-100, 100)
        self.color = color
        self.lifetime = lifetime
        self.age = 0
        self.size = random.uniform(2, 8)
        self.shape = None

class ParticleSystem:
    def __init__(self, max_particles=100):
        self.particles = []
        self.max_particles = max_particles
        self.emit_rate = 10
        self.time_since_emit = 0
        
    def start(self):
        self.batch = self.game_object.scene.window.graphics.batch
        
    def emit(self, count=1):
        for _ in range(count):
            if len(self.particles) >= self.max_particles:
                return
                
            particle = Particle(
                self.game_object.x,
                self.game_object.y,
                (255, 255, 255)
            )
            particle.shape = shapes.Circle(
                particle.x, particle.y,
                particle.size,
                color=particle.color,
                batch=self.batch
            )
            self.particles.append(particle)
            
    def update(self, dt):
        # Создаем новые частицы
        self.time_since_emit += dt
        if self.time_since_emit >= 1.0 / self.emit_rate:
            self.emit()
            self.time_since_emit = 0
            
        # Обновляем существующие частицы
        for particle in self.particles[:]:
            particle.age += dt
            if particle.age >= particle.lifetime:
                particle.shape.delete()
                self.particles.remove(particle)
                continue
                
            particle.x += particle.velocity_x * dt
            particle.y += particle.velocity_y * dt
            
            # Затухание
            alpha = 255 * (1 - particle.age / particle.lifetime)
            particle.shape.opacity = int(alpha)
            
            particle.shape.x = particle.x
            particle.shape.y = particle.y
