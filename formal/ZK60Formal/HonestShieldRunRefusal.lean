/-
D63 lane L68c, part 3d (`HonestShieldRunRefusal.lean`):
1. Block `k` (`k < 26`) `OpenCollFamily` (`shdP_blkCollA`, `shdP_blkCollH`, `shdP_blkCollB`) and
   `shdP_blk_audit_and_carry`.
2. Stage OUT-C `OpenCollFamily` (`shdP_outcCollA`, `shdP_outcCollH`, `shdP_outcCollB`) and
   `shdP_outc_audit`.
3. Whole-run `shdP_SiteIdx` packing (`packRunSite`, `shdP_runSite`) via `div`/`mod` (zero 26-way
   unrolling in `whnf`), proving **`shdP_refuse_hk`** and **`shdP_refuse_hδ`**.
4. Whole-run prefix agreement (`final_shdP_incEndProg`, `final_shdP_blkBodyProg`,
   `shdP_runPreBlk_of_proveSegs_take`), `ShdRunProverMatch` (+ `shdP_stdProverMatch`), and
   **`shdP_refuse_hcover`**, **`shdP_refuse_hcover_std`**, **`shdP_refuse_O`** — completely
   discharging `hk`, `hδ`, and `hcover` (`O.refuse`) of
   `RunShieldOpenShell.sshC_productionReadyL_epP_openShell`!

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); never unfolds
`clog2 131072`, `embFoldL`, `tauTable`, `shdVi`, `shdVo`, `shdP_Pk0`, or `pubsR13L`.
-/
import ZK60Formal.HonestShieldRunProg

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Sound ZK60.TokenRun
open ZK60.Exec.StageCheck (kI)
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestOracle ZK60.HonestRun
open ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape (ClassifyRunPublicP classifyModelP classifySpecP)
open ZK60.RunShape.Shield (ShieldLayer shieldExport shieldExport_l17 shieldCal shieldS0 shieldShape ShieldRun)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockPublic)
open ZK60.Exec.Block (BlockParams Cm Hist Acc SlotDef SlotProof SlotRec SlotKind SlotS Tab TabS Priv PrivS
  Coord CoordS Sym Claims4 histOf slotShape slotTerms slotDefChecks hostedSum tabVals
  maskCoef oneMinusProd buildClaim claimPoint rowLog fp2U labA labH labM absorbRoot defineS defineS_ok posTag)
open ZK60.Exec.Block.Join.R13H.Look (logupSumR13)

/-! ## 1. Block `k` (`k < 26`) `OpenCollFamily` & `OpenAuditOk` (`A`, `H`, `B_k`) + Output Carry -/

section BlockAudit

private def shdBlkLy0 : ShieldLayer := ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩

private def numTabsList (aB hB ioIn ioOut : ℕ) : ℕ → ℕ → List (List TabS) → List (List TabS)
  | _, _, [] => []
  | ak, hk, ts :: rest =>
    Exec.Block.DefW16.numTabs aB hB ioIn ioOut ak hk 0 ts
      :: numTabsList aB hB ioIn ioOut (ak + Exec.Block.cmCountS .a ts) (hk + Exec.Block.cmCountS .h ts) rest

private theorem numProg_map_tabs (aB hB ioIn ioOut : ℕ) :
    ∀ (ak hk : ℕ) (ss : List SlotS),
      (Exec.Block.DefW16.numProg aB hB ioIn ioOut ak hk ss).map SlotS.tabs
        = numTabsList aB hB ioIn ioOut ak hk (ss.map SlotS.tabs)
  | _, _, [] => rfl
  | ak, hk, s :: ss => by
    simp only [Exec.Block.DefW16.numProg, Exec.Block.DefW16.numSlot, List.map_cons, numTabsList,
      numProg_map_tabs aB hB ioIn ioOut _ _ ss]

private theorem privsCmS_numTabs_ah (aB hB ioIn ioOut : ℕ) (cm : Cm) (hcm : cm = .a ∨ cm = .h) :
    ∀ (ak hk pk : ℕ) (ts : List TabS),
      privsCmS cm (Exec.Block.DefW16.numTabs aB hB ioIn ioOut ak hk pk ts)
        = privsCmS cm (Exec.Block.DefW16.numTabs aB hB 0 0 ak hk pk ts)
  | _, _, _, [] => rfl
  | ak, hk, pk, .eq _ _ :: ts => privsCmS_numTabs_ah aB hB ioIn ioOut cm hcm ak hk pk ts
  | ak, hk, pk, .pub _ :: ts => privsCmS_numTabs_ah aB hB ioIn ioOut cm hcm ak hk (pk + 1) ts
  | ak, hk, pk, .priv p :: ts => by
    simp only [Exec.Block.DefW16.numTabs, privsCmS]
    have hsr : p.cm = cm → Exec.Block.DefW16.setRow aB hB ioIn ioOut ak hk p
        = Exec.Block.DefW16.setRow aB hB 0 0 ak hk p := fun heq => by
      unfold Exec.Block.DefW16.setRow; rcases hcm with rfl | rfl <;> rw [heq]
    by_cases hp : p.cm = cm
    · change (if p.cm = cm then _ else _) = (if p.cm = cm then _ else _)
      rw [ite_eq_left hp, ite_eq_left hp, hsr hp, privsCmS_numTabs_ah aB hB ioIn ioOut cm hcm _ _ pk ts]
    · change (if p.cm = cm then _ else _) = (if p.cm = cm then _ else _)
      rw [ite_eq_right hp, ite_eq_right hp, privsCmS_numTabs_ah aB hB ioIn ioOut cm hcm _ _ pk ts]

private theorem numTabsList_ah_indep (aB hB ioIn ioOut : ℕ) (cm : Cm) (hcm : cm = .a ∨ cm = .h) :
    ∀ (ak hk : ℕ) (tss : List (List TabS)),
      (numTabsList aB hB ioIn ioOut ak hk tss).map (privsCmS cm)
        = (numTabsList aB hB 0 0 ak hk tss).map (privsCmS cm)
  | _, _, [] => rfl
  | ak, hk, ts :: rest => by
    simp only [numTabsList, List.map_cons, privsCmS_numTabs_ah aB hB ioIn ioOut cm hcm ak hk 0 ts,
      numTabsList_ah_indep aB hB ioIn ioOut cm hcm _ _ rest]

private theorem blk_bytes_len (g : List ℕ) (b : Option ℕ) :
    (Exec.Block.DefR13.bytes g b).length = g.length + (if b.isSome then 1 else 0) := by
  cases b <;> simp [Exec.Block.DefR13.bytes]

private theorem blk_nHelp_indep (Ly : ShieldLayer) (d : Exec.Slot.W16R2.Dom) :
    Exec.Block.DefR13.nHelp (Exec.Block.DefR13.cfgShieldR13 Ly) d
      = Exec.Block.DefR13.nHelp (Exec.Block.DefR13.cfgShieldR13 shdBlkLy0) d := by
  cases d <;> simp [Exec.Block.DefR13.nHelp, Exec.Block.DefR13.lookups, Exec.Block.DefR13.ids,
    Exec.Block.DefR13.idsR13, Exec.Block.DefR13.lsOf, Exec.Block.DefR13.cfgShieldR13,
    Exec.Block.DefR13.precShieldR13, shdBlkLy0, blk_bytes_len]

private theorem blk_fh_indep (Ly : ShieldLayer) (k : ℕ) :
    Exec.Block.DefR13.fh (Exec.Block.DefR13.cfgShieldR13 Ly) k
      = Exec.Block.DefR13.fh (Exec.Block.DefR13.cfgShieldR13 shdBlkLy0) k := by
  unfold Exec.Block.DefR13.fh Exec.Block.DefR13.hIdsN; simp only [blk_nHelp_indep]

private theorem blk_hDoms_indep (Ly : ShieldLayer) :
    Exec.Block.DefR13.hDoms (Exec.Block.DefR13.cfgShieldR13 Ly)
      = Exec.Block.DefR13.hDoms (Exec.Block.DefR13.cfgShieldR13 shdBlkLy0) := by
  unfold Exec.Block.DefR13.hDoms; simp only [blk_nHelp_indep]

private theorem blk_hOff_indep (Ly : ShieldLayer) (hp : ℕ) :
    Exec.Block.DefR13.hOff (Exec.Block.DefR13.cfgShieldR13 Ly) hp
      = Exec.Block.DefR13.hOff (Exec.Block.DefR13.cfgShieldR13 shdBlkLy0) hp := by
  unfold Exec.Block.DefR13.hOff; simp only [blk_hDoms_indep]; rfl

private theorem blk_hDataRows_indep (Ly : ShieldLayer) :
    Exec.Block.DefR13.hDataRows (Exec.Block.DefR13.cfgShieldR13 Ly) = 4282 := by
  unfold Exec.Block.DefR13.hDataRows; rw [blk_hDoms_indep]
  exact (show ((Exec.Block.DefR13.hDoms (Exec.Block.DefR13.cfgShieldR13 shdBlkLy0)).map
    fun d => 2 * Exec.Block.DefW16.rowsOf (Exec.Block.DefR13.cfgShieldR13 shdBlkLy0) d).sum = 4282 by decide +kernel)

private theorem blk_aDataRows_indep (Ly : ShieldLayer) :
    Exec.Block.DefR13.aDataRows (Exec.Block.DefR13.cfgShieldR13 Ly) = 4283 :=
  (show Exec.Block.DefR13.aDataRows (Exec.Block.DefR13.cfgShieldR13 shdBlkLy0) = 4283 by decide +kernel)

private theorem blk_logupSumR13_indep (Ly : ShieldLayer) :
    logupSumR13 (Exec.Block.DefR13.cfgShieldR13 Ly) = logupSumR13 (Exec.Block.DefR13.cfgShieldR13 shdBlkLy0) := by
  unfold logupSumR13; simp only [blk_hDoms_indep, blk_fh_indep, blk_hOff_indep]; rfl

private theorem blk_rawSlot_tabs_congr (c₁ c₂ : Exec.Block.DefW16.W16Cfg)
    (hsh : c₁.sh = c₂.sh) (hlc : c₁.logCols = c₂.logCols)
    (hh24 : c₁.p.h24 = c₂.p.h24) (hwrho : c₁.p.wrho = c₂.p.wrho)
    (hnh : ∀ d, Exec.Block.DefR13.nHelp c₁ d = Exec.Block.DefR13.nHelp c₂ d) (s : ℕ) :
    (Exec.Block.DefR13.rawSlot c₁ s).tabs = (Exec.Block.DefR13.rawSlot c₂ s).tabs := by
  have hids : Exec.Block.DefR13.ids c₁ = Exec.Block.DefR13.ids c₂ := by
    unfold Exec.Block.DefR13.ids Exec.Block.DefR13.lsOf; rw [hh24, hwrho]
  have hdomS : ∀ d, Exec.Block.DefR13.domStart c₁ d = Exec.Block.DefR13.domStart c₂ d := fun d => by
    unfold Exec.Block.DefR13.domStart; simp only [hids]
  have hdomE : ∀ d, Exec.Block.DefR13.domEnd c₁ d = Exec.Block.DefR13.domEnd c₂ d := fun d => by
    unfold Exec.Block.DefR13.domEnd; simp only [hids]
  have hdomPl : ∀ d, Exec.Block.DefR13.domPl c₁ d = Exec.Block.DefR13.domPl c₂ d := fun d => by
    unfold Exec.Block.DefR13.domPl; rw [hdomS, hdomE]
  have hplaneDom : ∀ q, Exec.Block.DefR13.planeDom c₁ q = Exec.Block.DefR13.planeDom c₂ q := fun q => by
    unfold Exec.Block.DefR13.planeDom; simp only [hdomE]
  have hrowsOf : ∀ d, Exec.Block.DefW16.rowsOf c₁ d = Exec.Block.DefW16.rowsOf c₂ d := fun d => by
    unfold Exec.Block.DefW16.rowsOf; rw [hsh, hlc]
  have hdomRow : ∀ d, Exec.Block.DefR13.domRow c₁ d = Exec.Block.DefR13.domRow c₂ d := fun d => by
    unfold Exec.Block.DefR13.domRow; simp only [hdomS, hdomE, hrowsOf]
  have haOff : ∀ q, Exec.Block.DefR13.aOff c₁ q = Exec.Block.DefR13.aOff c₂ q := fun q => by
    unfold Exec.Block.DefR13.aOff; rw [hdomRow, hplaneDom, hdomS, hrowsOf, hlc]
  have hlogOf : ∀ q, Exec.Block.DefR13.logOf c₁ q = Exec.Block.DefR13.logOf c₂ q := fun q => by
    unfold Exec.Block.DefR13.logOf; rw [hsh, hplaneDom]
  have haPlane : Exec.Block.DefR13.aPlane c₁ = Exec.Block.DefR13.aPlane c₂ := funext fun q => by
    unfold Exec.Block.DefR13.aPlane; rw [haOff, hlogOf]
  have hsupp : ∀ d, Exec.Block.DefW16.supp c₁ d = Exec.Block.DefW16.supp c₂ d := fun d => by
    unfold Exec.Block.DefW16.supp; rw [hsh]
  have hzeroPl : ∀ d, Exec.Block.DefR13.zeroPl c₁ d = Exec.Block.DefR13.zeroPl c₂ d := fun d => by
    unfold Exec.Block.DefR13.zeroPl; rw [hsh, hdomPl, hids]
  have hseg : ∀ s' j, Exec.Block.DefR13.seg c₁ s' j = Exec.Block.DefR13.seg c₂ s' j := fun s' j => by
    unfold Exec.Block.DefR13.seg; rw [hsh]
  have hclaimPt : ∀ s', Exec.Block.DefR13.claimPt c₁ s' = Exec.Block.DefR13.claimPt c₂ s' := fun s' => by
    unfold Exec.Block.DefR13.claimPt; simp only [hseg]
  have hfh : ∀ k, Exec.Block.DefR13.fh c₁ k = Exec.Block.DefR13.fh c₂ k := fun k => by
    unfold Exec.Block.DefR13.fh Exec.Block.DefR13.hIdsN; simp only [hnh]
  have hhDoms : Exec.Block.DefR13.hDoms c₁ = Exec.Block.DefR13.hDoms c₂ := by
    unfold Exec.Block.DefR13.hDoms; simp only [hnh]
  have hhOff : ∀ hp, Exec.Block.DefR13.hOff c₁ hp = Exec.Block.DefR13.hOff c₂ hp := fun hp => by
    unfold Exec.Block.DefR13.hOff; simp only [hhDoms, hrowsOf, hlc]
  have hhTab : ∀ hp, Exec.Block.DefR13.hTab c₁ hp = Exec.Block.DefR13.hTab c₂ hp := fun hp => by
    unfold Exec.Block.DefR13.hTab; simp only [hhOff, hhDoms, hsh]
  have hepTab : ∀ cm, Exec.Block.DefW16.epTab c₁ cm = Exec.Block.DefW16.epTab c₂ cm := fun cm => by
    unfold Exec.Block.DefW16.epTab; rw [hsh]
  unfold Exec.Block.DefR13.rawSlot
  dsimp only
  simp only [apply_ite SlotS.tabs, hids, hsh, hsupp, hseg, haPlane, haOff, hlogOf, hclaimPt,
    hzeroPl, hhTab, hfh, hdomPl, hnh, hepTab]

private theorem blk_rawSlot_tabs_indep (Ly : ShieldLayer) (s : ℕ) (_hs : s < 23) :
    (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) s).tabs
      = (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 shdBlkLy0) s).tabs :=
  blk_rawSlot_tabs_congr (Exec.Block.DefR13.cfgShieldR13 Ly) (Exec.Block.DefR13.cfgShieldR13 shdBlkLy0)
    rfl rfl rfl rfl (blk_nHelp_indep Ly) s

private def shdBlkTabs0 : List (List TabS) :=
  numTabsList 4283 4282 0 0 0 0
    ((List.range 23).map (fun s => (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 shdBlkLy0) s).tabs))

private def blkPrivsA : List (ℕ × PrivS) :=
  (List.range 23).flatMap (fun s => (privsCmS .a (shdBlkTabs0.getD s [])).map (fun p => (s, p)))

private def blkPrivsH : List (ℕ × PrivS) :=
  (List.range 23).flatMap (fun s => (privsCmS .h (shdBlkTabs0.getD s [])).map (fun p => (s, p)))

private def blkGroupsA : List SymGroup :=
  dedupSymGroupsOrder (blkPrivsA.filterMap (fun sp => (privSymKey 14 sp.2).map (fun k => (sp.1, k))))

private def blkGroupsH : List SymGroup :=
  dedupSymGroupsOrder (blkPrivsH.filterMap (fun sp => (privSymKey 14 sp.2).map (fun k => (sp.1, k))))

private def blkMains (s : ℕ) : ℕ := (Exec.Block.R13.shieldSlots.getD s (0, 0, 0)).1
private def blkExts (s : ℕ) : ℕ := (Exec.Block.R13.shieldSlots.getD s (0, 0, 0)).2.1

private theorem blkSpecA_ok :
    blkGroupsA.length = 36
      ∧ checkSymSpec 23 14 4283 4575 146 false blkMains blkExts Exec.Block.R13.shieldDraws blkPrivsA blkGroupsA = true := by
  decide +kernel

private theorem blkSpecH_ok :
    blkGroupsH.length = 8
      ∧ checkSymSpec 23 14 4282 4388 53 true blkMains blkExts Exec.Block.R13.shieldDraws blkPrivsH blkGroupsH = true := by
  decide +kernel

private theorem blk_progR13_ah_eq (Ly : ShieldLayer) (ioIn ioOut : ℕ) (cm : Cm) (hcm : cm = .a ∨ cm = .h) (s : ℕ) (hs : s < 23) :
    privsCmS cm ((Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).getD s SlotS.empty).tabs
      = privsCmS cm (shdBlkTabs0.getD s []) := by
  have hraw : (Exec.Block.DefR13.rawProg (Exec.Block.DefR13.cfgShieldR13 Ly)).map SlotS.tabs
      = (List.range 23).map (fun i => (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 shdBlkLy0) i).tabs) := by
    unfold Exec.Block.DefR13.rawProg; rw [List.map_map]
    exact List.map_congr_left (fun i hi => blk_rawSlot_tabs_indep Ly i (List.mem_range.mp hi))
  have hall : ((Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).map SlotS.tabs).map (privsCmS cm)
      = shdBlkTabs0.map (privsCmS cm) := by
    unfold Exec.Block.DefR13.progR13 shdBlkTabs0
    rw [blk_aDataRows_indep, blk_hDataRows_indep, numProg_map_tabs, hraw, numTabsList_ah_indep _ _ _ _ cm hcm]
  have hg := congrArg (fun l => l.getD s []) hall
  have hlen1 : (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).length = 23 := by
    unfold Exec.Block.DefR13.progR13 Exec.Block.DefR13.rawProg
    have hnp : ∀ aB hB iI iO ak hk (ss : List SlotS), (Exec.Block.DefW16.numProg aB hB iI iO ak hk ss).length = ss.length := by
      intro aB hB iI iO ak hk ss; induction ss generalizing ak hk with
      | nil => rfl | cons _ tl ih => simp [Exec.Block.DefW16.numProg, ih]
    rw [hnp, List.length_map, List.length_range]
  have hlen2 : shdBlkTabs0.length = 23 := rfl
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_map, List.getElem?_map,
    List.getElem?_eq_getElem (by omega), List.getElem?_eq_getElem (by omega)] at hg
  have hget1 : (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).getD s SlotS.empty
      = (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut)[s]'(by omega) := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem (by omega)]; rfl
  have hget2 : shdBlkTabs0.getD s [] = shdBlkTabs0[s]'(by omega) := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem (by omega)]; rfl
  rw [hget1, hget2]; exact hg

private theorem blk_progR13_io_eq (Ly : ShieldLayer) (ioIn ioOut : ℕ) (s : ℕ) (hs : s < 23) :
    privsCmS .inp ((Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).getD s SlotS.empty).tabs
      = (if s = 21 then [⟨.inp, [(0, false)], 19, Exec.Block.DefW16.rhoC 0 19, ioIn, 0⟩] else [])
    ∧ privsCmS .out ((Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).getD s SlotS.empty).tabs
      = (if s = 22 then [⟨.out, [(0, false)], 19, Exec.Block.DefW16.rhoC 0 19, ioOut, 0⟩] else []) := by
  have hmapIO : ∀ (aB hB iI iO ak hk pk : ℕ) (cm : Cm) (r : ℕ) (hcm : (cm = .inp ∧ r = iI) ∨ (cm = .out ∧ r = iO))
      (ts : List TabS),
      privsCmS cm (Exec.Block.DefW16.numTabs aB hB iI iO ak hk pk ts)
        = (privsCmS cm ts).map (fun p => { p with maskRow := r }) := by
    intro aB hB iI iO ak hk pk cm r hcm ts
    induction ts generalizing ak hk pk with
    | nil => rfl
    | cons t tl ih =>
      cases t with
      | eq _ _ => exact ih ak hk pk
      | pub _ => exact ih ak hk (pk + 1)
      | priv p =>
        simp only [Exec.Block.DefW16.numTabs, privsCmS]
        by_cases hp : p.cm = cm
        · change (if p.cm = cm then _ else _) = _
          rw [ite_eq_left hp, ite_eq_left hp, List.map_cons, ih]
          congr 1; unfold Exec.Block.DefW16.setRow
          rcases hcm with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;> rw [hp]
        · change (if p.cm = cm then _ else _) = _
          rw [ite_eq_right hp, ite_eq_right hp, ih]
  have hraw : (Exec.Block.DefR13.rawProg (Exec.Block.DefR13.cfgShieldR13 Ly)).map SlotS.tabs
      = (List.range 23).map (fun i => (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 shdBlkLy0) i).tabs) := by
    unfold Exec.Block.DefR13.rawProg; rw [List.map_map]
    exact List.map_congr_left (fun i hi => blk_rawSlot_tabs_indep Ly i (List.mem_range.mp hi))
  have hntIO : ∀ (aB hB iI iO ak hk : ℕ) (cm : Cm) (r : ℕ) (hcm : (cm = .inp ∧ r = iI) ∨ (cm = .out ∧ r = iO))
      (tss : List (List TabS)),
      (numTabsList aB hB iI iO ak hk tss).map (privsCmS cm)
        = tss.map (fun ts => (privsCmS cm ts).map (fun p => { p with maskRow := r })) := by
    intro aB hB iI iO ak hk cm r hcm tss
    induction tss generalizing ak hk with
    | nil => rfl
    | cons ts rest ih => simp only [numTabsList, List.map_cons, hmapIO aB hB iI iO ak hk 0 cm r hcm ts, ih]
  have hrawInp : ∀ i : Fin 23,
      privsCmS .inp (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 shdBlkLy0) i.val).tabs
        = (if i.val = 21 then [⟨.inp, [(0, false)], 19, Exec.Block.DefW16.rhoC 0 19, 0, 0⟩] else []) := by
    intro i; fin_cases i <;> rfl
  have hrawOut : ∀ i : Fin 23,
      privsCmS .out (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 shdBlkLy0) i.val).tabs
        = (if i.val = 22 then [⟨.out, [(0, false)], 19, Exec.Block.DefW16.rhoC 0 19, 0, 0⟩] else []) := by
    intro i; fin_cases i <;> rfl
  have hlen1 : (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).length = 23 := by
    unfold Exec.Block.DefR13.progR13 Exec.Block.DefR13.rawProg
    have hnp : ∀ aB hB iI iO ak hk (ss : List SlotS), (Exec.Block.DefW16.numProg aB hB iI iO ak hk ss).length = ss.length := by
      intro aB hB iI iO ak hk ss; induction ss generalizing ak hk with
      | nil => rfl | cons _ tl ih => simp [Exec.Block.DefW16.numProg, ih]
    rw [hnp, List.length_map, List.length_range]
  have hstep : ∀ (cm : Cm) (r : ℕ), ((cm = .inp ∧ r = ioIn) ∨ (cm = .out ∧ r = ioOut)) →
      privsCmS cm ((Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).getD s SlotS.empty).tabs
        = (privsCmS cm (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 shdBlkLy0) s).tabs).map
            (fun p => { p with maskRow := r }) := by
    intro cm r hcm
    have hall : ((Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).map SlotS.tabs).map (privsCmS cm)
        = (List.range 23).map (fun i =>
            (privsCmS cm (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 shdBlkLy0) i).tabs).map
              (fun p => { p with maskRow := r })) := by
      unfold Exec.Block.DefR13.progR13; rw [numProg_map_tabs, hraw, hntIO _ _ _ _ _ _ cm r hcm, List.map_map]; rfl
    have hg := congrArg (fun l => l.getD s []) hall
    rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_map, List.getElem?_map,
      List.getElem?_eq_getElem (by omega), List.getElem?_range hs] at hg
    have hget1 : (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).getD s SlotS.empty
        = (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut)[s]'(by omega) := by
      rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem (by omega)]; rfl
    rw [hget1]; exact hg
  refine ⟨?_, ?_⟩
  · rw [hstep .inp ioIn (Or.inl ⟨rfl, rfl⟩), hrawInp ⟨s, hs⟩]
    by_cases h21 : s = 21
    · rw [ite_eq_left h21, ite_eq_left h21]; rfl
    · rw [ite_eq_right h21, ite_eq_right h21]; rfl
  · rw [hstep .out ioOut (Or.inr ⟨rfl, rfl⟩), hrawOut ⟨s, hs⟩]
    by_cases h22 : s = 22
    · rw [ite_eq_left h22, ite_eq_left h22]; rfl
    · rw [ite_eq_right h22, ite_eq_right h22]; rfl

private def blkSumPre : List Exec.Block.ZPart :=
  let c0 := Exec.Block.DefR13.cfgShieldR13 shdBlkLy0
  (List.range 52).flatMap (fun hp =>
    let sign := if decide (Exec.Block.DefR13.fh c0 8 ≤ hp) && decide (hp < Exec.Block.DefR13.fh c0 8 + 3) then Fp2.one.neg else Fp2.one
    let ls := c0.sh.logs ((Exec.Block.DefR13.hDoms c0).getD hp .Tab)
    [⟨(Exec.Block.DefR13.hOff c0 hp).1, ls, sign, []⟩, ⟨(Exec.Block.DefR13.hOff c0 hp).2, ls, sign.mul fp2U, []⟩])

private theorem blk_logupSumR13_split :
    (logupSumR13 (Exec.Block.DefR13.cfgShieldR13 shdBlkLy0)).parts
        = blkSumPre ++ [⟨4280 * 2 ^ 14, 14, Fp2.one, []⟩, ⟨4281 * 2 ^ 14, 14, Fp2.one.mul fp2U, []⟩]
      ∧ ∀ q ∈ blkSumPre, q.point = [] ∧ 14 ≤ q.logSize ∧ partHi q (2 ^ 14) ≤ 4280 := by
  let c0 := Exec.Block.DefR13.cfgShieldR13 shdBlkLy0
  have hlen53 : (Exec.Block.DefR13.hDoms c0).length = 53 := by decide +kernel
  have hfh8 : Exec.Block.DefR13.fh c0 8 = 49 := by decide +kernel
  have hhOff52 : Exec.Block.DefR13.hOff c0 52 = (4280 * 2 ^ 14, 4281 * 2 ^ 14) := by decide +kernel
  have hls52 : c0.sh.logs ((Exec.Block.DefR13.hDoms c0).getD 52 .Tab) = 14 := by decide +kernel
  have hpreNat : (List.range 52).all (fun hp =>
      let ls := c0.sh.logs ((Exec.Block.DefR13.hDoms c0).getD hp .Tab)
      decide (14 ≤ ls)
        && decide ((Exec.Block.DefR13.hOff c0 hp).1 / 2 ^ 14 + (2 ^ ls + 2 ^ 14 - 1) / 2 ^ 14 ≤ 4280)
        && decide ((Exec.Block.DefR13.hOff c0 hp).2 / 2 ^ 14 + (2 ^ ls + 2 ^ 14 - 1) / 2 ^ 14 ≤ 4280)) = true := by
    decide +kernel
  refine ⟨?_, ?_⟩
  · unfold logupSumR13 blkSumPre
    rw [hlen53, List.range_succ, List.flatMap_append, List.flatMap_singleton]
    refine congrArg (blkSumPre ++ ·) ?_
    dsimp only
    rw [hfh8, hhOff52, hls52]
    rfl
  · intro q hq; unfold blkSumPre at hq
    obtain ⟨hp, hhp, hq'⟩ := List.mem_flatMap.mp hq
    have ha := List.all_eq_true.mp hpreNat hp hhp
    simp only [Bool.and_eq_true, decide_eq_true_eq] at ha
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hq'
    rcases hq' with rfl | rfl
    · exact ⟨rfl, ha.1.1, ha.1.2⟩
    · exact ⟨rfl, ha.1.1, ha.2⟩

private theorem sep_of_eq {α : Type} {key : Option Dig} {p q : TProg α} (h : p = q) (hp : TProg.Sep key p) :
    TProg.Sep key q := h ▸ hp

private theorem sqLE_of_eq {α : Type} {m : ℕ} {p q : TProg α} (h : p = q) (hp : SqLE m p) :
    SqLE m q := h ▸ hp

private theorem blk_shieldDraws_le53 : ∀ s, s < 23 → Exec.Block.R13.shieldDraws s ≤ 53 :=
  fun s hs => (show ∀ i : Fin 23, Exec.Block.R13.shieldDraws i.val ≤ 53 by decide +kernel) ⟨s, hs⟩

private theorem blk_mains_le25 : ∀ s, s < 23 → blkMains s ≤ 25 :=
  fun s hs => (show ∀ i : Fin 23, blkMains i.val ≤ 25 by decide +kernel) ⟨s, hs⟩

private theorem blk_range23_split : List.range 23 = List.range 21 ++ 21 :: [22] := by decide +kernel

private theorem blk_mains_21_gt18 : 18 < blkMains 21 := by decide +kernel

private theorem shdP_blk_draws_le53 {Coins : Type} (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26)
    (s : ℕ) (hsLt : s < 23) (x : Coins × List Fp2) :
    (corePf (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) x s).draws s ≤ 53 := by
  change (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).draws s ≤ 53
  rw [shdP_Pk0_draws tag ioIn ioOut checkOpening Rp hR k hk]
  exact blk_shieldDraws_le53 s hsLt

private theorem blkSlotEndProg_eq {α Coins : Type} (tag : MTag) (P : BlockParams) (k : ℕ) (dig : Dig)
    (pre : Coins → TProg α) (TB_next TA : Coins → Table) (M : Coins → MTable)
    (TH : Coins → Fp2 → Fp2 → Fp2 → Table) (Dc : Coins → SlotData P) (s : ℕ) (c : Coins) :
    blkSlotEndProg tag P k dig pre TB_next TA M TH Dc s c
      = famPre (corePf P) (coreDf P Dc) coreBga (blkHeadProg tag P k dig pre TB_next TA M TH c) s := rfl

noncomputable def shdP_blkCollA {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (pre : Coins → TProg α) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 12000 < 2 ^ 64)
    (TB_next TA : Coins → Table) (M : Coins → MTable) (TH : Coins → Fp2 → Fp2 → Fp2 → Table)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k)) : OpenCollFamily Lq Coins 630 :=
  let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
  symCollFamily Lq hLq key domain hdom (corePf P) (coreDf P Dc) coreBga
    (fun s c' => famPre (corePf P) (coreDf P Dc) coreBga (blkHeadProg tag P k dig pre TB_next TA M TH c') s)
    23 (mPre + 847) 53 25
    blkMains Exec.Block.R13.shieldDraws blkGroupsA 36 630 (by rw [strictPairs_length])
    (fun s hsLt c => sep_of_eq (blkSlotEndProg_eq tag P k dig pre TB_next TA M TH Dc s c)
      (shdP_blkSlotEndProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c).1)
    (fun s hsLt c => sqLE_of_eq (blkSlotEndProg_eq tag P k dig pre TB_next TA M TH Dc s c)
      (shdP_blkSlotEndProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c).2)
    (shdP_blk_draws_le53 tag ioIn ioOut checkOpening Rp hR k hk) (by omega)

noncomputable def shdP_blkCollH {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (pre : Coins → TProg α) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 12000 < 2 ^ 64)
    (TB_next TA : Coins → Table) (M : Coins → MTable) (TH : Coins → Fp2 → Fp2 → Fp2 → Table)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k)) : OpenCollFamily Lq Coins 36 :=
  let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
  symCollFamily Lq hLq key domain hdom (corePf P) (coreDf P Dc) coreBga
    (fun s c' => famPre (corePf P) (coreDf P Dc) coreBga (blkHeadProg tag P k dig pre TB_next TA M TH c') s)
    23 (mPre + 847) 53 25
    blkMains Exec.Block.R13.shieldDraws blkGroupsH 9 36 (by rw [strictPairs_length])
    (fun s hsLt c => sep_of_eq (blkSlotEndProg_eq tag P k dig pre TB_next TA M TH Dc s c)
      (shdP_blkSlotEndProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c).1)
    (fun s hsLt c => sqLE_of_eq (blkSlotEndProg_eq tag P k dig pre TB_next TA M TH Dc s c)
      (shdP_blkSlotEndProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c).2)
    (shdP_blk_draws_le53 tag ioIn ioOut checkOpening Rp hR k hk) (by omega)

