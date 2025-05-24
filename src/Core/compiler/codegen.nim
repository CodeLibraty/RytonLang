import std/[strutils, strformat, tables, sets]
import parser

type
  CodeGenerator* = ref object
    indentLevel: int
    output: string
    currentModule: string
    importedModules: HashSet[string]
    module_mapping: Table[string, string]
    currentFuncReturnModifier: char
    currentLambdaReturnModifier: char
    inVar: bool

proc newCodeGenerator*(): CodeGenerator =
  result = CodeGenerator(
    indentLevel: 0,
    output: "",
    currentModule: "main",
    importedModules: initHashSet[string](),
    module_mapping: initTable[string, string](),
    currentFuncReturnModifier: '\0',
    currentLambdaReturnModifier: '\0',
    inVar: false
  )

proc indent(self: CodeGenerator): string =
  return "  ".repeat(self.indentLevel)

proc emitLine(self: var CodeGenerator, code: string = "") =
  self.output.add(self.indent() & code & "\n")

proc increaseIndent(self: var CodeGenerator) =
  self.indentLevel += 1

proc decreaseIndent(self: var CodeGenerator) =
  if self.indentLevel > 0:
    self.indentLevel -= 1

proc addImport(self: var CodeGenerator, moduleName: string) =
  self.importedModules.incl(moduleName)

proc generateImports(self: CodeGenerator): string =
  var imports = newSeq[string]()

  for moduleName in self.importedModules:
    if moduleName.len > 0: # Проверяем что модуль не пустой
      if self.module_mapping.hasKey(moduleName):
        let mappedModule = self.module_mapping[moduleName]
        if "." in mappedModule:
          let parts = mappedModule.split(".")
        else:
          imports.add(fmt"import {mappedModule}")
      else:
        imports.add(fmt"import {moduleName}")

  if imports.len > 0:
    result = imports.join("\n")


# Forward declarations
proc generateExpression(self: var CodeGenerator, node: Node): string
proc generateStatement(self: var CodeGenerator, node: Node)
proc generateBlock(self: var CodeGenerator, node: Node)
proc generateFunctionDeclaration(self: var CodeGenerator, node: Node)
proc generateLambdaDeclaration(self: var CodeGenerator, node: Node)
proc generateIfStatement(self: var CodeGenerator, node: Node)

