SRC='/Users/victorrielly/IntelligenceRegulation/formal/ZK60Formal/RunBlkPinsHd.lean'
OUT='/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/l66_review/'
body=open(SRC).read()
idx=body.rindex('end ZK60.ProtocolClassify')
meta = r'''
-- REVIEW APPENDIX (reviewer-generated; not in the original file): binder dump and use analysis
section ReviewMeta
open Lean Meta Elab Command

def dumpSig (n : Name) (file : String) : MetaM Unit := do
  let ci ← getConstInfo n
  forallTelescope ci.type fun xs concl => do
    let mut s := s!"THEOREM {n} binders={xs.size}\n"
    for x in xs do
      let d ← x.fvarId!.getDecl
      let t ← ppExpr d.type
      s := s ++ s!"BINDER {d.userName} [{repr d.binderInfo}] :: {(toString t).replace "\n" " "}\n"
    let c ← ppExpr concl
    s := s ++ s!"CONCLUSION :: {(toString c).replace "\n" " "}\n"
    IO.FS.writeFile file s

def useAnalysis (n : Name) (file : String) : MetaM Unit := do
  let ci ← getConstInfo n
  let v := ci.value!
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
  dumpSig `ZK60.ProtocolClassify.RunShapeP.sshC_productionReadyL_epP_blkAlive (D ++ "sig_blkAlive.txt")
  dumpSig `ZK60.ProtocolClassify.RunShapeP.sshC_productionReadyL_epP_pinsHd (D ++ "sig_pinsHd.txt")
  useAnalysis `ZK60.ProtocolClassify.RunShapeP.sshC_productionReadyL_epP_pinsHd (D ++ "use_top.txt")
  let env ← getEnv
  let mut auxN : Option Name := none
  for (n, _) in env.constants.map₂.toList do
    if (toString n).endsWith "sshC_productionReadyL_epP_pinsHd_aux" then auxN := some n
  match auxN with
  | some n => useAnalysis n (D ++ "use_aux.txt")
  | none => IO.FS.writeFile (D ++ "use_aux.txt") "aux not found\n"

end ReviewMeta
'''
open(OUT+'RunBlkPinsHd_review_copy2.lean','w').write(body[:idx]+meta+'\n'+body[idx:])
