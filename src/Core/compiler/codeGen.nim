import std/[strutils, strformat, json]
import ../bytecode/librbt
import parser

type
  BTGenerator* = ref object
    rbtBuilder*: RBTBuilder
    currentFile*: string
    statements*: seq[JsonNode]

proc newBTGenerator*(filename: string): BTGenerator =
  result = BTGenerator(
    rbtBuilder: createRBTGenerator(),
    currentFile: filename,
    statements: @[]
  )

proc generateExpression(self: var BTGenerator, node: Node): JsonNode
proc generateStatement(self: var BTGenerator, node: Node): JsonNode
proc generateBlock(self: var BTGenerator, node: Node): JsonNode

proc generateBlock(self: var BTGenerator, node: Node): JsonNode =
  if node == nil:
    return newJNull()
    
  case node.kind:
  of nkBlock:
    var statements: seq[JsonNode] = @[]
    for stmt in node.blockStmts:
      let stmtNode = self.generateStatement(stmt)
      if not stmtNode.isNil:
        statements.add(stmtNode)
    return self.rbtBuilder.generateBlock(statements)
  else:
    let stmt = self.generateStatement(node)
    return self.rbtBuilder.generateBlock(@[stmt])

proc generateFunction(self: var BTGenerator, node: Node): JsonNode =
  var params: seq[JsonNode] = @[]
  for param in node.funcParams:
    let defaultValue = if param.paramDefault != nil: 
                         self.generateExpression(param.paramDefault) 
                       else: 
                         newJNull()
    params.add(self.rbtBuilder.generateParam(param.paramName, param.paramType, 
                                            $param.paramTypeModifier, defaultValue))
  
  var generics: seq[JsonNode] = @[]
  for generic in node.funcGenericParams:
    var constraints: seq[JsonNode] = @[]
    for constraint in generic.genericConstraints:
      constraints.add(self.rbtBuilder.generateGenericConstraint(constraint.constraintType))
    generics.add(self.rbtBuilder.generateGenericParam(generic.genericName, constraints))
  
  let body = self.generateBlock(node.funcBody)
  
  return self.rbtBuilder.generateFuncDef(node.funcName, params, generics, 
                                         node.funcRetType, $node.funcRetTypeModifier, 
                                         node.funcMods, body, node.funcPublic)

proc generateLambda(self: var BTGenerator, node: Node): JsonNode =
  var params: seq[JsonNode] = @[]
  for param in node.lambdaParams:
    let defaultValue = if param.paramDefault != nil: 
                         self.generateExpression(param.paramDefault) 
                       else: 
                         newJNull()
    params.add(self.rbtBuilder.generateParam(param.paramName, param.paramType, 
                                            $param.paramTypeModifier, defaultValue))
  
  var generics: seq[JsonNode] = @[]
  for generic in node.lambdaGenericParams:
    var constraints: seq[JsonNode] = @[]
    for constraint in generic.genericConstraints:
      constraints.add(self.rbtBuilder.generateGenericConstraint(constraint.constraintType))
    generics.add(self.rbtBuilder.generateGenericParam(generic.genericName, constraints))
  
  let body = self.generateBlock(node.lambdaBody)
  
  return self.rbtBuilder.generateLambdaDef(params, generics, node.lambdaRetType, 
                                          $node.lambdaRetTypeModifier, node.lambdaMods, body)

proc generatePack(self: var BTGenerator, node: Node): JsonNode =
  var generics: seq[JsonNode] = @[]
  for generic in node.packGenericParams:
    var constraints: seq[JsonNode] = @[]
    for constraint in generic.genericConstraints:
      constraints.add(self.rbtBuilder.generateGenericConstraint(constraint.constraintType))
    generics.add(self.rbtBuilder.generateGenericParam(generic.genericName, constraints))
  
  let body = self.generateBlock(node.packBody)
  
  return self.rbtBuilder.generatePackDef(node.packName, generics, node.packParents, 
                                         node.packMods, body)

proc generateStruct(self: var BTGenerator, node: Node): JsonNode =
  var fields: seq[JsonNode] = @[]
  for field in node.structFields:
    let defaultValue = if field.fieldDefault != nil: 
                         self.generateExpression(field.fieldDefault) 
                       else: 
                         newJNull()
    fields.add(self.rbtBuilder.generateFieldDef(field.fieldName, field.fieldType, defaultValue))
  
  var methods: seq[JsonNode] = @[]
  for meth in node.structMethods:
    methods.add(self.generateFunction(meth))
  
  return self.rbtBuilder.generateStructDef(node.structName, fields, methods)

