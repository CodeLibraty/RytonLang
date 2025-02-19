# Модули стандартной библиотеки Ryton
## std.Math:
```
fibonacci(n: Int) !Int
```
- Вычисляет n-ное число Фибоначчи
- n - позиция числа в последовательности

```
factorial(n: Int) !Int
``` 
- Вычисляет факториал числа
- n - неотрицательное целое число

```
prime_factors(n: Int) !List
```
- Возвращает список простых множителей числа
- n - целое число для разложения

```
is_prime(n: Int) !Bool
```
- Проверяет, является ли число простым
- n - проверяемое число

```
gcd(a: Int, b: Int) !Int
```
- Находит наибольший общий делитель
- a, b - целые числа

```
lcm(a: Int, b: Int) !Int
```
- Находит наименьшее общее кратное
- a, b - целые числа

```
precise_sqrt(x: Float, precision: Int = 10) !Decimal
```
- Вычисляет корень с указанной точностью
- x - число
- precision - количество знаков после запятой

```
round_to_significant(number: Float, significant_digits: Int) !Float
```
- Округляет число до значащих цифр
- number - исходное число
- significant_digits - количество значащих цифр

```
deg_to_rad(degrees: Float) !Float
```
- Конвертирует градусы в радианы
- degrees - угол в градусах

```
rad_to_deg(radians: Float) !Float
```
- Конвертирует радианы в градусы
- radians - угол в радианах

## std.Path:
```
pwd() !String
```
- Возвращает текущую рабочую директорию

```
get_home() !String
```
- Получает домашнюю директорию пользователя

```
cd(path: String)
```
- Меняет текущую директорию
- path - путь к новой директории

```
mkdir(dir: String)
```
- Создает директорию
- dir - путь к создаваемой директории

```
mv(old_name: String, new_name: String)
```
- Перемещает/переименовывает файл
- old_name - исходный путь
- new_name - новый путь

```
cp(source_file: String, dest_file: String)
```
- Копирует файл
- source_file - исходный файл
- dest_file - путь копирования

```
remove(path: String)
```
- Удаляет файл
- path - путь к файлу

```
rmdir(path: String)
```
- Удаляет пустую директорию
- path - путь к директории

## std.RandoMizer:
```
range_Float(start: Float, end: Float, precision: Int = 2) !Float
```
- Генерирует случайное Float число
- start - начало диапазона
- end - конец диапазона
- precision - количество знаков после запятой

```
weighted_choice(choices: List, weights: List) !Any
```
- Выбор с весами из списка
- choices - список вариантов
- weights - список весов для каждого варианта

```
unique_List(start: Int, end: Int, count: Int) !List
```
- Генерирует список уникальных чисел
- start - начало диапазона
- end - конец диапазона
- count - количество чисел

```
shuffle_weighted(items: List, weights: List) !List
```
- Перемешивание с учетом весов
- items - список элементов
- weights - веса элементов

```
probability(percentage: Float) !Bool
```
- Возвращает True с указанной вероятностью
- percentage - вероятность в процентах

```
tring(length: Int, chars: String = "abcdef...") !String
```
- Генерирует случайную строку
- length - длина строки
- chars - допустимые символы

## std.DataTime:
```
time(type: String = 'std') !String
```
- Возвращает текущее время в разных форматах
- type: 'std' - стандартный, 'asc' - ASCII, 'unix' - UNIX timestamp, 'utc' - UTC

```
hours() !Int
```
- Возвращает текущий час (0-23)

```
minutes() !Int 
```
- Возвращает текущую минуту (0-59)

```
seconds() !Int
```
- Возвращает текущую секунду (0-59)

```
time_short() !String
```
- Возвращает время в формате "HH:MM:SS"

```
cal() !String
```
- Возвращает дату и время в формате "YYYY-MM-DD HH:MM:SS"

```
sleep(time: Float = 0)
```
- Останавливает выполнение на указанное количество секунд
- time - время в секундах

```
today() !Int
```
- Возвращает текущую дату

```
now(tz: TimeZone = None, type: String = 'std') !Int
```
- Возвращает текущие дату и время
- tz - временная зона
- type: 'std' или 'utc'

## std.Files:
```
write_file(path: String, content: String) !Bool
```
- Записывает содержимое в файл
- path - путь к файлу
- content - содержимое для записи

```
read_file(path: String) !String
```
- Читает содержимое файла
- path - путь к файлу

```
list_dir(path: String = ".") !List[String]
```
- Возвращает список файлов в директории
- path - путь к директории

```
create_dir(path: String) !Bool
```
- Создает директорию
- path - путь новой директории

```
remove_dir(path: String) !Bool
```
- Удаляет директорию
- path - путь к директории

```
copy_file(src: String, dst: String) !Bool
```
- Копирует файл
- src - исходный файл
- dst - путь назначения

```
move_file(src: String, dst: String) !Bool
```
- Перемещает файл
- src - исходный путь
- dst - новый путь

## std.ReGex:
### class Regex:
```
compile(pattern: String, flags: Int = 0) !Pattern
```
- Компилирует регулярное выражение с флагами
- pattern - шаблон регулярного выражения
- flags - флаги компиляции

