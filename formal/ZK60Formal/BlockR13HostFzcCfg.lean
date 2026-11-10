/-
D63 lane L49 (2026-11-10), sub-agent `fzc`, part 3: **`FzcCfg` at the R13 rung and at every Shieldstral layer**, by
evaluation of the raw slots `18`, `11`, `12` one field at a time (never of whole programs, finding L44-R4).

* **`fzcCfg_rung`**: `FzcCfg DefR13.cfgRungR13 2` (`Dom::F` of log `15`, `F` planes from `90`);
* **`fzcCfg_shield`**: `FzcCfg (DefR13.cfgShieldR13 L) 1` for every layer `L` of the Shieldstral export (`Dom::F` of
  log `21`, `F` planes from `88`): slots `11`, `12`, slot `18`'s hosted list and draws are checked for a symbolic
  layer; slot `18`'s tables and IR one layer at a time (for a symbolic layer the elaborator's evaluation reaches the
  recursion limit); the gate shift's bound `≤ 24` is the export's (`shield_layers_ok`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostFzc

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Fzc

open ZK60.Exec.Block

/-! ## The R13 rung -/

theorem tabs18_rung : (DefR13.rawSlot DefR13.cfgRungR13 18).tabs = tabsFR DefR13.cfgRungR13 2 := rfl
theorem ir18_rung : (DefR13.rawSlot DefR13.cfgRungR13 18).ir = irFR DefR13.cfgRungR13 2 := rfl
theorem host18_rung : (DefR13.rawSlot DefR13.cfgRungR13 18).hosted = [(11, .dr 18 12), (12, .dr 18 13)] := rfl
theorem tabs11_rung : (DefR13.rawSlot DefR13.cfgRungR13 11).tabs = tabsGU DefR13.cfgRungR13 := rfl
theorem ir11_rung : (DefR13.rawSlot DefR13.cfgRungR13 11).ir = ZK60.Exec.Slot.Build.mmIr DefW16.cstS 0 1 := rfl
theorem host11_rung : (DefR13.rawSlot DefR13.cfgRungR13 11).hosted = [] := rfl
theorem tabs12_rung : (DefR13.rawSlot DefR13.cfgRungR13 12).tabs = tabsGU DefR13.cfgRungR13 := rfl
theorem ir12_rung : (DefR13.rawSlot DefR13.cfgRungR13 12).ir = ZK60.Exec.Slot.Build.mmIr DefW16.cstS 0 1 := rfl
theorem host12_rung : (DefR13.rawSlot DefR13.cfgRungR13 12).hosted = [] := rfl
theorem dl18_rung : ZK60.Exec.Slot.R13.draws DefR13.cfgRungR13.sh 18
    = [(.mu, 12), (.nu, 2), (.zeta, 1), (.tau, DefR13.cfgRungR13.sh.logs .F)] := rfl
theorem nlk_rung : (DefR13.lookups DefR13.cfgRungR13 .F).length = 14 := rfl

/-- **The R13 rung's configuration facts for `SC_FZC`.** -/
theorem fzcCfg_rung : FzcCfg DefR13.cfgRungR13 2 :=
  ⟨tabs18_rung, ir18_rung, host18_rung, tabs11_rung, ir11_rung, host11_rung, tabs12_rung, ir12_rung, host12_rung,
    dl18_rung, nlk_rung, by decide, by decide, by decide⟩

/-! ## Every Shieldstral layer -/

section Shield

variable (L : ZK60.RunShape.Shield.ShieldLayer)

theorem host18_shield :
    (DefR13.rawSlot (DefR13.cfgShieldR13 L) 18).hosted = [(11, .dr 18 12), (12, .dr 18 13)] := rfl
theorem tabs11_shield : (DefR13.rawSlot (DefR13.cfgShieldR13 L) 11).tabs = tabsGU (DefR13.cfgShieldR13 L) := rfl
theorem ir11_shield :
    (DefR13.rawSlot (DefR13.cfgShieldR13 L) 11).ir = ZK60.Exec.Slot.Build.mmIr DefW16.cstS 0 1 := rfl
theorem host11_shield : (DefR13.rawSlot (DefR13.cfgShieldR13 L) 11).hosted = [] := rfl
theorem tabs12_shield : (DefR13.rawSlot (DefR13.cfgShieldR13 L) 12).tabs = tabsGU (DefR13.cfgShieldR13 L) := rfl
theorem ir12_shield :
    (DefR13.rawSlot (DefR13.cfgShieldR13 L) 12).ir = ZK60.Exec.Slot.Build.mmIr DefW16.cstS 0 1 := rfl
theorem host12_shield : (DefR13.rawSlot (DefR13.cfgShieldR13 L) 12).hosted = [] := rfl
theorem dl18_shield : ZK60.Exec.Slot.R13.draws (DefR13.cfgShieldR13 L).sh 18
    = [(.mu, 12), (.nu, 2), (.zeta, 1), (.tau, (DefR13.cfgShieldR13 L).sh.logs .F)] := rfl
theorem nlk_shield : (DefR13.lookups (DefR13.cfgShieldR13 L) .F).length = 14 := rfl

end Shield

/-- Slot `18`'s raw tables at every layer, one layer at a time (for a symbolic layer the elaborator's evaluation of
slot `18` reaches the recursion limit). -/
theorem tabs18_shield : ∀ L ∈ ZK60.RunShape.Shield.shieldExport,
    (DefR13.rawSlot (DefR13.cfgShieldR13 L) 18).tabs = tabsFR (DefR13.cfgShieldR13 L) 1 := by
  intro L hL
  simp only [ZK60.RunShape.Shield.shieldExport, List.mem_cons, List.not_mem_nil, or_false] at hL
  rcases hL with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> rfl

/-- Slot `18`'s raw IR at every layer, one layer at a time (the layer's gate shift enters the lookups' pins). -/
theorem ir18_shield : ∀ L ∈ ZK60.RunShape.Shield.shieldExport,
    (DefR13.rawSlot (DefR13.cfgShieldR13 L) 18).ir = irFR (DefR13.cfgShieldR13 L) 1 := by
  intro L hL
  simp only [ZK60.RunShape.Shield.shieldExport, List.mem_cons, List.not_mem_nil, or_false] at hL
  rcases hL with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> rfl

/-- **Every Shieldstral layer's configuration facts for `SC_FZC`** (the gate shift's bound from the export). -/
theorem fzcCfg_shield : ∀ L ∈ ZK60.RunShape.Shield.shieldExport, FzcCfg (DefR13.cfgShieldR13 L) 1 := by
  intro L hL
  have hg : L.gate ≤ 24 := (ZK60.RunShape.Shield.shield_layers_ok L hL).2.2.2.2.2.2.2.1
  exact ⟨tabs18_shield L hL, ir18_shield L hL, host18_shield L, tabs11_shield L, ir11_shield L, host11_shield L,
    tabs12_shield L, ir12_shield L, host12_shield L, dl18_shield L, nlk_shield L,
    show (16 : ℕ) < 64 by norm_num, show L.gate < 64 by omega, show (12 : ℕ) < 64 by norm_num⟩

end ZK60.Exec.Block.Join.R13H.Fzc