proc generateEnum(self: var BTGenerator, node: Node): JsonNode =
  var variants: seq[JsonNode] = @[]
  for variant in node.enumVariants:
    let value = if variant.variantValue != nil: 
                  self.generateExpression(variant.variantValue) 
                else: 
                  newJNull()
    variants.add(self.rbtBuilder.generateEnumVariant(variant.variantName, value))
  
  var methods: seq[JsonNode] = @[]
  for meth in node.enumMethods:
    methods.add(self.generateFunction(meth))
  
  return self.rbtBuilder.generateEnumDef(node.enumName, variants, methods)

proc generateState(self: var BTGenerator, node: Node): JsonNode =
  let body = self.generateBlock(node.stateBody)
  return self.rbtBuilder.generateState(node.stateName, body)

proc generateImport(self: var BTGenerator, node: Node): JsonNode =
  var imports: seq[JsonNode] = @[]
  for importSpec in node.imports:
    # Создаем JSON для каждого импорта
    let importNode = %*{
      "path": importSpec.path,
      "alias": importSpec.alias,
      "filters": importSpec.filter,
      "items": importSpec.items,
      "isAll": importSpec.isAll
    }
    imports.add(importNode)
  return self.rbtBuilder.generateImport(imports)

proc generateProgram(self: var BTGenerator, node: Node) =
  for stmt in node.stmts:
    var stmtNode: JsonNode
    
    case stmt.kind:
    of nkFuncDef:     stmtNode = self.generateFunction(stmt)
    of nkLambdaDef:   stmtNode = self.generateLambda(stmt)
    of nkPackDef:     stmtNode = self.generatePack(stmt)
    of nkStructDef:   stmtNode = self.generateStruct(stmt)
    of nkEnumDef:     stmtNode = self.generateEnum(stmt)
    of nkState:       stmtNode = self.generateState(stmt)
    of nkImport:      stmtNode = self.generateImport(stmt)
    else:             stmtNode = self.generateStatement(stmt)
    
    if not stmtNode.isNil:
      self.statements.add(stmtNode)

proc generate*(self: var BTGenerator, ast: Node): RBTBuilder =
  case ast.kind:
  of nkProgram:
    self.generateProgram(ast)
  else:
    let stmt = self.generateStatement(ast)
    if not stmt.isNil:
      self.statements.add(stmt)
  
  # Создаем финальную программу
  let program = self.rbtBuilder.generateProgram(self.statements)
  self.rbtBuilder.ast = program
  
  return self.rbtBuilder

proc generateByteCode*(ast: Node, filename: string = "output"): RBTBuilder =
  var generator = newBTGenerator(filename)
  return generator.generate(ast)

proc generateAndSave*(ast: Node, filename: string) =
  var generator = newBTGenerator(filename)
  let builder = generator.generate(ast)
  
  # Устанавливаем метаданные
  discard builder.setMetadata(
    sourceLang = "Ryton",
    sourceLangVersion = "1.0",
    sourceFile = filename & ".ryton",
    outputFile = filename & ".rbt",
    projectName = "RytonProject",
    projectAuthor = "RytonCompiler",
    projectVersion = "1.0.0"
  )
  
  # Генерируем RBT файл
  builder.generateRBTFile(filename & ".rbt")
  
  echo fmt"Bytecode generated: {filename}.rbt"

# Дополнительные утилиты для работы с типами
proc generateTypeCheck(self: var BTGenerator, node: Node): JsonNode =
  let checkExpr = if node.checkExpr != nil: 
                    self.generateExpression(node.checkExpr) 
                  else: 
                    newJNull()
  let checkBlock = if node.checkBlock != nil: 
                     self.generateBlock(node.checkBlock) 
                   else: 
                     newJNull()
  return self.rbtBuilder.generateTypeCheck(node.checkType, node.checkFunc, 
                                           checkBlock, checkExpr)

proc generateSlice(self: var BTGenerator, node: Node): JsonNode =
  let sliceArray = self.generateExpression(node.sliceArray)
  let startIndex = self.generateExpression(node.startIndex)
  let endIndex = self.generateExpression(node.endIndex)
  return self.rbtBuilder.generateSlice(sliceArray, startIndex, endIndex, node.inclusive)

proc generateRangeExpr(self: var BTGenerator, node: Node): JsonNode =
  let rangeStart = self.generateExpression(node.rangeStart)
  let rangeEnd = self.generateExpression(node.rangeEnd)
  let rangeStep = if node.rangeStep != nil: 
                    self.generateExpression(node.rangeStep) 
                  else: 
                    newJNull()
  return self.rbtBuilder.generateRangeExpr(rangeStart, rangeEnd, rangeStep)

