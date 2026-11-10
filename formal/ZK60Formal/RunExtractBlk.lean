/-
D63 lane L45 (2026-11-10), part 6: **the blocks' `A`, `H`, `M` facts with the extraction discharged** (finding
L43-2 at the blocks).

L43's `rh_blk_opA`, `rh_blk_opH`, `rh_blk_M` prove `RhOpW` / `RhMW` at every block part of an accepted run given the
extraction at "the opening the verifier opened"; their statements hide WHICH opening (`∃ zo root, RhXOk … zo root →
…`), so the extraction cannot be supplied to them from outside. Here the same facts are proved with the extraction
discharged inside, from `¬ EvXR` with the run's own Merkle work: the opening is block `k`'s segment's, the segment read
off the receipt alone is the decoded one (`rx_blk_seg`, `rx_blockData_inj`, `rx_blk_coreOf`: `rxCoreOf` IS block `k`'s
core), its root is among `EvXR`'s roots (block `k`'s three), its columns are checked by block `k`'s Merkle work
(`blockV` at `256, 256, 256, 16, 16, 12`), and the run's transcript absorbs its root at a fixed position
(`rx_blkPre_get`: `A` at `5`, `M` at `8`, `H` at `12` after the part's start).

* `rx_blockData_inj`, **`rx_blk_seg`**, **`rx_blk_coreOf`**, `rx_blkPre_get`;
* **`rx_blk_opA`**, **`rx_blk_opH`**, **`rx_blk_M`**: `RhOpW` for block `k`'s `A` and `H`, `RhMW` for its `M`, at part
  `k + 1`, OUTRIGHT (`k < 26`).

The proofs follow L43's `rh_blk_*` step for step.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunExtractStage

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape)

