import sys

class MemoryManager:
    __slots__ = ('objects', 'total_allocated')

    def __init__(self):
        self.objects = {}
        self.total_allocated = 0

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