```
match_all(pattern: String, text: String) !List[Match]
```
- Находит все совпадения в тексте
- pattern - регулярное выражение
- text - исходный текст

```
extract_groups(pattern: String, text: String) !List[Tuple]
```
- Извлекает все группы из совпадений
- pattern - регулярное выражение с группами
- text - исходный текст

```
split_by_pattern(pattern: String, text: String, maxsplit: Int = 0) !List[String]
```
- Разделяет текст по шаблону
- pattern - разделяющий шаблон
- text - исходный текст
- maxsplit - максимальное количество разделений

```
replace_all(pattern: String, repl: String, text: String) !String
```
- Заменяет все совпадения
- pattern - что заменять
- repl - на что заменять
- text - исходный текст

```
find_first(pattern: String, text: String) !Match
```
- Находит первое совпадение
- pattern - искомый шаблон
- text - где искать

```
validate(pattern: String, text: String) !Bool
```
- Проверяет соответствие текста шаблону
- pattern - шаблон для проверки
- text - проверяемый текст

```
find_between(start: String, end: String, text: String) !List[String]
```
- Находит текст между start и end
- start - начальный шаблон
- end - конечный шаблон
- text - где искать

```
remove_matches(pattern: String, text: String) !String
```
- Удаляет все совпадения с шаблоном
- pattern - что удалять
- text - откуда удалять

```
count_matches(pattern: String, text: String) !Int
```
- Подсчитывает количество совпадений
- pattern - что считать
- text - где считать

```
replace(text: String, word: String, replacement: String) !String
```
- Заменяет слово на замену
- text - исходный текст
- word - что заменять
- replacement - на что заменять

```
replace_regex(text: String, pattern: String, replacement: String) !String
```
- Заменяет по регулярному выражению
- text - исходный текст
- pattern - шаблон замены
- replacement - замена

```
split(text: String, delimiter: String = " ") !List[String]
```
- Разделяет текст по разделителю
- text - исходный текст
- delimiter - разделитель

### Методы вне классов:

```
create_pattern(*parts: String) !String
```

- Объединяет части в единый шаблон регулярного выражения
- parts - части шаблона


```
escape_pattern(text: String) !String
```

- Экранирует специальные символы в тексте
- text - текст для экранирования


```
join(items: List[String], delimiter: String = "") !String
```

- Соединяет список строк через разделитель
- items - строки для соединения
- delimiter - разделитель


```
trim(text: String) !String
```

- Удаляет пробелы в начале и конце
- text - исходный текст


```
contains(text: String, substring: String) !Bool
```

- Проверяет наличие подстроки
- text - где искать
- substring - что искать


```
starts_with(text: String, prefix: String) !Bool
```

- Проверяет начало строки
- text - проверяемый текст
- prefix - искомое начало


```
ends_with(text: String, suffix: String) !Bool
```

- Проверяет конец строки
- text - проверяемый текст
- suffix - искомый конец


```
to_upper(text: String) !String
```

- Преобразует в верхний регистр
- text - исходный текст


```
to_lower(text: String) !String
```

- Преобразует в нижний регистр
- text - исходный текст


```
capitalize(text: String) !String
```

- Делает первую букву заглавной
- text - исходный текст


```
reverse(text: String) !String
```

- Переворачивает строку
- text - исходный текст


```
count_words(text: String) !Int
```

- Считает количество слов
- text - исходный текст


```
find_all(text: String, substring: String) !List[Int]
```

- Находит все позиции подстроки
- text - где искать
- substring - что искать


```
extract_numbers(text: String) !List[String]
```

- Извлекает все числа из текста
- text - исходный текст


```
extract_emails(text: String) !List[String]
```

- Извлекает email адреса из текста
- text - исходный текст


```
extract_urls(text: String) !List[String]
```

- Извлекает URL из текста
- text - исходный текст


```
is_palindrome(text: String) !Bool
```

- Проверяет является ли текст палиндромом
- text - проверяемый текст


```
levenshtein_distance(s1: String, s2: String) !Int
```

- Вычисляет расстояние Левенштейна
- s1, s2 - сравниваемые строки


```
format_template(template: String, **kwargs: Dict) !String
```

- Форматирует шаблон строки
- template - шаблон
- kwargs - именованные аргументы


```
truncate(text: String, length: Int, suffix: String = "...") !String
```

- Обрезает текст до длины
- text - исходный текст
- length - максимальная длина
- suffix - окончание


```
wrap(text: String, width: Int) !List[String]
```

- Разбивает текст на строки заданной ширины
- text - исходный текст
- width - ширина строки


```
remove_punctuation(text: String) !String
```

- Удаляет знаки пунктуации
- text - исходный текст


```
slugify(text: String) !String
```

- Преобразует в URL-совместимый slug
- text - исходный текст


```
is_anagram(text1: String, text2: String) !Bool
```

- Проверяет являются ли строки анаграммами
- text1, text2 - проверяемые строки


```
count_chars(text: String) !Dict[String, Int]
```

- Подсчитывает количество каждого символа
- text - исходный текст
