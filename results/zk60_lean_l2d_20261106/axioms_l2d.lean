-- D63 L1/L2, fourth Lean lane (2026-11-06): the axiom audit of every theorem the lane adds or changes.
-- Run: lake -d formal env lean results/zk60_lean_l2d_20261106/axioms_l2d.lean
import ZK60Formal.CircuitTokenRun

open ZK60.Block ZK60.Out ZK60.TokenRun

-- CircuitBlock.lean (changed: the product's word class is the shape's stack)
#print axioms BlockShape.prodC_bounds
#print axioms productC_iff
#print axioms prodPlane_iff
#print axioms blockSat_iff
#print axioms blockSpec_class
#print axioms block_circuitIff
#print axioms run_iff
#print axioms run_circuitIff
-- CircuitOut.lean
#print axioms byteLimbs_iff
#print axioms xBytes_iff
#print axioms argmaxN_succ
#print axioms argmaxN_spec
#print axioms argmaxN_unique
#print axioms lfun_fin
#print axioms two_ne_zero_gf
#print axioms two_pow_ne_zero_gf
#print axioms selector_one
#print axioms sum_indicator
#print axioms argmax_iff
#print axioms ss_bounds40
#print axioms fnormElem_eq_some
#print axioms fnormDiv_iff
#print axioms fnormTok_iff
#print axioms fnormTok_class
#print axioms logit_cast
#print axioms logit_abs_le
#print axioms out_iff
#print axioms verdict_iff
#print axioms margin_abs_le
#print axioms outC_iff
-- CircuitTokenRun.lean
#print axioms lt_gP_of_V
#print axioms ctl_le
#print axioms ctlPos_le
#print axioms in_iff
#print axioms inSpec_some
#print axioms inSpec_class
#print axioms outSpec_lt
#print axioms runOut_iff
#print axioms tokenRun_iff
#print axioms tokenSpec_lt
#print axioms tokenRun_circuitIff
#print axioms verdictOf_le
#print axioms classifyRun_iff
#print axioms classifyRun_circuitIff
