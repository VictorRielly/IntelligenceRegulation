-- Copyright 2026 Anthropic PBC
-- SPDX-License-Identifier: Apache-2.0
-- Modified for ZK60Formal (IntelligenceRegulation), 2026-11-04: module paths renamed under
-- ZK60Formal.ThirdParty.FlashProve. Nothing else changed.
/-
Code/Lines/Multiplicity.lean: the multiplicity of a zero of the resultant.

The files of the directory Code/Lines prove [BCIKS20, Theorem 4.1], in integers; Code/Half.lean
states it in the terms of this library.
Exactly: the directory proves correlated agreement over lines in the case 2e + k + 1 = n (n the
block length, k the bound on the degree of the code's polynomials), at an integer radius e
(`lines_tight`); Code/Half.lean relaxes the equality to ≤ (`caOn_rsCode`).

The determinant R_X of the Sylvester matrix of A and B with respect to X vanishes to high order at
every z for which A(X, z) divides B(X, z) with a quotient of small degree. In Lean, R_X is, up to
sign, Mathlib's `resultant` at the sizes a_X and b_X, the source's bounds on the degrees of A and B
in X (see ResultantDegree.lean).

Source. E. Ben-Sasson, D. Carmon, Y. Ishai, S. Kopparty, S. Saraf, "Proximity Gaps for Reed–Solomon
Codes", Cryptology ePrint Archive 2020/654, version of July 3, 2021 (cited below as BCIKS20 or "the
source"). This is the step of Appendix D (proof of Lemma 4.3, p. 60) that shows that R_X has a root
of multiplicity at least a_X at each such z.

Difference from the source. Both proofs start from the same fact. Because B(X, z) = p · A(X, z) with
deg p ≤ d_X = b_X - a_X, the rows of the source's Sylvester matrix that hold the coefficients of B
are, at Z = z, linear combinations of the rows that hold the coefficients of A, and both need the
bound on deg p for this. The source concludes that the matrix has rank at most b_X at z, and from
the rank that R_X and its first a_X - 1 derivatives vanish there, and refers to [Spi95, Proposition
4.2.17]. The proof here makes the same combinations before Z is set to z: it subtracts the multiple
p · A from B, which does not change the determinant, and then takes the factor Z - z out of the a_X
columns that hold the coefficients of B (Mathlib's matrix is the transpose of the source's, with the
rows and columns in another order, so the source's rows are columns here). So it uses neither ranks
nor derivatives, and it states the result as divisibility by (Z - z)^a_X. The second theorem is the
count in the source's next step: a non-zero polynomial with roots of multiplicity a_X at n_Z points,
where n_Z is the source's number of such z, has degree at least a_X n_Z.

The Lean library ArkLib (https://github.com/Verified-zkEVM/ArkLib) also formalizes Theorem 4.1 and
Lemma 4.3 of ePrint 2020/654, the two results of which this directory proves our library's own Lean
statements.

Our statement of Lemma 4.3 has the lemma in part: the divisibility and the degree bounds of the
quotient, not its agreement counts.

lean/CREDITS.md has ArkLib's entry.

Notation:
  `F[X][X]`: `Polynomial (Polynomial F)`, the polynomials in the source's two variables X and Z: the
    outer variable is the source's X (the variable of the code) and the inner variable is the
    source's Z (the parameter of the line) (Code/Lines/Bivariate.lean's head);
  `atZ z A` (Code/Lines/Bivariate.lean): a polynomial in X: A(X, z): the inner variable Z is set to
    `z` in every coefficient;
  `X - C z`: in a term of type `F[X]` that denotes a polynomial in Z, Lean's `X` is the source's Z
    (Code/Lines/Bivariate.lean's head).
-/
import ZK60Formal.ThirdParty.FlashProve.Code.Lines.Bivariate
import Mathlib.RingTheory.Polynomial.Resultant.Basic

namespace Code.Lines

open Polynomial

variable {F : Type*} [Field F]

/-- If deg_X A ≤ m and B(X, z) = p · A(X, z) with deg p + m ≤ n, then (Z - z)^m divides the
resultant of A and B at the sizes m and n. -/
theorem pow_dvd_resultant {A B : F[X][X]} {m n : ℕ} {z : F} {p : F[X]} (hA : A.natDegree ≤ m)
    (hp : p.natDegree + m ≤ n) (h : atZ z B = p * atZ z A) :
    (X - C z) ^ m ∣ resultant A B m n := by
  have h0 : atZ z (B - A * p.map C) = 0 := by
    rw [map_sub, map_mul, atZ_map_C, h, mul_comm, sub_self]
  obtain ⟨Q, hQ⟩ := exists_eq_C_mul_of_atZ_eq_zero h0
  have hB : B = C (X - C z) * Q + A * p.map C := by
    rw [← hQ, sub_add_cancel]
  have hp' : (p.map C).natDegree + m ≤ n := (Nat.add_le_add_right natDegree_map_le m).trans hp
  rw [hB, resultant_add_mul_right A (C (X - C z) * Q) (p.map C) m n hp' hA, resultant_C_mul_right]
  exact dvd_mul_right _ _

/-- Let deg_X A ≤ m, and for every z in Sz let B(X, z) = p · A(X, z) for some p with deg p + m ≤ n.
If the resultant of A and B at the sizes m and n is not zero, its degree is at least m · |Sz|. -/
theorem mul_card_le_natDegree_resultant {A B : F[X][X]} {m n : ℕ} (Sz : Finset F)
    (hA : A.natDegree ≤ m) (h : ∀ z ∈ Sz, ∃ p : F[X], p.natDegree + m ≤ n ∧ atZ z B = p * atZ z A)
    (hR : resultant A B m n ≠ 0) :
    m * Sz.card ≤ (resultant A B m n).natDegree := by
  have hdvd : ∏ z ∈ Sz, (X - C z) ^ m ∣ resultant A B m n := by
    refine Finset.prod_dvd_of_coprime (fun a _ b _ hab => ?_) fun z hz => ?_
    · exact (pairwise_coprime_X_sub_C Function.injective_id hab).pow
    · obtain ⟨p, hp, hz'⟩ := h z hz
      exact pow_dvd_resultant hA hp hz'
  have hdeg : (∏ z ∈ Sz, (X - C z) ^ m).natDegree = m * Sz.card := by
    rw [natDegree_prod_of_monic _ _ fun z _ => (monic_X_sub_C z).pow m]
    simp [mul_comm]
  rw [← hdeg]
  exact natDegree_le_of_dvd hdvd hR

end Code.Lines
