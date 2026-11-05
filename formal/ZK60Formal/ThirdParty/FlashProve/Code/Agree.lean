-- Copyright 2026 Anthropic PBC
-- SPDX-License-Identifier: Apache-2.0
-- Modified for ZK60Formal (IntelligenceRegulation), 2026-11-04: module paths renamed under
-- ZK60Formal.ThirdParty.FlashProve. Nothing else changed.
/-
Code/Agree.lean: a linear code as a subspace, agreement on a set of positions, and mutual correlated
agreement as a count.

Definitions and their first lemmas only. The statements that hold for every linear code
(Code/Third.lean, Code/Derived.lean) are written for a subspace D of the space of words ι → E, where
ι is any finite set of positions. Only Mathlib's types and `Prob.cnt` are used. Code/Iface.lean
gives a code by a generator matrix; its code is the range of that matrix. The labels (P1), (P2) are
those of `Enc.Props` there.

Notation: `cnt P` (`Prob.cnt`, Prob/Cnt.lean): a natural number, the number of elements of a finite
type with the property P; θ: an element of E, the coefficient of f₁ in f₀ + θ f₁ (`MCA`).
-/
import Mathlib.Algebra.Module.Submodule.Basic
import Mathlib.Algebra.Module.Pi
import Mathlib.Algebra.Field.Defs
import Mathlib.Data.Fintype.Card
import ZK60Formal.ThirdParty.FlashProve.Prob.Cnt

namespace Code
open Prob

variable {E ι : Type} [Field E]

/-- The words that agree on the set S of positions with some word of the code D. In symbols: f|S ∈
D|S. They form a subspace. -/
def agreeOn (D : Submodule E (ι → E)) (S : Finset ι) : Submodule E (ι → E) where
  carrier := {f | ∃ u ∈ D, ∀ j ∈ S, f j = u j}
  add_mem' := by
    rintro f g ⟨u, hu, hfu⟩ ⟨v, hv, hgv⟩
    exact ⟨u + v, D.add_mem hu hv,
      fun j hj => by rw [Pi.add_apply, Pi.add_apply, hfu j hj, hgv j hj]⟩
  zero_mem' := ⟨0, D.zero_mem, fun _ _ => rfl⟩
  smul_mem' := by
    rintro c f ⟨u, hu, hfu⟩
    exact ⟨c • u, D.smul_mem c hu, fun j hj => by rw [Pi.smul_apply, Pi.smul_apply, hfu j hj]⟩

@[simp] theorem mem_agreeOn {D : Submodule E (ι → E)} {S : Finset ι} {f : ι → E} :
    f ∈ agreeOn D S ↔ ∃ u ∈ D, ∀ j ∈ S, f j = u j := Iff.rfl

/-- A word of the code agrees with the code on every set. -/
theorem mem_agreeOn_of_mem {D : Submodule E (ι → E)} {f : ι → E} (hf : f ∈ D) (S : Finset ι) :
    f ∈ agreeOn D S :=
  ⟨f, hf, fun _ _ => rfl⟩

/-- Agreement on a set gives agreement on every subset. -/
theorem agreeOn_anti (D : Submodule E (ι → E)) {S T : Finset ι} (h : S ⊆ T) :
    agreeOn D T ≤ agreeOn D S :=
  fun _ ⟨u, hu, hfu⟩ => ⟨u, hu, fun j hj => hfu j (h hj)⟩

/-- (P1) Distance. Every non-zero word of the code D has at least d non-zero symbols. -/
def MinDist [Finite ι] (D : Submodule E (ι → E)) (d : ℕ) : Prop :=
  ∀ u ∈ D, u ≠ 0 → d ≤ cnt (fun j => u j ≠ 0)

/-- (P2) Mutual correlated agreement on lines, as a count.
Let f₀ and f₁ be interleaved words, with any finite set R of rows. At most `bad` values of θ admit a
set S of all but at most e positions on which every row of f₀ + θ f₁ agrees with a word of the code,
while not all rows of f₀ and of f₁ do.
One number serves every set of rows. -/
def MCA [Finite E] [Fintype ι] (D : Submodule E (ι → E)) (e bad : ℕ) : Prop :=
  ∀ (R : Type) [Finite R] (f₀ f₁ : R → ι → E),
    cnt (fun θ : E =>
        ∃ S : Finset ι,
          Fintype.card ι ≤ S.card + e ∧
          (∀ a, f₀ a + θ • f₁ a ∈ agreeOn D S) ∧
          ¬ ((∀ a, f₀ a ∈ agreeOn D S) ∧ ∀ a, f₁ a ∈ agreeOn D S)) ≤ bad

/-- A larger count is also a bound. -/
theorem MCA.mono [Finite E] [Fintype ι] {D : Submodule E (ι → E)} {e bad bad' : ℕ}
    (h : MCA D e bad) (hb : bad ≤ bad') :
    MCA D e bad' := fun R _ f₀ f₁ => (h R f₀ f₁).trans hb

end Code
