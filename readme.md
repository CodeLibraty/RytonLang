# Ryton Programming Language

Ryton - современный язык программирования с инновационным синтаксисом и богатой стандартной библиотекой.

## Особенности

- Трансляция в Python код
- Возможность Компиляции и сборки проекта на Ryton в нативный код C через Nuitka
- Обширная стандартная библиотека
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
# изначально присутствует сборка под linux X86_64
```

Пример кода
```
module import {
    std.lib
}

func main {
    print('Hello World')
}

programm.start { 
	main()
}
```

Структура проект
```
RytonLang/
├── Interpritator/     # Ядро языка :полностью работает:
├── examples/          # Примеры кода :отсутсвует:
├── docs/             # Документация  :отсутсвует:
└── tools/            # Инструменты разработки :отсутсвует:
```

Лицензия
Copyright (c) 2024 DichRumpany team. См. [LICENSE](LICENSE) для деталей.

Команда
RejziDich - Lead Developer
DichRumpany team - Core Team

Контакты
GitHub: RejziDich/RytonLang
EMail:  rejzidich@gmail.com

Сообщество
Site project: ryton.vercel.app
Site team:    sitedrt.vercel.app
Discord:      https://discord.com/invite/D2hqwn94rs

