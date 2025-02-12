import nimpy
import tables
import os

# Import Python modules
let sys* = pyImport("sys")

# Cache for loaded modules
type PyObject* {.importc: "PyObject", header: "<Python.h>".} = object

var loadedModules = initTable[string, nimpy.PyObject]()


proc importPythonModule*(name: string): nimpy.PyObject {.exportc, dynlib.} =
  result = pyImport(name)
