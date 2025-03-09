#import nimpy

#proc main() =
#  # Добавляем путь к модулям
#  let sys = pyImport("sys")
#  discard sys.path.append("./")
#  
#  let ruvix = pyImport("RuVix").RuVix()
#  let app = ruvix.create_app()
#  
#  let main_layout = ruvix.create_widget("BoxLayout")
#  let label = ruvix.create_widget("Label", text="Привет, мир!")
#  
# discard ruvix.add_widget(main_layout, label)
#  discard app.set_root(main_layout)
#  discard app.run()

#when isMainModule:
#  main()

import nimpy

{.push exportc, dynlib.}

proc NimMain() {.importc.}

proc initPython() {.exportc.} =
  NimMain()
  let sys = pyImport("sys")
  discard sys.path.append("./")

proc getRuvix(): PyObject {.exportc.} =
  let ruvix = pyImport("RuVix")
  result = ruvix.RuVix()

proc createApp(ruvix: PyObject): PyObject {.exportc.} =
  result = ruvix.create_app()

proc createWidget(ruvix: PyObject, wtype: cstring): PyObject {.exportc.} =
  result = ruvix.create_widget(wtype)

proc addWidget(ruvix: PyObject, parent, child: PyObject): PyObject {.exportc.} =
  result = ruvix.add_widget(parent, child)

proc setRoot(app, widget: PyObject): PyObject {.exportc.} =
  result = app.set_root(widget)

proc runApp(app: PyObject): PyObject {.exportc.} =
  result = app.run()

{.pop.}

