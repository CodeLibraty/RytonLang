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
import std/SysInfo
import std/fStrings
var userName: String = runCmdOutput("whoami")

class DeltaShell:
  method currentDir*(): String =
    runCmdOutput("pwd").replace(f"/home/{userName}" , "~")
  
  method commandExecute*(command: String) =
    let command = command.split(" ")
    if command[0] == "cd":
      print(runCmdOutput(f"cd {command[1]}" ))
    else:
      print(runCmdOutput(command.join(" ")))
  
  method UIShell*() =
    var command = " "
    while true:
      pause(10)
      command = input(f"{userName}#[{this.currentDir()}]> " )
      if command == "exit":
        break
      elif command == """":
        discard
      else:
        this.commandExecute(command)
  
proc Main*() =
  DeltaShell().UIShell()



Main()