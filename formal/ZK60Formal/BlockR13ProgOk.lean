/-
D63 lane L44 (2026-11-10), deliverable 6: **the Shieldstral T128 R13 program passes its check at every layer** of
the app's export (`progOKb` against `R13.shieldSlots`): one kernel evaluation per layer (`progR13_shield_ok_l0` …
`_l25`), and **`progR13_shield_ok`** for every layer of `shieldExport`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13ProgCnt

namespace ZK60.Exec.Block.DefR13

open ZK60.Exec
open ZK60.Exec.Slot

theorem progR13_shield_ok_l1 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨8, 8, 14, 8, 19, 2600, 1471, 3⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l2 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨8, 8, 16, 6, 18, 2727, 1196, 4⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l3 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨8, 8, 15, 8, 20, 2899, 1448, 3⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l4 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨8, 6, 15, 8, 20, 2304, 1289, 3⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l5 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨8, 7, 15, 8, 20, 2277, 1539, 3⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l6 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨7, 7, 15, 8, 20, 2190, 1370, 3⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l7 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨8, 6, 15, 8, 20, 2212, 1424, 3⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l8 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨8, 6, 15, 8, 20, 2248, 1479, 3⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l9 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨7, 7, 14, 8, 20, 2267, 1302, 4⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l10 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨7, 6, 16, 8, 19, 2218, 1539, 3⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l11 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨7, 7, 15, 8, 20, 2233, 1533, 4⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l12 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨7, 6, 14, 8, 20, 2208, 1246, 4⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l13 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨7, 7, 13, 8, 20, 2185, 999, 4⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l14 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨7, 7, 13, 8, 19, 2118, 1052, 3⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l15 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨7, 7, 13, 8, 20, 2015, 1182, 4⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l16 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨6, 6, 14, 8, 20, 2174, 1481, 4⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l17 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨7, 7, 14, 8, 20, 2430, 1435, 4⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l18 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨6, 7, 15, 8, 20, 2448, 1607, 4⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l19 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨7, 7, 15, 8, 20, 2599, 1835, 4⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l20 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨6, 7, 16, 8, 20, 2273, 1926, 4⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l21 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨7, 7, 14, 8, 20, 2343, 2091, 3⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l22 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨6, 7, 15, 8, 20, 2753, 2455, 3⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l23 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨7, 8, 16, 8, 19, 3854, 2062, 4⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l24 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨7, 8, 15, 8, 19, 4532, 2467, 4⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

theorem progR13_shield_ok_l25 (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 ⟨7, 8, 15, 5, 19, 3047, 3106, 4⟩) ioIn ioOut) R13.shieldSlots = true := by
  rw [progR13_okb]
  decide +kernel

/-- **The Shieldstral program passes its check** against `R13.shieldSlots`, at every layer of the app's export. -/
theorem progR13_shield_ok (ioIn ioOut : ℕ) : ∀ L ∈ ZK60.RunShape.Shield.shieldExport,
    progOKb (fun _ => 1) (progR13 (cfgShieldR13 L) ioIn ioOut) R13.shieldSlots = true := by
  intro L hL
  simp only [ZK60.RunShape.Shield.shieldExport, List.mem_cons, List.not_mem_nil, or_false] at hL
  rcases hL with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  · exact progR13_shield_ok_l0 ioIn ioOut
  · exact progR13_shield_ok_l1 ioIn ioOut
  · exact progR13_shield_ok_l2 ioIn ioOut
  · exact progR13_shield_ok_l3 ioIn ioOut
  · exact progR13_shield_ok_l4 ioIn ioOut
  · exact progR13_shield_ok_l5 ioIn ioOut
  · exact progR13_shield_ok_l6 ioIn ioOut
  · exact progR13_shield_ok_l7 ioIn ioOut
  · exact progR13_shield_ok_l8 ioIn ioOut
  · exact progR13_shield_ok_l9 ioIn ioOut
  · exact progR13_shield_ok_l10 ioIn ioOut
  · exact progR13_shield_ok_l11 ioIn ioOut
  · exact progR13_shield_ok_l12 ioIn ioOut
  · exact progR13_shield_ok_l13 ioIn ioOut
  · exact progR13_shield_ok_l14 ioIn ioOut
  · exact progR13_shield_ok_l15 ioIn ioOut
  · exact progR13_shield_ok_l16 ioIn ioOut
  · exact progR13_shield_ok_l17 ioIn ioOut
  · exact progR13_shield_ok_l18 ioIn ioOut
  · exact progR13_shield_ok_l19 ioIn ioOut
  · exact progR13_shield_ok_l20 ioIn ioOut
  · exact progR13_shield_ok_l21 ioIn ioOut
  · exact progR13_shield_ok_l22 ioIn ioOut
  · exact progR13_shield_ok_l23 ioIn ioOut
  · exact progR13_shield_ok_l24 ioIn ioOut
  · exact progR13_shield_ok_l25 ioIn ioOut

end ZK60.Exec.Block.DefR13
