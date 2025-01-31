# RytonLang - Руководство пользователя

# 1. Функции
## Базовый синтаксис функций
```ryton
// Простая функция без параметров
func hello {
    print("Hello, World!")
}

// Функция с параметрами
func greet(str) {
    print(f"Hello, {name}!")
}

// Функция с возвращаемым значением
// не обязательно указывать тип возвращаемого значения или аргументов но лучше указывать
func add(a: int, b: int) !int {
    return a + b
}

// Однострочная функция
func multiply(x: int, y: int) => x * y
```

## МетаМодификаторы функций
```ryton
// Кэширование результатов
func heavy_calc(data: int) !cached {
    // результаты будут кэшироваться
}

// Асинхронное выполнение
func fetch_data(url: str) !async {
    // асинхронная функция
}

// Несколько модификаторов
func process_data(items: list) !cached|async {
    // кэшируемая асинхронная функция
}
```

## Контракты функций
```ryton
func divide(a: int, b: int) -> float {
    require b != 0
    ensure result > 0
    body {
        return a / b
    }
}
```

# 2. Классы (pack)
## Базовый синтаксис
```ryton
pack User {
    name: str
    age: int
    
    func greet {
        print(f"Hello, {this.name}!")
    }
}
```
## Наследование
```ryton
pack Animal {
    species: str
}

pack Dog :: Animal {
    breed: str
}
```

## Метамодификаторы классов
```ryton
// Неизменяемый класс
pack Config !frozen {
    host: str
    port: int
}

// Класс с автоматическими слотами
pack Performance !slots {
    metrics: list
}

// Несколько модификаторов
pack Cache !singleton|frozen {
    data: dict
}
```

## Структуры данных
```ryton
struct UserData {
    name: str(min=2, max=50)
    age: int(min=0, max=150)
    email: str(pattern="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
}
```

# 3. Обработка ошибок
## Базовый синтаксис
```ryton
try {
    risky_operation()
} elerr {
    handle_error()
}
```

## Типизированная обработка ошибок
```ryton
try {
    connect_to_database()
} elerr ConnectionError {
    retry_connection()
} elerr TimeoutError {
    show_timeout_message()
} elerr {
    // Обработка остальных ошибок
}
```

## Однострочная обработка
### полная обработка
```ryton
try { getData() } elerr DataError { return default_value }
```
### частичная обработка
```ryton
try { getData() }
```

# 4. Модули и пакеты
## Импорт модулей
```ryton
module import {
    std.lib:stdlib
    std.Math[add|sub|mul|div|cossinus:cos]
    std.Files:fs
    std.Terminal[ascii|emoji|unicode]
}
```

## Импорт пакетов
```ryton
package import {
    MyPackage[MyPack] {
        // Импорт нужных публичных элементов
    }
}
```

## Интеграция с другими языками
```ryton
// Python модули
pylib: numpy
pylib: pandas as pd

// Java модули
jvmlib: java.util as jutil

// Zig интеграция
#ZigModule(
    fn calculate(x: i32) i32 {
        return x * 2;
    }
) -> fast_math

// всё это можно использовать в коде
```

## Создание модуля
```ryton
pack MyModule {
    // Публичные элементы
    func public_method {
        internal_helper()
    }

    // автоматический экспорт при импорте модуля
    export func public_method {
        internal_helper()
    }

    // Приватные элементы
    private func internal_helper {
        // Внутренняя логика
    }
}
```

# 5. События
```ryton
// событие когда пользователь залогинился
// то есть занчение переменной UserLogin стало равно true
event UserLogin -> True { 
    validate_session()
    update_status()
}
// проверяется это занчение каждые 0.1 секунды по умолчанию не заввисимо в отдельном потоке
```

# 6. Циклы
## Базовые циклы
```ryton
// Цикл for
for item in items {
    process(item)
}

// Цикл while
while run == True {
    print('running')
}

// Цикл until (работает пока условие ложно)
until (counter > 10) {
    counter += 1
}

// Бесконечный цикл с задержкой
infinit 1.5 {  // задержка 1.5 секунды
    check_status()
}

// Повторить 5 раз с задержкой 1 секунда
repeat 5 1.0 {
    send_request()
}
```
## Диапазоны в циклах
```
// Диапазон включительно
for i in 1..5 {  // 1,2,3,4,5
    print(i)
}

// Диапазон исключительно
for i in 1...5 {  // 1,2,3,4
    print(i)
}
```

# 7. Условия
## Базовые условия
```ryton
if user.age >= 18 {
    allow_access()
} elif user.age >= 13 {
    request_parent_permission()
} else {
    deny_access()
}
```
## Сопоставление с образцом
```ryton
switch value {
    case 1 {
        print("One")
    }
    case 2 => print("Two")

    else => print("Other")
}
```
## Условные выражения
```ryton
// Тернарный оператор
result = if value > 0 { "positive" } else { "negative" }

// Условное присваивание
config ?= load_default_config()  // Присваивает только если config == None
```

# 8. Типы данных
## Базовые типы
```ryton
name: str = "John"
age: int = 25
active: bool = true
price: float = 99.99
// указывать типы необязательно
```
## Таблицы
```ryton
// в райтон нету обычных таблиц, есть только метатаблицы
table UserSettings {
    'theme': "dark"
    'language': "en"
    'notifications' := check_status()  // Вычисляемое поле
}
```
## Массивы и коллекции
```ryton
// Массивы
numbers = [1, 2, 3, 4, 5]
names = ["Alice", "Bob", "Charlie"]

// Вызов функции с массивом
process[data, config, options]

// Операции с массивами
first = numbers[0]
slice = numbers[1..3]
```

## 9. Специальные операторы
```ryton
// Оператор конвейера
data |> process |> save

// Оператор сравнения
value <=> other  // возвращает -1, 0 или 1

// Операторы композиции функций
transform = filter >> map >> reduce
```
## 10. Декораторы
```ryton
<timeit>
<Cache(max_size=100)>
func expensive_operation {
    // код
}
```

## 11. Директивы Транслятора
```ryton
static_typing = true // включить статический  анализ
trash_cleaner = true // включить сборщик мусора
```