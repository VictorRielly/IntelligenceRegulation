/-
D63 W16R2 Shieldstral port, Item (5b) (`BlockDefineW16Shield.lean`):
**the W16R2 Shieldstral T128 (`export_u1`) slot program `progW16 (cfgShieldU1 cnA cnM)` evaluated,
and `block_knowledge_define_alg_w16r2_shieldU1` discharging the tables part of the slot polynomials
for all 26 layers of `export_u1` at once.**

Because `export_u1` is A29-uniform (`RunShapeShieldU1.shieldExportU1_uniform`), all 26 layers share
identical `ShapeW` (`shShieldW16U1`), `fams` (`famsShieldW16U1`, `nRange = 13`), `logCols = 14`,
shifts (`ao = 21, score = 19, down = 22, gate = 20, wrho = 16`), plane IDs (`q0 = 27, k0 = 33,
s0 = 39, f0 = 47, t0 = 56`, `72` `A` planes, `44` `H` planes), data rows (`aDataRows = 2280`,
`hDataRows = 2516`, total rows `2504 / 2606`), and table counts (`aCntW16Shield` = 111,
`hCntW16Shield` = 44 + 1 = 45). Only `(cnA, cnM)` vary across the 26 layers, and they enter
`rawSlot` solely as constant coefficients inside `SC_DZC`'s `dzcIr`, which neither `cmCountS` nor
`progOKb` inspects — so one single `decide +kernel` evaluation discharges all 26 layers simultaneously.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.BlockDefineAlg
import ZK60Formal.BlockInstW16Shield
import ZK60Formal.RunShapeShieldU1

set_option autoImplicit false

namespace ZK60.Exec.Block.DefW16

open ZK60.Exec
open ZK60.Exec.Slot.W16R2 (Dom shShieldW16U1)
open ZK60.Exec.Slot.Build.Lay (PrecW)
open ZK60.RunShape.Shield (ShieldLayer)
open ZK60.RunShape.ShieldU1 (shieldExportU1 shieldExportU1_uniform precShieldW16U1 famsShieldW16U1)

/-- The A29-uniform precision of `export_u1` parameterized by per-layer norm calibrations
`(cnA, cnM)` (all other fields are identical across all 26 layers of `shieldExportU1`). -/
def precShieldU1 (cnA cnM : ℕ) : PrecW :=
  { h24 := true, tn := 1, cnA := cnA, cnM := cnM, ceps := 2439, q := 15, k := 15, v := 16,
    score := 19, pv := 12, ao := 21, gate := 20, up := 12, prodbits := 24, down := 22,
    fp := 12, wrho := 16, rope := 7, fold := 16 }

/-- **The W16R2 Shieldstral T128 (`export_u1`) configuration** for norm calibrations `(cnA, cnM)`. -/
def cfgShieldU1 (cnA cnM : ℕ) : W16Cfg :=
  ⟨shShieldW16U1, precShieldU1 cnA cnM, famsShieldW16U1, 14⟩

/-- For every one of the 26 layers `c ∈ shieldExportU1`, `precShieldW16U1 c = precShieldU1 c.cnA c.cnM`. -/
theorem precShieldW16U1_eq (c : ShieldLayer) (hc : c ∈ shieldExportU1) :
    precShieldW16U1 c = precShieldU1 c.cnA c.cnM := by
  obtain ⟨hao, hs, hz, hgate, -⟩ := shieldExportU1_uniform c hc
  unfold precShieldW16U1 precShieldU1
  simp only [hao, hs, hz, hgate]

/-- Plane IDs at `export_u1`: `q0 = 27, k0 = 33, s0 = 39, f0 = 47, t0 = 56`, total `A` planes `72`. -/
theorem idsW_shieldU1 (cnA cnM : ℕ) :
    let I := idsW (precShieldU1 cnA cnM)
    [I.q0, I.k0, I.s0, I.f0, I.t0, I.t0 + 3 + nRange (cfgShieldU1 cnA cnM)] = [27, 33, 39, 47, 56, 72] := by
  change [((idsW (precShieldU1 0 0)).q0), ((idsW (precShieldU1 0 0)).k0), ((idsW (precShieldU1 0 0)).s0),
    ((idsW (precShieldU1 0 0)).f0), ((idsW (precShieldU1 0 0)).t0),
    ((idsW (precShieldU1 0 0)).t0 + 3 + nRange (cfgShieldU1 0 0))] = [27, 33, 39, 47, 56, 72]
  decide +kernel

