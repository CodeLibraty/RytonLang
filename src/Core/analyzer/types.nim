import std/[tables, sets]

type
  SymbolKind* = enum
    skVariable, skFunction, skClass, skParameter, skMethod

  Symbol* = object
    name*: string
    kind*: SymbolKind
    symbolType*: string
    line*: int
    column*: int
    isUsed*: bool
    scope*: string

  Scope* = object
    name*: string
    symbols*: Table[string, Symbol]
    parent*: ref Scope

  SemanticError* = object
    message*: string
    line*: int
    column*: int
    errorType*: string

  SemanticWarning* = object
    message*: string
    line*: int
    column*: int
    warningType*: string

  SemanticAnalyzer* = ref object
    currentScope*: ref Scope
    globalScope*: ref Scope
    errors*: seq[SemanticError]
    warnings*: seq[SemanticWarning]
    currentFunction*: string
    currentClass*: string
    classTypes*: Table[string, seq[string]]  # Добавляем таблицу для хранения методов классов

proc newScope*(name: string, parent: ref Scope = nil): ref Scope =
  result = new(Scope)
  result.name = name
  result.symbols = initTable[string, Symbol]()
  result.parent = parent

proc newSemanticAnalyzer*(): SemanticAnalyzer =
  result = SemanticAnalyzer()
  result.globalScope = newScope("global")
  result.currentScope = result.globalScope
  result.errors = @[]
  result.warnings = @[]
  result.classTypes = initTable[string, seq[string]]()
