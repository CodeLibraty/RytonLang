import std/[strutils, strformat, tables]

type
  LexerContext* = enum
    lcNormal      # Обычный контекст
    lcExpression  # Внутри выражения
    lcStatement   # Начало statement
    lcAttribute   # После точки
    lcImport      # Внтури module import
    lcTypeCheck   # Внтури блока типовой проверки

  TokenKind* = enum
    # Ключевые слова
    tkFunc, tkPack, tkEvent, tkInit, tkMacro, tkIf, tkElif, tkElse
    tkFor, tkIn, tkInfinit, tkRepeat, tkTry, tkError, tkSwitch, tkWith
    tkLazy, tkData, tkTable, tkPrivate, tkSlots, tkImport, tkModule,
    tkNoop, tkOutPut, tkLambda, tkEach, tkFrom, tkTo, tkStep, tkWhere,
    tkState, tkWhile, tkDefault, tkCase
    
    # Операторы
    tkPlus, tkMinus, tkMul, tkDiv, tkAssign, tkEq, tkNe, tkLt, tkGt, tkLe, tkGe
    tkPlusEq, tkMinusEq, tkMulEq, tkDivEq, tkPipe, tkAnd, tkOr, tkNot, tkRightArrow, tkLeftArrow,
    tkDot, tkComma, tkColon, tkColonColon, tkSemicolon, tkQuestion, tkBang, tkPercent,
    tkColonEq, tkTrue, tkFalse, tkDotDot, tkDotDotDot, tkRetType, tkModStart, tkModEnd,
    tkPtr, tkRef, tkBar, tkDef, tkVal, tkFatArrow

    # Синтаксис свойств
    tkTypeCheck,     # <
    tkTypeEnd,       # >
    tkTypeColon,     # :
    tkTypeFunc,      # Имя функции в проверке типа
    tkBacktick,      # `
    tkTypeDirective  # Токен для директивы внутри обратных кавычек

    # Скобки и разделители
    tkLParen, tkRParen, tkLBrace, tkRBrace, tkLBracket, tkRBracket
    
    # Литералы
    tkString, tkNumber, tkIdentifier
    
    # Специальные токены
    tkComment, tkNewline, tkEOF, tkUnknown

  Token* = object
    kind*: TokenKind
    lexeme*: string
    line*: int
    column*: int

  Lexer* = ref object
    source*: string
    tokens*: seq[Token]
    current*: int
    start*: int
    line*: int
    column*: int
    context*: LexerContext
    keywords*: Table[string, TokenKind]

proc newLexer*(source: string): Lexer =
  result = Lexer(
    source: source,
    tokens: @[],
    current: 0,
    start: 0,
    line: 1,
    column: 1,
    context: lcNormal,
    keywords: {
      "func":       tkFunc,
      "lambda":     tkLambda,
      "pack":       tkPack,
      "state":      tkState,
      "event":      tkEvent,
      "init":       tkInit,
      "macro":      tkMacro,
      "def":        tkDef,
      "val":        tkVal,
      "if":         tkIf,
      "elif":       tkElif,
      "else":       tkElse,
      "for":        tkFor,
      "in":         tkIn,
      "infinit":    tkInfinit,
      "repeat":     tkRepeat,
      "try":        tkTry,
      "error":      tkError,
      "switch":     tkSwitch,
      "case":       tkCase,
      "default":    tkDefault,
      "with":       tkWith,
      "lazy":       tkLazy,
      "data":       tkData,
      "table":      tkTable,
      "private":    tkPrivate,
      "slots":      tkSlots,
      "while":      tkWhile,
      "output":     tkOutPut,
      "each":       tkEach,
      "from":       tkFrom,
      "to":         tkTo,
      "step":       tkStep,
      "where":      tkWhere,
      "true":       tkTrue,
      "false":      tkFalse,
      "and":        tkAnd,
      "or":         tkOr,
      "not":        tkNot,
      "noop":       tkNoop,
      "module import":  tkModule
    }.toTable
  )

proc isAtEnd(self: Lexer): bool =
  self.current >= self.source.len