/-- The lookups give `shShieldW16U1`'s helper counts (`L:1, D:10, Q:3, Kv:3, S:4, F:4`), matching
`hDoms.length = 44` `H` planes. -/
theorem helpers_shieldU1 (cnA cnM : ℕ) :
    [Dom.L, .D, .Q, .Kv, .S, .F].map (nHelp (cfgShieldU1 cnA cnM))
      = [Dom.L, .D, .Q, .Kv, .S, .F].map shShieldW16U1.helpers
    ∧ (hDoms (cfgShieldU1 cnA cnM)).length = 44 := by
  change [Dom.L, .D, .Q, .Kv, .S, .F].map (nHelp (cfgShieldU1 0 0))
      = [Dom.L, .D, .Q, .Kv, .S, .F].map shShieldW16U1.helpers
    ∧ (hDoms (cfgShieldU1 0 0)).length = 44
  decide +kernel

/-- Data row counts of `A` and `H` at `export_u1`: `aDataRows = 2280` (`aRows = 2280 + 2*111 + 2 = 2504`),
`hDataRows = 2516` (`hRows = 2516 + 2*44 + 2 = 2606`). -/
theorem dataRows_shieldU1 (cnA cnM : ℕ) :
    aDataRows (cfgShieldU1 cnA cnM) = 2280 ∧ hDataRows (cfgShieldU1 cnA cnM) = 2516 := by
  change aDataRows (cfgShieldU1 0 0) = 2280 ∧ hDataRows (cfgShieldU1 0 0) = 2516
  decide +kernel

private theorem idsW_u1 (a m : ℕ) : idsW (cfgShieldU1 a m).p = idsW (cfgShieldU1 0 0).p := rfl
private theorem sh_u1 (a m : ℕ) : (cfgShieldU1 a m).sh = (cfgShieldU1 0 0).sh := rfl
private theorem logCols_u1 (a m : ℕ) : (cfgShieldU1 a m).logCols = (cfgShieldU1 0 0).logCols := rfl
private theorem nRange_u1 (a m : ℕ) : nRange (cfgShieldU1 a m) = nRange (cfgShieldU1 0 0) := rfl
private theorem subW_u1 (a m : ℕ) : subW (cfgShieldU1 a m) = subW (cfgShieldU1 0 0) := rfl
private theorem domStart_u1 (a m : ℕ) (d : Dom) : domStart (cfgShieldU1 a m) d = domStart (cfgShieldU1 0 0) d := rfl
private theorem domPl_u1 (a m : ℕ) (d : Dom) : domPl (cfgShieldU1 a m) d = domPl (cfgShieldU1 0 0) d := rfl
private theorem aOff_u1 (a m q : ℕ) : aOff (cfgShieldU1 a m) q = aOff (cfgShieldU1 0 0) q := rfl
private theorem logOf_u1 (a m q : ℕ) : logOf (cfgShieldU1 a m) q = logOf (cfgShieldU1 0 0) q := rfl
private theorem nHelp_u1 (a m : ℕ) (d : Dom) : nHelp (cfgShieldU1 a m) d = nHelp (cfgShieldU1 0 0) d := rfl
private theorem fh_u1 (a m k : ℕ) : fh (cfgShieldU1 a m) k = fh (cfgShieldU1 0 0) k := rfl
private theorem zeroPl_u1 (a m : ℕ) (d : Dom) : zeroPl (cfgShieldU1 a m) d = zeroPl (cfgShieldU1 0 0) d := rfl
private theorem aPlane_u1 (a m : ℕ) : aPlane (cfgShieldU1 a m) = aPlane (cfgShieldU1 0 0) := funext fun _ => rfl
private theorem hTab_u1 (a m hp : ℕ) : hTab (cfgShieldU1 a m) hp = hTab (cfgShieldU1 0 0) hp := rfl
private theorem epTab_u1 (a m : ℕ) (cm : Cm) : epTab (cfgShieldU1 a m) cm = epTab (cfgShieldU1 0 0) cm := rfl
private theorem supp_u1 (a m : ℕ) (d : Dom) : supp (cfgShieldU1 a m) d = supp (cfgShieldU1 0 0) d := rfl
private theorem seg_u1 (a m s j : ℕ) : seg (cfgShieldU1 a m) s j = seg (cfgShieldU1 0 0) s j := rfl
private theorem claimPt_u1 (a m s : ℕ) : claimPt (cfgShieldU1 a m) s = claimPt (cfgShieldU1 0 0) s := rfl
private theorem lksS_u1 (a m : ℕ) (f : ℕ → ℕ) (d : Dom) : lksS (cfgShieldU1 a m) f d = lksS (cfgShieldU1 0 0) f d := rfl
private theorem padGroup_u1 (a m : ℕ) (d : Dom) (gi : ℕ) (f : ℕ → ℕ) :
    padGroup (cfgShieldU1 a m) d gi f = padGroup (cfgShieldU1 0 0) d gi f := rfl

