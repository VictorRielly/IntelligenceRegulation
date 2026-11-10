import ZK60Formal.BlockR13HostSzcProg

open ZK60.Exec.Block ZK60.Exec.Block.Join.R13H.Szc

-- D63 lane L49, sub-agent szc: which field of `SzcCfg` is expensive at a Shieldstral layer?
def L0 : ZK60.RunShape.Shield.ShieldLayer := ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩

theorem p_help : (DefR13.cfgShieldR13 L0).sh.helpers .S = 7 + 1 := rfl
theorem p_lk : (DefR13.lookups (DefR13.cfgShieldR13 L0) .S).length = 13 + 2 * 1 := rfl
theorem p_pad : ZK60.Exec.Slot.W16R2.padOn (DefR13.cfgShieldR13 L0).sh 17 = false := rfl
theorem p_perRow : (DefR13.cfgShieldR13 L0).sh.perRow = 2 ^ (DefR13.cfgShieldR13 L0).sh.lt := rfl
theorem p_raw4 : DefR13.rawSlot (DefR13.cfgShieldR13 L0) 4 = rawRsR (DefR13.cfgShieldR13 L0) := rfl
theorem p_raw8 : DefR13.rawSlot (DefR13.cfgShieldR13 L0) 8 = rawScR (DefR13.cfgShieldR13 L0) := rfl
theorem p_raw17_tabs : (DefR13.rawSlot (DefR13.cfgShieldR13 L0) 17).tabs = (rawSzcR (DefR13.cfgShieldR13 L0) 1).tabs := rfl
theorem p_raw17_ir : (DefR13.rawSlot (DefR13.cfgShieldR13 L0) 17).ir = (rawSzcR (DefR13.cfgShieldR13 L0) 1).ir := rfl
theorem p_raw17_hosted : (DefR13.rawSlot (DefR13.cfgShieldR13 L0) 17).hosted
    = (rawSzcR (DefR13.cfgShieldR13 L0) 1).hosted := rfl
theorem p_raw17_nz : (DefR13.rawSlot (DefR13.cfgShieldR13 L0) 17).nonzero
    = (rawSzcR (DefR13.cfgShieldR13 L0) 1).nonzero := rfl
theorem p_raw17_tail : tabs17Tail (DefR13.cfgShieldR13 L0) 1
    = (List.range 13).map (fun i => DefR13.aPlane (DefR13.cfgShieldR13 L0) (75 + i))
      ++ [DefW16.aTab (DefR13.aOff (DefR13.cfgShieldR13 L0) 4) 12 (DefW16.rhoC 0 12) 0,
          DefW16.aTab (DefR13.aOff (DefR13.cfgShieldR13 L0) 5) 12 (DefW16.rhoC 0 12) 0]
      ++ (List.range 8).map (fun j => DefR13.hTab (DefR13.cfgShieldR13 L0) (DefR13.fh (DefR13.cfgShieldR13 L0) 4 + j))
      ++ [DefR13.hTab (DefR13.cfgShieldR13 L0) (DefR13.fh (DefR13.cfgShieldR13 L0) 5)] := rfl
theorem p_rung_raw17 : DefR13.rawSlot DefR13.cfgRungR13 17 = rawSzcR DefR13.cfgRungR13 2 := rfl
