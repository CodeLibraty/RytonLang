class PragmaHandler:
    @staticmethod
    def inline(code: str) -> str:
        return f"@functools.lru_cache()\n{code}"
    
    @staticmethod
    def parallel(code: str) -> str:
        return f"@concurrent.futures.ThreadPoolExecutor()\n{code}"
    
    @staticmethod
    def unsafe(code: str) -> str:
        return code.replace("check_bounds", "pass")