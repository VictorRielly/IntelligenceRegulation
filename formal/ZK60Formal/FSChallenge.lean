/-
D63, step L3 (soundness): the challenges as the code derives them from a hash output, and their bias.

What the code does (`zkp_core::transcript`):
* `challenge_fp2`: one squeeze gives a 32-byte digest; its first 16 bytes, read as a little-endian `u128`, reduced mod
  `p`, are the first coordinate `c0`; the last 16 bytes, the same way, are `c1` (`Fp::from_u128(v) = v mod p`). The
  challenge is `c0 + U·c1` in `Fp2`.
* `challenge_fp`: the first 16 bytes only, reduced mod `p` (not used for soundness challenges of the private block).
* `challenge_indices(n, bound)`: each 8-byte chunk of a squeeze, as a little-endian `u64`, masked by `bound − 1`
  (`bound` a power of two, asserted), four indices per squeeze.

The model. A 32-byte digest is a pair of 128-bit numbers, `Fin N × Fin N` with `N = 2^128` (a bijection with the
32 bytes). `fp2Chal p N` reduces each half mod `p`, into `ZMod p × ZMod p`; any field `F` with a bijection
`ι : ZMod p × ZMod p ≃ F` (for `Fp2`: `(c0, c1) ↦ c0 + U·c1`, a bijection by `HidingMOpening.lean`'s `fp2_bijective`)
then gets `ι ∘ fp2Chal p N`.

What is proved.
* `card_fin_mod_fiber_le`: at most `⌊N/p⌋ + 1` numbers below `N` reduce to a given residue; exactly at most `N/p` when
  `p ∣ N` (`card_fin_mod_fiber_le_of_dvd`).
* `card_fp2Chal_fiber_le`, `card_fp2Field_fiber_le`: every `Fp2` challenge has at most `(⌊N/p⌋ + 1)²` digest
  preimages.
* `biasFactor_fp2_le`: so the bias factor of `FSRbr.lean` is at most `(1 + p/N)²`: every probability bound `e/|Fp2|`
  for a uniform challenge holds for the derived challenge up to the factor `(1 + p/2^128)²`; for a set `S` of
  challenges directly, `prob_fp2Field_mem_le`. For Goldilocks `p = 2^64 − 2^32 + 1 < 2^64` this is at most
  `(1 + 2^-64)²` (`bias_le_two_pow_64`, `goldilocks_bias_le`). For `k` challenges in one bound the factor is at
  most `(1 + 2^-64)^(2k)` (Part 1's §3.7 figure); in the Fiat–Shamir theorem it is paid once per hash query, not per
  challenge, because the union bound there is over queries.
* `idxChal`, `idxChal_eq`, `biasFactor_idx_eq_one`: the masked index (`v &&& (2^h − 1)`, which is `v mod 2^h`) has
  exactly `2^64/2^h` preimages per value, so its bias factor is exactly `1`: the column indices are exactly uniform.

What the model takes from the code. `v as usize` before the mask is lossless on the 64-bit platforms we run on (on a
32-bit platform it truncates; still uniform for `bound ≤ 2^32`). The refusals `nonzero(…)` / `c ≠ 0` of a zero draw
only add rejection and are not modelled.
-/
import ZK60Formal.FSRbr
import Mathlib.Data.ZMod.Basic

namespace ZK60.Sound

open scoped ENNReal
open Finset

/-! ## Reduction mod `p` -/

/-- **Reduction mod `p` is nearly balanced.** At most `⌊N/p⌋ + 1` of the numbers below `N` reduce to a given residue
`r` mod `p` (the map `v ↦ v / p` is injective on them and lands below `⌊N/p⌋ + 1`). -/
theorem card_fin_mod_fiber_le (N p : ℕ) [NeZero p] (r : ZMod p) :
    (univ.filter (fun v : Fin N => ((v : ℕ) : ZMod p) = r)).card ≤ N / p + 1 := by
  refine le_trans (card_le_card_of_injOn (fun v : Fin N => (v : ℕ) / p) (t := range (N / p + 1)) ?_ ?_)
    (by rw [card_range])
  · intro v _
    simp only [coe_range, Set.mem_Iio]
    exact Nat.lt_succ_of_le (Nat.div_le_div_right v.isLt.le)
  · intro a ha b hb hab
    simp only [coe_filter, mem_univ, true_and, Set.mem_ofPred_eq] at ha hb
    have ha' : (a : ℕ) % p = r.val := by rw [← ha, ZMod.val_natCast]
    have hb' : (b : ℕ) % p = r.val := by rw [← hb, ZMod.val_natCast]
    have hab' : (a : ℕ) / p = (b : ℕ) / p := hab
    apply Fin.ext
    calc (a : ℕ) = p * ((a : ℕ) / p) + (a : ℕ) % p := (Nat.div_add_mod _ _).symm
      _ = p * ((b : ℕ) / p) + (b : ℕ) % p := by rw [hab', ha', hb']
      _ = b := Nat.div_add_mod _ _

/-- **Reduction mod a divisor is exactly balanced.** When `p ∣ N`, at most `N/p` numbers below `N` reduce to each
residue (so exactly `N/p`: the `p` fibers cover the `N` numbers). -/
theorem card_fin_mod_fiber_le_of_dvd (N p : ℕ) [NeZero p] (hdvd : p ∣ N) (r : ZMod p) :
    (univ.filter (fun v : Fin N => ((v : ℕ) : ZMod p) = r)).card ≤ N / p := by
  refine le_trans (card_le_card_of_injOn (fun v : Fin N => (v : ℕ) / p) (t := range (N / p)) ?_ ?_)
    (by rw [card_range])
  · intro v _
    simp only [coe_range, Set.mem_Iio]
    exact Nat.div_lt_div_of_lt_of_dvd hdvd v.isLt
  · intro a ha b hb hab
    simp only [coe_filter, mem_univ, true_and, Set.mem_ofPred_eq] at ha hb
    have ha' : (a : ℕ) % p = r.val := by rw [← ha, ZMod.val_natCast]
    have hb' : (b : ℕ) % p = r.val := by rw [← hb, ZMod.val_natCast]
    have hab' : (a : ℕ) / p = (b : ℕ) / p := hab
    apply Fin.ext
    calc (a : ℕ) = p * ((a : ℕ) / p) + (a : ℕ) % p := (Nat.div_add_mod _ _).symm
      _ = p * ((b : ℕ) / p) + (b : ℕ) % p := by rw [hab', ha', hb']
      _ = b := Nat.div_add_mod _ _

/-! ## The `Fp2` challenge -/

/-- **The code's `challenge_fp2`** on a digest read as its two 128-bit halves `(lo, hi)`: each half reduced mod `p`,
the low half the first coordinate. -/
def fp2Chal (p N : ℕ) (v : Fin N × Fin N) : ZMod p × ZMod p :=
  (((v.1 : ℕ) : ZMod p), ((v.2 : ℕ) : ZMod p))

/-- Every coordinate pair has at most `(⌊N/p⌋ + 1)²` digest preimages. -/
theorem card_fp2Chal_fiber_le (N p : ℕ) [NeZero p] (c : ZMod p × ZMod p) :
    (univ.filter (fun v : Fin N × Fin N => fp2Chal p N v = c)).card ≤ (N / p + 1) ^ 2 := by
  have h : univ.filter (fun v : Fin N × Fin N => fp2Chal p N v = c)
      = (univ.filter (fun a : Fin N => ((a : ℕ) : ZMod p) = c.1))
        ×ˢ (univ.filter (fun b : Fin N => ((b : ℕ) : ZMod p) = c.2)) := by
    ext v
    simp [fp2Chal, Prod.ext_iff]
  rw [h, card_product, sq]
  exact Nat.mul_le_mul (card_fin_mod_fiber_le N p c.1) (card_fin_mod_fiber_le N p c.2)

/-- **The `Fp2` challenge in any field** `F` that the coordinate pairs map onto bijectively (`ι`; for `Fp2` this is
`(c0, c1) ↦ c0 + U·c1`). -/
def fp2Field {F : Type} (p N : ℕ) (ι : ZMod p × ZMod p ≃ F) (v : Fin N × Fin N) : F := ι (fp2Chal p N v)

/-- Every field challenge has at most `(⌊N/p⌋ + 1)²` digest preimages. -/
theorem card_fp2Field_fiber_le {F : Type} [DecidableEq F] (N p : ℕ) [NeZero p] (ι : ZMod p × ZMod p ≃ F) (c : F) :
    (univ.filter (fun v : Fin N × Fin N => fp2Field p N ι v = c)).card ≤ (N / p + 1) ^ 2 := by
  have h : univ.filter (fun v : Fin N × Fin N => fp2Field p N ι v = c)
      = univ.filter (fun v : Fin N × Fin N => fp2Chal p N v = ι.symm c) := by
    ext v
    simp only [mem_filter, mem_univ, true_and]
    exact (Equiv.eq_symm_apply ι).symm
  rw [h]
  exact card_fp2Chal_fiber_le N p (ι.symm c)

/-- **The bias factor of `challenge_fp2`** is at most `(1 + p/N)²`: `(⌊N/p⌋ + 1)²·p²/N² ≤ ((N + p)/N)²`. Here `F` has
`p²` elements (it is in bijection with `ZMod p × ZMod p`). -/
theorem biasFactor_fp2_le {F : Type} [Fintype F] (N p : ℕ) [NeZero N] (hF : Fintype.card F = p ^ 2) :
    biasFactor ((N / p + 1) ^ 2) F (Fin N × Fin N) ≤ (1 + (p : ℝ≥0∞) / N) ^ 2 := by
  have hN0 : (N : ℝ≥0∞) ≠ 0 := by exact_mod_cast NeZero.ne N
  have hNt : (N : ℝ≥0∞) ≠ ⊤ := ENNReal.natCast_ne_top _
  have hnat : (N / p + 1) ^ 2 * p ^ 2 ≤ (N + p) ^ 2 := by
    rw [← mul_pow]
    refine Nat.pow_le_pow_left ?_ 2
    rw [add_mul, one_mul]
    exact Nat.add_le_add_right (Nat.div_mul_le_self N p) p
  have hone : (1 : ℝ≥0∞) + (p : ℝ≥0∞) / N = ((N + p : ℕ) : ℝ≥0∞) / N := by
    rw [Nat.cast_add, ENNReal.add_div, ENNReal.div_self hN0 hNt]
  rw [biasFactor, Fintype.card_prod, Fintype.card_fin, hF, hone]
  calc (((N / p + 1) ^ 2 : ℕ) : ℝ≥0∞) * ((p ^ 2 : ℕ) : ℝ≥0∞) / ((N * N : ℕ) : ℝ≥0∞)
      ≤ (((N + p) ^ 2 : ℕ) : ℝ≥0∞) / ((N * N : ℕ) : ℝ≥0∞) := by
        gcongr
        exact_mod_cast hnat
    _ = (((N + p : ℕ) : ℝ≥0∞) / N) ^ 2 := by
        rw [div_eq_mul_inv, div_eq_mul_inv, mul_pow, ← ENNReal.inv_pow, Nat.cast_pow, Nat.cast_mul,
          sq (N : ℝ≥0∞)]

/-- **A modulus below `2^64`.** For `p ≤ 2^64` and `N = 2^128`, `p/N ≤ 2^-64`: the bias factor of `challenge_fp2` is
at most `(1 + 2^-64)²`. -/
theorem bias_le_two_pow_64 (p : ℕ) (hp : p ≤ 2 ^ 64) :
    (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2 ≤ (1 + (2⁻¹ : ℝ≥0∞) ^ 64) ^ 2 := by
  gcongr
  have h2 : (2⁻¹ : ℝ≥0∞) ^ 64 * 2 ^ 64 = 1 := by
    rw [← mul_pow, ENNReal.inv_mul_cancel two_ne_zero ENNReal.ofNat_ne_top, one_pow]
  have h128 : (2⁻¹ : ℝ≥0∞) ^ 64 * ((2 ^ 128 : ℕ) : ℝ≥0∞) = ((2 ^ 64 : ℕ) : ℝ≥0∞) := by
    simp only [Nat.cast_pow, Nat.cast_ofNat]
    rw [show (128 : ℕ) = 64 + 64 from rfl, pow_add, ← mul_assoc, h2, one_mul]
  rw [ENNReal.div_le_iff (by positivity) (ENNReal.natCast_ne_top _), h128]
  exact_mod_cast hp

/-- **Goldilocks.** For `p = 2^64 − 2^32 + 1` the bias factor of `challenge_fp2` is at most `(1 + 2^-64)²`. -/
theorem goldilocks_bias_le :
    (1 + ((2 ^ 64 - 2 ^ 32 + 1 : ℕ) : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2 ≤ (1 + (2⁻¹ : ℝ≥0∞) ^ 64) ^ 2 :=
  bias_le_two_pow_64 _ (by norm_num)

/-- **A set of `Fp2` challenges, hit by the derived challenge.** For a uniform digest, the code's `challenge_fp2`
lands in a set `S` of field elements with probability at most `|S|/|F| · (1 + p/N)²`. -/
theorem prob_fp2Field_mem_le {F : Type} [Fintype F] [DecidableEq F] (N p : ℕ) [NeZero N] [NeZero p]
    (ι : ZMod p × ZMod p ≃ F) (hF : Fintype.card F = p ^ 2) (S : Finset F) :
    (PMF.uniformOfFintype (Fin N × Fin N)).toOuterMeasure {v | fp2Field p N ι v ∈ S}
      ≤ (S.card : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / N) ^ 2 := by
  classical
  have : Nonempty F := ⟨ι 0⟩
  have hE : EscapesWithin (fun v : Fin N × Fin N => fp2Field p N ι v ∈ S) (S.card * (N / p + 1) ^ 2) :=
    (show EscapesWithin (fun c : F => c ∈ S) S.card from ⟨S, le_rfl, fun _ h => h⟩).comap _
      (card_fp2Field_fiber_le N p ι)
  calc _ ≤ ((S.card * (N / p + 1) ^ 2 : ℕ) : ℝ≥0∞) / Fintype.card (Fin N × Fin N) := hE.prob_le
    _ = (S.card : ℝ≥0∞) / Fintype.card F * biasFactor ((N / p + 1) ^ 2) F (Fin N × Fin N) :=
        div_card_eq_mul_bias _ _
    _ ≤ _ := by gcongr; exact biasFactor_fp2_le N p hF

/-! ## The column indices -/

/-- **The code's `challenge_indices`** on one 8-byte chunk `v`: `v &&& (bound − 1)` with `bound = 2^h`. -/
def idxChal (h : ℕ) (v : Fin (2 ^ 64)) : Fin (2 ^ h) :=
  ⟨(v : ℕ) &&& (2 ^ h - 1), by rw [Nat.and_two_pow_sub_one_eq_mod]; exact Nat.mod_lt _ (by positivity)⟩

/-- The mask is reduction mod `2^h`. -/
theorem idxChal_eq (h : ℕ) (v : Fin (2 ^ 64)) : ((idxChal h v : Fin (2 ^ h)) : ℕ) = (v : ℕ) % 2 ^ h :=
  Nat.and_two_pow_sub_one_eq_mod _ _

/-- Every index value has at most `2^64/2^h` chunk preimages (for `h ≤ 64`). -/
theorem card_idxChal_fiber_le {h : ℕ} (hh : h ≤ 64) (j : Fin (2 ^ h)) :
    (univ.filter (fun v : Fin (2 ^ 64) => idxChal h v = j)).card ≤ 2 ^ 64 / 2 ^ h := by
  have hset : univ.filter (fun v : Fin (2 ^ 64) => idxChal h v = j)
      = univ.filter (fun v : Fin (2 ^ 64) => ((v : ℕ) : ZMod (2 ^ h)) = ((j : ℕ) : ZMod (2 ^ h))) := by
    ext v
    simp only [mem_filter, mem_univ, true_and]
    rw [Fin.ext_iff, idxChal_eq, ZMod.natCast_eq_natCast_iff', Nat.mod_eq_of_lt j.isLt]
  rw [hset]
  exact card_fin_mod_fiber_le_of_dvd (2 ^ 64) (2 ^ h) (pow_dvd_pow 2 hh) _

/-- **The column indices are exactly uniform**: the bias factor of `challenge_indices` is `1` (for `h ≤ 64`). -/
theorem biasFactor_idx_eq_one {h : ℕ} (hh : h ≤ 64) :
    biasFactor (2 ^ 64 / 2 ^ h) (Fin (2 ^ h)) (Fin (2 ^ 64)) = 1 := by
  have hdiv : 2 ^ 64 / 2 ^ h * 2 ^ h = 2 ^ 64 := Nat.div_mul_cancel (pow_dvd_pow 2 hh)
  rw [biasFactor, Fintype.card_fin, Fintype.card_fin, ← Nat.cast_mul, hdiv]
  exact ENNReal.div_self (by positivity) (ENNReal.natCast_ne_top _)

end ZK60.Sound
