import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib
import cairo
import psutil
from collections import deque

class RytonProfiler(Gtk.ApplicationWindow):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.set_title("Ryton Performance Monitor")
        self.set_default_size(1000, 800)

        # Тёмная тема
        self.colors = {
            'bg': (0.1, 0.1, 0.1),
            'grid': (0.2, 0.2, 0.2),
            'text': (0.8, 0.8, 0.8),
            'cpu': (0.8, 0.2, 0.2),
            'memory': (0.2, 0.4, 0.8),
            'disk': (0.2, 0.8, 0.4),
            'network': (0.8, 0.6, 0.2),
            'threads': (0.6, 0.2, 0.8)  # Purple color for threads
        }

        self.drawing_area = Gtk.DrawingArea()
        self.drawing_area.set_draw_func(self.draw)
        self.set_child(self.drawing_area)

        # Расширенные метрики
        self.metrics = {
            'cpu': deque(maxlen=100),
            'memory': deque(maxlen=100),
            'disk': deque(maxlen=100),
            'network': deque(maxlen=100),
            'threads': deque(maxlen=100)
        }

        GLib.timeout_add(100, self.update_metrics)

    def draw(self, area, cr, width, height):
        # Фон
        cr.set_source_rgb(*self.colors['bg'])
        cr.paint()

        # Сетка
        self.draw_grid(cr, width, height)
        
        # Графики
        section_height = height / len(self.metrics)
        for i, (name, data) in enumerate(self.metrics.items()):
            y_offset = i * section_height
            self.draw_metric(cr, data, name, width, section_height, y_offset)

    def draw_grid(self, cr, width, height):
        cr.set_source_rgb(*self.colors['grid'])
        for x in range(0, width, 50):
            cr.move_to(x, 0)
            cr.line_to(x, height)
        for y in range(0, height, 50):
            cr.move_to(0, y)
            cr.line_to(width, y)
        cr.stroke()

    def draw_metric(self, cr, data, name, width, height, offset):
        if not data:
            return

        # Заголовок метрики
        cr.set_source_rgb(*self.colors['text'])
        cr.set_font_size(20)
        cr.move_to(10, offset + 30)
        cr.show_text(f"{name.upper()}: {data[-1]:.1f}%")

        # График
        cr.set_source_rgb(*self.colors[name])
        cr.move_to(0, offset + height - data[0] * height/100)
        for i, v in enumerate(data):
            cr.line_to(i * (width/100), offset + height - v * height/100)
        cr.stroke()

    def update_metrics(self):
        self.metrics['cpu'].append(psutil.cpu_percent())
        self.metrics['memory'].append(psutil.Process().memory_percent())
        self.metrics['disk'].append(psutil.disk_usage('/').percent)
        self.metrics['network'].append(psutil.net_io_counters().bytes_sent % 100)
        self.metrics['threads'].append(len(psutil.Process().threads()))
        
        self.drawing_area.queue_draw()
        return True

class RytonProfilerApp(Gtk.Application):
    def __init__(self):
        super().__init__()
        self.connect('activate', self.on_activate)

    def on_activate(self, app):
        win = RytonProfiler(application=app)
        win.present()

def runprofile():
    app = RytonProfilerApp()
    app.run(None)
