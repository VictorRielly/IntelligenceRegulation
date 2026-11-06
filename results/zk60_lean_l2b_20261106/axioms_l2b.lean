import ZK60Formal
open ZK60.Circuit ZK60.Block
-- Every theorem of the five new files (third lane, 2026-11-06: the second lane's list, completed with the helpers).
-- the matmul hand-off (CircuitMatmul)
#print axioms ZK60.Circuit.hosted_cast
#print axioms ZK60.Circuit.bilinear_cast
#print axioms ZK60.Circuit.dot_abs_le
#print axioms ZK60.Circuit.hosted_abs_le
#print axioms ZK60.Circuit.requantIn_mul
#print axioms ZK60.Circuit.matmul_requant_iff
#print axioms ZK60.Circuit.bilinear_requant_iff
#print axioms ZK60.Circuit.abs_le_of_int16
#print axioms ZK60.Circuit.hosted16_le
#print axioms ZK60.Circuit.hosted24_le
#print axioms ZK60.Circuit.hostedScore_le
#print axioms ZK60.Circuit.hostedPV_le
#print axioms ZK60.Circuit.noWrap_class_bounds
#print axioms ZK60.Circuit.ss_bounds
#print axioms ZK60.Circuit.ss_cast
-- RoPE, the product, the functional tables, the LogUp table (CircuitRopeAct)
#print axioms ZK60.Circuit.ropeRel_iff
#print axioms ZK60.Circuit.abs_ropeSgn_mul
#print axioms ZK60.Circuit.rope_iff
#print axioms ZK60.Circuit.rope_pair
#print axioms ZK60.Circuit.prodRel_iff
#print axioms ZK60.Circuit.product_iff
#print axioms ZK60.Circuit.natCast_inj_lt
#print axioms ZK60.Circuit.expQuery_iff
#print axioms ZK60.Circuit.actQuery_iff
#print axioms ZK60.Circuit.gateAct_iff
#print axioms ZK60.Circuit.codeTable_range_iff
#print axioms ZK60.Circuit.codeTable_exp_iff
#print axioms ZK60.Circuit.codeTable_act_iff
#print axioms ZK60.Circuit.w16r2Fams_FamsOK
-- stages (CircuitStage)
#print axioms ZK60.Circuit.liftO_eq_some
#print axioms ZK60.Circuit.liftO_exists
#print axioms ZK60.Circuit.obind_eq_some
#print axioms ZK60.Circuit.obind_some
#print axioms ZK60.Circuit.rq_eq_some
#print axioms ZK60.Circuit.rq_class
#print axioms ZK60.Circuit.liftO_rq_class
#print axioms ZK60.Circuit.rqPlane_iff
#print axioms ZK60.Circuit.rqPlaneBil_iff
#print axioms ZK60.Circuit.normTok_iff
#print axioms ZK60.Circuit.normTok_class
#print axioms ZK60.Circuit.delta_eq
#print axioms ZK60.Circuit.mask_e_eq
#print axioms ZK60.Circuit.num_eq
#print axioms ZK60.Circuit.term_nonneg
#print axioms ZK60.Circuit.totalOf_bounds
#print axioms ZK60.Circuit.num_bounds
#print axioms ZK60.Circuit.softmaxRow_iff
#print axioms ZK60.Circuit.softmaxF_class
-- the causal mask (CircuitMasked, candidate C9)
#print axioms ZK60.Circuit.masked_column_forced
#print axioms ZK60.Circuit.softmaxF_live_only
-- the block and the run (CircuitBlock)
#print axioms ZK60.Block.residual_class
#print axioms ZK60.Block.resPlane_iff
#print axioms ZK60.Block.ropePlane_iff
#print axioms ZK60.Block.prodPlane_iff
#print axioms ZK60.Block.gatePlane_iff
#print axioms ZK60.Block.normPlane_iff
#print axioms ZK60.Block.blockSat_iff
#print axioms ZK60.Block.blockSpec_class
#print axioms ZK60.Block.i16_eq_of_cast
#print axioms ZK60.Block.block_circuitIff
#print axioms ZK60.Block.runSpec_class
#print axioms ZK60.Block.run_iff
#print axioms ZK60.Block.run_circuitIff
#print axioms ZK60.Block.w16r2_8B_geometry
-- the L1 check's host residual
#print axioms ZK60.L1.hostRes_zero_iff
