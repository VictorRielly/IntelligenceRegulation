/-
D63 lane L68c, part 2a (`HonestShieldBlockBase.lean`):
Shieldstral T128 R13 26-layer block verifier completeness (`shdP_blockVerify_of_tables_r13`),
transcript-aware `D12aBlockPT` / `d12aBlockSegPT`, concrete `shdP_segPaths` / `shdP_vdChk_ok`,
and full `SegComplete` bridge (`shdP_blk_segComplete`) discharging `hsegBlk` of
`RunShieldOpenShell.sshC_productionReadyL_epP_openShell` from per-block table & slot arithmetic.

Resolves L68b-3 (`∀ s < 23` bounded slot degrees), L32-1 (transcript-indexed `CoreData`), and
L25-1 (`own` verifying both `cr.root` AND `ClaimTrue` on `cr.pending`) with ZERO upstream edits.
Parameterizes the codec theorem on `hmRows : (Pk k).geom.mRows = 50` so this file builds 100% GREEN
before `RunShieldBlkInst.lean:504` lands `mRows := 50` (where `hmRows` collapses to `rfl`).
Only at most `propext`, `Classical.choice`, `Quot.sound`; zero `sorry`s.
-/
import ZK60Formal.HonestShieldCore
import ZK60Formal.HonestRunBlock
import ZK60Formal.RunShieldOpenShell

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.ProtocolClassify
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestRun
open ZK60.Circuit (gP GF)
open ZK60.Exec.Block (BlockParams Cm Segment SegGeom Geom Core SlotProof CoreCanon CoreShape
  HidingCanon HidingShape SlotCanon encSeg decodeSegment pathsDepth slotShape slotTerms posTag)
open ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape (ClassifyRunPublicP classifyModelP classifySpecP classifySpecP_lt)
open ZK60.RunShape.Shield (shieldS0 ShieldRun shieldRun_valid)

/-! ## 1. `shdP_Pk0` accessors (zero unfolding of `@[irreducible] shdP_Pk0`) -/

section Pk0Accessors

variable (tag : MTag) (ioIn ioOut : ℕ)
  (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
  (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26)

theorem shdP_Pk0_logCols :
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).logCols = 14 := by
  rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk]; rfl

theorem shdP_Pk0_endpointLogN :
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).endpointLogN = 14 := by
  rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk]; rfl

theorem shdP_Pk0_aRows :
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).aRows = 4577 := by
  rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk]; rfl

theorem shdP_Pk0_hRows :
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).hRows = 4390 := by
  rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk]; rfl

theorem shdP_Pk0_aPath :
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).aPath = 16 := by
  rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk]; rfl

theorem shdP_Pk0_hPath :
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).hPath = 16 := by
  rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk]; rfl

theorem shdP_Pk0_maskPath :
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).maskPath = 12 := by
  rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk]; rfl

theorem shdP_Pk0_preChecks :
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).preChecks = .ok () := by
  rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk]; rfl

theorem shdP_Pk0_draws :
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).draws = Exec.Block.R13.shieldDraws := by
  rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk]; rfl

theorem shdP_Pk0_nFunctionals :
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).nFunctionals = 34 := by
  rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk]; rfl

theorem shdP_Pk0_maskVerify :
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).maskVerify = maskField tag 23 := by
  rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk]; rfl

theorem shdP_Pk0_pcsVerify :
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).pcsVerify = ZK60.Exec.R13.pcsFieldR13 tag shdP_rowsOf := by
  rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk]; rfl

theorem shdP_Pk0_slots :
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).geom.slots = Exec.Block.R13.shieldSlots := by
  rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk]; rfl

theorem shdP_Pk0_terms :
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).geom.terms = Exec.Block.R13.shieldTerms := by
  rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk]; rfl

theorem shdP_Pk0_slots_length :
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).geom.slots.length = 23 := by
  rw [shdP_Pk0_slots tag ioIn ioOut checkOpening Rp hR k hk]; decide