/-- For every slot `s ≠ 14` (`SC_DZC`), `rawSlot (cfgShieldU1 cnA cnM) s` is identical to `rawSlot (cfgShieldU1 0 0) s`. -/
theorem rawSlot_shieldU1_ne14 (cnA cnM s : ℕ) (h14 : s ≠ 14) :
    rawSlot (cfgShieldU1 cnA cnM) s = rawSlot (cfgShieldU1 0 0) s := by
  unfold rawSlot
  simp only [idsW_u1, sh_u1, logCols_u1, nRange_u1, subW_u1, domStart_u1, domPl_u1, aOff_u1, logOf_u1,
    nHelp_u1, fh_u1, zeroPl_u1, aPlane_u1, hTab_u1, epTab_u1, supp_u1, seg_u1, claimPt_u1, lksS_u1, padGroup_u1,
    show s ≠ Slot.W16R2.scDZC from h14, ↓reduceIte]
  rfl

/-- For slot `14` (`SC_DZC`), `rawSlot (cfgShieldU1 cnA cnM) 14` shares `tabs`, `hosted`, `nonzero`,
and all structural IR arguments with `cfgShieldU1 0 0`, varying only in `(2 * cnA, 2 * cnM)`. -/
theorem rawSlot_shieldU1_14_eq (cnA cnM : ℕ) :
    rawSlot (cfgShieldU1 cnA cnM) 14 =
      let c := cfgShieldU1 0 0
      let I := idsW c.p
      let shaped := fun q : ℕ => 5 + (q - 8)
      let n := (domPl c .D).length
      let nh := nHelp c .D
      let gi := 7 + n + nh
      ⟨(rawSlot c 14).tabs,
        Slot.Build.dzcIr cstS
          ⟨0, 1, 2, 3, 4, shaped I.x, shaped I.y, shaped I.ao, shaped I.x1, shaped I.ym, shaped I.z, shaped I.x2,
            I.nr.map shaped, I.ns.map shaped, I.mr.map shaped, I.ms.map shaped, I.ral.map shaped, I.rdl.map shaped,
            5 + n, 6 + n, 7 + n, optIx (supp c .D) gi⟩
          ⟨2 * (cnA : ℤ), 2 * (cnM : ℤ), 2 ^ c.p.tn, 2 ^ (c.p.tn + 1), c.p.ao, c.p.down⟩
          (lksS c shaped .D) (seg c 14 0) (seg c 14 1)
          (fun j => ((seg c 14 2).getD 0 .zero).pow j) (padGroup c .D gi shaped),
        (rawSlot c 14).hosted, (rawSlot c 14).nonzero⟩ := by
  unfold rawSlot
  simp only [idsW_u1, sh_u1, domPl_u1, aOff_u1,
    nHelp_u1, fh_u1, aPlane_u1, hTab_u1, supp_u1, seg_u1, claimPt_u1, lksS_u1, padGroup_u1,
    Slot.W16R2.scSS, Slot.W16R2.scSSM, Slot.W16R2.scTZC, Slot.W16R2.scLZC, Slot.W16R2.scRS,
    Slot.W16R2.scQMM, Slot.W16R2.scKMM, Slot.W16R2.scVMM, Slot.W16R2.scWO, Slot.W16R2.scGMM,
    Slot.W16R2.scUMM, Slot.W16R2.scDMM, Slot.W16R2.scSCORE, Slot.W16R2.scPV, Slot.W16R2.scDZC,
    show ¬ (14 = 0 ∨ 14 = 1) by decide, show (14 : ℕ) ≠ 2 by decide, show (14 : ℕ) ≠ 3 by decide,
    show (14 : ℕ) ≠ 4 by decide, show ¬ (14 = 5 ∨ 14 = 6 ∨ 14 = 7 ∨ 14 = 10) by decide,
    show ¬ (14 = 11 ∨ 14 = 12 ∨ 14 = 13) by decide, show ¬ (14 = 8 ∨ 14 = 9) by decide, ↓reduceIte]
  rfl

