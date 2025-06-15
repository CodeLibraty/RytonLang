import std/[os, strutils]

# Пользователь и окружение
proc getHomeDir*(): string =
  return getHomeDir()

proc getCurrentDir*(): string =
  return getCurrentDir()

# Системные пути
proc getBinPaths*(): seq[string] =
  let pathEnv = getEnv("PATH")
  when defined(windows):
    return pathEnv.split(';')
  else:
    return pathEnv.split(':')

proc getSystemBinDir*(): string =
  when defined(windows):
    return getEnv("SYSTEMROOT", "C:\\Windows") & "\\System32"
  elif defined(linux):
    return "/usr/bin"
  elif defined(macosx):
    return "/usr/bin"
  else:
    return "/usr/bin"

proc getTempDir*(): string =
  return getTempDir()

proc getConfigDir*(): string =
  when defined(windows):
    return getEnv("APPDATA", getHomeDir() & "\\AppData\\Roaming")
  elif defined(macosx):
    return getHomeDir() & "/Library/Application Support"
  else:
    return getEnv("XDG_CONFIG_HOME", getHomeDir() & "/.config")

proc getDataDir*(): string =
  when defined(windows):
    return getEnv("LOCALAPPDATA", getHomeDir() & "\\AppData\\Local")
  elif defined(macosx):
    return getHomeDir() & "/Library/Application Support"
  else:
    return getEnv("XDG_DATA_HOME", getHomeDir() & "/.local/share")
