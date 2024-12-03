import ctypes
import os
import platform

class RyLow:
    def __init__(self):
        self.os_type = platform.system().lower()
        self.drivers = {}

    def load_driver(self, driver_name, driver_path):
        """
        Загружает драйвер из указанного пути.
        """
        try:
            if self.os_type == 'windows':
                driver = ctypes.windll.LoadLibrary(driver_path)
            elif self.os_type in ['linux', 'darwin']:
                driver = ctypes.cdll.LoadLibrary(driver_path)
            else:
                raise OSError(f"Unsupported OS: {self.os_type}")
            
            self.drivers[driver_name] = driver
            return True
        except Exception as e:
            print(f"Error loading driver {driver_name}: {str(e)}")
            return False

    def unload_driver(self, driver_name):
        """
        Выгружает драйвер из памяти.
        """
        if driver_name in self.drivers:
            del self.drivers[driver_name]
            return True
        return False

    def call_driver_function(self, driver_name, function_name, *args):
        """
        Вызывает функцию загруженного драйвера.
        """
        if driver_name not in self.drivers:
            raise ValueError(f"Driver {driver_name} not loaded")
        
        driver = self.drivers[driver_name]
        if not hasattr(driver, function_name):
            raise AttributeError(f"Function {function_name} not found in driver {driver_name}")
        
        func = getattr(driver, function_name)
        return func(*args)

    def get_system_info(self):
        """
        Возвращает информацию о системе.
        """
        return {
            "OS": self.os_type,
            "Architecture": platform.architecture(),
            "Machine": platform.machine(),
            "Processor": platform.processor()
        }

    def list_loaded_drivers(self):
        """
        Возвращает список загруженных драйверов.
        """
        return list(self.drivers.keys())

    def is_driver_loaded(self, driver_name):
        """
        Проверяет, загружен ли драйвер.
        """
        return driver_name in self.drivers

    def get_driver_info(self, driver_name):
        """
        Возвращает информацию о загруженном драйвере.
        """
        if driver_name not in self.drivers:
            raise ValueError(f"Driver {driver_name} not loaded")
        
        driver = self.drivers[driver_name]
        return {
            "Name": driver_name,
            "Path": driver._name if hasattr(driver, '_name') else "Unknown",
            "Functions": [func for func in dir(driver) if callable(getattr(driver, func))]
        }

# Пример использования:
if __name__ == "__main__":
    rylow = RyLow()
    print(rylow.get_system_info())
    
    # Пример загрузки драйвера (замените на реальный путь к драйверу)
    if rylow.load_driver("example_driver", "/path/to/example_driver.so"):
        print("Driver loaded successfully")
        print(rylow.get_driver_info("example_driver"))
        
        # Пример вызова функции драйвера
        # result = rylow.call_driver_function("example_driver", "some_function", arg1, arg2)
        # print(result)
        
        rylow.unload_driver("example_driver")
    else:
        print("Failed to load driver")
