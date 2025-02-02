#!/bin/bash

NUITKA_OPTIONS="--jobs=10 --follow-imports --include-package=Interpritator \
--include-data-file=Interpritator/stdFunction.py=Interpritator/stdFunction.py \
--output-dir=dist --nofollow-import-to=numpy --nofollow-import-to=ray --nofollow-import-to=dask --nofollow-import-to=PyQt6 --nofollow-import-to=numba --nofollow-import-to=cython --include-module=kivy --include-module=kivymd --include-module=jpype --standalone"

echo Установка/проверка зависимостей
#pip install -r requirements.txt

echo Сборка через Nuitka
python3 -m nuitka $NUITKA_OPTIONS ryton.py

echo Копирование стандартных библиотек
cp -r Interpritator dist/ryton.dist
echo Сборка завершена