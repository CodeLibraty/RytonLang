import math
from decimal import Decimal, getcontext

def fibonacci(self, n):
    """Вычисляет n-ное число Фибоначчи"""
    if n <= 0:
        return 0
    a, b = 0, 1
    for _ in range(n - 1):
        a, b = b, a + b
    return b
    
def factorial(self, n):
    """Вычисляет факториал с поддержкой больших чисел"""
    if n < 0:
        raise ValueError("Факториал отрицательного числа не определен")
    if n == 0:
        return 1
    return n * self.factorial(n - 1)
    
def prime_factors(self, n):
    """Возвращает список простых множителей числа"""
    factors = []
    d = 2
    while n > 1:
        while n % d == 0:
            factors.append(d)
            n //= d
        d += 1
        if d * d > n:
            if n > 1:
                factors.append(n)
            break
    return factors
    
def is_prime(self, n):
    """Проверяет, является ли число простым"""
    if n < 2:
        return False
    for i in range(2, int(math.sqrt(n)) + 1):
        if n % i == 0:
            return False
    return True
    
def gcd(self, a, b):
    """Находит наибольший общий делитель"""
    while b:
        a, b = b, a % b
    return a
    
def lcm(self, a, b):
    """Находит наименьшее общее кратное"""
    return abs(a * b) // self.gcd(a, b)
    
def precise_sqrt(self, x, precision=10):
    """Вычисляет корень с указанной точностью"""
    return Decimal(x).sqrt()
    
def round_to_significant(self, number, significant_digits):
    """Округляет число до значащих цифр"""
    return float(f"%.{significant_digits}g" % number)
    
def deg_to_rad(self, degrees):
    """Конвертирует градусы в радианы"""
    return degrees * math.pi / 180
    
def rad_to_deg(self, radians):
    """Конвертирует радианы в градусы"""
    return radians * 180 / math.pi
