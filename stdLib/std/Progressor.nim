import std/[tables, terminal, os, math, strutils, strformat, random, times]

# МОДУЛЬ НЕ ТЕСТИРОВАН!!

type
  SpinnerStyle* = enum
    ssClassic = "classic"
    ssDots = "dots"
    ssLine = "line"
    ssCircle = "circle"
    ssArrow = "arrow"
    ssBounce = "bounce"
    ssWave = "wave"
    ssClock = "clock"
    ssEarth = "earth"
    ssMoon = "moon"

  ProgressBarStyle* = enum
    pbsClassic = "classic"
    pbsBlocks = "blocks"
    pbsArrows = "arrows"
    pbsCircles = "circles"
    pbsGradient = "gradient"
    pbsNeon = "neon"

  SpinnerConfig* = object
    style*: SpinnerStyle
    frames*: seq[string]
    interval*: int  # миллисекунды
    color*: ForegroundColor
    prefix*: string
    suffix*: string

  ProgressBarConfig* = object
    style*: ProgressBarStyle
    width*: int
    fillChar*: char
    emptyChar*: char
    leftBracket*: string
    rightBracket*: string
    color*: ForegroundColor
    showPercent*: bool
    showTime*: bool
    showSpeed*: bool

  Spinner* = ref object
    config: SpinnerConfig
    currentFrame: int
    isRunning: bool
    startTime: float
    message: string

  ProgressBar* = ref object
    config: ProgressBarConfig
    total: int
    current: int
    startTime: float
    lastUpdate: float
    isRunning: bool

# Предустановленные стили спиннеров
const SpinnerFrames = {
  ssClassic: @["|", "/", "-", "\\"],
  ssDots: @["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"],
  ssLine: @["─", "\\", "|", "/"],
  ssCircle: @["◐", "◓", "◑", "◒"],
  ssArrow: @["←", "↖", "↑", "↗", "→", "↘", "↓", "↙"],
  ssBounce: @["⠁", "⠂", "⠄", "⠂"],
  ssWave: @["▁", "▃", "▄", "▅", "▆", "▇", "█", "▇", "▆", "▅", "▄", "▃"],
  ssClock: @["🕐", "🕑", "🕒", "🕓", "🕔", "🕕", "🕖", "🕗", "🕘", "🕙", "🕚", "🕛"],
  ssEarth: @["🌍", "🌎", "🌏"],
  ssMoon: @["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"]
}.toTable

proc toChar(s: string): char = 
  if s.len > 0: s[0] else: ' '

# Конструкторы конфигураций
proc newSpinnerConfig*(style: SpinnerStyle = ssClassic, 
                      color: ForegroundColor = fgWhite,
                      interval: int = 100,
                      prefix: string = "",
                      suffix: string = ""): SpinnerConfig =
  result = SpinnerConfig(
    style: style,
    frames: SpinnerFrames[style],
    interval: interval,
    color: color,
    prefix: prefix,
    suffix: suffix
  )

proc newProgressBarConfig*(style: ProgressBarStyle = pbsClassic,
                          width: int = 40,
                          color: ForegroundColor = fgGreen,
                          showPercent: bool = true,
                          showTime: bool = true,
                          showSpeed: bool = false): ProgressBarConfig =
  result = ProgressBarConfig(
    style: style,
    width: width,
    color: color,
    showPercent: showPercent,
    showTime: showTime,
    showSpeed: showSpeed
  )
  
  # Настройка символов в зависимости от стиля
  case style:
  of pbsClassic:
    result.fillChar = "█".toChar()
    result.emptyChar = "░".toChar()
    result.leftBracket = "["
    result.rightBracket = "]"
  of pbsBlocks:
    result.fillChar = "■".toChar()
    result.emptyChar = "□".toChar()
    result.leftBracket = "▐"
    result.rightBracket = "▌"
  of pbsArrows:
    result.fillChar = "▶".toChar()
    result.emptyChar = "▷".toChar()
    result.leftBracket = "◀"
    result.rightBracket = "▶"
  of pbsCircles:
    result.fillChar = "●".toChar()
    result.emptyChar = "○".toChar()
    result.leftBracket = "("
    result.rightBracket = ")"
  of pbsGradient:
    result.fillChar = "█".toChar()
    result.emptyChar = " ".toChar()
    result.leftBracket = "▐"
    result.rightBracket = "▌"
  of pbsNeon:
    result.fillChar = "▓".toChar()
    result.emptyChar = "▒".toChar()
    result.leftBracket = "▐"
    result.rightBracket = "▌"

