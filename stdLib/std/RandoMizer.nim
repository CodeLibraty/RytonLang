## RandoMizer - Advanced Random Generation Module for RytonLang and NimLang
## Provides comprehensive random number generation, distributions, and utilities

import std/[random, times, math, strutils, tables]

# Экспортируем основные типы
export random.Rand

type
  # Типы распределений
  Distribution* = enum
    distUniform,     # Равномерное
    distNormal,      # Нормальное (Гауссово)
    distExponential, # Экспоненциальное
    distPoisson,     # Пуассона
    distBinomial,    # Биномиальное
    distGamma,       # Гамма
    distBeta,        # Бета
    distWeibull      # Вейбулла

  # Генератор случайных чисел
  RandoMizer* = ref object
    rng*: Rand
    seed*: int64
    distribution*: Distribution
    params*: Table[string, float]

  # Результат генерации последовательности
  RandomSequence*[T] = object
    values*: seq[T]
    stats*: RandomStats

  # Статистика по сгенерированным числам
  RandomStats* = object
    count*: int
    min*: float
    max*: float
    mean*: float
    variance*: float
    stdDev*: float

# ============================================================================
# ОСНОВНЫЕ ФУНКЦИИ СОЗДАНИЯ И ИНИЦИАЛИЗАЦИИ
# ============================================================================

proc newRandoMizer*(seed: int64 = 0): RandoMizer =
  ## Создает новый генератор случайных чисел
  result = RandoMizer(
    rng: initRand(if seed == 0: getTime().toUnix else: seed),
    seed: if seed == 0: getTime().toUnix else: seed,
    distribution: distUniform,
    params: initTable[string, float]()
  )

proc setSeed*(rm: RandoMizer, seed: int64) =
  ## Устанавливает новое зерно генератора
  rm.seed = seed
  rm.rng = initRand(seed)

proc randomSeed*(): int64 =
  ## Генерирует случайное зерно на основе времени
  result = getTime().toUnix + getTime().nanosecond

# ============================================================================
# БАЗОВЫЕ ГЕНЕРАТОРЫ
# ============================================================================

proc nextInt*(rm: RandoMizer): int =
  ## Генерирует случайное целое число
  result = rm.rng.rand(int.high)

proc nextInt*(rm: RandoMizer, max: int): int =
  ## Генерирует случайное целое число от 0 до max-1
  result = rm.rng.rand(max - 1)

proc nextInt*(rm: RandoMizer, min, max: int): int =
  ## Генерирует случайное целое число в диапазоне [min, max]
  result = rm.rng.rand(max - min) + min

proc nextFloat*(rm: RandoMizer): float =
  ## Генерирует случайное число с плавающей точкой [0.0, 1.0)
  result = rm.rng.rand(1.0)

proc nextFloat*(rm: RandoMizer, max: float): float =
  ## Генерирует случайное число с плавающей точкой [0.0, max)
  result = rm.rng.rand(max)

proc nextFloat*(rm: RandoMizer, min, max: float): float =
  ## Генерирует случайное число с плавающей точкой [min, max)
  result = rm.rng.rand(max - min) + min

proc nextBool*(rm: RandoMizer): bool =
  ## Генерирует случайное булево значение
  result = rm.rng.rand(1) == 1

proc nextBool*(rm: RandoMizer, probability: float): bool =
  ## Генерирует булево значение с заданной вероятностью true
  result = rm.nextFloat() < probability

# ============================================================================
# РАСПРЕДЕЛЕНИЯ
# ============================================================================

proc setDistribution*(rm: RandoMizer, dist: Distribution, params: varargs[(string, float)]) =
  ## Устанавливает тип распределения и его параметры
  rm.distribution = dist
  rm.params.clear()
  for (key, value) in params:
    rm.params[key] = value

proc nextNormal*(rm: RandoMizer, mean: float = 0.0, stdDev: float = 1.0): float =
  ## Генерирует число из нормального распределения (метод Бокса-Мюллера)
  var u1, u2: float
  while true:
    u1 = rm.nextFloat()
    if u1 > 0.0:
      break
  u2 = rm.nextFloat()
  
  let z0 = sqrt(-2.0 * ln(u1)) * cos(2.0 * PI * u2)
  result = z0 * stdDev + mean

