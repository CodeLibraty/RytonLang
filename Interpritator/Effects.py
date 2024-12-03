from typing import Dict, Callable, Any

class Effect:
    def __init__(self, name: str):
        self.name = name
        self.dependencies = set()

class EffectRegistry:
    _effects: Dict[str, Effect] = {
        'IO': Effect('IO'),
        'Pure': Effect('Pure'),
        'State': Effect('State')
    }
    
    @classmethod
    def validate(cls, func_name: str, effects: list[str]) -> bool:
        return all(effect in cls._effects for effect in effects)