/-- **A block's single phase absorbs `A`'s root at `5`, `M`'s at `8`, `H`'s at `12`** (the frame's five absorbs, then
L9's `rootOps`). -/
theorem rx_blkPre_get (P : Block.BlockParams) (k : ℕ) (dg root : Dig) (rows logN : ℕ) (core : Block.Core)
    (sl : List Block.SlotProof) :
    (rtBlockFrame k dg root rows logN ++ (Block.rootOps P core ++ Block.fullOps P 0 sl))[5]?
        = some (Op.absorb Block.labA core.aRoot.toList)
      ∧ (rtBlockFrame k dg root rows logN ++ (Block.rootOps P core ++ Block.fullOps P 0 sl))[5 + 3]?
        = some (Op.absorb Block.labM core.maskRoot.toList)
      ∧ (rtBlockFrame k dg root rows logN ++ (Block.rootOps P core ++ Block.fullOps P 0 sl))[5 + 7]?
        = some (Op.absorb Block.labH core.hRoot.toList) :=
  ⟨rfl, rfl, rfl⟩

/-- **A block's data determine its roots and openings.** -/
theorem rx_blockData_inj (P : Block.BlockParams) (k : ℕ) (dg : Dig) (rows logN : ℕ) (sg sg' : Block.Segment)
    (h : rtBlockData P k dg rows logN sg = rtBlockData P k dg rows logN sg') :
    sg.core.aRoot = sg'.core.aRoot ∧ sg.core.hRoot = sg'.core.hRoot ∧ sg.core.maskRoot = sg'.core.maskRoot
      ∧ sg.core.aOpen = sg'.core.aOpen ∧ sg.core.hOpen = sg'.core.hOpen ∧ sg.core.maskOpen = sg'.core.maskOpen
      ∧ sg.inOpen = sg'.inOpen := by
  have hpre := congrArg RtData.pre h
  obtain ⟨a1, m1, h1⟩ := rx_blkPre_get P k dg (sg.bRoot.getD zeroDig) rows logN sg.core sg.core.slots
  obtain ⟨a2, m2, h2⟩ := rx_blkPre_get P k dg (sg'.bRoot.getD zeroDig) rows logN sg'.core sg'.core.slots
  have eA := congrArg (fun l : List Op => l[5]?) hpre
  have eM := congrArg (fun l : List Op => l[5 + 3]?) hpre
  have eH := congrArg (fun l : List Op => l[5 + 7]?) hpre
  simp only [rtBlockData] at eA eM eH
  rw [a1, a2] at eA
  rw [m1, m2] at eM
  rw [h1, h2] at eH
  simp only [Option.some.injEq, Op.absorb.injEq, true_and] at eA eM eH
  exact ⟨Subtype.ext eA, Subtype.ext eH, Subtype.ext eM, congrArg RtData.aO h, congrArg RtData.hO h,
    congrArg RtData.mo h, congrArg RtData.xO h⟩

section Blk

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag)
  {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
  (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **The block segment read off the bytes alone has the verifier's data**: on an accepted run, at a part `i` that is
D12a block `k`, if the run's reading gives block `k`'s data of a segment `sg`, then the segment read off the bytes alone
(`rtSegOf`) exists and has the same data. -/
theorem rx_blk_seg (R : RtRun V key domain Lq) (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt)
    (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i k : ℕ) (p : RtPart)
    (hσi : R.σs[i]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k p))
    (sg : Block.Segment)
    (hrdi : (R.rd (s, segs)).2[i]? = some (rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg)) :
    ∃ sg' : Block.Segment, rtSegOf (sgeom s k) (segs.getD i []) = some sg'
      ∧ rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg'
        = rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg := by
  obtain ⟨-, -, -, -, -, -, -, hrd⟩ := R.accept_part (liftH G) s segs hE i _ hσi
  rw [hrdi] at hrd
  have hrd' : rtBlockRd Pk sgeom digest bRows bLogN k s (segs.getD i [])
      = rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg := (Option.some.inj hrd).symm
  unfold rtBlockRd at hrd'
  rcases hso : rtSegOf (sgeom s k) (segs.getD i []) with _ | sg'
  · rw [hso] at hrd'
    have hl := congrArg (fun d : RtData => d.pre.length) hrd'
    simp [RtData.nil, rtBlockData, rtBlockFrame] at hl
  · rw [hso] at hrd'
    exact ⟨sg', rfl, hrd'⟩

/-- **`rxCoreOf` IS block `k`'s core** (its roots and openings), on an accepted run. -/
theorem rx_blk_coreOf (R : RtRun V key domain Lq) (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt)
    (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (k : ℕ) (p : RtPart)
    (hσi : R.σs[k + 1]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k p))
    (sg : Block.Segment)
    (hrdi : (R.rd (s, segs)).2[k + 1]? = some (rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg)) :
    (rxCoreOf sgeom (s, segs) k).2.aRoot = sg.core.aRoot ∧ (rxCoreOf sgeom (s, segs) k).2.hRoot = sg.core.hRoot
      ∧ (rxCoreOf sgeom (s, segs) k).2.maskRoot = sg.core.maskRoot
      ∧ (rxCoreOf sgeom (s, segs) k).2.aOpen = sg.core.aOpen ∧ (rxCoreOf sgeom (s, segs) k).2.hOpen = sg.core.hOpen
      ∧ (rxCoreOf sgeom (s, segs) k).2.maskOpen = sg.core.maskOpen := by
  obtain ⟨sg', hso, hdat⟩ := rx_blk_seg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R G s segs hE (k + 1) k
    p hσi sg hrdi
  obtain ⟨e1, e2, e3, e4, e5, e6, -⟩ := rx_blockData_inj (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg' sg hdat
  have hc : (rxCoreOf sgeom (s, segs) k).2 = sg'.core := by
    show ((rtSegOf (sgeom s k) (segs.getD (k + 1) [])).map Block.Segment.core).getD rxCore0 = sg'.core
    rw [hso]
    rfl
  rw [hc]
  exact ⟨e1, e2, e3, e4, e5, e6⟩

/-- Block `k`'s roots are the run's (`EvXR`'s `rootsV (coreOf o k)`). -/
theorem rx_blkRoot_mem (rx : ClsStmt Hdr × ClsReceipt → List Dig) (o : ClsStmt Hdr × ClsReceipt) (k : ℕ)
    (hk : k < 26) :
    (rxCoreOf sgeom o k).2.aRoot ∈ runRoots 26 (rxCoreOf sgeom) rx o
      ∧ (rxCoreOf sgeom o k).2.hRoot ∈ runRoots 26 (rxCoreOf sgeom) rx o
      ∧ (rxCoreOf sgeom o k).2.maskRoot ∈ runRoots 26 (rxCoreOf sgeom) rx o :=
  ⟨mem_runRoots 26 _ rx o k hk _ (by simp [rootsV]), mem_runRoots 26 _ rx o k hk _ (by simp [rootsV]),
    mem_runRoots 26 _ rx o k hk _ (by simp [rootsV])⟩

/-- **BLOCK `k`'S `A` MEETS `RhOpW` OUTRIGHT** at part `k + 1` of an accepted run outside the run's Merkle event (with
the run's own Merkle work). L43's `rh_blk_opA` with the extraction discharged. -/
theorem rx_blk_opA (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (k : ℕ) (hk : k < 26)
    (bp : RtBlk Lq (Pk k)) (wX gX mX : ℕ)
    (hσi : R.σs[k + 1]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
      (rtBlockPart (Pk k) bp.S (bp.nA + bp.pA.rows) bp.pA.m (bp.nH + bp.pH.rows) bp.pH.m wX gX mX)))
    (hgeo : ∀ s, (sgeom s k).g = (Pk k).geom) (hA : RkPcsR13 U tag bp.pA)
    (incG outcG : Hdr → StageGeom) (Lb : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt))
    (hrun : A.run G = (s, segs))
    (hX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hfit : 8 * bp.pA.rows ≤ Lq) :
    Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (rkR13 bp.pA.rows (R.pf.off (k + 1) + 5)) bp.nA
      (fun hdr => (rkAccBlk (Pk k) (R.pf.off (k + 1) + 5)
        (R.pf.off (k + 1) + (rtBlockPart (Pk k) bp.S (bp.nA + bp.pA.rows) bp.pA.m (bp.nH + bp.pH.rows) bp.pH.m wX gX
          mX).pre) hdr).claims.a)
      (R.pf.off (k + 1) + (R.pf.part (k + 1)).oA) (R.pf.off (k + 1) + (R.pf.part (k + 1)).oBA)
      (R.pf.off (k + 1) + (R.pf.part (k + 1)).oA + (bp.nA + bp.pA.rows)) (A.runLog G).2 G (R.tr G (s, segs))) := by
  set i := k + 1 with hiDef
  set p := rtBlockPart (Pk k) bp.S (bp.nA + bp.pA.rows) bp.pA.m (bp.nH + bp.pH.rows) bp.pH.m wX gX mX with hpDef
  have hS : p.S = bp.S := rfl
  have hwA : p.wA = bp.nA + bp.pA.rows := rfl
  have hmA : p.mA = 64 := hA.hm U tag
  obtain ⟨cr, sg, root, ic, oc, t₂, t', bga, rs, acc, tM, tA, tH, -, hcan, -, hshape, hrdi, hpi, hroot, hbs, -, hmv,
    hpa, -, -, -, -, hread⟩ :=
    rk_blk_run Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv G s segs hE i k p hσi bp hgeo
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  have hpart : R.pf.part i = p := rh_part_eq R.pf i p hpi
  have hpd : RtPartOk Lq p (rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg) :=
    rk_forall₂_getElem? hgood.2.2.2 i p _ hpi hrdi
  have hplen : (rtBlockFrame k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1))
      ++ (Block.rootOps (Pk k) sg.core ++ Block.fullOps (Pk k) 0 sg.core.slots)).length = p.pre := hpd.1
  have hgA : sg.core.aOpen.groupVecs.length = p.gA := hpd.2.2.1
  have hgd : sg.bRoot.getD zeroDig = root := by rw [hroot]; rfl
  have hd1 : ∀ j, j < sg.core.slots.length → 1 ≤ (Block.slotShape (Pk k) j).2.2 :=
    fun j hj => (bp.hgeomL j (by rw [hshape.1] at hj; exact hj)).1
  have htM := blockSlots_tr (liftH G) (Pk k) sg.core _ bga rs acc tM hbs hd1
  rw [bp.hPm] at hmv
  have htA := (rt_mask_tr bp.tag bp.S (liftH G) _ _ _ tM tA hmv).1
  set u := opsStps (rtBlockFrame k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1))
      ++ (Block.rootOps (Pk k) sg.core ++ Block.fullOps (Pk k) 0 sg.core.slots)) ++ mStps p.S sg.core.maskOpen
    with huDef
  obtain ⟨tk, td, trem, tctr, tst⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood i p
    (rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg) hpi hrdi u
    (pcsStps p.wA p.mA sg.core.aOpen ++ (pcsStps p.wH p.mH sg.core.hOpen ++ pcsStps p.wX p.mX sg.inOpen))
    (by rw [huDef]; simp only [rtPartStps, rtBlockData, List.append_assoc])
  have hul : (stpsOps u).length = p.oA := by
    rw [huDef, stpsOps_append, List.length_append, stpsOps_opsStps, stpsOps_mStps_length, hplen]
    rfl
  have hlpre : (stpsOps (rtPre R.pf (R.rd (s, segs)) i)).length = R.pf.off i := (rtPre_facts Lq R.pf _ hgood i).2.1
  have hle : R.pf.off i + p.pre ≤ R.pf.off i + p.oA := by simp only [RtPart.oA]; omega
  have hp12 : 5 + 7 < p.pre := by
    rw [← hplen]
    simp only [List.length_append, Block.rootOps_length, rtBlockFrame, List.length_cons, List.length_nil]
    omega
  -- the root's position on the run's transcript
  have habs : Block.absAt ((R.tr G (s, segs)).take (R.pf.off i + p.oA)) (R.pf.off i + 5)
      = some sg.core.aRoot.toList := by
    have tk' := tk
    rw [hul, stpsOps_append] at tk'
    refine rs_absAt_run (R.tr G (s, segs)) (liftH G) _ _ (stpsOps u) (R.pf.off i) _ _ 5 Block.labA _ tk' hlpre
      (by omega) (by omega) ?_
    have hlt : 5 < (rtBlockFrame k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1))
        ++ (Block.rootOps (Pk k) sg.core ++ Block.fullOps (Pk k) 0 sg.core.slots)).length := by omega
    rw [huDef, stpsOps_append, stpsOps_opsStps, List.getElem?_append_left hlt]
    exact (rx_blkPre_get (Pk k) k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1)) sg.core
      sg.core.slots).1
  -- the extraction
  obtain ⟨cA, -, -, cAo, -, -⟩ := rx_blk_coreOf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R G s segs hE
    k p hσi sg hrdi
  have hmem : sg.core.aRoot ∈ runRoots 26 (rxCoreOf sgeom) (rxRoots incG outcG sgeom Lb) (A.run G) := by
    have h0 := (rx_blkRoot_mem sgeom (rxRoots incG outcG sgeom Lb) (A.run G) k hk).1
    rw [hrun] at h0 ⊢
    rw [cA] at h0
    exact h0
  have hzo : (rxCoreOf sgeom (A.run G) k).2.aOpen = sg.core.aOpen := by rw [hrun]; exact cAo
  have hx := rx_xok tag Lq h64 key domain hs hL _ _ _ A G hX (rkR13 bp.pA.rows (R.pf.off i + 5)) _ sg.core.aOpen
    sg.core.aRoot hmem habs hfit
    (rx_q_blkA tag Lq h64 (rxCoreOf sgeom) (rxVx tag Lq h64 incG outcG sgeom Lb) A G k hk sg.core.aOpen hzo)
  have htA' : runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i ++ u))
      = tA := by
    rw [htA, htM, huDef, hgd, hS]
    simp only [stpsOps_append, stpsOps_opsStps, runOps_append, List.append_assoc]
  have hlen := rh_take_len key domain Lq R.pf R.rd G (s, segs) hgood i u tk
  rw [hul] at td trem hlen
  rw [htA'] at td tctr
  rw [List.append_assoc, hmA, hwA] at td tst
  have hcnt := (bp.hcnt (liftH G) sg.core _ bga rs acc tM hbs hshape.1).1
  refine ⟨?_⟩
  rw [hpart]
  have hok := bp.pA.hok () (liftH G) sg.core.aRoot acc.claims.a sg.core.aOpen tA tH hpa
  rw [hA.htag, hA.hpt, hA.hlc'] at hok
  exact
    { tA := tA
      tH := tH
      zo := sg.core.aOpen
      c := R.pf.sqAt i + stpsSq u
      rs := (pcsStps p.wH p.mH sg.core.hOpen ++ pcsStps p.wX p.mX sg.inOpen)
        ++ rtPartsStps (R.pf.parts.drop (i + 1)) ((R.rd (s, segs)).2.drop (i + 1))
      prm := bp.pA.prm
      ev := bp.pA.ev
      cl := acc.claims.a
      root := sg.core.aRoot
      hpl := hlen
      hdrop := td
      hpre := trem
      hctr := tctr
      hst := tst
      hvpos := rfl
      haB := by
        have hr13 : (rkR13 bp.pA.rows (R.pf.off i + 5)).rows = bp.pA.rows := rfl
        rw [hgA, hr13]
        simp only [RtPart.oBA]
        omega
      hlc := hA.hlc
      hqp := by rw [bp.pA.hqp, hA.hQ]; rfl
      hnQ := by rw [bp.pA.hnQ, hA.hQ]; rfl
      hnn := by rw [bp.pA.hnn, hA.hN]; rfl
      hpow := by rw [bp.pA.hnn]; exact bp.pA.hpow
      hQ0 := by norm_num [rkR13]
      hm := by norm_num [rkR13]
      hspec := hA.hspec
      hok := hok
      hcnt := hcnt
      hrd := by
        show (rkAccBlk (Pk k) (R.pf.off i + 5) (R.pf.off i + p.pre)
          ((R.tr G (s, segs)).take (R.pf.off i + p.oA))).claims.a = acc.claims.a
        rw [hread ((R.tr G (s, segs)).take (R.pf.off i + p.oA)) (rk_take_take_le _ _ _ hle)]
      hcan := hcan.2.2.1
      hcolX := hx }

/-- **BLOCK `k`'S `H` MEETS `RhOpW` OUTRIGHT** (with the LogUp sum claim, root at `off + 12`). L43's `rh_blk_opH` with
the extraction discharged. -/
theorem rx_blk_opH (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (k : ℕ) (hk : k < 26)
    (bp : RtBlk Lq (Pk k)) (wX gX mX : ℕ)
    (hσi : R.σs[k + 1]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
      (rtBlockPart (Pk k) bp.S (bp.nA + bp.pA.rows) bp.pA.m (bp.nH + bp.pH.rows) bp.pH.m wX gX mX)))
    (hgeo : ∀ s, (sgeom s k).g = (Pk k).geom) (hH : RkPcsR13 U tag bp.pH)
    (incG outcG : Hdr → StageGeom) (Lb : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt))
    (hrun : A.run G = (s, segs))
    (hX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hfit : 8 * bp.pH.rows ≤ Lq) :
    Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (rkR13 bp.pH.rows (R.pf.off (k + 1) + (5 + 7)))
      bp.nH
      (fun hdr => (rkAccBlk (Pk k) (R.pf.off (k + 1) + 5)
        (R.pf.off (k + 1) + (rtBlockPart (Pk k) bp.S (bp.nA + bp.pA.rows) bp.pA.m (bp.nH + bp.pH.rows) bp.pH.m wX gX
          mX).pre) hdr).claims.h ++ [(Pk k).logupSumClaim])
      (R.pf.off (k + 1) + (R.pf.part (k + 1)).oH) (R.pf.off (k + 1) + (R.pf.part (k + 1)).oBH)
      (R.pf.off (k + 1) + (R.pf.part (k + 1)).oH + (bp.nH + bp.pH.rows)) (A.runLog G).2 G (R.tr G (s, segs))) := by
  set i := k + 1 with hiDef
  set p := rtBlockPart (Pk k) bp.S (bp.nA + bp.pA.rows) bp.pA.m (bp.nH + bp.pH.rows) bp.pH.m wX gX mX with hpDef
  have hS : p.S = bp.S := rfl
  have hwA : p.wA = bp.nA + bp.pA.rows := rfl
  have hmA' : p.mA = bp.pA.m := rfl
  have hwH : p.wH = bp.nH + bp.pH.rows := rfl
  have hmH : p.mH = 64 := hH.hm U tag
  obtain ⟨cr, sg, root, ic, oc, t₂, t', bga, rs, acc, tM, tA, tH, -, hcan, -, hshape, hrdi, hpi, hroot, hbs, -, hmv,
    hpa, hph, -, -, -, hread⟩ :=
    rk_blk_run Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv G s segs hE i k p hσi bp hgeo
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  have hpart : R.pf.part i = p := rh_part_eq R.pf i p hpi
  have hpd : RtPartOk Lq p (rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg) :=
    rk_forall₂_getElem? hgood.2.2.2 i p _ hpi hrdi
  have hplen : (rtBlockFrame k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1))
      ++ (Block.rootOps (Pk k) sg.core ++ Block.fullOps (Pk k) 0 sg.core.slots)).length = p.pre := hpd.1
  have hgA : sg.core.aOpen.groupVecs.length = p.gA := hpd.2.2.1
  have hgH : sg.core.hOpen.groupVecs.length = p.gH := hpd.2.2.2.1
  have hgd : sg.bRoot.getD zeroDig = root := by rw [hroot]; rfl
  have hd1 : ∀ j, j < sg.core.slots.length → 1 ≤ (Block.slotShape (Pk k) j).2.2 :=
    fun j hj => (bp.hgeomL j (by rw [hshape.1] at hj; exact hj)).1
  have htM := blockSlots_tr (liftH G) (Pk k) sg.core _ bga rs acc tM hbs hd1
  rw [bp.hPm] at hmv
  have htA := (rt_mask_tr bp.tag bp.S (liftH G) _ _ _ tM tA hmv).1
  obtain ⟨hcA, hcH, -, -⟩ := bp.hcnt (liftH G) sg.core _ bga rs acc tM hbs hshape.1
  have htH := (bp.pA.tr () (liftH G) sg.core.aRoot acc.claims.a sg.core.aOpen tA tH hpa bp.nA hcA).1
  set u := opsStps (rtBlockFrame k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1))
      ++ (Block.rootOps (Pk k) sg.core ++ Block.fullOps (Pk k) 0 sg.core.slots)) ++ mStps p.S sg.core.maskOpen
      ++ pcsStps p.wA p.mA sg.core.aOpen
    with huDef
  obtain ⟨tk, td, trem, tctr, tst⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood i p
    (rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg) hpi hrdi u
    (pcsStps p.wH p.mH sg.core.hOpen ++ pcsStps p.wX p.mX sg.inOpen)
    (by rw [huDef]; simp only [rtPartStps, rtBlockData, List.append_assoc])
  have hul : (stpsOps u).length = p.oH := by
    rw [huDef, stpsOps_append, stpsOps_append, List.length_append, List.length_append, stpsOps_opsStps,
      stpsOps_mStps_length, stpsOps_pcsStps_length, hplen, hgA]
    simp only [RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have hlpre : (stpsOps (rtPre R.pf (R.rd (s, segs)) i)).length = R.pf.off i := (rtPre_facts Lq R.pf _ hgood i).2.1
  have hle : R.pf.off i + p.pre ≤ R.pf.off i + p.oH := by
    simp only [RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have hp12 : 5 + 7 < p.pre := by
    rw [← hplen]
    simp only [List.length_append, Block.rootOps_length, rtBlockFrame, List.length_cons, List.length_nil]
    omega
  have habs : Block.absAt ((R.tr G (s, segs)).take (R.pf.off i + p.oH)) (R.pf.off i + (5 + 7))
      = some sg.core.hRoot.toList := by
    have tk' := tk
    rw [hul, stpsOps_append] at tk'
    refine rs_absAt_run (R.tr G (s, segs)) (liftH G) _ _ (stpsOps u) (R.pf.off i) _ _ _ Block.labH _ tk' hlpre
      (by omega) (by omega) ?_
    have hlt : 5 + 7 < (rtBlockFrame k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1))
        ++ (Block.rootOps (Pk k) sg.core ++ Block.fullOps (Pk k) 0 sg.core.slots)).length := by omega
    rw [huDef, stpsOps_append, stpsOps_append, stpsOps_opsStps, List.append_assoc, List.getElem?_append_left hlt]
    exact (rx_blkPre_get (Pk k) k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1)) sg.core
      sg.core.slots).2.2
  obtain ⟨-, cH, -, -, cHo, -⟩ := rx_blk_coreOf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R G s segs hE
    k p hσi sg hrdi
  have hmem : sg.core.hRoot ∈ runRoots 26 (rxCoreOf sgeom) (rxRoots incG outcG sgeom Lb) (A.run G) := by
    have h0 := (rx_blkRoot_mem sgeom (rxRoots incG outcG sgeom Lb) (A.run G) k hk).2.1
    rw [hrun] at h0 ⊢
    rw [cH] at h0
    exact h0
  have hzo : (rxCoreOf sgeom (A.run G) k).2.hOpen = sg.core.hOpen := by rw [hrun]; exact cHo
  have hx := rx_xok tag Lq h64 key domain hs hL _ _ _ A G hX (rkR13 bp.pH.rows (R.pf.off i + (5 + 7))) _
    sg.core.hOpen sg.core.hRoot hmem habs hfit
    (rx_q_blkH tag Lq h64 (rxCoreOf sgeom) (rxVx tag Lq h64 incG outcG sgeom Lb) A G k hk sg.core.hOpen hzo)
  have htH' : runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i ++ u))
      = tH := by
    rw [htH, htA, htM, huDef, hgd, hS, hwA, hmA']
    simp only [stpsOps_append, stpsOps_opsStps, runOps_append, List.append_assoc]
  have hlen := rh_take_len key domain Lq R.pf R.rd G (s, segs) hgood i u tk
  rw [hul] at td trem hlen
  rw [htH'] at td tctr
  rw [List.append_assoc, hmH, hwH] at td tst
  refine ⟨?_⟩
  rw [hpart]
  have hok := bp.pH.hok () (liftH G) sg.core.hRoot (acc.claims.h ++ [(Pk k).logupSumClaim]) sg.core.hOpen tH t₂ hph
  rw [hH.htag, hH.hpt, hH.hlc'] at hok
  exact
    { tA := tH
      tH := t₂
      zo := sg.core.hOpen
      c := R.pf.sqAt i + stpsSq u
      rs := pcsStps p.wX p.mX sg.inOpen
        ++ rtPartsStps (R.pf.parts.drop (i + 1)) ((R.rd (s, segs)).2.drop (i + 1))
      prm := bp.pH.prm
      ev := bp.pH.ev
      cl := acc.claims.h ++ [(Pk k).logupSumClaim]
      root := sg.core.hRoot
      hpl := hlen
      hdrop := td
      hpre := trem
      hctr := tctr
      hst := tst
      hvpos := rfl
      haB := by
        have hr13H : (rkR13 bp.pH.rows (R.pf.off i + (5 + 7))).rows = bp.pH.rows := rfl
        rw [hgH, hr13H]
        simp only [RtPart.oBH]
        omega
      hlc := hH.hlc
      hqp := by rw [bp.pH.hqp, hH.hQ]; rfl
      hnQ := by rw [bp.pH.hnQ, hH.hQ]; rfl
      hnn := by rw [bp.pH.hnn, hH.hN]; rfl
      hpow := by rw [bp.pH.hnn]; exact bp.pH.hpow
      hQ0 := by norm_num [rkR13]
      hm := by norm_num [rkR13]
      hspec := hH.hspec
      hok := hok
      hcnt := hcH
      hrd := by
        show (rkAccBlk (Pk k) (R.pf.off i + 5) (R.pf.off i + p.pre)
          ((R.tr G (s, segs)).take (R.pf.off i + p.oH))).claims.h ++ [(Pk k).logupSumClaim]
            = acc.claims.h ++ [(Pk k).logupSumClaim]
        rw [hread ((R.tr G (s, segs)).take (R.pf.off i + p.oH)) (rk_take_take_le _ _ _ hle)]
      hcan := hcan.2.2.2
      hcolX := hx }

/-- **BLOCK `k`'S `M` MEETS `RhMW` OUTRIGHT** (root at `off + 8`). L43's `rh_blk_M` with the extraction
discharged. -/
theorem rx_blk_M (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (k : ℕ) (hk : k < 26)
    (bp : RtBlk Lq (Pk k)) (wX gX mX : ℕ)
    (hσi : R.σs[k + 1]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
      (rtBlockPart (Pk k) bp.S (bp.nA + bp.pA.rows) bp.pA.m (bp.nH + bp.pH.rows) bp.pH.m wX gX mX)))
    (hgeo : ∀ s, (sgeom s k).g = (Pk k).geom) (htag : bp.tag = tag)
    (incG outcG : Hdr → StageGeom) (Lb : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt))
    (hrun : A.run G = (s, segs))
    (hX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hfit : 8 * (2 * bp.S + 4) ≤ Lq) :
    Nonempty (RhMW tag Lq h64 key domain hs hL (rtW R.pf.sqs) bp.S (Pk k).nFunctionals (R.pf.off (k + 1) + (5 + 3))
      (fun hdr => (rkAccBlk (Pk k) (R.pf.off (k + 1) + 5)
        (R.pf.off (k + 1) + (rtBlockPart (Pk k) bp.S (bp.nA + bp.pA.rows) bp.pA.m (bp.nH + bp.pH.rows) bp.pH.m wX gX
          mX).pre) hdr).fs
        ++ (rkAccBlk (Pk k) (R.pf.off (k + 1) + 5)
        (R.pf.off (k + 1) + (rtBlockPart (Pk k) bp.S (bp.nA + bp.pA.rows) bp.pA.m (bp.nH + bp.pH.rows) bp.pH.m wX gX
          mX).pre) hdr).hostFs)
      (R.pf.off (k + 1) + (R.pf.part (k + 1)).pre) (A.runLog G).2 G (R.tr G (s, segs))) := by
  set i := k + 1 with hiDef
  set p := rtBlockPart (Pk k) bp.S (bp.nA + bp.pA.rows) bp.pA.m (bp.nH + bp.pH.rows) bp.pH.m wX gX mX with hpDef
  have hS : p.S = bp.S := rfl
  obtain ⟨cr, sg, root, ic, oc, t₂, t', bga, rs, acc, tM, tA, tH, -, hcan, -, hshape, hrdi, hpi, hroot, hbs, hnf, hmv,
    -, -, -, -, -, hread⟩ :=
    rk_blk_run Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv G s segs hE i k p hσi bp hgeo
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  have hpart : R.pf.part i = p := rh_part_eq R.pf i p hpi
  have hpd : RtPartOk Lq p (rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg) :=
    rk_forall₂_getElem? hgood.2.2.2 i p _ hpi hrdi
  have hplen : (rtBlockFrame k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1))
      ++ (Block.rootOps (Pk k) sg.core ++ Block.fullOps (Pk k) 0 sg.core.slots)).length = p.pre := hpd.1
  have hgd : sg.bRoot.getD zeroDig = root := by rw [hroot]; rfl
  have hd1 : ∀ j, j < sg.core.slots.length → 1 ≤ (Block.slotShape (Pk k) j).2.2 :=
    fun j hj => (bp.hgeomL j (by rw [hshape.1] at hj; exact hj)).1
  have htM := blockSlots_tr (liftH G) (Pk k) sg.core _ bga rs acc tM hbs hd1
  rw [bp.hPm] at hmv
  have hok : MaskOk (liftH G) bp.tag (rootFp 9) (rootFp 12) sg.core.maskRoot bp.S
      ((acc.fs ++ acc.hostFs).map toMF) (toMO sg.core.maskOpen) tM tA := by
    rw [maskField, mapErr_ok, w16r2MCheck_ok_iff] at hmv
    exact hmv
  rw [htag] at hok
  set u := opsStps (rtBlockFrame k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1))
      ++ (Block.rootOps (Pk k) sg.core ++ Block.fullOps (Pk k) 0 sg.core.slots)) with huDef
  obtain ⟨tk, td, trem, tctr, tst⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood i p
    (rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg) hpi hrdi u
    (mStps p.S sg.core.maskOpen ++ (pcsStps p.wA p.mA sg.core.aOpen ++ (pcsStps p.wH p.mH sg.core.hOpen
      ++ pcsStps p.wX p.mX sg.inOpen)))
    (by rw [huDef]; simp only [rtPartStps, rtBlockData])
  have hul : (stpsOps u).length = p.pre := by
    rw [huDef, stpsOps_opsStps, hplen]
  have hlpre : (stpsOps (rtPre R.pf (R.rd (s, segs)) i)).length = R.pf.off i := (rtPre_facts Lq R.pf _ hgood i).2.1
  have hp12 : 5 + 7 < p.pre := by
    rw [← hplen]
    simp only [List.length_append, Block.rootOps_length, rtBlockFrame, List.length_cons, List.length_nil]
    omega
  have habs : Block.absAt ((R.tr G (s, segs)).take (R.pf.off i + p.pre)) (R.pf.off i + (5 + 3))
      = some sg.core.maskRoot.toList := by
    have tk' := tk
    rw [hul, stpsOps_append] at tk'
    refine rs_absAt_run (R.tr G (s, segs)) (liftH G) _ _ (stpsOps u) (R.pf.off i) _ _ _ Block.labM _ tk' hlpre
      (by omega) (by omega) ?_
    rw [huDef, stpsOps_opsStps]
    exact (rx_blkPre_get (Pk k) k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1)) sg.core
      sg.core.slots).2.1
  obtain ⟨-, -, cM, -, -, cMo⟩ := rx_blk_coreOf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R G s segs hE
    k p hσi sg hrdi
  have hmem : sg.core.maskRoot ∈ runRoots 26 (rxCoreOf sgeom) (rxRoots incG outcG sgeom Lb) (A.run G) := by
    have h0 := (rx_blkRoot_mem sgeom (rxRoots incG outcG sgeom Lb) (A.run G) k hk).2.2
    rw [hrun] at h0 ⊢
    rw [cM] at h0
    exact h0
  have hmo : (rxCoreOf sgeom (A.run G) k).2.maskOpen = sg.core.maskOpen := by rw [hrun]; exact cMo
  have hx := rx_xmok tag Lq h64 key domain hs hL _ _ _ A G hX bp.S _ _ tM tA sg.core.maskOpen sg.core.maskRoot
    ((acc.fs ++ acc.hostFs).map toMF) hok hmem habs hfit
    (rx_q_blkM tag Lq h64 (rxCoreOf sgeom) (rxVx tag Lq h64 incG outcG sgeom Lb) A G k hk sg.core.maskOpen hmo)
  have htM' : runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i ++ u))
      = tM := by
    rw [htM, huDef, hgd]
    simp only [stpsOps_append, stpsOps_opsStps, runOps_append]
  have hlen := rh_take_len key domain Lq R.pf R.rd G (s, segs) hgood i u tk
  rw [hul] at td trem hlen
  rw [htM'] at td tctr
  rw [List.append_assoc, hS] at td tst
  refine ⟨?_⟩
  rw [hpart]
  exact
    { tM := tM
      tA := tA
      mo := sg.core.maskOpen
      c := R.pf.sqAt i + stpsSq u
      rs := (pcsStps p.wA p.mA sg.core.aOpen ++ (pcsStps p.wH p.mH sg.core.hOpen ++ pcsStps p.wX p.mX sg.inOpen))
        ++ rtPartsStps (R.pf.parts.drop (i + 1)) ((R.rd (s, segs)).2.drop (i + 1))
      root := sg.core.maskRoot
      fs := acc.fs ++ acc.hostFs
      hpl := hlen
      hdrop := td
      hpre := trem
      hctr := tctr
      hst := tst
      hcan := hcan.2.1
      hok := hok
      hk := hnf
      hrd := by
        show (rkAccBlk (Pk k) (R.pf.off i + 5) (R.pf.off i + p.pre) ((R.tr G (s, segs)).take (R.pf.off i + p.pre))).fs
          ++ (rkAccBlk (Pk k) (R.pf.off i + 5) (R.pf.off i + p.pre)
            ((R.tr G (s, segs)).take (R.pf.off i + p.pre))).hostFs = acc.fs ++ acc.hostFs
        rw [hread ((R.tr G (s, segs)).take (R.pf.off i + p.pre)) (rk_take_take_le _ _ _ le_rfl)]
      hcols := hx }

end Blk

end ZK60.ProtocolClassify
