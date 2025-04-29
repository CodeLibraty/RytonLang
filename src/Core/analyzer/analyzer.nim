import std/[strutils, strformat, tables, sets, sequtils, options]
import ../compiler/lexer

type
  SyntaxError* = object
    message*: string
    line*: int
    column*: int
    lineContent*: string
    suggestion*: string

  Block = object
    openBrace: Token
    defToken: Option[Token]
    blockType: TokenKind

proc formatSyntaxError*(error: SyntaxError): string =
  var errorMessage = fmt"""
╭ SyntaxError
│ {error.message}
├─────────────────
│ Line {error.line}
│ 
│ {error.lineContent}
│ {' '.repeat(max(0, error.column-1))}^"""

  if error.suggestion.len > 0:
    errorMessage &= fmt""" 
│ 
│ Suggestion: {error.suggestion}"""
  
  errorMessage &= "\n╰─────────────────"
  return errorMessage

proc analyzeCode*(code: string): seq[SyntaxError] =
  result = @[]
  let lines = code.splitLines()
  let tokens = tokenize(code)
  
  var blockStack: seq[Token] = @[]
  
  for token in tokens:
    case token.kind
    of tkLBrace: blockStack.add(token)
    of tkRBrace:
      if blockStack.len == 0:
        result.add(SyntaxError(
          message: "Лишняя закрывающая скобка '}'",
          line: token.line,
          column: token.column,
          lineContent: lines[token.line - 1]
        ))
      else:
        discard blockStack.pop()

    else: discard

  if blockStack.len > 0:
    let lastBrace = blockStack[^1]
    result.add(SyntaxError(
      message: "Незакрытый блок",
      line: lastBrace.line, 
      column: lastBrace.column,
      lineContent: lines[lastBrace.line - 1],
      suggestion: "Добавьте закрывающую скобку '}'"
    ))

proc checkSyntax*(code: string): bool =
  let errors = analyzeCode(code)
  if errors.len > 0:
    for error in errors:
      echo formatSyntaxError(error)
    return false
  return true
