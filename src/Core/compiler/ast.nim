import std/[tables, strutils, strformat, options, sequtils]
import lexer, parser

type
  AstVisitor* = ref object of RootObj

  AstTransformer* = ref object of AstVisitor

  SymbolTable* = ref object
    symbols*: Table[string, Symbol]
    parent*: SymbolTable

  SymbolKind* = enum
    skVariable, skFunction, skPack,
    skStruct, skEnum, skField, skParameter

  Symbol* = ref object
    name*: string
    line*: int
    column*: int
    case kind*: SymbolKind
    of skVariable:
      varType*: string
      isConst*: bool
    of skFunction:
      params*: seq[Symbol]
      returnType*: string
      modifiers*: seq[string]
    of skPack:
      parents*: seq[string]
      packModifiers*: seq[string]
    of skStruct:
      structFields*: seq[Symbol]
      structMethods*: seq[Symbol]
    of skEnum:
      enumVariants*: seq[Symbol]
      enumMethods*: seq[Symbol]
    of skField:
      fieldType*: string
      fieldDefault*: string
    of skParameter:
      paramType*: string

# Методы для SymbolTable
proc newSymbolTable*(parent: SymbolTable = nil): SymbolTable =
  SymbolTable(symbols: initTable[string, Symbol](), parent: parent)

proc define*(self: SymbolTable, symbol: Symbol): bool =
  if self.symbols.hasKey(symbol.name):
    return false
  self.symbols[symbol.name] = symbol
  return true

proc resolve*(self: SymbolTable, name: string): Option[Symbol] =
  if self.symbols.hasKey(name):
    return some(self.symbols[name])
  
  if self.parent != nil:
    return self.parent.resolve(name)
  
  return none(Symbol)

# Базовые методы для AstVisitor
# Предварительное объявление метода visit
method visit*(self: AstVisitor, node: Node) {.base.}

method visitProgram*(self: AstVisitor, node: Node) {.base.} =
  for stmt in node.stmts:
    self.visit(stmt)

method visitBlock*(self: AstVisitor, node: Node) {.base.} =
  for stmt in node.blockStmts:
    self.visit(stmt)

method visitExprStmt*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.expr)

method visitFuncDef*(self: AstVisitor, node: Node) {.base.} =
  for param in node.funcParams:
    self.visit(param)
  self.visit(node.funcBody)

method visitLambdaDef*(self: AstVisitor, node: Node) {.base.} =
  for param in node.funcParams:
    self.visit(param)
  self.visit(node.funcBody)

method visitPackDef*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.packBody)

method visitStructDef*(self: AstVisitor, node: Node) {.base.} =
  for field in node.structFields:
    self.visit(field)
  for meth in node.structMethods:
    self.visit(meth)

method visitEnumDef*(self: AstVisitor, node: Node) {.base.} =
  for variant in node.enumVariants:
    self.visit(variant)
  for meth in node.enumMethods:
    self.visit(meth)

method visitEnumVariant*(self: AstVisitor, node: Node) {.base.} =
  if node.variantValue != nil:
    self.visit(node.variantValue)

method visitFieldDef*(self: AstVisitor, node: Node) {.base.} =
  if node.fieldDefault != nil:
    self.visit(node.fieldDefault)

method visitStructInit*(self: AstVisitor, node: Node) {.base.} =
  for arg in node.structArgs:
    self.visit(arg)

method visitParam*(self: AstVisitor, node: Node) {.base.} =
  discard

method visitState*(self: AstVisitor, node: Node) {.base.} = 
  self.visit(node.stateBody)

method visitStateBody*(self: AstVisitor, node: Node) {.base.} = 
  for meth in node.stateMethods:
    self.visit(meth)
  for variable in node.stateVars:
    self.visit(variable)
  for watcher in node.stateWatchers:
    self.visit(watcher)

method visitIf*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.ifCond)
  self.visit(node.ifThen)
  
  for elifBranch in node.ifElifs:
    self.visit(elifBranch.cond)
    self.visit(elifBranch.body)
  
  if node.ifElse != nil:
    self.visit(node.ifElse)

method visitSwitch*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.switchExpr)
  for caseNode in node.switchCases:
    self.visit(caseNode)
  if node.switchDefault != nil:
    self.visit(node.switchDefault)

method visitSwitchCase*(self: AstVisitor, node: Node) {.base.} =
  for condition in node.caseConditions:
    self.visit(condition)
  if node.caseGuard != nil:
    self.visit(node.caseGuard)
  self.visit(node.caseBody)

method visitInit*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.initBody)

method visitFor*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.forRange.start)
  self.visit(node.forRange.endExpr)
  self.visit(node.forBody)

method visitEach*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.eachStart)
  self.visit(node.eachEnd)
  if node.eachStep != nil:
    self.visit(node.eachStep)
  if node.eachWhere != nil:
    self.visit(node.eachWhere)
  self.visit(node.eachBody)

method visitWhile*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.whileCond)
  self.visit(node.whileBody)

method visitInfinit*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.infDelay)
  self.visit(node.infBody)

method visitRepeat*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.repCount)
  self.visit(node.repDelay)
  self.visit(node.repBody)

method visitTry*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.tryBody)
  self.visit(node.tryCatch)

method visitEvent*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.evCond)
  self.visit(node.evBody)

method visitImport*(self: AstVisitor, node: Node) {.base.} =
  discard

method visitReturn*(self: AstVisitor, node: Node) {.base.} =
  if node.retVal != nil:
    self.visit(node.retVal)

method visitBinary*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.binLeft)
  self.visit(node.binRight)

method visitUnary*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.unExpr)

method visitCall*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.callFunc)
  for arg in node.callArgs:
    self.visit(arg)

method visitProperty*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.propObj)

method visitGroup*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.groupExpr)

method visitAssign*(self: AstVisitor, node: Node) {.base.} =
  if node.assignProps.len > 0:
    for prop in node.assignProps:
      self.visit(prop)

  self.visit(node.assignTarget)
  self.visit(node.assignVal)

method visitIdent*(self: AstVisitor, node: Node) {.base.} =
  discard

method visitNumber*(self: AstVisitor, node: Node) {.base.} =
  discard

method visitFormatString*(self: AstVisitor, node: Node) {.base.} =
  discard

method visitString*(self: AstVisitor, node: Node) {.base.} =
  discard

method visitBool*(self: AstVisitor, node: Node) {.base.} =
  discard

method visitArray*(self: AstVisitor, node: Node) {.base.} =
  for element in node.elements:
    self.visit(element)

method visitArrayAccess*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.array)
  self.visit(node.index)

method visitTable*(self: AstVisitor, node: Node) {.base.} =
  for pair in node.tablePairs:
    self.visit(pair)

method visitTablePair*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.pairKey)
  self.visit(node.pairValue)

method visitSlice*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.sliceArray)
  self.visit(node.startIndex)
  self.visit(node.endIndex)

method visitTupleAccess*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.tupleObj)

method visitRangeExpr*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.rangeStart)
  self.visit(node.rangeEnd)
  if node.rangeStep != nil:
    self.visit(node.rangeStep)

method visitChainCall*(self: AstVisitor, node: Node) {.base.} =
  for call in node.chain:
    self.visit(call)

method visitSubscript*(self: AstVisitor, node: Node) {.base.} =
  self.visit(node.container)
  for idx in node.indices:
    self.visit(idx)

method visitNoop*(self: AstVisitor, node: Node) {.base.} =
  discard

