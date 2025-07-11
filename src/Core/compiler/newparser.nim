import std/[strutils, strformat, json]
import lexer
import ../bytecode/librbt

# Исправленное определение типа Node
type
  NodeKind* = enum
    # Программа и операторы
    nkProgram,        # Программа
    nkBlock,          # Блок кода
    nkExprStmt,       # Выражение-оператор
    
    # Определения
    nkFuncDef,        # Определение функции
    nkLambdaDef,      # Определение лямбда-функции
    nkPackDef,        # Определение класса (pack)
    nkInit,           # init
    nkParam,          # Параметр функции
    nkStructDef,      # Определение структуры
    nkEnumDef,        # Определение перечисления
    nkEnumVariant,    # Вариант перечисления
    nkFieldDef,       # Поле структуры
    nkStructInit,     # Инициализация структуры

    # Управляющие конструкции
    nkIf,             # Условный оператор
    nkFor,            # Цикл for
    nkEach,           # Цикл each
    nkInfinit,        # Бесконечный цикл
    nkRepeat,         # Цикл с повторениями
    nkTry,            # Блок try-error
    nkEvent,          # Событие
    nkImport,         # Импорт модулей
    nkReturn,         # Оператор return
    nkState,          # Объявление состояния
    nkStateBody,      # Тело состояния
    nkWhile,
    nkSwitch,         # Switch statement
    nkSwitchCase,     # Case в switch
  
    # Выражения
    nkBinary,         # Бинарное выражение
    nkUnary,          # Унарное выражение
    nkCall,           # Вызов функции
    nkProperty,       # Доступ к свойству
    nkGroup,          # Группировка выражений
    nkGenericParam,   # Параметр дженерика T, U etc
    nkGenericConstraint, # Ограничение дженерика T: SomeType

    # Присваивания
    nkAssign,         # Присваивание
    
    # Литералы
    nkIdent,          # Идентификатор
    nkNumber,         # Число
    nkString,         # Строка
    nkFormatString,   # Форматированная строка
    nkBool,           # Булево значение
    nkArray,          # Массив
    nkTable,          # Таблица/словарь
    nkTablePair,      # Пара ключ-значение
    nkTypeCheck,      # Типо-повденческий контроль
    nkArrayAccess,    # Доступ к элементам массива [index]
    nkSlice,          # Срезы массивов [start..end]
    nkTupleAccess,    # Доступ к элементам кортежа
    nkRangeExpr,      # Выражения диапазонов
    nkChainCall,      # Цепочки вызовов
    nkSubscript,      # Индексация
    nkNoop            # Пустой оператор (noop)

  DeclType* = enum
    dtNone,  # Просто присваивание
    dtDef,   # var x = ...
    dtVal    # let x = ...
  
  ImportSpec* = object
    path*: seq[string]
    filter*: seq[string]
    items*: seq[string]
    alias*: string
    isAll*: bool

  Node* = ref object
    line*: int        # Строка в исходном коде
    column*: int      # Колонка в исходном коде
    rbtNode*: JsonNode # RBT представление узла
    
    case kind*: NodeKind
    of nkProgram:
      stmts*: seq[Node]
    
    of nkBlock:
      blockStmts*: seq[Node]
    
    of nkExprStmt:
      expr*: Node
    
    of nkInit:
      initBody*: Node
      initParams*: seq[Node]

    of nkFuncDef:
      funcName*: string
      funcParams*: seq[Node]
      funcGenericParams*: seq[Node]
      funcMods*: seq[string]
      funcRetType*: string
      funcRetTypeModifier*: char
      funcPublic*: bool
      funcBody*: Node

    of nkLambdaDef:
      lambdaParams*: seq[Node]
      lambdaMods*: seq[string]
      lambdaRetType*: string
      lambdaGenericParams*: seq[Node]
      lambdaRetTypeModifier*: char
      lambdaBody*: Node
    
    of nkPackDef:
      packName*: string
      packGenericParams*: seq[Node]
      packParents*: seq[string]
      packMods*: seq[string]
      packBody*: Node

    of nkGenericParam:
      genericName*: string
      genericConstraints*: seq[Node]  # T: SomeType + AnotherType
    
    of nkGenericConstraint:
      constraintType*: string

    of nkState:
      stateName*: string
      stateBody*: Node

    of nkStateBody:
      stateMethods*: seq[Node]    # Методы состояния
      stateVars*: seq[Node]       # Переменные состояния
      stateWatchers*: seq[Node]   # Watch блоки

    of nkParam:
      paramName*: string
      paramType*: string
      paramTypeModifier*: char
      paramDefault*: Node

    of nkStructDef:
      structName*: string
      structFields*: seq[Node]
      structMethods*: seq[Node]
    
    of nkEnumDef:
      enumName*: string
      enumVariants*: seq[Node]
      enumMethods*: seq[Node]
    
    of nkEnumVariant:
      variantName*: string
      variantValue*: Node  # может быть nil для автоматической нумерации
    
    of nkFieldDef:
      fieldName*: string
      fieldType*: string
      fieldDefault*: Node  # может быть nil
    
    of nkStructInit:
      structType*: string
      structArgs*: seq[Node]  # именованные аргументы
  
    of nkIf:
      ifCond*: Node
      ifThen*: Node
      ifElifs*: seq[tuple[cond: Node, body: Node]]
      ifElse*: Node

    of nkSwitch:
      switchExpr*: Node              # Выражение для сравнения
      switchCases*: seq[Node]        # Список case'ов
      switchDefault*: Node           # Default case (может быть nil)
    
    of nkSwitchCase:
      caseConditions*: seq[Node]     # Условия case (может быть несколько через |)
      caseBody*: Node               # Тело case
      caseGuard*: Node              # Guard условие (может быть nil)

    of nkFor:
      forVar*: string
      forRange*: tuple[start: Node, inclusive: bool, endExpr: Node]
      forBody*: Node

    of nkEach:
      eachVar*:     string        # Имя переменной цикла
      eachStart*:   Node          # Начальное выражение
      eachEnd*:     Node          # Конечное выражение  
      eachStep*:    Node          # Шаг (может быть nil)
      eachWhere*:   Node          # Условие where (может быть nil)
      eachBody*:    Node          # Тело цикла

    of nkWhile:
      whileCond*: Node
      whileBody*: Node

    of nkInfinit:
      infDelay*: Node
      infBody*: Node
    
    of nkRepeat:
      repCount*: Node
      repDelay*: Node
      repBody*: Node
    
    of nkTry:
      tryBody*: Node
      tryErrType*: string
      tryCatch*: Node
    
    of nkEvent:
      evCond*: Node
      evBody*: Node
    
    of nkImport:
      imports*: seq[ImportSpec]
    
    of nkReturn:
      retVal*: Node
    
    of nkBinary:
      binOp*: string
      binLeft*: Node
      binRight*: Node
    
    of nkUnary:
      unOp*: string
      unExpr*: Node
    
    of nkCall:
      callFunc*: Node
      callArgs*: seq[Node]
    
    of nkProperty:
      propObj*: Node
      propName*: string
    
    of nkGroup:
      groupExpr*: Node
    
    of nkAssign:
      declType*:          DeclType
      assignOp*:          string
      assignTarget*:      Node
      assignVal*:         Node
      assignProps*:       seq[Node]
      varType*:           string
      varTypeModifier*:   char
      
    of nkIdent:
      ident*:   string
    
    of nkNumber:
      numVal*:  string
    
    of nkString:
      strVal*:  string

    of nkFormatString:
      formatType*: string     # Тип форматтера (fmt, custom, etc.)
      formatContent*: string  # Содержимое строки

    of nkTypeCheck:
      checkType*:   string    # Тип для проверки
      checkFunc*:   string    # Функция обработки
      checkBlock*:  Node      # Блок кода (если многострочный блок)
      checkExpr*:   Node      # Выражение для проверки

    of nkArray:
      elements*: seq[Node]

    of nkTable:
      tablePairs*: seq[Node]    # Пары ключ-значение
    
    of nkTablePair:
      pairKey*: Node           # Ключ
      pairValue*: Node         # Значение

    of nkArrayAccess:
      array*: Node
      index*: Node

    of nkSlice:
      sliceArray*: Node
      startIndex*: Node
      endIndex*: Node
      inclusive*: bool

    of nkTupleAccess:
      tupleObj*: Node
      fieldIndex*: int

    of nkRangeExpr:
      rangeStart*: Node
      rangeEnd*: Node
      rangeStep*: Node

    of nkChainCall:
      chain*: seq[Node]

    of nkSubscript:
      container*: Node
      indices*: seq[Node]

    of nkBool:
      boolVal*: bool
    
    of nkNoop:
      discard

  Parser* = ref object
    tokens*: seq[Token]
    current*: int
    errors*: seq[string]
    rbtBuilder*: RBTBuilder

proc newNode*(kind: NodeKind): Node =
  result = Node(kind: kind)

proc newParser*(tokens: seq[Token]): Parser =
  result = Parser(
    tokens: tokens,
    current: 0,
    errors: @[],
    rbtBuilder: createRBTGenerator()
  )

# Вспомогательные функции для работы с токенами
proc isAtEnd(p: Parser): bool =
  p.current >= p.tokens.len or p.tokens[p.current].kind == tkEOF

proc peek(p: Parser): Token =
  if p.isAtEnd():
    result = Token(kind: tkEOF, lexeme: "", line: 0, column: 0)
  else:
    result = p.tokens[p.current]

proc previous(p: Parser): Token =
  result = p.tokens[max(0, p.current - 1)]

proc advance(p: Parser): Token =
  if not p.isAtEnd():
    inc(p.current)
  result = p.previous()

proc check(p: Parser, kind: TokenKind): bool =
  if p.isAtEnd():
    return false
  return p.peek().kind == kind

proc match(p: Parser, kinds: varargs[TokenKind]): bool =
  for kind in kinds:
    if p.check(kind):
      discard p.advance()
      return true
  return false

proc consume(p: Parser, kind: TokenKind, message: string): Token =
  if p.check(kind):
    return p.advance()
  
  let token = p.peek()
  echo fmt"""
╭ SyntaxError
│ {message}
├─────────────────
│ Line {token.line}
│ {token.lexeme}
│ {' '.repeat(token.column)}^
╰─────────────────"""
  return token

# Конвертация Node в JsonNode для RBT
proc nodeToRBT(node: Node): JsonNode =
  if node == nil:
    return newJNull()
  
  case node.kind:
  of nkIdent:
    return createIdent(node.ident)
  of nkNumber:
    return createNumber(node.numVal)
  of nkString:
    return createString(node.strVal)
  of nkBool:
    return createBool(node.boolVal)
  of nkArray:
    var elements: seq[JsonNode] = @[]
    for elem in node.elements:
      elements.add(nodeToRBT(elem))
    return createArray(elements)
  of nkBinary:
    return createBinary(node.binOp, nodeToRBT(node.binLeft), nodeToRBT(node.binRight))
  of nkUnary:
    return createUnary(node.unOp, nodeToRBT(node.unExpr))
  of nkCall:
    var args: seq[JsonNode] = @[]
    for arg in node.callArgs:
      args.add(nodeToRBT(arg))
    return createCall(nodeToRBT(node.callFunc), args)
  else:
    return newJNull()