proc generateTupleAccess(self: var BTGenerator, node: Node): JsonNode =
  let tupleObj = self.generateExpression(node.tupleObj)
  return self.rbtBuilder.generateTupleAccess(tupleObj, node.fieldIndex)

proc generateChainCall(self: var BTGenerator, node: Node): JsonNode =
  var chain: seq[JsonNode] = @[]
  for chainNode in node.chain:
    chain.add(self.generateExpression(chainNode))
  return self.rbtBuilder.generateChainCall(chain)

proc generateSubscript(self: var BTGenerator, node: Node): JsonNode =
  let container = self.generateExpression(node.container)
  var indices: seq[JsonNode] = @[]
  for index in node.indices:
    indices.add(self.generateExpression(index))
  return self.rbtBuilder.generateSubscript(container, indices)

# Обновляем основную функцию generateExpression
proc generateExpression(self: var BTGenerator, node: Node): JsonNode =
  if node == nil:
    return newJNull()
    
  case node.kind:
  of nkNumber:        return self.rbtBuilder.generateNumber(node.numVal)
  of nkString:        return self.rbtBuilder.generateString(node.strVal)
  of nkBool:          return self.rbtBuilder.generateBool(node.boolVal)
  of nkIdent:         return self.rbtBuilder.generateIdent(node.ident)
  of nkAssign:
    let target = self.generateExpression(node.assignTarget)
    let value = self.generateExpression(node.assignVal)
    let declType = case node.declType:
      of dtDef:  "dtDef"
      of dtVal:  "dtVal" 
      of dtNone: "dtNone"
    return self.rbtBuilder.generateAssign(declType, node.assignOp, target, value, 
                                        node.varType, $node.varTypeModifier)
  of nkBinary:
    let left = self.generateExpression(node.binLeft)
    let right = self.generateExpression(node.binRight)
    return self.rbtBuilder.generateBinary(node.binOp, left, right)
  of nkUnary:
    let expr = self.generateExpression(node.unExpr)
    return self.rbtBuilder.generateUnary(node.unOp, expr)
  of nkCall:
    let funcExpr = self.generateExpression(node.callFunc)
    var args: seq[JsonNode] = @[]
    for arg in node.callArgs:
      args.add(self.generateExpression(arg))
    return self.rbtBuilder.generateCall(funcExpr, args)
  of nkProperty:
    let objExpr = self.generateExpression(node.propObj)
    return self.rbtBuilder.generateProperty(objExpr, node.propName)
  of nkArrayAccess:
    let arrayExpr = self.generateExpression(node.array)
    let indexExpr = self.generateExpression(node.index)
    return self.rbtBuilder.generateArrayAccess(arrayExpr, indexExpr)
  of nkArray:
    var elements: seq[JsonNode] = @[]
    for element in node.elements:
      elements.add(self.generateExpression(element))
    return self.rbtBuilder.generateArray(elements)
  of nkTable:
    var pairs: seq[JsonNode] = @[]
    for pair in node.tablePairs:
      let key = self.generateExpression(pair.pairKey)
      let value = self.generateExpression(pair.pairValue)
      pairs.add(self.rbtBuilder.generateTablePair(key, value))
    return self.rbtBuilder.generateTable(pairs)
  of nkGroup:         return self.rbtBuilder.generateGroup(self.generateExpression(node.groupExpr))
  of nkFormatString:  return self.rbtBuilder.generateFormatString(node.formatType, node.formatContent)
  of nkTypeCheck:     return self.generateTypeCheck(node)
  of nkSlice:         return self.generateSlice(node)
  of nkRangeExpr:     return self.generateRangeExpr(node)
  of nkTupleAccess:   return self.generateTupleAccess(node)
  of nkChainCall:     return self.generateChainCall(node)
  of nkSubscript:     return self.generateSubscript(node)
  else:               return newJNull()

# Функция для генерации Init блоков
proc generateInit(self: var BTGenerator, node: Node): JsonNode =
  var params: seq[JsonNode] = @[]
  for param in node.initParams:
    let defaultValue = if param.paramDefault != nil: 
                         self.generateExpression(param.paramDefault) 
                       else: 
                         newJNull()
    params.add(self.rbtBuilder.generateParam(param.paramName, param.paramType, 
                                            $param.paramTypeModifier, defaultValue))
  
  let body = self.generateBlock(node.initBody)
  return self.rbtBuilder.generateInit(params, body)

