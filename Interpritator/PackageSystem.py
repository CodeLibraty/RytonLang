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

        # Создаем новый экземпляр SharpyLang для выполнения кода пакета
        package_sharpy = SharpyLang()
        package_sharpy.execute(package_code)
        
        # Собираем экспортированные элементы
        exports = {name: value for name, value in package_sharpy.globals.items() 
                   if not name.startswith('__')}
        
        self.loaded_packages[package_name] = exports
        return exports