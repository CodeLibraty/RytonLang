import std/[strformat]
import ../compiler/parser
import types, scope_manager

proc analyzeExpression*(self: SemanticAnalyzer, node: Node): string =
  if node == nil:
    return ""

  case node.kind:
  of nkIdent:
    echo fmt"=== ANALYZING IDENTIFIER IN EXPRESSION: {node.ident} ==="
    echo fmt"Current scope: {self.currentScope.name}"
    echo fmt"Line: {node.line}, Column: {node.column}"
    
    let symbol = self.findSymbol(node.ident)
    if symbol.name == "":
      echo fmt"ERROR: Identifier '{node.ident}' not found in expression!"
      self.addError(
        fmt"Undefined identifier '{node.ident}'",
        node.line, node.column, "UndefinedIdentifier"
      )
      return "unknown"
    
    echo fmt"SUCCESS: Found identifier '{node.ident}' with type '{symbol.symbolType}'"
    self.markSymbolUsed(node.ident)
    return symbol.symbolType

  of nkNumber:
    return "int"

  of nkString:
    return "string"

  of nkBool:
    return "bool"

  of nkBinary:
    let leftType = self.analyzeExpression(node.binLeft)
    let rightType = self.analyzeExpression(node.binRight)
    
    case node.binOp:
    of "+", "-", "*", "/":
      if leftType != rightType:
        self.addError(
          fmt"Type mismatch: cannot apply '{node.binOp}' to '{leftType}' and '{rightType}'",
          node.line, node.column, "TypeMismatch"
        )
      return leftType
    
    of "==", "!=", "<", ">", "<=", ">=":
      if leftType != rightType:
        self.addWarning(
          fmt"Comparing different types: '{leftType}' and '{rightType}'",
          node.line, node.column, "TypeComparison"
        )
      return "bool"
    
    of "and", "or":
      if leftType != "bool" or rightType != "bool":
        self.addError(
          fmt"Logical operators require bool operands, got '{leftType}' and '{rightType}'",
          node.line, node.column, "TypeMismatch"
        )
      return "bool"
    
    else:
      return "unknown"

  of nkProperty:
    if node.propObj.kind == nkIdent:
      let objSymbol = self.findSymbol(node.propObj.ident)
      if objSymbol.name != "":
        # Проверяем, есть ли метод в классе
        if self.hasMethod(objSymbol.symbolType, node.propName):
          self.markSymbolUsed(node.propObj.ident)
          return "method"
        else:
          # UFCS: ищем функцию с именем node.propName
          let funcSymbol = self.findSymbol(node.propName)
          if funcSymbol.name != "" and funcSymbol.kind == skFunction:
            self.markSymbolUsed(node.propObj.ident)
            self.markSymbolUsed(node.propName)
            return "method"
          else:
            self.addError(
              fmt"Method or function '{node.propName}' not found for type '{objSymbol.symbolType}'",
              node.line, node.column, "UndefinedMethod"
            )
            return "unknown"

      else:
        self.addError(
          fmt"Undefined object '{node.propObj.ident}'",
          node.line, node.column, "UndefinedIdentifier"
        )
        return "unknown"
    return "unknown"

  of nkCall:
    if node.callFunc.kind == nkProperty:
      # Это вызов метода через точку (obj.method())
      let methodType = self.analyzeExpression(node.callFunc)
      for arg in node.callArgs:
        discard self.analyzeExpression(arg)
      return "unknown"  # Тип возврата метода
    else:
      # Это обычный вызов функции
      let funcType = self.analyzeExpression(node.callFunc)
      for arg in node.callArgs:
        discard self.analyzeExpression(arg)
      return "unknown"

  else:
    return "unknown"
