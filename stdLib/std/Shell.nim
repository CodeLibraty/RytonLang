import std/[os, osproc, strutils, strformat, terminal, strtabs, times, streams]

type
  ShellError* = object of CatchableError
  
  CommandResult* = object
    exitCode*: int
    output*: string
    error*: string
    duration*: float
    success*: bool
  
  ShellConfig* = object
    workingDir*: string
    env*: StringTableRef
    timeout*: int
    shell*: string

# Глобальная конфигурация
var globalShellConfig* = ShellConfig(
  workingDir: getCurrentDir(),
  env: newStringTable(),
  timeout: 0,
  shell: when defined(windows): "cmd.exe" else: "/bin/bash"
)

proc runCmd*(command: string, config: ShellConfig = globalShellConfig): CommandResult =
  ## Выполняет команду и возвращает результат
  let startTime = cpuTime()
  
  try:
    let workDir = if config.workingDir.len > 0: config.workingDir else: getCurrentDir()
    let envTable = if config.env.len > 0: config.env else: nil
    
    let process = startProcess(
      command = command,
      workingDir = workDir,
      env = envTable,
      options = {poUsePath, poStdErrToStdOut}
    )
    
    var output = ""
    
    if config.timeout > 0:
      let deadline = cpuTime() + config.timeout.float
      while process.running and cpuTime() < deadline:
        sleep(10)
      
      if process.running:
        process.kill()
        process.close()
        raise newException(ShellError, fmt"Command timed out after {config.timeout} seconds")
    
    # Правильное чтение из Stream
    let outputStream = process.outputStream
    var line = ""
    while outputStream.readLine(line):
      output.add(line & "\n")
    
    let exitCode = process.waitForExit()
    process.close()
    
    result = CommandResult(
      exitCode: exitCode,
      output: output.strip(),
      error: "",
      duration: cpuTime() - startTime,
      success: exitCode == 0
    )
    
  except Exception as e:
    result = CommandResult(
      exitCode: -1,
      output: "",
      error: e.msg,
      duration: cpuTime() - startTime,
      success: false
    )

proc runCmdSilent*(command: string): bool =
  ## Выполняет команду без вывода, возвращает только успех/неудачу
  let result = runCmd(command)
  return result.success

proc runCmdOutput*(command: string): string =
  ## Выполняет команду и возвращает только вывод
  let result = runCmd(command)
  return result.output

proc changeDir*(path: string) =
  ## Устанавливает рабочую директорию для команд
  globalShellConfig.workingDir = path

proc setTimeout*(seconds: int) =
  ## Устанавливает таймаут для команд
  globalShellConfig.timeout = seconds

proc setEnv*(key, value: string) =
  ## Добавляет переменную окружения
  globalShellConfig.env[key] = value

proc clearEnv*() =
  ## Очищает переменные окружения
  globalShellConfig.env = newStringTable()


