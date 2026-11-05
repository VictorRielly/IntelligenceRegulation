/-
D63, step L3 (soundness of the IOP): the proximity test for our Reed–Solomon code, at δ/3 and at δ/2.

The row code of `pcs.rs` (ZK mode) is `RS[D, K']` with `K' = n + q_pad` message symbols, `D = 7·G_N` a coset of `N`
distinct points of `F_p`: the verifier's encoder maps `(message, pads)` bijectively onto the polynomials of degree
`< K'` (`pcs.rs:557-569`, `:656-677`; the δ/2 lemma check §1). FlashProve's `rsCode dom K` is the code of the
polynomials of degree `≤ K` at the points `dom`, so ours is `rsCode dom (K' − 1)`, of minimum distance
`N − K = N − K' + 1` (`minDist_rsCode`).

What is proved:
* `rs_proximity_third`: δ/3 (rate 1/4, D15). If `3e + K + 1 ≤ N` (i.e. `3e < d`) and the rows are `e`-far, uniform
  weights give an `e`-close combination with probability `≤ (e + 1)/|L|`.
* `rs_proximity_half`: **δ/2, the unique-decoding radius (rate 1/2, D59; BCIKS20 Thm 3.1 / Thm 1.7 with Thm 4.1).**
  If `2e + K + 1 ≤ N` and the rows are `e`-far, uniform weights give an `e`-close combination with probability
  `≤ N/|L|`. The line case is FlashProve's `caOn_rsCode` (BCIKS20 Theorem 4.1, ported); the step from lines to
  independent weights is `comb_close_prob` (`SoundProximity.lean`), with no loss.
* `close_of_close_lift`, `rs_proximity_third_ext`, `rs_proximity_half_ext`: **the field split of the code.** The
  committed rows are over `F_p`, the weights over `F_p²`. A matrix over `F` whose image over the extension `L` is
  `e`-close to the extension's RS code (same points, read in `L`) is already `e`-close to the RS code over `F`: apply
  an `F`-linear form `φ : L → F` with `φ 1 = 1` to the decoded polynomials' coefficients. So `e`-far over `F_p` gives
  the bounds above over `F_p²`, with `|L| = p²`.

Counted: `count.py`'s regular-opening field terms are `(⌊δN/3⌋ + 1 + 4096)/p²` at δ/3 and `(N + 4096)/p²` at δ/2
(the 4096 is the carried ceiling of REVIEW_R14 A5). The proved terms are `(e + 1)/p²` and `N/p²`: the same, without
the ceiling.
-/
import ZK60Formal.SoundProximity
import ZK60Formal.ThirdParty.FlashProve.Code.Half

namespace ZK60.Sound

open scoped ENNReal
open Finset Prob Code Polynomial

variable {L ι κ : Type} [Field L] [Fintype ι] [Fintype κ]

/-- **The proximity test at δ/3 for Reed–Solomon codes.** Let `dom` be `N` distinct points and `3e + K + 1 ≤ N`
(the code of degree `≤ K` has minimum distance `N − K > 3e`). If the rows `U` are `e`-far from the interleaved code,
uniform weights `ρ` give an `e`-close combination with probability at most `(e + 1)/|L|`. -/
theorem rs_proximity_third [Fintype L] [DecidableEq κ] (dom : ι ↪ L) {e K : ℕ}
    (hn : 3 * e + K + 1 ≤ Fintype.card ι) (U : κ → ι → L) (hfar : ¬ Close (rsCode dom K) e U) :
    (PMF.uniformOfFintype (κ → L)).toOuterMeasure {r | Close (rsCode dom K) e (fun _ : Unit => comb U r)}
      ≤ ((e + 1 : ℕ) : ℝ≥0∞) / Fintype.card L :=
  proximity_third (minDist_rsCode dom K) (by omega) U hfar

/-- **The proximity test at δ/2 for Reed–Solomon codes (BCIKS20 Theorem 3.1, task 3).** Let `dom` be `N` distinct
points and `2e + K + 1 ≤ N`, the unique-decoding radius `e ≤ (N − K − 1)/2` of the code of degree `≤ K`. If the rows
`U` are `e`-far from the interleaved code, uniform independent weights `ρ` give an `e`-close combination with
probability at most `N/|L|`. -/
theorem rs_proximity_half [Fintype L] [DecidableEq κ] (dom : ι ↪ L) {e K : ℕ}
    (hn : 2 * e + K + 1 ≤ Fintype.card ι) (U : κ → ι → L) (hfar : ¬ Close (rsCode dom K) e U) :
    (PMF.uniformOfFintype (κ → L)).toOuterMeasure {r | Close (rsCode dom K) e (fun _ : Unit => comb U r)}
      ≤ (Fintype.card ι : ℝ≥0∞) / Fintype.card L :=
  comb_close_prob (minDist_rsCode dom K) (by omega) (by omega) (caOn_rsCode dom hn) U hfar

/-! ## Rows over the base field, weights over the extension -/

variable {F : Type} [Field F] [Algebra F L]

omit [Fintype ι] in
variable (L) in
/-- The evaluation points, read in the extension field `L`. -/
def liftDom (dom : ι ↪ F) : ι ↪ L :=
  dom.trans ⟨algebraMap F L, (algebraMap F L).injective⟩

omit [Fintype ι] in
theorem liftDom_apply (dom : ι ↪ F) (x : ι) : liftDom L dom x = algebraMap F L (dom x) := rfl

