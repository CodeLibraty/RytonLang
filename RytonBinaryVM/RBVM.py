from ctypes import CDLL, c_void_p, POINTER, cast, memmove, create_string_buffer, CFUNCTYPE, c_char, addressof
from zipfile import ZipFile
import mmap
import os

class RytonBinaryVM:
    def __init__(self):
        self.mem_size = 4096
        self.exec_memory = mmap.mmap(
            -1, self.mem_size,
            prot=mmap.PROT_READ | mmap.PROT_WRITE | mmap.PROT_EXEC
        )
        self.libraries = {}
        
    def load_bundle(self, bundle_path: str):
        with ZipFile(bundle_path, 'r') as bundle:
            code = bundle.read('entry.dist/entry.bin')
            code_buffer = create_string_buffer(code)
            
            # Get memory address directly
            mem_addr = addressof(code_buffer)
            
            # Copy to executable memory
            self.exec_memory.write(code_buffer.raw)
            self.exec_memory.seek(0)