# Спиннер
proc newSpinner*(config: SpinnerConfig = newSpinnerConfig()): Spinner =
  result = Spinner(
    config: config,
    currentFrame: 0,
    isRunning: false,
    startTime: 0.0,
    message: ""
  )

proc start*(spinner: Spinner, message: string = "Loading...") =
  spinner.message = message
  spinner.isRunning = true
  spinner.startTime = epochTime()
  spinner.currentFrame = 0
  hideCursor()

proc stop*(spinner: Spinner, finalMessage: string = "") =
  spinner.isRunning = false
  stdout.write("\r" & " ".repeat(80) & "\r")  # Очищаем строку
  if finalMessage.len > 0:
    echo finalMessage
  showCursor()

proc update*(spinner: Spinner, newMessage: string = "") =
  if not spinner.isRunning:
    return
    
  if newMessage.len > 0:
    spinner.message = newMessage
  
  let frame = spinner.config.frames[spinner.currentFrame]
  let elapsed = epochTime() - spinner.startTime
  
  var output = ""
  if spinner.config.prefix.len > 0:
    output.add(spinner.config.prefix & " ")
  
  setForegroundColor(spinner.config.color)
  output.add(frame)
  resetAttributes()
  
  output.add(" " & spinner.message)
  
  if spinner.config.suffix.len > 0:
    output.add(" " & spinner.config.suffix)
  
  stdout.write("\r" & output)
  stdout.flushFile()
  
  spinner.currentFrame = (spinner.currentFrame + 1) mod spinner.config.frames.len

proc spin*(spinner: Spinner, message: string = "Loading...", duration: int = 0) =
  spinner.start(message)
  
  if duration > 0:
    let endTime = epochTime() + duration.float
    while epochTime() < endTime and spinner.isRunning:
      spinner.update()
      sleep(spinner.config.interval)
  else:
    while spinner.isRunning:
      spinner.update()
      sleep(spinner.config.interval)

# Прогресс-бар
proc newProgressBar*(total: int, config: ProgressBarConfig = newProgressBarConfig()): ProgressBar =
  result = ProgressBar(
    config: config,
    total: total,
    current: 0,
    startTime: epochTime(),
    lastUpdate: 0.0,
    isRunning: false
  )

proc start*(pb: ProgressBar) =
  pb.isRunning = true
  pb.startTime = epochTime()
  pb.current = 0
  hideCursor()

proc update*(pb: ProgressBar, current: int = -1, message: string = "") =
  if not pb.isRunning:
    return
    
  if current >= 0:
    pb.current = min(current, pb.total)
  
  let now = epochTime()
  pb.lastUpdate = now
  
  let percentage = if pb.total > 0: (pb.current.float / pb.total.float) else: 0.0
  let filled = int(percentage * pb.config.width.float)
  let empty = pb.config.width - filled
  
  var bar = pb.config.leftBracket
  
  # Специальная обработка для градиентного стиля
  if pb.config.style == pbsGradient:
    setForegroundColor(pb.config.color)
    for i in 0..<filled:
      let intensity = i.float / pb.config.width.float
      if intensity < 0.3:
        bar.add("░")
      elif intensity < 0.6:
        bar.add("▒")
      else:
        bar.add("▓")
    resetAttributes()
    bar.add(" ".repeat(empty))
  else:
    setForegroundColor(pb.config.color)
    bar.add(pb.config.fillChar.repeat(filled))
    resetAttributes()
    bar.add(pb.config.emptyChar.repeat(empty))
  
  bar.add(pb.config.rightBracket)
  
  var output = "\r" & bar
  
  if pb.config.showPercent:
    output.add(fmt" {percentage * 100:5.1f}%")
  
  if pb.config.showTime:
    let elapsed = now - pb.startTime
    let eta = if pb.current > 0: 
      elapsed * (pb.total.float - pb.current.float) / pb.current.float 
    else: 0.0
    output.add(fmt" ETA: {eta:4.1f}s")
  
  if pb.config.showSpeed and pb.current > 0:
    let speed = pb.current.float / (now - pb.startTime)
    output.add(fmt" {speed:5.1f} it/s")
  
  if message.len > 0:
    output.add(" " & message)
  
  stdout.write(output)
  stdout.flushFile()

