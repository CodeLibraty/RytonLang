import ctypes
import time
from pathlib import Path
import os

class RytonGC:
    def __init__(self, algorithm="MarkSweep", heap_size=1024*1024*16, threshold=10000):
        lib_path = Path(__file__).parent / "libRGC.so"
        self.gc_lib = ctypes.CDLL(str(lib_path))
        
        # Определяем типы для C функций
        self.gc_lib.init_collector.argtypes = [ctypes.c_int, ctypes.c_size_t, ctypes.c_size_t]
        self.gc_lib.init_collector.restype = ctypes.c_void_p
        
        self.gc_lib.collect.argtypes = [ctypes.c_void_p]
        self.gc_lib.allocate.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
        self.gc_lib.allocate.restype = ctypes.c_void_p
        
        # Маппинг алгоритмов
        algorithms = {
            "MarkSweep": 0,
            "Reference": 1, 
            "Generational": 2,
            "Incremental": 3
        }
        
        # Инициализируем коллектор
        self.collector = self.gc_lib.init_collector(
            algorithms[algorithm],
            heap_size,
            threshold
        )
        
        self.last_collection = time.time()
        self.collection_interval = 1000
        
    def collect(self):
        self.gc_lib.collect(self.collector)
        self.last_collection = time.time()
        
    def allocate(self, size):
        return self.gc_lib.allocate(self.collector, size)
        
    def get_stats(self):
        stats = self.gc_lib.get_stats(self.collector)
        return {
            "total_allocated": stats.total_allocated,
            "objects_count": stats.objects_count,
            "last_collection": self.last_collection
        }
