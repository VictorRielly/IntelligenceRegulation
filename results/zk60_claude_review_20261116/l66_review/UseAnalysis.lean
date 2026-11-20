import ZK60Formal.RunBlkPinsHd
-- REVIEW (reviewer-generated): which binders of the top theorem and of its private aux theorem occur in the proof term.
open Lean Meta Elab Command

def useAnalysis (n : Name) (file : String) : MetaM Unit := do
  let ci ← getConstInfo n
  let v ← match ci with
    | .thmInfo tv => pure tv.value
    | .defnInfo dv => pure dv.value
    | _ => throwError "no value"
  lambdaTelescope v fun xs b => do
    let mut s := s!"USES {n} binders={xs.size}\n"
    for x in xs do
      let d ← x.fvarId!.getDecl
      let inBody := b.containsFVar x.fvarId!
      let mut inTypes := false
      for y in xs do
        if y != x then
          let dy ← y.fvarId!.getDecl
          if dy.type.containsFVar x.fvarId! then inTypes := true
      let isP ← isProp d.type
      s := s ++ s!"USE {d.userName} prop={isP} inBody={inBody} inOtherBinderTypes={inTypes}\n"
    IO.FS.writeFile file s

run_cmd liftTermElabM do
  let D := "/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/l66_review/"
  useAnalysis `ZK60.ProtocolClassify.RunShapeP.sshC_productionReadyL_epP_pinsHd (D ++ "use_top.txt")
  let env ← getEnv
  let mut auxN : Option Name := none
  for (n, _) in env.constants.map₁.toList do
    if (toString n).endsWith "sshC_productionReadyL_epP_pinsHd_aux" then auxN := some n
  match auxN with
  | some n => useAnalysis n (D ++ "use_aux.txt")
  | none => IO.FS.writeFile (D ++ "use_aux.txt") "aux not found\n"
