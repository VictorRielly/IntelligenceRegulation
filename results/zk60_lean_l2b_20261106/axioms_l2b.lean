import ZK60Formal
open ZK60.Circuit ZK60.Block
-- the matmul hand-off (CircuitMatmul)
#print axioms ZK60.Circuit.hosted_cast
#print axioms ZK60.Circuit.dot_abs_le
#print axioms ZK60.Circuit.hosted_abs_le
#print axioms ZK60.Circuit.requantIn_mul
#print axioms ZK60.Circuit.matmul_requant_iff
#print axioms ZK60.Circuit.bilinear_requant_iff
#print axioms ZK60.Circuit.hosted16_le
#print axioms ZK60.Circuit.hosted24_le
#print axioms ZK60.Circuit.hostedScore_le
#print axioms ZK60.Circuit.hostedPV_le
#print axioms ZK60.Circuit.noWrap_class_bounds
#print axioms ZK60.Circuit.ss_bounds
-- RoPE, the product, the functional tables, the LogUp table (CircuitRopeAct)
#print axioms ZK60.Circuit.ropeRel_iff
#print axioms ZK60.Circuit.rope_iff
#print axioms ZK60.Circuit.rope_pair
#print axioms ZK60.Circuit.prodRel_iff
#print axioms ZK60.Circuit.product_iff
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
#print axioms ZK60.Circuit.rqPlane_iff
#print axioms ZK60.Circuit.rqPlaneBil_iff
#print axioms ZK60.Circuit.normTok_iff
#print axioms ZK60.Circuit.normTok_class
#print axioms ZK60.Circuit.softmaxRow_iff
#print axioms ZK60.Circuit.softmaxF_class
-- the causal mask (CircuitMasked, candidate C9)
#print axioms ZK60.Circuit.masked_column_forced
#print axioms ZK60.Circuit.softmaxF_live_only
-- the block and the run (CircuitBlock)
#print axioms ZK60.Block.resPlane_iff
#print axioms ZK60.Block.ropePlane_iff
#print axioms ZK60.Block.prodPlane_iff
#print axioms ZK60.Block.gatePlane_iff
#print axioms ZK60.Block.normPlane_iff
#print axioms ZK60.Block.blockSat_iff
#print axioms ZK60.Block.blockSpec_class
#print axioms ZK60.Block.block_circuitIff
#print axioms ZK60.Block.run_iff
#print axioms ZK60.Block.run_circuitIff
#print axioms ZK60.Block.w16r2_8B_geometry
