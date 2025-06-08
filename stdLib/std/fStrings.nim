import macros, strutils, terminal

# Функция для обработки стилевых тегов
proc processStyleTags*(text: string): string =
  var i = 0
  var styleStack: seq[string] = @[]
  
  while i < text.len:
    if i < text.len - 1 and text[i] == '<':
      # Начало тега
      var isClosing = false
      i += 1 # Пропускаем <
      
      if i < text.len and text[i] == '/':
        isClosing = true
        i += 1 # Пропускаем /
      
      var tag = ""
      while i < text.len and text[i] != '>':
        tag.add text[i]
        i += 1
      
      if i < text.len: i += 1 # Пропускаем >
      
      if isClosing:
        # Закрывающий тег - восстанавливаем предыдущий стиль
        if styleStack.len > 0:
          discard styleStack.pop()
          result.add "\e[0m"
          # Восстанавливаем все активные стили
          for style in styleStack:
            let styles = style.split('|')
            for s in styles:
              case s.toLowerAscii()
              of "red": result.add $ansiForegroundColorCode(fgRed)
              of "green": result.add $ansiForegroundColorCode(fgGreen)
              of "blue": result.add $ansiForegroundColorCode(fgBlue)
              of "yellow": result.add $ansiForegroundColorCode(fgYellow)
              of "magenta": result.add $ansiForegroundColorCode(fgMagenta)
              of "cyan": result.add $ansiForegroundColorCode(fgCyan)
              of "white": result.add $ansiForegroundColorCode(fgWhite)
              of "black": result.add $ansiForegroundColorCode(fgBlack)
              of "bold": result.add $ansiStyleCode(styleBright)
              of "italic": result.add $ansiStyleCode(styleItalic)
              of "underline": result.add $ansiStyleCode(styleUnderscore)
              of "bg-red": result.add "\e[41m"
              of "bg-green": result.add "\e[42m"
              of "bg-blue": result.add "\e[44m"
              of "bg-yellow": result.add "\e[43m"
              of "bg-magenta": result.add "\e[45m"
              of "bg-cyan": result.add "\e[46m"
              of "bg-white": result.add "\e[47m"
              of "bg-black": result.add "\e[40m"
              else: discard
      else:
        # Открывающий тег - применяем стиль
        styleStack.add tag
        let styles = tag.split('|')
        for s in styles:
          case s.toLowerAscii()
          of "red": result.add $ansiForegroundColorCode(fgRed)
          of "green": result.add $ansiForegroundColorCode(fgGreen)
          of "blue": result.add $ansiForegroundColorCode(fgBlue)
          of "yellow": result.add $ansiForegroundColorCode(fgYellow)
          of "magenta": result.add $ansiForegroundColorCode(fgMagenta)
          of "cyan": result.add $ansiForegroundColorCode(fgCyan)
          of "white": result.add $ansiForegroundColorCode(fgWhite)
          of "black": result.add $ansiForegroundColorCode(fgBlack)
          of "bold": result.add $ansiStyleCode(styleBright)
          of "italic": result.add $ansiStyleCode(styleItalic)
          of "underline": result.add $ansiStyleCode(styleUnderscore)
          of "bg-red": result.add "\e[41m"
          of "bg-green": result.add "\e[42m"
          of "bg-blue": result.add "\e[44m"
          of "bg-yellow": result.add "\e[43m"
          of "bg-magenta": result.add "\e[45m"
          of "bg-cyan": result.add "\e[46m"
          of "bg-white": result.add "\e[47m"
          of "bg-black": result.add "\e[40m"
          else: discard
    else:
      # Обычный символ
      result.add text[i]
      i += 1
  
  # Сбрасываем все стили в конце
  if styleStack.len > 0:
    result.add $resetStyle
  
  return result # Макрос для f-строк с поддержкой тегов и интерполяции

macro f*(text: static string): string =
  var resultStr = ""
  var i = 0
  
  while i < text.len:
    if i < text.len - 1 and text[i] == '{':
      # Начало выражения
      i += 1 # Пропускаем {
      var expr = ""
      
      # Собираем выражение до закрывающей скобки
      while i < text.len and text[i] != '}':
        expr.add text[i]
        i += 1
      
      # Пропускаем закрывающую скобку
      if i < text.len: i += 1
      
      # Добавляем выражение в результат
      resultStr.add "\" & $(" & expr & ") & \""
    else:
      # Обычный символ или тег
      if text[i] == '"': resultStr.add "\\\""
      elif text[i] == '\\': resultStr.add "\\\\"
      else: resultStr.add text[i]
      i += 1
  
  # Обрабатываем теги в результате
  let processedStr = "processStyleTags(\"" & resultStr & "\")"
  result = parseExpr(processedStr)

# Пример использования
when isMainModule:
  let name = "Максим"
  let value = 42
  
  echo f"Привет, <red>{name}</red>! Значение: <green|bold>{value}</green|bold>"
  echo f"<blue|underline|bg-green>Подчеркнутый синий</blue|underline|bg-green> и <yellow|italic>курсивный желтый</yellow|italic>"
  echo f"<red|bold|underline>Комбинированные стили</red|bold|underline>"
