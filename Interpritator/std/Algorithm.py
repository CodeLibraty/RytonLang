import math
import random
from functools import lru_cache

def bubble_sort(arr):
    """ Сортировка пузырьком""" 
    n = len(arr)
    for i in range(n):
        for j in range(0, n - i - 1):
            if arr[j] > arr[j + 1]:
                arr[j], arr[j + 1] = arr[j + 1], arr[j]
    return arr

def quick_sort(arr):
    """ Быстрая сортировка""" 
    if len(arr) <= 1:
        return arr
    pivot = arr[len(arr) // 2]
    left = [x for x in arr if x < pivot]
    middle = [x for x in arr if x == pivot]
    right = [x for x in arr if x > pivot]
    return quick_sort(left) + middle + quick_sort(right)

""" Бинарный поиск""" 
@lru_cache(maxsize=128)
def binary_search(arr, target):
    left, right = 0, len(arr) - 1
    while left <= right:
        mid = (left + right) // 2
        if arr[mid] == target:
            return mid
        elif arr[mid] < target:
            left = mid + 1
        else:
            right = mid - 1
    return -1

""" Алгоритм Дейкстры (для графа, представленного списком смежности)""" 
def dijkstra(graph, start):
    distances = {node: float('infinity') for node in graph}
    distances[start] = 0
    unvisited = list(graph.keys())
    
    while unvisited:
        current = min(unvisited, key=lambda node: distances[node])
        unvisited.remove(current)
        
        for neighbor, weight in graph[current].items():
            distance = distances[current] + weight
            if distance < distances[neighbor]:
                distances[neighbor] = distance
    
    return distances

""" Решето Эратосфена""" 
@lru_cache(maxsize=128)
def sieve_of_eratosthenes(n):
    primes = [True] * (n + 1)
    primes[0] = primes[1] = False
    for i in range(2, int(n**0.5) + 1):
        if primes[i]:
            for j in range(i*i, n + 1, i):
                primes[j] = False
    return [i for i in range(n + 1) if primes[i]]

""" Алгоритм Кнута-Морриса-Пратта (КМП)""" 
def kmp_search(text, pattern):
    def compute_lps(pattern):
        lps = [0] * len(pattern)
        length = 0
        i = 1
        while i < len(pattern):
            if pattern[i] == pattern[length]:
                length += 1
                lps[i] = length
                i += 1
            else:
                if length != 0:
                    length = lps[length - 1]
                else:
                    lps[i] = 0
                    i += 1
        return lps

    lps = compute_lps(pattern)
    i = j = 0
    results = []
    while i < len(text):
        if pattern[j] == text[i]:
            i += 1
            j += 1
        if j == len(pattern):
            results.append(i - j)
            j = lps[j - 1]
        elif i < len(text) and pattern[j] != text[i]:
            if j != 0:
                j = lps[j - 1]
            else:
                i += 1
    return results

""" Алгоритм Флойда-Уоршелла""" 
def floyd_warshall(graph):
    dist = {(u, v): float('inf') if u != v else 0 for u in graph for v in graph}
    for u in graph:
        for v, w in graph[u].items():
            dist[u, v] = w
    for k in graph:
        for i in graph:
            for j in graph:
                dist[i, j] = min(dist[i, j], dist[i, k] + dist[k, j])
    return dist

""" Алгоритм Краскала""" 
def kruskal(graph):
    def find(parent, i):
        if parent[i] == i:
            return i
        return find(parent, parent[i])

    def union(parent, rank, x, y):
        xroot = find(parent, x)
        yroot = find(parent, y)
        if rank[xroot] < rank[yroot]:
            parent[xroot] = yroot
        elif rank[xroot] > rank[yroot]:
            parent[yroot] = xroot
        else:
            parent[yroot] = xroot
            rank[xroot] += 1

    edges = [(w, u, v) for u in graph for v, w in graph[u].items()]
    edges.sort()
    parent = {node: node for node in graph}
    rank = {node: 0 for node in graph}
    mst = []

    for w, u, v in edges:
        x = find(parent, u)
        y = find(parent, v)
        if x != y:
            mst.append((u, v, w))
            union(parent, rank, x, y)

    return mst

""" Алгоритм Прима""" 
def prim(graph):
    start_vertex = next(iter(graph))
    mst = []
    visited = {start_vertex}
    edges = [(cost, start_vertex, to) for to, cost in graph[start_vertex].items()]
    heapq.heapify(edges)

    while edges:
        cost, frm, to = heapq.heappop(edges)
        if to not in visited:
            visited.add(to)
            mst.append((frm, to, cost))
            for next_to, next_cost in graph[to].items():
                if next_to not in visited:
                    heapq.heappush(edges, (next_cost, to, next_to))

    return mst

""" Поиск в глубину (DFS)""" 
def dfs(graph, start, visited=None):
    if visited is None:
        visited = set()
    visited.add(start)
    for next in graph[start] - visited:
        dfs(graph, next, visited)
    return visited

""" Поиск в ширину (BFS)""" 
from collections import deque

def bfs(graph, start):
    visited = set([start])
    queue = deque([start])
    while queue:
        vertex = queue.popleft()
        for neighbour in graph[vertex]:
            if neighbour not in visited:
                visited.add(neighbour)
                queue.append(neighbour)
    return visited

""" Алгоритм Кадане (максимальная подпоследовательность)""" 
def kadane(arr):
    max_current = max_global = arr[0]
    for i in range(1, len(arr)):
        max_current = max(arr[i], max_current + arr[i])
        if max_current > max_global:
            max_global = max_current
    return max_global

""" Алгоритм Форда-Фалкерсона (максимальный поток)""" 
def ford_fulkerson(graph, source, sink):
    def bfs(graph, s, t, parent):
        visited = {s}
        queue = deque([s])
        while queue:
            u = queue.popleft()
            for v in graph[u]:
                if v not in visited and graph[u][v] > 0:
                    queue.append(v)
                    visited.add(v)
                    parent[v] = u
                    if v == t:
                        return True
        return False

    parent = {}
    max_flow = 0
    while bfs(graph, source, sink, parent):
        path_flow = float("Inf")
        s = sink
        while s != source:
            path_flow = min(path_flow, graph[parent[s]][s])
            s = parent[s]
        max_flow += path_flow
        v = sink
        while v != source:
            u = parent[v]
            graph[u][v] -= path_flow
            graph[v][u] += path_flow
            v = parent[v]
    return max_flow

""" Алгоритм Хаффмана""" 
import heapq
from collections import defaultdict

def huffman_encoding(data):
    frequency = defaultdict(int)
    for symbol in data:
        frequency[symbol] += 1
    heap = [[weight, [symbol, ""]] for symbol, weight in frequency.items()]
    heapq.heapify(heap)
    while len(heap) > 1:
        lo = heapq.heappop(heap)
        hi = heapq.heappop(heap)
        for pair in lo[1:]:
            pair[1] = '0' + pair[1]
        for pair in hi[1:]:
            pair[1] = '1' + pair[1]
        heapq.heappush(heap, [lo[0] + hi[0]] + lo[1:] + hi[1:])
    return sorted(heapq.heappop(heap)[1:], key=lambda p: (len(p[-1]), p))

""" Алгоритм Ли (волновой алгоритм)""" 
def lee_algorithm(maze, start, end):
    queue = deque([[start]])
    seen = set([start])
    while queue:
        path = queue.popleft()
        x, y = path[-1]
        if (x, y) == end:
            return path
        for x2, y2 in ((x+1,y), (x-1,y), (x,y+1), (x,y-1)):
            if 0 <= x2 < len(maze) and 0 <= y2 < len(maze[0]) and maze[x2][y2] != '#' and (x2, y2) not in seen:
                queue.append(path + [(x2, y2)])
                seen.add((x2, y2))

""" Алгоритм Косарайю (поиск сильно связанных компонент)""" 
def kosaraju(graph):
    def dfs(v, visited, stack):
        visited.add(v)
        for u in graph[v]:
            if u not in visited:
                dfs(u, visited, stack)
        stack.append(v)

    def dfs_reverse(v, visited, component):
        visited.add(v)
        component.append(v)
        for u in reversed_graph[v]:
            if u not in visited:
                dfs_reverse(u, visited, component)

    stack = []
    visited = set()
    for v in graph:
        if v not in visited:
            dfs(v, visited, stack)

    reversed_graph = {v: [] for v in graph}
    for v in graph:
        for u in graph[v]:
            reversed_graph[u].append(v)

    visited.clear()
    components = []
    while stack:
        v = stack.pop()
        if v not in visited:
            component = []
            dfs_reverse(v, visited, component)
            components.append(component)

    return components

""" Алгоритм Евклида (НОД)""" 
def gcd(a, b):
    while b:
        a, b = b, a % b
    return a

""" Решето Аткина""" 
def sieve_of_atkin(limit):
    sieve = [False] * (limit + 1)
    sieve[2], sieve[3] = True, True
    x, y, n = 1, 1, 0
    
    while x * x <= limit:
        y = 1
        while y * y <= limit:
            n = 4 * x * x + y * y
            if n <= limit and (n % 12 == 1 or n % 12 == 5):
                sieve[n] = not sieve[n]
            n = 3 * x * x + y * y
            if n <= limit and n % 12 == 7:
                sieve[n] = not sieve[n]
            n = 3 * x * x - y * y
            if x > y and n <= limit and n % 12 == 11:
                sieve[n] = not sieve[n]
            y += 1
        x += 1
    
    for i in range(5, int(limit**0.5) + 1):
        if sieve[i]:
            for j in range(i * i, limit + 1, i * i):
                sieve[j] = False
    
    return [x for x in range(2, limit + 1) if sieve[x]]

""" Алгоритм Рабина-Карпа""" 
def rabin_karp(text, pattern):
    d = 256  # количество символов в алфавите
    q = 101  # простое число
    m, n = len(pattern), len(text)
    p, t, h, results = 0, 0, 1, []

    for i in range(m - 1):
        h = (h * d) % q

    for i in range(m):
        p = (d * p + ord(pattern[i])) % q
        t = (d * t + ord(text[i])) % q

    for i in range(n - m + 1):
        if p == t:
            if text[i:i+m] == pattern:
                results.append(i)
        if i < n - m:
            t = (d * (t - ord(text[i]) * h) + ord(text[i + m])) % q
            if t < 0:
                t += q

    return results

""" Алгоритм Бойера-Мура""" 
def boyer_moore(text, pattern):
    def build_bad_char_heuristic(pattern):
        bad_char = defaultdict(lambda: -1)
        for i in range(len(pattern)):
            bad_char[pattern[i]] = i
        return bad_char

    m, n = len(pattern), len(text)
    bad_char = build_bad_char_heuristic(pattern)
    results = []
    i = 0

    while i <= n - m:
        j = m - 1
        while j >= 0 and pattern[j] == text[i + j]:
            j -= 1
        if j < 0:
            results.append(i)
            i += (m - bad_char[text[i + m]] if i + m < n else 1)
        else:
            i += max(1, j - bad_char[text[i + j]])

    return results

""" Алогоритм max""" 
@lru_cache(maxsize=128)
def max(*args, key=None):
    if len(args) == 0:
        raise ValueError("max() arg is an empty sequence")
    
    if len(args) == 1 and isinstance(args[0], (list, tuple)):
        args = args[0]
    
    if key is None:
        max_value = args[0]
        for arg in args[1:]:
            if arg > max_value:
                max_value = arg
    else:
        max_value = args[0]
        max_key = key(args[0])
        for arg in args[1:]:
            k = key(arg)
            if k > max_key:
                max_value = arg
                max_key = k
    
    return max_value
