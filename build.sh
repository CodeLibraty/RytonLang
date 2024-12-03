#!/bin/bash

NUITKA_OPTIONS="--follow-imports --include-package=Interpritator \
--include-data-file=Interpritator/stdFunction.py=Interpritator/stdFunction.py \
--output-dir=dist --standalone"

echo Установка/проверка зависимостей
pip install -r requirements.txt

#echo Копирование дополнительных файлов
#cp -r Interpritator/langs dist/Interpritator/
#cp -r Interpritator/std dist/Interpritator/

echo Сборка через Nuitka
python -m nuitka $NUITKA_OPTIONS ryton_launcher.py
