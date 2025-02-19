from numba import jit as numba_jit, vectorize, guvectorize
from numba import float64, int64
import numpy as np

def JIT(func):
    """Basic JIT compilation for numeric functions"""
    return numba_jit(nopython=True)(func)

def ParallelJIT(func):
    """JIT with parallel execution"""
    return numba_jit(nopython=True, parallel=True)(func)

def FastMathJIT(func):
    """JIT with fast math optimizations"""
    return numba_jit(nopython=True, fastmath=True)(func)

def vector_jit(func):
    """Vectorized JIT for element-wise operations"""
    return vectorize([float64(float64), int64(int64)])(func)

def matrix_jit(func):
    """JIT for matrix operations"""
    return guvectorize([(float64[:,:], float64[:,:])], '(m,n),(m,n)')(func)

def cache_jit(func):
    """JIT with compilation cache"""
    return numba_jit(nopython=True, cache=True)(func)
