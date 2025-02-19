import nimpy

type
  NumpyArray* = object
    data: PyObject
    shape: seq[int]
    dtype: string

  PandasDataFrame* = object
    data: PyObject
    columns: seq[string]
    index: seq[int]

proc toNumpyArray*(obj: PyObject): NumpyArray {.exportpy.} =
  result.data = obj
  result.shape = obj.shape.to(seq[int])
  result.dtype = obj.dtype.to(string)
