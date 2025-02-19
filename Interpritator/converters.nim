import nimpy

proc convertNumeric*(obj: PyObject): PyObject =
  # Конвертация числовых типов
  case obj.kind:
    of pkInt: result = obj.to(int)
    of pkFloat: result = obj.to(float)
    else: raise newException(ValueError, "Unsupported numeric type")

proc convertSequence*(obj: PyObject): PyObject =
  # Конвертация последовательностей
  case obj.kind:
    of pkList: result = obj.to(seq[PyObject])
    of pkTuple: result = obj.to(tuple[PyObject])
    else: raise newException(ValueError, "Unsupported sequence type")
