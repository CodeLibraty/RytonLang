import os
import classes

# NC Ryton Compiler - v0.2.4          #
# (с) 2025 CodeLibraty Foundation     #
#     This file is auto-generated     #
import std.Core.stdTypes
import std.Core.stdModifiers
import std.Core.stdFunctions
import std.Shell
proc changeDir*(dir: String) =
  discard

proc print*(text: String) =
  discard

proc runOutput*(cmd: String): Int =
  discard


class DeltaShell:
  method cmdRun*(cmd: String) {.mod, moss.} =
    let command = cmd.split(" ")
    if command[0] == "cd":
      changeDir(command[1])
    else:
      print(runOutput(cmd))
  
  method DShell*(sas: String) =
    var command = " "
    let sas = proc() =
      discard

    let sdas = proc(arg: Int): Int {.trace.} =
      return arg * 10

    while true:
      sleep(100)
      command = input("> ")
      if command == "exit":
        break
      else:
        this.cmdRun(command)
  
if value == 1:
  print("1")
elif value == 2:
  print("2")
elif (value == 3) and (value == 4):
  print("3 and 4")
elif (value == 5) or (value == 6):
  print("5 or 6")
elif (value >= 7 and value <= 10):
  print("7..10")
elif (value >= 11 and value < 15):
  print("11...15")
else:
  print("else")
proc test*(a: Int, b: Int) =
  var aa = proc() =
    var aa = proc() =
      var aa = proc() =
        var aa = proc() =
          var aa = proc() =
            var aa = proc() =
              discard







let shell = DeltaShell()
shell.DShell("String ")