/-- An `F`-linear form on `L` that is `1` at `1` (for `L = F_p²`: the first coordinate). -/
theorem exists_form_one : ∃ φ : L →ₗ[F] F, φ 1 = 1 := by
  obtain ⟨φ, hφ⟩ := Module.Projective.exists_dual_ne_zero F (one_ne_zero : (1 : L) ≠ 0)
  refine ⟨(φ 1)⁻¹ • φ, ?_⟩
  rw [LinearMap.smul_apply, smul_eq_mul, inv_mul_cancel₀ hφ]

omit [Fintype ι] in
/-- A base-field word that agrees on `S` with a word of the extension's RS code agrees on `S` with a word of the
base field's RS code: apply a form `φ` with `φ 1 = 1` to the coefficients of the decoded polynomial. -/
theorem mem_agreeOn_rs_of_lift (dom : ι ↪ F) (K : ℕ) (S : Finset ι) (u : ι → F)
    (h : liftWord L u ∈ agreeOn (rsCode (liftDom L dom) K) S) : u ∈ agreeOn (rsCode dom K) S := by
  obtain ⟨φ, hφ⟩ := exists_form_one (F := F) (L := L)
  obtain ⟨c, hcD, hcS⟩ := mem_agreeOn.mp h
  obtain ⟨p, hp, hc⟩ := mem_rsCode.mp hcD
  set q : F[X] := ∑ k ∈ range (K + 1), C (φ (p.coeff k)) * X ^ k with hq
  have hqdeg : q.natDegree ≤ K := by
    refine natDegree_sum_le_of_forall_le _ _ fun k hk => (natDegree_C_mul_X_pow_le _ _).trans ?_
    have := mem_range.mp hk
    omega
  have key : ∀ a : F, φ (p.eval (algebraMap F L a)) = q.eval a := by
    intro a
    rw [eval_eq_sum_range' (n := K + 1) (by omega), map_sum, hq, eval_finsetSum]
    refine sum_congr rfl fun k _ => ?_
    rw [eval_mul, eval_C, eval_pow, eval_X, ← map_pow, mul_comm (p.coeff k), ← Algebra.smul_def, map_smul,
      smul_eq_mul, mul_comm]
  refine mem_agreeOn.mpr ⟨fun x => q.eval (dom x), mem_rsCode.mpr ⟨q, hqdeg, fun x => rfl⟩, fun j hj => ?_⟩
  have hu : u j = φ (liftWord L u j) := by
    simp only [liftWord, Algebra.algebraMap_eq_smul_one, map_smul, hφ, smul_eq_mul, mul_one]
  rw [hu, hcS j hj, hc j, liftDom_apply]
  exact key (dom j)

/-- **The field split.** If the rows of `U` over `F`, read in `L`, are `e`-close to the RS code over `L` at the same
points, then `U` is `e`-close to the RS code over `F`. So a matrix that is `e`-far over `F` is `e`-far over `L`. -/
theorem close_of_close_lift (dom : ι ↪ F) {K e : ℕ} {R : Type} (U : R → ι → F)
    (h : Close (rsCode (liftDom L dom) K) e (fun i => liftWord L (U i))) : Close (rsCode dom K) e U := by
  obtain ⟨S, hS, hU⟩ := h
  exact ⟨S, hS, fun i => mem_agreeOn_rs_of_lift dom K S (U i) (hU i)⟩

/-- **δ/3 with the code's field split.** Rows over `F` (`F_p`), `e`-far from the RS code over `F` with
`3e + K + 1 ≤ N`; weights uniform over `L` (`F_p²`). The combination of the rows read in `L` is `e`-close to the RS
code over `L` with probability at most `(e + 1)/|L|`. -/
theorem rs_proximity_third_ext [Fintype L] [DecidableEq κ] (dom : ι ↪ F) {e K : ℕ}
    (hn : 3 * e + K + 1 ≤ Fintype.card ι) (U : κ → ι → F) (hfar : ¬ Close (rsCode dom K) e U) :
    (PMF.uniformOfFintype (κ → L)).toOuterMeasure
        {r | Close (rsCode (liftDom L dom) K) e (fun _ : Unit => comb (fun i => liftWord L (U i)) r)}
      ≤ ((e + 1 : ℕ) : ℝ≥0∞) / Fintype.card L :=
  rs_proximity_third (liftDom L dom) hn _ (fun h => hfar (close_of_close_lift dom U h))

/-- **δ/2 with the code's field split (task 3, as the code runs it).** Rows over `F` (`F_p`), `e`-far from the RS
code over `F` with `2e + K + 1 ≤ N`; weights uniform and independent over `L` (`F_p²`, `challenge_fp2_vec(rows)`).
The combination of the rows read in `L` is `e`-close to the RS code over `L` with probability at most `N/|L|`. -/
theorem rs_proximity_half_ext [Fintype L] [DecidableEq κ] (dom : ι ↪ F) {e K : ℕ}
    (hn : 2 * e + K + 1 ≤ Fintype.card ι) (U : κ → ι → F) (hfar : ¬ Close (rsCode dom K) e U) :
    (PMF.uniformOfFintype (κ → L)).toOuterMeasure
        {r | Close (rsCode (liftDom L dom) K) e (fun _ : Unit => comb (fun i => liftWord L (U i)) r)}
      ≤ (Fintype.card ι : ℝ≥0∞) / Fintype.card L :=
  rs_proximity_half (liftDom L dom) hn _ (fun h => hfar (close_of_close_lift dom U h))

end ZK60.Sound