# Объявления функций парсинга
proc expression(p: Parser): Node
proc statement(p: Parser): Node
proc parseArgument(p: Parser): Node
proc parseBlock(p: Parser): Node
proc parsePackBody(p: Parser): Node
proc functionDeclaration(p: Parser): Node
proc lambdaDeclaration(p: Parser): Node
proc packDeclaration(p: Parser): Node
proc fieldDeclaration(p: Parser): Node
proc structDeclaration(p: Parser): Node
proc enumVariant(p: Parser): Node
proc enumDeclaration(p: Parser): Node
proc ifStatement(p: Parser): Node
proc parseInitBlock(p: Parser): Node
proc forStatement(p: Parser): Node
proc infinitStatement(p: Parser): Node
proc repeatStatement(p: Parser): Node
proc tryStatement(p: Parser): Node
proc eventStatement(p: Parser): Node
proc parseTable(p: Parser): Node
proc parseTablePair(p: Parser): Node
proc importStatement(p: Parser): Node
proc returnStatement(p: Parser): Node
proc expressionStatement(p: Parser): Node

# Парсинг выражений
proc parseArguments(p: Parser): seq[Node]
proc primary(p: Parser): Node

proc parseArgument(p: Parser): Node =
  ## Парсит один аргумент (может быть именованным или позиционным)
  
  # Пропускаем переносы строк
  while p.match(tkNewline): discard
  
  # Проверяем на именованный аргумент (identifier: value)
  if p.check(tkIdentifier):
    let checkpoint = p.current
    let nameToken = p.advance()
    
    # Пропускаем переносы строк после имени
    while p.match(tkNewline): discard
    
    if p.match(tkAssign):
      # Это именованный аргумент
      while p.match(tkNewline): discard # Пропускаем переносы после двоеточия
      
      let value = p.primary()
      
      # Создаем узел именованного аргумента с RBT
      let namedArg = newNode(nkAssign)
      namedArg.assignOp = "="
      namedArg.declType = dtNone
      
      let target = newNode(nkIdent)
      target.ident = nameToken.lexeme
      target.line = nameToken.line
      target.column = nameToken.column
      target.rbtNode = p.rbtBuilder.generateIdent(nameToken.lexeme)
      
      namedArg.assignTarget = target
      namedArg.assignVal = value
      namedArg.line = nameToken.line
      namedArg.column = nameToken.column
      
      # Генерируем RBT для присваивания
      namedArg.rbtNode = p.rbtBuilder.generateAssign(
        "dtNone", "=", nodeToRBT(target), nodeToRBT(value), "", ""
      )
      
      return namedArg
    else:
      # Это обычный аргумент, откатываемся
      p.current = checkpoint
      return p.primary()
  else:
    # Позиционный аргумент
    return p.primary()

proc parseArguments(p: Parser): seq[Node] =
  ## Парсит аргументы функций и инициализаций с поддержкой именованных параметров
  result = @[]
  
  # Пропускаем возможные переносы строк перед первым аргументом
  while p.match(tkNewline): discard
  
  if p.check(tkRParen):
    return result # Пустой список аргументов
  
  # Парсим первый аргумент
  let firstArg = p.parseArgument()
  if firstArg != nil:
    result.add(firstArg)
  
  # Парсим остальные аргументы через запятую
  while p.match(tkComma):
    # Пропускаем возможные переносы строк после запятой
    while p.match(tkNewline): discard
    
    if p.check(tkRParen):
      break # Завершаем если встретили закрывающую скобку
    
    let arg = p.parseArgument()
    if arg != nil:
      result.add(arg)
  
  # Пропускаем возможные переносы строк перед закрывающей скобкой
  while p.match(tkNewline): discard

proc primary(p: Parser): Node =
  # Пропускаем переносы строк в начале
  
  if p.match(tkNumber):
    let token = p.previous()
    result = newNode(nkNumber)
    result.numVal = token.lexeme
    result.line = token.line
    result.column = token.column
    result.rbtNode = p.rbtBuilder.generateNumber(token.lexeme)
    return result
  
  if p.match(tkString):
    let token = p.previous()
    result = newNode(nkString)
    result.strVal = token.lexeme
    result.line = token.line
    result.column = token.column
    result.rbtNode = p.rbtBuilder.generateString(token.lexeme)
    return result

  if p.match(tkFormatString):
    let token = p.previous()
    let parts = token.lexeme.split(":", 1) # Разделяем форматтер и содержимое
    
    result = newNode(nkFormatString)
    result.formatType = parts[0]     # Тип форматтера (fmt, custom, etc.)
    result.formatContent = parts[1]  # Содержимое строки
    result.line = token.line
    result.column = token.column
    result.rbtNode = p.rbtBuilder.generateFormatString(parts[0], parts[1])
    return result
  
  # Булевы значения
  if p.match(tkTrue):
    let token = p.previous()
    result = newNode(nkBool)
    result.boolVal = true
    result.line = token.line
    result.column = token.column
    result.rbtNode = p.rbtBuilder.generateBool(true)
    return result
    
  if p.match(tkFalse):
    let token = p.previous()
    result = newNode(nkBool)
    result.boolVal = false
    result.line = token.line
    result.column = token.column
    result.rbtNode = p.rbtBuilder.generateBool(false)
    return result

  # Лямбда-функции
  if p.check(tkLambda):
    return p.lambdaDeclaration()

  if p.match(tkIdentifier):
    let token = p.previous()
    result = newNode(nkIdent)
    result.ident = token.lexeme
    result.line = token.line
    result.column = token.column
    result.rbtNode = p.rbtBuilder.generateIdent(token.lexeme)
    var expr = result

    while true:
      # Пропускаем переносы строк между операциями
      while p.match(tkNewline): discard
      
      # Доступ к элементам массива [index]
      if p.match(tkLBracket):
        let index = p.expression()
        discard p.consume(tkRBracket, "Expected ']' after array index")
        let access = newNode(nkArrayAccess)
        access.array = expr
        access.index = index
        access.line = token.line
        access.column = token.column
        access.rbtNode = p.rbtBuilder.generateArrayAccess(nodeToRBT(expr), nodeToRBT(index))
        expr = access

      # Доступ к полям через точку obj.field
      elif p.match(tkDot):
        let name = p.consume(tkIdentifier, "Expected property name after '.'")
        let prop = newNode(nkProperty)
        prop.propObj = expr
        prop.propName = name.lexeme
        prop.line = name.line
        prop.column = name.column
        prop.rbtNode = p.rbtBuilder.generateProperty(nodeToRBT(expr), name.lexeme)
        expr = prop
        
      # Вызов методов obj.method() с новой системой аргументов
      elif p.match(tkLParen):
        let args = p.parseArguments()
        discard p.consume(tkRParen, "Expected ')' after arguments")
        let call = newNode(nkCall)
        call.callFunc = expr
        call.callArgs = args
        call.line = token.line
        call.column = token.column
        
        var rbtArgs: seq[JsonNode] = @[]
        for arg in args:
          rbtArgs.add(nodeToRBT(arg))
        call.rbtNode = p.rbtBuilder.generateCall(nodeToRBT(expr), rbtArgs)
        expr = call

      # Срезы массивов arr[1..5]
      elif p.match(tkDotDot, tkDotDotDot):
        let inclusive = p.previous().kind == tkDotDot
        let endIndex = p.expression()
        discard p.consume(tkRBracket, "Expected ']' after slice range")
        let slice = newNode(nkSlice)
        slice.sliceArray = expr
        slice.startIndex = p.expression()
        slice.endIndex = endIndex
        slice.inclusive = inclusive
        slice.line = token.line
        slice.column = token.column
        slice.rbtNode = p.rbtBuilder.generateSlice(
          nodeToRBT(expr), nodeToRBT(slice.startIndex), nodeToRBT(endIndex), inclusive
        )
        expr = slice
        
      else:
        break
        
    return expr
  
  if p.match(tkNoop):
    let token = p.previous()
    result = newNode(nkNoop)
    result.line = token.line
    result.column = token.column
    result.rbtNode = p.rbtBuilder.generateNoop()
    return result

  if p.match(tkLBrace):
    return p.parseTable()

  if p.match(tkLBracket):
    var elements: seq[Node] = @[]
    
    # Пропускаем переносы строк после открывающей скобки
    while p.match(tkNewline): discard
    
    if not p.check(tkRBracket):
      # Первый элемент
      elements.add(p.primary())
      
      # Остальные элементы через запятую
      while p.match(tkComma):
        while p.match(tkNewline): discard
        if p.check(tkRBracket): break
        elements.add(p.primary())
    
    # Пропускаем переносы строк перед закрывающей скобкой
    while p.match(tkNewline): discard
    discard p.consume(tkRBracket, "Expected ']' after array elements")
    
    result = newNode(nkArray)
    result.elements = elements
    
    var rbtElements: seq[JsonNode] = @[]
    for elem in elements:
      rbtElements.add(nodeToRBT(elem))
    result.rbtNode = p.rbtBuilder.generateArray(rbtElements)
    return result

  if p.match(tkLParen):
    while p.match(tkNewline): discard
    let expr = p.expression()
    while p.match(tkNewline): discard
    discard p.consume(tkRParen, "Expected ')' after expression")
    result = newNode(nkGroup)
    result.groupExpr = expr
    result.rbtNode = p.rbtBuilder.generateGroup(nodeToRBT(expr))
    return result
  
  let token = p.peek()
  p.errors.add(fmt"Expected expression at line {token.line}, column {token.column}")
  discard p.advance() # Пропускаем проблемный токен
  return nil

proc finishCall(p: Parser, callee: Node): Node =
  if callee == nil:
    return nil
    
  var args: seq[Node] = @[]

  if not p.check(tkRParen):
    let arg = p.expression()
    if arg != nil:
      args.add(arg)
    while p.match(tkComma):
      let nextArg = p.expression() 
      if nextArg != nil:
        args.add(nextArg)
  discard p.consume(tkRParen, "Expected ')' after arguments")

  result = newNode(nkCall)
  result.callFunc = callee
  result.callArgs = args
  
  var rbtArgs: seq[JsonNode] = @[]
  for arg in args:
    rbtArgs.add(nodeToRBT(arg))
  result.rbtNode = p.rbtBuilder.generateCall(nodeToRBT(callee), rbtArgs)
  return result

proc call(p: Parser): Node =
  var expr = p.primary()
  
  while true:
    if p.match(tkLParen):
      expr = p.finishCall(expr)
    elif p.match(tkDot):
      let name = p.consume(tkIdentifier, "Expected property name after '.'")
      let prop = newNode(nkProperty)
      prop.propObj = expr
      prop.propName = name.lexeme
      prop.line = name.line
      prop.column = name.column
      prop.rbtNode = p.rbtBuilder.generateProperty(nodeToRBT(expr), name.lexeme)
      expr = prop
    else:
      break
  
  return expr

proc unary(p: Parser): Node =
  if p.match(tkMinus, tkNot):
    let operator = p.previous()
    let right = p.unary()
    
    result = newNode(nkUnary)
    result.unOp = if operator.kind == tkMinus: "-" else: "not"
    result.unExpr = right
    result.line = operator.line
    result.column = operator.column
    result.rbtNode = p.rbtBuilder.generateUnary(result.unOp, nodeToRBT(right))
    return result
  
  return p.call()

