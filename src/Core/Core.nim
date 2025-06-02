import std/[strutils, strformat, tables, terminal]
import compiler/lexer
import compiler/parser
import compiler/codegen
import compiler/ast
import analyzer/semantic

const
  FgBlack*   = "\e[30m"
  FgRed*     = "\e[31m"
  FgGreen*   = "\e[32m"
  FgYellow*  = "\e[33m"
  FgBlue*    = "\e[34m"
  FgMagenta* = "\e[35m"
  FgCyan*    = "\e[36m"
  FgWhite*   = "\e[37m"
  Reset*     = "\e[0m"

type
  CompilerPhase* = enum
    phLexing, phParsing, phSemanticAnalysis, phCodeGeneration

  CompilationResult* = object
    success*: bool
    errorMessage*: string
    errorLine*: int
    errorColumn*: int
    phase*: CompilerPhase

  RytonCompiler* = ref object
    sourceCode*: string
    tokens*: seq[Token]
    outputPath*: string
    verbose*: bool
    ast*: Node

proc newCompiler*(sourceCode: string, outputPath: string = "", verbose: bool = false): RytonCompiler =
  ## Создает новый экземпляр компилятора
  result = RytonCompiler(
    sourceCode: sourceCode,
    tokens: @[],
    outputPath: outputPath,
    verbose: verbose
  )

proc tokenize*(self: RytonCompiler): CompilationResult =
  ## Выполняет лексический анализ исходного кода
  try:
    let lexer = newLexer(self.sourceCode)
    self.tokens = lexer.scanTokens()
    
    if self.verbose:
      echo "Tokenization completed successfully."
      echo fmt"Found {self.tokens.len} tokens."
    
    return CompilationResult(
      success: true,
      phase: phLexing
    )
  except Exception as e:
    return CompilationResult(
      success: false,
      errorMessage: e.msg,
      phase: phLexing
    )

proc dumpTokens*(self: RytonCompiler, filePath: string = "") =
  ## Выводит все токены в консоль или файл
  if self.tokens.len == 0:
    echo "No tokens to dump. Run tokenize() first."
    return
  
  var output = ""
  for i, token in self.tokens:
    let tokenStr = fmt"{i:4}: {token.kind:<15} '{token.lexeme}' at {token.line}:{token.column}"
    output.add(tokenStr & "\n")
  
  if filePath.len > 0:
    try:
      writeFile(filePath, output)
      if self.verbose:
        echo fmt"Tokens dumped to {filePath}"
    except Exception as e:
      echo fmt"Error writing to file: {e.msg}"
  else:
    echo output

proc getTokenStatistics*(self: RytonCompiler): Table[TokenKind, int] =
  ## Возвращает статистику по типам токенов
  result = initTable[TokenKind, int]()
  
  for token in self.tokens:
    if result.hasKey(token.kind):
      result[token.kind] = result[token.kind] + 1
    else:
      result[token.kind] = 1

proc printTokenStatistics*(self: RytonCompiler) =
  ## Выводит статистику по типам токенов
  if self.tokens.len == 0:
    echo "No tokens available. Run tokenize() first."
    return
  
  let stats = self.getTokenStatistics()
  echo "Token Statistics:"
  echo "================="
  
  for kind, count in stats.pairs:
    echo fmt"{kind:<15}: {count:4} ({count * 100 / self.tokens.len:.1f}%)"

proc findTokensByKind*(self: RytonCompiler, kind: TokenKind): seq[Token] =
  ## Находит все токены определенного типа
  result = @[]
  for token in self.tokens:
    if token.kind == kind:
      result.add(token)

proc findKeywords*(self: RytonCompiler): Table[string, int] =
  ## Находит все ключевые слова и их количество
  result = initTable[string, int]()
  
  let keywordKinds = {
    tkFunc, tkPack, tkEvent, tkInit, tkMacro, tkIf, tkElif, tkElse,
    tkFor, tkIn, tkInfinit, tkRepeat, tkTry, tkError, tkSwitch, tkWith,
    tkLazy, tkData, tkTable, tkPrivate, tkSlots, tkImport, tkModule, tkNoop
  }
  
  for token in self.tokens:
    if token.kind in keywordKinds:
      if result.hasKey(token.lexeme):
        result[token.lexeme] = result[token.lexeme] + 1
      else:
        result[token.lexeme] = 1

