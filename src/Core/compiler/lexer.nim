import std/[strutils, strformat, tables]

type
  TokenKind* = enum
    # Ключевые слова
    tkFunc, tkPack, tkEvent, tkInit, tkMacro, tkIf, tkElif, tkElse
    tkFor, tkIn, tkInfinit, tkRepeat, tkTry, tkElerr, tkSwitch, tkWith
    tkLazy, tkData, tkTable, tkPrivate, tkSlots, tkImport, tkModule,
    tkNoop, tkOutPut
    
    # Операторы
    tkPlus, tkMinus, tkMul, tkDiv, tkAssign, tkEq, tkNe, tkLt, tkGt, tkLe, tkGe
    tkPlusEq, tkMinusEq, tkMulEq, tkDivEq, tkPipe, tkAnd, tkOr, tkArrow, tkFatArrow
    tkDot, tkComma, tkColon, tkColonColon, tkSemicolon, tkQuestion, tkBang, tkPercent,
    tkColonEq, tkTrue, tkFalse, tkDotDot, tkDotDotDot, tkRetType, tkModStart, tkModEnd,
    tkPtr, tkRef, tkBar, tkDef, tkVal
    
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
    keywords*: Table[string, TokenKind]

proc newLexer*(source: string): Lexer =
  ## Создает новый лексер для заданного исходного кода
  result = Lexer(
    source: source,
    tokens: @[],
    current: 0,
    start: 0,
    line: 1,
    column: 1,
    keywords: {
      "func": tkFunc,
      "pack": tkPack,
      "event": tkEvent,
      "init": tkInit,
      "macro": tkMacro,
      "def": tkDef,
      "val": tkVal,
      "if": tkIf,
      "elif": tkElif,
      "else": tkElse,
      "for": tkFor,
      "in": tkIn,
      "infinit": tkInfinit,
      "repeat": tkRepeat,
      "try": tkTry,
      "elerr": tkElerr,
      "switch": tkSwitch,
      "with": tkWith,
      "lazy": tkLazy,
      "data": tkData,
      "table": tkTable,
      "private": tkPrivate,
      "slots": tkSlots,
      "module import": tkModule,
      "output": tkOutPut,
      "true": tkTrue,
      "false": tkFalse,
      "noop": tkNoop
    }.toTable
  )

proc isAtEnd(self: Lexer): bool =
  ## Проверяет, достигнут ли конец исходного кода
  self.current >= self.source.len

proc advance(self: Lexer): char =
  ## Возвращает текущий символ и переходит к следующему
  result = self.source[self.current]
  inc(self.current)
  inc(self.column)

proc peek(self: Lexer): char =
  ## Возвращает текущий символ без перехода к следующему
  if self.isAtEnd(): return '\0'
  return self.source[self.current]

proc peekNext(self: Lexer): char =
  ## Возвращает следующий символ без перехода к нему
  if self.current + 1 >= self.source.len: return '\0'
  return self.source[self.current + 1]

proc match(self: Lexer, expected: char): bool =
  ## Проверяет, соответствует ли текущий символ ожидаемому
  if self.isAtEnd(): return false
  if self.source[self.current] != expected: return false
  
  inc(self.current)
  inc(self.column)
  return true

proc addToken(self: Lexer, kind: TokenKind, lexeme: string = "") =
  ## Добавляет токен в список токенов
  let text = if lexeme == "": self.source[self.start..<self.current] else: lexeme
  self.tokens.add(Token(
    kind: kind,
    lexeme: text,
    line: self.line,
    column: self.column - text.len
  ))

proc scanString(self: Lexer) =
  ## Обрабатывает строковый литерал
  while self.peek() != '"' and not self.isAtEnd():
    if self.peek() == '\n':
      inc(self.line)
      self.column = 1
    discard self.advance()
  
  if self.isAtEnd():
    # Ошибка: незакрытая строка
    self.addToken(tkUnknown)
    return
  
  # Закрывающая кавычка
  discard self.advance()
  
  # Значение строки (без кавычек)
  let value = self.source[self.start+1..<self.current-1]
  self.addToken(tkString, value)

