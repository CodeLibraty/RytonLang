import std/[tables, strutils, streams, endians]
import librbt
import ../compiler/parser

type
  RBTLoader* = ref object
    instructions*: seq[RBTInstruction]
    functions*: Table[string, RBTFunction]
    classes*: Table[string, RBTClass]
    metadata*: seq[RBTMetadata]
    currentFile*: string

proc newRBTLoader*(): RBTLoader =
  RBTLoader(
    instructions: @[],
    functions: initTable[string, RBTFunction](),
    classes: initTable[string, RBTClass](),
    metadata: @[]
  )

proc loadFromFile*(loader: var RBTLoader, filename: string): bool =
  try:
    let content = readFile(filename)
    loader.currentFile = filename
    
    var stream = newStringStream(content)
    defer: stream.close()
    
    # Читаем заголовок
    let magic = stream.readStr(4)
    if magic != "RBT\0":
      return false
    
    let version = stream.readUint32()
    if version > RBT_VERSION:
      return false
    
    # Читаем секции
    while not stream.atEnd():
      let sectionType = stream.readUint8()
      let sectionSize = stream.readUint32()
      
      case sectionType:
      of 0x01: loader.loadInstructions(stream, sectionSize)
      of 0x02: loader.loadFunctions(stream, sectionSize)
      of 0x03: loader.loadClasses(stream, sectionSize)
      of 0x04: loader.loadVariables(stream, sectionSize)
      of 0x05: loader.loadConstants(stream, sectionSize)
      of 0x06: loader.loadMetadata(stream, sectionSize)
      else: stream.setPosition(stream.getPosition() + sectionSize.int)
    
    return true
  except:
    return false

proc loadInstructions(loader: var RBTLoader, stream: Stream, size: uint32) =
  let endPos = stream.getPosition() + size.int
  
  while stream.getPosition() < endPos:
    var instruction = RBTInstruction()
    instruction.opcode = RBTOpcode(stream.readUint8())
    let operandCount = stream.readUint8()
    
    for i in 0..<operandCount:
      var operand = RBTValue()
      operand.valueType = RBTValueType(stream.readUint8())
      
      case operand.valueType:
      of rvtString:
        let strLen = stream.readUint32()
        operand.val = stream.readStr(strLen.int)
      of rvtInt:
        operand.intVal = stream.readInt64()
      of rvtFloat:
        operand.floatVal = stream.readFloat64()
      of rvtBool:
        operand.boolVal = stream.readBool()
      
      instruction.operands.add(operand)
    
    loader.instructions.add(instruction)

proc loadFunctions(loader: var RBTLoader, stream: Stream, size: uint32) =
  let endPos = stream.getPosition() + size.int
  
  while stream.getPosition() < endPos:
    var function = RBTFunction()
    
    let nameLen = stream.readUint32()
    function.name = stream.readStr(nameLen.int)
    
    let paramCount = stream.readUint8()
    for i in 0..<paramCount:
      var param = RBTParam()
      
      let paramNameLen = stream.readUint32()
      param.name = stream.readStr(paramNameLen.int)
      
      let paramTypeLen = stream.readUint32()
      param.paramType = stream.readStr(paramTypeLen.int)
      
      let hasDefault = stream.readBool()
      if hasDefault:
        param.defaultValue = RBTValue()
        param.defaultValue.valueType = RBTValueType(stream.readUint8())
        case param.defaultValue.valueType:
        of rvtString:
          let strLen = stream.readUint32()
          param.defaultValue.val = stream.readStr(strLen.int)
        of rvtInt:
          param.defaultValue.intVal = stream.readInt64()
        of rvtFloat:
          param.defaultValue.floatVal = stream.readFloat64()
        of rvtBool:
          param.defaultValue.boolVal = stream.readBool()
      
      function.params.add(param)
    
    let retTypeLen = stream.readUint32()
    function.returnType = stream.readStr(retTypeLen.int)
    
    function.visibility = RBTVisibility(stream.readUint8())
    
    let modCount = stream.readUint8()
    for i in 0..<modCount:
      let modLen = stream.readUint32()
      function.modifiers.add(stream.readStr(modLen.int))
    
    loader.functions[function.name] = function