method visit*(self: AstVisitor, node: Node) {.base.} =
  if node == nil:
    return
    
  case node.kind
  of nkProgram:           self.visitProgram(node)
  of nkBlock:             self.visitBlock(node)
  of nkExprStmt:          self.visitExprStmt(node)
  of nkFuncDef:           self.visitFuncDef(node)
  of nkLambdaDef:         self.visitLambdaDef(node)
  of nkPackDef:           self.visitPackDef(node)
  of nkStructDef:         self.visitStructDef(node)
  of nkEnumDef:           self.visitEnumDef(node)
  of nkEnumVariant:       self.visitEnumVariant(node)
  of nkFieldDef:          self.visitFieldDef(node)
  of nkStructInit:        self.visitStructInit(node)
  of nkState:             self.visitState(node)
  of nkStateBody:         self.visitStateBody(node)
  of nkParam:             self.visitParam(node)
  of nkIf:                self.visitIf(node)
  of nkSwitch:            self.visitSwitch(node)
  of nkSwitchCase:        self.visitSwitchCase(node)
  of nkInit:              self.visitInit(node)
  of nkFor:               self.visitFor(node)
  of nkEach:              self.visitEach(node)
  of nkInfinit:           self.visitInfinit(node)
  of nkWhile:             self.visitWhile(node)
  of nkRepeat:            self.visitRepeat(node)
  of nkTry:               self.visitTry(node)
  of nkEvent:             self.visitEvent(node)
  of nkImport:            self.visitImport(node)
  of nkOutPut:            self.visitReturn(node)
  of nkBinary:            self.visitBinary(node)
  of nkUnary:             self.visitUnary(node)
  of nkCall:              self.visitCall(node)
  of nkProperty:          self.visitProperty(node)
  of nkGroup:             self.visitGroup(node)
  of nkAssign:            self.visitAssign(node)
  of nkIdent:             self.visitIdent(node)
  of nkNumber:            self.visitNumber(node)
  of nkString:            self.visitString(node)
  of nkFormatString:      self.visitFormatString(node)
  of nkBool:              self.visitBool(node)
  of nkArray:             self.visitArray(node)
  of nkTable:             self.visitTable(node)
  of nkTablePair:         self.visitTablePair(node)
  of nkTypeCheck:         self.visit(node)
  of nkArrayAccess:       self.visitArrayAccess(node)
  of nkSlice:             self.visitSlice(node) 
  of nkTupleAccess:       self.visitTupleAccess(node)
  of nkRangeExpr:         self.visitRangeExpr(node)
  of nkChainCall:         self.visitChainCall(node)
  of nkSubscript:         self.visitSubscript(node)
  of nkNoop:              self.visitNoop(node)

# Предварительное объявление метода transform
method transform*(self: AstTransformer, node: Node): Node {.base.}

# Базовые методы для AstTransformer
method transformProgram*(self: AstTransformer, node: Node): Node {.base.} =
  var newStmts: seq[Node] = @[]
  for stmt in node.stmts:
    let transformed = self.transform(stmt)
    if transformed != nil:
      newStmts.add(transformed)
  
  result = newNode(nkProgram)
  result.stmts = newStmts
  result.line = node.line
  result.column = node.column

method transformBlock*(self: AstTransformer, node: Node): Node {.base.} =
  var newStmts: seq[Node] = @[]
  for stmt in node.blockStmts:
    let transformed = self.transform(stmt)
    if transformed != nil:
      newStmts.add(transformed)
  
  result = newNode(nkBlock)
  result.blockStmts = newStmts
  result.line = node.line
  result.column = node.column

method transformExprStmt*(self: AstTransformer, node: Node): Node {.base.} =
  let expr = self.transform(node.expr)
  if expr == nil:
    return nil
  
  result = newNode(nkExprStmt)
  result.expr = expr
  result.line = node.line
  result.column = node.column

method transformFuncDef*(self: AstTransformer, node: Node): Node {.base.} =
  var newParams: seq[Node] = @[]
  for param in node.funcParams:
    let transformed = self.transform(param)
    if transformed != nil:
      newParams.add(transformed)
  
  let body = self.transform(node.funcBody)
  if body == nil:
    return nil
  
  result = newNode(nkFuncDef)
  result.funcName = node.funcName
  result.funcParams = newParams
  result.funcMods = node.funcMods
  result.funcRetType = node.funcRetType
  result.funcBody = body
  result.line = node.line
  result.column = node.column

method transformLambdaDef*(self: AstTransformer, node: Node): Node {.base.} =
  var newParams: seq[Node] = @[]
  for param in node.lambdaParams:
    let transformed = self.transform(param)
    if transformed != nil:
      newParams.add(transformed)
  
  let body = self.transform(node.lambdaBody)
  if body == nil:
    return nil
  
  result = newNode(nkFuncDef)
  result.lambdaParams = newParams
  result.lambdaMods = node.funcMods
  result.lambdaRetType = node.funcRetType
  result.lambdaBody = body
  result.line = node.line
  result.column = node.column

method transformPackDef*(self: AstTransformer, node: Node): Node {.base.} =
  let body = self.transform(node.packBody)
  if body == nil:
    return nil
  
  result = newNode(nkPackDef)
  result.packName = node.packName
  result.packParents = node.packParents
  result.packMods = node.packMods
  result.packBody = body
  result.line = node.line
  result.column = node.column

method transformStructDef*(self: AstTransformer, node: Node): Node {.base.} =
  var newFields: seq[Node] = @[]
  var newMethods: seq[Node] = @[]
  var hasChanges = false
  
  for field in node.structFields:
    let transformed = self.transform(field)
    if transformed != field:
      hasChanges = true
    if transformed != nil:
      newFields.add(transformed)
  
  for meth in node.structMethods:
    let transformed = self.transform(meth)
    if transformed != meth:
      hasChanges = true
    if transformed != nil:
      newMethods.add(transformed)
  
  if not hasChanges:
    return node
  
  result = newNode(nkStructDef)
  result.structName = node.structName
  result.structFields = newFields
  result.structMethods = newMethods
  result.line = node.line
  result.column = node.column

method transformEnumDef*(self: AstTransformer, node: Node): Node {.base.} =
  var newVariants: seq[Node] = @[]
  var newMethods: seq[Node] = @[]
  var hasChanges = false
  
  for variant in node.enumVariants:
    let transformed = self.transform(variant)
    if transformed != variant:
      hasChanges = true
    if transformed != nil:
      newVariants.add(transformed)
  
  for meth in node.enumMethods:
    let transformed = self.transform(meth)
    if transformed != meth:
      hasChanges = true
    if transformed != nil:
      newMethods.add(transformed)
  
  if not hasChanges:
    return node
  
  result = newNode(nkEnumDef)
  result.enumName = node.enumName
  result.enumVariants = newVariants
  result.enumMethods = newMethods
  result.line = node.line
  result.column = node.column

method transformEnumVariant*(self: AstTransformer, node: Node): Node {.base.} =
  if node.variantValue == nil:
    return node
  
  let transformedValue = self.transform(node.variantValue)
  
  if transformedValue == node.variantValue:
    return node
  
  result = newNode(nkEnumVariant)
  result.variantName = node.variantName
  result.variantValue = transformedValue
  result.line = node.line
  result.column = node.column

method transformFieldDef*(self: AstTransformer, node: Node): Node {.base.} =
  if node.fieldDefault == nil:
    return node
  
  let transformedDefault = self.transform(node.fieldDefault)
  
  if transformedDefault == node.fieldDefault:
    return node
  
  result = newNode(nkFieldDef)
  result.fieldName = node.fieldName
  result.fieldType = node.fieldType
  result.fieldDefault = transformedDefault
  result.line = node.line
  result.column = node.column

method transformStructInit*(self: AstTransformer, node: Node): Node {.base.} =
  var newArgs: seq[Node] = @[]
  var hasChanges = false
  
  for arg in node.structArgs:
    let transformed = self.transform(arg)
    if transformed != arg:
      hasChanges = true
    if transformed != nil:
      newArgs.add(transformed)
  
  if not hasChanges:
    return node
  
  result = newNode(nkStructInit)
  result.structType = node.structType
  result.structArgs = newArgs
  result.line = node.line
  result.column = node.column