proc nextExponential*(rm: RandoMizer, lambda: float = 1.0): float =
  ## Генерирует число из экспоненциального распределения
  let u = rm.nextFloat()
  result = -ln(1.0 - u) / lambda

proc nextPoisson*(rm: RandoMizer, lambda: float): int =
  ## Генерирует число из распределения Пуассона
  if lambda < 30.0:
    # Алгоритм Кнута для малых lambda
    let L = exp(-lambda)
    var k = 0
    var p = 1.0
    while true:
      inc k
      p *= rm.nextFloat()
      if p <= L:
        break
    result = k - 1
  else:
    # Аппроксимация нормальным распределением для больших lambda
    result = max(0, int(rm.nextNormal(lambda, sqrt(lambda)) + 0.5))

proc nextGamma*(rm: RandoMizer, shape: float, scale: float = 1.0): float =
  ## Генерирует число из гамма-распределения
  if shape < 1.0:
    # Алгоритм Аренса-Дитера
    let c = (1.0 / shape)
    let d = ((1.0 - shape) * pow(shape, shape / (1.0 - shape)))
    
    while true:
      let u = rm.nextFloat()
      let v = rm.nextFloat()
      let w = u * d
      
      if u <= (1.0 - shape):
        let x = pow(w, c)
        if v <= exp(-x):
          return x * scale
      else:
        let x = -ln(c * (1.0 - u))
        if v <= pow(x, shape - 1.0):
          return x * scale
  else:
    # Алгоритм Марсальи-Цанга
    let d = shape - 1.0/3.0
    let c = 1.0 / sqrt(9.0 * d)
    
    while true:
      var x = rm.nextNormal()
      let v = 1.0 + c * x
      if v > 0:
        let v3 = v * v * v
        let u = rm.nextFloat()
        if u < 1.0 - 0.0331 * (x * x) * (x * x):
          return d * v3 * scale
        if ln(u) < 0.5 * x * x + d * (1.0 - v3 + ln(v3)):
          return d * v3 * scale

proc nextBeta*(rm: RandoMizer, alpha: float, beta: float): float =
  ## Генерирует число из бета-распределения
  let x = rm.nextGamma(alpha)
  let y = rm.nextGamma(beta)
  result = x / (x + y)

proc nextWeibull*(rm: RandoMizer, shape: float, scale: float = 1.0): float =
  ## Генерирует число из распределения Вейбулла
  let u = rm.nextFloat()
  result = scale * pow(-ln(1.0 - u), 1.0 / shape)

proc nextFromDistribution*(rm: RandoMizer): float =
  ## Генерирует число согласно установленному распределению
  case rm.distribution
  of distUniform:
    result = rm.nextFloat()
  of distNormal:
    let mean = rm.params.getOrDefault("mean", 0.0)
    let stdDev = rm.params.getOrDefault("stdDev", 1.0)
    result = rm.nextNormal(mean, stdDev)
  of distExponential:
    let lambda = rm.params.getOrDefault("lambda", 1.0)
    result = rm.nextExponential(lambda)
  of distPoisson:
    let lambda = rm.params.getOrDefault("lambda", 1.0)
    result = float(rm.nextPoisson(lambda))
  of distGamma:
    let shape = rm.params.getOrDefault("shape", 1.0)
    let scale = rm.params.getOrDefault("scale", 1.0)
    result = rm.nextGamma(shape, scale)
  of distBeta:
    let alpha = rm.params.getOrDefault("alpha", 1.0)
    let beta = rm.params.getOrDefault("beta", 1.0)
    result = rm.nextBeta(alpha, beta)
  of distWeibull:
    let shape = rm.params.getOrDefault("shape", 1.0)
    let scale = rm.params.getOrDefault("scale", 1.0)
    result = rm.nextWeibull(shape, scale)
  else:
    result = rm.nextFloat()

# ============================================================================
# ГЕНЕРАЦИЯ ПОСЛЕДОВАТЕЛЬНОСТЕЙ
# ============================================================================

