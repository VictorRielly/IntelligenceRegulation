-- Copyright 2026 Anthropic PBC
-- SPDX-License-Identifier: Apache-2.0
-- Modified for ZK60Formal (IntelligenceRegulation), 2026-11-04: module paths renamed under
-- ZK60Formal.ThirdParty.FlashProve; in `card_filter_atX_domain_le`, `exact Iff.rfl` added after
-- `convert h` (Mathlib v4.34.1 leaves that goal open). Nothing else changed.
/-
Code/Lines/Tight.lean: correlated agreement over lines at an integer radius e, for the Reed-Solomon
code of the polynomials of degree at most k, when the block length is exactly n = 2 e + k + 1.

The files of the directory Code/Lines prove [BCIKS20, Theorem 4.1], in integers; Code/Half.lean
states it in the terms of this library and removes the condition on the block length.
Exactly: the directory proves the case 2e + k + 1 = n, at an integer radius e (`lines_tight`);
Code/Half.lean relaxes the equality to ≤ (`caOn_rsCode`).
In `lines_tight` closeness is given by a set of positions of agreement, in place of a bound on the
Hamming distance; the good values z form any finite set, so that the field may be infinite; the code
is given through its polynomials. The names ending in "_tight" refer to the case n = 2 e + k + 1.

Source. E. Ben-Sasson, D. Carmon, Y. Ishai, S. Kopparty, S. Saraf, "Proximity Gaps for Reed–Solomon
Codes", Cryptology ePrint Archive 2020/654, version of July 3, 2021 (cited below as BCIKS20 or "the
source"). This is the proof of Theorem 4.1 in Section 4.3 (pp. 15–17). Call z good if u₀ + z u₁, for
the two given words u₀ and u₁, agrees with a codeword outside at most e positions (the source's set
S), and let P_z be the polynomial of such a codeword. The steps are: find A and B
(Interpolation.lean), show B(X, z) = P_z(X) A(X, z) for every good z (BerlekampWelch.lean), divide B
by A (PolishchukSpielman.lean, applied as in the source with a_X = a_Z = e, d_X = k and d_Z = 1),
and read the two codewords v₀ and v₁ off the quotient P.

Differences from the source. The source takes the number of points x with P(x, Z) = u₀(x) + Z u₁(x)
from the last conclusion of Lemma 4.3, which PolishchukSpielman.lean does not state; here it is
proved in this file. The source writes the quotient as v₀(X) + Z v₁(X). Here v₀ = P(X, 0) and v₁ =
P(X, 1) - P(X, 0), and the bound on the degree of P in Z is not used.

The Lean library ArkLib (https://github.com/Verified-zkEVM/ArkLib) also formalizes Theorem 4.1 and
Lemma 4.3 of ePrint 2020/654, the two results of which this directory proves our library's own Lean
statements.

Our statement of Lemma 4.3 has the lemma in part: the divisibility and the degree bounds of the
quotient, not its agreement counts.

lean/CREDITS.md has ArkLib's entry.

Notation:
  `D : ι ↪ F`: an injective map from ι, a finite type (the positions: `GoodAt`), into the field: the
    domain;
  `F[X][X]`: `Polynomial (Polynomial F)`, the polynomials in the source's two variables X and Z: the
    outer variable is the source's X (the variable of the code) and the inner variable is the
    source's Z (the parameter of the line) (Code/Lines/Bivariate.lean's head);
  `atX x A` (Code/Lines/Bivariate.lean): a polynomial in Z: A(x, Z): the outer variable X is set to
    the constant `x`;
  `atZ z A` (Code/Lines/Bivariate.lean): a polynomial in X: A(X, z): the inner variable Z is set to
    `z` in every coefficient.
-/
import ZK60Formal.ThirdParty.FlashProve.Code.Lines.Interpolation
import ZK60Formal.ThirdParty.FlashProve.Code.Lines.BerlekampWelch
import ZK60Formal.ThirdParty.FlashProve.Code.Lines.PolishchukSpielman

namespace Code.Lines

open Polynomial Finset

/-- The condition (⋆) of the Polishchuk–Spielman lemma holds for n = 2 e + k + 1 points x, N > n
points z and the degree bounds bX = e + k and bZ = e + 1. -/
theorem star_tight {e k n N : ℕ} (hn : 2 * e + k + 1 = n) (hN : n < N) :
    (e + k) * N + (e + 1) * n < n * N := by
  have h3 : (e + 1) * n < (e + 1) * N := Nat.mul_lt_mul_of_pos_left hN (by omega)
  have h4 : n * N = (e + k) * N + (e + 1) * N := by
    rw [← hn]
    ring
  omega

variable {F : Type*} [Field F] {ι : Type} [Fintype ι]

/-- A non-zero A has A(x, Z) = 0 for at most deg_X A points x of the domain. -/
theorem card_filter_atX_domain_le
    (D : ι ↪ F) {A : F[X][X]} (hA : A ≠ 0) [DecidablePred fun x : ι => atX (D x) A = 0] :
    (univ.filter fun x : ι => atX (D x) A = 0).card ≤ A.natDegree := by
  classical
  have h := card_filter_atX_eq_zero_le hA (univ.map D)
  rw [filter_map, card_map] at h
  convert h
  exact Iff.rfl

/-- The value z is good for the words u₀, u₁: the word u₀ + z u₁ agrees, outside at most e
positions, with the values of a polynomial of degree at most k. -/
def GoodAt (D : ι ↪ F) (e k : ℕ) (u₀ u₁ : ι → F) (z : F) : Prop :=
  ∃ p : F[X],
    p.natDegree ≤ k ∧
    ∃ S : Finset ι, Fintype.card ι ≤ S.card + e ∧ ∀ x ∈ S, u₀ x + z * u₁ x = p.eval (D x)

