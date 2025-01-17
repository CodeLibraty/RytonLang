from llvmlite import ir, binding

class RytonBytecodeToLLVM:
    def __init__(self):
        self.module = ir.Module()
        self.builder = None
        self.stack = []
        self.func = None

        # Declare printf function
        self.printf_type = ir.FunctionType(ir.IntType(32), [ir.IntType(8).as_pointer()], var_arg=True)
        self.printf = ir.Function(self.module, self.printf_type, name="printf")
        
        # Declare pow function
        self.pow_type = ir.FunctionType(ir.DoubleType(), [ir.DoubleType(), ir.DoubleType()])
        self.pow = ir.Function(self.module, self.pow_type, name="llvm.pow.f64")

    def compile(self, bytecode):
        func_type = ir.FunctionType(ir.DoubleType(), [])
        self.func = ir.Function(self.module, func_type, "main")
        block = self.func.append_basic_block("entry")
        self.builder = ir.IRBuilder(block)
        
        # Default return value
        default_ret = ir.Constant(ir.DoubleType(), 0.0)
        
        i = 0
        while i < len(bytecode):
            op = bytecode[i]
            
            if op == '↑':
                i += 1
                value = ir.Constant(ir.DoubleType(), float(bytecode[i]))
                self.stack.append(value)
                default_ret = value  # Update default return
                
            elif op == '+':
                right = self.stack.pop()
                left = self.stack.pop()
                result = self.builder.fadd(left, right)
                self.stack.append(result)
                default_ret = result  # Update default return
                
            elif op == '◈':
                if self.stack:
                    self.emit_print(self.stack[-1])
                
            i += 1
            
        # Return last computed value or default
        self.builder.ret(default_ret)
        return str(self.module)

    def emit_print(self, value):
        fmt = "%f\n\0"
        c_fmt = ir.Constant(ir.ArrayType(ir.IntType(8), len(fmt)), 
                          bytearray(fmt.encode("utf8")))
        fmt_arg = self.builder.alloca(c_fmt.type)
        self.builder.store(c_fmt, fmt_arg)
        fmt_arg = self.builder.bitcast(fmt_arg, ir.IntType(8).as_pointer())
        self.builder.call(self.printf, [fmt_arg, value])

    def emit_pow(self, base, exp):
        return self.builder.call(self.pow, [base, exp])

