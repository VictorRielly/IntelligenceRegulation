/-
D63 lane L49 (2026-11-10), sub-agent `szc`, part 3: **`SzcCfg` at the R13 rung and at every Shieldstral layer**, by
evaluation of the raw slots (never of whole programs, finding L44-R4).

* **`szcCfg_rung`**: `SzcCfg DefR13.cfgRungR13 2` (three softmax limbs, nine `Dom::S` helpers, `per_row = 32`);
* `szcCfg_s0` … `szcCfg_s25`: `SzcCfg` at layer `i` of the app's Shieldstral T128 R13 block (`shieldExport[i]`; two
  softmax limbs, eight helpers, `per_row = 128`), one declaration per layer (the elaboration budget of one declaration
  holds one layer's evaluation of slot `17`, not 26; for a symbolic layer it runs out);
* **`szcCfg_shield`**: `SzcCfg (DefR13.cfgShieldR13 L) 1` for every layer `L` of `shieldExport`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostSzcProg

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Szc

open ZK60.Exec.Block
open ZK60.RunShape.Shield (shieldExport)

/-- **The R13 rung's configuration facts.** -/
theorem szcCfg_rung : SzcCfg DefR13.cfgRungR13 2 where
  raw17 := rfl
  raw4 := rfl
  raw8 := rfl
  help := rfl
  lk := rfl
  pad := rfl
  perRow := rfl
  perRowLt := by decide

theorem szcCfg_s0 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨0, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s1 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨1, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s2 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨2, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s3 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨3, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s4 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨4, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s5 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨5, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s6 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨6, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s7 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨7, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s8 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨8, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s9 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨9, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s10 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨10, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s11 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨11, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s12 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨12, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s13 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨13, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s14 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨14, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s15 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨15, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s16 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨16, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s17 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨17, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s18 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨18, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s19 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨19, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s20 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨20, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s21 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨21, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s22 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨22, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s23 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨23, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s24 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨24, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩
theorem szcCfg_s25 : SzcCfg (DefR13.cfgShieldR13 (shieldExport.get ⟨25, by decide⟩)) 1 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩

/-- **Every Shieldstral layer's configuration facts.** -/
theorem szcCfg_shield : ∀ L ∈ shieldExport, SzcCfg (DefR13.cfgShieldR13 L) 1 := by
  intro L hL
  simp only [shieldExport, List.mem_cons, List.not_mem_nil, or_false] at hL
  rcases hL with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  exacts [szcCfg_s0, szcCfg_s1, szcCfg_s2, szcCfg_s3, szcCfg_s4, szcCfg_s5, szcCfg_s6, szcCfg_s7, szcCfg_s8,
    szcCfg_s9, szcCfg_s10, szcCfg_s11, szcCfg_s12, szcCfg_s13, szcCfg_s14, szcCfg_s15, szcCfg_s16, szcCfg_s17,
    szcCfg_s18, szcCfg_s19, szcCfg_s20, szcCfg_s21, szcCfg_s22, szcCfg_s23, szcCfg_s24, szcCfg_s25]

end ZK60.Exec.Block.Join.R13H.Szc
