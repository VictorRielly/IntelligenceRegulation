-- D63 generic-lemma lane (2026-11-06): the axiom audit of every theorem in CompleteSub.lean and ZKHybrid.lean.
-- Run: lake -d formal env lean results/zk60_lean_gen_20261106/axioms_gen.lean
import ZK60Formal.CompleteSub
import ZK60Formal.ZKHybrid

open ZK60.Complete ZK60.ZKHybrid

-- CompleteSub: probability helpers
#print axioms one_sub_le_prob
#print axioms prob_forall_ge
#print axioms prob_snd_mem_le
#print axioms prHC_le_of_forall
#print axioms fresh_point_prob_le
#print axioms fresh_point_prob_le_coins
-- CompleteSub (a): the sumcheck, masked, extended; the zero-check; batching
#print axioms interpEval_honestMsg
#print axioms honestMsg_check
#print axioms sumcheck_complete
#print axioms sumcheck_complete_prob
#print axioms sumcheck_complete_list
#print axioms sumcheck_complete_masked
#print axioms sumcheck_complete_extended
#print axioms zerocheck_complete
#print axioms batch_complete
-- CompleteSub (a'): the CFS mask in coefficient form
#print axioms cfs_masked_chainDefect
#print axioms cfs_masked_honest
#print axioms cfs_refusal_prob
-- CompleteSub (b): LogUp
#print axioms exists_tupleMass
#print axioms regroup
#print axioms logup_identity_honest
#print axioms logup_ratfunc_honest
#print axioms helperRel_honest
#print axioms logupRefuses_iff
#print axioms not_mem_poles_of_not_refuses
#print axioms logup_block_complete
#print axioms logup_complete_prob_gen
#print axioms logup_block_complete_prob
-- CompleteSub (c): the opening and the Merkle tree
#print axioms opening_complete
#print axioms opening_complete_prob
#print axioms mproduct_complete
#print axioms mopening_complete
#print axioms treePath_length
#print axioms climb_treePath
#print axioms opens_honest
#print axioms colCommit_opens_honest
-- CompleteSub (d): composition into Complete / ArithComplete
#print axioms complete_of_checks
#print axioms arithComplete_of_checks
-- ZKHybrid: uniform laws
#print axioms prob_marginal
#print axioms prob_const
-- ZKHybrid (A): programming the random oracle
#print axioms program_at
#print axioms program_off
#print axioms runLog_program
#print axioms progSwap_bad
#print axioms progSwap_good
#print axioms run_program_good
#print axioms progSwap_involutive
#print axioms real_swap_iff
#print axioms program_coupling
#print axioms progBad_le
#print axioms program_real_ideal
#print axioms program_real_ideal_inj
-- ZKHybrid (B): the R-receipt hybrid
#print axioms ovr_append
#print axioms ovr_ofFn_program
#print axioms runState_ask
#print axioms within_ask_pos
#print axioms telescope_le
#print axioms telescope_ge
#print axioms splitHead
#print axioms extend_fst
#print axioms extend_snd
#print axioms hyb_run_real
#print axioms hyb_run_sim
#print axioms toSim_run
#print axioms toSim_run_init
#print axioms hybProb_zero
#print axioms hybProb_ge
#print axioms zeroKnowledge_of_hybrid
#print axioms zeroKnowledge_of_hybrid_uniform
#print axioms zeroKnowledge_min_one
#print axioms zeroKnowledge_target_of_hybrid
