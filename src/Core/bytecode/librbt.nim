## RBT (Ryton Bytecode Tech) Library
## Декларативный API для создания AST узлов Ryton

import std/[json, strformat, strutils, sequtils, tables, times, os]

type
  RBTAccess* = enum
    raPublic = "public"
    raPrivate = "private"
    raProtected = "protected"

  RBTScope* = enum
    rsGlobal = "global"
    rsLocal = "local"

  RBTGeneric* = object
    name*: string
    constraints*: seq[string]

  RBTParam* = object
    name*: string
    contentType*: string
    defaultContent*: JsonNode

  RBTNamespace* = object
    name*: string
    access*: RBTAccess
    content*: seq[string]

  RBTMetadata* = object
    sourceLang*: string
    sourceLangVersion*: string
    sourceFile*: string
    outputFile*: string
    generatorName*: string
    generatorVersion*: string
    projectName*: string
    projectAuthor*: string
    projectVersion*: string

  RBTException* = object of CatchableError
    errorType*: string
    errorText*: string
    levelDanger*: int

  RBTBuilder* = ref object
    ast*: JsonNode
    namespaces*: Table[string, RBTNamespace]
    metadata*: RBTMetadata
    currentBlock*: JsonNode

  RBTBlock* = ref object
    builder*: RBTBuilder
    blockNode*: JsonNode

# ============================================================================
# СОЗДАНИЕ BUILDER
# ============================================================================

proc createRBTGenerator*(): RBTBuilder =
  RBTBuilder(
    ast: %*{
      "kind": "nkProgram",
      "body": []
    },
    namespaces: initTable[string, RBTNamespace](),
    metadata: RBTMetadata(
      generatorName: "RBTGENCL",
      generatorVersion: "0.2.5"
    ),
    currentBlock: nil
  )

# ============================================================================
# МЕТАДАННЫЕ
# ============================================================================

proc setMetadata*(builder: RBTBuilder, sourceLang, sourceLangVersion, sourceFile, 
                 outputFile, projectName, projectAuthor, projectVersion: string): RBTBuilder =
  builder.metadata.sourceLang = sourceLang
  builder.metadata.sourceLangVersion = sourceLangVersion
  builder.metadata.sourceFile = sourceFile
  builder.metadata.outputFile = outputFile
  builder.metadata.projectName = projectName
  builder.metadata.projectAuthor = projectAuthor
  builder.metadata.projectVersion = projectVersion
  return builder

# ============================================================================
# ПРОСТРАНСТВА ИМЁН
# ============================================================================

proc createNameSpace*(builder: RBTBuilder, name: string): RBTBuilder =
  let ns = RBTNamespace(
    name: name,
    access: raPrivate,
    content: @[]
  )
  builder.namespaces[name] = ns
  return builder

proc setAccess*(builder: RBTBuilder, access: string): RBTBuilder =
  for name, ns in builder.namespaces.mpairs:
    case access:
    of "public": ns.access = raPublic
    of "private": ns.access = raPrivate
    of "protected": ns.access = raProtected
  return builder

# ============================================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ДЛЯ СОЗДАНИЯ УЗЛОВ
# ============================================================================

proc createIdent*(value: string): JsonNode =
  %*{
    "kind": "nkIdent",
    "ident": value
  }

proc createNumber*(value: string): JsonNode =
  %*{
    "kind": "nkNumber",
    "numVal": value
  }

proc createString*(value: string): JsonNode =
  %*{
    "kind": "nkString",
    "strVal": value
  }

proc createBool*(value: bool): JsonNode =
  %*{
    "kind": "nkBool",
    "boolVal": value
  }

proc createBinaryOp*(op: string, left, right: JsonNode): JsonNode =
  %*{
    "kind": "nkBinary",
    "binOp": op,
    "binLeft": left,
    "binRight": right
  }

proc createBinaryOp*(op: string, left, right: string): JsonNode =
  createBinaryOp(op, createIdent(left), createIdent(right))

proc createUnaryOp*(op: string, expr: JsonNode): JsonNode =
  %*{
    "kind": "nkUnary",
    "unOp": op,
    "unExpr": expr
  }

proc createRange*(start, endExpr: string, inclusive: bool): JsonNode =
  %*{
    "kind": "nkRangeExpr",
    "rangeStart": createIdent(start),
    "rangeEnd": createIdent(endExpr),
    "inclusive": inclusive
  }

# ============================================================================
# БЛОКИ КОДА
# ============================================================================

proc beginBlock*(builder: RBTBuilder): RBTBlock =
  let blockNode = %*{
    "kind": "nkBlock",
    "body": []
  }
  RBTBlock(
    builder: builder,
    blockNode: blockNode
  )

proc addInstruction*(blockRef: RBTBlock, instruction: JsonNode): RBTBlock =
  blockRef.blockNode["body"].add(instruction)
  return blockRef

proc endBlock*(blockRef: RBTBlock): JsonNode =
  return blockRef.blockNode

# ============================================================================
# ФУНКЦИИ
# ============================================================================

proc createFunction*(builder: RBTBuilder, name: string): RBTBuilder =
  let funcNode = %*{
    "kind": "nkFuncDef",
    "name": name,
    "access": "public",
    "generics": [],
    "params": [],
    "returnType": "",
    "returnTypeModifier": "",
    "modifiers": [],
    "body": {
      "kind": "nkBlock",
      "body": []
    }
  }
  builder.currentBlock = funcNode
  return builder

proc addParams*(builder: RBTBuilder, name, contentType: string, defaultContent: string = ""): RBTBuilder =
  if builder.currentBlock != nil and builder.currentBlock.hasKey("params"):
    let paramNode = %*{
      "kind": "nkParam",
      "name": name,
      "paramType": contentType,
      "paramTypeModifier": "",
      "defaultValue": if defaultContent != "": createString(defaultContent) else: newJNull()
    }
    builder.currentBlock["params"].add(paramNode)
  return builder

proc setReturnType*(builder: RBTBuilder, returnType: string): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["returnType"] = %returnType
  return builder

proc addModificators*(builder: RBTBuilder, modifiers: seq[string]): RBTBuilder =
  if builder.currentBlock != nil and builder.currentBlock.hasKey("modifiers"):
    for modifier in modifiers:
      builder.currentBlock["modifiers"].add(%modifier)
  return builder

proc addGeneric*(builder: RBTBuilder, name: string, constraints: seq[string] = @[]): RBTBuilder =
  if builder.currentBlock != nil and builder.currentBlock.hasKey("generics"):
    let genericNode = %*{
      "kind": "nkGenericParam",
      "name": name,
      "constraints": []
    }
    for constraint in constraints:
      genericNode["constraints"].add(%*{
        "kind": "nkGenericConstraint",
        "constraintType": constraint
      })
    builder.currentBlock["generics"].add(genericNode)
  return builder

proc addToNameSpace*(builder: RBTBuilder, namespaceName: string): RBTBuilder =
  if builder.namespaces.hasKey(namespaceName) and builder.currentBlock != nil:
    if builder.currentBlock.hasKey("name"):
      builder.namespaces[namespaceName].content.add(builder.currentBlock["name"].getStr())
  return builder

# ============================================================================
# КЛАССЫ (PACKS)
# ============================================================================

proc createClass*(builder: RBTBuilder, name: string): RBTBuilder =
  let classNode = %*{
    "kind": "nkPackDef",
    "name": name,
    "access": "public",
    "generics": [],
    "parents": [],
    "modifiers": [],
    "body": {
      "kind": "nkBlock",
      "body": []
    }
  }
  builder.currentBlock = classNode
  return builder

# ============================================================================
# СТРУКТУРЫ
# ============================================================================

proc createStruct*(builder: RBTBuilder, name: string): RBTBuilder =
  let structNode = %*{
    "kind": "nkStructDef",
    "name": name,
    "access": "public",
    "generics": [],
    "fields": [],
    "methods": []
  }
  builder.currentBlock = structNode
  return builder

# ============================================================================
# ПЕРЕЧИСЛЕНИЯ
# ============================================================================

proc createEnum*(builder: RBTBuilder, name: string): RBTBuilder =
  let enumNode = %*{
    "kind": "nkEnumDef",
    "name": name,
    "access": "public",
    "variants": [],
    "methods": []
  }
  builder.currentBlock = enumNode
  return builder

# ============================================================================
# СОБЫТИЯ
# ============================================================================

proc createEvent*(builder: RBTBuilder, name: string): RBTBuilder =
  let eventNode = %*{
    "kind": "nkEvent",
    "name": name,
    "scope": "local",
    "condition": newJNull(),
    "body": {
      "kind": "nkBlock",
      "body": []
    }
  }
  builder.currentBlock = eventNode
  return builder

proc setScope*(builder: RBTBuilder, scope: string): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["scope"] = %scope
  return builder

proc setCondition*(builder: RBTBuilder, condition: JsonNode): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["condition"] = condition
  return builder

# ============================================================================
# СОСТОЯНИЯ
# ============================================================================

proc createState*(builder: RBTBuilder, name: string): RBTBuilder =
  let stateNode = %*{
    "kind": "nkState",
    "name": name,
    "body": {
      "kind": "nkStateBody",
      "methods": [],
      "vars": [],
      "watchers": []
    }
  }
  builder.currentBlock = stateNode
  return builder

# ============================================================================
# ЛЯМБДА ФУНКЦИИ
# ============================================================================

proc createLambda*(builder: RBTBuilder): RBTBuilder =
  let lambdaNode = %*{
    "kind": "nkLambdaDef",
    "params": [],
    "generics": [],
    "returnType": "",
    "returnTypeModifier": "",
    "modifiers": [],
    "body": {
      "kind": "nkBlock",
      "body": []
    }
  }
  builder.currentBlock = lambdaNode
  return builder

# ============================================================================
# ИНСТРУКЦИИ
# ============================================================================

