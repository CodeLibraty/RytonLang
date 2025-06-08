import std/[strutils, strformat, times, os, terminal, tables]

type
  LogLevel* = enum
    llInfo = "INFO"
    llWarning = "WARNING" 
    llError = "ERROR"
    llSuccess = "SUCCESS"

  Logger* = ref object
    currentFile*: bool
    colors*: bool
    printType*: bool
    stringLog*: bool
    autoDumpFile*: string
    logging*: bool
    warningColor*: string
    errorColor*: string
    infoColor*: string
    successColor*: string
    isStarted: bool
    logHistory: seq[string]
    colorMap: Table[string, string]

proc initColorMap(): Table[string, string] =
  result = {
    "red": "\e[31m",
    "green": "\e[32m", 
    "yellow": "\e[33m",
    "blue": "\e[34m",
    "magenta": "\e[35m",
    "cyan": "\e[36m",
    "white": "\e[37m",
    "orange": "\e[38;5;208m",
    "reset": "\e[0m"
  }.toTable

proc newLogger*(
  currentFile: bool = true,
  colors: bool = true,
  printType: bool = true,
  stringLog: bool = true,
  autoDumpFile: string = "",
  logging: bool = true,
  warningColor: string = "yellow",
  errorColor: string = "red", 
  infoColor: string = "blue",
  successColor: string = "green"
): Logger =
  result = Logger(
    currentFile: currentFile,
    colors: colors,
    printType: printType,
    stringLog: stringLog,
    autoDumpFile: autoDumpFile,
    logging: logging,
    warningColor: warningColor,
    errorColor: errorColor,
    infoColor: infoColor,
    successColor: successColor,
    isStarted: false,
    logHistory: @[],
    colorMap: initColorMap()
  )

proc getColorCode(self: Logger, colorName: string): string =
  if not self.colors:
    return ""
  return self.colorMap.getOrDefault(colorName.toLower(), "")

proc getResetCode(self: Logger): string =
  if not self.colors:
    return ""
  return self.colorMap["reset"]

proc getCurrentFileInfo(): tuple[file: string, line: int] =
  # В реальной реализации это должно получать информацию из стека вызовов
  # Для демонстрации используем заглушку
  result = (file: "main.nim", line: 1)

proc formatLogMessage(self: Logger, level: LogLevel, message: string): string =
  let timestamp = now().format("yyyy-MM-dd HH:mm:ss")
  var parts: seq[string] = @[]
  
  # Добавляем тип лога если включено
  if self.printType:
    let colorCode = case level
      of llInfo: self.getColorCode(self.infoColor)
      of llWarning: self.getColorCode(self.warningColor) 
      of llError: self.getColorCode(self.errorColor)
      of llSuccess: self.getColorCode(self.successColor)
    
    parts.add(fmt"{colorCode}[{level}]{self.getResetCode()}")
  
  # Добавляем информацию о файле если включено
  if self.currentFile:
    let fileInfo = getCurrentFileInfo()
    parts.add(fmt"")
  
  # Добавляем сообщение
  parts.add(message)
  
  result = parts.join(": ")
  
  # Добавляем в историю если включено
  if self.stringLog:
    let historyEntry = fmt"""[{timestamp}] {parts.join(": ")}"""
    self.logHistory.add(historyEntry)

proc dumpFile*(self: Logger, filePath: string)

proc log(self: Logger, level: LogLevel, message: string) =
  # Если логирование отключено или логгер не запущен, ничего не делаем
  when not defined(release):
    if not self.logging or not self.isStarted:
      return
  else:
    return # В релизе все логи отключены
  
  let formattedMessage = self.formatLogMessage(level, message)
  echo formattedMessage
  
  # Автоматический дамп при ошибке
  if level == llError and self.autoDumpFile.len > 0:
    self.dumpFile(self.autoDumpFile)

proc start*(self: Logger) =
  ## Запускает логгер
  self.isStarted = true
  if self.logging:
    self.log(llInfo, "Logger started")

proc stop*(self: Logger) =
  ## Останавливает логгер
  if self.logging and self.isStarted:
    self.log(llInfo, "Logger stopped")
  self.isStarted = false

proc info*(self: Logger, message: string) =
  ## Выводит информационное сообщение
  self.log(llInfo, message)

proc warning*(self: Logger, message: string) =
  ## Выводит предупреждение
  self.log(llWarning, message)

proc error*(self: Logger, message: string) =
  ## Выводит ошибку
  self.log(llError, message)

proc success*(self: Logger, message: string) =
  ## Выводит сообщение об успехе
  self.log(llSuccess, message)

proc dumpFile*(self: Logger, filePath: string) =
  ## Сохраняет все логи в файл
  if not self.stringLog or self.logHistory.len == 0:
    return
  
  try:
    # Создаем директорию если её нет
    let dir = parentDir(filePath)
    if dir.len > 0 and not dirExists(dir):
      createDir(dir)
    
    # Записываем логи в файл
    let content = self.logHistory.join("\n")
    writeFile(filePath, content)
    
    if self.logging and self.isStarted:
      self.log(llInfo, fmt"Logs dumped to {filePath}")
  except Exception as e:
    if self.logging and self.isStarted:
      self.log(llError, fmt"Failed to dump logs: {e.msg}")

proc clearHistory*(self: Logger) =
  ## Очищает историю логов
  self.logHistory = @[]

# Макросы для компиляционного отключения логов
template debugLog*(logger: Logger, message: string) =
  when not defined(release):
    logger.info(message)

template debugWarning*(logger: Logger, message: string) =
  when not defined(release):
    logger.warning(message)

template debugError*(logger: Logger, message: string) =
  when not defined(release):
    logger.error(message)

# Глобальный логгер для удобства
var globalLogger*: Logger

proc initGlobalLogger*(
  currentFile: bool = true,
  colors: bool = true,
  printType: bool = true,
  stringLog: bool = true,
  autoDumpFile: string = "./.dump/global.log",
  logging: bool = true,
  warningColor: string = "yellow",
  errorColor: string = "red",
  infoColor: string = "blue", 
  successColor: string = "green"
) =
  globalLogger = newLogger(
    currentFile, colors, printType, stringLog,
    autoDumpFile, logging, warningColor, errorColor,
    infoColor, successColor
  )

# Глобальные функции для удобства
proc logInfo*(message: string) =
  if globalLogger != nil:
    globalLogger.info(message)

proc logWarning*(message: string) =
  if globalLogger != nil:
    globalLogger.warning(message)

proc logError*(message: string) =
  if globalLogger != nil:
    globalLogger.error(message)

proc logSuccess*(message: string) =
  if globalLogger != nil:
    globalLogger.success(message)