proc loadClasses(loader: var RBTLoader, stream: Stream, size: uint32) =
  let endPos = stream.getPosition() + size.int
  
  while stream.getPosition() < endPos:
    var class = RBTClass()
    
    let nameLen = stream.readUint32()
    class.name = stream.readStr(nameLen.int)
    
    let parentCount = stream.readUint8()
    for i in 0..<parentCount:
      let parentLen = stream.readUint32()
      class.parents.add(stream.readStr(parentLen.int))
    
    let modCount = stream.readUint8()
    for i in 0..<modCount:
      let modLen = stream.readUint32()
      class.modifiers.add(stream.readStr(modLen.int))
    
    let methodCount = stream.readUint16()
    for i in 0..<methodCount:
      var meth = RBTFunction()
      
      let methodNameLen = stream.readUint32()
      meth.name = stream.readStr(methodNameLen.int)
      
      let paramCount = stream.readUint8()
      for j in 0..<paramCount:
        var param = RBTParam()
        
        let paramNameLen = stream.readUint32()
        param.name = stream.readStr(paramNameLen.int)
        
        let paramTypeLen = stream.readUint32()
        param.paramType = stream.readStr(paramTypeLen.int)
        
        meth.params.add(param)
      
      let retTypeLen = stream.readUint32()
      meth.returnType = stream.readStr(retTypeLen.int)
      
      meth.visibility = RBTVisibility(stream.readUint8())
      
      class.methods.add(meth)
    
    loader.classes[class.name] = class

proc loadVariables(loader: var RBTLoader, stream: Stream, size: uint32) =
  let endPos = stream.getPosition() + size.int
  
  while stream.getPosition() < endPos:
    var variable = RBTVariable()
    
    let nameLen = stream.readUint32()
    variable.name = stream.readStr(nameLen.int)
    
    let typeLen = stream.readUint32()
    variable.varType = stream.readStr(typeLen.int)
    
    variable.isConstant = stream.readBool()
    
    variable.value = RBTValue()
    variable.value.valueType = RBTValueType(stream.readUint8())
    
    case variable.value.valueType:
    of rvtString:
      let strLen = stream.readUint32()
      variable.value.val = stream.readStr(strLen.int)
    of rvtInt:
      variable.value.intVal = stream.readInt64()
    of rvtFloat:
      variable.value.floatVal = stream.readFloat64()
    of rvtBool:
      variable.value.boolVal = stream.readBool()
    
    loader.variables[variable.name] = variable

proc loadConstants(loader: var RBTLoader, stream: Stream, size: uint32) =
  let endPos = stream.getPosition() + size.int
  
  while stream.getPosition() < endPos:
    var constant = RBTConstant()
    
    let nameLen = stream.readUint32()
    constant.name = stream.readStr(nameLen.int)
    
    let typeLen = stream.readUint32()
    constant.constType = stream.readStr(typeLen.int)
    
    constant.value = RBTValue()
    constant.value.valueType = RBTValueType(stream.readUint8())
    
    case constant.value.valueType:
    of rvtString:
      let strLen = stream.readUint32()
      constant.value.val = stream.readStr(strLen.int)
    of rvtInt:
      constant.value.intVal = stream.readInt64()
    of rvtFloat:
      constant.value.floatVal = stream.readFloat64()
    of rvtBool:
      constant.value.boolVal = stream.readBool()
    
    loader.constants[constant.name] = constant

proc loadMetadata(loader: var RBTLoader, stream: Stream, size: uint32) =
  let endPos = stream.getPosition() + size.int
  
  while stream.getPosition() < endPos:
    var metadata = RBTMetadata()
    
    let fileLen = stream.readUint32()
    metadata.sourceFile = stream.readStr(fileLen.int)
    
    metadata.line = stream.readInt32()
    metadata.column = stream.readInt32()
    
    let codeLen = stream.readUint32()
    metadata.originalCode = stream.readStr(codeLen.int)
    
    loader.metadata.add(metadata)

