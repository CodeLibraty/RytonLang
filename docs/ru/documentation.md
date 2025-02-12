# Функции в Райтон
## 1. Базовый синтаксис
```
func hello {
    print("Hello!")
}
```

- Ключевое слово `func` для объявления
- Фигурные скобки вместо двоеточия
- Не требуются скобки если нет параметров
## 2. Параметры и типы
```
func greet(name: String, age: Int) {
    print(f"Hello {name}, you are {age} years old!")
}

// строгая проверка типов
func greet(name: String, age: Int) !String|validate {
    return f"Hello {name}, you are {age} years old!"
}
```

- Типизация через двоеточие
- Проверка типов

## 3. односторчные функции
```
func greet(name: String, age: Int) => f"Hello {name}, you are {age} years old!"
```

## 4. декораторы
```
<RunTimer.timeit>
<Сache(128)>
func heavy_calc(data: List) {
    </
      тяжелые вычисления,
      выполнение котрых будет засекатся и
      кешироватся определённым образом
    />
}
```

## 5. Модификаторы функций
```
func heavy_calc(data: List) cached|async|logged {
    // тяжелые вычисления
}
```
- `cached` - кэширование результатов
- `async`  - асинхронное выполнение
- `logged` - автоматически логирует функцию
- Можно комбинировать через |

## 6. Лямбды
```
func(x, y) => x + y
func(x) => {
    return x * 2
}
```
- Короткий синтаксис со стрелкой
- Однострочные и блочные версии

# Классы в Райтон
## 1. Базовое объявление
```
pack Animal {
    slots {"name", "age"}
    init {
        this.name = "Unknown"
        this.age = 0
    }
}
```

- Ключевое слово pack
- slots для атрибутов
- Конструктор через `init`
## 2. Наследование
```
pack Dog :: Animal {
    init {
        super()
        this.breed = "Mixed"
    }
    
    func bark {
        print("Woof!")
    }
}
```

- `::` для наследования
- super() для вызова родителя
- Переопределение методов
## 3. Модификаторы классов
```
pack User !slots|frozen {
    name: 'Вася'
    email: 'vasya@mail.com'
}
```

- `@slots` - оптимизация памяти
- `@frozen` - неизменяемый класс
- `@singleton` - паттерн одиночка
## 4. Приватность
```
pack Database {
    private connection: 'Connection'
    
    private func connect {
        # приватный метод
    }
}
```

- private для атрибутов
- private для методов
- Защита внутреннего состояния


# Управляющие конструкции в Райтон
## События:
```
event temperature -> high {
    alert("Too hot!")
}
```
- сомотрят на изменение переменной и выполняется код
- запускаются в отдельном потоке
## Циклы
### Простой цикл:
```
for i in 1...10 {
    print(i)
}
```

- Диапазон через `...` включая конец
- `..` для исключения конца

### Бесконечный цикл:
```
infinit 0.1 { // с задержкой 0.1 сек
    check_status()
}
```

### Цикл с повторами:
```
repeat 5 0.5 { // 5 раз с задержкой 0.5 сек
    send_request()
}
```

## Условия
### Базовое условие:
```
if x > 0 {
    print("Positive")
} elif x < 0 {
    print("Negative")
} else {
    print("Zero")
}
```

### Switch выражение:
```
switch value {
    | 1 => print("One")
    | 2 => print("Two")
    | String(text) => print(f"Text: {text}")
    
    else => print("Default")
}
```

## Обработка ошибок
### Try-elerr блок:
```
try {
    dangerous_operation()
} elerr {
    print("Error occurred")
}
```

### С типом ошибки:
```
try {
    connect_to_db()
} elerr ConnectionError {
    retry_connection()
} elerr {
    log_error()
}
```

### Однострочный обработчик:
```
try { parse_data() } elerr ValueError { return None }
```

# Интеграции с другими языками
## 1. Вызов Python из Ryton
```
pylib: mymodule

mymodule.greet("John")
```
- Импорт модуля через `pylib`
- Вызов функций через точку
## 2. Использование Zig из Ryton
### Импорт библиотеки:
```
ziglib: mylib
mylib.add(2, 3)
```
- Импорт библиотеки через `ziglib`
- Вызов функций через точку
### Запуск на прямую:
```
#Zig(start)
// код на Zig
#Zig(end: result)
```
- Код Zig через метатеги `#Zig(start)` и `#Zig(end: result)`
### Создание модуля на Zig прямо в Ryton:
```
#ZigModule(
    // код на Zig
) -> module

module.func()
```
## 3. Импорт экосистемы JVM:
```
jvmlib: java.util.ArrayList as JArrayList

list = JArrayList()
list.add("Hello")
```
## 4. Импорт нативных библиотек:
```
nativelib: libmylib.so as MyLib

MyLib.func()
```
