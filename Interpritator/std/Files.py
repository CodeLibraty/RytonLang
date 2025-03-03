import ctypes

# Загружаем нативную библиотеку
_lib = ctypes.CDLL("/usr/local/lib/ryton/Interpritator/std/Files.so")
_lib.listDir.restype = ctypes.c_int

def write_file(path: str, content: str):
    result = _lib.writeFile(str(path).encode(), content.encode())
    return result == 0

def read_file(path: str) -> str:
    buffer_size = 1024 * 1024  # 1MB buffer
    buffer = ctypes.create_string_buffer(buffer_size)
    bytes_read = _lib.readFile(str(path).encode(), buffer, buffer_size)
    if bytes_read > 0:
        return buffer.raw[:bytes_read].decode()
    return ""

def list_dir(path: str = ".") -> list:
    buffer_size = 4096
    buffer = ctypes.create_string_buffer(buffer_size)
    bytes_read = _lib.listDir(str(path).encode(), buffer, buffer_size)
    
    if bytes_read <= 0:
        return []
        
    # Split buffer by null bytes to get file names
    raw_data = buffer.raw[:bytes_read]
    files = [name.decode() for name in raw_data.split(b'\0') if name]
    return files


def create_dir(path: str):
    return _lib.createDir(path.encode())

def remove_dir(path: str):
    return _lib.removeDir(path.encode())

def copy_file(src: str, dst: str):
    return _lib.copyFile(src.encode(), dst.encode())

def move_file(src: str, dst: str):
    return _lib.moveFile(src.encode(), dst.encode())

def delete_file(path: str):
    return _lib.deleteFile(path.encode())

def file_info(path: str) -> dict:
    stat = _lib.fileInfo(path.encode())
    return {
        "size": stat.size,
        "modified": stat.mtime,
        "accessed": stat.atime,
        "created": stat.ctime
    }

def exists(path: str) -> bool:
    return bool(_lib.fileExists(path.encode()))

def append_to_file(path: str, content: str):
    return _lib.appendFile(path.encode(), content.encode())

def set_file_perm(path: str, perms: int):
    return _lib.setFilePerms(path.encode(), perms)

def is_file(path: str) -> bool:
    return bool(_lib.isFile(path.encode()))

def is_dir(path: str) -> bool:
    return bool(_lib.isDir(path.encode()))
