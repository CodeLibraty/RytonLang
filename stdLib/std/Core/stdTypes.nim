import std/[sets, tables]

type
  String* = string
  Int* = int
  Int8* = int8
  Int16* = int16
  Int32* = int32
  Int64* = int64
  UInt* = uint
  UInt8* = uint8
  UInt16* = uint16
  UInt32* = uint32
  UInt64* = uint64
  Float* = float
  Float32* = float32
  Float64* = float64
  Bool* = bool
  Char* = char
  Byte* = byte
  Array*[T] = seq[T]
  Table*[K,V] = TableRef[K,V]
  Set*[T] = HashSet[T]
  Pointer*[T] = ptr T
  Reference*[T] = ref T
  Tuple* = tuple
  Option*[T] = Option[T]