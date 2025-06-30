# NC Ryton Compiler - v0.2.4      #
# (с) 2025 CodeLibraty Foundation #
#     This file is auto-generated #




import std/Core/stdTypes
import std/Core/stdModifiers
import std/Core/stdFunctions
import std/Shell
import std/Files
import std/Info
import std/Paths
import std/fStrings
type
  myStruct* = object
    x*: Int
    y*: Int
    z*: Int

proc newmyStruct*(x: Int, y: Int, z: Int = 10): myStruct =
  result.x = x
  result.y = y
  result.z = z
type
  Status* = enum
    Success
    Error
proc isOk*(this: Status, ): Bool =
  return this == Success

proc message*(this: Status, ): String =
  if this == Success:
    return "Operation completed"
  elif this == Error:
    return "Operation failed"

proc Main*[T](): T =
  var stat: Status = Success
  stat.message().print()
  var myStruct = newmyStruct(x = 10, y = 20)
  print(myStruct.x)
  print(myStruct.y)
  print(myStruct.z)



Main()