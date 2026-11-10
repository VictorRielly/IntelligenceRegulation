/-
D63 lane L55 (2026-11-10), part 6: **the closing opening of a block part that follows a block part MEETS `RhOpW`
OUTRIGHT** (the top theorem's `hopX1` at parts `2 … Lb`; the brief's deliverable 2).

At part `k + 2` (block `k + 1`), the closing opening is the boundary opening of `B_{k+1}`, the commitment block `k`
(part `k + 1`) made: the run's `bndOpen` against the root block `k` handed on, on the claims block `k` left pending
followed by block `k + 1`'s incoming claims. With the carry tied to the previous part (`cb_two`, `cb_blk_run_of`):

* `cb_blockData_bRoot`: a block's data determine its boundary root (the frame's third absorb);
* **`cb_blk_opX`**: on an accepted run outside L45's Merkle event `EvXR` (no new event: `rxRoots` lists every block's
  boundary root and `rxVx` checks every block's `in_open`, finding L55-3), block `k + 1`'s closing opening meets
  `RhOpW` at the boundary geometry (`rkR13 rows (off (k + 1) + 2)`: the root absorbed ALONE at the third absorb of
  part `k + 1`'s frame), with `bp0.nOut + bp1.nIn` claims read by the two blocks' readers (`rkAccBlk`: block `k`'s
  outgoing, then block `k + 1`'s incoming), given the boundary opening's numbers at R13 (`RkPcsR13`, met by the code's
  `bndOpen`: `cbBndPcs_r13`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunCloseBRun
import ZK60Formal.RunCloseBPcs
import ZK60Formal.RunExtractBlk

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)

/-- **A block's data determine its boundary root** (the frame's third absorb, `absorb_root("B", …)`). -/
theorem cb_blockData_bRoot (P : Block.BlockParams) (k : ℕ) (dg : Dig) (rows logN : ℕ) (sg sg' : Block.Segment)
    (h : rtBlockData P k dg rows logN sg = rtBlockData P k dg rows logN sg') :
    sg.bRoot.getD zeroDig = sg'.bRoot.getD zeroDig := by
  have hpre := congrArg RtData.pre h
  have e := congrArg (fun l : List Op => l[2]?) hpre
  have g1 : (rtBlockFrame k dg (sg.bRoot.getD zeroDig) rows logN
      ++ (Block.rootOps P sg.core ++ Block.fullOps P 0 sg.core.slots))[2]?
        = some (Op.absorb labB (sg.bRoot.getD zeroDig).toList) := rfl
  have g2 : (rtBlockFrame k dg (sg'.bRoot.getD zeroDig) rows logN
      ++ (Block.rootOps P sg'.core ++ Block.fullOps P 0 sg'.core.slots))[2]?
        = some (Op.absorb labB (sg'.bRoot.getD zeroDig).toList) := rfl
  simp only [rtBlockData] at e
  rw [g1, g2] at e
  simp only [Option.some.injEq, Op.absorb.injEq, true_and] at e
  exact Subtype.ext e

section Blk

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag)
  {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
  (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **BLOCK `k + 1`'S CLOSING OPENING (THE BOUNDARY BLOCK `k` COMMITTED) MEETS `RhOpW` OUTRIGHT** at part `k + 2` of
an accepted run outside the run's Merkle event, at the boundary geometry with the root absorbed at
`off (k + 1) + 2`, its claims block `k`'s outgoing then block `k + 1`'s incoming. -/
theorem cb_blk_opX (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (k : ℕ) (hk : k + 1 < 26)
    (bp0 : RtBlk Lq (Pk k)) (bp1 : RtBlk Lq (Pk (k + 1))) (p0 p1 : RtPart)
    (hσ0 : R.σs[k + 1]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k p0))
    (hσ1 : R.σs[k + 1 + 1]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen (k + 1) p1))
    (hgeo0 : ∀ s, (sgeom s k).g = (Pk k).geom) (hgeo1 : ∀ s, (sgeom s (k + 1)).g = (Pk (k + 1)).geom)
    (hS1 : p1.S = bp1.S) (hwA1 : p1.wA = bp1.nA + bp1.pA.rows) (hmA1 : p1.mA = bp1.pA.m)
    (hwH1 : p1.wH = bp1.nH + bp1.pH.rows) (hmH1 : p1.mH = bp1.pH.m)
    (pX : RtPcs (fun (s : ClsStmt Hdr) H root cl o t => bndOpen H s (k + 1) root cl o t)) (hX : RkPcsR13 U tag pX)
    (hwX1 : p1.wX = bp0.nOut + bp1.nIn + pX.rows) (hmX1 : p1.mX = pX.m)
    (incG outcG : Hdr → StageGeom) (Lb : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt))
    (hrun : A.run G = (s, segs))
    (hXev : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hfit : 8 * pX.rows ≤ Lq) :
    Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (rkR13 pX.rows (R.pf.off (k + 1) + 2))
      (bp0.nOut + bp1.nIn)
      (fun hdr => (rkAccBlk (Pk k) (R.pf.off (k + 1) + 5) (R.pf.off (k + 1) + p0.pre) hdr).claims.out
        ++ (rkAccBlk (Pk (k + 1)) (R.pf.off (k + 1 + 1) + 5) (R.pf.off (k + 1 + 1) + p1.pre) hdr).claims.inp)
      (R.pf.off (k + 1 + 1) + (R.pf.part (k + 1 + 1)).oX) (R.pf.off (k + 1 + 1) + (R.pf.part (k + 1 + 1)).oBX)
      (R.pf.off (k + 1 + 1) + (R.pf.part (k + 1 + 1)).oX + ((bp0.nOut + bp1.nIn) + pX.rows)) (A.runLog G).2 G
      (R.tr G (s, segs))) := by
  -- the two steps on one carry, and each block as the verifier saw it
  obtain ⟨cr, cr', cr'', t, t', t'', -, ht, h1, -, ht', h2⟩ := cb_two R (liftH G) s segs hE (k + 1) _ _ hσ0 hσ1
  obtain ⟨sg0, root0, ic0, oc0, t₂0, bga0, rs0, acc0, tM0, tA0, tH0, -, -, hshape0, hrdi0, hpi0, hroot0, hbs0,
    -, -, -, -, -, -, -, hcr', hread0⟩ :=
    cb_blk_run_of Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv G s segs hE (k + 1) k p0 hσ0 bp0 hgeo0
      cr cr' t t' ht h1
  obtain ⟨sg1, root1, ic1, oc1, t₂, bga, rs, acc, tM, tA, tH, -, hcanX1, hshape1, hrdi1, hpi1, hroot1, hbs1,
    -, hmv1, hpa1, hph1, hic1, -, hbo1, -, hread1⟩ :=
    cb_blk_run_of Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv G s segs hE (k + 1 + 1) (k + 1) p1 hσ1
      bp1 hgeo1 cr' cr'' t' t'' ht' h2
  subst hcr'
  subst hic1
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  have hpart : R.pf.part (k + 1 + 1) = p1 := rh_part_eq R.pf _ p1 hpi1
  have hpart0 : R.pf.part (k + 1) = p0 := rh_part_eq R.pf _ p0 hpi0
  -- part k + 2's data and steps
  have hpd : RtPartOk Lq p1
      (rtBlockData (Pk (k + 1)) (k + 1) (digest s (k + 1)) (bRows (k + 1 + 1)) (bLogN (k + 1 + 1)) sg1) :=
    rk_forall₂_getElem? hgood.2.2.2 _ p1 _ hpi1 hrdi1
  have hplen : (rtBlockFrame (k + 1) (digest s (k + 1)) (sg1.bRoot.getD zeroDig) (bRows (k + 1 + 1))
      (bLogN (k + 1 + 1)) ++ (Block.rootOps (Pk (k + 1)) sg1.core ++ Block.fullOps (Pk (k + 1)) 0 sg1.core.slots)).length
        = p1.pre := hpd.1
  have hgA : sg1.core.aOpen.groupVecs.length = p1.gA := hpd.2.2.1
  have hgH : sg1.core.hOpen.groupVecs.length = p1.gH := hpd.2.2.2.1
  have hgX : sg1.inOpen.groupVecs.length = p1.gX := hpd.2.2.2.2.1
  have hgd : sg1.bRoot.getD zeroDig = root1 := by rw [hroot1]; rfl
  have hd1 : ∀ j, j < sg1.core.slots.length → 1 ≤ (Block.slotShape (Pk (k + 1)) j).2.2 :=
    fun j hj => (bp1.hgeomL j (by rw [hshape1.1] at hj; exact hj)).1
  have htM := blockSlots_tr (liftH G) (Pk (k + 1)) sg1.core _ bga rs acc tM hbs1 hd1
  rw [bp1.hPm] at hmv1
  have htA := (rt_mask_tr bp1.tag bp1.S (liftH G) _ _ _ tM tA hmv1).1
  obtain ⟨hcA, hcH, hcI, -⟩ := bp1.hcnt (liftH G) sg1.core _ bga rs acc tM hbs1 hshape1.1
  have htH := (bp1.pA.tr () (liftH G) sg1.core.aRoot acc.claims.a sg1.core.aOpen tA tH hpa1 bp1.nA hcA).1
  have ht₂ := (bp1.pH.tr () (liftH G) sg1.core.hRoot (acc.claims.h ++ [(Pk (k + 1)).logupSumClaim]) sg1.core.hOpen tH t₂
    hph1 bp1.nH hcH).1
  set u := opsStps (rtBlockFrame (k + 1) (digest s (k + 1)) (sg1.bRoot.getD zeroDig) (bRows (k + 1 + 1))
      (bLogN (k + 1 + 1)) ++ (Block.rootOps (Pk (k + 1)) sg1.core ++ Block.fullOps (Pk (k + 1)) 0 sg1.core.slots))
      ++ mStps p1.S sg1.core.maskOpen ++ pcsStps p1.wA p1.mA sg1.core.aOpen ++ pcsStps p1.wH p1.mH sg1.core.hOpen
    with huDef
  obtain ⟨tk, td, trem, tctr, tst⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood (k + 1 + 1) p1
    (rtBlockData (Pk (k + 1)) (k + 1) (digest s (k + 1)) (bRows (k + 1 + 1)) (bLogN (k + 1 + 1)) sg1) hpi1 hrdi1 u
    (pcsStps p1.wX p1.mX sg1.inOpen) (by rw [huDef]; simp only [rtPartStps, rtBlockData, List.append_assoc])
  have hul : (stpsOps u).length = p1.oX := by
    rw [huDef, stpsOps_append, stpsOps_append, stpsOps_append, List.length_append, List.length_append,
      List.length_append, stpsOps_opsStps, stpsOps_mStps_length, stpsOps_pcsStps_length, stpsOps_pcsStps_length,
      hplen, hgA, hgH]
    simp only [RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have hpre1 : runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
      (stpsOps (rtPre R.pf (R.rd (s, segs)) (k + 1 + 1) ++ u)) = t₂ := by
    rw [ht₂, htH, htA, htM, huDef, hgd, hS1, hwA1, hmA1, hwH1, hmH1]
    simp only [stpsOps_append, stpsOps_opsStps, runOps_append, List.append_assoc]
  have hlen := rh_take_len key domain Lq R.pf R.rd G (s, segs) hgood (k + 1 + 1) u tk
  rw [hul] at td trem hlen
  rw [hpre1] at td tctr
  have hmX64 : p1.mX = 64 := by rw [hmX1]; exact hX.hm U tag
  rw [hmX64, hwX1] at td tst
  -- part k + 1's frame absorbs B_{k+1}'s root alone, third
  have hpd0 : RtPartOk Lq p0 (rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg0) :=
    rk_forall₂_getElem? hgood.2.2.2 _ p0 _ hpi0 hrdi0
  obtain ⟨tk0, -, -, -, -⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood (k + 1) p0
    (rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg0) hpi0 hrdi0
    (opsStps (rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg0).pre) _ rfl
  rw [stpsOps_opsStps, hpd0.1, stpsOps_append, stpsOps_opsStps] at tk0
  have hlpre0 : (stpsOps (rtPre R.pf (R.rd (s, segs)) (k + 1))).length = R.pf.off (k + 1) :=
    (rtPre_facts Lq R.pf _ hgood (k + 1)).2.1
  have hpre0 : 5 ≤ p0.pre := by
    rw [← hpd0.1]
    simp only [rtBlockData, List.length_append, rtBlockFrame, List.length_cons, List.length_nil]
    omega
  have hlt0 : k + 1 < R.pf.parts.length := (List.getElem?_eq_some_iff.mp hpi0).1
  have hsucc := RtProf.off_succ R.pf (k + 1) hlt0
  rw [hpart0] at hsucc
  have hle0 : R.pf.off (k + 1) + p0.pre ≤ R.pf.off (k + 1 + 1) + p1.oX := by
    rw [hsucc]
    simp only [RtPart.len, RtPart.oBX, RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have hle1 : R.pf.off (k + 1 + 1) + p1.pre ≤ R.pf.off (k + 1 + 1) + p1.oX := by
    simp only [RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have hgd0 : sg0.bRoot.getD zeroDig = root0 := by rw [hroot0]; rfl
  have habs : Block.absAt ((R.tr G (s, segs)).take (R.pf.off (k + 1 + 1) + p1.oX)) (R.pf.off (k + 1) + 2)
      = some root0.toList := by
    refine rs_absAt_run (R.tr G (s, segs)) (liftH G) _ _ _ (R.pf.off (k + 1)) _ _ 2 labB _ tk0 hlpre0 (by omega)
      (by omega) ?_
    rw [← hgd0]
    rfl
  -- the extraction (L45's event; block k's root and block k + 1's in_open are the run's)
  obtain ⟨sg0', hso0, hdat0⟩ := rx_blk_seg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R G s segs hE
    (k + 1) k p0 hσ0 sg0 hrdi0
  have hb0 := cb_blockData_bRoot (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg0' sg0 hdat0
  have hmem : root0 ∈ runRoots 26 (rxCoreOf sgeom) (rxRoots incG outcG sgeom Lb) (A.run G) := by
    rw [hrun]
    unfold runRoots
    refine List.mem_append_right _ ?_
    unfold rxRoots
    refine List.mem_append_right _ ?_
    rw [List.mem_map]
    refine ⟨k, List.mem_range.mpr (by omega), ?_⟩
    show ((rtSegOf (sgeom s k) (segs.getD (k + 1) [])).bind Block.Segment.bRoot).getD zeroDig = root0
    rw [hso0]
    show sg0'.bRoot.getD zeroDig = root0
    rw [hb0, hgd0]
  obtain ⟨sg1', hso1, hdat1⟩ := rx_blk_seg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R G s segs hE
    (k + 1 + 1) (k + 1) p1 hσ1 sg1 hrdi1
  have hx1 : sg1'.inOpen = sg1.inOpen :=
    (rx_blockData_inj (Pk (k + 1)) (k + 1) (digest s (k + 1)) (bRows (k + 1 + 1)) (bLogN (k + 1 + 1)) sg1' sg1
      hdat1).2.2.2.2.2.2
  have hzo : sg1.inOpen.columns ∈ rxOpenings incG outcG sgeom Lb (A.run G) := by
    rw [hrun]
    unfold rxOpenings
    refine List.mem_append_right _ ?_
    rw [List.mem_map]
    refine ⟨k + 1, List.mem_range.mpr hk, ?_⟩
    show ((rtSegOf (sgeom s (k + 1)) (segs.getD (k + 1 + 1) [])).map (fun sg => sg.inOpen.columns)).getD []
      = sg1.inOpen.columns
    rw [hso1]
    show sg1'.inOpen.columns = sg1.inOpen.columns
    rw [hx1]
  have hx := rx_xok tag Lq h64 key domain hs hL _ _ _ A G hXev (rkR13 pX.rows (R.pf.off (k + 1) + 2)) _ sg1.inOpen
    root0 hmem habs hfit
    (rx_q_work tag Lq h64 incG outcG sgeom Lb (rxCoreOf sgeom) A G sg1.inOpen.columns hzo 16 (by norm_num))
  -- the claims and their count
  have hcO := (bp0.hcnt (liftH G) sg0.core _ bga0 rs0 acc0 tM0 hbs0 hshape0.1).2.2.2
  have hok := pX.hok s (liftH G) root0 (acc0.claims.out ++ acc.claims.inp) sg1.inOpen t₂ t'' hbo1
  rw [hX.htag, hX.hpt, hX.hlc'] at hok
  refine ⟨?_⟩
  rw [hpart]
  exact
    { tA := t₂
      tH := t''
      zo := sg1.inOpen
      c := R.pf.sqAt (k + 1 + 1) + stpsSq u
      rs := rtPartsStps (R.pf.parts.drop (k + 1 + 1 + 1)) ((R.rd (s, segs)).2.drop (k + 1 + 1 + 1))
      prm := pX.prm
      ev := pX.ev
      cl := acc0.claims.out ++ acc.claims.inp
      root := root0
      hpl := hlen
      hdrop := td
      hpre := trem
      hctr := tctr
      hst := tst
      hvpos := rfl
      haB := by
        have hr : (rkR13 pX.rows (R.pf.off (k + 1) + 2)).rows = pX.rows := rfl
        rw [hgX, hr]
        simp only [RtPart.oBX]
        omega
      hlc := hX.hlc
      hqp := by rw [pX.hqp, hX.hQ]; rfl
      hnQ := by rw [pX.hnQ, hX.hQ]; rfl
      hnn := by rw [pX.hnn, hX.hN]; rfl
      hpow := by rw [pX.hnn]; exact pX.hpow
      hQ0 := by norm_num [rkR13]
      hm := by norm_num [rkR13]
      hspec := hX.hspec
      hok := hok
      hcnt := by rw [List.length_append, hcO, hcI]
      hrd := by
        show (rkAccBlk (Pk k) (R.pf.off (k + 1) + 5) (R.pf.off (k + 1) + p0.pre)
            ((R.tr G (s, segs)).take (R.pf.off (k + 1 + 1) + p1.oX))).claims.out
          ++ (rkAccBlk (Pk (k + 1)) (R.pf.off (k + 1 + 1) + 5) (R.pf.off (k + 1 + 1) + p1.pre)
            ((R.tr G (s, segs)).take (R.pf.off (k + 1 + 1) + p1.oX))).claims.inp
          = acc0.claims.out ++ acc.claims.inp
        rw [hread0 _ (rk_take_take_le _ _ _ hle0), hread1 _ (rk_take_take_le _ _ _ hle1)]
      hcan := hcanX1
      hcolX := hx }

end Blk

end ZK60.ProtocolClassify
