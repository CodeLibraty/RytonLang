import nimpy, tables

type RytonBridge = object
  libs: Table[string, PyObject]

proc newBridge(): RytonBridge {.exportpy.} = 
  result.libs = initTable[string, PyObject]()

proc load*(rb: RytonBridge, name: string) {.exportpy.} =
  rb.libs[name] = pyImport(name)

proc get*(rb: RytonBridge, lib, attr: string): PyObject {.exportpy.} =
  rb.libs[lib].getAttr(attr)
