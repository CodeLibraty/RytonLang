from rpyc.utils.server import OneShotServer

import rpyc
import os

try: from .Core import *  # Импортируем всё
except: from Core import *

class QUIService(rpyc.Service):
    def __init__(self):
        self.qui = QuantUI(None)

    def exposed_create_app(self):
        return self.qui.create_app()
 
    def exposed_create_widget(self, widget_type, **kwargs):
        return self.qui.create_widget(widget_type, **kwargs)

    def exposed_add_widget(self, parent, child):
        return self.qui.add_widget(parent, child)

    def exposed_set_root(self, widget):
        self.qui.set_root(widget)

    def exposed_set_text(self, widget, text):
        widget.setText(text)

    def exposed_setStyle(self, widget, style):
        self.qui.setStyle(widget, style)

    def exposed_bind(self, widget, callback):
        return self.qui.bind(widget, callback)

    def exposed_run(self):
        return self.qui.run_app()

def startService():
    server = OneShotServer(QUIService(), port=18861, protocol_config={
        'allow_public_attrs': True,
        'allow_setattr': True,
    })
    server.start()

if __name__ == '__main__':
    startService()