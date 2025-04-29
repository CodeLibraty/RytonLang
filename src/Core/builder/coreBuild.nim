import scanner, sourceCompile, linker
import ../Core
import std/[strutils, os, sequtils]

type
  CompileOptions* = object
    compileC*:   bool
    compileZig*: bool
    outputDir*:  string

  ProjectConfig* = object
    rootDir*:    string     # Корневая директория проекта
    buildDir*:   string     # Директория для промежуточных файлов
    outputName*: string     # Имя выходного файла
    mainFile*:   string     # Путь к основному файлу проекта

const 
  sourceExts = [".nim", ".ry"]
  skipDirs = ["assets", "resources", "configures", "icons", "images", "bins", "libs"]

proc generateHeaders*(projectRoot: string) =
  let modules = scanSourceDir(projectRoot / "src")
  generateBindings(modules, projectRoot / "build" / "bindings")

proc compileObjects*(projectRoot: string, options: CompileOptions) =
  let 
    cTarget = CompileTarget(
      compiler: "gcc",
      flags: @["-O2"],
      outputDir: options.outputDir
    )
    zigTarget = CompileTarget(
      compiler: "zig",
      flags: @[],
      outputDir: options.outputDir
    )

  if options.compileC:
    for file in walkFiles(projectRoot / "src/C/*.c"):
      discard compileC(file, cTarget)

  if options.compileZig:
    for file in walkFiles(projectRoot / "src/Zig/*.zig"):
      discard compileZig(file, zigTarget)

proc linkProject*(projectRoot: string, outputName: string) =
  let script = LinkerScript(
    entry: "main",
    sections: @[],
    outputPath: projectRoot / "build" / outputName
  )
  
  discard linkObjects(projectRoot / "build/obj", script)

proc copySourceDir(src, dst: string) =
  for dir in walkDir(src):
    let dirName = dir.path.extractFilename
    if dir.kind == pcDir and dirName notin skipDirs:
      # Рекурсивно копируем каталоги с исходниками
      createDir(dst / dirName)
      copySourceDir(dir.path, dst / dirName)
    elif dir.kind == pcFile and dir.path.splitFile.ext in sourceExts:
      # Копируем исходные файлы
      copyFile(dir.path, dst / dir.path.extractFilename)
    elif dir.kind == pcDir and dirName in skipDirs:
      # Создаём символическую ссылку для ресурсных каталогов
      createSymlink(src / dirName, dst / dirName)

proc buildProject*(config: ProjectConfig) =
  echo "Building Ryton files in: ", config.rootDir
  
  # Ищем все .ry файлы рекурсивно
  for ryFile in walkDirRec(config.rootDir, {pcFile}):
    if ryFile.endsWith(".ry"):
      let nimFile = ryFile.changeFileExt("nim")
      echo "Compiling: ", ryFile
      
      # Читаем исходный код
      let content = readFile(ryFile)
      
      # Компилируем в Nim код
      let compiler = newCompiler(content, nimFile)
      let nimCode = compiler.compileToNimCode(content)
      
      # Записываем результат рядом с исходным файлом
      writeFile(nimFile, nimCode)