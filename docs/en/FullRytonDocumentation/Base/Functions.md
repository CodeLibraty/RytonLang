## Functions in Ryton: creating useful actions

Imagine that you are making a game about a magician. Your magician must be able to cast spells, heal, teleport. Each such action is a function!

### What are functions and why are they needed?

Take Skyrim - there are a lot of spells there. Instead of writing out the entire spell code every time, we create a function:
```
func fireball {
    def damage = 50
    def mana_cost = 30
    
    print(f"Casting fireball for {damage} damage!")
    output damage
}
```

Now you can use the spell anywhere:
```
def player_damage = fireball() // Starting the fireball!
```

### Functions with parameters

What if we want to strengthen the spell? Using the parameters:
```
func lightning(power: Int) {
    def damage = power * 10
    print(f"Lightning strikes for {damage} damage!")
    output damage
}

lightning(5) // Lightning for 50 damage
lightning(10) // Super lightning for 100 damage!
```

### Return values

Functions can return something via output:
```
func healSpell(amount: Int): Int {
    def healing = amount * 2
    print(f"Healing for {healing} HP")
    output healing
}
```

the function will return the value that you wrote in output, and then we will save it to our variable. as here:
```
def healed = healSpell(25) // Will cure by 50 HP
```

Well, is it difficult? Let's put it into practice then!

### Practical examples

Let's create a simple battle system for an RPG:
```
func attack(damage: Int) {
    print(f"Attacking with force {damage}!")
output damage
}

func defend(armor: Int) {
    def protection = armor * 2
    print(f"Blocking {protection} damage")
output protection
}
```

#### Now we use them together:
```
def enemy_attack = attack(10) // The enemy attacks by 10
def blocked = defend(5) // Block 10 damage (5 * 2)
def final_damage = enemy_attack - blocked

print(f"Total damage: {final_damage}")
```

#### Making the system more complex

Let's add different types of attacks:
```
func slash(power: Int) {
    def damage = power * 2
    print(f"Let's cut with a sword! Damage: {damage}")
output damage
}

func pierce(power: Int) {
    def damage = power * 1.5
print(f"Spear me! Damage: {damage}")
output damage
}
```

### Functions inside the pack

The functions are especially useful in pack:
```
pack Warrior {
    init {
        def health = 100 // creating HP
        def strength = 15  
        def armor = 10 // and armor
    }

    func battleCry {
        print("For glory!")
        strength += 5
    }

    func takeDamage(damage: Int) {
        def real_damage = defend(armor, damage) // calculating damage based on armor
        health -= real_damage // and doing real damage
    }
}
```

functions inside packages, by the way, are called methods, but it doesn't matter, the behavior of functions in a package and without is no different

### Your first battle system!

It's time to create something of your own!

1. Choose your favorite game
2. Think about what actions there are:
   - Attacks
   - Abilities
   - Interactions
3. Create functions for these actions
4. Combine them into a combat system

An example for Dark Souls:
```
func rollDodge(player) {
    def i_frames = 15
    print(f"{player} rolls to dodge!")
    output i_frames
}

func parry(weapon) {
    if weapon == "shield" {
        print("Perfect parry!")
        output true
    }
    output false
}
```

And now it's your turn! Create functions for the combat system from your favorite game.

Run the compiler and check the code - if you see `Build Success!` then your combat system is ready for battle!

## What's next?

Now you can create individual actions. But games need whole objects - characters, objects, monsters.
Ryton has a pack for this! Let's learn how to create them.

[Packages in Ryton →](./Packs.md )