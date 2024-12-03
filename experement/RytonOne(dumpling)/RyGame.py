# RyGame.py

import pygame
import sys
import math
import random
import pygame.gfxdraw
import pygame.freetype
import pytmx
import pyscroll
import pymunk
import pygame_gui
import noise

class RyGame:
    def __init__(self, width, height, title="RyGame", fps=60):
        pygame.init()
        pygame.mixer.init()
        self.width = width
        self.height = height
        self.screen = pygame.display.set_mode((width, height))
        pygame.display.set_caption(title)
        self.clock = pygame.time.Clock()
        self.fps = fps
        self.sprites = []
        self.running = True
        self.font = pygame.freetype.Font(None, 36)
        self.keys = pygame.key.get_pressed()
        self.mouse_pos = (0, 0)
        self.mouse_buttons = (False, False, False)
        self.dt = 0
        self.background_color = (0, 0, 0)
        self.camera = None
        self.particle_systems = []
        self.space = pymunk.Space()
        self.space.gravity = (0, 980)
        self.ui_manager = pygame_gui.UIManager((width, height))
        self.weather_effects = []

    def run(self, update_func, draw_func):
        while self.running:
            self.dt = self.clock.tick(self.fps) / 1000.0
            self._handle_events()
            update_func()
            self._update_sprites()
            self._update_particle_systems()
            self._update_weather_effects()
            self.space.step(self.dt)
            self.screen.fill(self.background_color)
            if self.camera:
                self.camera.update()
            draw_func()
            self._draw_sprites()
            self._draw_particle_systems()
            self._draw_weather_effects()
            self.ui_manager.draw_ui(self.screen)
            pygame.display.flip()
        pygame.quit()
        sys.exit()

    def _handle_events(self):
        self.keys = pygame.key.get_pressed()
        self.mouse_pos = pygame.mouse.get_pos()
        self.mouse_buttons = pygame.mouse.get_pressed()
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
            self.ui_manager.process_events(event)

    def _update_sprites(self):
        for sprite in self.sprites:
            sprite.update()

    def _draw_sprites(self):
        for sprite in self.sprites:
            sprite.draw(self.screen)

    def _update_particle_systems(self):
        for ps in self.particle_systems:
            ps.update()

    def _draw_particle_systems(self):
        for ps in self.particle_systems:
            ps.draw(self.screen)

    def _update_weather_effects(self):
        for effect in self.weather_effects:
            effect.update()

    def _draw_weather_effects(self):
        for effect in self.weather_effects:
            effect.draw(self.screen)

    def create_sprite(self, x, y, width, height, color=(255,255,255), image=None, physics=False):
        sprite = RySprite(self, x, y, width, height, color, image, physics)
        self.sprites.append(sprite)
        return sprite

    def remove_sprite(self, sprite):
        self.sprites.remove(sprite)
        if sprite.body:
            self.space.remove(sprite.body, sprite.shape)

    def set_background(self, color):
        self.background_color = color

    def draw_text(self, text, x, y, color=(255,255,255), size=36):
        self.font.render_to(self.screen, (x, y), text, color, size=size)

    def play_sound(self, filename):
        sound = pygame.mixer.Sound(filename)
        sound.play()

    def play_music(self, filename, loops=-1):
        pygame.mixer.music.load(filename)
        pygame.mixer.music.play(loops)

    def stop_music(self):
        pygame.mixer.music.stop()

    def is_key_pressed(self, key):
        return self.keys[key]

    def is_mouse_pressed(self, button=0):
        return self.mouse_buttons[button]

    def get_mouse_pos(self):
        return self.mouse_pos

    def set_camera(self, target):
        self.camera = RyCamera(self, target)

    def load_tilemap(self, filename):
        return RyTilemap(self, filename)

    def create_particle_system(self, x, y):
        ps = RyParticleSystem(self, x, y)
        self.particle_systems.append(ps)
        return ps

    def create_ui_element(self, element_type, rect, text=""):
        if element_type == "button":
            return pygame_gui.elements.UIButton(relative_rect=rect, text=text, manager=self.ui_manager)
        elif element_type == "text_entry":
            return pygame_gui.elements.UITextEntryLine(relative_rect=rect, manager=self.ui_manager)

    def add_weather_effect(self, effect_type):
        if effect_type == "rain":
            self.weather_effects.append(RyRain(self))
        elif effect_type == "snow":
            self.weather_effects.append(RySnow(self))

    def generate_terrain(self, width, height, scale=0.1):
        return RyTerrain(self, width, height, scale)

