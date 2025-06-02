import std/[strutils, strformat, sequtils]

type
  RyiParser* = ref object
    content*: string
    lines*: seq[string]
    current*: int
    
  RyiEntry* = object
    kind*: RyiEntryKind
    name*: string
    visibility*: string  # "pub" или "priv"
    params*: string
    returnType*: string
    className*: string   # Для методов
    fields*: seq[RyiField]  # Для типов
    
  RyiField* = object
    name*: string
    fieldType*: string
    visibility*: string
    
  RyiEntryKind* = enum
    rekType, rekFunc, rekMethod

proc newRyiParser*(content: string): RyiParser =
  result = RyiParser(
    content: content,
    lines: content.splitLines(),
    current: 0
  )

proc parseTypeEntry*(parser: RyiParser, line: string, startLine: int): RyiEntry 
proc parseFuncEntry*(parser: RyiParser, line: string): RyiEntry 
proc parseMethodEntry*(parser: RyiParser, line: string): RyiEntry

proc parseRyiFile*(parser: RyiParser): seq[RyiEntry] =
  ## Парсит .ryi файл и возвращает список интерфейсов
  result = @[]
  
  var i = 0
  while i < parser.lines.len:
    let line = parser.lines[i].strip()
    
    # Пропускаем пустые строки и комментарии
    if line.len == 0 or line.startsWith("#"):
      inc i
      continue
    
    if line.startsWith("type "):
      # type pub MyClass = ref object {
      let typeEntry = parser.parseTypeEntry(line, i)
      result.add(typeEntry)
      
    elif line.startsWith("func "):
      # func pub myFunction(arg: String):Int
      let funcEntry = parser.parseFuncEntry(line)
      result.add(funcEntry)
      
    elif line.startsWith("method "):
      # method pub myMethod from MyClass(arg: String):None
      let methodEntry = parser.parseMethodEntry(line)
      result.add(methodEntry)
    
    inc i

proc parseTypeEntry*(parser: RyiParser, line: string, startLine: int): RyiEntry =
  ## Парсит определение типа
  # type pub MyClass = ref object {
  let parts = line.split()
  if parts.len < 4:
    raise newException(ValueError, fmt"Invalid type definition: {line}")
  
  let visibility = parts[1]  # "pub" или "priv"
  let typeName = parts[2]    # "MyClass"
  
  result = RyiEntry(
    kind: rekType,
    name: typeName,
    visibility: visibility,
    params: "",
    returnType: "",
    className: "",
    fields: @[]
  )
  
  # Ищем поля типа
  var i = startLine + 1
  while i < parser.lines.len:
    let fieldLine = parser.lines[i].strip()
    
    if fieldLine == "}":
      break
    
    if fieldLine.len > 0 and not fieldLine.startsWith("#"):
      # pub fieldName: String
      let fieldParts = fieldLine.split(":", 1)
      if fieldParts.len == 2:
        let nameAndVis = fieldParts[0].strip().split()
        if nameAndVis.len >= 2:
          let fieldVis = nameAndVis[0]    # "pub" или "priv"
          let fieldName = nameAndVis[1]   # "fieldName"
          let fieldType = fieldParts[1].strip()  # "String"
          
          result.fields.add(RyiField(
            name: fieldName,
            fieldType: fieldType,
            visibility: fieldVis
          ))
    
    inc i

proc parseFuncEntry*(parser: RyiParser, line: string): RyiEntry =
  ## Парсит определение функции
  # func pub myFunction(arg1: String, arg2: Int):Bool
  
  # Убираем "func "
  let funcPart = line[5..^1].strip()
  
  # Разделяем на части до и после скобок
  let parenPos = funcPart.find("(")
  if parenPos == -1:
    raise newException(ValueError, fmt"Invalid function definition: {line}")
  
  # Извлекаем заголовок функции
  let header = funcPart[0..<parenPos].strip()
  let headerParts = header.split()
  if headerParts.len < 2:
    raise newException(ValueError, fmt"Invalid function header: {header}")
  
  let visibility = headerParts[0]  # "pub" или "priv"
  let funcName = headerParts[1]    # "myFunction"
  
  # Извлекаем параметры и возвращаемый тип
  let paramAndReturn = funcPart[parenPos..^1]
  let colonPos = paramAndReturn.rfind("):")
  
  var params = ""
  var returnType = "None"
  
  if colonPos != -1:
    # Есть возвращаемый тип
    params = paramAndReturn[1..<colonPos].strip()  # Убираем ( и ):
    returnType = paramAndReturn[colonPos+2..^1].strip()
  else:
    # Нет возвращаемого типа
    let rparenPos = paramAndReturn.rfind(")")
    if rparenPos != -1:
      params = paramAndReturn[1..<rparenPos].strip()
  
  result = RyiEntry(
    kind: rekFunc,
    name: funcName,
    visibility: visibility,
    params: params,
    returnType: returnType,
    className: "",
    fields: @[]
  )

