-- Copyright 2026 Anthropic PBC
-- SPDX-License-Identifier: Apache-2.0
-- Modified for ZK60Formal (IntelligenceRegulation), 2026-11-04: module paths renamed under
-- ZK60Formal.ThirdParty.FlashProve; `finset_sum_coeff` (deprecated) written `finsetSum_coeff`,
-- and dropped from one `simp` call where it is no longer used. Nothing else changed.
/-
Code/Lines/Interpolation.lean: the first step of the Berlekamp-Welch decoder over F(Z).

The files of the directory Code/Lines prove [BCIKS20, Theorem 4.1], in integers; Code/Half.lean
states it in the terms of this library.
Exactly: the directory proves correlated agreement over lines in the case 2e + k + 1 = n, at an
integer radius e (`lines_tight`); Code/Half.lean relaxes the equality to ≤ (`caOn_rsCode`).

The first step of the Berlekamp–Welch decoder for the word u₀ + Z u₁ over F(Z), for at most e errors
and a code of polynomials of degree at most k:
polynomials A and B in X and Z of bounded degrees with B(x, Z) = (u₀(x) + Z u₁(x)) A(x, Z) at every
point x of the domain.

Source. E. Ben-Sasson, D. Carmon, Y. Ishai, S. Kopparty, S. Saraf, "Proximity Gaps for Reed–Solomon
Codes", Cryptology ePrint Archive 2020/654, version of July 3, 2021 (cited below as BCIKS20 or "the
source"). This is Step 1 of the proof of Theorem 4.1 (Section 4.3.1, pp. 15–16).

Differences from the source. The source finds A and B over the field F(Z): it shows that certain
minors vanish and then bounds the degrees in Z by a homogeneous form of Cramer's rule. Here the
block length is exactly n = 2 e + k + 1 (Code/Half.lean reduces the theorem to this case), and A and
B come from a count of dimensions over F: the pairs (A, B) within the degree bounds form a space of
dimension n (e + 2) + 1, and the conditions are n (e + 2) linear equations. The count does not use
the set S of the source's theorem, which the source uses at this step. The source asks for a
non-zero solution (A, B).
Here the stronger A ≠ 0 is proved; Tight.lean uses it to count the points x with A(x, Z) = 0.

The Lean library ArkLib (https://github.com/Verified-zkEVM/ArkLib) also formalizes Theorem 4.1 and
Lemma 4.3 of ePrint 2020/654, the two results of which this directory proves our library's own Lean
statements.

Our statement of Lemma 4.3 has the lemma in part: the divisibility and the degree bounds of the
quotient, not its agreement counts.

lean/CREDITS.md has ArkLib's entry.
Against ArkLib's source at commit db7005f8: "ArkLib,
Data/CodingTheory/ProximityGap/BCIKS20/AffineLines/JointAgreement.lean: the main statement has the
same shape as ArkLib's statement of the same step (the same conclusions in the same order, with the
same strengthening to A nonzero); the proof takes another route (a count of dimensions, not the
Berlekamp-Welch kernel)."

Notation:
  `D : ι ↪ F`: an injective map from ι, a finite type (the positions: `GoodAt`,
    Code/Lines/Tight.lean), into the field: the domain;
  `F[X][X]`: `Polynomial (Polynomial F)`, the polynomials in the source's two variables X and Z: the
    outer variable is the source's X (the variable of the code) and the inner variable is the
    source's Z (the parameter of the line) (Code/Lines/Bivariate.lean's head);
  `atX x A` (Code/Lines/Bivariate.lean): a polynomial in Z: A(x, Z): the outer variable X is set to
    the constant `x`;
  `degZ A` (Code/Lines/Bivariate.lean): a natural number: the degree of A in the inner variable Z.
-/
import ZK60Formal.ThirdParty.FlashProve.Code.Lines.Bivariate
import Mathlib.LinearAlgebra.FiniteDimensional.Lemmas
import Mathlib.RingTheory.Polynomial.Basic
noncomputable section -- Lean tags what it cannot compile

namespace Code.Lines

open Polynomial

variable {F : Type*} [Field F] {ι : Type} [Fintype ι]

