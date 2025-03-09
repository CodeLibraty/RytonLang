import rpyc
from rpyc.utils.server import ThreadedServer
import os

from kivy.app import App
from kivy.clock import mainthread
from kivy.config import Config
Config.set('graphics', 'window_state', 'visible')
from App import *  # Импортируем всё
import threading
import time

class RuVixService(rpyc.Service):
    def __init__(self):
        self.ruvix = RuVix(None)
        self.app = None
        self.running = True
        
    @mainthread
    def exposed_create_app(self):
        return self.ruvix.create_app()
        
    @mainthread 
    def exposed_create_widget(self, widget_type, **kwargs):
        return self.ruvix.create_widget(widget_type, **kwargs)
        
    @mainthread
    def exposed_add_widget(self, parent, child):
        return self.ruvix.add_widget(parent, child)

    @mainthread
    def exposed_set_root(self, widget):
        self.ruvix.set_root(widget)

    @mainthread
    def exposed_run(self):
        app = App.get_running_app()
        app.run()
        
        # Keep the server alive
        while self.running:
            time.sleep(0.1)


server = ThreadedServer(RuVixService, port=18861)
server.start()