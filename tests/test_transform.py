from rich.progress import Progress, SpinnerColumn
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

from typing import Any, Dict

import inspect
import time
import sys
import os

# Добавляем корневую директорию проекта в PYTHONPATH
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from Interpritator.SyntaxTransformer import *

console = Console()


class TestClassTransformer:
    def test_transform_pack(self):
        transformer = ClassTransformer()
        code = "pack User(BaseUser) :"
        result = transformer.transform_pack(code)
        assert result == "class User(BaseUser):"

    def test_transform_slots(self):
        transformer = ClassTransformer()
        code = "slots {'name', 'age'}"
        result = transformer.transform_slots(code) 
        assert result == "__slots__ = ('name', 'age')"

class TestFunctionTransformer:
    def test_transform_lambda(self):
        transformer = FunctionTransformer()
        code = "func(x, y) { x + y }"
        result = transformer.transform_lambda(code)
        assert result == "lambda x, y: x + y"

    def test_transform_decorators(self):
        transformer = FunctionTransformer()
        code = "<cache(128)>\nfunc test() {"
        result = transformer.transform_decorators(code)
        assert "@lru_cache(maxsize=128)" in result

class TestControlFlowTransformer:
    def test_transform_switch(self):
        transformer = ControlFlowTransformer()
        code = """
        switch value {
            | 1 => print("One")
            | 2 => print("Two")
            else => print("Other")
        }
        """
        result = transformer.transform_switch(code)
        assert "def _pattern_match():" in result

class TestModuleTransformer:
    def test_transform_zig_tags(self):
        transformer = ModuleTransformer()
        code = "#Zig(start)\nconst x = 1;\n#Zig(end: result)"
        result = transformer.transform_zig_tags(code)
        assert "zig_bridge = ZigBridge()" in result

def get_test_case(method_name: str) -> str:
    """Возвращает тестовый код для конкретного метода"""
    test_cases = {
        'transform_pack':       'pack TestClass() :',
        'transform_func':       'func test() :',
        'transform_switch':     'switch value { | 1 => print("One") }',
        'transform_slots':      'slots {"name", "age"}',
        'transform_init':       'init :',
        'transform_event':      'event temperature -> high { alert("Too hot!") }',
        'transform_lambda':     'func(x, y) { x + y }',
        'transform_decorators': '<cache(128)>\nfunc test() {',
        'transform_private':    'private func test { print("test") }',
        'transform_data':       'data User { name: String, age: Int }',
    }
    return test_cases.get(method_name, '')

def get_expected_result(method_name: str) -> str:
    """Возвращает ожидаемый результат для метода"""
    expected_results = {
        'transform_pack':       'class TestClass:',
        'transform_func':       'def test():',
        'transform_switch':     'def _pattern_match():',
        'transform_slots':      '__slots__ = ("name", "age")',
        'transform_init':       'def __init__(self):',
        'transform_event':      'start_event(temperature, high',
        'transform_lambda':     'lambda x, y: x + y',
        'transform_decorators': '@lru_cache(maxsize=128)',
        'transform_private':    'def _test():',
        'transform_data':       '@dataclass\nclass User:',
    }
    return expected_results.get(method_name, '')

def validate_result(result: str, method_name: str) -> bool:
    """Проверяет корректность результата трансформации"""
    validations = {
        'transform_pack':       lambda r: 'class' in r,
        'transform_func':       lambda r: 'def' in r,
        'transform_switch':     lambda r: '_pattern_match' in r,
        'transform_slots':      lambda r: '__slots__' in r,
        'transform_init':       lambda r: '__init__' in r,
        'transform_event':      lambda r: 'start_event' in r,
        'transform_lambda':     lambda r: 'lambda' in r,
        'transform_decorators': lambda r: '@' in r,
        'transform_private':    lambda r: '_' in r,
        'transform_data':       lambda r: '@dataclass' in r,
    }
    validator = validations.get(method_name, lambda r: True)
    return validator(result)

