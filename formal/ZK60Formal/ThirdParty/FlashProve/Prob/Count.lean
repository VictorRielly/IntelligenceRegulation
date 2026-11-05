-- Copyright 2026 Anthropic PBC
-- SPDX-License-Identifier: Apache-2.0
-- Modified for ZK60Formal (IntelligenceRegulation), 2026-11-04: module paths renamed under
-- ZK60Formal.ThirdParty.FlashProve; cut to part 1 (counts), the only part the ported Code/ files
-- use: the definitions `prod`, `joint` and parts 2 to 5 (averages, event probabilities, pairs, the
-- adapter, among them `expect_comm`, the declaration shared with VCV-io) are removed, and with them
-- the import of Prob.Basic (replaced by Prob.Cnt, which it imported). The header below is the
-- original's.
/-
Prob/Count.lean: discrete probability on Mathlib's PMF, and the adapter between counts and
probabilities.

The errors of the interactive oracle proof and of the code are stated as "at most k of the |C|
values of the challenge are bad", while the definition of the argument system in the random oracle
model (ZKCP/Defs.lean) is stated in probabilities. This file has the elementary probability that
both sides share and the conversion between them (the adapter), for C finite and non-empty:

    cnt P ≤ k   ↔   Pr[ P c | c ← C uniform ] ≤ k / |C|            (pr_unif_le_iff_cnt_le)

No oracle, field, code or protocol occurs here: everything is stated on Mathlib's types.

Contents
  1. counts: union bounds, products, bijections                     (cnt_*)
  2. averages E[F(a) | a ← p]                                        (expect_*)
  3. event probabilities Pr[a ∈ E | a ← p]: union bounds, Markov     (pr_*)
  4. pairs, dependent and independent                               (joint, prod)
  5. the adapter: uniform distributions are counts                  (*_unif*)

Shared with VCV-io (`expect_comm`): lean/CREDITS.md, section 4.
-/
import Mathlib.Probability.ProbabilityMassFunction.Constructions
import Mathlib.Probability.Distributions.Uniform
import Mathlib.Data.Fintype.BigOperators
import Mathlib.Data.Fintype.Pi
import Mathlib.Data.Fintype.Prod
import Mathlib.Logic.Equiv.Prod
import Mathlib.Tactic.Ring
import ZK60Formal.ThirdParty.FlashProve.Prob.Cnt
noncomputable section -- Lean tags what it cannot compile

open scoped ENNReal

namespace Prob

universe u v w
variable {α : Type u} {β : Type v} {γ : Type w}

/-! ## 1. Counts -/

section Counts
open Finset
variable {C D ι : Type}

/-- cnt is the cardinality of the filtered set, for every enumeration and every decision
procedure. -/
theorem cnt_eq_card_filter [Fintype C] (P : C → Prop) [DecidablePred P] :
    cnt P = (univ.filter P).card := by
  unfold cnt
  rw [Nat.card_eq_fintype_card, Fintype.card_subtype]

theorem cnt_congr [Finite C] {P Q : C → Prop} (h : ∀ c, P c ↔ Q c) : cnt P = cnt Q := by
  have : P = Q := funext fun c => propext (h c)
  rw [this]

theorem cnt_le_card [Fintype C] (P : C → Prop) : cnt P ≤ Fintype.card C := by
  classical
  rw [cnt_eq_card_filter]
  exact card_le_univ _

theorem cnt_true [Fintype C] : cnt (fun _ : C => True) = Fintype.card C := by
  classical
  rw [cnt_eq_card_filter]
  simp

/-- To bound a count by k it suffices to bound by k every finite set of elements with the
property. -/
theorem cnt_le_of_forall_finset [Finite C] {P : C → Prop} {k : ℕ}
    (h : ∀ Y : Finset C, (∀ x ∈ Y, P x) → Y.card ≤ k) : cnt P ≤ k := by
  classical
  cases nonempty_fintype C
  rw [cnt_eq_card_filter]
  exact h _ (fun x hx => (mem_filter.mp hx).2)

/-- A finite set of elements with the property has at most as many elements as the count. -/
theorem card_le_cnt [Finite C] {P : C → Prop} (Y : Finset C) (h : ∀ x ∈ Y, P x) :
    Y.card ≤ cnt P := by
  classical
  cases nonempty_fintype C
  rw [cnt_eq_card_filter]
  exact card_le_card fun x hx => mem_filter.mpr ⟨mem_univ x, h x hx⟩

/-- A property that fails on the set S holds of at most |C| - |S| elements. -/
theorem cnt_add_card_le [Fintype C] {P : C → Prop} {S : Finset C} (h : ∀ j ∈ S, ¬ P j) :
    cnt P + S.card ≤ Fintype.card C := by
  classical
  rw [cnt_eq_card_filter]
  have hdis : Disjoint (univ.filter P) S :=
    Finset.disjoint_left.mpr fun j hj hS => h j hS (mem_filter.mp hj).2
  rw [← card_union_of_disjoint hdis]
  exact card_le_univ _

