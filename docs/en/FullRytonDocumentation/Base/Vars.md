# Variables in Ryton: data storage  

Variables are like boxes in which you put things in order to use them later. In games, variables store the character's health, the number of coins, and the player's name. In programming, they are needed to save data — numbers, text, lists — and give them names so that they can be easily accessed.

## What are variables and why are they needed?  

Imagine a Minecraft game: you need to remember how many blocks are in your inventory, how many health hearts are left, and which potions are active. Without variables, you'd have to recalculate or keep it in mind every time. In the code, the variables work the same way:
```
def blocks = 64 // Number of blocks
def health = 20 // Player's health
val maxHealth = 20 // Maximum health, it does not change
```

Or take a real-life example - a cookbook. When you prepare a pie, you need to remember:
```
def sugar = 3 // Tablespoons sugar
def flour = 2 // Cups flour
val temp = 180 // Oven temperature, it does not change
```

### Basic syntax: how to create a variable

In Ryton, variables are created simply:
```
def playerName = "Alex" // Mutable variable
val worldSeed = 12345 // Immutable variable
```

- Changeable (def) - the value can be changed:
```
def score = 0
score = 100 // Can be changed
```

- Immutable (val) - the value is set once:
```
val maxLevel = 100
maxLevel = 200 // Error! Can't be changed
```

### Examples from games

Let's create a simple RPG system:
```
def playerHealth = 100 // Player Health
def mana = 50 // Mana for spells
val maxMana = 100 // Maximum mana
def gold = 0 // Player coins
```

#### Player takes damage
```
playerHealth -= 25 // 75 health remaining
```

#### The player uses the spell
```
mana -= 30 // Wasting mana
gold += 100 // We get a reward
```

### Real-life examples

- Financial accounting:
```
def balance = 1000 // Money in the account
def expenses = 0 // Expenses
val salary = 5000 // Salary
```

- Pizza recipe:
```
def cheese = 300 // Grams of cheese
val bakingTime = 15 // Minutes in the oven
def toppings = ["tomatoes", "mushrooms", "olives"]
```

## Scope: where variables live

Variables are only available where they are created:
```
func makePizza {
    def temp = 200 // Temperature for this function only 
    print(temp)   // 200
}
print(temp)       // Error! temp doesn't exist here and you can't use it here.
```

## Data types in variables

Ryton defines the type itself, but you can specify it explicitly:
```
def age: Int = 25 // Number
def name: String = "Max" // Text
def items: Array = [1, 2, 3] // The list
```
but this is not necessary, he himself can determine whether you create a line or a number.

## Practical examples

Let's create an inventory system:
```
def inventory = ["sword", "shield", "potion"] // inventory
def equipped = "sword" // currently equipped
def durability = 100 // sword strength
```

### Item Usage
```
durability -= 10 // subtract from durability
if durability <= 0 {
equipped = "no"
}
```

### Achievement system:
```
val achievements = ["First Victory", "Sword Master"]
def score = 0
def level = 1
```

### Getting an achievement
```
score += 100
if score >= 1000 {
    level += 1
}
```

# What's next?

Now you know how to create and use variables in Ryton. This is the basis for creating more complex programs, from games to business applications. In the following sections, we will learn how to use variables in functions and create complex data structures!

## Your first game code!

It's time to create something of your own! 

1. Choose your favorite game
2. Think about what variables there are:
   - Characteristics of the hero
   - Items and resources
   - Points and achievements
3. Write the code on Ryton using these variables
4. Describe where and how they are used in the game.

My favorite game is Minecraft:
```
def blocks = 64 # Stack of blocks in hand
def hunger = 20 # Hunger scale
val maxStackSize = 64 # Maximum items in stack
def position = [10, 64, -30]  # Player coordinates
```

And now it's your turn! Create variables for your favorite game and tell us about them. For example, `Counter-Strike` or `Terraria`.

This will help you better understand how variables work in real projects!

You can even run the compiler and see if you did everything right, if so, they will tell you that `Build Success!`

## What's next?
Cool! Now you know how to store data. But what if you need to do something about them?
There are functions for this! Let's learn how to create actions in your program.

[Functions in Ryton →](./Functions.md)