# Expression generation
proc generateExpression(self: var CodeGenerator, node: Node): string =
  if node == nil:
    return "nil"

  case node.kind
  of nkLambdaDef:
    let savedOutput = self.output
    self.output = ""

    self.generateLambdaDeclaration(node)
    result = self.output

    self.output = savedOutput

  of nkIf:
    let savedOutput = self.output
    self.output = ""

    self.inVar = true
    self.generateIfStatement(node)
    self.inVar = false

    result = self.output

    self.output = savedOutput

  of nkBinary:
    # Binary expression
    let left = self.generateExpression(node.binLeft)
    let right = self.generateExpression(node.binRight)

    # Map operators
    let op = case node.binOp
      of "+": "+"
      of "-": "-"
      of "*": "*"
      of "**": "**"
      of "/": "/"
      of "==": "=="
      of "!=": "!="
      of "<": "<"
      of ">": ">"
      of "<=": "<="
      of ">=": ">="
      of "and": "and"
      of "or": "or"
      else: node.binOp

    return fmt"{left} {op} {right}"

  of nkUnary:
    # Unary expression
    let expr = self.generateExpression(node.unExpr)

    let op = case node.unOp
      of "-": "-"
      of "not": "not "
      else: node.unOp

    return fmt"{op}({expr})"

  of nkNumber:
    # Number literal
    return node.numVal

  of nkString:
    # String literal
    return "\"" & node.strVal & "\""

  of nkBool:
    # Boolean literal
    return if node.boolVal: "true" else: "false"

  of nkIdent:
    # Identifier
    return node.ident

  of nkCall:
    # Function call
    let callee = self.generateExpression(node.callFunc)
    var args: seq[string] = @[]

    for arg in node.callArgs:
      args.add(self.generateExpression(arg))

    let argsStr = args.join(", ")
    return fmt"{callee}({argsStr})"

  of nkProperty:
    # Property access
    let obj = self.generateExpression(node.propObj)
    return fmt"{obj}.{node.propName}"

  of nkGroup:
    # Grouped expression
    let expr = self.generateExpression(node.groupExpr)
    return fmt"({expr})"

  of nkAssign:
    # Assignment
    let target = self.generateExpression(node.assignTarget)
    let value = self.generateExpression(node.assignVal)

    # Handle different assignment operators
    let op = case node.assignOp
      of "=": "="
      of "+=": "+="
      of "-=": "-="
      of "*=": "*="
      of "/=": "/="
      else: "="

    let prefix = case node.declType
      of dtDef: "var" # def в Ryton -> var в Nim
      of dtVal: "let" # val в Ryton -> let в Nim
      of dtNone: "" # Без префикса для обычного присваивания

    var typeCheck = ""
    if node.assignProps.len > 0:
      let prop = node.assignProps[0]

      if prop.kind == nkTypeCheck:
        self.increaseIndent()
        let lines = prop.checkFunc.split("\n")
        var code: string

        for line in lines: code.add(self.indent() & line.strip(
            trailing = false) & "\n")

        typeCheck = fmt"if not isType({target}, {prop.checkType}):{code}"
        self.decreaseIndent()

    # Генерируем как единый блок
    if prefix.len > 0:
      if typeCheck.len > 0:
        result = fmt"{prefix} {target} {op} {value}" & "\n" & self.indent() & typeCheck
      else:
        result = fmt"{prefix} {target} {op} {value}"
    else:
      if typeCheck.len > 0:
        result = fmt"{target} {op} {value}" & "\n" & self.indent() & typeCheck
      else:
        result = fmt"{target} {op} {value}"
      if typeCheck.len > 0:
        result = result & "\n" & typeCheck

  of nkArray:
    result = "["
    for i, elem in node.elements:
      if i > 0: result.add(", ")
      result.add(self.generateExpression(elem))
    result.add("]")

  of nkArrayAccess:
    let arr = self.generateExpression(node.array)
    let idx = self.generateExpression(node.index)
    result = fmt"{arr}[{idx}]"

  of nkNoop:
    # No operation
    return "discard"

  else:
    # Unsupported expression type
    return fmt"# Unsupported expression type: {node.kind}"

# Statement generation
proc generateLambdaDeclaration(self: var CodeGenerator, node: Node) =
  var params: seq[string] = @[]
  var nilChecks: seq[string] = @[]

  # Process parameters
  for param in node.lambdaParams:
    var paramStr = param.paramName
    if param.paramType.len > 0:
      paramStr.add(": ")

      # Обрабатываем модификаторы типов
      case param.paramTypeModifier
      of '!':
        # Строгий тип - добавляем проверку не-nil
        paramStr.add(param.paramType)
        # Добавим код проверки в начало функции
        nilChecks.add(fmt"if {param.paramName} == nil: raise newException(ValueError, ""{param.paramName} cannot be nil"")")
      of '?':
        # Опциональный тип - используем Option[T]
        self.addImport("options")
        paramStr.add("Option[" & param.paramType & "]")
      else:
        # Обычный тип
        paramStr.add(param.paramType)

    params.add(paramStr)

  # Handle return type
  var returnType = ""
  if node.lambdaRetType.len > 0:
    # Сохраняем модификатор возвращаемого типа для использования в generateReturnStatement
    self.currentLambdaReturnModifier = node.lambdaRetTypeModifier
    # Обрабатываем модификатор возвращаемого типа
    case node.lambdaRetTypeModifier
    of '?':
      self.addImport("options")
      returnType = ": Option[" & node.lambdaRetType & "]"
    of '!':
      returnType = ": " & node.lambdaRetType
      # Добавим проверку результата перед возвратом
    else:
      returnType = ": " & node.lambdaRetType

  # Handle modifiers
  var modifiers = ""
  if node.lambdaMods.len > 0:
    modifiers = " {." & node.lambdaMods.join(", ") & ".}"

  # Generate function signature
  let paramsStr = params.join(", ")
  self.emitLine(fmt"proc({paramsStr}){returnType}{modifiers} =")

  # Generate function body
  self.increaseIndent()
  # Вставляем проверки в начало тела функции
  for check in nilChecks:
    self.emitLine(check)
  if nilChecks.len > 0:
    self.emitLine("") # Пустая строка после проверок

  self.generateBlock(node.lambdaBody)
  self.decreaseIndent()

  # Сбрасываем модификатор типа возврощаемого значения после генерации функции
  self.currentLambdaReturnModifier = '\0'

