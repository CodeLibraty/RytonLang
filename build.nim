import std/[os, strutils, strformat, osproc]

const 
  SrcDir = "src"
  BinDir = "bin"
  DocsDir = "documentations"
  WasmDir = "wasm"

proc createDirIfNotExists(dir: string) =
  if not dirExists(dir):
    createDir(dir)
    echo fmt"Created directory: {dir}"

proc runCommand(cmd: string): bool =
  echo fmt"Executing: {cmd}"
  let exitCode = execCmd(cmd)
  result = exitCode == 0
  if not result:
    echo fmt"Command failed with exit code {exitCode}"

proc buildProject(release: bool = false) =
  createDirIfNotExists(BinDir)
  
  let 
    outputFile = if release: BinDir / "ryton" else: BinDir / "ryton_debug"
    releaseFlag = if release: "-d:release --opt:speed" else: "-d:debug --debuginfo --linedir:on"
  
  let cmd = fmt"nim c {releaseFlag} -o:{outputFile} {SrcDir}/ryton.nim"
  if runCommand(cmd):
    echo fmt"Build successful: {outputFile}"
  else:
    echo "Build failed"

proc buildWasm() =
  createDirIfNotExists(WasmDir)
  
  let cmd = fmt"nim c -d:emscripten -o:{WasmDir}/ryton.js {SrcDir}/ryton.nim"
  if runCommand(cmd):
    echo fmt"WebAssembly build successful: {WasmDir}/ryton.js"
  else:
    echo "WebAssembly build failed"

proc buildJs() =
  createDirIfNotExists("web")
  let cmd = fmt"nim js -d:release --out:web/ryton.js {SrcDir}/ryton.nim"
  if runCommand(cmd):
    echo "JS build successful: web/ryton.js"
  else:
    echo "JS build failed"

proc generateDocs() =
  createDirIfNotExists(DocsDir)
  
  let cmd = fmt"nim doc --project --index:on --outdir:{DocsDir} {SrcDir}/ryton.nim"
  if runCommand(cmd):
    echo fmt"Documentation generated in {DocsDir}"
  else:
    echo "Documentation generation failed"

proc installDeps() =
  let cmd = "nimble install npeg"
  if runCommand(cmd):
    echo "Dependencies installed successfully"
  else:
    echo "Failed to install dependencies"

proc clean() =
  for dir in [BinDir, DocsDir]:
    if dirExists(dir):
      removeDir(dir)
      echo fmt"Removed directory: {dir}"
  
  # Удаление временных файлов компиляции
  for file in walkDirRec(SrcDir):
    if file.endsWith(".o") or file.endsWith(".obj") or file.endsWith(".pdb") or file.endsWith(".ilk"):
      removeFile(file)
      echo fmt"Removed file: {file}"

proc showHelp() =
  echo """
Build script for Ryton Programming Language

Usage:
  nim r build.nim [command]

Commands:
  build         Build debug version
  wasm          Build WebAssembly version
  js            Build JS version
  release       Build release version
  test          Run tests
  docs          Generate documentation
  install_deps  Install dependencies
  clean         Clean build artifacts
  help          Show this help message
  """

proc main() =
  let args = commandLineParams()
  
  if args.len == 0:
    buildProject()
    return
  
  case args[0].toLowerAscii()
  of "build":
    buildProject()
  of "wasm":
    buildWasm()
  of "js":
    buildJs()
  of "release":
    buildProject(release = true)
  of "docs":
    generateDocs()
  of "install_deps":
    installDeps()
  of "clean":
    clean()
  of "help":
    showHelp()
  else:
    echo fmt"Unknown command: {args[0]}"
    showHelp()

when isMainModule:
  main()
