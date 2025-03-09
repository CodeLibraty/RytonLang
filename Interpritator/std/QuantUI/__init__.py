import rpyc

def connect():
    return rpyc.connect("localhost", 18861, config={
        'sync_request_timeout': None,
        'allow_public_attrs': True
    })