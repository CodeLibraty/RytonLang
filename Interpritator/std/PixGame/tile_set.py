# Создание простого tileset.py
import arcade

def create_terrain_tileset(output_path='terrain_tileset.png'):
    """
    Создание базового тайлсета для карты
    """
    # Создаем изображение 512x512 пикселей (16x16 тайлов)
    image = arcade.create_filled_image(
        512, 512, 
        arcade.color.LIGHT_GREEN
    )
    
    # Сохраняем изображение
    arcade.save_image(output_path, image)

# Вызов функции для генерации тайлсета
create_terrain_tileset()
