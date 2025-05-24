import std/[os, strutils, strformat]

type
  CompileTarget* = object
    compiler*: string
    flags*: seq[string]
    outputDir*: string

proc compileC*(sourcePath: string, target: CompileTarget): bool =
  let objFile = target.outputDir / sourcePath.extractFilename.changeFileExt("o")
  let cmd = target.compiler & " -c " & sourcePath & " -o " & objFile & " " & target.flags.join(" ")
  result = execShellCmd(cmd) == 0

proc compileZig*(sourcePath: string, target: CompileTarget): bool =
  let objFile = target.outputDir / sourcePath.extractFilename.changeFileExt("")
  let cmd = "zig build-obj " & sourcePath & " -femit-bin=" & objFile
  result = execShellCmd(cmd) == 0

proc compileNim*(target: CompileTarget, srctodir: string, mainFile: string, outputBin: string): bool =
  let stdlibPath = getCurrentDir() / "stdlib"
  let cmd = "nim c --path:" & stdlibPath & " --out:" & outputBin & " " & srctodir / mainFile
  echo "Executing: ", cmd 
  result = execShellCmd(cmd) == 0