proc generateInts*(rm: RandoMizer, count: int, min: int = 0, max: int = 100): RandomSequence[int] =
  ## Генерирует последовательность случайных целых чисел
  result.values = newSeq[int](count)
  for i in 0..<count:
    result.values[i] = rm.nextInt(min, max)
  
  # Вычисляем статистику
  result.stats = RandomStats(
    count: count,
    min: float(result.values.min),
    max: float(result.values.max),
    mean: float(result.values.sum) / float(count)
  )
  
  let meanVal = result.stats.mean
  var variance = 0.0
  for val in result.values:
    variance += pow(float(val) - meanVal, 2.0)
  variance /= float(count)
  
  result.stats.variance = variance
  result.stats.stdDev = sqrt(variance)

proc generateFloats*(rm: RandoMizer, count: int, min: float = 0.0, max: float = 1.0): RandomSequence[float] =
  ## Генерирует последовательность случайных чисел с плавающей точкой
  result.values = newSeq[float](count)
  for i in 0..<count:
    result.values[i] = rm.nextFloat(min, max)
  
  # Вычисляем статистику
  result.stats = RandomStats(
    count: count,
    min: result.values.min,
    max: result.values.max,
    mean: result.values.sum / float(count)
  )
  
  let meanVal = result.stats.mean
  var variance = 0.0
  for val in result.values:
    variance += pow(val - meanVal, 2.0)
  variance /= float(count)
  
  result.stats.variance = variance
  result.stats.stdDev = sqrt(variance)

proc generateFromDistribution*(rm: RandoMizer, count: int): RandomSequence[float] =
  ## Генерирует последовательность чисел согласно установленному распределению
  result.values = newSeq[float](count)
  for i in 0..<count:
    result.values[i] = rm.nextFromDistribution()
  
  # Вычисляем статистику
  result.stats = RandomStats(
    count: count,
    min: result.values.min,
    max: result.values.max,
    mean: result.values.sum / float(count)
  )
  
  let meanVal = result.stats.mean
  var variance = 0.0
  for val in result.values:
    variance += pow(val - meanVal, 2.0)
  variance /= float(count)
  
  result.stats.variance = variance
  result.stats.stdDev = sqrt(variance)

# ============================================================================
# РАБОТА С КОЛЛЕКЦИЯМИ
# ============================================================================

proc shuffle*[T](rm: RandoMizer, arr: var seq[T]) =
  ## Перемешивает массив (алгоритм Фишера-Йетса)
  for i in countdown(arr.len - 1, 1):
    let j = rm.nextInt(i + 1)
    swap(arr[i], arr[j])

proc shuffled*[T](rm: RandoMizer, arr: seq[T]): seq[T] =
  ## Возвращает перемешанную копию массива
  result = arr
  rm.shuffle(result)

proc choice*[T](rm: RandoMizer, arr: seq[T]): T =
  ## Выбирает случайный элемент из массива
  if arr.len == 0:
    raise newException(IndexDefect, "Cannot choose from empty sequence")
  result = arr[rm.nextInt(arr.len)]

proc choices*[T](rm: RandoMizer, arr: seq[T], count: int, replace: bool = true): seq[T] =
  ## Выбирает несколько случайных элементов
  result = newSeq[T](count)
  if replace:
    for i in 0..<count:
      result[i] = rm.choice(arr)
  else:
    if count > arr.len:
      raise newException(ValueError, "Cannot choose more elements than available without replacement")
    var available = arr
    for i in 0..<count:
      let idx = rm.nextInt(available.len)
      result[i] = available[idx]
      available.del(idx)

proc weightedChoice*[T](rm: RandoMizer, items: seq[T], weights: seq[float]): T =
  ## Выбирает элемент с учетом весов
  if items.len != weights.len:
    raise newException(ValueError, "Items and weights must have the same length")
  
  let totalWeight = weights.sum
  let randomWeight = rm.nextFloat(totalWeight)
  
  var currentWeight = 0.0
  for i, weight in weights:
    currentWeight += weight
    if randomWeight <= currentWeight:
      return items[i]
  
  # Fallback (не должно происходить)
  return items[^1]