method transformState*(self: AstTransformer, node: Node): Node {.base.} =
  let body = self.transform(node.stateBody)
  
  result = newNode(nkState)
  result.stateName = node.stateName
  result.stateBody = body
  result.line = node.line
  result.column = node.column

method transformStateBody*(self: AstTransformer, node: Node): Node {.base.} =
  var newMethods: seq[Node] = @[]
  var newVars: seq[Node] = @[]
  var newWatchers: seq[Node] = @[]
  
  for meth in node.stateMethods:
    newMethods.add(self.transform(meth))
  for variable in node.stateVars:
    newVars.add(self.transform(variable))
  for watcher in node.stateWatchers:
    newWatchers.add(self.transform(watcher))
    
  result = newNode(nkStateBody)
  result.stateMethods = newMethods
  result.stateVars = newVars
  result.stateWatchers = newWatchers
  result.line = node.line
  result.column = node.column
  
method transformParam*(self: AstTransformer, node: Node): Node {.base.} =
  result = newNode(nkParam)
  result.paramName = node.paramName
  result.paramType = node.paramType
  result.line = node.line
  result.column = node.column

method transformIf*(self: AstTransformer, node: Node): Node {.base.} =
  let cond = self.transform(node.ifCond)
  if cond == nil:
    return nil
  
  let thenBranch = self.transform(node.ifThen)
  if thenBranch == nil:
    return nil
  
  var newElifs: seq[tuple[cond: Node, body: Node]] = @[]
  for elifBranch in node.ifElifs:
    let elifCond = self.transform(elifBranch.cond)
    let elifBody = self.transform(elifBranch.body)
    if elifCond != nil and elifBody != nil:
      newElifs.add((cond: elifCond, body: elifBody))
  
  var elseBranch: Node = nil
  if node.ifElse != nil:
    elseBranch = self.transform(node.ifElse)
  
  result = newNode(nkIf)
  result.ifCond = cond
  result.ifThen = thenBranch
  result.ifElifs = newElifs
  result.ifElse = elseBranch
  result.line = node.line
  result.column = node.column

method transformSwitch*(self: AstTransformer, node: Node): Node {.base.} =
  let expr = self.transform(node.switchExpr)
  var newCases: seq[Node] = @[]
  for caseNode in node.switchCases:
    let transformed = self.transform(caseNode)
    if transformed != nil:
      newCases.add(transformed)
  
  var defaultCase: Node = nil
  if node.switchDefault != nil:
    defaultCase = self.transform(node.switchDefault)
  
  result = newNode(nkSwitch)
  result.switchExpr = expr
  result.switchCases = newCases
  result.switchDefault = defaultCase
  result.line = node.line
  result.column = node.column

method transformSwitchCase*(self: AstTransformer, node: Node): Node {.base.} =
  var newConditions: seq[Node] = @[]
  for condition in node.caseConditions:
    let transformed = self.transform(condition)
    if transformed != nil:
      newConditions.add(transformed)
  
  var guard: Node = nil
  if node.caseGuard != nil:
    guard = self.transform(node.caseGuard)
  
  let body = self.transform(node.caseBody)
  
  result = newNode(nkSwitchCase)
  result.caseConditions = newConditions
  result.caseGuard = guard
  result.caseBody = body
  result.line = node.line
  result.column = node.column

method transformFor*(self: AstTransformer, node: Node): Node {.base.} =
  let start = self.transform(node.forRange.start)
  if start == nil:
    return nil
  
  let endExpr = self.transform(node.forRange.endExpr)
  if endExpr == nil:
    return nil
  
  let body = self.transform(node.forBody)
  if body == nil:
    return nil
  
  result = newNode(nkFor)
  result.forVar = node.forVar
  result.forRange = (start: start, inclusive: node.forRange.inclusive, endExpr: endExpr)
  result.forBody = body
  result.line = node.line
  result.column = node.column

method transformEach*(self: AstTransformer, node: Node): Node =
  let eachStart = self.transform(node.eachStart)
  let eachEnd = self.transform(node.eachEnd)
  var step = if node.eachStep != nil: self.transform(node.eachStep) else: nil
  var where = if node.eachWhere != nil: self.transform(node.eachWhere) else: nil
  let body = self.transform(node.eachBody)

  result = newNode(nkEach)
  result.eachVar = node.eachVar
  result.eachStart = eachStart
  result.eachEnd = eachEnd
  result.eachStep = step
  result.eachWhere = where
  result.eachBody = body
  result.line = node.line
  result.column = node.column

method transformWhile*(self: AstTransformer, node: Node): Node {.base.} =
  let cond = self.transform(node.whileCond)
  let body = self.transform(node.whileBody)
  
  result = newNode(nkWhile)
  result.whileCond = cond
  result.whileBody = body
  result.line = node.line
  result.column = node.column

method transformInfinit*(self: AstTransformer, node: Node): Node {.base.} =
  let delay = self.transform(node.infDelay)
  if delay == nil:
    return nil
  
  let body = self.transform(node.infBody)
  if body == nil:
    return nil
  
  result = newNode(nkInfinit)
  result.infDelay = delay
  result.infBody = body
  result.line = node.line
  result.column = node.column

method transformInit(self: AstTransformer, node: Node): Node {.base.} =
  let body = self.transform(node.initBody)
  if body == nil:
    return nil
  
  result = newNode(nkInit)
  result.initBody = body
  result.line = node.line
  result.column = node.column

method transformRepeat*(self: AstTransformer, node: Node): Node {.base.} =
  let count = self.transform(node.repCount)
  if count == nil:
    return nil
  
  let delay = self.transform(node.repDelay)
  if delay == nil:
    return nil
  
  let body = self.transform(node.repBody)
  if body == nil:
    return nil
  
  result = newNode(nkRepeat)
  result.repCount = count
  result.repDelay = delay
  result.repBody = body
  result.line = node.line
  result.column = node.column

method transformTry*(self: AstTransformer, node: Node): Node {.base.} =
  let tryBody = self.transform(node.tryBody)
  if tryBody == nil:
    return nil
  
  let catchBody = self.transform(node.tryCatch)
  if catchBody == nil:
    return nil
  
  result = newNode(nkTry)
  result.tryBody = tryBody
  result.tryErrType = node.tryErrType
  result.tryCatch = catchBody
  result.line = node.line
  result.column = node.column

method transformEvent*(self: AstTransformer, node: Node): Node {.base.} =
  let cond = self.transform(node.evCond)
  if cond == nil:
    return nil
  
  let body = self.transform(node.evBody)
  if body == nil:
    return nil
  
  result = newNode(nkEvent)
  result.evCond = cond
  result.evBody = body
  result.line = node.line
  result.column = node.column

method transformImport*(self: AstTransformer, node: Node): Node {.base.} =
  result = newNode(nkImport)
  result.imports = node.imports
  result.line = node.line
  result.column = node.column

method transformReturn*(self: AstTransformer, node: Node): Node {.base.} =
  var value: Node = nil
  if node.retVal != nil:
    value = self.transform(node.retVal)
  
  result = newNode(nkOutPut)
  result.retVal = value
  result.line = node.line
  result.column = node.column

method transformBinary*(self: AstTransformer, node: Node): Node {.base.} =
  let left = self.transform(node.binLeft)
  if left == nil:
    return nil
  
  let right = self.transform(node.binRight)
  if right == nil:
    return nil
  
  result = newNode(nkBinary)
  result.binOp = node.binOp
  result.binLeft = left
  result.binRight = right
  result.line = node.line
  result.column = node.column

