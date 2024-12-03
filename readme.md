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
# изначально присутствует сборка под linux X86_64 в папке dist/ryton_launcher.dist/ryton :нужно запускать бинраник именно внутри этой папке потому-что все зависимости лежат там:
```

Пример кода
```
module import {
    std.lib
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

