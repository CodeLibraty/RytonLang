import std/[strutils, strformat, tables, sets, times]
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
    currentFile*: string
    currentNimLine*: int
    rytonVersion*: string

proc newCodeGenerator*(): CodeGenerator =
  result = CodeGenerator(
    indentLevel: 0,
    output: "",
    currentModule: "main",
    importedModules: initHashSet[string](),
    module_mapping: initTable[string, string](),
    currentFuncReturnModifier: '\0',
    currentLambdaReturnModifier: '\0',
    inVar: false,
    currentFile: "main.ry",
    currentNimLine: 1,
    rytonVersion: "0.2.4"
  )

proc indent(self: CodeGenerator): string =
  return "  ".repeat(self.indentLevel)

proc emitLine(self: var CodeGenerator, code: string = "", 
              node: Node = nil, nodeType: string = "", 
              status: string = "ok", extra: string = "") =
  
  # Если переданы параметры для трассировки - добавляем комментарий
  if node != nil and nodeType.len > 0:
    var comment = fmt"# ryton:{self.currentFile}:{node.line}:{node.column}|node:{nodeType}|status:{status}"
    if extra.len > 0:
      comment.add(fmt"|{extra}")
    
    self.output.add(self.indent() & comment & "\n")
    inc(self.currentNimLine)
  
  # Генерируем основную строку кода
  self.output.add(self.indent() & code & "\n")
  inc(self.currentNimLine)

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
proc generateFunctionDeclaration(self: var CodeGenerator, node: Node, addToClass: string = "")
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

  of nkFormatString:
    # Обрабатываем форматированные строки
    let formatter = node.formatType
    let content = node.formatContent

    return fmt"""{formatter}"{content}" """

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
    let value  = self.generateExpression(node.assignVal)

    var noVarType = false
    let varType = node.varType
    if varType == "": noVarType = true

    # Handle different assignment operators
    let op = case node.assignOp
      of "=":   "="
      of "+=":  "+="
      of "-=":  "-="
      of "*=":  "*="
      of "/=":  "/="
      else:     "="

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

        for line in lines: code.add(self.indent() & line.strip(trailing = false) & "\n")

        typeCheck = fmt"if not isType({target}, {prop.checkType}):{code}"
        self.decreaseIndent()

    # Генерируем как единый блок
    if prefix.len > 0:
      if noVarType == false:
        if typeCheck.len > 0:
          result = fmt"{prefix} {target}: {varType} {op} {value}" & "\n" & self.indent() & typeCheck
        else:
          result = fmt"{prefix} {target}: {varType} {op} {value}"
      else:
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

  of nkTable:
    # Генерируем Nim таблицу
    self.addImport("tables")
    
    if node.tablePairs.len == 0:
      return "initTable[string, auto]()"
    
    var pairs: seq[string] = @[]
    for pair in node.tablePairs:
      let key = self.generateExpression(pair.pairKey)
      let value = self.generateExpression(pair.pairValue)
      pairs.add(fmt"{key}: {value}")
    
    let pairsStr = pairs.join(", ")
    return fmt"{{{pairsStr}}}.toTable()"
  
  of nkTablePair:
    # Это не должно вызываться напрямую
    let key = self.generateExpression(node.pairKey)
    let value = self.generateExpression(node.pairValue)
    return fmt"{key}: {value}"

  of nkStructInit:
    let structType = node.structType
    var args: seq[string] = @[]
    
    for arg in node.structArgs:
      if arg.kind == nkAssign:
        let name = arg.assignTarget.ident
        let value = self.generateExpression(arg.assignVal)
        args.add(fmt"{name}: {value}")
    
    let argsStr = args.join(", ")
    return fmt"new{structType}({argsStr})"

  of nkNoop:
    # No operation
    return "discard"

  else:
    # Unsupported expression type
    return fmt"# Unsupported expression type: {node.kind}"

# Statement generation
proc processParameters(self: var CodeGenerator, params: seq[Node]): tuple[paramStrings: seq[string], nilChecks: seq[string]] =
  var paramStrings: seq[string] = @[]
  var nilChecks: seq[string] = @[]

  for param in params:
    var paramStr = param.paramName
    if param.paramType.len > 0:
      paramStr.add(": ")

      case param.paramTypeModifier
      of '!':
        paramStr.add(param.paramType)
        nilChecks.add(fmt"if {param.paramName} == nil: raise newException(ValueError, ""{param.paramName} cannot be nil"")")
      of '?':
        self.addImport("options")
        paramStr.add("Option[" & param.paramType & "]")
      else:
        paramStr.add(param.paramType)

    # Обработка дефолтного значения
    if param.paramDefault != nil:
      let defaultExpr = self.generateExpression(param.paramDefault)
      paramStr.add(" = " & defaultExpr)
    
    paramStrings.add(paramStr)

  return (paramStrings, nilChecks)

