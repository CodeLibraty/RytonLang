import std/[os, strutils, tables, posix]

# Типы систем
type
  SystemType* = enum
    stLinux, stWindows, stMacOS, stAndroid, stIOS, stFreeBSD, stUnknown

  Architecture* = enum
    archX86, archX64, archARM, archARM64, archUnknown

# Основная информация о системе
proc getSystemType*(): SystemType =
  when defined(linux):
    if fileExists("/system/build.prop"):
      return stAndroid
    else:
      return stLinux
  elif defined(windows):
    return stWindows
  elif defined(macosx):
    return stMacOS
  elif defined(freebsd):
    return stFreeBSD
  else:
    return stUnknown

proc getArchitecture*(): Architecture =
  when sizeof(pointer) == 8:
    when defined(amd64) or defined(x86_64):
      return archX64
    elif defined(arm64) or defined(aarch64):
      return archARM64
    else:
      return archUnknown
  else:
    when defined(i386):
      return archX86
    elif defined(arm):
      return archARM
    else:
      return archUnknown

# Системная информация
proc getSystemVersion*(): string =
  when defined(windows):
    return "Windows " & getEnv("OS")
  elif defined(linux):
    if fileExists("/etc/os-release"):
      # Парсим /etc/os-release
      return "Linux"
    else:
      return "Linux"
  elif defined(macosx):
    return "macOS"
  else:
    return "Unknown"

# Проверки возможностей
proc isAdmin*(): bool =
  when defined(windows):
    # Проверка на администратора в Windows сложнее
    return false
  else:
    return getEnv("USER") == "root" or getuid() == 0

# Переменные окружения
proc getAllEnvVars*(): Table[string, string] =
  var envTable = initTable[string, string]()
  for key, val in envPairs():
    envTable[key] = val
  return envTable

proc getEnvVar*(name: string, default: string = ""): string =
  return getEnv(name, default)

proc setEnvVar*(name: string, value: string) =
  putEnv(name, value)
