[app]
name = "project"
author = "rejzi"
version = "1.0"
package = "org.rejzi.project"

[deps]
rytonc = "1.0"
nim = "2.2.2"

[rimbleLibs]
"rtk" = "1.0" 

[nimbleLibs]
"nimqt" = "1.2" 

[tasks.ryton]
"1" = "ryton_debug build src"

[tasks.tokens]
"1" = "ryton_debug tokens test/src/main.ry"

[tasks.ast]
"1" = "ryton_debug ast test/src/main.ry"

[tasks.nim]
"1" = "nim c --path:~/projects/CLI/RytonLang/stdLib -d:debug --debuginfo --linedir:on -o:test/bin/main test/src/main.nim"

[tasks.build]
"1" = "ryton_debug build src"
"2" = "nim c --path:~/projects/CLI/RytonLang/stdLib -d:debug --debuginfo --linedir:on -o:test/bin/main test/src/main.nim"

[tasks.run]
"1" = "ryton_debug build src" 
"2" = "nim c --path:~/projects/CLI/RytonLang/stdLib -d:debug --debuginfo --linedir:on -o:test/bin/main test/src/main.nim"
"3" = "test/bin/main"
