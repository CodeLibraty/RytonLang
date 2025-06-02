import std/[os, strutils, strformat, times, tables, sequtils, re]
when defined(windows):
  import winlean
else:
  import posix

type
  FileType* = enum
    ftFile,        # Обычный файл
    ftDirectory,   # Папка
    ftSymlink,     # Символическая ссылка
    ftHardlink,    # Жесткая ссылка
    ftDevice,      # Устройство
    ftPipe,        # Именованный канал
    ftSocket,      # Сокет
    ftUnknown      # Неизвестный тип

  FilePermission* = enum
    fpRead,        # Чтение
    fpWrite,       # Запись
    fpExecute      # Выполнение

  FilePermissions* = set[FilePermission]

  FileInfo* = object
    path*: string
    name*: string
    size*: int64
    fileType*: FileType
    permissions*: FilePermissions
    createdAt*: DateTime
    modifiedAt*: DateTime
    accessedAt*: DateTime
    owner*: string
    group*: string
    isHidden*: bool

  MountPoint* = object
    device*: string
    mountPath*: string
    fileSystem*: string
    options*: seq[string]
    totalSpace*: int64
    freeSpace*: int64
    usedSpace*: int64

  FilesError* = object of CatchableError

# === Основные функции для работы с файлами ===

proc exists*(path: string): bool =
  ## Проверяет существование файла или папки
  return fileExists(path) or dirExists(path)

proc isFile*(path: string): bool =
  ## Проверяет, является ли путь файлом
  return fileExists(path)

proc isDirectory*(path: string): bool =
  ## Проверяет, является ли путь папкой
  return dirExists(path)

proc isSymlink*(path: string): bool =
  ## Проверяет, является ли путь символической ссылкой
  when defined(windows):
    # На Windows используем GetFileAttributes
    let attrs = getFileAttributes(path.cstring)
    return attrs != INVALID_FILE_ATTRIBUTES and 
           (attrs and FILE_ATTRIBUTE_REPARSE_POINT) != 0
  else:
    # На Unix системах используем lstat
    var info: Stat
    return lstat(path.cstring, info) == 0 and S_ISLNK(info.st_mode)

proc getFileType*(path: string): FileType =
  ## Определяет тип файла
  if not exists(path):
    return ftUnknown
  
  when defined(windows):
    let attrs = getFileAttributes(path.cstring)
    if attrs == INVALID_FILE_ATTRIBUTES:
      return ftUnknown
    
    if (attrs and FILE_ATTRIBUTE_REPARSE_POINT) != 0:
      return ftSymlink
    elif (attrs and FILE_ATTRIBUTE_DIRECTORY) != 0:
      return ftDirectory
    else:
      return ftFile
  else:
    var info: Stat
    if stat(path.cstring, info) != 0:
      return ftUnknown
    
    if S_ISREG(info.st_mode): return ftFile
    elif S_ISDIR(info.st_mode): return ftDirectory
    elif S_ISLNK(info.st_mode): return ftSymlink
    elif S_ISBLK(info.st_mode) or S_ISCHR(info.st_mode): return ftDevice
    elif S_ISFIFO(info.st_mode): return ftPipe
    elif S_ISSOCK(info.st_mode): return ftSocket
    else: return ftUnknown

proc getFileSize*(path: string): int64 =
  ## Получает размер файла в байтах
  if not isFile(path):
    raise newException(FilesError, fmt"Path '{path}' is not a file")
  
  let info = getFileInfo(path)
  return info.size

proc getFilePermissions*(path: string): FilePermissions =
  ## Получает права доступа к файлу
  result = {}
  
  when defined(windows):
    # На Windows проверяем атрибуты файла
    let attrs = getFileAttributes(path.cstring)
    if attrs != INVALID_FILE_ATTRIBUTES:
      result.incl(fpRead)  # Обычно чтение доступно
      if (attrs and FILE_ATTRIBUTE_READONLY) == 0:
        result.incl(fpWrite)
      # Для выполнения проверяем расширение
      let ext = splitFile(path).ext.toLowerAscii()
      if ext in [".exe", ".bat", ".cmd", ".com"]:
        result.incl(fpExecute)
  else:
    # На Unix системах используем stat
    var info: Stat
    if stat(path.cstring, info) == 0:
      let mode = info.st_mode
      if (mode.int32 and S_IRUSR) != 0: result.incl(fpRead)
      if (mode.int32 and S_IWUSR) != 0: result.incl(fpWrite)
      if (mode.int32 and S_IXUSR) != 0: result.incl(fpExecute)

proc setFilePermissions*(path: string, permissions: FilePermissions) =
  ## Устанавливает права доступа к файлу
  when defined(windows):
    # На Windows можем только убрать/добавить атрибут только для чтения
    let attrs = getFileAttributes(path.cstring)
    if attrs != INVALID_FILE_ATTRIBUTES:
      var newAttrs = attrs
      if fpWrite in permissions:
        newAttrs = newAttrs and (not FILE_ATTRIBUTE_READONLY)
      else:
        newAttrs = newAttrs or FILE_ATTRIBUTE_READONLY
      discard setFileAttributes(path.cstring, newAttrs)
  else:
    # На Unix системах используем chmod
    var mode: Mode = Mode(0)
    if fpRead in permissions: mode = Mode(mode.uint32 or S_IRUSR.uint32)
    if fpWrite in permissions: mode = Mode(mode.uint32 or S_IWUSR.uint32)
    if fpExecute in permissions: mode = Mode(mode.uint32 or S_IXUSR.uint32)

    discard chmod(path.cstring, mode)