private theorem rawSlot_tabs_shieldU1 (cnA cnM s : ℕ) :
    (rawSlot (cfgShieldU1 cnA cnM) s).tabs = (rawSlot (cfgShieldU1 0 0) s).tabs := by
  unfold rawSlot
  simp only [idsW_u1, sh_u1, logCols_u1, nRange_u1, subW_u1, domStart_u1, domPl_u1, aOff_u1, logOf_u1,
    nHelp_u1, fh_u1, zeroPl_u1, aPlane_u1, hTab_u1, epTab_u1, supp_u1, seg_u1, claimPt_u1, lksS_u1, padGroup_u1,
    apply_ite SlotS.tabs]
  rfl

private theorem dzcIr_irDeg_cn (R : Slot.Build.DzcR) (num1 numM1 num2 numM2 dv den : ℤ) (sao sdown : ℕ)
    (lks : List (Slot.Build.LkD Sym)) (mu nu : List Sym) (zp : ℕ → Sym) (groups : List (ℕ × List ℕ)) :
    irDeg (Slot.Build.dzcIr cstS R ⟨num1, numM1, dv, den, sao, sdown⟩ lks mu nu zp groups)
      = irDeg (Slot.Build.dzcIr cstS R ⟨num2, numM2, dv, den, sao, sdown⟩ lks mu nu zp groups) := by
  rw [← irDeg_map (fun _ : Sym => ()), ← irDeg_map (fun _ : Sym => ())]
  congr 1

private theorem rawSlot_irDeg_shieldU1 (cnA cnM s : ℕ) :
    irDeg (rawSlot (cfgShieldU1 cnA cnM) s).ir = irDeg (rawSlot (cfgShieldU1 0 0) s).ir := by
  unfold rawSlot
  simp only [idsW_u1, sh_u1, logCols_u1, nRange_u1, subW_u1, domStart_u1, domPl_u1, aOff_u1, logOf_u1,
    nHelp_u1, fh_u1, zeroPl_u1, aPlane_u1, hTab_u1, epTab_u1, supp_u1, seg_u1, claimPt_u1, lksS_u1, padGroup_u1]
  by_cases h14 : s = Slot.W16R2.scDZC
  · subst h14
    simp only [Slot.W16R2.scSS, Slot.W16R2.scSSM, Slot.W16R2.scTZC, Slot.W16R2.scLZC, Slot.W16R2.scRS,
      Slot.W16R2.scQMM, Slot.W16R2.scKMM, Slot.W16R2.scVMM, Slot.W16R2.scWO, Slot.W16R2.scGMM,
      Slot.W16R2.scUMM, Slot.W16R2.scDMM, Slot.W16R2.scSCORE, Slot.W16R2.scPV, Slot.W16R2.scDZC,
      show ¬ (14 = 0 ∨ 14 = 1) by decide, show (14 : ℕ) ≠ 2 by decide, show (14 : ℕ) ≠ 3 by decide,
      show (14 : ℕ) ≠ 4 by decide, show ¬ (14 = 5 ∨ 14 = 6 ∨ 14 = 7 ∨ 14 = 10) by decide,
      show ¬ (14 = 11 ∨ 14 = 12 ∨ 14 = 13) by decide, show ¬ (14 = 8 ∨ 14 = 9) by decide, ↓reduceIte]
    exact dzcIr_irDeg_cn _ _ _ _ _ _ _ _ _ _ _ _ _ _
  · simp only [h14, ↓reduceIte]
    rfl

private theorem slotOKb_shieldU1 (rl : Cm → ℕ) (d cnA cnM s : ℕ) :
    slotOKb rl d (rawSlot (cfgShieldU1 cnA cnM) s) = slotOKb rl d (rawSlot (cfgShieldU1 0 0) s) := by
  unfold slotOKb
  rw [rawSlot_tabs_shieldU1 cnA cnM s, rawSlot_irDeg_shieldU1 cnA cnM s]