method transformUnary*(self: AstTransformer, node: Node): Node {.base.} =
  let expr = self.transform(node.unExpr)
  if expr == nil:
    return nil
  
  result = newNode(nkUnary)
  result.unOp = node.unOp
  result.unExpr = expr
  result.line = node.line
  result.column = node.column

method transformCall*(self: AstTransformer, node: Node): Node {.base.} =
  let func_expr = self.transform(node.callFunc)
  if func_expr == nil:
    return nil
  
  var newArgs: seq[Node] = @[]
  for arg in node.callArgs:
    let transformed = self.transform(arg)
    if transformed != nil:
      newArgs.add(transformed)
  
  result = newNode(nkCall)
  result.callFunc = func_expr
  result.callArgs = newArgs
  result.line = node.line
  result.column = node.column

method transformProperty*(self: AstTransformer, node: Node): Node {.base.} =
  let obj = self.transform(node.propObj)
  if obj == nil:
    return nil
  
  result = newNode(nkProperty)
  result.propObj = obj
  result.propName = node.propName
  result.line = node.line
  result.column = node.column

method transformGroup*(self: AstTransformer, node: Node): Node {.base.} =
  let expr = self.transform(node.groupExpr)
  if expr == nil:
    return nil
  
  result = newNode(nkGroup)
  result.groupExpr = expr
  result.line = node.line
  result.column = node.column

method transformAssign*(self: AstTransformer, node: Node): Node {.base.} =
  let target = self.transform(node.assignTarget)
  let value = self.transform(node.assignVal)
  
  result = newNode(nkAssign)
  result.declType = node.declType
  result.assignOp = node.assignOp
  result.assignTarget = target
  result.assignVal = value
  
  # Трансформируем свойства
  if node.assignProps.len > 0:
    result.assignProps = @[]
    for prop in node.assignProps:
      result.assignProps.add(self.transform(prop))

  result.line = node.line
  result.column = node.column

method transformIdent*(self: AstTransformer, node: Node): Node {.base.} =
  result = newNode(nkIdent)
  result.ident = node.ident
  result.line = node.line
  result.column = node.column

method transformNumber*(self: AstTransformer, node: Node): Node {.base.} =
  result = newNode(nkNumber)
  result.numVal = node.numVal
  result.line = node.line
  result.column = node.column

method transformBool*(self: AstTransformer, node: Node): Node {.base.} =
  result = newNode(nkBool)
  result.boolVal = node.boolVal
  result.line = node.line
  result.column = node.column

method transformString*(self: AstTransformer, node: Node): Node {.base.} =
  result = newNode(nkString)
  result.strVal = node.strVal
  result.line = node.line
  result.column = node.column

method transformFormatString*(self: AstTransformer, node: Node): Node {.base.} =
  result = newNode(nkFormatString)
  result.formatType = node.formatType
  result.formatContent = node.formatContent
  result.line = node.line
  result.column = node.column

method transformTable*(self: AstTransformer, node: Node): Node {.base.} =
  var newPairs: seq[Node] = @[]
  for pair in node.tablePairs:
    let transformed = self.transform(pair)
    if transformed != nil:
      newPairs.add(transformed)
  
  result = newNode(nkTable)
  result.tablePairs = newPairs
  result.line = node.line
  result.column = node.column

method transformTablePair*(self: AstTransformer, node: Node): Node {.base.} =
  let key = self.transform(node.pairKey)
  let value = self.transform(node.pairValue)
  
  if key == nil or value == nil:
    return nil
  
  result = newNode(nkTablePair)
  result.pairKey = key
  result.pairValue = value
  result.line = node.line
  result.column = node.column

method transformTypeCheck*(self: AstTransformer, node: Node): Node {.base.} =
  result = newNode(nkTypeCheck)
  result.checkType = node.checkType
  result.checkFunc = node.checkFunc
  result.checkExpr = self.transform(node.checkExpr)
  result.line = node.line
  result.column = node.column

method transformArray*(self: AstTransformer, node: Node): Node {.base.} =
  var newElements: seq[Node] = @[]
  for element in node.elements:
    let transformed = self.transform(element)
    if transformed != nil:
      newElements.add(transformed)
  
  result = newNode(nkArray)
  result.elements = newElements
  result.line = node.line
  result.column = node.column

method transformArrayAccess*(self: AstTransformer, node: Node): Node {.base.} =
  result = newNode(nkArrayAccess)
  result.array = self.transform(node.array)
  result.index = self.transform(node.index)

method transformSlice*(self: AstTransformer, node: Node): Node {.base.} =
  result = newNode(nkSlice)
  result.sliceArray = self.transform(node.sliceArray)
  result.startIndex = self.transform(node.startIndex)
  result.endIndex = self.transform(node.endIndex)
  result.inclusive = node.inclusive

method transformTupleAccess*(self: AstTransformer, node: Node): Node {.base.} =
  result = newNode(nkTupleAccess)
  result.tupleObj = self.transform(node.tupleObj)
  result.fieldIndex = node.fieldIndex

method transformRangeExpr*(self: AstTransformer, node: Node): Node {.base.} =
  result = newNode(nkRangeExpr)
  result.rangeStart = self.transform(node.rangeStart)
  result.rangeEnd = self.transform(node.rangeEnd)
  result.rangeStep = self.transform(node.rangeStep)

method transformChainCall*(self: AstTransformer, node: Node): Node {.base.} =
  result = newNode(nkChainCall)
  result.chain = node.chain.mapIt(self.transform(it))

method transformSubscript*(self: AstTransformer, node: Node): Node {.base.} =
  result = newNode(nkSubscript)
  result.container = self.transform(node.container)
  result.indices = node.indices.mapIt(self.transform(it))

method transformNoop*(self: AstTransformer, node: Node): Node {.base.} =
  result = newNode(nkNoop)
  result.line = node.line
  result.column = node.column

method transform*(self: AstTransformer, node: Node): Node {.base.} =
  if node == nil:
    return nil
    
  case node.kind
  of nkProgram:       return self.transformProgram(node)
  of nkBlock:         return self.transformBlock(node)
  of nkExprStmt:      return self.transformExprStmt(node)
  of nkFuncDef:       return self.transformFuncDef(node)
  of nkLambdaDef:     return self.transformLambdaDef(node)
  of nkPackDef:       return self.transformPackDef(node)
  of nkStructDef:     return self.transformStructDef(node)
  of nkEnumDef:       return self.transformEnumDef(node)
  of nkEnumVariant:   return self.transformEnumVariant(node)
  of nkFieldDef:      return self.transformFieldDef(node)
  of nkStructInit:    return self.transformStructInit(node)
  of nkState:         return self.transformState(node)
  of nkStateBody:     return self.transformStateBody(node)
  of nkParam:         return self.transformParam(node)
  of nkIf:            return self.transformIf(node)
  of nkSwitch:        return self.transformSwitch(node)
  of nkSwitchCase:    return self.transformSwitchCase(node)
  of nkInit:          return self.transformInit(node)
  of nkFor:           return self.transformFor(node)
  of nkEach:          return self.transformEach(node)
  of nkInfinit:       return self.transformInfinit(node)
  of nkWhile:         return self.transformWhile(node)
  of nkRepeat:        return self.transformRepeat(node)
  of nkTry:           return self.transformTry(node)
  of nkEvent:         return self.transformEvent(node)
  of nkImport:        return self.transformImport(node)
  of nkOutPut:        return self.transformReturn(node)
  of nkBinary:        return self.transformBinary(node)
  of nkUnary:         return self.transformUnary(node)
  of nkCall:          return self.transformCall(node)
  of nkProperty:      return self.transformProperty(node)
  of nkGroup:         return self.transformGroup(node)
  of nkAssign:        return self.transformAssign(node)
  of nkIdent:         return self.transformIdent(node)
  of nkNumber:        return self.transformNumber(node)
  of nkBool:          return self.transformBool(node)
  of nkString:        return self.transformString(node)
  of nkFormatString:  return self.transformFormatString(node)
  of nkTable:         return self.transformTable(node)
  of nkTablePair:     return self.transformTablePair(node)
  of nkTypeCheck:     return self.transformTypeCheck(node)
  of nkArray:         return self.transformArray(node)
  of nkArrayAccess:   return self.transformArrayAccess(node)
  of nkSlice:         return self.transformSlice(node)
  of nkTupleAccess:   return self.transformTupleAccess(node)
  of nkRangeExpr:     return self.transformRangeExpr(node)
  of nkChainCall:     return self.transformChainCall(node)
  of nkSubscript:     return self.transformSubscript(node)
  of nkNoop:          return self.transformNoop(node)