proc getFileInfo*(path: string): FileInfo =
  ## Получает подробную информацию о файле
  if not exists(path):
    raise newException(FilesError, fmt"Path '{path}' does not exist")
  
  let (dir, name, ext) = splitFile(path)
  let fullName = name & ext
  
  result = FileInfo(
    path: path,
    name: fullName,
    fileType: getFileType(path),
    permissions: getFilePermissions(path)
  )
  
  when defined(windows):
    var handle: Handle
    var findData: WIN32_FIND_DATA
    
    handle = findFirstFile(path.cstring, findData)
    if handle != INVALID_HANDLE_VALUE:
      # Размер файла
      result.size = (int64(findData.nFileSizeHigh) shl 32) or int64(findData.nFileSizeLow)
      
      # Времена
      result.createdAt = fromWinTime(findData.ftCreationTime)
      result.modifiedAt = fromWinTime(findData.ftLastWriteTime)
      result.accessedAt = fromWinTime(findData.ftLastAccessTime)
      
      # Скрытый файл
      result.isHidden = (findData.dwFileAttributes and FILE_ATTRIBUTE_HIDDEN) != 0
      
      findClose(handle)
  else:
    var info: Stat
    if stat(path.cstring, info) == 0:
      result.size = info.st_size
      result.createdAt = fromUnix(info.st_ctime.int64).local
      result.modifiedAt = fromUnix(info.st_mtime.int64).local
      result.accessedAt = fromUnix(info.st_atime.int64).local
      result.isHidden = fullName.startsWith(".")

# === Функции для работы с папками ===

proc createDirectory*(path: string, recursive: bool = false) =
  ## Создает папку
  if recursive:
    createDir(path)
  else:
    if dirExists(parentDir(path)) or parentDir(path) == "":
      createDir(path)
    else:
      raise newException(FilesError, fmt"Parent directory does not exist: {parentDir(path)}")

proc removeDirectory*(path: string, recursive: bool = false) =
  ## Удаляет папку
  if not dirExists(path):
    raise newException(FilesError, fmt"Directory does not exist: {path}")
  
  if recursive:
    removeDir(path)
  else:
    # Проверяем, что папка пуста
    let contents = toSeq(walkDir(path))
    if contents.len > 0:
      raise newException(FilesError, fmt"Directory is not empty: {path}")
    removeDir(path)

proc listDirectory*(path: string, recursive: bool = false): seq[string] =
  ## Получает список файлов и папок в директории
  result = @[]
  
  if not dirExists(path):
    raise newException(FilesError, fmt"Directory does not exist: {path}")
  
  if recursive:
    for file in walkDirRec(path):
      result.add(file)
  else:
    for kind, file in walkDir(path):
      result.add(file)

proc listFiles*(path: string, recursive: bool = false): seq[string] =
  ## Получает список только файлов в директории
  result = @[]
  
  if recursive:
    for file in walkDirRec(path):
      if isFile(file):
        result.add(file)
  else:
    for kind, file in walkDir(path):
      if kind == pcFile:
        result.add(file)

proc listDirectories*(path: string, recursive: bool = false): seq[string] =
  ## Получает список только папок в директории
  result = @[]
  
  if recursive:
    for file in walkDirRec(path):
      if isDirectory(file):
        result.add(file)
  else:
    for kind, file in walkDir(path):
      if kind == pcDir:
        result.add(file)

# === Функции для работы с файлами ===

proc createFile*(path: string, content: string = "") =
  ## Создает файл с содержимым
  writeFile(path, content)

proc removeFile*(path: string) =
  ## Удаляет файл
  if not isFile(path):
    raise newException(FilesError, fmt"File does not exist: {path}")
  removeFile(path)

proc copyFile*(source, destination: string, overwrite: bool = false) =
  ## Копирует файл
  if not isFile(source):
    raise newException(FilesError, fmt"Source file does not exist: {source}")
  
  if exists(destination) and not overwrite:
    raise newException(FilesError, fmt"Destination already exists: {destination}")
  
  copyFile(source, destination)

proc moveFile*(source, destination: string, overwrite: bool = false) =
  ## Перемещает файл
  if not isFile(source):
    raise newException(FilesError, fmt"Source file does not exist: {source}")
  
  if exists(destination) and not overwrite:
    raise newException(FilesError, fmt"Destination already exists: {destination}")
  
  moveFile(source, destination)

proc readTextFile*(path: string): string =
  ## Читает текстовый файл
  if not isFile(path):
    raise newException(FilesError, fmt"File does not exist: {path}")
  return readFile(path)

proc writeTextFile*(path: string, content: string) =
  ## Записывает текст в файл
  writeFile(path, content)

proc appendTextFile*(path: string, content: string) =
  ## Добавляет текст в конец файла
  let file = open(path, fmAppend)
  try:
    file.write(content)
  finally:
    file.close()

# === Функции для работы с символическими ссылками ===

proc createSymlink*(target, linkPath: string) =
  ## Создает символическую ссылку
  when defined(windows):
    # На Windows требуются права администратора для создания symlink
    let flags = if isDirectory(target): SYMBOLIC_LINK_FLAG_DIRECTORY else: 0
    if createSymbolicLink(linkPath.cstring, target.cstring, flags) == 0:
      raise newException(FilesError, "Failed to create symbolic link")
  else:
    if symlink(target.cstring, linkPath.cstring) != 0:
      raise newException(FilesError, "Failed to create symbolic link")