proc generateFunctionDeclaration(self: var CodeGenerator, node: Node) =
  var name: string
  var public: bool
  var accessMethod: string

  name = node.funcName # если не анонимная функция, то имя функции
  public = node.funcPublic

  if public == true: accessMethod = "*"
  else: accessMethod = ""

  var params: seq[string] = @[]
  var nilChecks: seq[string] = @[]

  # Process parameters
  for param in node.funcParams:
    var paramStr = param.paramName
    if param.paramType.len > 0:
      paramStr.add(": ")

      # Обрабатываем модификаторы типов
      case param.paramTypeModifier
      of '!':
        # Строгий тип - добавляем проверку не-nil
        paramStr.add(param.paramType)
        # Добавим код проверки в начало функции
        nilChecks.add(fmt"if {param.paramName} == nil: raise newException(ValueError, ""{param.paramName} cannot be nil"")")
      of '?':
        # Опциональный тип - используем Option[T]
        self.addImport("options")
        paramStr.add("Option[" & param.paramType & "]")
      else:
        # Обычный тип
        paramStr.add(param.paramType)

    params.add(paramStr)

  # Handle return type
  var returnType = ""
  if node.funcRetType.len > 0:
    # Сохраняем модификатор возвращаемого типа для использования в generateReturnStatement
    self.currentFuncReturnModifier = node.funcRetTypeModifier
    # Обрабатываем модификатор возвращаемого типа
    case node.funcRetTypeModifier
    of '?':
      self.addImport("options")
      returnType = ": Option[" & node.funcRetType & "]"
    of '!':
      returnType = ": " & node.funcRetType
      # Добавим проверку результата перед возвратом
    else:
      returnType = ": " & node.funcRetType

  # Handle modifiers
  var modifiers = ""
  if node.funcMods.len > 0:
    modifiers = " {." & node.funcMods.join(", ") & ".}"

  # Generate function signature
  let paramsStr = params.join(", ")
  self.emitLine(fmt"proc {name}{accessMethod}({paramsStr}){returnType}{modifiers} =")

  # Generate function body
  self.increaseIndent()
  # Вставляем проверки в начало тела функции
  for check in nilChecks:
    self.emitLine(check)
  if nilChecks.len > 0:
    self.emitLine("") # Пустая строка после проверок

  self.generateBlock(node.funcBody)
  self.decreaseIndent()

  # Сбрасываем модификатор типа возврощаемого значения после генерации функции
  self.currentFuncReturnModifier = '\0'

  self.emitLine() # Add an empty line after function

proc generateMethodDeclaration(self: var CodeGenerator, node: Node,
    className: string) =
  let name = node.funcName
  var params: seq[string] = @[]
  var nilChecks: seq[string] = @[]

  # Process parameters
  for param in node.funcParams:
    var paramStr = param.paramName
    if param.paramType.len > 0:
      paramStr.add(": ")

      # Обрабатываем модификаторы типов
      case param.paramTypeModifier
      of '!':
        # Строгий тип - добавляем проверку не-nil
        paramStr.add(param.paramType)
        # Добавим код проверки в начало функции
        nilChecks.add(fmt"if {param.paramName} == nil: raise newException(ValueError, ""{param.paramName} cannot be nil"")")
      of '?':
        # Опциональный тип - используем Option[T]
        self.addImport("options")
        paramStr.add("Option[" & param.paramType & "]")
      else:
        # Обычный тип
        paramStr.add(param.paramType)

    params.add(paramStr)

  # Handle return type
  var returnType = ""
  if node.funcRetType.len > 0:
    # Сохраняем модификатор возвращаемого типа для использования в generateReturnStatement
    self.currentFuncReturnModifier = node.funcRetTypeModifier
    # Обрабатываем модификатор возвращаемого типа
    case node.funcRetTypeModifier
    of '?':
      self.addImport("options")
      returnType = ": Option[" & node.funcRetType & "]"
    of '!':
      returnType = ": " & node.funcRetType
      # Добавим проверку результата перед возвратом
    else:
      returnType = ": " & node.funcRetType

  # Handle modifiers
  var modifiers = ""
  if node.funcMods.len > 0:
    modifiers = " {." & node.funcMods.join(", ") & ".}"

  # Generate function signature
  let paramsStr = params.join(", ")
  self.emitLine(fmt"method {name}*({paramsStr}){returnType}{modifiers} =")

  # Generate function body
  self.increaseIndent()
  # Вставляем проверки в начало тела функции
  for check in nilChecks:
    self.emitLine(check)
  if nilChecks.len > 0:
    self.emitLine("") # Пустая строка после проверок

  self.generateBlock(node.funcBody)
  self.decreaseIndent()

  # Сбрасываем модификатор типа возврощаемого значения после генерации функции
  self.currentFuncReturnModifier = '\0'

  self.emitLine() # Add an empty line after function

