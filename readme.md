# Ryton Programming Language

Ryton - современный и прагматичный язык программирования высокого уровня, который делает правильное простым, а сложное - понятным.

![Logo](card.png)

Ryton следует философии "хочешь лучше - делай проще", предоставляя разработчикам современные инструменты в максимально понятной форме. Все проекты на Ryton распространяются под специальной открытой лицензией, формируя экосистему качественного и прозрачного программного обеспечения.

Ryton - это язык для тех, кто ценит простоту, производительность и открытость в разработке профессионального ПО.

## Особенности

- Под капотом CPython 
- Возможность Компиляции и сборки проекта на Ryton в нативный код C через Nuitka
- Обширная стандартная библиотека
- Интгерация с другим языком [ZigLang](https://github.com/ziglang/zig) # действительно класный язык
- Чистый и интуитивный синтаксис
- Встроенная поддержка DSL
- Мощная система метапрограммирования
- Интеграция с другими языками

## Быстрый старт

```bash
# Установка (пока что только сборка из исходников)

git clone https://github.com/RejziDich/RytonLang
cd RytonLang
./build.sh

# Запуск примера
./dist/ryton file.ry
# изначально присутствует сборка под linux X86_64 в папке dist/ryton_launcher.dist/ryton :нужно запускать бинраник именно внутри этой папке потому-что все зависимости лежат там:
```

Пример кода
```
module import {
    std.UpIO
}

func main {
    print('Hello World')
}

main()
```

Структура проект
```
RytonLang/
├── Interpritator/     # Ядро языка :полностью функционирует:
├── examples/          # Примеры кода :в разработке:
├── docs/             # Документация  :в разработке:
└── tools/            # Инструменты разработки :в разработке:
```

Лицензия
Copyright (c) 2024 DichRumpany team. См. [LICENSE](LICENSE) для деталей.

Команда
- RejziDich - Lead Developer
- DichRumpany team - Core Team

Контакты
- GitHub: https://github.com/Rejzi-dich/RytonLang
- EMail:  rejzidich@gmail.com или rejzi@drt.com(нестабилен)

Сообщество
- Site project: ryton.vercel.app
- Site team:    sitedrt.vercel.app
- Discord:      https://discord.com/invite/D2hqwn94rs

