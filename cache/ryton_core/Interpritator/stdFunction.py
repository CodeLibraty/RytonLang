import csv
import rich
from rich.table import Table as RichTable
from rich.console import Console
from typing import List, Dict, Any, Callable
from PackageSystem import PackageSystem

class Table:
    def __init__(self):
        self.rows = []
        self.headers = []
        self.styles = {}
        self.console = Console()

    def create(self, headers: List[str]) -> 'Table':
        self.headers = headers
        return self

    def add_row(self, row: List[Any]) -> None:
        self.rows.append(row)

    def add_rows(self, rows: List[List[Any]]) -> None:
        self.rows.extend(rows)

    def style(self, options: Dict[str, str]) -> None:
        self.styles = {
            'border': options.get('border', '│'),
            'header_color': options.get('header_color', 'blue'),
            'row_color': options.get('row_color', 'white'),
            'alignment': options.get('alignment', 'left')
        }

    def from_csv(self, filepath: str) -> None:
        with open(filepath, 'r', encoding='utf-8') as file:
            reader = csv.reader(file)
            self.headers = next(reader)
            self.rows = list(reader)

    def to_csv(self, filepath: str) -> None:
        with open(filepath, 'w', encoding='utf-8', newline='') as file:
            writer = csv.writer(file)
            writer.writerow(self.headers)
            writer.writerows(self.rows)

    def filter(self, column: str, condition: Callable) -> None:
        col_index = self.headers.index(column)
        self.rows = [row for row in self.rows if condition(row[col_index])]

    def sort(self, column: str, reverse: bool = False) -> None:
        col_index = self.headers.index(column)
        self.rows.sort(key=lambda x: x[col_index], reverse=reverse)

    def get_column(self, column: str) -> List[Any]:
        col_index = self.headers.index(column)
        return [row[col_index] for row in self.rows]

    def update_column(self, column: str, values: List[Any]) -> None:
        col_index = self.headers.index(column)
        for i, value in enumerate(values):
            self.rows[i][col_index] = value

    def add_column(self, name: str, values: List[Any]) -> None:
        self.headers.append(name)
        for i, row in enumerate(self.rows):
            row.append(values[i])

    def remove_column(self, column: str) -> None:
        col_index = self.headers.index(column)
        self.headers.pop(col_index)
        for row in self.rows:
            row.pop(col_index)

    def aggregate(self, column: str, func: Callable) -> Any:
        return func(self.get_column(column))

    def display(self) -> None:
        table = RichTable(show_header=True)
        
        for header in self.headers:
            table.add_column(header, style=self.styles.get('header_color'))
        
        for row in self.rows:
            table.add_row(*[str(cell) for cell in row], style=self.styles.get('row_color'))
        
        self.console.print(table)

    def to_html(self, filepath: str) -> None:
        html = ["<table border='1'>", "<tr>"]
        
        html.extend(f"<th>{header}</th>" for header in self.headers)
        html.append("</tr>")
        
        for row in self.rows:
            html.append("<tr>")
            html.extend(f"<td>{cell}</td>" for cell in row)
            html.append("</tr>")
        
        html.append("</table>")
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write('\n'.join(html))

    def merge(self, other_table: 'Table', on: str) -> None:
        self_col_index = self.headers.index(on)
        other_col_index = other_table.headers.index(on)
        
        new_headers = self.headers + [h for h in other_table.headers if h != on]
        new_rows = []
        
        for self_row in self.rows:
            key = self_row[self_col_index]
            for other_row in other_table.rows:
                if other_row[other_col_index] == key:
                    new_row = self_row + [cell for i, cell in enumerate(other_row) if other_table.headers[i] != on]
                    new_rows.append(new_row)
        
        self.headers = new_headers
        self.rows = new_rows

    def stats(self, column: str) -> Dict[str, Any]:
        values = [float(x) for x in self.get_column(column) if str(x).replace('.','').isdigit()]
        if not values:
            return {'mean': 0, 'min': 0, 'max': 0, 'count': 0}
        return {
            'mean': sum(values) / len(values),
            'min': min(values),
            'max': max(values),
            'count': len(values)
        }

class Parallel:
    def parallel(self, *funcs):
        threads = []
        results = {}
        
        def wrapper(func_name, func):
            results[func_name] = func()
        
        for func in funcs:
            thread = threading.Thread(target=wrapper, args=(func.__name__, func))
            threads.append(thread)
            thread.start()
            
        for thread in threads:
            thread.join()
            
        return results

class Memory:
    def allocate(name, value):
        sharpy.memory_manager.allocate(name, value)

    def free(name):
        sharpy.memory_manager.free(name)

    def get_obj(name):
        return sharpy.memory_manager.get(name)

    def mem_usage():
        return sharpy.memory_manager.memory_usage()

    def obj_count():
        return sharpy.memory_manager.object_count()

    def gc_collect():
        return gc.collect()

    def set_gc_threshold(threshold0, threshold1=None, threshold2=None):
        if threshold1 is None and threshold2 is None:
            gc.set_threshold(threshold0)
        elif threshold2 is None:
            gc.set_threshold(threshold0, threshold1)
        else:
            gc.set_threshold(threshold0, threshold1, threshold2)

    def get_gc_threshold():
        return gc.get_threshold()

    def enable_gc():
        gc.enable()

    def disable_gc():
        gc.disable()

    def is_gc_enabled():
        return gc.isenabled()