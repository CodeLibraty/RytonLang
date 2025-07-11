import std/[json, strutils, strformat, tables, sets, os]

type
  RBTNimGenerator* = ref object
    indentLevel: int
    output: string
    currentModule: string
    importedModules: HashSet[string]
    moduleMapping: Table[string, string]
    currentFuncReturnModifier: char
    currentLambdaReturnModifier: char
    inVar: bool
    currentFile: string
    currentNimLine: int
    rytonVersion: string
    rbtData: JsonNode

  RBTException* = object of CatchableError

proc newRBTNimGenerator*(): RBTNimGenerator =
  result = RBTNimGenerator(
    indentLevel: 0,
    output: "",
    currentModule: "main",
    importedModules: initHashSet[string](),
    moduleMapping: initTable[string, string](),
    currentFuncReturnModifier: '\0',
    currentLambdaReturnModifier: '\0',
    inVar: false,
    currentFile: "main.ry",
    currentNimLine: 1,
    rytonVersion: "0.2.4"
  )

proc indent(self: RBTNimGenerator): string =
  return "  ".repeat(self.indentLevel)

proc emitLine(self: var RBTNimGenerator, code: string = "", 
              nodeData: JsonNode = nil, nodeType: string = "", 
              status: string = "ok", extra: string = "") =
  
  if nodeData != nil and nodeType.len > 0:
    let line = if nodeData.hasKey("line"): nodeData["line"].getInt() else: 0
    let column = if nodeData.hasKey("column"): nodeData["column"].getInt() else: 0
    var comment = fmt"# ryton:{self.currentFile}:{line}:{column}|node:{nodeType}|status:{status}"
    if extra.len > 0:
      comment.add(fmt"|{extra}")
    
    self.output.add(self.indent() & comment & "\n")
    inc(self.currentNimLine)
  
  self.output.add(self.indent() & code & "\n")
  inc(self.currentNimLine)

proc increaseIndent(self: var RBTNimGenerator) =
  self.indentLevel += 1

proc decreaseIndent(self: var RBTNimGenerator) =
  if self.indentLevel > 0:
    self.indentLevel -= 1

proc addImport(self: var RBTNimGenerator, moduleName: string) =
  self.importedModules.incl(moduleName)

proc generateImports(self: RBTNimGenerator): string =
  var imports = newSeq[string]()

  for moduleName in self.importedModules:
    if moduleName.len > 0:
      if self.moduleMapping.hasKey(moduleName):
        let mappedModule = self.moduleMapping[moduleName]
        if "." in mappedModule:
          let parts = mappedModule.split(".")
          imports.add(fmt"from {parts[0..^2].join(""/"")} import {parts[^1]}")
        else:
          imports.add(fmt"import {mappedModule}")
      else:
        imports.add(fmt"import {moduleName}")

  if imports.len > 0:
    result = imports.join("\n")

# Forward declarations
proc generateExpression(self: var RBTNimGenerator, node: JsonNode): string
proc generateStatement(self: var RBTNimGenerator, node: JsonNode)
proc generateBlock(self: var RBTNimGenerator, node: JsonNode)

proc generatePackDeclaration(self: var RBTNimGenerator, node: JsonNode)
proc generateMethodDeclaration(self: var RBTNimGenerator, node: JsonNode)
proc generateInitDeclaration(self: var RBTNimGenerator, node: JsonNode)
proc generateLambdaDeclaration(self: var RBTNimGenerator, node: JsonNode)
proc generateIfStatement(self: var RBTNimGenerator, node: JsonNode)

# Utility functions for JSON node processing
proc getNodeKind(node: JsonNode): string =
  if node.hasKey("kind"):
    return node["kind"].getStr()
  return ""

proc getNodeField(node: JsonNode, field: string, default: string = ""): string =
  case node.kind
  of JObject:
    if node.hasKey(field):
      let fieldNode = node[field]
      case fieldNode.kind
      of JString: return fieldNode.getStr()
      of JInt: return $fieldNode.getInt()
      of JFloat: return $fieldNode.getFloat()
      of JBool: return $fieldNode.getBool()
      else: return default
    return default
  of JString: return node.getStr()
  of JInt: return $node.getInt()
  of JFloat: return $node.getFloat()
  of JBool: return $node.getBool()
  else: return default

proc getNodeArray(node: JsonNode, field: string): seq[JsonNode] =
  case node.kind
  of JObject:
    if node.hasKey(field) and node[field].kind == JArray:
      for item in node[field]:
        result.add(item)
  of JArray:
    for item in node:
      result.add(item)

proc getNodeObject(node: JsonNode, field: string): JsonNode =
  if node.hasKey(field):
    return node[field]
  return node  # Возвращаем сам узел если это не объект