private noncomputable def mkBndCollFamily {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (Pf : α → ℕ → BlockParams) (Df : (x : α) → (s : ℕ) → SlotData (Pf x s))
    (bga : α → Fp2 × Fp2 × Fp2)
    (pre : Coins → TProg (List Exec.Block.ZClaim)) (mPre : ℕ)
    (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (pSlot : Coins → TProg (α × List SlotRec × Acc))
    (slotIdx roundIdx mSlot maxDr : ℕ)
    (hSlot : ∀ c, TProg.Sep key (pSlot c) ∧ SqLE mSlot (pSlot c))
    (hDr : ∀ x, (Pf x slotIdx).draws slotIdx ≤ maxDr)
    (hBnd : mPre + (mSlot + maxDr + 1 + roundIdx) < 2 ^ 64) : OpenCollFamily Lq Coins 1 where
  site _ :=
    let pR := fun c => depRoundDrProg Pf Df bga (pSlot c) slotIdx roundIdx
    zkeyCollisionStartSite Lq hLq key domain hdom
      (fun c => bindP (pre c) (fun pend => bindP (pR c) (fun _ => TProg.done pend)))
      (fun pend => ((claimKey 14 (pend.headD zclaim0)).1.getD 13 Fp2.zero).toK shdP_U)
      (fun c => sep_bindP key (pre c) _ (hs c) (fun _ =>
        sep_bindP key (pR c) (fun _ => TProg.done _)
          (sep_depRoundDrProg key Pf Df bga (pSlot c) slotIdx roundIdx (hSlot c).1)
          (fun _ => trivial)))
      (fun c dg => noWrap_start_of_sqLE
        (sqLE_bindP (pre c) _ mPre (mSlot + maxDr + 1 + roundIdx) (hsq c) (fun pend =>
          sqLE_mono _ ((mSlot + maxDr + 1 + roundIdx) + 0) (mSlot + maxDr + 1 + roundIdx)
            (sqLE_bindP (pR c) (fun _ => TProg.done pend) (mSlot + maxDr + 1 + roundIdx) 0
              (sqLE_depRoundDrProg Pf Df bga (pSlot c) slotIdx roundIdx mSlot maxDr (hSlot c).2 hDr)
              (fun _ => trivial)) (by omega)))
        hBnd dg)
  hk _ := le_rfl
  hδ _ := rfl

noncomputable def shdP_blkCollB {Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (pre : Coins → TProg (List Exec.Block.ZClaim)) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 12000 < 2 ^ 64)
    (TB_next TA : Coins → Table) (M : Coins → MTable) (TH : Coins → Fp2 → Fp2 → Fp2 → Table)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k)) : OpenCollFamily Lq Coins 1 :=
  let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
  mkBndCollFamily Lq hLq key domain hdom (corePf P) (coreDf P Dc) coreBga pre mPre hs hsq
    (blkSlotEndProg tag P k dig (fun _ : Coins => TProg.done ()) TB_next TA M TH Dc 21)
    21 18 (0 + 847) 53
    (shdP_blkSlotEndProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig 0 key
      (fun _ : Coins => TProg.done ()) TB_next TA M TH Dc (fun _ => trivial) (fun _ => trivial) 21 (by omega))
    (shdP_blk_draws_le53 tag ioIn ioOut checkOpening Rp hR k hk 21 (by omega))
    (by omega)

private theorem shdP_blk_head_final {α Coins : Type} (Lq : ℕ) (key : Option Dig) (domain : List UInt8)
    (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (k : ℕ) (dig : Dig)
    (pre : Coins → TProg α) (TB_next TA : Coins → Table) (M : Coins → MTable) (TH : Coins → Fp2 → Fp2 → Fp2 → Table)
    (G : QB Lq → Dig) (c : Coins) (D : CoreData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (hA : D.aRoot = rootOf (liftH G) tag 16 (TA c))
    (hM : D.maskRoot = rootOf (liftH G) tag 12 (mTab 23 (cosetPt (rootFp 12)) (M c)))
    (hH : ∀ b g a, D.hRoot b g a = rootOf (liftH G) tag 16 (TH c b g a)) :
    let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
    let t0 := Tr.newKeyed (liftH G) domain key
    let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) t0).1
    (blkHeadProg tag P k dig pre TB_next TA M TH c).final (liftH G) t0
      = (coreT3 (liftH G) P D tFr, (c, [(coreB (liftH G) P D tFr).1, (coreG (liftH G) P D tFr).1, (coreA (liftH G) P D tFr).1])) := by
  intro P t0 tFr
  unfold blkHeadProg; rw [final_coreHeadProg]
  have hT2 : (absorbRoot (liftH G) tFr labA (rootOf (liftH G) tag 16 (TA c)) P.aRows P.logCols).absorb (liftH G)
      labM (rootOf (liftH G) tag 12 (mTab 23 (cosetPt (rootFp 12)) (M c))).toList = coreT2 (liftH G) P D tFr := by
    unfold coreT2; rw [hA, hM]
  rw [hT2, ← hH]; rfl

private theorem shdP_blk_shape_ok {Coins : Type} (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26)
    (x : Coins × List Fp2) (s : ℕ) (hsLt : s < 23) :
    (slotShape (corePf (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) x s) s).1 = blkMains s
      ∧ blkMains s ≤ 25
      ∧ (slotShape (corePf (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) x s) s).2.1 = blkExts s := by
  unfold corePf slotShape blkMains blkExts
  rw [shdP_Pk0_slots tag ioIn ioOut checkOpening Rp hR k hk]
  exact ⟨rfl, blk_mains_le25 s hsLt, rfl⟩

private theorem shdP_blk_defPrivs_ah (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26)
    (b g a : Fp2) (cm : Cm) (hcm : cm = .a ∨ cm = .h) (s : ℕ) (hsLt : s < 23)
    (recs1 : List SlotRec) (dr : List Fp2) (df : SlotDef)
    (hdf : (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).define s (histOf b g a recs1) dr = .ok df) :
    privsCm cm df.tabs = (privsCmS cm (shdBlkTabs0.getD s [])).map (PrivS.eval (Sym.eval (histOf b g a recs1) s dr)) := by
  rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk] at hdf
  obtain ⟨-, rfl⟩ := defineS_ok hdf
  rw [privsCm_map_eval, blk_progR13_ah_eq (shdP_blkLy k hk) ioIn ioOut cm hcm s hsLt]

private theorem flatMap_map_pair_map {α β γ : Type} (l : List ℕ) (g : ℕ → List α)
    (f₁ : ℕ → α → β) (f₂ : ℕ → β → γ) (h : ℕ × α → γ)
    (hEq : ∀ s p, f₂ s (f₁ s p) = h (s, p)) :
    l.flatMap (fun s => ((g s).map (f₁ s)).map (f₂ s))
      = (l.flatMap (fun s => (g s).map (fun p => (s, p)))).map h := by
  rw [List.map_flatMap]
  refine flatMap_congr_eq (fun s _ => ?_)
  rw [List.map_map, List.map_map]
  exact List.map_congr_left (fun p _ => hEq s p)