proc generateGenericParams(self: var CodeGenerator, genericParams: seq[Node]): string =
  ## Генерирует параметры дженериков [T, U: SomeType]
  if genericParams.len == 0:
    return ""
  
  var params: seq[string] = @[]
  for param in genericParams:
    var paramStr = param.genericName
    
    # Добавляем ограничения
    if param.genericConstraints.len > 0:
      var constraints: seq[string] = @[]
      for constraint in param.genericConstraints:
        constraints.add(constraint.constraintType)
      paramStr.add(": " & constraints.join(" + "))
    
    params.add(paramStr)
  
  return "[" & params.join(", ") & "]"

proc generateGenericType(self: var CodeGenerator, baseType: string, genericArgs: seq[string] = @[]): string =
  ## Генерирует дженерик тип Array[T] -> seq[T] в Nim
  result = case baseType
    of "Array": "seq"
    of "List": "seq" 
    of "Map", "Table": "Table"
    of "Set": "HashSet"
    of "Optional": "Option"
    else: baseType
  
  if genericArgs.len > 0:
    result.add("[" & genericArgs.join(", ") & "]")

proc processReturnType(self: var CodeGenerator, retType: string, retTypeModifier: char): string =
  if retType.len == 0:
    return ""

  case retTypeModifier
  of '?':
    self.addImport("options")
    return ": Option[" & retType & "]"
  of '!':
    return ": " & retType
  else:
    return ": " & retType

proc processModifiers(modifiers: seq[string]): string =
  if modifiers.len > 0:
    return " {." & modifiers.join(", ") & ".}"
  return ""

proc emitNilChecks(self: var CodeGenerator, nilChecks: seq[string]) =
  for check in nilChecks:
    self.emitLine(check)
  if nilChecks.len > 0:
    self.emitLine("")

proc generateLambdaDeclaration(self: var CodeGenerator, node: Node) =
  let (paramStrings, nilChecks) = self.processParameters(node.lambdaParams)
  let returnType = self.processReturnType(node.lambdaRetType, node.lambdaRetTypeModifier)
  let modifiers = processModifiers(node.lambdaMods)

  self.currentLambdaReturnModifier = node.lambdaRetTypeModifier

  # Генерируем дженерик параметры
  let genericParams = self.generateGenericParams(node.lambdaGenericParams)

  let paramsStr = paramStrings.join(", ")
  var saveIndent = self.indentLevel
  self.indentLevel = 0
  self.emitLine(fmt"proc{genericParams}({paramsStr}){returnType}{modifiers} =")
  self.indentLevel = saveIndent

  self.increaseIndent()
  self.emitNilChecks(nilChecks)
  self.generateBlock(node.lambdaBody)
  self.decreaseIndent()

  self.currentLambdaReturnModifier = '\0'

proc generateFunctionDeclaration(self: var CodeGenerator, node: Node, addToClass: string = "") =
  let (paramStrings, nilChecks) = self.processParameters(node.funcParams)
  let returnType = self.processReturnType(node.funcRetType, node.funcRetTypeModifier)
  let modifiers = processModifiers(node.funcMods)
  let accessMethod = if node.funcPublic: "*" else: ""

  self.currentFuncReturnModifier = node.funcRetTypeModifier

  # Генерируем дженерик параметры
  let genericParams = self.generateGenericParams(node.funcGenericParams)

  let paramsStr = paramStrings.join(", ")
  if addToClass.len > 0:
    self.emitLine(fmt"proc {node.funcName}{accessMethod}{genericParams}(this: {addToClass}, {paramsStr}){returnType}{modifiers} =")
  else:
    self.emitLine(fmt"proc {node.funcName}{accessMethod}{genericParams}({paramsStr}){returnType}{modifiers} =")

  self.increaseIndent()
  self.emitNilChecks(nilChecks)
  self.generateBlock(node.funcBody)
  self.decreaseIndent()

  self.currentFuncReturnModifier = '\0'
  self.emitLine()

