import os

class PackageSystem:
    def __init__(self):
        self.loaded_packages = {}
        self.package_paths = [os.getcwd()]

    def find_package_file(self, package_name):
        for path in self.package_paths:
            file_path = os.path.join(path, f"{package_name}.ry")
            if os.path.exists(file_path):
                return file_path
        raise ImportError(f"Package '{package_name}' not found")

    def load_package(self, package_name, sharpy_instance):
        if package_name in self.loaded_packages:
            return self.loaded_packages[package_name]

        file_path = self.find_package_file(package_name)
        with open(file_path, 'r') as file:
            package_code = file.read()

        # Создаем отдельный словарь для сбора экспортов
        namespace = {}
        
        # Выполняем код пакета в этом пространстве имен
        exec(sharpy_instance.transform_syntax(package_code), namespace)
        
        # Собираем только пользовательские определения
        exports = {name: value for name, value in namespace.items() 
                if not name.startswith('__') and not name in globals()}
        
        self.loaded_packages[package_name] = exports
        return exports