# Expression generation
proc generateExpression(self: var RBTNimGenerator, node: JsonNode): string =
  if node == nil or node.kind == JNull:
    return "nil"

  let nodeKind = getNodeKind(node)
  
  case nodeKind
  of "nkLambdaDef":
    let savedOutput = self.output
    self.output = ""
    self.generateLambdaDeclaration(node)
    result = self.output
    self.output = savedOutput

  of "nkIf":
    let savedOutput = self.output
    self.output = ""
    self.inVar = true
    self.generateIfStatement(node)
    self.inVar = false
    result = self.output
    self.output = savedOutput

  of "nkBinary":
    let left = self.generateExpression(getNodeObject(node, "left"))
    let right = self.generateExpression(getNodeObject(node, "right"))
    let op = getNodeField(node, "operator")
    
    let nimOp = case op
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
      else: op

    return fmt"{left} {nimOp} {right}"

  of "nkUnary":
    let expr = self.generateExpression(getNodeObject(node, "expression"))
    let op = getNodeField(node, "operator")
    
    let nimOp = case op
      of "-": "-"
      of "not": "not "
      else: op

    return fmt"{nimOp}({expr})"

  of "nkNumber":
    return getNodeField(node, "value")

  of "nkString":
    let value = getNodeField(node, "value")
    return "\"" & value & "\""

  of "nkFormatString":
    let formatter = getNodeField(node, "formatter")
    let content = getNodeField(node, "content")
    return fmt"""{formatter}"{content}" """

  of "nkBool":
    let value = getNodeField(node, "value")
    return if value == "true": "true" else: "false"

  of "nkIdent":
    return getNodeField(node, "name")

  of "nkCall":
    let callee = self.generateExpression(getNodeObject(node, "function"))
    var args: seq[string] = @[]
    
    for arg in getNodeArray(node, "arguments"):
      args.add(self.generateExpression(arg))

    let argsStr = args.join(", ")
    return fmt"{callee}({argsStr})"

  of "nkProperty":
    let obj = self.generateExpression(getNodeObject(node, "object"))
    let propName = getNodeField(node, "property")
    return fmt"{obj}.{propName}"

  of "nkGroup":
    let expr = self.generateExpression(getNodeObject(node, "expression"))
    return fmt"({expr})"

  of "nkAssign":
    let target = self.generateExpression(getNodeObject(node, "target"))
    let value = self.generateExpression(getNodeObject(node, "value"))
    let assignOp = getNodeField(node, "operator", "=")
    let declType = getNodeField(node, "declType")
    let varType = getNodeField(node, "varType")
    
    let nimOp = case assignOp
      of "=": "="
      of "+=": "+="
      of "-=": "-="
      of "*=": "*="
      of "/=": "/="
      else: "="

    let prefix = case declType
      of "def": "var"
      of "val": "let"
      else: ""

    var typeCheck = ""
    if node.hasKey("typeCheck"):
      let checkNode = node["typeCheck"]
      let checkType = getNodeField(checkNode, "type")
      let checkFunc = getNodeField(checkNode, "function")
      
      self.increaseIndent()
      let lines = checkFunc.split("\n")
      var code: string
      for line in lines: 
        code.add(self.indent() & line.strip(trailing = false) & "\n")
      
      typeCheck = fmt"if not isType({target}, {checkType}):{code}"
      self.decreaseIndent()

    if prefix.len > 0:
      if varType.len > 0:
        if typeCheck.len > 0:
          result = fmt"{prefix} {target}: {varType} {nimOp} {value}" & "\n" & self.indent() & typeCheck
        else:
          result = fmt"{prefix} {target}: {varType} {nimOp} {value}"
      else:
        if typeCheck.len > 0:
          result = fmt"{prefix} {target} {nimOp} {value}" & "\n" & self.indent() & typeCheck
        else:
          result = fmt"{prefix} {target} {nimOp} {value}"
    else:
      if typeCheck.len > 0:
        result = fmt"{target} {nimOp} {value}" & "\n" & self.indent() & typeCheck
      else:
        result = fmt"{target} {nimOp} {value}"

  of "nkArray":
    result = "["
    let elements = getNodeArray(node, "elements")
    for i, elem in elements:
      if i > 0: result.add(", ")
      result.add(self.generateExpression(elem))
    result.add("]")

  of "nkArrayAccess":
    let arr = self.generateExpression(getNodeObject(node, "array"))
    let idx = self.generateExpression(getNodeObject(node, "index"))
    result = fmt"{arr}[{idx}]"

  of "nkTable":
    self.addImport("tables")
    
    let pairs = getNodeArray(node, "pairs")
    if pairs.len == 0:
      return "initTable[string, auto]()"
    
    var pairStrings: seq[string] = @[]
    for pair in pairs:
      let key = self.generateExpression(getNodeObject(pair, "key"))
      let value = self.generateExpression(getNodeObject(pair, "value"))
      pairStrings.add(fmt"{key}: {value}")
    
    let pairsStr = pairStrings.join(", ")
    return fmt"{{{pairsStr}}}.toTable()"

  of "nkStructInit":
    let structType = getNodeField(node, "structType")
    var args: seq[string] = @[]
    
    for arg in getNodeArray(node, "arguments"):
      if getNodeKind(arg) == "nkAssign":
        let name = getNodeField(getNodeObject(arg, "target"), "name")
        let value = self.generateExpression(getNodeObject(arg, "value"))
        args.add(fmt"{name}: {value}")
    
    let argsStr = args.join(", ")
    return fmt"new{structType}({argsStr})"

  of "nkNoop":
    return "discard"

  else:
    return fmt"# Unsupported expression type: {nodeKind}"

# Statement generation procedures
proc processParameters(self: var RBTNimGenerator, params: seq[JsonNode]): tuple[paramStrings: seq[string], nilChecks: seq[string]] =
  var paramStrings: seq[string] = @[]
  var nilChecks: seq[string] = @[]

  for param in params:
    let paramName = getNodeField(param, "name")
    let paramType = getNodeField(param, "type")
    let paramTypeModifier = getNodeField(param, "typeModifier")
    let paramDefault = getNodeObject(param, "defaultValue")
    
    var paramStr = paramName
    if paramType.len > 0:
      paramStr.add(": ")

      case paramTypeModifier
      of "!":
        paramStr.add(paramType)
        nilChecks.add(fmt"if {paramName} == nil: raise newException(ValueError, ""{paramName} cannot be nil"")")
      of "?":
        self.addImport("options")
        paramStr.add("Option[" & paramType & "]")
      else:
        paramStr.add(paramType)

    if paramDefault.kind != JNull:
      let defaultExpr = self.generateExpression(paramDefault)
      paramStr.add(" = " & defaultExpr)
    
    paramStrings.add(paramStr)

  return (paramStrings, nilChecks)

proc generateGenericParams(self: var RBTNimGenerator, genericParams: seq[JsonNode]): string =
  if genericParams.len == 0:
    return ""
  
  var params: seq[string] = @[]
  for param in genericParams:
    let paramName = getNodeField(param, "name")
    var paramStr = paramName
    
    let constraints = getNodeArray(param, "constraints")
    if constraints.len > 0:
      var constraintStrs: seq[string] = @[]
      for constraint in constraints:
        constraintStrs.add(getNodeField(constraint, "type"))
      paramStr.add(": " & constraintStrs.join(" + "))
    
    params.add(paramStr)
  
  return "[" & params.join(", ") & "]"

proc processReturnType(self: var RBTNimGenerator, retType: string, retTypeModifier: string): string =
  if retType.len == 0:
    return ""

  case retTypeModifier
  of "?":
    self.addImport("options")
    return ": Option[" & retType & "]"
  of "!":
    return ": " & retType
  else:
    return ": " & retType

