import pygame
import os
os.environ['PYGAME_HIDE_SUPPORT_PROMPT'] = "hide"

# RyG lib

@staticmethod
def ryg_init():
    # Инициализация Pygame
    pygame.init()

@staticmethod
def screen_mode(width: int, height: int):
        # Установка режима отображения
    pygame.display.set_mode((width, height))

@staticmethod
def screen_caption(title: str):
        # Установка заголовка окна
    pygame.display.set_caption(title)

@staticmethod
def draw_rect(color: tuple[int, int, int], rect: tuple[int, int, int, int]):
        # Отрисовка прямоугольника
    screen = pygame.display.get_surface()
    pygame.draw.rect(screen, color, rect)

@staticmethod
def flip():
        # Обновление экрана
    pygame.display.flip()

@staticmethod
def end_game():
        # Завершение Pygame
    pygame.quit()
