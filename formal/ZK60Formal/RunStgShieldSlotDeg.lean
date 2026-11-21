/-
D63 lane L63, leg 18 (2026-11-21; ruling L63-10, finding L68b-3): **the repaired slot-degree hypothesis is MET at the
Shield run's schedules.**

Before ruling L63-10 the 15 completeness declarations of lanes L25, L29, L32 and L39 took
`∀ s, 1 ≤ slotD P s ∧ slotD P s < gP`, refutable for every `P` (`slotD P P.geom.slots.length = 0`). After the repair
they take `∀ s, s < P.geom.slots.length → 1 ≤ slotD P s ∧ slotD P s < gP`. This file proves that form, with `gP` the
Goldilocks prime of the 15 theorems, for:

* `shdSD_blkParams`: the Shieldstral T128 R13 block parameters `shdP_blkParams` (RunShieldBlkInst.lean) at EVERY
  layer and public input (the schedule `R13.shieldSlots` depends on neither; its 23 degrees lie in `[2, 5]`);
* `shdSD_Pk0`: the 26-block family `shdP_Pk0` the top `sshC_productionReadyL_epP_blkEF` names, at every block
  `k < 26` of a run with `ShieldRun Rp`;
* `shdSD_incV` / `shdSD_outcV`: stage IN-C and OUT-C at ANY stage verifier (their 4 and 8 slots have degrees `≤ 4`
  and `≤ 5`, `rc_incBounds` / `rc_outcBounds`), so in particular at the Shield run's `shdP_incV` and `shdP_outcV`
  (RunShieldInstP.lean): `shdSD_shdIncV`, `shdSD_shdOutcV`.

So the degree premise of the repaired theorems is dischargeable at the real run (non-vacuity of that one premise; the
theorems' other premises are untouched here). Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunShieldBlkInst
import ZK60Formal.RunShieldInstP
import ZK60Formal.RunCoverStage

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Layout ZK60.TokenRun ZK60.Assembly ZK60.StageX ZK60.RunShape
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP)
open ZK60.Block (BlockPublic)
open ZK60.Exec.Block (BlockParams Cm)
open ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape.Shield (ShieldLayer shieldS0 shieldShape ShieldRun)

/-- The R13 Shieldstral block schedule has 23 slots. -/
theorem shdSD_shieldSlots_length : Exec.Block.R13.shieldSlots.length = 23 := rfl

/-- Its 23 round degrees lie in `[1, 5]` (in fact `[2, 5]`). -/
theorem shdSD_shieldSlots_deg : ∀ s, s < 23 →
    1 ≤ (Exec.Block.R13.shieldSlots.getD s (0, 0, 0)).2.2 ∧ (Exec.Block.R13.shieldSlots.getD s (0, 0, 0)).2.2 ≤ 5 := by
  decide

theorem shdSD_five_lt_gP : 5 < gP := by decide

/-- **Any block parameters on the R13 Shieldstral schedule meet the repaired degree hypothesis.** -/
theorem shdSD_of_slots (P : BlockParams) (h : P.geom.slots = Exec.Block.R13.shieldSlots) :
    ∀ s, s < P.geom.slots.length → 1 ≤ HonestClassify.slotD P s ∧ HonestClassify.slotD P s < gP := by
  intro s hs
  rw [h, shdSD_shieldSlots_length] at hs
  obtain ⟨h1, h5⟩ := shdSD_shieldSlots_deg s hs
  have e : HonestClassify.slotD P s = (Exec.Block.R13.shieldSlots.getD s (0, 0, 0)).2.2 := by
    show (P.geom.slots.getD s (0, 0, 0)).2.2 = _
    rw [h]
  rw [e]
  exact ⟨h1, lt_of_le_of_lt h5 shdSD_five_lt_gP⟩

/-- **The Shieldstral block parameters meet it at every layer and public input.** -/
theorem shdSD_blkParams (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    ∀ s, s < (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb).geom.slots.length →
      1 ≤ HonestClassify.slotD (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb) s
        ∧ HonestClassify.slotD (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb) s < gP :=
  shdSD_of_slots _ rfl

/-- **The 26-block family of the top meets it at every block of a Shield run.** -/
theorem shdSD_Pk0 (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) :
    ∀ s, s < (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).geom.slots.length →
      1 ≤ HonestClassify.slotD (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) s
        ∧ HonestClassify.slotD (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) s < gP :=
  shdSD_of_slots _ (by rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk]; rfl)

/-- **Stage IN-C meets it at every stage verifier and head context** (its 4 slots, degrees `≤ 4`). -/
theorem shdSD_incV (V : IncV) (cx : IncCtx) :
    ∀ s, s < (V.bp cx).geom.slots.length →
      1 ≤ HonestClassify.slotD (V.bp cx) s ∧ HonestClassify.slotD (V.bp cx) s < gP := by
  intro s hs
  obtain ⟨h1, h4, -⟩ := rc_incBounds V cx s hs
  exact ⟨h1, lt_of_le_of_lt (le_trans h4 (by decide)) shdSD_five_lt_gP⟩

/-- **Stage OUT-C meets it at every stage verifier** (its 8 slots, degrees `≤ 5`). -/
theorem shdSD_outcV (V : OutcV) :
    ∀ s, s < V.bp.geom.slots.length → 1 ≤ HonestClassify.slotD V.bp s ∧ HonestClassify.slotD V.bp s < gP := by
  intro s hs
  obtain ⟨h1, h5, -⟩ := rc_outcBounds V s hs
  exact ⟨h1, lt_of_le_of_lt h5 shdSD_five_lt_gP⟩

/-- At the Shield run's stage IN-C verifier (`shdP_incV`, RunShieldInstP.lean). -/
theorem shdSD_shdIncV (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (embFold : List Fp2 → List Fp2) (bInRow : ℕ) (cx : IncCtx) :
    ∀ s, s < ((shdP_incV tag Rp embDigest embFold bInRow).bp cx).geom.slots.length →
      1 ≤ HonestClassify.slotD ((shdP_incV tag Rp embDigest embFold bInRow).bp cx) s
        ∧ HonestClassify.slotD ((shdP_incV tag Rp embDigest embFold bInRow).bp cx) s < gP :=
  shdSD_incV _ cx

/-- At the Shield run's stage OUT-C verifier family (`shdP_outcV`, every verdict `v`). -/
theorem shdSD_shdOutcV (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v : ℕ) :
    ∀ s, s < (shdP_outcV tag Rp wDigest bOutRow v).bp.geom.slots.length →
      1 ≤ HonestClassify.slotD (shdP_outcV tag Rp wDigest bOutRow v).bp s
        ∧ HonestClassify.slotD (shdP_outcV tag Rp wDigest bOutRow v).bp s < gP :=
  shdSD_outcV _

end ZK60.ProtocolClassify
