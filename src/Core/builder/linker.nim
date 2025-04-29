import std/[os, strutils, sequtils]

type
  LinkerScript* = object
    entry*: string
    sections*: seq[string]
    outputPath*: string

proc generateScript*(script: LinkerScript): string =
  result = """
ENTRY(""" & script.entry & """)
SECTIONS
{
  . = 0x08048000;
  .text : { *(.text) }
  .data : { *(.data) }
  .bss  : { *(.bss) }
}
"""

proc linkObjects*(objDir: string, script: LinkerScript): bool =
  let 
    scriptPath = script.outputPath.parentDir / "link.ld"
    objFiles = toSeq(walkFiles(objDir / "*.o"))
  
  writeFile(scriptPath, generateScript(script))
  let cmd = "gcc -no-pie -Wl,--export-dynamic " & objFiles.join(" ") & " -o " & script.outputPath
  result = execShellCmd(cmd) == 0