proc generateInitBlock(self: var CodeGenerator, node: Node) =
  var params: seq[string] = @[]
  var nilChecks: seq[string] = @[]

  # Process parameters
  for param in node.initParams:
    var paramStr = param.paramName
    if param.paramType.len > 0:
      paramStr.add(": ")

      # Обрабатываем модификаторы типов
      case param.paramTypeModifier
      of '!':
        # Строгий тип - добавляем проверку не-nil
        paramStr.add(param.paramType)
        # Добавим код проверки в начало функции
        nilChecks.add(fmt"if {param.paramName} == nil: raise newException(ValueError, ""{param.paramName} cannot be nil"")")
      of '?':
        # Опциональный тип - используем Option[T]
        self.addImport("options")
        paramStr.add("Option[" & param.paramType & "]")
      else:
        # Обычный тип
        paramStr.add(param.paramType)

    params.add(paramStr)

  let paramsStr = params.join(", ")

  # Генерируем метод init
  self.emitLine(fmt"method init*({paramsStr}) =")
  self.increaseIndent()

  # Вставляем проверки в начало тела функции
  for check in nilChecks:
    self.emitLine(check)
  if nilChecks.len > 0:
    self.emitLine("") # Пустая строка после проверок

  self.generateBlock(node.initBody)

  self.decreaseIndent()
  self.emitLine()

proc generateStateDeclaration(self: var CodeGenerator, node: Node) =
  # Добавляем приватное поле состояния
  self.emitLine(fmt"var currentState: string = ""{node.stateName}""")

  # Методы состояния
  for meth in node.stateBody.stateMethods:
    self.emitLine(fmt"method {meth.funcName}*() =")
    self.increaseIndent()
    self.emitLine(fmt"if self.currentState == ""{node.stateName}"": ")
    self.increaseIndent()
    self.generateBlock(meth.funcBody)
    self.decreaseIndent()
    self.decreaseIndent()
    self.emitLine()

  # Метод переключения состояния
  self.emitLine("method switchState*(newState: string) =")
  self.increaseIndent()
  self.emitLine("self.currentState = newState")
  self.decreaseIndent()

proc generatePackDeclaration(self: var CodeGenerator, node: Node) =
  self.addImport("classes")

  let name = node.packName
  let parents = if node.packParents.len > 0:
    " of " & node.packParents.join(", ")
  else: ""

  let modifiers = if node.packMods.len > 0:
    "{." & node.packMods.join(", ") & ".}"
  else: ""

  self.emitLine(modifiers)
  self.emitLine(fmt"class {name}{parents}:")
  self.increaseIndent()

  # Затем все методы
  # Обрабатываем все узлы по порядку
  for stmt in node.packBody.blockStmts:
    case stmt.kind
    of nkInit:
      self.generateInitBlock(stmt)
    of nkFuncDef:
      if stmt.funcMods.len > 0:
        echo "Mods found: ", stmt.funcMods
      self.generateMethodDeclaration(stmt, name)
    of nkIf, nkOutPut:
      # Эти узлы должны быть внутри методов, а не напрямую в классе
      echo "Warning: statement outside of method: ", stmt.kind
    else: discard

  self.decreaseIndent()

