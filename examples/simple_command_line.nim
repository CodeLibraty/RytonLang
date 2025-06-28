# NC Ryton Compiler - v0.2.4      #
# (с) 2025 CodeLibraty Foundation #
#     This file is auto-generated #

import os
import classes


import std/Core/stdTypes
import std/Core/stdModifiers
import std/Core/stdFunctions
import std/Shell
import std/Files
import std/Info
import std/Paths
import std/fStrings
var userName: String = runCmdOutput("whoami")

class DeltaShell:
  method currentDir*(): String =
    runCmdOutput("pwd").replace(f"/home/{userName}" , "~")
  
  method commandListDirectory*() =
    let files = listDirectory(this.currentDir)
    print("Files in <italic>`{this.currentDir}`</italic>:")
    for file in files:
      print(file)
  
  method commandExecute*(command: String) =
    let command = command.split(" ")
    if command[0] == "cd":
      if len(command) == 1:
        changeDir(f"/home/{userName}" )
      else:
        let fullCurrentPath = runCmdOutput("pwd")
        let dir = f"{fullCurrentPath}/{command[1]}" 
        if isDirectory(dir) == false:
          if command[1] == "~":
            changeDir(f"/home/{userName}" )
          else:
            print(f"<red|bold>Error</red|bold>: Directory <italic>`{dir}`</italic> not found." )
        else:
          changeDir(dir)
    elif command[0] == "cls":
      if runCmdSilent("clear") == false:
        print("<red|bold>Error</red|bold>: Command execute failure.")
    elif command[0] == "ls":
      this.commandListDirectory()
    else:
      runCmdOutput(command.join(" ")).print()
  
  method UIShell*() =
    var command = " "
    while true:
      pause(10)
      command = input(f"<green>{userName}<bold>#</bold></green>[<blue|italic>{this.currentDir()}</blue|italic>]> " )
      if command == "exit":
        break
      elif command == " ":
        discard
      else:
        this.commandExecute(command)
  
proc Main*() =
  DeltaShell().UIShell()



Main()