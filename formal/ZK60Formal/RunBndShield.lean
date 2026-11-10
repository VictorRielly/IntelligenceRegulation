/-
D63 lane L56 (2026-11-10), part 6: **block `k`'s verifier is layer `k` of the app's Shieldstral export** (finding
L54-2: nothing in the top theorem tied block `k`'s verifier `Pk k` to layer `k`).

Lane L49's block statement `block_knowledge_r13_shield` holds for a verifier `P` that IS the code's Shieldstral T128 R13
verifier at a layer `Ly ∈ shieldExport`: `IsShieldR13 P`, its `define` R13's program at the layer's calibration and
the layer's public tables (`hdef`), its column count, endpoint size, three slot kinds and LogUp sum claim (`hlc`, `hep`,
`hk3`, `hk19`, `hk20`, `hls`), and the layout's facts (`hLay`). This file names that bundle and the run-level tie:

* **`ShieldBlkAt P Ly Pb`**: `P` is the code's verifier at layer `Ly` with public data `Pb` (every premise lane L49's
  block statement asks of the verifier, by its own names);
* **`ShieldRunAt Pk blks Lb`**: for every block `k < Lb`, layer `k` of `shieldExport` exists, the run's block `k`
  (`blks[k]`) carries that layer's calibration, and `Pk k` is the code's verifier at that layer with that block's
  public data (`HEq`: the same data at the same shape);
* `ShieldBlkAt.defineS`, **`ShieldRunAt.hdefS`**: lane L54's `hdefS` follows (its weakest part);
* `ShieldRunAt.lb_le`: the run has at most 26 blocks (the export's).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13StmtDone
import ZK60Formal.RunShapeShield

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H.Look
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Circuit (gP GF)
open ZK60.Layout

/-- **`P` is the code's Shieldstral T128 R13 block verifier at layer `Ly`, with public data `Pb`**: every premise lane
L49's `block_knowledge_r13_shield` asks of its verifier (`hP`, `hdef`, `hlc`, `hep`, `hk3`, `hk19`, `hk20`, `hls`) and
of the layout (`hLay`), at some opening tag, row counts, layout, public tables and IO slot indices. -/
def ShieldBlkAt (P : BlockParams) (Ly : ZK60.RunShape.Shield.ShieldLayer)
    (Pb : ZK60.Block.BlockPublic (ZK60.RunShape.Shield.shieldShape Ly)) : Prop :=
  ∃ (tag : MTag) (rowsOf : Cm → ℕ)
    (Lay : W16Layout (ZK60.RunShape.Shield.shieldShape Ly) (CtR (DefR13.cfgShieldR13 Ly))
      (CwR (DefR13.cfgShieldR13 Ly)) (CgR (DefR13.cfgShieldR13 Ly)) (CjR (DefR13.cfgShieldR13 Ly))
      (CdR (DefR13.cfgShieldR13 Ly)) (CfR (DefR13.cfgShieldR13 Ly)))
    (B : W16Pub (ZK60.RunShape.Shield.shieldShape Ly) Pb Lay) (ioIn ioOut : ℕ),
    Link.IsShieldR13 P tag rowsOf
      ∧ P.define = defineS (DefR13.progR13 (DefR13.cfgShieldR13 Ly) ioIn ioOut)
          (Pub.pubsR13L (DefR13.cfgShieldR13 Ly) Pb Lay B (ZK60.RunShape.Shield.shieldShape Ly).nG)
      ∧ P.logCols = 14 ∧ 0 < P.endpointLogN
      ∧ P.kind 3 = SlotKind.standalone ∧ P.kind 19 = SlotKind.standalone ∧ P.kind 20 = SlotKind.standalone
      ∧ P.logupSumClaim = Look.logupSumR13 (DefR13.cfgShieldR13 Ly)
      ∧ LayR Lay

/-- **The run's blocks are the export's layers, in order** (finding L54-2): for every block `k < Lb`, layer `k` of
`shieldExport` exists, the run's block `k` carries its calibration, and `Pk k` is the code's verifier at that layer
with that block's public data. -/
def ShieldRunAt {S0 : ZK60.Block.BlockShape} (Pk : ℕ → BlockParams) (blks : List (ZK60.RunShape.RunBlock S0))
    (Lb : ℕ) : Prop :=
  ∀ k, k < Lb → ∃ (Ly : ZK60.RunShape.Shield.ShieldLayer) (b : ZK60.RunShape.RunBlock S0)
    (Pb : ZK60.Block.BlockPublic (ZK60.RunShape.Shield.shieldShape Ly)),
    ZK60.RunShape.Shield.shieldExport[k]? = some Ly ∧ blks[k]? = some b
      ∧ b.cal = ZK60.RunShape.Shield.shieldCal Ly ∧ HEq Pb b.pub ∧ ShieldBlkAt (Pk k) Ly Pb

/-- A verifier at a layer has a slot program's `define` (lane L54's `hdefS`, at one block). -/
theorem ShieldBlkAt.defineS {P : BlockParams} {Ly : ZK60.RunShape.Shield.ShieldLayer}
    {Pb : ZK60.Block.BlockPublic (ZK60.RunShape.Shield.shieldShape Ly)} (h : ShieldBlkAt P Ly Pb) :
    ∃ (prog : List SlotS) (pubs : PubTabs), P.define = defineS prog pubs := by
  obtain ⟨_, _, _, _, _, _, _, hdef, _⟩ := h
  exact ⟨_, _, hdef⟩

/-- **Lane L54's `hdefS` follows from the run-level tie.** -/
theorem ShieldRunAt.hdefS {S0 : ZK60.Block.BlockShape} {Pk : ℕ → BlockParams}
    {blks : List (ZK60.RunShape.RunBlock S0)} {Lb : ℕ} (h : ShieldRunAt Pk blks Lb) :
    ∀ k, k < Lb → ∃ (prog : List SlotS) (pubs : PubTabs), (Pk k).define = defineS prog pubs := by
  intro k hk
  obtain ⟨_, _, _, _, _, _, _, hb⟩ := h k hk
  exact hb.defineS

/-- The run has at most the export's 26 blocks. -/
theorem ShieldRunAt.lb_le {S0 : ZK60.Block.BlockShape} {Pk : ℕ → BlockParams}
    {blks : List (ZK60.RunShape.RunBlock S0)} {Lb : ℕ} (h : ShieldRunAt Pk blks Lb) : Lb ≤ 26 := by
  by_contra hc
  obtain ⟨_, _, _, hLy, _⟩ := h 26 (by omega)
  have hlen : ZK60.RunShape.Shield.shieldExport.length = 26 := ZK60.RunShape.Shield.shieldExport_l17.1
  rw [List.getElem?_eq_none (by omega)] at hLy
  cases hLy

end ZK60.Exec.Block.Join.R13H
