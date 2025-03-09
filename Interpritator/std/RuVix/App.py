from kivymd.app import MDApp
from kivymd.uix.button import MDRaisedButton, MDFlatButton, MDIconButton
from kivymd.uix.label import MDLabel
from kivymd.uix.textfield import MDTextField
from kivymd.uix.boxlayout import MDBoxLayout
from kivymd.uix.floatlayout import MDFloatLayout
from kivymd.uix.gridlayout import MDGridLayout
from kivymd.uix.slider import MDSlider
from kivymd.uix.selectioncontrol import MDSwitch, MDCheckbox
from kivymd.uix.progressbar import MDProgressBar
from kivymd.uix.spinner import MDSpinner
from kivymd.uix.tab import MDTabs, MDTabsBase, MDTabsLabel
from kivymd.uix.card import MDCard
from kivymd.uix.list import MDList, OneLineListItem, TwoLineListItem, ThreeLineListItem
from kivymd.uix.dialog import MDDialog
from kivymd.uix.menu import MDDropdownMenu
from kivymd.uix.toolbar import MDTopAppBar
from kivymd.uix.navigationdrawer import MDNavigationDrawer
from kivymd.uix.snackbar import Snackbar
from kivymd.uix.chip import MDChip
from kivymd.uix.tooltip import MDTooltip
from kivymd.uix.expansionpanel import MDExpansionPanel, MDExpansionPanelThreeLine
from kivymd.uix.bottomnavigation import MDBottomNavigation, MDBottomNavigationItem
from kivymd.uix.taptargetview import MDTapTargetView
from kivymd.uix.pickers import MDDatePicker, MDTimePicker
from kivymd.uix.filemanager import MDFileManager
from kivymd.uix.banner import MDBanner
from kivymd.uix.datatables import MDDataTable

from kivy.app import App
from kivy.uix.widget import Widget
from kivy.uix.scrollview import ScrollView
from kivy.uix.image import Image
from kivy.uix.button import Button
from kivy.uix.textinput import TextInput

from kivy import core
from kivy.graphics.texture import Texture
from kivy.clock import Clock
from kivy.graphics import Rectangle
from kivy.graphics import Color, Rectangle, Canvas, Mesh
from kivy.core.window import Window

from functools import lru_cache

import importlib
import pygame
import random

class Window(MDFloatLayout):
    """Базовое окно для наследования"""
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.title = "RytonApp"
        self.size_hint = (1, 1)
        self._widgets = {}
        self._styles = {}
        self._events = {}
        self._animations = []

    def add(self, widget, **kwargs):
        """Создает и добавляет виджет в окно"""
        widget_class = self.get_widget_class(widget)
        widget = widget_class(**kwargs)
        self._widgets[widget.name] = widget
        self.add_widget(widget)
        return widget

    def set_style(self, name, style_dict):
        """Применяет стили к компонентам"""
        self._styles[name] = style_dict
        if widget := self._widgets.get(name):
            for key, value in style_dict.items():
                setattr(widget, key, value)
    
    def add_component(self, name, widget, style=None):
        """Добавляет компонент с опциональными стилями"""
        self._widgets[name] = widget
        if style:
            self.set_style(name, style)
        self.add_widget(widget)
        
    def on_event(self, event_name, callback):
        """Подписка на события окна"""
        if event_name not in self._events:
            self._events[event_name] = []
        self._events[event_name].append(callback)
        
    def emit_event(self, event_name, *args, **kwargs):
        """Вызов обработчиков события"""
        for callback in self._events.get(event_name, []):
            callback(*args, **kwargs)
            
    def animate(self, widget_name, **properties):
        """Анимация компонента"""
        if widget := self._widgets.get(widget_name):
            anim = Animation(**properties)
            self._animations.append(anim)
            anim.start(widget)

class Game(Window):
    """Окно для игр с поддержкой физики и эффектов"""
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.game_widget = RytonGameWidget()
        self.add_component('game', self.game_widget)
        self.fps = 60
        self._running = False
        self._entities = []
        self._collision_handlers = {}
        self.physics_enabled = True
        
    def add_entity(self, entity):
        """Добавление игрового объекта"""
        self._entities.append(entity)
        
    def on_collision(self, type1, type2, handler):
        """Обработчик столкновений"""
        self._collision_handlers[(type1, type2)] = handler
        
    def check_collisions(self):
        """Проверка столкновений"""
        for i, entity1 in enumerate(self._entities):
            for entity2 in self._entities[i+1:]:
                key = (type(entity1), type(entity2))
                if handler := self._collision_handlers.get(key):
                    if entity1.collides_with(entity2):
                        handler(entity1, entity2)
                        
    def update(self, dt):
        if self._running:
            if self.physics_enabled:
                self.check_collisions()
            self.game_loop(dt)
            for entity in self._entities:
                entity.update(dt)