proc processModifiers(modifiers: seq[JsonNode]): string =
  if modifiers.len > 0:
    var modStrs: seq[string] = @[]
    for modifier in modifiers:
      modStrs.add(getNodeField(modifier, "name"))
    return " {." & modStrs.join(", ") & ".}"
  return ""

proc emitNilChecks(self: var RBTNimGenerator, nilChecks: seq[string]) =
  for check in nilChecks:
    self.emitLine(check)
  if nilChecks.len > 0:
    self.emitLine("")

proc generateLambdaDeclaration(self: var RBTNimGenerator, node: JsonNode) =
  let params = getNodeArray(node, "parameters")
  let (paramStrings, nilChecks) = self.processParameters(params)
  let returnType = getNodeField(node, "returnType")
  let returnTypeModifier = getNodeField(node, "returnTypeModifier")
  let genericParams = getNodeArray(node, "genericParameters")
  let modifiers = getNodeArray(node, "modifiers")
  
  let genericStr = self.generateGenericParams(genericParams)
  let returnTypeStr = self.processReturnType(returnType, returnTypeModifier)
  let modifierStr = processModifiers(modifiers)
  
  let paramsStr = paramStrings.join(", ")
  
  self.currentLambdaReturnModifier = if returnTypeModifier.len > 0: returnTypeModifier[0] else: '\0'
  
  self.emitLine(fmt"proc{genericStr}({paramsStr}){returnTypeStr}{modifierStr} =", node, "nkLambdaDef")
  self.increaseIndent()
  
  self.emitNilChecks(nilChecks)
  
  let body = getNodeObject(node, "body")
  self.generateBlock(body)
  
  self.decreaseIndent()
  self.currentLambdaReturnModifier = '\0'

proc generateFunctionDeclaration(self: var RBTNimGenerator, node: JsonNode) =
  let funcName = getNodeField(node, "name")
  let params = getNodeArray(node, "parameters")
  let (paramStrings, nilChecks) = self.processParameters(params)
  let returnType = getNodeField(node, "returnType")
  let returnTypeModifier = getNodeField(node, "returnTypeModifier")
  let genericParams = getNodeArray(node, "genericParameters")
  let modifiers = getNodeArray(node, "modifiers")
  let isPublic = getNodeField(node, "isPublic", "true") == "true"
  
  let genericStr = self.generateGenericParams(genericParams)
  let returnTypeStr = self.processReturnType(returnType, returnTypeModifier)
  let modifierStr = processModifiers(modifiers)
  let publicStr = if isPublic: "*" else: ""
  
  let paramsStr = paramStrings.join(", ")
  
  self.currentFuncReturnModifier = if returnTypeModifier.len > 0: returnTypeModifier[0] else: '\0'
  
  self.emitLine(fmt"proc {funcName}{publicStr}{genericStr}({paramsStr}){returnTypeStr}{modifierStr} =", node, "nkFuncDef")
  self.increaseIndent()
  
  self.emitNilChecks(nilChecks)
  
  let body = getNodeObject(node, "body")
  self.generateBlock(body)
  
  self.decreaseIndent()
  self.currentFuncReturnModifier = '\0'


proc generatePackBody(self: var RBTNimGenerator, node: JsonNode) =
  let statements = getNodeArray(node, "statements")
  
  for stmt in statements:
    let stmtKind = getNodeKind(stmt)
    case stmtKind
    of "nkFuncDef":
      self.generateMethodDeclaration(stmt)
    of "nkInit":
      self.generateInitDeclaration(stmt)
    of "nkAssign":
      let target = getNodeField(getNodeObject(stmt, "target"), "name")
      let varType = getNodeField(stmt, "varType")
      let declType = getNodeField(stmt, "declType")
      
      if declType in ["def", "val"] and varType.len > 0:
        self.emitLine(fmt"{target}*: {varType}", stmt, "nkAssign")
    else:
      self.generateStatement(stmt)

proc generatePackDeclaration(self: var RBTNimGenerator, node: JsonNode) =
  let packName = getNodeField(node, "name")
  let genericParams = getNodeArray(node, "genericParameters")
  let parents = getNodeArray(node, "parents")
  let modifiers = getNodeArray(node, "modifiers")
  
  let genericStr = self.generateGenericParams(genericParams)
  let modifierStr = processModifiers(modifiers)
  
  var parentStr = ""
  if parents.len > 0:
    var parentNames: seq[string] = @[]
    for parent in parents:
      parentNames.add(getNodeField(parent, "name"))
    parentStr = " of " & parentNames.join(", ")
  
  self.emitLine(fmt"type", node, "nkPackDef")
  self.increaseIndent()
  self.emitLine(fmt"{packName}*{genericStr} = ref object{parentStr}{modifierStr}")
  
  let body = getNodeObject(node, "body")
  if body.kind != JNull:
    self.generatePackBody(body)
  
  self.decreaseIndent()

proc generateMethodDeclaration(self: var RBTNimGenerator, node: JsonNode) =
  let funcName = getNodeField(node, "name")
  let params = getNodeArray(node, "parameters")
  let (paramStrings, nilChecks) = self.processParameters(params)
  let returnType = getNodeField(node, "returnType")
  let returnTypeModifier = getNodeField(node, "returnTypeModifier")
  let genericParams = getNodeArray(node, "genericParameters")
  let modifiers = getNodeArray(node, "modifiers")
  
  let genericStr = self.generateGenericParams(genericParams)
  let returnTypeStr = self.processReturnType(returnType, returnTypeModifier)
  let modifierStr = processModifiers(modifiers)
  
  let paramsStr = paramStrings.join(", ")
  
  self.currentFuncReturnModifier = if returnTypeModifier.len > 0: returnTypeModifier[0] else: '\0'
  
  self.emitLine("")
  self.emitLine(fmt"proc {funcName}*{genericStr}({paramsStr}){returnTypeStr}{modifierStr} =", node, "nkFuncDef")
  self.increaseIndent()
  
  self.emitNilChecks(nilChecks)
  
  let body = getNodeObject(node, "body")
  self.generateBlock(body)
  
  self.decreaseIndent()
  self.currentFuncReturnModifier = '\0'

