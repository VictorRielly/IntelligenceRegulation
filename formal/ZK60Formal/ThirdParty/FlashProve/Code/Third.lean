-- Copyright 2026 Anthropic PBC
-- SPDX-License-Identifier: Apache-2.0
-- Modified for ZK60Formal (IntelligenceRegulation), 2026-11-04: module paths renamed under
-- ZK60Formal.ThirdParty.FlashProve; the section "Codes with encoder (Code/Iface.lean)" and the
-- import of Code.Iface removed (Code/Iface.lean is not ported). Nothing else changed.
/-
Code/Third.lean: mutual correlated agreement of every linear code up to a third of its distance.

A value θ is bad for interleaved words f₀, f₁ if there is a set of all but at most e positions on
which every row of f₀ + θ f₁ agrees with a word of the code while not all rows of f₀ and f₁ do;
`MCA D e bad` says that there are at most `bad` such values, for any number of rows
(Code/Agree.lean).

 * If every non-zero word of the code has at least d non-zero symbols and 3 e < d, then
   `MCA D e (e + 1)` (`mca_third`). The plain form (correlated agreement) is `close_of_card` and
   `cnt_close_le`.
 * The same for a code with encoder (Code/Iface.lean): `Enc.onCode_iff`, `Enc.mca_iff`,
   `Enc.minDist_codeE`, `Enc.mca_third`. [ZK60Formal: this section is not ported.]

The mathematics of the first item is published. For two single words it is the lemma of Roth and
Zémor, printed by Ames, Hazay, Ishai and Venkitasubramaniam (ePrint 2022/1608, Appendix A) and
written out with its proof by Diamond and Posen (ePrint 2023/630, Theorem 2.1).
For interleaved words it is statement (20) of Angeris, Evans and Roh (ePrint 2024/1399), and Theorem
3.1 of Diamond and Gruen (ePrint 2024/1351) gives the step from words to interleaved words. None of
these is assumed here: everything is proved from the definitions, in the forms for sets of values
(`close_of_card`, `card_bad_le`) for every field, every subspace of words and every set of rows; the
counted forms take a finite field, and `MCA` ranges over finite sets of rows. No property of a
particular code enters.

The proof, in steps. A set of positions is large if it omits at most e positions.
Let Y be a set of values θ, and for each of them let f₀ + θ f₁ agree with words of the code on a
large set S_θ.
 1. Two different values in Y determine tables g₀, g₁ of words of the code with which f₀, f₁ agree
    on S_θ₁ ∩ S_θ₂ (`line_of_two`).
 2. For every θ, the words of the code with which f₀ + θ f₁ agrees on a large set are the rows of
    g₀ + θ g₁: the two agree on a set that omits at most 3 e < d positions (`meet_of_agree`).
 3. Call a position wrong if (f₀, f₁) differs there from (g₀, g₁) in some row. At a wrong position
    the two lines meet for at most one θ (`meet_unique`).
 4. Count the pairs of a value in Y and a wrong position of S_θ. Each value is in at least n_w - e
    pairs (n_w: the number of wrong positions) and each position in at most one.
    With e + 2 values this gives n_w ≤ e (`card_wrong_le`).
 5. (The mutual form.) If θ is bad, then S_θ contains a wrong position, since otherwise f₀ and f₁
    would agree with g₀ and g₁ on S_θ. By step 3 different bad values have different wrong
    positions. So there are at most n_w ≤ e bad values if there are at least e + 2, which is absurd
    (`card_le_card_wrong`, `card_bad_le`).

Against ArkLib's source at commit db7005f8: "ArkLib formalizes the
same lemma (AHIV22,
Lemma 4.4, for single words) in Data/CodingTheory/ProximityGap/AHIV22.lean by the same published
steps (Roth and Zémor; written out by Diamond and Posen)."
lean/CREDITS.md has ArkLib's entry.
-/
import Mathlib.LinearAlgebra.Dual.Lemmas
import Mathlib.LinearAlgebra.Matrix.ToLin
import Mathlib.LinearAlgebra.Span.Basic
import Mathlib.Algebra.Algebra.Bilinear
import Mathlib.Algebra.BigOperators.Pi
import Mathlib.Algebra.Order.BigOperators.Group.Finset
import Mathlib.Tactic.Linarith
import Mathlib.Tactic.LinearCombination
import Mathlib.Tactic.Abel
import ZK60Formal.ThirdParty.FlashProve.Prob.Count
import ZK60Formal.ThirdParty.FlashProve.Code.Agree

namespace Code

open Finset Prob

/-! ## Counting -/

section Counting

/-- If A omits at most a positions and B at most c, then their intersection omits at most a + c. -/
theorem card_inter_large {ι : Type} [Fintype ι] [DecidableEq ι] {A B : Finset ι} {a c : ℕ}
    (hA : Fintype.card ι ≤ A.card + a) (hB : Fintype.card ι ≤ B.card + c) :
    Fintype.card ι ≤ (A ∩ B).card + (a + c) := by
  have h1 := card_union_add_card_inter A B
  have h2 : (A ∪ B).card ≤ Fintype.card ι := card_le_univ _
  omega

