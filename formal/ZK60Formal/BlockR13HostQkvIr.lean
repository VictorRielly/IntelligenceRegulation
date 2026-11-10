/-
D63 lane L49 (2026-11-10), sub-agent `qkv`, part 1: **R13's `SC_QZC` / `SC_KVZC` IR, evaluated** (the IR builder
`DefR13.r13QzcIr`, a transcription of `slot_ir_accuracy.rs:243-307`, read in any commutative ring, as L13's
`qzcIr_eval` reads W16R2's).

* `reqV8`: a requantization host with byte limbs, `2^s·x + Σ_k 256^k·l_k − 2^(s−1)`; `post2_vals8`: the two host nodes
  after the zero-check node;
* `r13QzcClauses`: the batch's four clauses: the RoPE clause `cos·src + sin·flip − 2^rope·rot − rr + 2^(rope−1)` and
  the three 16-bit word decompositions `x + 32768 − Σ_k 256^k·l_k` of `src`, `rot`, `oth`;
* **`r13QzcIr_eval`**: the slot polynomial is L13's three host terms with `Z = logup + pad + gate·Σ_k μ_k·c_k`
  (`μ_0 … μ_3` the clauses, `μ_4 …` LogUp's helpers) and the hosts `reqV8 s1 src r1`, `reqV8 s2 oth r2`;
* `r13QzcIr_map`: the builder commutes with reading its coefficients elsewhere.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.SlotW16BuildSlots
import ZK60Formal.SlotW16Compose
import ZK60Formal.BlockR13Prog

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Qkv

open ZK60.Exec ZK60.Exec.Slot ZK60.Exec.Slot.Build
open ZK60.Exec.Block.DefR13 (QzcR13 r13QzcIr r13QzcPre r13QzcPost int16B)

section Eval

variable {R : Type} [CommRing R]

/-- **A requantization host with byte limbs** `2^s·x + Σ_k 256^k·l_k − 2^(s−1)` (R13's `reqB` after `limbsB`). -/
def reqV8 (c : Cst R) (v : List R) (s x : ℕ) (l : List ℕ) : R :=
  c.base (2 ^ s) * v.getD x 0 + L256 c v l + c.base (-(2 ^ (s - 1) : ℤ))

/-- **The two byte-limb requantization hosts after the zero-check node** (R13's `qzc` host nodes). -/
theorem post2_vals8 (c : Cst R) (hc : c.Std) (v A : List R) (z : R) (l₁ : List ℕ) (s₁ x₁ : ℕ) (l₂ : List ℕ)
    (s₂ x₂ : ℕ) :
    nodeVals v [limbsB c l₁, reqB c s₁ x₁ (A.length + 1), limbsB c l₂, reqB c s₂ x₂ (A.length + 1 + 2)] (A ++ [z])
      = A ++ [z, L256 c v l₁, reqV8 c v s₁ x₁ l₁, L256 c v l₂, reqV8 c v s₂ x₂ l₂] := by
  simp only [nodeVals, bodyVal_limbs256 c hc, bodyVal_req c hc, List.append_assoc, List.cons_append,
    List.nil_append, Nat.add_assoc, getD_len_add, List.getD_cons_succ, List.getD_cons_zero, reqV8]

/-- **R13 `qzc`'s four clauses** (slot_ir_accuracy.rs:282-300): the RoPE clause, then the 16-bit word decompositions
of the source, the rotated and the third word. -/
def r13QzcClauses (c : Cst R) (Rr : QzcR13) (rope : ℕ) (v : List R) : List R :=
  [v.getD Rr.cos 0 * v.getD Rr.src 0 + v.getD Rr.sin 0 * v.getD Rr.flip 0 + c.base (-(2 ^ rope : ℤ)) * v.getD Rr.rot 0
      - L256 c v Rr.rr + c.base (2 ^ (rope - 1)),
    v.getD Rr.src 0 + c.base 32768 - L256 c v Rr.wl,
    v.getD Rr.rot 0 + c.base 32768 - L256 c v Rr.rwl,
    v.getD Rr.oth 0 + c.base 32768 - L256 c v Rr.ol]

/-- **R13 `SC_QZC` / `SC_KVZC`'s polynomial**: the host terms with `Z = logup + pad + gate·Σ_k μ_k·c_k` (the four
clauses at `μ_0 … μ_3`, LogUp's helpers from `μ_4`) and the byte-limb requantization hosts. -/
theorem r13QzcIr_eval (c : Cst R) (hc : c.Std) (v : List R) (Rr : QzcR13) (rope s1 s2 : ℕ) (lks : List (LkD R))
    (mu nu : List R) (zp : ℕ → R) (groups : List (ℕ × List ℕ)) :
    irEval (r13QzcIr c Rr rope s1 s2 lks mu nu zp groups) v
      = hostTerms v 0 1 2 Rr.gate Rr.gate nu
          (logupSem c v Rr.h0 (fun k => mu.getD (4 + k) 0) 0 lks
            + padSem c v (mu.getD (4 + (lks.length + 1) / 2) 0) zp 0 groups
            + gV v Rr.gate * batchV mu (r13QzcClauses c Rr rope v))
          (reqV8 c v s1 Rr.src Rr.r1) (reqV8 c v s2 Rr.oth Rr.r2) := by
  obtain ⟨A, ⟨t, hAt⟩, hnv, ht⟩ := zcIr_vals c v (r13QzcPre c Rr rope mu) lks Rr.h0
    (fun k => mu.getD (4 + k) c.zero) [] (mu.getD (4 + (lks.length + 1) / 2) c.zero) zp groups [gatedSt c Rr.gate 8]
    (r13QzcPost c Rr s1 s2) (fun o => threeTerms c (0, 1, 2) Rr.gate o nu (o + 2) (o + 4))
  have h8 : A.getD 8 0 = batchV mu (r13QzcClauses c Rr rope v) := by
    rw [hAt, getD_lt _ _ _ (by rw [nodeVals_length]; simp [r13QzcPre])]
    simp only [r13QzcPre, int16B, nodeVals, List.nil_append,
      List.cons_append, List.getD_cons_succ, List.getD_cons_zero, bodyVal_limbs256 c hc, bodyVal_sum, stVal, batchB,
      st, fval, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.prod_cons, List.prod_nil,
      List.zipIdx_cons, List.zipIdx_nil, batchV, r13QzcClauses, hc.one, hc.negOne, hc.zero]
    ring
  unfold r13QzcIr irEval
  rw [hnv, ht]
  simp only [r13QzcPost]
  rw [post2_vals8 c hc v A _ Rr.r1 s1 Rr.src Rr.r2 s2 Rr.oth, threeTerms_eval c hc]
  simp only [List.map_nil, List.sum_nil, add_zero, List.map_cons, List.sum_cons, stVal_gated c hc, h8, hc.zero]

end Eval

/-- **R13 `qzc`'s builder commutes with reading its coefficients elsewhere.** -/
theorem r13QzcIr_map {α β : Type} (f : α → β) (c : Cst α) (Rr : QzcR13) (rope s1 s2 : ℕ) (lks : List (LkD α))
    (mu nu : List α) (zp : ℕ → α) (groups : List (ℕ × List ℕ)) :
    (r13QzcIr c Rr rope s1 s2 lks mu nu zp groups).map f
      = r13QzcIr (c.map f) Rr rope s1 s2 (lks.map (LkD.map f)) (mu.map f) (nu.map f) (f ∘ zp) groups := by
  unfold r13QzcIr
  rw [zcIr_map]
  simp only [r13QzcPre, r13QzcPost, int16B, threeTerms, gatedSt, limbsB, reqB, batchB, st, List.map_cons,
    List.map_nil, Body.map, SubTerm.map, Term.map, Cst.map, List.map_map, Function.comp_def,
    ZK60.Exec.Slot.Compose.getD_map_f, List.length_map]
  rfl

end ZK60.Exec.Block.Join.R13H.Qkv