class Dialog(MDDialog):
    """Улучшенный диалог"""
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.auto_dismiss = True
        self._callbacks = {}
        self._data = {}
        self._validators = {}
        
    def set_data(self, key, value):
        """Сохранение данных диалога"""
        self._data[key] = value
        
    def get_data(self, key):
        """Получение данных диалога"""
        return self._data.get(key)
        
    def add_validator(self, field, validator):
        """Добавление валидатора для поля"""
        self._validators[field] = validator
        
    def validate(self):
        """Проверка всех полей"""
        for field, validator in self._validators.items():
            if not validator(self.get_data(field)):
                return False
        return True
        
    def on_button(self, text, callback):
        """Обработчик кнопки с валидацией"""
        def wrapper():
            if self.validate():
                callback()
        self._callbacks[text] = wrapper

class RytonGameWidget(Widget):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.canvas = Canvas()
        self.pygame_surface = None
        self.texture = None
        self.physics_enabled = False
        self.effects = []
        Clock.schedule_interval(self.update, 1.0/60.0)

    def _update_physics(self, dt):
        if self.physics_enabled:
            # Update velocity with gravity
            self.velocity[1] -= self.gravity * dt
            
            # Update position
            self.pos[0] += self.velocity[0] * dt
            self.pos[1] += self.velocity[1] * dt
            
            # Ground collision
            if self.pos[1] < 0:
                self.pos[1] = 0
                self.velocity[1] = -self.velocity[1] * 0.8  # Bounce with damping

    def setup_pygame(self, size=(800, 600)):
        pygame.init()
        self.size = size
        self.pygame_surface = pygame.Surface(size)
        self.texture = Texture.create(size=size)
        self.texture.flip_vertical()
        
        with self.canvas:
            Color(1, 1, 1, 1)
            self.rect = Rectangle(size=size, texture=self.texture)
        
        # Schedule regular updates    
        Clock.schedule_interval(self.update, 1.0/60.0)
            
    def update(self, dt):
        if hasattr(self, 'draw_callback'):
            self.draw_callback(self.pygame_surface)
            data = pygame.image.tostring(self.pygame_surface, 'RGB')
            self.texture.blit_buffer(data, colorfmt='rgb', bufferfmt='ubyte')
            self.canvas.ask_update()

class RytonMDApp(MDApp):
    def __init__(self, ryton_instance=None, **kwargs):
        super().__init__(**kwargs)
        self.ryton = ryton_instance
        self.widgets = {}
        # Initialize theme
        self.theme_cls.theme_style = "Light"
        self.theme_cls.primary_palette = "Blue"
        
    def set_root(self, widget):
        self.root = widget

    def build(self):
        return self.root