proc scanSingleQuoteString(self: Lexer) =
  ## Обрабатывает строковый литерал в одинарных кавычках
  while self.peek() != '\'' and not self.isAtEnd():
    if self.peek() == '\n':
      inc(self.line)
      self.column = 1
    discard self.advance()
  
  if self.isAtEnd():
    # Ошибка: незакрытая строка
    self.addToken(tkUnknown)
    return
  
  # Закрывающая кавычка
  discard self.advance()
  
  # Значение строки (без кавычек)
  let value = self.source[self.start+1..<self.current-1]
  self.addToken(tkString, value)

proc scanNumber(self: Lexer) =
  ## Обрабатывает числовой литерал
  while self.peek().isDigit():
    discard self.advance()
  
  # Проверяем десятичную точку
  if self.peek() == '.' and self.peekNext().isDigit():
    # Потребляем точку
    discard self.advance()
    
    # Потребляем цифры после точки
    while self.peek().isDigit():
      discard self.advance()
  
  self.addToken(tkNumber)

proc scanIdentifier(self: Lexer) =
  ## Обрабатывает идентификатор или ключевое слово
  while self.peek().isAlphaNumeric() or self.peek() == '_':
    discard self.advance()

  let text = self.source[self.start..<self.current]

  # Добавляем проверку составных ключевых слов
  if text == "module" and self.peek() == ' ':
    discard self.advance() # пробел
    if self.source[self.current..self.current+5] == "import":
      self.current += 6
      self.addToken(tkModule)
      return
  
  # Проверяем, является ли это ключевым словом
  let kind = if self.keywords.hasKey(text): self.keywords[text] else: tkIdentifier
  
  self.addToken(kind)

proc scanComment(self: Lexer) =
  ## Обрабатывает однострочный комментарий
  while self.peek() != '\n' and not self.isAtEnd():
    discard self.advance()
  
  self.addToken(tkComment)

proc scanMultilineComment(self: Lexer) =
  ## Обрабатывает многострочный комментарий
  var nesting = 1
  
  while nesting > 0 and not self.isAtEnd():
    if self.peek() == '/' and self.peekNext() == '*':
      discard self.advance() # /
      discard self.advance() # *
      inc(nesting)
    elif self.peek() == '*' and self.peekNext() == '/':
      discard self.advance() # *
      discard self.advance() # /
      dec(nesting)
    elif self.peek() == '\n':
      inc(self.line)
      self.column = 1
      discard self.advance()
    else:
      discard self.advance()
  
  self.addToken(tkComment)

proc scanRytonComment(self: Lexer) =
  ## Обрабатывает специальный комментарий Ryton (</.../>)
  while not (self.peek() == '/' and self.peekNext() == '>') and not self.isAtEnd():
    if self.peek() == '\n':
      inc(self.line)
      self.column = 1
    discard self.advance()
  
  if self.isAtEnd():
    # Ошибка: незакрытый комментарий
    self.addToken(tkUnknown)
    return
  
  # Закрывающие символы
  discard self.advance() # /
  discard self.advance() # >
  
  self.addToken(tkComment)

