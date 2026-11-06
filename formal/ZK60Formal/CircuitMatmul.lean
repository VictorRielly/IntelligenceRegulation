/-
D63, step L2 (`CircuitIff`), the MATMUL HAND-OFF: the hosted value of a requantization IS the integer matmul sum, and
its no-wrap bound follows from the word classes and the shapes. This removes the premise `|a| ≤ 2^62` of
`requant_iff` (CircuitRequant.lean) at every matmul site.

The constraint, as the code builds it. A matmul slot (`SC_QMM`, `SC_KMM`, `SC_VMM`, `SC_WO`, argument.rs:2150-2191;
`SC_GMM`, `SC_UMM`, `SC_DMM`, argument.rs:2299-2332) proves, by its sumcheck, the claim
`Σ_i x~(r_t, i) · Wf~(i, r_j)` at a random point, where `Wf` is the PUBLIC weight folded with the public per-output
multiplier (`accuracy_fold::fold`, accuracy_fold.rs:46-60: `eq_j · m_j · W[j, i]`). The zero-check slot that hosts the
requantization carries the term `ν · eq(p, ·) · (2^s·q + R − 2^(s−1))` against the same point (the `hosted` lists, e.g.
argument_accuracy.rs:484, 498). L3 (the zero-check and sumcheck soundness, `SoundZeroCheck.lean`, `SoundSumcheck.lean`)
turns the two claims into the identity at EVERY position of the cube:
  `2^s·q(t, j) + R(t, j) − 2^(s−1) = Σ_i x(t, i) · (W(i, j)·m_j)`   in `GF`,
i.e. `HostRel s (Σ_i x_i·(W_i·m)) q R`. That identity is the matmul's contribution to the constraint system; this file
proves what it gives.

The two private-by-private products (the scores `SC_SCORE`, argument.rs:2231-2266, and `SC_PV`, :2267-2292) host
`Σ_c qr·kr` and `Σ_j P·v`, with no multiplier (`bilinear_requant_iff`).

The bounds (all CODE, checked before anything is proved):
* public weights and gains are symmetric int8, `|W| ≤ 127` (private_block.rs:863-869, witness_accuracy.rs:498-517:
  "R13 public weights/gains must be symmetric int8");
* the folded multipliers satisfy `m ≤ 2^14` (accuracy_fold.rs:51-55; the registered ones are `≤ 2^4 .. 2^8`,
  accuracy_public.rs:136-140 with `multiplier_bits = [5, 5, 6, 8, 6, 4, 6]`, accuracy_precision.rs:105);
* the geometry's NO-WRAP CLASS: width, query width and kv width `≤ 4096`, hidden `≤ 16384` (accuracy_public.rs:16-28);
* the inputs are words of their classes: int16 (`Word16`, 2^15), the 24-bit product word (`Word24`, 2^23), the
  softmax quotient `P ∈ [0, 2^13)`.

`noWrap_class_bounds` evaluates every site at the worst case of that class: the largest hosted value is the down
projection's, `16384 · 2^23 · 127 · 2^14 < 2^58`, five bits below `2^62`.
-/
import ZK60Formal.CircuitNorm
import Mathlib.Algebra.BigOperators.Ring.Finset
import Mathlib.Algebra.Order.BigOperators.Group.Finset

namespace ZK60.Circuit

open ZK60.Model

/-! ## Dot products: their field image and their bound -/

/-- The field image of a hosted matmul value: `Σ_i x_i·((W_i·m : ℤ) : GF)` is the image of the integer
`(Σ_i x_i·W_i)·m`. -/
theorem hosted_cast {ι : Type} [Fintype ι] (x w : ι → ℤ) (m : ℕ) :
    (∑ i, (x i : GF) * ((w i * (m : ℤ) : ℤ) : GF)) = ((((∑ i, x i * w i) * (m : ℤ)) : ℤ) : GF) := by
  push_cast
  rw [Finset.sum_mul]
  refine Finset.sum_congr rfl fun i _ => ?_
  ring

/-- The field image of a private-by-private product sum. -/
theorem bilinear_cast {ι : Type} [Fintype ι] (x w : ι → ℤ) :
    (∑ i, (x i : GF) * (w i : GF)) = ((∑ i, x i * w i : ℤ) : GF) := by
  push_cast
  rfl