proc generateInitDeclaration(self: var RBTNimGenerator, node: JsonNode) =
  let params = getNodeArray(node, "parameters")
  let (paramStrings, nilChecks) = self.processParameters(params)
  
  let paramsStr = paramStrings.join(", ")
  
  self.emitLine("")
  self.emitLine(fmt"proc init*({paramsStr}) =", node, "nkInit")
  self.increaseIndent()
  
  self.emitNilChecks(nilChecks)
  
  let body = getNodeObject(node, "body")
  self.generateBlock(body)
  
  self.decreaseIndent()

proc generateStructDeclaration(self: var RBTNimGenerator, node: JsonNode) =
  let structName = getNodeField(node, "name")
  let genericParams = getNodeArray(node, "genericParameters")
  let isPublic = getNodeField(node, "isPublic", "true") == "true"
  
  let genericStr = self.generateGenericParams(genericParams)
  let publicStr = if isPublic: "*" else: ""
  
  self.emitLine(fmt"type", node, "nkStructDef")
  self.increaseIndent()
  self.emitLine(fmt"{structName}{publicStr}{genericStr} = object")
  
  self.increaseIndent()
  let fields = getNodeArray(node, "fields")
  for field in fields:
    let fieldName = getNodeField(field, "name")
    let fieldType = getNodeField(field, "type")
    let defaultValue = getNodeObject(field, "defaultValue")
    
    var fieldStr = fmt"{fieldName}*: {fieldType}"
    if defaultValue.kind != JNull:
      let defaultExpr = self.generateExpression(defaultValue)
      fieldStr.add(fmt" = {defaultExpr}")
    
    self.emitLine(fieldStr, field, "nkFieldDef")
  self.decreaseIndent()
  
  let methods = getNodeArray(node, "methods")
  for meth in methods:
    self.generateMethodDeclaration(meth)
  
  self.decreaseIndent()

proc generateEnumDeclaration(self: var RBTNimGenerator, node: JsonNode) =
  let enumName = getNodeField(node, "name")
  let genericParams = getNodeArray(node, "genericParameters")
  let isPublic = getNodeField(node, "isPublic", "true") == "true"
  
  let genericStr = self.generateGenericParams(genericParams)
  let publicStr = if isPublic: "*" else: ""
  
  self.emitLine(fmt"type", node, "nkEnumDef")
  self.increaseIndent()
  self.emitLine(fmt"{enumName}{publicStr}{genericStr} = enum")
  
  self.increaseIndent()
  let variants = getNodeArray(node, "variants")
  for i, variant in variants:
    let variantName = getNodeField(variant, "name")
    let variantValue = getNodeObject(variant, "value")
    
    var variantStr = variantName
    if variantValue.kind != JNull:
      let valueExpr = self.generateExpression(variantValue)
      variantStr.add(fmt" = {valueExpr}")
    
    if i < variants.len - 1:
      variantStr.add(",")
    
    self.emitLine(variantStr, variant, "nkEnumVariant")
  self.decreaseIndent()
  
  let methods = getNodeArray(node, "methods")
  for meth in methods:
    self.generateMethodDeclaration(meth)
  
  self.decreaseIndent()

proc generateIfStatement(self: var RBTNimGenerator, node: JsonNode) =
  let condition = self.generateExpression(getNodeObject(node, "condition"))
  
  self.emitLine(fmt"if {condition}:", node, "nkIf")
  self.increaseIndent()
  
  let thenBranch = getNodeObject(node, "thenBranch")
  self.generateBlock(thenBranch)
  
  self.decreaseIndent()
  
  let elifBranches = getNodeArray(node, "elifBranches")
  for elifBranch in elifBranches:
    let elifCondition = self.generateExpression(getNodeObject(elifBranch, "condition"))
    self.emitLine(fmt"elif {elifCondition}:")
    self.increaseIndent()
    
    let elifBody = getNodeObject(elifBranch, "body")
    self.generateBlock(elifBody)
    
    self.decreaseIndent()
  
  let elseBranch = getNodeObject(node, "elseBranch")
  if elseBranch.kind != JNull:
    self.emitLine("else:")
    self.increaseIndent()
    self.generateBlock(elseBranch)
    self.decreaseIndent()

proc generateForStatement(self: var RBTNimGenerator, node: JsonNode) =
  let variable = getNodeField(node, "variable")
  let rangeStart = self.generateExpression(getNodeObject(node, "rangeStart"))
  let rangeEnd = getNodeObject(node, "rangeEnd")
  let inclusive = getNodeField(node, "inclusive", "true") == "true"
  
  if rangeEnd.kind != JNull:
    let rangeEndExpr = self.generateExpression(rangeEnd)
    let rangeOp = if inclusive: ".." else: "..<"
    self.emitLine(fmt"for {variable} in {rangeStart}{rangeOp}{rangeEndExpr}:", node, "nkFor")
  else:
    self.emitLine(fmt"for {variable} in {rangeStart}:", node, "nkFor")
  
  self.increaseIndent()
  
  let body = getNodeObject(node, "body")
  self.generateBlock(body)
  
  self.decreaseIndent()

proc generateEachStatement(self: var RBTNimGenerator, node: JsonNode) =
  let variable = getNodeField(node, "variable")
  let startExpr = self.generateExpression(getNodeObject(node, "start"))
  let endExpr = self.generateExpression(getNodeObject(node, "end"))
  let stepExpr = getNodeObject(node, "step")
  let whereExpr = getNodeObject(node, "where")
  
  var stepStr = "1"
  if stepExpr.kind != JNull:
    stepStr = self.generateExpression(stepExpr)
  
  self.emitLine(fmt"for {variable} in countup({startExpr}, {endExpr}, {stepStr}):", node, "nkEach")
  self.increaseIndent()
  
  if whereExpr.kind != JNull:
    let whereCondition = self.generateExpression(whereExpr)
    self.emitLine(fmt"if not ({whereCondition}):")
    self.increaseIndent()
    self.emitLine("continue")
    self.decreaseIndent()
  
  let body = getNodeObject(node, "body")
  self.generateBlock(body)
  
  self.decreaseIndent()

proc generateWhileStatement(self: var RBTNimGenerator, node: JsonNode) =
  let condition = self.generateExpression(getNodeObject(node, "condition"))
  
  self.emitLine(fmt"while {condition}:", node, "nkWhile")
  self.increaseIndent()
  
  let body = getNodeObject(node, "body")
  self.generateBlock(body)
  
  self.decreaseIndent()