proc finish*(pb: ProgressBar, message: string = "Complete!") =
  pb.isRunning = false
  pb.current = pb.total
  pb.update(pb.current)
  echo "\n" & message
  showCursor()

proc increment*(pb: ProgressBar, step: int = 1, message: string = "") =
  pb.update(pb.current + step, message)

# Готовые функции для быстрого использования
proc quickSpinner*(message: string = "Loading...", style: SpinnerStyle = ssClassic, duration: int = 3000) =
  let config = newSpinnerConfig(style, fgCyan, 100, "🔄", "")
  let spinner = newSpinner(config)
  spinner.start(message)
  sleep(duration)
  spinner.stop("✅ Done!")

proc quickProgress*(total: int, style: ProgressBarStyle = pbsClassic, stepDelay: int = 100) =
  let config = newProgressBarConfig(style, 50, fgGreen, true, true, true)
  let pb = newProgressBar(total, config)
  pb.start()
  
  for i in 0..total:
    pb.update(i, fmt"Processing item {i}/{total}")
    sleep(stepDelay)
  
  pb.finish("✅ Processing complete!")

# Многострочный прогресс (для нескольких задач)
type
  MultiProgress* = ref object
    bars: seq[ProgressBar]
    labels: seq[string]
    isRunning: bool

proc newMultiProgress*(): MultiProgress =
  result = MultiProgress(
    bars: @[],
    labels: @[],
    isRunning: false
  )

proc addTask*(mp: MultiProgress, label: string, total: int, config: ProgressBarConfig = newProgressBarConfig()): int =
  mp.labels.add(label)
  mp.bars.add(newProgressBar(total, config))
  return mp.bars.len - 1

proc start*(mp: MultiProgress) =
  mp.isRunning = true
  hideCursor()
  for bar in mp.bars:
    bar.start()

proc updateTask*(mp: MultiProgress, taskId: int, current: int, message: string = "") =
  if taskId >= 0 and taskId < mp.bars.len:
    # Перемещаемся к нужной строке
    stdout.write(fmt"\e[{mp.bars.len - taskId}A")
    stdout.write("\r" & " ".repeat(100) & "\r")
    stdout.write(mp.labels[taskId] & ": ")
    mp.bars[taskId].update(current, message)
    # Возвращаемся вниз
    stdout.write(fmt"\e[{mp.bars.len - taskId}B")

proc finish*(mp: MultiProgress) =
  mp.isRunning = false
  for i, bar in mp.bars:
    bar.finish("")
  showCursor()

# Анимированные эффекты
proc typewriterEffect*(text: string, delay: int = 50, color: ForegroundColor = fgWhite) =
  setForegroundColor(color)
  for ch in text:
    stdout.write(ch)
    stdout.flushFile()
    sleep(delay)
  resetAttributes()
  echo ""

proc matrixEffect*(lines: int = 10, duration: int = 3000) =
  let chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
  let width = terminalWidth()
  let endTime = epochTime() + duration.float / 1000.0
  
  hideCursor()
  while epochTime() < endTime:
    for line in 0..<lines:
      var output = ""
      for col in 0..<width:
        if rand(10) < 3:  # 30% шанс символа
          setForegroundColor(fgGreen)
          output.add(chars[rand(chars.len)])
        else:
          output.add(" ")
      resetAttributes()
      echo output
    sleep(100)
    # Очищаем экран
    stdout.write("\e[2J\e[H")
  showCursor()

# Экспорт основных функций
export SpinnerStyle, ProgressBarStyle, SpinnerConfig, ProgressBarConfig
export Spinner, ProgressBar, MultiProgress
export newSpinner, newProgressBar, newMultiProgress
export quickSpinner, quickProgress, typewriterEffect, matrixEffect