/-- Counting pairs. Let P relate the elements of Y to those of W. If every element of Y is related
to at least k elements of W, and every element of W to at most one element of Y, then |Y| k ≤
|W|. -/
theorem card_mul_le_of_rows_cols {α β : Type*} (Y : Finset α) (W : Finset β) (P : α → β → Prop)
    (k : ℕ) (hrow : ∀ x ∈ Y, ∃ T ⊆ W, k ≤ T.card ∧ ∀ j ∈ T, P x j)
    (hcol : ∀ j ∈ W, ∀ x ∈ Y, ∀ y ∈ Y, P x j → P y j → x = y) : Y.card * k ≤ W.card := by
  classical
  have hrow' : ∀ x ∈ Y, k ≤ (W.filter (P x)).card := by
    intro x hx
    obtain ⟨T, hT, hk, hP⟩ := hrow x hx
    exact hk.trans (card_le_card fun j hj => mem_filter.mpr ⟨hT hj, hP j hj⟩)
  have hcol' : ∀ j ∈ W, (Y.filter fun x => P x j).card ≤ 1 := by
    intro j hj
    exact card_le_one.mpr fun x hx y hy =>
      hcol j hj x (mem_filter.mp hx).1 y (mem_filter.mp hy).1
        (mem_filter.mp hx).2 (mem_filter.mp hy).2
  have hdc : ∑ x ∈ Y, (W.filter (P x)).card = ∑ j ∈ W, (Y.filter fun x => P x j).card := by
    simp only [card_filter]
    exact sum_comm
  calc Y.card * k = ∑ _x ∈ Y, k := by rw [sum_const, smul_eq_mul]
    _ ≤ ∑ x ∈ Y, (W.filter (P x)).card := sum_le_sum hrow'
    _ = ∑ j ∈ W, (Y.filter fun x => P x j).card := hdc
    _ ≤ ∑ _j ∈ W, 1 := sum_le_sum hcol'
    _ = W.card := by simp

/-- The arithmetic at the end of the count. -/
theorem bad_le_of_count {s B e : ℕ} (hs : e + 2 ≤ s) (h : s * (B - e) ≤ B) : B ≤ e := by
  by_contra hB
  obtain ⟨j, rfl⟩ := Nat.exists_eq_add_of_le (Nat.succ_le_of_lt (not_le.mp hB))
  have h1 : e.succ + j - e = j + 1 := by omega
  rw [h1] at h
  have h2 : (e + 2) * (j + 1) ≤ s * (j + 1) := Nat.mul_le_mul_right _ hs
  nlinarith [Nat.zero_le (e * j)]

end Counting

variable {E ι : Type} [Field E] [Fintype ι]

/-! ## Distance and unique decoding -/

/-- A smaller number is also a lower bound for the distance. -/
theorem MinDist.mono {D : Submodule E (ι → E)} {d d' : ℕ} (h : MinDist D d) (hd : d' ≤ d) :
    MinDist D d' :=
  fun u hu hne => hd.trans (h u hu hne)

/-- A subcode has at least the distance of the code. -/
theorem MinDist.anti {D D' : Submodule E (ι → E)} {d : ℕ} (h : MinDist D d) (hD : D' ≤ D) :
    MinDist D' d :=
  fun u hu hne => h u (hD hu) hne

/-- Let the code have minimum distance at least d (`MinDist`). Two words of the code that agree on
more than n - d positions are equal. -/
theorem MinDist.eq_of_agree {D : Submodule E (ι → E)} {d : ℕ} (hd : MinDist D d)
    {u v : ι → E} (hu : u ∈ D) (hv : v ∈ D) {S : Finset ι}
    (hS : Fintype.card ι < S.card + d) (h : ∀ j ∈ S, u j = v j) : u = v := by
  by_contra hne
  have h1 := hd (u - v) (D.sub_mem hu hv) (sub_ne_zero.mpr hne)
  have h2 := cnt_add_card_le (P := fun j => (u - v) j ≠ 0) (S := S)
    (fun j hj hc => hc (by rw [Pi.sub_apply, h j hj, sub_self]))
  omega

/-- Unique decoding. If the code has minimum distance at least d (`MinDist`) and 2 e < d, then at
most one word of the code agrees with a given word on all but at most e positions. -/
theorem MinDist.decode_unique {D : Submodule E (ι → E)} {d e : ℕ} (hd : MinDist D d)
    (h2 : 2 * e < d) {f u v : ι → E} (hu : u ∈ D) (hv : v ∈ D) {S T : Finset ι}
    (hS : Fintype.card ι ≤ S.card + e) (hT : Fintype.card ι ≤ T.card + e)
    (hfu : ∀ j ∈ S, f j = u j) (hfv : ∀ j ∈ T, f j = v j) : u = v := by
  classical
  have hST := card_inter_large hS hT
  refine hd.eq_of_agree hu hv (S := S ∩ T) (by omega) fun j hj => ?_
  rw [← hfu j (mem_inter.mp hj).1, ← hfv j (mem_inter.mp hj).2]

/-- The interleaved word f, with rows indexed by R, is close to the interleaved code: on one common
set of all but at most e positions every row agrees with a word of the code D. The distance of
interleaved words counts columns. -/
def Close {R : Type*} (D : Submodule E (ι → E)) (e : ℕ) (f : R → ι → E) : Prop :=
  ∃ S : Finset ι, Fintype.card ι ≤ S.card + e ∧ ∀ a, f a ∈ agreeOn D S

