/-
Gap audit (premise register, 2026-11-10), scratch file A: the EXACT statements of the top theorems, as Lean prints
them, their axioms, the premise structures they take, and the dependency closure of the top run theorem inside the
`ZK60` namespace. Never imported by the root; run with `lake env lean`.
-/
import ZK60Formal

set_option pp.proofs false
set_option pp.fieldNotation true
set_option pp.funBinderTypes true
set_option pp.piBinderTypes true

open ZK60

/-! ## 1. The top theorems, every binder shown -/

#check @ZK60.ProtocolClassify.rt_productionReady_r13
#check @ZK60.ProtocolClassify.classifyU_productionReady_run_r13_token
#check @ZK60.ProtocolClassify.classifyUExec_productionReady_run_r13
#check @ZK60.ProtocolClassify.classifyU_productionReady_run_r13
#check @ZK60.Exec.Block.block_knowledge_final_r13_shield
#check @ZK60.Exec.Block.block_knowledge_final_w16r2

/-! ## 2. Axioms -/

#print axioms ZK60.ProtocolClassify.rt_productionReady_r13
#print axioms ZK60.ProtocolClassify.classifyU_productionReady_run_r13_token
#print axioms ZK60.ProtocolClassify.classifyUExec_productionReady_run_r13
#print axioms ZK60.ProtocolClassify.classifyU_productionReady_run_r13
#print axioms ZK60.Exec.Block.block_knowledge_final_r13_shield
#print axioms ZK60.Exec.Block.block_knowledge_final_r13
#print axioms ZK60.Exec.Block.block_knowledge_final_w16r2

/-! ## 3. The structures the premises are made of -/

#print ZK60.ProtocolClassify.ClassifyOpen
#print ZK60.ProtocolClassify.RtRun
#print ZK60.ProtocolClassify.RtProf
#print ZK60.ProtocolClassify.RtProf.Valid
#print ZK60.ProtocolClassify.RtKData
#print ZK60.ProtocolClassify.RtKData.Valid
#print ZK60.ProtocolClassify.RtOpen.Valid
#print ZK60.ProtocolClassify.XTest
#print ZK60.ProtocolClassify.HonestIn
#print ZK60.ProtocolClassify.Site
#print ZK60.ProtocolClassify.RunV
#print ZK60.ProtocolClassify.RunP
#print ZK60.Exec.PlaneCommit
#print ZK60.Exec.R13.r13TokenCommit
#print ZK60.ProtocolClassify.classifyProtocolU
#print ZK60.TokenRun.classifyModel
#print ZK60.ProtocolClassify.AliveOrd
#print ZK60.ProtocolClassify.EvXR

/-! ## 4. The model's types: the weights and the hidden output are `Unit` -/

example (S : ZK60.Block.BlockShape) (R : ZK60.TokenRun.ClassifyRunPublic S) :
    (ZK60.TokenRun.classifyModel S R).Weights = Unit := rfl
example (S : ZK60.Block.BlockShape) (R : ZK60.TokenRun.ClassifyRunPublic S) :
    (ZK60.TokenRun.classifyModel S R).HidOut = Unit := rfl

/-! ## 5. The dependency closure of the top run theorem inside `ZK60` -/

open Lean in
/-- Every `ZK60.*` constant reachable from `root` through types and values (theorem proofs included). -/
def gapDeps (env : Environment) (root : Name) : NameSet := Id.run do
  let mut seen : NameSet := {}
  let mut todo : Array Name := #[root]
  let mut fuel := 1000000
  while todo.size > 0 && fuel > 0 do
    fuel := fuel - 1
    let n := todo.back!
    todo := todo.pop
    if seen.contains n then continue
    seen := seen.insert n
    match env.find? n with
    | some ci =>
      let cs := ci.type.getUsedConstants ++
        (match ci.value? (allowOpaque := true) with | some v => v.getUsedConstants | none => #[])
      for c in cs do
        if (`ZK60).isPrefixOf c && !seen.contains c then todo := todo.push c
    | none => pure ()
  return seen

open Lean Elab Command in
elab "#gap_deps " root:ident " [" probes:ident,* "]" : command => do
  let env ← getEnv
  let r := root.getId
  let s := gapDeps env r
  logInfo m!"{r}: {s.toList.length} ZK60 constants in the closure"
  for p in probes.getElems do
    logInfo m!"  {p.getId} in closure: {s.contains p.getId}"

#gap_deps ZK60.ProtocolClassify.rt_productionReady_r13 [
  ZK60.ProtocolClassify.ClassifyOpen.extIn, ZK60.ProtocolClassify.ClassifyOpen.extBlocks,
  ZK60.ProtocolClassify.ClassifyOpen.extOut, ZK60.ProtocolClassify.ClassifyOpen.extEp,
  ZK60.ProtocolClassify.ClassifyOpen.zk, ZK60.ProtocolClassify.ClassifyOpen.parts,
  ZK60.ProtocolClassify.ClassifyOpen.refuse, ZK60.ProtocolClassify.ClassifyOpen.counts,
  ZK60.ProtocolClassify.ClassifyOpen.shape, ZK60.ProtocolClassify.ClassifyOpen.weights,
  ZK60.ProtocolClassify.ClassifyOpen.inPub, ZK60.ProtocolClassify.ClassifyOpen.outPub,
  ZK60.ProtocolClassify.ClassifyOpen.blocks, ZK60.ProtocolClassify.ClassifyOpen.commit,
  ZK60.ProtocolClassify.ClassifyOpen.policy,
  ZK60.Exec.Block.block_knowledge_final_r13_shield, ZK60.Exec.Block.block_knowledge_final_r13,
  ZK60.Exec.Block.block_knowledge_final_w16r2,
  ZK60.TokenRun.classifyRun_circuitIff, ZK60.ProtocolClassify.classify_complete_target,
  ZK60.ProtocolClassify.rtRunClassify, ZK60.ProtocolClassify.rt_hwin,
  ZK60.ProtocolClassify.classify_productionReady, ZK60.ProtocolClassify.classifyU_productionReady_ep_target,
  ZK60.Assembly.semanticHiding_of_zeroKnowledge, ZK60.Exec.encLin_caOn]