/-- `|Σ_i x_i·w_i| ≤ |ι|·X·W`. -/
theorem dot_abs_le {ι : Type} [Fintype ι] (x w : ι → ℤ) {X Wb : ℤ} (hx : ∀ i, |x i| ≤ X) (hw : ∀ i, |w i| ≤ Wb) :
    |∑ i, x i * w i| ≤ (Fintype.card ι : ℤ) * (X * Wb) := by
  calc |∑ i, x i * w i| ≤ ∑ i, |x i * w i| := Finset.abs_sum_le_sum_abs _ _
    _ ≤ ∑ _i : ι, X * Wb := Finset.sum_le_sum fun i _ => by
        rw [abs_mul]
        exact mul_le_mul (hx i) (hw i) (abs_nonneg _) (le_trans (abs_nonneg _) (hx i))
    _ = (Fintype.card ι : ℤ) * (X * Wb) := by
        rw [Finset.sum_const, Finset.card_univ, nsmul_eq_mul]

/-- The hosted value of a matmul with multiplier `m` is below `2^62` once `N·X·W·M ≤ 2^62`, where `N` bounds the
inner dimension, `X` the input words, `W` the weights and `M` the multiplier. -/
theorem hosted_abs_le {ι : Type} [Fintype ι] (x w : ι → ℤ) (m : ℕ) {N X Wb M : ℤ}
    (hx : ∀ i, |x i| ≤ X) (hw : ∀ i, |w i| ≤ Wb) (hN : (Fintype.card ι : ℤ) ≤ N) (hm : (m : ℤ) ≤ M)
    (hX : 0 ≤ X) (hW : 0 ≤ Wb) (hb : N * (X * Wb) * M ≤ 2 ^ 62) :
    |(∑ i, x i * w i) * (m : ℤ)| ≤ 2 ^ 62 := by
  have h1 := dot_abs_le x w hx hw
  have hXW : 0 ≤ X * Wb := mul_nonneg hX hW
  have h2 : |∑ i, x i * w i| ≤ N * (X * Wb) := le_trans h1 (mul_le_mul_of_nonneg_right hN hXW)
  have hN0 : 0 ≤ N * (X * Wb) := le_trans (abs_nonneg _) h2
  have hm0 : (0 : ℤ) ≤ (m : ℤ) := Int.natCast_nonneg m
  rw [abs_mul, abs_of_nonneg hm0]
  calc |∑ i, x i * w i| * (m : ℤ) ≤ N * (X * Wb) * M := mul_le_mul h2 hm hm0 hN0
    _ ≤ 2 ^ 62 := hb

/-! ## The requantization of a matmul -/

/-- `requant acc m s` is `requant (acc·m) 1 s`: the multiplier enters only through the product. -/
theorem requantIn_mul (lo hi acc : ℤ) (m s : ℕ) :
    requantIn lo hi acc m s = requantIn lo hi (acc * (m : ℤ)) 1 s := by
  have h : requant acc m s = requant (acc * (m : ℤ)) 1 s := by
    simp only [requant, Nat.cast_one, mul_one]
  unfold requantIn
  rw [h]