# Пример конкретного визитора: SymbolCollector
type
  SymbolCollector* = ref object of AstVisitor
    currentScope*: SymbolTable
    errors*: seq[string]

proc newSymbolCollector*(): SymbolCollector =
  result = SymbolCollector(
    currentScope: newSymbolTable(),
    errors: @[]
  )

method visitFuncDef*(self: SymbolCollector, node: Node) =
  # Создаем символ функции
  var paramSymbols: seq[Symbol] = @[]
  for param in node.funcParams:
    let paramSymbol = Symbol(
      name: param.paramName,
      kind: skParameter,
      paramType: param.paramType,
      line: param.line,
      column: param.column
    )
    paramSymbols.add(paramSymbol)
  
  let funcSymbol = Symbol(
    name: node.funcName,
    kind: skFunction,
    params: paramSymbols,
    returnType: node.funcRetType,
    modifiers: node.funcMods,
    line: node.line,
    column: node.column
  )
  
  # Добавляем функцию в текущую область видимости
  if not self.currentScope.define(funcSymbol):
    self.errors.add(fmt"Function '{node.funcName}' already defined at line {node.line}, column {node.column}")
    return
  
  # Создаем новую область видимости для тела функции
  let previousScope = self.currentScope
  self.currentScope = newSymbolTable(previousScope)
  
  # Добавляем параметры в область видимости функции
  for param in paramSymbols:
    discard self.currentScope.define(param)
  
  # Посещаем тело функции
  self.visit(node.funcBody)
  
  # Восстанавливаем предыдущую область видимости
  self.currentScope = previousScope

method visitLambdaDef*(self: SymbolCollector, node: Node) =
  # Создаем символ функции
  var paramSymbols: seq[Symbol] = @[]
  for param in node.lambdaParams:
    let paramSymbol = Symbol(
      name: param.paramName,
      kind: skParameter,
      paramType: param.paramType,
      line: param.line,
      column: param.column
    )
    paramSymbols.add(paramSymbol)
  
  let lambdaSymbol = Symbol(
    kind: skFunction,
    params: paramSymbols,
    returnType: node.lambdaRetType,
    modifiers: node.lambdaMods,
    line: node.line,
    column: node.column
  )
  
  # Добавляем функцию в текущую область видимости
  if not self.currentScope.define(lambdaSymbol): discard
  
  # Создаем новую область видимости для тела функции
  let previousScope = self.currentScope
  self.currentScope = newSymbolTable(previousScope)
  
  # Добавляем параметры в область видимости функции
  for param in paramSymbols:
    discard self.currentScope.define(param)
  
  # Посещаем тело функции
  self.visit(node.lambdaBody)
  
  # Восстанавливаем предыдущую область видимости
  self.currentScope = previousScope

method visitPackDef*(self: SymbolCollector, node: Node) =
  # Создаем символ пакета
  let packSymbol = Symbol(
    name: node.packName,
    kind: skPack,
    parents: node.packParents,
    packModifiers: node.packMods,
    line: node.line,
    column: node.column
  )
  
  # Добавляем пакет в текущую область видимости
  if not self.currentScope.define(packSymbol):
    self.errors.add(fmt"Pack '{node.packName}' already defined at line {node.line}, column {node.column}")
    return
  
  # Создаем новую область видимости для тела пакета
  let previousScope = self.currentScope
  self.currentScope = newSymbolTable(previousScope)
  
  # Посещаем тело пакета
  self.visit(node.packBody)
  
  # Восстанавливаем предыдущую область видимости
  self.currentScope = previousScope

method visitStructDef*(self: SymbolCollector, node: Node) =
  # Создаем символы полей
  var fieldSymbols: seq[Symbol] = @[]
  for field in node.structFields:
    let fieldSymbol = Symbol(
      name: field.fieldName,
      kind: skField,
      fieldType: field.fieldType,
      fieldDefault: if field.fieldDefault != nil: "has_default" else: "",
      line: field.line,
      column: field.column
    )
    fieldSymbols.add(fieldSymbol)
  
  # Создаем символы методов
  var methodSymbols: seq[Symbol] = @[]
  for meth in node.structMethods:
    var paramSymbols: seq[Symbol] = @[]
    for param in meth.funcParams:
      let paramSymbol = Symbol(
        name: param.paramName,
        kind: skParameter,
        paramType: param.paramType,
        line: param.line,
        column: param.column
      )
      paramSymbols.add(paramSymbol)
    
    let methodSymbol = Symbol(
      name: meth.funcName,
      kind: skFunction,
      params: paramSymbols,
      returnType: meth.funcRetType,
      modifiers: meth.funcMods,
      line: meth.line,
      column: meth.column
    )
    methodSymbols.add(methodSymbol)
  
  # Создаем символ структуры
  let structSymbol = Symbol(
    name: node.structName,
    kind: skStruct,
    structFields: fieldSymbols,
    structMethods: methodSymbols,
    line: node.line,
    column: node.column
  )
  
  # Добавляем структуру в текущую область видимости
  if not self.currentScope.define(structSymbol):
    self.errors.add(fmt"Struct '{node.structName}' already defined at line {node.line}, column {node.column}")
    return
  
  # Посещаем поля и методы для дальнейшего анализа
  for field in node.structFields:
    self.visit(field)
  for meth in node.structMethods:
    self.visit(meth)

method visitEnumDef*(self: SymbolCollector, node: Node) =
  # Создаем символы вариантов
  var variantSymbols: seq[Symbol] = @[]
  for variant in node.enumVariants:
    let variantSymbol = Symbol(
      name: variant.variantName,
      kind: skVariable,
      varType: node.enumName,
      isConst: true,
      line: variant.line,
      column: variant.column
    )
    variantSymbols.add(variantSymbol)
  
  # Создаем символы методов
  var methodSymbols: seq[Symbol] = @[]
  for meth in node.enumMethods:
    var paramSymbols: seq[Symbol] = @[]
    for param in meth.funcParams:
      let paramSymbol = Symbol(
        name: param.paramName,
        kind: skParameter,
        paramType: param.paramType,
        line: param.line,
        column: param.column
      )
      paramSymbols.add(paramSymbol)
    
    let methodSymbol = Symbol(
      name: meth.funcName,
      kind: skFunction,
      params: paramSymbols,
      returnType: meth.funcRetType,
      modifiers: meth.funcMods,
      line: meth.line,
      column: meth.column
    )
    methodSymbols.add(methodSymbol)
  
  # Создаем символ перечисления
  let enumSymbol = Symbol(
    name: node.enumName,
    kind: skEnum,
    enumVariants: variantSymbols,
    enumMethods: methodSymbols,
    line: node.line,
    column: node.column
  )
  
  # Добавляем перечисление в текущую область видимости
  if not self.currentScope.define(enumSymbol):
    self.errors.add(fmt"Enum '{node.enumName}' already defined at line {node.line}, column {node.column}")
    return
  
  # Посещаем варианты и методы
  for variant in node.enumVariants:
    self.visit(variant)
  for meth in node.enumMethods:
    self.visit(meth)