private theorem progOKb_map_congr {α : Type} (rl : Cm → ℕ) (f g : α → SlotS) :
    ∀ (xs : List α) (ds : List (ℕ × ℕ × ℕ)),
      (∀ x ∈ xs, ∀ d, slotOKb rl d (f x) = slotOKb rl d (g x)) →
      progOKb rl (xs.map f) ds = progOKb rl (xs.map g) ds
  | [], [], _ => rfl
  | [], _ :: _, _ => rfl
  | _ :: _, [], _ => rfl
  | x :: xs, d :: ds, h => by
    show (slotOKb rl d.2.2 (f x) && progOKb rl (xs.map f) ds)
      = (slotOKb rl d.2.2 (g x) && progOKb rl (xs.map g) ds)
    rw [h x List.mem_cons_self d.2.2,
      progOKb_map_congr rl f g xs ds (fun y hy => h y (List.mem_cons_of_mem _ hy))]

theorem rawProg_shieldU1_ok_zero :
    progOKb (fun _ => 1) (rawProg (cfgShieldU1 0 0)) W16R2.shieldSlots = true := by
  decide +kernel

/-- **The W16R2 Shieldstral (`export_u1`) raw program passes its check** for EVERY `(cnA, cnM)`. -/
theorem rawProg_shieldU1_ok (cnA cnM : ℕ) :
    progOKb (fun _ => 1) (rawProg (cfgShieldU1 cnA cnM)) W16R2.shieldSlots = true := by
  unfold rawProg
  rw [progOKb_map_congr (fun _ => 1) (rawSlot (cfgShieldU1 cnA cnM)) (rawSlot (cfgShieldU1 0 0))
    _ _ (fun s _ d => slotOKb_shieldU1 (fun _ => 1) d cnA cnM s)]
  exact rawProg_shieldU1_ok_zero

theorem progW16_shieldU1_ok (cnA cnM ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progW16 (cfgShieldU1 cnA cnM) ioIn ioOut) W16R2.shieldSlots = true := by
  unfold progW16
  rw [numProg_ok]
  exact rawProg_shieldU1_ok cnA cnM

theorem rawProg_shieldU1_cntA_zero :
    (rawProg (cfgShieldU1 0 0)).map (fun s => cmCountS .a s.tabs) = Link.aCntW16Shield := by
  decide +kernel

theorem rawProg_shieldU1_cntH_zero :
    (rawProg (cfgShieldU1 0 0)).map (fun s => cmCountS .h s.tabs) = Link.hCntW16Shield := by
  decide +kernel

/-- **The W16R2 Shieldstral (`export_u1`) private tables in `A` per slot are `Link.aCntW16Shield` (111).** -/
theorem progW16_shieldU1_cntA (cnA cnM ioIn ioOut : ℕ) :
    (progW16 (cfgShieldU1 cnA cnM) ioIn ioOut).map (fun s => cmCountS .a s.tabs) = Link.aCntW16Shield := by
  unfold progW16
  rw [numProg_cm]
  unfold rawProg
  rw [List.map_map]
  have hEq : List.map ((fun s => cmCountS .a s.tabs) ∘ rawSlot (cfgShieldU1 cnA cnM)) (List.range Slot.W16R2.nSlots)
      = List.map ((fun s => cmCountS .a s.tabs) ∘ rawSlot (cfgShieldU1 0 0)) (List.range Slot.W16R2.nSlots) :=
    List.map_congr_left fun s _ => congrArg (cmCountS .a) (rawSlot_tabs_shieldU1 cnA cnM s)
  rw [hEq, ← List.map_map]
  exact rawProg_shieldU1_cntA_zero

/-- **The W16R2 Shieldstral (`export_u1`) private tables in `H` per slot are `Link.hCntW16Shield` (44; +1 = 45).** -/
theorem progW16_shieldU1_cntH (cnA cnM ioIn ioOut : ℕ) :
    (progW16 (cfgShieldU1 cnA cnM) ioIn ioOut).map (fun s => cmCountS .h s.tabs) = Link.hCntW16Shield := by
  unfold progW16
  rw [numProg_cm]
  unfold rawProg
  rw [List.map_map]
  have hEq : List.map ((fun s => cmCountS .h s.tabs) ∘ rawSlot (cfgShieldU1 cnA cnM)) (List.range Slot.W16R2.nSlots)
      = List.map ((fun s => cmCountS .h s.tabs) ∘ rawSlot (cfgShieldU1 0 0)) (List.range Slot.W16R2.nSlots) :=
    List.map_congr_left fun s _ => congrArg (cmCountS .h) (rawSlot_tabs_shieldU1 cnA cnM s)
  rw [hEq, ← List.map_map]
  exact rawProg_shieldU1_cntH_zero