class RySprite:
    def __init__(self, game, x, y, width, height, color=(255,255,255), image=None, physics=False):
        self.game = game
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.color = color
        self.image = None
        self.rect = pygame.Rect(x, y, width, height)
        self.velocity = [0, 0]
        self.acceleration = [0, 0]
        self.rotation = 0
        self.body = None
        self.shape = None
        
        if image:
            self.image = pygame.image.load(image).convert_alpha()
            self.image = pygame.transform.scale(self.image, (width, height))
            self.original_image = self.image.copy()

        if physics:
            self.body = pymunk.Body()
            self.body.position = x, y
            self.shape = pymunk.Poly.create_box(self.body, (width, height))
            self.game.space.add(self.body, self.shape)

    def update(self):
        if self.body:
            self.x, self.y = self.body.position
            self.rotation = -math.degrees(self.body.angle)
        else:
            self.velocity[0] += self.acceleration[0] * self.game.dt
            self.velocity[1] += self.acceleration[1] * self.game.dt
            self.x += self.velocity[0] * self.game.dt
            self.y += self.velocity[1] * self.game.dt
        self.rect.x = int(self.x)
        self.rect.y = int(self.y)

    def draw(self, screen):
        if self.image:
            rotated_image = pygame.transform.rotate(self.original_image, self.rotation)
            new_rect = rotated_image.get_rect(center=self.rect.center)
            screen.blit(rotated_image, new_rect.topleft)
        else:
            pygame.draw.rect(screen, self.color, self.rect)

    def set_position(self, x, y):
        self.x = x
        self.y = y
        if self.body:
            self.body.position = x, y
        self.rect.x = int(x)
        self.rect.y = int(y)

    def set_velocity(self, vx, vy):
        if self.body:
            self.body.velocity = vx, vy
        else:
            self.velocity = [vx, vy]

    def set_acceleration(self, ax, ay):
        self.acceleration = [ax, ay]

    def set_rotation(self, angle):
        self.rotation = angle
        if self.body:
            self.body.angle = -math.radians(angle)

    def collides_with(self, other):
        return self.rect.colliderect(other.rect)

class RyColor:
    BLACK = (0, 0, 0)
    WHITE = (255, 255, 255)
    RED = (255, 0, 0)
    GREEN = (0, 255, 0)
    BLUE = (0, 0, 255)
    YELLOW = (255, 255, 0)
    CYAN = (0, 255, 255)
    MAGENTA = (255, 0, 255)

class RyKey:
    LEFT = pygame.K_LEFT
    RIGHT = pygame.K_RIGHT
    UP = pygame.K_UP
    DOWN = pygame.K_DOWN
    SPACE = pygame.K_SPACE
    RETURN = pygame.K_RETURN
    ESCAPE = pygame.K_ESCAPE

class RyCamera:
    def __init__(self, game, target):
        self.game = game
        self.target = target
        self.offset_x = 0
        self.offset_y = 0

    def update(self):
        self.offset_x = self.game.width // 2 - self.target.rect.centerx
        self.offset_y = self.game.height // 2 - self.target.rect.centery

        for sprite in self.game.sprites:
            sprite.rect.x += self.offset_x
            sprite.rect.y += self.offset_y

