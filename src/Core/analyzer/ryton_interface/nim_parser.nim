import std/[strutils, strformat]
import compiler/[ast, parser, llstream, idents, options, msgs, pathutils]

type
  NimParser* = ref object
    config*: ConfigRef
    cache*: IdentCache
    
  NimNode* = PNode
  
  NimFieldInfo* = object
    name*: string
    nimType*: string
    exported*: bool
    
  NimParamInfo* = object
    name*: string
    nimType*: string

proc newNimParser*(): NimParser =
  ## Создает новый парсер Nim файлов
  let config = newConfigRef()
  let cache = newIdentCache()
  
  # Настраиваем конфигурацию для парсинга
  config.verbosity = 0 # Отключаем лишний вывод
  config.cmd = cmdCompileToC
  
  result = NimParser(
    config: config,
    cache: cache
  )

proc parseNimFile*(nimParser: NimParser, filePath: string): NimNode =
  ## Парсит Nim файл используя Nim Compiler API
  try:
    let fileIndex = fileInfoIdx(nimParser.config, AbsoluteFile(filePath))
    let stream = llStreamOpen(AbsoluteFile(filePath), fmRead)
    if stream == nil:
      raise newException(IOError, fmt"Cannot open file: {filePath}")
    
    # Создаем парсер компилятора
    var compilerParser: parser.Parser
    openParser(compilerParser, fileIndex, stream, nimParser.cache, nimParser.config)
    
    result = parseAll(compilerParser)
    closeParser(compilerParser)
    
    if result == nil:
      raise newException(ValueError, fmt"Failed to parse {filePath}")
  except Exception as e:
    echo fmt"Error parsing {filePath}: {e.msg}"
    raise

proc walkNodes*(parser: NimParser, node: NimNode): seq[NimNode] =
  ## Обходит все узлы AST рекурсивно
  result = @[]
  
  if node == nil:
    return
  
  result.add(node)
  
  for child in node:
    result.add(parser.walkNodes(child))

proc getNodeKind*(parser: NimParser, node: NimNode): string =
  ## Получает тип узла как строку
  if node == nil:
    return "nil"
  return $node.kind

proc isExported*(parser: NimParser, node: NimNode): bool =
  ## Проверяет, экспортируется ли узел (имеет ли *)
  if node == nil:
    return false
  
  case node.kind:
  of nkTypeDef:
    # type MyType* = ...
    if node.len > 0 and node[0].kind == nkPostfix:
      return node[0][0].ident.s == "*"
  
  of nkProcDef, nkMethodDef, nkFuncDef:
    # proc myProc*() = ...
    if node.len > 0 and node[0].kind == nkPostfix:
      return node[0][0].ident.s == "*"
  
  of nkIdentDefs:
    # field*: string
    if node.len > 0 and node[0].kind == nkPostfix:
      return node[0][0].ident.s == "*"
  
  else:
    discard
  
  return false

proc extractTypeString*(parser: NimParser, typeNode: NimNode): string =
  ## Извлекает строковое представление типа
  if typeNode == nil:
    return ""
  
  case typeNode.kind:
  of nkIdent:
    return typeNode.ident.s
  
  of nkSym:
    return typeNode.sym.name.s
  
  of nkBracketExpr:
    # Generic типы: seq[int], Table[string, int]
    if typeNode.len > 0:
      var typeStr = parser.extractTypeString(typeNode[0])
      if typeNode.len > 1:
        typeStr.add("[")
        for i in 1..<typeNode.len:
          if i > 1:
            typeStr.add(", ")
          typeStr.add(parser.extractTypeString(typeNode[i]))
        typeStr.add("]")
      return typeStr
  
  of nkRefTy:
    # ref Type
    if typeNode.len > 0:
      return "ref " & parser.extractTypeString(typeNode[0])
  
  of nkPtrTy:
    # ptr Type
    if typeNode.len > 0:
      return "ptr " & parser.extractTypeString(typeNode[0])
  
  of nkVarTy:
    # var Type
    if typeNode.len > 0:
      return "var " & parser.extractTypeString(typeNode[0])
  
  of nkProcTy:
    # proc type
    return "proc"
  
  of nkEmpty:
    return ""
  
  else:
    return $typeNode.kind