/-- The check at any block verifier with the W16R2 Shieldstral schedule and positive row logs. -/
theorem progW16_shieldU1_okP (P : BlockParams) (hsl : P.geom.slots = W16R2.shieldSlots) (hlc : 0 < P.logCols)
    (hep : 0 < P.endpointLogN) (cnA cnM ioIn ioOut : ℕ) :
    progOKb (rowLog P) (progW16 (cfgShieldU1 cnA cnM) ioIn ioOut) P.geom.slots = true := by
  rw [hsl, progOKb_congr (rowLog P) (fun _ => 1) (fun cm => by cases cm <;> simp [rowLog, hlc, hep])]
  exact progW16_shieldU1_ok cnA cnM ioIn ioOut

end ZK60.Exec.Block.DefW16

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Circuit (gP GF)
open ZK60.Exec.Slot.W16R2 (segLn)
open scoped ENNReal

section DefineAlgShieldU1

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- The W16R2 Shieldstral (`export_u1`) program's table totals (`111` in `A`, `45` in `H`). -/
theorem progW16_shieldU1_sums (cnA cnM ioIn ioOut : ℕ) :
    sumFrom (fun k => (cntS Cm.a (DefW16.progW16 (DefW16.cfgShieldU1 cnA cnM) ioIn ioOut)).getD k 0) 0 23 = 111
      ∧ sumFrom (fun k => (cntS Cm.h (DefW16.progW16 (DefW16.cfgShieldU1 cnA cnM) ioIn ioOut)).getD k 0) 0 23 + 1 = 45 := by
  have ha : cntS Cm.a (DefW16.progW16 (DefW16.cfgShieldU1 cnA cnM) ioIn ioOut) = Link.aCntW16Shield :=
    DefW16.progW16_shieldU1_cntA cnA cnM ioIn ioOut
  have hh : cntS Cm.h (DefW16.progW16 (DefW16.cfgShieldU1 cnA cnM) ioIn ioOut) = Link.hCntW16Shield :=
    DefW16.progW16_shieldU1_cntH cnA cnM ioIn ioOut
  rw [ha, hh]
  exact Link.cnt_sums_w16_shield

