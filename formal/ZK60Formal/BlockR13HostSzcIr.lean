/-
D63 lane L49 (2026-11-10), sub-agent `szc`, part 1: **R13's `SC_SZC` IR, evaluated** (the IR builder
`DefR13.r13SzcIr`, a transcription of `slot_ir_accuracy.rs:311-428`, non-DD, read in any commutative ring, as L13's
`szcIr_eval` reads W16R2's).

* `reqV8`: a requantization host with byte limbs, `2^s·x + Σ_k 256^k·l_k − 2^(s−1)`;
* `r13SzcDelta`: `δ = mx − mask·s8 − 127·mask + 127`;
* `r13SzcClauses`: the batch's five softmax clauses `s0 … s4`: `zsel² − zsel`, `zsel·δ`,
  `2^f_p·mask·e − p·sum − Σ_k 256^k·sr_k`, `Σ 256^k·sg_k + Σ 256^k·sr_k + 1 − sum`, `p − Σ_k 256^k·pl_k`;
* `r13SzcExp`: the exp tuple's relation `hx·(α − g_exp − δ − β·e) − 1`;
* **`r13SzcIr_eval`**: the slot polynomial is L13's three host terms with
  `Z = logup + μ_{5+h}·exp + pad + gate·Σ_k μ_k·c_k` (`μ_0 … μ_4` the clauses, `μ_5 …` LogUp's helpers, the exp tuple
  after them, the pad weight last) and the hosts `sum + λ`, `reqV8 score s8 rsl`;
* `r13SzcIr_map`: the builder commutes with reading its coefficients elsewhere.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.SlotW16BuildSlots
import ZK60Formal.SlotW16Compose
import ZK60Formal.BlockR13Prog

-- The node computations try a short list of simp sets (`first | … | …`); Mathlib's style linters flag the
-- alternatives not taken. Style warnings only.
set_option linter.unusedSimpArgs false
set_option linter.unreachableTactic false
set_option linter.unusedTactic false
set_option linter.unnecessarySeqFocus false

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Szc

open ZK60.Exec ZK60.Exec.Slot ZK60.Exec.Slot.Build
open ZK60.Exec.Block.DefR13 (SzcR13 r13SzcIr r13SzcPre r13SzcPost)

section Eval

variable {R : Type} [CommRing R]

