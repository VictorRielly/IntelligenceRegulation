/-
D63 lane L42 (2026-11-10), part 2: **the media classifier's allowed leakage, named** (Victor's ruling D76 (1)).

This is the ONE definition a reviewer reads to know what the media classifier's receipts may reveal about the item.
The approved statements (`ZeroKnowledgeL`, `SemanticHidingL`, `ProductionReadyL` in `Statements.lean`) take it as their
argument `Λ`; the production theorems of the classify run name it (`StatementsD76Gate.lean`).
-/
import ZK60Formal.CircuitTokenRun

set_option autoImplicit false

namespace ZK60.D76

open ZK60.TokenRun
open ZK60.Block (BlockShape)

/-- **The media classifier's allowed leakage (D76)**: of an item `x` (its token ids), a receipt may reveal
* the token count `T` and the width `d` of the registered shape `S`,
* the layer count `L`: the number of blocks of the registered run `R`,
* whether the request is served: the integer model returns a verdict (an unserved request gets the one constant
  refusal, D65(2)).

The verdict itself is the model's public output part (`classifyModel`'s `publicPart`), shown to the simulator beside
`Λ x`. Nothing else about `x`. -/
noncomputable def classifyLeak (S : BlockShape) (R : ClassifyRunPublic S) (x : S.Tok → ℕ) : ℕ × ℕ × ℕ × Bool :=
  (S.T, S.d, R.Ps.length, (classifySpec R x).isSome)

/-- Its last component is the served bit: `true` exactly when the integer model admits the item. -/
theorem classifyLeak_served (S : BlockShape) (R : ClassifyRunPublic S) (x : S.Tok → ℕ) :
    (classifyLeak S R x).2.2.2 = true ↔ (classifyModel S R).admissible x :=
  Option.isSome_iff_exists

end ZK60.D76
