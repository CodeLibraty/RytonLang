import strformat
import strutils
import classes
import std.Core.stdTypes
import std.Core.stdModifiers
import times
class MainPack:
  method calcs*(this: MainPack, n: Int): Float {.trace, metrics.} =
    if n == nil: raise newException(ValueError, "n cannot be nil")
    
    if n = 1:
      echo(n)
    let myFunc = # Unsupported expression type: nkLambdaDef
    var result = # Unsupported expression type: nkLambdaDef
    var myfunc = # Unsupported expression type: nkLambdaDef
    var q = (n / 2.8)
    if not isType(q, Float):
      echo("this is a float")
      q = float(q)
      sas = 1.2


    var pq = (q / 1.9)
    if not isType(pq, Float):
      echao


    var t = (s * 10)
    result = s
    if result == nil: raise newException(ValueError, "Cannot return nil from non-optional function")
    return result
  
echo(calc(10))
