import std/[strutils, strformat]
import lexer

# Исправленное определение типа Node
type
  NodeKind* = enum
    # Программа и операторы
    nkProgram,        # Программа
    nkBlock,          # Блок кода
    nkExprStmt,       # Выражение-оператор
    
    # Определения
    nkFuncDef,        # Определение функции
    nkPackDef,        # Определение класса (pack)
    nkInit,           # init
    nkParam,          # Параметр функции
    
    # Управляющие конструкции
    nkIf,             # Условный оператор
    nkFor,            # Цикл for
    nkInfinit,        # Бесконечный цикл
    nkRepeat,         # Цикл с повторениями
    nkTry,            # Блок try-elerr
    nkEvent,          # Событие
    nkImport,         # Импорт модулей
    nkOutPut,         # Оператор return
    
    # Выражения
    nkBinary,         # Бинарное выражение
    nkUnary,          # Унарное выражение
    nkCall,           # Вызов функции
    nkProperty,       # Доступ к свойству
    nkGroup,          # Группировка выражений
    
    # Присваивания
    nkAssign,         # Присваивание
    
    # Литералы
    nkIdent,          # Идентификатор
    nkNumber,         # Число
    nkString,         # Строка
    nkBool,           # Булево значение
    nkArray,
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
    
    case kind*: NodeKind
    of nkProgram:
      stmts*: seq[Node]
    
    of nkBlock:
      blockStmts*: seq[Node]
    
    of nkExprStmt:
      expr*: Node
    
    of nkInit:
      initBody*: Node

    of nkFuncDef:
      funcName*: string
      funcParams*: seq[Node]
      funcMods*: seq[string]
      funcRetType*: string
      funcBody*: Node
    
    of nkPackDef:
      packName*: string
      packParents*: seq[string]
      packMods*: seq[string]
      packBody*: Node
    
    of nkParam:
      paramName*: string
      paramType*: string
    
    of nkIf:
      ifCond*: Node
      ifThen*: Node
      ifElifs*: seq[tuple[cond: Node, body: Node]]
      ifElse*: Node
    
    of nkFor:
      forVar*: string
      forRange*: tuple[start: Node, inclusive: bool, endExpr: Node]
      forBody*: Node
    
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
    
    of nkOutPut:
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
      declType*: DeclType 
      assignOp*: string
      assignTarget*: Node
      assignVal*: Node
    
    of nkIdent:
      ident*: string
    
    of nkNumber:
      numVal*: string
    
    of nkString:
      strVal*: string

    of nkArray:
      elements*: seq[Node]

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
proc newNode*(kind: NodeKind): Node =
  result = Node(kind: kind)