private theorem shdP_blk_parts_A {Coins : Type}
    (Lq : ℕ) (key : Option Dig) (domain : List UInt8)
    (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (pre : Coins → TProg (List Exec.Block.ZClaim)) (TB_next : Coins → Table)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (G : QB Lq → Dig) (c : Coins) (D : CoreData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (hD : D.slot = Dc c)
    (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr)
    (hsl :
      let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
      let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
      slotsProve (liftH G) P D.slot (coreB (liftH G) P D tFr).1 (coreG (liftH G) P D tFr).1 (coreA (liftH G) P D tFr).1 23 [] 0 {}
        (coreT3 (liftH G) P D tFr) = .ok (sps, recs, acc, t4)) :
    let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
    let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
    let b := (coreB (liftH G) P D tFr).1; let g := (coreG (liftH G) P D tFr).1; let a := (coreA (liftH G) P D tFr).1
    acc.claims.a.map Exec.Block.ZClaim.parts = blkPrivsA.map (fun sp =>
      let r := recs.getD sp.1 rec0
      let ev := Sym.eval (histOf b g a (recs.take sp.1)) sp.1 r.draws
      let p := sp.2.eval ev
      (buildClaim (corePf P (c, [b, g, a]) sp.1) p (claimPoint p r.rho) (oneMinusProd r.es) (maskCoef r.es p.extRound) Fp2.zero).parts) ++ [] := by
  intro P tFr b g a
  have hfam : famProve (liftH G) (corePf P (c, [b, g, a])) (coreDf P Dc (c, [b, g, a])) b g a 23 [] 0 {}
      (coreT3 (liftH G) P D tFr) = .ok (sps, recs, acc, t4) := by
    rw [← slotsProve_eq_fam, ← hD]; exact hsl
  have hfp := famProve_claims_parts (liftH G) (corePf P (c, [b, g, a])) (coreDf P Dc (c, [b, g, a])) b g a .a
    (fun s recs1 dr => (privsCmS .a (shdBlkTabs0.getD s [])).map (PrivS.eval (Sym.eval (histOf b g a recs1) s dr)))
    23 [] 0 {} _ sps recs acc t4 hfam (fun i hi recs1 dr df _ hdf _ _ => by
      rw [Nat.zero_add] at hdf ⊢
      exact shdP_blk_defPrivs_ah tag ioIn ioOut checkOpening Rp hR k hk b g a .a (Or.inl rfl) i hi recs1 dr df hdf)
  dsimp only [claimsCm] at hfp
  rw [List.length_nil, List.map_nil, List.nil_append] at hfp
  simp only [Nat.zero_add] at hfp
  rw [hfp, List.append_nil]
  exact flatMap_map_pair_map (List.range 23) (fun s => privsCmS .a (shdBlkTabs0.getD s [])) _ _ _ (fun _ _ => rfl)

private theorem shdP_blk_audit_A {Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (pre : Coins → TProg (List Exec.Block.ZClaim)) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 12000 < 2 ^ 64)
    (TB_next TA : Coins → Table) (M : Coins → MTable) (TH : Coins → Fp2 → Fp2 → Fp2 → Table)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (G : QB Lq → Dig) (c : Coins) (D : CoreData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (hA : D.aRoot = rootOf (liftH G) tag 16 (TA c))
    (hM : D.maskRoot = rootOf (liftH G) tag 12 (mTab 23 (cosetPt (rootFp 12)) (M c)))
    (hH : ∀ b g a, D.hRoot b g a = rootOf (liftH G) tag 16 (TH c b g a))
    (hD : D.slot = Dc c)
    (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr)
    (hsl :
      let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
      let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
      slotsProve (liftH G) P D.slot (coreB (liftH G) P D tFr).1 (coreG (liftH G) P D tFr).1 (coreA (liftH G) P D tFr).1 23 [] 0 {}
        (coreT3 (liftH G) P D tFr) = .ok (sps, recs, acc, t4)) :
    OpenAuditOk shdP_blkOpenGeomA 14 146 630
      (shdP_blkCollA Lq hLq key domain hdom tag ioIn ioOut checkOpening Rp hR k hk dig pre mPre hs hsq hmPre TB_next TA M TH Dc)
      G c acc.claims.a := by
  let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
  let t0 := Tr.newKeyed (liftH G) domain key
  let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) t0).1
  let b := (coreB (liftH G) P D tFr).1; let g := (coreG (liftH G) P D tFr).1; let a := (coreA (liftH G) P D tFr).1
  have hDraws : P.draws = Exec.Block.R13.shieldDraws := shdP_Pk0_draws tag ioIn ioOut checkOpening Rp hR k hk
  have hLogCols : P.logCols = 14 := shdP_Pk0_logCols tag ioIn ioOut checkOpening Rp hR k hk
  have hEpLog : P.endpointLogN = 14 := shdP_Pk0_endpointLogN tag ioIn ioOut checkOpening Rp hR k hk
  have hF := shdP_blk_head_final Lq key domain tag ioIn ioOut checkOpening Rp k dig pre TB_next TA M TH G c D hA hM hH
  have hfam : famProve (liftH G) (corePf P (c, [b, g, a])) (coreDf P Dc (c, [b, g, a])) b g a 23 [] 0 {}
      (coreT3 (liftH G) P D tFr) = .ok (sps, recs, acc, t4) := by
    rw [← slotsProve_eq_fam, ← hD]; exact hsl
  have hPartsA := shdP_blk_parts_A Lq key domain tag ioIn ioOut checkOpening Rp hR k hk dig pre TB_next Dc G c D hD sps recs acc t4 hsl
  have hAud := openAuditOk_of_symSpec Lq hLq key domain hdom (corePf P) (coreDf P Dc) coreBga
    (blkHeadProg tag P k dig pre TB_next TA M TH)
    23 14 4577 4283 4575 146 36 630 (mPre + 847) 53 25 blkMains blkExts Exec.Block.R13.shieldDraws
    blkPrivsA blkGroupsA none (by rw [strictPairs_length])
    (fun s hsLt c' => sep_of_eq (blkSlotEndProg_eq tag P k dig pre TB_next TA M TH Dc s c')
      (shdP_blkSlotEndProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c').1)
    (fun s hsLt c' => sqLE_of_eq (blkSlotEndProg_eq tag P k dig pre TB_next TA M TH Dc s c')
      (shdP_blkSlotEndProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c').2)
    (shdP_blk_draws_le53 tag ioIn ioOut checkOpening Rp hR k hk)
    (by omega) (by norm_num) rfl rfl (by rw [blkSpecA_ok.1]; rfl) blkSpecA_ok.2 G c (c, [b, g, a]) _ hF
    (shdP_blk_shape_ok tag ioIn ioOut checkOpening Rp hR k hk (c, [b, g, a]))
    (fun _ _ => hDraws ▸ rfl)
    (fun sp _ => by unfold rowLog; cases sp.2.cm <;> first | exact hLogCols | exact hEpLog)
    sps recs acc t4 hfam (fun _ _ _ _ h => by cases h) acc.claims.a hPartsA
  exact hAud

private theorem shdP_blk_audit_H {Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (pre : Coins → TProg (List Exec.Block.ZClaim)) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 12000 < 2 ^ 64)
    (TB_next TA : Coins → Table) (M : Coins → MTable) (TH : Coins → Fp2 → Fp2 → Fp2 → Table)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (G : QB Lq → Dig) (c : Coins) (D : CoreData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (hA : D.aRoot = rootOf (liftH G) tag 16 (TA c))
    (hM : D.maskRoot = rootOf (liftH G) tag 12 (mTab 23 (cosetPt (rootFp 12)) (M c)))
    (hH : ∀ b g a, D.hRoot b g a = rootOf (liftH G) tag 16 (TH c b g a))
    (hD : D.slot = Dc c)
    (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr)
    (hsl :
      let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
      let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
      slotsProve (liftH G) P D.slot (coreB (liftH G) P D tFr).1 (coreG (liftH G) P D tFr).1 (coreA (liftH G) P D tFr).1 23 [] 0 {}
        (coreT3 (liftH G) P D tFr) = .ok (sps, recs, acc, t4)) :
    let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
    OpenAuditOk shdP_blkOpenGeomH 14 54 36
      (shdP_blkCollH Lq hLq key domain hdom tag ioIn ioOut checkOpening Rp hR k hk dig pre mPre hs hsq hmPre TB_next TA M TH Dc)
      G c (acc.claims.h ++ [P.logupSumClaim]) := by
  let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
  let t0 := Tr.newKeyed (liftH G) domain key
  let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) t0).1
  let b := (coreB (liftH G) P D tFr).1; let g := (coreG (liftH G) P D tFr).1; let a := (coreA (liftH G) P D tFr).1
  have hPeq : P = shdP_blkParams tag ioIn ioOut checkOpening (shdP_blkLy k hk) (shdP_blkPb Rp hR k hk) :=
    shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk
  have hDraws : P.draws = Exec.Block.R13.shieldDraws := shdP_Pk0_draws tag ioIn ioOut checkOpening Rp hR k hk
  have hLogCols : P.logCols = 14 := shdP_Pk0_logCols tag ioIn ioOut checkOpening Rp hR k hk
  have hEpLog : P.endpointLogN = 14 := shdP_Pk0_endpointLogN tag ioIn ioOut checkOpening Rp hR k hk
  have hF := shdP_blk_head_final Lq key domain tag ioIn ioOut checkOpening Rp k dig pre TB_next TA M TH G c D hA hM hH
  have hfam : famProve (liftH G) (corePf P (c, [b, g, a])) (coreDf P Dc (c, [b, g, a])) b g a 23 [] 0 {}
      (coreT3 (liftH G) P D tFr) = .ok (sps, recs, acc, t4) := by
    rw [← slotsProve_eq_fam, ← hD]; exact hsl
  have hPartsH : (acc.claims.h ++ [P.logupSumClaim]).map Exec.Block.ZClaim.parts = blkPrivsH.map (fun sp =>
      let r := recs.getD sp.1 rec0
      let ev := Sym.eval (histOf b g a (recs.take sp.1)) sp.1 r.draws
      let p := sp.2.eval ev
      (buildClaim (corePf P (c, [b, g, a]) sp.1) p (claimPoint p r.rho) (oneMinusProd r.es) (maskCoef r.es p.extRound) Fp2.zero).parts)
      ++ [P.logupSumClaim.parts] := by
    have hfp := famProve_claims_parts (liftH G) (corePf P (c, [b, g, a])) (coreDf P Dc (c, [b, g, a])) b g a .h
      (fun s recs1 dr => (privsCmS .h (shdBlkTabs0.getD s [])).map (PrivS.eval (Sym.eval (histOf b g a recs1) s dr)))
      23 [] 0 {} _ sps recs acc t4 hfam (fun i hi recs1 dr df _ hdf _ _ => by
        rw [Nat.zero_add] at hdf ⊢
        exact shdP_blk_defPrivs_ah tag ioIn ioOut checkOpening Rp hR k hk b g a .h (Or.inr rfl) i hi recs1 dr df hdf)
    dsimp only [claimsCm] at hfp
    rw [List.length_nil, List.map_nil, List.nil_append] at hfp
    simp only [Nat.zero_add] at hfp
    rw [List.map_append, List.map_singleton, hfp]
    exact congrArg (· ++ [P.logupSumClaim.parts])
      (flatMap_map_pair_map (List.range 23) (fun s => privsCmS .h (shdBlkTabs0.getD s [])) _ _ _ (fun _ _ => rfl))
  have hLogupEq : P.logupSumClaim = logupSumR13 (Exec.Block.DefR13.cfgShieldR13 shdBlkLy0) := by
    rw [hPeq]; exact blk_logupSumR13_indep (shdP_blkLy k hk)
  exact openAuditOk_of_symSpec Lq hLq key domain hdom (corePf P) (coreDf P Dc) coreBga
    (blkHeadProg tag P k dig pre TB_next TA M TH)
    23 14 4390 4282 4388 53 9 36 (mPre + 847) 53 25 blkMains blkExts Exec.Block.R13.shieldDraws
    blkPrivsH blkGroupsH (some (4280, 4281, P.logupSumClaim, blkSumPre)) (by rw [strictPairs_length])
    (fun s hsLt c' => sep_of_eq (blkSlotEndProg_eq tag P k dig pre TB_next TA M TH Dc s c')
      (shdP_blkSlotEndProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c').1)
    (fun s hsLt c' => sqLE_of_eq (blkSlotEndProg_eq tag P k dig pre TB_next TA M TH Dc s c')
      (shdP_blkSlotEndProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c').2)
    (shdP_blk_draws_le53 tag ioIn ioOut checkOpening Rp hR k hk)
    (by omega) (by norm_num) rfl rfl (by rw [blkSpecH_ok.1]; rfl) blkSpecH_ok.2 G c (c, [b, g, a]) _ hF
    (shdP_blk_shape_ok tag ioIn ioOut checkOpening Rp hR k hk (c, [b, g, a]))
    (fun _ _ => hDraws ▸ rfl)
    (fun sp _ => by unfold rowLog; cases sp.2.cm <;> first | exact hLogCols | exact hEpLog)
    sps recs acc t4 hfam (fun u0 u1 sc pre' hso => by
      have he := Option.some.inj hso; simp only [Prod.mk.injEq] at he; obtain ⟨rfl, rfl, rfl, rfl⟩ := he
      exact ⟨rfl, rfl, by rw [hLogupEq]; exact blk_logupSumR13_split.1, blk_logupSumR13_split.2⟩)
    (acc.claims.h ++ [P.logupSumClaim]) hPartsH

private theorem shdP_blk_inp_parts {Coins : Type}
    (Lq : ℕ) (key : Option Dig) (domain : List UInt8)
    (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (pre : Coins → TProg (List Exec.Block.ZClaim)) (TB_next : Coins → Table)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (G : QB Lq → Dig) (c : Coins) (D : CoreData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (hD : D.slot = Dc c)
    (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr)
    (hsl :
      let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
      let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
      slotsProve (liftH G) P D.slot (coreB (liftH G) P D tFr).1 (coreG (liftH G) P D tFr).1 (coreA (liftH G) P D tFr).1 23 [] 0 {}
        (coreT3 (liftH G) P D tFr) = .ok (sps, recs, acc, t4)) :
    let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
    acc.claims.inp.map Exec.Block.ZClaim.parts =
      [(buildClaim P ⟨.inp, [(0, Fp2.one)], 19, StageV.rhoC 0 19, ioIn, 0⟩
          (claimPoint ⟨.inp, [(0, Fp2.one)], 19, StageV.rhoC 0 19, ioIn, 0⟩ (recs.getD 21 rec0).rho)
          (oneMinusProd (recs.getD 21 rec0).es) (maskCoef (recs.getD 21 rec0).es 0) Fp2.zero).parts] := by
  let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
  let t0 := Tr.newKeyed (liftH G) domain key
  let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) t0).1
  let b := (coreB (liftH G) P D tFr).1; let g := (coreG (liftH G) P D tFr).1; let a := (coreA (liftH G) P D tFr).1
  have hPeq : P = shdP_blkParams tag ioIn ioOut checkOpening (shdP_blkLy k hk) (shdP_blkPb Rp hR k hk) :=
    shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk
  have hfam : famProve (liftH G) (corePf P (c, [b, g, a])) (coreDf P Dc (c, [b, g, a])) b g a 23 [] 0 {}
      (coreT3 (liftH G) P D tFr) = .ok (sps, recs, acc, t4) := by
    rw [← slotsProve_eq_fam, ← hD]; exact hsl
  have hfp := famProve_claims_parts (liftH G) (corePf P (c, [b, g, a])) (coreDf P Dc (c, [b, g, a])) b g a .inp
    (fun s _ _ => if s = 21 then [⟨.inp, [(0, Fp2.one)], 19, StageV.rhoC 0 19, ioIn, 0⟩] else [])
    23 [] 0 {} _ sps recs acc t4 hfam (fun i hi _ _ df _ hdf _ _ => by
      rw [Nat.zero_add] at hdf ⊢
      change P.define i _ _ = .ok df at hdf
      rw [hPeq] at hdf; obtain ⟨-, rfl⟩ := defineS_ok hdf
      rw [privsCm_map_eval, (blk_progR13_io_eq (shdP_blkLy k hk) ioIn ioOut i hi).1]
      by_cases h21 : i = 21
      · rw [ite_eq_left h21, ite_eq_left h21]; rfl
      · rw [ite_eq_right h21, ite_eq_right h21]; rfl)
  dsimp only [claimsCm] at hfp
  rw [List.length_nil, List.map_nil, List.nil_append] at hfp
  simp only [Nat.zero_add] at hfp
  rw [hfp, blk_range23_split, List.flatMap_append, List.flatMap_cons, List.flatMap_singleton,
    List.flatMap_eq_nil_iff.mpr (fun i hi => by
      have hne : i ≠ 21 := by have := List.mem_range.mp hi; omega
      rw [ite_eq_right hne]; rfl),
    ite_eq_right (by omega : 22 ≠ 21), List.map_nil, List.nil_append, List.append_nil, ite_eq_left rfl, List.map_singleton]

private theorem shdP_blk_out_carry {Coins : Type}
    (Lq : ℕ) (key : Option Dig) (domain : List UInt8)
    (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (pre : Coins → TProg (List Exec.Block.ZClaim)) (TB_next : Coins → Table)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (G : QB Lq → Dig) (c : Coins) (D : CoreData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (hD : D.slot = Dc c)
    (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr)
    (hsl :
      let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
      let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
      slotsProve (liftH G) P D.slot (coreB (liftH G) P D tFr).1 (coreG (liftH G) P D tFr).1 (coreA (liftH G) P D tFr).1 23 [] 0 {}
        (coreT3 (liftH G) P D tFr) = .ok (sps, recs, acc, t4)) :
    (ioOut = 32 ∨ ioOut = 34) → BndCarryOk ioOut acc.claims.out := fun hio => by
  let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
  let t0 := Tr.newKeyed (liftH G) domain key
  let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) t0).1
  let b := (coreB (liftH G) P D tFr).1; let g := (coreG (liftH G) P D tFr).1; let a := (coreA (liftH G) P D tFr).1
  have hPeq : P = shdP_blkParams tag ioIn ioOut checkOpening (shdP_blkLy k hk) (shdP_blkPb Rp hR k hk) :=
    shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk
  have hEpLog : P.endpointLogN = 14 := shdP_Pk0_endpointLogN tag ioIn ioOut checkOpening Rp hR k hk
  have hfam : famProve (liftH G) (corePf P (c, [b, g, a])) (coreDf P Dc (c, [b, g, a])) b g a 23 [] 0 {}
      (coreT3 (liftH G) P D tFr) = .ok (sps, recs, acc, t4) := by
    rw [← slotsProve_eq_fam, ← hD]; exact hsl
  have hShape := shdP_blk_shape_ok tag ioIn ioOut checkOpening Rp hR k hk (c, [b, g, a])
  have hOutParts : acc.claims.out.map Exec.Block.ZClaim.parts =
      [(buildClaim P ⟨.out, [(0, Fp2.one)], 19, StageV.rhoC 0 19, ioOut, 0⟩
          (claimPoint ⟨.out, [(0, Fp2.one)], 19, StageV.rhoC 0 19, ioOut, 0⟩ (recs.getD 22 rec0).rho)
          (oneMinusProd (recs.getD 22 rec0).es) (maskCoef (recs.getD 22 rec0).es 0) Fp2.zero).parts] := by
    have hfp := famProve_claims_parts (liftH G) (corePf P (c, [b, g, a])) (coreDf P Dc (c, [b, g, a])) b g a .out
      (fun s _ _ => if s = 22 then [⟨.out, [(0, Fp2.one)], 19, StageV.rhoC 0 19, ioOut, 0⟩] else [])
      23 [] 0 {} _ sps recs acc t4 hfam (fun i hi _ _ df _ hdf _ _ => by
        rw [Nat.zero_add] at hdf ⊢
        change P.define i _ _ = .ok df at hdf
        rw [hPeq] at hdf; obtain ⟨-, rfl⟩ := defineS_ok hdf
        rw [privsCm_map_eval, (blk_progR13_io_eq (shdP_blkLy k hk) ioIn ioOut i hi).2]
        by_cases h22 : i = 22
        · rw [ite_eq_left h22, ite_eq_left h22]; rfl
        · rw [ite_eq_right h22, ite_eq_right h22]; rfl)
    dsimp only [claimsCm] at hfp
    rw [List.length_nil, List.map_nil, List.nil_append] at hfp
    simp only [Nat.zero_add] at hfp
    rw [hfp, List.range_succ, List.flatMap_append, List.flatMap_singleton,
      List.flatMap_eq_nil_iff.mpr (fun i hi => by
        have hne : i ≠ 22 := by have := List.mem_range.mp hi; omega
        rw [ite_eq_right hne]; rfl),
      List.nil_append, ite_eq_left rfl, List.map_singleton]
  obtain ⟨_, _, hslot⟩ := famProve_split (liftH G) (corePf P (c, [b, g, a])) (coreDf P Dc (c, [b, g, a])) b g a 23 [] 0 {} _ sps recs acc t4 hfam
  cases hout : acc.claims.out with
  | nil => have hl := congrArg List.length hOutParts; rw [hout] at hl; simp only [List.length_map, List.length_nil, List.length_cons] at hl; omega
  | cons cl rest =>
    cases rest with
    | cons _ _ => have hl := congrArg List.length hOutParts; rw [hout] at hl; simp only [List.length_map, List.length_nil, List.length_cons] at hl; omega
    | nil =>
      rw [hout, List.map_singleton, List.singleton_inj] at hOutParts
      obtain ⟨_, _, _, _, sp22, r22, _, _, _, _, hget22, hsp22⟩ := hslot 22 (by omega)
      simp only [Nat.zero_add, List.length_nil] at hget22 hsp22
      obtain ⟨_, _, _, _, _, he22, he22L, _, _, _, _⟩ := slotProve_ok_struct (liftH G) P (Dc c) 22 _ _ _ sp22 r22 _ _ hsp22
      have he22L' : (recs.getD 22 rec0).es.length = 1 := by rw [hget22]; exact he22L.trans (hShape 22 (by omega)).2.2
      have hbc := buildClaim_bndCarryOk P ⟨.out, [(0, Fp2.one)], 19, StageV.rhoC 0 19, ioOut, 0⟩
        (claimPoint ⟨.out, [(0, Fp2.one)], 19, StageV.rhoC 0 19, ioOut, 0⟩ (recs.getD 22 rec0).rho)
        (recs.getD 22 rec0).es cl.value ioOut hEpLog rfl rfl (by unfold claimPoint StageV.rhoC; simp only [List.length_map, List.length_range']) rfl hio
        (fun e he => by rw [hget22] at he; exact (he22 e he).1)
        (fun e he => by rw [hget22] at he; exact (he22 e he).2) (by change 0 < (recs.getD 22 rec0).es.length; omega)
      obtain ⟨cl2, hcl2Eq, hfl2, hsu2, hun2⟩ := hbc
      have hpeq : cl.parts = cl2.parts := by rw [hOutParts, List.singleton_inj.mp hcl2Eq.symm]; rfl
      refine ⟨cl, rfl, by rw [hpeq]; exact hfl2, ?_, fun q hq => by
        have h := hun2 q (by rw [← hpeq]; exact hq); unfold claimKey at h ⊢; rw [hpeq]; exact h⟩
      unfold SurvivingAuditClaim at hsu2 ⊢; unfold claimWeight at hsu2 ⊢; rw [hpeq]; exact hsu2

private theorem shdP_blk_audit_B {Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (pre : Coins → TProg (List Exec.Block.ZClaim)) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 12000 < 2 ^ 64)
    (TB_next TA : Coins → Table) (M : Coins → MTable) (TH : Coins → Fp2 → Fp2 → Fp2 → Table)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (G : QB Lq → Dig) (c : Coins) (D : CoreData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (hA : D.aRoot = rootOf (liftH G) tag 16 (TA c))
    (hM : D.maskRoot = rootOf (liftH G) tag 12 (mTab 23 (cosetPt (rootFp 12)) (M c)))
    (hH : ∀ b g a, D.hRoot b g a = rootOf (liftH G) tag 16 (TH c b g a))
    (hD : D.slot = Dc c)
    (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr)
    (hsl :
      let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
      let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
      slotsProve (liftH G) P D.slot (coreB (liftH G) P D tFr).1 (coreG (liftH G) P D tFr).1 (coreA (liftH G) P D tFr).1 23 [] 0 {}
        (coreT3 (liftH G) P D tFr) = .ok (sps, recs, acc, t4)) :
    let t0 := Tr.newKeyed (liftH G) domain key
    let pend := ((pre c).final (liftH G) t0).2
    ∀ r0, ((r0 = 32 ∧ ioIn = 34) ∨ (r0 = 34 ∧ ioIn = 32)) → BndCarryOk r0 pend →
      OpenAuditOk shdP_bndOpenGeom 14 2 1
        (shdP_blkCollB Lq hLq key domain hdom tag ioIn ioOut checkOpening Rp hR k hk dig pre mPre hs hsq hmPre TB_next TA M TH Dc) G c
        (pend ++ acc.claims.inp) := by
  intro t0 pend r0 hpair hpend
  let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
  let preFr := fun c' => blkFrameProg k dig (pre c') (rootOfP tag 16 (TB_next c'))
  let tFr := ((preFr c).final (liftH G) t0).1
  let b := (coreB (liftH G) P D tFr).1; let g := (coreG (liftH G) P D tFr).1; let a := (coreA (liftH G) P D tFr).1
  have hEpLog : P.endpointLogN = 14 := shdP_Pk0_endpointLogN tag ioIn ioOut checkOpening Rp hR k hk
  have hfam : famProve (liftH G) (corePf P (c, [b, g, a])) (coreDf P Dc (c, [b, g, a])) b g a 23 [] 0 {}
      (coreT3 (liftH G) P D tFr) = .ok (sps, recs, acc, t4) := by
    rw [← slotsProve_eq_fam, ← hD]; exact hsl
  have hShape := shdP_blk_shape_ok tag ioIn ioOut checkOpening Rp hR k hk (c, [b, g, a])
  have hInpParts := shdP_blk_inp_parts Lq key domain tag ioIn ioOut checkOpening Rp hR k hk dig pre TB_next Dc G c D hD sps recs acc t4 hsl
  obtain ⟨_, _, hslot⟩ := famProve_split (liftH G) (corePf P (c, [b, g, a])) (coreDf P Dc (c, [b, g, a])) b g a 23 [] 0 {} _ sps recs acc t4 hfam
  cases hinp : acc.claims.inp with
  | nil => have hl := congrArg List.length hInpParts; rw [hinp] at hl; simp only [List.length_map, List.length_nil, List.length_cons] at hl; omega
  | cons cl1 rest =>
    cases rest with
    | cons _ _ => have hl := congrArg List.length hInpParts; rw [hinp] at hl; simp only [List.length_map, List.length_nil, List.length_cons] at hl; omega
    | nil =>
      rw [hinp, List.map_singleton, List.singleton_inj] at hInpParts
      obtain ⟨sps21, recs21, acc21, t21, sp21, r21, acc22, t22, hfam21, -, hget21, hsp21⟩ := hslot 21 (by omega)
      simp only [Nat.zero_add, List.length_nil] at hget21 hsp21
      obtain ⟨df21, hdf21, -, hrho21, -, he21, he21L, -, -, -, -⟩ :=
        slotProve_ok_struct (liftH G) P (Dc c) 21 _ acc21 t21 sp21 r21 acc22 t22 hsp21
      have he21L' : (recs.getD 21 rec0).es.length = 1 := by rw [hget21]; exact he21L.trans (hShape 21 (by omega)).2.2
      let p21Priv : Priv := ⟨.inp, [(0, Fp2.one)], 19, StageV.rhoC 0 19, ioIn, 0⟩
      let cl1' := buildClaim P p21Priv (claimPoint p21Priv (recs.getD 21 rec0).rho)
        (oneMinusProd (recs.getD 21 rec0).es) (maskCoef (recs.getD 21 rec0).es 0) Fp2.zero
      have hsite : List.range' 32 (36 - 32) = [32, 33, 34, 35] := rfl
      have hsurv1 := buildClaim_survivingAuditClaim P p21Priv (claimPoint p21Priv (recs.getD 21 rec0).rho)
        (recs.getD 21 rec0).es Fp2.zero 32 36 2 1 none (by change 0 < P.endpointLogN; omega) (by change 0 < 19; omega)
        (by unfold claimPoint p21Priv StageV.rhoC; simp only [List.length_map, List.length_range'])
        (fun sc hsc => by rw [List.mem_singleton.mp hsc]; change 0 / 2 ^ P.endpointLogN + (2 ^ 19 + 2 ^ P.endpointLogN - 1) / 2 ^ P.endpointLogN ≤ 32; rw [hEpLog]; norm_num)
        (by change 32 ≤ ioIn; rcases hpair with ⟨-, h⟩ | ⟨-, h⟩ <;> omega)
        (by change ioIn + 2 ≤ 36; rcases hpair with ⟨-, h⟩ | ⟨-, h⟩ <;> omega)
        (by change (ioIn - 32) % 2 = 0; rcases hpair with ⟨-, h⟩ | ⟨-, h⟩ <;> omega)
        (fun e he => by rw [hget21] at he; exact (he21 e he).1)
        (fun e he => by rw [hget21] at he; exact (he21 e he).2) (by change 0 < (recs.getD 21 rec0).es.length; omega)
      have hunif1 := buildClaim_parts_uniform P p21Priv (claimPoint p21Priv (recs.getD 21 rec0).rho)
        (recs.getD 21 rec0).es Fp2.zero (by change 0 < P.endpointLogN; omega) (by intro h; cases h) (by change 0 < 19; omega)
        (by unfold claimPoint p21Priv StageV.rhoC; simp only [List.length_map, List.length_range'])
        (fun _ _ hlt => by change 19 < P.endpointLogN at hlt; omega)
      have hrl1 : rowLog P p21Priv.cm = 14 := hEpLog
      rw [hrl1, hsite] at hsurv1; rw [hrl1] at hunif1
      refine bnd_openAuditOk_of_pair r0 ioIn hpair pend hpend cl1
        (by rw [hInpParts]; exact hsurv1.1)
        (by have hsu1 := hsurv1.2; unfold SurvivingAuditClaim claimWeight at hsu1 ⊢; rw [hInpParts]; exact hsu1)
        (fun q hq => by unfold claimKey; rw [hInpParts] at hq ⊢; exact hunif1.2 q hq)
        _ G c (fun hcoll => ?_)
      dsimp only [shdP_blkCollB, mkBndCollFamily]; rw [zkeyCollisionStartSite_fires]; dsimp only
      have hpre21 : (blkSlotEndProg tag P k dig (fun _ : Coins => TProg.done ()) TB_next TA M TH Dc 21 c).final (liftH G)
          ((pre c).final (liftH G) t0).1 = (t21, ((c, [b, g, a]), recs21, acc21)) := by
        have hhd0 : (blkHeadProg tag P k dig (fun _ : Coins => TProg.done ()) TB_next TA M TH c).final (liftH G)
            ((pre c).final (liftH G) t0).1 = (coreT3 (liftH G) P D tFr, (c, [b, g, a])) := by
          unfold blkHeadProg; rw [final_coreHeadProg]
          have hfr0 : ((blkFrameProg k dig (TProg.done ()) (rootOfP tag 16 (TB_next c))).final (liftH G)
              ((pre c).final (liftH G) t0).1).1 = tFr := by
            unfold tFr preFr; rw [final_blkFrameProg, final_blkFrameProg, final_done_fst]
          rw [hfr0]
          have hT2 : (absorbRoot (liftH G) tFr labA (rootOf (liftH G) tag 16 (TA c)) P.aRows P.logCols).absorb (liftH G)
              labM (rootOf (liftH G) tag 12 (mTab 23 (cosetPt (rootFp 12)) (M c))).toList = coreT2 (liftH G) P D tFr := by
            unfold coreT2; rw [hA, hM]
          rw [hT2, ← hH]; rfl
        rw [blkSlotEndProg, final_famPre (liftH G) (corePf P) (coreDf P Dc) coreBga _ 21 _ sps21 recs21 acc21 t21
          (by rw [hhd0]; exact hfam21), hhd0]
      have hch21 := final_depRoundDrProg_chal (liftH G) (corePf P) (coreDf P Dc) coreBga
        (blkSlotEndProg tag P k dig (fun _ : Coins => TProg.done ()) TB_next TA M TH Dc 21 c) 21 18
        ((pre c).final (liftH G) t0).1 t21 (c, [b, g, a]) recs21 acc21 hpre21 df21 hdf21
        (by rw [(hShape 21 (by omega)).1]; exact blk_mains_21_gt18)
      rw [final_bindP, final_bindP, final_done_fst, final_done_snd]
      rw [hch21.2]
      change Fp2.toK shdP_U
        ((List.take (slotShape P 21).1
            (slotRho (liftH G) P (Dc c) 21 (histOf b g a recs21) acc21 t21 df21)).getD 18 Fp2.zero) = _
      rw [← hrho21, ← hget21]
      have h13 : (claimKey 14 cl1).1.getD 13 Fp2.zero = (recs.getD 21 rec0).rho.getD 18 Fp2.zero := by
        have hk1 : claimKey 14 cl1 = claimKey 14 cl1' := by unfold claimKey; rw [hInpParts]
        rw [hk1, hunif1.1]
        simp only [claimPoint, p21Priv, StageV.rhoC, List.getD_eq_getElem?_getD, List.getElem?_drop,
          List.getElem?_map, List.getElem?_range' (by omega : 19 - 14 + 13 < 19 - 0)]; rfl
      exact congrArg (Fp2.toK shdP_U) (h13.symm.trans (congrArg (fun k => k.1.getD 13 Fp2.zero) hcoll.symm))

/-- **Block `k` `A`, `H`, `B_k` `OpenAuditOk` + output carry & `inp` length discharge**. -/
theorem shdP_blk_audit_and_carry {Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (pre : Coins → TProg (List Exec.Block.ZClaim)) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 12000 < 2 ^ 64)
    (TB_next TA : Coins → Table) (M : Coins → MTable) (TH : Coins → Fp2 → Fp2 → Fp2 → Table)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (G : QB Lq → Dig) (c : Coins) (D : CoreData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (hA : D.aRoot = rootOf (liftH G) tag 16 (TA c))
    (hM : D.maskRoot = rootOf (liftH G) tag 12 (mTab 23 (cosetPt (rootFp 12)) (M c)))
    (hH : ∀ b g a, D.hRoot b g a = rootOf (liftH G) tag 16 (TH c b g a))
    (hD : D.slot = Dc c)
    (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr)
    (hsl :
      let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
      let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
      slotsProve (liftH G) P D.slot (coreB (liftH G) P D tFr).1 (coreG (liftH G) P D tFr).1 (coreA (liftH G) P D tFr).1 23 [] 0 {}
        (coreT3 (liftH G) P D tFr) = .ok (sps, recs, acc, t4)) :
    let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
    let t0 := Tr.newKeyed (liftH G) domain key
    let pend := ((pre c).final (liftH G) t0).2
    OpenAuditOk shdP_blkOpenGeomA 14 146 630
        (shdP_blkCollA Lq hLq key domain hdom tag ioIn ioOut checkOpening Rp hR k hk dig pre mPre hs hsq hmPre TB_next TA M TH Dc) G c acc.claims.a
      ∧ OpenAuditOk shdP_blkOpenGeomH 14 54 36
          (shdP_blkCollH Lq hLq key domain hdom tag ioIn ioOut checkOpening Rp hR k hk dig pre mPre hs hsq hmPre TB_next TA M TH Dc) G c
          (acc.claims.h ++ [P.logupSumClaim])
      ∧ acc.claims.inp.length = 1
      ∧ ((ioOut = 32 ∨ ioOut = 34) → BndCarryOk ioOut acc.claims.out)
      ∧ (∀ r0, ((r0 = 32 ∧ ioIn = 34) ∨ (r0 = 34 ∧ ioIn = 32)) → BndCarryOk r0 pend →
          OpenAuditOk shdP_bndOpenGeom 14 2 1
            (shdP_blkCollB Lq hLq key domain hdom tag ioIn ioOut checkOpening Rp hR k hk dig pre mPre hs hsq hmPre TB_next TA M TH Dc) G c
            (pend ++ acc.claims.inp)) :=
  let hInpLen : acc.claims.inp.length = 1 := by
    have hl := congrArg List.length
      (shdP_blk_inp_parts Lq key domain tag ioIn ioOut checkOpening Rp hR k hk dig pre TB_next Dc G c D hD sps recs acc t4 hsl)
    simpa only [List.length_map, List.length_singleton] using hl
  ⟨shdP_blk_audit_A Lq hLq key domain hdom tag ioIn ioOut checkOpening Rp hR k hk dig pre mPre hs hsq hmPre
      TB_next TA M TH Dc G c D hA hM hH hD sps recs acc t4 hsl,
   shdP_blk_audit_H Lq hLq key domain hdom tag ioIn ioOut checkOpening Rp hR k hk dig pre mPre hs hsq hmPre
      TB_next TA M TH Dc G c D hA hM hH hD sps recs acc t4 hsl,
   hInpLen,
   shdP_blk_out_carry Lq key domain tag ioIn ioOut checkOpening Rp hR k hk dig pre TB_next Dc G c D hD sps recs acc t4 hsl,
   shdP_blk_audit_B Lq hLq key domain hdom tag ioIn ioOut checkOpening Rp hR k hk dig pre mPre hs hsq hmPre
      TB_next TA M TH Dc G c D hA hM hH hD sps recs acc t4 hsl⟩

end BlockAudit

/-! ## 2. Stage OUT-C `OpenCollFamily` & `OpenAuditOk` (`A`, `H`, `B_26`) -/

section StageOutAudit

private def outcPrivsA_at : ℕ → List PrivS
  | 0 => [⟨.a, [(3 * 4096, false)], 12, Exec.Block.DefW16.rhoC 0 12, 16, 0⟩]
  | 1 => [⟨.a, [(3 * 4096, false)], 12, Exec.Block.DefW16.rhoC 0 12, 18, 0⟩]
  | 2 => [⟨.a, [(0, false)], 1, Exec.Block.DefW16.rhoC 0 1, 20, 0⟩,
          ⟨.a, [(4096, false)], 1, Exec.Block.DefW16.rhoC 0 1, 22, 0⟩]
         ++ (List.range 9).map (fun kk => ⟨.a, [(2 * 4096 + 2 * kk, false)], 1, Exec.Block.DefW16.rhoC 0 1, 24 + 2 * kk, 0⟩)
  | 3 => [⟨.a, [(6 * 4096, false)], 12, Exec.Block.DefW16.rhoC 0 12, 42, 0⟩]
  | 4 => [⟨.a, [(2 * 4096, false)], 12, Exec.Block.DefW16.rhoC 0 12, 44, 0⟩]
  | 5 => (List.range 12).map (fun j => ⟨.a, [((3 + j) * 4096, false)], 12, Exec.Block.DefW16.rhoC 0 12, 46 + 2 * j, 0⟩)
         ++ [⟨.a, [(0, false)], 1, [CoordS.fixed .zero], 70, 0⟩]
  | 6 => [⟨.a, [(15 * 4096, false)], 12, Exec.Block.DefW16.rhoC 0 12, 72, 0⟩]
  | _ => []

private def outcPrivsH_at : ℕ → List PrivS
  | 4 => [⟨.h, [(0, false), (4096, true)], 12, Exec.Block.DefW16.rhoC 0 12, 18, 0⟩]
  | 5 => (List.range 6).map (fun j =>
      ⟨.h, [(2 * (1 + j) * 4096, false), ((2 * (1 + j) + 1) * 4096, true)], 12,
        Exec.Block.DefW16.rhoC 0 12, 20 + 2 * j, 0⟩)
  | 6 => [⟨.h, [(14 * 4096, false), (15 * 4096, true)], 12, Exec.Block.DefW16.rhoC 0 12, 32, 0⟩]
  | 7 => [⟨.h, [(16 * 4096, false), (17 * 4096, true)], 12, Exec.Block.DefW16.rhoC 0 12, 34, 0⟩]
  | _ => []

private def outcPrivsA : List (ℕ × PrivS) :=
  (List.range 8).flatMap (fun s => (outcPrivsA_at s).map (fun p => (s, p)))

private def outcPrivsH : List (ℕ × PrivS) :=
  (List.range 8).flatMap (fun s => (outcPrivsH_at s).map (fun p => (s, p)))

private def outcGroupsA : List SymGroup :=
  dedupSymGroupsOrder (outcPrivsA.filterMap (fun sp => (privSymKey 12 sp.2).map (fun k => (sp.1, k))))

private def outcGroupsH : List SymGroup :=
  dedupSymGroupsOrder (outcPrivsH.filterMap (fun sp => (privSymKey 12 sp.2).map (fun k => (sp.1, k))))

private def outcMains : ℕ → ℕ | 2 => 1 | s => if s < 8 then 12 else 0
private def outcExts : ℕ → ℕ | s => if s < 8 then 1 else 0
private def outcDrawsF : ℕ → ℕ | 0 => 12 | 2 => 7 | 4 => 15 | 5 => 23 | 6 => 15 | _ => 0

private theorem outcSpecA_ok :
    outcGroupsA.length = 16
      ∧ checkSymSpec 8 12 16 74 29 false outcMains outcExts outcDrawsF outcPrivsA outcGroupsA = true := by
  decide +kernel

private theorem outcSpecH_ok :
    outcGroupsH.length = 4
      ∧ checkSymSpec 8 12 18 36 9 true outcMains outcExts outcDrawsF outcPrivsH outcGroupsH = true := by
  decide +kernel

private theorem outcPrivsA_all_a : outcPrivsA.all (fun q => decide (q.2.cm = .a)) = true := by
  decide +kernel

private theorem outcPrivsH_all_h : outcPrivsH.all (fun q => decide (q.2.cm = .h)) = true := by
  decide +kernel

private def outcSumPre : List Exec.Block.ZPart :=
  (List.range 8).flatMap (fun p =>
    let sg := if p = 7 then kI (-1) else kI 1
    [⟨2 * p * 4096, 12, sg, []⟩, ⟨(2 * p + 1) * 4096, 12, sg.mul fp2U, []⟩])

private theorem outcSumPre_ok :
    ∀ q ∈ outcSumPre, q.point = [] ∧ 12 ≤ q.logSize ∧ partHi q (2 ^ 12) ≤ 16 := by
  intro q hq; unfold outcSumPre at hq
  obtain ⟨p, hp, hq'⟩ := List.mem_flatMap.mp hq
  have hp8 : p < 8 := List.mem_range.mp hp
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hq'
  rcases hq' with rfl | rfl
  · refine ⟨rfl, le_rfl, ?_⟩; unfold partHi; interval_cases p <;> norm_num
  · refine ⟨rfl, le_rfl, ?_⟩; unfold partHi; interval_cases p <;> norm_num

private theorem shdP_outcLay_audit_nums (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (v : ℕ) :
    let L := outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14
    L.aRows = 76 ∧ L.aProx = 74 ∧ L.aSiteRows = List.range' 16 58
      ∧ L.hRows = 38 ∧ L.hProx = 36 ∧ L.hSiteRows = List.range' 18 18 ∧ L.hURows = (16, 17)
      ∧ L.aLog = [1, 1, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12]
      ∧ L.hLog = [12, 12, 12, 12, 12, 12, 12, 12, 12]
      ∧ (∀ p, p < 16 → L.aOff p = p * 4096)
      ∧ (∀ p, p < 9 → L.hOff p = (2 * p * 4096, (2 * p + 1) * 4096))
      ∧ L.aMaskBase = 16 ∧ L.hMaskBase = 18
      ∧ L.logupSumClaim.parts = outcSumPre ++ [⟨16 * 2 ^ 12, 12, Fp2.one, []⟩, ⟨17 * 2 ^ 12, 12, Fp2.one.mul fp2U, []⟩] := by
  intro L
  have hLv : L = outcLay (shdP_outcPub Rp wDigest) 14 := rc_outcLay_verdict _ 14 v
  rw [hLv]
  obtain ⟨hllo, hldo, hltab, -⟩ := shdP_outcPub_logs Rp wDigest
  have hlt : (shdP_outcPub Rp wDigest).lt = 12 := rfl
  have hlogN : (outcLay (shdP_outcPub Rp wDigest) 14).logN = 12 := hlt
  have hk1 : kI 1 = Fp2.one := by decide
  have haL : (outcLay (shdP_outcPub Rp wDigest) 14).aLog = [1, 1, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12] := by
    change [OutcPub.toLog, OutcPub.toLog, (shdP_outcPub Rp wDigest).llo]
      ++ List.replicate 12 (shdP_outcPub Rp wDigest).ldo ++ [(shdP_outcPub Rp wDigest).ltab] = _
    rw [hllo, hldo, hltab]; rfl
  have hhL : (outcLay (shdP_outcPub Rp wDigest) 14).hLog = [12, 12, 12, 12, 12, 12, 12, 12, 12] := by
    change [(shdP_outcPub Rp wDigest).llo] ++ List.replicate 6 (shdP_outcPub Rp wDigest).ldo
      ++ [(shdP_outcPub Rp wDigest).ltab, (shdP_outcPub Rp wDigest).lt] = _
    rw [hllo, hldo, hltab, hlt]; rfl
  have haRowsL : (outcLay (shdP_outcPub Rp wDigest) 14).aRowsL = List.replicate 16 1 := by
    unfold Lay.aRowsL; rw [haL, hlogN]; decide
  have hhRowsL : (outcLay (shdP_outcPub Rp wDigest) 14).hRowsL = List.replicate 9 1 := by
    unfold Lay.hRowsL; rw [hhL, hlogN]; decide
  have haOff : ∀ p, p < 16 → (outcLay (shdP_outcPub Rp wDigest) 14).aOff p = p * 4096 := fun p hp => by
    unfold Lay.aOff Lay.n; rw [haRowsL]
    change ((List.replicate 16 1).take p).sum * 2 ^ 12 = p * 4096
    rw [List.take_replicate, List.sum_replicate_nat, Nat.min_eq_left (by omega), Nat.mul_one]; norm_num
  have hhOff : ∀ p, p < 9 → (outcLay (shdP_outcPub Rp wDigest) 14).hOff p = (2 * p * 4096, (2 * p + 1) * 4096) := fun p hp => by
    unfold Lay.hOff Lay.n; rw [hhRowsL]
    have hget : (List.replicate 9 1).getD p 0 = 1 := by
      rw [List.getD_eq_getElem?_getD, List.getElem?_replicate, ite_eq_left hp]; rfl
    change ((2 * ((List.replicate 9 1).take p).sum) * 2 ^ 12,
        (2 * ((List.replicate 9 1).take p).sum + (List.replicate 9 1).getD p 0) * 2 ^ 12) = _
    rw [List.take_replicate, List.sum_replicate_nat, Nat.min_eq_left (by omega), Nat.mul_one, hget]; norm_num
  have haRows : (outcLay (shdP_outcPub Rp wDigest) 14).aRows = 76 := (shdP_outcLay_nums Rp wDigest).1
  have hhRows : (outcLay (shdP_outcPub Rp wDigest) 14).hRows = 38 := (shdP_outcLay_nums Rp wDigest).2.1
  have haMb : (outcLay (shdP_outcPub Rp wDigest) 14).aMaskBase = 16 := by unfold Lay.aMaskBase Lay.aDataRows; rw [haRowsL]; rfl
  have hhMb : (outcLay (shdP_outcPub Rp wDigest) 14).hMaskBase = 18 := by unfold Lay.hMaskBase Lay.hDataRows; rw [hhRowsL]; rfl
  have haPr : (outcLay (shdP_outcPub Rp wDigest) 14).aProx = 74 := by unfold Lay.aRows at haRows; omega
  have hhPr : (outcLay (shdP_outcPub Rp wDigest) 14).hProx = 36 := by unfold Lay.hRows at hhRows; omega
  refine ⟨haRows, haPr, by unfold Lay.aSiteRows; rw [haMb, haPr], hhRows, hhPr,
    by unfold Lay.hSiteRows; rw [hhMb, hhPr],
    by unfold Lay.hURows Lay.n; rw [show (outcLay (shdP_outcPub Rp wDigest) 14).hU = 8 from rfl, hhOff 8 (by omega), hlogN]; decide,
    haL, hhL, haOff, hhOff, haMb, hhMb, ?_⟩
  unfold Lay.logupSumClaim
  have hlen9 : (outcLay (shdP_outcPub Rp wDigest) 14).hLog.length = 9 := by rw [hhL]; rfl
  rw [hlen9, List.range_succ, List.flatMap_append, List.flatMap_singleton]
  refine congrArg₂ (· ++ ·) ?_ ?_
  · unfold outcSumPre
    refine flatMap_congr_eq (fun p hp => ?_)
    have hp8 : p < 8 := List.mem_range.mp hp
    rw [hhOff p (by omega), hhL]
    have hlogp : ([12, 12, 12, 12, 12, 12, 12, 12, 12] : List ℕ).getD p 0 = 12 := by interval_cases p <;> rfl
    have hsgn : (outcLay (shdP_outcPub Rp wDigest) 14).hSign.getD p 0 = if p = 7 then -1 else 1 := by
      change ([1, 1, 1, 1, 1, 1, 1, -1, 1] : List ℤ).getD p 0 = _; interval_cases p <;> rfl
    rw [hlogp, hsgn]
    by_cases h7 : p = 7
    · rw [ite_eq_left h7, ite_eq_left h7]
    · rw [ite_eq_right h7, ite_eq_right h7]
  · rw [hhOff 8 (by omega), hhL]
    have hlog8 : ([12, 12, 12, 12, 12, 12, 12, 12, 12] : List ℕ).getD 8 0 = 12 := rfl
    have hsgn8 : (outcLay (shdP_outcPub Rp wDigest) 14).hSign.getD 8 0 = 1 := rfl
    rw [hlog8, hsgn8, hk1]; rfl

private theorem shdP_outcDefine_privs (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v s : ℕ)
    (hs : s < 8) (hist : Hist) (dr : List Fp2) (df : SlotDef)
    (hlen : dr.length = outcDraws (rcVerdict (shdP_outcPub Rp wDigest) v) s)
    (hcan : ∀ a ∈ dr, a.Canon)
    (hdef : outcDefine (rcVerdict (shdP_outcPub Rp wDigest) v) (shdP_outcGeo bOutRow) s hist dr = .ok df)
    (ev : Sym → Fp2) (hev0 : ev .zero = Fp2.zero) :
    privsCm .a df.tabs = (outcPrivsA_at s).map (PrivS.eval ev)
      ∧ privsCm .h df.tabs = (outcPrivsH_at s).map (PrivS.eval ev)
      ∧ privsCm .inp df.tabs = (if s = 0 then [⟨.inp, [(0, Fp2.one)], 19, fixedBits Rp.row.val 7 ++ StageV.rhoC 0 12, bOutRow, 0⟩] else []) := by
  let O := rcVerdict (shdP_outcPub Rp wDigest) v; let G := shdP_outcGeo bOutRow; let L := outcLay O 14
  have hLG : outcLay O G.bLogN = L := rfl
  obtain ⟨hllo, hldo, hltab, hdb⟩ := shdP_outcPub_logs Rp wDigest
  have hllo' : O.llo = 12 := hllo; have hldo' : O.ldo = 12 := hldo; have hltab' : O.ltab = 12 := hltab
  have hdb' : O.dBits = 12 := hdb; have htb' : O.tBits = 7 := shdP_clog2_128
  have hlift : O.lift = 0 := by unfold OutcPub.lift; omega
  have hbout : O.bOutLog = 19 := by show Nat.log2 (128 * 4096) = 19; exact (Nat.log2_eq_iff (by norm_num)).mpr ⟨by norm_num, by norm_num⟩
  obtain ⟨-, -, -, -, -, -, -, haL, hhL, haOff, hhOff, haMb, hhMb, -⟩ := shdP_outcLay_audit_nums Rp wDigest v
  change L.aLog = _ at haL; change L.hLog = _ at hhL
  change ∀ p, p < 16 → L.aOff p = p * 4096 at haOff
  change ∀ p, p < 9 → L.hOff p = (2 * p * 4096, (2 * p + 1) * 4096) at hhOff
  change L.aMaskBase = 16 at haMb; change L.hMaskBase = 18 at hhMb
  interval_cases s
  · change outcDefIO O G dr = .ok df at hdef; rw [outcDefIO_ok O G dr] at hdef; cases hdef
    have hp0 : L.prefixA 0 = 0 := rfl
    have haX := haOff ocC_X (by decide)
    refine ⟨?_, rfl, ?_⟩
    · change ([⟨.a, [(L.aOff ocC_X, Fp2.one)], L.aLog.getD ocC_X 0,
          fixedC (List.replicate O.lift Fp2.zero) ++ StageV.rhoC 0 O.dBits,
          L.aMaskBase + 2 * (L.prefixA 0 + 0), 0⟩] : List Priv) = _
      rw [haX, haL, haMb, hp0, hlift, hdb']; rfl
    · change ([⟨.inp, [(0, Fp2.one)], O.bOutLog, fixedBits Rp.row.val O.tBits ++ StageV.rhoC 0 O.dBits, bOutRow, 0⟩] : List Priv) = _
      rw [hbout, htb', hdb']; rfl
  · change outcDefSS O G = .ok df at hdef; rw [outcDefSS_ok O G] at hdef; cases hdef
    have hp1 : L.prefixA 1 = 1 := rfl
    have haX := haOff ocC_X (by decide)
    refine ⟨?_, rfl, rfl⟩
    change ([⟨.a, [(L.aOff ocC_X, Fp2.one)], L.aLog.getD ocC_X 0,
        StageV.rhoC 0 (L.aLog.getD ocC_X 0), L.aMaskBase + 2 * (L.prefixA 1 + 0), 0⟩] : List Priv) = _
    rw [haX, haL, haMb, hp1]; rfl
  · change outcDefTZC O G dr = .ok df at hdef; rw [shdP_outcDraws_eq_run] at hlen
    let y : Fin 7 → shdP_K := fun j => (dr.getD j.val Fp2.zero).toK shdP_U
    have hw : stgWords shdP_U shdP_hbij y = dr := stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 7 hlen
    have hne : ∀ j ∈ Z_range 7 1 6, y j ≠ 0 := fun j hj hy0 => by
      obtain ⟨_, hm⟩ := outcDefTZC_err shdP_U shdP_hbij shdP_hU O G y ⟨j, hj, hy0⟩; rw [hw] at hm; rw [hm] at hdef; cases hdef
    have hok := outcDefTZC_ok shdP_U shdP_hbij shdP_hU O G rfl y hne
    rw [hw] at hok; rw [hok] at hdef; cases hdef
    have hp2 : L.prefixA 2 = 2 := rfl
    have hZ9 : (List.range (3 * OutcPub.limbsIsqrt)).zipIdx 2 =
        [(0, 2), (1, 3), (2, 4), (3, 5), (4, 6), (5, 7), (6, 8), (7, 9), (8, 10)] := rfl
    have haD := haOff ocC_D (by decide)
    have haDSQ := haOff ocC_DSQ (by decide)
    have haLm := haOff ocC_LIMB (by decide)
    refine ⟨?_, rfl, rfl⟩
    simp only [hLG, hZ9, List.map_cons, List.map_nil, List.cons_append, List.nil_append]
    simp only [haD, haDSQ, haLm, haL, haMb, hp2]
    rfl
  · change outcDefPD O G = .ok df at hdef; rw [outcDefPD_ok O G] at hdef; cases hdef
    have hp3 : L.prefixA 3 = 13 := rfl
    have haY := haOff ocC_Y (by decide)
    refine ⟨?_, rfl, rfl⟩
    change ([⟨.a, [(L.aOff ocC_Y, Fp2.one)], L.aLog.getD ocC_Y 0,
        fixedC (List.replicate O.lift Fp2.zero) ++ StageV.rhoC 0 O.dBits,
        L.aMaskBase + 2 * (L.prefixA 3 + 0), 0⟩] : List Priv) = _
    rw [haY, haL, haMb, hp3, hlift, hdb']; rfl
  · change outcDefLZC O G hist dr = .ok df at hdef; rw [shdP_outcDraws_eq_run] at hlen
    let y : Fin 15 → shdP_K := fun j => (dr.getD j.val Fp2.zero).toK shdP_U
    have hw : stgWords shdP_U shdP_hbij y = dr := stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 15 hlen
    have hne : ∀ j ∈ Z_range 15 O.llo 3, y j ≠ 0 := fun j hj hy0 => by
      obtain ⟨_, hm⟩ := outcDefLZC_err shdP_U shdP_hbij shdP_hU O G hist y ⟨j, hj, hy0⟩; rw [hw] at hm; rw [hm] at hdef; cases hdef
    have hok := outcDefLZC_ok shdP_U shdP_hbij shdP_hU O G hist (by omega) y hne
    rw [hw] at hok; rw [hok] at hdef; cases hdef
    have hp4A : L.prefixA 4 = 14 := rfl; have hp4H : L.prefixH 4 = 0 := rfl
    have haLm := haOff ocC_LIMB (by decide)
    have hhLo := hhOff ocH_LO (by decide)
    refine ⟨?_, ?_, rfl⟩
    · change ([⟨.a, [(L.aOff ocC_LIMB, Fp2.one)], L.aLog.getD ocC_LIMB 0,
          StageV.rhoC 0 (L.aLog.getD ocC_LIMB 0), L.aMaskBase + 2 * (L.prefixA 4 + 0), 0⟩] : List Priv) = _
      rw [haLm, haL, haMb, hp4A]; rfl
    · change ([⟨.h, [((L.hOff ocH_LO).1, Fp2.one), ((L.hOff ocH_LO).2, fp2U)],
          L.hLog.getD ocH_LO 0, StageV.rhoC 0 (L.hLog.getD ocH_LO 0), L.hMaskBase + 2 * (L.prefixH 4 + 0), 0⟩] : List Priv) = _
      rw [hhLo, hhL, hhMb, hp4H]; rfl
  · change outcDefDZC O G hist dr = .ok df at hdef; rw [shdP_outcDraws_eq_run] at hlen
    let y : Fin 23 → shdP_K := fun j => (dr.getD j.val Fp2.zero).toK shdP_U
    have hw : stgWords shdP_U shdP_hbij y = dr := stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 23 hlen
    have hne : ∀ j ∈ Z_range 23 O.ldo 11, y j ≠ 0 := fun j hj hy0 => by
      obtain ⟨_, hm⟩ := outcDefDZC_err shdP_U shdP_hbij shdP_hU O G hist y ⟨j, hj, hy0⟩; rw [hw] at hm; rw [hm] at hdef; cases hdef
    have hok := outcDefDZC_ok shdP_U shdP_hbij shdP_hU O G hist (by omega) y hne
    rw [hw] at hok; rw [hok] at hdef; cases hdef
    have hp5A : L.prefixA 5 = 15 := rfl; have hp5H : L.prefixH 5 = 1 := rfl
    have hZ12 : (List.range' ocC_X (ocC_MULT - ocC_X)).zipIdx 0 =
        [(3, 0), (4, 1), (5, 2), (6, 3), (7, 4), (8, 5), (9, 6), (10, 7), (11, 8), (12, 9), (13, 10), (14, 11)] := rfl
    have hZ6 : (List.range 6).zipIdx 0 = [(0, 0), (1, 1), (2, 2), (3, 3), (4, 4), (5, 5)] := rfl
    have hLen12 : (List.range' ocC_X (ocC_MULT - ocC_X)).length = 12 := rfl
    have haD := haOff ocC_D (by decide)
    have ha3 := haOff 3 (by omega); have ha4 := haOff 4 (by omega); have ha5 := haOff 5 (by omega)
    have ha6 := haOff 6 (by omega); have ha7 := haOff 7 (by omega); have ha8 := haOff 8 (by omega)
    have ha9 := haOff 9 (by omega); have ha10 := haOff 10 (by omega); have ha11 := haOff 11 (by omega)
    have ha12 := haOff 12 (by omega); have ha13 := haOff 13 (by omega); have ha14 := haOff 14 (by omega)
    have hh1 : L.hOff (ocH_D0 + 0) = (2 * 1 * 4096, 3 * 4096) := hhOff 1 (by omega)
    have hh2 : L.hOff (ocH_D0 + 1) = (2 * 2 * 4096, 5 * 4096) := hhOff 2 (by omega)
    have hh3 : L.hOff (ocH_D0 + 2) = (2 * 3 * 4096, 7 * 4096) := hhOff 3 (by omega)
    have hh4 : L.hOff (ocH_D0 + 3) = (2 * 4 * 4096, 9 * 4096) := hhOff 4 (by omega)
    have hh5 : L.hOff (ocH_D0 + 4) = (2 * 5 * 4096, 11 * 4096) := hhOff 5 (by omega)
    have hh6 : L.hOff (ocH_D0 + 5) = (2 * 6 * 4096, 13 * 4096) := hhOff 6 (by omega)
    refine ⟨?_, ?_, rfl⟩
    · simp only [hLG, hZ12, hZ6, hLen12, List.map_cons, List.map_nil, List.cons_append, List.nil_append]
      simp only [haD, ha3, ha4, ha5, ha6, ha7, ha8, ha9, ha10, ha11, ha12, ha13, ha14, haL, haMb, hp5A]
      change _ = (List.range 12).map (fun j => (⟨.a, [((3 + j) * 4096, Fp2.one)], 12, StageV.rhoC 0 12, 46 + 2 * j, 0⟩ : Priv))
        ++ [(⟨.a, [(0, Fp2.one)], 1, [Coord.fixed (ev .zero)], 70, 0⟩ : Priv)]
      rw [hev0]; rfl
    · simp only [hLG, hZ12, hZ6, hLen12, List.map_cons, List.map_nil, List.cons_append, List.nil_append]
      simp only [hh1, hh2, hh3, hh4, hh5, hh6, hhL, hhMb, hp5H]; rfl
  · change outcDefTAB O G hist dr = .ok df at hdef; rw [shdP_outcDraws_eq_run] at hlen
    let y : Fin 15 → shdP_K := fun j => (dr.getD j.val Fp2.zero).toK shdP_U
    have hw : stgWords shdP_U shdP_hbij y = dr := stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 15 hlen
    have hne : ∀ j ∈ Z_range 15 O.ltab 3, y j ≠ 0 := fun j hj hy0 => by
      obtain ⟨_, hm⟩ := outcDefTAB_err shdP_U shdP_hbij shdP_hU O G hist y ⟨j, hj, hy0⟩; rw [hw] at hm; rw [hm] at hdef; cases hdef
    have hok := outcDefTAB_ok shdP_U shdP_hbij shdP_hU O G hist (by omega) y hne
    rw [hw] at hok; rw [hok] at hdef; cases hdef
    have hp6A : L.prefixA 6 = 28 := rfl; have hp6H : L.prefixH 6 = 7 := rfl
    have haM := haOff ocC_MULT (by decide)
    have hhG := hhOff ocH_GU8 (by decide)
    refine ⟨?_, ?_, rfl⟩
    · change ([⟨.a, [(L.aOff ocC_MULT, Fp2.one)], L.aLog.getD ocC_MULT 0,
          StageV.rhoC 0 (L.aLog.getD ocC_MULT 0), L.aMaskBase + 2 * (L.prefixA 6 + 0), 0⟩] : List Priv) = _
      rw [haM, haL, haMb, hp6A]; rfl
    · change ([⟨.h, [((L.hOff ocH_GU8).1, Fp2.one), ((L.hOff ocH_GU8).2, fp2U)],
          L.hLog.getD ocH_GU8 0, StageV.rhoC 0 (L.hLog.getD ocH_GU8 0), L.hMaskBase + 2 * (L.prefixH 6 + 0), 0⟩] : List Priv) = _
      rw [hhG, hhL, hhMb, hp6H]; rfl
  · change outcDefZS O G = .ok df at hdef; rw [outcDefZS_ok O G] at hdef; cases hdef
    have hp7H : L.prefixH 7 = 8 := rfl
    have hhU := hhOff ocH_U (by decide)
    refine ⟨rfl, ?_, rfl⟩
    change ([⟨.h, [((L.hOff ocH_U).1, Fp2.one), ((L.hOff ocH_U).2, fp2U)],
        L.hLog.getD ocH_U 0, StageV.rhoC 0 (L.hLog.getD ocH_U 0), L.hMaskBase + 2 * (L.prefixH 7 + 0), 0⟩] : List Priv) = _
    rw [hhU, hhL, hhMb, hp7H]; rfl

private theorem outcSlotEndProg_eq {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (wDigest : Dig) (bOutRow v : ℕ) (pre : Coins → TProg α) (TA : Coins → Table) (M : Coins → MTable)
    (TH : Coins → List Fp2 → Table) (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp) (s : ℕ) (c : Coins) :
    let V := shdVo tag Rp wDigest bOutRow v
    outcSlotEndProg tag Rp wDigest bOutRow v pre TA M TH Dc s c
      = famPre (outcPf V) (outcDf V Dc) outcBga
          (outcHeadProg V c (pre c) (rootOfP tag 14 (TA c))
            (rootOfP tag 12 (mTab 8 (cosetPt (rootFp 12)) (M c))) (fun ch' => rootOfP tag 14 (TH c ch'))) s := rfl

noncomputable def shdP_outcCollA {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v : ℕ)
    (pre : Coins → TProg α) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 1000 < 2 ^ 64)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp) : OpenCollFamily Lq Coins 120 :=
  let V := shdVo tag Rp wDigest bOutRow v
  symCollFamily Lq hLq key domain hdom (outcPf V) (outcDf V Dc) outcBga
    (fun s c' => famPre (outcPf V) (outcDf V Dc) outcBga
      (outcHeadProg V c' (pre c') (rootOfP tag 14 (TA c'))
        (rootOfP tag 12 (mTab 8 (cosetPt (rootFp 12)) (M c'))) (fun ch' => rootOfP tag 14 (TH c' ch'))) s)
    8 (mPre + 175) 23 15
    outcMains outcDrawsF outcGroupsA 16 120 (by rw [strictPairs_length])
    (fun s hsLt c => sep_of_eq (outcSlotEndProg_eq tag Rp wDigest bOutRow v pre TA M TH Dc s c)
      (shdP_outcSlotEndProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c).1)
    (fun s hsLt c => sqLE_of_eq (outcSlotEndProg_eq tag Rp wDigest bOutRow v pre TA M TH Dc s c)
      (shdP_outcSlotEndProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c).2)
    (fun s hsLt _ => by change outcDraws (rcVerdict (shdP_outcPub Rp wDigest) v) s ≤ 23; rw [shdP_outcDraws_eq_run]; interval_cases s <;> norm_num) (by omega)

noncomputable def shdP_outcCollH {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v : ℕ)
    (pre : Coins → TProg α) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 1000 < 2 ^ 64)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp) : OpenCollFamily Lq Coins 10 :=
  let V := shdVo tag Rp wDigest bOutRow v
  symCollFamily Lq hLq key domain hdom (outcPf V) (outcDf V Dc) outcBga
    (fun s c' => famPre (outcPf V) (outcDf V Dc) outcBga
      (outcHeadProg V c' (pre c') (rootOfP tag 14 (TA c'))
        (rootOfP tag 12 (mTab 8 (cosetPt (rootFp 12)) (M c'))) (fun ch' => rootOfP tag 14 (TH c' ch'))) s)
    8 (mPre + 175) 23 15
    outcMains outcDrawsF outcGroupsH 5 10 (by rw [strictPairs_length])
    (fun s hsLt c => sep_of_eq (outcSlotEndProg_eq tag Rp wDigest bOutRow v pre TA M TH Dc s c)
      (shdP_outcSlotEndProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c).1)
    (fun s hsLt c => sqLE_of_eq (outcSlotEndProg_eq tag Rp wDigest bOutRow v pre TA M TH Dc s c)
      (shdP_outcSlotEndProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c).2)
    (fun s hsLt _ => by change outcDraws (rcVerdict (shdP_outcPub Rp wDigest) v) s ≤ 23; rw [shdP_outcDraws_eq_run]; interval_cases s <;> norm_num) (by omega)

noncomputable def shdP_outcCollB {Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v : ℕ)
    (pre : Coins → TProg (List Exec.Block.ZClaim)) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 1000 < 2 ^ 64)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp) : OpenCollFamily Lq Coins 1 :=
  let V := shdVo tag Rp wDigest bOutRow v
  mkBndCollFamily Lq hLq key domain hdom (outcPf V) (outcDf V Dc) outcBga pre mPre hs hsq
    (outcSlotEndProg tag Rp wDigest bOutRow v (fun _ : Coins => TProg.done ()) TA M TH Dc 0)
    0 11 (0 + 175) 23
    (shdP_outcSlotEndProg_sep_sq tag Rp wDigest bOutRow v 0 key (fun _ : Coins => TProg.done ()) TA M TH Dc
      (fun _ => trivial) (fun _ => trivial) 0 (by omega))
    (fun _ => by change outcDraws (rcVerdict (shdP_outcPub Rp wDigest) v) 0 ≤ 23; rw [shdP_outcDraws_eq_run]; norm_num)
    (by omega)

private theorem shdP_outc_audit_A {Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v : ℕ)
    (pre : Coins → TProg (List Exec.Block.ZClaim)) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 1000 < 2 ^ 64)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp)
    (G : QB Lq → Dig) (c : Coins) (D : OutcData (shdVo tag Rp wDigest bOutRow v))
    (hA : D.aRoot = rootOf (liftH G) tag 14 (TA c))
    (hM : D.maskRoot = rootOf (liftH G) tag 12 (mTab 8 (cosetPt (rootFp 12)) (M c)))
    (hH : ∀ ch, D.hRoot ch = rootOf (liftH G) tag 14 (TH c ch))
    (hD : D.slot = Dc c)
    (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr)
    (hsl :
      let V := shdVo tag Rp wDigest bOutRow v
      let ch := (outcCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).1
      slotsProve (liftH G) V.bp D.slot (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 8 [] 0 {}
        (absorbRoot (liftH G) (outcCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).2 labH (D.hRoot ch) V.bp.hRows V.bp.logCols)
        = .ok (sps, recs, acc, t4)) :
    let V := shdVo tag Rp wDigest bOutRow v
    OpenAuditOk ⟨V.lay.aRows, V.lay.aSiteRows, none, V.lay.aProx, outcAGroups⟩ 12 29 120
      (shdP_outcCollA Lq hLq key domain hdom tag Rp wDigest bOutRow v pre mPre hs hsq hmPre TA M TH Dc) G c acc.claims.a := by
  intro V
  let t0 := Tr.newKeyed (liftH G) domain key
  let tStart := ((pre c).final (liftH G) t0).1
  let ch := (outcCh (liftH G) V D tStart).1
  let hd := fun c' => outcHeadProg V c' (pre c') (rootOfP tag 14 (TA c'))
    (rootOfP tag 12 (mTab 8 (cosetPt (rootFp 12)) (M c'))) (fun ch' => rootOfP tag 14 (TH c' ch'))
  have hF : (hd c).final (liftH G) t0
      = (absorbRoot (liftH G) (outcCh (liftH G) V D tStart).2 labH (D.hRoot ch) V.bp.hRows V.bp.logCols, (c, ch)) := by
    rw [final_outcHeadProg, hH]; unfold ch outcCh; rw [hA, hM]
  have hfam : famProve (liftH G) (outcPf V (c, ch)) (outcDf V Dc (c, ch)) (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2
      8 [] 0 {} (absorbRoot (liftH G) (outcCh (liftH G) V D tStart).2 labH (D.hRoot ch) V.bp.hRows V.bp.logCols)
      = .ok (sps, recs, acc, t4) := by
    rw [← slotsProve_eq_fam, ← hD]; exact hsl
  obtain ⟨haR, haP, haS, -, -, -, -, -, -, -, -, -, -, -⟩ := shdP_outcLay_audit_nums Rp wDigest v
  have hVlay : V.lay = outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14 := rfl
  have hShape : ∀ s, s < 8 → (slotShape (outcPf V (c, ch) s) s).1 = outcMains s ∧ outcMains s ≤ 15
      ∧ (slotShape (outcPf V (c, ch) s) s).2.1 = outcExts s := fun s hsLt => by
    change (slotShape V.bp s).1 = _ ∧ _ ∧ (slotShape V.bp s).2.1 = _
    rw [shdP_outcSlotShape_eq_run]; interval_cases s <;> decide
  have hdEq : ∀ s, s < 8 → (outcPf V (c, ch) s).draws s = outcDrawsF s := fun s hsLt => by
    change outcDraws (rcVerdict (shdP_outcPub Rp wDigest) v) s = _; rw [shdP_outcDraws_eq_run]; interval_cases s <;> rfl
  have hPartsA : acc.claims.a.map Exec.Block.ZClaim.parts = outcPrivsA.map (fun sp =>
      let r := recs.getD sp.1 rec0
      let ev := Sym.eval (histOf (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 (recs.take sp.1)) sp.1 r.draws
      let p := sp.2.eval ev
      (buildClaim (outcPf V (c, ch) sp.1) p (claimPoint p r.rho) (oneMinusProd r.es) (maskCoef r.es p.extRound) Fp2.zero).parts) ++ [] := by
    have hfp := famProve_claims_parts (liftH G) (outcPf V (c, ch)) (outcDf V Dc (c, ch)) _ _ _ .a
      (fun s recs1 dr => (outcPrivsA_at s).map
        (PrivS.eval (Sym.eval (histOf (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 recs1) s dr)))
      8 [] 0 {} _ sps recs acc t4 hfam (fun i hi recs1 dr df _ hdf hdrLen hcan => by
        rw [Nat.zero_add] at hdf hdrLen ⊢
        exact (shdP_outcDefine_privs Rp wDigest bOutRow v i hi
          (histOf (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 recs1) dr df hdrLen hcan hdf
          (Sym.eval (histOf (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 recs1) i dr) rfl).1)
    dsimp only [claimsCm] at hfp
    rw [List.length_nil, List.map_nil, List.nil_append] at hfp
    simp only [Nat.zero_add] at hfp
    rw [hfp, List.append_nil]
    exact flatMap_map_pair_map (List.range 8) outcPrivsA_at _ _ _ (fun _ _ => rfl)
  have h := openAuditOk_of_symSpec Lq hLq key domain hdom (outcPf V) (outcDf V Dc) outcBga hd
    8 12 76 16 74 29 16 120 (mPre + 175) 23 15 outcMains outcExts outcDrawsF outcPrivsA outcGroupsA none
    (by rw [strictPairs_length])
    (fun s hsLt c' => sep_of_eq (outcSlotEndProg_eq tag Rp wDigest bOutRow v pre TA M TH Dc s c')
      (shdP_outcSlotEndProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c').1)
    (fun s hsLt c' => sqLE_of_eq (outcSlotEndProg_eq tag Rp wDigest bOutRow v pre TA M TH Dc s c')
      (shdP_outcSlotEndProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c').2)
    (fun s hsLt _ => by change outcDraws (rcVerdict (shdP_outcPub Rp wDigest) v) s ≤ 23; rw [shdP_outcDraws_eq_run]; interval_cases s <;> norm_num)
    (by omega) (by norm_num) rfl rfl (by rw [outcSpecA_ok.1]; rfl) outcSpecA_ok.2 G c (c, ch) _ hF
    hShape hdEq (fun sp hsp => by
      have hcm : sp.2.cm = .a := of_decide_eq_true (List.all_eq_true.mp outcPrivsA_all_a sp hsp)
      unfold rowLog; rw [hcm]; rfl)
    sps recs acc t4 hfam (fun _ _ _ _ h => by cases h) acc.claims.a hPartsA
  change OpenAuditOk ⟨V.lay.aRows, V.lay.aSiteRows, none, V.lay.aProx, outcAGroups⟩ 12 29 120 _ G c acc.claims.a
  rw [hVlay, haR, haP, haS]; exact h

private theorem shdP_outc_audit_H {Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v : ℕ)
    (pre : Coins → TProg (List Exec.Block.ZClaim)) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 1000 < 2 ^ 64)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp)
    (G : QB Lq → Dig) (c : Coins) (D : OutcData (shdVo tag Rp wDigest bOutRow v))
    (hA : D.aRoot = rootOf (liftH G) tag 14 (TA c))
    (hM : D.maskRoot = rootOf (liftH G) tag 12 (mTab 8 (cosetPt (rootFp 12)) (M c)))
    (hH : ∀ ch, D.hRoot ch = rootOf (liftH G) tag 14 (TH c ch))
    (hD : D.slot = Dc c)
    (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr)
    (hsl :
      let V := shdVo tag Rp wDigest bOutRow v
      let ch := (outcCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).1
      slotsProve (liftH G) V.bp D.slot (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 8 [] 0 {}
        (absorbRoot (liftH G) (outcCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).2 labH (D.hRoot ch) V.bp.hRows V.bp.logCols)
        = .ok (sps, recs, acc, t4)) :
    let V := shdVo tag Rp wDigest bOutRow v
    OpenAuditOk ⟨V.lay.hRows, V.lay.hSiteRows, some V.lay.hURows, V.lay.hProx, outcHGroups⟩ 12 10 10
      (shdP_outcCollH Lq hLq key domain hdom tag Rp wDigest bOutRow v pre mPre hs hsq hmPre TA M TH Dc) G c
      (acc.claims.h ++ [V.lay.logupSumClaim]) := by
  intro V
  let t0 := Tr.newKeyed (liftH G) domain key
  let tStart := ((pre c).final (liftH G) t0).1
  let ch := (outcCh (liftH G) V D tStart).1
  let hd := fun c' => outcHeadProg V c' (pre c') (rootOfP tag 14 (TA c'))
    (rootOfP tag 12 (mTab 8 (cosetPt (rootFp 12)) (M c'))) (fun ch' => rootOfP tag 14 (TH c' ch'))
  have hF : (hd c).final (liftH G) t0
      = (absorbRoot (liftH G) (outcCh (liftH G) V D tStart).2 labH (D.hRoot ch) V.bp.hRows V.bp.logCols, (c, ch)) := by
    rw [final_outcHeadProg, hH]; unfold ch outcCh; rw [hA, hM]
  have hfam : famProve (liftH G) (outcPf V (c, ch)) (outcDf V Dc (c, ch)) (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2
      8 [] 0 {} (absorbRoot (liftH G) (outcCh (liftH G) V D tStart).2 labH (D.hRoot ch) V.bp.hRows V.bp.logCols)
      = .ok (sps, recs, acc, t4) := by
    rw [← slotsProve_eq_fam, ← hD]; exact hsl
  obtain ⟨-, -, -, hhR, hhP, hhS, hhU, -, -, -, -, -, -, hsumParts⟩ := shdP_outcLay_audit_nums Rp wDigest v
  have hVlay : V.lay = outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14 := rfl
  have hShape : ∀ s, s < 8 → (slotShape (outcPf V (c, ch) s) s).1 = outcMains s ∧ outcMains s ≤ 15
      ∧ (slotShape (outcPf V (c, ch) s) s).2.1 = outcExts s := fun s hsLt => by
    change (slotShape V.bp s).1 = _ ∧ _ ∧ (slotShape V.bp s).2.1 = _
    rw [shdP_outcSlotShape_eq_run]; interval_cases s <;> decide
  have hdEq : ∀ s, s < 8 → (outcPf V (c, ch) s).draws s = outcDrawsF s := fun s hsLt => by
    change outcDraws (rcVerdict (shdP_outcPub Rp wDigest) v) s = _; rw [shdP_outcDraws_eq_run]; interval_cases s <;> rfl
  have hPartsH : (acc.claims.h ++ [V.lay.logupSumClaim]).map Exec.Block.ZClaim.parts = outcPrivsH.map (fun sp =>
      let r := recs.getD sp.1 rec0
      let ev := Sym.eval (histOf (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 (recs.take sp.1)) sp.1 r.draws
      let p := sp.2.eval ev
      (buildClaim (outcPf V (c, ch) sp.1) p (claimPoint p r.rho) (oneMinusProd r.es) (maskCoef r.es p.extRound) Fp2.zero).parts)
      ++ [V.lay.logupSumClaim.parts] := by
    have hfp := famProve_claims_parts (liftH G) (outcPf V (c, ch)) (outcDf V Dc (c, ch)) _ _ _ .h
      (fun s recs1 dr => (outcPrivsH_at s).map
        (PrivS.eval (Sym.eval (histOf (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 recs1) s dr)))
      8 [] 0 {} _ sps recs acc t4 hfam (fun i hi recs1 dr df _ hdf hdrLen hcan => by
        rw [Nat.zero_add] at hdf hdrLen ⊢
        exact (shdP_outcDefine_privs Rp wDigest bOutRow v i hi
          (histOf (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 recs1) dr df hdrLen hcan hdf
          (Sym.eval (histOf (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 recs1) i dr) rfl).2.1)
    dsimp only [claimsCm] at hfp
    rw [List.length_nil, List.map_nil, List.nil_append] at hfp
    simp only [Nat.zero_add] at hfp
    rw [List.map_append, List.map_singleton, hfp]
    exact congrArg (· ++ [V.lay.logupSumClaim.parts])
      (flatMap_map_pair_map (List.range 8) outcPrivsH_at _ _ _ (fun _ _ => rfl))
  have h := openAuditOk_of_symSpec Lq hLq key domain hdom (outcPf V) (outcDf V Dc) outcBga hd
    8 12 38 18 36 9 5 10 (mPre + 175) 23 15 outcMains outcExts outcDrawsF outcPrivsH outcGroupsH
    (some (16, 17, V.lay.logupSumClaim, outcSumPre)) (by rw [strictPairs_length])
    (fun s hsLt c' => sep_of_eq (outcSlotEndProg_eq tag Rp wDigest bOutRow v pre TA M TH Dc s c')
      (shdP_outcSlotEndProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c').1)
    (fun s hsLt c' => sqLE_of_eq (outcSlotEndProg_eq tag Rp wDigest bOutRow v pre TA M TH Dc s c')
      (shdP_outcSlotEndProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c').2)
    (fun s hsLt _ => by change outcDraws (rcVerdict (shdP_outcPub Rp wDigest) v) s ≤ 23; rw [shdP_outcDraws_eq_run]; interval_cases s <;> norm_num)
    (by omega) (by norm_num) rfl rfl (by rw [outcSpecH_ok.1]; rfl) outcSpecH_ok.2 G c (c, ch) _ hF
    hShape hdEq (fun sp hsp => by
      have hcm : sp.2.cm = .h := of_decide_eq_true (List.all_eq_true.mp outcPrivsH_all_h sp hsp)
      unfold rowLog; rw [hcm]; rfl)
    sps recs acc t4 hfam (fun u0 u1 sc pre' hso => by
      have he := Option.some.inj hso; simp only [Prod.mk.injEq] at he; obtain ⟨rfl, rfl, rfl, rfl⟩ := he
      exact ⟨rfl, rfl, hsumParts, outcSumPre_ok⟩)
    (acc.claims.h ++ [V.lay.logupSumClaim]) hPartsH
  change OpenAuditOk ⟨V.lay.hRows, V.lay.hSiteRows, some V.lay.hURows, V.lay.hProx, outcHGroups⟩ 12 10 10 _ G c _
  rw [hVlay, hhR, hhP, hhS, hhU]; exact h

private theorem shdP_outc_audit_B {Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v : ℕ)
    (pre : Coins → TProg (List Exec.Block.ZClaim)) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 1000 < 2 ^ 64)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp)
    (G : QB Lq → Dig) (c : Coins) (D : OutcData (shdVo tag Rp wDigest bOutRow v))
    (hA : D.aRoot = rootOf (liftH G) tag 14 (TA c))
    (hM : D.maskRoot = rootOf (liftH G) tag 12 (mTab 8 (cosetPt (rootFp 12)) (M c)))
    (hH : ∀ ch, D.hRoot ch = rootOf (liftH G) tag 14 (TH c ch))
    (hD : D.slot = Dc c)
    (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr)
    (hsl :
      let V := shdVo tag Rp wDigest bOutRow v
      let ch := (outcCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).1
      slotsProve (liftH G) V.bp D.slot (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 8 [] 0 {}
        (absorbRoot (liftH G) (outcCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).2 labH (D.hRoot ch) V.bp.hRows V.bp.logCols)
        = .ok (sps, recs, acc, t4)) :
    let t0 := Tr.newKeyed (liftH G) domain key
    let pend := ((pre c).final (liftH G) t0).2
    ∀ r0, ((r0 = 32 ∧ bOutRow = 34) ∨ (r0 = 34 ∧ bOutRow = 32)) → BndCarryOk r0 pend →
      OpenAuditOk shdP_bndOpenGeom 14 2 1
        (shdP_outcCollB Lq hLq key domain hdom tag Rp wDigest bOutRow v pre mPre hs hsq hmPre TA M TH Dc) G c
        (pend ++ acc.claims.inp) := by
  intro t0 pend r0 hpair hpend
  let V := shdVo tag Rp wDigest bOutRow v
  let tStart := ((pre c).final (liftH G) t0).1
  let ch := (outcCh (liftH G) V D tStart).1
  have hfam : famProve (liftH G) (outcPf V (c, ch)) (outcDf V Dc (c, ch)) (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2
      8 [] 0 {} (absorbRoot (liftH G) (outcCh (liftH G) V D tStart).2 labH (D.hRoot ch) V.bp.hRows V.bp.logCols)
      = .ok (sps, recs, acc, t4) := by
    rw [← slotsProve_eq_fam, ← hD]; exact hsl
  obtain ⟨hShape0M, hShape0E⟩ : (slotShape V.bp 0).1 = 12 ∧ (slotShape V.bp 0).2.1 = 1 := by
    rw [shdP_outcSlotShape_eq_run]; exact ⟨rfl, rfl⟩
  let p0Priv : Priv := ⟨.inp, [(0, Fp2.one)], 19, fixedBits Rp.row.val 7 ++ StageV.rhoC 0 12, bOutRow, 0⟩
  have hInpParts : acc.claims.inp.map Exec.Block.ZClaim.parts =
      [(buildClaim V.bp p0Priv (claimPoint p0Priv (recs.getD 0 rec0).rho)
          (oneMinusProd (recs.getD 0 rec0).es) (maskCoef (recs.getD 0 rec0).es 0) Fp2.zero).parts] := by
    have hfp := famProve_claims_parts (liftH G) (outcPf V (c, ch)) (outcDf V Dc (c, ch)) _ _ _ .inp
      (fun s _ _ => if s = 0 then [p0Priv] else [])
      8 [] 0 {} _ sps recs acc t4 hfam (fun i hi recs1 dr df _ hdf hdrLen hcan => by
        rw [Nat.zero_add] at hdf hdrLen ⊢
        exact (shdP_outcDefine_privs Rp wDigest bOutRow v i hi
          (histOf (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 recs1) dr df hdrLen hcan hdf
          (fun _ => Fp2.zero) rfl).2.2)
    dsimp only [claimsCm] at hfp
    rw [List.length_nil, List.map_nil, List.nil_append] at hfp
    simp only [Nat.zero_add] at hfp
    rw [hfp, show List.range 8 = 0 :: List.range' 1 7 from rfl, List.flatMap_cons,
      List.flatMap_eq_nil_iff.mpr (fun i hi => by
        have hne : i ≠ 0 := by have := List.mem_range'.mp hi; omega
        rw [ite_eq_right hne]; rfl),
      List.append_nil, ite_eq_left rfl, List.map_singleton]
  cases hinp : acc.claims.inp with
  | nil => have hl := congrArg List.length hInpParts; rw [hinp] at hl; simp only [List.length_map, List.length_nil, List.length_cons] at hl; omega
  | cons cl1 rest =>
    cases rest with
    | cons _ _ => have hl := congrArg List.length hInpParts; rw [hinp] at hl; simp only [List.length_map, List.length_nil, List.length_cons] at hl; omega
    | nil =>
      rw [hinp, List.map_singleton, List.singleton_inj] at hInpParts
      obtain ⟨_, _, hslot⟩ := famProve_split (liftH G) (outcPf V (c, ch)) (outcDf V Dc (c, ch)) _ _ _ 8 [] 0 {} _ sps recs acc t4 hfam
      obtain ⟨sps0, recs0, acc0, t0s, sp0, r0s, acc1, t1s, hfam0, -, hget0, hsp0⟩ := hslot 0 (by omega)
      simp only [Nat.zero_add, List.length_nil] at hget0 hsp0
      obtain ⟨df0, hdf0, -, hrho0, -, he0, he0L, -, -, -, -⟩ :=
        slotProve_ok_struct (liftH G) V.bp (Dc c) 0 _ acc0 t0s sp0 r0s acc1 t1s hsp0
      have he0L' : (recs.getD 0 rec0).es.length = 1 := by rw [hget0]; exact he0L.trans hShape0E
      have hptLen : (claimPoint p0Priv (recs.getD 0 rec0).rho).length = 19 := by
        unfold claimPoint p0Priv fixedBits StageV.rhoC
        simp only [List.length_map, List.length_append, List.length_range, List.length_range']
      let cl1' := buildClaim V.bp p0Priv (claimPoint p0Priv (recs.getD 0 rec0).rho)
        (oneMinusProd (recs.getD 0 rec0).es) (maskCoef (recs.getD 0 rec0).es 0) Fp2.zero
      have hsite : List.range' 32 (36 - 32) = [32, 33, 34, 35] := rfl
      have hsurv1 := buildClaim_survivingAuditClaim V.bp p0Priv (claimPoint p0Priv (recs.getD 0 rec0).rho)
        (recs.getD 0 rec0).es Fp2.zero 32 36 2 1 none (by change 0 < 14; omega) (by change 0 < 19; omega) hptLen
        (fun sc hsc => by rw [List.mem_singleton.mp hsc]; change 0 / 2 ^ 14 + (2 ^ 19 + 2 ^ 14 - 1) / 2 ^ 14 ≤ 32; norm_num)
        (by change 32 ≤ bOutRow; rcases hpair with ⟨-, h⟩ | ⟨-, h⟩ <;> omega)
        (by change bOutRow + 2 ≤ 36; rcases hpair with ⟨-, h⟩ | ⟨-, h⟩ <;> omega)
        (by change (bOutRow - 32) % 2 = 0; rcases hpair with ⟨-, h⟩ | ⟨-, h⟩ <;> omega)
        (fun e he => by rw [hget0] at he; exact (he0 e he).1)
        (fun e he => by rw [hget0] at he; exact (he0 e he).2) (by change 0 < (recs.getD 0 rec0).es.length; omega)
      have hunif1 := buildClaim_parts_uniform V.bp p0Priv (claimPoint p0Priv (recs.getD 0 rec0).rho)
        (recs.getD 0 rec0).es Fp2.zero (by change 0 < 14; omega) (by intro h; cases h) (by change 0 < 19; omega) hptLen
        (fun _ _ hlt => by change 19 < 14 at hlt; omega)
      have hrl1 : rowLog V.bp p0Priv.cm = 14 := rfl
      rw [hrl1, hsite] at hsurv1; rw [hrl1] at hunif1
      refine bnd_openAuditOk_of_pair r0 bOutRow hpair pend hpend cl1
        (by rw [hInpParts]; exact hsurv1.1)
        (by have hsu1 := hsurv1.2; unfold SurvivingAuditClaim claimWeight at hsu1 ⊢; rw [hInpParts]; exact hsu1)
        (fun q hq => by unfold claimKey; rw [hInpParts] at hq ⊢; exact hunif1.2 q hq)
        _ G c (fun hcoll => ?_)
      dsimp only [shdP_outcCollB, mkBndCollFamily]; rw [zkeyCollisionStartSite_fires]; dsimp only
      have hpre0 : (outcSlotEndProg tag Rp wDigest bOutRow v (fun _ : Coins => TProg.done ()) TA M TH Dc 0 c).final (liftH G) tStart
          = (t0s, ((c, ch), recs0, acc0)) := by
        have hhd0 : (outcHeadProg V c (TProg.done ()) (rootOfP tag 14 (TA c))
            (rootOfP tag 12 (mTab 8 (cosetPt (rootFp 12)) (M c))) (fun ch' => rootOfP tag 14 (TH c ch'))).final (liftH G) tStart
            = (absorbRoot (liftH G) (outcCh (liftH G) V D tStart).2 labH (D.hRoot ch) V.bp.hRows V.bp.logCols, (c, ch)) := by
          rw [final_outcHeadProg, final_done_fst, hH]; unfold ch outcCh; rw [hA, hM]
        rw [outcSlotEndProg, final_famPre (liftH G) (outcPf V) (outcDf V Dc) outcBga _ 0 _ sps0 recs0 acc0 t0s
          (by rw [hhd0]; exact hfam0), hhd0]
      have hch0 := final_depRoundDrProg_chal (liftH G) (outcPf V) (outcDf V Dc) outcBga
        (outcSlotEndProg tag Rp wDigest bOutRow v (fun _ : Coins => TProg.done ()) TA M TH Dc 0 c) 0 11
        tStart t0s (c, ch) recs0 acc0 hpre0 df0 hdf0 (by change 11 < (slotShape V.bp 0).1; rw [hShape0M]; norm_num)
      rw [final_bindP, final_bindP, final_done_fst, final_done_snd]
      rw [hch0.2, ← hrho0, ← hget0]
      have h13 : (claimKey 14 cl1).1.getD 13 Fp2.zero = (recs.getD 0 rec0).rho.getD 11 Fp2.zero := by
        have hk1 : claimKey 14 cl1 = claimKey 14 cl1' := by unfold claimKey; rw [hInpParts]
        rw [hk1, hunif1.1]; unfold claimPoint p0Priv
        rw [List.map_append, List.getD_eq_getElem?_getD, List.getElem?_drop, show 19 - 14 + 13 = 7 + 11 by omega]
        have hfbLen : (fixedBits Rp.row.val 7).length = 7 := by
          unfold fixedBits; rw [List.length_map, List.length_range]
        rw [List.getElem?_append_right (by rw [List.length_map, hfbLen]; omega), List.length_map, hfbLen, Nat.add_sub_cancel_left]
        simp only [StageV.rhoC, List.getElem?_map, List.getElem?_range' (by omega : 11 < 12 - 0)]; rfl
      exact congrArg (Fp2.toK shdP_U) (h13.symm.trans (congrArg (fun k => k.1.getD 13 Fp2.zero) hcoll.symm))

/-- **Stage OUT-C `A`, `H`, `B_26` `OpenAuditOk` discharge**. -/
theorem shdP_outc_audit {Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v : ℕ)
    (pre : Coins → TProg (List Exec.Block.ZClaim)) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 1000 < 2 ^ 64)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp)
    (G : QB Lq → Dig) (c : Coins) (D : OutcData (shdVo tag Rp wDigest bOutRow v))
    (hA : D.aRoot = rootOf (liftH G) tag 14 (TA c))
    (hM : D.maskRoot = rootOf (liftH G) tag 12 (mTab 8 (cosetPt (rootFp 12)) (M c)))
    (hH : ∀ ch, D.hRoot ch = rootOf (liftH G) tag 14 (TH c ch))
    (hD : D.slot = Dc c)
    (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr)
    (hsl :
      let V := shdVo tag Rp wDigest bOutRow v
      let ch := (outcCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).1
      slotsProve (liftH G) V.bp D.slot (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 8 [] 0 {}
        (absorbRoot (liftH G) (outcCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).2 labH (D.hRoot ch) V.bp.hRows V.bp.logCols)
        = .ok (sps, recs, acc, t4)) :
    let V := shdVo tag Rp wDigest bOutRow v
    let t0 := Tr.newKeyed (liftH G) domain key
    let pend := ((pre c).final (liftH G) t0).2
    OpenAuditOk ⟨V.lay.aRows, V.lay.aSiteRows, none, V.lay.aProx, outcAGroups⟩ 12 29 120
        (shdP_outcCollA Lq hLq key domain hdom tag Rp wDigest bOutRow v pre mPre hs hsq hmPre TA M TH Dc) G c acc.claims.a
      ∧ OpenAuditOk ⟨V.lay.hRows, V.lay.hSiteRows, some V.lay.hURows, V.lay.hProx, outcHGroups⟩ 12 10 10
          (shdP_outcCollH Lq hLq key domain hdom tag Rp wDigest bOutRow v pre mPre hs hsq hmPre TA M TH Dc) G c
          (acc.claims.h ++ [V.lay.logupSumClaim])
      ∧ (∀ r0, ((r0 = 32 ∧ bOutRow = 34) ∨ (r0 = 34 ∧ bOutRow = 32)) → BndCarryOk r0 pend →
          OpenAuditOk shdP_bndOpenGeom 14 2 1
            (shdP_outcCollB Lq hLq key domain hdom tag Rp wDigest bOutRow v pre mPre hs hsq hmPre TA M TH Dc) G c
            (pend ++ acc.claims.inp)) :=
  ⟨shdP_outc_audit_A Lq hLq key domain hdom tag Rp wDigest bOutRow v pre mPre hs hsq hmPre TA M TH Dc G c D hA hM hH hD sps recs acc t4 hsl,
   shdP_outc_audit_H Lq hLq key domain hdom tag Rp wDigest bOutRow v pre mPre hs hsq hmPre TA M TH Dc G c D hA hM hH hD sps recs acc t4 hsl,
   shdP_outc_audit_B Lq hLq key domain hdom tag Rp wDigest bOutRow v pre mPre hs hsq hmPre TA M TH Dc G c D hA hM hH hD sps recs acc t4 hsl⟩

end StageOutAudit

/-! ## 3. Whole-Run `shdP_SiteIdx` Packing, `shdP_runSite`, `shdP_refuse_hk`, and `shdP_refuse_hδ` -/

section RunSitePacking

universe u

/-- Pack `1` Stage IN-C + `26` R13 Blocks + `1` Stage OUT-C into `shdP_SiteIdx` via `div`/`mod`
(zero 26-way unrolling in `whnf`). -/
def packRunSite {A : Type u} (dflt : A)
    (sIn : SiteIdx incSegCount → A)
    (sBlk : (k : ℕ) → k < 26 → SiteIdx blkSegCount → A)
    (sOut : SiteIdx outcSegCount → A) : shdP_SiteIdx → A
  | ⟨j, idx⟩ =>
    if h1 : idx.val < incSegCount j then
      sIn ⟨j, ⟨idx.val, h1⟩⟩
    else if h2 : idx.val < incSegCount j + 26 * blkSegCount j then
      have hpos : 0 < blkSegCount j := Nat.pos_of_mul_pos_left (by omega : 0 < 26 * blkSegCount j)
      have hk : (idx.val - incSegCount j) / blkSegCount j < 26 :=
        Nat.div_lt_of_lt_mul (by rw [Nat.mul_comm]; omega)
      have hm : (idx.val - incSegCount j) % blkSegCount j < blkSegCount j := Nat.mod_lt _ hpos
      sBlk ((idx.val - incSegCount j) / blkSegCount j) hk ⟨j, ⟨(idx.val - incSegCount j) % blkSegCount j, hm⟩⟩
    else if h3 : idx.val < shdP_runUsedCount j then
      sOut ⟨j, ⟨idx.val - (incSegCount j + 26 * blkSegCount j), by unfold shdP_runUsedCount at h3; omega⟩⟩
    else dflt

theorem packRunSite_inc {A : Type u} (dflt : A) (sIn : SiteIdx incSegCount → A)
    (sBlk : (k : ℕ) → k < 26 → SiteIdx blkSegCount → A) (sOut : SiteIdx outcSegCount → A)
    (i : SiteIdx incSegCount) :
    ∃ i' : shdP_SiteIdx, packRunSite dflt sIn sBlk sOut i' = sIn i := by
  have hle := shdP_runUsedCount_le i.1; unfold shdP_runUsedCount at hle
  refine ⟨⟨i.1, ⟨i.2.val, by have := i.2.isLt; omega⟩⟩, ?_⟩
  dsimp only [packRunSite]; rw [dite_eq_left i.2.isLt]

theorem packRunSite_blk {A : Type u} (dflt : A) (sIn : SiteIdx incSegCount → A)
    (sBlk : (k : ℕ) → k < 26 → SiteIdx blkSegCount → A) (sOut : SiteIdx outcSegCount → A)
    (k : ℕ) (hk : k < 26) (i : SiteIdx blkSegCount) :
    ∃ i' : shdP_SiteIdx, packRunSite dflt sIn sBlk sOut i' = sBlk k hk i := by
  have hbp : 0 < blkSegCount i.1 := by have := i.2.isLt; omega
  have hmul : (k + 1) * blkSegCount i.1 ≤ 26 * blkSegCount i.1 := Nat.mul_le_mul_right _ hk
  have hblkLt : blkSegCount i.1 * k + i.2.val < 26 * blkSegCount i.1 := by have := i.2.isLt; nlinarith
  have hle := shdP_runUsedCount_le i.1; unfold shdP_runUsedCount at hle
  let pos := incSegCount i.1 + (blkSegCount i.1 * k + i.2.val)
  refine ⟨⟨i.1, ⟨pos, by omega⟩⟩, ?_⟩
  dsimp only [packRunSite]
  rw [dite_eq_right (by omega : ¬ pos < incSegCount i.1),
    dite_eq_left (by omega : pos < incSegCount i.1 + 26 * blkSegCount i.1)]
  have hsub : pos - incSegCount i.1 = blkSegCount i.1 * k + i.2.val := Nat.add_sub_cancel_left _ _
  have hdiv : (pos - incSegCount i.1) / blkSegCount i.1 = k := by
    rw [hsub, Nat.mul_add_div hbp, Nat.div_eq_of_lt i.2.isLt, Nat.add_zero]
  have hmod : (pos - incSegCount i.1) % blkSegCount i.1 = i.2.val := by
    rw [hsub, Nat.mul_add_mod, Nat.mod_eq_of_lt i.2.isLt]
  have hEq : ∀ (k₁ k₂ : ℕ) (hk₁ : k₁ < 26) (hk₂ : k₂ < 26) (m₁ m₂ : ℕ)
      (hm₁ : m₁ < blkSegCount i.1) (hm₂ : m₂ < blkSegCount i.1),
      k₁ = k₂ → m₁ = m₂ → sBlk k₁ hk₁ ⟨i.1, ⟨m₁, hm₁⟩⟩ = sBlk k₂ hk₂ ⟨i.1, ⟨m₂, hm₂⟩⟩ := by
    rintro _ _ _ _ _ _ _ _ rfl rfl; rfl
  exact hEq _ k _ hk _ i.2.val _ i.2.isLt hdiv hmod

theorem packRunSite_outc {A : Type u} (dflt : A) (sIn : SiteIdx incSegCount → A)
    (sBlk : (k : ℕ) → k < 26 → SiteIdx blkSegCount → A) (sOut : SiteIdx outcSegCount → A)
    (i : SiteIdx outcSegCount) :
    ∃ i' : shdP_SiteIdx, packRunSite dflt sIn sBlk sOut i' = sOut i := by
  have hle := shdP_runUsedCount_le i.1
  let pos := incSegCount i.1 + 26 * blkSegCount i.1 + i.2.val
  have hused : pos < shdP_runUsedCount i.1 := by unfold shdP_runUsedCount; have := i.2.isLt; omega
  refine ⟨⟨i.1, ⟨pos, lt_of_lt_of_le hused hle⟩⟩, ?_⟩
  dsimp only [packRunSite]
  rw [dite_eq_right (by omega : ¬ pos < incSegCount i.1),
    dite_eq_right (by omega : ¬ pos < incSegCount i.1 + 26 * blkSegCount i.1),
    dite_eq_left hused]
  have hEq : ∀ (m₁ m₂ : ℕ) (hm₁ : m₁ < outcSegCount i.1) (hm₂ : m₂ < outcSegCount i.1),
      m₁ = m₂ → sOut ⟨i.1, ⟨m₁, hm₁⟩⟩ = sOut ⟨i.1, ⟨m₂, hm₂⟩⟩ := by
    rintro _ _ _ _ rfl; rfl
  exact hEq _ i.2.val _ i.2.isLt (Nat.add_sub_cancel_left _ _)

theorem packRunSite_prop {A : Type u} (dflt : A) (sIn : SiteIdx incSegCount → A)
    (sBlk : (k : ℕ) → k < 26 → SiteIdx blkSegCount → A) (sOut : SiteIdx outcSegCount → A)
    (P : Fin 7 → A → Prop)
    (hd : ∀ j, P j dflt) (hi : ∀ i, P i.1 (sIn i))
    (hb : ∀ k (hk : k < 26) i, P i.1 (sBlk k hk i)) (ho : ∀ i, P i.1 (sOut i))
    (idx : shdP_SiteIdx) : P idx.1 (packRunSite dflt sIn sBlk sOut idx) := by
  rcases idx with ⟨j, m⟩
  dsimp only [packRunSite]
  by_cases h1 : m.val < incSegCount j
  · rw [dite_eq_left h1]; exact hi ⟨j, ⟨m.val, h1⟩⟩
  · rw [dite_eq_right h1]
    by_cases h2 : m.val < incSegCount j + 26 * blkSegCount j
    · rw [dite_eq_left h2]; exact hb _ _ ⟨j, _⟩
    · rw [dite_eq_right h2]
      by_cases h3 : m.val < shdP_runUsedCount j
      · rw [dite_eq_left h3]; exact ho ⟨j, _⟩
      · rw [dite_eq_right h3]; exact hd j

private theorem shdP_runDomain_ne_35 : shdP_runDomain.length ≠ 35 := by decide

private noncomputable def shdP_hdrProgF {Hdr Coins : Type} (tag : MTag) (hw : Hdr → ClsHdrW) (hdr : Hdr) (verdict : ℕ)
    (x : shieldS0.Tok → ℕ) (epBase : Coins → EpxSalt 6) (c : Coins) : TProg Unit :=
  shdP_hdrProg tag hw hdr verdict x (epBase c)

private theorem shdP_hdrProg_sep_sq {Hdr Coins : Type} (tag : MTag) (hw : Hdr → ClsHdrW) (hdr : Hdr) (verdict : ℕ)
    (x : shieldS0.Tok → ℕ) (epBase : Coins → EpxSalt 6) (key : Option Dig) :
    ∀ c, TProg.Sep key (shdP_hdrProgF tag hw hdr verdict x epBase c)
      ∧ SqLE 0 (shdP_hdrProgF tag hw hdr verdict x epBase c) := by
  intro c
  unfold shdP_hdrProgF
  exact ⟨@sep_shdP_hdrProg Hdr tag hw hdr verdict x (epBase c) key,
    @sqLE_shdP_hdrProg Hdr tag hw hdr verdict x (epBase c)⟩

private theorem shdP_runPreBlk_sep_sq_all {Hdr Coins : Type} (tag : MTag) (key : Option Dig)
    (hw : Hdr → ClsHdrW) (hdr : Hdr) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (Wx : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x) :
    ∀ k, k ≤ 26 → ∀ c,
      TProg.Sep key (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x Wx k c)
        ∧ SqLE (515 + k * 10359) (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x Wx k c) :=
  fun k hk c =>
    ⟨@shdP_runPreBlk_sep Hdr Coins tag key hw hdr Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x Wx k c,
     @shdP_runPreBlk_sqLE Hdr Coins tag hw hdr Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x Wx k hk c⟩

private noncomputable def shdP_runSite_aux {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (hV : Rp.inp.V = 131072)
    (ioIn ioOut : ℕ) (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (Wx : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (preHdr : Coins → TProg Unit)
    (hHdr : ∀ c, TProg.Sep key (preHdr c) ∧ SqLE 0 (preHdr c))
    (preBlk : ℕ → Coins → TProg (List Exec.Block.ZClaim))
    (hBlk : ∀ k, k ≤ 26 → ∀ c, TProg.Sep key (preBlk k c) ∧ SqLE (515 + k * 10359) (preBlk k c)) :
    shdP_SiteIdx → ProtocolClassify.Site (QB Lq) Coins shdP_K :=
  let hLq : 47 ≤ Lq := by omega
  let v := (classifySpecP Rp x).getD 0
  packRunSite (shdP_emptySite Lq)
    (incSegSite Lq hLq key shdP_runDomain shdP_runDomain_ne_35 tag Rp hV embDigest bInRow
      preHdr 0 (fun c => (hHdr c).1) (fun c => (hHdr c).2) (by norm_num) (Wx.TB 0) Wx.incTA Wx.incM Wx.incTH Wx.hrIncA Wx.hrIncH Wx.incSlot
      (shdP_incCollA Lq hLq key shdP_runDomain shdP_runDomain_ne_35 tag Rp embDigest bInRow
        preHdr 0 (fun c => (hHdr c).1) (fun c => (hHdr c).2) (by norm_num) (Wx.TB 0) Wx.incTA Wx.incM Wx.incTH Wx.incSlot)
      (shdP_incCollH Lq hLq key shdP_runDomain shdP_runDomain_ne_35 tag Rp embDigest bInRow
        preHdr 0 (fun c => (hHdr c).1) (fun c => (hHdr c).2) (by norm_num) (Wx.TB 0) Wx.incTA Wx.incM Wx.incTH Wx.incSlot))
    (fun k hk =>
      blkSegSite Lq hLq key shdP_runDomain shdP_runDomain_ne_35 tag ioIn ioOut checkOpening Rp hR k hk (blkDig k)
        (preBlk k) (515 + k * 10359) (fun c => (hBlk k (by omega) c).1) (fun c => (hBlk k (by omega) c).2) (by omega)
        (Wx.TB (k + 1)) (Wx.blkTA k) (Wx.blkM k) (Wx.blkTH k) (Wx.hrBlkA k hk) (Wx.hrBlkH k hk) (Wx.blkSlot k)
        (shdP_blkCollA Lq hLq key shdP_runDomain shdP_runDomain_ne_35 tag ioIn ioOut checkOpening Rp hR k hk (blkDig k)
          (preBlk k) (515 + k * 10359) (fun c => (hBlk k (by omega) c).1) (fun c => (hBlk k (by omega) c).2) (by omega)
          (Wx.TB (k + 1)) (Wx.blkTA k) (Wx.blkM k) (Wx.blkTH k) (Wx.blkSlot k))
        (shdP_blkCollH Lq hLq key shdP_runDomain shdP_runDomain_ne_35 tag ioIn ioOut checkOpening Rp hR k hk (blkDig k)
          (preBlk k) (515 + k * 10359) (fun c => (hBlk k (by omega) c).1) (fun c => (hBlk k (by omega) c).2) (by omega)
          (Wx.TB (k + 1)) (Wx.blkTA k) (Wx.blkM k) (Wx.blkTH k) (Wx.blkSlot k))
        (shdP_blkCollB Lq hLq key shdP_runDomain shdP_runDomain_ne_35 tag ioIn ioOut checkOpening Rp hR k hk (blkDig k)
          (preBlk k) (515 + k * 10359) (fun c => (hBlk k (by omega) c).1) (fun c => (hBlk k (by omega) c).2) (by omega)
          (Wx.TB (k + 1)) (Wx.blkTA k) (Wx.blkM k) (Wx.blkTH k) (Wx.blkSlot k)))
    (outcSegSite Lq hLq key shdP_runDomain shdP_runDomain_ne_35 tag Rp wDigest bOutRow v
      (preBlk 26) (515 + 26 * 10359) (fun c => (hBlk 26 le_rfl c).1) (fun c => (hBlk 26 le_rfl c).2) (by norm_num)
      Wx.outcTA Wx.outcM Wx.outcTH Wx.hrOutcA Wx.hrOutcH Wx.outcSlot
      (shdP_outcCollA Lq hLq key shdP_runDomain shdP_runDomain_ne_35 tag Rp wDigest bOutRow v
        (preBlk 26) (515 + 26 * 10359) (fun c => (hBlk 26 le_rfl c).1) (fun c => (hBlk 26 le_rfl c).2) (by norm_num) Wx.outcTA Wx.outcM Wx.outcTH Wx.outcSlot)
      (shdP_outcCollH Lq hLq key shdP_runDomain shdP_runDomain_ne_35 tag Rp wDigest bOutRow v
        (preBlk 26) (515 + 26 * 10359) (fun c => (hBlk 26 le_rfl c).1) (fun c => (hBlk 26 le_rfl c).2) (by norm_num) Wx.outcTA Wx.outcM Wx.outcTH Wx.outcSlot)
      (shdP_outcCollB Lq hLq key shdP_runDomain shdP_runDomain_ne_35 tag Rp wDigest bOutRow v
        (preBlk 26) (515 + 26 * 10359) (fun c => (hBlk 26 le_rfl c).1) (fun c => (hBlk 26 le_rfl c).2) (by norm_num) Wx.outcTA Wx.outcM Wx.outcTH Wx.outcSlot))

private theorem shdP_runSite_aux_k_delta {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (hV : Rp.inp.V = 131072)
    (ioIn ioOut : ℕ) (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (Wx : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (preHdr : Coins → TProg Unit)
    (hHdr : ∀ c, TProg.Sep key (preHdr c) ∧ SqLE 0 (preHdr c))
    (preBlk : ℕ → Coins → TProg (List Exec.Block.ZClaim))
    (hBlk : ∀ k, k ≤ 26 → ∀ c, TProg.Sep key (preBlk k c) ∧ SqLE (515 + k * 10359) (preBlk k c)) (i : shdP_SiteIdx) :
    (shdP_runSite_aux tag Lq hL20 key Rp hR hV ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow blkDig epBase x Wx
        preHdr hHdr preBlk hBlk i).k ≤ shdP_kOf i
      ∧ (shdP_runSite_aux tag Lq hL20 key Rp hR hV ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow blkDig epBase x Wx
        preHdr hHdr preBlk hBlk i).δ = 0 := by
  unfold shdP_runSite_aux
  exact packRunSite_prop _ _ _ _
    (fun j (s : ProtocolClassify.Site (QB Lq) Coins shdP_K) => s.k ≤ kPer gP (2 ^ 17) (2 ^ 20) j ∧ s.δ = 0)
    (fun _ => ⟨Nat.zero_le _, rfl⟩)
    (fun i' => incSegSite_k_delta _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ i')
    (fun k hk i' => blkSegSite_k_delta _ _ _ _ _ _ _ _ _ _ _ k hk _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ i')
    (fun i' => outcSegSite_k_delta _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ i') i

private theorem shdP_runSite_aux_inc {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (hV : Rp.inp.V = 131072)
    (ioIn ioOut : ℕ) (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (Wx : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (preHdr : Coins → TProg Unit)
    (hHdr : ∀ c, TProg.Sep key (preHdr c) ∧ SqLE 0 (preHdr c))
    (preBlk : ℕ → Coins → TProg (List Exec.Block.ZClaim))
    (hBlk : ∀ k, k ≤ 26 → ∀ c, TProg.Sep key (preBlk k c) ∧ SqLE (515 + k * 10359) (preBlk k c))
    (i0 : SiteIdx incSegCount) :
    ∃ i' : shdP_SiteIdx,
      shdP_runSite_aux tag Lq hL20 key Rp hR hV ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow blkDig epBase x Wx
        preHdr hHdr preBlk hBlk i'
      = incSegSite Lq (by omega) key shdP_runDomain shdP_runDomain_ne_35 tag Rp hV embDigest bInRow
          preHdr 0 (fun c => (hHdr c).1) (fun c => (hHdr c).2) (by norm_num) (Wx.TB 0) Wx.incTA Wx.incM Wx.incTH Wx.hrIncA Wx.hrIncH Wx.incSlot
          (shdP_incCollA Lq (by omega) key shdP_runDomain shdP_runDomain_ne_35 tag Rp embDigest bInRow
            preHdr 0 (fun c => (hHdr c).1) (fun c => (hHdr c).2) (by norm_num) (Wx.TB 0) Wx.incTA Wx.incM Wx.incTH Wx.incSlot)
          (shdP_incCollH Lq (by omega) key shdP_runDomain shdP_runDomain_ne_35 tag Rp embDigest bInRow
            preHdr 0 (fun c => (hHdr c).1) (fun c => (hHdr c).2) (by norm_num) (Wx.TB 0) Wx.incTA Wx.incM Wx.incTH Wx.incSlot) i0 := by
  unfold shdP_runSite_aux
  exact packRunSite_inc _ _ _ _ i0

private theorem shdP_runSite_aux_blk {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (hV : Rp.inp.V = 131072)
    (ioIn ioOut : ℕ) (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (Wx : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (preHdr : Coins → TProg Unit)
    (hHdr : ∀ c, TProg.Sep key (preHdr c) ∧ SqLE 0 (preHdr c))
    (preBlk : ℕ → Coins → TProg (List Exec.Block.ZClaim))
    (hBlk : ∀ k, k ≤ 26 → ∀ c, TProg.Sep key (preBlk k c) ∧ SqLE (515 + k * 10359) (preBlk k c))
    (k : ℕ) (hk : k < 26) (i0 : SiteIdx blkSegCount) :
    ∃ i' : shdP_SiteIdx,
      shdP_runSite_aux tag Lq hL20 key Rp hR hV ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow blkDig epBase x Wx
        preHdr hHdr preBlk hBlk i'
      = blkSegSite Lq (by omega) key shdP_runDomain shdP_runDomain_ne_35 tag ioIn ioOut checkOpening Rp hR k hk (blkDig k)
          (preBlk k) (515 + k * 10359) (fun c => (hBlk k (by omega) c).1) (fun c => (hBlk k (by omega) c).2) (by omega)
          (Wx.TB (k + 1)) (Wx.blkTA k) (Wx.blkM k) (Wx.blkTH k) (Wx.hrBlkA k hk) (Wx.hrBlkH k hk) (Wx.blkSlot k)
          (shdP_blkCollA Lq (by omega) key shdP_runDomain shdP_runDomain_ne_35 tag ioIn ioOut checkOpening Rp hR k hk (blkDig k)
            (preBlk k) (515 + k * 10359) (fun c => (hBlk k (by omega) c).1) (fun c => (hBlk k (by omega) c).2) (by omega)
            (Wx.TB (k + 1)) (Wx.blkTA k) (Wx.blkM k) (Wx.blkTH k) (Wx.blkSlot k))
          (shdP_blkCollH Lq (by omega) key shdP_runDomain shdP_runDomain_ne_35 tag ioIn ioOut checkOpening Rp hR k hk (blkDig k)
            (preBlk k) (515 + k * 10359) (fun c => (hBlk k (by omega) c).1) (fun c => (hBlk k (by omega) c).2) (by omega)
            (Wx.TB (k + 1)) (Wx.blkTA k) (Wx.blkM k) (Wx.blkTH k) (Wx.blkSlot k))
          (shdP_blkCollB Lq (by omega) key shdP_runDomain shdP_runDomain_ne_35 tag ioIn ioOut checkOpening Rp hR k hk (blkDig k)
            (preBlk k) (515 + k * 10359) (fun c => (hBlk k (by omega) c).1) (fun c => (hBlk k (by omega) c).2) (by omega)
            (Wx.TB (k + 1)) (Wx.blkTA k) (Wx.blkM k) (Wx.blkTH k) (Wx.blkSlot k)) i0 := by
  unfold shdP_runSite_aux
  exact packRunSite_blk _ _ _ _ k hk i0

private theorem shdP_runSite_aux_outc {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (hV : Rp.inp.V = 131072)
    (ioIn ioOut : ℕ) (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (Wx : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (preHdr : Coins → TProg Unit)
    (hHdr : ∀ c, TProg.Sep key (preHdr c) ∧ SqLE 0 (preHdr c))
    (preBlk : ℕ → Coins → TProg (List Exec.Block.ZClaim))
    (hBlk : ∀ k, k ≤ 26 → ∀ c, TProg.Sep key (preBlk k c) ∧ SqLE (515 + k * 10359) (preBlk k c))
    (i0 : SiteIdx outcSegCount) :
    ∃ i' : shdP_SiteIdx,
      shdP_runSite_aux tag Lq hL20 key Rp hR hV ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow blkDig epBase x Wx
        preHdr hHdr preBlk hBlk i'
      = outcSegSite Lq (by omega) key shdP_runDomain shdP_runDomain_ne_35 tag Rp wDigest bOutRow ((classifySpecP Rp x).getD 0)
          (preBlk 26) (515 + 26 * 10359) (fun c => (hBlk 26 le_rfl c).1) (fun c => (hBlk 26 le_rfl c).2) (by norm_num)
          Wx.outcTA Wx.outcM Wx.outcTH Wx.hrOutcA Wx.hrOutcH Wx.outcSlot
          (shdP_outcCollA Lq (by omega) key shdP_runDomain shdP_runDomain_ne_35 tag Rp wDigest bOutRow ((classifySpecP Rp x).getD 0)
            (preBlk 26) (515 + 26 * 10359) (fun c => (hBlk 26 le_rfl c).1) (fun c => (hBlk 26 le_rfl c).2) (by norm_num) Wx.outcTA Wx.outcM Wx.outcTH Wx.outcSlot)
          (shdP_outcCollH Lq (by omega) key shdP_runDomain shdP_runDomain_ne_35 tag Rp wDigest bOutRow ((classifySpecP Rp x).getD 0)
            (preBlk 26) (515 + 26 * 10359) (fun c => (hBlk 26 le_rfl c).1) (fun c => (hBlk 26 le_rfl c).2) (by norm_num) Wx.outcTA Wx.outcM Wx.outcTH Wx.outcSlot)
          (shdP_outcCollB Lq (by omega) key shdP_runDomain shdP_runDomain_ne_35 tag Rp wDigest bOutRow ((classifySpecP Rp x).getD 0)
            (preBlk 26) (515 + 26 * 10359) (fun c => (hBlk 26 le_rfl c).1) (fun c => (hBlk 26 le_rfl c).2) (by norm_num) Wx.outcTA Wx.outcM Wx.outcTH Wx.outcSlot) i0 := by
  unfold shdP_runSite_aux
  exact packRunSite_outc _ _ _ _ i0

private theorem carry_mk_root (p : List Exec.Block.ZClaim) (r : Dig) : (Carry.mk p r).root = r := rfl

private theorem incDataAt_bRoot {V : IncV} (H : HIn → Dig) (tag : MTag) (lr elr q eq : ℕ) (C : IncTables V) (t : Tr) :
    (incDataAt H tag shdP_U shdP_hbij V lr elr q eq C t).bRoot = C.bRoot := rfl

private theorem incDataAt_aRoot {V : IncV} (H : HIn → Dig) (tag : MTag) (lr elr q eq : ℕ) (C : IncTables V) (t : Tr) :
    (incDataAt H tag shdP_U shdP_hbij V lr elr q eq C t).aRoot = rootOf H tag (V.pub.lt + lr) C.TA := rfl

private theorem incDataAt_maskRoot {V : IncV} (H : HIn → Dig) (tag : MTag) (lr elr q eq : ℕ) (C : IncTables V) (t : Tr) :
    (incDataAt H tag shdP_U shdP_hbij V lr elr q eq C t).maskRoot = rootOf H tag 12 (mTab 4 (cosetPt (rootFp 12)) C.M) := rfl

private theorem incDataAt_hRoot {V : IncV} (H : HIn → Dig) (tag : MTag) (lr elr q eq : ℕ) (C : IncTables V) (t : Tr) (ch : List Fp2) :
    (incDataAt H tag shdP_U shdP_hbij V lr elr q eq C t).hRoot ch = rootOf H tag (V.pub.lt + lr) (C.TH ch) := rfl

private theorem incDataAt_mOpen {V : IncV} (H : HIn → Dig) (tag : MTag) (lr elr q eq : ℕ) (C : IncTables V) (t : Tr) :
    (incDataAt H tag shdP_U shdP_hbij V lr elr q eq C t).mOpen = bMask H tag shdP_U shdP_hbij C.M 4 := rfl

private theorem incDataAt_aOpen {V : IncV} (H : HIn → Dig) (tag : MTag) (lr elr q eq : ℕ) (C : IncTables V) (t : Tr) :
    (incDataAt H tag shdP_U shdP_hbij V lr elr q eq C t).aOpen = bOpen H tag ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) C.TA := rfl

private theorem incDataAt_hOpen {V : IncV} (H : HIn → Dig) (tag : MTag) (lr elr q eq : ℕ) (C : IncTables V) (t : Tr) :
    (incDataAt H tag shdP_U shdP_hbij V lr elr q eq C t).hOpen
      = bOpen H tag ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr)
          (C.TH (incCh H V (incDataAt H tag shdP_U shdP_hbij V lr elr q eq C t) t).1) :=
  congrArg (fun ch => bOpen H tag ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) (C.TH ch))
    (incChOf_data H tag shdP_U shdP_hbij V lr elr q eq C t)

private theorem incDataAt_epOpen {V : IncV} (H : HIn → Dig) (tag : MTag) (lr elr q eq : ℕ) (C : IncTables V) (t : Tr) :
    (incDataAt H tag shdP_U shdP_hbij V lr elr q eq C t).epOpen
      = bOpen H tag ⟨V.pub.epLogN, 2 ^ elr, eq, eq⟩ (V.pub.epLogN + elr) C.TE := rfl

private theorem shdRunWitness_incDataAt_fields {Hdr Coins : Type} {tag : MTag} {Rp : ClassifyRunPublicP shieldS0}
    {embDigest : Dig} {bInRow : ℕ} {wDigest : Dig} {bOutRow ioIn ioOut : ℕ}
    {checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit}
    {epBase : Coins → EpxSalt 6} {x : shieldS0.Tok → ℕ}
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (H : HIn → Dig) (c : Coins) (t : Tr) :
    let V := shdVi tag Rp embDigest bInRow
    let D := incDataAt H tag shdP_U shdP_hbij V 2 3 256 256 (W.incTables H c) t
    D.bRoot = rootOf H tag 16 (W.TB 0 c)
      ∧ D.aRoot = rootOf H tag 14 (W.incTA c)
      ∧ D.maskRoot = rootOf H tag 12 (mTab 4 (cosetPt (rootFp 12)) (W.incM c))
      ∧ (∀ ch, D.hRoot ch = rootOf H tag 14 (W.incTH c ch))
      ∧ D.slot = W.incSlot c
      ∧ D.mOpen = bMask H tag shdP_U shdP_hbij (W.incM c) 4
      ∧ D.aOpen = bOpen H tag ⟨12, 4, 256, 256⟩ 14 (W.incTA c)
      ∧ D.hOpen = bOpen H tag ⟨12, 4, 256, 256⟩ 14 (W.incTH c (incCh H V D t).1)
      ∧ D.epOpen = bOpen H tag ⟨8, 8, 256, 256⟩ 11 (shdP_epTable (Hdr := Hdr) tag x (epBase c)) := by
  intro V D
  have hlt : V.pub.lt + 2 = 14 := rfl
  have hprm : (⟨V.pub.lt, 2 ^ 2, 256, 256⟩ : PcsPrm) = ⟨12, 4, 256, 256⟩ := rfl
  have hepD : V.pub.epLogN + 3 = 11 := rfl
  have hepP : (⟨V.pub.epLogN, 2 ^ 3, 256, 256⟩ : PcsPrm) = ⟨8, 8, 256, 256⟩ := rfl
  refine ⟨?_, ?_, ?_, ?_, rfl, ?_, ?_, ?_, ?_⟩
  · rw [incDataAt_bRoot]; dsimp only [ShdRunWitness.incTables]
  · rw [incDataAt_aRoot]; exact congrArg₂ (rootOf H tag) hlt rfl
  · rw [incDataAt_maskRoot]; exact congrArg (fun m => rootOf H tag 12 (mTab 4 (cosetPt (rootFp 12)) m)) rfl
  · intro ch; rw [incDataAt_hRoot]; exact congrArg₂ (rootOf H tag) hlt rfl
  · rw [incDataAt_mOpen]; exact congrArg (fun m => bMask H tag shdP_U shdP_hbij m 4) rfl
  · rw [incDataAt_aOpen]
    have h1 := congrArg₂ (fun p d => bOpen H tag p d (W.incTables H c).TA) hprm hlt
    exact h1.trans (congrArg (bOpen H tag ⟨12, 4, 256, 256⟩ 14) rfl)
  · rw [incDataAt_hOpen]
    have h1 := congrArg₂ (fun p d => bOpen H tag p d ((W.incTables H c).TH (incCh H V D t).1)) hprm hlt
    exact h1.trans (congrArg (bOpen H tag ⟨12, 4, 256, 256⟩ 14) rfl)
  · rw [incDataAt_epOpen]
    have h1 := congrArg₂ (fun p d => bOpen H tag p d (W.incTables H c).TE) hepP hepD
    exact h1.trans (congrArg (bOpen H tag ⟨8, 8, 256, 256⟩ 11) rfl)

private theorem coreDataAt_aRoot {P : BlockParams} (H : HIn → Dig) (tag : MTag) (prm : PcsPrm) (depth S : ℕ) (C : CoreTables P) (t : Tr) :
    (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t).aRoot = rootOf H tag depth C.TA := rfl

private theorem coreDataAt_maskRoot {P : BlockParams} (H : HIn → Dig) (tag : MTag) (prm : PcsPrm) (depth S : ℕ) (C : CoreTables P) (t : Tr) :
    (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t).maskRoot = rootOf H tag 12 (mTab S (cosetPt (rootFp 12)) C.M) := rfl

private theorem coreDataAt_hRoot {P : BlockParams} (H : HIn → Dig) (tag : MTag) (prm : PcsPrm) (depth S : ℕ) (C : CoreTables P) (t : Tr) (b g a : Fp2) :
    (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t).hRoot b g a = rootOf H tag depth (C.TH b g a) := rfl

private theorem coreDataAt_mOpen {P : BlockParams} (H : HIn → Dig) (tag : MTag) (prm : PcsPrm) (depth S : ℕ) (C : CoreTables P) (t : Tr) :
    (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t).mOpen = bMask H tag shdP_U shdP_hbij C.M S := rfl

private theorem coreDataAt_aOpen {P : BlockParams} (H : HIn → Dig) (tag : MTag) (prm : PcsPrm) (depth S : ℕ) (C : CoreTables P) (t : Tr) :
    (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t).aOpen = bOpen H tag prm depth C.TA := rfl

private theorem coreDataAt_hOpen {P : BlockParams} (H : HIn → Dig) (tag : MTag) (prm : PcsPrm) (depth S : ℕ) (C : CoreTables P) (t : Tr) :
    (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t).hOpen
      = bOpen H tag prm depth
          (C.TH (coreB H P (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t) t).1
            (coreG H P (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t) t).1
            (coreA H P (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t) t).1) := by
  have h := bgaOf_core H tag shdP_U shdP_hbij prm depth S P C t
  have h1 : (bgaOf H P (rootOf H tag depth C.TA) (rootOf H tag 12 (mTab S (cosetPt (rootFp 12)) C.M)) t).1
      = (coreB H P (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t) t).1 := congrArg Prod.fst h
  have h2 : (bgaOf H P (rootOf H tag depth C.TA) (rootOf H tag 12 (mTab S (cosetPt (rootFp 12)) C.M)) t).2.1
      = (coreG H P (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t) t).1 := congrArg (fun x => x.2.1) h
  have h3 : (bgaOf H P (rootOf H tag depth C.TA) (rootOf H tag 12 (mTab S (cosetPt (rootFp 12)) C.M)) t).2.2
      = (coreA H P (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t) t).1 := congrArg (fun x => x.2.2) h
  change bOpen H tag prm depth (C.TH _ _ _) = _
  rw [h1, h2, h3]

private theorem shdRunWitness_blkDataAt_fields {Hdr Coins : Type} {tag : MTag} {Rp : ClassifyRunPublicP shieldS0}
    {embDigest : Dig} {bInRow : ℕ} {wDigest : Dig} {bOutRow ioIn ioOut : ℕ}
    {checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit}
    {epBase : Coins → EpxSalt 6} {x : shieldS0.Tok → ℕ}
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (k : ℕ) (H : HIn → Dig) (c : Coins) (t : Tr) :
    let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
    let D := coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 P (W.blkTables k c).coreT t
    D.aRoot = rootOf H tag 16 (W.blkTA k c)
      ∧ D.maskRoot = rootOf H tag 12 (mTab 23 (cosetPt (rootFp 12)) (W.blkM k c))
      ∧ (∀ b g a, D.hRoot b g a = rootOf H tag 16 (W.blkTH k c b g a))
      ∧ D.slot = W.blkSlot k c
      ∧ D.mOpen = bMask H tag shdP_U shdP_hbij (W.blkM k c) 23
      ∧ D.aOpen = bOpen H tag Exec.R13.r13Prm 16 (W.blkTA k c)
      ∧ D.hOpen = bOpen H tag Exec.R13.r13Prm 16 (W.blkTH k c (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1) := by
  intro P D
  refine ⟨?_, ?_, ?_, rfl, ?_, ?_, ?_⟩
  · rw [coreDataAt_aRoot]; exact congrArg (rootOf H tag 16) rfl
  · rw [coreDataAt_maskRoot]; exact congrArg (fun m => rootOf H tag 12 (mTab 23 (cosetPt (rootFp 12)) m)) rfl
  · intro b g a; rw [coreDataAt_hRoot]; exact congrArg (rootOf H tag 16) rfl
  · rw [coreDataAt_mOpen]; exact congrArg (fun m => bMask H tag shdP_U shdP_hbij m 23) rfl
  · rw [coreDataAt_aOpen]; exact congrArg (bOpen H tag Exec.R13.r13Prm 16) rfl
  · rw [coreDataAt_hOpen]; exact congrArg (bOpen H tag Exec.R13.r13Prm 16) rfl

private theorem outcDataAt_aRoot {V : OutcV} (tag : MTag) (H : HIn → Dig) (C : OutcTables V) (t : Tr) :
    (outcDataAt_abs tag H V C t).aRoot = rootOf H tag 14 C.TA := rfl

private theorem outcDataAt_maskRoot {V : OutcV} (tag : MTag) (H : HIn → Dig) (C : OutcTables V) (t : Tr) :
    (outcDataAt_abs tag H V C t).maskRoot = rootOf H tag 12 (mTab 8 (cosetPt (rootFp 12)) C.M) := rfl

private theorem outcDataAt_hRoot {V : OutcV} (tag : MTag) (H : HIn → Dig) (C : OutcTables V) (t : Tr) (ch : List Fp2) :
    (outcDataAt_abs tag H V C t).hRoot ch = rootOf H tag 14 (C.TH ch) := rfl

private theorem outcDataAt_mOpen {V : OutcV} (tag : MTag) (H : HIn → Dig) (C : OutcTables V) (t : Tr) :
    (outcDataAt_abs tag H V C t).mOpen = bMask H tag shdP_U shdP_hbij C.M 8 := rfl

private theorem outcDataAt_aOpen {V : OutcV} (tag : MTag) (H : HIn → Dig) (C : OutcTables V) (t : Tr) :
    (outcDataAt_abs tag H V C t).aOpen = bOpen H tag ⟨12, 4, 256, 256⟩ 14 C.TA := rfl

private theorem outcDataAt_hOpen {V : OutcV} (tag : MTag) (H : HIn → Dig) (C : OutcTables V) (t : Tr) :
    (outcDataAt_abs tag H V C t).hOpen
      = bOpen H tag ⟨12, 4, 256, 256⟩ 14 (C.TH (outcCh H V (outcDataAt_abs tag H V C t) t).1) := rfl

private theorem shdRunWitness_outcDataAt_fields {Hdr Coins : Type} {tag : MTag} {Rp : ClassifyRunPublicP shieldS0}
    {embDigest : Dig} {bInRow : ℕ} {wDigest : Dig} {bOutRow ioIn ioOut : ℕ}
    {checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit}
    {epBase : Coins → EpxSalt 6} {x : shieldS0.Tok → ℕ}
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (H : HIn → Dig) (c : Coins) (t : Tr) :
    let v := (classifySpecP Rp x).getD 0
    let V := shdVo tag Rp wDigest bOutRow v
    let D := shdP_outcDataAt tag Rp wDigest bOutRow H v (W.outcTables c) t
    D.aRoot = rootOf H tag 14 (W.outcTA c)
      ∧ D.maskRoot = rootOf H tag 12 (mTab 8 (cosetPt (rootFp 12)) (W.outcM c))
      ∧ (∀ ch, D.hRoot ch = rootOf H tag 14 (W.outcTH c ch))
      ∧ D.slot = W.outcSlot c
      ∧ D.mOpen = bMask H tag shdP_U shdP_hbij (W.outcM c) 8
      ∧ D.aOpen = bOpen H tag ⟨12, 4, 256, 256⟩ 14 (W.outcTA c)
      ∧ D.hOpen = bOpen H tag ⟨12, 4, 256, 256⟩ 14 (W.outcTH c (outcCh H V D t).1) := by
  intro v V D
  refine ⟨?_, ?_, ?_, rfl, ?_, ?_, ?_⟩
  · rw [outcDataAt_aRoot]; exact congrArg (rootOf H tag 14) rfl
  · rw [outcDataAt_maskRoot]; exact congrArg (fun m => rootOf H tag 12 (mTab 8 (cosetPt (rootFp 12)) m)) rfl
  · intro ch; rw [outcDataAt_hRoot]; exact congrArg (rootOf H tag 14) rfl
  · rw [outcDataAt_mOpen]; exact congrArg (fun m => bMask H tag shdP_U shdP_hbij m 8) rfl
  · rw [outcDataAt_aOpen]; exact congrArg (bOpen H tag ⟨12, 4, 256, 256⟩ 14) rfl
  · rw [outcDataAt_hOpen]; exact congrArg (bOpen H tag ⟨12, 4, 256, 256⟩ 14) rfl

private theorem shdP_runSite_aux_cover_inc {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (hV : Rp.inp.V = 131072) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (hbIn : bInRow = 32 ∨ bInRow = 34) (wDigest : Dig) (bOutRow : ℕ)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (Wx : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (preHdr : Coins → TProg Unit)
    (hHdr : ∀ c, TProg.Sep key (preHdr c) ∧ SqLE 0 (preHdr c))
    (preBlk : ℕ → Coins → TProg (List Exec.Block.ZClaim))
    (hBlk : ∀ k, k ≤ 26 → ∀ c, TProg.Sep key (preBlk k c) ∧ SqLE (515 + k * 10359) (preBlk k c))
    (G : QB Lq → Dig) (c : Coins)
    (hincErr : incProve (liftH G) (shdVi tag Rp embDigest bInRow)
      (incDataAt (liftH G) tag shdP_U shdP_hbij (shdVi tag Rp embDigest bInRow) 2 3 256 256
        (Wx.incTables (liftH G) c) ((preHdr c).final (liftH G) (Tr.newKeyed (liftH G) shdP_runDomain key)).1)
      ((preHdr c).final (liftH G) (Tr.newKeyed (liftH G) shdP_runDomain key)).1 = .error ()) :
    ∃ i' : shdP_SiteIdx,
      (shdP_runSite_aux tag Lq hL20 key Rp hR hV ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow blkDig epBase x Wx
        preHdr hHdr preBlk hBlk i').fires shdP_U G c := by
  have hLq : 47 ≤ Lq := by omega
  let t0 := Tr.newKeyed (liftH G) shdP_runDomain key
  let D_in := incDataAt (liftH G) tag shdP_U shdP_hbij (shdVi tag Rp embDigest bInRow) 2 3 256 256
    (Wx.incTables (liftH G) c) ((preHdr c).final (liftH G) t0).1
  obtain ⟨hB, hA, hM, hH, hD, hMO, hAO, hHO, -⟩ := shdRunWitness_incDataAt_fields Wx (liftH G) c ((preHdr c).final (liftH G) t0).1
  have hAud := fun sps recs acc t4 hsl =>
    shdP_inc_audit_and_carry Lq hLq key shdP_runDomain shdP_runDomain_ne_35 tag Rp embDigest bInRow hbIn
      preHdr 0 (fun c' => (hHdr c').1) (fun c' => (hHdr c').2) (by norm_num)
      (Wx.TB 0) Wx.incTA Wx.incM Wx.incTH Wx.incSlot G c D_in hB hA hM hH hD sps recs acc t4 hsl
  obtain ⟨i0, hi0⟩ := incSeg_refuse_cover Lq hLq key shdP_runDomain shdP_runDomain_ne_35 tag Rp hinPub hV embDigest bInRow
    preHdr 0 (fun c' => (hHdr c').1) (fun c' => (hHdr c').2) (by norm_num)
    (Wx.TB 0) Wx.incTA Wx.incM Wx.incTH Wx.hrIncA Wx.hrIncH Wx.incSlot _ _ G c D_in
    hB hA hM hH hD hMO hAO hHO (fun sps recs acc t4 hsl => (hAud sps recs acc t4 hsl).1)
    (fun sps recs acc t4 hsl => (hAud sps recs acc t4 hsl).2.1) hincErr
  obtain ⟨i', hi'⟩ := shdP_runSite_aux_inc tag Lq hL20 key Rp hR hV ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow
    blkDig epBase x Wx preHdr hHdr preBlk hBlk i0
  exact ⟨i', by rw [hi']; exact hi0⟩

private theorem shdP_runSite_aux_cover_blk {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (hV : Rp.inp.V = 131072)
    (ioIn ioOut : ℕ) (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (Wx : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (preHdr : Coins → TProg Unit)
    (hHdr : ∀ c, TProg.Sep key (preHdr c) ∧ SqLE 0 (preHdr c))
    (preBlk : ℕ → Coins → TProg (List Exec.Block.ZClaim))
    (hBlk : ∀ k, k ≤ 26 → ∀ c, TProg.Sep key (preBlk k c) ∧ SqLE (515 + k * 10359) (preBlk k c))
    (k : ℕ) (hk : k < 26) (G : QB Lq → Dig) (c : Coins)
    (r0 : ℕ) (pend : List Exec.Block.ZClaim)
    (bndCheckK : List Exec.Block.ZClaim → Tr → Except String Unit)
    (hpendEq : pend = ((preBlk k c).final (liftH G) (Tr.newKeyed (liftH G) shdP_runDomain key)).2)
    (hcarK : BndCarryOk r0 pend)
    (hpairK : (r0 = 32 ∧ ioIn = 34) ∨ (r0 = 34 ∧ ioIn = 32))
    (hchkA : ∀ cl t e, checkOpening (liftH G) .a cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomA 14 cl t = .error e')
    (hchkH : ∀ cl t e, checkOpening (liftH G) .h cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomH 14 cl t = .error e')
    (hbndK : ∀ cl t e, bndCheckK cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t = .error e')
    (hblkErr :
      let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
      let tFr := ((blkFrameProg k (blkDig k) (preBlk k c) (rootOfP tag 16 (Wx.TB (k + 1) c))).final
        (liftH G) (Tr.newKeyed (liftH G) shdP_runDomain key)).1
      let D := coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 P (Wx.blkTables k c).coreT tFr
      blkAlphaBadP (shdP_blkLy k hk) (shdP_blkPb Rp hR k hk) (coreB (liftH G) P D tFr).1 (coreG (liftH G) P D tFr).1 (coreA (liftH G) P D tFr).1
        ∨ coreProve (liftH G) P D tFr = .error ()
        ∨ ∃ R e, coreProve (liftH G) P D tFr = .ok R
            ∧ bndCheckK (pend ++ R.acc.claims.inp) R.t7 = .error e) :
    ∃ i' : shdP_SiteIdx,
      (shdP_runSite_aux tag Lq hL20 key Rp hR hV ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow blkDig epBase x Wx
        preHdr hHdr preBlk hBlk i').fires shdP_U G c := by
  have hLq : 47 ≤ Lq := by omega
  let t0 := Tr.newKeyed (liftH G) shdP_runDomain key
  let tFr := ((blkFrameProg k (blkDig k) (preBlk k c) (rootOfP tag 16 (Wx.TB (k + 1) c))).final (liftH G) t0).1
  let D_k := coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) (Wx.blkTables k c).coreT tFr
  obtain ⟨hA, hM, hH, hD, hMO, hAO, hHO⟩ := shdRunWitness_blkDataAt_fields Wx k (liftH G) c tFr
  have hAud := fun sps recs acc t4 hsl =>
    shdP_blk_audit_and_carry Lq hLq key shdP_runDomain shdP_runDomain_ne_35 tag ioIn ioOut checkOpening Rp hR k hk (blkDig k)
      (preBlk k) (515 + k * 10359) (fun c' => (hBlk k (by omega) c').1) (fun c' => (hBlk k (by omega) c').2)
      (by omega) (Wx.TB (k + 1)) (Wx.blkTA k) (Wx.blkM k) (Wx.blkTH k) (Wx.blkSlot k)
      G c D_k hA hM hH hD sps recs acc t4 hsl
  have hLen23 := shdP_Pk0_slots_length tag ioIn ioOut checkOpening Rp hR k hk
  obtain ⟨i0, hi0⟩ := blkSeg_refuse_cover Lq hLq key shdP_runDomain shdP_runDomain_ne_35 tag ioIn ioOut checkOpening Rp hR k hk (blkDig k)
    (preBlk k) (515 + k * 10359) (fun c' => (hBlk k (by omega) c').1) (fun c' => (hBlk k (by omega) c').2)
    (by omega) (Wx.TB (k + 1)) (Wx.blkTA k) (Wx.blkM k) (Wx.blkTH k) (Wx.hrBlkA k hk) (Wx.hrBlkH k hk) (Wx.blkSlot k)
    _ _ _ G c D_k pend bndCheckK hchkA hchkH hbndK
    hA hM hH hD hMO hAO hHO
    (fun sps recs acc t4 hsl => (hAud sps recs acc t4 hsl).1)
    (fun sps recs acc t4 hsl => (hAud sps recs acc t4 hsl).2.1)
    (fun R hRcp => by
      obtain ⟨hsl, -, -, -, -, -, -, -, -, -, -⟩ := coreProve_ok (liftH G) _ _ _ R hRcp
      rw [hLen23] at hsl
      rw [hpendEq]; exact (hAud _ _ _ _ hsl).2.2.2.2 r0 hpairK (by rw [← hpendEq]; exact hcarK))
    hblkErr
  obtain ⟨i', hi'⟩ := shdP_runSite_aux_blk tag Lq hL20 key Rp hR hV ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow
    blkDig epBase x Wx preHdr hHdr preBlk hBlk k hk i0
  exact ⟨i', by rw [hi']; exact hi0⟩

private theorem shdP_runSite_aux_cover_outc {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (hV : Rp.inp.V = 131072)
    (ioIn ioOut : ℕ) (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (Wx : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (preHdr : Coins → TProg Unit)
    (hHdr : ∀ c, TProg.Sep key (preHdr c) ∧ SqLE 0 (preHdr c))
    (preBlk : ℕ → Coins → TProg (List Exec.Block.ZClaim))
    (hBlk : ∀ k, k ≤ 26 → ∀ c, TProg.Sep key (preBlk k c) ∧ SqLE (515 + k * 10359) (preBlk k c))
    (G : QB Lq → Dig) (c : Coins) (cr₁ : Carry)
    (hpendEq : cr₁.pending = ((preBlk 26 c).final (liftH G) (Tr.newKeyed (liftH G) shdP_runDomain key)).2)
    (hown : (shdP_outcDataAt tag Rp wDigest bOutRow (liftH G) ((classifySpecP Rp x).getD 0) (Wx.outcTables c)
      ((preBlk 26 c).final (liftH G) (Tr.newKeyed (liftH G) shdP_runDomain key)).1).own cr₁ = true)
    (hcar26 : BndCarryOk ioOut cr₁.pending)
    (hB26 : (ioOut = 32 ∧ bOutRow = 34) ∨ (ioOut = 34 ∧ bOutRow = 32))
    (houtErr : outcProve (liftH G) (shdVo tag Rp wDigest bOutRow ((classifySpecP Rp x).getD 0))
      (shdP_outcDataAt tag Rp wDigest bOutRow (liftH G) ((classifySpecP Rp x).getD 0) (Wx.outcTables c)
        ((preBlk 26 c).final (liftH G) (Tr.newKeyed (liftH G) shdP_runDomain key)).1)
      cr₁ ((preBlk 26 c).final (liftH G) (Tr.newKeyed (liftH G) shdP_runDomain key)).1 = .error ()) :
    ∃ i' : shdP_SiteIdx,
      (shdP_runSite_aux tag Lq hL20 key Rp hR hV ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow blkDig epBase x Wx
        preHdr hHdr preBlk hBlk i').fires shdP_U G c := by
  have hLq : 47 ≤ Lq := by omega
  let v := (classifySpecP Rp x).getD 0
  let t0 := Tr.newKeyed (liftH G) shdP_runDomain key
  let D_out := shdP_outcDataAt tag Rp wDigest bOutRow (liftH G) v (Wx.outcTables c) ((preBlk 26 c).final (liftH G) t0).1
  obtain ⟨hA, hM, hH, hD, hMO, hAO, hHO⟩ := shdRunWitness_outcDataAt_fields Wx (liftH G) c ((preBlk 26 c).final (liftH G) t0).1
  have hAud := fun sps recs acc t4 hsl =>
    shdP_outc_audit Lq hLq key shdP_runDomain shdP_runDomain_ne_35 tag Rp wDigest bOutRow v
      (preBlk 26) (515 + 26 * 10359) (fun c' => (hBlk 26 le_rfl c').1) (fun c' => (hBlk 26 le_rfl c').2)
      (by norm_num) Wx.outcTA Wx.outcM Wx.outcTH Wx.outcSlot G c D_out hA hM hH hD sps recs acc t4 hsl
  obtain ⟨i0, hi0⟩ := outcSeg_refuse_cover Lq hLq key shdP_runDomain shdP_runDomain_ne_35 tag Rp wDigest bOutRow v
    (preBlk 26) (515 + 26 * 10359) (fun c' => (hBlk 26 le_rfl c').1) (fun c' => (hBlk 26 le_rfl c').2)
    (by norm_num) Wx.outcTA Wx.outcM Wx.outcTH Wx.hrOutcA Wx.hrOutcH Wx.outcSlot _ _ _ G c D_out cr₁ hown
    hA hM hH hD hMO hAO hHO
    (fun sps recs acc t4 hsl => (hAud sps recs acc t4 hsl).1)
    (fun sps recs acc t4 hsl => (hAud sps recs acc t4 hsl).2.1)
    (fun sps recs acc t4 hsl => by
      rw [hpendEq]
      exact (hAud sps recs acc t4 hsl).2.2 ioOut hB26 (by rw [← hpendEq]; exact hcar26))
    houtErr
  obtain ⟨i', hi'⟩ := shdP_runSite_aux_outc tag Lq hL20 key Rp hR hV ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow
    blkDig epBase x Wx preHdr hHdr preBlk hBlk i0
  exact ⟨i', by rw [hi']; exact hi0⟩

/-- **Whole-run Shieldstral T128 R13 refusal-site family** (`shdP_SiteIdx → Site (QB Lq) Coins shdP_K`):
packs all 28 segments (`1` Stage IN-C + `26` R13 Blocks + `1` Stage OUT-C) into `shdP_SiteIdx` with
exact per-kind counts (`84 / 22867 / 610 / 662 / 447 / 40 / 0 ≤ shdP_siteCount`). -/
noncomputable def shdP_runSite {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (hV : Rp.inp.V = 131072)
    (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (ioIn ioOut : ℕ) (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6)
    (W : (x : shieldS0.Tok → ℕ) → ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (x : shieldS0.Tok → ℕ) : shdP_SiteIdx → ProtocolClassify.Site (QB Lq) Coins shdP_K :=
  shdP_runSite_aux tag Lq hL20 key Rp hR hV ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow blkDig epBase x (W x)
    (shdP_hdrProgF tag hw hdr ((classifySpecP Rp x).getD 0) x epBase)
    (shdP_hdrProg_sep_sq tag hw hdr ((classifySpecP Rp x).getD 0) x epBase key)
    (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x (W x))
    (shdP_runPreBlk_sep_sq_all tag key hw hdr Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x (W x))

/-- **Discharges `hk` of `RunShieldOpenShell.sshC_productionReadyL_epP_openShell`**. -/
theorem shdP_refuse_hk {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (hV : Rp.inp.V = 131072)
    (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (ioIn ioOut : ℕ) (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6)
    (W : (x : shieldS0.Tok → ℕ) → ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (x : shieldS0.Tok → ℕ) (i : shdP_SiteIdx) :
    (shdP_runSite tag Lq hL20 key Rp hR hV hw hdr ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow blkDig epBase W x i).k
      ≤ shdP_kOf i :=
  (shdP_runSite_aux_k_delta tag Lq hL20 key Rp hR hV ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow blkDig epBase x (W x)
    (shdP_hdrProgF tag hw hdr ((classifySpecP Rp x).getD 0) x epBase)
    (shdP_hdrProg_sep_sq tag hw hdr ((classifySpecP Rp x).getD 0) x epBase key)
    (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x (W x))
    (shdP_runPreBlk_sep_sq_all tag key hw hdr Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x (W x)) i).1

/-- **Discharges `hδ` of `RunShieldOpenShell.sshC_productionReadyL_epP_openShell`**. -/
theorem shdP_refuse_hδ {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (hV : Rp.inp.V = 131072)
    (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (ioIn ioOut : ℕ) (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6)
    (W : (x : shieldS0.Tok → ℕ) → ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (x : shieldS0.Tok → ℕ) (i : shdP_SiteIdx) :
    (shdP_runSite tag Lq hL20 key Rp hR hV hw hdr ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow blkDig epBase W x i).δ
      = 0 :=
  (shdP_runSite_aux_k_delta tag Lq hL20 key Rp hR hV ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow blkDig epBase x (W x)
    (shdP_hdrProgF tag hw hdr ((classifySpecP Rp x).getD 0) x epBase)
    (shdP_hdrProg_sep_sq tag hw hdr ((classifySpecP Rp x).getD 0) x epBase key)
    (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x (W x))
    (shdP_runPreBlk_sep_sq_all tag key hw hdr Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x (W x)) i).2

end RunSitePacking

/-! ## 4. Prefix Agreement, `ShdRunProverMatch`, `shdP_refuse_hcover`, and `shdP_refuse_O` -/

section RunRefusalCover

private theorem list_take_succ_of_getElem? {α : Type} :
    ∀ (l : List α) (n : ℕ) (a : α), l[n]? = some a → l.take (n + 1) = l.take n ++ [a]
  | [], _, _, h => by cases h
  | x :: _, 0, a, h => by simp only [List.getElem?_cons_zero, Option.some.injEq] at h; subst h; rfl
  | x :: xs, n + 1, a, h => by
    simp only [List.getElem?_cons_succ] at h
    simp only [List.take_succ_cons, List.cons_append, list_take_succ_of_getElem? xs n a h]

/-- Decompose a `proveSegs` refusal into the exact first failing segment `j`, its succeeding prefix `ps.take j`,
and the carry & transcript `(cr₁, t₁)` handed to `ps[j]`. -/
theorem proveSegs_refuses_at_getElem {St X Coins : Type} (H : HIn → Dig) (s : St) (x : X) (c : Coins) (bnd : Dig) :
    ∀ (ps : List (SegP St X Coins)) (cr : Carry) (t : Tr),
      proveSegs H s x c bnd ps cr t = .error () →
      ∃ (j : ℕ) (bs₁ : List (List UInt8)) (cr₁ : Carry) (t₁ : Tr) (p : SegP St X Coins),
        j < ps.length ∧ ps[j]? = some p
        ∧ proveSegs H s x c bnd (ps.take j) cr t = .ok (bs₁, cr₁, t₁)
        ∧ p.run H s x c bnd (posTag H t₁) cr₁ t₁ = .error ()
  | [], _, _, h => by cases h
  | p :: ps, cr, t, h => by
    have h' : (p.run H s x c bnd (posTag H t) cr t >>= fun r =>
        proveSegs H s x c bnd ps r.2.1 r.2.2 >>= fun r' => .ok (r.1 (posTag H r.2.2) :: r'.1, r'.2.1, r'.2.2))
        = .error () := h
    cases hp : p.run H s x c bnd (posTag H t) cr t with
    | error e =>
      cases e; exact ⟨0, [], cr, t, p, Nat.zero_lt_succ _, rfl, rfl, hp⟩
    | ok r =>
      rw [hp] at h'
      cases hq : proveSegs H s x c bnd ps r.2.1 r.2.2 with
      | error e =>
        cases e
        obtain ⟨j, bs₁, cr₁, t₁, p₁, hj, hget, hpre, herr⟩ := proveSegs_refuses_at_getElem H s x c bnd ps r.2.1 r.2.2 hq
        refine ⟨j + 1, r.1 (posTag H r.2.2) :: bs₁, cr₁, t₁, p₁, Nat.succ_lt_succ hj, by simpa using hget, ?_, herr⟩
        show (p.run H s x c bnd (posTag H t) cr t >>= fun r0 =>
          proveSegs H s x c bnd (ps.take j) r0.2.1 r0.2.2 >>= fun r' => .ok (r0.1 (posTag H r0.2.2) :: r'.1, r'.2.1, r'.2.2)) = _
        rw [hp]; dsimp only [Bind.bind, Except.bind]; rw [hpre]
      | ok r' =>
        have h'' : (Except.ok r >>= fun r0 => proveSegs H s x c bnd ps r0.2.1 r0.2.2 >>= fun r' =>
            (.ok (r0.1 (posTag H r0.2.2) :: r'.1, r'.2.1, r'.2.2) : Except Unit _)) = .error () := h'
        have he : (Except.ok r >>= fun r0 => proveSegs H s x c bnd ps r0.2.1 r0.2.2 >>= fun r' =>
            (.ok (r0.1 (posTag H r0.2.2) :: r'.1, r'.2.1, r'.2.2) : Except Unit _))
            = .ok (r.1 (posTag H r.2.2) :: r'.1, r'.2.1, r'.2.2) := by
          dsimp only [Bind.bind, Except.bind]; rw [hq]
        rw [he] at h''; cases h''

theorem proveSegs_append_ok {St X Coins : Type} (H : HIn → Dig) (s : St) (x : X) (c : Coins) (bnd : Dig) :
    ∀ (ps₁ ps₂ : List (SegP St X Coins)) (cr : Carry) (t : Tr) (bs : List (List UInt8)) (cr' : Carry) (t' : Tr),
      proveSegs H s x c bnd (ps₁ ++ ps₂) cr t = .ok (bs, cr', t') →
      ∃ bs₁ cr₁ t₁ bs₂,
        proveSegs H s x c bnd ps₁ cr t = .ok (bs₁, cr₁, t₁)
        ∧ proveSegs H s x c bnd ps₂ cr₁ t₁ = .ok (bs₂, cr', t')
  | [], ps₂, cr, t, bs, cr', t', h => ⟨[], cr, t, bs, rfl, h⟩
  | p :: ps₁, ps₂, cr, t, bs, cr', t', h => by
    have h' : (p.run H s x c bnd (posTag H t) cr t >>= fun r =>
        proveSegs H s x c bnd (ps₁ ++ ps₂) r.2.1 r.2.2 >>= fun r' => .ok (r.1 (posTag H r.2.2) :: r'.1, r'.2.1, r'.2.2))
        = .ok (bs, cr', t') := h
    simp only [ex_bind_ok_iff] at h'
    obtain ⟨⟨enc, cr₀, t₀⟩, hp, ⟨bs', cr₂, t₂⟩, hrest, heq⟩ := h'
    simp only [Except.ok.injEq, Prod.mk.injEq] at heq; obtain ⟨rfl, rfl, rfl⟩ := heq
    obtain ⟨bs₁, cr₁, t₁, bs₂, h1, h2⟩ := proveSegs_append_ok H s x c bnd ps₁ ps₂ cr₀ t₀ bs' cr₂ t₂ hrest
    refine ⟨enc (posTag H t₀) :: bs₁, cr₁, t₁, bs₂, ?_, h2⟩
    show (p.run H s x c bnd (posTag H t) cr t >>= fun r =>
        proveSegs H s x c bnd ps₁ r.2.1 r.2.2 >>= fun r' => .ok (r.1 (posTag H r.2.2) :: r'.1, r'.2.1, r'.2.2)) = _
    rw [hp]; dsimp only [Bind.bind, Except.bind]; rw [h1]

/-- Abstract match contract connecting a concrete `P : RunP` to the oracle-independent witness `W`.
Holds both for the standard provers (`shdP_stdProverMatch`) and for any `blkAlphaBad`-guarded block prover. -/
structure ShdRunProverMatch {Hdr Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x) : Prop where
  inC_ok : ∀ (H : HIn → Dig) (r : Dig) (c : Coins) (bnd start : Dig) (cr : Carry) (t : Tr)
      (enc : Dig → List UInt8) (cr' : Carry) (t' : Tr),
    P.inC.run H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c bnd start cr t = .ok (enc, cr', t') →
    ∃ R, incProve H (shdVi tag Rp embDigest bInRow)
        (incDataAt H tag shdP_U shdP_hbij (shdVi tag Rp embDigest bInRow) 2 3 256 256 (W.incTables H c) t) t = .ok R
      ∧ cr' = ⟨R.acc.claims.out, rootOf H tag 16 (W.TB 0 c)⟩ ∧ t' = R.t8
  inC_err : ∀ (H : HIn → Dig) (r : Dig) (c : Coins) (bnd start : Dig) (cr : Carry) (t : Tr),
    P.inC.run H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c bnd start cr t = .error () →
    incProve H (shdVi tag Rp embDigest bInRow)
      (incDataAt H tag shdP_U shdP_hbij (shdVi tag Rp embDigest bInRow) 2 3 256 256 (W.incTables H c) t) t = .error ()
  blk_ok : ∀ (k : ℕ) (_hk : k < 26) (H : HIn → Dig) (r : Dig) (c : Coins) (bnd start : Dig) (cr : Carry) (t : Tr)
      (enc : Dig → List UInt8) (cr' : Carry) (t' : Tr),
    (P.blk k).run H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c bnd start cr t = .ok (enc, cr', t') →
    let Pk := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
    let tFr := ((blkFrameProg k (blkDig k) (TProg.done ()) (rootOfP tag 16 (W.TB (k + 1) c))).final H t).1
    let D := coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 Pk (W.blkTables k c).coreT tFr
    ∃ R, coreProve H Pk D tFr = .ok R
      ∧ cr' = ⟨R.acc.claims.out, rootOf H tag 16 (W.TB (k + 1) c)⟩
      ∧ t' = (bOpen H tag Exec.R13.r13Prm 16 (W.TB k c) (cr.pending ++ R.acc.claims.inp) R.t7).2
  blk_err : ∀ (k : ℕ) (hk : k < 26) (H : HIn → Dig) (r : Dig) (c : Coins) (bnd start : Dig) (cr : Carry) (t : Tr),
    cr.root = rootOf H tag 16 (W.TB k c) →
    (∀ cl ∈ cr.pending, ClaimTrue shdP_U (2 ^ 14) 14 (W.TB k c).rows (toZClaim cl)) →
    (P.blk k).run H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c bnd start cr t = .error () →
    let Pk := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
    let tFr := ((blkFrameProg k (blkDig k) (TProg.done ()) (rootOfP tag 16 (W.TB (k + 1) c))).final H t).1
    let D := coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 Pk (W.blkTables k c).coreT tFr
    blkAlphaBadP (shdP_blkLy k hk) (shdP_blkPb Rp hR k hk) (coreB H Pk D tFr).1 (coreG H Pk D tFr).1 (coreA H Pk D tFr).1
      ∨ coreProve H Pk D tFr = .error ()
      ∨ ∃ R e, coreProve H Pk D tFr = .ok R
          ∧ bndCheck (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) k (cr.pending ++ R.acc.claims.inp) R.t7 = .error e
  outC_err : ∀ (H : HIn → Dig) (r : Dig) (c : Coins) (bnd start : Dig) (cr : Carry) (t : Tr),
    P.outC.run H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c bnd start cr t = .error () →
    outcProve H (shdVo tag Rp wDigest bOutRow ((classifySpecP Rp x).getD 0))
      (shdP_outcDataAt tag Rp wDigest bOutRow H ((classifySpecP Rp x).getD 0) (W.outcTables c) t) cr t = .error ()

private theorem runRef_except_cases {ε α : Type} (x : Except ε α) :
    (∃ e, x = .error e) ∨ (∃ a, x = .ok a) := by
  cases x with
  | error e => exact Or.inl ⟨e, rfl⟩
  | ok a => exact Or.inr ⟨a, rfl⟩

open Classical in
private theorem shdP_blkSegP_run_decomp {St X Coins : Type} (tag : MTag) (Pk : ℕ → BlockParams)
    (sgeom : St → ℕ → Exec.Block.SegGeom) (check : St → ℕ → Except String Unit)
    (paths : St → Exec.Block.Segment → Except String Unit) (digest : St → ℕ → Dig)
    (bRows bLogN : ℕ → ℕ)
    (bndCheck : St → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → St → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr → Except String Tr)
    (W : (HIn → Dig) → St → X → Coins → (k : ℕ) → ShdBlkTables Pk k)
    (k : ℕ) (H : HIn → Dig) (s : St) (x : X) (c : Coins) (bnd start : Dig) (cr : Carry) (t : Tr) :
    let w := W H s x c k
    let bRoot := rootOf H tag 16 w.TB_next
    let tFrame := blockFrame (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) H s k bRoot t
    let D := coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 (Pk k) w.coreT tFrame
    (∀ enc cr' t',
      (shdP_blkSegP tag Pk sgeom check paths digest bRows bLogN bndCheck bndOpen W k).run H s x c bnd start cr t = .ok (enc, cr', t') →
      ∃ R, coreProve H (Pk k) D tFrame = .ok R
        ∧ cr' = ⟨R.acc.claims.out, bRoot⟩
        ∧ t' = (bOpen H tag Exec.R13.r13Prm 16 w.TB_prev (cr.pending ++ R.acc.claims.inp) R.t7).2)
    ∧ (cr.root = rootOf H tag 16 w.TB_prev →
       (∀ cl ∈ cr.pending, ClaimTrue shdP_U (2 ^ 14) 14 w.TB_prev.rows (toZClaim cl)) →
       (shdP_blkSegP tag Pk sgeom check paths digest bRows bLogN bndCheck bndOpen W k).run H s x c bnd start cr t = .error () →
       coreProve H (Pk k) D tFrame = .error ()
         ∨ ∃ R e, coreProve H (Pk k) D tFrame = .ok R
             ∧ bndCheck s k (cr.pending ++ R.acc.claims.inp) R.t7 = .error e) := by
  intro w bRoot tFrame D
  refine ⟨fun enc cr' t' h => ?_, fun hroot htrue h => ?_⟩
  · unfold shdP_blkSegP at h
    dsimp only at h
    by_cases hown : decide (cr.root = rootOf H tag 16 w.TB_prev
        ∧ ∀ cl ∈ cr.pending, ClaimTrue shdP_U (2 ^ 14) 14 w.TB_prev.rows (toZClaim cl)) = true
    · rw [ite_eq_left hown] at h
      cases hcp : coreProve H (Pk k) D tFrame with
      | error e => rw [hcp] at h; cases h
      | ok R =>
        rw [hcp] at h; dsimp only at h
        cases hbc : bndCheck s k (cr.pending ++ R.acc.claims.inp) R.t7 with
        | error e => rw [hbc] at h; cases h
        | ok u =>
          rw [hbc] at h; dsimp only at h
          simp only [Except.ok.injEq, Prod.mk.injEq] at h
          obtain ⟨-, rfl, rfl⟩ := h
          exact ⟨R, rfl, rfl, rfl⟩
    · rw [ite_eq_right hown] at h; cases h
  · unfold shdP_blkSegP at h
    dsimp only at h
    rw [decide_eq_true ⟨hroot, htrue⟩, ite_eq_left rfl] at h
    cases hcp : coreProve H (Pk k) D tFrame with
    | error e => cases e; exact Or.inl rfl
    | ok R =>
      rw [hcp] at h; dsimp only at h
      cases hbc : bndCheck s k (cr.pending ++ R.acc.claims.inp) R.t7 with
      | error e => exact Or.inr ⟨R, e, rfl, hbc⟩
      | ok u => rw [hbc] at h; dsimp only at h; cases h

private theorem incP_abs_run_decomp {Hdr Coins : Type} (tag : MTag) (V : IncV)
    (C : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → IncTables V)
    (H : HIn → Dig) (s : ClsStmt Hdr) (x : shieldS0.Tok → ℕ) (c : Coins) (bnd start : Dig) (cr : Carry) (t : Tr) :
    (∀ enc cr' t',
      (inSegP _ (incP_abs tag V C)).run H s x c bnd start cr t = .ok (enc, cr', t') →
      ∃ R, incProve H V (incDataAt H tag shdP_U shdP_hbij V 2 3 256 256 (C H s x c) t) t = .ok R
        ∧ cr' = ⟨R.acc.claims.out, (C H s x c).bRoot⟩ ∧ t' = R.t8)
    ∧ ((inSegP _ (incP_abs tag V C)).run H s x c bnd start cr t = .error () →
      incProve H V (incDataAt H tag shdP_U shdP_hbij V 2 3 256 256 (C H s x c) t) t = .error ()) := by
  refine ⟨fun enc cr' t' h => ?_, fun h => ?_⟩
  · dsimp only [inSegP, incP_abs] at h
    cases hpr : incProve H V (incDataAt H tag shdP_U shdP_hbij V 2 3 256 256 (C H s x c) t) t with
    | error e => rw [hpr] at h; cases h
    | ok R =>
      rw [hpr] at h; dsimp only [Bind.bind, Except.bind] at h
      simp only [Except.ok.injEq, Prod.mk.injEq] at h
      obtain ⟨-, rfl, rfl⟩ := h; exact ⟨R, rfl, rfl, rfl⟩
  · dsimp only [inSegP, incP_abs] at h
    cases hpr : incProve H V (incDataAt H tag shdP_U shdP_hbij V 2 3 256 256 (C H s x c) t) t with
    | error e => cases e; rfl
    | ok R => rw [hpr] at h; dsimp only [Bind.bind, Except.bind] at h; cases h

private theorem outcP_abs_run_decomp {Hdr Coins : Type} (tag : MTag) (V : ℕ → OutcV)
    (C : (HIn → Dig) → (s : ClsStmt Hdr) → (shieldS0.Tok → ℕ) → Coins → OutcTables (V s.verdict))
    (H : HIn → Dig) (s : ClsStmt Hdr) (x : shieldS0.Tok → ℕ) (c : Coins) (bnd start : Dig) (cr : Carry) (t : Tr) :
    (outSegP _ (outcP_abs tag V C)).run H s x c bnd start cr t = .error () →
    outcProve H (V s.verdict) (outcDataAt_abs tag H (V s.verdict) (C H s x c) t) cr t = .error () := by
  intro h; dsimp only [outSegP, outcP_abs] at h
  cases hpr : outcProve H (V s.verdict) (outcDataAt_abs tag H (V s.verdict) (C H s x c) t) cr t with
  | error e => cases e; rfl
  | ok R => rw [hpr] at h; dsimp only [Bind.bind, Except.bind] at h; cases h

open Classical in
/-- Standard Shieldstral honest provers (`shdP_incP`, `shdP_blkSegP`, `shdP_outcP`) satisfy `ShdRunProverMatch`. -/
theorem shdP_stdProverMatch {Hdr Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (check : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (C_in : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → IncTables (shdVi tag Rp embDigest bInRow))
    (W_blk : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → (k : ℕ) → ShdBlkTables (shdP_Pk0 tag ioIn ioOut checkOpening Rp) k)
    (C_out : (HIn → Dig) → (s : ClsStmt Hdr) → (shieldS0.Tok → ℕ) → Coins → OutcTables (shdVo tag Rp wDigest bOutRow s.verdict))
    (hdig : ∀ r v k, k < 26 → digest (honestStmt P.hdr r v) k = blkDig k)
    (hPin : P.inC = inSegP _ (shdP_incP tag Rp embDigest bInRow C_in))
    (hPblk : P.blk = shdP_blkSegP tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
      (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp)) check paths digest (fun _ => 38) (fun _ => 14)
      bndCheck (cbBndOpen tag 38) W_blk)
    (hPout : P.outC = outSegP _ (shdP_outcP tag Rp wDigest bOutRow C_out))
    (hCin : ∀ H r c, C_in H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c = W.incTables H c)
    (hWblk : ∀ H r c k, k < 26 → W_blk H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c k = W.blkTables k c)
    (hCout : ∀ H r c, C_out H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c = W.outcTables c) :
    ShdRunProverMatch tag Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening bndCheck blkDig epBase P x W where
  inC_ok H r c bnd start cr t enc cr' t' h := by
    rw [hPin] at h
    have hd := (incP_abs_run_decomp tag (shdVi tag Rp embDigest bInRow) C_in H
      (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c bnd start cr t).1 enc cr' t' h
    rw [hCin H r c] at hd; exact hd
  inC_err H r c bnd start cr t h := by
    rw [hPin] at h
    have hd := (incP_abs_run_decomp tag (shdVi tag Rp embDigest bInRow) C_in H
      (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c bnd start cr t).2 h
    rw [hCin H r c] at hd; exact hd
  blk_ok k hk H r c bnd start cr t enc cr' t' h := by
    rw [hPblk] at h
    have hd := (shdP_blkSegP_run_decomp tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
      (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp)) check paths digest (fun _ => 38) (fun _ => 14)
      bndCheck (cbBndOpen tag 38) W_blk k H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c bnd start cr t).1 enc cr' t' h
    rw [hWblk H r c k hk] at hd
    have hfr : blockFrame (d12aBlockProf (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
          (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp)) check paths digest (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38))
        H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) k (rootOf H tag 16 (W.blkTables k c).TB_next) t
        = ((blkFrameProg k (blkDig k) (TProg.done ()) (rootOfP tag 16 (W.TB (k + 1) c))).final H t).1 := by
      rw [final_blkFrameProg, final_done_fst]; unfold blockFrame d12aBlockProf; dsimp only [ShdRunWitness.blkTables]; rw [hdig r _ k hk]
    rw [hfr] at hd; exact hd
  blk_err k hk H r c bnd start cr t hroot htrue h := by
    rw [hPblk] at h
    have hd := (shdP_blkSegP_run_decomp tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
      (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp)) check paths digest (fun _ => 38) (fun _ => 14)
      bndCheck (cbBndOpen tag 38) W_blk k H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c bnd start cr t).2
    rw [hWblk H r c k hk] at hd
    have hd' := hd hroot htrue h
    have hfr : blockFrame (d12aBlockProf (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
          (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp)) check paths digest (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38))
        H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) k (rootOf H tag 16 (W.blkTables k c).TB_next) t
        = ((blkFrameProg k (blkDig k) (TProg.done ()) (rootOfP tag 16 (W.TB (k + 1) c))).final H t).1 := by
      rw [final_blkFrameProg, final_done_fst]; unfold blockFrame d12aBlockProf; dsimp only [ShdRunWitness.blkTables]; rw [hdig r _ k hk]
    rw [hfr] at hd'; exact Or.inr hd'
  outC_err H r c bnd start cr t h := by
    rw [hPout] at h
    have hd := outcP_abs_run_decomp tag (shdVo tag Rp wDigest bOutRow) C_out H
      (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c bnd start cr t h
    rw [hCout H r c] at hd; exact hd

private theorem shdP_inc_audit_and_carry_and {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ)
    (hbIn : bInRow = 32 ∨ bInRow = 34)
    (pre : Coins → TProg α) (mPre : ℕ) (hPre : ∀ c, TProg.Sep key (pre c) ∧ SqLE mPre (pre c))
    (hmPre : mPre + 1000 < 2 ^ 64)
    (TB TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → (ch : List Fp2) → SlotData ((shdVi tag Rp embDigest bInRow).bp
      (incCtx (shdVi tag Rp embDigest bInRow).pub ch)))
    (G : QB Lq → Dig) (c : Coins) (D : IncData (shdVi tag Rp embDigest bInRow))
    (hB : D.bRoot = rootOf (liftH G) tag 16 (TB c))
    (hA : D.aRoot = rootOf (liftH G) tag 14 (TA c))
    (hM : D.maskRoot = rootOf (liftH G) tag 12 (mTab 4 (cosetPt (rootFp 12)) (M c)))
    (hH : ∀ ch, D.hRoot ch = rootOf (liftH G) tag 14 (TH c ch))
    (hD : D.slot = Dc c)
    (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr)
    (hsl :
      let V := shdVi tag Rp embDigest bInRow
      let ch := (incCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).1
      stSlotsProve (liftH G) (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN) (D.slot ch) Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {}
        (absorbRoot (liftH G) (incCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).2 labH (D.hRoot ch) V.lay.hRows V.lay.logN)
        = .ok (sps, recs, acc, t4)) :
    acc.claims.a.length = 3
      ∧ (acc.claims.h ++ [(shdVi tag Rp embDigest bInRow).lay.logupSumClaim]).length = 4
      ∧ acc.claims.inp.length = 1
      ∧ BndCarryOk bInRow acc.claims.out := by
  obtain ⟨hAudA, hAudH, hInpLen, hOutCarry⟩ := shdP_inc_audit_and_carry Lq hLq key domain hdom tag Rp embDigest bInRow hbIn
    pre mPre (fun c' => (hPre c').1) (fun c' => (hPre c').2) hmPre TB TA M TH Dc G c D hB hA hM hH hD sps recs acc t4 hsl
  exact ⟨hAudA.1, hAudH.1, hInpLen, hOutCarry⟩

private theorem shdP_blk_audit_and_carry_and {Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (pre : Coins → TProg (List Exec.Block.ZClaim)) (mPre : ℕ)
    (hPre : ∀ c, TProg.Sep key (pre c) ∧ SqLE mPre (pre c))
    (hmPre : mPre + 12000 < 2 ^ 64)
    (TB_next TA : Coins → Table) (M : Coins → MTable) (TH : Coins → Fp2 → Fp2 → Fp2 → Table)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (G : QB Lq → Dig) (c : Coins) (D : CoreData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (hA : D.aRoot = rootOf (liftH G) tag 16 (TA c))
    (hM : D.maskRoot = rootOf (liftH G) tag 12 (mTab 23 (cosetPt (rootFp 12)) (M c)))
    (hH : ∀ b g a, D.hRoot b g a = rootOf (liftH G) tag 16 (TH c b g a))
    (hD : D.slot = Dc c)
    (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr)
    (hsl :
      let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
      let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
      slotsProve (liftH G) P D.slot (coreB (liftH G) P D tFr).1 (coreG (liftH G) P D tFr).1 (coreA (liftH G) P D tFr).1 23 [] 0 {}
        (coreT3 (liftH G) P D tFr) = .ok (sps, recs, acc, t4)) :
    acc.claims.a.length = 146
      ∧ (acc.claims.h ++ [(shdP_Pk0 tag ioIn ioOut checkOpening Rp k).logupSumClaim]).length = 54
      ∧ acc.claims.inp.length = 1
      ∧ ((ioOut = 32 ∨ ioOut = 34) → BndCarryOk ioOut acc.claims.out) := by
  obtain ⟨hAudA, hAudH, hInpLen, hOutCarry, -⟩ := shdP_blk_audit_and_carry Lq hLq key domain hdom tag ioIn ioOut checkOpening Rp hR k hk dig
    pre mPre (fun c' => (hPre c').1) (fun c' => (hPre c').2) hmPre TB_next TA M TH Dc G c D hA hM hH hD sps recs acc t4 hsl
  exact ⟨hAudA.1, hAudH.1, hInpLen, hOutCarry⟩

private theorem shdP_runPreBlk_zero {Hdr Coins : Type} (tag : MTag) (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (c : Coins) :
    shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W 0 c
      = shdP_incEndProg tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x W c := rfl

private theorem shdP_runPreBlk_succ {Hdr Coins : Type} (tag : MTag) (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (k : ℕ) (c : Coins) (hk : k < 26) :
    shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W (k + 1) c
      = bindP (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c)
          (fun pend => shdP_blkBodyProg tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c pend) := by
  change (if k < 26 then
      bindP (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c)
        (fun pend => shdP_blkBodyProg tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c pend)
    else shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c) = _
  rw [ite_eq_left hk]

private theorem final_bMaskProg_at {α : Type} (H : HIn → Dig) (tag : MTag) (S : ℕ) (M : α → MTable)
    (fs : α → List Exec.Block.MaskFunctional) (pre : TProg α) (t : Tr)
    (t1 : Tr) (a : α) (M0 : MTable) (fs0 : List Exec.Block.MaskFunctional)
    (hpre : pre.final H t = (t1, a)) (hM0 : M a = M0) (hfs0 : fs a = fs0) :
    ((bMaskProg S M fs pre).final H t).1 = (bMask H tag shdP_U shdP_hbij M0 S fs0 t1).2
      ∧ ((bMaskProg S M fs pre).final H t).2.1 = a := by
  have h := final_bMaskProg H tag S M fs pre t
  rw [hpre] at h; dsimp only at h; rw [hM0, hfs0] at h; exact h

private theorem final_bOpenProg_at {α : Type} (H : HIn → Dig) (tag : MTag) (prm : PcsPrm) (depth maxCl : ℕ)
    (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ) (pre : TProg α) (t : Tr)
    (T : α → Table) (cl : α → List Exec.Block.ZClaim)
    (t1 : Tr) (T0 : Table) (cl0 : List Exec.Block.ZClaim)
    (ht1 : (pre.final H t).1 = t1) (hT0 : T (pre.final H t).2 = T0) (hcl0 : cl (pre.final H t).2 = cl0)
    (hlen : cl0.length ≤ maxCl) :
    ((bOpenProg prm maxCl T cl pre).final H t).1 = (bOpen H tag prm depth T0 cl0 t1).2
      ∧ ((bOpenProg prm maxCl T cl pre).final H t).2.1 = (pre.final H t).2 := by
  have h := final_bOpenProg H tag prm depth maxCl hnn hnQ T cl pre t (by rw [hcl0]; exact hlen)
  rw [ht1, hT0, hcl0] at h; exact h

private theorem shdP_incEndProg_eq {Hdr Coins : Type} (tag : MTag) (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (c : Coins) :
    shdP_incEndProg tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x W c
      = bindP (bOpenProg ⟨8, 8, 256, 256⟩ 1 (fun _ => shdP_epTable (Hdr := Hdr) tag x (epBase c))
          (fun y => y.1.1.1.2.2.claims.inp)
          (incOpenHProg tag Rp embDigest bInRow (shdP_hdrProgF tag hw hdr ((classifySpecP Rp x).getD 0) x epBase)
            (W.TB 0) W.incTA W.incM W.incTH W.incSlot c))
          (fun z => TProg.done z.1.1.1.1.2.2.claims.out) := by
  unfold shdP_incEndProg
  have hpre : (fun c' => shdP_hdrProg tag hw hdr ((classifySpecP Rp x).getD 0) x (epBase c'))
      = shdP_hdrProgF tag hw hdr ((classifySpecP Rp x).getD 0) x epBase := rfl
  rw [hpre]

private theorem shdP_blkBodyProg_eq {Hdr Coins : Type} (tag : MTag)
    (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (k : ℕ) (c : Coins) (pend : List Exec.Block.ZClaim) :
    shdP_blkBodyProg tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c pend
      = bindP (bOpenProg Exec.R13.r13Prm 2 (fun _ => W.TB k c) (fun y => pend ++ y.1.1.1.2.2.claims.inp)
          (blkOpenHProg tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) k (blkDig k) (fun _ : Coins => TProg.done ())
            (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k) c))
          (fun z => TProg.done z.1.1.1.1.2.2.claims.out) := rfl

private theorem final_shdP_incEndProg_aux {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (tag : MTag)
    (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ) (hbIn : bInRow = 32 ∨ bInRow = 34)
    (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (preHdr : Coins → TProg Unit) (hHdr : ∀ c, TProg.Sep key (preHdr c) ∧ SqLE 0 (preHdr c))
    (G : QB Lq → Dig) (c : Coins) (R : IncRun)
    (hpr : incProve (liftH G) (shdVi tag Rp embDigest bInRow)
      (incDataAt (liftH G) tag shdP_U shdP_hbij (shdVi tag Rp embDigest bInRow) 2 3 256 256 (W.incTables (liftH G) c)
        ((preHdr c).final (liftH G) (Tr.newKeyed (liftH G) shdP_runDomain key)).1)
      ((preHdr c).final (liftH G) (Tr.newKeyed (liftH G) shdP_runDomain key)).1 = .ok R) :
    (bindP (bOpenProg ⟨8, 8, 256, 256⟩ 1 (fun _ => shdP_epTable (Hdr := Hdr) tag x (epBase c))
        (fun y => y.1.1.1.2.2.claims.inp)
        (incOpenHProg tag Rp embDigest bInRow preHdr (W.TB 0) W.incTA W.incM W.incTH W.incSlot c))
        (fun z => TProg.done z.1.1.1.1.2.2.claims.out)).final
        (liftH G) (Tr.newKeyed (liftH G) shdP_runDomain key) = (R.t8, R.acc.claims.out)
      ∧ BndCarryOk bInRow R.acc.claims.out := by
  let V := shdVi tag Rp embDigest bInRow
  let t0 := Tr.newKeyed (liftH G) shdP_runDomain key
  let tStart := (preHdr c).final (liftH G) t0 |>.1
  let D := incDataAt (liftH G) tag shdP_U shdP_hbij V 2 3 256 256 (W.incTables (liftH G) c) tStart
  obtain ⟨-, hch, ht3, hsl, -, -, -, -, -, -, -, -, hmo, hao, hho, -, ht8⟩ := incProve_ok (liftH G) V D tStart R hpr
  have hns4 : V.lay.ns = 4 := rfl
  rw [hns4] at hsl
  have hsl' : stSlotsProve (liftH G) (V.bp (incCtx V.pub (incCh (liftH G) V D tStart).1)) (incElog V.pub V.geo.bLogN)
      (D.slot (incCh (liftH G) V D tStart).1) Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {}
      (absorbRoot (liftH G) (incCh (liftH G) V D tStart).2 labH (D.hRoot (incCh (liftH G) V D tStart).1) V.lay.hRows V.lay.logN)
      = .ok (R.seg.core.slots, R.recs, R.acc, R.t4) := by rw [← ht3, ← hch]; exact hsl
  obtain ⟨hBd, hAd, hMd, hHd, hDd, hMO, hAO, hHO, hEO⟩ := shdRunWitness_incDataAt_fields W (liftH G) c tStart
  obtain ⟨hALen, hHLen, hInpLen, hOutCarry⟩ := shdP_inc_audit_and_carry_and Lq (by omega) key shdP_runDomain
    shdP_runDomain_ne_35 tag Rp embDigest bInRow hbIn
    preHdr 0 hHdr (by norm_num)
    (W.TB 0) W.incTA W.incM W.incTH W.incSlot G c D hBd hAd hMd hHd hDd _ _ _ _ hsl'
  have hhdF : (incHeadProg V c (preHdr c) (rootOfP tag 16 (W.TB 0 c)) (rootOfP tag 14 (W.incTA c))
      (rootOfP tag 12 (mTab 4 (cosetPt (rootFp 12)) (W.incM c))) (fun ch' => rootOfP tag 14 (W.incTH c ch'))).final (liftH G) t0
      = (R.t3, (c, R.ch)) := by
    rw [final_incHeadProg, hch, ht3]; unfold incCh; rw [hBd, hAd, hMd, hHd]
  have hS : (incSlotEndProg tag Rp embDigest bInRow preHdr (W.TB 0) W.incTA W.incM W.incTH W.incSlot 4 c).final (liftH G) t0
      = (R.t4, ((c, R.ch), R.recs, R.acc)) := by
    have hslot : stSlotsProve (liftH G) (V.bp (incCtx V.pub R.ch)) (incElog V.pub V.geo.bLogN)
        (W.incSlot c R.ch) Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {} R.t3
        = .ok (R.seg.core.slots, R.recs, R.acc, R.t4) := by
      rw [← hDd]; exact hsl
    rw [incSlotEndProg, final_famPre (liftH G) (incPf V) (incDf V W.incSlot) incBga _ 4 t0 R.seg.core.slots R.recs R.acc R.t4
      (by rw [hhdF, ← stSlotsProve_eq_fam]; exact hslot), hhdF]
  have hM : ((incMaskProg tag Rp embDigest bInRow preHdr (W.TB 0) W.incTA W.incM W.incTH W.incSlot c).final (liftH G) t0).1
        = (bMask (liftH G) tag shdP_U shdP_hbij (W.incM c) 4 (R.acc.fs ++ R.acc.hostFs) R.t4).2
      ∧ ((incMaskProg tag Rp embDigest bInRow preHdr (W.TB 0) W.incTA W.incM W.incTH W.incSlot c).final (liftH G) t0).2.1
        = ((c, R.ch), R.recs, R.acc) :=
    final_bMaskProg_at (liftH G) tag 4 (fun y => W.incM y.1.1) (fun y => y.2.2.fs ++ y.2.2.hostFs)
      (incSlotEndProg tag Rp embDigest bInRow preHdr (W.TB 0) W.incTA W.incM W.incTH W.incSlot 4 c) t0
      R.t4 ((c, R.ch), R.recs, R.acc) (W.incM c) (R.acc.fs ++ R.acc.hostFs) hS rfl rfl
  have ht5 : ((incMaskProg tag Rp embDigest bInRow preHdr (W.TB 0) W.incTA W.incM W.incTH W.incSlot c).final (liftH G) t0).1 = R.t5 := by
    rw [hMO] at hmo; exact hM.1.trans (congrArg Prod.snd hmo).symm
  have hA : ((incOpenAProg tag Rp embDigest bInRow preHdr (W.TB 0) W.incTA W.incM W.incTH W.incSlot c).final (liftH G) t0).1
        = (bOpen (liftH G) tag ⟨12, 4, 256, 256⟩ 14 (W.incTA c) R.acc.claims.a R.t5).2
      ∧ ((incOpenAProg tag Rp embDigest bInRow preHdr (W.TB 0) W.incTA W.incM W.incTH W.incSlot c).final (liftH G) t0).2.1
        = ((incMaskProg tag Rp embDigest bInRow preHdr (W.TB 0) W.incTA W.incM W.incTH W.incSlot c).final (liftH G) t0).2 :=
    final_bOpenProg_at (liftH G) tag ⟨12, 4, 256, 256⟩ 14 3 (by norm_num [PcsPrm.nn]) (by norm_num)
      (incMaskProg tag Rp embDigest bInRow preHdr (W.TB 0) W.incTA W.incM W.incTH W.incSlot c) t0
      (fun y => W.incTA y.1.1.1) (fun y => y.1.2.2.claims.a)
      R.t5 (W.incTA c) R.acc.claims.a ht5 (by rw [hM.2]) (by rw [hM.2]) hALen.le
  have ht6 : ((incOpenAProg tag Rp embDigest bInRow preHdr (W.TB 0) W.incTA W.incM W.incTH W.incSlot c).final (liftH G) t0).1 = R.t6 := by
    rw [hAO] at hao; exact hA.1.trans (congrArg Prod.snd hao).symm
  have hH : ((incOpenHProg tag Rp embDigest bInRow preHdr (W.TB 0) W.incTA W.incM W.incTH W.incSlot c).final (liftH G) t0).1
        = (bOpen (liftH G) tag ⟨12, 4, 256, 256⟩ 14 (W.incTH c (incCh (liftH G) V D tStart).1) (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6).2
      ∧ ((incOpenHProg tag Rp embDigest bInRow preHdr (W.TB 0) W.incTA W.incM W.incTH W.incSlot c).final (liftH G) t0).2.1
        = ((incOpenAProg tag Rp embDigest bInRow preHdr (W.TB 0) W.incTA W.incM W.incTH W.incSlot c).final (liftH G) t0).2 :=
    final_bOpenProg_at (liftH G) tag ⟨12, 4, 256, 256⟩ 14 4 (by norm_num [PcsPrm.nn]) (by norm_num)
      (incOpenAProg tag Rp embDigest bInRow preHdr (W.TB 0) W.incTA W.incM W.incTH W.incSlot c) t0
      (fun y => W.incTH y.1.1.1.1 y.1.1.1.2) (fun y => y.1.1.2.2.claims.h ++ [V.lay.logupSumClaim])
      R.t6 (W.incTH c (incCh (liftH G) V D tStart).1) (R.acc.claims.h ++ [V.lay.logupSumClaim]) ht6
      (by rw [hA.2, hM.2, hch]) (by rw [hA.2, hM.2]) hHLen.le
  have ht7 : ((incOpenHProg tag Rp embDigest bInRow preHdr (W.TB 0) W.incTA W.incM W.incTH W.incSlot c).final (liftH G) t0).1 = R.t7 := by
    rw [hHO] at hho; exact hH.1.trans (congrArg Prod.snd hho).symm
  have hE := final_bOpenProg_at (liftH G) tag ⟨8, 8, 256, 256⟩ 11 1 (by norm_num [PcsPrm.nn]) (by norm_num)
    (incOpenHProg tag Rp embDigest bInRow preHdr (W.TB 0) W.incTA W.incM W.incTH W.incSlot c) t0
    (fun _ => shdP_epTable (Hdr := Hdr) tag x (epBase c)) (fun y => y.1.1.1.2.2.claims.inp)
    R.t7 (shdP_epTable (Hdr := Hdr) tag x (epBase c)) R.acc.claims.inp ht7
    rfl (by rw [hH.2, hA.2, hM.2]) hInpLen.le
  refine ⟨?_, hOutCarry⟩
  rw [final_bindP]
  exact Prod.ext (by rw [final_done_fst, hE.1, ht8, hEO])
    (by rw [final_done_snd, hE.2, hH.2, hA.2, hM.2])

/-- Prefix agreement for Stage IN-C (`shdP_incEndProg` lands at `(R.t8, R.acc.claims.out)` with `BndCarryOk bInRow`). -/
theorem final_shdP_incEndProg {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (tag : MTag) (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ) (hbIn : bInRow = 32 ∨ bInRow = 34)
    (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (G : QB Lq → Dig) (c : Coins) (R : IncRun)
    (hpr : incProve (liftH G) (shdVi tag Rp embDigest bInRow)
      (incDataAt (liftH G) tag shdP_U shdP_hbij (shdVi tag Rp embDigest bInRow) 2 3 256 256 (W.incTables (liftH G) c)
        ((shdP_hdrProg tag hw hdr ((classifySpecP Rp x).getD 0) x (epBase c)).final (liftH G)
          (Tr.newKeyed (liftH G) shdP_runDomain key)).1)
      ((shdP_hdrProg tag hw hdr ((classifySpecP Rp x).getD 0) x (epBase c)).final (liftH G)
        (Tr.newKeyed (liftH G) shdP_runDomain key)).1 = .ok R) :
    (shdP_incEndProg tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x W c).final
        (liftH G) (Tr.newKeyed (liftH G) shdP_runDomain key) = (R.t8, R.acc.claims.out)
      ∧ BndCarryOk bInRow R.acc.claims.out := by
  rw [shdP_incEndProg_eq]
  have hpreEq : shdP_hdrProg tag hw hdr ((classifySpecP Rp x).getD 0) x (epBase c)
      = shdP_hdrProgF tag hw hdr ((classifySpecP Rp x).getD 0) x epBase c := rfl
  rw [hpreEq] at hpr
  exact final_shdP_incEndProg_aux Lq hL20 key tag Rp embDigest bInRow hbIn wDigest bOutRow ioIn ioOut checkOpening epBase x W
    (shdP_hdrProgF tag hw hdr ((classifySpecP Rp x).getD 0) x epBase)
    (shdP_hdrProg_sep_sq tag hw hdr ((classifySpecP Rp x).getD 0) x epBase key)
    G c R hpr

private theorem final_shdP_blkBodyProg_aux {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (k : ℕ) (hk : k < 26) (G : QB Lq → Dig) (c : Coins) (t_k : Tr)
    (pre0 : Coins → TProg Unit) (hpre0 : (pre0 c).final (liftH G) t_k = (t_k, ()))
    (r0 : ℕ) (pend : List Exec.Block.ZClaim) (hpend : BndCarryOk r0 pend)
    (R : CoreRun)
    (hALen : R.acc.claims.a.length = 146)
    (hHLen : (R.acc.claims.h ++ [(shdP_Pk0 tag ioIn ioOut checkOpening Rp k).logupSumClaim]).length = 54)
    (hInpLen : R.acc.claims.inp.length = 1)
    (hcp :
      let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
      let tFr := ((blkFrameProg k (blkDig k) (pre0 c) (rootOfP tag 16 (W.TB (k + 1) c))).final (liftH G) t_k).1
      coreProve (liftH G) P (coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 P (W.blkTables k c).coreT tFr) tFr = .ok R) :
    let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
    (bindP (bOpenProg Exec.R13.r13Prm 2 (fun _ => W.TB k c) (fun y => pend ++ y.1.1.1.2.2.claims.inp)
        (blkOpenHProg tag P k (blkDig k) pre0 (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k) c))
        (fun z => TProg.done z.1.1.1.1.2.2.claims.out)).final (liftH G) t_k
      = ((bOpen (liftH G) tag Exec.R13.r13Prm 16 (W.TB k c) (pend ++ R.acc.claims.inp) R.t7).2, R.acc.claims.out) := by
  intro P
  let _ := hpre0
  let tFr := ((blkFrameProg k (blkDig k) (pre0 c) (rootOfP tag 16 (W.TB (k + 1) c))).final (liftH G) t_k).1
  let D := coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 P (W.blkTables k c).coreT tFr
  obtain ⟨hsl, -, -, -, -, -, -, -, hmo, hao, hho⟩ := coreProve_ok (liftH G) P D tFr R hcp
  have hLen23 := shdP_Pk0_slots_length tag ioIn ioOut checkOpening Rp hR k hk
  rw [hLen23] at hsl
  obtain ⟨hAd, hMd, hHd, hDd, hMO, hAO, hHO⟩ := shdRunWitness_blkDataAt_fields W k (liftH G) c tFr
  let b := (coreB (liftH G) P D tFr).1; let g := (coreG (liftH G) P D tFr).1; let a := (coreA (liftH G) P D tFr).1
  have hhdF : (blkHeadProg tag P k (blkDig k) pre0 (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) c).final
      (liftH G) t_k = (coreT3 (liftH G) P D tFr, (c, [b, g, a])) := by
    unfold blkHeadProg; rw [final_coreHeadProg]
    have hT2 : (absorbRoot (liftH G) tFr labA (rootOf (liftH G) tag 16 (W.blkTA k c)) P.aRows P.logCols).absorb (liftH G)
        labM (rootOf (liftH G) tag 12 (mTab 23 (cosetPt (rootFp 12)) (W.blkM k c))).toList = coreT2 (liftH G) P D tFr := by
      unfold coreT2; rw [hAd, hMd]
    rw [hT2, ← hHd]; rfl
  have hS : (blkSlotEndProg tag P k (blkDig k) pre0 (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k) 23 c).final
      (liftH G) t_k = (R.t4, ((c, [b, g, a]), R.recs, R.acc)) := by
    have hslot : slotsProve (liftH G) P (W.blkSlot k c) b g a 23 [] 0 {} (coreT3 (liftH G) P D tFr)
        = .ok (R.core.slots, R.recs, R.acc, R.t4) := by
      rw [← hDd]; exact hsl
    rw [blkSlotEndProg, final_famPre (liftH G) (corePf P) (coreDf P (W.blkSlot k)) coreBga _ 23 t_k R.core.slots R.recs R.acc R.t4
      (by rw [hhdF, ← slotsProve_eq_fam]; exact hslot), hhdF]
  have hM : ((blkMaskProg tag P k (blkDig k) pre0 (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k) c).final (liftH G) t_k).1
        = (bMask (liftH G) tag shdP_U shdP_hbij (W.blkM k c) 23 (R.acc.fs ++ R.acc.hostFs) R.t4).2
      ∧ ((blkMaskProg tag P k (blkDig k) pre0 (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k) c).final (liftH G) t_k).2.1
        = ((c, [b, g, a]), R.recs, R.acc) :=
    final_bMaskProg_at (liftH G) tag 23 (fun y => W.blkM k y.1.1) (fun y => y.2.2.fs ++ y.2.2.hostFs)
      (blkSlotEndProg tag P k (blkDig k) pre0 (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k) 23 c) t_k
      R.t4 ((c, [b, g, a]), R.recs, R.acc) (W.blkM k c) (R.acc.fs ++ R.acc.hostFs) hS rfl rfl
  have ht5 : ((blkMaskProg tag P k (blkDig k) pre0 (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k) c).final (liftH G) t_k).1 = R.t5 := by
    rw [hMO] at hmo; exact hM.1.trans (congrArg Prod.snd hmo).symm
  have hA : ((blkOpenAProg tag P k (blkDig k) pre0 (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k) c).final (liftH G) t_k).1
        = (bOpen (liftH G) tag Exec.R13.r13Prm 16 (W.blkTA k c) R.acc.claims.a R.t5).2
      ∧ ((blkOpenAProg tag P k (blkDig k) pre0 (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k) c).final (liftH G) t_k).2.1
        = ((blkMaskProg tag P k (blkDig k) pre0 (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k) c).final (liftH G) t_k).2 :=
    final_bOpenProg_at (liftH G) tag Exec.R13.r13Prm 16 146 (by norm_num [PcsPrm.nn, Exec.R13.r13Prm]) (by norm_num [Exec.R13.r13Prm])
      (blkMaskProg tag P k (blkDig k) pre0 (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k) c) t_k
      (fun y => W.blkTA k y.1.1.1) (fun y => y.1.2.2.claims.a)
      R.t5 (W.blkTA k c) R.acc.claims.a ht5 (by rw [hM.2]) (by rw [hM.2]) hALen.le
  have ht6 : ((blkOpenAProg tag P k (blkDig k) pre0 (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k) c).final (liftH G) t_k).1 = R.t6 := by
    rw [hAO] at hao; exact hA.1.trans (congrArg Prod.snd hao).symm
  have hH : ((blkOpenHProg tag P k (blkDig k) pre0 (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k) c).final (liftH G) t_k).1
        = (bOpen (liftH G) tag Exec.R13.r13Prm 16 (W.blkTH k c b g a) (R.acc.claims.h ++ [P.logupSumClaim]) R.t6).2
      ∧ ((blkOpenHProg tag P k (blkDig k) pre0 (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k) c).final (liftH G) t_k).2.1
        = ((blkOpenAProg tag P k (blkDig k) pre0 (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k) c).final (liftH G) t_k).2 :=
    final_bOpenProg_at (liftH G) tag Exec.R13.r13Prm 16 54 (by norm_num [PcsPrm.nn, Exec.R13.r13Prm]) (by norm_num [Exec.R13.r13Prm])
      (blkOpenAProg tag P k (blkDig k) pre0 (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k) c) t_k
      (fun y => W.blkTH k y.1.1.1.1 (coreBga y.1.1.1).1 (coreBga y.1.1.1).2.1 (coreBga y.1.1.1).2.2)
      (fun y => y.1.1.2.2.claims.h ++ [P.logupSumClaim])
      R.t6 (W.blkTH k c b g a) (R.acc.claims.h ++ [P.logupSumClaim]) ht6
      (by rw [hA.2, hM.2]; rfl) (by rw [hA.2, hM.2]) hHLen.le
  have ht7 : ((blkOpenHProg tag P k (blkDig k) pre0 (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k) c).final (liftH G) t_k).1 = R.t7 := by
    rw [hHO] at hho; exact hH.1.trans (congrArg Prod.snd hho).symm
  have hpendLen : pend.length = 1 := by obtain ⟨_, rfl, _, _, _⟩ := hpend; rfl
  have hB := final_bOpenProg_at (liftH G) tag Exec.R13.r13Prm 16 2 (by norm_num [PcsPrm.nn, Exec.R13.r13Prm]) (by norm_num [Exec.R13.r13Prm])
    (blkOpenHProg tag P k (blkDig k) pre0 (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k) c) t_k
    (fun _ => W.TB k c) (fun y => pend ++ y.1.1.1.2.2.claims.inp)
    R.t7 (W.TB k c) (pend ++ R.acc.claims.inp) ht7
    rfl (by rw [hH.2, hA.2, hM.2]) (by rw [List.length_append, hpendLen, hInpLen])
  rw [final_bindP]
  exact Prod.ext (by rw [final_done_fst, hB.1])
    (by rw [final_done_snd, hB.2, hH.2, hA.2, hM.2])

/-- Prefix agreement for Block `k` (`shdP_blkBodyProg` lands at `(bOpen.2, R.acc.claims.out)` with `BndCarryOk ioOut`). -/
theorem final_shdP_blkBodyProg {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (tag : MTag) (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ) (hioOut : ioOut = 32 ∨ ioOut = 34)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (k : ℕ) (hk : k < 26) (G : QB Lq → Dig) (c : Coins) (r0 : ℕ) (pend : List Exec.Block.ZClaim) (hpend : BndCarryOk r0 pend)
    (R : CoreRun)
    (hcp :
      let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
      let t_k := ((shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c).final
        (liftH G) (Tr.newKeyed (liftH G) shdP_runDomain key)).1
      let tFr := ((blkFrameProg k (blkDig k) (TProg.done ()) (rootOfP tag 16 (W.TB (k + 1) c))).final (liftH G) t_k).1
      coreProve (liftH G) P (coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 P (W.blkTables k c).coreT tFr) tFr = .ok R) :
    let t_k := ((shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c).final
      (liftH G) (Tr.newKeyed (liftH G) shdP_runDomain key)).1
    (shdP_blkBodyProg tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c pend).final (liftH G) t_k
        = ((bOpen (liftH G) tag Exec.R13.r13Prm 16 (W.TB k c) (pend ++ R.acc.claims.inp) R.t7).2, R.acc.claims.out)
      ∧ BndCarryOk ioOut R.acc.claims.out := by
  intro t_k
  let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
  let t0 := Tr.newKeyed (liftH G) shdP_runDomain key
  let hBlkK := shdP_runPreBlk_sep_sq_all tag key hw hdr Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k (by omega)
  let tFr := ((blkFrameProg k (blkDig k) (TProg.done ()) (rootOfP tag 16 (W.TB (k + 1) c))).final (liftH G) t_k).1
  have htFrEq : ((blkFrameProg k (blkDig k)
      (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c)
      (rootOfP tag 16 (W.TB (k + 1) c))).final (liftH G) t0).1 = tFr := by
    unfold tFr; rw [final_blkFrameProg, final_blkFrameProg, final_done_fst]
  let D := coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 P (W.blkTables k c).coreT tFr
  obtain ⟨hsl, -, -, -, -, -, -, -, -, -, -⟩ := coreProve_ok (liftH G) P D tFr R hcp
  have hLen23 := shdP_Pk0_slots_length tag ioIn ioOut checkOpening Rp hR k hk
  rw [hLen23] at hsl
  have hsl' : slotsProve (liftH G) P D.slot
      (coreB (liftH G) P D ((blkFrameProg k (blkDig k)
        (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c)
        (rootOfP tag 16 (W.TB (k + 1) c))).final (liftH G) t0).1).1
      (coreG (liftH G) P D ((blkFrameProg k (blkDig k)
        (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c)
        (rootOfP tag 16 (W.TB (k + 1) c))).final (liftH G) t0).1).1
      (coreA (liftH G) P D ((blkFrameProg k (blkDig k)
        (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c)
        (rootOfP tag 16 (W.TB (k + 1) c))).final (liftH G) t0).1).1
      23 [] 0 {}
      (coreT3 (liftH G) P D ((blkFrameProg k (blkDig k)
        (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c)
        (rootOfP tag 16 (W.TB (k + 1) c))).final (liftH G) t0).1)
      = .ok (R.core.slots, R.recs, R.acc, R.t4) := by
    rw [htFrEq]; exact hsl
  obtain ⟨hAd, hMd, hHd, hDd, -, -, -⟩ := shdRunWitness_blkDataAt_fields W k (liftH G) c tFr
  obtain ⟨hALen, hHLen, hInpLen, hOutCarry⟩ := shdP_blk_audit_and_carry_and Lq (by omega) key shdP_runDomain
    shdP_runDomain_ne_35 tag ioIn ioOut checkOpening Rp hR k hk (blkDig k)
    (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k)
    (515 + k * 10359) hBlkK (by omega) (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k)
    G c D hAd hMd hHd hDd _ _ _ _ hsl'
  refine ⟨?_, hOutCarry hioOut⟩
  rw [shdP_blkBodyProg_eq]
  exact final_shdP_blkBodyProg_aux Lq tag Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W
    k hk G c t_k (fun _ => TProg.done ()) rfl r0 pend hpend R hALen hHLen hInpLen hcp

/-- **Whole-run prefix invariant** by induction on `k ≤ 26`: whenever the first `1 + k` segments succeed,
`shdP_runPreBlk k` lands at `(t₁, cr₁.pending)` and `cr₁` satisfies ownership (`root` + `ClaimTrue`) and `BndCarryOk`. -/
theorem shdP_runPreBlk_of_proveSegs_take {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (hw : Hdr → ClsHdrW)
    (preA preB : Hdr → Except String Unit) (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig) (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (ioIn ioOut : ℕ) (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hbIn : bInRow = 32 ∨ bInRow = 34) (hioOut : ioOut = 32 ∨ ioOut = 34)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (hMatch : ShdRunProverMatch tag Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening bndCheck blkDig epBase P x W)
    (G : QB Lq → Dig) (c : Coins)
    (hIncOutTrue : ∀ t R,
      incProve (liftH G) (shdVi tag Rp embDigest bInRow)
        (incDataAt (liftH G) tag shdP_U shdP_hbij (shdVi tag Rp embDigest bInRow) 2 3 256 256 (W.incTables (liftH G) c) t) t = .ok R →
      ∀ cl ∈ R.acc.claims.out, ClaimTrue shdP_U (2 ^ 14) 14 (W.TB 0 c).rows (toZClaim cl))
    (hBlkOutTrue : ∀ k, k < 26 → ∀ t R,
      coreProve (liftH G) (shdP_Pk0 tag ioIn ioOut checkOpening Rp k)
        (coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 (shdP_Pk0 tag ioIn ioOut checkOpening Rp k)
          (W.blkTables k c).coreT t) t = .ok R →
      ∀ cl ∈ R.acc.claims.out, ClaimTrue shdP_U (2 ^ 14) 14 (W.TB (k + 1) c).rows (toZClaim cl)) :
    let V := shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
      (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck
    let inRoot := honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr tag hL20) G x ((shdP_honestIn (Hdr := Hdr) tag epBase).base c)
    let st := honestStmt P.hdr inRoot ((classifySpecP Rp x).getD 0)
    let tStart := V.start (liftH G) st
    ∀ k, k ≤ 26 → ∀ bs₁ cr₁ t₁,
      proveSegs (liftH G) st x c tStart.state ((P.parts 26).take (1 + k)) carry0 tStart = .ok (bs₁, cr₁, t₁) →
      (shdP_runPreBlk tag hw P.hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c).final
          (liftH G) (Tr.newKeyed (liftH G) shdP_runDomain key) = (t₁, cr₁.pending)
        ∧ cr₁.root = rootOf (liftH G) tag 16 (W.TB k c)
        ∧ (∀ cl ∈ cr₁.pending, ClaimTrue shdP_U (2 ^ 14) 14 (W.TB k c).rows (toZClaim cl))
        ∧ BndCarryOk (if k = 0 then bInRow else ioOut) cr₁.pending := by
  intro V inRoot st tStart k
  have htStartEq : tStart = ((shdP_hdrProg tag hw P.hdr ((classifySpecP Rp x).getD 0) x (epBase c)).final
      (liftH G) (Tr.newKeyed (liftH G) shdP_runDomain key)).1 :=
    (final_shdP_hdrProg tag Lq hL20 hw P.hdr ((classifySpecP Rp x).getD 0) shdP_runDomain key G x (epBase c)).symm
  induction k with
  | zero =>
    intro _ bs₁ cr₁ t₁ hpre
    change proveSegs (liftH G) st x c tStart.state [P.inC] carry0 tStart = .ok (bs₁, cr₁, t₁) at hpre
    have h' : (P.inC.run (liftH G) st x c tStart.state (posTag (liftH G) tStart) carry0 tStart >>= fun r =>
        (.ok ([r.1 (posTag (liftH G) r.2.2)], r.2.1, r.2.2) : Except Unit _)) = .ok (bs₁, cr₁, t₁) := hpre
    obtain ⟨⟨enc, cr₀, t₀⟩, hrun, heq⟩ := (ex_bind_ok_iff _ _ _).mp h'
    simp only [Except.ok.injEq, Prod.mk.injEq] at heq; obtain ⟨-, rfl, rfl⟩ := heq
    obtain ⟨R, hpr, rfl, rfl⟩ := hMatch.inC_ok (liftH G) inRoot c _ _ carry0 tStart enc cr₀ t₀ hrun
    rw [htStartEq] at hpr
    obtain ⟨hfin, hcar⟩ := final_shdP_incEndProg Lq hL20 key tag hw P.hdr Rp embDigest bInRow hbIn
      wDigest bOutRow ioIn ioOut checkOpening epBase x W G c R hpr
    rw [shdP_runPreBlk_zero]
    exact ⟨hfin, (carry_mk_root _ _).trans (congrArg (rootOf (liftH G) tag 16) rfl),
      hIncOutTrue _ R hpr, by rw [ite_eq_left rfl]; exact hcar⟩
  | succ k ih =>
    intro hk bs₁ cr₁ t₁ hpre
    have hk26 : k < 26 := by omega
    have hgetK : (P.parts 26)[1 + k]? = some (P.blk k) := by
      rw [Nat.add_comm 1 k]
      change ((List.range 26).map P.blk ++ [P.outC])[k]? = some (P.blk k)
      rw [List.getElem?_append_left (by simp [hk26]), List.getElem?_map, List.getElem?_range hk26, Option.map_some]
    have htake : (P.parts 26).take (1 + (k + 1)) = (P.parts 26).take (1 + k) ++ [P.blk k] :=
      list_take_succ_of_getElem? (P.parts 26) (1 + k) (P.blk k) hgetK
    rw [htake] at hpre
    obtain ⟨bs₀, cr₀, t₀, bs₂, hpre0, hblk1⟩ := proveSegs_append_ok (liftH G) st x c tStart.state _ [P.blk k] carry0 tStart bs₁ cr₁ t₁ hpre
    obtain ⟨hfin0, -, -, hcar0⟩ := ih (by omega) bs₀ cr₀ t₀ hpre0
    have h' : ((P.blk k).run (liftH G) st x c tStart.state (posTag (liftH G) t₀) cr₀ t₀ >>= fun r =>
        (.ok ([r.1 (posTag (liftH G) r.2.2)], r.2.1, r.2.2) : Except Unit _)) = .ok (bs₂, cr₁, t₁) := hblk1
    obtain ⟨⟨enc, cr₂, t₂⟩, hrun, heq⟩ := (ex_bind_ok_iff _ _ _).mp h'
    simp only [Except.ok.injEq, Prod.mk.injEq] at heq; obtain ⟨-, rfl, rfl⟩ := heq
    obtain ⟨R, hcp, rfl, rfl⟩ := hMatch.blk_ok k hk26 (liftH G) inRoot c _ _ cr₀ t₀ enc cr₂ t₂ hrun
    have ht0Eq : t₀ = ((shdP_runPreBlk tag hw P.hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c).final
        (liftH G) (Tr.newKeyed (liftH G) shdP_runDomain key)).1 := by rw [hfin0]
    rw [ht0Eq] at hcp
    obtain ⟨hfinB, hcarB⟩ := final_shdP_blkBodyProg Lq hL20 key tag hw P.hdr Rp hR embDigest bInRow
      wDigest bOutRow ioIn ioOut hioOut checkOpening blkDig epBase x W k hk26 G c _ cr₀.pending hcar0 R hcp
    refine ⟨?_, carry_mk_root _ _, hBlkOutTrue k hk26 _ R hcp, by rw [ite_eq_right (Nat.succ_ne_zero k)]; exact hcarB⟩
    rw [shdP_runPreBlk_succ tag hw P.hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c hk26,
      final_bindP, hfin0]
    dsimp only
    rw [← ht0Eq] at hfinB; exact hfinB

open Classical in
/-- **WHOLE-RUN REFUSAL COVER (`shdP_refuse_hcover`)**: discharges `hcover` of
`RunShieldOpenShell.sshC_productionReadyL_epP_openShell` verbatim across all 28 segments! -/
theorem shdP_refuse_hcover {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (hV : Rp.inp.V = 131072) (hinPub : Rp.inp.Valid)
    (hw : Hdr → ClsHdrW) (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (ioIn ioOut : ℕ) (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hB0 : (bInRow = 32 ∧ ioIn = 34) ∨ (bInRow = 34 ∧ ioIn = 32))
    (hBk : (ioOut = 32 ∧ ioIn = 34) ∨ (ioOut = 34 ∧ ioIn = 32))
    (hB26 : (ioOut = 32 ∧ bOutRow = 34) ∨ (ioOut = 34 ∧ bOutRow = 32))
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins)
    (hdig : ∀ r v k, k < 26 → digest (honestStmt P.hdr r v) k = blkDig k)
    (W : (x : shieldS0.Tok → ℕ) → ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (hMatch : ∀ x, (classifyModelP Rp).admissible x →
      ShdRunProverMatch tag Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening bndCheck blkDig epBase P x (W x))
    (hchkA : ∀ (G : QB Lq → Dig) cl t e, checkOpening (liftH G) .a cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomA 14 cl t = .error e')
    (hchkH : ∀ (G : QB Lq → Dig) cl t e, checkOpening (liftH G) .h cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomH 14 cl t = .error e')
    (hbnd : ∀ (G : QB Lq → Dig) s k cl t e, k < 26 → bndCheck s k cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t = .error e')
    (hIncOutTrue : ∀ x, (classifyModelP Rp).admissible x → ∀ (G : QB Lq → Dig) c t R,
      incProve (liftH G) (shdVi tag Rp embDigest bInRow)
        (incDataAt (liftH G) tag shdP_U shdP_hbij (shdVi tag Rp embDigest bInRow) 2 3 256 256 ((W x).incTables (liftH G) c) t) t = .ok R →
      ∀ cl ∈ R.acc.claims.out, ClaimTrue shdP_U (2 ^ 14) 14 ((W x).TB 0 c).rows (toZClaim cl))
    (hBlkOutTrue : ∀ x, (classifyModelP Rp).admissible x → ∀ (G : QB Lq → Dig) c k, k < 26 → ∀ t R,
      coreProve (liftH G) (shdP_Pk0 tag ioIn ioOut checkOpening Rp k)
        (coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 (shdP_Pk0 tag ioIn ioOut checkOpening Rp k)
          ((W x).blkTables k c).coreT t) t = .ok R →
      ∀ cl ∈ R.acc.claims.out, ClaimTrue shdP_U (2 ^ 14) 14 ((W x).TB (k + 1) c).rows (toZClaim cl)) :
    ∀ x, (classifyModelP Rp).admissible x → ∀ G c,
      honestSegs
        (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck)
        P (liftH G)
        (honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr tag hL20) G x
          ((shdP_honestIn (Hdr := Hdr) tag epBase).base c))
        ((classifySpecP Rp x).getD 0) x c = .error () →
      ∃ i, (shdP_runSite tag Lq hL20 key Rp hR hV hw P.hdr ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow
        blkDig epBase W x i).fires shdP_U G c := by
  intro x hx G c href
  let _ := hdig
  have hbIn : bInRow = 32 ∨ bInRow = 34 := hB0.imp And.left And.left
  have hioOut : ioOut = 32 ∨ ioOut = 34 := hBk.imp And.left And.left
  let V := shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck
  let inRoot := honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr tag hL20) G x
    ((shdP_honestIn (Hdr := Hdr) tag epBase).base c)
  let v := (classifySpecP Rp x).getD 0
  let st := honestStmt P.hdr inRoot v
  let t0 := Tr.newKeyed (liftH G) shdP_runDomain key
  let tStart := V.start (liftH G) st
  let Wx := W x
  let hHdr := shdP_hdrProg_sep_sq tag hw P.hdr v x epBase key
  let hBlk := shdP_runPreBlk_sep_sq_all tag key hw P.hdr Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x Wx
  have hsiteEq : shdP_runSite tag Lq hL20 key Rp hR hV hw P.hdr ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow
      blkDig epBase W x
      = shdP_runSite_aux tag Lq hL20 key Rp hR hV ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow
          blkDig epBase x Wx
          (shdP_hdrProgF tag hw P.hdr v x epBase) hHdr
          (shdP_runPreBlk tag hw P.hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x Wx) hBlk := rfl
  have hMx := hMatch x hx
  have htStartEq : tStart = ((shdP_hdrProgF tag hw P.hdr v x epBase c).final (liftH G) t0).1 :=
    (final_shdP_hdrProg tag Lq hL20 hw P.hdr v shdP_runDomain key G x (epBase c)).symm
  obtain ⟨j, bs₁, cr₁, t₁, p, hjLen, hjGet, hpre, herr⟩ :=
    proveSegs_refuses_at_getElem (X := shieldS0.Tok → ℕ) (liftH G) st x c tStart.state (P.parts 26) carry0 tStart href
  have hj28 : j < 28 := by rw [RunP.parts_length P 26] at hjLen; exact hjLen
  by_cases hj0 : j = 0
  · -- Segment 0: Stage IN-C
    subst hj0
    change (P.inC :: ((List.range 26).map P.blk ++ [P.outC]))[0]? = some p at hjGet
    rw [List.getElem?_cons_zero, Option.some.injEq] at hjGet; subst hjGet
    simp only [List.take_zero, proveSegs, Except.ok.injEq, Prod.mk.injEq] at hpre
    obtain ⟨-, rfl, rfl⟩ := hpre
    have hincErr := hMx.inC_err (liftH G) inRoot c _ _ carry0 tStart herr
    rw [htStartEq] at hincErr
    obtain ⟨i', hi'⟩ := shdP_runSite_aux_cover_inc tag Lq hL20 key Rp hR hV hinPub ioIn ioOut checkOpening
      embDigest bInRow hbIn wDigest bOutRow blkDig epBase x Wx
      (shdP_hdrProgF tag hw P.hdr v x epBase) hHdr
      (shdP_runPreBlk tag hw P.hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x Wx) hBlk
      G c hincErr
    exact ⟨i', by rw [hsiteEq]; exact hi'⟩
  · by_cases hj27 : j < 27
    · -- Segments 1..26: Block `k = j - 1`
      let k := j - 1
      have hk : k < 26 := by omega
      have hjEq : j = 1 + k := by omega
      rw [hjEq] at hjGet hpre
      have hgetK : (P.parts 26)[1 + k]? = some (P.blk k) := by
        rw [Nat.add_comm 1 k]
        change ((List.range 26).map P.blk ++ [P.outC])[k]? = some (P.blk k)
        rw [List.getElem?_append_left (by simp [hk]), List.getElem?_map, List.getElem?_range hk, Option.map_some]
      rw [hgetK, Option.some.injEq] at hjGet; subst hjGet
      obtain ⟨hfinK, hrootK, htrueK, hcarK⟩ := shdP_runPreBlk_of_proveSegs_take tag Lq hL20 key Rp hR hw preA preB
        check0 paths digest bndCheck ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow hbIn hioOut blkDig epBase
        P x Wx hMx G c (hIncOutTrue x hx G c) (hBlkOutTrue x hx G c) k (by omega) bs₁ cr₁ t₁ hpre
      have hblkErr := hMx.blk_err k hk (liftH G) inRoot c _ _ cr₁ t₁ hrootK htrueK herr
      have ht1Eq : t₁ = ((shdP_runPreBlk tag hw P.hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x Wx k c).final
          (liftH G) t0).1 := by rw [hfinK]
      have hpendEq : cr₁.pending = ((shdP_runPreBlk tag hw P.hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x Wx k c).final
          (liftH G) t0).2 := by rw [hfinK]
      have htFrEq : ((blkFrameProg k (blkDig k) (TProg.done ()) (rootOfP tag 16 (Wx.TB (k + 1) c))).final (liftH G) t₁).1
          = ((blkFrameProg k (blkDig k)
              (shdP_runPreBlk tag hw P.hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x Wx k c)
              (rootOfP tag 16 (Wx.TB (k + 1) c))).final (liftH G) t0).1 := by
        rw [ht1Eq, final_blkFrameProg, final_blkFrameProg, final_done_fst]
      rw [htFrEq] at hblkErr
      have hpairK : ((if k = 0 then bInRow else ioOut) = 32 ∧ ioIn = 34) ∨ ((if k = 0 then bInRow else ioOut) = 34 ∧ ioIn = 32) := by
        by_cases hk0 : k = 0
        · rw [ite_eq_left hk0]; exact hB0
        · rw [ite_eq_right hk0]; exact hBk
      obtain ⟨i', hi'⟩ := shdP_runSite_aux_cover_blk tag Lq hL20 key Rp hR hV ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow blkDig epBase x Wx
        (shdP_hdrProgF tag hw P.hdr v x epBase) hHdr
        (shdP_runPreBlk tag hw P.hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x Wx) hBlk
        k hk G c (if k = 0 then bInRow else ioOut) cr₁.pending (bndCheck st k) hpendEq hcarK hpairK
        (hchkA G) (hchkH G) (fun cl t e => hbnd G st k cl t e hk) hblkErr
      exact ⟨i', by rw [hsiteEq]; exact hi'⟩
    · -- Segment 27: Stage OUT-C
      have hjEq : j = 27 := by omega
      subst hjEq
      have hget27 : (P.parts 26)[27]? = some P.outC := by
        show ((List.range 26).map P.blk ++ [P.outC])[26]? = some P.outC
        rw [List.getElem?_append_right (by simp)]; simp
      rw [hget27, Option.some.injEq] at hjGet; subst hjGet
      obtain ⟨hfin26, hroot26, htrue26, hcar26⟩ := shdP_runPreBlk_of_proveSegs_take tag Lq hL20 key Rp hR hw preA preB
        check0 paths digest bndCheck ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow hbIn hioOut blkDig epBase
        P x Wx hMx G c (hIncOutTrue x hx G c) (hBlkOutTrue x hx G c) 26 le_rfl bs₁ cr₁ t₁ hpre
      have houtErr := hMx.outC_err (liftH G) inRoot c _ _ cr₁ t₁ herr
      have ht1Eq : t₁ = ((shdP_runPreBlk tag hw P.hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x Wx 26 c).final
          (liftH G) t0).1 := by rw [hfin26]
      have hpendEq : cr₁.pending = ((shdP_runPreBlk tag hw P.hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x Wx 26 c).final
          (liftH G) t0).2 := by rw [hfin26]
      rw [ht1Eq] at houtErr
      have hown : (shdP_outcDataAt tag Rp wDigest bOutRow (liftH G) v (Wx.outcTables c)
          ((shdP_runPreBlk tag hw P.hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x Wx 26 c).final (liftH G) t0).1).own cr₁ = true := by
        dsimp only [shdP_outcDataAt, outcDataAt_abs, ShdRunWitness.outcTables]
        exact decide_eq_true ⟨hroot26, htrue26⟩
      rw [ite_eq_right (by omega : 26 ≠ 0)] at hcar26
      obtain ⟨i', hi'⟩ := shdP_runSite_aux_cover_outc tag Lq hL20 key Rp hR hV ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow blkDig epBase x Wx
        (shdP_hdrProgF tag hw P.hdr v x epBase) hHdr
        (shdP_runPreBlk tag hw P.hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x Wx) hBlk
        G c cr₁ hpendEq hown hcar26 hB26 houtErr
      exact ⟨i', by rw [hsiteEq]; exact hi'⟩

/-- Direct specialization of `shdP_refuse_hcover` to the standard honest Shieldstral provers
(`shdP_incP`, `shdP_blkSegP`, `shdP_outcP`). -/
theorem shdP_refuse_hcover_std {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (hV : Rp.inp.V = 131072) (hinPub : Rp.inp.Valid)
    (hw : Hdr → ClsHdrW) (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (ioIn ioOut : ℕ) (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hB0 : (bInRow = 32 ∧ ioIn = 34) ∨ (bInRow = 34 ∧ ioIn = 32))
    (hBk : (ioOut = 32 ∧ ioIn = 34) ∨ (ioOut = 34 ∧ ioIn = 32))
    (hB26 : (ioOut = 32 ∧ bOutRow = 34) ∨ (ioOut = 34 ∧ bOutRow = 32))
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins)
    (hdig : ∀ r v k, k < 26 → digest (honestStmt P.hdr r v) k = blkDig k)
    (W : (x : shieldS0.Tok → ℕ) → ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (C_in : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → IncTables (shdVi tag Rp embDigest bInRow))
    (W_blk : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → (k : ℕ) → ShdBlkTables (shdP_Pk0 tag ioIn ioOut checkOpening Rp) k)
    (C_out : (HIn → Dig) → (s : ClsStmt Hdr) → (shieldS0.Tok → ℕ) → Coins → OutcTables (shdVo tag Rp wDigest bOutRow s.verdict))
    (hPin : P.inC = inSegP _ (shdP_incP tag Rp embDigest bInRow C_in))
    (hPblk : P.blk = shdP_blkSegP tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
      (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp)) (vdChk check0) paths digest (fun _ => 38) (fun _ => 14)
      bndCheck (cbBndOpen tag 38) W_blk)
    (hPout : P.outC = outSegP _ (shdP_outcP tag Rp wDigest bOutRow C_out))
    (hCin : ∀ x, (classifyModelP Rp).admissible x → ∀ H r c, C_in H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c = (W x).incTables H c)
    (hWblk : ∀ x, (classifyModelP Rp).admissible x → ∀ H r c k, k < 26 → W_blk H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c k = (W x).blkTables k c)
    (hCout : ∀ x, (classifyModelP Rp).admissible x → ∀ H r c, C_out H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c = (W x).outcTables c)
    (hchkA : ∀ (G : QB Lq → Dig) cl t e, checkOpening (liftH G) .a cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomA 14 cl t = .error e')
    (hchkH : ∀ (G : QB Lq → Dig) cl t e, checkOpening (liftH G) .h cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomH 14 cl t = .error e')
    (hbnd : ∀ (G : QB Lq → Dig) s k cl t e, k < 26 → bndCheck s k cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t = .error e')
    (hIncOutTrue : ∀ x, (classifyModelP Rp).admissible x → ∀ (G : QB Lq → Dig) c t R,
      incProve (liftH G) (shdVi tag Rp embDigest bInRow)
        (incDataAt (liftH G) tag shdP_U shdP_hbij (shdVi tag Rp embDigest bInRow) 2 3 256 256 ((W x).incTables (liftH G) c) t) t = .ok R →
      ∀ cl ∈ R.acc.claims.out, ClaimTrue shdP_U (2 ^ 14) 14 ((W x).TB 0 c).rows (toZClaim cl))
    (hBlkOutTrue : ∀ x, (classifyModelP Rp).admissible x → ∀ (G : QB Lq → Dig) c k, k < 26 → ∀ t R,
      coreProve (liftH G) (shdP_Pk0 tag ioIn ioOut checkOpening Rp k)
        (coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 (shdP_Pk0 tag ioIn ioOut checkOpening Rp k)
          ((W x).blkTables k c).coreT t) t = .ok R →
      ∀ cl ∈ R.acc.claims.out, ClaimTrue shdP_U (2 ^ 14) 14 ((W x).TB (k + 1) c).rows (toZClaim cl)) :
    ∀ x, (classifyModelP Rp).admissible x → ∀ G c,
      honestSegs
        (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck)
        P (liftH G)
        (honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr tag hL20) G x
          ((shdP_honestIn (Hdr := Hdr) tag epBase).base c))
        ((classifySpecP Rp x).getD 0) x c = .error () →
      ∃ i, (shdP_runSite tag Lq hL20 key Rp hR hV hw P.hdr ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow
        blkDig epBase W x i).fires shdP_U G c :=
  shdP_refuse_hcover tag Lq hL20 key Rp hR hV hinPub hw preA preB check0 paths digest bndCheck ioIn ioOut
    checkOpening embDigest bInRow wDigest bOutRow hB0 hBk hB26 blkDig epBase P hdig W
    (fun x hx => shdP_stdProverMatch tag Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening
      (vdChk check0) paths digest bndCheck blkDig epBase P x (W x) C_in W_blk C_out hdig hPin hPblk hPout
      (hCin x hx) (hWblk x hx) (hCout x hx))
    hchkA hchkH hbnd hIncOutTrue hBlkOutTrue

/-- **Direct `O.refuse` discharge** (`ClassifyOpenP.refuse` + `O.counts`) via `shdP_classifyP_refuse_of_cover`. -/
theorem shdP_refuse_O {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (hV : Rp.inp.V = 131072) (hinPub : Rp.inp.Valid)
    (hw : Hdr → ClsHdrW) (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (ioIn ioOut : ℕ) (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hB0 : (bInRow = 32 ∧ ioIn = 34) ∨ (bInRow = 34 ∧ ioIn = 32))
    (hBk : (ioOut = 32 ∧ ioIn = 34) ∨ (ioOut = 34 ∧ ioIn = 32))
    (hB26 : (ioOut = 32 ∧ bOutRow = 34) ∨ (ioOut = 34 ∧ bOutRow = 32))
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins)
    (hdig : ∀ r v k, k < 26 → digest (honestStmt P.hdr r v) k = blkDig k)
    (W : (x : shieldS0.Tok → ℕ) → ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (hMatch : ∀ x, (classifyModelP Rp).admissible x →
      ShdRunProverMatch tag Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening bndCheck blkDig epBase P x (W x))
    (hchkA : ∀ (G : QB Lq → Dig) cl t e, checkOpening (liftH G) .a cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomA 14 cl t = .error e')
    (hchkH : ∀ (G : QB Lq → Dig) cl t e, checkOpening (liftH G) .h cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomH 14 cl t = .error e')
    (hbnd : ∀ (G : QB Lq → Dig) s k cl t e, k < 26 → bndCheck s k cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t = .error e')
    (hIncOutTrue : ∀ x, (classifyModelP Rp).admissible x → ∀ (G : QB Lq → Dig) c t R,
      incProve (liftH G) (shdVi tag Rp embDigest bInRow)
        (incDataAt (liftH G) tag shdP_U shdP_hbij (shdVi tag Rp embDigest bInRow) 2 3 256 256 ((W x).incTables (liftH G) c) t) t = .ok R →
      ∀ cl ∈ R.acc.claims.out, ClaimTrue shdP_U (2 ^ 14) 14 ((W x).TB 0 c).rows (toZClaim cl))
    (hBlkOutTrue : ∀ x, (classifyModelP Rp).admissible x → ∀ (G : QB Lq → Dig) c k, k < 26 → ∀ t R,
      coreProve (liftH G) (shdP_Pk0 tag ioIn ioOut checkOpening Rp k)
        (coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 (shdP_Pk0 tag ioIn ioOut checkOpening Rp k)
          ((W x).blkTables k c).coreT t) t = .ok R →
      ∀ cl ∈ R.acc.claims.out, ClaimTrue shdP_U (2 ^ 14) 14 ((W x).TB (k + 1) c).rows (toZClaim cl)) :
    let site := shdP_runSite tag Lq hL20 key Rp hR hV hw P.hdr ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow
      blkDig epBase W
    (∀ x, (classifyModelP Rp).admissible x → ∀ G c, (∀ i, ¬ (site x i).fires shdP_U G c) →
      ∃ r, honestSegs
        (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck)
        P (liftH G)
        (honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr tag hL20) G x
          ((shdP_honestIn (Hdr := Hdr) tag epBase).base c))
        ((classifySpecP Rp x).getD 0) x c = .ok r)
      ∧ (∀ x i, (site x i).k ≤ shdP_kOf i)
      ∧ (∀ x i, (site x i).δ = 0) :=
  ⟨shdP_classifyP_refuse_of_cover Rp Lq _ P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn tag epBase) shdP_U _
      (shdP_refuse_hcover tag Lq hL20 key Rp hR hV hinPub hw preA preB check0 paths digest bndCheck ioIn ioOut
        checkOpening embDigest bInRow wDigest bOutRow hB0 hBk hB26 blkDig epBase P hdig W hMatch
        hchkA hchkH hbnd hIncOutTrue hBlkOutTrue),
    shdP_refuse_hk tag Lq hL20 key Rp hR hV hw P.hdr ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow blkDig epBase W,
    shdP_refuse_hδ tag Lq hL20 key Rp hR hV hw P.hdr ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow blkDig epBase W⟩

end RunRefusalCover

end ZK60.HonestShield