proc generateInfinitStatement(self: var RBTNimGenerator, node: JsonNode) =
  let delay = self.generateExpression(getNodeObject(node, "delay"))
  
  self.addImport("os")
  
  self.emitLine("while true:", node, "nkInfinit")
  self.increaseIndent()
  
  let body = getNodeObject(node, "body")
  self.generateBlock(body)
  
  self.emitLine(fmt"sleep({delay})")
  
  self.decreaseIndent()

proc generateRepeatStatement(self: var RBTNimGenerator, node: JsonNode) =
  let count = self.generateExpression(getNodeObject(node, "count"))
  let delay = self.generateExpression(getNodeObject(node, "delay"))
  
  self.addImport("os")
  
  self.emitLine(fmt"for _ in 0..<{count}:", node, "nkRepeat")
  self.increaseIndent()
  
  let body = getNodeObject(node, "body")
  self.generateBlock(body)
  
  self.emitLine(fmt"sleep({delay})")
  
  self.decreaseIndent()

proc generateTryStatement(self: var RBTNimGenerator, node: JsonNode) =
  self.emitLine("try:", node, "nkTry")
  self.increaseIndent()
  
  let tryBody = getNodeObject(node, "tryBody")
  self.generateBlock(tryBody)
  
  self.decreaseIndent()
  
  let errorType = getNodeField(node, "errorType")
  let catchBody = getNodeObject(node, "catchBody")
  
  if errorType.len > 0:
    self.emitLine(fmt"except {errorType}:")
  else:
    self.emitLine("except CatchableError:")
  
  self.increaseIndent()
  self.generateBlock(catchBody)
  self.decreaseIndent()

proc generateEventStatement(self: var RBTNimGenerator, node: JsonNode) =
  let eventName = getNodeField(node, "name")
  let condition = self.generateExpression(getNodeObject(node, "condition"))
  let scope = getNodeField(node, "scope", "local")
  
  let procName = fmt"event_{eventName}"
  
  self.emitLine(fmt"proc {procName}*() =", node, "nkEvent")
  self.increaseIndent()
  
  self.emitLine(fmt"if {condition}:")
  self.increaseIndent()
  
  let body = getNodeObject(node, "body")
  self.generateBlock(body)
  
  self.decreaseIndent()
  self.decreaseIndent()

proc generateStateStatement(self: var RBTNimGenerator, node: JsonNode) =
  let stateName = getNodeField(node, "name")
  
  self.emitLine(fmt"type", node, "nkState")
  self.increaseIndent()
  self.emitLine(fmt"{stateName}State* = ref object")
  
  self.increaseIndent()
  let stateBody = getNodeObject(node, "body")
  let variables = getNodeArray(stateBody, "variables")
  
  for variable in variables:
    let varName = getNodeField(getNodeObject(variable, "target"), "name")
    let varType = getNodeField(variable, "varType")
    if varType.len > 0:
      self.emitLine(fmt"{varName}*: {varType}", variable, "nkAssign")
  
  self.decreaseIndent()
  
  let methods = getNodeArray(stateBody, "methods")
  for meth in methods:
    self.generateMethodDeclaration(meth)
  
  self.decreaseIndent()

proc generateSwitchStatement(self: var RBTNimGenerator, node: JsonNode) =
  let expr = self.generateExpression(getNodeObject(node, "expression"))
  let cases = getNodeArray(node, "cases")
  let defaultCase = getNodeObject(node, "defaultCase")
  
  self.emitLine(fmt"case {expr}:", node, "nkSwitch")
  
  for caseNode in cases:
    let conditions = getNodeArray(caseNode, "conditions")
    let guard = getNodeObject(caseNode, "guard")
    let caseBody = getNodeObject(caseNode, "body")
    
    for i, condition in conditions:
      let conditionExpr = self.generateExpression(condition)
      
      if getNodeKind(condition) == "nkBinary" and getNodeField(condition, "operator") in ["..", "..."]:
        let left = self.generateExpression(getNodeObject(condition, "left"))
        let right = self.generateExpression(getNodeObject(condition, "right"))
        let op = if getNodeField(condition, "operator") == "..": ".." else: "..<"
        self.emitLine(fmt"of {left}{op}{right}:", caseNode, "nkSwitchCase")
      else:
        if i == 0:
          self.emitLine(fmt"of {conditionExpr}:", caseNode, "nkSwitchCase")
        else:
          self.emitLine(fmt", {conditionExpr}:")
    
    self.increaseIndent()
    
    if guard.kind != JNull:
      let guardCondition = self.generateExpression(guard)
      self.emitLine(fmt"if {guardCondition}:")
      self.increaseIndent()
      self.generateBlock(caseBody)
      self.decreaseIndent()
    else:
      self.generateBlock(caseBody)
    
    self.decreaseIndent()
  
  if defaultCase.kind != JNull:
    self.emitLine("else:")
    self.increaseIndent()
    self.generateBlock(defaultCase)
    self.decreaseIndent()

proc generateReturnStatement(self: var RBTNimGenerator, node: JsonNode) =
  let value = getNodeObject(node, "value")
  
  if value.kind != JNull:
    let returnExpr = self.generateExpression(value)
    
    if self.currentFuncReturnModifier == '!' or self.currentLambdaReturnModifier == '!':
      self.emitLine(fmt"if result == nil: raise newException(ValueError, ""Return value cannot be nil"")", node, "nkReturn")
    
    self.emitLine(fmt"return {returnExpr}", node, "nkReturn")
  else:
    self.emitLine("return", node, "nkReturn")

