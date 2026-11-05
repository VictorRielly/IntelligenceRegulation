-- Copyright 2026 Anthropic PBC
-- SPDX-License-Identifier: Apache-2.0
-- Modified for ZK60Formal (IntelligenceRegulation), 2026-11-04: module paths renamed under
-- ZK60Formal.ThirdParty.FlashProve; the import of Code.RS and the theorem
-- `mca_monomialImage_rsCode` (which needs Code/RS.lean's `monomialImage`) removed, since neither
-- is ported. Nothing else changed.
/-
Code/Half.lean: mutual correlated agreement of Reed-Solomon codes up to half the distance.

`rsCode D K` is the code of the polynomials of degree at most K over a field L, evaluated at n
distinct points D. The three theorems on agreement assume 2 e + K + 1 ≤ n and a finite L.

  `caOn_rsCode`   [BCIKS20, Theorem 4.1], in integers: correlated agreement on lines for two words
      at the radius e, with at most n exceptional values. The directory Code/Lines holds the proof
      for the block length n = 2 e + K + 1, and this file removes that condition.
  `mca_rsCode`   Mutual correlated agreement on lines at the radius e with at most n bad values, for
      any number of interleaved rows (`MCA`, Code/Agree.lean). The step from two words to this form
      is in Code/Mutual.lean.
  `mca_monomialImage_rsCode`   The same for a generalised Reed-Solomon code (non-zero multipliers,
      positions renamed). With `MCAOn.subcode` this is the route for circle codes
      (Code/Circle/MCA.lean). [ZK60Formal: not ported.]

Source: E. Ben-Sasson, D. Carmon, Y. Ishai, S. Kopparty, S. Saraf, "Proximity Gaps for Reed–Solomon
Codes", Cryptology ePrint Archive 2020/654, version of July 3, 2021, Theorem 4.1 (correlated
agreement over lines, unique-decoding radius). There RS[F_q, D, k] is the code of the polynomials of
degree at most k, the rate is ρ = (k + 1) / n, and the theorem is stated for a real δ ≤ (1 - ρ) / 2.
Here the radius is the integer e = ⌊δ n⌋, so that the condition reads 2 e + K + 1 ≤ n.

The evaluation domain is given as an injective family of points D : ι ↪ L, following the Lean
library ArkLib (https://github.com/Verified-zkEVM/ArkLib), so that the block length is n = |ι|; any
subset of L in any order is a domain. ArkLib's Reed–Solomon code takes a strict bound on the degree,
while "rsCode D K" keeps the source's bound, degree at most K. ArkLib also formalizes Theorem 4.1 of
the source. lean/CREDITS.md has ArkLib's entry.
Of the ten files that hold the proofs of Theorem 4.1 and of a part of Lemma 4.3 of the source (this
one and the nine of Code/Lines), one takes the same route of proof as ArkLib throughout
(ResultantDegree.lean), one has the frame of ArkLib's proof from start to end (RelPrimeCase.lean),
one more takes the same route in places (Bivariate.lean), and the statement of one lemma
(coeff_swap, Bivariate.lean) is the same text, but for one qualified name, as a line in an older,
undated extract of ArkLib's source [not in ArkLib at db7005f8; where it is: the header of
Code/Lines/Bivariate.lean]; more may be shared with ArkLib than this lists. ArkLib is not a
dependency: no file of this library imports it.
-/
import ZK60Formal.ThirdParty.FlashProve.Code.Lines.Tight
import ZK60Formal.ThirdParty.FlashProve.Code.Mutual

namespace Code

open Finset Prob Polynomial

variable {L ι : Type} [Field L] [Fintype ι]

/-! ## The code as a subspace -/

omit [Fintype ι] in
/-- The Reed–Solomon code of the polynomials of degree at most K, evaluated at the points D x. -/
def rsCode (D : ι ↪ L) (K : ℕ) : Submodule L (ι → L) where
  carrier := {w | ∃ p : L[X], p.natDegree ≤ K ∧ ∀ x, w x = p.eval (D x)}
  add_mem' := by
    rintro v w ⟨p, hp, hv⟩ ⟨q, hq, hw⟩
    exact ⟨p + q,
      (natDegree_add_le _ _).trans (max_le hp hq),
      fun x => by rw [Pi.add_apply, hv, hw, eval_add]⟩
  zero_mem' := ⟨0, by simp, fun x => by simp⟩
  smul_mem' := by
    rintro c v ⟨p, hp, hv⟩
    exact ⟨C c * p,
      (natDegree_C_mul_le _ _).trans hp,
      fun x => by rw [Pi.smul_apply, hv, eval_mul, eval_C, smul_eq_mul]⟩

