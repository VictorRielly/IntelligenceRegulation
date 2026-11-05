-- Copyright 2026 Anthropic PBC
-- SPDX-License-Identifier: Apache-2.0
-- Modified for ZK60Formal (IntelligenceRegulation), 2026-11-04: module paths renamed under
-- ZK60Formal.ThirdParty.FlashProve. Nothing else changed.
/-
Code/Lines/RelPrime.lean: the resultant of two polynomials without a common factor is not zero.
(not all hypotheses are named here: see `resultant_ne_zero_of_isRelPrime`)

The files of the directory Code/Lines prove [BCIKS20, Theorem 4.1], in integers; Code/Half.lean
states it in the terms of this library.
Exactly: the directory proves correlated agreement over lines in the case 2e + k + 1 = n (n the
block length, k the bound on the degree of the code's polynomials), at an integer radius e
(`lines_tight`); Code/Half.lean relaxes the equality to ≤ (`caOn_rsCode`).

Two relatively prime polynomials A ≠ 0 and B over a unique factorization domain have a non-zero
resultant at the exact degree of A and any second size that is at least deg B.

Source. E. Ben-Sasson, D. Carmon, Y. Ishai, S. Kopparty, S. Saraf, "Proximity Gaps for Reed–Solomon
Codes", Cryptology ePrint Archive 2020/654, version of July 3, 2021 (cited below as BCIKS20 or "the
source"). Appendix D (proof of Lemma 4.3, p. 59, with footnote 9) uses this fact for A and B in
F[Z][X] without proof.

The proof here takes a non-zero vector in the kernel of the Sylvester matrix, which gives U and V of
small degree with A U + B V = 0, and concludes from unique factorization that A divides V. The sizes
of a resultant are explained in ResultantDegree.lean.

The Lean library ArkLib (https://github.com/Verified-zkEVM/ArkLib) also formalizes Theorem 4.1 and
Lemma 4.3 of ePrint 2020/654, the two results of which this directory proves our library's own Lean
statements.

Our statement of Lemma 4.3 has the lemma in part: the divisibility and the degree bounds of the
quotient, not its agreement counts.

lean/CREDITS.md has ArkLib's entry.
-/
import Mathlib.RingTheory.Polynomial.Resultant.Basic
import Mathlib.RingTheory.Polynomial.UniqueFactorization
import Mathlib.LinearAlgebra.Matrix.ToLinearEquiv

namespace Code.Lines

open Polynomial

variable {R : Type*} [CommRing R] [IsDomain R] [UniqueFactorizationMonoid R]

/-- Over a unique factorization domain: if A ≠ 0 and every common divisor of A and B is a unit, then
the resultant of A and B, at the exact degree of A and any size n ≥ deg B, is not zero. -/
theorem resultant_ne_zero_of_isRelPrime
    {A B : R[X]} (hA : A ≠ 0) (h : IsRelPrime A B) {n : ℕ} (hB : B.natDegree ≤ n) :
    resultant A B A.natDegree n ≠ 0 := by
  intro h0
  -- A non-zero vector in the kernel of the Sylvester matrix.
  obtain ⟨v, hv, hMv⟩ :=
    Matrix.exists_mulVec_eq_zero_iff.mpr (show (sylvester A B A.natDegree n).det = 0 from h0)
  let b₁ := ((degreeLT.basis R A.natDegree).prod (degreeLT.basis R n)).reindex finSumFinEquiv
  let b₂ := degreeLT.basis R (A.natDegree + n)
  let pq := b₁.equivFun.symm v
  have hpq : pq ≠ 0 := by
    intro h1
    exact hv ((LinearEquiv.map_eq_zero_iff _).mp h1)
  have hker : sylvesterMap A B le_rfl hB pq = 0 := by
    apply b₂.repr.injective
    have := LinearMap.toMatrix_mulVec_repr b₁ b₂ (sylvesterMap A B le_rfl hB) pq
    rw [toMatrix_sylvesterMap'] at this
    have hrepr : (b₁.repr pq : Fin (A.natDegree + n) → R) = v := by
      rw [← Module.Basis.equivFun_apply]
      exact b₁.equivFun.apply_symm_apply v
    rw [hrepr, hMv] at this
    ext i
    simpa using (congrFun this i).symm
  -- The kernel vector is a pair (V, U) with A * U + B * V = 0.
  obtain ⟨⟨V, hV⟩, ⟨U, hU⟩⟩ := pq
  have heq : A * U + B * V = 0 := by
    simpa using congrArg Subtype.val hker
  have hV' : V.degree < A.natDegree := Polynomial.mem_degreeLT.mp hV
  -- A divides B * V, so A divides V, so V = 0.
  have hdvd : A ∣ B * V := ⟨-U, by linear_combination heq⟩
  have hAV : A ∣ V := h.dvd_of_dvd_mul_left hdvd
  have hV0 : V = 0 := by
    by_contra hne
    have h1 := Polynomial.degree_le_of_dvd hAV hne
    rw [Polynomial.degree_eq_natDegree hA] at h1
    exact absurd hV' (not_lt.mpr h1)
  have hU0 : U = 0 := by
    rw [hV0, mul_zero, add_zero] at heq
    exact (mul_eq_zero.mp heq).resolve_left hA
  apply hpq
  subst hV0 hU0
  rfl

end Code.Lines
