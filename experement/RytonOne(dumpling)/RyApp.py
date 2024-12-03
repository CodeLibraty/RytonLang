from kivy.app import App
from kivy.uix.widget import Widget
from kivy.clock import Clock
from kivy.core.window import Window
from kivy.graphics import Rectangle, Color, Ellipse
from kivy.core.image import Image as CoreImage
from kivy.core.audio import SoundLoader
from kivy.storage.jsonstore import JsonStore
import random
import math

# Кэширование
texture_cache = {}
sound_cache = {}
font_cache = {}

def load_texture(image_path):
    if image_path not in texture_cache:
        texture_cache[image_path] = CoreImage(image_path).texture
    return texture_cache[image_path]

def load_sound(sound_path):
    if sound_path not in sound_cache:
        sound_cache[sound_path] = SoundLoader.load(sound_path)
    return sound_cache[sound_path]

# Глобальные переменные
game_objects = []
pressed_keys = set()
touch_positions = {}
particle_systems = []
current_scene = None
camera_x, camera_y = 0, 0

# Функции для работы с игровыми объектами
def create_game_object(x, y, width, height, color=(1, 0, 0), image_path=None):
    game_object = {
        'x': x, 'y': y,
        'width': width, 'height': height,
        'color': color,
        'velocity_x': 0, 'velocity_y': 0,
        'image': load_texture(image_path) if image_path else None,
        'update': lambda dt: None,
        'on_collision': lambda other: None
    }
    game_objects.append(game_object)
    return game_object

def remove_game_object(game_object):
    if game_object in game_objects:
        game_objects.remove(game_object)

# Функции для работы с частицами
def create_particle_system(x, y, particle_count, particle_lifetime, particle_speed, color):
    particle_system = {
        'x': x, 'y': y,
        'particles': [{'x': x, 'y': y, 'lifetime': particle_lifetime, 'velocity_x': random.uniform(-1, 1) * particle_speed, 'velocity_y': random.uniform(-1, 1) * particle_speed} for _ in range(particle_count)],
        'color': color
    }
    particle_systems.append(particle_system)
    return particle_system

def update_particle_systems(dt):
    for system in particle_systems:
        for particle in system['particles']:
            particle['x'] += particle['velocity_x'] * dt
            particle['y'] += particle['velocity_y'] * dt
            particle['lifetime'] -= dt
        system['particles'] = [p for p in system['particles'] if p['lifetime'] > 0]
    particle_systems[:] = [s for s in particle_systems if s['particles']]

# Функции для работы с физикой
def apply_gravity(game_object, gravity=9.8):
    game_object['velocity_y'] -= gravity

def check_collisions():
    for i, obj1 in enumerate(game_objects):
        for obj2 in game_objects[i+1:]:
            if (obj1['x'] < obj2['x'] + obj2['width'] and
                obj1['x'] + obj1['width'] > obj2['x'] and
                obj1['y'] < obj2['y'] + obj2['height'] and
                obj1['y'] + obj1['height'] > obj2['y']):
                obj1['on_collision'](obj2)
                obj2['on_collision'](obj1)

# Функции для работы с вводом
def on_key_down(keyboard, keycode, text, modifiers):
    pressed_keys.add(keycode[1])

def on_key_up(keyboard, keycode):
    pressed_keys.discard(keycode[1])

def on_touch_down(touch):
    touch_positions[touch.id] = (touch.x, touch.y)

def on_touch_up(touch):
    if touch.id in touch_positions:
        del touch_positions[touch.id]

# Функции для работы со сценами
def set_scene(scene_function):
    global current_scene, game_objects, particle_systems
    game_objects = []
    particle_systems = []
    current_scene = scene_function
    current_scene()

# Функции для работы с камерой
def move_camera(dx, dy):
    global camera_x, camera_y
    camera_x += dx
    camera_y += dy

# Функции для сохранения и загрузки игры
game_state = JsonStore('game_state.json')

def save_game():
    game_state.put('player', x=player['x'], y=player['y'])

def load_game():
    if game_state.exists('player'):
        player_data = game_state.get('player')
        player['x'] = player_data['x']
        player['y'] = player_data['y']

# Основной игровой цикл
def update(dt):
    if current_scene:
        for game_object in game_objects:
            game_object['update'](dt)
            game_object['x'] += game_object['velocity_x'] * dt
            game_object['y'] += game_object['velocity_y'] * dt
        check_collisions()
        update_particle_systems(dt)

# Отрисовка
def draw(canvas):
    canvas.clear()
    for game_object in game_objects:
        with canvas:
            if game_object['image']:
                Rectangle(texture=game_object['image'], pos=(game_object['x'] - camera_x, game_object['y'] - camera_y), size=(game_object['width'], game_object['height']))
            else:
                Color(*game_object['color'])
                Rectangle(pos=(game_object['x'] - camera_x, game_object['y'] - camera_y), size=(game_object['width'], game_object['height']))
    
    for system in particle_systems:
        with canvas:
            Color(*system['color'])
            for particle in system['particles']:
                Ellipse(pos=(particle['x'] - camera_x, particle['y'] - camera_y), size=(5, 5))

# Пример использования
def example_scene():
    global player
    player = create_game_object(100, 100, 50, 50, color=(0, 1, 0), image_path='player.png')
    
    def player_update(dt):
        if 'left' in pressed_keys:
            player['x'] -= 200 * dt
        if 'right' in pressed_keys:
            player['x'] += 200 * dt
        if 'up' in pressed_keys:
            player['y'] += 200 * dt
        if 'down' in pressed_keys:
            player['y'] -= 200 * dt
        
        if touch_positions:
            touch = list(touch_positions.values())[0]
            dx = touch[0] - player['x']
            dy = touch[1] - player['y']
            length = math.sqrt(dx**2 + dy**2)
            if length > 0:
                player['x'] += (dx / length) * 200 * dt
                player['y'] += (dy / length) * 200 * dt
    
    player['update'] = player_update
    
    create_particle_system(300, 300, 100, 2, 50, (1, 1, 0))

# Настройка Kivy приложения
class GameApp(App):
    def build(self):
        game_widget = Widget()
        Window.bind(on_key_down=on_key_down)
        Window.bind(on_key_up=on_key_up)
        game_widget.bind(on_touch_down=on_touch_down)
        game_widget.bind(on_touch_up=on_touch_up)
        
        Clock.schedule_interval(update, 1.0 / 60.0)
        Clock.schedule_interval(lambda dt: game_widget.canvas.clear(), 1.0 / 60.0)
        Clock.schedule_interval(lambda dt: draw(game_widget.canvas), 1.0 / 60.0)
        
        set_scene(example_scene)
        
        return game_widget

if __name__ == '__main__':
    GameApp().run()
