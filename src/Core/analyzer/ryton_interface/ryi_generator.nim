import std/[strutils, strformat, tables, os, sequtils]
import ../../compiler/parser
import ../../compiler/lexer
import ../../Core

import nim_parser
import ryi_parser

type
  RyiGenerator* = ref object
    outputDir*: string

proc newRyiGenerator*(outputDir: string): RyiGenerator =
  result = RyiGenerator(outputDir: outputDir)
  createDir(outputDir)

# ===== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ =====

proc convertRytonType(generator: RyiGenerator, rytonType: string): string =
  case rytonType:
  of "String": return "String"
  of "Int": return "Int"
  of "Bool": return "Bool"
  of "Table": return "Table"
  of "": return "None"
  else: return rytonType

proc inferRytonFieldType(generator: RyiGenerator, valueNode: Node): string =
  if valueNode == nil:
    return "Auto"
  
  case valueNode.kind:
  of nkString: return "String"
  of nkNumber: return "Int"
  of nkBool: return "Bool"
  of nkArray: return "Array"
  else: return "Auto"

proc formatRytonParams(generator: RyiGenerator, params: seq[Node]): string =
  var paramStrs: seq[string] = @[]
  
  for param in params:
    if param.kind == nkParam:
      let paramType = generator.convertRytonType(param.paramType)
      paramStrs.add(fmt"{param.paramName}: {paramType}")
  
  return paramStrs.join(", ")

proc convertNimType(generator: RyiGenerator, nimType: string): string =
  case nimType.toLowerAscii():
  of "string": return "String"
  of "int", "int32", "int64": return "Int"
  of "bool": return "Bool"
  of "void", "": return "None"
  of "float", "float32", "float64": return "Float"
  else:
    if nimType.startsWith("seq["):
      return "Array"
    elif nimType.startsWith("Table["):
      return "Table"
    else:
      return nimType

# ===== ИЗВЛЕЧЕНИЕ ИЗ RYTON AST =====

proc extractPackFields(generator: RyiGenerator, pack: Node): seq[RyiField] =
  result = @[]
  
  if pack.packBody == nil:
    return
  
  for stmt in pack.packBody.blockStmts:
    if stmt.kind == nkAssign and stmt.declType in [dtDef, dtVal]:
      if stmt.assignTarget != nil and stmt.assignTarget.kind == nkIdent:
        let field = RyiField(
          name: stmt.assignTarget.ident,
          fieldType: generator.inferRytonFieldType(stmt.assignVal),
          visibility: "pub"
        )
        result.add(field)

proc extractPackMethods(generator: RyiGenerator, pack: Node): seq[RyiEntry] =
  result = @[]
  
  if pack.packBody == nil:
    return
  
  for stmt in pack.packBody.blockStmts:
    case stmt.kind:
    of nkFuncDef:
      let methodEntry = RyiEntry(
        kind: rekMethod,
        name: stmt.funcName,
        visibility: if stmt.funcPublic: "pub" else: "priv",
        params: generator.formatRytonParams(stmt.funcParams),
        returnType: generator.convertRytonType(stmt.funcRetType),
        className: pack.packName,
        fields: @[]
      )
      result.add(methodEntry)
    
    of nkInit:
      let initEntry = RyiEntry(
        kind: rekMethod,
        name: "init",
        visibility: "pub",
        params: generator.formatRytonParams(stmt.initParams),
        returnType: "None",
        className: pack.packName,
        fields: @[]
      )
      result.add(initEntry)
    
    else:
      discard

proc extractRytonInterfaces(generator: RyiGenerator, ast: Node): seq[RyiEntry] =
  result = @[]
  
  if ast == nil:
    return
  
  case ast.kind:
  of nkProgram:
    for stmt in ast.stmts:
      result.add(generator.extractRytonInterfaces(stmt))
  
  of nkPackDef:
    var packEntry = RyiEntry(
      kind: rekType,
      name: ast.packName,
      visibility: "pub",
      params: "",
      returnType: "",
      className: "",
      fields: @[]
    )
    
    packEntry.fields = generator.extractPackFields(ast)
    result.add(packEntry)
    result.add(generator.extractPackMethods(ast))
  
  of nkFuncDef:
    let funcEntry = RyiEntry(
      kind: rekFunc,
      name: ast.funcName,
      visibility: if ast.funcPublic: "pub" else: "priv",
      params: generator.formatRytonParams(ast.funcParams),
      returnType: generator.convertRytonType(ast.funcRetType),
      className: "",
      fields: @[]
    )
    result.add(funcEntry)
  
  else:
    discard

# ===== ИЗВЛЕЧЕНИЕ ИЗ NIM AST =====

