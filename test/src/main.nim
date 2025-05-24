import times
import strformat
import strutils
import classes
import std.Core.stdTypes
import std.Core.stdModifiers
import std.Core.stdFunctions
while True:
  print("Hello World!")
while 1 == 18:
  print("Я хочу пиццы")

class Simple:
  method simple*() =
    if name:
      if name:
        print("Simple nahuy")
  

class Package:
  method myFunction*(name: String) =
    print("Hello World!", name)
  
  method Main*() =
    print("HI! I Ryton App")
    var name = input("Enter your name: ")
    if not isType(name, String):      
      print("wtf? enter youre name as a string!")
      

    pause(1000)
    print("Hello ", name, "!")
    var age = toInt(input("Enter your age: "))
    pause(1000)
    if age < 18:
      print("You are not old enough to enter this site!")
    elif age > 18:
      print("You are old enough to enter this site!")
    else:
      print("You old!")
    print("You are ", age)
  
var package = mysd.Package(sas, 10, "kdkd", [1, 2, 3])
package.myFunction("sas")
package.Main()