proc generateMethodDeclaration(self: var CodeGenerator, node: Node, className: string) =
  let (paramStrings, nilChecks) = self.processParameters(node.funcParams)
  let returnType = self.processReturnType(node.funcRetType, node.funcRetTypeModifier)
  let modifiers = processModifiers(node.funcMods)
  let accessMethod = if node.funcPublic: "*" else: ""

  self.currentFuncReturnModifier = node.funcRetTypeModifier

  # Генерируем дженерик параметры
  let genericParams = self.generateGenericParams(node.funcGenericParams)

  let paramsStr = paramStrings.join(", ")
  self.emitLine(fmt"method {node.funcName}{accessMethod}{genericParams}({paramsStr}){returnType}{modifiers} =")

  self.increaseIndent()
  self.emitNilChecks(nilChecks)
  self.generateBlock(node.funcBody)
  self.decreaseIndent()

  self.currentFuncReturnModifier = '\0'
  self.emitLine()

proc generateInitBlock(self: var CodeGenerator, node: Node) =
  let (paramStrings, nilChecks) = self.processParameters(node.initParams)
  let paramsStr = paramStrings.join(", ")

  self.emitLine(fmt"method init*({paramsStr}) =")
  self.increaseIndent()
  self.emitNilChecks(nilChecks)
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
    of nkAssign:
      let assignExpr = self.generateExpression(stmt)
      self.emitLine(assignExpr)
    of nkIf, nkReturn:
      # Эти узлы должны быть внутри методов, а не напрямую в классе
      echo "Warning: statement outside of method: ", stmt.kind
    else: discard

  self.decreaseIndent()

proc generateStructDeclaration(self: var CodeGenerator, node: Node) =
  let name = node.structName
  
  self.emitLine(fmt"type")
  self.increaseIndent()
  self.emitLine(fmt"{name}* = object")
  
  self.increaseIndent()
  for field in node.structFields:
    let fieldType = field.fieldType
    if field.fieldDefault != nil:
      # Поля с значениями по умолчанию генерируем как обычные поля
      # значения по умолчанию обрабатываем в конструкторе
      self.emitLine(fmt"{field.fieldName}*: {fieldType}")
    else:
      self.emitLine(fmt"{field.fieldName}*: {fieldType}")
  self.decreaseIndent()
  self.decreaseIndent()
  
  # Генерируем конструктор
  self.emitLine()
  var params: seq[string] = @[]
  var assignments: seq[string] = @[]
  
  for field in node.structFields:
    if field.fieldDefault != nil:
      let defaultVal = self.generateExpression(field.fieldDefault)
      params.add(fmt"{field.fieldName}: {field.fieldType} = {defaultVal}")
    else:
      params.add(fmt"{field.fieldName}: {field.fieldType}")
    assignments.add(fmt"result.{field.fieldName} = {field.fieldName}")
  
  let paramsStr = params.join(", ")
  self.emitLine(fmt"proc new{name}*({paramsStr}): {name} =")
  self.increaseIndent()
  for assignment in assignments:
    self.emitLine(assignment)
  self.decreaseIndent()
  
  # Генерируем методы
  for meth in node.structMethods:
    self.generateFunctionDeclaration(meth, name)

proc generateEnumDeclaration(self: var CodeGenerator, node: Node) =
  let name = node.enumName
  
  self.emitLine(fmt"type")
  self.increaseIndent()
  self.emitLine(fmt"{name}* = enum")
  
  self.increaseIndent()
  for i, variant in node.enumVariants:
    if variant.variantValue != nil:
      let value = self.generateExpression(variant.variantValue)
      self.emitLine(fmt"{variant.variantName} = {value}")
    else:
      self.emitLine(fmt"{variant.variantName}")
  self.decreaseIndent()
  self.decreaseIndent()
  
  # Генерируем методы
  for meth in node.enumMethods:
    self.generateFunctionDeclaration(meth, name)

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


