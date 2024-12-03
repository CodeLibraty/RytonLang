from nuitka.plugins.PluginBase import NuitkaPluginBase

class RytonPlugin(NuitkaPluginBase):
    plugin_name = "ryton"
    
    def __init__(self):
        self.stdlib_modules = [
            "Terminal", "Path", "Files", 
            "String", "DateTime", "Archive", "DeBugger",
            "ErroRize", "RuVixCore", "Algorithm",
            "HyperConfigFormat", "System", "DocTools", "MatplotUp",
            "NeuralNet", "Media", "NetWorker", "Tuix",
            "MetaTable", "ColoRize", "RunTimer", "DSL", "ProgRessing"
        ]
        
    def getImplicitImports(self, module):
        if module.getFullName() == "Interpritator":
            result = [
                ("Interpritator.stdFunction", None),
                ("Interpritator.std", None)
            ]
            
            for lib in self.stdlib_modules:
                result.append((f"Interpritator.std.{lib}", None))
                
            return result
            
        return ()

from nuitka.plugins.Plugins import registerPlugin
registerPlugin(RytonPlugin())