proc readSymlink*(linkPath: string): string =
  ## Читает цель символической ссылки
  if not isSymlink(linkPath):
    raise newException(FilesError, fmt"Path is not a symbolic link: {linkPath}")
  
  when defined(windows):
    # Сложная реализация для Windows через GetFinalPathNameByHandle
    result = expandSymlink(linkPath)
  else:
    var buffer = newString(1024)
    let length = readlink(linkPath.cstring, buffer.cstring, buffer.len)
    if length == -1:
      raise newException(FilesError, "Failed to read symbolic link")
    result = buffer[0..<length]

# === Функции для работы с путями ===

proc absolutePath*(path: string): string =
  ## Получает абсолютный путь
  return absolutePath(path)

proc relativePath*(path, base: string): string =
  ## Получает относительный путь
  return relativePath(path, base)

proc normalizePath*(path: string): string =
  ## Нормализует путь
  return normalizedPath(path)

proc joinPaths*(paths: varargs[string]): string =
  ## Объединяет пути
  return joinPath(paths)

proc splitPath*(path: string): tuple[dir, name, ext: string] =
  ## Разделяет путь на компоненты
  return splitFile(path)

proc getParentDirectory*(path: string): string =
  ## Получает родительскую директорию
  return parentDir(path)

proc getFileName*(path: string): string =
  ## Получает имя файла без пути
  return extractFilename(path)

proc getFileExtension*(path: string): string =
  ## Получает расширение файла
  return splitFile(path).ext

proc changeExtension*(path, newExt: string): string =
  ## Изменяет расширение файла
  let (dir, name, _) = splitFile(path)
  return joinPath(dir, name & newExt)

# === Функции для работы с монтированием (только Unix (linux|mac)) ===

when not defined(windows):
  const
    MNT_FORCE = 0x00000001   # Force unmounting
    MNT_DETACH = 0x00000002  # Just detach from the tree
    MNT_EXPIRE = 0x00000004  # Mark for expiry
    UMOUNT_NOFOLLOW = 0x00000008  # Don't follow symlink on unmount

  {.push importc, header: "<sys/mount.h>".}
  proc umount2(target: cstring, flags: cint): cint
  proc mountSyscall(source: cstring, target: cstring, filesystemtype: cstring,
                   mountflags: culong, data: pointer): cint
  {.pop.}

  proc getMountPoints*(): seq[MountPoint] =
    ## Получает список точек монтирования (только Unix)
    result = @[]
    
    try:
      let mountsContent = readFile("/proc/mounts")
      for line in mountsContent.splitLines():
        if line.strip() == "": continue
        
        let parts = line.split()
        if parts.len >= 4:
          var mountPoint = MountPoint(
            device: parts[0],
            mountPath: parts[1],
            fileSystem: parts[2],
            options: parts[3].split(",")
          )
          
          # Получаем информацию о дисковом пространстве
          var statvfs_info: Statvfs
          if statvfs(mountPoint.mountPath.cstring, statvfs_info) == 0:
            let blockSize = statvfs_info.f_frsize
            mountPoint.totalSpace = int64(statvfs_info.f_blocks) * int64(blockSize)
            mountPoint.freeSpace = int64(statvfs_info.f_bavail) * int64(blockSize)
            mountPoint.usedSpace = mountPoint.totalSpace - mountPoint.freeSpace
          
          result.add(mountPoint)
    except:
      # Если не удается прочитать /proc/mounts, возвращаем пустой список
      discard

  proc mountFS*(device, mountPoint, fileSystem: string, options: seq[string] = @[]): bool =
    let optionsStr = if options.len > 0: options.join(",") else: ""
    let flags: culong = 0
    return mountSyscall(device.cstring, mountPoint.cstring, fileSystem.cstring,
                      flags, optionsStr.cstring.pointer) == 0

  proc unmountFS*(mountPoint: string, force: bool = false): bool =
    let flags = if force: MNT_FORCE.cint else: 0.cint
    return umount2(mountPoint.cstring, flags) == 0

else:
  # Для Windows - заглушки, так как концепция монтирования отличается
  proc getMountPoints*(): seq[MountPoint] =
    ## Получает список дисков (Windows)
    result = @[]
    
    when defined(windows):
      let drives = getLogicalDrives()
      var drive = 'A'
      var mask = 1'u32
      
      while drive <= 'Z':
        if (drives and mask) != 0:
          let drivePath = $drive & ":\\"
          var mountPoint = MountPoint(
            device: drivePath,
            mountPath: drivePath,
            fileSystem: "NTFS" # Упрощение, можно получить реальный тип
          )
          
          # Получаем информацию о дисковом пространстве
          var freeBytesAvailable, totalBytes, totalFreeBytes: int64
          if getDiskFreeSpaceEx(drivePath.cstring, freeBytesAvailable.addr, 
                               totalBytes.addr, totalFreeBytes.addr):
            mountPoint.totalSpace = totalBytes
            mountPoint.freeSpace = totalFreeBytes
            mountPoint.usedSpace = totalBytes - totalFreeBytes
          
          result.add(mountPoint)
        
        inc(drive)
        mask = mask shl 1

# === Функции для работы с дисковым пространством ===

proc getDiskSpace*(path: string): tuple[total, free, used: int64] =
  ## Получает информацию о дисковом пространстве
  when defined(windows):
    var freeBytesAvailable, totalBytes, totalFreeBytes: int64
    if getDiskFreeSpaceEx(path.cstring, freeBytesAvailable.addr, 
                         totalBytes.addr, totalFreeBytes.addr):
      result.total = totalBytes
      result.free = totalFreeBytes
      result.used = totalBytes - totalFreeBytes
    else:
      raise newException(FilesError, "Failed to get disk space information")
  else:
    var statvfs_info: Statvfs
    if statvfs(path.cstring, statvfs_info) == 0:
      let blockSize = statvfs_info.f_frsize
      result.total = int64(statvfs_info.f_blocks) * int64(blockSize)
      result.free = int64(statvfs_info.f_bavail) * int64(blockSize)
      result.used = result.total - result.free
    else:
      raise newException(FilesError, "Failed to get disk space information")