proc printKeywordStatistics*(self: RytonCompiler) =
  ## Выводит статистику по ключевым словам
  let keywords = self.findKeywords()
  
  if keywords.len == 0:
    echo "No keywords found."
    return
  
  echo "Keyword Statistics:"
  echo "=================="
  
  for keyword, count in keywords.pairs:
    echo fmt"{keyword:<10}: {count:4}"

proc printTokens*(tokens: seq[Token]) =
  ## Выводит токены в консоль
  echo "Tokens: "
  echo lexerTokens(tokens)

proc saveTokens*(tokens: seq[Token]) =
  ## Выводит токены в консоль
  echo "Tokens saved to: " 
  let textTokens = lexerTokens(tokens)

  writeFile("tokens.txt", textTokens)

proc loadFile*(filePath: string): string =
  ## Загружает содержимое файла
  try:
    result = readFile(filePath)
  except Exception as e:
    echo fmt"Error loading file {filePath}: {e.msg}"
    result = ""

proc saveToFile*(content: string, filePath: string): bool =
  ## Сохраняет содержимое в файл
  try:
    writeFile(filePath, content)
    return true
  except Exception as e:
    echo fmt"Error saving to file {filePath}: {e.msg}"
    return false

# Добавляем функцию для парсинга кода
# Обновляем функцию parse
proc parse*(self: RytonCompiler): CompilationResult =
  ## Выполняет синтаксический анализ и строит AST
  try:
    if self.tokens.len == 0:
      # Если токены еще не получены, выполняем лексический анализ
      let lexResult = self.tokenize()
      if not lexResult.success:
        return lexResult
    
    # Создаем парсер
    var p = newParser(self.tokens)
    
    # Вызываем метод parse из Parser, который возвращает корневой узел AST
    # В вашем parser.nim должна быть функция parse, которая парсит весь код
    self.ast = p.parse()

    if self.verbose:
      echo "Parsing completed successfully."
    
    return CompilationResult(
      success: true,
      phase: phParsing
    )
  except Exception as e:
    return CompilationResult(
      success: false,
      errorMessage: e.msg,
      phase: phParsing
    )

proc semanticAnalysis*(self: RytonCompiler): CompilationResult =
  try:
    if self.ast == nil:
      let parseResult = self.parse()
      if not parseResult.success:
        return parseResult
    
    let analyzer = newSemanticAnalyzer()
    discard analyzer.analyze(self.ast)
    
    # if self.verbose:
    #   analyzer.printErrors()
    
    if analyzer.hasErrors():
      # Выводим первую ошибку для диагностики
      let firstError = analyzer.errors[0]
      return CompilationResult(
        success: false,
        errorMessage: firstError.message,
        errorLine: firstError.line,
        errorColumn: firstError.column,
        phase: phSemanticAnalysis
      )
    
    return CompilationResult(
      success: true,
      phase: phSemanticAnalysis
    )
  except Exception as e:
    return CompilationResult(
      success: false,
      errorMessage: fmt"Semantic analyzer crashed: {e.msg}",
      errorLine: 0,
      errorColumn: 0,
      phase: phSemanticAnalysis
    )

# Добавляем функцию для вывода AST
proc dumpAST*(self: RytonCompiler, filePath: string = "") =
  ## Выводит AST в консоль или файл
  if self.ast == nil:
    echo "No AST to dump. Run parse() first."
    return
  
  if filePath.len > 0:
    try:
      # Перенаправляем вывод в файл
      let oldStdout = stdout
      let fileHandle = open(filePath, fmWrite)
      stdout = fileHandle
      
      printAST(self.ast)
      
      # Восстанавливаем стандартный вывод
      stdout = oldStdout
      fileHandle.close()
      
      if self.verbose:
        echo fmt"AST dumped to {filePath}"
    except Exception as e:
      echo fmt"Error writing to file: {e.msg}"
  else:
    printAST(self.ast)

