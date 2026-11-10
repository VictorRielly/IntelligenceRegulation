/-
D63 lane L44 (2026-11-10), deliverable 6: **the R13 program's facts by evaluation** (`BlockR13Prog.lean`'s `progR13`):
its plane ids and helper counts, its `A` / `H` tables per slot at the R13 rung and at the Shieldstral T128 R13 block
(L31-3), and its check against R13's schedules.

Only `propext`, `Classical.choice`, `Quot.sound`; every fact by `decide +kernel` on the configurations.
-/
import ZK60Formal.BlockR13Prog

namespace ZK60.Exec.Block.DefR13

open ZK60.Exec
open ZK60.Exec.Slot
open ZK60.Exec.Slot.W16R2 (Dom)
open ZK60.Exec.Block.DefW16 (W16Cfg)

/-! ## The facts at the rung and at the Shieldstral block -/

/-- The rung's plane ids. -/
theorem idsR13_rung : [(ids cfgRungR13).q0, (ids cfgRungR13).k0, (ids cfgRungR13).s0, (ids cfgRungR13).f0,
    (ids cfgRungR13).t0, (ids cfgRungR13).t0 + 3] = [47, 61, 75, 90, 106, 109] := by
  decide +kernel

/-- The lookups give the rung's helper counts (`L 1, D 17, Q 7, Kv 7, S 9, F 7`). -/
theorem helpers_rung : [Dom.L, .D, .Q, .Kv, .S, .F].map (nHelp cfgRungR13)
    = [Dom.L, .D, .Q, .Kv, .S, .F].map ZK60.Exec.Slot.R13.shRungR13.helpers := by
  decide +kernel

/-- The lookups give the Shieldstral shape's helper counts (`S 8`), at every layer of the export. -/
theorem helpers_shield : ∀ L ∈ ZK60.RunShape.Shield.shieldExport,
    [Dom.L, .D, .Q, .Kv, .S, .F].map (nHelp (cfgShieldR13 L))
      = [Dom.L, .D, .Q, .Kv, .S, .F].map ZK60.Exec.Slot.R13.shShieldR13.helpers := by
  decide +kernel

/-- **The R13 rung program passes its check** against `R13.rungSlots`. -/
theorem progR13_rung_ok (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 cfgRungR13 ioIn ioOut) R13.rungSlots = true := by
  rw [progR13_okb]
  decide +kernel

/-- **The rung's `A` tables per slot are L31's `aCntR13Rung`** (148). -/
theorem progR13_rung_cntA (ioIn ioOut : ℕ) :
    (progR13 cfgRungR13 ioIn ioOut).map (fun s => cmCountS .a s.tabs) = Link.aCntR13Rung := by
  rw [progR13_cm]
  decide +kernel

/-- **The rung's `H` tables per slot are L31's `hCntR13Rung`** (54; 55 with the LogUp sum claim). -/
theorem progR13_rung_cntH (ioIn ioOut : ℕ) :
    (progR13 cfgRungR13 ioIn ioOut).map (fun s => cmCountS .h s.tabs) = Link.hCntR13Rung := by
  rw [progR13_cm]
  decide +kernel

/-- **L31-3, for the program: the Shieldstral block's `A` tables per slot are `aCntR13Shield`** (146), at every layer
of the app's export. -/
theorem progR13_shield_cntA (ioIn ioOut : ℕ) : ∀ L ∈ ZK60.RunShape.Shield.shieldExport,
    (progR13 (cfgShieldR13 L) ioIn ioOut).map (fun s => cmCountS .a s.tabs) = Link.aCntR13Shield := by
  intro L hL
  rw [progR13_cm]
  revert L
  decide +kernel

/-- **L31-3, for the program: its `H` tables per slot are `hCntR13Shield`** (53; 54 with the LogUp sum claim). -/
theorem progR13_shield_cntH (ioIn ioOut : ℕ) : ∀ L ∈ ZK60.RunShape.Shield.shieldExport,
    (progR13 (cfgShieldR13 L) ioIn ioOut).map (fun s => cmCountS .h s.tabs) = Link.hCntR13Shield := by
  intro L hL
  rw [progR13_cm]
  revert L
  decide +kernel

/-- **The Shieldstral program passes its check** against `R13.shieldSlots`, at the first layer of the app's export
(the check reads only the tables and the IRs' degrees; every layer is evaluated in `BlockR13ProgOk.lean`). -/
theorem progR13_shield_ok_l0 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

end ZK60.Exec.Block.DefR13