/-- A property and its negation partition the type. -/
theorem cnt_add_cnt_not [Fintype C] (P : C → Prop) :
    cnt P + cnt (fun c => ¬ P c) = Fintype.card C := by
  classical
  rw [cnt_eq_card_filter, cnt_eq_card_filter]
  exact card_filter_add_card_filter_not (s := univ) P

/-- Union bound for two bad sets of one challenge. -/
theorem cnt_or_le [Fintype C] (P Q : C → Prop) : cnt (fun c => P c ∨ Q c) ≤ cnt P + cnt Q := by
  classical
  rw [cnt_eq_card_filter, cnt_eq_card_filter, cnt_eq_card_filter, filter_or]
  exact card_union_le _ _

/-- Union bound in the form in which it is used: whatever is bad is bad for one of two reasons. -/
theorem cnt_le_add [Fintype C] {P Q R : C → Prop} (h : ∀ c, P c → Q c ∨ R c) :
    cnt P ≤ cnt Q + cnt R :=
  (cnt_mono h).trans (cnt_or_le Q R)

/-- Union bound over a finite family of bad sets of one challenge. -/
theorem cnt_exists_le [Fintype C] [Fintype ι] (P : ι → C → Prop) :
    cnt (fun c => ∃ i, P i c) ≤ ∑ i, cnt (P i) := by
  classical
  simp only [cnt_eq_card_filter]
  have : (univ.filter fun c => ∃ i, P i c) = univ.biUnion fun i => univ.filter (P i) := by
    ext c; simp
  rw [this]
  exact card_biUnion_le

/-- Union bound over a finite set of indices. -/
theorem cnt_exists_mem_le [Fintype C] (s : Finset ι) (P : ι → C → Prop) :
    cnt (fun c => ∃ i ∈ s, P i c) ≤ ∑ i ∈ s, cnt (P i) := by
  classical
  simp only [cnt_eq_card_filter]
  have : (univ.filter fun c => ∃ i ∈ s, P i c) = s.biUnion fun i => univ.filter (P i) := by
    ext c; simp
  rw [this]
  exact card_biUnion_le

/-- Union bound with the same bound k for each member of the family. -/
theorem cnt_exists_le_mul [Fintype C] [Fintype ι] (P : ι → C → Prop)
    (k : ℕ) (h : ∀ i, cnt (P i) ≤ k) :
    cnt (fun c => ∃ i, P i c) ≤ Fintype.card ι * k :=
  (cnt_exists_le P).trans ((sum_le_sum fun i _ => h i).trans (by simp))

/-- A property that holds of at most one value has count at most 1. -/
theorem cnt_le_one [Fintype C] {P : C → Prop} (h : ∀ a b, P a → P b → a = b) : cnt P ≤ 1 := by
  classical
  rw [cnt_eq_card_filter, card_le_one]
  intro a ha b hb
  simp only [mem_filter, mem_univ, true_and] at ha hb
  exact h a b ha hb