proc factor(p: Parser): Node =
  var expr = p.unary()
  
  while p.match(tkMul, tkDiv):
    let operator = p.previous()
    let right = p.unary()
    
    let binary = newNode(nkBinary)
    binary.binOp = if operator.kind == tkMul: "*" else: "/"
    binary.binLeft = expr
    binary.binRight = right
    binary.line = operator.line
    binary.column = operator.column
    binary.rbtNode = p.rbtBuilder.generateBinary(binary.binOp, nodeToRBT(expr), nodeToRBT(right))
    expr = binary
  
  return expr

proc term(p: Parser): Node =
  var expr = p.factor()
  
  while p.match(tkPlus, tkMinus):
    let operator = p.previous()
    let right = p.factor()
    
    let binary = newNode(nkBinary)
    binary.binOp = if operator.kind == tkPlus: "+" else: "-"
    binary.binLeft = expr
    binary.binRight = right
    binary.line = operator.line
    binary.column = operator.column
    binary.rbtNode = p.rbtBuilder.generateBinary(binary.binOp, nodeToRBT(expr), nodeToRBT(right))
    expr = binary
  
  return expr

proc comparison(p: Parser): Node =
  var expr = p.term()
  
  while p.match(tkLt, tkLe, tkGt, tkGe):
    let operator = p.previous()
    let right = p.term()

    # Проверяем следующий токен
    if p.check(tkLParen):
      # Если это вызов функции, обрабатываем его отдельно
      let funcCall = p.finishCall(right)
      expr = funcCall
    else:
      # Иначе создаем бинарное выражение сравнения
      let binary = newNode(nkBinary)
      case operator.kind
      of tkLt: binary.binOp = "<"
      of tkLe: binary.binOp = "<="
      of tkGt: binary.binOp = ">"
      of tkGe: binary.binOp = ">="
      else: binary.binOp = ""
      
      binary.binLeft = expr
      binary.binRight = right
      binary.line = operator.line
      binary.column = operator.column
      binary.rbtNode = p.rbtBuilder.generateBinary(binary.binOp, nodeToRBT(expr), nodeToRBT(right))
      expr = binary
      
  return expr

proc equality(p: Parser): Node =
  var expr = p.comparison()
  
  while p.match(tkEq, tkNe):
    let operator = p.previous()
    let right = p.comparison()
    
    let binary = newNode(nkBinary)
    binary.binOp = if operator.kind == tkEq: "==" else: "!="
    binary.binLeft = expr
    binary.binRight = right
    binary.line = operator.line
    binary.column = operator.column
    binary.rbtNode = p.rbtBuilder.generateBinary(binary.binOp, nodeToRBT(expr), nodeToRBT(right))
    expr = binary
  
  return expr

proc logicalAnd(p: Parser): Node =
  var expr = p.equality()
  
  while p.match(tkAnd):
    let operator = p.previous()
    let right = p.equality()
    
    let binary = newNode(nkBinary)
    binary.binOp = "and"
    binary.binLeft = expr
    binary.binRight = right
    binary.line = operator.line
    binary.column = operator.column
    binary.rbtNode = p.rbtBuilder.generateBinary("and", nodeToRBT(expr), nodeToRBT(right))
    expr = binary
  
  return expr

proc logicalOr(p: Parser): Node =
  var expr = p.logicalAnd()
  
  while p.match(tkOr):
    let operator = p.previous()
    let right = p.logicalAnd()
    
    let binary = newNode(nkBinary)
    binary.binOp = "or"
    binary.binLeft = expr
    binary.binRight = right
    binary.line = operator.line
    binary.column = operator.column
    binary.rbtNode = p.rbtBuilder.generateBinary("or", nodeToRBT(expr), nodeToRBT(right))
    expr = binary
  
  return expr

proc parseGenericParam(p: Parser): Node =
  ## Парсит T или T: SomeType или T: Type1 + Type2
  let nameToken = p.consume(tkIdentifier, "Expected generic parameter name")
  
  result = newNode(nkGenericParam)
  result.genericName = nameToken.lexeme
  result.genericConstraints = @[]
  result.line = nameToken.line
  result.column = nameToken.column
  
  # Проверяем ограничения
  if p.match(tkColon):
    # Первое ограничение
    let constraintType = p.consume(tkIdentifier, "Expected constraint type").lexeme
    let constraint = newNode(nkGenericConstraint)
    constraint.constraintType = constraintType
    constraint.rbtNode = p.rbtBuilder.generateGenericConstraint(constraintType)
    result.genericConstraints.add(constraint)
    
    # Дополнительные ограничения через +
    while p.match(tkPlus):
      let additionalType = p.consume(tkIdentifier, "Expected constraint type after '+'").lexeme
      let additionalConstraint = newNode(nkGenericConstraint)
      additionalConstraint.constraintType = additionalType
      additionalConstraint.rbtNode = p.rbtBuilder.generateGenericConstraint(additionalType)
      result.genericConstraints.add(additionalConstraint)

  var rbtConstraints: seq[JsonNode] = @[]
  for constraint in result.genericConstraints:
    rbtConstraints.add(nodeToRBT(constraint))
  result.rbtNode = p.rbtBuilder.generateGenericParam(result.genericName, rbtConstraints)

proc parseGenericParams(p: Parser): seq[Node] =
  ## Парсит [T, U: SomeType, V: AnotherType + MoreType]
  result = @[]
  
  if not p.match(tkLBracket):
    return result
  
  # Пропускаем переносы строк
  while p.match(tkNewline): discard
  
  if p.check(tkRBracket):
    discard p.advance()
    return result
  
  # Первый параметр
  result.add(p.parseGenericParam())
  
  # Остальные параметры через запятую
  while p.match(tkComma):
    while p.match(tkNewline): discard
    if p.check(tkRBracket): break
    result.add(p.parseGenericParam())
  
  while p.match(tkNewline): discard
  discard p.consume(tkRBracket, "Expected ']' after generic parameters")

proc parseGenericType(p: Parser, baseType: string): string =
  ## Парсит Array[int] или Table[string, int] etc
  result = baseType
  
  if p.match(tkLBracket):
    result &= "["
    
    # Первый тип
    result &= p.consume(tkIdentifier, "Expected type in generic").lexeme
    
    # Остальные типы через запятую
    while p.match(tkComma):
      result &= ", "
      result &= p.consume(tkIdentifier, "Expected type after comma").lexeme
    
    result &= "]"
    discard p.consume(tkRBracket, "Expected ']' after generic types")

proc assignment(p: Parser): Node =
  var declType = dtNone
  
  # Проверяем def/val
  declType = if p.match(tkDef):    dtDef
             elif p.match(tkVal):  dtVal
             else:                 dtNone

  # Если это объявление переменной, парсим name : Type
  if declType != dtNone:
    # Ожидаем имя переменной
    let nameToken = p.consume(tkIdentifier, "Expected variable name after 'def'/'val'")
    
    var varType = ""
    var typeModifier = '\0'
    
    # Проверяем аннотацию типа
    if p.match(tkColon):
      # Проверяем модификаторы типа
      if p.match(tkBang):
        typeModifier = '!'
      elif p.match(tkQuestion):
        typeModifier = '?'

      # Получаем тип
      varType = p.consume(tkIdentifier, "Expected type name after ':'").lexeme
      
      # Обработка сложных типов (ptr, ref, generic)
      if varType in ["ptr", "ref"] and p.check(tkIdentifier):
        varType &= " " & p.advance().lexeme
      
      if p.match(tkLBracket):
        varType &= "["
        var bracketDepth = 1
        while bracketDepth > 0 and not p.isAtEnd():
          if p.match(tkLBracket):
            bracketDepth += 1
            varType &= "["
          elif p.match(tkRBracket):
            bracketDepth -= 1
            varType &= "]"
          else:
            varType &= p.advance().lexeme
    
    # Ожидаем знак присваивания
    let assignOp = p.consume(tkAssign, "Expected '=' after variable declaration")
    
    while p.match(tkNewline): discard

    # Парсим значение
    let value = if p.check(tkLambda): p.lambdaDeclaration()
                elif p.check(tkIf):   p.ifStatement()
                else:                 p.assignment()
    
    # Создаем узел присваивания
    let assign = newNode(nkAssign)
    assign.declType = declType
    assign.assignOp = "="
    
    let target = newNode(nkIdent)
    target.ident = nameToken.lexeme
    target.line = nameToken.line
    target.column = nameToken.column
    target.rbtNode = p.rbtBuilder.generateIdent(nameToken.lexeme)
    
    assign.assignTarget = target
    assign.assignVal = value
    assign.varType = varType  # Сохраняем тип
    assign.varTypeModifier = typeModifier
    assign.line = assignOp.line
    assign.column = assignOp.column
    
    # Генерируем RBT для присваивания
    let declTypeStr = case declType:
      of dtDef: "dtDef"
      of dtVal: "dtVal"
      else: "dtNone"
    
    assign.rbtNode = p.rbtBuilder.generateAssign(
      declTypeStr, "=", nodeToRBT(target), nodeToRBT(value), 
      varType, $typeModifier
    )
    
    return assign
  
  # Если не объявление переменной, парсим как обычно
  var expr = p.logicalOr()

  while true:
    if p.match(tkAssign, tkPlusEq, tkMinusEq, tkMulEq, tkDivEq):
      let operator = p.previous()
      let nextToken = p.peek()
      
      let value = if p.check(tkLambda): p.lambdaDeclaration()
      elif p.check(tkIf):               p.ifStatement()
      else:                             p.assignment()

      if expr.kind == nkIdent:
        let assign = newNode(nkAssign)
        assign.declType = declType

        assign.assignOp = case operator.kind
          of tkAssign:  "="
          of tkPlusEq:  "+="
          of tkMinusEq: "-="
          of tkMulEq:   "*="
          of tkDivEq:   "/="
          else:         ""
        
        assign.assignTarget   = expr
        assign.assignVal      = value
        assign.line           = operator.line
        assign.column         = operator.column

        # Генерируем RBT для присваивания
        assign.rbtNode = p.rbtBuilder.generateAssign(
          "dtNone", assign.assignOp, nodeToRBT(expr), nodeToRBT(value), "", ""
        )

        expr = assign
      else:
        p.errors.add(fmt"Invalid assignment target at line {operator.line}, column {operator.column}")
    else:
      break
  
  return expr

proc expression(p: Parser): Node =
  return p.assignment()