proc generateImportStatement(self: var RBTNimGenerator, node: JsonNode) =
  let imports = getNodeArray(node, "imports")
  
  for importSpec in imports:
    let importType = getNodeField(importSpec, "type")
    let path = getNodeArray(importSpec, "path")
    let alias = getNodeField(importSpec, "alias")
    let filters = getNodeArray(importSpec, "filters")
    let isAll = getNodeField(importSpec, "isAll", "false") == "true"
    
    case importType
    of "ryton":
      var pathStr = ""
      for i, pathPart in path:
        if i > 0: pathStr.add("/")
        pathStr.add(getNodeField(pathPart, "name"))
      
      if alias.len > 0:
        self.emitLine(fmt"import {pathStr} as {alias}", node, "nkImport")
        self.moduleMapping[alias] = pathStr
      elif filters.len > 0:
        var filterStrs: seq[string] = @[]
        for filter in filters:
          filterStrs.add(getNodeField(filter, "name"))
        self.emitLine(fmt"from {pathStr} import {filterStrs.join("", "")}", node, "nkImport")
      elif isAll:
        self.emitLine(fmt"import {pathStr}", node, "nkImport")
      else:
        self.emitLine(fmt"import {pathStr}", node, "nkImport")
      
      self.addImport(pathStr)
    
    of "nim":
      var pathStr = ""
      for i, pathPart in path:
        if i > 0: pathStr.add("/")
        pathStr.add(getNodeField(pathPart, "name"))
      
      if filters.len > 0:
        var filterStrs: seq[string] = @[]
        for filter in filters:
          filterStrs.add(getNodeField(filter, "name"))
        self.emitLine(fmt"from {pathStr} import {filterStrs.join("", "")}", node, "nkImport")
      else:
        self.emitLine(fmt"import {pathStr}", node, "nkImport")
      
      self.addImport(pathStr)
    
    of "rbt":
      let rbtPath = getNodeField(importSpec, "rbtPath")
      self.emitLine(fmt"# RBT import: {rbtPath}", node, "nkImport")

proc generateExpressionStatement(self: var RBTNimGenerator, node: JsonNode) =
  let expr = getNodeObject(node, "expression")
  let exprStr = self.generateExpression(expr)
  
  if not self.inVar:
    self.emitLine(exprStr, node, "nkExprStmt")

proc generateNoopStatement(self: var RBTNimGenerator, node: JsonNode) =
  self.emitLine("discard", node, "nkNoop")

proc generateBlock(self: var RBTNimGenerator, node: JsonNode) =
  if node == nil or node.kind == JNull:
    self.emitLine("discard")
    return
  
  let statements = getNodeArray(node, "statements")
  
  if statements.len == 0:
    self.emitLine("discard")
    return
  
  for stmt in statements:
    self.generateStatement(stmt)

proc generateStatement(self: var RBTNimGenerator, node: JsonNode) =
  if node == nil or node.kind == JNull:
    return
  
  let nodeKind = getNodeKind(node)
  
  case nodeKind
  of "nkFuncDef":
    self.generateFunctionDeclaration(node)
  
  of "nkLambdaDef":
    self.generateLambdaDeclaration(node)
  
  of "nkPackDef":
    self.generatePackDeclaration(node)
  
  of "nkStructDef":
    self.generateStructDeclaration(node)
  
  of "nkEnumDef":
    self.generateEnumDeclaration(node)
  
  of "nkIf":
    self.generateIfStatement(node)
  
  of "nkFor":
    self.generateForStatement(node)
  
  of "nkEach":
    self.generateEachStatement(node)
  
  of "nkWhile":
    self.generateWhileStatement(node)
  
  of "nkInfinit":
    self.generateInfinitStatement(node)
  
  of "nkRepeat":
    self.generateRepeatStatement(node)
  
  of "nkTry":
    self.generateTryStatement(node)
  
  of "nkEvent":
    self.generateEventStatement(node)
  
  of "nkState":
    self.generateStateStatement(node)
  
  of "nkSwitch":
    self.generateSwitchStatement(node)
  
  of "nkReturn":
    self.generateReturnStatement(node)
  
  of "nkImport":
    self.generateImportStatement(node)
  
  of "nkExprStmt":
    self.generateExpressionStatement(node)
  
  of "nkAssign":
    let assignExpr = self.generateExpression(node)
    self.emitLine(assignExpr, node, "nkAssign")
  
  of "nkNoop":
    self.generateNoopStatement(node)
  
  of "nkBlock":
    self.generateBlock(node)
  
  else:
    self.emitLine(fmt"# Unsupported statement type: {nodeKind}", node, nodeKind, "unsupported")

proc generateProgram(self: var RBTNimGenerator, node: JsonNode) =
  let statements = getNodeArray(node, "body")
  
  for stmt in statements:
    self.generateStatement(stmt)
    self.emitLine("")

proc processNamespaces(self: var RBTNimGenerator, namespaces: JsonNode) =
  if namespaces == nil or namespaces.kind != JObject:
    return
  
  for namespaceName, namespaceData in namespaces:
    let access = getNodeField(namespaceData, "access", "local")
    let contents = getNodeArray(namespaceData, "contents")
    
    if access == "global":
      self.emitLine(fmt"# Global namespace: {namespaceName}")
    else:
      self.emitLine(fmt"# Local namespace: {namespaceName}")
    
    for content in contents:
      let contentName = getNodeField(content, "name")
      self.emitLine(fmt"# - {contentName}")
    
    self.emitLine("")

proc processMetadata(self: var RBTNimGenerator, metadata: JsonNode) =
  if metadata == nil or metadata.kind != JObject:
    return
  
  let sourceLang = getNodeField(metadata, "sourceLang", "Unknown")
  let sourceLangVersion = getNodeField(metadata, "sourceLangVersion", "0.0.0")
  let sourceFile = getNodeField(metadata, "sourceFile", "unknown.src")
  let outputFile = getNodeField(metadata, "outputFile", "output.nim")
  let generatorName = getNodeField(metadata, "generatorName", "RBTGENCL")
  let generatorVersion = getNodeField(metadata, "generatorVersion", "0.2.5")
  let projectName = getNodeField(metadata, "projectName", "Unknown Project")
  let projectAuthor = getNodeField(metadata, "projectAuthor", "Unknown Author")
  let projectVersion = getNodeField(metadata, "projectVersion", "0.0.0")
  
  self.currentFile = sourceFile
  self.rytonVersion = sourceLangVersion
  
  self.emitLine(fmt"# Generated by {generatorName} v{generatorVersion}")
  self.emitLine(fmt"# Source: {sourceLang} v{sourceLangVersion}")
  self.emitLine(fmt"# File: {sourceFile} -> {outputFile}")
  self.emitLine(fmt"# Project: {projectName} v{projectVersion} by {projectAuthor}")
  self.emitLine("")