/-- Let the block length be n = 2 e + k + 1. If every z in a set Sz of more than n elements is good,
then there are A ≠ 0 of degree at most e in X and P of degree at most k in X with A(x, Z) P(x, Z) =
(u₀(x) + Z u₁(x)) A(x, Z) at every point x of the domain. -/
theorem exists_quotient (D : ι ↪ F) {e k : ℕ} (hn : 2 * e + k + 1 = Fintype.card ι) (u₀ u₁ : ι → F)
    (Sz : Finset F) (hSz : ∀ z ∈ Sz, GoodAt D e k u₀ u₁ z) (hcard : Fintype.card ι < Sz.card) :
    ∃ A P : F[X][X],
      A ≠ 0 ∧ A.natDegree ≤ e ∧ P.natDegree ≤ k ∧
      ∀ x, atX (D x) A * atX (D x) P = (C (u₀ x) + X * C (u₁ x)) * atX (D x) A := by
  have hSxc : (univ.map D).card = Fintype.card ι := by rw [card_map, card_univ]
  obtain ⟨A, B, hA, hAX, hAZ, hBX, hBZ, hAB⟩ := exists_interpolant D hn u₀ u₁
  -- For every x in the domain, B(x, Z) is A(x, Z) times a polynomial of degree at most 1.
  have hx : ∀ x ∈ univ.map D, ∃ p : F[X], p.natDegree ≤ 1 ∧ atX x B = p * atX x A := by
    intro x hxS
    obtain ⟨i, -, rfl⟩ := mem_map.mp hxS
    exact ⟨C (u₀ i) + X * C (u₁ i), natDegree_line_le _ _, hAB i⟩
  -- For every z in Sz, B(X, z) is A(X, z) times the polynomial of a close codeword
  -- (Berlekamp–Welch).
  have hz : ∀ z ∈ Sz, ∃ p : F[X], p.natDegree ≤ k ∧ atZ z B = p * atZ z A := by
    intro z hzS
    obtain ⟨p, hp, S, hS, hag⟩ := hSz z hzS
    refine ⟨p, hp,
      berlekamp_welch D hn.le ((natDegree_atZ_le z A).trans hAX) ((natDegree_atZ_le z B).trans hBX)
        hp (fun x => u₀ x + z * u₁ x) ?_ S hS hag⟩
    intro x
    have h := congrArg (Polynomial.eval z) (hAB x)
    rw [eval_mul, eval_atX, eval_atX] at h
    simp only [eval_add, eval_C, eval_mul, eval_X] at h
    rw [h]
    ring
  -- The Polishchuk–Spielman lemma with a_X = a_Z = e, d_X = k and d_Z = 1, as in the source (p.
  -- 16).
  have hstar : (e + k) * Sz.card + (e + 1) * (univ.map D).card < (univ.map D).card * Sz.card := by
    rw [hSxc]
    exact star_tight hn hcard
  obtain ⟨P, hP, hPX, -⟩ := polishchuk_spielman (univ.map D) Sz hAX hAZ hBX hBZ hx hz hstar
  refine ⟨A, P, hA, hAX, hPX, ?_⟩
  intro x
  rw [← map_mul, ← hP, hAB x]

/-- Correlated agreement over lines at the integer radius e, when the block length is exactly n = 2
e + k + 1. If more than n values z are good, then u₀ and u₁ agree with the values of two polynomials
of degree at most k outside one set of at most e positions. -/
theorem lines_tight (D : ι ↪ F) {e k : ℕ} (hn : 2 * e + k + 1 = Fintype.card ι) (u₀ u₁ : ι → F)
    (Sz : Finset F) (hSz : ∀ z ∈ Sz, GoodAt D e k u₀ u₁ z) (hcard : Fintype.card ι < Sz.card) :
    ∃ p₀ p₁ : F[X],
      p₀.natDegree ≤ k ∧ p₁.natDegree ≤ k ∧
      ∃ W : Finset ι, W.card ≤ e ∧ ∀ x, x ∉ W → u₀ x = p₀.eval (D x) ∧ u₁ x = p₁.eval (D x) := by
  classical
  obtain ⟨A, P, hA, hAX, hPX, hAP⟩ := exists_quotient D hn u₀ u₁ Sz hSz hcard
  refine ⟨atZ 0 P, atZ 1 P - atZ 0 P,
    (natDegree_atZ_le 0 P).trans hPX,
    (natDegree_sub_le_of_le ((natDegree_atZ_le 1 P).trans hPX)
        ((natDegree_atZ_le 0 P).trans hPX)).trans (max_self k).le,
    univ.filter fun x => atX (D x) A = 0,
    (card_filter_atX_domain_le D hA).trans hAX,
    fun x hx => ?_⟩
  -- Outside the points x of the domain with A(x, Z) = 0, the quotient is the line.
  have hne : atX (D x) A ≠ 0 := fun h0 => hx (mem_filter.mpr ⟨mem_univ x, h0⟩)
  have hq : atX (D x) P = C (u₀ x) + X * C (u₁ x) := by
    apply mul_left_cancel₀ hne
    rw [hAP x, mul_comm]
  have h0 : (atZ 0 P).eval (D x) = u₀ x := by
    rw [← eval_atX, hq]
    simp
  have h1 : (atZ 1 P).eval (D x) = u₀ x + u₁ x := by
    rw [← eval_atX, hq]
    simp
  exact ⟨h0.symm, by rw [eval_sub, h0, h1, add_sub_cancel_left]⟩

end Code.Lines
