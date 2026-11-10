import ZK60Formal.BlockR13Prog

set_option autoImplicit false

namespace L49LookProbe

open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.Build.Lay (LkW PrecW)
open ZK60.Exec.Slot.W16R2 (Dom)

def bLk (q : ℕ) : LkW := ⟨[(q, 1)], 0, 8⟩
def pLk (q e : ℕ) : LkW := ⟨[(q, 2 ^ e)], 0, 8⟩

def lkFe (p : PrecW) (ls : ℕ) : List LkW :=
  [bLk (86 + 2 * ls + 1), bLk (86 + 2 * ls + 2), bLk (86 + 2 * ls + 3), pLk (86 + 2 * ls + 3) (8 * 3 - p.gate),
    bLk (86 + 2 * ls + 6), bLk (86 + 2 * ls + 7), bLk (86 + 2 * ls + 8), bLk (86 + 2 * ls + 9),
    pLk (86 + 2 * ls + 9) (8 * 2 - p.up), bLk (86 + 2 * ls + 11), bLk (86 + 2 * ls + 12), bLk (86 + 2 * ls + 13),
    bLk (86 + 2 * ls + 14), bLk (86 + 2 * ls + 15)]

def lkFc (p : PrecW) (ls : ℕ) : List LkW :=
  [bLk (84 + 2 * (ls + 1) + 1), bLk (84 + 2 * (ls + 1) + 2), bLk (84 + 2 * (ls + 1) + 3),
    pLk (84 + 2 * (ls + 1) + 3) (8 * 3 - p.gate), bLk (84 + 2 * (ls + 1) + 6), bLk (84 + 2 * (ls + 1) + 7),
    bLk (84 + 2 * (ls + 1) + 8), bLk (84 + 2 * (ls + 1) + 9), pLk (84 + 2 * (ls + 1) + 9) (8 * 2 - p.up),
    bLk (84 + 2 * (ls + 1) + 11), bLk (84 + 2 * (ls + 1) + 12), bLk (84 + 2 * (ls + 1) + 13),
    bLk (84 + 2 * (ls + 1) + 14), bLk (84 + 2 * (ls + 1) + 15)]

theorem ids_shield (L : ZK60.RunShape.Shield.ShieldLayer) :
    DefR13.ids (DefR13.cfgShieldR13 L) = DefR13.idsR13 true 2 := by
  show DefR13.idsR13 (DefR13.cfgShieldR13 L).p.h24 (DefR13.lsOf (DefR13.cfgShieldR13 L).p) = _
  rw [show (DefR13.cfgShieldR13 L).p.h24 = true from rfl]
  show DefR13.idsR13 true (((DefR13.cfgShieldR13 L).p.wrho + 7) / 8) = _
  rw [show (DefR13.cfgShieldR13 L).p.wrho = 16 from rfl]

theorem v1 (L : ZK60.RunShape.Shield.ShieldLayer) :
    DefR13.lookups (DefR13.cfgShieldR13 L) .F = lkFe (DefR13.cfgShieldR13 L).p 1 := by
  unfold DefR13.lookups
  rw [ids_shield L]
  rfl

theorem v4 (L : ZK60.RunShape.Shield.ShieldLayer) :
    DefR13.lookups (DefR13.cfgShieldR13 L) .F = lkFe (DefR13.cfgShieldR13 L).p 1 := by
  simp [DefR13.lookups, ids_shield L, DefR13.idsR13, DefR13.bytes, lkFe, bLk, pLk]

theorem v5 (L : ZK60.RunShape.Shield.ShieldLayer) :
    DefR13.lookups (DefR13.cfgShieldR13 L) .F = lkFc (DefR13.cfgShieldR13 L).p 1 := rfl

theorem v6 (L : ZK60.RunShape.Shield.ShieldLayer) :
    DefR13.lookups (DefR13.cfgShieldR13 L) .F = lkFc (DefR13.cfgShieldR13 L).p 1 := by
  unfold DefR13.lookups
  rw [ids_shield L]
  rfl

-- the generic lists at a symbolic configuration
theorem ids_of (c : W16Cfg) {ls : ℕ} (h24 : c.p.h24 = true) (hls : DefR13.lsOf c.p = ls + 1) :
    DefR13.ids c = DefR13.idsR13 true (ls + 1) := by
  unfold DefR13.ids
  rw [h24, hls]

theorem g6 (c : W16Cfg) {ls : ℕ} (h24 : c.p.h24 = true) (hls : DefR13.lsOf c.p = ls + 1) :
    DefR13.lookups c .F = lkFc c.p ls := by
  unfold DefR13.lookups
  rw [ids_of c h24 hls]
  rfl

theorem shSh (L : ZK60.RunShape.Shield.ShieldLayer) :
    (DefR13.cfgShieldR13 L).sh = ZK60.Exec.Slot.R13.shShieldR13 := rfl

theorem c1 (L : ZK60.RunShape.Shield.ShieldLayer) :
    2 ^ (DefR13.cfgShieldR13 L).sh.logs .S + (2 ^ (DefR13.cfgShieldR13 L).sh.logs .S
      + 2 ^ (DefR13.cfgShieldR13 L).sh.logs .F) = 3145728 := by
  rw [shSh]
  decide +kernel

theorem c2 (L : ZK60.RunShape.Shield.ShieldLayer) :
    2 ^ (DefR13.cfgShieldR13 L).sh.logs .S + (2 ^ (DefR13.cfgShieldR13 L).sh.logs .S
      + 2 ^ (DefR13.cfgShieldR13 L).sh.logs .F) = 3145728 := by
  rw [shSh]
  rfl

end L49LookProbe
