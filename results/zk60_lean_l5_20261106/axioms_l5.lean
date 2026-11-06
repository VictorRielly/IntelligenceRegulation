import ZK60Formal.ExecMerkle

-- D63 step L5 (2026-11-06): the axiom audit of the executable foundation's theorems. Each must show at most
-- `propext`, `Classical.choice`, `Quot.sound` (no `sorryAx`, no `Lean.ofReduceBool`).

open ZK60.Exec

-- ExecField.lean: bytes
#print axioms leNat_leBytes
#print axioms leNat_lt
#print axioms leNat_le64
#print axioms ofLE64_le64
-- ExecField.lean: the base field
#print axioms Fp.new_toNat
#print axioms Fp.new_canon
#print axioms Fp.add_toNat
#print axioms Fp.sub_toNat
#print axioms Fp.neg_toNat
#print axioms Fp.t0_spec
#print axioms Fp.t1_spec
#print axioms Fp.res_spec
#print axioms Fp.reduce128_arith
#print axioms Fp.reduce128_toNat
#print axioms Fp.mul_toNat
#print axioms Fp.mul_canon
#print axioms Fp.add_canon
#print axioms Fp.sub_canon
#print axioms Fp.neg_canon
#print axioms Fp.toGF_add
#print axioms Fp.toGF_sub
#print axioms Fp.toGF_neg
#print axioms Fp.toGF_mul
#print axioms Fp.toGF_reduce128
#print axioms Fp.toGF_new
#print axioms Fp.toGF_powAux
#print axioms Fp.toGF_pow
#print axioms Fp.pow_canon
#print axioms Fp.toGF_inv
#print axioms Fp.inv_canon
#print axioms Fp.toGF_zero_iff
#print axioms Fp.toGF_ofGF
#print axioms Fp.ofGF_canon
#print axioms Fp.toGF_injective
#print axioms Fp.ofGF_toGF
#print axioms seven_not_square
-- ExecField.lean: the extension field
#print axioms Fp2.fromBytes_toBytes
#print axioms Fp2.toK_add
#print axioms Fp2.toK_sub
#print axioms Fp2.toK_neg
#print axioms Fp2.toK_mul
#print axioms Fp2.toK_mulBase
#print axioms Fp2.canon_mul
#print axioms Fp2.toK_one
#print axioms Fp2.norm_toGF
#print axioms Fp2.norm_ne_zero
#print axioms Fp2.toK_inv
#print axioms Fp2.toK_bijective
-- ExecTranscript.lean
#print axioms digOf?_toList
#print axioms leNat_le64_ofNat
#print axioms decodeLink_msg
#print axioms decodeLink_none_of_long
#print axioms startMsg_ok_rungG
#print axioms chainEnc
#print axioms squeeze_out
#print axioms runOps_chainFrom
#print axioms runOps_chain
#print axioms leNat_take16_lt
#print axioms leNat_drop16_lt
#print axioms challengeFp2Of_toGF
#print axioms challengeFpOf_toGF
#print axioms idx_eq_idxChal
-- ExecMerkle.lean
#print axioms colBytes_length
#print axioms decColAux_colBytes
#print axioms decCol_colBytes
#print axioms splitDig_append
#print axioms merkleEnc
#print axioms foldPath_eq_climb
#print axioms verifyColumn_iff
#print axioms liftH_eq
#print axioms merkleEncB
#print axioms climbB_eq
#print axioms opensB_iff
#print axioms exec_merkle_binding
