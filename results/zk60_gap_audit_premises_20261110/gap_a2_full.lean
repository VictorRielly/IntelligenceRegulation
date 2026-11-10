/-
Gap audit (premise register, 2026-11-10), scratch file A2: the top theorems' statements printed IN FULL (no `⋯`), so
the register can be read off Lean's own output. Never imported by the root; run with `lake env lean`.
-/
import ZK60Formal

set_option pp.proofs false
set_option pp.maxSteps 10000000
set_option pp.deepTerms true
set_option pp.deepTerms.threshold 100000
set_option pp.funBinderTypes true
set_option pp.piBinderTypes true

#check @ZK60.ProtocolClassify.rt_productionReady_r13
#check @ZK60.ProtocolClassify.classifyUExec_productionReady_run_r13
#check @ZK60.Exec.Block.block_knowledge_final_r13_shield
#print ZK60.ProtocolClassify.SegComplete
#print ZK60.ProtocolClassify.RunExt
#print ZK60.ProtocolClassify.InOk
#print ZK60.ProtocolClassify.OutOk
#print ZK60.ProtocolClassify.BlockOn
#print ZK60.ProtocolClassify.KindRun
#print ZK60.ProtocolClassify.RtMask
#print ZK60.ProtocolClassify.RtOpen
#print ZK60.Exec.PlaneCommit.SaltMk
#print ZK60.Exec.PlaneCommit.OpensU
#print ZK60.ProtocolClassify.RtSeg.Holds
#print ZK60.ProtocolClassify.clsStmtOf
#print ZK60.ProtocolClassify.Site.fires
