import numba
from functools import wraps

class JitCompile:
    def __init__(self, mode='numba', nopython=True):
        self.mode = mode
        self.nopython = nopython
        
    def __call__(self, func):
        if self.mode == 'numba':
            return numba.jit(nopython=self.nopython)(func)
            
        elif self.mode == 'cython':
            @wraps(func)
            @cython.ccall
            @cython.returns(cython.double)
            def wrapper(*args, **kwargs):
                return func(*args, **kwargs)
            return wrapper
            
        return func