# ============================================================================
# ГЕНЕРАЦИЯ СТРОК И СИМВОЛОВ
# ============================================================================

const
  LOWERCASE_LETTERS*  = "abcdefghijklmnopqrstuvwxyz"
  UPPERCASE_LETTERS*  = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  DIGITS*             = "0123456789"
  PUNCTUATION*        = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
  ALPHANUMERIC*       = LOWERCASE_LETTERS & UPPERCASE_LETTERS & DIGITS
  PRINTABLE*          = ALPHANUMERIC & PUNCTUATION & " "

proc nextChar*(rm: RandoMizer, charset: string = ALPHANUMERIC): char =
  ## Генерирует случайный символ из заданного набора
  result = charset[rm.nextInt(charset.len)]

proc nextString*(rm: RandoMizer, length: int, charset: string = ALPHANUMERIC): string =
  ## Генерирует случайную строку заданной длины
  result = newString(length)
  for i in 0..<length:
    result[i] = rm.nextChar(charset)

proc nextString*(rm: RandoMizer, minLength, maxLength: int, charset: string = ALPHANUMERIC): string =
  ## Генерирует случайную строку случайной длины в диапазоне
  let length = rm.nextInt(minLength, maxLength + 1)
  result = rm.nextString(length, charset)

proc nextPassword*(rm: RandoMizer, length: int = 12, includeSymbols: bool = true): string =
  ## Генерирует случайный пароль
  var charset = ALPHANUMERIC
  if includeSymbols:
    charset.add("!@#$%^&*()_+-=[]{}|;:,.<>?")
  
  result = rm.nextString(length, charset)
  
  # Убеждаемся, что пароль содержит хотя бы одну цифру, букву и символ
  if length >= 3:
    result[0] = rm.nextChar(LOWERCASE_LETTERS)
    result[1] = rm.nextChar(DIGITS)
    if includeSymbols and length > 2:
      result[2] = rm.nextChar("!@#$%^&*")

proc nextEmail*(rm: RandoMizer): string =
  ## Генерирует случайный email адрес
  let domains = @["gmail.com", "yahoo.com", "hotmail.com", "outlook.com", "yandex.ru"]
  let username = rm.nextString(rm.nextInt(5, 12), LOWERCASE_LETTERS & DIGITS)
  let domain = rm.choice(domains)
  result = username & "@" & domain

proc nextName*(rm: RandoMizer): string =
  ## Генерирует случайное имя
  let firstNames = @[
    "Alexander", "Anna", "Boris", "Catherine", "Dmitry", "Elena", "Fyodor", "Galina",
    "Igor", "Julia", "Konstantin", "Larisa", "Mikhail", "Natasha", "Oleg", "Polina",
    "Roman", "Svetlana", "Timur", "Ulyana", "Viktor", "Yana", "Zakhar"
  ]
  result = rm.choice(firstNames)

# ============================================================================
# ГЕНЕРАЦИЯ ДАННЫХ
# ============================================================================

proc nextColor*(rm: RandoMizer): string =
  ## Генерирует случайный цвет в формате HEX
  result = "#"
  for i in 0..<6:
    result.add(rm.nextChar("0123456789ABCDEF"))

proc nextRGB*(rm: RandoMizer): tuple[r, g, b: int] =
  ## Генерирует случайный цвет в формате RGB
  result = (
    r: rm.nextInt(256),
    g: rm.nextInt(256),
    b: rm.nextInt(256)
  )

proc nextDate*(rm: RandoMizer, startYear: int = 1970, endYear: int = 2030): tuple[year, month, day: int] =
  ## Генерирует случайную дату
  let yearVal = rm.nextInt(startYear, endYear + 1)
  let monthVal = rm.nextInt(1, 13)
  let daysInMonth = case monthVal
    of 2: 
      if yearVal mod 4 == 0 and (yearVal mod 100 != 0 or yearVal mod 400 == 0): 
        29 
      else: 
        28
    of 4, 6, 9, 11: 
      30
    else: 
      31
  let dayVal = rm.nextInt(1, daysInMonth + 1)
  result = (year: yearVal, month: monthVal, day: dayVal)


