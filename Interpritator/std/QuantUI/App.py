from PyQt6.QtWidgets import *
from PyQt6.QtCore import *
from PyQt6.QtGui import *
from functools import lru_cache
import importlib

class QuantWindow(QMainWindow):
    def __init__(self, **kwargs):
        super().__init__()
        self.title = "QuantApp"
        self._widgets = {}
        self._styles = {}
        self._events = {}
        self._animations = []

    def add(self, widget, **kwargs):
        widget_instance = self.get_widget_class(widget)(**kwargs)
        self._widgets[widget_instance.objectName()] = widget_instance
        return widget_instance

    def set_style(self, name, style_dict):
        self._styles[name] = style_dict
        if widget := self._widgets.get(name):
            widget.setStyleSheet(self._compile_style(style_dict))

    def on_event(self, event_name, callback):
        if event_name not in self._events:
            self._events[event_name] = []
        self._events[event_name].append(callback)

class QuantApp:
    def __init__(self, **kwargs):
        self.app = QApplication([])
        self.widgets = {}
        self.custom_widgets = {}
        
    def create_widget(self, widget_type, **kwargs):
        widget_classes = {
            'Button': QPushButton,
            'Label': QLabel,
            'Input': QLineEdit,
            'Container': QWidget,
            'VBox': QVBoxLayout,
            'HBox': QHBoxLayout,
            'Grid': QGridLayout,
            'Tabs': QTabWidget,
            'Table': QTableWidget,
            'Tree': QTreeWidget,
            'List': QListWidget,
            'Dialog': QDialog,
            'Menu': QMenu,
            'Toolbar': QToolBar,
            'ScrollArea': QScrollArea,
            'Splitter': QSplitter,
            'Frame': QFrame,
            'GroupBox': QGroupBox,
            'ComboBox': QComboBox,
            'SpinBox': QSpinBox,
            'Slider': QSlider,
            'ProgressBar': QProgressBar
        }

        if widget_type in widget_classes:
            return widget_classes[widget_type](**kwargs)
        elif widget_type in self.custom_widgets:
            return self.custom_widgets[widget_type](**kwargs)
        else:
            raise ValueError(f"Unknown widget type: {widget_type}")

    def register_custom_widget(self, name, widget_class):
        self.custom_widgets[name] = widget_class

    def create_window(self):
        return QuantWindow()

    def set_root(self, window):
        self.root = window
        self.root.show()

    def add_widget(self, parent, child):
        if isinstance(parent, QLayout):
            parent.addWidget(child)
        else:
            parent.layout().addWidget(child)

    def bind_event(self, widget, event_name, callback):
        if hasattr(widget, event_name):
            getattr(widget, event_name).connect(callback)

    def run(self):
        return self.app.exec()

@lru_cache(maxsize=128)
def init():
    print('QuantUI 1.0 [based on PyQt6]')
    return QuantApp()