omit [Fintype ι] in
theorem mem_rsCode {D : ι ↪ L} {K : ℕ} {w : ι → L} :
    w ∈ rsCode D K ↔ ∃ p : L[X], p.natDegree ≤ K ∧ ∀ x, w x = p.eval (D x) := Iff.rfl

omit [Fintype ι] in
/-- A larger degree bound gives a larger code. -/
theorem rsCode_mono (D : ι ↪ L) {K K' : ℕ} (h : K ≤ K') : rsCode D K ≤ rsCode D K' :=
  fun _ ⟨p, hp, hw⟩ => ⟨p, hp.trans h, hw⟩

/-- A non-zero word of the code has at least n - K non-zero symbols. -/
theorem minDist_rsCode (D : ι ↪ L) (K : ℕ) : MinDist (rsCode D K) (Fintype.card ι - K) := by
  classical
  rintro w ⟨p, hp, hw⟩ hne
  rw [cnt_eq_card_filter]
  have hsplit := card_filter_add_card_filter_not (s := (univ : Finset ι)) (fun x => w x ≠ 0)
  rw [card_univ] at hsplit
  have hZ : (univ.filter fun x => ¬ w x ≠ 0).card ≤ K := by
    by_contra hlt
    apply hne
    have hp0 : p = 0 := by
      apply eq_zero_of_natDegree_lt_card_of_eval_eq_zero' p ((univ.filter fun x => ¬ w x ≠ 0).map D)
      · intro y hy
        obtain ⟨x, hx, rfl⟩ := mem_map.mp hy
        rw [← hw x]
        exact not_not.mp (mem_filter.mp hx).2
      · rw [card_map]
        omega
    funext x
    rw [hw x, hp0]
    simp
  omega

/-! ## [BCIKS20, Theorem 4.1], in integers -/

/-- [BCIKS20, Theorem 4.1] when the block length is exactly n = 2 e + K + 1. -/
theorem caOn_rsCode_tight [Finite L] (D : ι ↪ L) {e K : ℕ} (hn : 2 * e + K + 1 = Fintype.card ι) :
    CAOn Unit (rsCode D K) e (Fintype.card ι) := by
  intro f₀ f₁ hfar
  refine cnt_le_of_forall_finset fun Y hY => ?_
  by_contra hcon
  apply hfar
  obtain ⟨p₀, p₁, h₀, h₁, W, hW, hag⟩ := Lines.lines_tight D hn (f₀ ()) (f₁ ()) Y (fun z hz => by
    obtain ⟨S, hS, hl⟩ := hY z hz
    obtain ⟨u, ⟨p, hp, hu⟩, hfu⟩ := mem_agreeOn.mp (hl ())
    exact ⟨p, hp, S, hS, fun x hx => (hfu x hx).trans (hu x)⟩) (by omega)
  refine close_of_wrong (g₀ := fun _ x => p₀.eval (D x)) (g₁ := fun _ x => p₁.eval (D x))
    (fun _ => ⟨p₀, h₀, fun _ => rfl⟩) (fun _ => ⟨p₁, h₁, fun _ => rfl⟩) (W := W) (fun j hj => ?_) hW
  by_contra hjW
  exact hj fun _ => hag j hjW

/-- [BCIKS20, Theorem 4.1], in integers. Let L be a finite field, take the code of all polynomials
of degree at most K evaluated at n distinct points of L, and let 2 e ≤ n - K - 1. Let o₀, o₁ be two
words. If o₀ + z o₁ agrees with a codeword outside at most e positions for more than n values z,
then there are codewords c₀, c₁ and a set of at least n - e positions on which o₀ = c₀ and o₁ = c₁.
In the terms of this library: n bounds correlated agreement for single words. -/
theorem caOn_rsCode [Finite L] (D : ι ↪ L) {e K : ℕ} (hn : 2 * e + K + 1 ≤ Fintype.card ι) :
    CAOn Unit (rsCode D K) e (Fintype.card ι) := by
  have hK : 2 * e + (Fintype.card ι - 2 * e - 1) + 1 = Fintype.card ι := by omega
  exact (caOn_rsCode_tight D hK).subcode
    (minDist_rsCode D _) (by omega) (rsCode_mono D (by omega)) (by omega)

/-! ## The mutual form, for any number of rows -/

/-- If 2 e + K + 1 ≤ n, then the code of the polynomials of degree at most K has mutual correlated
agreement on lines at the radius e with at most n bad values, for any number of interleaved rows. -/
theorem mca_rsCode [Finite L] (D : ι ↪ L) {e K : ℕ} (hn : 2 * e + K + 1 ≤ Fintype.card ι) :
    MCA (rsCode D K) e (Fintype.card ι) :=
  fun R _ => (mcaOn_iff_caOn_of_le (minDist_rsCode D K) (by omega) (by omega)).mpr
    ((caOn_rsCode D hn).of_one_row (minDist_rsCode D K) (by omega) (by omega) R)

end Code