proc nextIP*(rm: RandoMizer): string =
  ## Генерирует случайный IP адрес
  result = $rm.nextInt(1, 256) & "." &
           $rm.nextInt(0, 256) & "." &
           $rm.nextInt(0, 256) & "." &
           $rm.nextInt(1, 256)

proc nextMAC*(rm: RandoMizer): string =
  ## Генерирует случайный MAC адрес
  result = ""
  for i in 0..<6:
    if i > 0: result.add(":")
    result.add(rm.nextChar("0123456789ABCDEF"))
    result.add(rm.nextChar("0123456789ABCDEF"))

proc nextUUID*(rm: RandoMizer): string =
  ## Генерирует случайный UUID v4
  result = ""
  for i in 0..<32:
    if i in [8, 12, 16, 20]:
      result.add("-")
    if i == 12:
      result.add("4")  # Версия 4
    elif i == 16:
      result.add(rm.nextChar("89AB"))  # Вариант
    else:
      result.add(rm.nextChar("0123456789ABCDEF"))

# ============================================================================
# СПЕЦИАЛЬНЫЕ ГЕНЕРАТОРЫ
# ============================================================================

proc nextGaussianNoise*(rm: RandoMizer, size: int, amplitude: float = 1.0): seq[float] =
  ## Генерирует гауссов шум
  result = newSeq[float](size)
  for i in 0..<size:
    result[i] = rm.nextNormal(0.0, amplitude)

proc nextPerlinNoise*(rm: RandoMizer, size: int, frequency: float = 0.1): seq[float] =
  ## Генерирует упрощенный шум Перлина
  result = newSeq[float](size)
  for i in 0..<size:
    let x = float(i) * frequency
    let xi = int(x)
    let xf = x - float(xi)
    
    let a = rm.nextNormal()
    let b = rm.nextNormal()
    
    # Линейная интерполяция
    result[i] = a * (1.0 - xf) + b * xf

proc nextWalk*(rm: RandoMizer, steps: int, stepSize: float = 1.0): seq[float] =
  ## Генерирует случайное блуждание
  result = newSeq[float](steps + 1)
  result[0] = 0.0
  
  for i in 1..steps:
    let step = if rm.nextBool(): stepSize else: -stepSize
    result[i] = result[i-1] + step

proc nextBrownianMotion*(rm: RandoMizer, steps: int, dt: float = 0.01): seq[float] =
  ## Генерирует броуновское движение
  result = newSeq[float](steps + 1)
  result[0] = 0.0
  
  for i in 1..steps:
    let dW = rm.nextNormal(0.0, sqrt(dt))
    result[i] = result[i-1] + dW

# ============================================================================
# СТАТИСТИЧЕСКИЕ ФУНКЦИИ
# ============================================================================

proc testUniformity*(values: seq[float], bins: int = 10): float =
  ## Тест на равномерность распределения (хи-квадрат)
  if values.len == 0: return 0.0
  
  let minVal = values.min
  let maxVal = values.max
  let binWidth = (maxVal - minVal) / float(bins)
  
  var counts = newSeq[int](bins)
  for val in values:
    let binIndex = min(int((val - minVal) / binWidth), bins - 1)
    inc counts[binIndex]
  
  let expected = float(values.len) / float(bins)
  var chiSquare = 0.0
  
  for count in counts:
    let diff = float(count) - expected
    chiSquare += (diff * diff) / expected
  
  result = chiSquare

proc testNormality*(values: seq[float]): tuple[mean, variance, skewness, kurtosis: float] =
  ## Тест на нормальность распределения
  if values.len == 0:
    return (0.0, 0.0, 0.0, 0.0)
  
  let n = float(values.len)
  let mean = values.sum / n
  
  var variance = 0.0
  var skewness = 0.0
  var kurtosis = 0.0
  
  for val in values:
    let diff = val - mean
    let diff2 = diff * diff
    let diff3 = diff2 * diff
    let diff4 = diff3 * diff
    
    variance += diff2
    skewness += diff3
    kurtosis += diff4
  
  variance /= n
  let stdDev = sqrt(variance)
  
  if stdDev > 0:
    skewness = (skewness / n) / pow(stdDev, 3.0)
    kurtosis = (kurtosis / n) / pow(stdDev, 4.0) - 3.0
  
  result = (mean: mean, variance: variance, skewness: skewness, kurtosis: kurtosis)