proc parameter(p: Parser): Node =
  let token = p.consume(tkIdentifier, "Expected parameter name")
  let name = token.lexeme
  
  # Тип параметра (опционально)
  var paramType = ""
  var typeModifier = '\0'

  if p.match(tkColon):
    if p.match(tkBang):
      typeModifier = '!'
    elif p.match(tkQuestion):
      typeModifier = '?'

    # Собираем полный тип с поддержкой составных типов
    let baseType = p.consume(tkIdentifier, "Expected parameter type after ':'").lexeme
    paramType = p.parseGenericType(baseType)  # Поддержка дженериков
    
    # Проверяем ptr/ref типы
    if paramType in ["ptr", "ref"] and p.check(tkIdentifier):
      paramType &= " " & p.advance().lexeme
    
    # Проверяем generic типы
    if p.match(tkLBracket):
      paramType &= "["
      var bracketDepth = 1
      
      while bracketDepth > 0 and not p.isAtEnd():
        if p.match(tkLBracket):
          bracketDepth += 1
          paramType &= "["
        elif p.match(tkRBracket):
          bracketDepth -= 1
          paramType &= "]"
        elif p.match(tkDotDot):
          paramType &= ".."
        elif p.check(tkNumber) or p.check(tkIdentifier):
          paramType &= p.advance().lexeme
        else:
          # Другие токены
          paramType &= p.advance().lexeme
  
  # Дефолтное значение (опционально)
  var defaultValue: Node = nil
  if p.match(tkAssign):
    defaultValue = p.expression()

  result = newNode(nkParam)
  result.paramName = name
  result.paramType = paramType
  result.paramTypeModifier = typeModifier
  result.paramDefault = defaultValue 
  result.line = token.line
  result.column = token.column
  
  # Генерируем RBT для параметра
  result.rbtNode = p.rbtBuilder.generateParam(
    name, paramType, $typeModifier, nodeToRBT(defaultValue)
  )
  
  return result

proc parseTablePair(p: Parser): Node =
  # Пропускаем переносы строк
  while p.match(tkNewline): discard
  
  # Парсим ключ (может быть идентификатором или строкой)
  var key: Node
  if p.check(tkIdentifier):
    let token = p.advance()
    key = newNode(nkIdent)
    key.ident = token.lexeme
    key.line = token.line
    key.column = token.column
    key.rbtNode = p.rbtBuilder.generateIdent(token.lexeme)
  elif p.check(tkString):
    let token = p.advance()
    key = newNode(nkString)
    key.strVal = token.lexeme
    key.line = token.line
    key.column = token.column
    key.rbtNode = p.rbtBuilder.generateString(token.lexeme)
  else:
    p.errors.add("Expected identifier or string as table key")
    return nil
  
  # Пропускаем переносы строк перед двоеточием
  while p.match(tkNewline): discard
  
  # Ожидаем двоеточие
  discard p.consume(tkColon, "Expected ':' after table key")
  
  # Пропускаем переносы строк после двоеточия
  while p.match(tkNewline): discard
  
  # Парсим значение
  let value = p.expression()
  
  # Создаем узел пары
  result = newNode(nkTablePair)
  result.pairKey = key
  result.pairValue = value
  result.line = key.line
  result.column = key.column
  result.rbtNode = p.rbtBuilder.generateTablePair(nodeToRBT(key), nodeToRBT(value))

proc parseTable(p: Parser): Node =
  result = newNode(nkTable)
  result.tablePairs = @[]
  
  # Пропускаем переносы строк после открывающей скобки
  while p.match(tkNewline): discard
  
  # Проверяем пустую таблицу
  if p.check(tkRBrace):
    discard p.consume(tkRBrace, "Expected '}' after empty table")
    result.rbtNode = p.rbtBuilder.generateTable(@[])
    return result
  
  # Парсим первую пару ключ-значение
  let firstPair = p.parseTablePair()
  if firstPair != nil:
    result.tablePairs.add(firstPair)
  
  # Парсим остальные пары через запятую
  while p.match(tkComma):
    # Пропускаем переносы строк после запятой
    while p.match(tkNewline): discard
    
    # Проверяем завершение таблицы
    if p.check(tkRBrace):
      break
    
    let pair = p.parseTablePair()
    if pair != nil:
      result.tablePairs.add(pair)
  
  # Пропускаем переносы строк перед закрывающей скобкой
  while p.match(tkNewline): discard
  
  discard p.consume(tkRBrace, "Expected '}' after table")
  
  # Генерируем RBT для таблицы
  var rbtPairs: seq[JsonNode] = @[]
  for pair in result.tablePairs:
    rbtPairs.add(nodeToRBT(pair))
  result.rbtNode = p.rbtBuilder.generateTable(rbtPairs)
  
  return result

proc importStatement(p: Parser): Node =
  result = newNode(nkImport)
  result.imports = @[]
  
  discard p.consume(tkModule, "Expected 'module import' keyword")
  discard p.consume(tkLBrace, "Expected '{' after import")
  
  while not p.check(tkRBrace) and not p.isAtEnd():
    var spec = ImportSpec(
      path: @[],
      filter: @[],
      alias: "",
      isAll: false,
      items: @[]
    )
    
    # Проверяем что это не новая строка
    if not p.check(tkNewline):
      spec.path.add(p.consume(tkIdentifier, "Expected module name").lexeme)
      while p.match(tkDot):
        spec.path.add(p.consume(tkIdentifier, "Expected identifier after '.'").lexeme)
    
      if p.match(tkLBracket):
        if p.match(tkMul):
          spec.isAll = true
        else:
          while not p.check(tkRBracket):
            let item = p.consume(tkIdentifier, "Expected import filter").lexeme
            spec.filter.add(item)
            spec.items.add(item)
            if not p.match(tkComma): break
        discard p.consume(tkRBracket, "Expected ']' after import filter")
      elif p.match(tkColon):
        spec.alias = p.consume(tkIdentifier, "Expected alias name").lexeme
    
      result.imports.add(spec)
      
    while p.match(tkNewline): discard
    
  discard p.consume(tkRBrace, "Expected '}' after imports")
  
  # Генерируем RBT для импорта
  #result.rbtNode = p.rbtBuilder.generateImport(result.imports)

proc parseInitBlock(p: Parser): Node =
  discard p.consume(tkInit, "Expected 'init' keyword")

  var params: seq[Node] = @[]
  if p.match(tkLParen):
    # Пропускаем возможные переносы строк перед первым параметром
    while p.match(tkNewline): discard
    
    if not p.check(tkRParen):
      # Первый параметр
      params.add(p.parameter())
      
      # Остальные параметры
      while p.match(tkComma):
        # Пропускаем возможные переносы строк после запятой
        while p.match(tkNewline): discard
        
        if not p.check(tkRParen):  # Проверяем, что не достигли конца списка
          params.add(p.parameter())
    
    # Пропускаем возможные переносы строк перед закрывающей скобкой
    while p.match(tkNewline): discard
    
    discard p.consume(tkRParen, "Expected ')' after parameters")

  result = newNode(nkInit)
  result.initParams = params
  result.initBody = p.parseBlock()
  result.line = p.previous().line
  result.column = p.previous().column
  
  # Генерируем RBT для init блока
  var rbtParams: seq[JsonNode] = @[]
  for param in params:
    rbtParams.add(nodeToRBT(param))
  result.rbtNode = p.rbtBuilder.generateInit(rbtParams, nodeToRBT(result.initBody))

proc parseStateBody(p: Parser): Node =
  result = newNode(nkStateBody)
  result.stateMethods = @[]
  result.stateVars = @[]
  result.stateWatchers = @[]
  
  discard p.consume(tkLBrace, "Expected '{' after state name")
  
  while not p.check(tkRBrace) and not p.isAtEnd():
    if p.check(tkFunc):
      result.stateMethods.add(p.functionDeclaration())
    elif p.check(tkVal) or p.check(tkDef):
      result.stateVars.add(p.assignment())
      
  discard p.consume(tkRBrace, "Expected '}' after state body")
  
  # Генерируем RBT для state body
  var rbtMethods: seq[JsonNode] = @[]
  var rbtVars: seq[JsonNode] = @[]
  var rbtWatchers: seq[JsonNode] = @[]
  
  for meth in result.stateMethods:
    rbtMethods.add(nodeToRBT(meth))
  for variable in result.stateVars:
    rbtVars.add(nodeToRBT(variable))
  for watcher in result.stateWatchers:
    rbtWatchers.add(nodeToRBT(watcher))
  
  result.rbtNode = p.rbtBuilder.generateStateBody(rbtMethods, rbtVars, rbtWatchers)

proc parseState(p: Parser): Node =
  discard p.consume(tkState, "Expected 'state' keyword")
  let name = p.consume(tkIdentifier, "Expected state name").lexeme
  
  result = newNode(nkState)
  result.stateName = name
  result.stateBody = p.parseBlock()
  
  # Генерируем RBT для state
  result.rbtNode = p.rbtBuilder.generateState(name, nodeToRBT(result.stateBody))
  
  return result

proc forStatement(p: Parser): Node =
  let token = p.consume(tkFor, "Expected 'for' keyword")
  
  # Переменная цикла
  let varName = p.consume(tkIdentifier, "Expected variable name after 'for'").lexeme
  
  # Ключевое слово 'in'
  discard p.consume(tkIn, "Expected 'in' after variable name")
  
  # Начальное выражение диапазона
  let rangeStart = p.expression()
  
  # Проверяем тип диапазона
  var inclusive = true
  var rangeEnd: Node

  if p.match(tkDotDot):       
    inclusive = true
    rangeEnd = p.expression()
  elif p.match(tkDotDotDot):  
    inclusive = false
    rangeEnd = p.expression()
  else:
    # Если нет диапазона, то это итерация по коллекции
    result = newNode(nkFor)
    result.forVar = varName
    result.forRange = (
      start: rangeStart,
      inclusive: true,
      endExpr: nil
    )
    result.forBody = p.parseBlock()
    result.line = token.line
    result.column = token.column
    
    # Генерируем RBT для for цикла
    result.rbtNode = p.rbtBuilder.generateFor(
      varName, nodeToRBT(rangeStart), true, newJNull(), nodeToRBT(result.forBody)
    )
    return result
  
  # Блок кода
  let body = p.parseBlock()
  
  result = newNode(nkFor)
  result.forVar = varName
  result.forRange = (
    start: rangeStart,
    inclusive: inclusive,
    endExpr: rangeEnd
  )
  result.forBody = body
  result.line = token.line
  result.column = token.column
  
  # Генерируем RBT для for цикла
  result.rbtNode = p.rbtBuilder.generateFor(
    varName, nodeToRBT(rangeStart), inclusive, nodeToRBT(rangeEnd), nodeToRBT(body)
  )
  
  return result

proc eachStatement(p: Parser): Node =
  let token = p.consume(tkEach, "Expected 'each' keyword")
  
  # Переменная цикла
  let varName = p.consume(tkIdentifier, "Expected variable name after 'each'").lexeme
  
  # from
  discard p.consume(tkFrom, "Expected 'from' after variable")
  let startExpr = p.expression()
  
  # to
  discard p.consume(tkTo, "Expected 'to' after start expression")
  let endExpr = p.expression()
  
  # Опциональный step
  var stepExpr: Node = nil
  if p.match(tkStep):
    stepExpr = p.expression()
    
  # Опциональное условие where
  var whereExpr: Node = nil
  if p.match(tkWhere):
    whereExpr = p.expression()
    
  # Блок кода
  let body = p.parseBlock()
  
  # Создаем узел Each
  result = newNode(nkEach)
  result.eachVar = varName
  result.eachStart = startExpr
  result.eachEnd = endExpr
  result.eachStep = stepExpr
  result.eachWhere = whereExpr
  result.eachBody = body
  result.line = token.line
  result.column = token.column
  
  # Генерируем RBT для each цикла
  result.rbtNode = p.rbtBuilder.generateEach(
    varName, nodeToRBT(startExpr), nodeToRBT(endExpr), 
    nodeToRBT(stepExpr), nodeToRBT(whereExpr), nodeToRBT(body)
  )

