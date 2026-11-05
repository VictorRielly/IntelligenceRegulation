-- Copyright 2026 Anthropic PBC
-- SPDX-License-Identifier: Apache-2.0
-- Modified for ZK60Formal (IntelligenceRegulation), 2026-11-04: module paths renamed under
-- ZK60Formal.ThirdParty.FlashProve; in `card_filter_atZ_eq_zero_le`, `unfold degZ` added before the
-- final `simpa` (Lean 4.34.1's `simpa` no longer closes the goal up to unfolding). Nothing else
-- changed.
/-
Code/Lines/Bivariate.lean: notation and elementary facts on polynomials in two variables.

The files of the directory Code/Lines prove the case 2e + k + 1 = n of [BCIKS20, Theorem 4.1]
(`lines_tight`), in integers; Code/Half.lean relaxes the equality to ≤ (`caOn_rsCode`) and states it
in the terms of this library.

Polynomials in two variables over a field, as far as the proof of the source's Theorem 4.1 needs
them.

Source. E. Ben-Sasson, D. Carmon, Y. Ishai, S. Kopparty, S. Saraf, "Proximity Gaps for Reed–Solomon
Codes", Cryptology ePrint Archive 2020/654, version of July 3, 2021 (cited below as BCIKS20 or "the
source"). This file formalizes no numbered statement of the source. It fixes the notation for the
files in this directory and proves the elementary facts that the source uses without proof in
Section 4 and Appendix D.

Notation. A polynomial in the source's two variables X and Z is an element of `F[X][X]`, that is
`Polynomial (Polynomial F)`. The outer variable is the source's X (the variable of the code) and the
inner variable is the source's Z (the parameter of the line). For `A : F[X][X]`:
* `atX x A` is A(x, Z), a polynomial in Z;
* `atZ z A` is A(X, z), a polynomial in X;
* `A.natDegree` is the degree of A in X, written deg_X A in the comments, and `degZ A` is the degree
  of A in Z, written deg_Z A. Both are natural numbers and are 0 for the zero polynomial.
Lean writes both variables `X`. In a term of type `F[X]` that denotes a polynomial in Z, such as `C
(u₀ x) + X * C (u₁ x)` or `X - C z`, Lean's `X` is the source's Z. Mathlib's
`Polynomial.Bivariate.swap` exchanges the two variables.

The Lean library ArkLib (https://github.com/Verified-zkEVM/ArkLib) also formalizes Lemma 4.3 of
ePrint 2020/654 and states several of the facts in this file; the proofs here take the same route as
ArkLib's in places, namely for the coefficients after the exchange of the variables and for the
number of zeros in one variable.

The statement of the lemma on the coefficients after the exchange (`coeff_swap`) is the same text,
but for one qualified name, as a line in an older, undated extract of ArkLib's source [where that
line is, by a comparison with an older, undated piece of ArkLib's source that the project holds:
"ArkLib, an earlier form of Data/CodingTheory/PolishchukSpielman/Degrees.lean,
inside the proof of ps_degree_x_swap: the same statement on coefficients after swapping, proved by
the same double induction. Commit and date unknown; the line is not in ArkLib at db7005f8 […]."];
the definition that sets the inner variable to a value is the same choice of an auxiliary notion as
a definition of ArkLib's; the definition of the degree in the inner variable differs.
At db7005f8 ArkLib takes its basic facts on polynomials in two variables from CompPoly, a separate
library of the same group; this file was not compared with CompPoly.
lean/CREDITS.md has ArkLib's entry.
-/
import Mathlib.Algebra.Polynomial.Bivariate
import Mathlib.Algebra.Polynomial.Roots
import Mathlib.Algebra.Polynomial.RingDivision
noncomputable section -- Lean tags what it cannot compile

namespace Code.Lines

open Polynomial Polynomial.Bivariate

variable {F : Type*} [Field F]

/-- `atX x A` is A(x, Z): the outer variable X is set to the constant `x`. -/
def atX (x : F) : F[X][X] →+* F[X] := evalRingHom (C x)

/-- `atZ z A` is A(X, z): the inner variable Z is set to `z` in every coefficient. -/
def atZ (z : F) : F[X][X] →+* F[X] := mapRingHom (evalRingHom z)

/-- The degree of A in the inner variable Z. -/
def degZ (A : F[X][X]) : ℕ := (swap A).natDegree

/-- The definition of `atX`, written out. -/
theorem atX_apply (x : F) (A : F[X][X]) : atX x A = A.eval (C x) := rfl

/-- The definition of `atZ`, written out. -/
theorem atZ_apply (z : F) (A : F[X][X]) : atZ z A = A.map (evalRingHom z) := rfl

/-- The polynomial a + Z b has degree at most 1. -/
theorem natDegree_line_le (a b : F) : (C a + X * C b : F[X]).natDegree ≤ 1 := by
  compute_degree

/-- The coefficient of X^j Z^i in `swap p` is the coefficient of X^i Z^j in `p`. -/
theorem coeff_swap (p : F[X][X]) (i j : ℕ) : ((swap p).coeff j).coeff i = (p.coeff i).coeff j := by
  induction p using Polynomial.induction_on' with
  | add p q hp hq => simp only [map_add, coeff_add, hp, hq]
  | monomial n f =>
    induction f using Polynomial.induction_on' with
    | add f g hf hg => simp only [map_add, coeff_add, hf, hg]
    | monomial m a =>
      rw [swap_monomial_monomial]
      by_cases hm : m = j <;> by_cases hn : n = i <;> simp [coeff_monomial, hm, hn]

/-- After the two variables are exchanged, the degree in Z is the former degree in X. -/
theorem degZ_swap (p : F[X][X]) : degZ (swap p) = p.natDegree := by
  unfold degZ
  rw [swap_swap_apply]

/-- The degree in Z is at most `d` if and only if every coefficient, a polynomial in Z, has degree
at most `d`. -/
theorem degZ_le_iff (p : F[X][X]) (d : ℕ) : degZ p ≤ d ↔ ∀ i, (p.coeff i).natDegree ≤ d := by
  unfold degZ
  simp only [natDegree_le_iff_coeff_eq_zero]
  constructor
  · intro h i N hN
    rw [← coeff_swap, h N hN, coeff_zero]
  · intro h N hN
    ext i
    rw [coeff_swap, h i N hN, coeff_zero]

/-- Setting X to x after exchanging the variables is the same as setting Z to x. -/
theorem atX_swap (x : F) (p : F[X][X]) : atX x (swap p) = atZ x p := by
  induction p using Polynomial.induction_on' with
  | add p q hp hq => simp only [map_add, hp, hq]
  | monomial n f =>
    rw [swap_monomial, map_mul, atX_apply, atX_apply, atZ_apply, eval_map, eval₂_at_apply, eval_C,
      map_monomial, coe_evalRingHom, C_mul_X_pow_eq_monomial]

/-- Setting Z to z after exchanging the variables is the same as setting X to z. -/
theorem atZ_swap (z : F) (p : F[X][X]) : atZ z (swap p) = atX z p := by
  rw [← atX_swap, swap_swap_apply]

/-- The coefficient of X^i in p(X, z) is the coefficient of X^i in p, a polynomial in Z, evaluated
at z. -/
theorem coeff_atZ (z : F) (p : F[X][X]) (i : ℕ) : (atZ z p).coeff i = (p.coeff i).eval z := by
  rw [atZ_apply, coeff_map, coe_evalRingHom]

/-- A polynomial in X alone, seen as a polynomial in two variables, does not change when Z is set to
`z`. -/
theorem atZ_map_C (z : F) (p : F[X]) : atZ z (p.map C) = p := by
  ext i
  rw [coeff_atZ, coeff_map, eval_C]

/-- A(x, Z) at Z = z equals A(X, z) at X = x. -/
theorem eval_atX (x z : F) (p : F[X][X]) : (atX x p).eval z = (atZ z p).eval x := by
  rw [atX_apply, atZ_apply, map_evalRingHom_eval]

/-- p(X, z) has degree at most deg_X p. -/
theorem natDegree_atZ_le (z : F) (p : F[X][X]) : (atZ z p).natDegree ≤ p.natDegree := by
  rw [atZ_apply]
  exact natDegree_map_le

/-- p(x, Z) has degree at most deg_Z p. -/
theorem natDegree_atX_le (x : F) (p : F[X][X]) : (atX x p).natDegree ≤ degZ p := by
  rw [← atZ_swap]
  exact natDegree_atZ_le x (swap p)

/-- The degree in Z of a product of two non-zero polynomials is the sum of their degrees in Z. -/
theorem degZ_mul {p q : F[X][X]} (hp : p ≠ 0) (hq : q ≠ 0) : degZ (p * q) = degZ p + degZ q := by
  unfold degZ
  rw [map_mul, natDegree_mul ((map_ne_zero_iff _ swap.injective).mpr hp)
    ((map_ne_zero_iff _ swap.injective).mpr hq)]

/-- If p(X, z) = 0, then Z - z divides p. -/
theorem exists_eq_C_mul_of_atZ_eq_zero {z : F} {p : F[X][X]} (h : atZ z p = 0) :
    ∃ q : F[X][X], p = C (X - C z) * q := by
  have hdvd : C (X - C z) ∣ p := by
    rw [C_dvd_iff_dvd_coeff]
    intro i
    rw [dvd_iff_isRoot, IsRoot.def, ← coeff_atZ, h, coeff_zero]
  exact hdvd

open Classical in
/-- A non-zero G has G(x, Z) = 0 for at most deg_X G values of x. -/
theorem card_filter_atX_eq_zero_le {G : F[X][X]} (hG : G ≠ 0) (S : Finset F) :
    (S.filter fun x => atX x G = 0).card ≤ G.natDegree := by
  have hsub : (S.filter fun x => atX x G = 0).image (C : F → F[X]) ⊆ G.roots.toFinset := by
    intro y hy
    obtain ⟨x, hx, rfl⟩ := Finset.mem_image.mp hy
    rw [Multiset.mem_toFinset, mem_roots hG]
    exact (Finset.mem_filter.mp hx).2
  calc (S.filter fun x => atX x G = 0).card
      = ((S.filter fun x => atX x G = 0).image (C : F → F[X])).card :=
        (Finset.card_image_of_injective _ C_injective).symm
    _ ≤ G.roots.toFinset.card := Finset.card_le_card hsub
    _ ≤ Multiset.card G.roots := Multiset.toFinset_card_le _
    _ ≤ G.natDegree := card_roots' G

open Classical in
/-- A non-zero G has G(X, z) = 0 for at most deg_Z G values of z. -/
theorem card_filter_atZ_eq_zero_le {G : F[X][X]} (hG : G ≠ 0) (S : Finset F) :
    (S.filter fun z => atZ z G = 0).card ≤ degZ G := by
  have h := card_filter_atX_eq_zero_le ((map_ne_zero_iff _ swap.injective).mpr hG) S
  unfold degZ
  simpa only [atX_swap] using h

/-- If B(X, z) has degree at most d for more than deg_Z B values of z, then B has degree at most d
in X. -/
theorem natDegree_le_of_atZ {B : F[X][X]} {d : ℕ} (S : Finset F) (hS : degZ B < S.card)
    (h : ∀ z ∈ S, (atZ z B).natDegree ≤ d) : B.natDegree ≤ d := by
  rw [natDegree_le_iff_coeff_eq_zero]
  intro N hN
  refine eq_zero_of_natDegree_lt_card_of_eval_eq_zero' (B.coeff N) S (fun z hz => ?_)
    (lt_of_le_of_lt ((degZ_le_iff B (degZ B)).mp le_rfl N) hS)
  rw [← coeff_atZ]
  exact coeff_eq_zero_of_natDegree_lt (lt_of_le_of_lt (h z hz) hN)

/-- If B(x, Z) has degree at most d for more than deg_X B values of x, then B has degree at most d
in Z. -/
theorem degZ_le_of_atX {B : F[X][X]} {d : ℕ} (S : Finset F) (hS : B.natDegree < S.card)
    (h : ∀ x ∈ S, (atX x B).natDegree ≤ d) : degZ B ≤ d := by
  refine natDegree_le_of_atZ (B := swap B) S ?_ (fun x hx => ?_)
  · rw [degZ_swap]
    exact hS
  · rw [atZ_swap]
    exact h x hx

/-- A non-zero polynomial of degree 0 in both variables is a unit. -/
theorem isUnit_of_degrees_eq_zero
    {A : F[X][X]} (hA : A ≠ 0) (hX : A.natDegree = 0) (hZ : degZ A = 0) : IsUnit A := by
  have h1 : A = C (A.coeff 0) := eq_C_of_natDegree_eq_zero hX
  have h2 : A.coeff 0 = C ((A.coeff 0).coeff 0) :=
    eq_C_of_natDegree_le_zero ((degZ_le_iff A 0).mp hZ.le 0)
  have h3 : (A.coeff 0).coeff 0 ≠ 0 := by
    intro h0
    apply hA
    rw [h1, h2, h0, C_0, C_0]
  rw [h1, h2]
  exact (isUnit_C.mpr (isUnit_C.mpr (isUnit_iff_ne_zero.mpr h3)))

/-- Exchanging the two variables keeps two polynomials relatively prime. -/
theorem isRelPrime_swap {A B : F[X][X]} (h : IsRelPrime A B) : IsRelPrime (swap A) (swap B) := by
  intro d hA hB
  have hA' : swap d ∣ A := by simpa only [swap_swap_apply] using map_dvd swap hA
  have hB' : swap d ∣ B := by simpa only [swap_swap_apply] using map_dvd swap hB
  simpa only [swap_swap_apply] using (h hA' hB').map swap

end Code.Lines