proc getDiskUsage*(path: string): float =
  ## Получает процент использования диска
  let (total, free, used) = getDiskSpace(path)
  if total > 0:
    return (used.float / total.float) * 100.0
  else:
    return 0.0

# === Функции для поиска файлов ===

proc findFiles*(directory: string, pattern: string = "*", 
                recursive: bool = true): seq[string] =
  result = @[]
  let regex = pattern.replace("*", ".*").re
  
  if recursive:
    for file in walkDirRec(directory):
      if isFile(file):
        let fileName = extractFilename(file)
        if pattern == "*" or fileName.match(regex):
          result.add(file)
  else:
    for kind, file in walkDir(directory):
      if kind == pcFile:
        let fileName = extractFilename(file)
        if pattern == "*" or fileName.match(regex):
          result.add(file)

proc findDirectories*(directory: string, pattern: string = "*", 
                     recursive: bool = true): seq[string] =
  result = @[]
  let regex = pattern.replace("*", ".*").re
  
  if recursive:
    for file in walkDirRec(directory):
      if isDirectory(file):
        let dirName = extractFilename(file)
        if pattern == "*" or dirName.match(regex):
          result.add(file)
  else:
    for kind, file in walkDir(directory):
      if kind == pcDir:
        let dirName = extractFilename(file)
        if pattern == "*" or dirName.match(regex):
          result.add(file)

proc findBySize*(directory: string, minSize: int64 = 0, 
                maxSize: int64 = high(int64), recursive: bool = true): seq[string] =
  ## Ищет файлы по размеру
  result = @[]
  
  let files = if recursive: 
    toSeq(walkDirRec(directory)).filterIt(isFile(it))
  else:
    toSeq(walkDir(directory)).filterIt(it.kind == pcFile).mapIt(it.path)
  
  for file in files:
    let size = getFileSize(file)
    if size >= minSize and size <= maxSize:
      result.add(file)

proc findByDate*(directory: string, fromDate: DateTime, 
                toDate: DateTime = now(), recursive: bool = true): seq[string] =
  ## Ищет файлы по дате модификации
  result = @[]
  
  let files = if recursive: 
    toSeq(walkDirRec(directory)).filterIt(isFile(it))
  else:
    toSeq(walkDir(directory)).filterIt(it.kind == pcFile).mapIt(it.path)
  
  for file in files:
    let info = getFileInfo(file)
    if info.modifiedAt >= fromDate and info.modifiedAt <= toDate:
      result.add(file)

# === Функции для работы с временными файлами ===

proc getTempDirectory*(): string =
  ## Получает путь к временной директории
  when defined(windows):
    result = getEnv("TEMP", getEnv("TMP", r"C:\Windows\Temp"))
  else:
    result = getEnv("TMPDIR", "/tmp")

proc createTempFile*(prefix: string = "temp", suffix: string = ".tmp"): string =
  ## Создает временный файл
  let tempDir = getTempDirectory()
  let timestamp = $epochTime().int64
  result = joinPath(tempDir, prefix & timestamp & suffix)
  createFile(result)

proc createTempDirectory*(prefix: string = "temp"): string =
  ## Создает временную директорию
  let tempDir = getTempDirectory()
  let timestamp = $epochTime().int64
  result = joinPath(tempDir, prefix & timestamp)
  createDirectory(result)

# === Функции для работы с правами доступа (расширенные) ===

when not defined(windows):
  proc getOwner*(path: string): tuple[user, group: string] =
    var info: Stat
    if stat(path.cstring, info) != 0:
      raise newException(FilesError, "Failed to get file owner")
    
    let passwd = getpwuid(info.st_uid)
    let user = if passwd != nil: $passwd.pw_name else: $info.st_uid
    
    let group_info = getgrgid(info.st_gid)
    let group = if group_info != nil: $group_info.gr_name else: $info.st_gid
    
    result = (user: user, group: group)

  proc setOwner*(path: string, user: string = "", group: string = "") =
    var uid: Uid = Uid.high  # Use maximum value instead of -1
    var gid: Gid = Gid.high  # Use maximum value instead of -1
    
    if user != "":
      let passwd = getpwnam(user.cstring)
      if passwd == nil:
        raise newException(FilesError, fmt"User not found: {user}")
      uid = passwd.pw_uid
    
    if group != "":
      let group_info = getgrnam(group.cstring)
      if group_info == nil:
        raise newException(FilesError, fmt"Group not found: {group}")
      gid = group_info.gr_gid
    
    if chown(path.cstring, uid, gid) != 0:
      raise newException(FilesError, "Failed to change owner")

# === Функции для мониторинга файловой системы ===

type
  FileWatchEvent* = enum
    fweCreated,    # Файл создан
    fweModified,   # Файл изменен
    fweDeleted,    # Файл удален
    fweRenamed     # Файл переименован

  FileWatchCallback* = proc(path: string, event: FileWatchEvent)

when defined(windows):
  # Для Windows можно использовать ReadDirectoryChangesW
  proc watchDirectory*(path: string, callback: FileWatchCallback, 
                      recursive: bool = false) =
    ## Мониторит изменения в директории (Windows)
    # Упрощенная реализация - в реальности нужно использовать WinAPI
    echo fmt"Watching directory: {path} (Windows implementation needed)"