proc whileStatement(p: Parser): Node =
  let token = p.consume(tkWhile, "Expected 'while' keyword")
  let condition = p.expression()
  let body = p.parseBlock()
  
  result = newNode(nkWhile)
  result.whileCond = condition
  result.whileBody = body
  result.line = token.line
  result.column = token.column
  
  # Генерируем RBT для while цикла
  result.rbtNode = p.rbtBuilder.generateWhile(nodeToRBT(condition), nodeToRBT(body))

proc infinitStatement(p: Parser): Node =
  let token = p.consume(tkInfinit, "Expected 'infinit' keyword")
  
  # Выражение задержки
  let delay = p.expression()
  
  # Блок кода
  let body = p.parseBlock()
  
  result = newNode(nkInfinit)
  result.infDelay = delay
  result.infBody = body
  result.line = token.line
  result.column = token.column
  
  # Генерируем RBT для infinit цикла
  result.rbtNode = p.rbtBuilder.generateInfinit(nodeToRBT(delay), nodeToRBT(body))
  
  return result

proc repeatStatement(p: Parser): Node =
  let token = p.consume(tkRepeat, "Expected 'repeat' keyword")
  
  # Количество повторений
  let count = p.expression()
  
  # Задержка
  let delay = p.expression()
  
  # Блок кода
  let body = p.parseBlock()
  
  result = newNode(nkRepeat)
  result.repCount = count
  result.repDelay = delay
  result.repBody = body
  result.line = token.line
  result.column = token.column
  
  # Генерируем RBT для repeat цикла
  result.rbtNode = p.rbtBuilder.generateRepeat(
    nodeToRBT(count), nodeToRBT(delay), nodeToRBT(body)
  )
  
  return result

proc eventStatement(p: Parser): Node =
  let token = p.consume(tkEvent, "Expected 'event' keyword")
  
  # Условие события
  let condition = p.expression()
  
  # Блок кода
  let body = p.parseBlock()
  
  result = newNode(nkEvent)
  result.evCond = condition
  result.evBody = body
  result.line = token.line
  result.column = token.column
  
  # Генерируем RBT для event
  result.rbtNode = p.rbtBuilder.generateEvent(nodeToRBT(condition), nodeToRBT(body))
  
  return result

proc returnStatement(p: Parser): Node =
  let token = p.consume(tkReturn, "Expected 'return' keyword")
  
  var value: Node = nil
  # Проверяем, есть ли выражение после return
  if not p.check(tkSemicolon) and not p.check(tkRBrace):
    value = p.expression()
  
  # Опционально: проверка на точку с запятой
  discard p.match(tkSemicolon)
  
  result = newNode(nkReturn)
  result.retVal = value
  result.line = token.line
  result.column = token.column
  
  # Генерируем RBT для return
  result.rbtNode = p.rbtBuilder.generateReturn(nodeToRBT(value))
  
  return result

proc ifStatement(p: Parser): Node =
  let token = p.consume(tkIf, "Expected 'if' keyword")
  let condition = p.expression()
  let thenBranch = p.parseBlock()
  
  var elifBranches: seq[tuple[cond: Node, body: Node]] = @[]
  var elseBranch: Node = nil

  while p.check(tkNewline): discard p.advance()

  while p.check(tkElif):
    discard p.consume(tkElif, "Expected 'elif'")
    let elifCond = p.expression()
    let elifBody = p.parseBlock()
    elifBranches.add((cond: elifCond, body: elifBody))

  while p.check(tkNewline): discard p.advance()

  if p.check(tkElse):
    discard p.consume(tkElse, "Expected 'else'")
    elseBranch = p.parseBlock()

  result = newNode(nkIf)
  result.ifCond = condition
  result.ifThen = thenBranch
  result.ifElifs = elifBranches
  result.ifElse = elseBranch
  result.line = token.line
  result.column = token.column
  
  # Генерируем RBT для if statement
  var rbtElifs: seq[JsonNode] = @[]
  for elifBranch in elifBranches:
    rbtElifs.add(p.rbtBuilder.generateElifBranch(nodeToRBT(elifBranch.cond), nodeToRBT(elifBranch.body)))
  
  result.rbtNode = p.rbtBuilder.generateIf(
    nodeToRBT(condition), nodeToRBT(thenBranch), rbtElifs, nodeToRBT(elseBranch)
  )
  
  return result

proc parseSwitchCase(p: Parser): Node =
  var conditions: seq[Node] = @[]
  var guard: Node = nil
  
  # Парсим число
  let start = p.primary()
  
  # Проверяем диапазон
  if p.match(tkDotDot, tkDotDotDot):
    let op = p.previous()
    let endExpr = p.primary()
    
    let range = newNode(nkBinary)
    range.binOp = if op.kind == tkDotDot: ".." else: "..."
    range.binLeft = start
    range.binRight = endExpr
    range.rbtNode = p.rbtBuilder.generateBinary(range.binOp, nodeToRBT(start), nodeToRBT(endExpr))
    conditions.add(range)
  else:
    conditions.add(start)
  
  # Парсим дополнительные условия через 'and' или 'or'
  while p.match(tkAnd, tkOr):
    let op = p.previous()
    let right = p.expression()
    
    # Создаем бинарное выражение для логических операторов
    let binary = newNode(nkBinary)
    binary.binOp = if op.kind == tkAnd: "and" else: "or"
    binary.binLeft = conditions[conditions.len - 1]
    binary.binRight = right
    binary.rbtNode = p.rbtBuilder.generateBinary(binary.binOp, nodeToRBT(binary.binLeft), nodeToRBT(right))
    
    conditions[conditions.len - 1] = binary
  
  # Проверяем guard условие (if)
  if p.match(tkIf):
    guard = p.expression()
  
  # Ожидаем => или {
  let body = p.parseBlock()

  result = newNode(nkSwitchCase)
  result.caseConditions = conditions
  result.caseBody = body
  result.caseGuard = guard
  
  # Генерируем RBT для switch case
  var rbtConditions: seq[JsonNode] = @[]
  for condition in conditions:
    rbtConditions.add(nodeToRBT(condition))
  
  result.rbtNode = p.rbtBuilder.generateSwitchCase(
    rbtConditions, nodeToRBT(body), nodeToRBT(guard)
  )

proc switchStatement(p: Parser): Node =
  let token = p.consume(tkSwitch, "Expected 'switch' keyword")
  let expr = p.expression()
  
  discard p.consume(tkLBrace, "Expected '{' after switch expression")
  
  var cases: seq[Node] = @[]
  var defaultCase: Node = nil
  
  while not p.check(tkRBrace) and not p.isAtEnd():
    # Пропускаем переносы строк
    while p.match(tkNewline): discard
    
    if p.match(tkCase):
      let caseNode = p.parseSwitchCase()
      if caseNode != nil:
        cases.add(caseNode)
    elif p.match(tkElse):
      defaultCase = p.parseBlock()
    else:
      break
  
  discard p.consume(tkRBrace, "Expected '}' after switch body")
  
  result = newNode(nkSwitch)
  result.switchExpr = expr
  result.switchCases = cases
  result.switchDefault = defaultCase
  result.line = token.line
  result.column = token.column
  
  # Генерируем RBT для switch statement
  var rbtCases: seq[JsonNode] = @[]
  for Сase in cases:
    rbtCases.add(nodeToRBT(Сase))
  
  result.rbtNode = p.rbtBuilder.generateSwitch(
    nodeToRBT(expr), rbtCases, nodeToRBT(defaultCase)
  )

proc tryStatement(p: Parser): Node =
  let token = p.consume(tkTry, "Expected 'try' keyword")
  
  # Блок try
  let tryBody = p.parseBlock()
  
  discard p.consume(tkError, "Expected 'error' after try block")
  
  # Опционально: тип ошибки
  var errorType = ""
  if p.check(tkIdentifier):
    errorType = p.advance().lexeme
  
  # Блок catch
  let catchBody = p.parseBlock()
  
  result = newNode(nkTry)
  result.tryBody = tryBody
  result.tryErrType = errorType
  result.tryCatch = catchBody
  result.line = token.line
  result.column = token.column
  
  # Генерируем RBT для try statement
  result.rbtNode = p.rbtBuilder.generateTry(
    nodeToRBT(tryBody), errorType, nodeToRBT(catchBody)
  )
  
  return result

proc lambdaDeclaration(p: Parser): Node =
  let token = p.consume(tkLambda, "Expected 'lambda' keyword")

  # Дженерик параметры [T, U: SomeType]
  let genericParams = p.parseGenericParams()

  # Параметры
  var params: seq[Node] = @[]
  if p.match(tkLParen):
    # Пропускаем возможные переносы строк перед первым параметром
    while p.match(tkNewline): discard
    
    if not p.check(tkRParen):
      # Первый параметр
      params.add(p.parameter())
      
      # Остальные параметры
      while p.match(tkComma):
        # Пропускаем возможные переносы строк после запятой
        while p.match(tkNewline): discard
        
        if not p.check(tkRParen):  # Проверяем, что не достигли конца списка
          params.add(p.parameter())
    
    # Пропускаем возможные переносы строк перед закрывающей скобкой
    while p.match(tkNewline): discard
    
    discard p.consume(tkRParen, "Expected ')' after parameters")

  # Тип возвращаемого значения
  var returnType = ""
  var returnTypeModifier = '\0'
  if p.match(tkColon):
    # Проверяем модификатор типа
    if p.match(tkBang):
      returnTypeModifier = '!'
    elif p.match(tkQuestion):
      returnTypeModifier = '?'
    
    returnType = p.consume(tkIdentifier, "Expected return type after ':'").lexeme

  # Модификаторы
  var modifiers: seq[string] = @[]
  if p.match(tkModStart):
    # Пропускаем возможные переносы строк
    while p.match(tkNewline): discard
    
    if p.check(tkIdentifier):
      modifiers.add(p.advance().lexeme)
      
      while p.match(tkComma):
        # Пропускаем возможные переносы строк
        while p.match(tkNewline): discard
        
        if p.check(tkIdentifier):
          modifiers.add(p.advance().lexeme)
    
    # Пропускаем возможные переносы строк
    while p.match(tkNewline): discard
    
    discard p.consume(tkModEnd, "Expected ')' after modifiers")

  # Тело функции
  let body = p.parseBlock()
  
  result = newNode(nkLambdaDef)
  result.lambdaParams = params
  result.lambdaGenericParams = genericParams
  result.lambdaRetType = returnType
  result.lambdaRetTypeModifier = returnTypeModifier 
  result.lambdaMods = modifiers
  result.lambdaBody = body
  result.line = token.line
  result.column = token.column
  
  # Генерируем RBT для lambda
  var rbtParams: seq[JsonNode] = @[]
  var rbtGenericParams: seq[JsonNode] = @[]
  
  for param in params:
    rbtParams.add(nodeToRBT(param))
  for genericParam in genericParams:
    rbtGenericParams.add(nodeToRBT(genericParam))
  
  result.rbtNode = p.rbtBuilder.generateLambda(
    rbtGenericParams, rbtParams, returnType, $returnTypeModifier, 
    modifiers, nodeToRBT(body)
  )
  
  return result