proc extractTypeName*(parser: NimParser, typeNode: NimNode): string =
  ## Извлекает имя типа из узла определения типа
  if typeNode == nil or typeNode.kind != nkTypeDef:
    return ""
  
  if typeNode.len == 0:
    return ""
  
  let nameNode = typeNode[0]
  case nameNode.kind:
  of nkIdent:
    return nameNode.ident.s
  of nkPostfix:
    # Экспортируемый тип (MyType*)
    if nameNode.len > 1:
      return nameNode[1].ident.s
  else:
    discard
  
  return ""

proc extractProcName*(parser: NimParser, procNode: NimNode): string =
  ## Извлекает имя процедуры/функции/метода
  if procNode == nil or procNode.kind notin {nkProcDef, nkMethodDef, nkFuncDef}:
    return ""
  
  if procNode.len == 0:
    return ""
  
  let nameNode = procNode[0]
  case nameNode.kind:
  of nkIdent:
    return nameNode.ident.s
  of nkPostfix:
    # Экспортируемая процедура (myProc*)
    if nameNode.len > 1:
      return nameNode[1].ident.s
  else:
    discard
  
  return ""

proc extractReturnType*(parser: NimParser, procNode: NimNode): string =
  ## Извлекает тип возвращаемого значения процедуры
  if procNode == nil or procNode.kind notin {nkProcDef, nkMethodDef, nkFuncDef}:
    return ""
  
  # Структура: [name, pattern, generics, params, pragma, reserved, body]
  if procNode.len < 4:
    return ""
  
  let paramsNode = procNode[3]
  if paramsNode == nil or paramsNode.kind != nkFormalParams:
    return ""
  
  # Первый элемент в FormalParams - это возвращаемый тип
  if paramsNode.len > 0 and paramsNode[0].kind != nkEmpty:
    return parser.extractTypeString(paramsNode[0])
  
  return ""

proc extractProcParams*(parser: NimParser, procNode: NimNode): seq[NimParamInfo] =
  ## Извлекает параметры процедуры
  result = @[]
  
  if procNode == nil or procNode.kind notin {nkProcDef, nkMethodDef, nkFuncDef}:
    return
  
  if procNode.len < 4:
    return
  
  let paramsNode = procNode[3]
  if paramsNode == nil or paramsNode.kind != nkFormalParams:
    return
  
  # Пропускаем первый элемент (возвращаемый тип)
  for i in 1..<paramsNode.len:
    let paramNode = paramsNode[i]
    if paramNode.kind == nkIdentDefs:
      # IdentDefs: [name1, name2, ..., type, default]
      let paramCount = paramNode.len - 2  # Исключаем тип и значение по умолчанию
      let typeNode = paramNode[paramCount]
      let paramType = parser.extractTypeString(typeNode)
      
      # Извлекаем имена параметров
      for j in 0..<paramCount:
        let nameNode = paramNode[j]
        var paramName = ""
        
        case nameNode.kind:
        of nkIdent:
          paramName = nameNode.ident.s
        of nkPostfix:
          if nameNode.len > 1:
            paramName = nameNode[1].ident.s
        else:
          paramName = fmt"param{j}"
        
        result.add(NimParamInfo(
          name: paramName,
          nimType: paramType
        ))