proc createInstruction*(builder: RBTBuilder, kind: string): RBTBuilder =
  case kind:
  of "nkIf":
    builder.currentBlock = %*{
      "kind": "nkIf",
      "condition": newJNull(),
      "thenBranch": {"kind": "nkBlock", "body": []},
      "elifBranches": [],
      "elseBranch": newJNull()
    }
  of "nkFor":
    builder.currentBlock = %*{
      "kind": "nkFor",
      "variable": "",
      "range": {
        "start": newJNull(),
        "inclusive": true,
        "endExpr": newJNull()
      },
      "body": {"kind": "nkBlock", "body": []}
    }
  of "nkEach":
    builder.currentBlock = %*{
      "kind": "nkEach",
      "variable": "",
      "start": newJNull(),
      "endExpr": newJNull(),
      "step": newJNull(),
      "where": newJNull(),
      "body": {"kind": "nkBlock", "body": []}
    }
  of "nkWhile":
    builder.currentBlock = %*{
      "kind": "nkWhile",
      "condition": newJNull(),
      "body": {"kind": "nkBlock", "body": []}
    }
  of "nkInfinit":
    builder.currentBlock = %*{
      "kind": "nkInfinit",
      "delay": newJNull(),
      "body": {"kind": "nkBlock", "body": []}
    }
  of "nkRepeat":
    builder.currentBlock = %*{
      "kind": "nkRepeat",
      "count": newJNull(),
      "delay": newJNull(),
      "body": {"kind": "nkBlock", "body": []}
    }
  of "nkSwitch":
    builder.currentBlock = %*{
      "kind": "nkSwitch",
      "expr": newJNull(),
      "cases": [],
      "defaultCase": newJNull()
    }
  of "nkTry":
    builder.currentBlock = %*{
      "kind": "nkTry",
      "tryBody": {"kind": "nkBlock", "body": []},
      "errorType": "",
      "catchBody": {"kind": "nkBlock", "body": []}
    }
  of "nkReturn":
    builder.currentBlock = %*{
      "kind": "nkReturn",
      "value": newJNull()
    }
  of "nkAssign":
    builder.currentBlock = %*{
      "kind": "nkAssign",
      "declType": "dtNone",
      "assignOp": "=",
      "target": newJNull(),
      "value": newJNull(),
      "varType": "",
      "varTypeModifier": ""
    }
  of "nkCall":
    builder.currentBlock = %*{
      "kind": "nkCall",
      "function": newJNull(),
      "args": []
    }
  of "nkVarDef":
    builder.currentBlock = %*{
      "kind": "nkAssign",
      "declType": "dtDef",
      "assignOp": "=",
      "target": newJNull(),
      "value": newJNull(),
      "varType": "",
      "varTypeModifier": ""
    }
  of "nkFieldDef":
    builder.currentBlock = %*{
      "kind": "nkFieldDef",
      "name": "",
      "fieldType": "",
      "defaultValue": newJNull()
    }
  of "nkEnumVariant":
    builder.currentBlock = %*{
      "kind": "nkEnumVariant",
      "name": "",
      "value": newJNull()
    }
  return
# ============================================================================
# УСТАНОВКА ПАРАМЕТРОВ ИНСТРУКЦИЙ
# ============================================================================

proc setVariable*(builder: RBTBuilder, variable: string): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["variable"] = %variable
  return builder

proc setRange*(builder: RBTBuilder, start, endExpr: string, inclusive: bool): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["range"] = %*{
      "start": createIdent(start),
      "inclusive": inclusive,
      "endExpr": createIdent(endExpr)
    }
  return builder

proc setStart*(builder: RBTBuilder, start: string): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["start"] = createIdent(start)
  return builder

proc setEnd*(builder: RBTBuilder, endExpr: string): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["endExpr"] = createIdent(endExpr)
  return builder

proc setStep*(builder: RBTBuilder, step: string): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["step"] = createIdent(step)
  return builder

proc setWhere*(builder: RBTBuilder, where: JsonNode): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["where"] = where
  return builder

proc setDelay*(builder: RBTBuilder, delay: string): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["delay"] = createIdent(delay)
  return builder

proc setExpression*(builder: RBTBuilder, expr: JsonNode): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["expr"] = expr
  return builder

proc setErrorType*(builder: RBTBuilder, errorType: string): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["errorType"] = %errorType
  return builder

# ============================================================================
# БЛОКИ ДЛЯ УСЛОВНЫХ КОНСТРУКЦИЙ
# ============================================================================

proc beginThenBlock*(builder: RBTBuilder): RBTBlock =
  if builder.currentBlock != nil and builder.currentBlock.hasKey("thenBranch"):
    let blockNode = %*{
      "kind": "nkBlock",
      "body": []
    }
    builder.currentBlock["thenBranch"] = blockNode
    return RBTBlock(builder: builder, blockNode: blockNode)
  return nil

proc beginElseBlock*(builder: RBTBuilder): RBTBlock =
  if builder.currentBlock != nil:
    let blockNode = %*{
      "kind": "nkBlock",
      "body": []
    }
    builder.currentBlock["elseBranch"] = blockNode
    return RBTBlock(builder: builder, blockNode: blockNode)
  return nil

proc beginTryBlock*(builder: RBTBuilder): RBTBlock =
  if builder.currentBlock != nil and builder.currentBlock.hasKey("tryBody"):
    let blockNode = %*{
      "kind": "nkBlock",
      "body": []
    }
    builder.currentBlock["tryBody"] = blockNode
    return RBTBlock(builder: builder, blockNode: blockNode)
  return nil

proc beginErrorBlock*(builder: RBTBuilder): RBTBlock =
  if builder.currentBlock != nil and builder.currentBlock.hasKey("catchBody"):
    let blockNode = %*{
      "kind": "nkBlock",
      "body": []
    }
    builder.currentBlock["catchBody"] = blockNode
    return RBTBlock(builder: builder, blockNode: blockNode)
  return nil

# ============================================================================
# SWITCH КОНСТРУКЦИИ
# ============================================================================

proc createCase*(builder: RBTBuilder): RBTBuilder =
  if builder.currentBlock != nil and builder.currentBlock.hasKey("cases"):
    let caseNode = %*{
      "kind": "nkSwitchCase",
      "conditions": [],
      "body": {"kind": "nkBlock", "body": []},
      "guard": newJNull()
    }
    builder.currentBlock["cases"].add(caseNode)
    builder.currentBlock = caseNode
  return builder

proc addCondition*(builder: RBTBuilder, condition: JsonNode): RBTBuilder =
  if builder.currentBlock != nil and builder.currentBlock.hasKey("conditions"):
    builder.currentBlock["conditions"].add(condition)
  return builder

proc setGuard*(builder: RBTBuilder, guard: JsonNode): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["guard"] = guard
  return builder

proc createDefault*(builder: RBTBuilder): RBTBuilder =
  if builder.currentBlock != nil:
    let defaultNode = %*{
      "kind": "nkBlock",
      "body": []
    }
    builder.currentBlock["defaultCase"] = defaultNode
    builder.currentBlock = defaultNode
  return builder

# ============================================================================
# МАССИВЫ И ТАБЛИЦЫ
# ============================================================================

proc createArray*(builder: RBTBuilder): RBTBuilder =
  builder.currentBlock = %*{
    "kind": "nkArray",
    "elements": []
  }
  return builder

proc addElement*(builder: RBTBuilder, element: JsonNode): RBTBuilder =
  if builder.currentBlock != nil and builder.currentBlock.hasKey("elements"):
    builder.currentBlock["elements"].add(element)
  return builder

proc createTable*(builder: RBTBuilder): RBTBuilder =
  builder.currentBlock = %*{
    "kind": "nkTable",
    "pairs": []
  }
  return builder

proc addPair*(builder: RBTBuilder, key, value: JsonNode): RBTBuilder =
  if builder.currentBlock != nil and builder.currentBlock.hasKey("pairs"):
    let pairNode = %*{
      "kind": "nkTablePair",
      "key": key,
      "value": value
    }
    builder.currentBlock["pairs"].add(pairNode)
  return builder

# ============================================================================
# ДОСТУП К ЭЛЕМЕНТАМ
# ============================================================================

proc createArrayAccess*(builder: RBTBuilder): RBTBuilder =
  builder.currentBlock = %*{
    "kind": "nkArrayAccess",
    "array": newJNull(),
    "index": newJNull()
  }
  return builder

proc setArray*(builder: RBTBuilder, arrayNode: JsonNode): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["array"] = arrayNode
  return builder

proc setIndex*(builder: RBTBuilder, index: JsonNode): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["index"] = index
  return builder

proc createPropertyAccess*(builder: RBTBuilder): RBTBuilder =
  builder.currentBlock = %*{
    "kind": "nkProperty",
    "object": newJNull(),
    "property": ""
  }
  return builder

proc setObject*(builder: RBTBuilder, objectNode: JsonNode): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["object"] = objectNode
  return builder

proc setProperty*(builder: RBTBuilder, property: string): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["property"] = %property
  return builder

# ============================================================================
# ФОРМАТИРОВАННЫЕ СТРОКИ
# ============================================================================

proc createFormatString*(builder: RBTBuilder): RBTBuilder =
  builder.currentBlock = %*{
    "kind": "nkFormatString",
    "formatter": "",
    "content": "",
    "variables": []
  }
  return builder

proc setFormatter*(builder: RBTBuilder, formatter: string): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["formatter"] = %formatter
  return builder

proc setContent*(builder: RBTBuilder, content: string): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["content"] = %content
  return builder

proc addVariable*(builder: RBTBuilder, name: string, value: JsonNode): RBTBuilder =
  if builder.currentBlock != nil and builder.currentBlock.hasKey("variables"):
    builder.currentBlock["variables"].add(%*{
      "name": name,
      "value": value
    })
  return builder

# ============================================================================
# ТИПОВЫЕ ПРОВЕРКИ
# ============================================================================

proc createTypeCheck*(builder: RBTBuilder): RBTBuilder =
  builder.currentBlock = %*{
    "kind": "nkTypeCheck",
    "checkType": "",
    "expr": newJNull(),
    "checkFunction": "",
    "body": {"kind": "nkBlock", "body": []}
  }
  return builder

proc setType*(builder: RBTBuilder, checkType: string): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["checkType"] = %checkType
  return builder

proc setCheckFunction*(builder: RBTBuilder, checkFunction: string): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["checkFunction"] = %checkFunction
  return builder

# ============================================================================
# ИМПОРТЫ
# ============================================================================

proc createRytonImport*(builder: RBTBuilder): RBTBuilder =
  builder.currentBlock = %*{
    "kind": "nkImport",
    "importType": "ryton",
    "path": [],
    "alias": "",
    "filters": []
  }
  return builder

proc createNimImport*(builder: RBTBuilder): RBTBuilder =
  builder.currentBlock = %*{
    "kind": "nkImport",
    "importType": "nim",
    "path": [],
    "alias": "",
    "filters": []
  }
  return builder

proc createRBTImport*(builder: RBTBuilder): RBTBuilder =
  builder.currentBlock = %*{
    "kind": "nkImport",
    "importType": "rbt",
    "path": [],
    "alias": "",
    "filters": []
  }
  return builder

proc setPath*(builder: RBTBuilder, path: seq[string]): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["path"] = %path
  return builder

proc setPath*(builder: RBTBuilder, path: string): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["path"] = %path
  return builder

proc setAlias*(builder: RBTBuilder, alias: string): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["alias"] = %alias
  return builder

