-- Copyright 2026 Anthropic PBC
-- SPDX-License-Identifier: Apache-2.0
-- Modified for ZK60Formal (IntelligenceRegulation), 2026-11-04: module paths renamed under
-- ZK60Formal.ThirdParty.FlashProve. Nothing else changed.
/-
Code/Lines/PolishchukSpielman.lean: the Polishchuk-Spielman lemma.

The files of the directory Code/Lines prove [BCIKS20, Theorem 4.1], in integers; Code/Half.lean
states it in the terms of this library.
Exactly: the directory proves correlated agreement over lines in the case 2e + k + 1 = n (n the
block length, k the bound on the degree of the code's polynomials), at an integer radius e
(`lines_tight`); Code/Half.lean relaxes the equality to ≤ (`caOn_rsCode`).

The Polishchuk–Spielman lemma, in the form of the source's Lemma 4.3.

Source. E. Ben-Sasson, D. Carmon, Y. Ishai, S. Kopparty, S. Saraf, "Proximity Gaps for Reed–Solomon
Codes", Cryptology ePrint Archive 2020/654, version of July 3, 2021 (cited below as BCIKS20 or "the
source"). Lemma 4.3 is stated on pp. 14–15 and proved in Appendix D (pp. 58–60). The source calls it
a version of the Polishchuk–Spielman lemma and cites [PS94] and [Spi95, Lemma 4.2.18] for it. It
says that its proof essentially follows [Spi95, Lemma 4.2.18].

By Appendix D (p. 58), the proof of [Spi95, Lemma 4.2.18] has an error that is easy to miss, and
the lemma in its first statement fails on some examples; for these the source cites [Bég19]. What
sets apart the form used is a bound that it asks on the degrees of the quotients (here
`p.natDegree ≤ dZ` and `p.natDegree ≤ dX`). It thanks Ronald Cramer and Jade Nardi "for pointing out
the precise flaw and suggesting possible fixes", and says that the fix it chose "was independently
discovered by Ronald Cramer".

The statement. In the source's notation, a_X and a_Z bound the degrees of A in X and Z, b_X and b_Z
bound those of B, d_X = b_X - a_X, d_Z = b_Z - a_Z, and n_X and n_Z are the numbers of points x and
z at which a quotient is given. The condition (⋆) is b_X / n_X + b_Z / n_Z < 1. In Lean the letters
are `aX`, `aZ`, `dX`, `dZ`, the points form the finite sets `Sx` and `Sz`, b_X is written `aX + dX`
and b_Z `aZ + dZ`, and (⋆) is multiplied by n_X n_Z. `polishchuk_spielman` has the source's
hypotheses and three of its five conclusions: A divides B, with a quotient P that has deg_X P ≤ d_X
and deg_Z P ≤ d_Z. The source's two remaining conclusions, that P agrees with the given quotients at
no fewer than n_Z - a_Z of the points z and n_X - a_X of the points x, are not stated; Tight.lean
proves the part of the second that it needs.

Differences from the source in the proof. The source lowers the bounds a_X and b_X together until
deg_X A = a_X or deg_X B = b_X, and likewise in Z (pp. 58–59). It remarks that deg_X A = a_X then
holds, as a consequence of the bound on the degrees of the quotients and of b_Z < n_Z, and omits the
details because its proof does not use this (p. 59). Here the proof first shows from these same two
facts that deg_X B ≤ deg_X A + d_X, and likewise that deg_Z B ≤ deg_Z A + d_Z, and then works with
the exact degrees of A (`polishchuk_spielman_exact`). The source divides A and B once by their
greatest common divisor. Here the proof is an induction on the sum of the two degrees of A. Each
step divides A and B by some common factor that is not a unit. The source reads the bounds on the
degrees of P off the reduced case, in which A is a constant (p. 60). Here they follow from the two
inequalities above and deg B = deg A + deg P in each variable.

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
  `atX x A` (Code/Lines/Bivariate.lean): a polynomial in Z: A(x, Z): the outer variable X is set to
    the constant `x`;
  `atZ z A` (Code/Lines/Bivariate.lean): a polynomial in X: A(X, z): the inner variable Z is set to
    `z` in every coefficient;
  `degZ A` (Code/Lines/Bivariate.lean): a natural number: the degree of A in the inner variable Z.
-/
import ZK60Formal.ThirdParty.FlashProve.Code.Lines.RelPrimeCase

namespace Code.Lines

open Polynomial

variable {F : Type*} [Field F]

/-- The condition (⋆) survives the division by a common factor of degrees gX and gZ. Here M = |Sx|
and N = |Sz| are the numbers of points x and z before the division, M' and N' are the numbers of
points after it, which are smaller by at most gX and gZ, and bX' and bZ' are the degree bounds on B
after it, so that the bounds before it are bX' + gX and bZ' + gZ. -/
theorem star_of_star {bX' bZ' gX gZ M N M' N' : ℕ} (hM : M ≤ M' + gX) (hN : N ≤ N' + gZ)
    (hstar : (bX' + gX) * N + (bZ' + gZ) * M < M * N) : bX' * N' + bZ' * M' < M' * N' := by
  have hM1 : bX' + gX ≤ M := by
    by_contra h
    have h1 : M * N ≤ (bX' + gX) * N := Nat.mul_le_mul_right N (by omega)
    omega
  have hN1 : bZ' + gZ ≤ N := by
    by_contra h
    have h1 : M * N ≤ M * (bZ' + gZ) := Nat.mul_le_mul_left M (by omega)
    have h2 : M * (bZ' + gZ) = (bZ' + gZ) * M := Nat.mul_comm _ _
    omega
  obtain ⟨s, rfl⟩ := Nat.exists_eq_add_of_le hM1
  obtain ⟨t, rfl⟩ := Nat.exists_eq_add_of_le hN1
  obtain ⟨s', rfl⟩ : ∃ s', M' = bX' + s' := Nat.exists_eq_add_of_le (by omega)
  obtain ⟨t', rfl⟩ : ∃ t', N' = bZ' + t' := Nat.exists_eq_add_of_le (by omega)
  have hs : s ≤ s' := by omega
  have ht : t ≤ t' := by omega
  have h1 : (bX' + gX) * (bZ' + gZ) < s * t := by nlinarith
  have h2 : bX' * bZ' ≤ (bX' + gX) * (bZ' + gZ) := Nat.mul_le_mul (by omega) (by omega)
  have h3 : s * t ≤ s' * t' := Nat.mul_le_mul hs ht
  nlinarith

/-- The statement of `polishchuk_spielman_exact` below, with the same hypotheses, arranged for an
induction on the sum n of the two degrees of A. The polynomials and the two sets vary in the
induction, and dX and dZ stay fixed. -/
theorem polishchuk_spielman_aux {dX dZ : ℕ} (n : ℕ) : ∀ (A B : F[X][X]) (Sx Sz : Finset F),
    A.natDegree + degZ A = n → A ≠ 0 →
    (∀ x ∈ Sx, ∃ p : F[X], p.natDegree ≤ dZ ∧ atX x B = p * atX x A) →
    (∀ z ∈ Sz, ∃ p : F[X], p.natDegree ≤ dX ∧ atZ z B = p * atZ z A) →
    B.natDegree ≤ A.natDegree + dX → degZ B ≤ degZ A + dZ →
    (A.natDegree + dX) * Sz.card + (degZ A + dZ) * Sx.card < Sx.card * Sz.card → A ∣ B := by
  induction n using Nat.strong_induction_on with
  | _ n ih =>
  intro A B Sx Sz hn hA hx hz hdx hdz hstar
  by_cases hrel : IsRelPrime A B
  · exact (isUnit_of_isRelPrime hA hrel Sx Sz hx hz hdx hdz hstar).dvd
  · -- A and B have a common factor G that is not a unit.
    unfold IsRelPrime at hrel
    push Not at hrel
    obtain ⟨G, ⟨A', rfl⟩, ⟨B', rfl⟩, hG⟩ := hrel
    have hG0 : G ≠ 0 := left_ne_zero_of_mul hA
    have hA'0 : A' ≠ 0 := right_ne_zero_of_mul hA
    have hdegX : (G * A').natDegree = G.natDegree + A'.natDegree := natDegree_mul hG0 hA'0
    have hdegZ : degZ (G * A') = degZ G + degZ A' := degZ_mul hG0 hA'0
    have hpos : 0 < G.natDegree + degZ G := by
      by_contra h
      exact hG (isUnit_of_degrees_eq_zero hG0 (by omega) (by omega))
    classical
    -- The points at which G does not vanish identically.
    have hcx : Sx.card ≤ (Sx.filter fun x => ¬ atX x G = 0).card + G.natDegree := by
      have h1 := Finset.card_filter_add_card_filter_not (s := Sx) (fun x => atX x G = 0)
      have h2 := card_filter_atX_eq_zero_le hG0 Sx
      omega
    have hcz : Sz.card ≤ (Sz.filter fun z => ¬ atZ z G = 0).card + degZ G := by
      have h1 := Finset.card_filter_add_card_filter_not (s := Sz) (fun z => atZ z G = 0)
      have h2 := card_filter_atZ_eq_zero_le hG0 Sz
      omega
    refine mul_dvd_mul_left G (ih (A'.natDegree + degZ A') (by omega) A' B'
      (Sx.filter fun x => ¬ atX x G = 0) (Sz.filter fun z => ¬ atZ z G = 0) rfl hA'0 ?_ ?_ ?_ ?_ ?_)
    · intro x hxm
      obtain ⟨hxS, hxG⟩ := Finset.mem_filter.mp hxm
      obtain ⟨p, hp, he⟩ := hx x hxS
      refine ⟨p, hp, mul_left_cancel₀ hxG ?_⟩
      rw [map_mul, map_mul] at he
      rw [he]
      ring
    · intro z hzm
      obtain ⟨hzS, hzG⟩ := Finset.mem_filter.mp hzm
      obtain ⟨p, hp, he⟩ := hz z hzS
      refine ⟨p, hp, mul_left_cancel₀ hzG ?_⟩
      rw [map_mul, map_mul] at he
      rw [he]
      ring
    · by_cases hB' : B' = 0
      · simp [hB']
      · have h1 : (G * B').natDegree = G.natDegree + B'.natDegree := natDegree_mul hG0 hB'
        omega
    · by_cases hB' : B' = 0
      · simp [hB', degZ]
      · have h1 : degZ (G * B') = degZ G + degZ B' := degZ_mul hG0 hB'
        omega
    · apply star_of_star (gX := G.natDegree) (gZ := degZ G) hcx hcz
      have e1 : A'.natDegree + dX + G.natDegree = (G * A').natDegree + dX := by omega
      have e2 : degZ A' + dZ + degZ G = degZ (G * A') + dZ := by omega
      rw [e1, e2]
      exact hstar

/-- The divisibility claim of the Polishchuk–Spielman lemma, with the exact degrees of A in place of
the bounds a_X and a_Z. Let A ≠ 0 and B be polynomials in X and Z. Suppose that for every x in Sx,
B(x, Z) = p · A(x, Z) for some p of degree at most dZ, and that for every z in Sz, B(X, z) = p ·
A(X, z) for some p of degree at most dX. Write b_X = deg_X A + dX and b_Z = deg_Z A + dZ. Suppose
deg_X B ≤ b_X, deg_Z B ≤ b_Z and b_X / |Sx| + b_Z / |Sz| < 1 (the source's condition (⋆)), written
without division. Then A divides B. -/
theorem polishchuk_spielman_exact {A B : F[X][X]} (hA : A ≠ 0) (Sx Sz : Finset F) {dX dZ : ℕ}
    (hx : ∀ x ∈ Sx, ∃ p : F[X], p.natDegree ≤ dZ ∧ atX x B = p * atX x A)
    (hz : ∀ z ∈ Sz, ∃ p : F[X], p.natDegree ≤ dX ∧ atZ z B = p * atZ z A)
    (hdx : B.natDegree ≤ A.natDegree + dX) (hdz : degZ B ≤ degZ A + dZ)
    (hstar : (A.natDegree + dX) * Sz.card + (degZ A + dZ) * Sx.card < Sx.card * Sz.card) : A ∣ B :=
  polishchuk_spielman_aux _ A B Sx Sz rfl hA hx hz hdx hdz hstar

/-- The Polishchuk–Spielman lemma (BCIKS20, Lemma 4.3). Let A and B be polynomials in X and Z with
deg_X A ≤ aX, deg_Z A ≤ aZ, deg_X B ≤ bX = aX + dX and deg_Z B ≤ bZ = aZ + dZ. Suppose that for
every x in Sx, B(x, Z) = p · A(x, Z) for some p of degree at most dZ, and that for every z in Sz,
B(X, z) = p · A(X, z) for some p of degree at most dX. Suppose bX / |Sx| + bZ / |Sz| < 1 (the
source's condition (⋆)), written without division. Then B = A · P for some P with deg_X P ≤ dX and
deg_Z P ≤ dZ. The source's two remaining conclusions, which count the z and the x at which P agrees
with the given quotients, are not stated. -/
theorem polishchuk_spielman {A B : F[X][X]} (Sx Sz : Finset F) {aX aZ dX dZ : ℕ}
    (hAX : A.natDegree ≤ aX) (hAZ : degZ A ≤ aZ) (hBX : B.natDegree ≤ aX + dX)
    (hBZ : degZ B ≤ aZ + dZ) (hx : ∀ x ∈ Sx, ∃ p : F[X], p.natDegree ≤ dZ ∧ atX x B = p * atX x A)
    (hz : ∀ z ∈ Sz, ∃ p : F[X], p.natDegree ≤ dX ∧ atZ z B = p * atZ z A)
    (hstar : (aX + dX) * Sz.card + (aZ + dZ) * Sx.card < Sx.card * Sz.card) :
    ∃ P : F[X][X], B = A * P ∧ P.natDegree ≤ dX ∧ degZ P ≤ dZ := by
  classical
  -- The condition (⋆) gives bX < |Sx| and bZ < |Sz|.
  have hM : aX + dX < Sx.card := by
    by_contra h
    have h1 : Sx.card * Sz.card ≤ (aX + dX) * Sz.card := Nat.mul_le_mul_right _ (by omega)
    omega
  have hN : aZ + dZ < Sz.card := by
    by_contra h
    have h1 : Sx.card * Sz.card ≤ (aZ + dZ) * Sx.card := by
      rw [Nat.mul_comm (aZ + dZ)]
      exact Nat.mul_le_mul_left _ (by omega)
    omega
  by_cases hA : A = 0
  · -- If A = 0, then B(x, Z) = 0 at more than deg_X B points x, so B = 0.
    refine ⟨0, ?_, by simp, by simp [degZ]⟩
    rw [mul_zero]
    by_contra hB
    have hcard := card_filter_atX_eq_zero_le hB Sx
    rw [Finset.filter_true_of_mem] at hcard
    · omega
    · intro x hxS
      obtain ⟨p, -, h⟩ := hx x hxS
      rw [h, hA, map_zero, mul_zero]
  · -- The degrees of B exceed the exact degrees of A by at most dX and dZ.
    have hdx : B.natDegree ≤ A.natDegree + dX := by
      refine natDegree_le_of_atZ Sz (by omega) fun z hzS => ?_
      obtain ⟨p, hp, h⟩ := hz z hzS
      rw [h]
      have h1 := natDegree_mul_le (p := p) (q := atZ z A)
      have h2 := natDegree_atZ_le z A
      omega
    have hdz : degZ B ≤ degZ A + dZ := by
      refine degZ_le_of_atX Sx (by omega) fun x hxS => ?_
      obtain ⟨p, hp, h⟩ := hx x hxS
      rw [h]
      have h1 := natDegree_mul_le (p := p) (q := atX x A)
      have h2 := natDegree_atX_le x A
      omega
    have hstar' : (A.natDegree + dX) * Sz.card + (degZ A + dZ) * Sx.card < Sx.card * Sz.card := by
      have h1 : (A.natDegree + dX) * Sz.card ≤ (aX + dX) * Sz.card :=
        Nat.mul_le_mul_right _ (by omega)
      have h2 : (degZ A + dZ) * Sx.card ≤ (aZ + dZ) * Sx.card := Nat.mul_le_mul_right _ (by omega)
      omega
    obtain ⟨P, hP⟩ := polishchuk_spielman_exact hA Sx Sz hx hz hdx hdz hstar'
    refine ⟨P, hP, ?_, ?_⟩
    · by_cases hP0 : P = 0
      · simp [hP0]
      · have h := natDegree_mul hA hP0
        rw [← hP] at h
        omega
    · by_cases hP0 : P = 0
      · simp [hP0, degZ]
      · have h := degZ_mul hA hP0
        rw [← hP] at h
        omega

end Code.Lines