else:
  # Для Linux можно использовать inotify
  proc watchDirectory*(path: string, callback: FileWatchCallback, 
                      recursive: bool = false) =
    ## Мониторит изменения в директории (Linux)
    # Упрощенная реализация - в реальности нужно использовать inotify
    echo fmt"Watching directory: {path} (Linux implementation needed)"

# === Утилиты для работы с файлами ===
import std/md5
proc calculateChecksum*(path: string, algorithm: string = "md5"): string =
  ## Вычисляет контрольную сумму файла
  
  if not isFile(path):
    raise newException(FilesError, fmt"File does not exist: {path}")
  
  case algorithm.toLowerAscii():
  of "md5":
    return $toMD5(readFile(path))
  else:
    raise newException(FilesError, fmt"Unsupported algorithm: {algorithm}")

proc compareFiles*(file1, file2: string): bool =
  ## Сравнивает два файла
  if not (isFile(file1) and isFile(file2)):
    return false
  
  let size1 = getFileSize(file1)
  let size2 = getFileSize(file2)
  
  if size1 != size2:
    return false
  
  # Сравниваем содержимое
  return readFile(file1) == readFile(file2)

proc duplicateFile*(source: string, times: int = 1): seq[string] =
  ## Создает несколько копий файла
  result = @[]
  
  if not isFile(source):
    raise newException(FilesError, fmt"Source file does not exist: {source}")
  
  let (dir, name, ext) = splitFile(source)
  
  for i in 1..times:
    let copyPath = joinPath(dir, fmt"{name}_copy_{i}{ext}")
    copyFile(source, copyPath)
    result.add(copyPath)

proc getDirectorySize*(path: string): int64 =
  ## Получает общий размер директории
  result = 0
  
  if not isDirectory(path):
    raise newException(FilesError, fmt"Path is not a directory: {path}")
  
  for file in walkDirRec(path):
    if isFile(file):
      result += getFileSize(file)

proc cleanDirectory*(path: string, olderThan: Duration = initDuration()) =
  ## Очищает директорию от старых файлов
  if not isDirectory(path):
    raise newException(FilesError, fmt"Path is not a directory: {path}")
  
  let cutoffTime = now() - olderThan
  
  for file in listFiles(path):
    let info = getFileInfo(file)
    if olderThan == initDuration() or info.modifiedAt < cutoffTime:
      removeFile(file)

# === Функции для архивации (базовые) ===

proc createArchive*(files: seq[string], archivePath: string) =
  ## Создает простой архив (tar-подобный формат)
  # Упрощенная реализация - в реальности нужна полноценная библиотека архивации
  var archive = open(archivePath, fmWrite)
  try:
    for file in files:
      if isFile(file):
        let content = readFile(file)
        let header = fmt"{file}|{content.len}|"
        archive.write(header)
        archive.write(content)
  finally:
    archive.close()

proc extractArchive*(archivePath: string, destination: string) =
  ## Извлекает файлы из архива
  # Упрощенная реализация
  if not isFile(archivePath):
    raise newException(FilesError, fmt"Archive does not exist: {archivePath}")
  
  createDirectory(destination, recursive = true)
  echo fmt"Extracting {archivePath} to {destination} (implementation needed)"

# === Функции для работы с сетевыми файловыми системами ===

when not defined(windows):
  proc mountNFS*(server: string, remotePath: string, localPath: string,
                options: seq[string] = @[]): bool =
    ## Монтирует NFS ресурс
    let nfsPath = fmt"{server}:{remotePath}"
    let allOptions = @["rw", "hard", "intr"] & options
    return mountFS(nfsPath, localPath, "nfs", allOptions)

  proc mountSMB*(server: string, share: string, localPath: string,
                username: string = "", password: string = ""): bool =
    ## Монтирует SMB/CIFS ресурс
    let smbPath = fmt"//{server}/{share}"
    var options = @["rw"]
    if username != "":
      options.add(fmt"username={username}")
    if password != "":
      options.add(fmt"password={password}")
    return mountFS(smbPath, localPath, "cifs", options)

else:
  proc mapNetworkDrive*(remotePath: string, driveLetter: char = '\0',
                       username: string = "", password: string = ""): bool =
    ## Подключает сетевой диск (Windows)
    when defined(windows):
      var netResource: NETRESOURCE
      netResource.dwType = RESOURCETYPE_DISK
      netResource.lpRemoteName = remotePath.cstring
      
      if driveLetter != '\0':
        let localName = $driveLetter & ":"
        netResource.lpLocalName = localName.cstring
      
      let userPtr = if username != "": username.cstring else: nil
      let passPtr = if password != "": password.cstring else: nil
      
      return WNetAddConnection2(netResource.addr, passPtr, userPtr, 0) == NO_ERROR

  proc unmapNetworkDrive*(driveLetter: char, force: bool = false): bool =
    ## Отключает сетевой диск (Windows)
    when defined(windows):
      let drivePath = $driveLetter & ":"
      let flags = if force: CONNECT_UPDATE_PROFILE else: 0
      return WNetCancelConnection2(drivePath.cstring, flags, force) == NO_ERROR

# === Функции для работы с метаданными файлов ===

type
  ExtendedAttribute* = object
    name*: string
    value*: string