proc addFilter*(builder: RBTBuilder, filter: string): RBTBuilder =
  if builder.currentBlock != nil and builder.currentBlock.hasKey("filters"):
    builder.currentBlock["filters"].add(%filter)
  return builder

# ============================================================================
# ВЫЗОВЫ ФУНКЦИЙ
# ============================================================================

proc setFunction*(builder: RBTBuilder, function: JsonNode): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["function"] = function
  return builder

proc addArgs*(builder: RBTBuilder, args: seq[JsonNode]): RBTBuilder =
  if builder.currentBlock != nil and builder.currentBlock.hasKey("args"):
    for arg in args:
      builder.currentBlock["args"].add(arg)
  return builder

proc addArg*(builder: RBTBuilder, arg: JsonNode): RBTBuilder =
  if builder.currentBlock != nil and builder.currentBlock.hasKey("args"):
    builder.currentBlock["args"].add(arg)
  return builder

# ============================================================================
# ПРИСВАИВАНИЯ И ПЕРЕМЕННЫЕ
# ============================================================================

proc setTarget*(builder: RBTBuilder, target: string): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["target"] = createIdent(target)
  return builder

proc setValue*(builder: RBTBuilder, value: JsonNode): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["value"] = value
  return builder

proc setVarType*(builder: RBTBuilder, varType: string): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["varType"] = %varType
  return builder

proc setName*(builder: RBTBuilder, name: string): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["name"] = %name
  return builder

proc setFieldType*(builder: RBTBuilder, fieldType: string): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["fieldType"] = %fieldType
  return builder

proc setDefaultValue*(builder: RBTBuilder, defaultValue: JsonNode): RBTBuilder =
  if builder.currentBlock != nil:
    builder.currentBlock["defaultValue"] = defaultValue
  return builder

# ============================================================================
# ДОБАВЛЕНИЕ УЗЛОВ В AST
# ============================================================================

proc addToAST*(builder: RBTBuilder, node: JsonNode): RBTBuilder =
  if builder.ast.hasKey("body"):
    builder.ast["body"].add(node)
  return builder

proc addCurrentToAST*(builder: RBTBuilder): RBTBuilder =
  if builder.currentBlock != nil:
    return builder.addToAST(builder.currentBlock)
  return builder

# ============================================================================
# ГЕНЕРАЦИЯ RBT ФАЙЛА
# ============================================================================

proc generateRBTFile*(builder: RBTBuilder, filename: string) =
  try:
    var namespacesJson = newJObject()
    for name, ns in builder.namespaces:
      namespacesJson[name] = %*{
        "access": $ns.access,
        "content": ns.content
      }
    
    let metaJson = %*{
      "sourceLang": builder.metadata.sourceLang,
      "sourceLangVersion": builder.metadata.sourceLangVersion,
      "sourceFile": builder.metadata.sourceFile,
      "outputFile": builder.metadata.outputFile,
      "generatorName": builder.metadata.generatorName,
      "generatorVersion": builder.metadata.generatorVersion,
      "projectName": builder.metadata.projectName,
      "projectAuthor": builder.metadata.projectAuthor,
      "projectVersion": builder.metadata.projectVersion
    }
    
    let rbtFile = %*{
      "header": "RBT",
      "version": "1.0",
      "ast": builder.ast,
      "namespaces": namespacesJson,
      "META": metaJson
    }
    
    writeFile(filename, rbtFile.pretty())
    echo fmt"RBT file generated: {filename}"
  except IOError as e:
    raise newException(RBTException, fmt"Error writing RBT file: {e.msg}")

# ============================================================================
# ЗАГРУЗКА RBT ФАЙЛА
# ============================================================================

proc loadRBTFile*(filename: string): RBTBuilder =
  try:
    let fileContent = readFile(filename)
    let jsonData = parseJson(fileContent)
    
    let builder = createRBTGenerator()
    
    if jsonData.hasKey("META"):
      let meta = jsonData["META"]
      builder.metadata.sourceLang = meta["sourceLang"].getStr()
      builder.metadata.sourceLangVersion = meta["sourceLangVersion"].getStr()
      builder.metadata.sourceFile = meta["sourceFile"].getStr()
      builder.metadata.outputFile = meta["outputFile"].getStr()
      builder.metadata.generatorName = meta["generatorName"].getStr()
      builder.metadata.generatorVersion = meta["generatorVersion"].getStr()
      builder.metadata.projectName = meta["projectName"].getStr()
      builder.metadata.projectAuthor = meta["projectAuthor"].getStr()
      builder.metadata.projectVersion = meta["projectVersion"].getStr()
    
    if jsonData.hasKey("namespaces"):
      for name, nsJson in jsonData["namespaces"]:
        var ns = RBTNamespace(
          name: name,
          content: @[]
        )
        case nsJson["access"].getStr():
        of "public": ns.access = raPublic
        of "private": ns.access = raPrivate
        of "protected": ns.access = raProtected
        
        for item in nsJson["content"]:
          ns.content.add(item.getStr())
        builder.namespaces[name] = ns
    
    if jsonData.hasKey("ast"):
      builder.ast = jsonData["ast"]
    
    return builder
  except IOError as e:
    raise newException(RBTException, fmt"Error reading RBT file: {e.msg}")
  except JsonParsingError as e:
    raise newException(RBTException, fmt"Error parsing RBT file: {e.msg}")

# ============================================================================
# ПРОЦЕДУРЫ ДЛЯ КАЖДОЙ КОНСТРУКЦИИ RYTON
# ============================================================================

proc generateProgram*(builder: RBTBuilder, statements: seq[JsonNode]): JsonNode =
  %*{
    "kind": "nkProgram",
    "body": statements
  }

proc generateBlock*(builder: RBTBuilder, statements: seq[JsonNode]): JsonNode =
  %*{
    "kind": "nkBlock",
    "body": statements
  }

proc generateExprStmt*(builder: RBTBuilder, expr: JsonNode): JsonNode =
  %*{
    "kind": "nkExprStmt",
    "expr": expr
  }

proc generateFuncDef*(builder: RBTBuilder, name: string, params: seq[JsonNode], 
                     generics: seq[JsonNode], returnType: string, 
                     returnTypeModifier: string, modifiers: seq[string], 
                     body: JsonNode, isPublic: bool): JsonNode =
  %*{
    "kind": "nkFuncDef",
    "name": name,
    "params": params,
    "generics": generics,
    "returnType": returnType,
    "returnTypeModifier": returnTypeModifier,
    "modifiers": modifiers,
    "body": body,
    "public": isPublic
  }

proc generateLambdaDef*(builder: RBTBuilder, params: seq[JsonNode], 
                       generics: seq[JsonNode], returnType: string,
                       returnTypeModifier: string, modifiers: seq[string],
                       body: JsonNode): JsonNode =
  %*{
    "kind": "nkLambdaDef",
    "params": params,
    "generics": generics,
    "returnType": returnType,
    "returnTypeModifier": returnTypeModifier,
    "modifiers": modifiers,
    "body": body
  }

proc generatePackDef*(builder: RBTBuilder, name: string, generics: seq[JsonNode],
                     parents: seq[string], modifiers: seq[string], 
                     body: JsonNode): JsonNode =
  %*{
    "kind": "nkPackDef",
    "name": name,
    "generics": generics,
    "parents": parents,
    "modifiers": modifiers,
    "body": body
  }

proc generateInit*(builder: RBTBuilder, params: seq[JsonNode], body: JsonNode): JsonNode =
  %*{
    "kind": "nkInit",
    "params": params,
    "body": body
  }

proc generateParam*(builder: RBTBuilder, name: string, paramType: string,
                   paramTypeModifier: string, defaultValue: JsonNode): JsonNode =
  %*{
    "kind": "nkParam",
    "name": name,
    "paramType": paramType,
    "paramTypeModifier": paramTypeModifier,
    "defaultValue": defaultValue
  }

proc generateStructDef*(builder: RBTBuilder, name: string, fields: seq[JsonNode],
                       methods: seq[JsonNode]): JsonNode =
  %*{
    "kind": "nkStructDef",
    "name": name,
    "fields": fields,
    "methods": methods
  }

proc generateEnumDef*(builder: RBTBuilder, name: string, variants: seq[JsonNode],
                     methods: seq[JsonNode]): JsonNode =
  %*{
    "kind": "nkEnumDef",
    "name": name,
    "variants": variants,
    "methods": methods
  }

proc generateEnumVariant*(builder: RBTBuilder, name: string, value: JsonNode): JsonNode =
  %*{
    "kind": "nkEnumVariant",
    "name": name,
    "value": value
  }

proc generateFieldDef*(builder: RBTBuilder, name: string, fieldType: string,
                      defaultValue: JsonNode): JsonNode =
  %*{
    "kind": "nkFieldDef",
    "name": name,
    "fieldType": fieldType,
    "defaultValue": defaultValue
  }

proc generateStructInit*(builder: RBTBuilder, structType: string, 
                        args: seq[JsonNode]): JsonNode =
  %*{
    "kind": "nkStructInit",
    "structType": structType,
    "args": args
  }

proc generateIf*(builder: RBTBuilder, condition: JsonNode, thenBranch: JsonNode,
                elifBranches: seq[tuple[cond: JsonNode, body: JsonNode]],
                elseBranch: JsonNode): JsonNode =
  var elifArray = newJArray()
  for elifBranch in elifBranches:
    elifArray.add(%*{
      "condition": elifBranch.cond,
      "body": elifBranch.body
    })
  
  %*{
    "kind": "nkIf",
    "condition": condition,
    "thenBranch": thenBranch,
    "elifBranches": elifArray,
    "elseBranch": elseBranch
  }

proc generateFor*(builder: RBTBuilder, variable: string, rangeStart: JsonNode,
                 rangeEnd: JsonNode, inclusive: bool, body: JsonNode): JsonNode =
  %*{
    "kind": "nkFor",
    "variable": variable,
    "range": {
      "start": rangeStart,
      "endExpr": rangeEnd,
      "inclusive": inclusive
    },
    "body": body
  }

proc generateEach*(builder: RBTBuilder, variable: string, start: JsonNode,
                  endExpr: JsonNode, step: JsonNode, where: JsonNode,
                  body: JsonNode): JsonNode =
  %*{
    "kind": "nkEach",
    "variable": variable,
    "start": start,
    "endExpr": endExpr,
    "step": step,
    "where": where,
    "body": body
  }

proc generateInfinit*(builder: RBTBuilder, delay: JsonNode, body: JsonNode): JsonNode =
  %*{
    "kind": "nkInfinit",
    "delay": delay,
    "body": body
  }

