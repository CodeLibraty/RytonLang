import std/[strformat, tables]
import ../compiler/parser
import types, scope_manager, expression_analyzer, statement_analyzer

export types, scope_manager, expression_analyzer, statement_analyzer

proc analyzeNode*(self: SemanticAnalyzer, node: Node) =
  if node == nil:
    return
  
  self.analyzeStatement(node)

proc analyze*(self: SemanticAnalyzer, ast: Node): bool =
  ## Выполняет семантический анализ AST
  ## Возвращает true если анализ прошел без ошибок
  
  if ast == nil:
    self.addError("Empty AST", 0, 0, "EmptyAST")
    return false
  
  case ast.kind:
  of nkProgram:
    for stmt in ast.stmts:
      self.analyzeNode(stmt)
  else:
    self.analyzeNode(ast)
  
  # Проверяем неиспользуемые символы в глобальной области видимости
  self.checkUnusedSymbols(self.globalScope)
  
  return self.errors.len == 0

proc printErrors*(self: SemanticAnalyzer) =
  ## Выводит все ошибки семантического анализа
  if self.errors.len == 0:
    echo "No semantic errors found."
    return
  
  echo fmt"Found {self.errors.len} semantic error(s):"
  for error in self.errors:
    echo fmt"  {error.errorType} at line {error.line}, column {error.column}: {error.message}"

proc printWarnings*(self: SemanticAnalyzer) =
  ## Выводит все предупреждения семантического анализа
  if self.warnings.len == 0:
    echo "No warnings found."
    return
  
  echo fmt"Found {self.warnings.len} warning(s):"
  for warning in self.warnings:
    echo fmt"  {warning.warningType} at line {warning.line}, column {warning.column}: {warning.message}"

proc getErrorCount*(self: SemanticAnalyzer): int =
  ## Возвращает количество ошибок
  return self.errors.len

proc getWarningCount*(self: SemanticAnalyzer): int =
  ## Возвращает количество предупреждений
  return self.warnings.len

proc hasErrors*(self: SemanticAnalyzer): bool =
  ## Проверяет наличие ошибок
  return self.errors.len > 0

proc reset*(self: SemanticAnalyzer) =
  ## Сбрасывает состояние анализатора
  self.globalScope = newScope("global")
  self.currentScope = self.globalScope
  self.errors = @[]
  self.warnings = @[]
  self.currentFunction = ""
  self.currentClass = ""
  # Правильный способ очистки таблицы в Nim
  self.classTypes = initTable[string, seq[string]]()
