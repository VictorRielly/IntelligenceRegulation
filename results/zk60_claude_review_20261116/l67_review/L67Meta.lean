import ZK60Formal.RunShieldInstP
import ZK60Formal.RunStgShieldLu
-- REVIEW (reviewer-generated): signature dump with Prop flags, the argument map of the top theorem's proof into the pinsHd theorem,
-- use analysis, reducibility status, the hLuStg match test, and the trivial-predicate examples. Reads the author's .olean files; writes only into this directory.
open Lean Meta Elab Command

def OUTD : String := "/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/l67_review/"

def dumpSigP (n : Name) (file : String) : MetaM Unit := do
  let ci ← getConstInfo n
  forallTelescope ci.type fun xs concl => do
    let mut s := s!"THEOREM {n} binders={xs.size}\n"
    for x in xs do
      let d ← x.fvarId!.getDecl
      let t ← ppExpr d.type
      let isP ← isProp d.type
      s := s ++ s!"BINDER {d.userName} [{repr d.binderInfo}] prop={isP} :: {(toString t).replace "\n" " "}\n"
    let c ← ppExpr concl
    s := s ++ s!"CONCLUSION :: {(toString c).replace "\n" " "}\n"
    IO.FS.writeFile file s

partial def peel (b : Expr) : Expr :=
  let b := b.consumeMData
  if b.isLet then peel (b.letBody!.instantiate1 b.letValue!)
  else if b.isAppOfArity ``letFun 4 then
    let body := b.appArg!
    if body.isLambda then peel (body.bindingBody!.instantiate1 (b.getArg! 2)) else b
  else if b.isApp && b.getAppFn.isLambda then peel b.headBeta
  else b

def valOf (ci : ConstantInfo) : MetaM Expr :=
  match ci with
  | .thmInfo tv => pure tv.value
  | .defnInfo dv => pure dv.value
  | _ => throwError "no value"