proc newParser*(tokens: seq[Token]): Parser =
  result = Parser(
    tokens: tokens,
    current: 0,
    errors: @[]
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


# Объявления функций парсинга
proc expression(p: Parser): Node
proc statement(p: Parser): Node
proc parseBlock(p: Parser): Node
proc parsePackBody(p: Parser): Node
proc functionDeclaration(p: Parser): Node
proc packDeclaration(p: Parser): Node
proc ifStatement(p: Parser): Node
proc parseInitBlock(p: Parser): Node
proc forStatement(p: Parser): Node
proc infinitStatement(p: Parser): Node
proc repeatStatement(p: Parser): Node
proc tryStatement(p: Parser): Node
proc eventStatement(p: Parser): Node
proc importStatement(p: Parser): Node
proc returnStatement(p: Parser): Node
proc expressionStatement(p: Parser): Node

# Парсинг выражений
proc primary(p: Parser): Node =
  if p.match(tkNumber):
    let token = p.previous()
    result = newNode(nkNumber)
    result.numVal = token.lexeme
    result.line = token.line
    result.column = token.column
    return result
  
  if p.match(tkString):
    let token = p.previous()
    result = newNode(nkString)
    result.strVal = token.lexeme
    result.line = token.line
    result.column = token.column
    return result
  
  if p.match(tkIdentifier):
    let token = p.previous()
    result = newNode(nkIdent)
    result.ident = token.lexeme
    result.line = token.line
    result.column = token.column
    var expr = result

    while true:
      # Доступ к элементам массива [index]
      if p.match(tkLBracket):
        let index = p.expression()
        discard p.consume(tkRBracket, "Expected ']' after array index")
        let access = newNode(nkArrayAccess)
        access.array = expr
        access.index = index
        access.line = token.line
        access.column = token.column
        expr = access
        
      # Доступ к полям через точку obj.field
      elif p.match(tkDot):
        let name = p.consume(tkIdentifier, "Expected property name after '.'")
        let prop = newNode(nkProperty)
        prop.propObj = expr
        prop.propName = name.lexeme
        prop.line = name.line
        prop.column = name.column
        expr = prop
        
      # Вызов методов obj.method()
      elif p.match(tkLParen):
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
        let call = newNode(nkCall)
        call.callFunc = expr
        call.callArgs = args
        expr = call
        
      # Срезы массивов arr[1..5]
      elif p.match(tkDotDot, tkDotDotDot):
        let inclusive = p.previous().kind == tkDotDot
        let endIndex = p.expression()
        discard p.consume(tkRBracket, "Expected ']' after slice range")
        let slice = newNode(nkSlice)
        slice.array = expr
        slice.startIndex = p.expression()
        slice.endIndex = endIndex
        slice.inclusive = inclusive
        slice.line = token.line
        slice.column = token.column
        expr = slice
        
      else:
        break
        
    return expr
  
  if p.match(tkNoop):
    let token = p.previous()
    result = newNode(nkNoop)
    result.line = token.line
    result.column = token.column
    return result

  if p.match(tkLBracket):
    var elements: seq[Node] = @[]
    
    if not p.check(tkRBracket):
      # Первый элемент
      elements.add(p.expression())
      
      # Остальные элементы через запятую
      while p.match(tkComma):
        elements.add(p.expression())
    
    discard p.consume(tkRBracket, "Expected ']' after array elements")
    
    result = newNode(nkArray)
    result.elements = elements
    return result

  if p.match(tkLParen):
    let expr = p.expression()
    discard p.consume(tkRParen, "Expected ')' after expression")
    result = newNode(nkGroup)
    result.groupExpr = expr
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
      expr = prop
    else:
      break
  
  return expr

proc unary(p: Parser): Node =
  if p.match(tkMinus, tkBang):
    let operator = p.previous()
    let right = p.unary()
    
    result = newNode(nkUnary)
    result.unOp = if operator.kind == tkMinus: "-" else: "!"
    result.unExpr = right
    result.line = operator.line
    result.column = operator.column
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
    expr = binary
  
  return expr

proc comparison(p: Parser): Node =
  var expr = p.term()
  
  while p.match(tkLt, tkLe, tkGt, tkGe):
    let operator = p.previous()
    let right = p.term()
    
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
    expr = binary
  
  return expr

proc logicalAnd(p: Parser): Node =
  var expr = p.equality()
  
  while p.match(tkAnd):
    let operator = p.previous()
    let right = p.equality()
    
    let binary = newNode(nkBinary)
    binary.binOp = "&&"
    binary.binLeft = expr
    binary.binRight = right
    binary.line = operator.line
    binary.column = operator.column
    expr = binary
  
  return expr

proc logicalOr(p: Parser): Node =
  var expr = p.logicalAnd()
  
  while p.match(tkOr):
    let operator = p.previous()
    let right = p.logicalAnd()
    
    let binary = newNode(nkBinary)
    binary.binOp = "||"
    binary.binLeft = expr
    binary.binRight = right
    binary.line = operator.line
    binary.column = operator.column
    expr = binary
  
  return expr

proc assignment(p: Parser): Node =
  let declType = if p.match(tkDef): dtDef
                 elif p.match(tkVal): dtVal
                 else: dtNone
  
  let expr = p.logicalOr()
  
  if p.match(tkAssign, tkPlusEq, tkMinusEq, tkMulEq, tkDivEq):
    let operator = p.previous()
    let value = p.assignment()
    
    if expr.kind == nkIdent:
      let assign = newNode(nkAssign)
      assign.declType = declType  # Тип объявления: var/let/none
      
      case operator.kind
      of tkAssign: assign.assignOp = "="
      of tkPlusEq: assign.assignOp = "+="
      of tkMinusEq: assign.assignOp = "-="
      of tkMulEq: assign.assignOp = "*="
      of tkDivEq: assign.assignOp = "/="
      else: assign.assignOp = ""
      
      assign.assignTarget = expr
      assign.assignVal = value
      assign.line = operator.line
      assign.column = operator.column
      return assign
    
    p.errors.add(fmt"Invalid assignment target at line {operator.line}, column {operator.column}")
  
  return expr

proc expression(p: Parser): Node =
  return p.assignment()

proc parameter(p: Parser): Node =
  let token = p.consume(tkIdentifier, "Expected parameter name")
  let name = token.lexeme
  
  # Тип параметра (опционально)
  var paramType = ""
  if p.match(tkColon):
    # Собираем полный тип с поддержкой составных типов
    paramType = p.consume(tkIdentifier, "Expected parameter type after ':'").lexeme
    
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
  
  result = newNode(nkParam)
  result.paramName = name
  result.paramType = paramType
  result.line = token.line
  result.column = token.column
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

proc parseInitBlock(p: Parser): Node =
  discard p.consume(tkInit, "Expected 'init' keyword")
  
  result = newNode(nkInit)
  result.initBody = p.parseBlock()
  result.line = p.previous().line
  result.column = p.previous().column

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
  if p.match(tkDotDot):
    inclusive = true
  elif p.match(tkDotDotDot):
    inclusive = false
  else:
    p.errors.add("Expected range operator '..' or '...'")
    return nil
  
  # Конечное выражение диапазона
  let rangeEnd = p.expression()
  
  # Блок кода
  let body = p.parseBlock()
  
  result = newNode(nkFor)
  result.forVar = varName
  result.forRange = (start: rangeStart, inclusive: inclusive, endExpr: rangeEnd)
  result.forBody = body
  result.line = token.line
  result.column = token.column
  return result

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
  return result

proc returnStatement(p: Parser): Node =
  let token = p.consume(tkOutPut, "Expected 'return' keyword")
  
  var value: Node = nil
  # Проверяем, есть ли выражение после return
  if not p.check(tkSemicolon) and not p.check(tkRBrace):
    value = p.expression()
  
  # Опционально: проверка на точку с запятой
  discard p.match(tkSemicolon)
  
  result = newNode(nkOutPut)
  result.retVal = value
  result.line = token.line
  result.column = token.column
  return result

proc ifStatement(p: Parser): Node =
  let token = p.consume(tkIf, "Expected 'if' keyword")
  
  # Условие
  let condition = p.expression()
  
  # Блок кода для if
  let thenBranch = p.parseBlock()
  
  var elifBranches: seq[tuple[cond: Node, body: Node]] = @[]
  var elseBranch: Node = nil
  
  # Обработка elif блоков
  while p.match(tkElif):
    let elifCond = p.expression()
    let elifBody = p.parseBlock()
    elifBranches.add((cond: elifCond, body: elifBody))
  
  # Обработка else блока
  if p.match(tkElse):
    elseBranch = p.parseBlock()
  
  result = newNode(nkIf)
  result.ifCond = condition
  result.ifThen = thenBranch
  result.ifElifs = elifBranches
  result.ifElse = elseBranch
  result.line = token.line
  result.column = token.column
  return result

proc tryStatement(p: Parser): Node =
  let token = p.consume(tkTry, "Expected 'try' keyword")
  
  # Блок try
  let tryBody = p.parseBlock()
  
  discard p.consume(tkElerr, "Expected 'elerr' after try block")
  
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
  return result

proc functionDeclaration(p: Parser): Node =
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
  if p.match(tkRetType):
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
  result.funcMods = modifiers
  result.funcBody = body
  result.line = token.line
  result.column = token.column
  return result

proc methodDeclaration(p: Parser): Node =
  let token = p.consume(tkFunc, "Expected 'func' keyword")
  
  # Имя функции
  let name = p.consume(tkIdentifier, "Expected function name after 'func'").lexeme
  
  # Параметры
  var params: seq[Node] = @[]
  if p.match(tkLParen):
    if not p.check(tkRParen):
      # Первый параметр
      params.add(p.parameter())
      
      # Остальные параметры
      while p.match(tkComma):
        params.add(p.parameter())
    
    discard p.consume(tkRParen, "Expected ')' after parameters")

  # Тип возвращаемого значения
  var returnType = ""
  if p.match(tkRetType):
    returnType = p.consume(tkIdentifier, "Expected return type after ':'").lexeme

  # Модификаторы
  var modifiers: seq[string] = @[]
  if p.match(tkModStart):
    modifiers.add(p.consume(tkIdentifier, "Expected modifier").lexeme)
    while p.match(tkComma):
      modifiers.add(p.consume(tkIdentifier, "Expected modifier").lexeme)
    discard p.consume(tkModEnd, "Expected ')'")
  
  # Тело функции
  let body = p.parseBlock()
  
  result = newNode(nkFuncDef)
  result.funcName = name
  result.funcParams = params
  result.funcRetType = returnType
  result.funcMods = modifiers
  result.funcBody = body
  result.line = token.line
  result.column = token.column
  return result

proc packDeclaration(p: Parser): Node =
  let token = p.consume(tkPack, "Expected 'pack' keyword")
  
  # Имя пакета
  let name = p.consume(tkIdentifier, "Expected pack name after 'pack'").lexeme

  # Модификаторы (опционально)
  var modifiers: seq[string] = @[]
  if p.match(tkModStart):
    modifiers.add(p.consume(tkIdentifier, "Expected modifier").lexeme)
    while p.match(tkComma):
      modifiers.add(p.consume(tkIdentifier, "Expected modifier").lexeme)
    discard p.consume(tkModEnd, "Expected ')'")

  # Родительские классы (опционально)
  var parents: seq[string] = @[]
  if p.match(tkColonColon):
    # Первый родитель
    parents.add(p.consume(tkIdentifier, "Expected parent class name after '::'").lexeme)
    
    # Остальные родители
    while p.match(tkPipe):
      parents.add(p.consume(tkIdentifier, "Expected parent class name after '|'").lexeme)
  
  # Тело пакета
  let body = p.parsePackBody()
  
  result = newNode(nkPackDef)
  result.packName = name
  result.packParents = parents
  result.packMods = modifiers
  result.packBody = body
  result.line = token.line
  result.column = token.column
  return result

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
  return result

proc parsePackBody(p: Parser): Node =
  var statements: seq[Node] = @[]
  
  discard p.consume(tkLBrace, "Expected '{'")
  
  while not p.check(tkRBrace) and not p.isAtEnd():
    echo "Current token: ", p.peek().lexeme
    if p.check(tkFunc):
      let methodDef = p.methodDeclaration()
      echo "Adding method kind: ", methodDef.kind
      statements.add(methodDef)
    elif p.check(tkInit):
      let initDef = p.parseInitBlock()
      echo "Adding init kind: ", initDef.kind
      statements.add(initDef)
    else:
      let stmt = p.statement()
      if stmt != nil:
        echo "Adding statement kind: ", stmt.kind
        statements.add(stmt)

  discard p.consume(tkRBrace, "Expected '}'")

  result = newNode(nkBlock)
  result.blockStmts = statements
  echo "Final statements count: ", statements.len

proc parseBlock(p: Parser): Node =
  discard p.consume(tkLBrace, "Expected '{' before block")
  
  var statements: seq[Node] = @[]
  while not p.check(tkRBrace) and not p.isAtEnd():
    let stmt = p.statement()
    if stmt != nil:
      statements.add(stmt)
  
  discard p.consume(tkRBrace, "Expected '}' after block")
  
  result = newNode(nkBlock)
  result.blockStmts = statements
  return result

proc statement(p: Parser): Node =
  # Обработка объявлений функций
  if p.check(tkFunc):
    return p.functionDeclaration()
  
  # Обработка объявлений пакетов (классов)
  if p.check(tkPack):
    return p.packDeclaration()
  
  # Обработка условных операторов
  if p.check(tkIf):
    return p.ifStatement()
  
  # Обработка циклов
  if p.check(tkFor):
    return p.forStatement()
  
  if p.check(tkInfinit):
    return p.infinitStatement()
  
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
  if p.check(tkOutPut):
    return p.returnStatement()
  
  # Обработка noop
  if p.check(tkNoop):
    discard p.advance() # Потребляем токен noop
    result = newNode(nkNoop)
    result.line = p.previous().line
    result.column = p.previous().column
    return result
  
  # Если ничего из вышеперечисленного не подошло, то это выражение-оператор
  return p.expressionStatement()

# Здесь должно быть объявление новой функции
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

  of nkPackDef:
    result = indentStr & fmt"Pack '{node.packName}':"
    if node.packParents.len > 0:
      result &= "\n" & indentStr & "  Parents: " & node.packParents.join(", ")
    if node.packMods.len > 0:
      result &= "\n" & indentStr & "  Modifiers: " & node.packMods.join(", ")
    result &= "\n" & indentStr & "  Body:\n"
    result &= `$`(node.packBody, indent + 4)
  
  of nkParam:
    result = indentStr & fmt"Parameter '{node.paramName}'"
    if node.paramType != "":
      result &= fmt": {node.paramType}"
  
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
  
  of nkFor:
    result = indentStr & fmt"For '{node.forVar}' in "
    result &= "\n" & indentStr & "  Start:\n"
    result &= `$`(node.forRange.start, indent + 4)
    result &= "\n" & indentStr & "  Inclusive: " & $node.forRange.inclusive
    result &= "\n" & indentStr & "  End:\n"
    result &= `$`(node.forRange.endExpr, indent + 4)
    result &= "\n" & indentStr & "  Body:\n"
    result &= `$`(node.forBody, indent + 4)
  
  of nkInfinit:
    result = indentStr & "Infinit:\n"
    result &= indentStr & "  Delay:\n"
    result &= `$`(node.infDelay, indent + 4)
    result &= "\n" & indentStr & "  Body:\n"
    result &= `$`(node.infBody, indent + 4)

  of nkInit:
    result = indentStr & "Init:\n"
    result &= `$`(node.infDelay, indent + 4)
    result &= "\n" & indentStr & "  Body:\n"
    result &= `$`(node.initBody, indent + 4)
  
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
      result &= indentStr & " Module: " & imp.path.join(".")
      if imp.isAll:
        result &= " [*]"
      elif imp.items.len > 0:
        result &= " [" & imp.items.join(", ") & "]"
      if imp.alias.len > 0:
        result &= " as " & imp.alias
      result &= "\n"
  
  of nkOutPut:
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
    result = indentStr & "Assign " & node.assignOp & ":\n"
    result &= indentStr & "  Target:\n"
    result &= `$`(node.assignTarget, indent + 4) & "\n"
    result &= indentStr & "  Value:\n"
    result &= `$`(node.assignVal, indent + 4)
  
  of nkIdent:
    result = indentStr & "Identifier: " & node.ident
  
  of nkNumber:
    result = indentStr & "Number: " & node.numVal

  of nkArray:
    result = indentStr & "array: "

  of nkString:
    result = indentStr & "String: " & node.strVal
  
  of nkBool:
    result = indentStr & "Boolean: " & $node.boolVal
  
  of nkNoop:
    result = indentStr & "Noop"
  else: result = " "

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