proc extractObjectFields*(parser: NimParser, typeNode: NimNode): seq[NimFieldInfo] =
  ## Извлекает поля объекта из определения типа
  result = @[]
  
  if typeNode == nil or typeNode.kind != nkTypeDef:
    return
  
  if typeNode.len < 3:
    return
  
  # Ищем объектное определение
  let typeDefNode = typeNode[2]
  var objectNode: NimNode = nil
  
  case typeDefNode.kind:
  of nkObjectTy:
    objectNode = typeDefNode
  of nkRefTy:
    # ref object
    if typeDefNode.len > 0 and typeDefNode[0].kind == nkObjectTy:
      objectNode = typeDefNode[0]
  of nkPtrTy:
    # ptr object
    if typeDefNode.len > 0 and typeDefNode[0].kind == nkObjectTy:
      objectNode = typeDefNode[0]
  else:
    return
  
  if objectNode == nil:
    return
  
  # Ищем список полей
  var recListNode: NimNode = nil
  for child in objectNode:
    if child.kind == nkRecList:
      recListNode = child
      break
  
  if recListNode == nil:
    return
  
  # Извлекаем поля
  for fieldNode in recListNode:
    if fieldNode.kind == nkIdentDefs:
      # IdentDefs: [name1, name2, ..., type, default]
      let fieldCount = fieldNode.len - 2
      let typeNode = fieldNode[fieldCount]
      let fieldType = parser.extractTypeString(typeNode)
      
      for i in 0..<fieldCount:
        let nameNode = fieldNode[i]
        var fieldName = ""
        var exported = false
        
        case nameNode.kind:
        of nkIdent:
          fieldName = nameNode.ident.s
          exported = false
        of nkPostfix:
          if nameNode.len > 1:
            fieldName = nameNode[1].ident.s
            exported = nameNode[0].ident.s == "*"
        else:
          fieldName = fmt"field{i}"
        
        result.add(NimFieldInfo(
          name: fieldName,
          nimType: fieldType,
          exported: exported
        ))

proc extractMethodClass*(parser: NimParser, methodNode: NimNode): string =
  ## Извлекает класс для метода (первый параметр)
  if methodNode == nil or methodNode.kind != nkMethodDef:
    return ""
  
  let params = parser.extractProcParams(methodNode)
  if params.len > 0:
    # Первый параметр метода - это self/this
    let firstParamType = params[0].nimType
    # Убираем ref/ptr если есть
    return firstParamType.replace("ref ", "").replace("ptr ", "").strip()
  
  return ""

proc extractValueString*(parser: NimParser, valueNode: NimNode): string =
  ## Извлекает строковое представление значения
  if valueNode == nil:
    return ""
  
  case valueNode.kind:
  of nkStrLit..nkTripleStrLit:
    return "\"" & valueNode.strVal & "\""
  of nkIntLit..nkUInt64Lit:
    return $valueNode.intVal
  of nkFloatLit..nkFloat128Lit:
    return $valueNode.floatVal
  of nkIdent:
    return valueNode.ident.s
  of nkSym:
    return valueNode.sym.name.s
  of nkNilLit:
    return "nil"
  else:
    return $valueNode.kind

proc extractConstants*(parser: NimParser, ast: NimNode): seq[tuple[name: string, value: string, nimType: string]] =
  ## Извлекает константы из AST
  result = @[]
  
  for node in parser.walkNodes(ast):
    if node.kind == nkConstSection:
      for constNode in node:
        if constNode.kind == nkConstDef and constNode.len >= 3:
          let nameNode = constNode[0]
          let typeNode = constNode[1]
          let valueNode = constNode[2]
          
          let constName = case nameNode.kind:
            of nkIdent: nameNode.ident.s
            of nkPostfix: 
              if nameNode.len > 1: nameNode[1].ident.s
              else: ""
            else: ""
          
          let constType = if typeNode.kind != nkEmpty:
                           parser.extractTypeString(typeNode)
                         else: "auto"
          
          let constValue = parser.extractValueString(valueNode)
          
          if constName.len > 0:
            result.add((name: constName, value: constValue, nimType: constType))

proc extractImports*(parser: NimParser, ast: NimNode): seq[string] =
  ## Извлекает все импорты из AST
  result = @[]
  
  for node in parser.walkNodes(ast):
    if node.kind == nkImportStmt:
      for importNode in node:
        let importName = parser.extractTypeString(importNode)
        if importName.len > 0:
          result.add(importName)

