/-
D63 lane L49 (2026-11-10), sub-agent dzc, part 1: **R13's `SC_DZC` IR read in a ring** (`DefR13.r13DzcIr`,
BlockR13Prog.lean, the code's `slot_ir_accuracy.rs::dzc`, lines 124-192), as lane L13's `dzcIr_eval` reads W16R2's
(SlotW16BuildSlots.lean, through `zcIr_vals`).

* `reqV8`: a requantization host with byte limbs, `2^s·x + Σ_k 256^k·l_k − 2^(s−1)`; `post2_vals8`: the IR's two host
  nodes (`limbsB`, `reqB`) after the zero-check node;
* `r13DzcClauses`: the thirteen clauses in the IR's batch order (`batchB … [4, 5, 7, 9, 11, 13, 14, 15, 16, 18, 20,
  22, 23]`): `d0, d1, wX, wY, wAO, wX1, d2, d3, d4, wYM, wZ, wX2, d5`;
* **`r13DzcIr_eval`**: at any terminal values, the IR's value is L13's three host terms (`hostTerms`) with
  `Z = logupSem + padSem + gate·Σ_k μ_k·c_k` (LogUp weights `μ_{13+k}`, pad weight `μ_{13+#helpers}`) and the hosts
  `reqV8` of `SC_WO` and `SC_DMM`;
* **`r13DzcIr_map`**: the builder commutes with reading its coefficients elsewhere (`Ir.map`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13Prog
import ZK60Formal.SlotW16Compose

set_option autoImplicit false
-- The node-value computations use broad simp sets tried in turn; Mathlib's style linters flag the alternatives not
-- taken and the simp arguments a branch did not need. Style warnings only (as in `SlotW16BuildSlots.lean`).
set_option linter.unusedSimpArgs false
set_option linter.unreachableTactic false
set_option linter.unusedTactic false
set_option linter.unnecessarySeqFocus false

namespace ZK60.Exec.Block.Join.R13H.Dzc

open ZK60.Exec ZK60.Exec.Slot
open ZK60.Exec.Slot.Build
open ZK60.Exec.Slot.Compose (getD_map_f)
open ZK60.Exec.Block.DefR13 (DzcR13 r13DzcPre r13DzcPost int16B)

section Eval

variable {R : Type} [CommRing R]

/-- **A requantization host with byte limbs**: `2^s·x + Σ_k 256^k·l_k − 2^(s−1)`. -/
def reqV8 (c : Cst R) (v : List R) (s x : ℕ) (l : List ℕ) : R :=
  c.base (2 ^ s) * v.getD x 0 + L256 c v l + c.base (-(2 ^ (s - 1) : ℤ))

/-- **The two requantization hosts with byte limbs after the zero-check node** (`r13DzcPost`). -/
theorem post2_vals8 (c : Cst R) (hc : c.Std) (v A : List R) (z : R) (l₁ : List ℕ) (s₁ x₁ : ℕ) (l₂ : List ℕ)
    (s₂ x₂ : ℕ) :
    nodeVals v [limbsB c l₁, reqB c s₁ x₁ (A.length + 1), limbsB c l₂, reqB c s₂ x₂ (A.length + 1 + 2)] (A ++ [z])
      = A ++ [z, L256 c v l₁, reqV8 c v s₁ x₁ l₁, L256 c v l₂, reqV8 c v s₂ x₂ l₂] := by
  simp only [nodeVals, bodyVal_limbs256 c hc, bodyVal_req c hc, List.append_assoc, List.singleton_append,
    List.cons_append, List.nil_append, Nat.add_assoc, getD_len_add, List.getD_cons_succ, List.getD_cons_zero, reqV8]

/-- **R13 `SC_DZC`'s thirteen clauses in the IR's batch order** (slot_ir_accuracy.rs `c0 … c12`): the first norm's
`d0`, `d1`; the word decompositions `wX`, `wY`, `wAO`, `wX1` (`x + 32768 − limbs`); the residual `d2`; the second
norm's `d3`, `d4`; `wYM`, `wZ`, `wX2`; the residual `d5`. -/
def r13DzcClauses (c : Cst R) (Rr : DzcR13) (K : DzcK) (v : List R) : List R :=
  [c.base K.num * (v.getD Rr.ig 0 * v.getD Rr.x 0) + c.base K.dv * v.getD Rr.id 0
      + c.base (-K.den) * (v.getD Rr.y 0 * v.getD Rr.id 0) - L256 c v Rr.nr,
    L256 c v Rr.nr + L256 c v Rr.ns + 1 + c.base (-K.den) * v.getD Rr.id 0,
    v.getD Rr.x 0 + c.base 32768 - L256 c v Rr.xl,
    v.getD Rr.y 0 + c.base 32768 - L256 c v Rr.yl,
    v.getD Rr.ao 0 + c.base 32768 - L256 c v Rr.al,
    v.getD Rr.x1 0 + c.base 32768 - L256 c v Rr.x1l,
    v.getD Rr.x1 0 - v.getD Rr.x 0 - v.getD Rr.ao 0,
    c.base K.numM * (v.getD Rr.igm 0 * v.getD Rr.x1 0) + c.base K.dv * v.getD Rr.idm 0
      + c.base (-K.den) * (v.getD Rr.ym 0 * v.getD Rr.idm 0) - L256 c v Rr.mr,
    L256 c v Rr.mr + L256 c v Rr.ms + 1 + c.base (-K.den) * v.getD Rr.idm 0,
    v.getD Rr.ym 0 + c.base 32768 - L256 c v Rr.yml,
    v.getD Rr.z 0 + c.base 32768 - L256 c v Rr.zl,
    v.getD Rr.x2 0 + c.base 32768 - L256 c v Rr.x2l,
    v.getD Rr.x2 0 - v.getD Rr.x1 0 - v.getD Rr.z 0]

theorem r13DzcClauses_length (c : Cst R) (Rr : DzcR13) (K : DzcK) (v : List R) :
    (r13DzcClauses c Rr K v).length = 13 := rfl

/-- **R13 `SC_DZC`'s polynomial** (`r13DzcIr`): the host terms with `Z = logup + pad + gate·Σ_k μ_k·c_k` (the
thirteen clauses `r13DzcClauses`) and the byte-limb hosts `SC_WO` (`2^ao·ao + ral − 2^(ao−1)`) and `SC_DMM`
(`2^down·z + rdl − 2^(down−1)`). -/
theorem r13DzcIr_eval (c : Cst R) (hc : c.Std) (v : List R) (Rr : DzcR13) (K : DzcK) (lks : List (LkD R))
    (mu nu : List R) (zp : ℕ → R) (groups : List (ℕ × List ℕ)) :
    irEval (ZK60.Exec.Block.DefR13.r13DzcIr c Rr K lks mu nu zp groups) v
      = hostTerms v 0 1 2 Rr.gate Rr.gate nu
          (logupSem c v Rr.h0 (fun k => mu.getD (13 + k) 0) 0 lks
            + padSem c v (mu.getD (13 + (lks.length + 1) / 2) 0) zp 0 groups
            + gV v Rr.gate * batchV mu (r13DzcClauses c Rr K v))
          (reqV8 c v K.sao Rr.ao Rr.ral) (reqV8 c v K.sdown Rr.z Rr.rdl) := by
  obtain ⟨A, ⟨t, hAt⟩, hnv, ht⟩ := zcIr_vals c v (r13DzcPre c Rr K mu) lks Rr.h0
    (fun k => mu.getD (13 + k) c.zero) [] (mu.getD (13 + (lks.length + 1) / 2) c.zero) zp groups
    [gatedSt c Rr.gate 24] (r13DzcPost c Rr K)
    (fun o => threeTerms c (0, 1, 2) Rr.gate o nu (o + 2) (o + 4))
  have h24 : A.getD 24 0 = batchV mu (r13DzcClauses c Rr K v) := by
    rw [hAt, getD_lt _ _ _ (by rw [nodeVals_length]; simp [r13DzcPre])]
    first
    | (simp only [r13DzcPre, int16B, nodeVals, List.nil_append, List.append_assoc, List.singleton_append,
        List.cons_append, List.getD_cons_succ, List.getD_cons_zero, bodyVal_limbs256 c hc, bodyVal_sum,
        bodyVal_affine, stVal, batchB, st, fval, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
        List.prod_cons, List.prod_nil, List.zipIdx_cons, List.zipIdx_nil, batchV, r13DzcClauses, hc.one,
        hc.negOne, hc.zero] <;> ring)
    | (simp only [r13DzcPre, int16B, nodeVals, List.nil_append, List.append_assoc, List.singleton_append,
        List.cons_append, List.getD_eq_getElem?_getD, List.getElem?_cons_succ, List.getElem?_cons_zero,
        Option.getD_some, bodyVal_limbs256 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval,
        List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.prod_cons, List.prod_nil, List.zipIdx_cons,
        List.zipIdx_nil, batchV, r13DzcClauses, hc.one, hc.negOne, hc.zero] <;> ring)
    | (simp [r13DzcPre, int16B, nodeVals, bodyVal_limbs256 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st,
        fval, batchV, r13DzcClauses, hc.one, hc.negOne, hc.zero] <;> ring)
  unfold ZK60.Exec.Block.DefR13.r13DzcIr irEval
  rw [hnv, ht]
  simp only [r13DzcPost]
  rw [post2_vals8 c hc v A _ Rr.ral K.sao Rr.ao Rr.rdl K.sdown Rr.z, threeTerms_eval c hc]
  simp only [List.map_nil, List.sum_nil, add_zero, List.map_cons, List.sum_cons, stVal_gated c hc, h24, hc.zero]

end Eval

/-- **R13 `SC_DZC`'s builder commutes with reading its coefficients elsewhere.** -/
theorem r13DzcIr_map {α β : Type} (f : α → β) (c : Cst α) (Rr : DzcR13) (K' : DzcK) (lks : List (LkD α))
    (mu nu : List α) (zp : ℕ → α) (groups : List (ℕ × List ℕ)) :
    (ZK60.Exec.Block.DefR13.r13DzcIr c Rr K' lks mu nu zp groups).map f
      = ZK60.Exec.Block.DefR13.r13DzcIr (c.map f) Rr K' (lks.map (LkD.map f)) (mu.map f) (nu.map f) (f ∘ zp)
          groups := by
  unfold ZK60.Exec.Block.DefR13.r13DzcIr
  rw [zcIr_map]
  simp only [r13DzcPre, r13DzcPost, int16B, threeTerms, gatedSt, limbsB, reqB, batchB, st, List.map_cons,
    List.map_nil, Body.map, SubTerm.map, Term.map, Cst.map, List.map_map, Function.comp_def, getD_map_f,
    List.length_map, Option.map_map] <;> rfl

end ZK60.Exec.Block.Join.R13H.Dzc