# Обновляем generateStatement для поддержки Init
proc generateStatement(self: var BTGenerator, node: Node): JsonNode =
  if node == nil:
    return newJNull()
    
  case node.kind:
  of nkInit:
    return self.generateInit(node)
  of nkAssign:
    let target = self.generateExpression(node.assignTarget)
    let value = self.generateExpression(node.assignVal)
    let declType = case node.declType:
      of dtDef: "dtDef"
      of dtVal: "dtVal"
      of dtNone: "dtNone"
    return self.rbtBuilder.generateAssign(declType, node.assignOp, target, value, 
                                         node.varType, $node.varTypeModifier)
  
  of nkReturn:
    let value = if node.retVal != nil: self.generateExpression(node.retVal) else: newJNull()
    return self.rbtBuilder.generateReturn(value)
  
  of nkIf:
    let condition = self.generateExpression(node.ifCond)
    let thenBranch = self.generateBlock(node.ifThen)
    var elifBranches: seq[tuple[cond: JsonNode, body: JsonNode]] = @[]
    for elifBranch in node.ifElifs:
      let elifCond = self.generateExpression(elifBranch.cond)
      let elifBody = self.generateBlock(elifBranch.body)
      elifBranches.add((cond: elifCond, body: elifBody))
    let elseBranch = if node.ifElse != nil: self.generateBlock(node.ifElse) else: newJNull()
    return self.rbtBuilder.generateIf(condition, thenBranch, elifBranches, elseBranch)
  
  of nkFor:
    let rangeStart = self.generateExpression(node.forRange.start)
    let rangeEnd = if node.forRange.endExpr != nil: 
                     self.generateExpression(node.forRange.endExpr) 
                   else: 
                     newJNull()
    let body = self.generateBlock(node.forBody)
    return self.rbtBuilder.generateFor(node.forVar, rangeStart, rangeEnd, 
                                      node.forRange.inclusive, body)
  
  of nkEach:
    let start = self.generateExpression(node.eachStart)
    let endExpr = self.generateExpression(node.eachEnd)
    let step = if node.eachStep != nil: self.generateExpression(node.eachStep) else: newJNull()
    let where = if node.eachWhere != nil: self.generateExpression(node.eachWhere) else: newJNull()
    let body = self.generateBlock(node.eachBody)
    return self.rbtBuilder.generateEach(node.eachVar, start, endExpr, step, where, body)
  
  of nkWhile:
    let condition = self.generateExpression(node.whileCond)
    let body = self.generateBlock(node.whileBody)
    return self.rbtBuilder.generateWhile(condition, body)
  
  of nkInfinit:
    let delay = self.generateExpression(node.infDelay)
    let body = self.generateBlock(node.infBody)
    return self.rbtBuilder.generateInfinit(delay, body)
  
  of nkRepeat:
    let count = self.generateExpression(node.repCount)
    let delay = self.generateExpression(node.repDelay)
    let body = self.generateBlock(node.repBody)
    return self.rbtBuilder.generateRepeat(count, delay, body)
  
  of nkTry:
    let tryBody = self.generateBlock(node.tryBody)
    let catchBody = self.generateBlock(node.tryCatch)
    return self.rbtBuilder.generateTry(tryBody, node.tryErrType, catchBody)
  
  of nkEvent:
    let condition = self.generateExpression(node.evCond)
    let body = self.generateBlock(node.evBody)
    return self.rbtBuilder.generateEvent(condition, body)
  
  of nkSwitch:
    let expr = self.generateExpression(node.switchExpr)
    var cases: seq[JsonNode] = @[]
    for caseNode in node.switchCases:
      var conditions: seq[JsonNode] = @[]
      for cond in caseNode.caseConditions:
        conditions.add(self.generateExpression(cond))
      let body = self.generateBlock(caseNode.caseBody)
      let guard = if caseNode.caseGuard != nil: 
                    self.generateExpression(caseNode.caseGuard) 
                  else: 
                    newJNull()
      cases.add(self.rbtBuilder.generateSwitchCase(conditions, body, guard))
    let defaultCase = if node.switchDefault != nil: 
                        self.generateBlock(node.switchDefault) 
                      else: 
                        newJNull()
    return self.rbtBuilder.generateSwitch(expr, cases, defaultCase)
  
  of nkExprStmt:
    let expr = self.generateExpression(node.expr)
    return self.rbtBuilder.generateExprStmt(expr)
  
  of nkNoop:
    return self.rbtBuilder.generateNoop()
  
  else:
    return newJNull()