proc generateIfStatement(self: var CodeGenerator, node: Node) =
  let condition = self.generateExpression(node.ifCond)

  # если мы внутри переменной то отступ от переменной делать не нужно
  if self.inVar == true:
    let saveIndentLevel = self.indentLevel
    self.indentLevel = 0
    self.emitLine(fmt"if {condition}:")
    self.indentLevel = saveIndentLevel
  else:
    self.emitLine(fmt"if {condition}:")

  self.increaseIndent()
  self.generateBlock(node.ifThen)
  self.decreaseIndent()

  # Handle elif branches
  for elifBranch in node.ifElifs:
    let elifCondition = self.generateExpression(elifBranch.cond)
    self.emitLine(fmt"elif {elifCondition}:")

    self.increaseIndent()
    self.generateBlock(elifBranch.body)
    self.decreaseIndent()

  # Handle else branch
  if node.ifElse != nil:
    self.emitLine("else:")
    self.increaseIndent()
    self.generateBlock(node.ifElse)
    self.decreaseIndent()

proc generateForStatement(self: var CodeGenerator, node: Node) =
  let variable = node.forVar
  let start = self.generateExpression(node.forRange.start)
  let endExpr = self.generateExpression(node.forRange.endExpr)

  # Determine the range operator based on inclusivity
  let rangeOp = if node.forRange.inclusive: ".." else: "..<"

  self.emitLine(fmt"for {variable} in {start}{rangeOp}{endExpr}:")

  self.increaseIndent()
  self.generateBlock(node.forBody)
  self.decreaseIndent()

proc generateEachStatement(self: var CodeGenerator, node: Node) =
  if node.eachStart.kind == nkIdent: # Если итерация по массиву
    self.emitLine(fmt"for {node.eachVar} in {self.generateExpression(node.eachStart)}:")
  else: # Если числовой диапазон
    self.emitLine(fmt"for {node.eachVar} in countup({self.generateExpression(node.eachStart)}, {self.generateExpression(node.eachEnd)}" &
      (if node.eachStep != nil: fmt", {self.generateExpression(node.eachStep)}" else: "") & "):")

  self.increaseIndent()
  if node.eachWhere != nil:
    self.emitLine(fmt"if {self.generateExpression(node.eachWhere)}:")
    self.increaseIndent()
    self.generateBlock(node.eachBody)
    self.decreaseIndent()
  else:
    self.generateBlock(node.eachBody)
  self.decreaseIndent()

proc generateWhileStatement(self: var CodeGenerator, node: Node) =
  let cond = self.generateExpression(node.whileCond)

  self.emitLine(fmt"while {cond}:")
  self.increaseIndent()
  self.generateBlock(node.whileBody)
  self.decreaseIndent()

proc generateInfinitStatement(self: var CodeGenerator, node: Node) =
  let delay = self.generateExpression(node.infDelay)

  # Import required module
  self.addImport("os")

  # Generate an infinite loop with delay
  self.emitLine("while true:")
  self.increaseIndent()
  self.emitLine(fmt"sleep({delay})")
  self.generateBlock(node.infBody)
  self.decreaseIndent()

proc generateRepeatStatement(self: var CodeGenerator, node: Node) =
  let count = self.generateExpression(node.repCount)
  let delay = self.generateExpression(node.repDelay)

  # Import required module
  self.addImport("os")

  # Generate a for loop with delay
  self.emitLine(fmt"for _ in 0..<{count}:")
  self.increaseIndent()
  self.emitLine(fmt"sleep({delay})")
  self.generateBlock(node.repBody)
  self.decreaseIndent()

proc generateTryStatement(self: var CodeGenerator, node: Node) =
  self.emitLine("try:")

  self.increaseIndent()
  self.generateBlock(node.tryBody)
  self.decreaseIndent()

  # Handle catch block
  if node.tryErrType.len > 0:
    self.emitLine(fmt"except {node.tryErrType}:")
  else:
    self.emitLine("except:")

  self.increaseIndent()
  self.generateBlock(node.tryCatch)
  self.decreaseIndent()

proc generateEventStatement(self: var CodeGenerator, node: Node) =
  let condition = self.generateExpression(node.evCond)

  # Generate event handler
  self.emitLine(fmt"proc eventHandler_{node.line}_{node.column}() =")
  self.increaseIndent()
  self.generateBlock(node.evBody)
  self.decreaseIndent()
  self.emitLine()

  # Generate event trigger
  self.emitLine(fmt"if {condition}:")
  self.increaseIndent()
  self.emitLine(fmt"eventHandler_{node.line}_{node.column}()")
  self.decreaseIndent()

