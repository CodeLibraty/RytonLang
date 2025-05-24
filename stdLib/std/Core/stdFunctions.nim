import std/[strutils, os, sequtils, random, sugar]
import stdTypes

# IO функции
proc print*(args: varargs[string, `$`]) =
  echo args.join(" ")

proc input*(prompt: string = ""): string =
  if prompt.len > 0:
    stdout.write(prompt)
  result = readLine(stdin)

# Конвертация типов
proc toString*(x: auto): string =
  $x

proc toInt*(s: string): Int =
  parseInt(s)

proc toFloat*(s: string): Float =
  parseFloat(s)

proc toBool*(s: string): Bool =
  parseBool(s)

proc isType*[T](value: auto, typ: typedesc[T]): bool =
  value is T

# Работа с последовательностями
proc len*[T](x: Array[T]): Int =
  x.len

proc map*[T,U](arr: Array[T], fn: proc(x: T): U): Array[U] =
  arr.map(fn)

proc filter*[T](arr: Array[T], fn: proc(x: T): bool): Array[T] =
  arr.filter(fn)

proc reduce*[T,U](arr: Array[T], fn: proc(acc: U, x: T): U, initial: U): U =
  arr.foldl(fn(a, b), initial)

# Математические функции
proc abs*(x: Int): Int =
  abs(x)

proc abs*(x: Float): Float =
  abs(x)

proc min*[T](x, y: T): T =
  min(x, y)

proc max*[T](x, y: T): T =
  max(x, y)

proc round*(x: Float): Int =
  round(x).int

proc floor*(x: Float): Int =
  floor(x).int

proc ceil*(x: Float): Int =
  ceil(x).int

# Строковые функции
proc split*(s: string, sep: string = " "): Array[string] =
  s.split(sep)

proc join*(arr: Array[string], sep: string = ""): string =
  arr.join(sep)

proc replace*(s: string, old: string, new: string): string =
  s.replace(old, new)

proc trim*(s: string): string =
  s.strip()

proc format*(fmt: string, args: varargs[string, `$`]): string =
  fmt % args

# Системные функции
proc exit*(code: Int = 0) =
  quit(code)

proc pause*(ms: Int) =
  sleep(ms)

proc getEnv*(key: string, default: string = ""): string =
  getEnv(key, default)

# Работа со списками
proc zip*[T,U](a: Array[T], b: Array[U]): Array[tuple[first: T, second: U]] =
  zip(a, b).toSeq

proc enumerate*[T](arr: Array[T]): Array[tuple[i: Int, val: T]] =
  toSeq(arr.pairs)

# Удобные функции
proc all*[T](arr: Array[T], pred: proc(x: T): bool): bool =
  arr.all(pred)

proc sum*[T](arr: Array[T]): T =
  arr.foldl(a + b)

proc sorted*[T](arr: Array[T]): Array[T] =
  arr.sorted()

proc reversed*[T](arr: Array[T]): Array[T] =
  arr.reversed()

# Работа со множествами
proc unique*[T](arr: Array[T]): Array[T] =
  arr.deduplicate()

proc intersection*[T](a, b: Set[T]): Set[T] =
  a * b

proc union*[T](a, b: Set[T]): Set[T] =
  a + b

# Дополнительные строковые функции
proc startsWith*(s, prefix: string): bool =
  s.startsWith(prefix)

proc endsWith*(s, suffix: string): bool =
  s.endsWith(suffix)

proc isDigit*(s: string): bool =
  s.allCharsInSet(Digits)

proc isAlpha*(s: string): bool =
  s.allCharsInSet(Letters)

# Математика
proc randInt*(a, b: Int): Int =
  rand(a..b)

proc randFloat*(): Float =
  rand(1.0)

proc randChoice*[T](arr: Array[T]): T =
  arr[rand(arr.high)]

# Быстрые операции с массивами
proc quickSum*(startMas, endMas: Int): Int =
  # Сумма последовательности без создания массива
  (endMas - startMas + 1) * (startMas + endMas) div 2

proc generateSequence*(pattern: string, count: Int): Array[string] =
  # Быстро генерирует последовательность по шаблону
  # "test_{}" -> ["test_0", "test_1", ...]
  collect:
    for i in 0..<count:
      pattern.format($i)

proc batch*[T](arr: Array[T], size: Int): Array[Array[T]] =
  # Разбивает массив на группы заданного размера
  arr.distribute(size)

proc quickStats*(nums: Array[Float]): tuple[min, max, avg, sum: Float] =
  # Считает все базовые статистики за один проход
  var min = nums[0]
  var max = nums[0]
  var sum = 0.0
  for n in nums:
    if n < min: min = n
    if n > max: max = n
    sum += n
  (min, max, sum/nums.len.float, sum)

# Быстрые операции со строками
proc quickParse*(s: string): tuple[ints: Array[Int], floats: Array[Float], words: Array[string]] =
  # Парсит все числа и слова за один проход
  var ints: Array[Int]
  var floats: Array[Float] 
  var words: Array[string]
  
  for part in s.split():
    try:
      ints.add(parseInt(part))
    except:
      try:
        floats.add(parseFloat(part))
      except:
        words.add(part)
  
  (ints, floats, words)

# Быстрые преобразования
proc quickConvert*[T,U](arr: Array[T], convert: proc(x: T): U): Array[U] =
  # Конвертирует массив за один проход без промежуточных операций
  arr.mapIt(convert(it))

# Матричные операции
proc transpose*(matrix: Array[Array[Float]]): Array[Array[Float]] =
  let rows = matrix.len
  let cols = matrix[0].len
  result = newSeqWith(cols, newSeq[Float](rows))
  for i in 0..<rows:
    for j in 0..<cols:
      result[j][i] = matrix[i][j]

proc normalize*(matrix: Array[Array[Float]]): Array[Array[Float]] =
  let rows = matrix.len
  let cols = matrix[0].len
  result = matrix
  var maxVal = matrix[0][0]
  
  # Find max value
  for row in matrix:
    for val in row:
      if val > maxVal: maxVal = val
      
  # Normalize by max value
  for i in 0..<rows:
    for j in 0..<cols:
      result[i][j] = matrix[i][j] / maxVal

proc invert*(matrix: Array[Array[Float]]): Array[Array[Float]] =
  let rows = matrix.len
  let cols = matrix[0].len
  result = matrix
  for i in 0..<rows:
    for j in 0..<cols:
      result[i][j] = 1.0 / matrix[i][j]
