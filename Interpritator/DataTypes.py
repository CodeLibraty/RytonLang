from typing import *
import os

# Base Types rename
String = str
Int = int
Float = float
Bool = bool
List = list
Dict = dict
Set = set
Tuple = tuple

# Custom Types
class Money:
    def __init__(self, amount, currency='USD'):
        self.amount = float(amount)
        self.currency = currency
    
    def __add__(self, other):
        if self.currency != other.currency:
            raise ValueError("Different currencies")
        return Money(self.amount + other.amount, self.currency)
    
    def __str__(self):
        return f"{self.amount:.2f} {self.currency}"

class Time:
    def __init__(self, hours=0, minutes=0, seconds=0):
        self.seconds = hours * 3600 + minutes * 60 + seconds
    
    def __add__(self, other):
        return Time(seconds=self.seconds + other.seconds)
        
    def __str__(self):
        h = self.seconds // 3600
        m = (self.seconds % 3600) // 60
        s = self.seconds % 60
        return f"{h:02d}:{m:02d}:{s:02d}"

class Range:
    def __init__(self, start, end, step=1):
        self.start = start
        self.end = end
        self.step = step
        
    def __iter__(self):
        current = self.start
        while current < self.end:
            yield current
            current += self.step

class Version:
    def __init__(self, version_str):
        self.parts = [int(x) for x in version_str.split('.')]
    
    def __lt__(self, other):
        return self.parts < other.parts
        
    def __str__(self):
        return '.'.join(str(x) for x in self.parts)

class Color:
    def __init__(self, r, g, b, a=255):
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    
    def __str__(self):
        return f"#{self.r:02x}{self.g:02x}{self.b:02x}"
        
    @classmethod
    def from_hex(cls, hex_str):
        hex_str = hex_str.lstrip('#')
        return cls(*[int(hex_str[i:i+2], 16) for i in (0, 2, 4)])

class URL:
    def __init__(self, url_string):
        self.original = url_string
        parts = url_string.split('://')
        self.protocol = parts[0] if len(parts) > 1 else 'http'
        
        domain_path = parts[-1].split('/', 1)
        self.domain = domain_path[0]
        self.path = '/' + domain_path[1] if len(domain_path) > 1 else '/'
        
        self.query = {}
        if '?' in self.path:
            self.path, query_string = self.path.split('?')
            for param in query_string.split('&'):
                if '=' in param:
                    key, value = param.split('=')
                    self.query[key] = value
    
    def __str__(self):
        query = '?' + '&'.join(f"{k}={v}" for k,v in self.query.items()) if self.query else ''
        return f"{self.protocol}://{self.domain}{self.path}{query}"

class Path:
    def __init__(self, path_string):
        self.parts = path_string.replace('\\', '/').replace('~', f'{os.path.expanduser("~")}').strip('/').split('/')

    def __truediv__(self, other):
        if isinstance(other, str):
            return Path('/'.join(self.parts + [other]))
        return Path('/'.join(self.parts + other.parts))
        
    def parent(self):
        return Path('/'.join(self.parts[:-1]))
        
    def name(self):
        return self.parts[-1]
        
    def __str__(self):
        return '/' + '/'.join(self.parts)

class BigInt:
    def __init__(self, value):
        self.value = int(value)
        
    def __add__(self, other):
        return BigInt(self.value + other.value)
        
    def __mul__(self, other):
        return BigInt(self.value * other.value)

class Decimal:
    def __init__(self, value, precision=2):
        self.value = float(value)
        self.precision = precision
        
    def __str__(self):
        return f"{self.value:.{self.precision}f}"

class Vector:
    def __init__(self, *args):
        self.data = list(args)
        
    def __add__(self, other):
        return Vector(*[a + b for a, b in zip(self.data, other.data)])
        
    def dot(self, other):
        return sum(a * b for a, b in zip(self.data, other.data))

class Matrix:
    def __init__(self, rows):
        self.rows = rows
        
    def __mul__(self, other):
        if isinstance(other, Vector):
            return Vector(*[sum(a * b for a, b in zip(row, other.data)) 
                          for row in self.rows])

class Email:
    def __init__(self, address):
        self.user, self.domain = address.split('@')
        self.address = address
    
    def __str__(self):
        return self.address

class PhoneNumber:
    def __init__(self, number):
        self.number = ''.join(c for c in number if c.isdigit())
        self.formatted = f"+{self.number[0]} ({self.number[1:4]}) {self.number[4:7]}-{self.number[7:]}"

class UUID:
    def __init__(self):
        import random
        self.bytes = [random.randint(0, 255) for _ in range(16)]
        self.bytes[6] = (self.bytes[6] & 0x0f) | 0x40
        self.bytes[8] = (self.bytes[8] & 0x3f) | 0x80
        
    def __str__(self):
        hex_bytes = [f"{b:02x}" for b in self.bytes]
        return f"{'-'.join([''.join(hex_bytes[:4]), ''.join(hex_bytes[4:6]), ''.join(hex_bytes[6:8]), ''.join(hex_bytes[8:10]), ''.join(hex_bytes[10:])])}"

class IPAddress:
    def __init__(self, ip):
        self.octets = [int(x) for x in ip.split('.')]
        
    def __str__(self):
        return '.'.join(str(x) for x in self.octets)
        
    def in_subnet(self, subnet):
        net, bits = subnet.split('/')
        net_octets = [int(x) for x in net.split('.')]
        mask = (1 << 32) - (1 << (32 - int(bits)))
        ip_int = sum(octet << (24-i*8) for i, octet in enumerate(self.octets))
        net_int = sum(octet << (24-i*8) for i, octet in enumerate(net_octets))
        return (ip_int & mask) == (net_int & mask)

class Temperature:
    def __init__(self, celsius):
        self.celsius = float(celsius)
        
    def to_fahrenheit(self):
        return self.celsius * 9/5 + 32
        
    def to_kelvin(self):
        return self.celsius + 273.15

class GeoPoint:
    def __init__(self, lat, lon):
        self.lat = float(lat)
        self.lon = float(lon)
        
    def distance_to(self, other):
        from math import radians, sin, cos, sqrt, atan2
        R = 6371  # радиус Земли
        lat1, lon1 = radians(self.lat), radians(self.lon)
        lat2, lon2 = radians(other.lat), radians(other.lon)
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
        c = 2 * atan2(sqrt(a), sqrt(1-a))
        return R * c
