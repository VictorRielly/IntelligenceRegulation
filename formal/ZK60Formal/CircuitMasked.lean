/-
D63, step L2: what the block proof shows about the CAUSAL MASK (optimization candidate C9 of the findings document).

The score plane covers every `(head, t, j)`, the masked columns `j > t` included: the score matmul hosts them
(`SC_SCORE`), their words are requantized and class-checked (two byte queries and two remainder limbs,
accuracy_layout.rs:328-330), and every softmax internal is committed and looked up there too (`e` and its exp tuple, `P`
and its direct lookup, `sr`, `sg` and their limbs, `zsel`; argument_accuracy.rs:624-631). About half of `Dom::S` is
masked (`T(T − 1)/2` of `T²` columns per head: 49.6% at `T = 128`).

What the proofs give:
* `masked_column_forced`: at a masked column the division clauses and their range facts FORCE `P = 0`, `sr = 0` and
  `sg = sum − 1`, whatever the committed values; the exp value there is `exp[mx + 127]`, read by nothing (the row sum
  multiplies it by the mask). So the masked softmax internals carry no information: committing them is overhead.
* `softmaxF_live_only`: the integer softmax row depends only on its LIVE scores. Hence the block's output depends on a
  masked score only through that score's own class check (`sSpec`'s refusal outside `[−127, 127]`): dropping the masked
  score positions changes the admissible inputs (a model change, like C4's class), not the output.
-/
import ZK60Formal.CircuitStage

namespace ZK60.Circuit

open ZK60.Model

/-- **At a masked column the softmax internals are forced** (candidate C9). With the masked numerator `0`, a row total
`1 ≤ sum ≤ 2^w`, the quotient's direct lookup and the two slack lookups, the clauses `c2`, `c3` hold only for
`P = 0`, `sr = 0`, `sg = sum − 1`. -/
theorem masked_column_forced (fp w : ℕ) (hfp : fp ≤ 24) (hw : w ≤ 24) (sum : ℤ) (hs1 : 1 ≤ sum)
    (hs2 : sum ≤ 2 ^ w) (P sr sg : GF) (hP : InRange (fp + 1) P) (hsr : RemW16 w sr) (hsg : RemW16 w sg)
    (h : SoftmaxDivRel 0 P (sum : GF) sr sg) : P = 0 ∧ sr = 0 ∧ sg = ((sum - 1 : ℤ) : GF) := by
  have h' : SoftmaxDivRel ((0 : ℤ) : GF) P (sum : GF) sr sg := by rw [Int.cast_zero]; exact h
  have hP0 : P = ((0 / sum : ℤ) : GF) :=
    (softmaxDiv_iff fp w hfp hw 0 sum (le_refl 0) (mul_nonneg (by positivity) (by linarith)) hs1 hs2 P).mp
      ⟨⟨sr, sg, h', hsr, hsg⟩, hP⟩
  rw [Int.zero_ediv, Int.cast_zero] at hP0
  obtain ⟨h2, h3⟩ := h
  rw [hP0] at h2
  have hsr0 : sr = 0 := by linear_combination -h2
  refine ⟨hP0, hsr0, ?_⟩
  rw [hsr0] at h3
  push_cast
  linear_combination h3

variable {T : ℕ}

/-- **The integer softmax row depends only on its live scores** (candidate C9). -/
theorem softmaxF_live_only (fp wrho : ℕ) (exp : ℤ → ℤ) (t : Fin T) (s s' : Fin T → ℤ)
    (h : ∀ j, j ≤ t → s j = s' j) : softmaxF fp wrho exp t s = softmaxF fp wrho exp t s' := by
  have hb : bestOf t s = bestOf t s' := by
    apply le_antisymm
    · refine (Finset.sup'_le_iff _ _).mpr fun j hj => ?_
      rw [h j (Finset.mem_filter.mp hj).2]
      exact Finset.le_sup' s' hj
    · refine (Finset.sup'_le_iff _ _).mpr fun j hj => ?_
      rw [← h j (Finset.mem_filter.mp hj).2]
      exact Finset.le_sup' s hj
  have hsm : smOf t s = smOf t s' := by
    funext j
    unfold smOf
    by_cases hj : j ≤ t
    · rw [if_pos hj, if_pos hj, h j hj]
    · rw [if_neg hj, if_neg hj]
  unfold softmaxF totalOf numOf expRow
  rw [hb, hsm]

end ZK60.Circuit
