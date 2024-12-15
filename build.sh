#!/bin/bash

NUITKA_OPTIONS="--jobs=4 --follow-imports --include-package=Interpritator \
--include-data-file=Interpritator/stdFunction.py=Interpritator/stdFunction.py \
--output-dir=dist --nofollow-import-to=numpy --nofollow-import-to=numba --nofollow-import-to=cython --nofollow-import-to=dask --nofollow-import-to=ray --include-module=ray --include-module=dask --standalone"

echo Установка/проверка зависимостей
pip install -r requirements.txt

echo Сборка через Nuitka
python -m nuitka $NUITKA_OPTIONS ryton_launcher.py

echo Копирование стандартных библиотек
cp -r Interpritator/std dist/ryton_launcher.dist/Interpritator/
echo Сборка завершена