proc generateFromRBT*(self: var RBTNimGenerator, rbtFilePath: string): string =
  if not fileExists(rbtFilePath):
    raise newException(RBTException, fmt"RBT file not found: {rbtFilePath}")
  
  let rbtContent = readFile(rbtFilePath)
  
  try:
    self.rbtData = parseJson(rbtContent)
  except JsonParsingError as e:
    raise newException(RBTException, fmt"Invalid JSON in RBT file: {e.msg}")
  
  # Validate RBT format
  if not self.rbtData.hasKey("header") or getNodeField(self.rbtData, "header") != "RBT":
    raise newException(RBTException, "Invalid RBT file: missing or incorrect header")
  
  if not self.rbtData.hasKey("version"):
    raise newException(RBTException, "Invalid RBT file: missing version")
  
  if not self.rbtData.hasKey("ast"):
    raise newException(RBTException, "Invalid RBT file: missing AST")
  
  # Process metadata
  if self.rbtData.hasKey("META"):
    self.processMetadata(self.rbtData["META"])
  
  # Process namespaces
  if self.rbtData.hasKey("namespaces"):
    self.processNamespaces(self.rbtData["namespaces"])
  
  # Generate imports section
  let importsStr = self.generateImports()
  if importsStr.len > 0:
    self.output.add(importsStr & "\n\n")
  
  # Generate main program
  let ast = self.rbtData["ast"]
  self.generateProgram(ast)
  
  return self.output

proc generateFromRBTToFile*(self: var RBTNimGenerator, rbtFilePath: string, outputPath: string) =
  let nimCode = self.generateFromRBT(rbtFilePath)
  
  let outputDir = outputPath.parentDir()
  if not dirExists(outputDir):
    createDir(outputDir)
  
  writeFile(outputPath, nimCode)

proc generateFromJSON*(self: var RBTNimGenerator, jsonContent: string): string =
  try:
    self.rbtData = parseJson(jsonContent)
  except JsonParsingError as e:
    raise newException(RBTException, fmt"Invalid JSON content: {e.msg}")
  
  # Validate RBT format
  if not self.rbtData.hasKey("header") or getNodeField(self.rbtData, "header") != "RBT":
    raise newException(RBTException, "Invalid RBT data: missing or incorrect header")
  
  if not self.rbtData.hasKey("version"):
    raise newException(RBTException, "Invalid RBT data: missing version")
  
  if not self.rbtData.hasKey("ast"):
    raise newException(RBTException, "Invalid RBT data: missing AST")
  
  # Process metadata
  if self.rbtData.hasKey("META"):
    self.processMetadata(self.rbtData["META"])
  
  # Process namespaces
  if self.rbtData.hasKey("namespaces"):
    self.processNamespaces(self.rbtData["namespaces"])
  
  # Generate imports section
  let importsStr = self.generateImports()
  if importsStr.len > 0:
    self.output.add(importsStr & "\n\n")
  
  # Generate main program
  let ast = self.rbtData["ast"]
  self.generateProgram(ast)
  
  return self.output

proc reset*(self: var RBTNimGenerator) =
  self.indentLevel = 0
  self.output = ""
  self.currentModule = "main"
  self.importedModules.clear()
  self.moduleMapping.clear()
  self.currentFuncReturnModifier = '\0'
  self.currentLambdaReturnModifier = '\0'
  self.inVar = false
  self.currentFile = "main.ry"
  self.currentNimLine = 1
  self.rbtData = nil

proc getGeneratedCode*(self: RBTNimGenerator): string =
  return self.output

proc getImportedModules*(self: RBTNimGenerator): seq[string] =
  result = @[]
  for module in self.importedModules:
    result.add(module)

proc getModuleMapping*(self: RBTNimGenerator): Table[string, string] =
  return self.moduleMapping

proc setModuleMapping*(self: var RBTNimGenerator, mapping: Table[string, string]) =
  self.moduleMapping = mapping

proc addModuleMapping*(self: var RBTNimGenerator, rytonModule: string, nimModule: string) =
  self.moduleMapping[rytonModule] = nimModule

proc getCurrentFile*(self: RBTNimGenerator): string =
  return self.currentFile

proc setCurrentFile*(self: var RBTNimGenerator, filename: string) =
  self.currentFile = filename

proc getRytonVersion*(self: RBTNimGenerator): string =
  return self.rytonVersion

proc setRytonVersion*(self: var RBTNimGenerator, version: string) =
  self.rytonVersion = version

# Utility procedures for advanced features
proc generateTypeCheck(self: var RBTNimGenerator, node: JsonNode): string =
  let checkType = getNodeField(node, "type")
  let checkFunc = getNodeField(node, "function")
  let checkExpr = getNodeObject(node, "expression")
  
  if checkExpr.kind != JNull:
    let expr = self.generateExpression(checkExpr)
    return fmt"when {expr} is {checkType}: {checkFunc}"
  else:
    return fmt"when compiles({checkFunc}): {checkFunc}"

proc generateDirective(self: var RBTNimGenerator, node: JsonNode): string =
  let directiveType = getNodeField(node, "type")
  let directiveContent = getNodeField(node, "content")
  
  case directiveType
  of "pragma":
    return fmt"{{.{directiveContent}.}}"
  of "emit":
    return fmt"{{.emit: ""{directiveContent}"".}}"
  of "compile":
    return fmt"{{.compile: ""{directiveContent}"".}}"
  of "link":
    return fmt"{{.link: ""{directiveContent}"".}}"
  of "passC":
    return fmt"{{.passC: ""{directiveContent}"".}}"
  of "passL":
    return fmt"{{.passL: ""{directiveContent}"".}}"
  else:
    return fmt"# Unknown directive: {directiveType} - {directiveContent}"

proc generateConditionalCompilation(self: var RBTNimGenerator, node: JsonNode): string =
  let condition = getNodeField(node, "condition")
  let thenCode = getNodeField(node, "thenCode")
  let elseCode = getNodeField(node, "elseCode")
  
  result = fmt"when {condition}:\n"
  result.add(self.indent() & "  " & thenCode & "\n")
  
  if elseCode.len > 0:
    result.add(self.indent() & "else:\n")
    result.add(self.indent() & "  " & elseCode & "\n")

