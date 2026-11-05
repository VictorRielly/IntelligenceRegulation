-- Copyright 2026 Anthropic PBC
-- SPDX-License-Identifier: Apache-2.0
-- Modified for ZK60Formal (IntelligenceRegulation), 2026-11-04: module paths renamed under
-- ZK60Formal.ThirdParty.FlashProve. Nothing else changed.
/-
Code/Lines/RelPrimeCase.lean: the Polishchuk-Spielman lemma for polynomials without a common factor.

The files of the directory Code/Lines prove the case 2e + k + 1 = n of [BCIKS20, Theorem 4.1]
(`lines_tight`), in integers; Code/Half.lean relaxes the equality to ≤ (`caOn_rsCode`) and states it
in the terms of this library.

The Polishchuk–Spielman lemma (the source's Lemma 4.3) for relatively prime A and B: in that case,
under the hypotheses of `isUnit_of_isRelPrime`, A is a unit.

Source. E. Ben-Sasson, D. Carmon, Y. Ishai, S. Kopparty, S. Saraf, "Proximity Gaps for Reed–Solomon
Codes", Cryptology ePrint Archive 2020/654, version of July 3, 2021 (cited below as BCIKS20 or "the
source"). This is the second half of the proof of Lemma 4.3 in Appendix D (pp. 59–60). In the
source's notation, a_X and a_Z bound the degrees of A in X and Z, b_X and b_Z bound those of B,
d_X = b_X - a_X, d_Z = b_Z - a_Z, and n_X and n_Z are the numbers of points x and z at which a
quotient is given. The determinant R_X of the Sylvester matrix of A and B with respect to X
(Mathlib's `resultant`, see ResultantDegree.lean) is a non-zero polynomial in Z of degree at most
a_X b_Z + a_Z b_X. It has a root of multiplicity at least a_X at every z for which A(X, z) divides
B(X, z) with a quotient of degree at most d_X. The same is true with X and Z exchanged. The source's
condition (⋆), b_X / n_X + b_Z / n_Z < 1, then forces a_X = a_Z = 0.

Differences from the source. Here a_X and a_Z are the exact degrees of A (PolishchukSpielman.lean
reduces the lemma to this case), and the last step multiplies the inequalities by n_X n_Z where the
source divides.

The Lean library ArkLib (https://github.com/Verified-zkEVM/ArkLib) also formalizes Lemma 4.3 of
ePrint 2020/654 and has a lemma of its own for the relatively prime case; the proof here takes the
same route as ArkLib's: the frame of the argument is the same as ArkLib's from start to end, and
each shared point has a ground in the paper.

The number types, the form of the inequality, the way the quotients are given and the second size of
the resultant differ. lean/CREDITS.md has ArkLib's entry.
Against ArkLib's source at commit db7005f8: "ArkLib,
Data/CodingTheory/PolishchukSpielman/Existence.lean: the lemma for the relatively prime case, whose
frame ours shares throughout, not only at its opening.
Every shared step is the paper's; the listed differences stand."

Notation:
  `F[X][X]`: `Polynomial (Polynomial F)`, the polynomials in the source's two variables X and Z: the
    outer variable is the source's X (the variable of the code) and the inner variable is the
    source's Z (the parameter of the line) (Code/Lines/Bivariate.lean's head);
  `atX x A` (Code/Lines/Bivariate.lean): a polynomial in Z: A(x, Z): the outer variable X is set to
    the constant `x`;
  `atZ z A` (Code/Lines/Bivariate.lean): a polynomial in X: A(X, z): the inner variable Z is set to
    `z` in every coefficient;
  `degZ A` (Code/Lines/Bivariate.lean): a natural number: the degree of A in the inner variable Z;
  `swap`: Mathlib's `Polynomial.Bivariate.swap` exchanges the two variables
    (Code/Lines/Bivariate.lean's head).
-/
import ZK60Formal.ThirdParty.FlashProve.Code.Lines.Bivariate
import ZK60Formal.ThirdParty.FlashProve.Code.Lines.ResultantDegree
import ZK60Formal.ThirdParty.FlashProve.Code.Lines.Multiplicity
import ZK60Formal.ThirdParty.FlashProve.Code.Lines.RelPrime

namespace Code.Lines

open Polynomial Polynomial.Bivariate

variable {F : Type*} [Field F]

/-- Let A ≠ 0 and B be relatively prime with deg_X B ≤ deg_X A + dX, deg_Z A ≤ aZ and deg_Z B ≤ bZ,
and let B(X, z) = p_z · A(X, z) with deg p_z ≤ dX for every z in Sz. Then deg_X A · |Sz| ≤ deg_X A ·
bZ + (deg_X A + dX) · aZ. The right-hand side bounds the degree of the resultant, which has a root
of multiplicity at least deg_X A at every z in Sz. -/
theorem natDegree_mul_card_le {A B : F[X][X]} (hA : A ≠ 0) (hrel : IsRelPrime A B) (Sz : Finset F)
    {dX aZ bZ : ℕ} (hz : ∀ z ∈ Sz, ∃ p : F[X], p.natDegree ≤ dX ∧ atZ z B = p * atZ z A)
    (hdx : B.natDegree ≤ A.natDegree + dX) (haZ : degZ A ≤ aZ) (hbZ : degZ B ≤ bZ) :
    A.natDegree * Sz.card ≤ A.natDegree * bZ + (A.natDegree + dX) * aZ := by
  have hR : resultant A B A.natDegree (A.natDegree + dX) ≠ 0 :=
    resultant_ne_zero_of_isRelPrime hA hrel hdx
  have h1 : A.natDegree * Sz.card ≤ (resultant A B A.natDegree (A.natDegree + dX)).natDegree := by
    refine mul_card_le_natDegree_resultant Sz le_rfl (fun z hzS => ?_) hR
    obtain ⟨p, hp, hpz⟩ := hz z hzS
    exact ⟨p, by omega, hpz⟩
  exact h1.trans
    (natDegree_resultant_le A B _ _ aZ bZ ((degZ_le_iff A aZ).mp haZ) ((degZ_le_iff B bZ).mp hbZ))

/-- Write bX = aX + dX, bZ = aZ + dZ and Δ = aX bZ + bX aZ. If aX N ≤ Δ, aZ M ≤ Δ and bX N + bZ M <
M N, then aX = aZ = 0. Here M and N stand for n_X and n_Z. -/
theorem eq_zero_of_counts {aX aZ dX dZ M N : ℕ} (h1 : aX * N ≤ aX * (aZ + dZ) + (aX + dX) * aZ)
    (h2 : aZ * M ≤ aZ * (aX + dX) + (aZ + dZ) * aX)
    (hstar : (aX + dX) * N + (aZ + dZ) * M < M * N) : aX = 0 ∧ aZ = 0 := by
  have hM : 0 < M := Nat.pos_of_ne_zero (by rintro rfl; simp at hstar)
  have hN : 0 < N := Nat.pos_of_ne_zero (by rintro rfl; simp at hstar)
  -- Δ is the bound on the degree of both resultants.
  obtain ⟨Δ, hΔ⟩ : ∃ Δ, Δ = aX * (aZ + dZ) + (aX + dX) * aZ := ⟨_, rfl⟩
  have h1' : aX * N ≤ Δ := by rw [hΔ]; exact h1
  have h2' : aZ * M ≤ Δ := by rw [hΔ]; linarith
  have hkey : Δ * (M * N) ≤ Δ * ((aX + dX) * N + (aZ + dZ) * M) := by
    calc Δ * (M * N) = (aX * N) * ((aZ + dZ) * M) + (aZ * M) * ((aX + dX) * N) := by rw [hΔ]; ring
      _ ≤ Δ * ((aZ + dZ) * M) + Δ * ((aX + dX) * N) := by gcongr
      _ = Δ * ((aX + dX) * N + (aZ + dZ) * M) := by ring
  have hΔ0 : Δ = 0 := by
    by_contra hne
    exact absurd (Nat.le_of_mul_le_mul_left hkey (Nat.pos_of_ne_zero hne)) (not_le.mpr hstar)
  rw [hΔ0] at h1' h2'
  constructor
  · exact (Nat.mul_eq_zero.mp (Nat.le_zero.mp h1')).resolve_right hN.ne'
  · exact (Nat.mul_eq_zero.mp (Nat.le_zero.mp h2')).resolve_right hM.ne'

/-- The Polishchuk–Spielman lemma for relatively prime A and B. Let A ≠ 0 and B be relatively prime.
Suppose that for every x in Sx, B(x, Z) = p · A(x, Z) for some p of degree at most dZ, and that for
every z in Sz, B(X, z) = p · A(X, z) for some p of degree at most dX. Write bX = deg_X A + dX and
bZ = deg_Z A + dZ, and suppose deg_X B ≤ bX, deg_Z B ≤ bZ and bX |Sz| + bZ |Sx| < |Sx| |Sz| (the
condition (⋆) without division). Then A is a unit, that is, a non-zero constant. -/
theorem isUnit_of_isRelPrime {A B : F[X][X]} (hA : A ≠ 0) (hrel : IsRelPrime A B) (Sx Sz : Finset F)
    {dX dZ : ℕ} (hx : ∀ x ∈ Sx, ∃ p : F[X], p.natDegree ≤ dZ ∧ atX x B = p * atX x A)
    (hz : ∀ z ∈ Sz, ∃ p : F[X], p.natDegree ≤ dX ∧ atZ z B = p * atZ z A)
    (hdx : B.natDegree ≤ A.natDegree + dX) (hdz : degZ B ≤ degZ A + dZ)
    (hstar : (A.natDegree + dX) * Sz.card + (degZ A + dZ) * Sx.card < Sx.card * Sz.card) :
    IsUnit A := by
  have h1 := natDegree_mul_card_le hA hrel Sz hz hdx le_rfl hdz
  -- The same count for the pair with the two variables exchanged.
  have hA' : swap A ≠ 0 := (map_ne_zero_iff _ (swap (R := F)).injective).mpr hA
  have h2 := natDegree_mul_card_le (A := swap A) (B := swap B) (dX := dZ)
    (aZ := A.natDegree) (bZ := A.natDegree + dX) hA' (isRelPrime_swap hrel) Sx
    (fun x hxS => by simpa only [atZ_swap] using hx x hxS) hdz
    (degZ_swap A).le ((degZ_swap B).le.trans hdx)
  obtain ⟨hX, hZ⟩ := eq_zero_of_counts h1 h2 hstar
  exact isUnit_of_degrees_eq_zero hA hX hZ

end Code.Lines
