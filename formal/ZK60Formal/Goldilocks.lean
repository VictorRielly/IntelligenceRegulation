/-
Goldilocks is prime: `p = 2^64 − 2^32 + 1` (zkp-core `field.rs`). Lucas's test with the witness `7` (the field's
standard multiplicative generator): `7^(p−1) = 1`, and `7^((p−1)/q) ≠ 1` for each prime `q` of
`p − 1 = 2^32 · 3 · 5 · 17 · 257 · 65537`. The powers are evaluated by `reduce_mod_char` (binary exponentiation in
`ZMod p`, Mathlib's `NormNum.PowMod`), so the kernel checks a chain of squarings mod `p`, not a `2^64`-fold product.

This discharges the premise `Fact (Nat.Prime gP)` that the field-generic L3 lemmas (SoundLogUp, SoundLogUpBlock, the
sumcheck and zero-check files, all stated over any `Field F`) and `CircuitSoftmax.rowmax_without_booleanity` need
at the code's field: `ZMod gP` is a field.
-/
import Mathlib.NumberTheory.LucasPrimality
import Mathlib.Tactic.ReduceModChar
import Mathlib.Tactic.NormNum.Prime
import ZK60Formal.CircuitSoftmax

namespace ZK60.Circuit

theorem gP_sub_one_factor : gP - 1 = 2 ^ 32 * (3 * (5 * (17 * (257 * 65537)))) := by norm_num

/-- The prime factors of `p − 1`. -/
theorem prime_dvd_gP_sub_one {q : ℕ} (hq : q.Prime) (h : q ∣ gP - 1) :
    q = 2 ∨ q = 3 ∨ q = 5 ∨ q = 17 ∨ q = 257 ∨ q = 65537 := by
  rw [gP_sub_one_factor] at h
  rcases (Nat.Prime.dvd_mul hq).mp h with h | h
  · exact Or.inl ((Nat.prime_dvd_prime_iff_eq hq Nat.prime_two).mp (hq.dvd_of_dvd_pow h))
  rcases (Nat.Prime.dvd_mul hq).mp h with h | h
  · exact Or.inr (Or.inl ((Nat.prime_dvd_prime_iff_eq hq (by norm_num)).mp h))
  rcases (Nat.Prime.dvd_mul hq).mp h with h | h
  · exact Or.inr (Or.inr (Or.inl ((Nat.prime_dvd_prime_iff_eq hq (by norm_num)).mp h)))
  rcases (Nat.Prime.dvd_mul hq).mp h with h | h
  · exact Or.inr (Or.inr (Or.inr (Or.inl ((Nat.prime_dvd_prime_iff_eq hq (by norm_num)).mp h))))
  rcases (Nat.Prime.dvd_mul hq).mp h with h | h
  · exact Or.inr (Or.inr (Or.inr (Or.inr (Or.inl ((Nat.prime_dvd_prime_iff_eq hq (by norm_num)).mp h)))))
  · exact Or.inr (Or.inr (Or.inr (Or.inr (Or.inr ((Nat.prime_dvd_prime_iff_eq hq (by norm_num)).mp h)))))

theorem pow7_full : (7 : ZMod 18446744069414584321) ^ 18446744069414584320 = 1 := by reduce_mod_char
theorem pow7_2 : (7 : ZMod 18446744069414584321) ^ 9223372034707292160 ≠ 1 := by reduce_mod_char; decide
theorem pow7_3 : (7 : ZMod 18446744069414584321) ^ 6148914689804861440 ≠ 1 := by reduce_mod_char; decide
theorem pow7_5 : (7 : ZMod 18446744069414584321) ^ 3689348813882916864 ≠ 1 := by reduce_mod_char; decide
theorem pow7_17 : (7 : ZMod 18446744069414584321) ^ 1085102592318504960 ≠ 1 := by reduce_mod_char; decide
theorem pow7_257 : (7 : ZMod 18446744069414584321) ^ 71777214277877760 ≠ 1 := by reduce_mod_char; decide
theorem pow7_65537 : (7 : ZMod 18446744069414584321) ^ 281470681743360 ≠ 1 := by reduce_mod_char; decide

/-- **Goldilocks is prime.** -/
theorem gP_prime : Nat.Prime gP := by
  refine lucas_primality gP 7 pow7_full ?_
  intro q hq hd
  rcases prime_dvd_gP_sub_one hq hd with rfl | rfl | rfl | rfl | rfl | rfl
  · rw [show (gP - 1) / 2 = 9223372034707292160 by norm_num]; exact pow7_2
  · rw [show (gP - 1) / 3 = 6148914689804861440 by norm_num]; exact pow7_3
  · rw [show (gP - 1) / 5 = 3689348813882916864 by norm_num]; exact pow7_5
  · rw [show (gP - 1) / 17 = 1085102592318504960 by norm_num]; exact pow7_17
  · rw [show (gP - 1) / 257 = 71777214277877760 by norm_num]; exact pow7_257
  · rw [show (gP - 1) / 65537 = 281470681743360 by norm_num]; exact pow7_65537

instance fact_gP_prime : Fact (Nat.Prime gP) := ⟨gP_prime⟩

-- `GF` is a field (the instance `ZMod.instField` with `fact_gP_prime`).
example : Field GF := inferInstance

/-- `rowmax_without_booleanity` at the code's field, with no premise left. -/
theorem rowmax_gf {n : ℕ} (s : Fin n → ℤ) (hs : ∀ j, -127 ≤ s j ∧ s j ≤ 127) (mx : GF) (d : Fin n → ℤ)
    (hd : ∀ j, 0 ≤ d j ∧ d j < 256) (hδ : ∀ j, mx - (s j : GF) = (d j : GF)) (z : Fin n → GF)
    (hz : ∑ j, z j = 1) (hzδ : ∀ j, z j * (mx - (s j : GF)) = 0) :
    ∃ j₀, (∀ j, s j ≤ s j₀) ∧ mx = (s j₀ : GF) ∧ ∀ j, d j = s j₀ - s j :=
  rowmax_without_booleanity s hs mx d hd hδ z hz hzδ

end ZK60.Circuit