class RyTilemap:
    def __init__(self, game, filename):
        self.game = game
        self.tmx_data = pytmx.load_pygame(filename)
        self.map_data = pyscroll.TiledMapData(self.tmx_data)
        self.map_layer = pyscroll.BufferedRenderer(self.map_data, (game.width, game.height))

    def draw(self, surface):
        self.map_layer.draw(surface)

    def make_map(self):
        temp_surface = pygame.Surface((self.tmx_data.width * self.tmx_data.tilewidth,
                                       self.tmx_data.height * self.tmx_data.tileheight))
        self.render(temp_surface)
        return temp_surface

    def render(self, surface):
        for layer in self.tmx_data.visible_layers:
            if isinstance(layer, pytmx.TiledTileLayer):
                for x, y, gid in layer:
                    tile = self.tmx_data.get_tile_image_by_gid(gid)
                    if tile:
                        surface.blit(tile, (x * self.tmx_data.tilewidth, y * self.tmx_data.tileheight))

class RyParticle:
    def __init__(self, x, y, color, size, lifetime):
        self.x = x
        self.y = y
        self.color = color
        self.size = size
        self.lifetime = lifetime
        self.velocity = [random.uniform(-1, 1), random.uniform(-1, 1)]

    def update(self):
        self.x += self.velocity[0]
        self.y += self.velocity[1]
        self.lifetime -= 1

    def draw(self, surface):
        pygame.gfxdraw.filled_circle(surface, int(self.x), int(self.y), self.size, self.color)

class RyParticleSystem:
    def __init__(self, game, x, y):
        self.game = game
        self.x = x
        self.y = y
        self.particles = []

    def emit(self, count, color, size, lifetime):
        for _ in range(count):
            self.particles.append(RyParticle(self.x, self.y, color, size, lifetime))

    def update(self):
        self.particles = [p for p in self.particles if p.lifetime > 0]
        for particle in self.particles:
            particle.update()

    def draw(self, surface):
        for particle in self.particles:
            particle.draw(surface)

class RyRain:
    def __init__(self, game):
        self.game = game
        self.drops = []
        for _ in range(100):
            self.drops.append([random.randint(0, game.width), random.randint(-game.height, 0)])

    def update(self):
        for drop in self.drops:
            drop[1] += 5
            if drop[1] > self.game.height:
                drop[1] = random.randint(-100, -10)
                drop[0] = random.randint(0, self.game.width)

    def draw(self, surface):
        for drop in self.drops:
            pygame.draw.line(surface, RyColor.CYAN, drop, (drop[0], drop[1] + 5), 1)

class RySnow:
    def __init__(self, game):
        self.game = game
        self.flakes = []
        for _ in range(100):
            self.flakes.append([random.randint(0, game.width), random.randint(-game.height, 0), random.randint(1, 3)])

    def update(self):
        for flake in self.flakes:
            flake[1] += flake[2]
            flake[0] += random.randint(-1, 1)
            if flake[1] > self.game.height:
                flake[1] = random.randint(-100, -10)
                flake[0] = random.randint(0, self.game.width)

    def draw(self, surface):
        for flake in self.flakes:
            pygame.draw.circle(surface, RyColor.WHITE, (int(flake[0]), int(flake[1])), flake[2])

class RyTerrain:
    def __init__(self, game, width, height, scale=0.1):
        self.game = game
        self.width = width
        self.height = height
        self.scale = scale
        self.terrain = self._generate()

    def _generate(self):
        terrain = []
        for x in range(self.width):
            value = noise.pnoise1(x * self.scale)
            y = int((value + 1) * 0.5 * self.height)
            terrain.append(y)
        return terrain

    def draw(self, surface):
        points = [(x, self.height - y) for x, y in enumerate(self.terrain)]
        points.append((self.width, self.height))
        points.append((0, self.height))
        pygame.draw.polygon(surface, RyColor.GREEN, points)

def ry_distance(x1, y1, x2, y2):
    return math.sqrt((x2 - x1)**2 + (y2 - y1)**2)

def ry_angle(x1, y1, x2, y2):
    return math.atan2(y2 - y1, x2 - x1)

