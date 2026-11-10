/-
D63 lane L55 (2026-11-10), part 10: **block `0`'s closing opening (`B_in`) MEETS `RhOpW` OUTRIGHT** (the top
theorem's `hopX1` at part `1`; the brief's deliverable 2).

At part `1` (block `0`) the closing opening is the boundary opening of `B_in`, the commitment stage IN-C made: the run's
`bndOpen` against the root IN-C handed on (`st.boundary_spec(0)`, classify_run.rs:390-402), on the claims IN-C left
pending followed by block `0`'s incoming claims. With the carry tied to the previous part:

* **`cb_inc_run_of`**: L45's `rs_inc_run` at a GIVEN carry and step, and the carry stage IN-C hands on:
  `⟨acc.claims.out, B_in⟩` (`incVerify_ok_iff`: the pending claims are the accumulator's outgoing ones);
* **`cb_inc_opX`**: on an accepted run outside L45's `EvXR` (no new event: `rxRoots` lists IN-C's `B_in` root,
  `rxVx` checks block `0`'s `in_open`), block `0`'s closing opening meets `RhOpW` at the boundary geometry
  (`rkR13 rows (off 0 + 2)`: the root absorbed alone at the third absorb of IN-C's frame), with `I.nOut + nIn (0)`
  claims read by IN-C's and block `0`'s readers.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunCloseBEnd

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Exec.StageV ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)

section Inc

variable {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}

/-- **L45's `rs_inc_run` AT A GIVEN CARRY AND STEP**, with the carry stage IN-C hands on. -/
theorem cb_inc_run_of (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i : ℕ) (p : RtPart)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (cx0 : IncCtx)
    (hσi : R.σs[i]? = some (rtIncSeg inc incG cx0 p))
    (hgeo : (incG s.hdr).g = (inc s.hdr).geom)
    (hgt : (inc s.hdr).geom.slots.length = (inc s.hdr).geom.terms.length)
    (hd : ∀ cx k, k < (inc s.hdr).geom.slots.length → 1 ≤ (Block.slotShape ((inc s.hdr).bp cx) k).2.2)
    (W : List (TItem × Dig) → IncV) (hW : W ((R.tr G (s, segs)).take (R.pf.off i + p.pre)) = inc s.hdr)
    (cr cr' : Carry) (t t'' : Tr)
    (ht : t = runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i)))
    (hstep : segStep (rtIncSeg inc incG cx0 p).v (liftH G) s (V.start (liftH G) s).state (segs.getD i []) cr t
      = .ok (cr', t'')) :
    ∃ (seg : StageSeg) (root : Dig) (recs : List Block.SlotRec) (acc : Block.Acc) (t4 : Tr),
      rtStageOf (incG s.hdr) (segs.getD i []) = some seg
      ∧ Block.CoreCanon seg.core ∧ Block.CoreShape (inc s.hdr).geom seg.core
      ∧ (R.rd (s, segs)).2[i]? = some (rtIncData (inc s.hdr) cx0 seg)
      ∧ R.pf.parts[i]? = some p
      ∧ seg.bRoot = some root
      ∧ (inc s.hdr).slots (liftH G) seg.core
          (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
            ++ rtIncFrame (inc s.hdr).pub.embDigest root (inc s.hdr).geo.bRows (inc s.hdr).geo.bLogN))
          = .ok (recs, acc, t4)
      ∧ cr' = ⟨acc.claims.out, root⟩
      ∧ ∀ hdr : List (TItem × Dig), hdr.take (R.pf.off i + p.pre) = (R.tr G (s, segs)).take (R.pf.off i + p.pre) →
          rkAccInc W (R.pf.off i + 5) (R.pf.off i + p.pre) hdr = acc := by
  obtain ⟨-, -, -, -, -, -, -, hrdi⟩ := R.accept_part (liftH G) s segs hE i _ hσi
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  obtain ⟨seg, e, broot, pending, hdec, hver, -, hcr⟩ :=
    (inSegExec_step_ok_iff inc incG (liftH G) s _ _ cr t cr' t'').mp hstep
  obtain ⟨-, -, -, -, -, hbr, recs, acc, t4, t5, t6, t7, hs, -, -, -, -, -, -, -, -, hpend⟩ :=
    (incVerify_ok_iff (liftH G) (inc s.hdr) s.inRoot seg t pending broot t'').mp hver
  have hgt' : (incG s.hdr).g.slots.length = (incG s.hdr).g.terms.length := by
    rw [hgeo]
    exact hgt
  obtain ⟨hhdr, hshape0, -⟩ := rt_decodeStage_spec hgt' hdec
  obtain ⟨hcanC, -⟩ := rs_decodeStage_canon hgt' hdec
  have hshape : Block.CoreShape (inc s.hdr).geom seg.core := by
    rw [hgeo] at hshape0
    exact hshape0
  have hof : rtStageOf (incG s.hdr) (segs.getD i []) = some seg := rtStageOf_decode hhdr hdec
  have hrd : rtIncRd inc incG cx0 s (segs.getD i []) = rtIncData (inc s.hdr) cx0 seg := by
    simp only [rtIncRd, hof]
  have hrdi' : (R.rd (s, segs)).2[i]? = some (rtIncData (inc s.hdr) cx0 seg) := by
    rw [hrdi]
    exact congrArg some hrd
  have hpi : R.pf.parts[i]? = some p := by
    show (R.σs.map (fun σ => σ.p))[i]? = some p
    rw [List.getElem?_map, hσi]
    rfl
  have hgd : seg.bRoot.getD zeroDig = broot := by rw [hbr]; rfl
  have hfr : (inc s.hdr).frame (liftH G) broot t
      = runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
        ++ rtIncFrame (inc s.hdr).pub.embDigest broot (inc s.hdr).geo.bRows (inc s.hdr).geo.bLogN) := by
    rw [runOps_append, ← ht]
    rfl
  rw [hfr] at hs
  have hcr' : cr' = ⟨acc.claims.out, broot⟩ := by rw [hcr, hpend]
  refine ⟨seg, broot, recs, acc, t4, hof, hcanC, hshape, hrdi', hpi, hbr, hs, hcr', ?_⟩
  intro hdr hhdr'
  have hpd : RtPartOk Lq p (rtIncData (inc s.hdr) cx0 seg) := rk_forall₂_getElem? hgood.2.2.2 i p _ hpi hrdi'
  have hpre_eq := rs_incPre_eq (inc s.hdr) cx0 seg broot hgd
  obtain ⟨tk, -, -, -, -⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood i p
    (rtIncData (inc s.hdr) cx0 seg) hpi hrdi' (opsStps (rtIncData (inc s.hdr) cx0 seg).pre) _ rfl
  rw [stpsOps_opsStps, hpd.1, stpsOps_append, stpsOps_opsStps, hpre_eq] at tk
  have hlen : (stpsOps (rtPre R.pf (R.rd (s, segs)) i)).length = R.pf.off i := (rtPre_facts Lq R.pf _ hgood i).2.1
  have hread := rs_accInc_trace (liftH G) (inc s.hdr) seg.core
    (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
      ++ rtIncFrame (inc s.hdr).pub.embDigest broot (inc s.hdr).geo.bRows (inc s.hdr).geo.bLogN)
    (Tr.newKeyed (liftH G) domain key) recs acc t4 cx0 hcanC.1 hshape.1 hd hs
  have hl5 : (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
      ++ rtIncFrame (inc s.hdr).pub.embDigest broot (inc s.hdr).geo.bRows (inc s.hdr).geo.bLogN).length
        = R.pf.off i + 5 := by
    rw [List.length_append, hlen]
    rfl
  rw [hl5] at hread
  have hW' : W (hdr.take (R.pf.off i + p.pre)) = inc s.hdr := by
    rw [hhdr']
    exact hW
  unfold rkAccInc
  rw [hW', hhdr']
  show rsAccInc (inc s.hdr) (R.pf.off i + 5)
    ((rtTr key domain Lq R.pf R.rd G (s, segs)).take (R.pf.off i + p.pre)) = acc
  rw [tk, ← hread]
  simp only [List.append_assoc]

end Inc

section IncX

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag)
  {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
  (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **BLOCK `0`'S CLOSING OPENING (`B_in`, THE BOUNDARY STAGE IN-C COMMITTED) MEETS `RhOpW` OUTRIGHT** at part `1` of an
accepted run outside the run's Merkle event, at the boundary geometry with the root absorbed at `off 0 + 2`, its
claims IN-C's outgoing then block `0`'s incoming. -/
theorem cb_inc_opX (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (pin : RtPart)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (cx0 : IncCtx) (I : RtInc Lq inc incG pin)
    (hσ0 : R.σs[0]? = some (rtIncSeg inc incG cx0 pin))
    (W : List (TItem × Dig) → IncV) (hW : W ((R.tr G (s, segs)).take (R.pf.off 0 + pin.pre)) = inc s.hdr)
    (bp1 : RtBlk Lq (Pk 0)) (p1 : RtPart)
    (hσ1 : R.σs[1]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen 0 p1))
    (hgeo1 : ∀ s, (sgeom s 0).g = (Pk 0).geom)
    (hS1 : p1.S = bp1.S) (hwA1 : p1.wA = bp1.nA + bp1.pA.rows) (hmA1 : p1.mA = bp1.pA.m)
    (hwH1 : p1.wH = bp1.nH + bp1.pH.rows) (hmH1 : p1.mH = bp1.pH.m)
    (pX : RtPcs (fun (s : ClsStmt Hdr) H root cl o t => bndOpen H s 0 root cl o t)) (hX : RkPcsR13 U tag pX)
    (hwX1 : p1.wX = I.nOut + bp1.nIn + pX.rows) (hmX1 : p1.mX = pX.m)
    (outcG : Hdr → StageGeom) (Lb : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (hrun : A.run G = (s, segs))
    (hXev : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hfit : 8 * pX.rows ≤ Lq) :
    Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (rkR13 pX.rows (R.pf.off 0 + 2))
      (I.nOut + bp1.nIn)
      (fun hdr => (rkAccInc W (R.pf.off 0 + 5) (R.pf.off 0 + (R.pf.part 0).pre) hdr).claims.out
        ++ (rkAccBlk (Pk 0) (R.pf.off 1 + 5) (R.pf.off 1 + (R.pf.part 1).pre) hdr).claims.inp)
      (R.pf.off 1 + (R.pf.part 1).oX) (R.pf.off 1 + (R.pf.part 1).oBX)
      (R.pf.off 1 + (R.pf.part 1).oX + ((I.nOut + bp1.nIn) + pX.rows)) (A.runLog G).2 G (R.tr G (s, segs))) := by
  obtain ⟨cr, cr', cr'', t, t', t'', -, ht, h1, -, ht', h2⟩ := cb_two R (liftH G) s segs hE 0 _ _ hσ0 hσ1
  have ht1 : t' = runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) 1)) := ht'
  have h21 : segStep (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen 0 p1).v (liftH G) s
      (V.start (liftH G) s).state (segs.getD 1 []) cr' t' = .ok (cr'', t'') := h2
  obtain ⟨seg0, root0, recs0, acc0, t40, hof0, -, hshape0, hrdi0, hpi0, hroot0, hs0, hcr', hread0⟩ :=
    cb_inc_run_of R hv G s segs hE 0 pin inc incG cx0 hσ0 (I.hgeo s.hdr) (I.hgt s.hdr)
      (fun cx k hk => (I.hgeomL s.hdr cx k hk).1) W hW cr cr' t t' ht h1
  obtain ⟨sg1, root1, ic1, oc1, t₂, bga, rs, acc, tM, tA, tH, -, hcanX1, hshape1, hrdi1, hpi1, hroot1, hbs1,
    -, hmv1, hpa1, hph1, hic1, -, hbo1, -, hread1⟩ :=
    cb_blk_run_of Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv G s segs hE 1 0 p1 hσ1 bp1 hgeo1
      cr' cr'' t' t'' ht1 h21
  subst hcr'
  subst hic1
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  have hpart : R.pf.part 1 = p1 := rh_part_eq R.pf _ p1 hpi1
  have hpart0 : R.pf.part 0 = pin := rh_part_eq R.pf _ pin hpi0
  -- part 1's data and steps
  have hpd : RtPartOk Lq p1 (rtBlockData (Pk 0) 0 (digest s 0) (bRows (0 + 1)) (bLogN (0 + 1)) sg1) :=
    rk_forall₂_getElem? hgood.2.2.2 _ p1 _ hpi1 hrdi1
  have hplen : (rtBlockFrame 0 (digest s 0) (sg1.bRoot.getD zeroDig) (bRows (0 + 1)) (bLogN (0 + 1))
      ++ (Block.rootOps (Pk 0) sg1.core ++ Block.fullOps (Pk 0) 0 sg1.core.slots)).length = p1.pre := hpd.1
  have hgA : sg1.core.aOpen.groupVecs.length = p1.gA := hpd.2.2.1
  have hgH : sg1.core.hOpen.groupVecs.length = p1.gH := hpd.2.2.2.1
  have hgX : sg1.inOpen.groupVecs.length = p1.gX := hpd.2.2.2.2.1
  have hgd : sg1.bRoot.getD zeroDig = root1 := by rw [hroot1]; rfl
  have hd1 : ∀ j, j < sg1.core.slots.length → 1 ≤ (Block.slotShape (Pk 0) j).2.2 :=
    fun j hj => (bp1.hgeomL j (by rw [hshape1.1] at hj; exact hj)).1
  have htM := blockSlots_tr (liftH G) (Pk 0) sg1.core _ bga rs acc tM hbs1 hd1
  rw [bp1.hPm] at hmv1
  have htA := (rt_mask_tr bp1.tag bp1.S (liftH G) _ _ _ tM tA hmv1).1
  obtain ⟨hcA, hcH, hcI, -⟩ := bp1.hcnt (liftH G) sg1.core _ bga rs acc tM hbs1 hshape1.1
  have htH := (bp1.pA.tr () (liftH G) sg1.core.aRoot acc.claims.a sg1.core.aOpen tA tH hpa1 bp1.nA hcA).1
  have ht₂ := (bp1.pH.tr () (liftH G) sg1.core.hRoot (acc.claims.h ++ [(Pk 0).logupSumClaim]) sg1.core.hOpen tH t₂
    hph1 bp1.nH hcH).1
  set u := opsStps (rtBlockFrame 0 (digest s 0) (sg1.bRoot.getD zeroDig) (bRows (0 + 1)) (bLogN (0 + 1))
      ++ (Block.rootOps (Pk 0) sg1.core ++ Block.fullOps (Pk 0) 0 sg1.core.slots))
      ++ mStps p1.S sg1.core.maskOpen ++ pcsStps p1.wA p1.mA sg1.core.aOpen ++ pcsStps p1.wH p1.mH sg1.core.hOpen
    with huDef
  obtain ⟨tk, td, trem, tctr, tst⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood 1 p1
    (rtBlockData (Pk 0) 0 (digest s 0) (bRows (0 + 1)) (bLogN (0 + 1)) sg1) hpi1 hrdi1 u
    (pcsStps p1.wX p1.mX sg1.inOpen) (by rw [huDef]; simp only [rtPartStps, rtBlockData, List.append_assoc])
  have hul : (stpsOps u).length = p1.oX := by
    rw [huDef, stpsOps_append, stpsOps_append, stpsOps_append, List.length_append, List.length_append,
      List.length_append, stpsOps_opsStps, stpsOps_mStps_length, stpsOps_pcsStps_length, stpsOps_pcsStps_length,
      hplen, hgA, hgH]
    simp only [RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have hpre1 : runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
      (stpsOps (rtPre R.pf (R.rd (s, segs)) 1 ++ u)) = t₂ := by
    rw [ht₂, htH, htA, htM, huDef, hgd, hS1, hwA1, hmA1, hwH1, hmH1]
    simp only [stpsOps_append, stpsOps_opsStps, runOps_append, List.append_assoc]
  have hlen := rh_take_len key domain Lq R.pf R.rd G (s, segs) hgood 1 u tk
  rw [hul] at td trem hlen
  rw [hpre1] at td tctr
  have hmX64 : p1.mX = 64 := by rw [hmX1]; exact hX.hm U tag
  rw [hmX64, hwX1] at td tst
  -- stage IN-C's frame absorbs B_in's root alone, third
  have hpd0 : RtPartOk Lq pin (rtIncData (inc s.hdr) cx0 seg0) := rk_forall₂_getElem? hgood.2.2.2 _ pin _ hpi0 hrdi0
  have hgd0 : seg0.bRoot.getD zeroDig = root0 := by rw [hroot0]; rfl
  have hpre_eq := rs_incPre_eq (inc s.hdr) cx0 seg0 root0 hgd0
  obtain ⟨tk0, -, -, -, -⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood 0 pin
    (rtIncData (inc s.hdr) cx0 seg0) hpi0 hrdi0 (opsStps (rtIncData (inc s.hdr) cx0 seg0).pre) _ rfl
  rw [stpsOps_opsStps, hpd0.1, stpsOps_append, stpsOps_opsStps, hpre_eq] at tk0
  have hlpre0 : (stpsOps (rtPre R.pf (R.rd (s, segs)) 0)).length = R.pf.off 0 :=
    (rtPre_facts Lq R.pf _ hgood 0).2.1
  have hpre0 : 5 ≤ pin.pre := by
    rw [← hpd0.1, hpre_eq]
    simp only [List.length_append, rtIncFrame, List.length_cons, List.length_nil]
    omega
  have hlt0 : 0 < R.pf.parts.length := (List.getElem?_eq_some_iff.mp hpi0).1
  have hsucc : R.pf.off 1 = R.pf.off 0 + (R.pf.part 0).len := RtProf.off_succ R.pf 0 hlt0
  rw [hpart0] at hsucc
  have hle0 : R.pf.off 0 + pin.pre ≤ R.pf.off 1 + p1.oX := by
    rw [hsucc]
    simp only [RtPart.len, RtPart.oBX, RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have hle1 : R.pf.off 1 + p1.pre ≤ R.pf.off 1 + p1.oX := by
    simp only [RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have habs : Block.absAt ((R.tr G (s, segs)).take (R.pf.off 1 + p1.oX)) (R.pf.off 0 + 2) = some root0.toList := by
    refine rs_absAt_run (R.tr G (s, segs)) (liftH G) _ _ _ (R.pf.off 0) _ _ 2 labB _ tk0 hlpre0 (by omega)
      (by omega) ?_
    rfl
  -- the extraction (L45's event: IN-C's B_in root and block 0's in_open are the run's)
  have hmem : root0 ∈ runRoots 26 (rxCoreOf sgeom) (rxRoots incG outcG sgeom Lb) (A.run G) := by
    rw [hrun]
    unfold runRoots
    refine List.mem_append_right _ ?_
    unfold rxRoots
    refine List.mem_append_left _ ?_
    refine List.mem_append_left _ ?_
    refine List.mem_append_left _ ?_
    show root0 ∈ rxStRoots (rtStageOf (incG s.hdr) (segs.getD 0 []))
    rw [hof0]
    show root0 ∈ [seg0.core.aRoot, seg0.core.hRoot, seg0.core.maskRoot, seg0.bRoot.getD zeroDig]
    rw [hgd0]
    simp
  obtain ⟨sg1', hso1, hdat1⟩ := rx_blk_seg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R G s segs hE
    1 0 p1 hσ1 sg1 hrdi1
  have hx1 : sg1'.inOpen = sg1.inOpen :=
    (rx_blockData_inj (Pk 0) 0 (digest s 0) (bRows (0 + 1)) (bLogN (0 + 1)) sg1' sg1 hdat1).2.2.2.2.2.2
  have hzo : sg1.inOpen.columns ∈ rxOpenings incG outcG sgeom Lb (A.run G) := by
    rw [hrun]
    unfold rxOpenings
    refine List.mem_append_right _ ?_
    rw [List.mem_map]
    refine ⟨0, List.mem_range.mpr (by norm_num), ?_⟩
    show ((rtSegOf (sgeom s 0) (segs.getD 1 [])).map (fun sg => sg.inOpen.columns)).getD []
      = sg1.inOpen.columns
    rw [hso1]
    show sg1'.inOpen.columns = sg1.inOpen.columns
    rw [hx1]
  have hx := rx_xok tag Lq h64 key domain hs hL _ _ _ A G hXev (rkR13 pX.rows (R.pf.off 0 + 2)) _ sg1.inOpen
    root0 hmem habs hfit
    (rx_q_work tag Lq h64 incG outcG sgeom Lb (rxCoreOf sgeom) A G sg1.inOpen.columns hzo 16 (by norm_num))
  -- the claims and their count
  have hcO := (I.hcnt s.hdr (liftH G) seg0.core _ recs0 acc0 t40 hs0 hshape0.1).2.2.2
  have hok := pX.hok s (liftH G) root0 (acc0.claims.out ++ acc.claims.inp) sg1.inOpen t₂ t'' hbo1
  rw [hX.htag, hX.hpt, hX.hlc'] at hok
  refine ⟨?_⟩
  rw [hpart]
  exact
    { tA := t₂
      tH := t''
      zo := sg1.inOpen
      c := R.pf.sqAt 1 + stpsSq u
      rs := rtPartsStps (R.pf.parts.drop (1 + 1)) ((R.rd (s, segs)).2.drop (1 + 1))
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
        have hr : (rkR13 pX.rows (R.pf.off 0 + 2)).rows = pX.rows := rfl
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
        show (rkAccInc W (R.pf.off 0 + 5) (R.pf.off 0 + (R.pf.part 0).pre)
            ((R.tr G (s, segs)).take (R.pf.off 1 + p1.oX))).claims.out
          ++ (rkAccBlk (Pk 0) (R.pf.off 1 + 5) (R.pf.off 1 + p1.pre)
            ((R.tr G (s, segs)).take (R.pf.off 1 + p1.oX))).claims.inp
          = acc0.claims.out ++ acc.claims.inp
        rw [hpart0, hread0 _ (rk_take_take_le _ _ _ hle0), hread1 _ (rk_take_take_le _ _ _ hle1)]
      hcan := hcanX1
      hcolX := hx }

end IncX

end ZK60.ProtocolClassify