proc functionDeclaration(p: Parser): Node =
  let token = p.consume(tkFunc, "Expected 'func' keyword")

  # Имя функции
  let name = p.consume(tkIdentifier, "Expected function name after 'func'").lexeme

  # публичная или приватная
  var public = true

  # Дженерик параметры [T, U: SomeType]
  let genericParams = p.parseGenericParams()

  # Параметры
  var params: seq[Node] = @[]
  if p.match(tkLParen):
    # Пропускаем возможные переносы строк перед первым параметром
    while p.match(tkNewline): discard
    
    if not p.check(tkRParen):
      # Первый параметр
      params.add(p.parameter())
      
      # Остальные параметры
      while p.match(tkComma):
        # Пропускаем возможные переносы строк после запятой
        while p.match(tkNewline): discard
        
        if not p.check(tkRParen):  # Проверяем, что не достигли конца списка
          params.add(p.parameter())
    
    # Пропускаем возможные переносы строк перед закрывающей скобкой
    while p.match(tkNewline): discard
    
    discard p.consume(tkRParen, "Expected ')' after parameters")

  # Тип возвращаемого значения
  var returnType = ""
  var returnTypeModifier = '\0'
  if p.match(tkColon):
    # Проверяем модификатор типа
    if p.match(tkBang):
      returnTypeModifier = '!'
    elif p.match(tkQuestion):
      returnTypeModifier = '?'
    
    let baseReturnType = p.consume(tkIdentifier, "Expected return type after ':'").lexeme
    returnType = p.parseGenericType(baseReturnType)

  # Модификаторы
  var modifiers: seq[string] = @[]
  if p.match(tkModStart):
    # Пропускаем возможные переносы строк
    while p.match(tkNewline): discard
    
    if p.check(tkIdentifier):
      modifiers.add(p.advance().lexeme)
      
      while p.match(tkComma):
        # Пропускаем возможные переносы строк
        while p.match(tkNewline): discard
        
        if p.check(tkIdentifier):
          modifiers.add(p.advance().lexeme)
    
    # Пропускаем возможные переносы строк
    while p.match(tkNewline): discard
    
    discard p.consume(tkModEnd, "Expected ')' after modifiers")

  # Тело функции
  let body = p.parseBlock()
  
  result = newNode(nkFuncDef)
  result.funcName = name
  result.funcGenericParams = genericParams
  result.funcParams = params
  result.funcRetType = returnType
  result.funcRetTypeModifier = returnTypeModifier 
  result.funcMods = modifiers
  result.funcBody = body
  result.funcPublic = public
  result.line = token.line
  result.column = token.column
  
  # Генерируем RBT для функции
  var rbtParams: seq[JsonNode] = @[]
  var rbtGenericParams: seq[JsonNode] = @[]
  
  for param in params:
    rbtParams.add(nodeToRBT(param))
  for genericParam in genericParams:
    rbtGenericParams.add(nodeToRBT(genericParam))
  
  result.rbtNode = p.rbtBuilder.generateFunction(
    name, rbtGenericParams, rbtParams, returnType, $returnTypeModifier,
    modifiers, nodeToRBT(body), public
  )
  
  return result

proc methodDeclaration(p: Parser): Node =
  let token = p.consume(tkFunc, "Expected 'func' keyword")

  # Имя функции
  let name = p.consume(tkIdentifier, "Expected function name after 'func'").lexeme

  # Параметры
  var params: seq[Node] = @[]
  if p.match(tkLParen):
    # Пропускаем возможные переносы строк перед первым параметром
    while p.match(tkNewline): discard
    
    if not p.check(tkRParen):
      # Первый параметр
      params.add(p.parameter())
      
      # Остальные параметры
      while p.match(tkComma):
        # Пропускаем возможные переносы строк после запятой
        while p.match(tkNewline): discard
        
        if not p.check(tkRParen):  # Проверяем, что не достигли конца списка
          params.add(p.parameter())
    
    # Пропускаем возможные переносы строк перед закрывающей скобкой
    while p.match(tkNewline): discard
    
    discard p.consume(tkRParen, "Expected ')' after parameters")

  # Тип возвращаемого значения
  var returnType = ""
  var returnTypeModifier = '\0'
  if p.match(tkColon):
    # Проверяем модификатор типа
    if p.match(tkBang):
      returnTypeModifier = '!'
    elif p.match(tkQuestion):
      returnTypeModifier = '?'
    
    returnType = p.consume(tkIdentifier, "Expected return type after ':'").lexeme

  # Модификаторы
  var modifiers: seq[string] = @[]
  if p.match(tkModStart):
    # Пропускаем возможные переносы строк
    while p.match(tkNewline): discard
    
    if p.check(tkIdentifier):
      modifiers.add(p.advance().lexeme)
      
      while p.match(tkComma):
        # Пропускаем возможные переносы строк
        while p.match(tkNewline): discard
        
        if p.check(tkIdentifier):
          modifiers.add(p.advance().lexeme)
    
    # Пропускаем возможные переносы строк
    while p.match(tkNewline): discard
    
    discard p.consume(tkModEnd, "Expected ')' after modifiers")

  # Тело функции
  let body = p.parseBlock()
  
  result = newNode(nkFuncDef)
  result.funcName = name
  result.funcParams = params
  result.funcRetType = returnType
  result.funcRetTypeModifier = returnTypeModifier 
  result.funcMods = modifiers
  result.funcBody = body
  result.line = token.line
  result.column = token.column
  
  # Генерируем RBT для метода
  var rbtParams: seq[JsonNode] = @[]
  for param in params:
    rbtParams.add(nodeToRBT(param))
  
  result.rbtNode = p.rbtBuilder.generateMethod(
    name, rbtParams, returnType, $returnTypeModifier, modifiers, nodeToRBT(body)
  )
  
  return result

proc packDeclaration(p: Parser): Node =
  let token = p.consume(tkPack, "Expected 'pack' keyword")
  
  # Имя пакета
  let name = p.consume(tkIdentifier, "Expected pack name after 'pack'").lexeme

  # Дженерик параметры [T, U: SomeType]
  let genericParams = p.parseGenericParams()

  # Модификаторы (опционально)
  var modifiers: seq[string] = @[]
  if p.match(tkModStart):
    modifiers.add(p.consume(tkIdentifier, "Expected modifier").lexeme)
    while p.match(tkComma):
      modifiers.add(p.consume(tkIdentifier, "Expected modifier").lexeme)
    discard p.consume(tkModEnd, "Expected ')'")

  # Родительские классы (опционально)
  var parents: seq[string] = @[]
  if p.match(tkLeftArrow):
    # Первый родитель
    parents.add(p.consume(tkIdentifier, "Expected parent class name after '<-'").lexeme)
    
    # Остальные родители
    while p.match(tkPipe):
      parents.add(p.consume(tkIdentifier, "Expected parent class name after '|'").lexeme)
  
  # Тело пакета
  let body = p.parsePackBody()
  
  result = newNode(nkPackDef)
  result.packName = name
  result.packGenericParams = genericParams
  result.packParents = parents
  result.packMods = modifiers
  result.packBody = body
  result.line = token.line
  result.column = token.column
  
  # Генерируем RBT для pack
  var rbtGenericParams: seq[JsonNode] = @[]
  for genericParam in genericParams:
    rbtGenericParams.add(nodeToRBT(genericParam))
  
  result.rbtNode = p.rbtBuilder.generatePack(
    name, rbtGenericParams, parents, modifiers, nodeToRBT(body)
  )
  
  return result

proc fieldDeclaration(p: Parser): Node =
  let nameToken = p.consume(tkIdentifier, "Expected field name")
  let name = nameToken.lexeme
  
  discard p.consume(tkColon, "Expected ':' after field name")
  
  let fieldType = p.consume(tkIdentifier, "Expected field type").lexeme
  
  var defaultValue: Node = nil
  if p.match(tkAssign):
    defaultValue = p.expression()
  
  # Опциональная запятая (как в parseBlock логике)
  discard p.match(tkComma)
  
  result = newNode(nkFieldDef)
  result.fieldName = name
  result.fieldType = fieldType
  result.fieldDefault = defaultValue
  result.line = nameToken.line
  result.column = nameToken.column
  
  # Генерируем RBT для field
  result.rbtNode = p.rbtBuilder.generateField(
    name, fieldType, nodeToRBT(defaultValue)
  )

proc structDeclaration(p: Parser): Node =
  let token = p.consume(tkStruct, "Expected 'struct' keyword")
  let name = p.consume(tkIdentifier, "Expected struct name").lexeme
  
  discard p.consume(tkLBrace, "Expected '{' after struct name")
  
  var fields: seq[Node] = @[]
  var methods: seq[Node] = @[]
  
  # Используем ту же логику что и в parseBlock
  while not p.check(tkRBrace) and not p.isAtEnd():
    # Пропускаем переносы строк
    while p.match(tkNewline): discard
    
    # Проверяем что не достигли конца блока
    if p.check(tkRBrace):
      break
    
    # Парсим содержимое структуры
    if p.check(tkFunc):
      let meth = p.functionDeclaration()
      if meth != nil:
        methods.add(meth)
    else:
      let field = p.fieldDeclaration()
      if field != nil:
        fields.add(field)
    
    # Пропускаем переносы строк после элемента
    while p.match(tkNewline): discard
  
  discard p.consume(tkRBrace, "Expected '}' after struct body")
  
  result = newNode(nkStructDef)
  result.structName = name
  result.structFields = fields
  result.structMethods = methods
  result.line = token.line
  result.column = token.column
  
  # Генерируем RBT для struct
  var rbtFields: seq[JsonNode] = @[]
  var rbtMethods: seq[JsonNode] = @[]
  
  for field in fields:
    rbtFields.add(nodeToRBT(field))
  for meth in methods:
    rbtMethods.add(nodeToRBT(meth))
  
  result.rbtNode = p.rbtBuilder.generateStruct(name, rbtFields, rbtMethods)

proc enumVariant(p: Parser): Node =
  let nameToken = p.consume(tkIdentifier, "Expected variant name")
  let name = nameToken.lexeme
  
  var value: Node = nil
  if p.match(tkAssign):
    value = p.expression()
  
  # Опциональная запятая (как в parseBlock логике)
  discard p.match(tkComma)
  
  result = newNode(nkEnumVariant)
  result.variantName = name
  result.variantValue = value
  result.line = nameToken.line
  result.column = nameToken.column
  
  # Генерируем RBT для enum variant
  result.rbtNode = p.rbtBuilder.generateEnumVariant(name, nodeToRBT(value))

