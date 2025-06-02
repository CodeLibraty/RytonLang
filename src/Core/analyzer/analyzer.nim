## Главный модуль анализатора
import semantic_analyzer, symbol_table, type_checker
import ../compiler/ast

export semantic_analyzer, symbol_table, type_checker

proc analyzeAST*(ast: Node): tuple[success: bool, errors: seq[string], warnings: seq[string]] =
  ## Главная функция для анализа AST
  ## Возвращает результат анализа с ошибками и предупреждениями
  
  let analyzer = newSemanticAnalyzer()
  
  # Выполняем семантический анализ
  let success = analyzer.analyze(ast)
  
  # Проверяем неиспользуемые символы
  analyzer.checkUnusedSymbols()
  
  return (
    success: success,
    errors: analyzer.getErrors(),
    warnings: analyzer.getWarnings()
  )

proc printAnalysisResult*(result: tuple[success: bool, errors: seq[string], warnings: seq[string]]) =
  ## Красиво выводит результаты анализа
  
  const
    FgRed = "\e[31m"
    FgYellow = "\e[33m"
    FgGreen = "\e[32m"
    Reset = "\e[0m"
  
  if result.errors.len > 0:
    echo fmt"{FgRed}✗ SEMANTIC ERRORS:{Reset}"
    for error in result.errors:
      echo fmt"  {FgRed}•{Reset} {error}"
    echo ""
  
  if result.warnings.len > 0:
    echo fmt"{FgYellow}⚠ WARNINGS:{Reset}"
    for warning in result.warnings:
      echo fmt"  {FgYellow}•{Reset} {warning}"
    echo ""
  
  if result.success:
    echo fmt"{FgGreen}✓ Semantic analysis completed successfully{Reset}"
  else:
    echo fmt"{FgRed}✗ Semantic analysis failed with {result.errors.len} error(s){Reset}"

# Удобные функции для интеграции
proc quickAnalyze*(ast: Node): bool =
  ## Быстрый анализ - возвращает только успех/неудачу
  let result = analyzeAST(ast)
  return result.success

proc verboseAnalyze*(ast: Node): bool =
  ## Анализ с выводом всех диагностик
  let result = analyzeAST(ast)
  printAnalysisResult(result)
  return result.success
