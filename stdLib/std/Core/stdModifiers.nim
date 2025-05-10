import std/macros

macro trace*(fn: untyped) =
  let name = $fn[0]
  let old_body = fn.body
  
  var new_body = copyNimTree(old_body)
  for node in new_body:
    if node.kind == nnkReturnStmt:
      let ret_val = node[0]
      node[0] = newStmtList(
        newCall(
          "echo", newStrLitNode("Exiting " & name)
        ),
        ret_val
      )
    
  fn.body = newStmtList(
    newCall("echo", newStrLitNode("Entering " & name)),
    new_body,
    newCall("echo", newStrLitNode("Exiting " & name))
  )
  result = fn

macro log*(fn: untyped) =
  let name = $fn[0]
  let params = $fn[3]
  let old_body = fn.body
  fn.body = newStmtList(
    newVarStmt(ident("logger"), newCall("newConsoleLogger")),
    newCall("log", ident("logger"), ident("lvlInfo"), 
      newStrLitNode("Called " & name & " with params: " & params)),
    old_body,
    newCall("log", ident("logger"), ident("lvlInfo"), 
      newStrLitNode("Function " & name & " completed"))
  )
  result = fn

macro metrics*(fn: untyped) =
  let name = $fn[0]
  let old_body = fn.body
  fn.body = newStmtList(
    newLetStmt(ident("start"), newCall("epochTime")),
    old_body,
    newLetStmt(ident("duration"), 
      infix(newCall("epochTime"), "-", ident("start"))),
    newCall("echo", newStrLitNode("Function " & name & " took "), 
      ident("duration"), newStrLitNode("s"))
  )
  result = fn