def argMap (n head : Name) (file : String) : MetaM Unit := do
  let ci ← getConstInfo n
  let v ← valOf ci
  let hi ← getConstInfo head
  let names ← forallTelescope hi.type fun xs _ => xs.mapM fun x => do return (← x.fvarId!.getDecl).userName
  lambdaTelescope v fun xs b => do
    let b := peel b
    let fnm := b.getAppFn
    let args := b.getAppArgs
    let mut s := s!"HEAD {fnm.constName?} nargs={args.size} (pinsHd binders={names.size}) top-theorem lambda binders={xs.size}\n"
    for i in [0:args.size] do
      let a := args[i]!
      let nm := names[i]?.getD `_
      let kind ← match a.consumeMData with
        | .fvar id => do
            let d ← id.getDecl
            pure s!"FORWARD {d.userName}"
        | e => pure s!"TERM head={e.getAppFn.constName?}"
      let pp ← ppExpr a
      let t := (toString pp).replace "\n" " "
      s := s ++ s!"ARG {nm} <- {kind} :: {t.take 260}\n"
    IO.FS.writeFile file s

def useAn (n : Name) (file : String) : MetaM Unit := do
  let ci ← getConstInfo n
  let v ← valOf ci
  lambdaTelescope v fun xs b => do
    let mut s := s!"USES {n} binders={xs.size}\n"
    for x in xs do
      let d ← x.fvarId!.getDecl
      let inBody := b.containsFVar x.fvarId!
      let isP ← isProp d.type
      s := s ++ s!"USE {d.userName} prop={isP} inBody={inBody}\n"
    IO.FS.writeFile file s

def hluTest (file : String) : MetaM Unit := do
  let ci ← getConstInfo `ZK60.ProtocolClassify.sshC_productionReadyL_epP_shieldInst
  forallTelescope ci.type fun xs _ => do
    let find (n : Name) : MetaM Expr := do
      for x in xs do
        if (← x.fvarId!.getDecl).userName == n then return x
      throwError "no {n}"
    let hLu ← find `hLuStg
    let T ← inferType hLu
    let eI ← find `eI
    let eO ← find `eO
    let LI ← find `ΛI
    let LO ← find `ΛO
    let sh ← getConstInfo `ZK60.ProtocolClassify.shd_hLuStg
    let lvls ← sh.levelParams.mapM fun _ => mkFreshLevelMVar
    let (ms, _, C) ← forallMetaTelescopeReducing (sh.instantiateTypeLevelParams lvls)
    let mI ← mkFreshExprMVar (← inferType LI)
    let mO ← mkFreshExprMVar (← inferType LO)
    let T' := T.replaceFVars #[eI, eO, LI, LO] #[mkConst `ZK60.ProtocolClassify.shdP_eI, mkConst `ZK60.ProtocolClassify.shdP_eO, mI, mO]
    let ok ← isDefEq T' C
    let mut s := s!"isDefEq (hLuStg at eI:=shdP_eI, eO:=shdP_eO, LI:=?, LO:=?) with shd_hLuStg conclusion: {ok}\n"
    let ppT ← ppExpr (← instantiateMVars T')
    s := s ++ s!"HLUSTG (instantiated) :: {(toString ppT).replace "\n" " "}\n"
    let ppC ← ppExpr (← instantiateMVars C)
    s := s ++ s!"SHD_HLUSTG CONCL (instantiated) :: {(toString ppC).replace "\n" " "}\n"
    for m in ms do
      let v ← instantiateMVars m
      let t ← inferType m
      let ppt ← ppExpr (← instantiateMVars t)
      if v.isMVar then s := s ++ s!"UNASSIGNED {(toString ppt).replace "\n" " " |>.take 200}\n"
    s := s ++ s!"LI := {(toString (← ppExpr (← instantiateMVars mI))).replace "\n" " " |>.take 400}\n"
    s := s ++ s!"LO := {(toString (← ppExpr (← instantiateMVars mO))).replace "\n" " " |>.take 400}\n"
    IO.FS.writeFile file s

run_cmd liftTermElabM do
  let P := `ZK60.ProtocolClassify
  dumpSigP (P ++ `RunShapeP ++ `sshC_productionReadyL_epP_pinsHd) (OUTD ++ "sigp_pinsHd.txt")
  dumpSigP (P ++ `sshC_productionReadyL_epP_shieldInst) (OUTD ++ "sigp_shieldInst.txt")
  argMap (P ++ `sshC_productionReadyL_epP_shieldInst) (P ++ `RunShapeP ++ `sshC_productionReadyL_epP_pinsHd) (OUTD ++ "argmap.txt")
  useAn (P ++ `sshC_productionReadyL_epP_shieldInst) (OUTD ++ "use_top.txt")
  hluTest (OUTD ++ "hlu_test.txt")
  let mut s := ""
  for n in [`shdP_rtRun, `shdP_wDelta, `shdRkD, `shdRkBase, `shdP_clampPk, `shdP_runV, `shdP_Iin, `shdP_rtBlk] do
    let nm := P ++ n
    let st ← getReducibilityStatus nm
    s := s ++ s!"{nm} : {repr st}\n"
  IO.FS.writeFile (OUTD ++ "reducibility.txt") s

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX ZK60.RunShape ZK60.ProtocolClassify
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
-- D5: the trivial predicate satisfies Rbr and StgLkAtV; only the doom premises can rule it out.
section Trivial
variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] {L : ℕ}

theorem trivial_rbr (m hdrLen e : ℕ) (absOf : QB L → Option (List UInt8)) :
    (stgLkSqV (K := K) m hdrLen e absOf (fun _ _ => True)).Rbr :=
  stgLkSqV_rbr m hdrLen e absOf _ (fun _ _ _ _ hns => absurd trivial hns)

theorem trivial_lkAt (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Exec.Block.BlockParams)
    (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB L → Option (List UInt8))
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) :
    StgLkAtV U key domain Pof m hdrLen bgaOf absOf (fun _ _ => True) G Lg τ :=
  fun _ _ _ _ _ => trivial

end Trivial
#print axioms trivial_rbr
#print axioms trivial_lkAt
