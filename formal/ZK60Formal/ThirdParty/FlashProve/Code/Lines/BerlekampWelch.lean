-- Copyright 2026 Anthropic PBC
-- SPDX-License-Identifier: Apache-2.0
-- Modified for ZK60Formal (IntelligenceRegulation), 2026-11-04: module paths renamed under
-- ZK60Formal.ThirdParty.FlashProve. Nothing else changed.
/-
Code/Lines/BerlekampWelch.lean: a lemma on the linear system of the Berlekamp-Welch decoder,
at one word.

The files of the directory Code/Lines prove [BCIKS20, Theorem 4.1], in integers; Code/Half.lean
states it in the terms of this library.
Exactly: the directory proves correlated agreement over lines in the case 2e + k + 1 = n, at an
integer radius e (`lines_tight`); Code/Half.lean relaxes the equality to ≤ (`caOn_rsCode`).
Closeness is given by a set of positions on which the word and the codeword agree, in place of a
bound on the Hamming distance, so that equality in the field need not be decidable.

If 2 e + k + 1 ≤ n, where n is the block length and k bounds the degree of the code's polynomials,
every solution (a, b), with deg a ≤ e and deg b ≤ e + k, of the linear system of the Berlekamp–Welch
decoder satisfies b = p · a, where p is the polynomial of a codeword that agrees with the word
outside at most e positions.

Source. E. Ben-Sasson, D. Carmon, Y. Ishai, S. Kopparty, S. Saraf, "Proximity Gaps for Reed–Solomon
Codes", Cryptology ePrint Archive 2020/654, version of July 3, 2021 (cited below as BCIKS20 or "the
source"). This is item 2 of Lemma 4.2 (p. 14), whose proof the source omits as well known, in the
form in which Section 4.3.2 (p. 16) uses it: the case a = 0 is included.

The Lean library ArkLib (https://github.com/Verified-zkEVM/ArkLib) also formalizes Theorem 4.1 and
Lemma 4.3 of ePrint 2020/654, the two results of which this directory proves our library's own Lean
statements.

Our statement of Lemma 4.3 has the lemma in part: the divisibility and the degree bounds of the
quotient, not its agreement counts.

lean/CREDITS.md has ArkLib's entry.
-/
import Mathlib.Logic.Embedding.Basic
import Mathlib.Algebra.Polynomial.Roots
import Mathlib.Data.Fintype.Card

namespace Code.Lines

open Polynomial

variable {F : Type*} [Field F] {ι : Type} [Fintype ι]

/-- Let n be the block length and w a word. Suppose 2 e + k + 1 ≤ n, deg a ≤ e, deg b ≤ e + k and
a(x) w(x) = b(x) at every point x of the domain. If p has degree at most k and its codeword agrees
with w on a set S of all but at most e positions, then b = p · a. -/
theorem berlekamp_welch (D : ι ↪ F) {e k : ℕ} (hn : 2 * e + k + 1 ≤ Fintype.card ι) {a b p : F[X]}
    (ha : a.natDegree ≤ e) (hb : b.natDegree ≤ e + k) (hp : p.natDegree ≤ k) (w : ι → F)
    (hw : ∀ x, a.eval (D x) * w x = b.eval (D x)) (S : Finset ι)
    (hS : Fintype.card ι ≤ S.card + e) (hd : ∀ x ∈ S, w x = p.eval (D x)) : b = p * a := by
  have hz : b - p * a = 0 := by
    apply Polynomial.eq_zero_of_natDegree_lt_card_of_eval_eq_zero' (b - p * a) (S.map D)
    · intro y hy
      obtain ⟨x, hx, rfl⟩ := Finset.mem_map.mp hy
      rw [eval_sub, eval_mul, ← hw x, hd x hx]
      ring
    · rw [Finset.card_map]
      have h1 : (p * a).natDegree ≤ e + k := by
        refine natDegree_mul_le.trans ?_
        omega
      have h2 : (b - p * a).natDegree ≤ e + k := (natDegree_sub_le _ _).trans (max_le hb h1)
      omega
  exact sub_eq_zero.mp hz

end Code.Lines
