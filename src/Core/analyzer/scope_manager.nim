import std/[strformat, strutils, tables]
import types

proc addError*(self: SemanticAnalyzer, message: string, line: int, column: int, errorType: string = "SemanticError") =
  self.errors.add(SemanticError(
    message: message,
    line: line,
    column: column,
    errorType: errorType
  ))

proc addWarning*(self: SemanticAnalyzer, message: string, line: int, column: int, warningType: string = "Warning") =
  self.warnings.add(SemanticWarning(
    message: message,
    line: line,
    column: column,
    warningType: warningType
  ))

proc enterScope*(self: SemanticAnalyzer, name: string) =
  let newScope = newScope(name, self.currentScope)
  self.currentScope = newScope

proc exitScope*(self: SemanticAnalyzer) =
  if self.currentScope.parent != nil:
    self.currentScope = self.currentScope.parent

proc addSymbol*(self: SemanticAnalyzer, symbol: Symbol): bool =
  if self.currentScope.symbols.hasKey(symbol.name):
    self.addError(
      fmt"Symbol '{symbol.name}' already declared in this scope",
      symbol.line, symbol.column, "RedefinitionError"
    )
    return false
  
  self.currentScope.symbols[symbol.name] = symbol
  return true

proc findSymbol*(self: SemanticAnalyzer, name: string): Symbol =
  echo fmt"=== SEARCHING FOR SYMBOL: {name} ==="
  var scope = self.currentScope
  
  while scope != nil:
    echo fmt"Checking scope: {scope.name} (has {scope.symbols.len} symbols)"
    
    if scope.name.startsWith("func_"):
      echo fmt"Function scope contents:"
      for symName, sym in scope.symbols:
        echo fmt"  - {symName} ({sym.kind}) type: {sym.symbolType}"
    
    if scope.symbols.hasKey(name):
      echo fmt"FOUND '{name}' in scope '{scope.name}'"
      return scope.symbols[name]
    
    scope = scope.parent
  
  echo fmt"Symbol '{name}' NOT FOUND"
  result = Symbol(name: "", kind: skVariable)

proc findSymbolInGlobalScope*(self: SemanticAnalyzer, name: string): Symbol =
  # Ищем только в глобальной области видимости
  if self.globalScope.symbols.hasKey(name):
    return self.globalScope.symbols[name]
  
  # Символ не найден
  result = Symbol(name: "", kind: skVariable)

proc markSymbolUsed*(self: SemanticAnalyzer, name: string) =
  var scope = self.currentScope
  while scope != nil:
    if scope.symbols.hasKey(name):
      scope.symbols[name].isUsed = true
      return
    scope = scope.parent

proc checkUnusedSymbols*(self: SemanticAnalyzer, scope: ref Scope) =
  for name, symbol in scope.symbols:
    if not symbol.isUsed and symbol.kind in {skVariable, skParameter}:
      self.addWarning(
        fmt"Unused {symbol.kind} '{name}'",
        symbol.line, symbol.column, "UnusedVariable"
      )

proc hasMethod*(self: SemanticAnalyzer, className: string, methodName: string): bool =
  if self.classTypes.hasKey(className):
    return methodName in self.classTypes[className]
  return false
