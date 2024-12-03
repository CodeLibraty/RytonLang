import tempfile

def temp_dir():
    return tempfile.gettempdir()

def create_temp_file():
    return tempfile.mkstemp()

def create_temp_dir():
    return tempfile.mkdtemp()