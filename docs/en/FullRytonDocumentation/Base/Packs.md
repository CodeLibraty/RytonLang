## Classes in Ryton: creating our own objects

Imagine that you are creating a game. You need characters with names, health, and weapons. The pack in Ryton is like a blueprint for creating such characters.

### What is pack and why is it needed?

Take Minecraft - there are different mobs: zombies, skeletons, spiders. Each mob has health, damage, and sounds. Instead of prescribing it for each mob separately, we create one `pack Mob`:
```
pack Mob {
    init {
        def name = "Unknown"
        def health = 20
        def damage = 2
    }
    
    func attack {
        print(f"{name} deals {damage} damage!")
    }
}

Now you can create different mobs:
def zombie = Mob()
zombie.name = "Zombie"
zombie.attack() // Outputs: Zombie deals 2 damage!
```

### Inheritance: improving the basic objects

What if we need a special mob with special padding? We use inheritance via `::` :
```
pack Skeleton :: Mob {
    init {
        super() // here we call our Mob class and ask it to create its own variables in this class
        name = "Skeleton" // now we can duplicate them
        def bowDamage = 5 // and create your own, which Mob does not have
    }
    
    func shootArrow { // now the skeleton has the ability to shoot arrows
        print(f"{name} shoots for {bowDamage} damage!")
    }
}
```

### Modifiers: special features

Sometimes you need to make a pack special. There are modifiers for this:
```
pack Player :: Mob !(final) {
    init {
        super()
        name = "Steve"
        def inventory = [] // player's inventory only
    }
    
    func addItem(item) {
inventory.add(item) // player-only padding
    }
}
```

here, final says that it is impossible to create a new mob from Stiv (the player) through inheritance, it is the final version

### Practical examples

Let's create a system of items for the game:
```
// here we create the basic properties of an item, they will be in all
pack Item items {
    init {
        def name = "" // name
        def weight = 1 // size
        def value = 0 // quantity
    }
}

pack Weapon :: Item {
    init {
        super() // taking all the basic properties

        name = "sword" // setting the name
        value = 1 // and the number of existing

        def damage = 10 // and add our own
        def durability = 100 // properties
    }
    
    // this pridmet can be used as a weapon
    func use {
        durability -= 1 // we take away from durability when using
        print(f"Dealt {damage} damage! Durability: {durability}")
    }
}
```

### Object interaction

Objects can work together:
```
// creating an inventory
pack Inventory {
    init {
        def items = []
        def maxWeight = 100
    }
    
    func addItem(item) {
        items.add(item)
    }
}

// creating
pack Game {
    init {
        def player = Player() // and in the game we create a player
        def inventory = Inventory() // and its inventory
    }
    
    func start {
        def sword = Weapon()
        sword.name = "Iron Sword"
        inventory.addItem(sword)
    }
}
```

### Your first pack!

It's time to create your own pack! 

1. Choose your favorite game
2. Think about what objects are there:
   - Item Characters
   - Abilities
3. Create a pack for one of them
4. Add methods and properties

An example for Minecraft:
```
// what do you think this block is?
pack Block {
    init {
        def type = "air"
        def hardness = 1
        def drops = []
    }
    
    func mine(tool) {
        print(f"Mining {type} with {tool}...")
        output drops
    }
}
```

And now it's your turn! Create a pack for an object from your favorite game.

Run the compiler to check the code - if you see `Build Success!`so it's all right!

## **Great**!
Now you have a solid foundation for writing your first programs!
Don't you know what to write? I'll give you some ideas!

### Ideas for your first projects:

1. RPG battle:
- Create a hero and a monster
- Add an attack system
- Make an inventory

2. The Clicker:
- Click counter
- Improvements
- Achievements

3. Text quest:
- History
- Elections
- Endings

4. Dungeon Simulator:
- Room generation
- Treasures
- Monsters

If it's difficult, then it's okay, try it:

1. Smart Calculator:
- Basic operations
- History of computing 
- Saving the results

2. Task Manager:
- Adding/deleting tasks
- Completion dates
- Priorities

3. Currency Converter:
- Exchange rates of major currencies
- Quick recalculation
- Saving history

4. Training Diary:
- Record exercises
- Calorie counting
- Tracking progress

5. Tagged notes:
- Create notes
- Search by tags
- Categories

These programs:
- Useful in real life
- They give results quickly
- Easy to improve gradually
- You can show it to your friends

Start with a simple option, and then add new features! and the fact that they are simple does not mean that they are useless!

Choose any idea and start creating! And if you get stuck, take a look at our Discord, they will always help you there!

and remember, it's better to do it once than read it 100 times!

[Project examples →](./Projects/Examples.md) // coming soon