proc advance(self: Lexer): char =
  result = self.source[self.current]
  inc(self.current)
  inc(self.column)

proc peek(self: Lexer): char =
  if self.isAtEnd(): return '\0'
  return self.source[self.current]

proc peekNext(self: Lexer): char =
  if self.current + 1 >= self.source.len: return '\0'
  return self.source[self.current + 1]

proc match(self: Lexer, expected: char): bool =
  if self.isAtEnd(): return false
  if self.source[self.current] != expected: return false
  
  inc(self.current)
  inc(self.column)
  return true

proc addToken(self: Lexer, kind: TokenKind, lexeme: string = "") =
  let text = if lexeme == "": self.source[self.start..<self.current] else: lexeme
  self.tokens.add(Token(
    kind: kind,
    lexeme: text,
    line: self.line,
    column: self.column - text.len
  ))

proc scanString(self: Lexer) =
  self.context = lcExpression
  while self.peek() != '"' and not self.isAtEnd():
    if self.peek() == '\n':
      inc(self.line)
      self.column = 1
    discard self.advance()
  
  if self.isAtEnd():
    self.addToken(tkUnknown)
    return
  
  discard self.advance()
  let value = self.source[self.start+1..<self.current-1]
  self.addToken(tkString, value)

proc scanSingleQuoteString(self: Lexer) =
  self.context = lcExpression
  while self.peek() != '\'' and not self.isAtEnd():
    if self.peek() == '\n':
      inc(self.line)
      self.column = 1
    discard self.advance()
  
  if self.isAtEnd():
    self.addToken(tkUnknown)
    return
  
  discard self.advance()
  let value = self.source[self.start+1..<self.current-1]
  self.addToken(tkString, value)

proc scanNumber(self: Lexer) =
  self.context = lcExpression
  while self.peek().isDigit():
    discard self.advance()
  
  if self.peek() == '.' and self.peekNext().isDigit():
    discard self.advance()
    while self.peek().isDigit():
      discard self.advance()
  
  self.addToken(tkNumber)

proc scanIdentifier(self: Lexer) =
  while self.peek().isAlphaNumeric() or self.peek() == '_' or self.peek() == '.':
    if self.peek() == '.':
      discard self.advance()
      if not self.peek().isAlphaAscii():
        break
    discard self.advance()

  let text = self.source[self.start..<self.current]

  # Проверяем контекст для правильной обработки ключевых слов
  case self.context
  of lcStatement:
    # В начале statement все ключевые слова обрабатываются как ключевые слова
    if self.keywords.hasKey(text):
      self.addToken(self.keywords[text])
    else:
      self.addToken(tkIdentifier)
      self.context = lcExpression
      
  of lcAttribute:
    # После точки всегда идентификатор
    self.addToken(tkIdentifier)
    self.context = lcExpression
    
  of lcExpression:
    # В выражении всё идентификаторы кроме операторов и лямбда функций
    if self.keywords.hasKey(text):
      self.addToken(self.keywords[text])
    else:
      self.addToken(tkIdentifier)

  of lcNormal:
    if text == "module" and self.peek() == ' ':
      discard self.advance() 
      if self.source[self.current..self.current+5] == "import":
        self.current += 6
        self.addToken(tkModule)
        while self.peek().isSpaceAscii: discard self.advance()
        if self.peek() == '{':
          discard self.advance()
          self.addToken(tkLBrace)
          self.context = lcImport
    elif self.keywords.hasKey(text):
      self.addToken(self.keywords[text])
    else:
      self.addToken(tkIdentifier)
      self.context = lcExpression

  of lcTypeCheck:
    # В контексте типовой проверки все идентификаторы 
    # обрабатываются как часть кода проверки
    if self.match('{'):
      var codeBuffer = ""
      var braceLevel = 1
      while braceLevel > 0:
        let c = self.advance()
        if c == '{': inc braceLevel
        elif c == '}':
          dec braceLevel
          if braceLevel == 0: break
        codeBuffer.add(c)
      self.addToken(tkTypeFunc, codeBuffer)
      self.context = lcNormal
    else:
      self.addToken(tkIdentifier)

  of lcImport:
    # Обрабатываем пути импорта как единые токены
    while self.peek().isAlphaNumeric() or self.peek() == '.' or self.peek() == '_':
      discard self.advance()
    self.addToken(tkIdentifier)