class RyAnimation:
    def __init__(self, frames, frame_duration):
        self.frames = frames
        self.frame_duration = frame_duration
        self.current_frame = 0
        self.time_elapsed = 0

    def update(self, dt):
        self.time_elapsed += dt
        if self.time_elapsed >= self.frame_duration:
            self.current_frame = (self.current_frame + 1) % len(self.frames)
            self.time_elapsed = 0

    def get_current_frame(self):
        return self.frames[self.current_frame]

class RyPathfinding:
    def __init__(self, game, grid):
        self.game = game
        self.grid = grid

    def find_path(self, start, end):
        def heuristic(a, b):
            return abs(a[0] - b[0]) + abs(a[1] - b[1])

        def get_neighbors(node):
            neighbors = []
            for dx, dy in [(0, 1), (1, 0), (0, -1), (-1, 0)]:
                x, y = node[0] + dx, node[1] + dy
                if 0 <= x < len(self.grid) and 0 <= y < len(self.grid[0]) and self.grid[x][y] == 0:
                    neighbors.append((x, y))
            return neighbors

        open_set = set([start])
        closed_set = set()
        came_from = {}
        g_score = {start: 0}
        f_score = {start: heuristic(start, end)}

        while open_set:
            current = min(open_set, key=lambda x: f_score[x])

            if current == end:
                path = []
                while current in came_from:
                    path.append(current)
                    current = came_from[current]
                path.append(start)
                return path[::-1]

            open_set.remove(current)
            closed_set.add(current)

            for neighbor in get_neighbors(current):
                if neighbor in closed_set:
                    continue

                tentative_g_score = g_score[current] + 1

                if neighbor not in open_set:
                    open_set.add(neighbor)
                elif tentative_g_score >= g_score[neighbor]:
                    continue

                came_from[neighbor] = current
                g_score[neighbor] = tentative_g_score
                f_score[neighbor] = g_score[neighbor] + heuristic(neighbor, end)

        return None

class RyDialogueSystem:
    def __init__(self, game):
        self.game = game
        self.dialogues = {}
        self.current_dialogue = None
        self.current_node = None

    def add_dialogue(self, name, dialogue_tree):
        self.dialogues[name] = dialogue_tree

    def start_dialogue(self, name):
        if name in self.dialogues:
            self.current_dialogue = self.dialogues[name]
            self.current_node = self.current_dialogue['start']
        else:
            print(f"Dialogue '{name}' not found.")

    def get_current_text(self):
        if self.current_node:
            return self.current_node['text']
        return None

    def get_current_options(self):
        if self.current_node and 'options' in self.current_node:
            return self.current_node['options']
        return None

    def choose_option(self, option_index):
        if self.current_node and 'options' in self.current_node:
            if 0 <= option_index < len(self.current_node['options']):
                next_node = self.current_node['options'][option_index]['next']
                self.current_node = self.current_dialogue[next_node]
            else:
                print("Invalid option index.")
        else:
            print("No options available.")

class RyInventory:
    def __init__(self, capacity):
        self.capacity = capacity
        self.items = []

    def add_item(self, item):
        if len(self.items) < self.capacity:
            self.items.append(item)
            return True
        return False

    def remove_item(self, item):
        if item in self.items:
            self.items.remove(item)
            return True
        return False

    def get_items(self):
        return self.items

class RyQuest:
    def __init__(self, name, description, objectives):
        self.name = name
        self.description = description
        self.objectives = objectives
        self.completed = False

    def update_objective(self, objective_index, progress):
        if 0 <= objective_index < len(self.objectives):
            self.objectives[objective_index]['progress'] = progress
            if all(obj['progress'] >= obj['required'] for obj in self.objectives):
                self.completed = True

    def is_completed(self):
        return self.completed

class RyQuestManager:
    def __init__(self):
        self.quests = []
        self.active_quests = []

    def add_quest(self, quest):
        self.quests.append(quest)

    def activate_quest(self, quest_name):
        for quest in self.quests:
            if quest.name == quest_name and quest not in self.active_quests:
                self.active_quests.append(quest)
                return True
        return False

    def complete_quest(self, quest_name):
        for quest in self.active_quests:
            if quest.name == quest_name:
                quest.completed = True
                self.active_quests.remove(quest)
                return True
        return False

    def update_quest_objective(self, quest_name, objective_index, progress):
        for quest in self.active_quests:
            if quest.name == quest_name:
                quest.update_objective(objective_index, progress)
                return True
        return False

