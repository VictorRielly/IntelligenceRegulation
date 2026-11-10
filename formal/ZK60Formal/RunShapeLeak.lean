/-
D63 lane L40 (2026-11-10), part 7: **the allowed leakage of Victor's ruling D76 at the per-block-shape model**, and the
per-block instances' factoring through it.

Lane L42's `classifyLeak S R x := (S.T, S.d, R.Ps.length, (classifySpec R x).isSome)` (StatementsD76Leak.lean) is
stated for L2's one-shape run data. Its per-block-shape analogue reads the same four things off the per-block run
data: the token count `T` and the width `d` (the run's carrier: the ONLY shape fields every block shares), the number
of blocks, and whether the per-block model `classifySpecP` serves the item. The blocks' own shapes are public data of
the model, the same for every item, and are not a function of the item.

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `classifyLeakP`, `classifyLeakP_served`: the per-block allowed leakage, its last component the served bit;
* **`classifyLeakP_toRunP`**: at equal shapes it IS L42's `classifyLeak S R` (nothing of D76 is lost);
* `clsLeakP_eq`, **`classifyP_leaksAtMost`**, **`classifyUP_leaksAtMost`**: the per-block instances `classifyProtocolP`,
  `classifyProtocolUP` (and so `classifyProtocolUExecP`, `RunShapeGateL.lean`) leak no more than `classifyLeakP`
  (`LeaksAtMost`, StatementsD76Bridge.lean).
-/
import ZK60Formal.RunShapeProtocol
import ZK60Formal.StatementsD76Leak
import ZK60Formal.StatementsD76Gate

set_option autoImplicit false

namespace ZK60.ProtocolClassify.RunShapeP

open ZK60 ZK60.Exec ZK60.TokenRun ZK60.RunShape
open ZK60.Block (BlockShape)
open ZK60.D76 (classifyLeak LeaksAtMost)

variable {S : BlockShape} {Hdr Salt Coins : Type}

/-- **The media classifier's allowed leakage (D76) at the per-block-shape model**: of an item `x`, the token count
`T` and the width `d` of the run's carrier, the number of blocks, and whether the item is served (the per-block integer
model returns a verdict). -/
noncomputable def classifyLeakP (R : ClassifyRunPublicP S) (x : S.Tok → ℕ) : ℕ × ℕ × ℕ × Bool :=
  (S.T, S.d, R.blks.length, (classifySpecP R x).isSome)

/-- Its last component is the served bit. -/
theorem classifyLeakP_served (R : ClassifyRunPublicP S) (x : S.Tok → ℕ) :
    (classifyLeakP R x).2.2.2 = true ↔ (classifyModelP R).admissible x :=
  Option.isSome_iff_exists

/-- **At equal shapes the per-block leakage IS L42's `classifyLeak`.** -/
theorem classifyLeakP_toRunP (R : ClassifyRunPublic S) : classifyLeakP (toRunP R) = classifyLeak S R := by
  funext x
  show (S.T, S.d, (R.Ps.map RunBlock.ofPub).length, (classifySpecP (toRunP R) x).isSome)
    = (S.T, S.d, R.Ps.length, (classifySpec R x).isSome)
  rw [List.length_map, classifySpecP_toRunP]

/-- The served bit two ways (L42's `served_eq` at the per-block model). -/
theorem served_eqP (R : ClassifyRunPublicP S) (x : S.Tok → ℕ) :
    @decide ((classifyModelP R).admissible x) (Classical.propDecidable _) = (classifySpecP R x).isSome := by
  rw [Bool.eq_iff_iff, @decide_eq_true_iff _ (Classical.propDecidable _), Option.isSome_iff_exists]
  rfl

/-- **The per-block instance's declared leakage is `classifyLeakP`**, field by field. -/
theorem clsLeakP_eq (R : ClassifyRunPublicP S) (x : S.Tok → ℕ) : clsLeakP R x = clsLeakOf (classifyLeakP R x) := by
  unfold clsLeakP
  rw [served_eqP]
  rfl

variable {R : ClassifyRunPublicP S} {Lq : ℕ} {V : RunV Hdr} {P : RunP Hdr (S.Tok → ℕ) Coins}
  {Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt} {h64 : 64 ≤ Lq} {hr : 8 * Cin.R ≤ Lq} {base : Coins → Salt}
  {e : ℕ}

/-- **`classifyProtocolP` leaks no more than `classifyLeakP`.** -/
theorem classifyP_leaksAtMost : LeaksAtMost (classifyProtocolP R Lq V P Cin h64 hr base) (classifyLeakP R) :=
  ⟨clsLeakOf, funext fun x => clsLeakP_eq R x⟩

/-- **`classifyProtocolUP` leaks no more than `classifyLeakP`.** -/
theorem classifyUP_leaksAtMost : LeaksAtMost (classifyProtocolUP R Lq V P Cin h64 hr base e) (classifyLeakP R) :=
  ⟨clsLeakOf, funext fun x => clsLeakP_eq R x⟩

end ZK60.ProtocolClassify.RunShapeP