proc scanComment(self: Lexer) =
  while self.peek() != '\n' and not self.isAtEnd():
    discard self.advance()
  self.addToken(tkComment)

proc scanMultilineComment(self: Lexer) =
  var nesting = 1
  while nesting > 0 and not self.isAtEnd():
    if self.peek() == '/' and self.peekNext() == '*':
      discard self.advance()
      discard self.advance()
      inc(nesting)
    elif self.peek() == '*' and self.peekNext() == '/':
      discard self.advance()
      discard self.advance()
      dec(nesting)
    elif self.peek() == '\n':
      inc(self.line)
      self.column = 1
      discard self.advance()
    else:
      discard self.advance()
  self.addToken(tkComment)

proc scanRytonComment(self: Lexer) =
  while not (self.peek() == '/' and self.peekNext() == '>') and not self.isAtEnd():
    if self.peek() == '\n':
      inc(self.line)
      self.column = 1
    discard self.advance()
  
  if self.isAtEnd():
    self.addToken(tkUnknown)
    return
  
  discard self.advance()
  discard self.advance()
  self.addToken(tkComment)

proc scanToken(self: Lexer) =
  let c = self.advance()
  
  case c:
    of '(':
      self.addToken(tkLParen)
      self.context = lcExpression
    of ')':
      self.addToken(tkRParen)
      self.context = lcExpression
    of '{':
      self.addToken(tkLBrace)
      self.context = lcStatement
    of '}':
      self.addToken(tkRBrace)
      self.context = lcNormal
    of '[':
      self.addToken(tkLBracket)
      self.context = lcExpression
    of ']':
      self.addToken(tkRBracket)
      self.context = lcExpression
    of ',':
      self.addToken(tkComma)
      self.context = lcExpression
    of ';':
      if self.match(' '):
        self.addToken(tkNewline)
        inc(self.line)
        self.column = 1
      else:
        self.addToken(tkSemicolon)
      self.context = lcStatement
    of '?':
      self.addToken(tkQuestion)
      self.context = lcExpression
    of '%':
      self.addToken(tkPercent)
      self.context = lcExpression
    
    of '+': 
      if self.match('='): self.addToken(tkPlusEq)
      else: self.addToken(tkPlus)
      self.context = lcExpression
      
    of '-': 
      if self.match('='): self.addToken(tkMinusEq)
      else: self.addToken(tkMinus)
      self.context = lcExpression
      
    of '*': 
      if self.match('='): self.addToken(tkMulEq)
      else: self.addToken(tkMul)
      self.context = lcExpression
      
    of '/': 
      if self.match('/'): self.scanComment()
      elif self.match('*'): self.scanMultilineComment()
      elif self.match('='): self.addToken(tkDivEq)
      else: self.addToken(tkDiv)
      self.context = lcExpression
      
    of '=': 
      if self.match('='): self.addToken(tkEq)
      elif self.match('>'): self.addToken(tkFatArrow)
      else: self.addToken(tkAssign)
      self.context = lcExpression

    of '`':
      # Начало директивы
      self.start = self.current
      while self.peek() != '`' and not self.isAtEnd():
        discard self.advance()
      
      if self.isAtEnd():
        self.addToken(tkUnknown)
        return
      
      let directive = self.source[self.start..<self.current]
      discard self.advance() # Потребляем закрывающую обратную кавычку
      self.addToken(tkTypeDirective, directive)

    of '<': 
      if self.match('='): self.addToken(tkLe) 
      elif self.match('-'): self.addToken(tkLeftArrow) 
      elif self.match('/'): self.scanRytonComment()
      elif self.peek().isAlphaAscii():
        # Токен для <
        self.start = self.current - 1
        self.addToken(tkTypeCheck)
        self.context = lcTypeCheck  # Переключаем контекст
        
        # Токен для типа
        self.start = self.current
        while self.peek().isAlphaAscii():
          discard self.advance()
        self.addToken(tkIdentifier)
        
        if self.match(':'):
          # Токен для :
          self.start = self.current - 1
          self.addToken(tkTypeColon)
          
          # Пропускаем пробелы до {
          while self.peek().isSpaceAscii: 
            discard self.advance()
          
          if self.peek() == '{':
            discard self.advance() # Пропускаем {
            self.start = self.current
            var braceLevel = 1
            
            while braceLevel > 0:
              if self.peek() == '{': inc braceLevel
              elif self.peek() == '}':
                dec braceLevel
                if braceLevel == 0: break
              discard self.advance()
            
            # Добавляем код без скобок
            let code = self.source[self.start..<self.current]
            self.addToken(tkTypeFunc, code)
            discard self.advance() # Пропускаем }
          
          if self.match('>'):
            self.start = self.current - 1
            self.addToken(tkTypeEnd)
            self.context = lcNormal
      else:
        self.addToken(tkLt)  # просто <
        self.context = lcExpression

    of '>': 
      if self.match('='): self.addToken(tkGe)
      else: self.addToken(tkGt)
      self.context = lcExpression
      
    of '|': 
      if self.match('>'): self.addToken(tkPipe)
      elif self.match(' '): self.addToken(tkBar)
      else: self.addToken(tkUnknown)
      self.context = lcExpression
      
    of '&': 
      if self.match('&'): self.addToken(tkAnd)
      else: self.addToken(tkUnknown)
      self.context = lcExpression
      
    of '.':
      if self.match('.'):
        if self.match('.'):
          self.addToken(tkDotDotDot)
        else:
          self.addToken(tkDotDot)
      else:
        self.addToken(tkDot)
        self.context = lcAttribute
        
    of ':':
      if self.match('='):
        self.addToken(tkColonEq)
      if not self.match(' '):
        if self.match(':'):
          self.addToken(tkColonColon)
        else:
          self.addToken(tkRetType)
      else:
        self.addToken(tkColon)
      self.context = lcExpression
        
    of '!': 
      if self.match(' ') or self.match('='):
        self.addToken(tkBang)
      elif self.match('('): 
        self.addToken(tkModStart)
        
        while self.peek() == ' ':
          discard self.advance()
        
        self.start = self.current
        while self.peek().isAlphaNumeric():
          discard self.advance()
        self.addToken(tkIdentifier)
        
        while self.peek() == ' ':
          discard self.advance()
        
        if self.match(')'):
          self.start = self.current - 1
          self.addToken(tkModEnd)
      else:
        self.addToken(tkBang)
      self.context = lcExpression
        
    of 'p':
      if self.source[self.current..self.current+2] == "ptr":
        self.current += 3
        self.addToken(tkPtr)
      else:
        self.scanIdentifier()
        
    of 'r': 
      if self.source[self.current..self.current+2] == "ref":
        self.current += 3
        self.addToken(tkRef) 
      else:
        self.scanIdentifier()

    of '"': self.scanString()
    of '\'': self.scanSingleQuoteString()
    
    of ' ', '\t', '\r': discard
    
    of '\n': 
      self.addToken(tkNewline)
      inc(self.line)
      self.column = 1
      self.context = lcStatement

    else:
      if c.isDigit():
        self.scanNumber()
      elif c.isAlphaAscii() or c == '_':
        self.scanIdentifier()
      else:
        self.addToken(tkUnknown)

proc scanTokens*(self: Lexer): seq[Token] =
  while not self.isAtEnd():
    self.start = self.current
    self.scanToken()
  
  self.tokens.add(Token(
    kind: tkEOF,
    lexeme: "",
    line: self.line,
    column: self.column
  ))
  
  return self.tokens

proc tokenize*(source: string): seq[Token] =
  let lexer = newLexer(source)
  return lexer.scanTokens()

proc `$`*(token: Token): string =
  if token.kind == tkNewline:
    fmt"{token.kind}('\n' at {token.line}:{token.column})"
  else:
    fmt"{token.kind}('{token.lexeme}' at {token.line}:{token.column})"

proc lexerTokens*(tokens: seq[Token]): string =
  for token in tokens:
    result &= fmt"{token}" & "\n"
  
  return result

