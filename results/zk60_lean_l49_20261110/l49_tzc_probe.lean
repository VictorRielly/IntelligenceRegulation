import ZK60Formal.BlockR13JoinForm
import ZK60Formal.BlockJoinTzcForm
import ZK60Formal.BlockHostBase

set_option autoImplicit false

namespace L49TzcProbe

open ZK60.Exec ZK60.Exec.Block
open ZK60.Exec.Block.DefW16 (W16Cfg cstS aTab rhoC)
open ZK60.Exec.Slot.Build (ssIr tzcIr TzcR)
open ZK60.Exec.Slot.W16R2 (Seg segOff segLn segSum)

def drS (s off n : ℕ) : List Sym := (List.range n).map fun i => Sym.dr s (off + i)

def aTz (off log : ℕ) : TabS := aTab off log (rhoC 0 log) 0

def rawSsR (c : W16Cfg) (s q : ℕ) : SlotS :=
  ⟨[TabS.eq (drS s 0 c.sh.lt) 0, aTz (DefR13.aOff c q) (c.sh.lt + c.sh.ld), TabS.pub 0], ssIr cstS 0 1 (some 2),
    [], []⟩

def tabsTzcR (c : W16Cfg) : List TabS :=
  [TabS.eq (drS 2 0 c.sh.lt) 0, TabS.eq (drS 0 0 c.sh.lt) 0, TabS.eq (drS 1 0 c.sh.lt) 0,
    aTz (DefR13.aOff c 0) c.sh.lt, aTz (DefR13.aOff c 1) c.sh.lt,
    aTz (DefR13.aOff c 6 + 0 * 2 ^ c.sh.lt) c.sh.lt, aTz (DefR13.aOff c 6 + 1 * 2 ^ c.sh.lt) c.sh.lt,
    aTz (DefR13.aOff c 6 + 2 * 2 ^ c.sh.lt) c.sh.lt, aTz (DefR13.aOff c 6 + 3 * 2 ^ c.sh.lt) c.sh.lt,
    aTz (DefR13.aOff c 6 + 4 * 2 ^ c.sh.lt) c.sh.lt, aTz (DefR13.aOff c 6 + 5 * 2 ^ c.sh.lt) c.sh.lt,
    aTz (DefR13.aOff c 6 + 6 * 2 ^ c.sh.lt) c.sh.lt, aTz (DefR13.aOff c 6 + 7 * 2 ^ c.sh.lt) c.sh.lt,
    aTz (DefR13.aOff c 6 + 8 * 2 ^ c.sh.lt) c.sh.lt,
    aTz (DefR13.aOff c 2) c.sh.lt, aTz (DefR13.aOff c 3) c.sh.lt,
    aTz (DefR13.aOff c 7 + 0 * 2 ^ c.sh.lt) c.sh.lt, aTz (DefR13.aOff c 7 + 1 * 2 ^ c.sh.lt) c.sh.lt,
    aTz (DefR13.aOff c 7 + 2 * 2 ^ c.sh.lt) c.sh.lt, aTz (DefR13.aOff c 7 + 3 * 2 ^ c.sh.lt) c.sh.lt,
    aTz (DefR13.aOff c 7 + 4 * 2 ^ c.sh.lt) c.sh.lt, aTz (DefR13.aOff c 7 + 5 * 2 ^ c.sh.lt) c.sh.lt,
    aTz (DefR13.aOff c 7 + 6 * 2 ^ c.sh.lt) c.sh.lt, aTz (DefR13.aOff c 7 + 7 * 2 ^ c.sh.lt) c.sh.lt,
    aTz (DefR13.aOff c 7 + 8 * 2 ^ c.sh.lt) c.sh.lt]

def rrT : TzcR := ⟨0, 1, 2, 3, 4, 14, 15, none⟩

def irTzcR (c : W16Cfg) : ZK60.Exec.Slot.Ir Sym :=
  tzcIr cstS rrT c.p.ceps (drS 2 c.sh.lt 6) (drS 2 (c.sh.lt + 6) 2) (fun j => Sym.pow Sym.zero j) []

def rawTzcR (c : W16Cfg) : SlotS :=
  ⟨tabsTzcR c, irTzcR c, [(0, Sym.dr 2 (c.sh.lt + 6)), (1, Sym.dr 2 (c.sh.lt + 7))], drS 2 (c.sh.lt + 6) 2⟩

