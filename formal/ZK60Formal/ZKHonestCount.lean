/-
D63 lane L33 (2026-11-09), part 5: **the counts by kind for a prover program, and the budget of a refusing prover**.

The counts `hKw` (a question is met by some point for few coins and values) of L19's step are stated per question.
For a prover program the points have a simple shape: a transcript point, a Merkle node, a salted leaf, a pad point each
SHOW one earlier value (a transcript point starts with the previous state, a node holds its children, a leaf holds its
column digest: L19-3's column digests as programmed points), and a column digest is fresh in the coins.

* **`exposed_card`**: a point that shows the value `v j` (some function of the point returns it) equals a given
  question for at most a `1/|D|` share of the coins and values: `|D|·count ≤ |C × D^k|`. This is the `2^-256` of every
  transcript, node, leaf and pad point, PROVED from the point's shape alone;
* **`hit_card_by_label`**: with a label read off the point (its key, its length, a squeeze's counter, an absorb's
  label), a question is met at most `m·κ` times: `m` the number of points with the question's label, `κ` the bound of
  one point of that label (L19's `hit_card_label` with a bound per label);
* **`hKw_exposed`**: both together, for a point family all of whose points show an earlier value: a question is met
  for at most `m(z)·|C × D^k|/|D|` of the coins and values;
* `refErr`, **`ref_cap_R`**: the budget of a REFUSING prover (finding L33-3). The refusal guard of `ZKHonestStep.lean` charges
  the questions asked AFTER the request at the before-request rates too (a refused receipt's transcript points are
  hidden), with the guard's factor `2`: the after-request rates are `2(δh + δp)` and `2(ωh + ωp)`. With a receipt's
  counts by kind `Z` (L19's `ZKKinds`): within `εzkTarget q R` for every `q` and every `R ≤ 2^r` when `r + b ≤ 131`
  and `a + r + 134 ≤ 256` (two bits below L19's `ZKKinds.cap_R`);
* **`runK_ref_cap_110`**: at L19's counts of a whole Shieldstral classify run as one receipt (`RunK.kinds`): every
  `R ≤ 2^110`; **`w16r2K_ref_cap_118`**, **`r13K_ref_cap_118`**: one block receipt at L19's counts: every
  `R ≤ 2^118`.

Every premise is an explicit hypothesis.
-/
import ZK60Formal.ZKHonestStep

set_option autoImplicit false

namespace ZK60.ZKHonest

open scoped ENNReal
open Finset ZK60 ZK60.ZKW16 ZK60.ZKCount

/-! ## A point that shows a value -/

/-- **A point that shows an earlier value is fresh.** If some function `g` of the point returns the value `v j`
(`hg`), the point equals a given question `z` for at most a `1/|D|` share of the coins and values. -/
theorem exposed_card {C D Q : Type} [Fintype C] [Fintype D] [DecidableEq Q] {k : ℕ}
    (P : C × (Fin k → D) → Q) (j : Fin k) (g : Q → D) (hg : ∀ s, g (P s) = s.2 j) (z : Q) :
    Fintype.card D * (univ.filter (fun s : C × (Fin k → D) => P s = z)).card
      ≤ Fintype.card (C × (Fin k → D)) := by
  classical
  have hfib : ∀ s ∈ univ.filter (fun s : C × (Fin k → D) => P s = z), s.2 j = g z := by
    intro s hs
    rw [← hg s, (mem_filter.mp hs).2]
  have hcard : ((univ : Finset D) ×ˢ univ.filter (fun s : C × (Fin k → D) => P s = z)).card
      ≤ (univ : Finset (C × (Fin k → D))).card := by
    refine Finset.card_le_card_of_injOn
      (fun p : D × (C × (Fin k → D)) => (p.2.1, Function.update p.2.2 j p.1)) (fun _ _ => mem_univ _) ?_
    intro p hp p' hp' heq
    have hp2 := (Finset.mem_product.mp (Finset.mem_coe.mp hp)).2
    have hp2' := (Finset.mem_product.mp (Finset.mem_coe.mp hp')).2
    have h1 : p.2.1 = p'.2.1 := congrArg Prod.fst heq
    have h2 : Function.update p.2.2 j p.1 = Function.update p'.2.2 j p'.1 := congrArg Prod.snd heq
    have h3 : p.1 = p'.1 := by
      have h := congrFun h2 j
      rwa [Function.update_self, Function.update_self] at h
    have h4 : p.2.2 = p'.2.2 := by
      funext i
      by_cases hi : i = j
      · rw [hi, hfib p.2 hp2, hfib p'.2 hp2']
      · have h := congrFun h2 i
        rwa [Function.update_of_ne hi, Function.update_of_ne hi] at h
    exact Prod.ext h3 (Prod.ext h1 h4)
  rw [Finset.card_product, Finset.card_univ, Finset.card_univ] at hcard
  exact hcard

open Classical in
/-- **The multiplicity bound with a bound per label** (L19's `hit_card_label`): if every point carries a fixed label
read off the point itself and a point of label `λ` is hit by a question at most `κ λ` times, a question `z` is hit by
some point at most `m·κ (lab z)` times, `m` the number of points with `z`'s label. -/
theorem hit_card_by_label {Ω Q L : Type} [Fintype Ω] [DecidableEq Q] [DecidableEq L] {k : ℕ} (P : Ω → Fin k → Q)
    (lab : Q → L) (ℓ : Fin k → L) (hlab : ∀ s i, lab (P s i) = ℓ i) (z : Q) (κ : L → ℕ)
    (hκ : ∀ i, (univ.filter (fun s => P s i = z)).card ≤ κ (ℓ i)) :
    (univ.filter (fun s => ∃ i, P s i = z)).card ≤ (univ.filter (fun i => ℓ i = lab z)).card * κ (lab z) := by
  classical
  calc (univ.filter (fun s => ∃ i, P s i = z)).card
      ≤ ((univ.filter (fun i => ℓ i = lab z)).biUnion (fun i => univ.filter (fun s => P s i = z))).card := by
        refine card_le_card (fun s hs => ?_)
        obtain ⟨i, hi⟩ := (mem_filter.mp hs).2
        refine mem_biUnion.mpr ⟨i, mem_filter.mpr ⟨mem_univ _, ?_⟩, mem_filter.mpr ⟨mem_univ _, hi⟩⟩
        rw [← hlab s i, hi]
    _ ≤ ∑ i ∈ univ.filter (fun i => ℓ i = lab z), (univ.filter (fun s => P s i = z)).card := card_biUnion_le
    _ ≤ ∑ _i ∈ univ.filter (fun i => ℓ i = lab z), κ (lab z) := by
        refine sum_le_sum (fun i hi => ?_)
        have h := hκ i
        rw [(mem_filter.mp hi).2] at h
        exact h
    _ = (univ.filter (fun i => ℓ i = lab z)).card * κ (lab z) := by rw [sum_const, smul_eq_mul]

open Classical in
/-- **`hKw` for points that show a value.** If every point carries a label read off the point (`hlab`) and shows an
earlier value (`hg`), a question `z` is met by some point for at most `m(z)·(|C × D^k| / |D|)` of the coins and values,
`m(z)` the number of points with `z`'s label: the transcript rate `mT·2^-256` of L19's `ZKKinds`, from the points'
shape. -/
theorem hKw_exposed {C D Q L : Type} [Fintype C] [Fintype D] [Nonempty D] [DecidableEq Q] [DecidableEq L] {k : ℕ}
    (P : C × (Fin k → D) → Fin k → Q) (lab : Q → L) (ℓ : Fin k → L) (hlab : ∀ s i, lab (P s i) = ℓ i)
    (j : Fin k → Fin k) (g : Fin k → Q → D) (hg : ∀ s i, g i (P s i) = s.2 (j i)) (z : Q) :
    (univ.filter (fun s : C × (Fin k → D) => ∃ i, P s i = z)).card
      ≤ (univ.filter (fun i => ℓ i = lab z)).card
        * (Fintype.card (C × (Fin k → D)) / Fintype.card D) := by
  refine hit_card_by_label P lab ℓ hlab z (fun _ => Fintype.card (C × (Fin k → D)) / Fintype.card D) (fun i => ?_)
  have h := exposed_card (fun s => P s i) (j i) (g i) (fun s => hg s i) z
  rw [Nat.mul_comm] at h
  exact (Nat.le_div_iff_mul_le Fintype.card_pos).mpr h

/-! ## The budget of a refusing prover -/

/-- `a + 2(b + a) ≤ 4(a + b)`. -/
theorem three_le_four (a b : ℝ≥0∞) : a + 2 * (b + a) ≤ 4 * (a + b) :=
  calc a + 2 * (b + a) ≤ a + 2 * (b + a) + (a + 2 * b) := le_self_add
    _ = 4 * (a + b) := by ring

/-- **The error of a refusing prover with a receipt's counts by kind `Z`**: `zk_of_refModel`'s
`Σ_{j<R} wStep δp ωp δh ωh εc q R j` at `Z`'s before-request rates and the after-request rates `2(δh + δp)`,
`2(ωh + ωp)` (the guard charges a question asked after the request at its before-request rate too, with the factor
`2` of `hid_card_ref`). -/
noncomputable def refErr (Z : ZKKinds) (q R : ℕ) : ℝ≥0∞ :=
  ∑ j ∈ range R, wStep Z.δp Z.ωp (2 * (Z.δh + Z.δp)) (2 * (Z.ωh + Z.ωp)) Z.εc q R j

/-- **The cap of a refusing prover** (finding L33-3). With the after-request rates `2(δh + δp)` and `2(ωh + ωp)` of
`zk_of_refModel` (the guard charges the after-request questions at the before-request rates too), a receipt's counts
by kind `Z` with `mT ≤ 2^a`, `qpT·mT ≤ 2^b` (`b ≥ 13`), the other counts at most `2^c` with `2c + 252` bits of column
freshness, `pts ≤ 2^p`: the summed error is within `εzkTarget q R` for every `q` and every `R ≤ 2^r` with
`r + b ≤ 131`, `a + r + 134 ≤ 256` and `r ≤ 118`. -/
theorem ref_cap_R (Z : ZKKinds) (c p a b r : ℕ) (hm : Z.mT ≤ 2 ^ a) (hb : Z.qpT * Z.mT ≤ 2 ^ b) (hb13 : 13 ≤ b)
    (hC : Z.cols ≤ 2 ^ c) (hLN : Z.leaves + Z.nodes ≤ 2 ^ c)
    (hqC : Z.qpC ≤ 2 ^ c) (hqL : Z.qpL ≤ 2 ^ c) (hqN : Z.qpN ≤ 2 ^ c)
    (hcol : 2 * c + 252 ≤ Z.hcol) (hcond : 2 * c + 252 ≤ Z.hcond) (h512 : 2 * c + 252 ≤ 512)
    (hp : Z.pts ≤ 2 ^ p) (hp' : 2 * p + 124 ≤ 256) (hrb : r + b ≤ 131) (har : a + r + 134 ≤ 256) (hr : r ≤ 118)
    (q R : ℕ) (hR : R ≤ 2 ^ r) : refErr Z q R ≤ εzkTarget q R := by
  show ∑ j ∈ range R, wStep Z.δp Z.ωp (2 * (Z.δh + Z.δp)) (2 * (Z.ωh + Z.ωp)) Z.εc q R j ≤ εzkTarget q R
  have hδ := ZKKinds.δ_le_gen Z c a (r + 131) hm hC hLN (by omega) (by omega) (by omega) (by omega)
  have hω := ZKKinds.ω_le Z c b hb hb13 (by omega) hC hLN hqC hqL hqN hcol hcond h512
  have hε := ZKKinds.εc_le Z p hp hp'
  have h3δ : Z.δp + 2 * (Z.δh + Z.δp) ≤ (2⁻¹ : ℝ≥0∞) ^ ((r + 1) + 128) :=
    calc Z.δp + 2 * (Z.δh + Z.δp) ≤ 4 * (Z.δp + Z.δh) := three_le_four _ _
      _ ≤ 4 * (2⁻¹ : ℝ≥0∞) ^ (r + 131) := mul_le_mul_right hδ _
      _ = (2 : ℝ≥0∞) ^ 2 * (2⁻¹ : ℝ≥0∞) ^ (2 + ((r + 1) + 128)) := by ring
      _ = (2⁻¹ : ℝ≥0∞) ^ ((r + 1) + 128) := two_pow_mul_inv_pow 2 ((r + 1) + 128)
  have e255 : 255 - b = 2 + (253 - b) := by omega
  have h3ω : Z.ωp + 2 * (Z.ωh + Z.ωp) ≤ (2⁻¹ : ℝ≥0∞) ^ (253 - b) :=
    calc Z.ωp + 2 * (Z.ωh + Z.ωp) ≤ 4 * (Z.ωp + Z.ωh) := three_le_four _ _
      _ ≤ 4 * (2⁻¹ : ℝ≥0∞) ^ (255 - b) := mul_le_mul_right hω _
      _ = (2 : ℝ≥0∞) ^ 2 * (2⁻¹ : ℝ≥0∞) ^ (2 + (253 - b)) := by rw [e255]; ring
      _ = (2⁻¹ : ℝ≥0∞) ^ (253 - b) := two_pow_mul_inv_pow 2 (253 - b)
  refine wBudget_le q R r hR _ _ _ _ _ ?_ ?_
  · calc (2 : ℝ≥0∞) ^ (r + 1) * (Z.δp + 2 * (Z.δh + Z.δp))
        ≤ 2 ^ (r + 1) * (2⁻¹ : ℝ≥0∞) ^ ((r + 1) + 128) := mul_le_mul_right h3δ _
      _ = (2⁻¹ : ℝ≥0∞) ^ 128 := two_pow_mul_inv_pow (r + 1) 128
  · have e253 : 253 - b = (r + 1) + (252 - b - r) := by omega
    have h1 : (2 : ℝ≥0∞) ^ (r + 1) * (Z.ωp + 2 * (Z.ωh + Z.ωp)) ≤ (2⁻¹ : ℝ≥0∞) ^ 121 :=
      calc (2 : ℝ≥0∞) ^ (r + 1) * (Z.ωp + 2 * (Z.ωh + Z.ωp))
          ≤ 2 ^ (r + 1) * (2⁻¹ : ℝ≥0∞) ^ (253 - b) := mul_le_mul_right h3ω _
        _ = 2 ^ (r + 1) * (2⁻¹ : ℝ≥0∞) ^ ((r + 1) + (252 - b - r)) := by rw [e253]
        _ = (2⁻¹ : ℝ≥0∞) ^ (252 - b - r) := two_pow_mul_inv_pow (r + 1) (252 - b - r)
        _ ≤ (2⁻¹ : ℝ≥0∞) ^ 121 := inv_pow_le_inv_pow (by omega)
    have h2 : 4 * Z.εc ≤ (2⁻¹ : ℝ≥0∞) ^ 122 :=
      calc 4 * Z.εc ≤ 4 * (2⁻¹ : ℝ≥0∞) ^ 124 := mul_le_mul_right hε _
        _ = (2 : ℝ≥0∞) ^ 2 * (2⁻¹ : ℝ≥0∞) ^ (2 + 122) := by ring
        _ = (2⁻¹ : ℝ≥0∞) ^ 122 := two_pow_mul_inv_pow 2 122
    calc (2 : ℝ≥0∞) ^ (r + 1) * (Z.ωp + 2 * (Z.ωh + Z.ωp)) + 4 * Z.εc
        ≤ (2⁻¹ : ℝ≥0∞) ^ 121 + (2⁻¹ : ℝ≥0∞) ^ 122 := add_le_add h1 h2
      _ ≤ (2⁻¹ : ℝ≥0∞) ^ 121 + (2⁻¹ : ℝ≥0∞) ^ 121 := add_le_add le_rfl (inv_pow_le_inv_pow (by norm_num))
      _ = (2 : ℝ≥0∞) ^ 1 * (2⁻¹ : ℝ≥0∞) ^ (1 + 120) := by ring
      _ = (2⁻¹ : ℝ≥0∞) ^ 120 := two_pow_mul_inv_pow 1 120

/-- **A whole Shieldstral classify run as one receipt, refusing prover**: at L19's counts (`RunK.kinds`,
`a = 5`, `b = 21`, `c = 23`, `p = 24`) the summed error with the refusal guard's after-request rates is within
`εzkTarget q R` for every `q` and every `R ≤ 2^110`. -/
theorem runK_ref_cap_110 (q R : ℕ) (hR : R ≤ 2 ^ 110) : refErr RunK.kinds q R ≤ εzkTarget q R :=
  ref_cap_R RunK.kinds 23 24 5 21 110 (by decide) (by decide) (by norm_num) (by decide) (by decide) (by decide)
    (by decide) (by decide) (by decide) (by decide) (by decide) (by decide) (by norm_num) (by norm_num) (by norm_num)
    (by norm_num) q R hR

/-- **One W16R2 block receipt, refusing prover**: at L19's counts (`W16R2K.kinds`, `a = 1`, `b = 13`, `c = 18`,
`p = 18`), within `εzkTarget q R` for every `q` and every `R ≤ 2^118` (L19's `W16R2K.every_R`, every `R`, is for a
prover that never refuses). -/
theorem w16r2K_ref_cap_118 (q R : ℕ) (hR : R ≤ 2 ^ 118) : refErr W16R2K.kinds q R ≤ εzkTarget q R :=
  ref_cap_R W16R2K.kinds 18 18 1 13 118 (by decide) (by decide) (by norm_num) (by decide) (by decide) (by decide)
    (by decide) (by decide) (by decide) (by decide) (by decide) (by decide) (by norm_num) (by norm_num) (by norm_num)
    (by norm_num) q R hR

/-- **One R13 block receipt, refusing prover**: at L19's counts (`R13K.kinds`, `a = 1`, `b = 13`, `c = 19`,
`p = 19`), within `εzkTarget q R` for every `q` and every `R ≤ 2^118`. -/
theorem r13K_ref_cap_118 (q R : ℕ) (hR : R ≤ 2 ^ 118) : refErr R13K.kinds q R ≤ εzkTarget q R :=
  ref_cap_R R13K.kinds 19 19 1 13 118 (by decide) (by decide) (by norm_num) (by decide) (by decide) (by decide)
    (by decide) (by decide) (by decide) (by decide) (by decide) (by decide) (by norm_num) (by norm_num) (by norm_num)
    (by norm_num) q R hR

end ZK60.ZKHonest