proc generateCode*(self: RytonCompiler): CompilationResult =
  ## Генерирует код на основе AST
  try:
    if self.ast == nil:
      # Если AST еще не построен, выполняем парсинг
      let parseResult = self.parse()
      if not parseResult.success:
        return parseResult
    
    # Генерируем код Nim из AST
    let nimCode = generateNimCode(self.ast)
    
    # Сохраняем сгенерированный код в файл, если указан путь
    if self.outputPath.len > 0:
      try:
        writeFile(self.outputPath, nimCode)
        if self.verbose:
          echo fmt"Code generated and saved to {self.outputPath}"
      except Exception as e:
        return CompilationResult(
          success: false,
          errorMessage: fmt"Error writing to file: {e.msg}",
          phase: phCodeGeneration
        )
    
    if self.verbose:
      echo "Code generation completed successfully."
    
    return CompilationResult(
      success: true,
      phase: phCodeGeneration
    )
  except Exception as e:
    return CompilationResult(
      success: false,
      errorMessage: e.msg,
      phase: phCodeGeneration
    )

proc formatError(errorType: string, message: string, errorLine: int, errorColumn: int): string =
  let width = terminal.terminalWidth()
  let line = "─".repeat(width - 1)
  result = fmt"""
├─{FgRed} ⚠ {errorType} {Reset}{"─".repeat(width - (6 + errorType.len))}
│ {message}
├{line}
│ Line {errorLine}, Column {errorColumn}
│ 
│ ↑
╰{line}"""

# Добавляем функцию для полной компиляции
proc compile*(self: RytonCompiler): CompilationResult =
  ## Выполняет полный цикл компиляции: лексический анализ, парсинг, генерация кода
  
  # Лексический анализ
  echo fmt"╭─────{FgGreen} Starting compilation... {Reset}"
  echo fmt"├──{FgYellow} Starting lexical analysis... {Reset}"
  let lexResult = self.tokenize()
  if not lexResult.success:
    echo fmt"├─{FgRed} ✗ Lexical analysis failed. {Reset}"
    echo formatError(fmt"LexerError", lexResult.errorMessage, lexResult.errorLine, lexResult.errorColumn)

  echo fmt"├─{FgGreen} ✓ Lexical analysis completed successfully. {Reset}"
  
  # Парсинг
  echo fmt"├──{FgYellow} Starting parsing... {Reset}"
  let parseResult = self.parse()
  if not parseResult.success:
    echo fmt"├─{FgRed} ✗ Parsing failed. {Reset}"
    echo formatError(fmt"ParserError", parseResult.errorMessage, parseResult.errorLine, parseResult.errorColumn)

  echo fmt"├─{FgGreen} ✓ Parsing completed successfully {Reset}"

  # Семантический анализ
  echo fmt"├──{FgYellow} Starting semantic analysis... {Reset}"
  let semanticResult = self.semanticAnalysis()
  if not semanticResult.success:
    echo fmt"├─{FgRed} ✗ Semantic analysis failed. {Reset}"
    echo formatError(fmt"SemanticError", semanticResult.errorMessage, semanticResult.errorLine, semanticResult.errorColumn)
    #return semanticResult
  echo fmt"├─{FgGreen} ✓ Semantic analysis completed successfully {Reset}"
  
  # Генерация кода
  echo fmt"├──{FgYellow} Starting code generation... {Reset}"
  let resultCode = self.generateCode()
  if not resultCode.success:
    echo fmt"├─{FgRed} ✗ Code generation failed. {Reset}"
    echo formatError(fmt"CodegenError", resultCode.errorMessage, resultCode.errorLine, resultCode.errorColumn)
    return resultCode
  echo fmt"├─{FgGreen} ✓ Code generation completed successfully. {Reset}"

  return resultCode

proc compileToNimCode*(self: RytonCompiler, rytonCode: string): string =
  self.sourceCode = rytonCode
  discard self.compile()
  return readFile(self.outputPath)

proc compileRytonFile*(self: RytonCompiler, rytonPath: string): string = 
  self.sourceCode = readFile(rytonPath)
  discard self.compile()
  return readFile(self.outputPath)