/-- **A requantization host with byte limbs** `2^s·x + Σ_k 256^k·l_k − 2^(s−1)` (R13's `reqB` after `limbsB`). -/
def reqV8 (c : Cst R) (v : List R) (s x : ℕ) (l : List ℕ) : R :=
  c.base (2 ^ s) * v.getD x 0 + L256 c v l + c.base (-(2 ^ (s - 1) : ℤ))

/-- `δ = mx − mask·s8 − 127·mask + 127`, as the code writes it (slot_ir_accuracy.rs:376-381). -/
def r13SzcDelta (c : Cst R) (Rr : SzcR13) (v : List R) : R :=
  v.getD Rr.mx 0 - v.getD Rr.mask 0 * v.getD Rr.s8 0 + c.base (-127) * v.getD Rr.mask 0 + c.base 127

/-- **R13 `szc`'s five softmax clauses** (slot_ir_accuracy.rs:382-398): `s0 = zsel² − zsel`, `s1 = zsel·δ`,
`s2 = 2^f_p·mask·e − p·sum − sr`, `s3 = sg + sr + 1 − sum`, `s4 = p − pl` (the remainders' and the quotient's byte
limbs `Σ_k 256^k·t_k`). -/
def r13SzcClauses (c : Cst R) (Rr : SzcR13) (fp : ℕ) (v : List R) : List R :=
  [v.getD Rr.zsel 0 * v.getD Rr.zsel 0 - v.getD Rr.zsel 0, v.getD Rr.zsel 0 * r13SzcDelta c Rr v,
    c.base (2 ^ fp) * (v.getD Rr.mask 0 * v.getD Rr.e 0) - v.getD Rr.p 0 * v.getD Rr.sum 0 - L256 c v Rr.sr,
    L256 c v Rr.sg + L256 c v Rr.sr + 1 - v.getD Rr.sum 0,
    v.getD Rr.p 0 - L256 c v Rr.pl]

/-- **The exp tuple's relation** `hx·(α − g_exp − δ − β·e) − 1` (`amdK = α − g_exp`, `nb = −β`). -/
def r13SzcExp (c : Cst R) (Rr : SzcR13) (v : List R) (amdK nb : R) : R :=
  v.getD Rr.hx 0 * (amdK - r13SzcDelta c Rr v + nb * v.getD Rr.e 0) - 1

/-- **R13 `SC_SZC`'s polynomial** (slot_ir_accuracy.rs:311-428): the host terms with `Z = logup + μ·exp + pad +
gate·Σ_k μ_k·c_k` (the five clauses at `μ_0 … μ_4`, LogUp's helpers from `μ_5`, the exp tuple after them, the pad
weight last) and the hosts `sum + λ` (`SC_RS`), `reqV8 score s8 rsl` (`SC_SCORE`). -/
theorem r13SzcIr_eval (c : Cst R) (hc : c.Std) (v : List R) (Rr : SzcR13) (fp score : ℕ) (lks : List (LkD R))
    (mu nu : List R) (amdK nb lam : R) (zp : ℕ → R) (groups : List (ℕ × List ℕ)) :
    irEval (r13SzcIr c Rr fp score lks mu nu amdK nb lam zp groups) v
      = hostTerms v 0 1 2 Rr.gHt Rr.gS nu
          (logupSem c v Rr.h0 (fun k => mu.getD (5 + k) 0) 0 lks
            + mu.getD (5 + (lks.length + 1) / 2) 0 * r13SzcExp c Rr v amdK nb
            + padSem c v (mu.getD (6 + (lks.length + 1) / 2) 0) zp 0 groups
            + gV v Rr.gS * batchV mu (r13SzcClauses c Rr fp v))
          (v.getD Rr.sum 0 + lam) (reqV8 c v score Rr.s8 Rr.rsl) := by
  obtain ⟨A, ⟨t, hAt⟩, hnv, ht⟩ := zcIr_vals c v (r13SzcPre c Rr fp mu amdK nb) lks Rr.h0
    (fun k => mu.getD (5 + k) c.zero) [st (mu.getD (5 + (lks.length + 1) / 2) c.zero) [.node 10]]
    (mu.getD (6 + (lks.length + 1) / 2) c.zero) zp groups [gatedSt c Rr.gS 11] (r13SzcPost c Rr score lam)
    (fun o => [⟨c.one, [0], [.node o]⟩, ⟨nu.getD 0 c.zero, 1 :: Rr.gHt.toList, [.node (o + 1)]⟩,
      ⟨nu.getD 1 c.zero, 2 :: Rr.gS.toList, [.node (o + 3)]⟩])
  have hlen : (nodeVals v (r13SzcPre c Rr fp mu amdK nb) []).length = 12 := by
    rw [nodeVals_length]; simp [r13SzcPre]
  have h10 : A.getD 10 0 = r13SzcExp c Rr v amdK nb := by
    rw [hAt, getD_lt _ _ _ (by omega)]
    first
    | (simp only [r13SzcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_cons_succ, List.getD_cons_zero, bodyVal_limbs256 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB,
        st, fval, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.prod_cons, List.prod_nil,
        List.zipIdx_cons, List.zipIdx_nil, r13SzcExp, r13SzcDelta, hc.one, hc.negOne, hc.zero] <;> ring)
    | (simp [r13SzcPre, nodeVals, bodyVal_limbs256 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval,
        r13SzcExp, r13SzcDelta, hc.one, hc.negOne, hc.zero] <;> ring)
  have h11 : A.getD 11 0 = batchV mu (r13SzcClauses c Rr fp v) := by
    rw [hAt, getD_lt _ _ _ (by omega)]
    first
    | (simp only [r13SzcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_cons_succ, List.getD_cons_zero, bodyVal_limbs256 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB,
        st, fval, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.prod_cons, List.prod_nil,
        List.zipIdx_cons, List.zipIdx_nil, batchV, r13SzcClauses, r13SzcDelta, hc.one, hc.negOne, hc.zero] <;> ring)
    | (simp [r13SzcPre, nodeVals, bodyVal_limbs256 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval,
        batchV, r13SzcClauses, r13SzcDelta, hc.one, hc.negOne, hc.zero] <;> ring)
  have hpost : ∀ z : R, nodeVals v (r13SzcPost c Rr score lam (A.length + 1)) (A ++ [z])
      = A ++ [z, v.getD Rr.sum 0 + lam, L256 c v Rr.rsl, reqV8 c v score Rr.s8 Rr.rsl] := by
    intro z
    simp only [r13SzcPost, nodeVals, bodyVal_limbs256 c hc, bodyVal_req c hc, List.append_assoc,
      List.singleton_append, List.cons_append, List.nil_append, Nat.add_assoc, getD_len_add, List.getD_cons_succ,
      List.getD_cons_zero, reqV8, bodyVal_sum, bodyVal_affine, stVal, st, List.map_cons, List.map_nil, List.sum_cons,
      List.sum_nil, List.prod_cons, List.prod_nil, fval, hc.one, mul_one, one_mul, add_zero]
  unfold r13SzcIr irEval
  rw [hnv, ht, hpost]
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, stVal_gated c hc, h11, hc.zero, add_zero]
  simp only [stVal, st, fval, List.map_cons, List.map_nil, List.prod_cons, List.prod_nil, mul_one, h10, hc.zero]
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, termVal, fval, getD_len, getD_len_add,
    List.getD_cons_zero, List.getD_cons_succ, List.prod_cons, List.prod_nil, hc.one, hc.zero, hostTerms]
  cases Rr.gHt <;> cases Rr.gS <;> simp [gV] <;> ring

end Eval

/-- **R13 `szc`'s builder commutes with reading its coefficients elsewhere.** -/
theorem r13SzcIr_map {α β : Type} (f : α → β) (c : Cst α) (Rr : SzcR13) (fp score : ℕ) (lks : List (LkD α))
    (mu nu : List α) (amdK nb lam : α) (zp : ℕ → α) (groups : List (ℕ × List ℕ)) :
    (r13SzcIr c Rr fp score lks mu nu amdK nb lam zp groups).map f
      = r13SzcIr (c.map f) Rr fp score (lks.map (LkD.map f)) (mu.map f) (nu.map f) (f amdK) (f nb) (f lam) (f ∘ zp)
          groups := by
  unfold r13SzcIr
  rw [zcIr_map]
  simp only [r13SzcPre, r13SzcPost, gatedSt, limbsB, reqB, batchB, st, List.map_cons, List.map_nil, Body.map,
    SubTerm.map, Term.map, Cst.map, List.map_map, Function.comp_def, ZK60.Exec.Slot.Compose.getD_map_f,
    List.length_map, Option.map_map] <;> rfl

end ZK60.Exec.Block.Join.R13H.Szc
