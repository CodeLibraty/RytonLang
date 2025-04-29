import std/[os, strutils, strformat, sequtils, re, tables]

type
  ParamType* = enum
    ptVoid, ptInt, ptFloat, ptString, ptPointer, ptCustom
    
  Parameter* = object
    name*: string
    case typ*: ParamType
    of ptCustom:
      customType*: string
    else: discard
    
  ExportedFunc* = object
    name*: string
    returnType*: Parameter
    params*: seq[Parameter]
    isVariadic*: bool
    
  SourceModule* = object
    kind*: SourceKind
    path*: string
    exports*: seq[ExportedFunc]
    types*: Table[string, string]
    
  SourceKind* = enum
    skC, skZig, skNim

let
  cFuncPattern = re("""(?:extern\s+)?(\w+)\s+(\w+)\s*\((.*?)\)\s*;""")
  cParamPattern = re"""(\w+(?:\s*\*)*)\s+(\w+)(?:\s*,\s*)?"""
  zigFuncPattern = re"""export\s+fn\s+(\w+)\s*\((.*?)\)(?:\s*->\s*(\w+))?"""
  zigParamPattern = re"""(\w+):\s*([\w\[\]\*]+)(?:\s*,\s*)?"""

proc parseType(typeStr: string): Parameter =
  let cleanType = typeStr.strip.toLowerAscii
  
  # C types
  if cleanType.startsWith("const char*") or cleanType.startsWith("char*"):
    return Parameter(typ: ptString)
    
  if cleanType.startsWith("int*"):
    return Parameter(typ: ptCustom, customType: "ptr cint")
    
  # Zig types  
  if cleanType == "[*]u8":
    return Parameter(typ: ptCustom, customType: "ptr uint8")
    
  if cleanType == "[*]const u8":
    return Parameter(typ: ptString)
    
  # Basic types
  case cleanType
  of "void": Parameter(typ: ptVoid)
  of "int": Parameter(typ: ptInt)
  of "float", "f32": Parameter(typ: ptFloat) 
  of "u32": Parameter(typ: ptCustom, customType: "cuint")
  of "usize": Parameter(typ: ptCustom, customType: "csize_t")
  of "bool": Parameter(typ: ptCustom, customType: "bool")
  else:
    if "*" in cleanType:
      Parameter(typ: ptPointer)
    else:
      Parameter(typ: ptCustom, customType: cleanType)

proc parseCFunction(line: string): ExportedFunc =
  var matches: array[3, string]
  if match(line, cFuncPattern, matches):
    result.name = matches[1]
    result.returnType = parseType(matches[0])
    
    if matches[2].len > 0:
      for param in findAll(matches[2], cParamPattern):
        var paramMatches: array[2, string]
        if match(param, cParamPattern, paramMatches):
          result.params.add(parseType(paramMatches[0]))
          result.params[^1].name = paramMatches[1]
    
    result.isVariadic = "..." in line

proc parseZigFunction(line: string): ExportedFunc =
  var matches: array[3, string]
  if match(line, zigFuncPattern, matches):
    result.name = matches[0]
    result.returnType = if matches[2].len > 0: parseType(matches[2])
                       else: Parameter(typ: ptVoid)
    
    if matches[1].len > 0:
      for param in findAll(matches[1], zigParamPattern):
        var paramMatches: array[2, string]
        if match(param, zigParamPattern, paramMatches):
          result.params.add(parseType(paramMatches[1]))
          result.params[^1].name = paramMatches[0]

proc typeToNim(p: Parameter): string =
  case p.typ
  of ptVoid: "void"
  of ptInt: "cint"
  of ptFloat: "cfloat" 
  of ptString: "cstring"
  of ptPointer: "pointer"
  of ptCustom: p.customType

proc generateNimBindings(funcs: seq[ExportedFunc]): string =
  result = "{.push importc, cdecl.}\n\n"
  
  for f in funcs:
    var params = newSeq[string]()
    for p in f.params:
      params.add(fmt"{p.name}: {typeToNim(p)}")
      
    let returnType = if f.returnType.typ != ptVoid:
                      fmt": {typeToNim(f.returnType)}"
                    else: ""
                    
    let variadicMark = if f.isVariadic: ", varargs[untyped]" else: ""
    
    result &= "proc " & f.name & "*(" & params.join(",") & variadicMark & ")" & returnType & "\n"
  
  result &= "\n{.pop.}"

proc scanCHeaders(path: string): seq[ExportedFunc] =
  let content = readFile(path)
  for line in content.splitLines:
    let line = line.strip
    if line.len > 0 and not line.startsWith("//"):
      let fn = parseCFunction(line)
      if fn.name.len > 0:
        result.add(fn)

proc scanZigExports(path: string): seq[ExportedFunc] =
  let content = readFile(path)
  for line in content.splitLines:
    let line = line.strip
    if line.startsWith("export fn"):
      let fn = parseZigFunction(line)
      if fn.name.len > 0:
        result.add(fn)

proc scanSourceDir*(dir: string): seq[SourceModule] =
  for kind, path in walkDir(dir):
    let dirName = path.extractFilename
    case dirName
    of "C":
      for file in walkFiles(path / "*.h"):
        result.add(SourceModule(
          kind: skC,
          path: file,
          exports: scanCHeaders(file)
        ))
    of "Zig":
      for file in walkFiles(path / "*.zig"):
        result.add(SourceModule(
          kind: skZig,
          path: file,
          exports: scanZigExports(file)
        ))

proc generateBindings*(modules: seq[SourceModule], outDir: string) =
  createDir(outDir)
  
  for m in modules:
    let filename = case m.kind
      of skC: "c_bindings.nim"
      of skZig: "zig_bindings.nim"
      else: continue
      
    let bindings = generateNimBindings(m.exports)
    writeFile(outDir / filename, bindings)
