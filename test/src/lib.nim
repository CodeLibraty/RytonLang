proc main*() =
  echo "hello"

type
  MyClass* = ref object
    attir*: int

method sas*(m: MyClass) =
  m.attir = 1
