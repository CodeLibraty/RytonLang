import std/[strformat, strutils, tables]
import ../compiler/parser
import types, scope_manager, expression_analyzer

proc analyzeStatement*(self: SemanticAnalyzer, node: Node)

proc analyzeNode*(self: SemanticAnalyzer, node: Node) =
  if node == nil:
    return
  
  self.analyzeStatement(node)

proc analyzeFunctionDeclaration*(self: SemanticAnalyzer, node: Node) =
  let oldFunction = self.currentFunction
  self.currentFunction = node.funcName
  
  # Добавляем функцию в ГЛОБАЛЬНУЮ область видимости (для UFCS)
  let funcSymbol = Symbol(
    name: node.funcName,
    kind: if self.currentClass != "": skMethod else: skFunction,
    symbolType: node.funcRetType,
    line: node.line,
    column: node.column,
    scope: "global"  # Всегда добавляем функции в глобальную область
  )

  # Сохраняем текущую область и переключаемся на глобальную
  let currentScope = self.currentScope
  self.currentScope = self.globalScope
  discard self.addSymbol(funcSymbol)
  self.currentScope = currentScope  # Возвращаемся обратно
  
  # Входим в область видимости функции
  self.enterScope(fmt"func_{node.funcName}")
  
  # Если это метод класса, добавляем неявный параметр 'this'
  if self.currentClass != "":
    let thisSymbol = Symbol(
      name: "this",
      kind: skParameter,
      symbolType: self.currentClass,
      line: node.line,
      column: node.column,
      scope: self.currentScope.name
    )
    discard self.addSymbol(thisSymbol)
  
  # Анализируем параметры
  for param in node.funcParams:
    let paramSymbol = Symbol(
      name: param.paramName,
      kind: skParameter,
      symbolType: param.paramType,
      line: param.line,
      column: param.column,
      scope: self.currentScope.name
    )
    discard self.addSymbol(paramSymbol)
  
  # Анализируем тело функции
  self.analyzeNode(node.funcBody)
  
  # Проверяем неиспользуемые символы
  self.checkUnusedSymbols(self.currentScope)
  
  # Выходим из области видимости
  self.exitScope()
  self.currentFunction = oldFunction

proc analyzePackDeclaration*(self: SemanticAnalyzer, node: Node) =
  let oldClass = self.currentClass
  self.currentClass = node.packName
  
  # Добавляем класс в глобальную область видимости
  let classSymbol = Symbol(
    name: node.packName,
    kind: skClass,
    symbolType: node.packName,
    line: node.line,
    column: node.column,
    scope: "global"
  )
  
  # Добавляем в глобальную область видимости
  let currentScope = self.currentScope
  self.currentScope = self.globalScope
  discard self.addSymbol(classSymbol)
  self.currentScope = currentScope
  
  # Инициализируем список методов для класса
  if not self.classTypes.hasKey(node.packName):
    self.classTypes[node.packName] = @[]
  
  # Входим в область видимости класса
  self.enterScope(fmt"class_{node.packName}")
  
  # Сначала собираем все методы класса БЕЗ добавления в символы
  for stmt in node.packBody.blockStmts:
    if stmt.kind == nkFuncDef:
      # Только добавляем метод в список методов класса
      self.classTypes[node.packName].add(stmt.funcName)
  
  # Теперь анализируем тела методов (они сами добавят себя как символы)
  for stmt in node.packBody.blockStmts:
    self.analyzeNode(stmt)
  
  # Выходим из области видимости
  self.exitScope()
  self.currentClass = oldClass

proc analyzeAssignment*(self: SemanticAnalyzer, node: Node) =
  let valueType = self.analyzeExpression(node.assignVal)
  
  if node.assignTarget.kind == nkIdent:
    let varName = node.assignTarget.ident
    
    case node.declType:
    of dtDef, dtVal:
      echo fmt"=== DECLARING NEW VARIABLE: {varName} ==="
      echo fmt"Current scope: {self.currentScope.name}"
      echo fmt"Value type: {valueType}"
      
      let varSymbol = Symbol(
        name: varName,
        kind: skVariable,
        symbolType: valueType,
        line: node.line,
        column: node.column,
        scope: self.currentScope.name
      )
      
      # Добавляем в текущую область видимости
      let success = self.addSymbol(varSymbol)
      
      if success:
        echo fmt"SUCCESS: Added variable '{varName}' to scope '{self.currentScope.name}'"
      else:
        echo fmt"FAILED: Could not add variable '{varName}'"
    
    of dtNone:
      # Обычное присваивание - проверяем существование переменной
      echo fmt"=== ASSIGNING TO EXISTING VARIABLE: {varName} ==="
      let symbol = self.findSymbol(varName)
      if symbol.name == "":
        self.addError(
          fmt"Undefined variable '{varName}'",
          node.line, node.column, "UndefinedVariable"
        )
      else:
        echo fmt"Found existing variable '{varName}' with type '{symbol.symbolType}'"
        if symbol.symbolType != valueType and symbol.symbolType != "unknown" and valueType != "unknown":
          self.addWarning(
            fmt"Type mismatch: assigning '{valueType}' to '{symbol.symbolType}'",
            node.line, node.column, "TypeMismatch"
          )
        self.markSymbolUsed(varName)