proc generateImportStatement(self: var CodeGenerator, node: Node) =
  for imp in node.imports:
    let modulePath = imp.path.join("/") # Сразу используем слеши для путей
    if imp.filter.len > 0:
      # Если есть [] - используем from/import
      let filterStr = imp.filter.join(", ")
      self.emitLine(fmt"from {modulePath} import {filterStr}")
    else:
      # Без [] - прямой импорт
      self.emitLine(fmt"import {modulePath}")

proc generateReturnStatement(self: var CodeGenerator, node: Node) =
  if node.retVal != nil:
    let value = self.generateExpression(node.retVal)

    # Если функция имеет опциональный возвращаемый тип, оборачиваем в some()
    if self.currentFuncReturnModifier == '?':
      self.emitLine(fmt"return some({value})")
    elif self.currentFuncReturnModifier == '!':
      # Для строгого типа добавляем проверку
      self.emitLine(fmt"result = {value}")
      self.emitLine(fmt"if result == nil: raise newException(ValueError, ""Cannot return nil from non-optional function"")")
      self.emitLine(fmt"return result")
    else:
      self.emitLine(fmt"return {value}")
  else:
    self.emitLine("return")

proc generateExpressionStatement(self: var CodeGenerator, node: Node) =
  let expr = self.generateExpression(node.expr)
  self.emitLine(expr)

proc generateBlock(self: var CodeGenerator, node: Node) =
  if node == nil:
    return

  if node.kind == nkBlock:
    # Process block statements
    for stmt in node.blockStmts:
      self.generateStatement(stmt)
  else:
    # If not a block, treat as a single statement
    self.generateStatement(node)

proc generateStatement(self: var CodeGenerator, node: Node) =
  if node == nil:
    return

  case node.kind
  of nkFuncDef:       self.generateFunctionDeclaration(node)
  of nkPackDef:       self.generatePackDeclaration(node)
  of nkState:         self.generateStateDeclaration(node)
  of nkIf:            self.generateIfStatement(node)
  of nkFor:           self.generateForStatement(node)
  of nkEach:          self.generateEachStatement(node)
  of nkWhile:         self.generateWhileStatement(node)
  of nkInfinit:       self.generateInfinitStatement(node)
  of nkRepeat:        self.generateRepeatStatement(node)
  of nkTry:           self.generateTryStatement(node)
  of nkEvent:         self.generateEventStatement(node)
  of nkImport:        self.generateImportStatement(node)
  of nkOutPut:        self.generateReturnStatement(node)
  of nkExprStmt:      self.generateExpressionStatement(node)
  of nkBlock:         self.generateBlock(node)
  of nkNoop:          self.emitLine("discard")
  of nkAssign:
    # For standalone assignment statements
    let assignExpr = self.generateExpression(node)
    self.emitLine(assignExpr)

  else: self.emitLine(fmt"# Unsupported statement type: {node.kind}")

proc generateProgram(self: var CodeGenerator, node: Node): string =
  # Reset state
  self.output = ""
  self.indentLevel = 0
  self.importedModules = initHashSet[string]()

  # Add standard imports
  self.addImport("strutils")
  self.addImport("strformat")
  self.addImport("times")

  # Generate statements
  for stmt in node.stmts:
    self.generateStatement(stmt)

  # Prepend imports
  let imports = self.generateImports()
  return imports & "\n" & self.output

proc generateNimCode*(ast: Node): string =
  ## Generates Nim code from the given AST
  var generator = newCodeGenerator()

  case ast.kind
  of nkProgram:
    result = generator.generateProgram(ast)
  else:
    # If the root is not a program, create a program node with the given node as the only statement
    var program = newNode(nkProgram)
    program.stmts = @[ast]
    result = generator.generateProgram(program)

# Вспомогательные функции для специфических языковых конструкций

proc generateMetaTableCode*(name: string, properties: Table[string,
    Node]): string =
  ## Генерирует код для MetaTable (специальная конструкция Ryton)
  var generator = newCodeGenerator()

  # Импортируем модуль tables
  generator.addImport("tables")

  # Генерируем инициализацию таблицы
  generator.emitLine(fmt"var {name}* = initTable[string, auto]()")

  # Добавляем свойства
  for key, value in properties:
    let valueStr = generator.generateExpression(value)
    generator.emitLine(fmt"{name}[\""{key}\""] = {valueStr}")

  return generator.generateImports() & "\n" & generator.output

