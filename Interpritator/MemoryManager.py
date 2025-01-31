import sys
from typing import Dict, Any
from .ZigLang.Bridge import ZigBridge

class MemoryManager:
    __slots__ = (
        'objects', 'total_allocated', 
        'stack_memory', 'arena_memory',
        'pool_memory', 'fixed_buffers',
        'zig_bridge', 'leak_detector'
    )

    def __init__(self):
        self.objects = {}
        self.total_allocated = 0
        self.stack_memory = []
        self.arena_memory = {}
        self.pool_memory = {}
        self.fixed_buffers = {}
        self.zig_bridge = ZigBridge()
        self.leak_detector = set()

    # Стековая память
    def stack_allocate(self, size: int) -> bytearray:
        buffer = bytearray(size)
        self.stack_memory.append(buffer)
        return buffer

    def stack_free(self):
        if self.stack_memory:
            self.stack_memory.pop()

    # Арена
    def arena_init(self, arena_id: str):
        self.arena_memory[arena_id] = []
        
    def arena_allocate(self, arena_id: str, size: int):
        buffer = bytearray(size)
        self.arena_memory[arena_id].append(buffer)
        return buffer

    def arena_free(self, arena_id: str):
        if arena_id in self.arena_memory:
            del self.arena_memory[arena_id]

    # Пул объектов
    def pool_init(self, pool_id: str, obj_size: int):
        self.pool_memory[pool_id] = {
            'size': obj_size,
            'free': [],
            'used': set()
        }

    def pool_allocate(self, pool_id: str):
        pool = self.pool_memory[pool_id]
        if pool['free']:
            obj = pool['free'].pop()
        else:
            obj = bytearray(pool['size'])
        pool['used'].add(obj)
        return obj

    def pool_free(self, pool_id: str, obj):
        pool = self.pool_memory[pool_id]
        if obj in pool['used']:
            pool['used'].remove(obj)
            pool['free'].append(obj)

    # Фиксированные буферы
    def fixed_allocate(self, buffer_id: str, size: int):
        buffer = bytearray(size)
        self.fixed_buffers[buffer_id] = buffer
        return buffer

    def fixed_free(self, buffer_id: str):
        if buffer_id in self.fixed_buffers:
            del self.fixed_buffers[buffer_id]

    # Детектор утечек
    def track_allocation(self, obj_id: str, obj):
        self.leak_detector.add(obj_id)

    def untrack_allocation(self, obj_id: str):
        self.leak_detector.remove(obj_id)

    def check_leaks(self):
        return len(self.leak_detector) > 0

    # Выравнивание памяти
    def align_allocation(self, size: int, alignment: int = 16):
        return self.zig_bridge.aligned_alloc(size, alignment)

    def memory_stats(self):
        return {
            'total_allocated': self.total_allocated,
            'stack_depth': len(self.stack_memory),
            'arena_count': len(self.arena_memory),
            'pool_count': len(self.pool_memory),
            'fixed_buffers': len(self.fixed_buffers),
            'tracked_objects': len(self.leak_detector)
        }

    def allocate(self, name, value):
        self.objects[name] = value
        self.total_allocated += sys.getsizeof(value)

    def free(self, name):
        if name in self.objects:
            self.total_allocated -= sys.getsizeof(self.objects[name])
            del self.objects[name]

    def get(self, name):
        return self.objects.get(name)

    def memory_usage(self):
        return self.total_allocated

    def object_count(self):
        return len(self.objects)