proc generateRepeat*(builder: RBTBuilder, count: JsonNode, delay: JsonNode,
                    body: JsonNode): JsonNode =
  %*{
    "kind": "nkRepeat",
    "count": count,
    "delay": delay,
    "body": body
  }

proc generateTry*(builder: RBTBuilder, tryBody: JsonNode, errorType: string,
                 catchBody: JsonNode): JsonNode =
  %*{
    "kind": "nkTry",
    "tryBody": tryBody,
    "errorType": errorType,
    "catchBody": catchBody
  }

proc generateEvent*(builder: RBTBuilder, condition: JsonNode, body: JsonNode): JsonNode =
  %*{
    "kind": "nkEvent",
    "condition": condition,
    "body": body
  }

proc generateImport*(builder: RBTBuilder, imports: seq[JsonNode]): JsonNode =
  %*{
    "kind": "nkImport",
    "imports": imports
  }

proc generateReturn*(builder: RBTBuilder, value: JsonNode): JsonNode =
  %*{
    "kind": "nkReturn",
    "value": value
  }

proc generateState*(builder: RBTBuilder, name: string, body: JsonNode): JsonNode =
  %*{
    "kind": "nkState",
    "name": name,
    "body": body
  }

proc generateStateBody*(builder: RBTBuilder, methods: seq[JsonNode],
                       vars: seq[JsonNode], watchers: seq[JsonNode]): JsonNode =
  %*{
    "kind": "nkStateBody",
    "methods": methods,
    "vars": vars,
    "watchers": watchers
  }

proc generateWhile*(builder: RBTBuilder, condition: JsonNode, body: JsonNode): JsonNode =
  %*{
    "kind": "nkWhile",
    "condition": condition,
    "body": body
  }

proc generateSwitch*(builder: RBTBuilder, expr: JsonNode, cases: seq[JsonNode],
                    defaultCase: JsonNode): JsonNode =
  %*{
    "kind": "nkSwitch",
    "expr": expr,
    "cases": cases,
    "defaultCase": defaultCase
  }

proc generateSwitchCase*(builder: RBTBuilder, conditions: seq[JsonNode],
                        body: JsonNode, guard: JsonNode): JsonNode =
  %*{
    "kind": "nkSwitchCase",
    "conditions": conditions,
    "body": body,
    "guard": guard
  }

proc generateBinary*(builder: RBTBuilder, op: string, left: JsonNode,
                    right: JsonNode): JsonNode =
  %*{
    "kind": "nkBinary",
    "binOp": op,
    "binLeft": left,
    "binRight": right
  }

proc generateUnary*(builder: RBTBuilder, op: string, expr: JsonNode): JsonNode =
  %*{
    "kind": "nkUnary",
    "unOp": op,
    "unExpr": expr
  }

proc generateCall*(builder: RBTBuilder, function: JsonNode, args: seq[JsonNode]): JsonNode =
  %*{
    "kind": "nkCall",
    "function": function,
    "args": args
  }

proc generateProperty*(builder: RBTBuilder, objectNode: JsonNode, property: string): JsonNode =
  %*{
    "kind": "nkProperty",
    "object": objectNode,
    "property": property
  }

proc generateGroup*(builder: RBTBuilder, expr: JsonNode): JsonNode =
  %*{
    "kind": "nkGroup",
    "expr": expr
  }

proc generateGenericParam*(builder: RBTBuilder, name: string,
                          constraints: seq[JsonNode]): JsonNode =
  %*{
    "kind": "nkGenericParam",
    "name": name,
    "constraints": constraints
  }

proc generateGenericConstraint*(builder: RBTBuilder, constraintType: string): JsonNode =
  %*{
    "kind": "nkGenericConstraint",
    "constraintType": constraintType
  }

proc generateAssign*(builder: RBTBuilder, declType: string, assignOp: string,
                    target: JsonNode, value: JsonNode, varType: string,
                    varTypeModifier: string): JsonNode =
  %*{
    "kind": "nkAssign",
    "declType": declType,
    "assignOp": assignOp,
    "target": target,
    "value": value,
    "varType": varType,
    "varTypeModifier": varTypeModifier
  }

proc generateIdent*(builder: RBTBuilder, ident: string): JsonNode =
  %*{
    "kind": "nkIdent",
    "ident": ident
  }

proc generateNumber*(builder: RBTBuilder, numVal: string): JsonNode =
  %*{
    "kind": "nkNumber",
    "numVal": numVal
  }

proc generateString*(builder: RBTBuilder, strVal: string): JsonNode =
  %*{
    "kind": "nkString",
    "strVal": strVal
  }

proc generateFormatString*(builder: RBTBuilder, formatType: string,
                          formatContent: string): JsonNode =
  %*{
    "kind": "nkFormatString",
    "formatType": formatType,
    "formatContent": formatContent
  }

proc generateBool*(builder: RBTBuilder, boolVal: bool): JsonNode =
  %*{
    "kind": "nkBool",
    "boolVal": boolVal
  }

proc generateArray*(builder: RBTBuilder, elements: seq[JsonNode]): JsonNode =
  %*{
    "kind": "nkArray",
    "elements": elements
  }

proc generateTable*(builder: RBTBuilder, pairs: seq[JsonNode]): JsonNode =
  %*{
    "kind": "nkTable",
    "pairs": pairs
  }

proc generateTablePair*(builder: RBTBuilder, key: JsonNode, value: JsonNode): JsonNode =
  %*{
    "kind": "nkTablePair",
    "key": key,
    "value": value
  }

proc generateTypeCheck*(builder: RBTBuilder, checkType: string, checkFunc: string,
                       checkBlock: JsonNode, checkExpr: JsonNode): JsonNode =
  %*{
    "kind": "nkTypeCheck",
    "checkType": checkType,
    "checkFunc": checkFunc,
    "checkBlock": checkBlock,
    "checkExpr": checkExpr
  }

proc generateArrayAccess*(builder: RBTBuilder, arrayNode: JsonNode,
                         index: JsonNode): JsonNode =
  %*{
    "kind": "nkArrayAccess",
    "array": arrayNode,
    "index": index
  }

proc generateSlice*(builder: RBTBuilder, sliceArray: JsonNode, startIndex: JsonNode,
                   endIndex: JsonNode, inclusive: bool): JsonNode =
  %*{
    "kind": "nkSlice",
    "sliceArray": sliceArray,
    "startIndex": startIndex,
    "endIndex": endIndex,
    "inclusive": inclusive
  }

proc generateTupleAccess*(builder: RBTBuilder, tupleObj: JsonNode,
                         fieldIndex: int): JsonNode =
  %*{
    "kind": "nkTupleAccess",
    "tupleObj": tupleObj,
    "fieldIndex": fieldIndex
  }

proc generateRangeExpr*(builder: RBTBuilder, rangeStart: JsonNode, rangeEnd: JsonNode,
                       rangeStep: JsonNode): JsonNode =
  %*{
    "kind": "nkRangeExpr",
    "rangeStart": rangeStart,
    "rangeEnd": rangeEnd,
    "rangeStep": rangeStep
  }

proc generateChainCall*(builder: RBTBuilder, chain: seq[JsonNode]): JsonNode =
  %*{
    "kind": "nkChainCall",
    "chain": chain
  }

proc generateSubscript*(builder: RBTBuilder, container: JsonNode,
                       indices: seq[JsonNode]): JsonNode =
  %*{
    "kind": "nkSubscript",
    "container": container,
    "indices": indices
  }

proc generateNoop*(builder: RBTBuilder): JsonNode =
  %*{
    "kind": "nkNoop"
  }

# ============================================================================
# ВАЛИДАЦИЯ RBT ФАЙЛОВ
# ============================================================================

proc validateRBTFile*(filename: string): bool =
  try:
    let fileContent = readFile(filename)
    let jsonData = parseJson(fileContent)
    
    # Проверяем обязательные поля
    if not jsonData.hasKey("header") or jsonData["header"].getStr() != "RBT":
      echo "Error: Invalid RBT header"
      return false
    
    if not jsonData.hasKey("version"):
      echo "Error: Missing version field"
      return false
    
    if not jsonData.hasKey("ast"):
      echo "Error: Missing AST field"
      return false
    
    # Проверяем версию
    let version = jsonData["version"].getStr()
    if version != "1.0":
      echo fmt"Warning: Unsupported RBT version: {version}"
    
    # Проверяем структуру AST
    let ast = jsonData["ast"]
    if not ast.hasKey("kind"):
      echo "Error: AST missing kind field"
      return false
    
    echo "RBT file validation successful"
    return true
    
  except IOError as e:
    echo fmt"Error reading file: {e.msg}"
    return false
  except JsonParsingError as e:
    echo fmt"Error parsing JSON: {e.msg}"
    return false

# ============================================================================
# КОНВЕРТАЦИЯ RBT В NIM
# ============================================================================

