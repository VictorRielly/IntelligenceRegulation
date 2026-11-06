/-
D63, step L2 (`CircuitIff`), family 3: SOFTMAX, the row maximum and the rounded division.

The constraints, as the code builds them (`szc_w16`, argument_accuracy.rs:624-631, and the row sums of `SC_RS`,
argument.rs:2135-2148):
* the score `s8` is a symmetric int8 word (CircuitRequant's `WordS8`), and `δ = mx − s8` at a live position (the
  masked form `mx − mask·(s8 − MASK) + MASK` at :626) is the index coordinate of the exp tuple `(δ, e)`, a table index in
  `[0, 256)` (`cx` at :631);
* `c0 = zsel² − zsel` (booleanity of the argmax selector), `c1 = zsel·δ`, and the row sum `Σ_j zsel_j = 1` (the `λ`
  half of `SC_RS`'s row claim `Σ_j (mask·e + λ·zsel) = sum + λ`);
* `c2 = mask·e·2^f_p − P·sum − sr`, `c3 = sg + sr + 1 − sum`, with `P` looked up directly at `f_p + 1` bits
  (range16::direct) and `sr`, `sg` at `wrho_s` bits; `sum` is the row's exp sum (the other half of `SC_RS`).

The spec (ModelInt.lean): `softmaxRow`.

Proved:
* `softmaxDiv_iff`: the division clauses with their three range facts hold exactly when `P = ⌊num/sum⌋`, for
  `0 ≤ num ≤ 2^f_p·sum` and `1 ≤ sum ≤ 2^wrho_s`; and `softmax_sg_window`: under those premises the builder's
  refusal `sg ≥ 2^wrho_s` (witness_accuracy.rs:898) never fires.
* `rowmax_without_booleanity` (candidate C7): `Σ_j zsel_j = 1`, `zsel_j·δ_j = 0` and the exp index range of every
  `δ_j` already force `mx` to be the row maximum and every `δ_j` to be `max − s_j`, with NO booleanity of `zsel`. The
  clause `c0` is therefore not used by the iff: it is redundant. (Over a field: the premise `Fact (Nat.Prime gP)` is
  discharged by `Goldilocks.lean`.)
-/
import ZK60Formal.CircuitRequant
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Algebra.Field.ZMod

namespace ZK60.Circuit

open ZK60.Model

/-! ## The division -/

/-- `c2` and `c3` at one score position, with the numerator `num = mask·e·2^f_p` (an integer the exp tuple fixes). -/
def SoftmaxDivRel (num P sum sr sg : GF) : Prop := num - P * sum - sr = 0 ∧ sg + sr + 1 - sum = 0

/-- **`CircuitIff` for the softmax division at one position.** -/
theorem softmaxDiv_iff (fp w : ℕ) (hfp : fp ≤ 24) (hw : w ≤ 24) (num sum : ℤ) (hn0 : 0 ≤ num)
    (hn : num ≤ 2 ^ fp * sum) (hs1 : 1 ≤ sum) (hs2 : sum ≤ 2 ^ w) (P : GF) :
    ((∃ sr sg : GF, SoftmaxDivRel (num : GF) P (sum : GF) sr sg ∧ RemW16 w sr ∧ RemW16 w sg) ∧ InRange (fp + 1) P) ↔
      P = ((num / sum : ℤ) : GF) := by
  have hW : (2 : ℤ) ^ w ≤ 2 ^ 24 := pow_le_pow_right₀ (by norm_num) hw
  have hF : (2 : ℤ) ^ (fp + 1) ≤ 2 ^ 25 := pow_le_pow_right₀ (by norm_num) (by omega)
  have hF1 : (2 : ℤ) ^ (fp + 1) = 2 * 2 ^ fp := by ring
  have hs0 : (0 : ℤ) < sum := by linarith
  have hn2 : num ≤ 2 ^ 25 * 2 ^ 24 := by
    have h1 : (2 : ℤ) ^ fp ≤ 2 ^ 24 := pow_le_pow_right₀ (by norm_num) hfp
    have h2 : (2 : ℤ) ^ fp * sum ≤ 2 ^ 24 * sum := mul_le_mul_of_nonneg_right h1 (le_of_lt hs0)
    linarith
  constructor
  · rintro ⟨⟨sr, sg, ⟨h1, h2⟩, hsr, hsg⟩, ⟨p, hp0, hp1, rfl⟩⟩
    obtain ⟨a, ha0, ha1, rfl⟩ := (remW16_iff w sr).mp hsr
    obtain ⟨b, hb0, hb1, rfl⟩ := (remW16_iff w sg).mp hsg
    have hps := mul_bounds (abs_le.mpr ⟨by linarith, by linarith⟩ : |p| ≤ 2 ^ 25)
      (abs_le.mpr ⟨by linarith, by linarith⟩ : |sum| ≤ 2 ^ 24)
    have e1 : ((num - p * sum - a : ℤ) : GF) = 0 := by push_cast; linear_combination h1
    have e2 : ((b + a + 1 - sum : ℤ) : GF) = 0 := by push_cast; linear_combination h2
    have E1 := int_eq_zero_of_cast e1 (by nlinarith [hps.2]) (by nlinarith [hps.1])
    have E2 := int_eq_zero_of_cast e2 (by linarith) (by linarith)
    have hdiv : num / sum = p ∧ num % sum = a := (Int.ediv_emod_unique hs0).mpr ⟨by linarith, ha0, by linarith⟩
    rw [hdiv.1]
  · intro hP
    have hm := Int.mul_ediv_add_emod num sum
    have hr0 : 0 ≤ num % sum := Int.emod_nonneg _ (ne_of_gt hs0)
    have hr1 : num % sum < sum := Int.emod_lt_of_pos _ hs0
    refine ⟨⟨((num % sum : ℤ) : GF), ((sum - 1 - num % sum : ℤ) : GF), ⟨?_, ?_⟩,
      (remW16_iff w _).mpr ⟨_, hr0, by linarith, rfl⟩, (remW16_iff w _).mpr ⟨_, by linarith, by linarith, rfl⟩⟩,
      ⟨num / sum, Int.ediv_nonneg hn0 (le_of_lt hs0), ?_, hP⟩⟩
    · rw [hP]
      have : ((num - num / sum * sum - num % sum : ℤ) : GF) = 0 := by
        have h0 : num - num / sum * sum - num % sum = 0 := by linarith
        rw [h0]; simp
      push_cast at this
      exact this
    · push_cast; ring
    · rw [Int.ediv_lt_iff_lt_mul hs0, hF1]
      have : (0 : ℤ) < 2 ^ fp * sum := mul_pos (by positivity) hs0
      linarith

/-- **The builder's softmax window refusal is unreachable** under the shape's window rule: with `0 ≤ sr < sum ≤
2^wrho_s` the slack `sg = sum − 1 − sr` is below `2^wrho_s`. (`wrho_s = clog2(T) + f_e` makes `sum ≤ T·2^f_e ≤
2^wrho_s`, shape.rs:394-400, 1125.) -/
theorem softmax_sg_window (w : ℕ) (num sum : ℤ) (hs1 : 1 ≤ sum) (hs2 : sum ≤ 2 ^ w) :
    sum - 1 - num % sum < 2 ^ w := by
  have := Int.emod_nonneg num (ne_of_gt (by linarith : (0 : ℤ) < sum))
  linarith

/-! ## The row maximum, without booleanity -/

/-- **`c0` is redundant** (candidate C7). For the live scores `s_j` (symmetric int8) of one row, a committed row
maximum `mx` whose differences `δ_j = mx − s_j` are exp-table indices `d_j ∈ [0, 256)`, and ANY field values `z_j`
with `Σ_j z_j = 1` and `z_j·δ_j = 0` (no booleanity): `mx` is the image of the row maximum, attained at some `j₀`,
and every `d_j` is `s_{j₀} − s_j`. -/
theorem rowmax_without_booleanity [Fact (Nat.Prime gP)] {n : ℕ} (s : Fin n → ℤ)
    (hs : ∀ j, -127 ≤ s j ∧ s j ≤ 127) (mx : GF) (d : Fin n → ℤ) (hd : ∀ j, 0 ≤ d j ∧ d j < 256)
    (hδ : ∀ j, mx - (s j : GF) = (d j : GF)) (z : Fin n → GF) (hz : ∑ j, z j = 1)
    (hzδ : ∀ j, z j * (mx - (s j : GF)) = 0) :
    ∃ j₀, (∀ j, s j ≤ s j₀) ∧ mx = (s j₀ : GF) ∧ ∀ j, d j = s j₀ - s j := by
  have hne : ∑ j, z j ≠ 0 := by rw [hz]; exact one_ne_zero
  obtain ⟨j₀, -, hj₀⟩ := Finset.exists_ne_zero_of_sum_ne_zero hne
  have hmx : mx = (s j₀ : GF) := by
    have := hzδ j₀
    rcases mul_eq_zero.mp this with h | h
    · exact absurd h hj₀
    · linear_combination h
  have hdj : ∀ j, d j = s j₀ - s j := by
    intro j
    have h := hδ j
    rw [hmx] at h
    have e : ((s j₀ - s j - d j : ℤ) : GF) = 0 := by push_cast; linear_combination h
    have := int_eq_zero_of_cast e (by linarith [(hs j).1, (hs j).2, (hs j₀).1, (hs j₀).2, (hd j).1, (hd j).2])
      (by linarith [(hs j).1, (hs j).2, (hs j₀).1, (hs j₀).2, (hd j).1, (hd j).2])
    linarith
  exact ⟨j₀, fun j => by linarith [hdj j, (hd j).1], hmx, hdj⟩

end ZK60.Circuit