method visitAssign*(self: SymbolCollector, node: Node) =
  # Проверяем, является ли целью присваивания идентификатор
  if node.assignTarget.kind == nkIdent:
    let name = node.assignTarget.ident
    
    # Проверяем, существует ли переменная в текущей области видимости
    if self.currentScope.resolve(name).isNone:
      # Создаем новый символ переменной
      let varSymbol = Symbol(
        name: name,
        kind: skVariable,
        varType: "", # Тип будет определен позже при анализе типов
        isConst: false,
        line: node.assignTarget.line,
        column: node.assignTarget.column
      )
      
      # Добавляем переменную в текущую область видимости
      discard self.currentScope.define(varSymbol)
  
  # Посещаем целевой узел и значение
  self.visit(node.assignTarget)
  self.visit(node.assignVal)

method visitIdent*(self: SymbolCollector, node: Node) =
  # Проверяем, существует ли идентификатор в текущей области видимости
  let name = node.ident
  if self.currentScope.resolve(name).isNone:
    # Это может быть ошибкой, если идентификатор используется до объявления
    # Но мы не добавляем ошибку здесь, так как это может быть глобальная переменная
    # или идентификатор из импортированного модуля
    discard

# Пример использования
proc analyzeAst*(ast: Node): seq[string] =
  let collector = newSymbolCollector()
  collector.visit(ast)
  return collector.errors

# Функция для красивого вывода AST
proc `$`*(node: Node): string =
  if node == nil:
    return "nil"
  
  case node.kind
  of nkProgram:
    result = "Program:\n"
    for stmt in node.stmts:
      result.add("  " & ($stmt).replace("\n", "\n  ") & "\n")
  
  of nkBlock:
    result = "Block:\n"
    for stmt in node.blockStmts:
      result.add("  " & ($stmt).replace("\n", "\n  ") & "\n")
  
  of nkExprStmt:
    result = "ExprStmt: " & $node.expr
  
  of nkFuncDef:
    result = "FuncDef: " & node.funcName & "("
    for i, param in node.funcParams:
      if i > 0: result.add(", ")
      result.add($param)
    result.add(")")
    if node.funcRetType.len > 0:
      result.add(":" & node.funcRetType)
    if node.funcMods.len > 0:
      result.add(" !" & node.funcMods.join("|"))
    result.add("\n  " & ($node.funcBody).replace("\n", "\n  "))
  
  of nkLambdaDef:
    result = "LambdaDef: " & "("
    for i, param in node.lambdaParams:
      if i > 0: result.add(", ")
      result.add($param)
    result.add(")")
    if node.lambdaRetType.len > 0:
      result.add(":" & node.lambdaRetType)
    if node.lambdaMods.len > 0:
      result.add(" !" & node.lambdaMods.join("|"))
    result.add("\n  " & ($node.lambdaBody).replace("\n", "\n  "))

  of nkPackDef:
    result = "PackDef: " & node.packName
    if node.packParents.len > 0:
      result.add(" <- " & node.packParents.join("|"))
    if node.packMods.len > 0:
      result.add(" !" & node.packMods.join("|"))
    result.add("\n  " & ($node.packBody).replace("\n", "\n  "))

  of nkStructDef:
    result = fmt"Struct '{node.structName}':\n"
    if node.structFields.len > 0:
      result.add("  Fields:\n")
      for i, field in node.structFields:
        result.add("    [" & $i & "] " & ($field).replace("\n", "\n    ") & "\n")
    if node.structMethods.len > 0:
      result.add("  Methods:\n")
      for i, meth in node.structMethods:
        result.add("    [" & $i & "] " & ($meth).replace("\n", "\n    ") & "\n")
  
  of nkEnumDef:
    result = fmt"Enum '{node.enumName}':\n"
    if node.enumVariants.len > 0:
      result.add("  Variants:\n")
      for i, variant in node.enumVariants:
        result.add("    [" & $i & "] " & ($variant).replace("\n", "\n    ") & "\n")
    if node.enumMethods.len > 0:
      result.add("  Methods:\n")
      for i, meth in node.enumMethods:
        result.add("    [" & $i & "] " & ($meth).replace("\n", "\n    ") & "\n")
  
  of nkEnumVariant:
    result = fmt"EnumVariant '{node.variantName}'"
    if node.variantValue != nil:
      result.add(" = " & ($node.variantValue).replace("\n", "\n  "))
  
  of nkFieldDef:
    result = fmt"Field '{node.fieldName}': {node.fieldType}"
    if node.fieldDefault != nil:
      result.add(" = " & ($node.fieldDefault).replace("\n", "\n  "))
  
  of nkStructInit:
    result = fmt"StructInit '{node.structType}':\n"
    for i, arg in node.structArgs:
      result.add("  [" & $i & "] " & ($arg).replace("\n", "\n  ") & "\n")

  of nkParam:
    result = node.paramName
    if node.paramType.len > 0:
      result.add(": " & node.paramType)
  
  of nkIf:
    result = "If: " & $node.ifCond & "\n"
    result.add("  Then: " & ($node.ifThen).replace("\n", "\n  ") & "\n")
    for elifBranch in node.ifElifs:
      result.add("  Elif: " & $elifBranch.cond & "\n")
      result.add("    " & ($elifBranch.body).replace("\n", "\n    ") & "\n")
    if node.ifElse != nil:
      result.add("  Else: " & ($node.ifElse).replace("\n", "\n  "))

  of nkInit:
    result = "Init:\n"
    result.add(" " & ($node.initBody).replace("\n", "\n "))

  of nkFor:
    result = "For: " & node.forVar & " in "
    result.add($node.forRange.start & ".." & (if node.forRange.inclusive: "." else: "") & $node.forRange.endExpr & "\n")
    result.add("  " & ($node.forBody).replace("\n", "\n  "))

  of nkInfinit:
    result = "Infinit: " & $node.infDelay & "\n"
    result.add("  " & ($node.infBody).replace("\n", "\n  "))
  
  of nkRepeat:
    result = "Repeat: " & $node.repCount & " " & $node.repDelay & "\n"
    result.add("  " & ($node.repBody).replace("\n", "\n  "))
  
  of nkTry:
    result = "Try:\n"
    result.add("  " & ($node.tryBody).replace("\n", "\n  ") & "\n")
    result.add("  Elerr")
    if node.tryErrType.len > 0:
      result.add(" " & node.tryErrType)
    result.add(":\n")
    result.add("    " & ($node.tryCatch).replace("\n", "\n    "))
  
  of nkEvent:
    result = "Event: " & $node.evCond & "\n"
    result.add("  " & ($node.evBody).replace("\n", "\n  "))

  of nkImport:
    result = "Import: " & node.imports.join(", ")
  
  of nkOutPut:
    result = "Return"
    if node.retVal != nil:
      result.add(": " & $node.retVal)
  
  of nkBinary:
    result = "Binary: " & $node.binOp & "\n"
    result.add("  Left: " & ($node.binLeft).replace("\n", "\n  ") & "\n")
    result.add("  Right: " & ($node.binRight).replace("\n", "\n  "))
  
  of nkUnary:
    result = "Unary: " & $node.unOp & "\n"
    result.add("  Expr: " & ($node.unExpr).replace("\n", "\n  "))
  
  of nkCall:
    result = "Call: " & $node.callFunc & "("
    for i, arg in node.callArgs:
      if i > 0: result.add(", ")
      result.add($arg)
    result.add(")")
  
  of nkProperty:
    result = "Property: " & $node.propObj & "." & node.propName
  
  of nkGroup:
    result = "Group: (" & $node.groupExpr & ")"
  
  of nkAssign:
    result = "Assign:\n"
    result.add("  Target: " & ($node.assignTarget).replace("\n", "\n  ") & "\n")
    result.add("  Value: " & ($node.assignVal).replace("\n", "\n  "))

  of nkTypeCheck:
    result = "Type Check:\n"
    result.add(" Type: " & node.checkType & "\n")
    result.add(" Function: " & node.checkFunc & "\n")
    if node.checkExpr != nil:
      result.add(" Expression:\n")
      result.add(" " & ($node.checkExpr).replace("\n", "\n "))

  of nkIdent:
    result = "Ident: " & node.ident
  
  of nkNumber:
    result = "Number: " & $node.numVal

  of nkBool:
    result = "Bool: " & $node.boolVal

  of nkString:
    result = "String: \"" & node.strVal & "\""

  of nkFormatString:
    result = "FormatString: " & node.formatType & "(\"" & node.formatContent & "\")"

  of nkTable:
    result = "Table:\n"
    for i, pair in node.tablePairs:
      result.add("  [" & $i & "] " & ($pair).replace("\n", "\n  ") & "\n")
  
  of nkTablePair:
    result = "TablePair:\n"
    result.add("  Key: " & ($node.pairKey).replace("\n", "\n  ") & "\n")
    result.add("  Value: " & ($node.pairValue).replace("\n", "\n  "))
  
  of nkArray:
    result = "Array: " & $node.elements

  of nkNoop:
    result = "Noop"

  else: result = " "