theorem t_raw2_rung : DefR13.rawSlot DefR13.cfgRungR13 2 = rawTzcR DefR13.cfgRungR13 := rfl
theorem t_raw0_rung : DefR13.rawSlot DefR13.cfgRungR13 0 = rawSsR DefR13.cfgRungR13 0 8 := rfl
theorem t_raw1_rung : DefR13.rawSlot DefR13.cfgRungR13 1 = rawSsR DefR13.cfgRungR13 1 26 := rfl

theorem t_raw2_shield (L : ZK60.RunShape.Shield.ShieldLayer) :
    DefR13.rawSlot (DefR13.cfgShieldR13 L) 2 = rawTzcR (DefR13.cfgShieldR13 L) := rfl
theorem t_raw0_shield (L : ZK60.RunShape.Shield.ShieldLayer) :
    DefR13.rawSlot (DefR13.cfgShieldR13 L) 0 = rawSsR (DefR13.cfgShieldR13 L) 0 8 := rfl
theorem t_raw1_shield (L : ZK60.RunShape.Shield.ShieldLayer) :
    DefR13.rawSlot (DefR13.cfgShieldR13 L) 1 = rawSsR (DefR13.cfgShieldR13 L) 1 26 := rfl

theorem t_dl2_rung : ZK60.Exec.Slot.R13.draws DefR13.cfgRungR13.sh 2
    = [(.tau, DefR13.cfgRungR13.sh.lt), (.mu, 6), (.nu, 2), (.zeta, 0)] := rfl
theorem t_dl2_shield (L : ZK60.RunShape.Shield.ShieldLayer) : ZK60.Exec.Slot.R13.draws (DefR13.cfgShieldR13 L).sh 2
    = [(.tau, (DefR13.cfgShieldR13 L).sh.lt), (.mu, 6), (.nu, 2), (.zeta, 0)] := rfl

theorem t_ceps_shield (L : ZK60.RunShape.Shield.ShieldLayer) :
    -2 ^ 64 < (DefR13.cfgShieldR13 L).p.ceps ∧ (DefR13.cfgShieldR13 L).p.ceps < 2 ^ 64 := by
  show -2 ^ 64 < (2439 : ℤ) ∧ (2439 : ℤ) < 2 ^ 64
  norm_num

theorem t_ceps_rung : -2 ^ 64 < DefR13.cfgRungR13.p.ceps ∧ DefR13.cfgRungR13.p.ceps < 2 ^ 64 := by
  show -2 ^ 64 < (1 : ℤ) ∧ (1 : ℤ) < 2 ^ 64
  norm_num

theorem t_sched2 (c : W16Cfg) : (ZK60.Exec.Slot.W16R2.sched c.sh 2).1 = c.sh.logs .T := rfl
theorem t_sched0 (c : W16Cfg) : (ZK60.Exec.Slot.W16R2.sched c.sh 0).1 = c.sh.logs .D := rfl
theorem t_sched1 (c : W16Cfg) : (ZK60.Exec.Slot.W16R2.sched c.sh 1).1 = c.sh.logs .D := rfl

theorem t_fin (c : W16Cfg) : DefR13.aOff c 6 + 5 * 2 ^ c.sh.lt
    = DefR13.aOff c 6 + (3 * ((1 : Fin 3) : ℕ) + ((2 : Fin 3) : ℕ)) * 2 ^ c.sh.lt := rfl

theorem t_segoffT (c : W16Cfg) : segOff (ZK60.Exec.Slot.R13.draws c.sh 2) .tau = 0 := rfl
theorem t_segLnT (c : W16Cfg) : segLn (ZK60.Exec.Slot.R13.draws c.sh 2) .tau = c.sh.lt := rfl

theorem t_segs (c : W16Cfg)
    (h : ZK60.Exec.Slot.R13.draws c.sh 2 = [(.tau, c.sh.lt), (.mu, 6), (.nu, 2), (.zeta, 0)]) :
    segOff (ZK60.Exec.Slot.R13.draws c.sh 2) .mu = c.sh.lt
      ∧ segOff (ZK60.Exec.Slot.R13.draws c.sh 2) .nu = c.sh.lt + 6
      ∧ segSum (ZK60.Exec.Slot.R13.draws c.sh 2) = c.sh.lt + 8
      ∧ segLn (ZK60.Exec.Slot.R13.draws c.sh 2) .mu - segLn (ZK60.Exec.Slot.R13.draws c.sh 2) .zeta = 6
      ∧ segLn (ZK60.Exec.Slot.R13.draws c.sh 2) .zeta = 0 := by
  rw [h]
  refine ⟨rfl, rfl, ?_, rfl, rfl⟩
  simp [segSum]

end L49TzcProbe