theorem cnt_eq_const [Fintype C] (v : C) : cnt (fun c => c = v) = 1 := by
  classical
  rw [cnt_eq_card_filter, filter_eq' univ v]
  simp

/-- cnt is invariant under a bijection of the challenge space. -/
theorem cnt_equiv [Fintype C] [Fintype D] (e : C ≃ D) (P : D → Prop) :
    cnt (fun c => P (e c)) = cnt P := by
  classical
  rw [cnt_eq_card_filter, cnt_eq_card_filter]
  exact card_equiv e (by simp)

/-- For a pair of challenges, the count is the sum, over the first, of the counts over the
second. -/
theorem cnt_prod_eq_sum [Fintype C] [Fintype D] (P : C × D → Prop) :
    cnt P = ∑ c, cnt fun d => P (c, d) := by
  classical
  simp only [cnt_eq_card_filter, card_filter]
  rw [← univ_product_univ, sum_product]

/-- The fibres of a function partition its domain. -/
theorem sum_cnt_fiber [Fintype C] [Fintype D] (f : C → D) :
    ∑ d, cnt (fun c => f c = d) = Fintype.card C := by
  classical
  simp only [cnt_eq_card_filter]
  rw [← Finset.card_univ]
  exact (Finset.card_eq_sum_card_fiberwise fun x _ => mem_univ (f x)).symm

/-- If for every first challenge at most k second challenges are bad, at most |C| k pairs are
bad. -/
theorem cnt_prod_le [Fintype C] [Fintype D] (P : C × D → Prop) (k : ℕ)
    (h : ∀ c, cnt (fun d => P (c, d)) ≤ k) : cnt P ≤ Fintype.card C * k := by
  rw [cnt_prod_eq_sum]
  exact (sum_le_sum fun c _ => h c).trans (by simp)

/-- Independent conditions on the two components multiply. -/
theorem cnt_and_prod [Fintype C] [Fintype D] (P : C → Prop) (Q : D → Prop) :
    cnt (fun x : C × D => P x.1 ∧ Q x.2) = cnt P * cnt Q := by
  classical
  rw [cnt_eq_card_filter, cnt_eq_card_filter, cnt_eq_card_filter]
  have : (univ.filter fun x : C × D => P x.1 ∧ Q x.2) = (univ.filter P) ×ˢ (univ.filter Q) := by
    ext x; simp
  rw [this, card_product]

theorem cnt_fst [Fintype C] [Fintype D] (P : C → Prop) :
    cnt (fun x : C × D => P x.1) = cnt P * Fintype.card D := by
  rw [← cnt_true (C := D), ← cnt_and_prod]
  exact cnt_congr fun x => by simp

theorem cnt_snd [Fintype C] [Fintype D] (Q : D → Prop) :
    cnt (fun x : C × D => Q x.2) = Fintype.card C * cnt Q := by
  rw [← cnt_true (C := C), ← cnt_and_prod]
  exact cnt_congr fun x => by simp

/-- Two rounds: a pair is bad if the first challenge is bad (at most k₁ values) or, the first being
good, the second is bad (at most k₂ values).  This is the count behind k₁/|C| + k₂/|D|. -/
theorem cnt_two_rounds_le [Fintype C] [Fintype D] (P : C × D → Prop) (B : C → Prop) (k₁ k₂ : ℕ)
    (h₁ : cnt B ≤ k₁) (h₂ : ∀ c, ¬ B c → cnt (fun d => P (c, d)) ≤ k₂) :
    cnt P ≤ k₁ * Fintype.card D + Fintype.card C * k₂ := by
  have hsplit : cnt P ≤ cnt (fun x : C × D => B x.1) + cnt (fun x : C × D => ¬ B x.1 ∧ P x) :=
    cnt_le_add fun x hx => by
      by_cases hb : B x.1
      · exact Or.inl hb
      · exact Or.inr ⟨hb, hx⟩
  refine hsplit.trans (Nat.add_le_add ?_ ?_)
  · rw [cnt_fst]
    exact Nat.mul_le_mul_right _ h₁
  · refine cnt_prod_le _ k₂ fun c => ?_
    by_cases hb : B c
    · rw [cnt_false fun d hd => hd.1 hb]
      exact Nat.zero_le _
    · exact (cnt_mono fun d hd => hd.2).trans (h₂ c hb)

/-- The lists of q entries that all have the property P number (cnt P)^q: the entries are
independent. -/
theorem cnt_forall_pow [Fintype C] (P : C → Prop) (q : ℕ) :
    cnt (fun I : Fin q → C => ∀ j, P (I j)) = cnt P ^ q := by
  classical
  rw [cnt_eq_card_filter, cnt_eq_card_filter]
  have hset : (univ.filter fun I : Fin q → C => ∀ j, P (I j))
      = Fintype.piFinset (fun _ : Fin q => univ.filter P) := by
    ext I
    simp [Fintype.mem_piFinset]
  rw [hset, Fintype.card_piFinset, Finset.prod_const, card_univ, Fintype.card_fin]

/-- Independent conditions on all coordinates of a tuple of challenges multiply. -/
theorem cnt_forall_pi [Fintype ι] [DecidableEq ι] {A : ι → Type}
    [∀ i, Fintype (A i)] (P : ∀ i, A i → Prop) :
    cnt (fun f : ∀ i, A i => ∀ i, P i (f i)) = ∏ i, cnt (P i) := by
  classical
  simp only [cnt_eq_card_filter]
  have hset : (univ.filter fun f : ∀ i, A i => ∀ i, P i (f i))
      = Fintype.piFinset (fun i => univ.filter (P i)) := by
    ext f
    simp [Fintype.mem_piFinset]
  rw [hset, Fintype.card_piFinset]

/-- A property of one coordinate has the same probability on a tuple of challenges as on that
coordinate. -/
theorem cnt_pi_coord [Fintype ι] [DecidableEq ι] {A : ι → Type} [∀ i, Fintype (A i)]
    (i₀ : ι) (P : A i₀ → Prop) :
    cnt (fun f : ∀ i, A i => P (f i₀)) * Fintype.card (A i₀) = cnt P * Fintype.card (∀ i, A i) := by
  classical
  let e := Equiv.piSplitAt i₀ A
  have h1 : cnt (fun f : ∀ i, A i => P (f i₀)) =
      cnt (fun x : A i₀ × (∀ j : {j // j ≠ i₀}, A j) => P x.1) :=
    cnt_equiv e (fun x : A i₀ × (∀ j : {j // j ≠ i₀}, A j) => P x.1)
  have h3 : Fintype.card (∀ i, A i) =
      Fintype.card (A i₀) * Fintype.card (∀ j : {j // j ≠ i₀}, A j) := by
    rw [Fintype.card_congr e, Fintype.card_prod]
  rw [h1, cnt_fst, h3]
  ring

end Counts
end Prob
