from PyQt6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                            QComboBox, QPushButton, QProgressBar, QLabel, QMessageBox)
from PyQt6.QtCore import Qt, QThread, pyqtSignal
from PyQt6.QtGui import QFont, QIcon
import requests
import platform
import sys
import os

class InstallerWorker(QThread):
    progress = pyqtSignal(int)
    finished = pyqtSignal()
    error = pyqtSignal(str)
    
    def __init__(self, version, platform_name):
        super().__init__()
        self.version = version
        self.platform_name = platform_name
        
    def run(self):
        try:
            # Формируем URL для загрузки
            ext = ".zip" if self.platform_name == "windows" else ".tar.gz"
            url = f"https://github.com/CodeLibraty/RytonLang/releases/download/{self.version}/ryton-{self.platform_name}{ext}"
            
            # Загружаем файл
            response = requests.get(url, stream=True)
            total_size = int(response.headers.get('content-length', 0))
            
            # Создаем временный файл
            temp_file = f"ryton_installer{ext}"
            block_size = 1024
            downloaded = 0
            
            with open(temp_file, 'wb') as f:
                for data in response.iter_content(block_size):
                    downloaded += len(data)
                    f.write(data)
                    progress = int((downloaded / total_size) * 100)
                    self.progress.emit(progress)
            
            # Устанавливаем в зависимости от платформы
            if self.platform_name == "windows":
                os.system(f'powershell Expand-Archive {temp_file} -DestinationPath "$env:LOCALAPPDATA\\Ryton"')
                os.system(f'setx PATH "%PATH%;%LOCALAPPDATA%\\Ryton"')
            else:
                os.system(f'tar -xzf {temp_file}')
                os.system(f'sudo mv ryton /usr/local/bin/')
            
            # Очищаем временные файлы
            os.remove(temp_file)
            self.finished.emit()
            
        except Exception as e:
            self.error.emit(str(e))

class RytonInstaller(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Установщик Ryton")
        self.setFixedSize(600, 500)
        
        # Основной виджет
        main_widget = QWidget()
        self.setCentralWidget(main_widget)
        layout = QVBoxLayout(main_widget)
        
        # Заголовок
        title = QLabel("Установка Ryton")
        title.setFont(QFont('Arial', 16, QFont.Weight.Bold))
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title)
        
        # Информация о платформе
        self.platform_name = self.detect_platform()
        platform_label = QLabel(f"Платформа: {self.platform_name}")
        layout.addWidget(platform_label)
        
        # Выпадающий список версий
        self.version_combo = QComboBox()
        self.version_combo.setPlaceholderText("Выберите версию")
        layout.addWidget(self.version_combo)
        
        # Кнопка установки
        self.install_button = QPushButton("Установить")
        self.install_button.clicked.connect(self.start_installation)
        layout.addWidget(self.install_button)
        
        # Прогресс бар
        self.progress_bar = QProgressBar()
        self.progress_bar.setVisible(False)
        layout.addWidget(self.progress_bar)
        
        # Статус
        self.status_label = QLabel()
        self.status_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self.status_label)
        
        # Загружаем список версий
        self.load_versions()
        
    def detect_platform(self):
        system = platform.system().lower()
        if system == "linux":
            return "android" if os.path.exists("/data/data/com.termux") else "linux"
        return system
        
    def load_versions(self):
        try:
            releases = requests.get("https://api.github.com/repos/CodeLibraty/RytonLang/releases").json()
            versions = [release["tag_name"] for release in releases]
            self.version_combo.addItems(versions)
        except Exception as e:
            QMessageBox.critical(self, "Ошибка", f"Не удалось загрузить список версий: {str(e)}")
            
    def start_installation(self):
        version = self.version_combo.currentText()
        if not version:
            QMessageBox.warning(self, "Внимание", "Выберите версию для установки")
            return
            
        self.install_button.setEnabled(False)
        self.progress_bar.setVisible(True)
        self.status_label.setText("Установка...")
        
        # Запускаем установку в отдельном потоке
        self.worker = InstallerWorker(version, self.platform_name)
        self.worker.progress.connect(self.update_progress)
        self.worker.finished.connect(self.installation_finished)
        self.worker.error.connect(self.installation_error)
        self.worker.start()
        
    def update_progress(self, value):
        self.progress_bar.setValue(value)
        
    def installation_finished(self):
        self.progress_bar.setValue(100)
        self.status_label.setText("Установка завершена!")
        QMessageBox.information(self, "Успех", "Ryton успешно установлен!")
        self.install_button.setEnabled(True)
        
    def installation_error(self, error_msg):
        self.status_label.setText("Ошибка установки")
        QMessageBox.critical(self, "Ошибка", f"Ошибка при установке: {error_msg}")
        self.install_button.setEnabled(True)

if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setStyle('Fusion')  # Современный стиль
    
    # Устанавливаем тему
    app.setStyleSheet("""
        QLabel {
            color: #333333;
        }
        QMainWindow {
            background-color: #f0f0f0;
        }
        QPushButton {
            background-color: #0078d4;
            color: white;
            border: none;
            padding: 8px;
            border-radius: 4px;
        }
        QPushButton:hover {
            background-color: #106ebe;
        }
        QPushButton:disabled {
            background-color: #cccccc;
        }
        QComboBox {
            padding: 6px;
            border: 1px solid #cccccc;
            border-radius: 4px;
        }
        QProgressBar {
            border: 1px solid #cccccc;
            border-radius: 4px;
            text-align: center;
        }
        QProgressBar::chunk {
            background-color: #0078d4;
        }
    """)
    
    installer = RytonInstaller()
    installer.show()
    sys.exit(app.exec())
