#!/bin/bash

NUITKA_OPTIONS="--jobs=10 --follow-imports --include-package=Interpritator \
--include-data-file=Interpritator/stdFunction.py=Interpritator/stdFunction.py \
--output-dir=build \
--nofollow-import-to=PyQt6 \
--nofollow-import-to=cython --nofollow-import-to=kivy --nofollow-import-to=kivymd \
--nofollow-import-to=PIL --nofollow-import-to=Interpritator.PyPyLang --nofollow-import-to=Interpritator.ZigLang \
--nofollow-import-to=Rich --nofollow-import-to=pygments \
--nofollow-import-to=Interpritator.std --show-modules --standalone"


echo Установка/проверка зависимостей
#pip install -r requirements.txt

echo Сборка через Nuitka
python3.13 -m nuitka $NUITKA_OPTIONS ryton.py

echo Копирование стандартных библиотек
cp -r Interpritator build/ryton.dist
echo Сборка завершена