proc convertToAST*(loader: RBTLoader): Node =
  result = newNode(nkProgram)
  result.stmts = @[]
  
  # Конвертируем константы
  for constName, rbtConst in loader.constants:
    let constNode = loader.convertConstant(rbtConst)
    result.stmts.add(constNode)
  
  # Конвертируем переменные
  for varName, rbtVar in loader.variables:
    let varNode = loader.convertVariable(rbtVar)
    result.stmts.add(varNode)
  
  # Конвертируем функции
  for funcName, rbtFunc in loader.functions:
    let funcNode = loader.convertFunction(rbtFunc)
    result.stmts.add(funcNode)
  
  # Конвертируем классы
  for className, rbtClass in loader.classes:
    let classNode = loader.convertClass(rbtClass)
    result.stmts.add(classNode)
  
  # Конвертируем инструкции в main блок
  if loader.instructions.len > 0:
    let mainBlock = loader.convertInstructions()
    result.stmts.add(mainBlock)

proc convertConstant(loader: RBTLoader, rbtConst: RBTConstant): Node =
  result = newNode(nkAssign)
  result.declType = dtVal
  result.assignOp = "="
  result.varType = rbtConst.constType
  
  let target = newNode(nkIdent)
  target.ident = rbtConst.name
  result.assignTarget = target
  
  result.assignVal = loader.convertValue(rbtConst.value)

proc convertVariable(loader: RBTLoader, rbtVar: RBTVariable): Node =
  result = newNode(nkAssign)
  result.declType = if rbtVar.isConstant: dtVal else: dtDef
  result.assignOp = "="
  result.varType = rbtVar.varType
  
  let target = newNode(nkIdent)
  target.ident = rbtVar.name
  result.assignTarget = target
  
  result.assignVal = loader.convertValue(rbtVar.value)

proc convertFunction(loader: RBTLoader, rbtFunc: RBTFunction): Node =
  result = newNode(nkFuncDef)
  result.funcName = rbtFunc.name
  result.funcRetType = rbtFunc.returnType
  result.funcMods = rbtFunc.modifiers
  result.funcPublic = rbtFunc.visibility == rvPublic
  result.funcParams = @[]
  result.funcGenericParams = @[]
  
  for param in rbtFunc.params:
    let paramNode = newNode(nkParam)
    paramNode.paramName = param.name
    paramNode.paramType = param.paramType
    
    if param.defaultValue != nil:
      paramNode.paramDefault = loader.convertValue(param.defaultValue)
    
    result.funcParams.add(paramNode)
  
  result.funcBody = newNode(nkBlock)
  result.funcBody.blockStmts = @[]

proc convertClass(loader: RBTLoader, rbtClass: RBTClass): Node =
  result = newNode(nkPackDef)
  result.packName = rbtClass.name
  result.packMods = rbtClass.modifiers
  result.packParents = rbtClass.parents
  result.packGenericParams = @[]
  
  result.packBody = newNode(nkBlock)
  result.packBody.blockStmts = @[]
  
  for meth in rbtClass.methods:
    let methodNode = loader.convertMethod(meth)
    result.packBody.blockStmts.add(methodNode)

proc convertMethod(loader: RBTLoader, rbtMethod: RBTFunction): Node =
  result = newNode(nkFuncDef)
  result.funcName = rbtMethod.name
  result.funcRetType = rbtMethod.returnType
  result.funcMods = @[]
  result.funcPublic = rbtMethod.visibility == rvPublic
  result.funcParams = @[]
  result.funcGenericParams = @[]
  
  for param in rbtMethod.params:
    let paramNode = newNode(nkParam)
    paramNode.paramName = param.name
    paramNode.paramType = param.paramType
    result.funcParams.add(paramNode)
  
  result.funcBody = newNode(nkBlock)
  result.funcBody.blockStmts = @[]

proc convertValue(loader: RBTLoader, value: RBTValue): Node =
  case value.valueType:
  of rvtString:
    result = newNode(nkString)
    result.strVal = value.val
  of rvtInt:
    result = newNode(nkNumber)
    result.numVal = $value.intVal
  of rvtFloat:
    result = newNode(nkNumber)
    result.numVal = $value.floatVal
  of rvtBool:
    result = newNode(nkBool)
    result.boolVal = value.boolVal

proc convertInstructions(loader: RBTLoader): Node =
  result = newNode(nkBlock)
  result.blockStmts = @[]
  
  var i = 0
  while i < loader.instructions.len:
    let instruction = loader.instructions[i]
    let stmtNode = loader.convertInstruction(instruction, i)
    if stmtNode != nil:
      result.blockStmts.add(stmtNode)
    inc i