proc parseMethodEntry*(parser: RyiParser, line: string): RyiEntry =
  ## Парсит определение метода
  # method pub myMethod from MyClass(arg1: String, arg2: Int):None
  
  # Убираем "method "
  let methodPart = line[7..^1].strip()
  
  # Ищем "from"
  let fromPos = methodPart.find(" from ")
  if fromPos == -1:
    raise newException(ValueError, fmt"Invalid method definition (missing 'from'): {line}")
  
  # Извлекаем заголовок метода
  let header = methodPart[0..<fromPos].strip()
  let headerParts = header.split()
  if headerParts.len < 2:
    raise newException(ValueError, fmt"Invalid method header: {header}")
  
  let visibility = headerParts[0]  # "pub" или "priv"
  let methodName = headerParts[1]  # "myMethod"
  
  # Извлекаем часть после "from"
  let afterFrom = methodPart[fromPos+6..^1].strip()  # +6 для " from "
  
  # Ищем скобку для разделения класса и параметров
  let parenPos = afterFrom.find("(")
  if parenPos == -1:
    raise newException(ValueError, fmt"Invalid method definition (missing params): {line}")
  
  let className = afterFrom[0..<parenPos].strip()  # "MyClass"
  
  # Извлекаем параметры и возвращаемый тип
  let paramAndReturn = afterFrom[parenPos..^1]
  let colonPos = paramAndReturn.rfind("):")
  
  var params = ""
  var returnType = "None"
  
  if colonPos != -1:
    # Есть возвращаемый тип
    params = paramAndReturn[1..<colonPos].strip()  # Убираем ( и ):
    returnType = paramAndReturn[colonPos+2..^1].strip()
  else:
    # Нет возвращаемого типа
    let rparenPos = paramAndReturn.rfind(")")
    if rparenPos != -1:
      params = paramAndReturn[1..<rparenPos].strip()
  
  result = RyiEntry(
    kind: rekMethod,
    name: methodName,
    visibility: visibility,
    params: params,
    returnType: returnType,
    className: className,
    fields: @[]
  )

proc validateRyiEntry*(parser: RyiParser, entry: RyiEntry): bool =
  ## Проверяет корректность записи интерфейса
  if entry.name.len == 0:
    echo "Error: Empty entry name"
    return false
  
  if entry.visibility notin ["pub", "priv"]:
    echo fmt"Error: Invalid visibility '{entry.visibility}' for {entry.name}"
    return false
  
  case entry.kind:
  of rekMethod:
    if entry.className.len == 0:
      echo fmt"Error: Method {entry.name} missing class name"
      return false
  else:
    discard
  
  return true

proc printRyiEntry*(parser: RyiParser, entry: RyiEntry) =
  ## Выводит информацию о записи интерфейса
  case entry.kind:
  of rekType:
    echo fmt"Type: {entry.visibility} {entry.name}"
    if entry.fields.len > 0:
      echo "  Fields:"
      for field in entry.fields:
        echo fmt"    {field.visibility} {field.name}: {field.fieldType}"
    else:
      echo "  No fields"
  
  of rekFunc:
    echo fmt"Function: {entry.visibility} {entry.name}({entry.params}):{entry.returnType}"
  
  of rekMethod:
    echo fmt"Method: {entry.visibility} {entry.name} from {entry.className}({entry.params}):{entry.returnType}"

proc getRyiStatistics*(parser: RyiParser, entries: seq[RyiEntry]): tuple[types: int, funcs: int, methods: int] =
  ## Возвращает статистику по интерфейсам
  var typeCount = 0
  var funcCount = 0
  var methodCount = 0
  
  for entry in entries:
    case entry.kind:
    of rekType: inc typeCount
    of rekFunc: inc funcCount
    of rekMethod: inc methodCount
  
  return (types: typeCount, funcs: funcCount, methods: methodCount)

proc findRyiEntry*(parser: RyiParser, entries: seq[RyiEntry], name: string, kind: RyiEntryKind): RyiEntry =
  ## Ищет запись интерфейса по имени и типу
  for entry in entries:
    if entry.name == name and entry.kind == kind:
      return entry
  
  raise newException(KeyError, fmt"Entry not found: {name} of kind {kind}")

proc filterRyiEntries*(parser: RyiParser, entries: seq[RyiEntry], 
                      kind: RyiEntryKind = rekType, 
                      visibility: string = ""): seq[RyiEntry] =
  ## Фильтрует записи интерфейсов
  result = @[]
  
  for entry in entries:
    var matches = true
    
    if entry.kind != kind:
      matches = false
    
    if visibility.len > 0 and entry.visibility != visibility:
      matches = false
    
    if matches:
      result.add(entry)

proc exportRyiToString*(parser: RyiParser, entries: seq[RyiEntry]): string =
  ## Экспортирует интерфейсы обратно в .ryi формат
  result = "# Generated interface file\n\n"
  
  # Группируем по типам
  let types = entries.filterIt(it.kind == rekType)
  let funcs = entries.filterIt(it.kind == rekFunc)
  let methods = entries.filterIt(it.kind == rekMethod)
  
  # Типы
  if types.len > 0:
    result.add("# Types\n")
    for entry in types:
      result.add(fmt"type {entry.visibility} {entry.name} = ref object {{" & "\n")
      
      if entry.fields.len > 0:
        for field in entry.fields:
          result.add(fmt"    {field.visibility} {field.name}: {field.fieldType}" & "\n")
      else:
        result.add("    # No fields\n")
      
      result.add("}\n\n")
  
  # Функции
  if funcs.len > 0:
    result.add("# Functions\n")
    for entry in funcs:
      result.add(fmt"func {entry.visibility} {entry.name}({entry.params}):{entry.returnType}" & "\n")
    result.add("\n")
  
  # Методы
  if methods.len > 0:
    result.add("# Methods\n")
    for entry in methods:
      result.add(fmt"method {entry.visibility} {entry.name} from {entry.className}({entry.params}):{entry.returnType}" & "\n")
    result.add("\n")