when not defined(windows):
  {.push importc, header: "<sys/xattr.h>".}
  proc listxattr(path: cstring, list: cstring, size: csize_t): clong
  proc getxattr(path: cstring, name: cstring, value: pointer, size: csize_t): clong
  proc setxattr(path: cstring, name: cstring, value: pointer, size: csize_t, flags: cint): cint
  proc removexattr(path: cstring, name: cstring): cint
  {.pop.}

  proc getExtendedAttributes*(path: string): seq[ExtendedAttribute] =
    ## Получает расширенные атрибуты файла (Linux/macOS)
    result = @[]
    
    # Получаем список имен атрибутов
    let listSize = listxattr(path.cstring, nil, 0)
    if listSize <= 0:
      return
    
    var namesList = newString(listSize)
    if listxattr(path.cstring, namesList.cstring, listSize.csize_t) <= 0:
      return
    
    # Парсим имена атрибутов
    var pos = 0
    while pos < namesList.len:
      let nameEnd = namesList.find('\0', pos)
      if nameEnd == -1:
        break
      
      let attrName = namesList[pos..<nameEnd]
      if attrName.len > 0:
        # Получаем значение атрибута
        let valueSize = getxattr(path.cstring, attrName.cstring, nil, 0)
        if valueSize > 0:
          var value = newString(valueSize)
          if getxattr(path.cstring, attrName.cstring, value.cstring.pointer, valueSize.csize_t) > 0:
            result.add(ExtendedAttribute(name: attrName, value: value))
      
      pos = nameEnd + 1

  proc setExtendedAttribute*(path: string, name: string, value: string) =
    ## Устанавливает расширенный атрибут файла
    if setxattr(path.cstring, name.cstring, value.cstring.pointer, value.len.csize_t, 0.cint) != 0:
      raise newException(FilesError, "Failed to set extended attribute")

  proc removeExtendedAttribute*(path: string, name: string) =
    ## Удаляет расширенный атрибут файла
    if removexattr(path.cstring, name.cstring) != 0:
      raise newException(FilesError, "Failed to remove extended attribute")

else:
  # Windows использует альтернативные потоки данных (ADS)
  proc getAlternateDataStreams*(path: string): seq[string] =
    ## Получает список альтернативных потоков данных (Windows)
    result = @[]
    # Реализация через FindFirstStreamW/FindNextStreamW
    echo "ADS enumeration not implemented"

# === Функции для работы с жесткими ссылками ===

when not defined(windows):
  proc createHardLink*(target: string, linkPath: string) =
    ## Создает жесткую ссылку
    if link(target.cstring, linkPath.cstring) != 0:
      raise newException(FilesError, "Failed to create hard link")

  proc getLinkCount*(path: string): int =
    ## Получает количество жестких ссылок на файл
    var info: Stat
    if stat(path.cstring, info) != 0:
      raise newException(FilesError, "Failed to get link count")
    return int(info.st_nlink)

else:
  proc createHardLink*(target: string, linkPath: string) =
    ## Создает жесткую ссылку (Windows)
    when defined(windows):
      if CreateHardLink(linkPath.cstring, target.cstring, nil) == 0:
        raise newException(FilesError, "Failed to create hard link")

# === Функции для работы с файловыми дескрипторами ===

when not defined(windows):
  proc getFileDescriptor*(file: File): cint =
    ## Получает файловый дескриптор
    return file.getFileHandle()

  proc duplicateFileDescriptor*(fd: cint): cint =
    ## Дублирует файловый дескриптор
    return dup(fd)

  proc redirectFileDescriptor*(oldFd: cint, newFd: cint) =
    ## Перенаправляет файловый дескриптор
    if dup2(oldFd, newFd) == -1:
      raise newException(FilesError, "Failed to redirect file descriptor")

# === Функции для работы с файловыми системами ===

type
  FileSystemInfo* = object
    name*: string
    totalSpace*: int64
    freeSpace*: int64
    usedSpace*: int64
    blockSize*: int64
    totalInodes*: int64
    freeInodes*: int64
    fileSystemType*: string
    mountOptions*: seq[string]

proc getFileSystemInfo*(path: string): FileSystemInfo =
  ## Получает информацию о файловой системе
  when defined(windows):
    var freeBytesAvailable, totalBytes, totalFreeBytes: int64
    if getDiskFreeSpaceEx(path.cstring, freeBytesAvailable.addr, 
                         totalBytes.addr, totalFreeBytes.addr):
      result = FileSystemInfo(
        name: path,
        totalSpace: totalBytes,
        freeSpace: totalFreeBytes,
        usedSpace: totalBytes - totalFreeBytes,
        fileSystemType: "NTFS" # Упрощение
      )
  else:
    var statvfs_info: Statvfs
    if statvfs(path.cstring, statvfs_info) == 0:
      result = FileSystemInfo(
        name: path,
        totalSpace: int64(statvfs_info.f_blocks) * int64(statvfs_info.f_frsize),
        freeSpace: int64(statvfs_info.f_bavail) * int64(statvfs_info.f_frsize),
        blockSize: int64(statvfs_info.f_frsize),
        totalInodes: int64(statvfs_info.f_files),
        freeInodes: int64(statvfs_info.f_ffree)
      )
      result.usedSpace = result.totalSpace - result.freeSpace

# === Функции для работы с файловыми потоками ===

type
  FileStream* = ref object
    file: File
    position: int64
    size: int64

proc openStream*(path: string, mode: FileMode = fmRead): FileStream =
  ## Открывает файловый поток
  result = FileStream()
  result.file = open(path, mode)
  result.position = 0
  
  if mode in {fmRead, fmReadWrite}:
    result.file.setFilePos(0, fspEnd)
    result.size = result.file.getFilePos()
    result.file.setFilePos(0, fspSet)

proc readStream*(stream: FileStream, buffer: var string, count: int): int =
  ## Читает данные из потока
  buffer = newString(count)
  result = stream.file.readBuffer(buffer[0].addr, count)
  buffer.setLen(result)  # Adjust string length to actual bytes read
  stream.position += result