proc convertRBTToNim*(rbtFilename: string, nimFilename: string) =
  try:
    let builder = loadRBTFile(rbtFilename)
    
    # Здесь будет логика конвертации AST в Nim код
    var nimCode = ""
    
    # Добавляем заголовок
    nimCode &= "# Generated from RBT file: " & rbtFilename & "\n"
    nimCode &= "# Generator: " & builder.metadata.generatorName & " " & builder.metadata.generatorVersion & "\n\n"
    
    # Добавляем импорты
    for name, ns in builder.namespaces:
      if ns.access == raPublic:
        nimCode &= "import " & name & "\n"
    
    nimCode &= "\n"
    
    # Конвертируем AST в Nim код (упрощенная версия)
    proc convertNodeToNim(node: JsonNode, indent: int = 0): string =
      let indentStr = "  ".repeat(indent)
      
      if node.isNil or node.kind == JNull:
        return ""
      
      case node["kind"].getStr():
      of "nkProgram":
        result = ""
        if node.hasKey("body"):
          for stmt in node["body"]:
            result &= convertNodeToNim(stmt, indent) & "\n"
      
      of "nkBlock":
        result = ""
        if node.hasKey("body"):
          for stmt in node["body"]:
            result &= convertNodeToNim(stmt, indent) & "\n"
      
      of "nkFuncDef":
        result = indentStr & "proc " & node["name"].getStr() & "("
        if node.hasKey("params"):
          var paramStrs: seq[string] = @[]
          for param in node["params"]:
            var paramStr = param["name"].getStr()
            if param.hasKey("paramType") and param["paramType"].getStr() != "":
              paramStr &= ": " & param["paramType"].getStr()
            paramStrs.add(paramStr)
          result &= paramStrs.join(", ")
        result &= ")"
        
        if node.hasKey("returnType") and node["returnType"].getStr() != "":
          result &= ": " & node["returnType"].getStr()
        
        result &= " =\n"
        if node.hasKey("body"):
          result &= convertNodeToNim(node["body"], indent + 1)
      
      of "nkIdent":
        result = node["ident"].getStr()
      
      of "nkNumber":
        result = node["numVal"].getStr()
      
      of "nkString":
        result = "\"" & node["strVal"].getStr() & "\""
      
      of "nkBool":
        result = if node["boolVal"].getBool(): "true" else: "false"
      
      of "nkCall":
        if node.hasKey("function"):
          result = convertNodeToNim(node["function"])
        result &= "("
        if node.hasKey("args"):
          var argStrs: seq[string] = @[]
          for arg in node["args"]:
            argStrs.add(convertNodeToNim(arg))
          result &= argStrs.join(", ")
        result &= ")"
      
      of "nkBinary":
        if node.hasKey("binLeft") and node.hasKey("binRight"):
          result = convertNodeToNim(node["binLeft"]) & " " & 
                  node["binOp"].getStr() & " " & 
                  convertNodeToNim(node["binRight"])
      
      of "nkAssign":
        if node.hasKey("target") and node.hasKey("value"):
          var declStr = ""
          if node.hasKey("declType"):
            case node["declType"].getStr():
            of "dtDef": declStr = "var "
            of "dtVal": declStr = "let "
          
          result = indentStr & declStr & convertNodeToNim(node["target"])
          
          if node.hasKey("varType") and node["varType"].getStr() != "":
            result &= ": " & node["varType"].getStr()
          
          result &= " = " & convertNodeToNim(node["value"])
      
      else:
        result = indentStr & "# Unsupported node: " & node["kind"].getStr()
    
    nimCode &= convertNodeToNim(builder.ast)
    
    writeFile(nimFilename, nimCode)
    echo fmt"Nim file generated: {nimFilename}"
    
  except Exception as e:
    raise newException(RBTException, fmt"Error converting RBT to Nim: {e.msg}")

# ============================================================================
# УТИЛИТЫ ДЛЯ РАБОТЫ С RBT
# ============================================================================

proc getRBTInfo*(filename: string): tuple[version: string, sourceLang: string, 
                                         sourceFile: string, generatorName: string] =
  try:
    let fileContent = readFile(filename)
    let jsonData = parseJson(fileContent)
    
    result.version = jsonData["version"].getStr()
    
    if jsonData.hasKey("META"):
      let meta = jsonData["META"]
      result.sourceLang = meta["sourceLang"].getStr()
      result.sourceFile = meta["sourceFile"].getStr()
      result.generatorName = meta["generatorName"].getStr()
    
  except Exception as e:
    raise newException(RBTException, fmt"Error reading RBT info: {e.msg}")

proc listRBTNamespaces*(filename: string): seq[string] =
  try:
    let fileContent = readFile(filename)
    let jsonData = parseJson(fileContent)
    
    result = @[]
    if jsonData.hasKey("namespaces"):
      for name, _ in jsonData["namespaces"]:
        result.add(name)
    
  except Exception as e:
    raise newException(RBTException, fmt"Error listing namespaces: {e.msg}")

proc extractRBTNamespace*(filename: string, namespaceName: string): seq[string] =
  try:
    let fileContent = readFile(filename)
    let jsonData = parseJson(fileContent)
    
    result = @[]
    if jsonData.hasKey("namespaces") and jsonData["namespaces"].hasKey(namespaceName):
      let ns = jsonData["namespaces"][namespaceName]
      if ns.hasKey("content"):
        for item in ns["content"]:
          result.add(item.getStr())
    
  except Exception as e:
    raise newException(RBTException, fmt"Error extracting namespace: {e.msg}")

proc mergeRBTFiles*(inputFiles: seq[string], outputFile: string) =
  try:
    let mainBuilder = createRBTGenerator()
    var allStatements: seq[JsonNode] = @[]
    
    for filename in inputFiles:
      let builder = loadRBTFile(filename)
      
      # Объединяем namespaces
      for name, ns in builder.namespaces:
        if not mainBuilder.namespaces.hasKey(name):
          mainBuilder.namespaces[name] = ns
        else:
          # Объединяем содержимое namespace'ов
          for item in ns.content:
            if item notin mainBuilder.namespaces[name].content:
              mainBuilder.namespaces[name].content.add(item)
      
      # Добавляем statements из AST
      if builder.ast.hasKey("body"):
        for stmt in builder.ast["body"]:
          allStatements.add(stmt)
    
    # Создаем объединенный AST
    mainBuilder.ast = %*{
      "kind": "nkProgram",
      "body": allStatements
    }
    
    # Устанавливаем метаданные
    mainBuilder.metadata.sourceLang = "ryton"
    mainBuilder.metadata.generatorName = "RBT Merger"
    mainBuilder.metadata.generatorVersion = "1.0"
    mainBuilder.metadata.outputFile = outputFile
    
    mainBuilder.generateRBTFile(outputFile)
    
  except Exception as e:
    raise newException(RBTException, fmt"Error merging RBT files: {e.msg}")

# ============================================================================
# ОПТИМИЗАЦИЯ RBT
# ============================================================================

proc optimizeRBT*(builder: RBTBuilder): RBTBuilder =
  # Простые оптимизации AST
  proc optimizeNode(node: JsonNode): JsonNode =
    if node.isNil or node.kind == JNull:
      return node
    
    case node["kind"].getStr():
    of "nkBinary":
      # Оптимизация константных выражений
      if node.hasKey("binLeft") and node.hasKey("binRight"):
        let left = node["binLeft"]
        let right = node["binRight"]
        
        if left["kind"].getStr() == "nkNumber" and right["kind"].getStr() == "nkNumber":
          let leftVal = parseFloat(left["numVal"].getStr())
          let rightVal = parseFloat(right["numVal"].getStr())
          let op = node["binOp"].getStr()
          
          var resultVal: float
          case op:
          of "+": resultVal = leftVal + rightVal
          of "-": resultVal = leftVal - rightVal
          of "*": resultVal = leftVal * rightVal
          of "/": 
            if rightVal != 0:
              resultVal = leftVal / rightVal
            else:
              return node # Избегаем деления на ноль
          else:
            return node
          
          return %*{
            "kind": "nkNumber",
            "numVal": $resultVal
          }
      
    of "nkBlock":
      # Удаление пустых блоков
      if node.hasKey("body") and node["body"].len == 0:
        return newJNull()
      
      # Оптимизация вложенных узлов
      if node.hasKey("body"):
        var optimizedBody = newJArray()
        for stmt in node["body"]:
          let optimizedStmt = optimizeNode(stmt)
          if not optimizedStmt.isNil and optimizedStmt.kind != JNull:
            optimizedBody.add(optimizedStmt)
        
        var result = node
        result["body"] = optimizedBody
        return result
    
    # Рекурсивная оптимизация для других типов узлов
    var result = node
    for key, value in node:
      if value.kind == JObject:
        result[key] = optimizeNode(value)
      elif value.kind == JArray:
        var optimizedArray = newJArray()
        for item in value:
          if item.kind == JObject:
            optimizedArray.add(optimizeNode(item))
          else:
            optimizedArray.add(item)
        result[key] = optimizedArray
    
    return result
  
  let optimizedBuilder = builder
  optimizedBuilder.ast = optimizeNode(builder.ast)
  return optimizedBuilder

# ============================================================================
# ЭКСПОРТ ОСНОВНЫХ ФУНКЦИЙ
# ============================================================================

export RBTBuilder, RBTBlock, RBTNamespace, RBTAccess, RBTMetadata, RBTException
export createRBTGenerator, setMetadata
export generateRBTFile, loadRBTFile, validateRBTFile, convertRBTToNim
export getRBTInfo, listRBTNamespaces, extractRBTNamespace, mergeRBTFiles
export optimizeRBT

# ============================================================================
# ТЕСТИРОВАНИЕ ВСЕХ КОМПОНЕНТОВ БИБЛИОТЕКИ
# ============================================================================