def run_all_transformer_tests():
    os.system("clear")
    # Собираем все трансформеры
    transformers = {
        'Class':       ClassTransformer(),
        'Function':    FunctionTransformer(),
        'ControlFlow': ControlFlowTransformer(),
        'Module':      ModuleTransformer(),
        'Expression':  ExpressionTransformer(),
        'Data':        DataTransformer()
    }
    
    results: Dict[str, Dict[str, Any]] = {}
    total_tests = 0
    failed_tests = []

    # Прогресс бар
    with Progress(
        SpinnerColumn(),
        *Progress.get_default_columns(),
        transient=True
    ) as progress:
        task = progress.add_task("[cyan]Тестирование...", total=None)
        
        # Проходим по каждому трансформеру
        for name, transformer in transformers.items():
            results[name] = {'passed': 0, 'failed': 0, 'methods': {}}
            
            # Получаем все методы трансформера
            methods = inspect.getmembers(transformer, predicate=inspect.ismethod)
            for method_name, method in methods:
                if method_name.startswith('transform_'):
                    total_tests += 1
                    try:
                        # Запускаем тест
                        start_time = time.time()
                        method_result = method(get_test_case(method_name))
                        execution_time = time.time() - start_time
                        
                        # Проверяем результат
                        if validate_result(method_result, method_name):
                            results[name]['passed'] += 1
                            results[name]['methods'][method_name] = {
                                'status': 'PASS',
                                'time': execution_time
                            }
                        else:
                            results[name]['failed'] += 1
                            failed_tests.append(f"{name}.{method_name}")
                            results[name]['methods'][method_name] = {
                                'status': 'FAIL',
                                'time': execution_time
                            }
                    except Exception as e:
                        results[name]['failed'] += 1
                        failed_tests.append(f"{name}.{method_name}")
                        results[name]['methods'][method_name] = {
                            'status': 'ERROR',
                            'error': str(e)
                        }

    # Вывод результатов
    console.clear()
    
    # Создаем таблицу результатов
    table = Table(show_header=True, header_style="bold magenta")
    table.add_column("Трансформер")
    table.add_column("Успешно")
    table.add_column("Провалено")
    table.add_column("Время")
    
    total_passed = 0
    total_failed = 0
    
    for name, result in results.items():
        passed = result['passed']
        failed = result['failed']
        total_passed += passed
        total_failed += failed
        
        # Добавляем строку в таблицу
        table.add_row(
            name,
            f"[green]{passed}[/green]",
            f"[red]{failed}[/red]",
            f"{sum(m['time'] for m in result['methods'].values() if 'time' in m):.3f}s"
        )

    # Выводим общую статистику
    console.print(Panel(table, title="Результаты тестирования"))
    
    if failed_tests:
        console.print("\n[red]Проваленные тесты:[/red]")
        for test in failed_tests:
            console.print(f"❌ {test}")

    # Детальный отчет об ошибках
    if failed_tests:
        console.print("\n[red bold]Детальный отчет об ошибках:[/red bold]")
        for name, result in results.items():
            failed_methods = {k: v for k, v in result['methods'].items() 
                            if v['status'] in ['FAIL', 'ERROR']}
            
            if failed_methods:
                console.print(f"\n[yellow]Трансформер: {name}[/yellow]")
                for method_name, data in failed_methods.items():
                    console.print(f"\n🔍 Метод: {method_name}")
                    console.print("  📥 Входные данные:", get_test_case(method_name))
                    console.print(f"  📋 Ожидаемый результат: {get_expected_result(method_name)}")
                    
                    if data['status'] == 'ERROR':
                        console.print(f"  ❌ Ошибка: {data['error']}")
                    else:
                        console.print(f"  ⚠️ Полученный результат: {data.get('actual_result', 'Нет данных')}")

    # Итоговая статистика
    success_rate = (total_passed / total_tests) * 100
    console.print(f"\nВсего тестов: {total_tests}")
    console.print(f"Успешно: [green]{total_passed}[/green]")
    console.print(f"Провалено: [red]{total_failed}[/red]")
    console.print(f"Успешность: [{'green' if success_rate > 80 else 'red'}]{success_rate:.1f}%[/]")


if __name__ == '__main__':
    run_all_transformer_tests()

