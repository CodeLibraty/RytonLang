## Функции в Ryton: создаем полезные действия

Представь что ты делаешь игру про мага. Твой маг должен уметь колдовать заклинания, лечиться, телепортироваться. Каждое такое действие - это функция!

### Что такое функции и зачем они нужны?

Возьмем Skyrim - там есть много заклинаний. Вместо того чтобы каждый раз прописывать весь код заклинания, мы создаем функцию:
```
func fireball {
    def damage = 50
    def mana_cost = 30
    
    print(f"Casting fireball for {damage} damage!")
    output damage
}
```

Теперь можно использовать заклинание где угодно:
```
def player_damage = fireball()  // Запускаем фаербол!
```

### Функции с параметрами

А что если мы хотим усилить заклинание? Используем параметры:
```
func lightning(power: Int) {
    def damage = power * 10
    print(f"Lightning strikes for {damage} damage!")
    output damage
}

lightning(5)   // Молния на 50 урона
lightning(10) // Супер молния на 100 урона!
```

### Возвращаемые значения

Функции могут что-то возвращать через output:
```
func healSpell(amount: Int): Int {
    def healing = amount * 2
    print(f"Healing for {healing} HP")
    output healing
}
```

функция вернёт значение что ты написал в output а потом это мы сохраним в нашу переменную. как здесь:
```
def healed = healSpell(25)  // Вылечит на 50 HP
```

Ну что, сложно? даваё тогда посмторим на практике!

### Практические примеры

Создадим простую систему боя для RPG:
```
func attack(damage: Int) {
    print(f"Атакуем с силой {damage}!")
    output damage
}

func defend(armor: Int) {
    def protection = armor * 2
    print(f"Блокируем {protection} урона")
    output protection
}
```

#### Теперь используем их вместе:
```
def enemy_attack = attack(10)           // Враг атакует на 10
def blocked = defend(5)                 // Блокируем 10 урона (5 * 2)
def final_damage = enemy_attack - blocked

print(f"Итоговый урон: {final_damage}")
```

#### Делаем систему сложнее

Добавим разные типы атак:
```
func slash(power: Int) {
    def damage = power * 2
    print(f"Рубим мечом! Урон: {damage}")
    output damage
}

func pierce(power: Int) {
    def damage = power * 1.5
    print(f"Колем копьём! Урон: {damage}")
    output damage
}
```

### Функции внутри pack

Функции особенно полезны в pack:
```
pack Warrior {
    init {
        def health = 100   // создаём ХП
        def strength = 15  
        def armor = 10     // и броню
    }

    func battleCry {
        print("For glory!")
        strength += 5
    }

    func takeDamage(damage: Int) {
        def real_damage = defend(armor, damage)  // вычисляем урон с учётом брони
        health -= real_damage  // и наносим реальный урон
    }
}
```

функции внтури паков кстати - называются методы, но это не имеет знаечния, поведение функций в паке и без не отличается

### Твоя первая боевая система!

Время создать что-то своё!

1. Выбери любимую игру
2. Подумай какие там есть действия:
   - Атаки
   - Способности
   - Взаимодействия
3. Создай функции для этих действий
4. Объедини их в боевую систему

Пример для Dark Souls:
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

А теперь твоя очередь! Создай функции для боевой системы из твоей любимой игры.

Запусти компилятор и проверь код - если увидишь "Build Success!" значит твоя боевая система готова к бою!

## Что дальше?

Теперь ты умеешь создавать отдельные действия. Но в играх нужны целые объекты - персонажи, предметы, монстры.
Для этого в Ryton есть pack! Давай научимся их создавать.

[Пакеты в Ryton →](./Packs.md)