when isMainModule:
  import std/[os, times]
  
  echo "=== ТЕСТИРОВАНИЕ БИБЛИОТЕКИ LibRBT ==="
  echo "Время начала: ", now()
  echo ""
  
  # ============================================================================
  # ТЕСТ 1: Создание базового RBT генератора
  # ============================================================================
  
  echo "ТЕСТ 1: Создание RBT генератора"
  try:
    let builder = createRBTGenerator()
    echo "✓ RBT генератор создан успешно"
    
    # Установка метаданных
    discard builder.setMetadata("ryton", "1.0", "test.ryt", "test.nim", "Test", "Author", "1.0.0")

    echo "✓ Метаданные установлены"
    
  except Exception as e:
    echo "✗ Ошибка создания генератора: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 2: Работа с namespace'ами
  # ============================================================================
  
  echo "ТЕСТ 2: Работа с namespace'ами"
  try:
    let builder = createRBTGenerator()
    
    # Добавление различных namespace'ов
    discard builder.createNameSpace("std")
    discard builder.createNameSpace("math")
    discard builder.createNameSpace("internal")
    discard builder.createNameSpace("protected")
    
    echo "✓ Namespace'ы добавлены: ", builder.namespaces.len, " штук"
    
    # Проверка содержимого
    if builder.namespaces.hasKey("std"):
      echo "✓ Namespace 'std' содержит: ", builder.namespaces["std"].content.join(", ")
    
  except Exception as e:
    echo "✗ Ошибка работы с namespace'ами: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 3: Создание базовых узлов AST
  # ============================================================================
  
  echo "ТЕСТ 3: Создание базовых узлов AST"
  try:
    let builder = createRBTGenerator()
    
    # Создание идентификатора
    let identNode = builder.generateIdent("myVariable")
    echo "✓ Идентификатор создан: ", identNode["ident"].getStr()
    
    # Создание числа
    let numberNode = builder.generateNumber("42")
    echo "✓ Число создано: ", numberNode["numVal"].getStr()
    
    # Создание строки
    let stringNode = builder.generateString("Hello, World!")
    echo "✓ Строка создана: ", stringNode["strVal"].getStr()
    
    # Создание булева значения
    let boolNode = builder.generateBool(true)
    echo "✓ Булево значение создано: ", boolNode["boolVal"].getBool()
    
    # Создание noop
    let noopNode = builder.generateNoop()
    echo "✓ Noop создан: ", noopNode["kind"].getStr()
    
  except Exception as e:
    echo "✗ Ошибка создания базовых узлов: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 4: Бинарные и унарные операции
  # ============================================================================
  
  echo "ТЕСТ 4: Бинарные и унарные операции"
  try:
    let builder = createRBTGenerator()
    
    let left = builder.generateNumber("10")
    let right = builder.generateNumber("5")
    
    # Бинарные операции
    let addNode = builder.generateBinary("+", left, right)
    echo "✓ Сложение создано: ", addNode["binOp"].getStr()
    
    let subNode = builder.generateBinary("-", left, right)
    echo "✓ Вычитание создано: ", subNode["binOp"].getStr()
    
    let mulNode = builder.generateBinary("*", left, right)
    echo "✓ Умножение создано: ", mulNode["binOp"].getStr()
    
    let divNode = builder.generateBinary("/", left, right)
    echo "✓ Деление создано: ", divNode["binOp"].getStr()
    
    # Унарные операции
    let negNode = builder.generateUnary("-", left)
    echo "✓ Унарный минус создан: ", negNode["unOp"].getStr()
    
    let notNode = builder.generateUnary("not", builder.generateBool(true))
    echo "✓ Логическое НЕ создано: ", notNode["unOp"].getStr()
    
  except Exception as e:
    echo "✗ Ошибка создания операций: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 5: Коллекции (массивы и таблицы)
  # ============================================================================
  
  echo "ТЕСТ 5: Коллекции"
  try:
    let builder = createRBTGenerator()
    
    # Создание массива
    let elements = @[
      builder.generateNumber("1"),
      builder.generateNumber("2"),
      builder.generateNumber("3")
    ]
    let arrayNode = builder.generateArray(elements)
    echo "✓ Массив создан с ", arrayNode["elements"].len, " элементами"
    
    # Создание таблицы
    let pairs = @[
      builder.generateTablePair(builder.generateString("name"), builder.generateString("John")),
      builder.generateTablePair(builder.generateString("age"), builder.generateNumber("25"))
    ]
    let tableNode = builder.generateTable(pairs)
    echo "✓ Таблица создана с ", tableNode["pairs"].len, " парами"
    
    # Доступ к элементам массива
    let arrayAccess = builder.generateArrayAccess(arrayNode, builder.generateNumber("0"))
    echo "✓ Доступ к массиву создан: ", arrayAccess["kind"].getStr()
    
    # Доступ к свойствам
    let propAccess = builder.generateProperty(builder.generateIdent("obj"), "property")
    echo "✓ Доступ к свойству создан: ", propAccess["property"].getStr()
    
  except Exception as e:
    echo "✗ Ошибка создания коллекций: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 6: Функции и вызовы
  # ============================================================================
  
  echo "ТЕСТ 6: Функции и вызовы"
  try:
    let builder = createRBTGenerator()
    
    # Создание параметров функции
    let params = @[
      builder.generateParam("x", "int", "!", newJNull()),
      builder.generateParam("y", "string", "?", builder.generateString("default"))
    ]
    
    # Создание тела функции
    let body = builder.generateBlock(@[
      builder.generateReturn(builder.generateBinary("+", 
        builder.generateIdent("x"), 
        builder.generateNumber("1")))
    ])
    
    # Создание функции
    let funcNode = builder.generateFuncDef("testFunc", params, @[], "int", "!", @["pure"], body, true)
    echo "✓ Функция создана: ", funcNode["name"].getStr()
    echo "✓ Параметров: ", funcNode["params"].len
    
    # Создание вызова функции
    let callArgs = @[builder.generateNumber("42"), builder.generateString("test")]
    let callNode = builder.generateCall(builder.generateIdent("testFunc"), callArgs)
    echo "✓ Вызов функции создан с ", callNode["args"].len, " аргументами"
    
    # Лямбда функция
    let lambdaNode = builder.generateLambdaDef(params, @[], "int", "!", @[], body)
    echo "✓ Лямбда функция создана: ", lambdaNode["kind"].getStr()
    
  except Exception as e:
    echo "✗ Ошибка создания функций: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 7: Условные конструкции
  # ============================================================================
  
  echo "ТЕСТ 7: Условные конструкции"
  try:
    let builder = createRBTGenerator()
    
    let condition = builder.generateBinary(">", builder.generateIdent("x"), builder.generateNumber("0"))
    let thenBranch = builder.generateBlock(@[builder.generateIdent("positive")])
    let elseBranch = builder.generateBlock(@[builder.generateIdent("negative")])
    
    # Создание if
    let ifNode = builder.generateIf(condition, thenBranch, @[], elseBranch)
    echo "✓ If конструкция создана: ", ifNode["kind"].getStr()
    
    # Создание switch
    let switchExpr = builder.generateIdent("value")
    let cases = @[
      builder.generateSwitchCase(
        @[builder.generateNumber("1")], 
        builder.generateBlock(@[builder.generateIdent("one")]), 
        newJNull()
      )
    ]
    let switchNode = builder.generateSwitch(switchExpr, cases, newJNull())
    echo "✓ Switch конструкция создана с ", switchNode["cases"].len, " case'ами"
    
  except Exception as e:
    echo "✗ Ошибка создания условных конструкций: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 8: Циклы
  # ============================================================================
  
  echo "ТЕСТ 8: Циклы"
  try:
    let builder = createRBTGenerator()
    
    let body = builder.generateBlock(@[builder.generateIdent("doSomething")])
    
    # For цикл
    let forNode = builder.generateFor("i", builder.generateNumber("0"), builder.generateNumber("10"), true, body)
    echo "✓ For цикл создан: ", forNode["variable"].getStr()
    
    # Each цикл
    let eachNode = builder.generateEach("item", builder.generateNumber("1"), builder.generateNumber("100"), 
                                       builder.generateNumber("2"), newJNull(), body)
    echo "✓ Each цикл создан: ", eachNode["variable"].getStr()
    
    # While цикл
    let whileNode = builder.generateWhile(builder.generateBool(true), body)
    echo "✓ While цикл создан: ", whileNode["kind"].getStr()
    
    # Infinit цикл
    let infinitNode = builder.generateInfinit(builder.generateNumber("1000"), body)
    echo "✓ Infinit цикл создан: ", infinitNode["kind"].getStr()
    
    # Repeat цикл
    let repeatNode = builder.generateRepeat(builder.generateNumber("5"), builder.generateNumber("500"), body)
    echo "✓ Repeat цикл создан: ", repeatNode["kind"].getStr()
    
  except Exception as e:
    echo "✗ Ошибка создания циклов: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 9: Классы и структуры
  # ============================================================================
  
  echo "ТЕСТ 9: Классы и структуры"
  try:
    let builder = createRBTGenerator()
    
    # Создание структуры
    let fields = @[
      builder.generateFieldDef("x", "int", builder.generateNumber("0")),
      builder.generateFieldDef("y", "int", builder.generateNumber("0"))
    ]
    let structNode = builder.generateStructDef("Point", fields, @[])
    echo "✓ Структура создана: ", structNode["name"].getStr(), " с ", structNode["fields"].len, " полями"
    
    # Создание перечисления
    let variants = @[
      builder.generateEnumVariant("Red", builder.generateNumber("0")),
      builder.generateEnumVariant("Green", builder.generateNumber("1")),
      builder.generateEnumVariant("Blue", builder.generateNumber("2"))
    ]
    let enumNode = builder.generateEnumDef("Color", variants, @[])
    echo "✓ Перечисление создано: ", enumNode["name"].getStr(), " с ", enumNode["variants"].len, " вариантами"
    
    # Создание класса (pack)
    let packBody = builder.generateBlock(@[])
    let packNode = builder.generatePackDef("MyClass", @[], @["BaseClass"], @["public"], packBody)
    echo "✓ Класс создан: ", packNode["name"].getStr()
    
  except Exception as e:
    echo "✗ Ошибка создания классов и структур: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 10: Присваивания и переменные
  # ============================================================================
  
  echo "ТЕСТ 10: Присваивания и переменные"
  try:
    let builder = createRBTGenerator()
    
    # Обычное присваивание
    let assignNode = builder.generateAssign("dtNone", "=", 
      builder.generateIdent("x"), 
      builder.generateNumber("42"), 
      "", "")
    echo "✓ Присваивание создано: ", assignNode["assignOp"].getStr()
    
    # Объявление переменной
    let varNode = builder.generateAssign("dtDef", "=", 
      builder.generateIdent("myVar"), 
      builder.generateString("hello"), 
      "string", "!")
    echo "✓ Объявление переменной создано: ", varNode["declType"].getStr()
    
    # Константа
    let constNode = builder.generateAssign("dtVal", "=", 
      builder.generateIdent("PI"), 
      builder.generateNumber("3.14159"), 
      "float", "")
    echo "✓ Константа создана: ", constNode["declType"].getStr()
    
  except Exception as e:
    echo "✗ Ошибка создания присваиваний: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 11: Обработка исключений
  # ============================================================================
  
  echo "ТЕСТ 11: Обработка исключений"
  try:
    let builder = createRBTGenerator()
    
    let tryBody = builder.generateBlock(@[
      builder.generateCall(builder.generateIdent("riskyFunction"), @[])
    ])
    
    let catchBody = builder.generateBlock(@[
      builder.generateCall(builder.generateIdent("handleError"), @[])
    ])
    
    let tryNode = builder.generateTry(tryBody, "Exception", catchBody)
    echo "✓ Try-catch создан: ", tryNode["kind"].getStr()
    echo "✓ Тип ошибки: ", tryNode["errorType"].getStr()
    
  except Exception as e:
    echo "✗ Ошибка создания try-catch: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 12: События и состояния
  # ============================================================================
  
  echo "ТЕСТ 12: События и состояния"
  try:
    let builder = createRBTGenerator()
    
    # Создание события
    let eventCondition = builder.generateBinary("==", 
      builder.generateIdent("status"), 
      builder.generateString("ready"))
    let eventBody = builder.generateBlock(@[builder.generateIdent("onReady")])
    let eventNode = builder.generateEvent(eventCondition, eventBody)
    echo "✓ Событие создано: ", eventNode["kind"].getStr()
    
    # Создание состояния
    let stateBody = builder.generateStateBody(@[], @[], @[])
    let stateNode = builder.generateState("GameState", stateBody)
    echo "✓ Состояние создано: ", stateNode["name"].getStr()
    
  except Exception as e:
    echo "✗ Ошибка создания событий и состояний: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 13: Импорты
  # ============================================================================
  
  echo "ТЕСТ 13: Импорты"
  try:
    let builder = createRBTGenerator()
    
    # Создание импорта
    let imports = @[%*{
      "path": ["std", "strutils"],
      "filter": ["split", "join"],
      "alias": "str",
      "isAll": false
    }]
    
    let importNode = builder.generateImport(imports)
    echo "✓ Импорт создан: ", importNode["kind"].getStr()
    echo "✓ Количество импортов: ", importNode["imports"].len
    
  except Exception as e:
    echo "✗ Ошибка создания импортов: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 14: Дженерики
  # ============================================================================
  
  echo "ТЕСТ 14: Дженерики"
  try:
    let builder = createRBTGenerator()
    
    # Создание ограничения дженерика
    let constraint = builder.generateGenericConstraint("Comparable")
    echo "✓ Ограничение дженерика создано: ", constraint["constraintType"].getStr()
    
    # Создание параметра дженерика
    let genericParam = builder.generateGenericParam("T", @[constraint])
    echo "✓ Параметр дженерика создан: ", genericParam["name"].getStr()
    
  except Exception as e:
    echo "✗ Ошибка создания дженериков: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 15: Типовые проверки
  # ============================================================================
  
  echo "ТЕСТ 15: Типовые проверки"
  try:
    let builder = createRBTGenerator()
    
    let checkBlock = builder.generateBlock(@[builder.generateIdent("validateInt")])
    let checkExpr = builder.generateIdent("value")
    
    let typeCheckNode = builder.generateTypeCheck("int", "isValidInt", checkBlock, checkExpr)
    echo "✓ Типовая проверка создана: ", typeCheckNode["checkType"].getStr()
    echo "✓ Функция проверки: ", typeCheckNode["checkFunc"].getStr()
    
  except Exception as e:
    echo "✗ Ошибка создания типовых проверок: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 16: Сложные выражения
  # ============================================================================
  
  echo "ТЕСТ 16: Сложные выражения"
  try:
    let builder = createRBTGenerator()
    
    # Создание среза массива
    let sliceNode = builder.generateSlice(
      builder.generateIdent("array"),
      builder.generateNumber("0"),
      builder.generateNumber("5"),
      true
    )
    echo "✓ Срез массива создан: ", sliceNode["kind"].getStr()
    
    # Создание доступа к кортежу
    let tupleAccess = builder.generateTupleAccess(builder.generateIdent("tuple"), 0)
    echo "✓ Доступ к кортежу создан: ", tupleAccess["fieldIndex"].getInt()
    
    # Создание диапазона
    let rangeExpr = builder.generateRangeExpr(
      builder.generateNumber("1"),
      builder.generateNumber("10"),
      builder.generateNumber("2")
    )
    echo "✓ Диапазон создан: ", rangeExpr["kind"].getStr()
    
    # Создание цепочки вызовов
    let chainCall = builder.generateChainCall(@[
      builder.generateIdent("obj"),
      builder.generateCall(builder.generateIdent("method1"), @[]),
      builder.generateCall(builder.generateIdent("method2"), @[])
    ])
    echo "✓ Цепочка вызовов создана с ", chainCall["chain"].len, " элементами"
    
    # Создание индексации
    let subscript = builder.generateSubscript(
      builder.generateIdent("container"),
      @[builder.generateNumber("0"), builder.generateString("key")]
    )
    echo "✓ Индексация создана с ", subscript["indices"].len, " индексами"
    
  except Exception as e:
    echo "✗ Ошибка создания сложных выражений: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 17: Создание полной программы
  # ============================================================================
  
  echo "ТЕСТ 17: Создание полной программы"
  try:
    let builder = createRBTGenerator()
    
    # Настройка метаданных
    discard builder.setMetadata("ryton", "1.0", "test_program.ryt", "test_program.nim", "Test", "Author", "1.0.0")
    
    # Добавление namespace'ов
    discard builder.createNameSpace("std")
    discard builder.createNameSpace("math")
    
    # Создание функции main
    let mainBody = builder.generateBlock(@[
      builder.generateCall(
        builder.generateIdent("println"), 
        @[builder.generateString("Hello, World!")]
      ),
      builder.generateAssign("dtDef", "=",
        builder.generateIdent("x"),
        builder.generateNumber("42"),
        "int", "!"
      ),
      builder.generateReturn(builder.generateNumber("0"))
    ])
    
    let mainFunc = builder.generateFuncDef("main", @[], @[], "int", "", @[], mainBody, true)
    
    # Создание программы
    let program = builder.generateProgram(@[mainFunc])
    builder.ast = program
    
    echo "✓ Полная программа создана"
    echo "✓ AST содержит: ", program["body"].len, " элементов"
    
  except Exception as e:
    echo "✗ Ошибка создания программы: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 18: Сохранение и загрузка RBT файла
  # ============================================================================
  
  echo "ТЕСТ 18: Сохранение и загрузка RBT файла"
  try:
    let builder = createRBTGenerator()
    
    # Создание простой программы
    discard builder.setMetadata("ryton", "1.0", "test.ryt", "test.nim", "Test", "Author", "1.0.0")
    discard builder.createNameSpace("std")
    
    let simpleProgram = builder.generateProgram(@[
      builder.generateCall(
        builder.generateIdent("println"),
        @[builder.generateString("Test")]
      )
    ])
    builder.ast = simpleProgram
    
    # Сохранение в файл
    let testFile = "test_output.rbt"
    builder.generateRBTFile(testFile)
    echo "✓ RBT файл сохранен: ", testFile
    
    # Проверка существования файла
    if fileExists(testFile):
      echo "✓ Файл существует на диске"
      
      # Загрузка файла
      let loadedBuilder = loadRBTFile(testFile)
      echo "✓ RBT файл загружен успешно"
      echo "✓ Версия: ", loadedBuilder.metadata.generatorVersion
      echo "✓ Исходный язык: ", loadedBuilder.metadata.sourceLang
      
      # Валидация файла
      if validateRBTFile(testFile):
        echo "✓ Файл прошел валидацию"
      else:
        echo "✗ Файл не прошел валидацию"
      
      # Получение информации о файле
      let info = getRBTInfo(testFile)
      echo "✓ Информация о файле получена:"
      echo "  - Версия: ", info.version
      echo "  - Исходный язык: ", info.sourceLang
      echo "  - Исходный файл: ", info.sourceFile
      echo "  - Генератор: ", info.generatorName
      
      # Список namespace'ов
      let namespaces = listRBTNamespaces(testFile)
      echo "✓ Namespace'ы в файле: ", namespaces.join(", ")
      
      # Извлечение содержимого namespace'а
      if namespaces.len > 0:
        let content = extractRBTNamespace(testFile, namespaces[0])
        echo "✓ Содержимое namespace '", namespaces[0], "': ", content.join(", ")
      
      # Удаление тестового файла
      removeFile(testFile)
      echo "✓ Тестовый файл удален"
      
    else:
      echo "✗ Файл не был создан"
    
  except Exception as e:
    echo "✗ Ошибка работы с файлами: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 19: Конвертация в Nim
  # ============================================================================
  
  echo "ТЕСТ 19: Конвертация в Nim"
  try:
    let builder = createRBTGenerator()
    
    # Создание простой программы для конвертации
    discard builder.setMetadata("ryton", "1.0", "convert_test.ryt", "convert_test.nim", "Test", "Author", "1.0.0")
    discard builder.createNameSpace("std")
    
    let convertProgram = builder.generateProgram(@[
      builder.generateFuncDef("greet", 
        @[builder.generateParam("name", "string", "", newJNull())],
        @[], "void", "", @[], 
        builder.generateBlock(@[
          builder.generateCall(
            builder.generateIdent("echo"),
            @[builder.generateBinary("+", 
              builder.generateString("Hello, "),
              builder.generateIdent("name")
            )]
          )
        ]), 
        true
      )
    ])
    builder.ast = convertProgram
    
    let rbtFile = "convert_test.rbt"
    let nimFile = "convert_test.nim"
    
    # Сохранение RBT
    builder.generateRBTFile(rbtFile)
    echo "✓ RBT файл для конвертации создан"
    
    # Конвертация в Nim
    convertRBTToNim(rbtFile, nimFile)
    echo "✓ Конвертация в Nim выполнена"
    
    # Проверка результата
    if fileExists(nimFile):
      let nimContent = readFile(nimFile)
      echo "✓ Nim файл создан, размер: ", nimContent.len, " символов"
      echo "✓ Первые 100 символов:"
      echo nimContent[0..<min(100, nimContent.len)]
      
      # Удаление тестовых файлов
      removeFile(rbtFile)
      removeFile(nimFile)
      echo "✓ Тестовые файлы удалены"
    else:
      echo "✗ Nim файл не был создан"
    
  except Exception as e:
    echo "✗ Ошибка конвертации: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 20: Объединение файлов
  # ============================================================================
  
  echo "ТЕСТ 20: Объединение RBT файлов"
  try:
    # Создание первого файла
    let builder1 = createRBTGenerator()
    discard builder1.setMetadata("ryton", "1.0", "file1.ryt", "file1.nim", "Test", "Author", "1.0.0")
    discard builder1.createNameSpace("module1")
    
    let program1 = builder1.generateProgram(@[
      builder1.generateFuncDef("func1", @[], @[], "void", "", @[], 
        builder1.generateBlock(@[builder1.generateNoop()]), true)
    ])
    builder1.ast = program1
    
    # Создание второго файла
    let builder2 = createRBTGenerator()
    discard builder2.setMetadata("ryton", "1.0", "file2.ryt", "file2.nim", "Test", "Author", "1.0.0")
    discard builder2.createNameSpace("module2")
    
    let program2 = builder2.generateProgram(@[
      builder2.generateFuncDef("func3", @[], @[], "void", "", @[], 
        builder2.generateBlock(@[builder2.generateNoop()]), true)
    ])
    builder2.ast = program2
    
    # Сохранение файлов
    let file1 = "merge_test1.rbt"
    let file2 = "merge_test2.rbt"
    let mergedFile = "merged_test.rbt"
    
    builder1.generateRBTFile(file1)
    builder2.generateRBTFile(file2)
    echo "✓ Два RBT файла созданы для объединения"
    
    # Объединение файлов
    mergeRBTFiles(@[file1, file2], mergedFile)
    echo "✓ Файлы объединены в: ", mergedFile
    
    # Проверка результата
    if fileExists(mergedFile):
      let mergedBuilder = loadRBTFile(mergedFile)
      echo "✓ Объединенный файл загружен"
      echo "✓ Namespace'ы в объединенном файле: ", mergedBuilder.namespaces.len
      
      # Проверка содержимого
      if mergedBuilder.namespaces.hasKey("module1") and mergedBuilder.namespaces.hasKey("module2"):
        echo "✓ Все namespace'ы сохранены при объединении"
      else:
        echo "✗ Не все namespace'ы сохранены"
      
      # Удаление тестовых файлов
      removeFile(file1)
      removeFile(file2)
      removeFile(mergedFile)
      echo "✓ Тестовые файлы удалены"
    else:
      echo "✗ Объединенный файл не создан"
    
  except Exception as e:
    echo "✗ Ошибка объединения файлов: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 21: Оптимизация RBT
  # ============================================================================
  
  echo "ТЕСТ 21: Оптимизация RBT"
  try:
    let builder = createRBTGenerator()
    
    # Создание неоптимизированного кода с константными выражениями
    let unoptimized = builder.generateProgram(@[
      builder.generateAssign("dtDef", "=",
        builder.generateIdent("result1"),
        builder.generateBinary("+", 
          builder.generateNumber("5"), 
          builder.generateNumber("3")
        ),
        "int", ""
      ),
      builder.generateAssign("dtDef", "=",
        builder.generateIdent("result2"),
        builder.generateBinary("*", 
          builder.generateNumber("10"), 
          builder.generateNumber("2")
        ),
        "int", ""
      ),
      # Пустой блок для тестирования удаления
      builder.generateBlock(@[])
    ])
    builder.ast = unoptimized
    
    echo "✓ Неоптимизированный код создан"
    echo "✓ Элементов в программе до оптимизации: ", unoptimized["body"].len
    
    # Оптимизация
    let optimizedBuilder = optimizeRBT(builder)
    echo "✓ Оптимизация выполнена"
    
    # Проверка результатов (базовая проверка)
    if optimizedBuilder.ast.hasKey("body"):
      echo "✓ Оптимизированный AST содержит body"
    else:
      echo "✗ Оптимизированный AST поврежден"
    
  except Exception as e:
    echo "✗ Ошибка оптимизации: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 22: Форматированные строки
  # ============================================================================
  
  echo "ТЕСТ 22: Форматированные строки"
  try:
    let builder = createRBTGenerator()
    
    # Создание форматированной строки
    let formatString = builder.generateFormatString("fmt", "Hello, {name}! You are {age} years old.")
    echo "✓ Форматированная строка создана: ", formatString["formatType"].getStr()
    echo "✓ Содержимое: ", formatString["formatContent"].getStr()
    
    # Создание программы с форматированной строкой
    let program = builder.generateProgram(@[
      builder.generateCall(
        builder.generateIdent("println"),
        @[formatString]
      )
    ])
    
    echo "✓ Программа с форматированной строкой создана"
    
  except Exception as e:
    echo "✗ Ошибка создания форматированных строк: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 23: Инициализация структур
  # ============================================================================
  
  echo "ТЕСТ 23: Инициализация структур"
  try:
    let builder = createRBTGenerator()
    
    # Создание инициализации структуры
    let structInit = builder.generateStructInit("Point", @[
      builder.generateAssign("dtNone", "=", 
        builder.generateIdent("x"), 
        builder.generateNumber("10"), 
        "", ""
      ),
      builder.generateAssign("dtNone", "=", 
        builder.generateIdent("y"), 
        builder.generateNumber("20"), 
        "", ""
      )
    ])
    
    echo "✓ Инициализация структуры создана: ", structInit["structType"].getStr()
    echo "✓ Аргументов инициализации: ", structInit["args"].len
    
  except Exception as e:
    echo "✗ Ошибка создания инициализации структур: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 24: Группировка выражений
  # ============================================================================
  
  echo "ТЕСТ 24: Группировка выражений"
  try:
    let builder = createRBTGenerator()
    
    # Создание группированного выражения
    let innerExpr = builder.generateBinary("+", 
      builder.generateNumber("2"), 
      builder.generateNumber("3")
    )
    let groupedExpr = builder.generateGroup(innerExpr)
    
    echo "✓ Группированное выражение создано: ", groupedExpr["kind"].getStr()
    
    # Использование в более сложном выражении
    let complexExpr = builder.generateBinary("*", 
      groupedExpr, 
      builder.generateNumber("4")
    )
    
    echo "✓ Сложное выражение с группировкой создано"
    
  except Exception as e:
    echo "✗ Ошибка создания группированных выражений: ", e.msg
  
  echo ""
  
  # ============================================================================
  # ТЕСТ 25: Комплексный тест - создание полноценного модуля
  # ============================================================================
  
  echo "ТЕСТ 25: Комплексный тест - полноценный модуль"
  try:
    let builder = createRBTGenerator()
    
    # Настройка метаданных
    discard builder.setMetadata("ryton", "1.0", "math_module.ryt", "math_module.nim", "Test", "Author", "1.0.0")
    
    # Добавление namespace'ов
    discard builder.createNameSpace("std")
    discard builder.createNameSpace("math")
    discard builder.createNameSpace("internal")
    
    # Создание структуры Vector2D
    let vectorFields = @[
      builder.generateFieldDef("x", "float", builder.generateNumber("0.0")),
      builder.generateFieldDef("y", "float", builder.generateNumber("0.0"))
    ]
    
    let vectorMethods = @[
      builder.generateFuncDef("length", @[], @[], "float", "", @["pure"], 
        builder.generateBlock(@[
          builder.generateReturn(
            builder.generateCall(
              builder.generateIdent("sqrt"),
              @[builder.generateBinary("+",
                builder.generateBinary("*", 
                  builder.generateProperty(builder.generateIdent("self"), "x"),
                  builder.generateProperty(builder.generateIdent("self"), "x")
                ),
                builder.generateBinary("*", 
                  builder.generateProperty(builder.generateIdent("self"), "y"),
                  builder.generateProperty(builder.generateIdent("self"), "y")
                )
              )]
            )
          )
        ]), 
        true
      )
    ]
    
    let vectorStruct = builder.generateStructDef("Vector2D", vectorFields, vectorMethods)
    
    # Создание перечисления Direction
    let directionVariants = @[
      builder.generateEnumVariant("North", builder.generateNumber("0")),
      builder.generateEnumVariant("South", builder.generateNumber("1")),
      builder.generateEnumVariant("East", builder.generateNumber("2")),
      builder.generateEnumVariant("West", builder.generateNumber("3"))
    ]
    
    let directionEnum = builder.generateEnumDef("Direction", directionVariants, @[])
    
    # Создание функции с условной логикой
    let mathFunc = builder.generateFuncDef("calculateDistance", 
      @[
        builder.generateParam("p1", "Vector2D", "", newJNull()),
        builder.generateParam("p2", "Vector2D", "", newJNull())
      ],
      @[], "float", "", @["pure"], 
      builder.generateBlock(@[
        builder.generateAssign("dtDef", "=",
          builder.generateIdent("dx"),
          builder.generateBinary("-",
            builder.generateProperty(builder.generateIdent("p2"), "x"),
            builder.generateProperty(builder.generateIdent("p1"), "x")
          ),
          "float", ""
        ),
        builder.generateAssign("dtDef", "=",
          builder.generateIdent("dy"),
          builder.generateBinary("-",
            builder.generateProperty(builder.generateIdent("p2"), "y"),
            builder.generateProperty(builder.generateIdent("p1"), "y")
          ),
          "float", ""
        ),
        builder.generateReturn(
          builder.generateCall(
            builder.generateIdent("sqrt"),
            @[builder.generateBinary("+",
              builder.generateBinary("*", builder.generateIdent("dx"), builder.generateIdent("dx")),
              builder.generateBinary("*", builder.generateIdent("dy"), builder.generateIdent("dy"))
            )]
          )
        )
      ]), 
      true
    )
    
    # Создание функции с циклом
    let arrayFunc = builder.generateFuncDef("sumArray", 
      @[builder.generateParam("arr", "Array[float]", "", newJNull())],
      @[], "float", "", @[], 
      builder.generateBlock(@[
        builder.generateAssign("dtDef", "=",
          builder.generateIdent("sum"),
          builder.generateNumber("0.0"),
          "float", ""
        ),
        builder.generateFor("item", 
          builder.generateIdent("arr"), 
          newJNull(), 
          false,
          builder.generateBlock(@[
            builder.generateAssign("dtNone", "+=",
              builder.generateIdent("sum"),
              builder.generateIdent("item"),
              "", ""
            )
          ])
        ),
        builder.generateReturn(builder.generateIdent("sum"))
      ]), 
      true
    )
    
    # Создание main функции с тестами
    let mainFunc = builder.generateFuncDef("main", @[], @[], "int", "", @[], 
      builder.generateBlock(@[
        builder.generateCall(
          builder.generateIdent("echo"),
          @[builder.generateString("Testing Math Module")]
        ),
        
        builder.generateAssign("dtDef", "=",
          builder.generateIdent("v1"),
          builder.generateStructInit("Vector2D", @[
            builder.generateAssign("dtNone", "=", 
              builder.generateIdent("x"), 
              builder.generateNumber("3.0"), 
              "", ""
            ),
            builder.generateAssign("dtNone", "=", 
              builder.generateIdent("y"), 
              builder.generateNumber("4.0"), 
              "", ""
            )
          ]),
          "Vector2D", ""
        ),
        
        builder.generateAssign("dtDef", "=",
          builder.generateIdent("length"),
          builder.generateCall(
            builder.generateProperty(builder.generateIdent("v1"), "length"),
            @[]
          ),
          "float", ""
        ),
        
        builder.generateCall(
          builder.generateIdent("echo"),
          @[builder.generateBinary("+", 
            builder.generateString("Vector length: "),
            builder.generateIdent("length")
          )]
        ),
        
        builder.generateReturn(builder.generateNumber("0"))
      ]), 
      true
    )
    
    # Создание полной программы
    let fullProgram = builder.generateProgram(@[
      vectorStruct,
      directionEnum,
      mathFunc,
      arrayFunc,
      mainFunc
    ])
    
    builder.ast = fullProgram
    
    echo "✓ Комплексный модуль создан успешно"
    echo "✓ Содержит структуры: 1"
    echo "✓ Содержит перечисления: 1" 
    echo "✓ Содержит функции: 3"
    echo "✓ Namespace'ов: ", builder.namespaces.len
    echo "✓ Общий размер AST: ", ($builder.ast).len, " символов"
    
    # Сохранение комплексного модуля
    let complexFile = "complex_module.rbt"
    builder.generateRBTFile(complexFile)
    echo "✓ Комплексный модуль сохранен в файл: ", complexFile
    
    # Валидация
    if validateRBTFile(complexFile):
      echo "✓ Комплексный модуль прошел валидацию"
    else:
      echo "✗ Комплексный модуль не прошел валидацию"
    
    # Конвертация в Nim
    let complexNimFile = "complex_module.nim"
    convertRBTToNim(complexFile, complexNimFile)
    echo "✓ Комплексный модуль сконвертирован в Nim"
    
    # Проверка размера результата
    if fileExists(complexNimFile):
      let nimContent = readFile(complexNimFile)
      echo "✓ Nim файл создан, размер: ", nimContent.len, " символов"
    
    # Очистка

  except Exception as e:
    raise e
