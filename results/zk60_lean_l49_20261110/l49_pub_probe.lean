/- D63 lane L49, sub-agent pub: probe of the SC_LZC part of BlockR13HostPub.lean (independent of the foundation). -/
import ZK60Formal.BlockR13JoinTab

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.PubProbe

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (wordGF toK_wordGF cubeTab cubeTab_getD drSeg foldTab fold_eqDr)
open ZK60.Exec.Block.Join.R13T (restR13)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.W16R2 (ShapeW)
open ZK60.Circuit (gP GF)

def gateLS (sh : ShapeW) (b : Fin (sh.logs .L) → Bool) : GF := if msbIndex (sh.logs .L) b / 2 ^ sh.lt < 9 then 1 else 0

theorem gateLS_rung : gateLS ZK60.Exec.Slot.R13.shRungR13 = ZK60.Exec.Block.Join.W16.Tab.gateLW := rfl

theorem restR13_three (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) (hist : Hist) (dr : List Fp2) (i : ℕ) :
    restR13 exp act nG 3 hist dr i = [] := rfl

def restR13L (c : W16Cfg) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) : PubTabs := fun s hist dr i =>
  if s = 3 then (if i = 0 then cubeTab (c.sh.logs .L) (gateLS c.sh) else []) else restR13 exp act nG s hist dr i

variable (c : W16Cfg) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ)

theorem restR13L_ne (s : ℕ) (hs : s ≠ 3) (hist : Hist) (dr : List Fp2) (i : ℕ) :
    restR13L c exp act nG s hist dr i = restR13 exp act nG s hist dr i := by
  show (if s = 3 then _ else _) = _
  rw [ite_eq_right hs]

theorem rest3R13L_getD {K : Type} [Field K] [Algebra GF K] (U : K) (hist : Hist) (dr : List Fp2)
    (b : Fin (c.sh.logs .L) → Bool) :
    ((restR13L c exp act nG 3 hist dr 0).getD (msbIndex (c.sh.logs .L) b) Fp2.zero).toK U
      = algebraMap GF K (gateLS c.sh b) := by
  show ((cubeTab (c.sh.logs .L) (gateLS c.sh)).getD _ _).toK U = _
  rw [cubeTab_getD, toK_wordGF]

structure PubCfg (c : W16Cfg) : Prop where
  padRule : c.sh.padRule = true
  padsL : c.sh.pads .L = true

theorem pubCfg_rung : PubCfg DefR13.cfgRungR13 := ⟨rfl, rfl⟩

theorem pubCfg_shield (L : ZK60.RunShape.Shield.ShieldLayer) : PubCfg (DefR13.cfgShieldR13 L) := ⟨rfl, rfl⟩

theorem idsR13_e (h24 : Bool) (ls : ℕ) : (DefR13.idsR13 h24 ls).e = 77 + (if h24 then 3 else 2) := by
  cases h24 <;> rfl

theorem zeroPl_L (c : W16Cfg) (hc : PubCfg c) : DefR13.zeroPl c .L = [6, 7] := by
  have he : 79 ≤ (DefR13.ids c).e := by
    show 79 ≤ (DefR13.idsR13 c.p.h24 (DefR13.lsOf c.p)).e
    rw [idsR13_e]
    split <;> omega
  have h6 : (6 == (DefR13.ids c).e) = false := beq_eq_false_iff_ne.mpr (by omega)
  have h7 : (7 == (DefR13.ids c).e) = false := beq_eq_false_iff_ne.mpr (by omega)
  unfold DefR13.zeroPl
  rw [hc.padRule, hc.padsL]
  show List.filter (fun i => !(i == (DefR13.ids c).e)) [6, 7] = [6, 7]
  simp [h6, h7]

theorem zeroPl_L2 (c : W16Cfg) (hc : PubCfg c) : DefR13.zeroPl c .L = [6, 7] := by
  have he : 79 ≤ (DefR13.ids c).e := by
    show 79 ≤ (DefR13.idsR13 c.p.h24 (DefR13.lsOf c.p)).e
    rw [idsR13_e]
    split <;> omega
  have h6 : (6 == (DefR13.ids c).e) = false := beq_eq_false_iff_ne.mpr (by omega)
  have h7 : (7 == (DefR13.ids c).e) = false := beq_eq_false_iff_ne.mpr (by omega)
  unfold DefR13.zeroPl
  rw [hc.padRule, hc.padsL]
  show List.filter (fun i => !(i == (DefR13.ids c).e)) [6, 7] = [6, 7]
  simp [List.filter, h6, h7]

theorem zeroPl_L3 (c : W16Cfg) (hc : PubCfg c) : DefR13.zeroPl c .L = [6, 7] := by
  have he : 79 ≤ (DefR13.ids c).e := by
    show 79 ≤ (DefR13.idsR13 c.p.h24 (DefR13.lsOf c.p)).e
    rw [idsR13_e]
    split <;> omega
  have h6 : (6 == (DefR13.ids c).e) = false := beq_eq_false_iff_ne.mpr (by omega)
  have h7 : (7 == (DefR13.ids c).e) = false := beq_eq_false_iff_ne.mpr (by omega)
  unfold DefR13.zeroPl
  rw [hc.padRule, hc.padsL]
  show List.filter (fun i => !(i == (DefR13.ids c).e)) [6, 7] = [6, 7]
  rw [List.filter_cons, List.filter_cons, List.filter_nil]
  simp only [h6, h7, Bool.not_false, ↓reduceIte]

theorem lzc_gate (c : W16Cfg) (hc : PubCfg c) :
    (ZK60.Exec.Block.DefW16.supp c .L && !(DefR13.zeroPl c .L).isEmpty) = true := by
  rw [zeroPl_L c hc]
  show (c.sh.padRule && c.sh.pads .L && !([6, 7] : List ℕ).isEmpty) = true
  rw [hc.padRule, hc.padsL]
  rfl

theorem rawSlot3_tabs (c : W16Cfg) (hc : PubCfg c) :
    (DefR13.rawSlot c 3).tabs = [TabS.eq (DefR13.seg c 3 0) 0, DefR13.aPlane c (DefR13.ids c).limb,
      DefR13.aPlane c (DefR13.ids c).limbm, DefR13.hTab c (DefR13.fh c 0), TabS.pub 0] := by
  show [TabS.eq (DefR13.seg c 3 0) 0, DefR13.aPlane c (DefR13.ids c).limb, DefR13.aPlane c (DefR13.ids c).limbm,
      DefR13.hTab c (DefR13.fh c 0)]
      ++ (if (ZK60.Exec.Block.DefW16.supp c .L && !(DefR13.zeroPl c .L).isEmpty) = true then [TabS.pub 0] else []) = _
  rw [lzc_gate c hc]
  rfl

#print axioms rawSlot3_tabs
#print axioms rest3R13L_getD
#print axioms gateLS_rung

end ZK60.Exec.Block.Join.R13H.PubProbe