proc generateCaseCondition(self: var CodeGenerator, switchExpr: string, condition: Node): string =
  case condition.kind
  of nkNumber, nkString, nkIdent:
    # Простое сравнение: value == condition
    let condExpr = self.generateExpression(condition)
    return fmt"{switchExpr} == {condExpr}"
  
  of nkBinary:
    case condition.binOp
    of "..":
      # Диапазон включительно
      let start = self.generateExpression(condition.binLeft)
      let endExpr = self.generateExpression(condition.binRight)
      return fmt"({switchExpr} >= {start} and {switchExpr} <= {endExpr})"
    
    of "...":
      # Диапазон исключительно  
      let start = self.generateExpression(condition.binLeft)
      let endExpr = self.generateExpression(condition.binRight)
      return fmt"({switchExpr} >= {start} and {switchExpr} < {endExpr})"
    
    of "and":
      # Логическое И: (condition1) and (condition2)
      let left = self.generateCaseCondition(switchExpr, condition.binLeft)
      let right = self.generateCaseCondition(switchExpr, condition.binRight)
      return fmt"({left}) and ({right})"
    
    of "or":
      # Логическое ИЛИ: (condition1) or (condition2)
      let left = self.generateCaseCondition(switchExpr, condition.binLeft)
      let right = self.generateCaseCondition(switchExpr, condition.binRight)
      return fmt"({left}) or ({right})"
    
    else:
      # Другие бинарные операции - сравниваем результат
      let condExpr = self.generateExpression(condition)
      return fmt"{switchExpr} == {condExpr}"
  
  of nkCall:
    # Вызов функции - сравниваем результат
    let condExpr = self.generateExpression(condition)
    return fmt"{switchExpr} == {condExpr}"
  
  else:
    # Для остальных случаев - прямое сравнение
    let condExpr = self.generateExpression(condition)
    return fmt"{switchExpr} == {condExpr}"

proc generateSwitchCondition(self: var CodeGenerator, switchExpr: string, caseNode: Node): string =
  var conditions: seq[string] = @[]
  
  for condition in caseNode.caseConditions:
    let conditionStr = self.generateCaseCondition(switchExpr, condition)
    conditions.add(conditionStr)
  
  result = conditions.join(" or ")
  
  # Добавляем guard условие если есть
  if caseNode.caseGuard != nil:
    let guardExpr = self.generateExpression(caseNode.caseGuard)
    result = fmt"({result}) and ({guardExpr})"

proc generateSwitchStatement(self: var CodeGenerator, node: Node) =
  let switchExpr = self.generateExpression(node.switchExpr)
  
  # Генерируем как серию if-elif-else
  var isFirst = true
  
  for caseNode in node.switchCases:
    let keyword = if isFirst: "if" else: "elif"
    isFirst = false
    
    # Генерируем условие для case
    let condition = self.generateSwitchCondition(switchExpr, caseNode)
    self.emitLine(fmt"{keyword} {condition}:")
    
    self.increaseIndent()
    self.generateBlock(caseNode.caseBody)
    self.decreaseIndent()
  
  # Генерируем default case если есть
  if node.switchDefault != nil:
    self.emitLine("else:")
    self.increaseIndent()
    self.generateBlock(node.switchDefault)
    self.decreaseIndent()

proc generateForStatement(self: var CodeGenerator, node: Node) =
  let variable = node.forVar
  
  # Проверяем, есть ли конечное выражение (диапазон) или это итерация по коллекции
  if node.forRange.endExpr == nil:
    # Итерация по коллекции: for item in collection
    let collection = self.generateExpression(node.forRange.start)
    self.emitLine(fmt"for {variable} in {collection}:")
  else:
    # Итерация по диапазону: for i in 1..10
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
  self.emitLine(fmt"pause({delay})")
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
  of nkStructDef:     self.generateStructDeclaration(node)
  of nkEnumDef:       self.generateEnumDeclaration(node)
  of nkState:         self.generateStateDeclaration(node)
  of nkIf:            self.generateIfStatement(node)
  of nkSwitch:        self.generateSwitchStatement(node)
  of nkFor:           self.generateForStatement(node)
  of nkWhile:         self.generateWhileStatement(node)
  of nkInfinit:       self.generateInfinitStatement(node)
  of nkRepeat:        self.generateRepeatStatement(node)
  of nkTry:           self.generateTryStatement(node)
  of nkEvent:         self.generateEventStatement(node)
  of nkImport:        self.generateImportStatement(node)
  of nkReturn:        self.generateReturnStatement(node)
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

  var rytonCompiler: string
  rytonCompiler.add(fmt"# NC Ryton Compiler - v{self.rytonVersion}      #" & "\n")
  rytonCompiler.add("# (с) 2025 CodeLibraty Foundation #\n")
  rytonCompiler.add("#     This file is auto-generated #\n\n")

  # Generate statementse
  for stmt in node.stmts:
    self.generateStatement(stmt)

  # Prepend imports
  let imports = self.generateImports()
  return rytonCompiler & imports & "\n\n\n" & self.output & "\n\n" & "Main()"

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

proc generateMetaTableCode*(name: string, properties: Table[string, Node]): string =
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

proc generateContractCode*(name: string, preConditions, postConditions, invariants: seq[string]): string =
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