proc scanToken(self: Lexer) =
  ## Сканирует один токен
  let c = self.advance()
  
  case c:
    of '(': self.addToken(tkLParen)
    of ')': self.addToken(tkRParen)
    of '{': self.addToken(tkLBrace)
    of '}': self.addToken(tkRBrace)
    of '[': self.addToken(tkLBracket)
    of ']': self.addToken(tkRBracket)
    of ',': self.addToken(tkComma)
    of ';': self.addToken(tkSemicolon)
    of '?': self.addToken(tkQuestion)
    of '%': self.addToken(tkPercent)
    
    # Операторы с возможными двойными символами
    of '+': 
      if self.match('='): self.addToken(tkPlusEq)
      else: self.addToken(tkPlus)
    of '-': 
      if self.match('='): self.addToken(tkMinusEq)
      else: self.addToken(tkMinus)
    of '*': 
      if self.match('='): self.addToken(tkMulEq)
      else: self.addToken(tkMul)
    of '/': 
      if self.match('/'): self.scanComment()
      elif self.match('*'): self.scanMultilineComment()
      elif self.match('='): self.addToken(tkDivEq)
      else: self.addToken(tkDiv)
    of '=': 
      if self.match('='): self.addToken(tkEq)
      elif self.match('>'): self.addToken(tkFatArrow)
      else: self.addToken(tkAssign)
    of '<': 
      if self.match('='): self.addToken(tkLe)
      elif self.match('/'): self.scanRytonComment()
      else: self.addToken(tkLt)
    of '>': 
      if self.match('='): self.addToken(tkGe)
      else: self.addToken(tkGt)
    of '|': 
      if self.match('>'): self.addToken(tkPipe)
      elif self.match(' '): self.addToken(tkBar)
      else: self.addToken(tkUnknown)
    of '&': 
      if self.match('&'): self.addToken(tkAnd)
      else: self.addToken(tkUnknown)
    of ':':
      if self.match('='):
        self.addToken(tkColonEq)  # Оператор ':='
      if not self.match(' '):
        if self.match(':'):
          self.addToken(tkColonColon) # Наследование
        else:
          self.addToken(tkRetType)
      else:
        self.addToken(tkColon)    # Просто двоеточие ':'
    of '.':
      if self.match('.'):
        if self.match('.'):
          self.addToken(tkDotDotDot)
        else:
          self.addToken(tkDotDot)
      else:
        self.addToken(tkDot)
    of '!': 
      if self.match(' ') or self.match('='):
        self.addToken(tkBang)
      elif self.match('('): 
        self.addToken(tkModStart)  # Добавляем только !( 
        
        while self.peek() == ' ':
          discard self.advance()
        
        self.start = self.current
        while self.peek().isAlphaNumeric():
          discard self.advance()
        self.addToken(tkIdentifier)
        
        while self.peek() == ' ':
          discard self.advance()
        
        if self.match(')'):
          self.start = self.current - 1  # Устанавливаем start на ')'
          self.addToken(tkModEnd)
      else:
        self.addToken(tkBang)
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

    # Строки
    of '"': self.scanString()
    of '\'': self.scanSingleQuoteString()
    
    # Пробелы и переносы строк
    of ' ', '\t', '\r': discard # Игнорируем пробелы
    of '\n': 
      self.addToken(tkNewline)
      inc(self.line)
      self.column = 1

    # Числа и идентификаторы
    else:
      if c.isDigit():
        self.scanNumber()
      elif c.isAlphaAscii() or c == '_':
        self.scanIdentifier()
      else:
        self.addToken(tkUnknown)

proc scanTokens*(self: Lexer): seq[Token] =
  ## Сканирует все токены в исходном коде
  while not self.isAtEnd():
    # Начинаем новый токен
    self.start = self.current
    self.scanToken()
  
  # Добавляем токен конца файла
  self.tokens.add(Token(
    kind: tkEOF,
    lexeme: "",
    line: self.line,
    column: self.column
  ))
  
  return self.tokens

proc tokenize*(source: string): seq[Token] =
  ## Удобная функция для токенизации строки
  let lexer = newLexer(source)
  return lexer.scanTokens()

# Вспомогательные функции для отладки
proc `$`*(token: Token): string =
  ## Строковое представление токена
  result = fmt"{token.kind}('{token.lexeme}' at {token.line}:{token.column})"

proc printTokens*(tokens: seq[Token]) =
  ## Выводит все токены
  for token in tokens:
    echo token