proc convertInstruction(loader: RBTLoader, instruction: RBTInstruction, index: int): Node =
  case instruction.opcode:
  of ropCreateVar:
    result = newNode(nkAssign)
    result.declType = dtDef
    result.assignOp = "="
    
    let target = newNode(nkIdent)
    target.ident = instruction.operands[0].val
    result.assignTarget = target
    
    result.varType = instruction.operands[1].val
    result.assignVal = loader.convertValue(instruction.operands[2])
  
  of ropCreateConst:
    result = newNode(nkAssign)
    result.declType = dtVal
    result.assignOp = "="
    
    let target = newNode(nkIdent)
    target.ident = instruction.operands[0].val
    result.assignTarget = target
    
    result.varType = instruction.operands[1].val
    result.assignVal = loader.convertValue(instruction.operands[2])
  
  of ropAssign:
    result = newNode(nkAssign)
    result.declType = dtNone
    result.assignOp = "="
    
    let target = newNode(nkIdent)
    target.ident = instruction.operands[0].val
    result.assignTarget = target
    
    result.assignVal = loader.convertValue(instruction.operands[1])
  
  of ropCall:
    result = newNode(nkCall)
    
    let funcName = newNode(nkIdent)
    funcName.ident = instruction.operands[0].val
    result.callFunc = funcName
    
    result.callArgs = @[]
    for i in 1..<instruction.operands.len:
      result.callArgs.add(loader.convertValue(instruction.operands[i]))
  
  of ropReturn:
    result = newNode(nkReturn)
    if instruction.operands.len > 0:
      result.retVal = loader.convertValue(instruction.operands[0])
  
  of ropAdd:
    result = newNode(nkBinary)
    result.binOp = "+"
    result.binLeft = loader.convertValue(instruction.operands[0])
    result.binRight = loader.convertValue(instruction.operands[1])
  
  of ropSub:
    result = newNode(nkBinary)
    result.binOp = "-"
    result.binLeft = loader.convertValue(instruction.operands[0])
    result.binRight = loader.convertValue(instruction.operands[1])
  
  of ropMul:
    result = newNode(nkBinary)
    result.binOp = "*"
    result.binLeft = loader.convertValue(instruction.operands[0])
    result.binRight = loader.convertValue(instruction.operands[1])
  
  of ropDiv:
    result = newNode(nkBinary)
    result.binOp = "/"
    result.binLeft = loader.convertValue(instruction.operands[0])
    result.binRight = loader.convertValue(instruction.operands[1])
  
  of ropEq:
    result = newNode(nkBinary)
    result.binOp = "=="
    result.binLeft = loader.convertValue(instruction.operands[0])
    result.binRight = loader.convertValue(instruction.operands[1])
  
  of ropNe:
    result = newNode(nkBinary)
    result.binOp = "!="
    result.binLeft = loader.convertValue(instruction.operands[0])
    result.binRight = loader.convertValue(instruction.operands[1])
  
  of ropLt:
    result = newNode(nkBinary)
    result.binOp = "<"
    result.binLeft = loader.convertValue(instruction.operands[0])
    result.binRight = loader.convertValue(instruction.operands[1])
  
  of ropGt:
    result = newNode(nkBinary)
    result.binOp = ">"
    result.binLeft = loader.convertValue(instruction.operands[0])
    result.binRight = loader.convertValue(instruction.operands[1])
  
  of ropLe:
    result = newNode(nkBinary)
    result.binOp = "<="
    result.binLeft = loader.convertValue(instruction.operands[0])
    result.binRight = loader.convertValue(instruction.operands[1])
  
  of ropGe:
    result = newNode(nkBinary)
    result.binOp = ">="
    result.binLeft = loader.convertValue(instruction.operands[0])
    result.binRight = loader.convertValue(instruction.operands[1])
  
  of ropAnd:
    result = newNode(nkBinary)
    result.binOp = "and"
    result.binLeft = loader.convertValue(instruction.operands[0])
    result.binRight = loader.convertValue(instruction.operands[1])
  
  of ropOr:
    result = newNode(nkBinary)
    result.binOp = "or"
    result.binLeft = loader.convertValue(instruction.operands[0])
    result.binRight = loader.convertValue(instruction.operands[1])
  
  of ropNot:
    result = newNode(nkUnary)
    result.unOp = "not"
    result.unExpr = loader.convertValue(instruction.operands[0])
  
  of ropNeg:
    result = newNode(nkUnary)
    result.unOp = "-"
    result.unExpr = loader.convertValue(instruction.operands[0])
  
  of ropCreateFunction:
    result = newNode(nkFuncDef)
    result.funcName = instruction.operands[0].val
    result.funcRetType = instruction.operands[1].val
    result.funcPublic = instruction.operands[2].boolVal
    result.funcParams = @[]
    result.funcGenericParams = @[]
    result.funcMods = @[]
    
    result.funcBody = newNode(nkBlock)
    result.funcBody.blockStmts = @[]
  
  of ropCreateClass:
    result = newNode(nkPackDef)
    result.packName = instruction.operands[0].val
    result.packParents = @[]
    result.packMods = @[]
    result.packGenericParams = @[]
    
    result.packBody = newNode(nkBlock)
    result.packBody.blockStmts = @[]
  
  of ropCreateObject:
    result = newNode(nkCall)
    
    let className = newNode(nkIdent)
    className.ident = instruction.operands[0].val
    result.callFunc = className
    
    result.callArgs = @[]
    for i in 1..<instruction.operands.len:
      result.callArgs.add(loader.convertValue(instruction.operands[i]))
  
  of ropGetProperty:
    result = newNode(nkProperty)
    result.propObj = loader.convertValue(instruction.operands[0])
    result.propName = instruction.operands[1].val
  
  of ropSetProperty:
    result = newNode(nkAssign)
    result.declType = dtNone
    result.assignOp = "="
    
    let propAccess = newNode(nkProperty)
    propAccess.propObj = loader.convertValue(instruction.operands[0])
    propAccess.propName = instruction.operands[1].val
    result.assignTarget = propAccess
    
    result.assignVal = loader.convertValue(instruction.operands[2])
  
  of ropEvent:
    result = newNode(nkEvent)
    result.evCond = loader.convertValue(instruction.operands[0])
    result.evBody = newNode(nkBlock)
    result.evBody.blockStmts = @[]
  
  of ropState:
    result = newNode(nkState)
    result.stateName = instruction.operands[0].val
    result.stateBody = newNode(nkBlock)
    result.stateBody.blockStmts = @[]
  
  of ropSwitch:
    result = newNode(nkSwitch)
    result.switchExpr = loader.convertValue(instruction.operands[0])
    result.switchCases = @[]
    result.switchDefault = nil
  
  of ropCase:
    result = newNode(nkSwitchCase)
    result.caseConditions = @[loader.convertValue(instruction.operands[0])]
    result.caseBody = newNode(nkBlock)
    result.caseBody.blockStmts = @[]
    result.caseGuard = nil
  
  of ropJump, ropJumpIf, ropLabel:
    # Эти инструкции не конвертируются напрямую в AST
    # Они используются для управления потоком выполнения
    result = nil
  
  of ropLoadVar:
    result = newNode(nkIdent)
    result.ident = instruction.operands[0].val
  
  of ropLoadConst:
    result = loader.convertValue(instruction.operands[0])
  
  of ropStoreVar:
    result = newNode(nkAssign)
    result.declType = dtNone
    result.assignOp = "="
    
    let target = newNode(nkIdent)
    target.ident = instruction.operands[0].val
    result.assignTarget = target
    
    result.assignVal = loader.convertValue(instruction.operands[1])
  
  of ropNoop:
    result = newNode(nkNoop)

proc executeRBTFile*(filename: string): bool =
  var loader = newRBTLoader()
  
  if not loader.loadFromFile(filename):
    echo "Failed to load RBT file: ", filename
    return false
  
  let ast = loader.convertToAST()
  
  var codegen = newCodeGenerator()
  let nimCode = codegen.generateProgram(ast)
  
  let tempNimFile = filename.changeFileExt(".nim")
  writeFile(tempNimFile, nimCode)
  
  let compileCmd = "nim c -r --hints:off " & tempNimFile
  let result = execShellCmd(compileCmd)
  
  return result == 0
