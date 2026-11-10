/-
D63 lane L49 (2026-11-10), part 2: **the R13 block statements at R13's own slot program, with the extraction, the
algebra data, the encodings and `R13Spec` discharged** (the R13 counterpart of lane L35's
`block_knowledge_define_alg_w16r2_rung` and lane L41's `block_knowledge_join_w16r2_rung`), at the R13 rung and at
every layer of the app's Shieldstral T128 R13 block.

* `progR13_rung_sums`, `progR13_rung_okP`: the R13 rung program's table counts (148 / 55) and its check at the
  verifier's row logs; `progR13_shield_ok`, `progR13_shield_sums`, `progR13_shield_okP`: the same at every layer of
  `shieldExport` (the 26 per-layer kernel checks of lane L44, L44-R4);
* **`block_knowledge_define_alg_r13_rung`**, **`block_knowledge_define_alg_r13_shield`**: L35's
  `block_knowledge_define_alg_r13_lk` / `…_r13_shield_lk26` at `prog := progR13 c` (`hprog`, `hsA`, `hsH` gone);
* **`block_knowledge_join_r13_rung`**, **`block_knowledge_join_r13_shield`**: the same with `xtE := xtR` (DEFINED from
  the committed `A` matrix), `sh := algShapeR`, `dt := dtR`, `enc := encR`, `encHt := encHtR`, `hspec` PROVED
  (`hspecR`), `hTok`, `hHd` from the layout facts `LayR`; the Shieldstral one at every layer `L ∈ shieldExport` with
  the layer's OWN shape `shieldShape L` (lane L40: its calibration) and `R13Windows` PROVED for it. Left by name: the
  hosts' named identities `hform` (with the batch's other entries `xc`, `pwc`), the helper layer and the lookup side.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostBase
import ZK60Formal.BlockDefineAlg

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open scoped ENNReal

/-! ## The program's facts at the two profiles -/

/-- The R13 rung program's table counts: 148 `A` tables, 54 `H` tables (55 with the sum claim). -/
theorem progR13_rung_sums (ioIn ioOut : ℕ) :
    sumFrom (fun k => (cntS Cm.a (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut)).getD k 0) 0 23 = 148
      ∧ sumFrom (fun k => (cntS Cm.h (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut)).getD k 0) 0 23 + 1 = 55 := by
  have ha : cntS Cm.a (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut) = Link.aCntR13Rung :=
    DefR13.progR13_rung_cntA ioIn ioOut
  have hh : cntS Cm.h (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut) = Link.hCntR13Rung :=
    DefR13.progR13_rung_cntH ioIn ioOut
  rw [ha, hh]
  exact And.intro Link.cnt_sums.2.2.1 Link.cnt_sums.2.2.2.1

/-- The R13 rung program passes the verifier's shape check at any verifier with the rung's schedule and positive
row logs. -/
theorem progR13_rung_okP (P : BlockParams) (hsl : P.geom.slots = ZK60.Exec.Block.R13.rungSlots)
    (hlc : 0 < P.logCols) (hep : 0 < P.endpointLogN) (ioIn ioOut : ℕ) :
    progOKb (rowLog P) (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut) P.geom.slots = true := by
  rw [hsl, progOKb_congr (rowLog P) (fun _ => 1) (fun cm => by cases cm <;> simp [rowLog, hlc, hep])]
  exact DefR13.progR13_rung_ok ioIn ioOut

/-- **Every Shieldstral layer's program passes the shape check** (lane L44's 26 per-layer kernel checks). -/
theorem progR13_shield_ok (ioIn ioOut : ℕ) : ∀ L ∈ ZK60.RunShape.Shield.shieldExport,
    progOKb (fun _ => 1) (DefR13.progR13 (DefR13.cfgShieldR13 L) ioIn ioOut) ZK60.Exec.Block.R13.shieldSlots = true := by
  intro L hL
  simp only [ZK60.RunShape.Shield.shieldExport, List.mem_cons, List.not_mem_nil, or_false] at hL
  rcases hL with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  · exact DefR13.progR13_shield_ok_l0 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l1 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l2 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l3 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l4 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l5 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l6 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l7 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l8 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l9 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l10 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l11 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l12 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l13 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l14 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l15 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l16 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l17 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l18 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l19 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l20 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l21 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l22 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l23 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l24 ioIn ioOut
  · exact DefR13.progR13_shield_ok_l25 ioIn ioOut