proc analyzeIfStatement*(self: SemanticAnalyzer, node: Node) =
  let condType = self.analyzeExpression(node.ifCond)
  if condType != "bool" and condType != "unknown":
    self.addWarning(
      fmt"Condition should be boolean, got '{condType}'",
      node.line, node.column, "TypeWarning"
    )
  
  self.analyzeNode(node.ifThen)
  
  for elifBranch in node.ifElifs:
    let elifCondType = self.analyzeExpression(elifBranch.cond)
    if elifCondType != "bool" and elifCondType != "unknown":
      self.addWarning(
        fmt"Elif condition should be boolean, got '{elifCondType}'",
        node.line, node.column, "TypeWarning"
      )
    self.analyzeNode(elifBranch.body)
  
  if node.ifElse != nil:
    self.analyzeNode(node.ifElse)

proc analyzeForStatement*(self: SemanticAnalyzer, node: Node) =
  self.enterScope("for_loop")
  
  # Добавляем переменную цикла
  let loopVarSymbol = Symbol(
    name: node.forVar,
    kind: skVariable,
    symbolType: "int",
    line: node.line,
    column: node.column,
    scope: self.currentScope.name
  )
  discard self.addSymbol(loopVarSymbol)
  
  # Анализируем диапазон
  discard self.analyzeExpression(node.forRange.start)
  discard self.analyzeExpression(node.forRange.endExpr)
  
  # Анализируем тело цикла
  self.analyzeNode(node.forBody)
  
  self.exitScope()

proc analyzeEachStatement*(self: SemanticAnalyzer, node: Node) =
  self.enterScope("each_loop")
  
  # Добавляем переменную цикла
  let loopVarSymbol = Symbol(
    name: node.eachVar,
    kind: skVariable,
    symbolType: "auto", # Тип зависит от итерируемого объекта
    line: node.line,
    column: node.column,
    scope: self.currentScope.name
  )
  discard self.addSymbol(loopVarSymbol)
  
  # Анализируем выражения
  discard self.analyzeExpression(node.eachStart)
  discard self.analyzeExpression(node.eachEnd)
  
  if node.eachStep != nil:
    discard self.analyzeExpression(node.eachStep)
  
  if node.eachWhere != nil:
    let whereType = self.analyzeExpression(node.eachWhere)
    if whereType != "bool" and whereType != "unknown":
      self.addWarning(
        fmt"Where condition should be boolean, got '{whereType}'",
        node.line, node.column, "TypeWarning"
      )
  
  # Анализируем тело цикла
  self.analyzeNode(node.eachBody)
  
  self.exitScope()

proc analyzeWhileStatement*(self: SemanticAnalyzer, node: Node) =
  let condType = self.analyzeExpression(node.whileCond)
  if condType != "bool" and condType != "unknown":
    self.addWarning(
      fmt"While condition should be boolean, got '{condType}'",
      node.line, node.column, "TypeWarning"
    )
  
  self.enterScope("while_loop")
  self.analyzeNode(node.whileBody)
  self.exitScope()

proc analyzeReturnStatement*(self: SemanticAnalyzer, node: Node) =
  if self.currentFunction == "":
    self.addError(
      "Return statement outside of function",
      node.line, node.column, "InvalidReturn"
    )
    return
  
  if node.retVal != nil:
    discard self.analyzeExpression(node.retVal)

proc analyzeStatement*(self: SemanticAnalyzer, node: Node) =
  case node.kind:
  of nkFuncDef:
    self.analyzeFunctionDeclaration(node)
  of nkPackDef:
    self.analyzePackDeclaration(node)
  of nkAssign:
    self.analyzeAssignment(node)
  of nkExprStmt:
    self.analyzeStatement(node.expr)
  of nkIf:
    self.analyzeIfStatement(node)
  of nkFor:
    self.analyzeForStatement(node)
  of nkEach:
    self.analyzeEachStatement(node)
  of nkWhile:
    self.analyzeWhileStatement(node)
  of nkOutPut:
    self.analyzeReturnStatement(node)
  of nkBlock:
    for stmt in node.blockStmts:
      self.analyzeStatement(stmt)
  else:
    discard