theorem shdP_Pk0_slotD_bounds (s : ℕ)
    (hs : s < (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).geom.slots.length) :
    1 ≤ slotD (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) s
      ∧ slotD (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) s < gP := by
  rw [shdP_Pk0_slots_length tag ioIn ioOut checkOpening Rp hR k hk] at hs
  obtain ⟨h1, h5, -, -⟩ := Exec.Block.R13.shield_slot_facts s hs
  change 1 ≤ ((shdP_Pk0 tag ioIn ioOut checkOpening Rp k).geom.slots.getD s (0, 0, 0)).2.2
    ∧ ((shdP_Pk0 tag ioIn ioOut checkOpening Rp k).geom.slots.getD s (0, 0, 0)).2.2 < gP
  rw [shdP_Pk0_slots tag ioIn ioOut checkOpening Rp hR k hk]
  exact ⟨h1, lt_of_le_of_lt h5 (by norm_num [gP])⟩

/-- Target R13 block geometry with `mRows = 50` (23 masks → `2*23 + 4 = 50` rows). -/
def shdP_blkGeom50 : Geom :=
  Exec.Block.R13.geom Exec.Block.R13.shieldSlots Exec.Block.R13.shieldTerms 50 36 4577 9 4390

theorem shdP_sgeom50_facts (k : ℕ) (hk : k < 26) :
    let sg := Exec.Block.R13.segGeom shdP_blkGeom50 0 28 (k + 1) 38 2
    sg.g.slots.length = sg.g.terms.length
      ∧ sg.g.maskDom ≤ 2 ^ 64 ∧ sg.g.blk.encCols ≤ 2 ^ 64 ∧ sg.ed.encCols ≤ 2 ^ 64
      ∧ sg.commits = true ∧ sg.closes = false ∧ sg.incoming = (2, 38)
      ∧ sg.len ≤ sg.g.ceiling := by
  intro sg
  have hcm : sg.commits = true := by
    simp [sg, Exec.Block.SegGeom.commits, Exec.Block.R13.segGeom]; omega
  have hcl : sg.closes = false := by
    simp [sg, Exec.Block.SegGeom.closes, Exec.Block.R13.segGeom]; omega
  have hinc : sg.incoming = (2, 38) := rfl
  refine ⟨by decide, by decide, by decide, by decide, hcm, hcl, hinc, ?_⟩
  unfold Exec.Block.SegGeom.len
  rw [hcm, hcl, hinc]
  decide

end Pk0Accessors

/-! ## 2. Concrete `paths` hook (`shdP_segPaths`) and `vdChk` discharge -/

section BlockHooks

/-- Concrete `paths` hook (`segment_paths_are_the_tree_depth`) for Shieldstral R13 blocks. -/
def shdP_segPaths {Hdr : Type} (_ : ClsStmt Hdr) (sg : Segment) : Except String Unit := do
  pathsDepth "A" 16 0 sg.core.aOpen.columns
  pathsDepth "H" 16 0 sg.core.hOpen.columns
  pathsDepth "M" 12 0 sg.core.maskOpen.columns
  pathsDepth "B" 16 0 sg.inOpen.columns

theorem shdP_segPaths_ok {Hdr : Type} (s : ClsStmt Hdr) (sg : Segment)
    (hA : pathsDepth "A" 16 0 sg.core.aOpen.columns = .ok ())
    (hH : pathsDepth "H" 16 0 sg.core.hOpen.columns = .ok ())
    (hM : pathsDepth "M" 12 0 sg.core.maskOpen.columns = .ok ())
    (hB : pathsDepth "B" 16 0 sg.inOpen.columns = .ok ()) :
    shdP_segPaths s sg = .ok () := by
  unfold shdP_segPaths
  exact bind_ok_of hA (bind_ok_of hH (bind_ok_of hM hB))

