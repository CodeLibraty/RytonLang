import std/[os, strformat, parseopt]
import Core/Core
import Core/builder/coreBuild

const 
  Version = "0.2.4"
  Description = """
The Ryton Programming Language Compiler
A simple and fast programming language that compiles to Nim
Developed by CodeLibraty Foundation
"""

type
  Command = enum
    cmdBuild,     # Build Ryton files in directory
    cmdCompile,   # Compile single file
    cmdTokens,    # Show tokens
    cmdAst        # Show AST

proc handleBuild(dir = getCurrentDir(), srcDir: string = "src") =
  let config = ProjectConfig(
    srcDir: dir / srcDir,
    rootDir: dir,
    buildDir: dir / "build",
    outputName: "main",
    mainFile: "main.nim"
  )
  if buildProject(config) == true:
    echo "\n✓ Compilation successful!"
  else:
    echo "\n✗ Compilation failed!"

proc handleTokens(file: string) =
  let source = readFile(file)
  var compiler = newCompiler(source, "")
  let lexResult = compiler.tokenize()
  if not lexResult.success:
    echo "Lexical error: ", lexResult.errorMessage
    echo fmt"Line {lexResult.errorLine}, column {lexResult.errorColumn}"
    return
  compiler.printTokenStatistics()
  printTokens(compiler.tokens)
  saveTokens(compiler.tokens)

proc handleAst(file: string) =
  let source = readFile(file)
  var compiler = newCompiler(source, "")
  let lexResult = compiler.tokenize()
  if not lexResult.success:
    echo "Lexical error: ", lexResult.errorMessage
    echo fmt"Line {lexResult.errorLine}, column {lexResult.errorColumn}"
    return
  let parseResult = compiler.parse()
  if not parseResult.success:
    echo "Syntax error: ", parseResult.errorMessage
    echo fmt"Line {parseResult.errorLine}, column {parseResult.errorColumn}"
    return
  compiler.dumpAST()

proc main() =
  var 
    command = cmdBuild
    inputSrc = ""
    outputFile = ""
    dir = getCurrentDir()
    verbose = false

  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "v", "version":
        echo "Ryton version ", Version
        quit(0)
      of "verbose":
        verbose = true
      of "o", "output":
        outputFile = p.val
      else:
        echo "Unknown option: ", p.key
        quit(1)
    of cmdArgument:
      case p.key
      of "build": command = cmdBuild
      of "compile": command = cmdCompile
      of "tokens": command = cmdTokens
      of "ast": command = cmdAst
      else:
        if inputSrc == "":
          inputSrc = p.key
        else:
          dir = p.key

  case command
  of cmdBuild:
    handleBuild(dir, inputSrc)
  of cmdCompile:
    if inputSrc == "":
      echo "Error: Input file required for compile command"
      quit(1)

  of cmdTokens:
    if inputSrc == "":
      echo "Error: Input file required for tokens command"
      quit(1)
    handleTokens(inputSrc)
  of cmdAst:
    if inputSrc == "":
      echo "Error: Input file required for ast command"
      quit(1)
    handleAst(inputSrc)

when isMainModule:
  main()