/-- A close interleaved word agrees, on a common large set, with a table of words of the code. -/
theorem Close.exists_table {R : Type*} {D : Submodule E (ι → E)} {e : ℕ}
    {f : R → ι → E} (h : Close D e f) :
    ∃ (g : R → ι → E) (S : Finset ι),
      (∀ a, g a ∈ D) ∧ Fintype.card ι ≤ S.card + e ∧ ∀ j ∈ S, ∀ a, f a j = g a j := by
  obtain ⟨S, hS, hf⟩ := h
  choose g hg hfg using fun a => mem_agreeOn.mp (hf a)
  exact ⟨g, S, hg, hS, fun j hj a => hfg a j hj⟩

/-- If the code has minimum distance at least d (`MinDist`) and 2 e < d, then the table of words of
the code with which a close interleaved word agrees on a large set is unique. -/
theorem Close.unique {R : Type*} {D : Submodule E (ι → E)} {d e : ℕ} (hd : MinDist D d)
    (h2 : 2 * e < d) {f g g' : R → ι → E} (hg : ∀ a, g a ∈ D) (hg' : ∀ a, g' a ∈ D) {S T : Finset ι}
    (hS : Fintype.card ι ≤ S.card + e) (hT : Fintype.card ι ≤ T.card + e)
    (hfg : ∀ j ∈ S, ∀ a, f a j = g a j) (hfg' : ∀ j ∈ T, ∀ a, f a j = g' a j) : g = g' :=
  funext fun a =>
    hd.decode_unique h2 (hg a) (hg' a) hS hT (fun j hj => hfg j hj a) (fun j hj => hfg' j hj a)

/-- Any selection of rows of a close interleaved word is close. -/
theorem Close.comp {R R' : Type*} {D : Submodule E (ι → E)} {e : ℕ} {f : R → ι → E}
    (h : Close D e f) (σ : R' → R) : Close D e (f ∘ σ) := by
  obtain ⟨S, hS, hf⟩ := h
  exact ⟨S, hS, fun a => hf (σ a)⟩

/-- Every combination of the rows of a close interleaved word is close to the code. -/
theorem Close.comb {R : Type*} [Fintype R] {D : Submodule E (ι → E)} {e : ℕ} {f : R → ι → E}
    (h : Close D e f) (c : R → E) :
    Close D e (fun _ : Unit => ∑ a, c a • f a) := by
  obtain ⟨S, hS, hf⟩ := h
  exact ⟨S, hS, fun _ => Submodule.sum_mem _ fun a _ => Submodule.smul_mem _ _ (hf a)⟩

/-- If f₀ and f₁ together are close, then every point f₀ + θ f₁ of their line is close. -/
theorem Close.line {R : Type*} {D : Submodule E (ι → E)} {e : ℕ} {f₀ f₁ : R → ι → E}
    (h : Close D e (Sum.elim f₀ f₁)) (θ : E) :
    Close D e (fun a => f₀ a + θ • f₁ a) := by
  obtain ⟨S, hS, hf⟩ := h
  exact ⟨S, hS,
    fun a => Submodule.add_mem _ (hf (Sum.inl a)) (Submodule.smul_mem _ _ (hf (Sum.inr a)))⟩

/-- Two interleaved words together are close if and only if both have all rows on the code on one
common large set. -/
theorem close_sumElim_iff {R : Type*} {D : Submodule E (ι → E)} {e : ℕ} {f₀ f₁ : R → ι → E} :
    Close D e (Sum.elim f₀ f₁) ↔
    ∃ S : Finset ι,
      Fintype.card ι ≤ S.card + e ∧ (∀ a, f₀ a ∈ agreeOn D S) ∧ ∀ a, f₁ a ∈ agreeOn D S := by
  constructor
  · rintro ⟨S, hS, hf⟩
    exact ⟨S, hS, fun a => hf (Sum.inl a), fun a => hf (Sum.inr a)⟩
  · rintro ⟨S, hS, h₀, h₁⟩
    refine ⟨S, hS, fun a => ?_⟩
    cases a with
    | inl a => exact h₀ a
    | inr a => exact h₁ a

/-! ## Two lines of interleaved words -/

section Lines

variable {R : Type*}

/-- At the position j, the line through f₀, f₁ and the line through g₀, g₁ have the same value at θ,
in every row. -/
def MeetAt (f₀ f₁ g₀ g₁ : R → ι → E) (θ : E) (j : ι) : Prop :=
  ∀ a, f₀ a j + θ * f₁ a j = g₀ a j + θ * g₁ a j

/-- The position j is wrong: in some row, (f₀, f₁) differs there from (g₀, g₁). -/
def WrongAt (f₀ f₁ g₀ g₁ : R → ι → E) (j : ι) : Prop :=
  ¬ ∀ a, f₀ a j = g₀ a j ∧ f₁ a j = g₁ a j

omit [Fintype ι] in
/-- If (a₀, a₁) ≠ (c₀, c₁), then a₀ + x a₁ = c₀ + x c₁ holds for at most one x. -/
theorem line_root_unique {a₀ a₁ c₀ c₁ x y : E} (hbad : ¬ (a₀ = c₀ ∧ a₁ = c₁))
    (hx : a₀ + x * a₁ = c₀ + x * c₁) (hy : a₀ + y * a₁ = c₀ + y * c₁) : x = y := by
  by_contra hne
  have h1 : (x - y) * (a₁ - c₁) = 0 := by linear_combination hx - hy
  have hd : a₁ - c₁ = 0 := (mul_eq_zero.mp h1).resolve_left (sub_ne_zero.mpr hne)
  have h0 : a₀ = c₀ := by linear_combination hx - x * hd
  exact hbad ⟨h0, sub_eq_zero.mp hd⟩

omit [Fintype ι] in
/-- (Step 3.) At a wrong position the two lines meet for at most one value. -/
theorem meet_unique {f₀ f₁ g₀ g₁ : R → ι → E} {j : ι} (hw : WrongAt f₀ f₁ g₀ g₁ j) {x y : E}
    (hx : MeetAt f₀ f₁ g₀ g₁ x j) (hy : MeetAt f₀ f₁ g₀ g₁ y j) : x = y := by
  obtain ⟨a, ha⟩ := not_forall.mp hw
  exact line_root_unique ha (hx a) (hy a)

omit [Fintype ι] in
/-- (Step 1.) Two values determine the line. If f₀ + x₁ f₁ has its rows on the code on S₁ and f₀ +
x₂ f₁ on S₂, with x₁ ≠ x₂, then there are tables g₀, g₁ of words of the code with which f₀ and f₁
agree at all common positions of S₁ and S₂. -/
theorem line_of_two {D : Submodule E (ι → E)} (f₀ f₁ : R → ι → E) {x₁ x₂ : E} (hne : x₁ ≠ x₂)
    {S₁ S₂ : Finset ι} (h₁ : ∀ a, f₀ a + x₁ • f₁ a ∈ agreeOn D S₁)
    (h₂ : ∀ a, f₀ a + x₂ • f₁ a ∈ agreeOn D S₂) :
    ∃ g₀ g₁ : R → ι → E,
      (∀ a, g₀ a ∈ D) ∧ (∀ a, g₁ a ∈ D) ∧
      ∀ j, j ∈ S₁ → j ∈ S₂ → ∀ a, f₀ a j = g₀ a j ∧ f₁ a j = g₁ a j := by
  choose c₁ hc₁ ha₁ using fun a => mem_agreeOn.mp (h₁ a)
  choose c₂ hc₂ ha₂ using fun a => mem_agreeOn.mp (h₂ a)
  have hd : x₂ - x₁ ≠ 0 := sub_ne_zero.mpr hne.symm
  have hg₁ : ∀ a, (x₂ - x₁)⁻¹ • (c₂ a - c₁ a) ∈ D := fun a =>
    D.smul_mem _ (D.sub_mem (hc₂ a) (hc₁ a))
  refine ⟨fun a => c₁ a - x₁ • ((x₂ - x₁)⁻¹ • (c₂ a - c₁ a)), fun a => (x₂ - x₁)⁻¹ • (c₂ a - c₁ a),
    fun a => D.sub_mem (hc₁ a) (D.smul_mem _ (hg₁ a)), hg₁, fun j hj₁ hj₂ a => ?_⟩
  have e₁ : f₀ a j + x₁ * f₁ a j = c₁ a j := ha₁ a j hj₁
  have e₂ : f₀ a j + x₂ * f₁ a j = c₂ a j := ha₂ a j hj₂
  have key : (x₂ - x₁)⁻¹ * (c₂ a j - c₁ a j) = f₁ a j := by
    rw [← e₁, ← e₂, show f₀ a j + x₂ * f₁ a j - (f₀ a j + x₁ * f₁ a j) = (x₂ - x₁) * f₁ a j by ring,
      inv_mul_cancel_left₀ hd]
  simp only [Pi.sub_apply, Pi.smul_apply, smul_eq_mul]
  rw [key, ← e₁]
  exact ⟨by ring, rfl⟩

/-- (Step 2.) Every close point lies on the line. Let f₀, f₁ agree with tables g₀, g₁ of words of
the code on a set that omits at most k positions, let the code have minimum distance at least d
(`MinDist`), and let k + e < d. If the rows of f₀ + θ f₁ are on the code on a set S that omits at
most e positions, then on S they are the rows of g₀ + θ g₁. -/
theorem meet_of_agree {D : Submodule E (ι → E)} {d k e : ℕ} (hd : MinDist D d) (hke : k + e < d)
    {f₀ f₁ g₀ g₁ : R → ι → E} (hg₀ : ∀ a, g₀ a ∈ D) (hg₁ : ∀ a, g₁ a ∈ D) {A : Finset ι}
    (hA : Fintype.card ι ≤ A.card + k) (hag : ∀ j ∈ A, ∀ a, f₀ a j = g₀ a j ∧ f₁ a j = g₁ a j)
    {θ : E} {S : Finset ι} (hS : Fintype.card ι ≤ S.card + e)
    (h : ∀ a, f₀ a + θ • f₁ a ∈ agreeOn D S) :
    ∀ j ∈ S, MeetAt f₀ f₁ g₀ g₁ θ j := by
  classical
  intro j hj a
  obtain ⟨c, hc, hfc⟩ := mem_agreeOn.mp (h a)
  have hAS := card_inter_large hA hS
  have hcg : c = g₀ a + θ • g₁ a := by
    refine hd.eq_of_agree hc (D.add_mem (hg₀ a) (D.smul_mem _ (hg₁ a))) (S := A ∩ S)
      (by omega) fun i hi => ?_
    rw [← hfc i (mem_inter.mp hi).2]
    simp only [Pi.add_apply, Pi.smul_apply, smul_eq_mul]
    rw [(hag i (mem_inter.mp hi).1 a).1, (hag i (mem_inter.mp hi).1 a).2]
  have := hfc j hj
  rw [hcg] at this
  exact this

/-- (Step 4.) Few wrong positions. Let W be a set of wrong positions. If for at least e + 2 values θ
the two lines meet on a set that omits at most e positions, then W has at most e elements. -/
theorem card_wrong_le {f₀ f₁ g₀ g₁ : R → ι → E} {e : ℕ} {W : Finset ι}
    (hW : ∀ j ∈ W, WrongAt f₀ f₁ g₀ g₁ j) {Y : Finset E} (hY : e + 2 ≤ Y.card)
    (h : ∀ θ ∈ Y, ∃ S : Finset ι, Fintype.card ι ≤ S.card + e ∧ ∀ j ∈ S, MeetAt f₀ f₁ g₀ g₁ θ j) :
    W.card ≤ e := by
  classical
  refine bad_le_of_count hY (card_mul_le_of_rows_cols Y W (MeetAt f₀ f₁ g₀ g₁) (W.card - e) ?_ ?_)
  · intro θ hθ
    obtain ⟨S, hS, hm⟩ := h θ hθ
    refine ⟨W ∩ S, inter_subset_left, ?_, fun j hj => hm j (mem_inter.mp hj).2⟩
    have h1 : W ⊆ (W ∩ S) ∪ Sᶜ := by
      intro j hj
      by_cases hjS : j ∈ S
      · exact mem_union_left _ (mem_inter.mpr ⟨hj, hjS⟩)
      · exact mem_union_right _ (mem_compl.mpr hjS)
    have h2 := (card_le_card h1).trans (card_union_le _ _)
    rw [card_compl] at h2
    omega
  · intro j hj x _ y _ hx hy
    exact meet_unique (hW j hj) hx hy

omit [Fintype ι] in
/-- (Step 5.) If for every value in Y the two lines meet at some wrong position of W, then Y has at
most as many elements as W. -/
theorem card_le_card_wrong {f₀ f₁ g₀ g₁ : R → ι → E} {W : Finset ι}
    (hW : ∀ j ∈ W, WrongAt f₀ f₁ g₀ g₁ j) {Y : Finset E}
    (h : ∀ θ ∈ Y, ∃ j ∈ W, MeetAt f₀ f₁ g₀ g₁ θ j) : Y.card ≤ W.card := by
  have h1 := card_mul_le_of_rows_cols Y W (MeetAt f₀ f₁ g₀ g₁) 1
    (fun θ hθ => by
      obtain ⟨j, hj, hm⟩ := h θ hθ
      exact ⟨{j}, singleton_subset_iff.mpr hj, by simp,
        fun i hi => by rw [mem_singleton.mp hi]; exact hm⟩)
    (fun j hj x _ y _ hx hy => meet_unique (hW j hj) hx hy)
  rwa [mul_one] at h1

end Lines

/-! ## Every linear code, up to a third of its distance -/

section Third

variable {R : Type*} {D : Submodule E (ι → E)} {d e : ℕ}

/-- Steps 1 to 4 together. Let 3 e < d, as in `close_of_card`, and let f₀ + θ f₁ be close for at
least e + 2 values θ. Then there are tables g₀, g₁ of words of the code such that
(i) at most e positions are wrong, and (ii) whenever the rows of f₀ + θ f₁ are on the code on a
    large set S, they are on S the rows of g₀ + θ g₁. -/
theorem exists_line_of_card (hd : MinDist D d) (h3 : 3 * e < d) (f₀ f₁ : R → ι → E) {Y : Finset E}
    (hY : e + 2 ≤ Y.card) (h : ∀ θ ∈ Y, Close D e (fun a => f₀ a + θ • f₁ a)) :
    ∃ (g₀ g₁ : R → ι → E) (W : Finset ι),
      (∀ a, g₀ a ∈ D) ∧ (∀ a, g₁ a ∈ D) ∧
      (∀ j, j ∈ W ↔ WrongAt f₀ f₁ g₀ g₁ j) ∧
      W.card ≤ e ∧
      ∀ (θ : E) (S : Finset ι), Fintype.card ι ≤ S.card + e →
        (∀ a, f₀ a + θ • f₁ a ∈ agreeOn D S) → ∀ j ∈ S, MeetAt f₀ f₁ g₀ g₁ θ j := by
  classical
  obtain ⟨x₁, hx₁, x₂, hx₂, hne⟩ := one_lt_card.mp (by omega : 1 < Y.card)
  obtain ⟨S₁, hS₁, h₁⟩ := h x₁ hx₁
  obtain ⟨S₂, hS₂, h₂⟩ := h x₂ hx₂
  obtain ⟨g₀, g₁, hg₀, hg₁, hag⟩ := line_of_two f₀ f₁ hne h₁ h₂
  have hA : Fintype.card ι ≤ (S₁ ∩ S₂).card + 2 * e := by
    have := card_inter_large hS₁ hS₂
    omega
  have hmeet : ∀ (θ : E) (S : Finset ι), Fintype.card ι ≤ S.card + e →
      (∀ a, f₀ a + θ • f₁ a ∈ agreeOn D S) → ∀ j ∈ S, MeetAt f₀ f₁ g₀ g₁ θ j := fun θ S hS hθ =>
    meet_of_agree hd (by omega : 2 * e + e < d) hg₀ hg₁ hA
      (fun j hj => hag j (mem_inter.mp hj).1 (mem_inter.mp hj).2) hS hθ
  refine ⟨g₀, g₁, univ.filter (WrongAt f₀ f₁ g₀ g₁), hg₀, hg₁, fun j => by simp, ?_, hmeet⟩
  refine card_wrong_le (fun j hj => (mem_filter.mp hj).2) hY fun θ hθ => ?_
  obtain ⟨S, hS, hθS⟩ := h θ hθ
  exact ⟨S, hS, hmeet θ S hS hθS⟩

/-- If f₀, f₁ differ from tables g₀, g₁ of words of the code at no more than e positions, then f₀
and f₁ together are close. -/
theorem close_of_wrong {f₀ f₁ g₀ g₁ : R → ι → E} (hg₀ : ∀ a, g₀ a ∈ D) (hg₁ : ∀ a, g₁ a ∈ D)
    {W : Finset ι} (hW : ∀ j, WrongAt f₀ f₁ g₀ g₁ j → j ∈ W) (hWe : W.card ≤ e) :
    Close D e (Sum.elim f₀ f₁) := by
  classical
  have hgood : ∀ j ∈ Wᶜ, ∀ a, f₀ a j = g₀ a j ∧ f₁ a j = g₁ a j := by
    intro j hj
    by_contra hc
    exact (mem_compl.mp hj) (hW j hc)
  refine close_sumElim_iff.mpr ⟨Wᶜ, ?_, fun a => ⟨g₀ a, hg₀ a, fun j hj => (hgood j hj a).1⟩,
    fun a => ⟨g₁ a, hg₁ a, fun j hj => (hgood j hj a).2⟩⟩
  have := card_le_univ W
  rw [card_compl]
  omega

/-- Plain form (correlated agreement), for sets of values. Let every non-zero word of the code have
at least d non-zero symbols, and let 3 e < d.
If f₀ + θ f₁ is close to the interleaved code for at least e + 2 values θ, then f₀ and f₁ together
are close to it. The field may be infinite, and the number of rows does not enter. -/
theorem close_of_card (hd : MinDist D d) (h3 : 3 * e < d) (f₀ f₁ : R → ι → E) {Y : Finset E}
    (hY : e + 2 ≤ Y.card) (h : ∀ θ ∈ Y, Close D e (fun a => f₀ a + θ • f₁ a)) :
    Close D e (Sum.elim f₀ f₁) := by
  obtain ⟨g₀, g₁, W, hg₀, hg₁, hW, hWe, -⟩ := exists_line_of_card hd h3 f₀ f₁ hY h
  exact close_of_wrong hg₀ hg₁ (fun j => (hW j).mpr) hWe

/-- (Step 5, in full.) Let g₀, g₁ be tables of words of the code, let W be the set of wrong
positions, and suppose that whenever the rows of f₀ + θ f₁ are on the code on a large set S, they
are on S the rows of g₀ + θ g₁. Then there are at most |W| bad values θ. -/
theorem card_bad_le_card_wrong {f₀ f₁ g₀ g₁ : R → ι → E} (hg₀ : ∀ a, g₀ a ∈ D) (hg₁ : ∀ a, g₁ a ∈ D)
    {W : Finset ι} (hW : ∀ j, j ∈ W ↔ WrongAt f₀ f₁ g₀ g₁ j)
    (hmeet : ∀ (θ : E) (S : Finset ι), Fintype.card ι ≤ S.card + e →
      (∀ a, f₀ a + θ • f₁ a ∈ agreeOn D S) → ∀ j ∈ S, MeetAt f₀ f₁ g₀ g₁ θ j)
    (Y : Finset E)
    (h : ∀ θ ∈ Y, ∃ S : Finset ι,
      Fintype.card ι ≤ S.card + e ∧
      (∀ a, f₀ a + θ • f₁ a ∈ agreeOn D S) ∧
      ¬ ((∀ a, f₀ a ∈ agreeOn D S) ∧ ∀ a, f₁ a ∈ agreeOn D S)) : Y.card ≤ W.card := by
  refine card_le_card_wrong (fun j hj => (hW j).mp hj) fun θ hθ => ?_
  obtain ⟨S, hS, hl, hn⟩ := h θ hθ
  by_contra hno
  have hgood : ∀ j ∈ S, ∀ a, f₀ a j = g₀ a j ∧ f₁ a j = g₁ a j := by
    intro j hj
    by_contra hc
    exact hno ⟨j, (hW j).mpr hc, hmeet θ S hS hl j hj⟩
  exact hn ⟨fun a => ⟨g₀ a, hg₀ a, fun j hj => (hgood j hj a).1⟩,
    fun a => ⟨g₁ a, hg₁ a, fun j hj => (hgood j hj a).2⟩⟩

/-- Mutual form, for sets of values. Let 3 e < d, as in `close_of_card`. Call θ bad if there is a
set S of all but at most e positions on which all rows of f₀ + θ f₁ agree with words of the code,
while not all rows of f₀ and f₁ do. Every finite set of bad values has at most e + 1 elements. The
field may be infinite. -/
theorem card_bad_le (hd : MinDist D d) (h3 : 3 * e < d) (f₀ f₁ : R → ι → E) (Y : Finset E)
    (h : ∀ θ ∈ Y, ∃ S : Finset ι, Fintype.card ι ≤ S.card + e ∧ (∀ a, f₀ a + θ • f₁ a ∈ agreeOn D S)
      ∧ ¬ ((∀ a, f₀ a ∈ agreeOn D S) ∧ ∀ a, f₁ a ∈ agreeOn D S)) : Y.card ≤ e + 1 := by
  by_contra hcon
  have hY : e + 2 ≤ Y.card := by omega
  obtain ⟨g₀, g₁, W, hg₀, hg₁, hW, hWe, hmeet⟩ := exists_line_of_card hd h3 f₀ f₁ hY
    (fun θ hθ => by
      obtain ⟨S, hS, hl, -⟩ := h θ hθ
      exact ⟨S, hS, hl⟩)
  have hle : Y.card ≤ W.card := card_bad_le_card_wrong hg₀ hg₁ hW hmeet Y h
  omega

/-- Plain form, as a count. Let 3 e < d, as in `close_of_card`. If f₀ and f₁ together are not close
to the interleaved code, then f₀ + θ f₁ is close to it for at most e + 1 values θ. -/
theorem cnt_close_le [Finite E] (hd : MinDist D d) (h3 : 3 * e < d)
    (f₀ f₁ : R → ι → E) (h : ¬ Close D e (Sum.elim f₀ f₁)) :
    cnt (fun θ : E => Close D e (fun a => f₀ a + θ • f₁ a)) ≤ e + 1 := by
  refine cnt_le_of_forall_finset fun Y hY => ?_
  by_contra hcon
  exact h (close_of_card hd h3 f₀ f₁ (by omega) hY)

/-- Let every non-zero word of the code D have at least d non-zero symbols, and let 3 e < d.
Then D has mutual correlated agreement on lines at the radius e with at most e + 1 bad values, for
any number of interleaved rows. -/
theorem mca_third [Finite E] (hd : MinDist D d) (h3 : 3 * e < d) : MCA D e (e + 1) :=
  fun _ _ f₀ f₁ => cnt_le_of_forall_finset fun Y hY => card_bad_le hd h3 f₀ f₁ Y hY

/-- Mutual correlated agreement for the line in the form (1 - θ) f₀ + θ f₁, with the same count. -/
theorem MCA.fold [Finite E] {bad : ℕ} (h : MCA D e bad) (R : Type) [Finite R] (f₀ f₁ : R → ι → E) :
    cnt (fun θ : E =>
        ∃ S : Finset ι,
          Fintype.card ι ≤ S.card + e ∧
          (∀ a, (1 - θ) • f₀ a + θ • f₁ a ∈ agreeOn D S) ∧
          ¬ ((∀ a, f₀ a ∈ agreeOn D S) ∧ ∀ a, f₁ a ∈ agreeOn D S)) ≤ bad := by
  refine (cnt_mono ?_).trans (h R f₀ (fun a => f₁ a - f₀ a))
  rintro θ ⟨S, hS, hl, hn⟩
  refine ⟨S, hS, fun a => ?_, fun hb => hn ⟨hb.1, fun a => ?_⟩⟩
  · have h1 : f₀ a + θ • (f₁ a - f₀ a) = (1 - θ) • f₀ a + θ • f₁ a := by
      rw [smul_sub, sub_smul, one_smul]
      abel
    rw [h1]
    exact hl a
  · have h1 := (agreeOn D S).add_mem (hb.2 a) (hb.1 a)
    rwa [sub_add_cancel] at h1

end Third

/-! ## The extension code -/

section Extension

variable {F : Type} [Field F] [Algebra F E]

/-- A vector over the small field F, read over the large field E. -/
def liftWord (E : Type) [Field E] [Algebra F E] {X : Type*} (u : X → F) : X → E := fun j =>
  algebraMap F E (u j)

/-- The extension code: the span over E of the words of a code over F. -/
def extendCode (E : Type) [Field E] [Algebra F E] (C : Submodule F (ι → F)) : Submodule E (ι → E) :=
  Submodule.span E (liftWord E '' (C : Set (ι → F)))

omit [Fintype ι] in
/-- A word of the code, read over E, is a word of the extension code. -/
theorem liftWord_mem_extendCode {C : Submodule F (ι → F)} {u : ι → F} (hu : u ∈ C) :
    liftWord E u ∈ extendCode E C :=
  Submodule.subset_span ⟨u, hu, rfl⟩

omit [Fintype ι] in
/-- An F-linear form on E, applied to every symbol of a word of the extension code, gives a word of
the code. -/
theorem form_comp_mem {C : Submodule F (ι → F)} {w : ι → E} (hw : w ∈ extendCode E C) :
    ∀ φ : E →ₗ[F] F, (fun j => φ (w j)) ∈ C := by
  unfold extendCode at hw
  induction hw using Submodule.span_induction with
  | mem x hx =>
    intro φ
    obtain ⟨u, hu, rfl⟩ := hx
    have h1 : (fun j => φ (liftWord E u j)) = φ 1 • u := by
      funext j
      simp only [liftWord, Pi.smul_apply, smul_eq_mul]
      rw [Algebra.algebraMap_eq_smul_one, map_smul, smul_eq_mul, mul_comm]
    rw [h1]
    exact C.smul_mem _ hu
  | zero =>
    intro φ
    have h1 : (fun j => φ ((0 : ι → E) j)) = 0 := by
      funext j
      simp
    rw [h1]
    exact C.zero_mem
  | add x y _ _ hx hy =>
    intro φ
    have h1 : (fun j => φ ((x + y) j)) = (fun j => φ (x j)) + fun j => φ (y j) := by
      funext j
      simp
    rw [h1]
    exact C.add_mem (hx φ) (hy φ)
  | smul c x _ hx =>
    intro φ
    exact hx (φ.comp (LinearMap.mulLeft F c))

/-- The extension code keeps every lower bound on the distance. -/
theorem MinDist.extendCode {C : Submodule F (ι → F)} {d : ℕ} (hd : MinDist C d) :
    MinDist (extendCode E C) d := by
  intro w hw hne
  obtain ⟨i, hi⟩ := Function.ne_iff.mp hne
  obtain ⟨φ, hφ⟩ := Module.Projective.exists_dual_ne_zero F hi
  have hne' : (fun j => φ (w j)) ≠ 0 := fun h0 => hφ (congrFun h0 i)
  refine (hd _ (form_comp_mem hw φ) hne').trans (cnt_mono fun j hj hz => hj ?_)
  show φ (w j) = 0
  rw [hz, map_zero]

variable {κ : Type} [Fintype κ]

omit [Fintype ι] in
/-- The generator matrix over E, applied to a vector over F, gives the word over F, read over E. -/
theorem mulVec_map_liftWord (G : Matrix ι κ F) (v : κ → F) :
    (G.map (algebraMap F E)).mulVec (liftWord E v) = liftWord E (G.mulVec v) := by
  funext j
  simp only [liftWord, Matrix.mulVec, dotProduct, Matrix.map_apply, map_sum, map_mul]

omit [Fintype ι] in
/-- The extension code is the range of the same generator matrix over E. -/
theorem range_mulVecLin_map (G : Matrix ι κ F) :
    LinearMap.range (G.map (algebraMap F E)).mulVecLin =
      extendCode E (LinearMap.range G.mulVecLin) := by
  classical
  apply le_antisymm
  · rintro _ ⟨v, rfl⟩
    have h1 : (G.map (algebraMap F E)).mulVecLin v =
        ∑ i, v i • liftWord E (G.mulVecLin (Pi.single i 1)) := by
      funext j
      simp only [Matrix.mulVecLin_apply, Matrix.mulVec_single_one, Finset.sum_apply, Pi.smul_apply,
        smul_eq_mul, liftWord, Matrix.mulVec, dotProduct, Matrix.map_apply, Matrix.col_apply]
      exact Finset.sum_congr rfl fun i _ => mul_comm _ _
    rw [h1]
    exact Submodule.sum_mem _ fun i _ => Submodule.smul_mem _ _ (liftWord_mem_extendCode ⟨_, rfl⟩)
  · refine Submodule.span_le.mpr ?_
    rintro _ ⟨_, ⟨v, rfl⟩, rfl⟩
    exact ⟨liftWord E v, mulVec_map_liftWord G v⟩

omit [Fintype ι] in
/-- An F-linear form on E, applied to every symbol of the image of v under the generator over E,
gives the image under the generator over F of the vector to whose entries the form is applied. -/
theorem form_mulVec_map (G : Matrix ι κ F) (φ : E →ₗ[F] F) (v : κ → E) (j : ι) :
    φ ((G.map (algebraMap F E)).mulVec v j) = G.mulVec (fun i => φ (v i)) j := by
  simp only [Matrix.mulVec, dotProduct, Matrix.map_apply, map_sum]
  refine Finset.sum_congr rfl fun i _ => ?_
  rw [← Algebra.smul_def, map_smul, smul_eq_mul]

/-- The generator over E keeps the distance: if every non-zero vector over F has an image with at
least d non-zero symbols, then so has every non-zero vector over E. -/
theorem dist_mulVec_map {G : Matrix ι κ F} {d : ℕ}
    (h : ∀ v : κ → F, v ≠ 0 → d ≤ cnt (fun j => G.mulVec v j ≠ 0)) (v : κ → E) (hv : v ≠ 0) :
    d ≤ cnt (fun j => (G.map (algebraMap F E)).mulVec v j ≠ 0) := by
  obtain ⟨i, hi⟩ := Function.ne_iff.mp hv
  obtain ⟨φ, hφ⟩ := Module.Projective.exists_dual_ne_zero F hi
  have hne : (fun i => φ (v i)) ≠ 0 := fun h0 => hφ (congrFun h0 i)
  refine (h _ hne).trans (cnt_mono fun j hj hz => hj ?_)
  rw [← form_mulVec_map, hz, map_zero]

/-- The distance of a code that is given by a generator matrix: if every non-zero vector has an
image with at least d non-zero symbols, then so has every non-zero word of the range. -/
theorem minDist_range_mulVecLin
    {G : Matrix ι κ F} {d : ℕ} (h : ∀ v : κ → F, v ≠ 0 → d ≤ cnt (fun j => G.mulVec v j ≠ 0)) :
    MinDist (LinearMap.range G.mulVecLin) d := by
  rintro _ ⟨v, rfl⟩ hne
  refine h v ?_
  rintro rfl
  exact hne (map_zero _)

/-- `mca_third` holds for a code that is given by a generator matrix over the small field F, with
interleaved words and values θ over the large, finite field E, if every non-zero vector over F has
an image with at least d non-zero symbols and 3 e < d. -/
theorem mca_third_of_matrix [Finite E] {G : Matrix ι κ F} {d e : ℕ}
    (h : ∀ v : κ → F, v ≠ 0 → d ≤ cnt (fun j => G.mulVec v j ≠ 0)) (h3 : 3 * e < d) :
    MCA (LinearMap.range (G.map (algebraMap F E)).mulVecLin) e (e + 1) := by
  rw [range_mulVecLin_map]
  exact mca_third (minDist_range_mulVecLin h).extendCode h3

end Extension
end Code
