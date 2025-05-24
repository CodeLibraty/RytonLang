import std/[sets, tables]

type
  # Base types
  Float32*  = float32
  Float64*  = float64
  String*   = string
  UInt16*   = uint16
  UInt32*   = uint32
  UInt64*   = uint64
  Float*    = float
  Int16*    = int16
  Int32*    = int32
  Int64*    = int64
  UInt8*    = uint8
  UInt*     = uint
  Int8*     = int8
  Bool*     = bool
  Char*     = char
  Byte*     = byte
  Void*     = typeof(nil)
  Any*      = auto
  Int*      = int

  # Compound Array types
  Float32Array*   = Array[Float32]
  Float64Array*   = Array[Float64]
  StringArray*    = Array[String]
  UInt16Array*    = Array[UInt16]
  UInt32Array*    = Array[UInt32]
  UInt64Array*    = Array[UInt64]
  FloatArray*     = Array[Float]
  Int16Array*     = Array[Int16]
  Int32Array*     = Array[Int32]
  Int64Array*     = Array[Int64]
  UInt8Array*     = Array[UInt8]
  UIntArray*      = Array[UInt]
  Int8Array*      = Array[Int8]
  BoolArray*      = Array[Bool]
  CharArray*      = Array[Char]
  ByteArray*      = Array[Byte]
  IntArray*       = Array[Int]

  # Compound Sequence types
  Float32Seq*   = seq[Float32]
  Float64Seq*   = seq[Float64]
  UInt16Seq*    = seq[UInt16]
  UInt32Seq*    = seq[UInt32]
  UInt64Seq*    = seq[UInt64]
  StringSeq*    = seq[String]
  UInt8Seq*     = seq[UInt8]
  Int16Seq*     = seq[Int16]
  Int32Seq*     = seq[Int32]
  Int64Seq*     = seq[Int64]
  FloatSeq*     = seq[Float]
  Int8Seq*      = seq[Int8]
  UIntSeq*      = seq[UInt]
  BoolSeq*      = seq[Bool]
  CharSeq*      = seq[Char]
  ByteSeq*      = seq[Byte]
  IntSeq*       = seq[Int]

  # Negative types
  NotString* = concept x
    not (x is String)
  NotInt* = concept x
    not (x is Int)
  NotInt8* = concept x
    not (x is Int8)
  NotInt16* = concept x
    not (x is Int16)
  NotInt32* = concept x
    not (x is Int32)
  NotInt64* = concept x
    not (x is Int64)
  NotUInt* = concept x
    not (x is UInt)
  NotUInt8* = concept x
    not (x is UInt8)
  NotUInt16* = concept x
    not (x is UInt16)
  NotUInt32* = concept x
    not (x is UInt32)
  NotUInt64* = concept x
    not (x is UInt64)
  NotFloat* = concept x
    not (x is Float)
  NotFloat32* = concept x
    not (x is Float32)
  NotFloat64* = concept x
    not (x is Float64)
  NotBool* = concept x
    not (x is Bool)
  NotChar* = concept x
    not (x is Char)
  NotByte* = concept x
    not (x is Byte)

  # Container types
  Reference*[T]   = ref T
  Table*[K,V]     = TableRef[K,V]
  Pointer*[T]     = ptr T
  Array*[T]       = seq[T]
  Set*[T]         = HashSet[T]
  Tuple*          = tuple

  # C types
  CULongLong*   = culonglong
  CLongLong*    = clonglong
  CUShort*      = cushort
  CDouble*      = cdouble
  CULong*       = culong
  CFloat*       = cfloat
  CShort*       = cshort
  CSizeT*       = csize_t
  CUChar*       = cuchar
  CVoid*        = pointer
  CLong*        = clong
  CChar*        = cchar
  CUInt*        = cuint
  CInt*         = cint

  # C arrays
  CCharArray*       = Array[CChar]
  CIntArray*        = Array[CInt] 
  CShortArray*      = Array[CShort]
  CLongArray*       = Array[CLong]
  CLongLongArray*   = Array[CLongLong]
  CUCharArray*      = Array[CUChar]
  CUIntArray*       = Array[CUInt]
  CUShortArray*     = Array[CUShort]
  CULongArray*      = Array[CULong]
  CULongLongArray*  = Array[CULongLong]
  CFloatArray*      = Array[CFloat]
  CDoubleArray*     = Array[CDouble]

  # C pointers
  CCharPtr*         = ptr CChar
  CIntPtr*          = ptr CInt
  CShortPtr*        = ptr CShort
  CLongPtr*         = ptr CLong
  CLongLongPtr*     = ptr CLongLong
  CUCharPtr*        = ptr CUChar
  CUIntPtr*         = ptr CUInt
  CUShortPtr*       = ptr CUShort
  CULongPtr*        = ptr CULong
  CULongLongPtr*    = ptr CULongLong
  CFloatPtr*        = ptr CFloat
  CDoublePtr*       = ptr CDouble
  CVoidPtr*         = pointer