proc extractNimInterfaces(generator: RyiGenerator, nimAST: nim_parser.NimNode, nimParser: NimParser): seq[RyiEntry] =
  result = @[]
  
  for node in nimParser.walkNodes(nimAST):
    let nodeKind = nimParser.getNodeKind(node)
    
    case nodeKind:
    of "nkTypeDef":
      echo "Processing type definition..."
      let isExp = nimParser.isExported(node)
      echo fmt"Is exported: {isExp}"
      if isExp:
        let typeName = nimParser.extractTypeName(node)
        echo fmt"Type name: {typeName}"
        var typeEntry = RyiEntry(
          kind: rekType,
          name: typeName,
          visibility: "pub",
          params: "",
          returnType: "",
          className: "",
          fields: @[]
        )
        
        let nimFields = nimParser.extractObjectFields(node)
        echo fmt"Found {nimFields.len} fields"
        for nimField in nimFields:
          echo fmt"Field: {nimField.name} : {nimField.nimType}"
          let ryiField = RyiField(
            name: nimField.name,
            fieldType: generator.convertNimType(nimField.nimType),
            visibility: if nimField.exported: "pub" else: "priv"
          )
          typeEntry.fields.add(ryiField)
        
        result.add(typeEntry)
        echo fmt"Added type entry: {typeName}"
      else:
        echo "Type is not exported, skipping"
    
    of "nkProcDef":
      echo "Processing proc definition..."
      let isExp = nimParser.isExported(node)
      echo fmt"Is exported: {isExp}"
      if isExp:
        let procName = nimParser.extractProcName(node)
        echo fmt"Proc name: {procName}"
        let params = nimParser.extractProcParams(node)
        echo fmt"Found {params.len} parameters"
        var paramStrs: seq[string] = @[]
        for param in params:
          let paramType = generator.convertNimType(param.nimType)
          paramStrs.add(fmt"{param.name}: {paramType}")
        
        let returnType = nimParser.extractReturnType(node)
        echo fmt"Return type: {returnType}"
        
        let procEntry = RyiEntry(
          kind: rekFunc,
          name: procName,
          visibility: "pub",
          params: paramStrs.join(", "),
          returnType: generator.convertNimType(returnType),
          className: "",
          fields: @[]
        )
        result.add(procEntry)
        echo fmt"Added proc entry: {procName}"
      else:
        echo "Proc is not exported, skipping"
    
    of "nkMethodDef":
      echo "Processing method definition..."
      let isExp = nimParser.isExported(node)
      echo fmt"Is exported: {isExp}"
      if isExp:
        let methodName = nimParser.extractProcName(node)
        echo fmt"Method name: {methodName}"
        let params = nimParser.extractProcParams(node)
        echo fmt"Found {params.len} parameters"
        var paramStrs: seq[string] = @[]
        for param in params:
          let paramType = generator.convertNimType(param.nimType)
          paramStrs.add(fmt"{param.name}: {paramType}")
        
        let returnType = nimParser.extractReturnType(node)
        let className = nimParser.extractMethodClass(node)
        echo fmt"Method class: {className}, return type: {returnType}"
        
        let methodEntry = RyiEntry(
          kind: rekMethod,
          name: methodName,
          visibility: "pub",
          params: paramStrs.join(", "),
          returnType: generator.convertNimType(returnType),
          className: className,
          fields: @[]
        )
        result.add(methodEntry)
        echo fmt"Added method entry: {methodName}"
      else:
        echo "Method is not exported, skipping"
    
    else:
      discard

# ===== ФОРМАТИРОВАНИЕ .RYI =====

proc formatRyiContent(generator: RyiGenerator, interfaces: seq[RyiEntry]): string =
  let ryiParser = newRyiParser("")
  return ryiParser.exportRyiToString(interfaces)

# ===== ОСНОВНЫЕ ФУНКЦИИ =====

proc generateFromRyton*(generator: RyiGenerator, rytonFile: string) =
  try:
    echo fmt"Processing Ryton file: {rytonFile}"
    
    let source = readFile(rytonFile)
    let compiler = newCompiler(source)
    
    let lexResult = compiler.tokenize()
    if not lexResult.success:
      echo "Lexer error: ", lexResult.errorMessage
      return
    
    let parseResult = compiler.parse()
    if not parseResult.success:
      echo "Parser error: ", parseResult.errorMessage
      return
    
    let ast = compiler.ast
    let interfaces = generator.extractRytonInterfaces(ast)
    let ryiContent = generator.formatRyiContent(interfaces)
    
    let outputFile = generator.outputDir / extractFilename(rytonFile).changeFileExt(".ryi")
    writeFile(outputFile, ryiContent)
    
    echo fmt"Generated: {outputFile}"
    echo fmt"Extracted {interfaces.len} interface entries"
    
  except Exception as e:
    echo fmt"Error processing {rytonFile}: {e.msg}"

proc generateFromNim*(generator: RyiGenerator, nimFile: string) =
  try:
    echo fmt"Processing Nim file: {nimFile}"
    
    let nimParser = newNimParser()
    let nimAST = nimParser.parseNimFile(nimFile)
    
    if not nimParser.validateNimAST(nimAST):
      echo "Invalid Nim AST"
      return
    
    let interfaces = generator.extractNimInterfaces(nimAST, nimParser)
    let ryiContent = generator.formatRyiContent(interfaces)
    
    let outputFile = generator.outputDir / extractFilename(nimFile).changeFileExt(".ryi")
    writeFile(outputFile, ryiContent)
    
    echo fmt"Generated: {outputFile}"
    echo fmt"Extracted {interfaces.len} interface entries"
    
  except Exception as e:
    echo fmt"Error processing {nimFile}: {e.msg}"

proc generateRyiFiles*(generator: RyiGenerator, filePaths: seq[string]) =
  echo fmt"Generating interfaces for {filePaths.len} files..."
  
  for filePath in filePaths:
    echo fmt"Processing: {filePath}"
    
    if not fileExists(filePath):
      echo fmt"File not found: {filePath}"
      continue
    
    try:
      if filePath.endsWith(".ry"):
        generator.generateFromRyton(filePath)
      elif filePath.endsWith(".nim"):
        generator.generateFromNim(filePath)
      else:
        echo fmt"Unsupported file type: {filePath}"
    except Exception as e:
      echo fmt"Error processing {filePath}: {e.msg}"
  
  echo "Interface generation completed!"


when isMainModule:
  let generator = newRyiGenerator("./.ryi")
  generator.generateRyiFiles(@["./test/src/lib.nim"])