class RuVix:
    def __init__(self, ryton_instance=None):
        self.ryton = ryton_instance
        self.app = None
        self.custom_widgets = {}

    def _create_particle_effect(self, count=100):
        class ParticleEffect:
            def __init__(self):
                self.particles = [(random.randint(0,800), random.randint(0,600), 
                                 random.randint(0,255), random.randint(0,255), random.randint(0,255),
                                 random.uniform(-1,1), random.uniform(-1,1)) # x,y,r,g,b,dx,dy
                                for _ in range(count)]
                
            def draw(self, surface):
                surface.fill((0,0,0,0)) # Очищаем поверхность эффектов
                for i, (x,y,r,g,b,dx,dy) in enumerate(self.particles):
                    pygame.draw.circle(surface, (r,g,b,128), (int(x),int(y)), 2)
                    # Обновляем позицию
                    new_x = x + dx
                    new_y = y + dy
                    # Проверяем границы
                    if not (0 <= new_x <= 800 and 0 <= new_y <= 600):
                        dx = -dx
                        dy = -dy
                    self.particles[i] = (new_x, new_y, r,g,b, dx,dy)
        return ParticleEffect()

    def _create_effect(self, effect_type, **params):
        effects = {
            'particles': self._create_particle_effect,
            'glow': self._create_glow_effect,
            'blur': self._create_blur_effect,
            'wave': self._create_wave_effect
        }
        return effects[effect_type](**params)

    def _create_blur_effect(self, radius=5):
        class BlurEffect:
            def update(self, dt):
                pass # Blur implementation will be added here
        return BlurEffect()
        
    def _create_wave_effect(self, amplitude=100, frequency=10):
        class WaveEffect:
            def update(self, dt):
                pass # Wave implementation will be added here
        return WaveEffect()

    def _create_particle_effect(self, count=100):
        class ParticleEffect:
            def __init__(self):
                self.particles = [(random.random()*800, random.random()*600) 
                                for _ in range(count)]
            def update(self, dt):
                for i, p in enumerate(self.particles):
                    self.particles[i] = (p[0] + random.random()*2-1,
                                       p[1] + random.random()*2-1)
        return ParticleEffect()
        
    def _create_glow_effect(self, radius=10):
        class GlowEffect:
            def update(self, dt):
                pass # Add glow implementation
        return GlowEffect()

    def draw_on_pygame(self, widget, draw_func):
        widget.draw_callback = draw_func
    
    def enable_physics(self, widget, mass=1.0, gravity=9.8):
        widget.physics_enabled = True
        widget.mass = mass
        widget.velocity = [0, 0]
        widget.gravity = gravity
    
    def add_effect(self, widget, effect_type, **params):
        effect = self._create_effect(effect_type, **params)
        widget.effects.append(effect)

    def create_color(self, r, g, b, a=1):
        return Color(r, g, b, a)

    def create_mesh(self, vertices, indices, mode='triangles'):
        return Mesh(
            vertices=vertices,
            indices=indices,
            mode=mode
        )

    def create_canvas_context(self, widget):
        return widget.canvas

    def create_game_widget(self, size=(800, 600)):
        widget = RytonGameWidget()
        widget.setup_pygame(size)
        return widget

    def register_custom_widget(self, widget_name, widget_class):
        self.custom_widgets[widget_name] = widget_class

    def custom_widget(self, widget_name):
        def decorator(widget_class):
            self.custom_widgets[widget_name] = widget_class
            return widget_class
        return decorator

    def load_custom_widgets_module(self, module_name):
        try:
            module = importlib.import_module(module_name)
            for name, obj in module.__dict__.items():
                if isinstance(obj, type) and issubclass(obj, Widget):
                    self.custom_widgets[name] = obj
        except ImportError:
            print(f"Failed to import custom widgets module: {module_name}")

    def create_app(self):
        self.app = RytonMDApp(self.ryton)
        return self.app

    def set_root(self, widget):
        if self.app:
            self.app.root = widget

    def create_widget(self, widget_type, **kwargs):
        widget_classes = {
            'Dialog': MDDialog,
            'Widget': Widget,
            'RaisedButton': MDRaisedButton,
            'Button': Button,
            'TextInput': TextInput,
            'FlatButton': MDFlatButton,
            'IconButton': MDIconButton,
            'Label': MDLabel,
            'TextField': MDTextField,
            'BoxLayout': MDBoxLayout,
            'FloatLayout': MDFloatLayout,
            'GridLayout': MDGridLayout,
            'ScrollView': ScrollView,
            'Slider': MDSlider,
            'Switch': MDSwitch,
            'Checkbox': MDCheckbox,
            'Image': Image,
            'ProgressBar': MDProgressBar,
            'Spinner': MDSpinner,
            'Tabs': MDTabs,
            'TabsBase': MDTabsBase,
            'Card': MDCard,
            'List': MDList,
            'OneLineListItem': OneLineListItem,
            'TwoLineListItem': TwoLineListItem,
            'ThreeLineListItem': ThreeLineListItem,
            'TopAppBar': MDTopAppBar,
            'NavigationDrawer': MDNavigationDrawer,
            'Snackbar': Snackbar,
            'Chip': MDChip,
            'Tooltip': MDTooltip,
            'ExpansionPanel': MDExpansionPanel,
            'ExpansionPanelThreeLine': MDExpansionPanelThreeLine,
            'BottomNavigation': MDBottomNavigation,
            'BottomNavigationItem': MDBottomNavigationItem,
            'TapTargetView': MDTapTargetView,
            'DatePicker': MDDatePicker,
            'TimePicker': MDTimePicker,
            'FileManager': MDFileManager,
            'Banner': MDBanner,
            'DataTable': MDDataTable,
        }

        if widget_type in widget_classes:
            return widget_classes[widget_type](**kwargs)
        elif hasattr(self, f"create_{widget_type}"):
            return getattr(self, f"create_{widget_type}")(**kwargs)
        else:
            raise ValueError(f"Unknown widget type: {widget_type}")

    def create_custom_widget(self, **kwargs):
        # Реализация кастомного виджета
        class CustomWidget(MDBoxLayout):
            def __init__(self, **kwargs):
                super().__init__(**kwargs)
                # Добавьте здесь логику вашего кастомного виджета
        
        return CustomWidget(**kwargs)

    def add_widget(self, parent, child):
        parent.add_widget(child)

    def bind_event(self, widget, event_name, callback):
        widget.bind(**{event_name: callback})

    def run_app(self):
        if self.app:
            self.app.run()

    def create_dialog(self, **kwargs):
        return MDDialog(**kwargs)

    def create_tab_group(self, **kwargs):
        tabs = self.create_widget('Tabs', **kwargs)
        return tabs
        
    def create_tab(self, title, **kwargs):
        content = self.create_widget('BoxLayout', 
            orientation='vertical',
            **kwargs
        )
        content.tab_label_text = title
        return content

    def create_dropdown_menu(self, **kwargs):
        return MDDropdownMenu(**kwargs)
