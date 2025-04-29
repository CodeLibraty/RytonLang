## Data types in Ryton: building blocks of programs

Imagine that you are building a house in Minecraft. There are different blocks there - stone, wood, earth. In programming, data types work the same way - they are different types of information that we use.

### Basic types

Int - integers:
- Number of coins: 100
- Character level: 25
- Sword Damage: 15

Float - fractional numbers:
- Boss's Health: 100.5
- Running speed: 4.7
- Respawn time: 3.2

String - text:
- Hero's name: "Steve"
- Sword name: "Excalibur"
- NPC cues: "Attention, anecdote"

Bool - true/false:
- Whether the character is alive: true
- Whether the door is open: false
- Is there a key: true

### Complex types

Array - lists:
- Inventory: ["sword", "shield", "potion"]
- Coordinates: [20, 90, 30]
- List of quests: ["Don't waste energy", "Live to 6:00"]

### Usage examples

Games often use different types together.:

# Hero characteristics
```
def name: String = "Arthas" // Name - text
def level: Int = 80 // Level - integer
def health: Float = 100.0 // Health - fractional number
def is_alive: Bool = true // Is he alive - true/false
def inventory: Array = ["sword", "shield"] // Inventory - list
```

### Your first types!

It's time to create something of your own!

1. Choose your favorite game
2. Think about what data is there:
   - Characteristics of heroes
   - Parameters of objects
   - Game settings
3. Identify their types

An example for Terraria:
```
def weapon_name: String = "Night's Edge"
def damage: Int = 42
def speed: Float = 4.2
def is_legendary: Bool = true
def materials: Array = ["Light Shard", "Soul of Night"]
```

And now it's your turn! Create variables with different types from your favorite game.

Run the compiler to check - if you see "Build Success!" then the types are specified correctly!

### What's next?

Do you know what def is in the examples above? 
It's a variable! You will find out what a variable is and how to work with it in the next section.

[Variables in Ryton →](./Vars.md)