type
  ConstantFolder* = ref object of AstTransformer

proc newConstantFolder*(): ConstantFolder =
  ConstantFolder()

method transformBinary*(self: ConstantFolder, node: Node): Node =
  # Сначала трансформируем левую и правую части
  let left = self.transform(node.binLeft)
  let right = self.transform(node.binRight)
  
  # возвращаем новый узел с трансформированными частями
  result = newNode(nkBinary)
  result.binOp = node.binOp
  result.binLeft = left
  result.binRight = right
  result.line = node.line
  result.column = node.column

method transformUnary*(self: ConstantFolder, node: Node): Node =
  # Трансформируем выражение
  let expr = self.transform(node.unExpr)
  
  # возвращаем новый узел с трансформированным выражением
  result = newNode(nkUnary)
  result.unOp = node.unOp
  result.unExpr = expr
  result.line = node.line
  result.column = node.column

# Пример использования ConstantFolder
proc foldConstants*(ast: Node): Node =
  let folder = newConstantFolder()
  return folder.transform(ast)

# Пример трансформера AST: DeadCodeEliminator
type
  DeadCodeEliminator* = ref object of AstTransformer

proc newDeadCodeEliminator*(): DeadCodeEliminator =
  DeadCodeEliminator()

method transformIf*(self: DeadCodeEliminator, node: Node): Node =
  # Сначала трансформируем условие
  let cond = self.transform(node.ifCond)
  
  # Если условие - булевый литерал, можем выполнить оптимизацию
  #[ #[ оптимизация не работает на время отладки ]#
  if cond.kind == nkBool:
    if cond.boolValue:
      # Условие всегда истинно, возвращаем только блок then
      return self.transform(node.ifThen)
    else:
      # Условие всегда ложно
      if node.ifElse != nil:
        # Если есть блок else, возвращаем его
        return self.transform(node.ifElse)
      else:
        # Если нет блока else, возвращаем пустой блок
        let result = newNode(nkBlock)
        result.blockStmts = @[]
        result.line = node.line
        result.column = node.column
        return result
  ]#

  # Если не можем оптимизировать, выполняем обычную трансформацию
  return procCall self.AstTransformer.transformIf(node)

# Пример использования DeadCodeEliminator
proc eliminateDeadCode*(ast: Node): Node =
  let eliminator = newDeadCodeEliminator()
  return eliminator.transform(ast)

# Функция для проверки типов в AST
proc typeCheck*(ast: Node): seq[string] =
  # Здесь будет реализация проверки типов
  # Это просто заглушка
  result = @[]

# Функция для генерации кода из AST
proc generateCode*(ast: Node): string =
  # Здесь будет реализация генерации кода
  # Это просто заглушка
  result = ""