proc enumDeclaration(p: Parser): Node =
  let token = p.consume(tkEnum, "Expected 'enum' keyword")
  let name = p.consume(tkIdentifier, "Expected enum name").lexeme
  
  discard p.consume(tkLBrace, "Expected '{' after enum name")
  
  var variants: seq[Node] = @[]
  var methods: seq[Node] = @[]
  
  # Используем ту же логику что и в parseBlock
  while not p.check(tkRBrace) and not p.isAtEnd():
    # Пропускаем переносы строк
    while p.match(tkNewline): discard
    
    # Проверяем что не достигли конца блока
    if p.check(tkRBrace):
      break
    
    # Парсим содержимое перечисления
    if p.check(tkFunc):
      let meth = p.functionDeclaration()
      if meth != nil:
        methods.add(meth)
    else:
      let variant = p.enumVariant()
      if variant != nil:
        variants.add(variant)
    
    # Пропускаем переносы строк после элемента
    while p.match(tkNewline): discard
  
  discard p.consume(tkRBrace, "Expected '}' after enum body")
  
  result = newNode(nkEnumDef)
  result.enumName = name
  result.enumVariants = variants
  result.enumMethods = methods
  result.line = token.line
  result.column = token.column
  
  # Генерируем RBT для enum
  var rbtVariants: seq[JsonNode] = @[]
  var rbtMethods: seq[JsonNode] = @[]
  
  for variant in variants:
    rbtVariants.add(nodeToRBT(variant))
  for meth in methods:
    rbtMethods.add(nodeToRBT(meth))
  
  result.rbtNode = p.rbtBuilder.generateEnum(name, rbtVariants, rbtMethods)

# Парсинг операторов
proc expressionStatement(p: Parser): Node =
  let expr = p.expression()

  if expr == nil:
    return nil

  result = newNode(nkExprStmt)
  result.expr = expr
  if expr != nil:
    result.line = expr.line
    result.column = expr.column
  
  # Генерируем RBT для expression statement
  result.rbtNode = p.rbtBuilder.generateExprStmt(nodeToRBT(expr))
  
  return result

proc parsePackBody(p: Parser): Node =
  var statements: seq[Node] = @[]
  
  if p.match(tkFatArrow):  # => для однострочного блока
    let stmt = p.statement()
    if stmt != nil:
      statements.add(stmt)
  else:
    discard p.consume(tkLBrace, "Expected '{' before block")
    while not p.check(tkRBrace) and not p.isAtEnd():
      if p.check(tkFunc):
        let methodDef = p.methodDeclaration()
        statements.add(methodDef)
      elif p.check(tkInit):
        let initDef = p.parseInitBlock()
        statements.add(initDef)
      elif p.check(tkDef) or p.check(tkVal):
        let varDef = p.assignment()
        statements.add(varDef)
      elif p.check(tkState):
        let stateDef = p.parseState()
        statements.add(stateDef)
      else:
        let stmt = p.statement()
        if stmt != nil:
          statements.add(stmt)
    discard p.consume(tkRBrace, "Expected '}' after block")

  result = newNode(nkBlock)
  result.blockStmts = statements
  
  # Генерируем RBT для pack body
  var rbtStmts: seq[JsonNode] = @[]
  for stmt in statements:
    rbtStmts.add(nodeToRBT(stmt))
  result.rbtNode = p.rbtBuilder.generateBlock(rbtStmts)

proc parseBlock(p: Parser): Node =
  result = newNode(nkBlock)
  result.blockStmts = @[]

  if p.match(tkFatArrow):  # => для однострочного блока
    if p.match(tkNewline): discard # пропускаяем одну новую строку если она есть
    let stmt = p.statement()
    if stmt != nil:
      result.blockStmts.add(stmt)
    
    # Генерируем RBT для однострочного блока
    var rbtStmts: seq[JsonNode] = @[]
    for stmt in result.blockStmts:
      rbtStmts.add(nodeToRBT(stmt))
    result.rbtNode = p.rbtBuilder.generateBlock(rbtStmts)
    
    return result

  # Обычный блок с {}
  discard p.consume(tkLBrace, "Expected '{' before block")
  while not p.check(tkRBrace) and not p.isAtEnd():
    let stmt = p.statement()
    if stmt != nil:
      result.blockStmts.add(stmt)
  discard p.consume(tkRBrace, "Expected '}' after block")
  
  # Генерируем RBT для блока
  var rbtStmts: seq[JsonNode] = @[]
  for stmt in result.blockStmts:
    rbtStmts.add(nodeToRBT(stmt))
  result.rbtNode = p.rbtBuilder.generateBlock(rbtStmts)
  
  return result

proc statement(p: Parser): Node =
  # Обработка объявлений функций
  if p.check(tkFunc):
    return p.functionDeclaration()

  if p.check(tkLambda):
    return p.lambdaDeclaration()
  
  # Обработка объявлений пакетов (классов)
  if p.check(tkPack):
    return p.packDeclaration()

  # Обработка структур данных
  if p.check(tkStruct):
    return p.structDeclaration()
  
  if p.check(tkEnum):
    return p.enumDeclaration()

  # Обработка условных операторов
  if p.check(tkIf):
    return p.ifStatement()

  if p.check(tkSwitch):
    return p.switchStatement()

  # Обработка циклов
  if p.check(tkFor):
    return p.forStatement()

  if p.check(tkEach):
    return p.eachStatement()

  if p.check(tkInfinit):
    return p.infinitStatement()

  if p.check(tkWhile):
    return p.whileStatement()

  if p.check(tkRepeat):
    return p.repeatStatement()
  
  # Обработка исключений
  if p.check(tkTry):
    return p.tryStatement()
  
  # Обработка событий
  if p.check(tkEvent):
    return p.eventStatement()
  
  # Обработка импортов
  if p.check(tkModule):
    return p.importStatement()
  
  # Обработка возврата из функции
  if p.check(tkReturn):
    return p.returnStatement()
  
  # Обработка noop
  if p.check(tkNoop):
    discard p.advance() # Потребляем токен noop
    result = newNode(nkNoop)
    result.line = p.previous().line
    result.column = p.previous().column
    result.rbtNode = p.rbtBuilder.generateNoop()
    return result
  
  # Если ничего из вышеперечисленного не подошло, то это выражение-оператор
  return p.expressionStatement()

