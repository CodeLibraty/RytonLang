from PyQt6.QtWidgets import *
import sys
from PyQt6.QtCore import *

class QuantUI:
    def __init__(self, ryton_instance=None):
        if QApplication.instance() is None:
            self.app = QApplication(sys.argv)
        self.app.setStyle('Fusion')
        self.layouts = {}  # Храним созданные лейауты

        # Material Design стили
        self.app.setStyleSheet("""
            QPushButton {
                background-color: #1976D2;
                color: white;
                border: none;
                border-radius: 4px;
                padding: 8px 16px;
                font-size: 14px;
                font-weight: 500;
                min-height: 36px;
            }
            QPushButton:hover {
                background-color: #1565C0;
            }
            QPushButton:pressed {
                background-color: #0D47A1;
            }
            
            QLabel {
                color: #F5F5F5;
                font-size: 16px; 
                padding: 5px;
            }
            
            QLineEdit {
                border: 2px solid #E0E0E0;
                border-radius: 4px;
                padding: 8px;
                background: white;
                selection-background-color: #2196F3;
            }
            QLineEdit:focus {
                border-color: #2196F3;
            }
            
            QComboBox {
                border: 2px solid #E0E0E0;
                border-radius: 4px;
                padding: 8px;
                min-height: 36px;
            }
            QComboBox::drop-down {
                border: none;
            }
            
            QCheckBox {
                spacing: 8px;
            }
            QCheckBox::indicator {
                width: 18px;
                height: 18px;
                border: 2px solid #757575;
                border-radius: 2px;
            }
            QCheckBox::indicator:checked {
                background-color: #2196F3;
                border-color: #2196F3;
            }
            
            /* iOS-style элементы */
            QSlider::groove:horizontal {
                height: 2px;
                background: #E0E0E0;
            }
            QSlider::handle:horizontal {
                background: #2196F3;
                width: 24px;
                height: 24px;
                margin: -12px 0;
                border-radius: 12px;
            }
            
            QProgressBar {
                border: none;
                background: #E0E0E0;
                height: 4px;
            }
            QProgressBar::chunk {
                background: #2196F3;
            }
        """)

        self.grid_items = 0 

    def create_app(self):
        self.window = QMainWindow()
        self.central = QWidget()
        self.window.setCentralWidget(self.central)
        self.main_layout = QVBoxLayout()
        self.central.setLayout(self.main_layout)
        
        # ДЕБАГ ИНФОРМАЦИЯ
        print("Создано окно:", self.window)
        print("Центральный виджет:", self.central)
        print("Главный лейаут:", self.main_layout)
        
        self.window.resize(800, 600)
        self.window.show()
        self.app.processEvents()  # Форсируем обработку событий
        return self.window
        
    def create_widget(self, widget_type, **kwargs):
        widget_classes = {
            'Label': QLabel,
            'Button': QPushButton,
            'BoxLayout': QVBoxLayout,
            'HBoxLayout': QHBoxLayout,
            'GridLayout': QGridLayout,
        }
        
        print(f"Создаём виджет типа {widget_type}")  # ДЕБАГ
        widget = widget_classes[widget_type]()
        if 'text' in kwargs:
            widget.setText(kwargs['text'])
        print("Создан виджет:", widget)  # ДЕБАГ
        return widget

    def bind(self, widget, callback):
        if isinstance(widget, QPushButton):
            widget.clicked.connect(callback)
        elif isinstance(widget, QLineEdit):
            widget.textChanged.connect(callback)
        elif isinstance(widget, QComboBox):
            widget.currentIndexChanged.connect(callback)
        elif isinstance(widget, QCheckBox):
            widget.stateChanged.connect(callback)
        elif isinstance(widget, QSlider):
            widget.valueChanged.connect(callback)
        return widget

    def add_widget(self, parent, child):
        if isinstance(parent, QVBoxLayout):
            if isinstance(child, QLayout):
                parent.addLayout(child)
            else:
                parent.addWidget(child)
        elif isinstance(parent, QHBoxLayout):
            if isinstance(child, QLayout):
                parent.addLayout(child)
            else:
                parent.addWidget(child)
        elif isinstance(parent, QFormLayout):
            if isinstance(child, QLayout):
                parent.addLayout(child)
            else:
                parent.addWidget(child)
        elif isinstance(parent, QStackedLayout):
            if isinstance(child, QLayout):
                parent.addLayout(child)
            else:
                parent.addWidget(child)

        if isinstance(parent, QGridLayout):
            # Просто добавляем в grid без всяких children()
            row = self.grid_items // 4  
            col = self.grid_items % 4
            parent.addWidget(child, row, col)
            self.grid_items += 1
        else:
            if isinstance(child, QLayout):
                parent.addLayout(child)
            else:
                parent.addWidget(child)

        self.main_layout.addLayout(parent)  # Привязываем к главному лейауту
        return child

    def setStyle(self, widget, style_sheet):
        widget.setStyleSheet(style_sheet)  

    def run_app(self):
        # Process events before blocking
        self.app.processEvents()
        # Run event loop with infinite timeout
        self.app.exec()