/-- The polynomial in X and Z whose coefficient of X^i Z^j is the entry `a i j` of a table of
coefficients. -/
def ofTable (m n : ℕ) : (Fin m → Fin n → F) →ₗ[F] F[X][X] where
  toFun a := ∑ i : Fin m, ∑ j : Fin n, monomial (i : ℕ) (monomial (j : ℕ) (a i j))
  map_add' a b := by simp [Finset.sum_add_distrib]
  map_smul' c a := by simp [Finset.smul_sum, smul_monomial]

/-- The definition of `ofTable`, written out. -/
theorem ofTable_apply {m n : ℕ} (a : Fin m → Fin n → F) :
    ofTable m n a = ∑ i : Fin m, ∑ j : Fin n, monomial (i : ℕ) (monomial (j : ℕ) (a i j)) := rfl

/-- The coefficients of the polynomial of a table are the entries of the table. -/
theorem coeff_ofTable {m n : ℕ} (a : Fin m → Fin n → F) (i : Fin m) (j : Fin n) :
    ((ofTable m n a).coeff i).coeff j = a i j := by
  simp [ofTable_apply, coeff_monomial, Fin.val_inj]

/-- If the polynomial of a table is zero, then the table is zero. -/
theorem ofTable_eq_zero {m n : ℕ} {a : Fin m → Fin n → F} (h : ofTable m n a = 0) : a = 0 := by
  funext i j
  rw [← coeff_ofTable a i j, h]
  simp

/-- The polynomial of a table with `m + 1` rows has degree at most `m` in X. -/
theorem natDegree_ofTable_le {m n : ℕ} (a : Fin (m + 1) → Fin n → F) :
    (ofTable (m + 1) n a).natDegree ≤ m := by
  rw [ofTable_apply]
  refine natDegree_sum_le_of_forall_le _ _ fun i _ => ?_
  refine natDegree_sum_le_of_forall_le _ _ fun j _ => ?_
  exact (natDegree_monomial_le _).trans (Nat.lt_succ_iff.mp i.isLt)

/-- The polynomial of a table with `n + 1` columns has degree at most `n` in Z. -/
theorem degZ_ofTable_le {m n : ℕ} (a : Fin m → Fin (n + 1) → F) :
    degZ (ofTable m (n + 1) a) ≤ n := by
  rw [degZ_le_iff]
  intro l
  rw [ofTable_apply, finsetSum_coeff]
  refine natDegree_sum_le_of_forall_le _ _ fun i _ => ?_
  rw [finsetSum_coeff]
  refine natDegree_sum_le_of_forall_le _ _ fun j _ => ?_
  rw [coeff_monomial]
  split_ifs
  · exact (natDegree_monomial_le _).trans (Nat.lt_succ_iff.mp j.isLt)
  · simp

/-- The linear conditions on a pair of tables with the polynomials A and B: for every point x of the
domain, the coefficients of Z^0, ..., Z^(e+1) in (u₀(x) + Z u₁(x)) A(x, Z) - B(x, Z). -/
def conditions (D : ι ↪ F) (e k : ℕ) (u₀ u₁ : ι → F) :
    ((Fin (e + 1) → Fin (e + 1) → F) × (Fin (e + k + 1) → Fin (e + 2) → F))
      →ₗ[F] (ι → Fin (e + 2) → F) where
  toFun v := fun x j =>
    ((C (u₀ x) + X * C (u₁ x)) * atX (D x) (ofTable _ _ v.1) - atX (D x) (ofTable _ _ v.2)).coeff j
  map_add' v w := by
    funext x j
    simp [mul_add]
    ring
  map_smul' c v := by
    funext x j
    simp [atX_apply, eval_smul, mul_sub]

omit [Fintype ι] in
/-- The definition of `conditions`, written out. -/
theorem conditions_apply (D : ι ↪ F) (e k : ℕ) (u₀ u₁ : ι → F)
    (v : (Fin (e + 1) → Fin (e + 1) → F) × (Fin (e + k + 1) → Fin (e + 2) → F))
    (x : ι) (j : Fin (e + 2)) :
    conditions D e k u₀ u₁ v x j =
      ((C (u₀ x) + X * C (u₁ x)) * atX (D x) (ofTable _ _ v.1) -
        atX (D x) (ofTable _ _ v.2)).coeff j := rfl