proc `$`*(node: Node, indent: int = 0): string =
  if node == nil:
    return " ".repeat(indent) & "nil"
  
  let indentStr = " ".repeat(indent)

  case node.kind
  of nkProgram:
    result = indentStr & "Program:\n"
    for stmt in node.stmts:
      result &= `$`(stmt, indent + 2) & "\n"
  
  of nkBlock:
    result = indentStr & "Block:\n"
    for stmt in node.blockStmts:
      result &= `$`(stmt, indent + 2) & "\n"
  
  of nkExprStmt:
    result = indentStr & "ExprStmt:\n"
    result &= `$`(node.expr, indent + 2)
  
  of nkFuncDef:
    result = indentStr & fmt"Function '{node.funcName}':"
    if node.funcGenericParams.len > 0:
      result &= "\n" & indentStr & "  Generic Parameters:\n"
      for param in node.funcGenericParams:
        result &= `$`(param, indent + 4) & "\n"
    if node.funcParams.len > 0:
      result &= "\n" & indentStr & "  Parameters:\n"
      for param in node.funcParams:
        result &= `$`(param, indent + 4) & "\n"
    if node.funcMods.len > 0:
      result &= indentStr & "  Modifiers: " & node.funcMods.join(", ") & "\n"
    if node.funcRetType != "":
      result &= indentStr & "  Return Type: " & node.funcRetType & "\n"
    result &= indentStr & "  Body:\n"
    result &= `$`(node.funcBody, indent + 4)

  of nkLambdaDef:
    result = indentStr & "Lambda:"
    if node.lambdaGenericParams.len > 0:
      result &= "\n" & indentStr & "  Generic Parameters:\n"
      for param in node.lambdaGenericParams:
        result &= `$`(param, indent + 4) & "\n"
    if node.lambdaParams.len > 0:
      result &= "\n" & indentStr & "  Parameters:\n"
      for param in node.lambdaParams:
        result &= `$`(param, indent + 4) & "\n"
    if node.lambdaMods.len > 0:
      result &= indentStr & "  Modifiers: " & node.lambdaMods.join(", ") & "\n"
    if node.lambdaRetType != "":
      result &= indentStr & "  Return Type: " & node.lambdaRetType & "\n"
    result &= indentStr & "  Body:\n"
    result &= `$`(node.lambdaBody, indent + 4)

  of nkPackDef:
    result = indentStr & fmt"Pack '{node.packName}':"
    if node.packGenericParams.len > 0:
      result &= "\n" & indentStr & "  Generic Parameters:\n"
      for param in node.packGenericParams:
        result &= `$`(param, indent + 4) & "\n"
    if node.packParents.len > 0:
      result &= "\n" & indentStr & "  Parents: " & node.packParents.join(", ")
    if node.packMods.len > 0:
      result &= "\n" & indentStr & "  Modifiers: " & node.packMods.join(", ")
    result &= "\n" & indentStr & "  Body:\n"
    result &= `$`(node.packBody, indent + 4)

  of nkGenericParam:
    result = indentStr & fmt"Generic Parameter '{node.genericName}'"
    if node.genericConstraints.len > 0:
      result &= ":\n"
      for constraint in node.genericConstraints:
        result &= `$`(constraint, indent + 2) & "\n"

  of nkGenericConstraint:
    result = indentStr & fmt"Constraint: {node.constraintType}"
  
  of nkParam:
    result = indentStr & fmt"Parameter '{node.paramName}'"
    if node.paramType != "":
      result &= fmt": {node.paramType}"
    if node.paramTypeModifier != '\0':
      result &= fmt" ({node.paramTypeModifier})"
    if node.paramDefault != nil:
      result &= "\n" & indentStr & "  Default:\n"
      result &= `$`(node.paramDefault, indent + 4)

  of nkStructDef:
    result = indentStr & fmt"Struct '{node.structName}':\n"
    if node.structFields.len > 0:
      result &= indentStr & "  Fields:\n"
      for field in node.structFields:
        result &= `$`(field, indent + 4) & "\n"
    if node.structMethods.len > 0:
      result &= indentStr & "  Methods:\n"
      for meth in node.structMethods:
        result &= `$`(meth, indent + 4) & "\n"

  of nkEnumDef:
    result = indentStr & fmt"Enum '{node.enumName}':\n"
    if node.enumVariants.len > 0:
      result &= indentStr & "  Variants:\n"
      for variant in node.enumVariants:
        result &= `$`(variant, indent + 4) & "\n"
    if node.enumMethods.len > 0:
      result &= indentStr & "  Methods:\n"
      for meth in node.enumMethods:
        result &= `$`(meth, indent + 4) & "\n"

  of nkEnumVariant:
    result = indentStr & fmt"Variant '{node.variantName}'"
    if node.variantValue != nil:
      result &= " = "
      result &= `$`(node.variantValue, 0)

  of nkFieldDef:
    result = indentStr & fmt"Field '{node.fieldName}': {node.fieldType}"
    if node.fieldDefault != nil:
      result &= " = "
      result &= `$`(node.fieldDefault, 0)

  of nkStructInit:
    result = indentStr & fmt"Struct Init '{node.structType}':\n"
    for arg in node.structArgs:
      result &= `$`(arg, indent + 2) & "\n"
  
  of nkIf:
    result = indentStr & "If:\n"
    result &= indentStr & "  Condition:\n"
    result &= `$`(node.ifCond, indent + 4) & "\n"
    result &= indentStr & "  Then:\n"
    result &= `$`(node.ifThen, indent + 4)
    
    if node.ifElifs.len > 0:
      for i, elifBranch in node.ifElifs:
        result &= "\n" & indentStr & "  Elif Condition:\n"
        result &= `$`(elifBranch.cond, indent + 4) & "\n"
        result &= indentStr & "  Elif Branch:\n"
        result &= `$`(elifBranch.body, indent + 4)
    
    if node.ifElse != nil:
      result &= "\n" & indentStr & "  Else:\n"
      result &= `$`(node.ifElse, indent + 4)

  of nkSwitch:
    result = indentStr & "Switch:\n"
    result &= indentStr & "  Expression:\n"
    result &= `$`(node.switchExpr, indent + 4) & "\n"
    result &= indentStr & "  Cases:\n"
    for Сase in node.switchCases:
      result &= `$`(Сase, indent + 4) & "\n"
    if node.switchDefault != nil:
      result &= indentStr & "  Default:\n"
      result &= `$`(node.switchDefault, indent + 4)

  of nkSwitchCase:
    result = indentStr & "Case:\n"
    result &= indentStr & "  Conditions:\n"
    for condition in node.caseConditions:
      result &= `$`(condition, indent + 4) & "\n"
    if node.caseGuard != nil:
      result &= indentStr & "  Guard:\n"
      result &= `$`(node.caseGuard, indent + 4) & "\n"
    result &= indentStr & "  Body:\n"
    result &= `$`(node.caseBody, indent + 4)
  
  of nkFor:
    result = indentStr & fmt"For '{node.forVar}' in "
    result &= "\n" & indentStr & "  Start:\n"
    result &= `$`(node.forRange.start, indent + 4)
    result &= "\n" & indentStr & "  Inclusive: " & $node.forRange.inclusive
    if node.forRange.endExpr != nil:
      result &= "\n" & indentStr & "  End:\n"
      result &= `$`(node.forRange.endExpr, indent + 4)
    result &= "\n" & indentStr & "  Body:\n"
    result &= `$`(node.forBody, indent + 4)

  of nkEach:
    result = indentStr & fmt"Each '{node.eachVar}':\n"
    result &= indentStr & "  From:\n"
    result &= `$`(node.eachStart, indent + 4) & "\n"
    result &= indentStr & "  To:\n"
    result &= `$`(node.eachEnd, indent + 4)
    if node.eachStep != nil:
      result &= "\n" & indentStr & "  Step:\n"
      result &= `$`(node.eachStep, indent + 4)
    if node.eachWhere != nil:
      result &= "\n" & indentStr & "  Where:\n"
      result &= `$`(node.eachWhere, indent + 4)
    result &= "\n" & indentStr & "  Body:\n"
    result &= `$`(node.eachBody, indent + 4)

  of nkWhile:
    result = indentStr & "While:\n"
    result &= indentStr & "  Condition:\n"
    result &= `$`(node.whileCond, indent + 4) & "\n"
    result &= indentStr & "  Body:\n"
    result &= `$`(node.whileBody, indent + 4)
  
  of nkInfinit:
    result = indentStr & "Infinit:\n"
    result &= indentStr & "  Delay:\n"
    result &= `$`(node.infDelay, indent + 4)
    result &= "\n" & indentStr & "  Body:\n"
    result &= `$`(node.infBody, indent + 4)

  of nkInit:
    result = indentStr & "Init:\n"
    if node.initParams.len > 0:
      result &= indentStr & "  Parameters:\n"
      for param in node.initParams:
        result &= `$`(param, indent + 4) & "\n"
    result &= indentStr & "  Body:\n"
    result &= `$`(node.initBody, indent + 4)

  of nkState:
    result = indentStr & fmt"State '{node.stateName}':\n"
    result &= `$`(node.stateBody, indent + 2)

  of nkStateBody:
    result = indentStr & "State Body:\n"
    if node.stateMethods.len > 0:
      result &= indentStr & "  Methods:\n"
      for meth in node.stateMethods:
        result &= `$`(meth, indent + 4) & "\n"
    if node.stateVars.len > 0:
      result &= indentStr & "  Variables:\n"
      for variable in node.stateVars:
        result &= `$`(variable, indent + 4) & "\n"
    if node.stateWatchers.len > 0:
      result &= indentStr & "  Watchers:\n"
      for watcher in node.stateWatchers:
        result &= `$`(watcher, indent + 4) & "\n"
  
  of nkRepeat:
    result = indentStr & "Repeat:\n"
    result &= indentStr & "  Count:\n"
    result &= `$`(node.repCount, indent + 4)
    result &= "\n" & indentStr & "  Delay:\n"
    result &= `$`(node.repDelay, indent + 4)
    result &= "\n" & indentStr & "  Body:\n"
    result &= `$`(node.repBody, indent + 4)
  
  of nkTry:
    result = indentStr & "Try:\n"
    result &= indentStr & "  Try Block:\n"
    result &= `$`(node.tryBody, indent + 4)
    result &= "\n" & indentStr & "  Error Type: " & node.tryErrType
    result &= "\n" & indentStr & "  Catch Block:\n"
    result &= `$`(node.tryCatch, indent + 4)
  
  of nkEvent:
    result = indentStr & "Event:\n"
    result &= indentStr & "  Condition:\n"
    result &= `$`(node.evCond, indent + 4)
    result &= "\n" & indentStr & "  Body:\n"
    result &= `$`(node.evBody, indent + 4)
  
  of nkImport:
    result = indentStr & "Import:\n"
    for imp in node.imports:
      result &= indentStr & "  Module: " & imp.path.join(".")
      if imp.isAll:
        result &= " [*]"
      elif imp.items.len > 0:
        result &= " [" & imp.items.join(", ") & "]"
      if imp.alias.len > 0:
        result &= " as " & imp.alias
      result &= "\n"
  
  of nkReturn:
    result = indentStr & "Return:\n"
    if node.retVal != nil:
      result &= `$`(node.retVal, indent + 2)
    else:
      result &= indentStr & "  <void>"
  
  of nkBinary:
    result = indentStr & "Binary " & node.binOp & ":\n"
    result &= indentStr & "  Left:\n"
    result &= `$`(node.binLeft, indent + 4) & "\n"
    result &= indentStr & "  Right:\n"
    result &= `$`(node.binRight, indent + 4)
  
  of nkUnary:
    result = indentStr & "Unary " & node.unOp & ":\n"
    result &= `$`(node.unExpr, indent + 2)
  
  of nkCall:
    result = indentStr & "Call:\n"
    result &= indentStr & "  Function:\n"
    result &= `$`(node.callFunc, indent + 4) & "\n"
    result &= indentStr & "  Arguments:\n"
    for arg in node.callArgs:
      result &= `$`(arg, indent + 4) & "\n"
  
  of nkProperty:
    result = indentStr & "Property Access:\n"
    result &= indentStr & "  Object:\n"
    result &= `$`(node.propObj, indent + 4) & "\n"
    result &= indentStr & "  Property: " & node.propName
  
  of nkGroup:
    result = indentStr & "Group:\n"
    result &= `$`(node.groupExpr, indent + 2)
  
  of nkAssign:
    result = indentStr & "Assign " & node.assignOp
    if node.declType != dtNone:
      result &= " (" & $node.declType & ")"
    if node.varType != "":
      result &= " : " & node.varType
      if node.varTypeModifier != '\0':
        result &= " (" & node.varTypeModifier & ")"
    result &= ":\n"
    result &= indentStr & "  Target:\n"
    result &= `$`(node.assignTarget, indent + 4) & "\n"
    result &= indentStr & "  Value:\n"
    result &= `$`(node.assignVal, indent + 4)
  
  of nkIdent:
    result = indentStr & "Identifier: " & node.ident
  
  of nkNumber:
    result = indentStr & "Number: " & node.numVal

  of nkString:
    result = indentStr & "String: \"" & node.strVal & "\""

  of nkFormatString:
    result = indentStr & "FormatString (" & node.formatType & "): \"" & node.formatContent & "\""

  of nkTypeCheck:
    result = indentStr & "TypeCheck:\n"
    result &= indentStr & "  Type: " & node.checkType & "\n"
    if node.checkFunc != "":
      result &= indentStr & "  Function: " & node.checkFunc
    if node.checkBlock != nil:
      result &= "\n" & indentStr & "  Block:\n"
      result &= `$`(node.checkBlock, indent + 4)
    if node.checkExpr != nil:
      result &= "\n" & indentStr & "  Expression:\n"
      result &= `$`(node.checkExpr, indent + 4)

  of nkArray:
    result = indentStr & "Array:\n"
    for element in node.elements:
      result &= `$`(element, indent + 2) & "\n"

  of nkTable:
    result = indentStr & "Table:\n"
    for pair in node.tablePairs:
      result &= `$`(pair, indent + 2) & "\n"

  of nkTablePair:
    result = indentStr & "TablePair:\n"
    result &= indentStr & "  Key:\n"
    result &= `$`(node.pairKey, indent + 4) & "\n"
    result &= indentStr & "  Value:\n"
    result &= `$`(node.pairValue, indent + 4)

  of nkArrayAccess:
    result = indentStr & "ArrayAccess:\n"
    result &= indentStr & "  Array:\n"
    result &= `$`(node.array, indent + 4) & "\n"
    result &= indentStr & "  Index:\n"
    result &= `$`(node.index, indent + 4)

  of nkSlice:
    result = indentStr & "Slice:\n"
    result &= indentStr & "  Array:\n"
    result &= `$`(node.sliceArray, indent + 4) & "\n"
    result &= indentStr & "  Start:\n"
    result &= `$`(node.startIndex, indent + 4) & "\n"
    result &= indentStr & "  End:\n"
    result &= `$`(node.endIndex, indent + 4) & "\n"
    result &= indentStr & "  Inclusive: " & $node.inclusive

  of nkTupleAccess:
    result = indentStr & "TupleAccess:\n"
    result &= indentStr & "  Tuple:\n"
    result &= `$`(node.tupleObj, indent + 4) & "\n"
    result &= indentStr & "  Field Index: " & $node.fieldIndex

  of nkRangeExpr:
    result = indentStr & "Range:\n"
    result &= indentStr & "  Start:\n"
    result &= `$`(node.rangeStart, indent + 4) & "\n"
    result &= indentStr & "  End:\n"
    result &= `$`(node.rangeEnd, indent + 4)
    if node.rangeStep != nil:
      result &= "\n" & indentStr & "  Step:\n"
      result &= `$`(node.rangeStep, indent + 4)

  of nkChainCall:
    result = indentStr & "ChainCall:\n"
    for i, call in node.chain:
      result &= indentStr & fmt"  Call {i}:\n"
      result &= `$`(call, indent + 4) & "\n"

  of nkSubscript:
    result = indentStr & "Subscript:\n"
    result &= indentStr & "  Container:\n"
    result &= `$`(node.container, indent + 4) & "\n"
    result &= indentStr & "  Indices:\n"
    for index in node.indices:
      result &= `$`(index, indent + 4) & "\n"
  
  of nkBool:
    result = indentStr & "Boolean: " & $node.boolVal
  
  of nkNoop:
    result = indentStr & "Noop"

proc `$`*(node: Node): string =
  return `$`(node, 0)

proc parse*(p: Parser): Node =
  ## Парсит токены и строит AST
  var statements: seq[Node] = @[]
  
  while not p.isAtEnd():
    let stmt = p.statement()
    if stmt != nil:
      statements.add(stmt)
  
  result = newNode(nkProgram)
  result.stmts = statements
  return result