/-- **One W16R2 Shieldstral T128 (`export_u1`) block's knowledge statement with the tables part of
the slot polynomials, relation algebra, and lookup cover bridge discharged**, for any checked
program `prog` with counts `111 / 45` (W16R2 twin of `block_knowledge_define_alg_r13_shield_lk26`). -/
theorem block_knowledge_define_alg_w16r2_shield_lk26 [Fintype K] [DecidableEq K] (U : K)
    (hU : U ^ 2 = algebraMap GF K 7) (hK2 : Module.finrank GF K = 2) (key : Option Dig)
    (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsShieldW16 P tag rowsOf)
    (prog : List SlotS) (pubs : PubTabs) (hdef : P.define = defineS prog pubs)
    (hprog : progOKb (rowLog P) prog P.geom.slots = true)
    (hsA : sumFrom (fun k => (cntS Cm.a prog).getD k 0) 0 23 = 111)
    (hsH : sumFrom (fun k => (cntS Cm.h prog).getD k 0) 0 23 + 1 = 45)
    (hlc : P.logCols = 14)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (hcsE : ∀ (cu : Cuts3 L) (rt : RootsO) (cm : Cm) (z : ZClaim), (cm = .inp ∨ cm = .out) →
      csE cu rt cm z = Link.claimSem U (rE cm) (rowLog P cm) (QE cm) (XE cu rt cm) z)
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    (fams : List (ℕ × ℕ)) (hF : ZK60.Circuit.FamsOK fams) (hW : ZK60.Layout.W16Widths S fams) (h24 : S.h24 = true)
    (xtE : Cuts3 L → RootsO → ZK60.Layout.W16Data Ct Cw Cg Cj Cd Cf)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csShieldW16 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    -- the block's algebra
    (sh : AlgShape P) (dt : AlgData K L sh)
    (hform : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen
      (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE prog pubs))
      (Link.csShieldW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ algHosts, FormAt U P
        ((polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE prog pubs)
          (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (algSp U sh dt (card_K_gt K) 0 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ)
        bga rs k)
    (enc : (k : ℕ) → (Fin (segLn (sh.dl k) .tau) → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (encHt : (Fin sh.nHt → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (hspec : W16Spec sh dt Pb Lay B xtE enc encHt)
    (hTok : Function.Surjective Lay.tok.emb) (hHd : Function.Surjective Lay.hd.emb)
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hformH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen
      (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE prog pubs))
      (Link.csShieldW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ w16r2RelKs 0, FormAt U P
        ((polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE prog pubs)
          (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (spH (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ) bga rs k)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen
      (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE prog pubs))
      (Link.csShieldW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 2 ^ 26)
    (hTtab : ∀ j, ∃ t0, ZK60.Circuit.CodeTable fams Pb.exp Pb.act S.nG t0 ∧ T j = tupK t0)
    (hcov : ∀ G q, W16Query Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) q →
      ∃ l, Alk (cutsOf key domain hs hL A G).1 l = tupK q)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen
      (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE prog pubs))
      (Link.csShieldW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X (Lay.dPos p))
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))))
      ≤ εsTarget q + εend :=
  block_knowledge_alg_w16r2_shield_lk26
    (U := U) (hU := hU) (hK2 := hK2) (key := key) (domain := domain) (hs := hs)
    (hL := hL) (hL64 := hL64) (hL20 := hL20) (P := P) (tag := tag) (rowsOf := rowsOf) (hP := hP)
    (aC := cntS Cm.a prog) (hC := cntS Cm.h prog)
    (hdc := defineS_defCm P prog pubs hdef (cntS Cm.a prog) (cntS Cm.h prog) rfl rfl)
    (hsA := hsA) (hsH := hsH) (hdrLen := hdrLen) (hdrSq := hdrSq) (hh := hh) (hq := hq)
    (Poly := polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE prog pubs) (csE := csE)
    (hpolyC := defineS_polyC P prog pubs hdef)
    (hPoly := fun cu rt => polyS_slotEvalN U hU P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt)
      prog pubs _ (csXof_dXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE csE hcsE cu rt) hdef hprog)
    (hdegP := fun cu rt k sn => polyS_indDeg U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt)
      prog pubs hprog k sn)
    (Pb := Pb) (Lay := Lay) (B := B) (fams := fams) (hF := hF) (hW := hW) (h24 := h24) (xtE := xtE)
    (q := q) (A := A) (hA := hA) (εend := εend) (hEnd := hEnd)
    (sh := sh) (dt := dt) (hform := hform) (enc := enc) (encHt := encHt) (hspec := hspec)
    (hTok := hTok) (hHd := hHd) (HGd := HGd) (spH := spH) (hdgH := hdgH) (hformH := hformH)
    (hgdH := hgdH) (Alk := Alk) (T := T) (mlk := mlk) (hN := hN) (he := he)
    (hTtab := hTtab) (hcov := hcov) (hhr := hhr)