theorem shdP_vdChk_ok {Hdr Salt Coins : Type}
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (Lq : ℕ) (P : RunP Hdr (shieldS0.Tok → ℕ) Coins)
    (Cin : PlaneCommit (shieldS0.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (base : Coins → Salt) (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (G : QB Lq → Dig) (x : shieldS0.Tok → ℕ) (c : Coins) (k : ℕ)
    (hx : (classifyModelP Rp).admissible x)
    (hchk0 : check0 (clsStmtOfP Rp Lq P Cin h64 hr base G x c) k = .ok ()) :
    vdChk check0 (clsStmtOfP Rp Lq P Cin h64 hr base G x c) k = .ok () := by
  obtain ⟨b, hb⟩ := hx
  have hv := (classifySpecP_lt Rp (shieldRun_valid Rp hR hinPub houtPub hweights) hb).2
  have hver : (clsStmtOfP Rp Lq P Cin h64 hr base G x c).verdict ≤ 1 := by
    change ((classifySpecP Rp x).getD 0) ≤ 1
    rw [hb]; exact hv
  rw [vdChk_eq check0 _ k hver]
  exact hchk0

end BlockHooks

/-! ## 3. Bounded R13 core verifier completeness & transcript-aware `D12aBlockPT` -/

section BoundedBlockR13

/-- Bounded R13 block core completeness (fixes L68b-3 without upstream edits, reusing `blockVerify_of_prove_bd`). -/
theorem shdP_blockVerify_of_tables_r13 (H : HIn → Dig) (tag : MTag) (P : BlockParams) (S : ℕ)
    (rowsOf : Cm → ℕ)
    (hPm : P.maskVerify = maskField tag S) (hPp : P.pcsVerify = Exec.R13.pcsFieldR13 tag rowsOf)
    (hdA : P.aPath = 16) (hdH : P.hPath = 16) (hdM : P.maskPath = 12)
    (C : CoreTables P) (t : Tr) (R : CoreRun)
    (h : coreProve H P (coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 S P C t) t = .ok R)
    (hdeg : ∀ s, s < P.geom.slots.length → 1 ≤ slotD P s ∧ slotD P s < gP)
    (hpre : P.preChecks = .ok ())
    (hslots : SlotsSum H P shdP_U C.slot
      (coreB H P (coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 S P C t) t).1
      (coreG H P (coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 S P C t) t).1
      (coreA H P (coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 S P C t) t).1
      P.geom.slots.length [] 0 {}
      (coreT3 H P (coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 S P C t) t))
    (hMh : MHonest shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) C.M S)
    (hMt : ∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
      (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK shdP_U
        = mTrue (algebraMap GF shdP_K (rootFp 9).toGF)
            (wtOf shdP_U ((R.acc.fs ++ R.acc.hostFs).map toMF) S) (mA shdP_U C.M S) i)
    (hrA : rowsOf .a = C.TA.rows.length)
    (hcA : ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 16) C.TA)
    (htA : ∀ c ∈ R.acc.claims.a, ClaimTrue shdP_U (2 ^ 14) 14 C.TA.rows (toZClaim c))
    (hrH : rowsOf .h = (C.TH
      (coreB H P (coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 S P C t) t).1
      (coreG H P (coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 S P C t) t).1
      (coreA H P (coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 S P C t) t).1).rows.length)
    (hcH : ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 16)
      (C.TH
        (coreB H P (coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 S P C t) t).1
        (coreG H P (coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 S P C t) t).1
        (coreA H P (coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 S P C t) t).1))
    (htH : ∀ c ∈ R.acc.claims.h ++ [P.logupSumClaim], ClaimTrue shdP_U (2 ^ 14) 14
      (C.TH
        (coreB H P (coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 S P C t) t).1
        (coreG H P (coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 S P C t) t).1
        (coreA H P (coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 S P C t) t).1).rows (toZClaim c)) :
    Exec.Block.blockVerify H P R.core t = .ok ((R.acc.claims.inp, R.acc.claims.out), R.t7) := by
  let D := coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 S P C t
  obtain ⟨-, -, -, -, -, -, hhR, -, hmo, hao, hho⟩ := coreProve_ok H P D t R h
  have hm1 : R.core.maskOpen = (bMask H tag shdP_U shdP_hbij C.M S (R.acc.fs ++ R.acc.hostFs) R.t4).1 :=
    congrArg Prod.fst hmo
  have hm2 : R.t5 = (bMask H tag shdP_U shdP_hbij C.M S (R.acc.fs ++ R.acc.hostFs) R.t4).2 :=
    congrArg Prod.snd hmo
  have ha1 : R.core.aOpen = (bOpen H tag Exec.R13.r13Prm 16 C.TA R.acc.claims.a R.t5).1 :=
    congrArg Prod.fst hao
  have ha2 : R.t6 = (bOpen H tag Exec.R13.r13Prm 16 C.TA R.acc.claims.a R.t5).2 :=
    congrArg Prod.snd hao
  have hTH := C.TH (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1
  have hho' : (R.core.hOpen, R.t7) = bOpen H tag Exec.R13.r13Prm 16 hTH (R.acc.claims.h ++ [P.logupSumClaim]) R.t6 := hho
  have hh1 : R.core.hOpen = (bOpen H tag Exec.R13.r13Prm 16 hTH (R.acc.claims.h ++ [P.logupSumClaim]) R.t6).1 :=
    congrArg Prod.fst hho'
  have hh2 : R.t7 = (bOpen H tag Exec.R13.r13Prm 16 hTH (R.acc.claims.h ++ [P.logupSumClaim]) R.t6).2 :=
    congrArg Prod.snd hho'
  have hhR' : R.core.hRoot = rootOf H tag 16 hTH := hhR
  have hnn : Exec.R13.r13Prm.nn = 2 ^ 16 := by norm_num [PcsPrm.nn, Exec.R13.r13Prm]
  have hnQ : 0 < Exec.R13.r13Prm.nQ := by norm_num [Exec.R13.r13Prm]
  refine blockVerify_of_prove_bd H P shdP_U shdP_hU D t R h hdeg hpre ?_ ?_ ?_ hslots ?_ ?_ ?_
  · rw [hdA, ha1]; exact bOpen_pathsDepth H tag "A" Exec.R13.r13Prm 16 hnn hnQ C.TA _ _ 0
  · rw [hdH, hh1]; exact bOpen_pathsDepth H tag "H" Exec.R13.r13Prm 16 hnn hnQ hTH _ _ 0
  · rw [hdM, hm1]; exact bMask_pathsDepth H tag shdP_U shdP_hbij "M" C.M S _ _ 0
  · rw [hPm, hm1, hm2]
    exact maskField_of_prove H tag shdP_U shdP_hbij shdP_hU C.M S hMh _ hMt _
  · rw [hPp, ha1, ha2]
    exact pcsFieldR13_of_prove H tag shdP_U shdP_hU rowsOf .a C.TA hrA hcA _ htA _
  · rw [hPp, hhR', hh1, hh2]
    exact pcsFieldR13_of_prove H tag shdP_U shdP_hU rowsOf .h hTH hrH hcH _ htH _

/-- Transcript-aware per-block table bundle (`TB_prev` = `B_k`, `TB_next` = `B_{k+1}`, `coreT` = `CoreTables (Pk k)`). -/
structure ShdBlkTables (Pk : ℕ → BlockParams) (k : ℕ) where
  TB_prev : Table
  TB_next : Table
  coreT : CoreTables (Pk k)

/-- Transcript-aware honest block segment prover (fixes L32-1 & L25-1 `own` cleanly). -/
open Classical in
noncomputable def shdP_blkSegP {St X Coins : Type} (tag : MTag) (Pk : ℕ → BlockParams)
    (sgeom : St → ℕ → SegGeom) (check : St → ℕ → Except String Unit)
    (paths : St → Segment → Except String Unit) (digest : St → ℕ → Dig)
    (bRows bLogN : ℕ → ℕ)
    (bndCheck : St → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → St → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr → Except String Tr)
    (W : (HIn → Dig) → St → X → Coins → (k : ℕ) → ShdBlkTables Pk k)
    (k : ℕ) : SegP St X Coins where
  run H s x c bnd start cr t :=
    let w := W H s x c k
    let own := decide (cr.root = rootOf H tag 16 w.TB_prev
      ∧ ∀ cl ∈ cr.pending, ClaimTrue shdP_U (2 ^ 14) 14 w.TB_prev.rows (toZClaim cl))
    if own then
      let bRoot := rootOf H tag 16 w.TB_next
      let tFrame := blockFrame (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) H s k bRoot t
      let D := coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 (Pk k) w.coreT tFrame
      match coreProve H (Pk k) D tFrame with
      | .error _ => .error ()
      | .ok R =>
        match bndCheck s k (cr.pending ++ R.acc.claims.inp) R.t7 with
        | .error _ => .error ()
        | .ok _ =>
          let io := HonestOpen.bOpen H tag Exec.R13.r13Prm 16 w.TB_prev (cr.pending ++ R.acc.claims.inp) R.t7
          .ok (fun e => encSeg bnd (sgeom s k).l (sgeom s k).k start ⟨some bRoot, R.core, io.1, none⟩ e,
            ⟨R.acc.claims.out, bRoot⟩, io.2)
    else .error ()

/-- **Block `k` `SegComplete` bridge** (`k < 26`): discharges `hsegBlk k` of
`RunShieldOpenShell.sshC_productionReadyL_epP_openShell` from per-block table & slot arithmetic contracts!
Parameterizes `hgeom50 : (Pk k).geom = shdP_blkGeom50` (becomes `rfl` once `RunShieldBlkInst.lean:504` flips `23 → 50`). -/
theorem shdP_blk_segComplete {Γ Hdr Coins : Type} (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (check : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (adm : (shieldS0.Tok → ℕ) → Prop) (hOf : Γ → HIn → Dig)
    (stOf : Γ → (shieldS0.Tok → ℕ) → Coins → ClsStmt Hdr)
    (Pk : ℕ → BlockParams)
    (k : ℕ) (hk : k < 26)
    (hgeom50 : (Pk k).geom = shdP_blkGeom50)
    (hPm : (Pk k).maskVerify = maskField tag 23)
    (hPp : (Pk k).pcsVerify = Exec.R13.pcsFieldR13 tag shdP_rowsOf)
    (hdA : (Pk k).aPath = 16) (hdH : (Pk k).hPath = 16) (hdM : (Pk k).maskPath = 12)
    (hpre : (Pk k).preChecks = .ok ())
    (W : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → (k' : ℕ) → ShdBlkTables Pk k')
    (hCheck : ∀ g x c, adm x → check (stOf g x c) k = .ok ())
    (hArith : ∀ g x c cr t R, adm x →
      let H := hOf g
      let st := stOf g x c
      let w := W H st x c k
      let bRoot := rootOf H tag 16 w.TB_next
      let tFrame := blockFrame (d12aBlockProf Pk (shdP_sgeom Hdr Pk) check shdP_segPaths digest
        (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38)) H st k bRoot t
      let D := coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 (Pk k) w.coreT tFrame
      let bga := ((coreB H (Pk k) D tFrame).1, (coreG H (Pk k) D tFrame).1, (coreA H (Pk k) D tFrame).1)
      let TH := w.coreT.TH bga.1 bga.2.1 bga.2.2
      coreProve H (Pk k) D tFrame = .ok R →
      bndCheck st k (cr.pending ++ R.acc.claims.inp) R.t7 = .ok () →
      (∀ s hist acc df ch0, (w.coreT.slot.scalar s hist acc df ch0).Canon)
      ∧ (∀ s hist acc df ch0 rho, ∀ w' ∈ w.coreT.slot.terms s hist acc df ch0 rho, w'.Canon)
      ∧ (∀ j, ∀ w' ∈ w.coreT.TA.cols j, w'.Canon)
      ∧ (∀ j, ∀ w' ∈ TH.cols j, w'.Canon)
      ∧ (∀ j, ∀ w' ∈ w.TB_prev.cols j, w'.Canon)
      ∧ (∀ j, (w.coreT.TA.cols j).length = w.coreT.TA.rows.length)
      ∧ (∀ j, (TH.cols j).length = TH.rows.length)
      ∧ (∀ j, (w.TB_prev.cols j).length = w.TB_prev.rows.length)
      ∧ (groupZclaims (R.acc.claims.a.map toZClaim) w.coreT.TA.rows.length 14).length = 36
      ∧ (groupZclaims ((R.acc.claims.h ++ [(Pk k).logupSumClaim]).map toZClaim) TH.rows.length 14).length = 9
      ∧ (groupZclaims ((cr.pending ++ R.acc.claims.inp).map toZClaim) w.TB_prev.rows.length 14).length = 2
      ∧ SlotsSum H (Pk k) shdP_U w.coreT.slot bga.1 bga.2.1 bga.2.2 23 [] 0 {} (coreT3 H (Pk k) D tFrame)
      ∧ MHonest shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) w.coreT.M 23
      ∧ (∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
          (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK shdP_U
            = mTrue (algebraMap GF shdP_K (rootFp 9).toGF)
                (wtOf shdP_U ((R.acc.fs ++ R.acc.hostFs).map toMF) 23) (mA shdP_U w.coreT.M 23) i)
      ∧ 4577 = w.coreT.TA.rows.length
      ∧ ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 16) w.coreT.TA
      ∧ (∀ cl ∈ R.acc.claims.a, ClaimTrue shdP_U (2 ^ 14) 14 w.coreT.TA.rows (toZClaim cl))
      ∧ 4390 = TH.rows.length
      ∧ ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 16) TH
      ∧ (∀ cl ∈ R.acc.claims.h ++ [(Pk k).logupSumClaim], ClaimTrue shdP_U (2 ^ 14) 14 TH.rows (toZClaim cl))
      ∧ 38 = w.TB_prev.rows.length
      ∧ ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 16) w.TB_prev
      ∧ (∀ cl ∈ R.acc.claims.inp, ClaimTrue shdP_U (2 ^ 14) 14 w.TB_prev.rows (toZClaim cl))) :
    SegComplete adm hOf stOf
      (shdP_blkSegP tag Pk (shdP_sgeom Hdr Pk) check shdP_segPaths digest
        (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38) W k)
      (blockSeg (d12aBlockProf Pk (shdP_sgeom Hdr Pk) check shdP_segPaths digest
        (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38)) k) := by
  let prof := d12aBlockProf Pk (shdP_sgeom Hdr Pk) check shdP_segPaths digest
    (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38)
  intro g x c bnd cr t enc cr' t' hx hrun
  let H := hOf g
  let st := stOf g x c
  let w := W H st x c k
  let bRoot := rootOf H tag 16 w.TB_next
  let tFrame := blockFrame prof H st k bRoot t
  let D := coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 (Pk k) w.coreT tFrame
  let bga := ((coreB H (Pk k) D tFrame).1, (coreG H (Pk k) D tFrame).1, (coreA H (Pk k) D tFrame).1)
  let TH := w.coreT.TH bga.1 bga.2.1 bga.2.2
  dsimp only [shdP_blkSegP] at hrun
  split_ifs at hrun with hown
  obtain ⟨hcrRoot, hcrPend⟩ := of_decide_eq_true hown
  cases hR' : coreProve H (Pk k) D tFrame with
  | error _ => rw [hR'] at hrun; cases hrun
  | ok R =>
    rw [hR'] at hrun
    cases hbc : bndCheck st k (cr.pending ++ R.acc.claims.inp) R.t7 with
    | error _ => rw [hbc] at hrun; cases hrun
    | ok _ =>
      rw [hbc] at hrun
      simp only [Except.ok.injEq, Prod.mk.injEq] at hrun
      obtain ⟨rfl, rfl, rfl⟩ := hrun
      obtain ⟨hSc, hTm, hcanA, hcanH, hcanB, hlenA, hlenH, hlenB,
        hgA, hgH, hgB, hslots, hMh, hMt, hrA, hcA, htA, hrH, hcH, htH, hrB, hcB, htB_inp⟩ :=
        hArith g x c cr t R hx hR' hbc
      obtain ⟨hs, -, -, -, -, -, -, -, hmo, hao, hho⟩ := coreProve_ok H (Pk k) D tFrame R hR'
      have hm1 : R.core.maskOpen = (bMask H tag shdP_U shdP_hbij w.coreT.M 23 (R.acc.fs ++ R.acc.hostFs) R.t4).1 :=
        congrArg Prod.fst hmo
      have ha1 : R.core.aOpen = (bOpen H tag Exec.R13.r13Prm 16 w.coreT.TA R.acc.claims.a R.t5).1 :=
        congrArg Prod.fst hao
      have hho' : (R.core.hOpen, R.t7) = bOpen H tag Exec.R13.r13Prm 16 TH (R.acc.claims.h ++ [(Pk k).logupSumClaim]) R.t6 := hho
      have hh1 : R.core.hOpen = (bOpen H tag Exec.R13.r13Prm 16 TH (R.acc.claims.h ++ [(Pk k).logupSumClaim]) R.t6).1 :=
        congrArg Prod.fst hho'
      let io := HonestOpen.bOpen H tag Exec.R13.r13Prm 16 w.TB_prev (cr.pending ++ R.acc.claims.inp) R.t7
      have hnn : Exec.R13.r13Prm.nn = 2 ^ 16 := by norm_num [Exec.R13.r13Prm, PcsPrm.nn]
      have hslen23 : (Pk k).geom.slots.length = 23 := by rw [hgeom50]; decide
      have hdeg : ∀ s, s < (Pk k).geom.slots.length → 1 ≤ slotD (Pk k) s ∧ slotD (Pk k) s < gP := by
        intro s hs
        rw [hslen23] at hs
        obtain ⟨h1, h5, -, -⟩ := Exec.Block.R13.shield_slot_facts s hs
        change 1 ≤ ((Pk k).geom.slots.getD s (0, 0, 0)).2.2 ∧ ((Pk k).geom.slots.getD s (0, 0, 0)).2.2 < gP
        rw [hgeom50]
        exact ⟨h1, lt_of_le_of_lt h5 (by norm_num [gP])⟩
      have hslots' : SlotsSum H (Pk k) shdP_U w.coreT.slot bga.1 bga.2.1 bga.2.2
          (Pk k).geom.slots.length [] 0 {} (coreT3 H (Pk k) D tFrame) := by
        rw [hslen23]; exact hslots
      have hbv := shdP_blockVerify_of_tables_r13 H tag (Pk k) 23 shdP_rowsOf
        hPm hPp hdA hdH hdM w.coreT tFrame R hR' hdeg hpre hslots' hMh hMt hrA hcA htA hrH hcH htH
      have hsgEq : shdP_sgeom Hdr Pk st k = Exec.Block.R13.segGeom shdP_blkGeom50 0 28 (k + 1) 38 2 := by
        unfold shdP_sgeom; rw [hgeom50]
      obtain ⟨hgt, hdom, henc, hee, hcm, hcl, hinc, hceil⟩ := shdP_sgeom50_facts k hk
      obtain ⟨hslLen, hslCan, hslSh⟩ := slotsProve_shape_canon H (Pk k) shdP_U w.coreT.slot
        bga.1 bga.2.1 bga.2.2 hSc hTm (Pk k).geom.slots.length [] 0 {} (coreT3 H (Pk k) D tFrame)
        R.core.slots R.recs R.acc R.t4 hslots' hs
      have hnQ : 0 < Exec.R13.r13Prm.nQ := by norm_num [Exec.R13.r13Prm]
      have hcan : CoreCanon R.core := by
        refine ⟨hslCan, ?_, ?_, ?_⟩
        · rw [hm1]; exact bMask_canon H tag shdP_U shdP_hbij w.coreT.M 23 _ _
        · rw [ha1]; exact bOpen_canon H tag Exec.R13.r13Prm 16 hnn hnQ w.coreT.TA hcanA _ _
        · rw [hh1]; exact bOpen_canon H tag Exec.R13.r13Prm 16 hnn hnQ TH hcanH _ _
      have hmSh := bMask_shape H tag shdP_U shdP_hbij w.coreT.M 23 (R.acc.fs ++ R.acc.hostFs) R.t4
      have haSh := bOpen_shape H tag Exec.R13.r13Prm 16 hnn hnQ w.coreT.TA hlenA R.acc.claims.a R.t5
      have hhSh := bOpen_shape H tag Exec.R13.r13Prm 16 hnn hnQ TH hlenH (R.acc.claims.h ++ [(Pk k).logupSumClaim]) R.t6
      have hbSh := bOpen_shape H tag Exec.R13.r13Prm 16 hnn hnQ w.TB_prev hlenB (cr.pending ++ R.acc.claims.inp) R.t7
      have hsh : CoreShape (shdP_sgeom Hdr Pk st k).g R.core := by
        rw [hsgEq]
        refine ⟨by rw [hslLen, hslen23]; rfl, fun i p s t' hp hs' ht' =>
            hslSh i p s t' hp (by rw [Nat.zero_add, hgeom50]; exact hs') (by rw [Nat.zero_add, hgeom50]; exact ht'),
          ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
        · rw [hm1]; exact hmSh.1
        · rw [hm1]; exact hmSh.2.1
        · rw [hm1]; exact hmSh.2.2.1
        · rw [hm1]; exact hmSh.2.2.2
        · intro o ho
          simp only [List.mem_cons, List.not_mem_nil, or_false] at ho
          rcases ho with rfl | rfl
          · rw [ha1]
            exact ⟨haSh.2.2.1, haSh.2.1, haSh.2.2.2.1, fun col hcol => ⟨(haSh.2.2.2.2 col hcol).1, (haSh.2.2.2.2 col hcol).2.2⟩⟩
          · rw [hh1]
            exact ⟨hhSh.2.2.1, hhSh.2.1, hhSh.2.2.2.1, fun col hcol => ⟨(hhSh.2.2.2.2 col hcol).1, (hhSh.2.2.2.2 col hcol).2.2⟩⟩
        · rw [ha1, haSh.1, hgA]; rfl
        · rw [hh1, hhSh.1, hgH]; rfl
        · intro col hcol; rw [ha1] at hcol
          exact (haSh.2.2.2.2 col hcol).2.1.trans hrA.symm
        · intro col hcol; rw [hh1] at hcol
          exact (hhSh.2.2.2.2 col hcol).2.1.trans hrH.symm
      have hic : HidingCanon io.1 := bOpen_canon H tag Exec.R13.r13Prm 16 hnn hnQ w.TB_prev hcanB _ _
      have his : HidingShape (shdP_sgeom Hdr Pk st k).ed (shdP_sgeom Hdr Pk st k).incoming.1
          (shdP_sgeom Hdr Pk st k).incoming.2 io.1 := by
        rw [hsgEq]
        refine ⟨hbSh.1.trans hgB, hbSh.2.1, hbSh.2.2.1, hbSh.2.2.2.1, fun col hcol => ?_⟩
        obtain ⟨hj, hclen, hcp⟩ := hbSh.2.2.2.2 col hcol
        exact ⟨hj, hclen.trans hrB.symm, hcp⟩
      have hdec : decodeSegment (shdP_sgeom Hdr Pk st k) bnd (posTag H t)
            (encSeg bnd (shdP_sgeom Hdr Pk st k).l (shdP_sgeom Hdr Pk st k).k (posTag H t)
              ⟨some bRoot, R.core, io.1, none⟩ (posTag H io.2))
          = .ok (⟨some bRoot, R.core, io.1, none⟩, posTag H io.2) :=
        d12a_codec_of_enc (shdP_sgeom Hdr Pk st k) (by rw [hsgEq]; exact hgt)
          (by rw [hsgEq]; exact hdom) (by rw [hsgEq]; exact henc) (by rw [hsgEq]; exact hee)
          bnd bRoot R.core io.1 hcan hsh (by rw [hsgEq]; exact hcm) hic his (by rw [hsgEq]; exact hcl)
          (fun start e => encSeg_length (shdP_sgeom Hdr Pk st k) (by rw [hsgEq]; exact hgt) bnd start
            ⟨some bRoot, R.core, io.1, none⟩ e hsh (by rw [hsgEq, hcm]; rfl) his (by rw [hsgEq]; exact hcl) rfl)
          (by rw [hsgEq]; exact hceil) (posTag H t) (posTag H io.2)
      have hpaths : shdP_segPaths st ⟨some bRoot, R.core, io.1, none⟩ = .ok () :=
        shdP_segPaths_ok st _
          (by rw [ha1]; exact bOpen_pathsDepth H tag "A" Exec.R13.r13Prm 16 hnn hnQ w.coreT.TA _ _ 0)
          (by rw [hh1]; exact bOpen_pathsDepth H tag "H" Exec.R13.r13Prm 16 hnn hnQ TH _ _ 0)
          (by rw [hm1]; exact bMask_pathsDepth H tag shdP_U shdP_hbij "M" w.coreT.M 23 _ _ 0)
          (bOpen_pathsDepth H tag "B" Exec.R13.r13Prm 16 hnn hnQ w.TB_prev _ _ 0)
      have hcb : cbBndOpen tag 38 H st k cr.root (cr.pending ++ R.acc.claims.inp) io.1 R.t7 = .ok io.2 := by
        unfold cbBndOpen
        have htAll : ∀ cl ∈ cr.pending ++ R.acc.claims.inp, ClaimTrue shdP_U (2 ^ 14) 14 w.TB_prev.rows (toZClaim cl) := by
          intro cl hcl
          rcases List.mem_append.mp hcl with h1 | h2
          · exact hcrPend cl h1
          · exact htB_inp cl h2
        rw [hcrRoot, hrB]
        exact pcsAt_of_prove H tag shdP_U shdP_hU 14 2 256 (by norm_num) (by norm_num) w.TB_prev
          (by simpa only [show (2 : ℕ) ^ 14 * 2 ^ 2 = 2 ^ 16 by norm_num] using hcB) _ htAll _
      -- Assemble `blockSeg (d12aBlockProf ...) k` acceptance step-by-step
      dsimp only [blockSeg, d12aBlockProf]
      refine bind_ok_of (hCheck g x c hx) ?_
      refine bind_ok_of hdec ?_
      refine bind_ok_of hpaths ?_
      refine bind_ok_of (a := bRoot) rfl ?_
      refine bind_ok_of hbv ?_
      refine bind_ok_of hbc ?_
      refine bind_ok_of hcb ?_
      rfl

end BoundedBlockR13

end ZK60.HonestShield
