-- Copyright 2026 Anthropic PBC
-- SPDX-License-Identifier: Apache-2.0
-- Modified for ZK60Formal (IntelligenceRegulation), 2026-11-04: module paths renamed under
-- ZK60Formal.ThirdParty.FlashProve; in `cnt_false`, `haveI` written `have` (Mathlib v4.34.1's style
-- linter). Nothing else changed.
/-
Prob/Cnt.lean: the counting function `cnt`.

`cnt P` is the number of elements of a finite type with the property P. In Iop/ and Blocks/ the
errors of the rounds (`Err`, Iop/Rbr.lean: one number for each round: how many values of the
challenge may lead from a doomed transcript (`Doomed`, there) to one that is not doomed) are counts:
the number of values of one verifier message that are bad. Counts are compared with probabilities by
`Err.Below` (Iop/InteractiveOracleProof.lean). Further lemmas on `cnt`: Prob/Count.lean.
-/
import Mathlib.SetTheory.Cardinal.Finite
import Mathlib.Data.Fintype.Card
noncomputable section -- Lean tags what it cannot compile

namespace Prob

/-- The number of elements of a finite type with the property P. The instance argument is there on
purpose: Nat.card of an infinite type is 0, so that without it a bound "cnt P ≤ e" could hold for
free. -/
def cnt {α : Type} [Finite α] (P : α → Prop) : ℕ := Nat.card {a : α // P a}

theorem cnt_mono {α : Type} [Finite α] {P Q : α → Prop} (h : ∀ a, P a → Q a) : cnt P ≤ cnt Q :=
  Nat.card_le_card_of_injective (fun x : {a // P a} => (⟨x.1, h x.1 x.2⟩ : {a // Q a}))
    (fun _ _ hab => Subtype.ext (congrArg (fun y : {a // Q a} => y.1) hab))

theorem cnt_false {α : Type} [Finite α] {P : α → Prop} (h : ∀ a, ¬ P a) : cnt P = 0 := by
  have : IsEmpty {a : α // P a} := ⟨fun x => h x.1 x.2⟩
  exact Nat.card_of_isEmpty

end Prob