/-- If the block length is n = 2 e + k + 1, there are A ≠ 0 and B with deg_X A ≤ e, deg_Z A ≤ e,
deg_X B ≤ e + k, deg_Z B ≤ e + 1 and B(x, Z) = (u₀(x) + Z u₁(x)) A(x, Z) for every x in the
domain. -/
theorem exists_interpolant (D : ι ↪ F) {e k : ℕ}
    (hn : 2 * e + k + 1 = Fintype.card ι) (u₀ u₁ : ι → F) :
    ∃ A B : F[X][X], A ≠ 0 ∧ A.natDegree ≤ e ∧ degZ A ≤ e ∧ B.natDegree ≤ e + k ∧ degZ B ≤ e + 1 ∧
      ∀ x, atX (D x) B = (C (u₀ x) + X * C (u₁ x)) * atX (D x) A := by
  classical
  -- There are more unknowns than conditions, so some non-zero pair of tables meets all conditions.
  have hdim : Module.finrank F (ι → Fin (e + 2) → F) <
      Module.finrank F ((Fin (e + 1) → Fin (e + 1) → F) × (Fin (e + k + 1) → Fin (e + 2) → F)) := by
    simp only [Module.finrank_prod, Module.finrank_pi_fintype, Module.finrank_self,
      Finset.sum_const, Finset.card_univ, Fintype.card_fin, smul_eq_mul, mul_one, ← hn]
    nlinarith
  obtain ⟨v, hv, hv0⟩ := (Submodule.ne_bot_iff _).mp
    (LinearMap.ker_ne_bot_of_finrank_lt (f := conditions D e k u₀ u₁) hdim)
  rw [LinearMap.mem_ker] at hv
  obtain ⟨a, b⟩ := v
  have hAX := natDegree_ofTable_le a
  have hAZ := degZ_ofTable_le a
  have hBX := natDegree_ofTable_le b
  have hBZ := degZ_ofTable_le b
  -- Both sides of the identity have degree at most e + 1 in Z, so the conditions give the identity.
  have hid : ∀ x,
      atX (D x) (ofTable _ _ b) = (C (u₀ x) + X * C (u₁ x)) * atX (D x) (ofTable _ _ a) := by
    intro x
    have hw := natDegree_line_le (u₀ x) (u₁ x)
    have hl : ((C (u₀ x) + X * C (u₁ x)) * atX (D x) (ofTable _ _ a)).natDegree ≤ e + 1 := by
      have := natDegree_atX_le (D x) (ofTable _ _ a)
      refine natDegree_mul_le.trans ?_
      omega
    have hr : (atX (D x) (ofTable _ _ b)).natDegree ≤ e + 1 := (natDegree_atX_le _ _).trans hBZ
    symm
    rw [← sub_eq_zero]
    ext j
    by_cases hj : j < e + 2
    · have := congrFun (congrFun hv x) ⟨j, hj⟩
      rw [conditions_apply] at this
      simpa using this
    · rw [coeff_zero]
      refine coeff_eq_zero_of_natDegree_lt (lt_of_le_of_lt (natDegree_sub_le_of_le hl hr) ?_)
      omega
  refine ⟨ofTable _ _ a, ofTable _ _ b, ?_, hAX, hAZ, hBX, hBZ, hid⟩
  -- If A = 0, then B(x, Z) = 0 at all n points x, and n exceeds the degree of B in X, so B = 0 too.
  intro hA
  apply hv0
  have hB : ofTable _ _ b = 0 := by
    by_contra hB
    have hcard := card_filter_atX_eq_zero_le hB (Finset.univ.map D)
    rw [Finset.filter_true_of_mem, Finset.card_map, Finset.card_univ] at hcard
    · omega
    · intro y hy
      obtain ⟨x, -, rfl⟩ := Finset.mem_map.mp hy
      rw [hid x, hA]
      simp
  rw [ofTable_eq_zero hA, ofTable_eq_zero hB]
  rfl

end Code.Lines