/-- **One W16R2 Shieldstral T128 (`export_u1`) block's knowledge statement at its own slot program
`progW16 (cfgShieldU1 cnA cnM) ioIn ioOut`** (valid for all 26 layers of `export_u1`, W16R2 twin of
`block_knowledge_define_alg_w16r2_rung`). -/
theorem block_knowledge_define_alg_w16r2_shieldU1 [Fintype K] [DecidableEq K] (U : K)
    (hU : U ^ 2 = algebraMap GF K 7) (hK2 : Module.finrank GF K = 2) (key : Option Dig)
    (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsShieldW16 P tag rowsOf)
    (cnA cnM ioIn ioOut : ℕ) (pubs : PubTabs)
    (hdef : P.define = defineS (DefW16.progW16 (DefW16.cfgShieldU1 cnA cnM) ioIn ioOut) pubs)
    (hlc : P.logCols = 14) (hep : 0 < P.endpointLogN)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (hcsE : ∀ (cu : Cuts3 L) (rt : RootsO) (cm : Cm) (z : ZClaim), (cm = .inp ∨ cm = .out) →
      csE cu rt cm z = Link.claimSem U (rE cm) (rowLog P cm) (QE cm) (XE cu rt cm) z)
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    (fams : List (ℕ × ℕ)) (hF : ZK60.Circuit.FamsOK fams) (hW : ZK60.Layout.W16Widths S fams) (h24 : S.h24 = true)
    (xtE : Cuts3 L → RootsO → ZK60.Layout.W16Data Ct Cw Cg Cj Cd Cf)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csShieldW16 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    -- the block's algebra
    (sh : AlgShape P) (dt : AlgData K L sh)
    (hform : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen
      (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
        (DefW16.progW16 (DefW16.cfgShieldU1 cnA cnM) ioIn ioOut) pubs))
      (Link.csShieldW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ algHosts, FormAt U P
        ((polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
          (DefW16.progW16 (DefW16.cfgShieldU1 cnA cnM) ioIn ioOut) pubs)
          (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (algSp U sh dt (card_K_gt K) 0 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ)
        bga rs k)
    (enc : (k : ℕ) → (Fin (segLn (sh.dl k) .tau) → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (encHt : (Fin sh.nHt → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (hspec : W16Spec sh dt Pb Lay B xtE enc encHt)
    (hTok : Function.Surjective Lay.tok.emb) (hHd : Function.Surjective Lay.hd.emb)
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hformH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen
      (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
        (DefW16.progW16 (DefW16.cfgShieldU1 cnA cnM) ioIn ioOut) pubs))
      (Link.csShieldW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ w16r2RelKs 0, FormAt U P
        ((polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
          (DefW16.progW16 (DefW16.cfgShieldU1 cnA cnM) ioIn ioOut) pubs)
          (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (spH (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ) bga rs k)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen
      (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
        (DefW16.progW16 (DefW16.cfgShieldU1 cnA cnM) ioIn ioOut) pubs))
      (Link.csShieldW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 2 ^ 26)
    (hTtab : ∀ j, ∃ t0, ZK60.Circuit.CodeTable fams Pb.exp Pb.act S.nG t0 ∧ T j = tupK t0)
    (hcov : ∀ G q, W16Query Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) q →
      ∃ l, Alk (cutsOf key domain hs hL A G).1 l = tupK q)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen
      (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
        (DefW16.progW16 (DefW16.cfgShieldU1 cnA cnM) ioIn ioOut) pubs))
      (Link.csShieldW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X (Lay.dPos p))
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))))
      ≤ εsTarget q + εend :=
  block_knowledge_define_alg_w16r2_shield_lk26
    (U := U) (hU := hU) (hK2 := hK2) (key := key) (domain := domain) (hs := hs)
    (hL := hL) (hL64 := hL64) (hL20 := hL20) (P := P) (tag := tag) (rowsOf := rowsOf) (hP := hP)
    (prog := DefW16.progW16 (DefW16.cfgShieldU1 cnA cnM) ioIn ioOut) (pubs := pubs) (hdef := hdef)
    (hprog := DefW16.progW16_shieldU1_okP P hP.hsl (by rw [hlc]; decide) hep cnA cnM ioIn ioOut)
    (hsA := (progW16_shieldU1_sums cnA cnM ioIn ioOut).1)
    (hsH := (progW16_shieldU1_sums cnA cnM ioIn ioOut).2)
    (hlc := hlc) (hdrLen := hdrLen) (hdrSq := hdrSq) (hh := hh) (hq := hq)
    (csE := csE) (rE := rE) (QE := QE) (XE := XE) (hcsE := hcsE)
    (Pb := Pb) (Lay := Lay) (B := B) (fams := fams) (hF := hF) (hW := hW) (h24 := h24) (xtE := xtE)
    (q := q) (A := A) (hA := hA) (εend := εend) (hEnd := hEnd)
    (sh := sh) (dt := dt) (hform := hform) (enc := enc) (encHt := encHt) (hspec := hspec)
    (hTok := hTok) (hHd := hHd) (HGd := HGd) (spH := spH) (hdgH := hdgH) (hformH := hformH)
    (hgdH := hgdH) (Alk := Alk) (T := T) (mlk := mlk) (hN := hN) (he := he)
    (hTtab := hTtab) (hcov := hcov) (hhr := hhr)

end DefineAlgShieldU1

end ZK60.Exec.Block