class RySaveSystem:
    @staticmethod
    def save_game(game_state, filename):
        with open(filename, 'wb') as f:
            pickle.dump(game_state, f)

    @staticmethod
    def load_game(filename):
        with open(filename, 'rb') as f:
            return pickle.load(f)

class RyAchievement:
    def __init__(self, name, description, condition):
        self.name = name
        self.description = description
        self.condition = condition
        self.unlocked = False

    def check_condition(self, game_state):
        if not self.unlocked and self.condition(game_state):
            self.unlocked = True
            return True
        return False

class RyAchievementManager:
    def __init__(self):
        self.achievements = []

    def add_achievement(self, achievement):
        self.achievements.append(achievement)

    def update_achievements(self, game_state):
        unlocked = []
        for achievement in self.achievements:
            if achievement.check_condition(game_state):
                unlocked.append(achievement)
        return unlocked

# Расширение основного класса RyGame
class RyGame:
    def __init__(self, width, height, title="RyGame", fps=60):
        pygame.init()
        pygame.mixer.init()
        self.width = width
        self.height = height
        self.screen = pygame.display.set_mode((width, height))
        pygame.display.set_caption(title)
        self.clock = pygame.time.Clock()
        self.fps = fps
        self.sprites = []
        self.running = True
        self.font = pygame.freetype.Font(None, 36)
        self.keys = pygame.key.get_pressed()
        self.mouse_pos = (0, 0)
        self.mouse_buttons = (False, False, False)
        self.dt = 0
        self.background_color = (0, 0, 0)
        self.camera = None
        self.particle_systems = []
        self.dialogue_system = RyDialogueSystem(self)
        self.quest_manager = RyQuestManager()
        self.achievement_manager = RyAchievementManager()

    def create_animation(self, frames, frame_duration):
        return RyAnimation(frames, frame_duration)

    def create_pathfinding(self, grid):
        return RyPathfinding(self, grid)

    def create_inventory(self, capacity):
        return RyInventory(capacity)

    def create_quest(self, name, description, objectives):
        quest = RyQuest(name, description, objectives)
        self.quest_manager.add_quest(quest)
        return quest

    def create_achievement(self, name, description, condition):
        achievement = RyAchievement(name, description, condition)
        self.achievement_manager.add_achievement(achievement)
        return achievement

    def load_image(self, filename):
        return pygame.image.load(filename).convert_alpha()

    def save_game(self, filename):
        game_state = {
            'player': self.player,
            'sprites': self.sprites,
            'quests': self.quest_manager.quests,
            'active_quests': self.quest_manager.active_quests,
            # Добавьте другие важные данные игры, которые нужно сохранить
        }
        RySaveSystem.save_game(game_state, filename)

    def load_game(self, filename):
        game_state = RySaveSystem.load_game(filename)
        self.player = game_state['player']
        self.sprites = game_state['sprites']
        self.quest_manager.quests = game_state['quests']
        self.quest_manager.active_quests = game_state['active_quests']
        # Восстановите другие важные данные игры

    def update_achievements(self):
        game_state = {
            'player': self.player,
            'quests': self.quest_manager.quests,
            # Добавьте другие данные, необходимые для проверки достижений
        }
        unlocked_achievements = self.achievement_manager.update_achievements(game_state)
        for achievement in unlocked_achievements:
            print(f"Achievement unlocked: {achievement.name} - {achievement.description}")


    def run(self, update_func, draw_func):
        while self.running:
            self.dt = self.clock.tick(self.fps) / 1000.0
            self._handle_events()
            update_func()
            self._update_sprites()
            self._update_particle_systems()
            self._update_weather_effects()
            self.space.step(self.dt)
            self.screen.fill(self.background_color)
            if self.camera:
                self.camera.update()
            draw_func()
            self._draw_sprites()
            self._draw_particle_systems()
            self._draw_weather_effects()
            self.ui_manager.draw_ui(self.screen)
            pygame.display.flip()
        pygame.quit()
        sys.exit()

    def _handle_events(self):
        self.keys = pygame.key.get_pressed()
        self.mouse_pos = pygame.mouse.get_pos()
        self.mouse_buttons = pygame.mouse.get_pressed()
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
            self.ui_manager.process_events(event)

    def _update_sprites(self):
        for sprite in self.sprites:
            sprite.update()

    def _draw_sprites(self):
        for sprite in self.sprites:
            sprite.draw(self.screen)

    def _update_particle_systems(self):
        for ps in self.particle_systems:
            ps.update()

    def _draw_particle_systems(self):
        for ps in self.particle_systems:
            ps.draw(self.screen)

    def _update_weather_effects(self):
        for effect in self.weather_effects:
            effect.update()

    def _draw_weather_effects(self):
        for effect in self.weather_effects:
            effect.draw(self.screen)

    def create_sprite(self, x, y, width, height, color=(255,255,255), image=None, physics=False):
        sprite = RySprite(self, x, y, width, height, color, image, physics)
        self.sprites.append(sprite)
        return sprite

    def remove_sprite(self, sprite):
        self.sprites.remove(sprite)
        if sprite.body:
            self.space.remove(sprite.body, sprite.shape)

    def set_background(self, color):
        self.background_color = color

    def draw_text(self, text, x, y, color=(255,255,255), size=36):
        self.font.render_to(self.screen, (x, y), text, color, size=size)

    def play_sound(self, filename):
        sound = pygame.mixer.Sound(filename)
        sound.play()

    def play_music(self, filename, loops=-1):
        pygame.mixer.music.load(filename)
        pygame.mixer.music.play(loops)

    def stop_music(self):
        pygame.mixer.music.stop()

    def is_key_pressed(self, key):
        return self.keys[key]

    def is_mouse_pressed(self, button=0):
        return self.mouse_buttons[button]

    def get_mouse_pos(self):
        return self.mouse_pos

    def set_camera(self, target):
        self.camera = RyCamera(self, target)

    def load_tilemap(self, filename):
        return RyTilemap(self, filename)

    def create_particle_system(self, x, y):
        ps = RyParticleSystem(self, x, y)
        self.particle_systems.append(ps)
        return ps

    def create_ui_element(self, element_type, rect, text=""):
        if element_type == "button":
            return pygame_gui.elements.UIButton(relative_rect=rect, text=text, manager=self.ui_manager)
        elif element_type == "text_entry":
            return pygame_gui.elements.UITextEntryLine(relative_rect=rect, manager=self.ui_manager)

    def add_weather_effect(self, effect_type):
        if effect_type == "rain":
            self.weather_effects.append(RyRain(self))
        elif effect_type == "snow":
            self.weather_effects.append(RySnow(self))

    def generate_terrain(self, width, height, scale=0.1):
        return RyTerrain(self, width, height, scale)

# Пример использования новых функций
if __name__ == "__main__":
    game = RyGame(800, 600, "Advanced RyGame Example")

    # Создание анимации
    player_frames = [game.load_image(f"player_frame_{i}.png") for i in range(1)]
    player_animation = game.create_animation(player_frames, 0.1)

    # Создание инвентаря
    inventory = game.create_inventory(10)

    # Создание квеста
    quest = game.create_quest("Collect Gems", "Collect 5 gems around the map", [
        {"description": "Collect gems", "required": 5, "progress": 0}
    ])

    # Создание достижения
    def gems_collected_condition(game_state):
        return len([item for item in game_state['player'].inventory.items if item.type == 'gem']) >= 10

    achievement = game.create_achievement("Gem Collector", "Collect 10 gems", gems_collected_condition)

    # Основной игровой цикл
    def update():
        player_animation.update(game.dt)
        game.update_achievements()

    def draw():
        # Отрисовка игры
        pass

    game.run(update, draw)
