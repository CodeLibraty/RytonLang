from kivy.app import App
from kivy.uix.widget import Widget
from kivy.uix.scrollview import ScrollView
from kivy.uix.image import Image
from kivy.uix.button import Button
from kivy.uix.textinput import TextInput
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
from kivymd.uix.tab import MDTabs, MDTabsBase
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
from kivy import core
import importlib
from functools import lru_cache

class RytonMDApp(MDApp):
    def __init__(self, ryton_instance, **kwargs):
        super().__init__(**kwargs)
        self.ryton = ryton_instance
        self.widgets = {}

    def build(self):
        return self.root

class RuVix:
    def __init__(self, ryton_instance):
        self.ryton = ryton_instance
        self.app = None
        self.custom_widgets = {}

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

    @lru_cache(maxsize=128)
    def create_widget(self, widget_type, **kwargs):
        widget_classes = {
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
#        return widget_classes[widget_type](**kwargs)

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

    @lru_cache(maxsize=128)
    def add_widget(self, parent, child):
        parent.add_widget(child)

    @lru_cache(maxsize=128)
    def bind_event(self, widget, event_name, callback):
        widget.bind(**{event_name: callback})

    @lru_cache(maxsize=128)
    def run_app(self):
        if self.app:
            self.app.run()

    @lru_cache(maxsize=128)
    def create_dialog(self, **kwargs):
        return MDDialog(**kwargs)

    @lru_cache(maxsize=128)
    def create_dropdown_menu(self, **kwargs):
        return MDDropdownMenu(**kwargs)

@lru_cache(maxsize=128)
def init(ryton_instance):
    print('RuVixApp 1.0 stable [based on kivy]')
    return RuVix(ryton_instance)
