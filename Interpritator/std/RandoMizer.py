from random import *
import time

def range_float(self, start, end, precision=2):
    """Генерирует случайное float число с указанной точностью"""
    val = self.random.uniform(start, end)
    return round(val, precision)

def weighted_choice(self, choices, weights):
    """Выбор с весами из списка"""
    return choices[self.random.choices(range(len(choices)), weights=weights)[0]]

def unique_list(self, start, end, count):
    """Генерирует список уникальных чисел"""
    return self.random.sample(range(start, end), count)
    
def shuffle_weighted(self, items, weights):
    """Перемешивание с учетом весов"""
    pairs = list(zip(items, weights))
    self.random.shuffle(pairs)
    return [item for item, _ in pairs]
    
def probability(self, percentage):
    """Возвращает True с указанной вероятностью в процентах"""
    return self.random.random() * 100 < percentage
    
def string(self, length, chars="abcdefghijklmnopqrstuvwxyz0123456789"):
    """Генерирует случайную строку"""
    return ''.join(self.random.choice(chars) for _ in range(length))

