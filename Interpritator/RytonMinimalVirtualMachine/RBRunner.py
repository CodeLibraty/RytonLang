class VM:
    def __init__(self):
        self.stack = []
        self.variables = {}
        self.ip = 0  # instruction pointer
        self.debug = False
        self.loop_stack = []

    def run(self, bytecode, debug=False):
        self.debug = debug
        self.code = list(bytecode)
        
        while self.ip < len(self.code):
            op = self.code[self.ip]
            
            if self.debug:
                print(f"Op: {op}, Stack: {self.stack}, IP: {self.ip}")

            if op == '⟳':  # LOOP_START
                self.loop_stack.append(self.ip)
                
            elif op == '∎':  # LOOP_END/END
                if self.loop_stack:
                    if self.stack and self.stack[-1] > 0:
                        self.stack[-1] -= 1
                        self.ip = self.loop_stack[-1]
                        continue
                    else:
                        self.loop_stack.pop()
                 
            elif op == '↑':  # LOAD
                self.ip += 1
                value = self.code[self.ip]
                self.stack.append(float(value))
                
            elif op == '↓':  # STORE
                if self.stack:
                    value = self.stack.pop()
                    self.variables[self.ip] = value
                else:
                    self.stack.append(0)  # Default value
                
            elif op == '+':  # ADD
                if len(self.stack) >= 2:
                    b = self.stack.pop()
                    a = self.stack.pop()
                    self.stack.append(a + b)
                
            elif op == '×':  # MUL
                if len(self.stack) >= 2:
                    b = self.stack.pop()
                    a = self.stack.pop()
                    self.stack.append(a * b)
                
            elif op == '²':  # POW
                if len(self.stack) >= 2:
                    b = self.stack.pop()
                    a = self.stack.pop()
                    self.stack.append(a ** b)

            elif op == '◈':  # PRINT
                if self.stack:
                    print(self.stack.pop(), end='')
                
            elif op == '⏎':  # NEWLINE
                print()
                
            self.ip += 1
            
        return self.stack[-1] if self.stack else None


# Тестируем:
vm = VM()
# 2 ** 3
result = vm.run('↑5⟳↑1↑2+◈⏎∎')