/-- **The matmul hand-off.** The hosted matmul identity (the matmul sumcheck's conclusion), the word's lookup and the
remainder's lookups hold exactly when the integer model, on the INTEGER matmul sum `Σ_i x_i·W_i` with multiplier `m`,
admits the position and `q` is its word. The only premise is the no-wrap bound of the hosted value, which
`hosted_abs_le` derives from the classes (`noWrap_class_bounds`). -/
theorem matmul_requant_iff (C : WordClass) (s : ℕ) (hs : s ≤ 24) {ι : Type} [Fintype ι] (x w : ι → ℤ) (m : ℕ)
    (hb : |(∑ i, x i * w i) * (m : ℤ)| ≤ 2 ^ 62) (q : GF) :
    (∃ R : GF, HostRel s (∑ i, (x i : GF) * ((w i * (m : ℤ) : ℤ) : GF)) q R ∧ C.P q ∧ RemW16 s R) ↔
      ∃ v r : ℤ, requantIn C.lo C.hi (∑ i, x i * w i) m s = some (v, r) ∧ q = (v : GF) := by
  rw [hosted_cast, requantIn_mul]
  exact requant_iff C s hs _ (abs_le.mp hb).1 (abs_le.mp hb).2 q

/-- **The private-by-private hand-off** (scores, `PV`): the hosted value is `Σ_i x_i·w_i` of two committed planes. -/
theorem bilinear_requant_iff (C : WordClass) (s : ℕ) (hs : s ≤ 24) {ι : Type} [Fintype ι] (x w : ι → ℤ)
    (hb : |∑ i, x i * w i| ≤ 2 ^ 62) (q : GF) :
    (∃ R : GF, HostRel s (∑ i, (x i : GF) * (w i : GF)) q R ∧ C.P q ∧ RemW16 s R) ↔
      ∃ v r : ℤ, requantIn C.lo C.hi (∑ i, x i * w i) 1 s = some (v, r) ∧ q = (v : GF) := by
  rw [bilinear_cast]
  exact requant_iff C s hs _ (abs_le.mp hb).1 (abs_le.mp hb).2 q

/-! ## The bounds, from the classes and the shapes -/

/-- int16 words have `|x| ≤ 2^15`. -/
theorem abs_le_of_int16 {x : ℤ} (h : -2 ^ 15 ≤ x ∧ x ≤ 2 ^ 15 - 1) : |x| ≤ 2 ^ 15 :=
  abs_le.mpr ⟨by linarith [h.1], by linarith [h.2]⟩

/-- An int16-input matmul over at most `4096` inner positions, int8 weights, multiplier `≤ 2^14`: the hosted value is
below `2^62` (in fact below `2^48`). The sites Q, K, V (inner: the width), O (the query width), gate and up (the
width). -/
theorem hosted16_le {ι : Type} [Fintype ι] (x w : ι → ℤ) (m : ℕ) (hx : ∀ i, -2 ^ 15 ≤ x i ∧ x i ≤ 2 ^ 15 - 1)
    (hw : ∀ i, |w i| ≤ 127) (hm : m ≤ 2 ^ 14) (hN : Fintype.card ι ≤ 4096) :
    |(∑ i, x i * w i) * (m : ℤ)| ≤ 2 ^ 62 :=
  hosted_abs_le x w m (N := 4096) (X := 2 ^ 15) (Wb := 127) (M := 2 ^ 14) (fun i => abs_le_of_int16 (hx i)) hw
    (by exact_mod_cast hN) (by exact_mod_cast hm) (by norm_num) (by norm_num) (by norm_num)

/-- The down projection: 24-bit product words over at most `16384` hidden positions (below `2^58`). -/
theorem hosted24_le {ι : Type} [Fintype ι] (x w : ι → ℤ) (m : ℕ) (hx : ∀ i, -2 ^ 23 ≤ x i ∧ x i ≤ 2 ^ 23 - 1)
    (hw : ∀ i, |w i| ≤ 127) (hm : m ≤ 2 ^ 14) (hN : Fintype.card ι ≤ 16384) :
    |(∑ i, x i * w i) * (m : ℤ)| ≤ 2 ^ 62 :=
  hosted_abs_le x w m (N := 16384) (X := 2 ^ 23) (Wb := 127) (M := 2 ^ 14)
    (fun i => abs_le.mpr ⟨by linarith [(hx i).1], by linarith [(hx i).2]⟩) hw
    (by exact_mod_cast hN) (by exact_mod_cast hm) (by norm_num) (by norm_num) (by norm_num)

/-- The scores: two int16 planes over a head dimension of at most `4096` (below `2^42`). -/
theorem hostedScore_le {ι : Type} [Fintype ι] (x w : ι → ℤ) (hx : ∀ i, -2 ^ 15 ≤ x i ∧ x i ≤ 2 ^ 15 - 1)
    (hw : ∀ i, -2 ^ 15 ≤ w i ∧ w i ≤ 2 ^ 15 - 1) (hN : Fintype.card ι ≤ 4096) : |∑ i, x i * w i| ≤ 2 ^ 62 := by
  have h := dot_abs_le x w (X := 2 ^ 15) (Wb := 2 ^ 15) (fun i => abs_le_of_int16 (hx i))
    (fun i => abs_le_of_int16 (hw i))
  have hN' : (Fintype.card ι : ℤ) ≤ 4096 := by exact_mod_cast hN
  have : (Fintype.card ι : ℤ) * (2 ^ 15 * 2 ^ 15) ≤ 4096 * (2 ^ 15 * 2 ^ 15) :=
    mul_le_mul_of_nonneg_right hN' (by norm_num)
  linarith

/-- `PV`: the quotient `0 ≤ P ≤ 2^12` against int16 values over at most `2^24` source tokens (below `2^51`). -/
theorem hostedPV_le {ι : Type} [Fintype ι] (x w : ι → ℤ) (hx : ∀ i, 0 ≤ x i ∧ x i ≤ 2 ^ 12)
    (hw : ∀ i, -2 ^ 15 ≤ w i ∧ w i ≤ 2 ^ 15 - 1) (hN : Fintype.card ι ≤ 2 ^ 24) : |∑ i, x i * w i| ≤ 2 ^ 62 := by
  have h := dot_abs_le x w (X := 2 ^ 12) (Wb := 2 ^ 15)
    (fun i => abs_le.mpr ⟨by linarith [(hx i).1], (hx i).2⟩) (fun i => abs_le_of_int16 (hw i))
  have hN' : (Fintype.card ι : ℤ) ≤ 2 ^ 24 := by exact_mod_cast hN
  have : (Fintype.card ι : ℤ) * (2 ^ 12 * 2 ^ 15) ≤ 2 ^ 24 * (2 ^ 12 * 2 ^ 15) :=
    mul_le_mul_of_nonneg_right hN' (by norm_num)
  linarith

/-- **Every hosted value of the W16R2 block, at the worst case of the code's no-wrap class**, against the `2^62` of
`requant_iff` (each entry: inner dimension, input bound, weight bound, multiplier bound):
* Q, K, V, O, gate, up: `4096 · 2^15 · 127 · 2^14 < 2^48`;
* down: `16384 · 2^23 · 127 · 2^14 < 2^58` (the largest; LowH24's 24-bit product word);
* scores: `4096 · 2^15 · 2^15 = 2^42`;
* `PV`: `2^24 · 2^12 · 2^15 = 2^51` (tokens bounded by `T·2^f_e ≤ 2^wrho_s ≤ 2^24`);
* RoPE: `2 · 2^7 · 2^15 = 2^23`; the SiLU product: `2^31 · 2^15 = 2^46`;
* the sum of squares of a norm: `4096 · 2^30 + 2^24 < 2^43`, against `isqrt_iff`'s `2^60`. -/
theorem noWrap_class_bounds :
    (4096 : ℤ) * (2 ^ 15 * 127) * 2 ^ 14 < 2 ^ 48 ∧
    (16384 : ℤ) * (2 ^ 23 * 127) * 2 ^ 14 < 2 ^ 58 ∧
    (4096 : ℤ) * (2 ^ 15 * 2 ^ 15) ≤ 2 ^ 42 ∧
    (2 ^ 24 : ℤ) * (2 ^ 12 * 2 ^ 15) ≤ 2 ^ 51 ∧
    (2 : ℤ) * (2 ^ 7 * 2 ^ 15) ≤ 2 ^ 23 ∧
    (2 ^ 31 : ℤ) * 2 ^ 15 ≤ 2 ^ 46 ∧
    (4096 : ℤ) * 2 ^ 30 + 2 ^ 24 < 2 ^ 43 ∧
    (2 : ℤ) ^ 58 ≤ 2 ^ 62 := by
  norm_num

/-! ## The sum of squares of a norm (the `SC_SS` hand-off) -/

/-- `SC_TZC` hosts `dsq + a1 − ceps` against `SC_SS`'s `Σ_i x_i·x_i` (argument.rs:2022-2028, 2099): the isqrt's
`ss = ceps + Σ x²` is an integer in `[0, 2^60)` for int16 inputs over at most `4096` positions, which discharges the
premise of `isqrt_iff`. -/
theorem ss_bounds {ι : Type} [Fintype ι] (x : ι → ℤ) (ceps : ℤ) (hx : ∀ i, -2 ^ 15 ≤ x i ∧ x i ≤ 2 ^ 15 - 1)
    (hc0 : 0 ≤ ceps) (hc1 : ceps ≤ 2 ^ 24) (hN : Fintype.card ι ≤ 4096) :
    0 ≤ ceps + ∑ i, x i * x i ∧ ceps + ∑ i, x i * x i < 2 ^ 60 := by
  have h0 : 0 ≤ ∑ i, x i * x i := Finset.sum_nonneg fun i _ => mul_self_nonneg (x i)
  have h := dot_abs_le x x (X := 2 ^ 15) (Wb := 2 ^ 15) (fun i => abs_le_of_int16 (hx i))
    (fun i => abs_le_of_int16 (hx i))
  have hN' : (Fintype.card ι : ℤ) ≤ 4096 := by exact_mod_cast hN
  have h2 : (Fintype.card ι : ℤ) * (2 ^ 15 * 2 ^ 15) ≤ 4096 * (2 ^ 15 * 2 ^ 15) :=
    mul_le_mul_of_nonneg_right hN' (by norm_num)
  have h3 : ∑ i, x i * x i ≤ |∑ i, x i * x i| := le_abs_self _
  constructor <;> linarith

/-- The field form of the hosted sum of squares. -/
theorem ss_cast {ι : Type} [Fintype ι] (x : ι → ℤ) (ceps : ℤ) :
    (ceps : GF) + ∑ i, (x i : GF) * (x i : GF) = ((ceps + ∑ i, x i * x i : ℤ) : GF) := by
  push_cast
  rfl

end ZK60.Circuit