proc writeStream*(stream: FileStream, data: string): int =
  ## Записывает данные в поток
  stream.file.write(data)
  result = data.len
  stream.position += result

proc seekStream*(stream: FileStream, position: int64, origin: FileSeekPos = fspSet) =
  ## Устанавливает позицию в потоке
  stream.file.setFilePos(position, origin)
  case origin:
  of fspSet: stream.position = position
  of fspCur: stream.position += position
  of fspEnd: stream.position = stream.size + position

proc closeStream*(stream: FileStream) =
  ## Закрывает файловый поток
  stream.file.close()

# === Функции для работы с файловыми фильтрами ===

type
  FileFilter* = object
    extensions*: seq[string]
    minSize*: int64
    maxSize*: int64
    namePattern*: string
    dateFrom*: DateTime
    dateTo*: DateTime
    includeHidden*: bool

proc newFileFilter*(): FileFilter =
  ## Создает новый файловый фильтр
  result = FileFilter(
    extensions: @[],
    minSize: 0,
    maxSize: high(int64),
    namePattern: "*",
    dateFrom: fromUnix(0).local,
    dateTo: now(),
    includeHidden: false
  )

proc matchesFilter*(path: string, filter: FileFilter): bool =
  ## Проверяет, соответствует ли файл фильтру
  if not isFile(path):
    return false
  
  let info = getFileInfo(path)
  
  # Проверка скрытых файлов
  if info.isHidden and not filter.includeHidden:
    return false
  
  # Проверка расширения
  if filter.extensions.len > 0:
    let ext = getFileExtension(path).toLowerAscii()
    if ext notin filter.extensions:
      return false
  
  # Проверка размера
  if info.size < filter.minSize or info.size > filter.maxSize:
    return false
  
  # Проверка имени
  if filter.namePattern != "*":
    let fileName = getFileName(path)
    let regex = filter.namePattern.replace("*", ".*").re
    if not fileName.match(regex):
      return false

  # Проверка даты
  if info.modifiedAt < filter.dateFrom or info.modifiedAt > filter.dateTo:
    return false
  
  return true

proc findFilesWithFilter*(directory: string, filter: FileFilter, 
                         recursive: bool = true): seq[string] =
  ## Ищет файлы с применением фильтра
  result = @[]
  
  let files = if recursive:
    toSeq(walkDirRec(directory))
  else:
    toSeq(walkDir(directory)).filterIt(it.kind == pcFile).mapIt(it.path)
  
  for file in files:
    if matchesFilter(file, filter):
      result.add(file)

# === Функции для работы с файловой безопасностью ===
import std/random

proc secureDelete*(path: string, passes: int = 3) =
  ## Безопасно удаляет файл (перезаписывает случайными данными)
  if not isFile(path):
    raise newException(FilesError, fmt"File does not exist: {path}")
  
  let size = getFileSize(path)
  var file = open(path, fmWrite)
  
  try:
    randomize()
    
    for pass in 1..passes:
      file.setFilePos(0, fspSet)
      
      # Заполняем файл случайными данными
      for i in 0..<size:
        file.write(char(rand(255)))
      
      file.flushFile()
  finally:
    file.close()
  
  # Удаляем файл
  removeFile(path)

proc isExecutable*(path: string): bool =
  ## Проверяет, является ли файл исполняемым
  if not isFile(path):
    return false
  
  let permissions = getFilePermissions(path)
  return fpExecute in permissions

proc makeExecutable*(path: string) =
  ## Делает файл исполняемым
  if not isFile(path):
    raise newException(FilesError, fmt"File does not exist: {path}")
  
  var permissions = getFilePermissions(path)
  permissions.incl(fpExecute)
  setFilePermissions(path, permissions)

# === Функции для работы с файловой статистикой ===

type
  DirectoryStats* = object
    totalFiles*: int
    totalDirectories*: int
    totalSize*: int64
    largestFile*: string
    largestFileSize*: int64
    oldestFile*: string
    oldestFileDate*: DateTime
    newestFile*: string
    newestFileDate*: DateTime
    filesByExtension*: Table[string, int]

proc getDirectoryStats*(path: string, recursive: bool = true): DirectoryStats =
  ## Получает статистику по директории
  result = DirectoryStats(
    filesByExtension: initTable[string, int](),
    oldestFileDate: now(),
    newestFileDate: fromUnix(0).local
  )
  
  if not isDirectory(path):
    raise newException(FilesError, fmt"Path is not a directory: {path}")
  
  if recursive:
    for itemPath in walkDirRec(path):
      let itemKind = if isFile(itemPath): pcFile else: pcDir
      
      case itemKind:
      of pcFile:
        inc(result.totalFiles)
        let info = getFileInfo(itemPath)
        result.totalSize += info.size
        
        # Самый большой файл
        if info.size > result.largestFileSize:
          result.largestFileSize = info.size
          result.largestFile = itemPath
        
        # Самый старый файл
        if info.modifiedAt < result.oldestFileDate:
          result.oldestFileDate = info.modifiedAt
          result.oldestFile = itemPath
        
        # Самый новый файл
        if info.modifiedAt > result.newestFileDate:
          result.newestFileDate = info.modifiedAt
          result.newestFile = itemPath
        
        # Статистика по расширениям
        let ext = getFileExtension(itemPath).toLowerAscii()
        if result.filesByExtension.hasKey(ext):
          result.filesByExtension[ext] += 1
        else:
          result.filesByExtension[ext] = 1
      
      of pcDir:
        inc(result.totalDirectories)
      
      else:
        discard
  else:
    for kind, itemPath in walkDir(path):
      case kind:
      of pcFile:
        inc(result.totalFiles)
        let info = getFileInfo(itemPath)
        result.totalSize += info.size
        
        # Same processing as above...
        if info.size > result.largestFileSize:
          result.largestFileSize = info.size
          result.largestFile = itemPath
        
        if info.modifiedAt < result.oldestFileDate:
          result.oldestFileDate = info.modifiedAt
          result.oldestFile = itemPath
        
        if info.modifiedAt > result.newestFileDate:
          result.newestFileDate = info.modifiedAt
          result.newestFile = itemPath
        
        let ext = getFileExtension(itemPath).toLowerAscii()
        if result.filesByExtension.hasKey(ext):
          result.filesByExtension[ext] += 1
        else:
          result.filesByExtension[ext] = 1
      
      of pcDir:
        inc(result.totalDirectories)
      
      else:
        discard