proc generateMacroCall(self: var RBTNimGenerator, node: JsonNode): string =
  let macroName = getNodeField(node, "name")
  let args = getNodeArray(node, "arguments")
  
  var argStrs: seq[string] = @[]
  for arg in args:
    argStrs.add(self.generateExpression(arg))
  
  return fmt"{macroName}({argStrs.join("", "")})"

proc generateTemplateCall(self: var RBTNimGenerator, node: JsonNode): string =
  let templateName = getNodeField(node, "name")
  let args = getNodeArray(node, "arguments")
  
  var argStrs: seq[string] = @[]
  for arg in args:
    argStrs.add(self.generateExpression(arg))
  
  return fmt"{templateName}({argStrs.join("", "")})"

proc generateAsyncProc(self: var RBTNimGenerator, node: JsonNode) =
  let funcName = getNodeField(node, "name")
  let params = getNodeArray(node, "parameters")
  let (paramStrings, nilChecks) = self.processParameters(params)
  let returnType = getNodeField(node, "returnType")
  let returnTypeModifier = getNodeField(node, "returnTypeModifier")
  let genericParams = getNodeArray(node, "genericParameters")
  let modifiers = getNodeArray(node, "modifiers")
  let isPublic = getNodeField(node, "isPublic", "true") == "true"
  
  self.addImport("asyncdispatch")
  
  let genericStr = self.generateGenericParams(genericParams)
  let returnTypeStr = if returnType.len > 0: fmt": Future[{returnType}]" else: ": Future[void]"
  let modifierStr = processModifiers(modifiers)
  let publicStr = if isPublic: "*" else: ""
  
  let paramsStr = paramStrings.join(", ")
  
  self.emitLine(fmt"proc {funcName}{publicStr}{genericStr}({paramsStr}){returnTypeStr} {{.async.}}{modifierStr} =", node, "nkAsyncFuncDef")
  self.increaseIndent()
  
  self.emitNilChecks(nilChecks)
  
  let body = getNodeObject(node, "body")
  self.generateBlock(body)
  
  self.decreaseIndent()

proc generateAwaitExpression(self: var RBTNimGenerator, node: JsonNode): string =
  let expr = self.generateExpression(getNodeObject(node, "expression"))
  return fmt"await {expr}"

proc generateYieldExpression(self: var RBTNimGenerator, node: JsonNode): string =
  let expr = getNodeObject(node, "expression")
  if expr.kind != JNull:
    let exprStr = self.generateExpression(expr)
    return fmt"yield {exprStr}"
  else:
    return "yield"

proc generateIterator(self: var RBTNimGenerator, node: JsonNode) =
  let iterName = getNodeField(node, "name")
  let params = getNodeArray(node, "parameters")
  let (paramStrings, nilChecks) = self.processParameters(params)
  let yieldType = getNodeField(node, "yieldType")
  let genericParams = getNodeArray(node, "genericParameters")
  let modifiers = getNodeArray(node, "modifiers")
  let isPublic = getNodeField(node, "isPublic", "true") == "true"
  
  let genericStr = self.generateGenericParams(genericParams)
  let yieldTypeStr = if yieldType.len > 0: fmt": {yieldType}" else: ""
  let modifierStr = processModifiers(modifiers)
  let publicStr = if isPublic: "*" else: ""
  
  let paramsStr = paramStrings.join(", ")
  
  self.emitLine(fmt"iterator {iterName}{publicStr}{genericStr}({paramsStr}){yieldTypeStr} {{.closure.}}{modifierStr} =", node, "nkIterator")
  self.increaseIndent()
  
  self.emitNilChecks(nilChecks)
  
  let body = getNodeObject(node, "body")
  self.generateBlock(body)
  
  self.decreaseIndent()

proc generateConverter(self: var RBTNimGenerator, node: JsonNode) =
  let converterName = getNodeField(node, "name")
  let fromType = getNodeField(node, "fromType")
  let toType = getNodeField(node, "toType")
  let isPublic = getNodeField(node, "isPublic", "true") == "true"
  
  let publicStr = if isPublic: "*" else: ""
  
  self.emitLine(fmt"converter {converterName}{publicStr}(x: {fromType}): {toType} =", node, "nkConverter")
  self.increaseIndent()
  
  let body = getNodeObject(node, "body")
  self.generateBlock(body)
  
  self.decreaseIndent()

proc generateConcept(self: var RBTNimGenerator, node: JsonNode) =
  let conceptName = getNodeField(node, "name")
  let typeParam = getNodeField(node, "typeParam", "T")
  let constraints = getNodeArray(node, "constraints")
  let isPublic = getNodeField(node, "isPublic", "true") == "true"
  
  let publicStr = if isPublic: "*" else: ""
  
  self.emitLine(fmt"type", node, "nkConcept")
  self.increaseIndent()
  self.emitLine(fmt"{conceptName}{publicStr} = concept {typeParam}")
  
  self.increaseIndent()
  for constraint in constraints:
    let constraintExpr = self.generateExpression(constraint)
    self.emitLine(constraintExpr)
  self.decreaseIndent()
  
  self.decreaseIndent()

# Main generation entry point with error handling
proc generateNimCode*(rbtFilePath: string, outputPath: string = ""): string =
  var generator = newRBTNimGenerator()
  
  try:
    let nimCode = generator.generateFromRBT(rbtFilePath)
    
    if outputPath.len > 0:
      generator.generateFromRBTToFile(rbtFilePath, outputPath)
    
    return nimCode
    
  except RBTException as e:
    echo fmt"RBT Generation Error: {e.msg}"
    return ""
  except IOError as e:
    echo fmt"File I/O Error: {e.msg}"
    return ""
  except Exception as e:
    echo fmt"Unexpected Error: {e.msg}"
    return ""


# Export main procedures
when isMainModule:
  import os
  
  if paramCount() < 1:
    echo "Usage: rbt_nimgen <input.rbt> [output.nim]"
    quit(1)
  
  let inputFile = paramStr(1)
  let outputFile = if paramCount() >= 2: paramStr(2) else: inputFile.changeFileExt("nim")
  
  let result = generateNimCode(inputFile, outputFile)
  
  if result.len > 0:
    echo fmt"Successfully generated Nim code: {outputFile}"
  else:
    echo "Failed to generate Nim code"
    quit(1)