# ============================================================================
# УТИЛИТЫ И ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ============================================================================

proc benchmark*(rm: RandoMizer, iterations: int = 1000000): tuple[intsPerSec, floatsPerSec: float] =
  ## Бенчмарк производительности генератора

  # Тест генерации целых чисел
  let startInt = cpuTime()
  for i in 0..<iterations:
    discard rm.nextInt()
  let endInt = cpuTime()
  let intsPerSec = float(iterations) / (endInt - startInt)
  
  # Тест генерации чисел с плавающей точкой
  let startFloat = cpuTime()
  for i in 0..<iterations:
    discard rm.nextFloat()
  let endFloat = cpuTime()
  let floatsPerSec = float(iterations) / (endFloat - startFloat)
  
  result = (intsPerSec: intsPerSec, floatsPerSec: floatsPerSec)

proc getState*(rm: RandoMizer): string =
  ## Получает состояние генератора в виде строки
  result = $rm.seed & ":" & $rm.distribution

proc setState*(rm: RandoMizer, state: string) =
  ## Восстанавливает состояние генератора из строки
  let parts = state.split(":")
  if parts.len >= 2:
    rm.setSeed(parseInt(parts[0]))
    # Восстановление распределения можно добавить при необходимости

proc clone*(rm: RandoMizer): RandoMizer =
  ## Создает копию генератора
  result = newRandoMizer(rm.seed)
  result.distribution = rm.distribution
  result.params = rm.params

# ============================================================================
# ГЛОБАЛЬНЫЕ ФУНКЦИИ ДЛЯ УДОБСТВА
# ============================================================================

var globalRandoMizer* = newRandoMizer()

proc randInt*(max: int): int = globalRandoMizer.nextInt(max)
proc randInt*(min, max: int): int = globalRandoMizer.nextInt(min, max)
proc randFloat*(): float = globalRandoMizer.nextFloat()
proc randFloat*(max: float): float = globalRandoMizer.nextFloat(max)
proc randFloat*(min, max: float): float = globalRandoMizer.nextFloat(min, max)
proc randBool*(): bool = globalRandoMizer.nextBool()
proc randChoice*[T](arr: seq[T]): T = globalRandoMizer.choice(arr)
proc randShuffle*[T](arr: var seq[T]) = globalRandoMizer.shuffle(arr)
proc randString*(length: int): string = globalRandoMizer.nextString(length)
proc randPassword*(length: int = 12): string = globalRandoMizer.nextPassword(length)
proc randColor*(): string = globalRandoMizer.nextColor()
proc randUUID*(): string = globalRandoMizer.nextUUID()

# ============================================================================
# ЭКСПОРТ ОСНОВНЫХ ФУНКЦИЙ
# ============================================================================

when isMainModule:
  # Пример использования
  echo "=== RandoMizer Demo ==="
  
  let rm = newRandoMizer()
  
  echo "Random integers: ", rm.generateInts(10, 1, 100).values
  echo "Random floats: ", rm.generateFloats(5, 0.0, 1.0).values
  echo "Random string: ", rm.nextString(10)
  echo "Random password: ", rm.nextPassword(16)
  echo "Random email: ", rm.nextEmail()
  echo "Random color: ", rm.nextColor()
  echo "Random UUID: ", rm.nextUUID()
  
  # Тест распределений
  rm.setDistribution(distNormal, ("mean", 0.0), ("stdDev", 1.0))
  let normalSeq = rm.generateFromDistribution(1000)
  echo "Normal distribution stats: ", normalSeq.stats
  
  # Бенчмарк
  let bench = rm.benchmark(100000)
  echo "Performance: ", bench.intsPerSec, " ints/sec, ", bench.floatsPerSec, " floats/sec"