# === Функции для работы с конфигурационными файлами ===

proc getConfigDirectory*(): string =
  ## Получает директорию для конфигурационных файлов
  when defined(windows):
    result = getEnv("APPDATA", joinPath(getHomeDir(), "AppData", "Roaming"))
  elif defined(macosx):
    result = joinPath(getHomeDir(), "Library", "Application Support")
  else:
    result = getEnv("XDG_CONFIG_HOME", joinPath(getHomeDir(), ".config"))

proc getDataDirectory*(): string =
  ## Получает директорию для пользовательских данных
  when defined(windows):
    result = getEnv("LOCALAPPDATA", joinPath(getHomeDir(), "AppData", "Local"))
  elif defined(macosx):
    result = joinPath(getHomeDir(), "Library", "Application Support")
  else:
    result = getEnv("XDG_DATA_HOME", joinPath(getHomeDir(), ".local", "share"))

proc getCacheDirectory*(): string =
  ## Получает директорию для кэша
  when defined(windows):
    result = getEnv("LOCALAPPDATA", joinPath(getHomeDir(), "AppData", "Local"))
  elif defined(macosx):
    result = joinPath(getHomeDir(), "Library", "Caches")
  else:
    result = getEnv("XDG_CACHE_HOME", joinPath(getHomeDir(), ".cache"))

# === Функции для работы с файловыми операциями в пакетном режиме ===

proc batchCopy*(sources: seq[string], destination: string, 
               overwrite: bool = false): seq[string] =
  ## Копирует несколько файлов
  result = @[]
  
  if not isDirectory(destination):
    createDirectory(destination, recursive = true)
  
  for source in sources:
    if isFile(source):
      let fileName = getFileName(source)
      let destPath = joinPath(destination, fileName)
      
      try:
        copyFile(source, destPath, overwrite)
        result.add(destPath)
      except:
        echo fmt"Failed to copy {source}: {getCurrentExceptionMsg()}"

proc batchMove*(sources: seq[string], destination: string, 
               overwrite: bool = false): seq[string] =
  ## Перемещает несколько файлов
  result = @[]
  
  if not isDirectory(destination):
    createDirectory(destination, recursive = true)
  
  for source in sources:
    if isFile(source):
      let fileName = getFileName(source)
      let destPath = joinPath(destination, fileName)
      
      try:
        moveFile(source, destPath, overwrite)
        result.add(destPath)
      except:
        echo fmt"Failed to move {source}: {getCurrentExceptionMsg()}"

proc batchDelete*(paths: seq[string], recursive: bool = false): int =
  ## Удаляет несколько файлов/папок
  result = 0
  
  for path in paths:
    try:
      if isFile(path):
        removeFile(path)
        inc(result)
      elif isDirectory(path):
        removeDirectory(path, recursive)
        inc(result)
    except:
      echo fmt"Failed to delete {path}: {getCurrentExceptionMsg()}"

# === Финальные утилиты ===

proc formatFileSize*(size: int64): string =
  ## Форматирует размер файла в читаемом виде
  const units = ["B", "KB", "MB", "GB", "TB", "PB"]
  var currentSize = size.float
  var unitIndex = 0
  
  while currentSize >= 1024.0 and unitIndex < units.high:
    currentSize /= 1024.0
    inc(unitIndex)
  
  if unitIndex == 0:
    result = fmt"{size} {units[unitIndex]}"
  else:
    result = fmt"{currentSize:.2f} {units[unitIndex]}"

proc printFileInfo*(path: string) =
  ## Выводит информацию о файле в консоль
  if not exists(path):
    echo fmt"Path does not exist: {path}"
    return
  
  let info = getFileInfo(path)
  echo fmt"Path: {info.path}"
  echo fmt"Name: {info.name}"
  echo fmt"Type: {info.fileType}"
  echo fmt"Size: {formatFileSize(info.size)}"
  echo fmt"Permissions: {info.permissions}"
  echo fmt"Created: {info.createdAt}"
  echo fmt"Modified: {info.modifiedAt}"
  echo fmt"Accessed: {info.accessedAt}"
  echo fmt"Hidden: {info.isHidden}"

proc printDirectoryTree*(path: string, maxDepth: int = -1, currentDepth: int = 0) =
  ## Выводит дерево директории
  if maxDepth >= 0 and currentDepth > maxDepth:
    return
  
  let indent = "  ".repeat(currentDepth)
  let name = if currentDepth == 0: path else: getFileName(path)
  
  if isDirectory(path):
    echo fmt"{indent}{name}/"
    
    try:
      for kind, item in walkDir(path):
        printDirectoryTree(item, maxDepth, currentDepth + 1)
    except:
      echo fmt"{indent}  Access denied"
  else:
    let size = try: formatFileSize(getFileSize(path)) except: "unknown"
    echo fmt"{indent}{name} ({size})"

