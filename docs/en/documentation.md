# RytonLang - User Manual

# 1. Functions
## Basic function syntax
```ryton
// Simple function without parameters
func hello {
    print(“Hello, World!”)
}

// Function with parameters
func greet(str) {
    print(f “Hello, {name}!”)
}

// Function with return value
// it is not necessary to specify the type of the return value or arguments, but it is better to do so
func add(a: int, b: int) !int {
    return a + b
}

// single line function
func multiply(x: int, y: int) => x * y
```

## MetaModifiers for functions
```ryton
// Results caching
func heavy_calc(data: int) !cached {
    // results will be cached
}

// Asynchronous execution
func fetch_data(url: str) !async {
    // asynchronous function
}

// Multiple modifiers
func process_data(items: list) !cached|async {
    // cached asynchronous function
}
```

## Function Contracts
```ryton
func divide(a: int, b: int) -> float {
    require b != 0
    ensure result > 0
    body {
        return a / b
    }
}
```

# 2. Classes (pack)
## Basic syntax
```ryton
pack User {
    name: str
    age: int
    
    func greet {
        print(f “Hello, {this.name}!”)
    }
}
```
## Inheritance
```ryton
pack Animal {
    species: str
}

pack Dog :: Animal {
    breed: str
}
```

## Class Metamodifiers
```ryton
// Immutable class
pack Config !frozen {
    host: str
    port: int
}

// Class with automatic slots
pack Performance !slots {
    metrics: list
}

// Multiple modifiers
pack Cache !singleton|frozen {
    data: dict
}
```

## Data structures
```ryton
struct UserData {
    name: str(min=2, max=50)
    age: int(min=0, max=150)
    email: str(pattern=“^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$”)
}
```

# 3. Error handling
## Basic syntax
```ryton
try {
    risky_operation()
} elerr {
    handle_error()
}
```

## Typed error handling
```ryton
try {
    connect_to_database()
} elerr ConnectionError {
    retry_connection()
} elerr TimeoutError {
    show_timeout_message()
} elerr {
    // Handling other errors
}
```

### single line processing
### full processing
```ryton
try { getData() } elerr DataError { return default_value }
```
### partial processing
```ryton
try { getData() }
```

# 4. Modules and packages
## Import modules
```ryton
module import {
    std.lib:stdlib
    std.Math[add|sub|mul|div|cossinus:cos]
    std.Files:fs
    std.Terminal[ascii|emoji|unicode]
}
```

## Import packages
```ryton
package import {
    MyPackage[MyPack] {
        // Import the required public items
    }
}
```

## Integration with other languages
```ryton
// Python modules
pylib: numpy
pylib: pandas as pd

// Java modules
jvmlib: java.util as jutil

// Zig integration
#ZigModule(
    fn calculate(x: i32) i32 {
        return x * 2;
    }
) -> fast_math

// all of this can be used in code
```

## Create module
```ryton
pack MyModule {
    // public elements
    func public_method {
        internal_helper()
    }

    // automatic export when importing a module
    export func public_method {
        internal_helper()
    }

    // Private elements
    private func internal_helper {
        // Internal logic
    }
}
```

# 5. Events
```ryton
// event when the user has logged in
// i.e. the value of the UserLogin variable became true
event UserLogin -> True { 
    validate_session()
    update_status()
}
// this value is checked every 0.1 seconds by default, regardless of whether it is in a separate thread
```

# 6. Cycles
## Basic loops
```ryton
// Cycle for
for item in items {
    process(item)
}

// While loop
while run == True {
    print('running')
}

// Until loop (runs until condition is false)
until (counter > 10) {
    counter += 1
}

// Infinite loop with delay
infinit 1.5 { // delay 1.5 seconds
    check_status()
}

// Repeat 5 times with a delay of 1 second
repeat 5 1.0 {
    send_request()
}
```
## Ranges in loops
```
// Inclusive range
for i in 1..5 { // 1,2,3,4,5
    print(i)
}

// Range exclusive
for i in 1...5 { // 1,2,3,4
    print(i)
}
```

# 7. Conditions
## Basic conditions
```ryton
if user.age >= 18 {
    allow_access()
} elif user.age >= 13 {
    request_parent_permission()
} else {
    deny_access()
}
```
## Pattern matching
```ryton
switch value {
    case 1 {
        print(“One”)
    }
    case 2 => print(“Two”)

    else => print(“Other”)
}
```
## Conditional expressions
```ryton
// Ternary operator
result = if value > 0 { “positive” } else { “negative” }

// Conditional assignment
config ?= load_default_config() // Assigns only if config == None
```

# 8. Data Types
## Basic types
```ryton
name: str = “John”
age: int = 25
active: bool = true
price: float = 99.99
// it is not necessary to specify types
```
## Tables
```ryton
// ryton doesn't have regular tables, only meta tables
table UserSettings {
    'theme': “dark”
    'language': “en”
    'notifications' := check_status() // Calculated field
}
```
## Arrays and collections
```ryton
// Arrays
numbers = [1, 2, 3, 4, 5]
names = [“Alice”, “Bob”, “Charlie”].

// Calling a function with an array
process[data, config, options]

// Operations with arrays
first = numbers[0]
slice = numbers[1..3]
```

## 9. Special operators
```ryton
// Pipeline operator
data |> process |> save

// Comparison operator
value <=> other // returns -1, 0 or 1

// Function composition operators
transform = filter >> map >> reduce
```
## 10. Decorators
```ryton
<timeit>
<Cache(max_size=100)>
func expensive_operation {
    // code
}
```

## 11. Translator directives
```ryton
static_typing = true // enable static analysis
trash_cleaner = true // enable garbage collector
```