proc generateContractCode*(name: string, preConditions, postConditions,
    invariants: seq[string]): string =
  ## Генерирует код для Contract (проектирование по контракту)
  var generator = newCodeGenerator()

  # Генерируем тип контракта
  generator.emitLine(fmt"type {name}* = object")
  generator.increaseIndent()
  generator.emitLine("discard")
  generator.decreaseIndent()
  generator.emitLine()

  # Генерируем проверку предусловий
  if preConditions.len > 0:
    generator.emitLine(fmt"proc checkPreConditions*(self: {name}, args: varargs[auto]): bool =")
    generator.increaseIndent()
    for i, cond in preConditions:
      if i == 0:
        generator.emitLine(fmt"result = {cond}")
      else:
        generator.emitLine(fmt"result = result and {cond}")
    generator.decreaseIndent()
    generator.emitLine()

  # Генерируем проверку постусловий
  if postConditions.len > 0:
    generator.emitLine(fmt"proc checkPostConditions*(self: {name}, result: auto): bool =")
    generator.increaseIndent()
    for i, cond in postConditions:
      if i == 0:
        generator.emitLine(fmt"result = {cond}")
      else:
        generator.emitLine(fmt"result = result and {cond}")
    generator.decreaseIndent()
    generator.emitLine()

  # Генерируем проверку инвариантов
  if invariants.len > 0:
    generator.emitLine(fmt"proc checkInvariants*(self: {name}): bool =")
    generator.increaseIndent()
    for i, cond in invariants:
      if i == 0:
        generator.emitLine(fmt"result = {cond}")
      else:
        generator.emitLine(fmt"result = result and {cond}")
    generator.decreaseIndent()
    generator.emitLine()

  return generator.output

proc generateEventSystem*(events: seq[tuple[name: string,
    targetType: string]]): string =
  ## Генерирует код для системы событий
  var generator = newCodeGenerator()

  # Импортируем необходимые модули
  generator.addImport("tables")

  # Генерируем систему событий
  generator.emitLine("type")
  generator.increaseIndent()
  generator.emitLine("EventHandler* = proc(sender: auto, args: auto)")
  generator.decreaseIndent()
  generator.emitLine()

  generator.emitLine("var eventHandlers* = initTable[string, seq[EventHandler]]()")
  generator.emitLine()

  # Генерируем функцию регистрации
  generator.emitLine("proc addEventListener*(eventName: string, handler: EventHandler) =")
  generator.increaseIndent()
  generator.emitLine("if not eventHandlers.hasKey(eventName):")
  generator.increaseIndent()
  generator.emitLine("eventHandlers[eventName] = @[]")
  generator.decreaseIndent()
  generator.emitLine("eventHandlers[eventName].add(handler)")
  generator.decreaseIndent()
  generator.emitLine()

  # Генерируем функцию триггера
  generator.emitLine("proc triggerEvent*(eventName: string, sender: auto, args: auto) =")
  generator.increaseIndent()
  generator.emitLine("if eventHandlers.hasKey(eventName):")
  generator.increaseIndent()
  generator.emitLine("for handler in eventHandlers[eventName]:")
  generator.increaseIndent()
  generator.emitLine("handler(sender, args)")
  generator.decreaseIndent()
  generator.decreaseIndent()
  generator.decreaseIndent()
  generator.emitLine()

  # Генерируем специфические типы событий
  for event in events:
    let name = event.name
    let targetType = event.targetType

    generator.emitLine(fmt"# Event: {name}")
    generator.emitLine(fmt"proc add{name}Listener*(handler: proc(target: {targetType})) =")
    generator.increaseIndent()
    generator.emitLine(fmt"addEventListener(\""{name}\"", proc(sender: auto, args: auto) =")
    generator.increaseIndent()
    generator.emitLine(fmt"handler({targetType}(args))")
    generator.decreaseIndent()
    generator.emitLine(")")
    generator.decreaseIndent()
    generator.emitLine()

    generator.emitLine(fmt"proc trigger{name}*(target: {targetType}) =")
    generator.increaseIndent()
    generator.emitLine(fmt"triggerEvent(\""{name}\"", nil, target)")
    generator.decreaseIndent()
    generator.emitLine()

  return generator.generateImports() & "\n" & generator.output

