-- D63 assembly lane (2026-11-06): the axiom audit of every theorem in Assembly.lean.
-- Run: lake -d formal env lean results/zk60_lean_asm_20261106/axioms_asm.lean
import ZK60Formal.Assembly

open ZK60.Assembly

-- oracle computations and uniform laws
#print axioms runState_mapOut
#print axioms within_mapOut
#print axioms within_liftHash
#print axioms runState_liftHash
#print axioms prob_coin0
#print axioms avg_le
-- (a) T2 ⇒ T2′
#print axioms semDist_within
#print axioms realProb_eq
#print axioms realProb_semDist
#print axioms idealProb_semDist
#print axioms semanticHiding_of_zeroKnowledge
-- (b) Statement 1 from the IOP-level extraction; completeness
#print axioms knowledgeSound_of_extract
#print axioms complete_of_arithComplete
#print axioms arithComplete_iff_complete
-- (c) the assembly and monotonicity
#print axioms productionReady_of
#print axioms productionReady_of_arith
#print axioms complete_mono
#print axioms knowledgeSound_mono
#print axioms iopExtract_mono
#print axioms binding_mono
#print axioms zeroKnowledge_mono
#print axioms productionReady_mono
-- (d) Binding from Merkle binding
#print axioms ColCommit.binding
#print axioms binding_of_colCommit