proc extractTemplates*(parser: NimParser, ast: NimNode): seq[string] =
  ## Извлекает шаблоны из AST
  result = @[]
  
  for node in parser.walkNodes(ast):
    if node.kind == nkTemplateDef:
      let templateName = parser.extractProcName(node)
      if templateName.len > 0:
        result.add(templateName)

proc extractMacros*(parser: NimParser, ast: NimNode): seq[string] =
  ## Извлекает макросы из AST
  result = @[]
  
  for node in parser.walkNodes(ast):
    if node.kind == nkMacroDef:
      let macroName = parser.extractProcName(node)
      if macroName.len > 0:
        result.add(macroName)

proc validateNimAST*(parser: NimParser, ast: NimNode): bool =
  ## Проверяет корректность Nim AST
  if ast == nil:
    echo "Error: AST is nil"
    return false
  
  if ast.kind != nkStmtList:
    echo fmt"Warning: Expected nkStmtList, got {ast.kind}"
  
  return true

proc printNimASTDebug*(parser: NimParser, node: NimNode, indent: int = 0) =
  ## Выводит отладочную информацию об AST
  if node == nil:
    return
  
  let indentStr = "  ".repeat(indent)
  echo fmt"{indentStr}{node.kind}"
  
  case node.kind:
  of nkIdent:
    echo fmt"{indentStr}  ident: {node.ident.s}"
  of nkSym:
    echo fmt"{indentStr}  sym: {node.sym.name.s}"
  of nkStrLit..nkTripleStrLit:
    echo fmt"{indentStr}  str: {node.strVal}"
  of nkIntLit..nkUInt64Lit:
    echo fmt"{indentStr}  int: {node.intVal}"
  else:
    discard
  
  for child in node:
    parser.printNimASTDebug(child, indent + 1)

proc findNodesByKind*(parser: NimParser, ast: NimNode, kind: TNodeKind): seq[NimNode] =
  ## Находит все узлы определенного типа
  result = @[]
  
  for node in parser.walkNodes(ast):
    if node.kind == kind:
      result.add(node)

proc extractProcSignature*(parser: NimParser, procNode: NimNode): string =
  ## Извлекает полную сигнатуру процедуры
  if procNode == nil or procNode.kind notin {nkProcDef, nkMethodDef, nkFuncDef}:
    return ""
  
  let procName = parser.extractProcName(procNode)
  let params = parser.extractProcParams(procNode)
  let returnType = parser.extractReturnType(procNode)
  
  var paramStrs: seq[string] = @[]
  for param in params:
    paramStrs.add(fmt"{param.name}: {param.nimType}")
  
  let paramStr = paramStrs.join(", ")
  let retStr = if returnType.len > 0: fmt": {returnType}" else: ""
  
  return fmt"{procName}({paramStr}){retStr}"

proc extractTypeSignature*(parser: NimParser, typeNode: NimNode): string =
  ## Извлекает полную сигнатуру типа
  if typeNode == nil or typeNode.kind != nkTypeDef:
    return ""
  
  let typeName = parser.extractTypeName(typeNode)
  let fields = parser.extractObjectFields(typeNode)
  
  var result = fmt"type {typeName} = object"
  if fields.len > 0:
    result.add(" {")
    for field in fields:
      let exportMark = if field.exported: "*" else: ""
      result.add(fmt" {field.name}{exportMark}: {field.nimType};")
    result.add(" }")
  
  return result

proc getNodeLocation*(parser: NimParser, node: NimNode): tuple[line: int, column: int] =
  ## Получает позицию узла в исходном коде
  if node == nil:
    return (line: 0, column: 0)
  
  return (line: node.info.line.int, column: node.info.col.int)

proc extractComments*(parser: NimParser, ast: NimNode): seq[string] =
  ## Извлекает комментарии из AST (если доступны)
  result = @[]
  
  for node in parser.walkNodes(ast):
    if node.kind == nkCommentStmt:
      result.add(node.comment)

