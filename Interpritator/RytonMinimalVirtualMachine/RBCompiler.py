class ByteCode:
    LOAD = '↑'    
    STORE = '↓'   
    ADD = '+'     
    POW = '²'      
    PRINT = '◈'    
    NEWLINE = '⏎'  
    LOOP = '⟳'
    END = '∎'

class Compiler:
    def compile(self, source: str) -> str:
        # Разбиваем на команды
        commands = source.strip().split(';')
        bytecode = []
        
        for cmd in commands:
            cmd = cmd.strip()
            if '=' in cmd:
                # Присваивание: x = 2
                var, value = cmd.split('=')
                bytecode.extend([ByteCode.LOAD, value.strip()])
                bytecode.append(ByteCode.STORE)
                
            elif cmd.startswith('print'):
                # Печать: print(2)
                value = cmd.split('print(')[1].split(')')[0]
                bytecode.extend([ByteCode.LOAD, value])
                bytecode.extend([ByteCode.PRINT, ByteCode.NEWLINE])
                
            elif cmd.startswith('for'):
                # Цикл: for i in range(5)
                count = cmd.split('range(')[1].split(')')[0]
                bytecode.extend([ByteCode.LOAD, count, ByteCode.LOOP])
                
        return ''.join(bytecode)

# Тесты
compiler = Compiler()

print(compiler.compile("x = 2; print(x)"))
