-- Copyright 2026 Anthropic PBC
-- SPDX-License-Identifier: Apache-2.0
-- Modified for ZK60Formal (IntelligenceRegulation), 2026-11-04: module paths renamed under
-- ZK60Formal.ThirdParty.FlashProve. Nothing else changed.
/-
Code/Lines/ResultantDegree.lean: the degree of a resultant of polynomials in two variables.

The files of the directory Code/Lines prove [BCIKS20, Theorem 4.1], in integers; Code/Half.lean
states it in the terms of this library.
Exactly: the directory proves correlated agreement over lines in the case 2e + k + 1 = n (n the
block length, k the bound on the degree of the code's polynomials), at an integer radius e
(`lines_tight`); Code/Half.lean relaxes the equality to ≤ (`caOn_rsCode`).

Source. E. Ben-Sasson, D. Carmon, Y. Ishai, S. Kopparty, S. Saraf, "Proximity Gaps for Reed–Solomon
Codes", Cryptology ePrint Archive 2020/654, version of July 3, 2021 (cited below as BCIKS20 or "the
source"). In Appendix D (proof of Lemma 4.3, p. 59) the source writes A and B as polynomials in X of
degrees a_X and b_X, takes the determinant R_X(Z) of their Sylvester matrix, and bounds its degree
in Z by a_X b_Z + a_Z b_X, where a_Z and b_Z bound the degrees of A and B in Z. Footnote 9 there
says how R_X differs from the resultant when a_X and b_X are not the exact degrees.

Mathlib's `Polynomial.resultant f g m n` is the determinant of the Sylvester matrix built as if f
had degree m and g had degree n. In this directory m and n are called the sizes. With m = a_X and
n = b_X it is the source's R_X up to sign (Mathlib's matrix is the transpose of the source's, with
the rows and columns in another order), and this file proves the bound for it.

The Lean library ArkLib (https://github.com/Verified-zkEVM/ArkLib) also proves a Lean statement of
its own of this degree bound, as a step of Lemma 4.3 of ePrint 2020/654, and the proof here takes
the same route as ArkLib's throughout: the same steps, and ten of the eleven library lemmas that it
calls by name.

The proof here first shows a lemma on any square matrix and holds over any commutative ring with
free degree bounds; ArkLib's pull request 878 describes a file of the same name with the same
generality, which by that description carries the argument of ArkLib's earlier proof over in general
form. lean/CREDITS.md has ArkLib's entry.
Against ArkLib's source at commit db7005f8: "ArkLib,
Data/Polynomial/ResultantDegree.lean: the same theorem (same generality and hypotheses) proved by
the same route. Neither the statement's generality nor the route comes from the paper, which bounds
a resultant in its own setting without this generality. ArkLib's file says that it generalizes an
earlier field-only ArkLib proof (the header's pull request 878)." and "ArkLib,
Data/CodingTheory/ProximityGap/BCIKS20/AffineLines/BWMatrix.lean: a near twin of our general lemma
on the degree of a determinant (same statement for a narrower index type, same proof). Nearly forced
over Mathlib."
-/
import Mathlib.RingTheory.Polynomial.Resultant.Basic
import Mathlib.Algebra.Polynomial.BigOperators

namespace Code.Lines

open Polynomial

variable {R : Type*} [CommRing R]

/-- If every entry in column `j` of a square matrix of polynomials has degree at most `d j`, then
the determinant has degree at most the sum of the `d j`. -/
theorem natDegree_det_le_sum {ι : Type*} [DecidableEq ι] [Fintype ι] (M : Matrix ι ι R[X])
    (d : ι → ℕ) (h : ∀ i j, (M i j).natDegree ≤ d j) : M.det.natDegree ≤ ∑ j, d j := by
  rw [Matrix.det_apply]
  refine natDegree_sum_le_of_forall_le _ _ fun σ _ => ?_
  refine (natDegree_smul_le _ _).trans ?_
  refine (natDegree_prod_le _ _).trans ?_
  exact Finset.sum_le_sum fun i _ => h _ _

/-- If every coefficient of `f` has degree at most `df` and every coefficient of `g` has degree at
most `dg`, then the resultant of `f` and `g` at the sizes `m` and `n` has degree at most `m * dg + n
* df`. -/
theorem natDegree_resultant_le (f g : R[X][X]) (m n df dg : ℕ)
    (hf : ∀ i, (f.coeff i).natDegree ≤ df) (hg : ∀ i, (g.coeff i).natDegree ≤ dg) :
    (resultant f g m n).natDegree ≤ m * dg + n * df := by
  have key : (sylvester f g m n).det.natDegree ≤
      ∑ j : Fin (m + n), Fin.addCases (motive := fun _ => ℕ) (fun _ => dg) (fun _ => df) j := by
    refine natDegree_det_le_sum _ _ fun i j => ?_
    induction j using Fin.addCases with
    | left j =>
      simp only [sylvester, Matrix.of_apply, Fin.addCases_left]
      split_ifs
      · exact hg _
      · simp
    | right j =>
      simp only [sylvester, Matrix.of_apply, Fin.addCases_right]
      split_ifs
      · exact hf _
      · simp
  rw [resultant]
  refine key.trans (le_of_eq ?_)
  rw [Fin.sum_univ_add]
  simp

end Code.Lines