theorem progR13_shield_okP (L : ZK60.RunShape.Shield.ShieldLayer) (hL : L ∈ ZK60.RunShape.Shield.shieldExport)
    (P : BlockParams) (hsl : P.geom.slots = ZK60.Exec.Block.R13.shieldSlots) (hlc : 0 < P.logCols)
    (hep : 0 < P.endpointLogN) (ioIn ioOut : ℕ) :
    progOKb (rowLog P) (DefR13.progR13 (DefR13.cfgShieldR13 L) ioIn ioOut) P.geom.slots = true := by
  rw [hsl, progOKb_congr (rowLog P) (fun _ => 1) (fun cm => by cases cm <;> simp [rowLog, hlc, hep])]
  exact progR13_shield_ok ioIn ioOut L hL

/-- Every Shieldstral layer's program has 146 `A` tables and 53 `H` tables (54 with the sum claim). -/
theorem progR13_shield_sums (ioIn ioOut : ℕ) (L : ZK60.RunShape.Shield.ShieldLayer)
    (hL : L ∈ ZK60.RunShape.Shield.shieldExport) :
    sumFrom (fun k => (cntS Cm.a (DefR13.progR13 (DefR13.cfgShieldR13 L) ioIn ioOut)).getD k 0) 0 23 = 146
      ∧ sumFrom (fun k => (cntS Cm.h (DefR13.progR13 (DefR13.cfgShieldR13 L) ioIn ioOut)).getD k 0) 0 23 + 1 = 54 := by
  have ha : cntS Cm.a (DefR13.progR13 (DefR13.cfgShieldR13 L) ioIn ioOut) = Link.aCntR13Shield :=
    DefR13.progR13_shield_cntA ioIn ioOut L hL
  have hh : cntS Cm.h (DefR13.progR13 (DefR13.cfgShieldR13 L) ioIn ioOut) = Link.hCntR13Shield :=
    DefR13.progR13_shield_cntH ioIn ioOut L hL
  rw [ha, hh]
  exact And.intro Link.cnt_sums.2.2.2.2.1 Link.cnt_sums.2.2.2.2.2

/-- The rung's `per_row` is a nonzero field element. -/
theorem perRow_rung : 0 < DefR13.cfgRungR13.sh.perRow ∧ DefR13.cfgRungR13.sh.perRow < gP := by
  refine ⟨by decide, ?_⟩
  show 32 < 18446744069414584321
  norm_num

/-- Every Shieldstral layer's `per_row` is a nonzero field element. -/
theorem perRow_shield (L : ZK60.RunShape.Shield.ShieldLayer) :
    0 < (DefR13.cfgShieldR13 L).sh.perRow ∧ (DefR13.cfgShieldR13 L).sh.perRow < gP := by
  refine ⟨(by decide : 0 < shShieldR.perRow), ?_⟩
  show 128 < 18446744069414584321
  norm_num

/-- **Every Shieldstral layer's own shape meets R13's windows at two softmax limbs** (lane L40's `shieldShape_r13` at
the export's validity facts). -/
theorem shieldWindows (L : ZK60.RunShape.Shield.ShieldLayer) (hL : L ∈ ZK60.RunShape.Shield.shieldExport) :
    ZK60.Layout.R13.R13Windows (ZK60.RunShape.Shield.shieldShape L) 1 :=
  ZK60.RunShape.Shield.shieldShape_r13 L (ZK60.RunShape.Shield.shield_layers_ok L hL)

end ZK60.Exec.Block.Join.R13H