proc isGenericType*(parser: NimParser, typeNode: NimNode): bool =
  ## Проверяет, является ли тип generic
  if typeNode == nil:
    return false
  
  case typeNode.kind:
  of nkBracketExpr:
    return true
  of nkGenericParams:
    return true
  else:
    return false

proc extractGenericParams*(parser: NimParser, typeNode: NimNode): seq[string] =
  ## Извлекает параметры generic типа
  result = @[]
  
  if typeNode == nil:
    return
  
  case typeNode.kind:
  of nkBracketExpr:
    for i in 1..<typeNode.len:
      result.add(parser.extractTypeString(typeNode[i]))
  
  of nkGenericParams:
    for paramNode in typeNode.sons:
      if paramNode.kind == nkIdentDefs:
        for i in 0..<paramNode.len-2:
          let nameNode = paramNode[i]
          if nameNode.kind == nkIdent:
            result.add(nameNode.ident.s)
  
  else:
    discard

proc hasPublicAPI*(parser: NimParser, ast: NimNode): bool =
  ## Проверяет, есть ли в модуле публичный API
  for node in parser.walkNodes(ast):
    if parser.isExported(node):
      return true
  return false

proc extractModuleInfo*(parser: NimParser, ast: NimNode): tuple[name: string, hasPublicAPI: bool, imports: seq[string]] =
  ## Извлекает общую информацию о модуле
  let imports = parser.extractImports(ast)
  let hasAPI = parser.hasPublicAPI(ast)
  
  # Имя модуля обычно не содержится в AST, нужно передавать отдельно
  return (name: "", hasPublicAPI: hasAPI, imports: imports)

proc getNodeChildren*(parser: NimParser, node: NimNode): seq[NimNode] =
  ## Получает прямых потомков узла
  result = @[]
  
  if node == nil:
    return
  
  for child in node:
    result.add(child)

proc findNodeByName*(parser: NimParser, ast: NimNode, name: string, kind: TNodeKind): NimNode =
  ## Ищет узел по имени и типу
  for node in parser.walkNodes(ast):
    if node.kind == kind:
      var nodeName = ""
      
      case kind:
      of nkTypeDef:
        nodeName = parser.extractTypeName(node)
      of nkProcDef, nkMethodDef, nkFuncDef:
        nodeName = parser.extractProcName(node)
      else:
        continue
      
      if nodeName == name:
        return node
  
  return nil

proc extractEnums*(parser: NimParser, ast: NimNode): seq[tuple[name: string, values: seq[string]]] =
  ## Извлекает перечисления из AST
  result = @[]
  
  for node in parser.walkNodes(ast):
    if node.kind == nkTypeDef and node.len >= 3:
      let typeDefNode = node[2]
      if typeDefNode.kind == nkEnumTy:
        let enumName = parser.extractTypeName(node)
        var enumValues: seq[string] = @[]
        
        for enumNode in typeDefNode.sons:
          case enumNode.kind:
          of nkIdent:
            enumValues.add(enumNode.ident.s)
          of nkEnumFieldDef:
            if enumNode.len > 0 and enumNode[0].kind == nkIdent:
              enumValues.add(enumNode[0].ident.s)
          else:
            discard
        
        if enumName.len > 0:
          result.add((name: enumName, values: enumValues))

proc extractAliases*(parser: NimParser, ast: NimNode): seq[tuple[name: string, target: string]] =
  ## Извлекает алиасы типов
  result = @[]
  
  for node in parser.walkNodes(ast):
    if node.kind == nkTypeDef and node.len >= 3:
      let typeDefNode = node[2]
      # Простой алиас - это когда правая часть это просто другой тип
      if typeDefNode.kind in {nkIdent, nkSym, nkBracketExpr}:
        let aliasName = parser.extractTypeName(node)
        let targetType = parser.extractTypeString(typeDefNode)
        
        if aliasName.len > 0 and targetType.len > 0:
          result.add((name: aliasName, target: targetType))