proc printAST*(node: Node, indent: int = 0) =
  ## Выводит AST в терминал с отступами для визуализации структуры
  if node == nil:
    echo ' '.repeat(indent) & "nil"
    return
  
  let indentStr = ' '.repeat(indent)
  
  case node.kind
  of nkProgram:
    echo indentStr & "Program:"
    for stmt in node.stmts:
      printAST(stmt, indent + 2)
  
  of nkBlock:
    echo indentStr & "Block:"
    for stmt in node.blockStmts:
      printAST(stmt, indent + 2)
  
  of nkFuncDef:
    echo indentStr & "Function: " & node.funcName
    echo indentStr & "  Parameters:"
    for param in node.funcParams:
      echo indentStr & "    " & param.paramName & (if param.paramType.len > 0: ": " & param.paramType else: "")
    if node.funcRetType.len > 0:
      echo indentStr & "  Return Type: " & node.funcRetType
    if node.funcMods.len > 0:
      echo indentStr & "  Modifiers: " & node.funcMods.join(", ")
    echo indentStr & "  Body:"
    printAST(node.funcBody, indent + 4)

  of nkLambdaDef:
    echo indentStr & fmt"Lambda: "
    echo indentStr & "  Parameters:"
    for param in node.lambdaParams:
      echo indentStr & "    " & param.paramName & (if param.paramType.len > 0: ": " & param.paramType else: "")
    if node.lambdaRetType.len > 0:
      echo indentStr & "  Return Type: " & node.lambdaRetType
    if node.lambdaMods.len > 0:
      echo indentStr & "  Modifiers: " & node.lambdaMods.join(", ")
    echo indentStr & "  Body:"
    printAST(node.lambdaBody, indent + 4)

  of nkPackDef:
    echo indentStr & "Pack: " & node.packName
    if node.packParents.len > 0:
      echo indentStr & "  Parents: " & node.packParents.join(", ")
    if node.packMods.len > 0:
      echo indentStr & "  Modifiers: " & node.packMods.join(", ")
    echo indentStr & "  Body:"
    printAST(node.packBody, indent + 4)

  of nkStructDef:
    echo indentStr & fmt"Struct: {node.structName}"
    if node.structFields.len > 0:
      echo indentStr & "  Fields:"
      for field in node.structFields:
        printAST(field, indent + 2)
    if node.structMethods.len > 0:
      echo indentStr & "  Methods:"
      for meth in node.structMethods:
        printAST(meth, indent + 2)
  
  of nkEnumDef:
    echo indentStr & fmt"Enum: {node.enumName}"
    if node.enumVariants.len > 0:
      echo indentStr & "  Variants:"
      for variant in node.enumVariants:
        printAST(variant, indent + 2)
    if node.enumMethods.len > 0:
      echo indentStr & "  Methods:"
      for meth in node.enumMethods:
        printAST(meth, indent + 2)
  
  of nkEnumVariant:
    echo indentStr & fmt"Variant: {node.variantName}"
    if node.variantValue != nil:
      echo indentStr & "  Value:"
      printAST(node.variantValue, indent + 2)
  
  of nkFieldDef:
    echo indentStr & fmt"Field: {node.fieldName}: {node.fieldType}"
    if node.fieldDefault != nil:
      echo indentStr & "  Default:"
      printAST(node.fieldDefault, indent + 2)
  
  of nkStructInit:
    echo indentStr & fmt"StructInit: {node.structType}"
    echo indentStr & "  Arguments:"
    for arg in node.structArgs:
      printAST(arg, indent + 2)

  of nkState:
    echo indentStr & "State: " & node.stateName
    echo indentStr & "  Body:"
    printAST(node.stateBody, indent + 4)
    
  of nkStateBody:
    for meth in node.stateMethods:
      printAST(meth, indent)
    for variable in node.stateVars:
      printAST(variable, indent)
    for watcher in node.stateWatchers:
      printAST(watcher, indent)
    
  of nkIf:
    echo indentStr & "If Statement:"
    echo indentStr & "  Condition:"
    printAST(node.ifCond, indent + 4)
    echo indentStr & "  Then:"
    printAST(node.ifThen, indent + 4)
    
    for i, elifBranch in node.ifElifs:
      echo indentStr & "  Elif " & $i & ":"
      echo indentStr & "    Condition:"
      printAST(elifBranch.cond, indent + 6)
      echo indentStr & "    Body:"
      printAST(elifBranch.body, indent + 6)
    
    if node.ifElse != nil:
      echo indentStr & "  Else:"
      printAST(node.ifElse, indent + 4)
  
  of nkFor:
    echo indentStr & "For Loop:"
    echo indentStr & "  Variable: " & node.forVar
    echo indentStr & "  Range:"
    echo indentStr & "    Start:"
    printAST(node.forRange.start, indent + 6)
    echo indentStr & "    End:"
    printAST(node.forRange.endExpr, indent + 6)
    echo indentStr & "    Inclusive: " & $node.forRange.inclusive
    echo indentStr & "  Body:"
    printAST(node.forBody, indent + 4)

  of nkEach:
    echo indentStr & "Each Loop:"
    echo indentStr & "  Variable: " & node.eachVar
    echo indentStr & "  Start:"
    printAST(node.eachStart, indent + 4)
    echo indentStr & "  End:"
    printAST(node.eachEnd, indent + 4)
    if node.eachStep != nil:
      echo indentStr & "  Step:"
      printAST(node.eachStep, indent + 4)
    if node.eachWhere != nil:
      echo indentStr & "  Where:"
      printAST(node.eachWhere, indent + 4)
    echo indentStr & "  Body:"
    printAST(node.eachBody, indent + 4)

  of nkWhile:
    echo indentStr & "While Loop:"
    echo indentStr & "  Condition:"
    printAST(node.whileCond, indent + 4)
    echo indentStr & "  Body:"
    printAST(node.whileBody, indent + 4)

  of nkInfinit:
    echo indentStr & "Infinit Loop:"
    echo indentStr & "  Delay:"
    printAST(node.infDelay, indent + 4)
    echo indentStr & "  Body:"
    printAST(node.infBody, indent + 4)
  
  of nkRepeat:
    echo indentStr & "Repeat Loop:"
    echo indentStr & "  Count:"
    printAST(node.repCount, indent + 4)
    echo indentStr & "  Delay:"
    printAST(node.repDelay, indent + 4)
    echo indentStr & "  Body:"
    printAST(node.repBody, indent + 4)
  
  of nkTry:
    echo indentStr & "Try-Elerr Statement:"
    echo indentStr & "  Try Body:"
    printAST(node.tryBody, indent + 4)
    if node.tryErrType.len > 0:
      echo indentStr & "  Error Type: " & node.tryErrType
    echo indentStr & "  Catch Body:"
    printAST(node.tryCatch, indent + 4)
  
  of nkEvent:
    echo indentStr & "Event Statement:"
    echo indentStr & "  Condition:"
    printAST(node.evCond, indent + 4)
    echo indentStr & "  Body:"
    printAST(node.evBody, indent + 4)

  of nkTable:
    echo indentStr & "Table:"
    for i, pair in node.tablePairs:
      echo indentStr & "  Pair " & $i & ":"
      printAST(pair, indent + 4)
  
  of nkTablePair:
    echo indentStr & "Table Pair:"
    echo indentStr & "  Key:"
    printAST(node.pairKey, indent + 4)
    echo indentStr & "  Value:"
    printAST(node.pairValue, indent + 4)

  of nkImport:
    echo indentStr & "Import Statement:"
    for imp in node.imports:
      let path = imp.path.join(".")
      if imp.filter.len > 0:
        if imp.filter[0] == "*":
          echo indentStr & "  " & path & " (all)"
        else:
          echo indentStr & "  " & path & " (" & imp.filter.join(", ") & ")"
      else:
        echo indentStr & "  " & path
  
  of nkOutPut:
    echo indentStr & "Return Statement:"
    if node.retVal != nil:
      printAST(node.retVal, indent + 2)
    else:
      echo indentStr & "  <no value>"
  
  of nkExprStmt:
    echo indentStr & "Expression Statement:"
    printAST(node.expr, indent + 2)
  
  of nkAssign:
    echo indentStr & "Assignment:"
    echo indentStr & "  Target:"
    printAST(node.assignTarget, indent + 4)
    echo indentStr & "  Operator: " & node.assignOp
    echo indentStr & "  DeclType: " & $node.declType
    echo indentStr & "  varType: " & node.varType
    echo indentStr & "  varTypeModifier: " & node.varTypeModifier
    echo indentStr & "  Value:"
    printAST(node.assignVal, indent + 4)
    if node.assignProps.len > 0:
      echo indentStr & "  Type Check:"
      for prop in node.assignProps:
        # Добавляем проверку типа узла
        case prop.kind
        of nkIdent:
          echo indentStr & "    " & prop.ident
        of nkTypeCheck:
          echo indentStr & "    <" & prop.checkType & ":" & prop.checkFunc & ">"
        else:
          echo indentStr & "    Unknown type property"

  of nkBinary:
    echo indentStr & "Binary Expression:"
    echo indentStr & "  Operator: " & node.binOp
    echo indentStr & "  Left:"
    printAST(node.binLeft, indent + 4)
    echo indentStr & "  Right:"
    printAST(node.binRight, indent + 4)
  
  of nkUnary:
    echo indentStr & "Unary Expression:"
    echo indentStr & "  Operator: " & node.unOp
    echo indentStr & "  Expression:"
    printAST(node.unExpr, indent + 4)
  
  of nkNumber:
    echo indentStr & "Number: " & node.numVal
  
  of nkString:
    echo indentStr & "String: \"" & node.strVal & "\""

  of nkFormatString:
    echo indentStr & "Format String:"
    echo indentStr & "  Formatter: " & node.formatType
    echo indentStr & "  Content: \"" & node.formatContent & "\""

  of nkBool:
    echo indentStr & "Boolean: " & (if node.boolVal: "true" else: "false")
  
  of nkIdent:
    echo indentStr & "Identifier: " & node.ident
  
  of nkCall:
    echo indentStr & "Function Call:"
    echo indentStr & "  Function:"
    printAST(node.callFunc, indent + 4)
    echo indentStr & "  Arguments:"
    for arg in node.callArgs:
      printAST(arg, indent + 4)
  
  of nkProperty:
    echo indentStr & "Property Access:"
    echo indentStr & "  Object:"
    printAST(node.propObj, indent + 4)
    echo indentStr & "  Property: " & node.propName

  of nkTypeCheck:
    echo indentStr & "Type Check:"
    echo indentStr & "  Type: " & node.checkType
    echo indentStr & "  Function: " & node.checkFunc
    if node.checkExpr != nil:
      echo indentStr & "  Expression:"
      printAST(node.checkExpr, indent + 4)

  of nkGroup:
    echo indentStr & "Grouped Expression:"
    printAST(node.groupExpr, indent + 2)
  
  of nkNoop:
    echo indentStr & "No Operation"
  
  else:
    echo indentStr & "Unknown Node Type: " & $node.kind

# Экспортируем все необходимые функции и типы
export
  AstVisitor, AstTransformer, SymbolTable, Symbol, SymbolKind,
  newSymbolTable, define, resolve,
  visit, transform,
  analyzeAst, foldConstants, eliminateDeadCode, typeCheck, generateCode,
  printAST
