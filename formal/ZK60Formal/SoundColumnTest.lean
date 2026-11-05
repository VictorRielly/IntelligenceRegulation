/-
D63, step L3 (soundness of the IOP): the column test of the polynomial commitment.

`pcs::verify_zk_tagged` (and `verify_zk`, `verify`) opens `Q` columns of the committed `m × N` matrix at indices
drawn by `tr.challenge_indices(Q, N)`: `Q` independent draws, WITH replacement, each a masked `u64` in `[0, N)` with
`N` a power of two, so each draw is exactly uniform once the hash bits are. At every sampled column `j` the verifier
checks `Enc(v)[j] = Σ_i ρ_i·U[i][j]` for each clear vector `v` (the group vectors and the proximity vector). This file
proves what that test catches, as a probability over the `Q` indices alone (the vectors are fixed before the indices
are drawn, which is the code's order: the vectors are absorbed, then the indices are squeezed).

What is proved:
* `card_miss`, `column_miss_prob`: the exact law. A set `D` of `N` columns is missed by all `Q` uniform draws with
  probability `((N − |D|)/N)^Q`;
* `column_test_sound`: the test itself. If the row `w` the verifier re-encodes and the combination `v` of the committed
  rows disagree on at least `e + 1` columns, all `Q` checks pass with probability at most `((N − (e + 1))/N)^Q`, the
  count's exact integer form `(1 − (e + 1)/N)^Q` (`count.py`, `regular`, rate 1/2: `Q_(nn − e − 1, nn) ** q`);
* `column_test_sound'`: the same with the disagreement set bounded below by any `t`, the form the close case of an
  opening uses (`t = d − e`);
* `third_column_le`: at rate 1/4 the count prices the column term as `((2N + K)/(3N))^Q`, i.e. `(1 − δ/3)^Q` with
  `δ = 1 − K/N`, while the radius it then uses is `e = ⌊δN/3⌋ = ⌊(N − K)/3⌋`. Since `3(e + 1) > N − K`, the proved
  `((N − (e + 1))/N)^Q` is at most the counted `((2N + K)/(3N))^Q`: the count is conservative here.
-/
import Mathlib.Probability.ProbabilityMassFunction.Constructions
import Mathlib.Probability.Distributions.Uniform

namespace ZK60.Sound

open scoped ENNReal
open Finset

/-- `(a / b)^n = a^n / b^n` in `ℝ≥0∞` (Mathlib's `div_pow` needs a division monoid, which `ℝ≥0∞` is not). -/
theorem ennreal_div_pow (a b : ℝ≥0∞) (n : ℕ) : (a / b) ^ n = a ^ n / b ^ n := by
  rw [div_eq_mul_inv, mul_pow, ← ENNReal.inv_pow, ← div_eq_mul_inv]

variable {ι : Type} [Fintype ι] [DecidableEq ι]

/-- The sample tuples `J : Fin Q → ι` that miss the column set `D` are exactly the tuples of columns outside `D`:
there are `(N − |D|)^Q` of them. -/
theorem card_miss (D : Finset ι) (Q : ℕ) :
    (univ.filter (fun J : Fin Q → ι => ∀ k, J k ∉ D)).card = (Fintype.card ι - D.card) ^ Q := by
  have hset : univ.filter (fun J : Fin Q → ι => ∀ k, J k ∉ D) = Fintype.piFinset (fun _ : Fin Q => Dᶜ) := by
    ext J
    simp [Fintype.mem_piFinset]
  rw [hset, Fintype.card_piFinset, prod_const, card_univ, Fintype.card_fin, card_compl]

variable [Nonempty ι]

/-- **The exact law of the column test.** `Q` independent uniform column indices (sampling with replacement, as
`challenge_indices` does) all miss a set `D` of the `N` columns with probability exactly `((N − |D|)/N)^Q`. -/
theorem column_miss_prob (D : Finset ι) (Q : ℕ) :
    (PMF.uniformOfFintype (Fin Q → ι)).toOuterMeasure {J | ∀ k, J k ∉ D}
      = (((Fintype.card ι - D.card : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q := by
  rw [PMF.toOuterMeasure_uniformOfFintype_apply, Fintype.card_ofFinset, ennreal_div_pow]
  have hfilt : (univ.filter (fun J : Fin Q → ι => J ∈ {J : Fin Q → ι | ∀ k, J k ∉ D}))
      = univ.filter (fun J : Fin Q → ι => ∀ k, J k ∉ D) := by
    ext J
    simp
  rw [hfilt, card_miss, Fintype.card_fun, Fintype.card_fin, Nat.cast_pow, Nat.cast_pow]

/-- **The column test, with any lower bound `t` on the disagreement.** If the re-encoded row `w` and the combination
`v` of the committed rows differ on at least `t` columns, then `Q` uniform indices all land where they agree with
probability at most `((N − t)/N)^Q`. -/
theorem column_test_sound' {F : Type} [DecidableEq F] (w v : ι → F) {t : ℕ}
    (h : t ≤ (univ.filter (fun j => w j ≠ v j)).card) (Q : ℕ) :
    (PMF.uniformOfFintype (Fin Q → ι)).toOuterMeasure {J | ∀ k, w (J k) = v (J k)}
      ≤ (((Fintype.card ι - t : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q := by
  set D := univ.filter (fun j => w j ≠ v j)
  have hset : {J : Fin Q → ι | ∀ k, w (J k) = v (J k)} = {J | ∀ k, J k ∉ D} := by
    ext J
    simp [D]
  rw [hset, column_miss_prob]
  gcongr

/-- **The column test (task 1).** If the row `w` that the verifier re-encodes from a clear vector and the combination
`v = Σ_i ρ_i·U_i` of the committed rows disagree on a set of at least `e + 1` of the `N` columns, then the `Q`
column checks, at indices drawn uniformly WITH replacement, all pass with probability at most
`((N − (e + 1))/N)^Q = (1 − (e + 1)/N)^Q`. This is `count.py`'s rate-1/2 column term `Q_(nn − e − 1, nn) ** q`
exactly. -/
theorem column_test_sound {F : Type} [DecidableEq F] (w v : ι → F) {e : ℕ}
    (h : e + 1 ≤ (univ.filter (fun j => w j ≠ v j)).card) (Q : ℕ) :
    (PMF.uniformOfFintype (Fin Q → ι)).toOuterMeasure {J | ∀ k, w (J k) = v (J k)}
      ≤ (((Fintype.card ι - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q :=
  column_test_sound' w v h Q

omit [Fintype ι] [DecidableEq ι] [Nonempty ι] in
/-- **The rate-1/4 count is conservative.** `count.py` prices a δ/3 opening's column term as `((2N + K)/(3N))^Q`
(`Q_(2 * nn + k, 3 * nn) ** q`), that is `(1 − δ/3)^Q` with `δ = 1 − K/N`, and takes the radius `e = ⌊δN/3⌋`. Any
`e` with `N − K ≤ 3(e + 1)` (in particular that one) has `((N − (e + 1))/N)^Q ≤ ((2N + K)/(3N))^Q`, so the proved
column term is never larger than the counted one. -/
theorem third_column_le {N K e : ℕ} (hN : 0 < N) (he : N - K ≤ 3 * (e + 1)) (Q : ℕ) :
    (((N - (e + 1) : ℕ) : ℝ≥0∞) / N) ^ Q ≤ (((2 * N + K : ℕ) : ℝ≥0∞) / (3 * N : ℕ)) ^ Q := by
  refine pow_le_pow_left₀ zero_le ?_ Q
  have h3 : (3 : ℝ≥0∞) ≠ 0 := by norm_num
  have h3t : (3 : ℝ≥0∞) ≠ ⊤ := by norm_num
  calc ((N - (e + 1) : ℕ) : ℝ≥0∞) / N
      = (3 * ((N - (e + 1) : ℕ) : ℝ≥0∞)) / (3 * (N : ℝ≥0∞)) :=
        (ENNReal.mul_div_mul_left _ _ h3 h3t).symm
    _ = ((3 * (N - (e + 1)) : ℕ) : ℝ≥0∞) / ((3 * N : ℕ) : ℝ≥0∞) := by push_cast; ring
    _ ≤ ((2 * N + K : ℕ) : ℝ≥0∞) / ((3 * N : ℕ) : ℝ≥0∞) := by
        gcongr
        omega

end ZK60.Sound
