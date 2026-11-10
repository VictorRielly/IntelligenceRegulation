/-
D63 lane L55 (2026-11-10), part 9: **stage OUT-C's closing opening (`B_out`) MEETS `RhOpW` OUTRIGHT** (the top
theorem's `hopX1` at part `Lb + 1`; the brief's deliverable 2).

At part `Lb + 1` the closing opening is `B_out = B_L`, the boundary the last block (part `Lb`) committed: stage OUT-C's
`bVerify` against the root the last block handed on, on the claims it left pending followed by OUT-C's incoming
claims (stage_out_c.rs:722-725). With the carry tied to the previous part (`cb_two`, `cb_blk_run_of`):

* **`cb_outc_run_of`**: L45's `rs_outc_run` at a GIVEN carry and step (so the carry can be the last block's);
* **`cb_outc_opX`**: on an accepted run outside L45's `EvXR` (no new event: `rxRoots` lists the last block's boundary
  root and `rxVx` checks OUT-C's `B_out` columns), `B_out`'s opening meets `RhOpW` at the boundary geometry
  (`rkR13 rows (off Lb + 2)`: the root absorbed alone at the third absorb of the last block's frame), with
  `nOut (Lb − 1) + O.nIn` claims read by the two readers, given `B_out`'s verifier at R13's numbers (`RkPcsR13`, met
  at the real stage: `rcOutcAt_pX_bnd`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunCloseBBlk
import ZK60Formal.RunStageRdHal
import ZK60Formal.RunExtractStage
import ZK60Formal.RunOpenGeoStageX

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Exec.StageV ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)

section Outc

variable {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}

/-- **L45's `rs_outc_run` AT A GIVEN CARRY AND STEP**: on an accepted run, if part `i` is stage OUT-C and its step
accepted from the carry `cr` on the run's transcript before the part, the verifier decoded a canonical segment of
the stage's shape, ran the slot phase, checked `M`, `A`, `H` and `B_out` against `cr.root` on `cr.pending` followed by
the stage's incoming claims, and `rkAccOutc` reads `acc` off every header agreeing with the run's transcript up to the
slot phase's end. -/
theorem cb_outc_run_of (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i : ℕ) (p : RtPart)
    (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (hσi : R.σs[i]? = some (rtOutcSeg outc outcG p))
    (hgeo : (outcG s.hdr).g = (outc s.hdr s.verdict).geom)
    (hgt : (outc s.hdr s.verdict).geom.slots.length = (outc s.hdr s.verdict).geom.terms.length)
    (hd : ∀ k, k < (outc s.hdr s.verdict).geom.slots.length →
      1 ≤ (Block.slotShape (outc s.hdr s.verdict).bp k).2.2)
    (W : List (TItem × Dig) → OutcV)
    (hW : W ((R.tr G (s, segs)).take (R.pf.off i + p.pre)) = outc s.hdr s.verdict)
    (cr cr' : Carry) (t t'' : Tr)
    (ht : t = runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i)))
    (hstep : segStep (rtOutcSeg outc outcG p).v (liftH G) s (V.start (liftH G) s).state (segs.getD i []) cr t
      = .ok (cr', t'')) :
    ∃ (seg : StageSeg) (ch : List Fp2) (recs : List Block.SlotRec) (acc : Block.Acc) (t4 t5 t6 t7 : Tr),
      rtStageOf (outcG s.hdr) (segs.getD i []) = some seg
      ∧ Block.CoreCanon seg.core ∧ Block.CoreShape (outc s.hdr s.verdict).geom seg.core
      ∧ (∀ o ∈ seg.closes, Block.HidingCanon o)
      ∧ (R.rd (s, segs)).2[i]? = some (rtOutcData (outc s.hdr s.verdict) seg)
      ∧ R.pf.parts[i]? = some p
      ∧ StageFS.stageSlots (liftH G) (outc s.hdr s.verdict).bp 2 OutcV.bga seg.core
          (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
            ++ rtOutcFrame (outc s.hdr s.verdict).stageIndex (outc s.hdr s.verdict).pub.wDigest))
          = .ok (ch, recs, acc, t4)
      ∧ (outc s.hdr s.verdict).maskVerify (liftH G) seg.core.maskRoot (acc.fs ++ acc.hostFs) seg.core.maskOpen t4
          = .ok t5
      ∧ (outc s.hdr s.verdict).pcsVerify (liftH G) .a seg.core.aRoot acc.claims.a seg.core.aOpen t5 = .ok t6
      ∧ (outc s.hdr s.verdict).pcsVerify (liftH G) .h seg.core.hRoot
          (acc.claims.h ++ [(outc s.hdr s.verdict).lay.logupSumClaim]) seg.core.hOpen t6 = .ok t7
      ∧ (outc s.hdr s.verdict).bVerify (liftH G) cr.root (cr.pending ++ acc.claims.inp) (seg.closes.headD IncV.ozk0)
          t7 = .ok t''
      ∧ ∀ hdr : List (TItem × Dig), hdr.take (R.pf.off i + p.pre) = (R.tr G (s, segs)).take (R.pf.off i + p.pre) →
          rkAccOutc W (R.pf.off i + 2) (R.pf.off i + p.pre) hdr = acc := by
  obtain ⟨-, -, -, -, -, -, -, hrdi⟩ := R.accept_part (liftH G) s segs hE i _ hσi
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  obtain ⟨seg, e, hdec, hver, -, -⟩ := (outSegExec_step_ok_iff outc outcG (liftH G) s _ _ cr t cr' t'').mp hstep
  obtain ⟨-, -, -, -, -, -, ch, recs, acc, t4, t5, t6, t7, hs, -, h5, -, -, h6, -, h7, -, h8⟩ :=
    (outcVerify_ok_iff (liftH G) (outc s.hdr s.verdict) cr.root cr.pending seg t t'').mp hver
  have hgt' : (outcG s.hdr).g.slots.length = (outcG s.hdr).g.terms.length := by
    rw [hgeo]
    exact hgt
  obtain ⟨hhdr, hshape0, -⟩ := rt_decodeStage_spec hgt' hdec
  obtain ⟨hcanC, hcanX⟩ := rs_decodeStage_canon hgt' hdec
  have hshape : Block.CoreShape (outc s.hdr s.verdict).geom seg.core := by
    rw [hgeo] at hshape0
    exact hshape0
  have hof : rtStageOf (outcG s.hdr) (segs.getD i []) = some seg := rtStageOf_decode hhdr hdec
  have hrd : rtOutcRd outc outcG s (segs.getD i []) = rtOutcData (outc s.hdr s.verdict) seg := by
    simp only [rtOutcRd, hof]
  have hrdi' : (R.rd (s, segs)).2[i]? = some (rtOutcData (outc s.hdr s.verdict) seg) := by
    rw [hrdi]
    exact congrArg some hrd
  have hpi : R.pf.parts[i]? = some p := by
    show (R.σs.map (fun σ => σ.p))[i]? = some p
    rw [List.getElem?_map, hσi]
    rfl
  have hfr : (outc s.hdr s.verdict).frame (liftH G) t
      = runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
        ++ rtOutcFrame (outc s.hdr s.verdict).stageIndex (outc s.hdr s.verdict).pub.wDigest) := by
    rw [runOps_append, ← ht]
    rfl
  rw [hfr] at hs
  refine ⟨seg, ch, recs, acc, t4, t5, t6, t7, hof, hcanC, hshape, hcanX, hrdi', hpi, hs, h5, h6, h7, h8, ?_⟩
  intro hdr hhdr'
  have hpd : RtPartOk Lq p (rtOutcData (outc s.hdr s.verdict) seg) := rk_forall₂_getElem? hgood.2.2.2 i p _ hpi hrdi'
  obtain ⟨tk, -, -, -, -⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood i p
    (rtOutcData (outc s.hdr s.verdict) seg) hpi hrdi' (opsStps (rtOutcData (outc s.hdr s.verdict) seg).pre) _ rfl
  rw [stpsOps_opsStps, hpd.1, stpsOps_append, stpsOps_opsStps] at tk
  have hlen : (stpsOps (rtPre R.pf (R.rd (s, segs)) i)).length = R.pf.off i := (rtPre_facts Lq R.pf _ hgood i).2.1
  have hread := rs_accS_trace (liftH G) (outc s.hdr s.verdict).bp 2 OutcV.bga seg.core
    (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
      ++ rtOutcFrame (outc s.hdr s.verdict).stageIndex (outc s.hdr s.verdict).pub.wDigest)
    (Tr.newKeyed (liftH G) domain key) ch recs acc t4 hcanC.1 hshape.1 hd hs
  have hl2 : (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
      ++ rtOutcFrame (outc s.hdr s.verdict).stageIndex (outc s.hdr s.verdict).pub.wDigest).length
        = R.pf.off i + 2 := by
    rw [List.length_append, hlen]
    rfl
  rw [hl2] at hread
  have hW' : W (hdr.take (R.pf.off i + p.pre)) = outc s.hdr s.verdict := by
    rw [hhdr']
    exact hW
  unfold rkAccOutc
  rw [hW', hhdr']
  show rsAccS (outc s.hdr s.verdict).bp 2 OutcV.bga (R.pf.off i + 2)
    ((rtTr key domain Lq R.pf R.rd G (s, segs)).take (R.pf.off i + p.pre)) = acc
  rw [tk, ← hread]
  show rsAccS (outc s.hdr s.verdict).bp 2 OutcV.bga (R.pf.off i + 2)
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
        ++ (rtOutcFrame (outc s.hdr s.verdict).stageIndex (outc s.hdr s.verdict).pub.wDigest
          ++ (StageFS.stageRootOps (outc s.hdr s.verdict).bp seg.core 2
            ++ Block.fullOps (outc s.hdr s.verdict).bp 0 seg.core.slots))))
    = _
  simp only [List.append_assoc]

end Outc

section OutX

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag)
  {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
  (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **STAGE OUT-C'S `B_out` OPENING MEETS `RhOpW` OUTRIGHT** at part `k + 2` (`k + 1 = Lb`: the last block is `k`) of
an accepted run outside the run's Merkle event, at the boundary geometry with the root absorbed at `off (k + 1) + 2`,
its claims the last block's outgoing then OUT-C's incoming. -/
theorem cb_outc_opX (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (k : ℕ) (hk : k < 26)
    (bp0 : RtBlk Lq (Pk k)) (p0 p1 : RtPart)
    (hσ0 : R.σs[k + 1]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k p0))
    (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom) (O : RtOutc Lq outc outcG p1)
    (hσ1 : R.σs[k + 1 + 1]? = some (rtOutcSeg outc outcG p1))
    (hgeo0 : ∀ s, (sgeom s k).g = (Pk k).geom)
    (W : List (TItem × Dig) → OutcV)
    (hW : W ((R.tr G (s, segs)).take (R.pf.off (k + 1 + 1) + p1.pre)) = outc s.hdr s.verdict)
    (hX : RkPcsR13 U tag O.pX) (hwX : p1.wX = bp0.nOut + O.nIn + O.pX.rows)
    (incG : Hdr → StageGeom) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (hrun : A.run G = (s, segs))
    (hXev : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom (k + 1)) (rxRoots incG outcG sgeom (k + 1)) A G)
    (hfit : 8 * O.pX.rows ≤ Lq) :
    Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (rkR13 O.pX.rows (R.pf.off (k + 1) + 2))
      (bp0.nOut + O.nIn)
      (fun hdr => (rkAccBlk (Pk k) (R.pf.off (k + 1) + 5) (R.pf.off (k + 1) + (R.pf.part (k + 1)).pre) hdr).claims.out
        ++ (rkAccOutc W (R.pf.off (k + 1 + 1) + 2) (R.pf.off (k + 1 + 1) + (R.pf.part (k + 1 + 1)).pre)
          hdr).claims.inp)
      (R.pf.off (k + 1 + 1) + (R.pf.part (k + 1 + 1)).oX) (R.pf.off (k + 1 + 1) + (R.pf.part (k + 1 + 1)).oBX)
      (R.pf.off (k + 1 + 1) + (R.pf.part (k + 1 + 1)).oX + ((bp0.nOut + O.nIn) + O.pX.rows)) (A.runLog G).2 G
      (R.tr G (s, segs))) := by
  obtain ⟨cr, cr', cr'', t, t', t'', -, ht, h1, -, ht', h2⟩ := cb_two R (liftH G) s segs hE (k + 1) _ _ hσ0 hσ1
  obtain ⟨sg0, root0, ic0, oc0, t₂0, bga0, rs0, acc0, tM0, tA0, tH0, -, -, hshape0, hrdi0, hpi0, hroot0, hbs0,
    -, -, -, -, -, -, -, hcr', hread0⟩ :=
    cb_blk_run_of Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv G s segs hE (k + 1) k p0 hσ0 bp0 hgeo0
      cr cr' t t' ht h1
  obtain ⟨seg, ch, recs, acc, t4, t5, t6, t7, hof, hcanC, hshape, hcanX, hrdi1, hpi1, hsl, h5, h6, h7, h8, hread1⟩ :=
    cb_outc_run_of R hv G s segs hE (k + 1 + 1) p1 outc outcG hσ1 (O.hgeo s.hdr s.verdict) (O.hgt s.hdr s.verdict)
      (fun j hj => (O.hgeomL s.hdr s.verdict j hj).1) W hW cr' cr'' t' t'' ht' h2
  subst hcr'
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  have hpart : R.pf.part (k + 1 + 1) = p1 := rh_part_eq R.pf _ p1 hpi1
  have hpart0 : R.pf.part (k + 1) = p0 := rh_part_eq R.pf _ p0 hpi0
  -- OUT-C's data and steps
  have hpd : RtPartOk Lq p1 (rtOutcData (outc s.hdr s.verdict) seg) := rk_forall₂_getElem? hgood.2.2.2 _ p1 _ hpi1 hrdi1
  have hgA : seg.core.aOpen.groupVecs.length = p1.gA := hpd.2.2.1
  have hgH : seg.core.hOpen.groupVecs.length = p1.gH := hpd.2.2.2.1
  have hgX : (seg.closes.headD IncV.ozk0).groupVecs.length = p1.gX := hpd.2.2.2.2.1
  have hd1 : ∀ j, j < seg.core.slots.length → 1 ≤ (Block.slotShape (outc s.hdr s.verdict).bp j).2.2 :=
    fun j hj => (O.hgeomL s.hdr s.verdict j (by rw [← hshape.1]; exact hj)).1
  have ht4 := rt_outcSlots_tr (liftH G) (outc s.hdr s.verdict) seg.core _ ch recs acc t4 hsl hd1
  rw [O.hPm s.hdr s.verdict] at h5
  have ht5 := (rt_mask_tr O.tag p1.S (liftH G) _ _ _ t4 t5 h5).1
  obtain ⟨hcA, hcH, hcI⟩ := O.hcnt s.hdr s.verdict (liftH G) seg.core _ ch recs acc t4 hsl hshape.1
  have ht6 := (O.pA.tr (s.hdr, s.verdict) (liftH G) seg.core.aRoot acc.claims.a seg.core.aOpen t5 t6 h6 O.nA hcA).1
  have ht7 := (O.pH.tr (s.hdr, s.verdict) (liftH G) seg.core.hRoot
    (acc.claims.h ++ [(outc s.hdr s.verdict).lay.logupSumClaim]) seg.core.hOpen t6 t7 h7 O.nH hcH).1
  set u := opsStps (rtOutcData (outc s.hdr s.verdict) seg).pre ++ mStps p1.S seg.core.maskOpen
      ++ pcsStps p1.wA p1.mA seg.core.aOpen ++ pcsStps p1.wH p1.mH seg.core.hOpen with huDef
  obtain ⟨tk, td, trem, tctr, tst⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood (k + 1 + 1) p1
    (rtOutcData (outc s.hdr s.verdict) seg) hpi1 hrdi1 u (pcsStps p1.wX p1.mX (seg.closes.headD IncV.ozk0))
    (by rw [huDef]; simp only [rtPartStps, rtOutcData, List.append_assoc])
  have hul : (stpsOps u).length = p1.oX := by
    rw [huDef, stpsOps_append, stpsOps_append, stpsOps_append, List.length_append, List.length_append,
      List.length_append, stpsOps_opsStps, stpsOps_mStps_length, stpsOps_pcsStps_length, stpsOps_pcsStps_length,
      hpd.1, hgA, hgH]
    simp only [RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have hwA : p1.wA = O.nA + O.pA.rows := O.hwA.symm
  have hmA : p1.mA = O.pA.m := O.hmA.symm
  have hwH : p1.wH = O.nH + O.pH.rows := O.hwH.symm
  have hmH : p1.mH = O.pH.m := O.hmH.symm
  have hpre1 : runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
      (stpsOps (rtPre R.pf (R.rd (s, segs)) (k + 1 + 1) ++ u)) = t7 := by
    rw [ht7, ht6, ht5, ht4, huDef, hwA, hmA, hwH, hmH]
    simp only [rtOutcData, stpsOps_append, stpsOps_opsStps, runOps_append, List.append_assoc]
  have hlen := rh_take_len key domain Lq R.pf R.rd G (s, segs) hgood (k + 1 + 1) u tk
  rw [hul] at td trem hlen
  rw [hpre1] at td tctr
  have hmX64 : p1.mX = 64 := by rw [← O.hmX]; exact hX.hm U tag
  rw [hmX64, hwX] at td tst
  -- the last block's frame absorbs B_out's root alone, third
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
  -- the extraction (L45's event: the last block's root and OUT-C's B_out are the run's)
  obtain ⟨sg0', hso0, hdat0⟩ := rx_blk_seg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R G s segs hE
    (k + 1) k p0 hσ0 sg0 hrdi0
  have hb0 := cb_blockData_bRoot (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg0' sg0 hdat0
  have hmem : root0 ∈ runRoots 26 (rxCoreOf sgeom) (rxRoots incG outcG sgeom (k + 1)) (A.run G) := by
    rw [hrun]
    unfold runRoots
    refine List.mem_append_right _ ?_
    unfold rxRoots
    refine List.mem_append_right _ ?_
    rw [List.mem_map]
    refine ⟨k, List.mem_range.mpr hk, ?_⟩
    show ((rtSegOf (sgeom s k) (segs.getD (k + 1) [])).bind Block.Segment.bRoot).getD zeroDig = root0
    rw [hso0]
    show sg0'.bRoot.getD zeroDig = root0
    rw [hb0, hgd0]
  have hseg : rxOutSeg outcG (k + 1) (A.run G) = some seg := by
    rw [hrun]
    exact hof
  have hzo := (rx_outCols_mem incG outcG sgeom (k + 1) (A.run G) seg hseg).2.2.2
  have hx := rx_xok tag Lq h64 key domain hs hL _ _ _ A G hXev (rkR13 O.pX.rows (R.pf.off (k + 1) + 2)) _
    (seg.closes.headD IncV.ozk0) root0 hmem habs hfit
    (rx_q_work tag Lq h64 incG outcG sgeom (k + 1) (rxCoreOf sgeom) A G (seg.closes.headD IncV.ozk0).columns hzo 16
      (by norm_num))
  -- the claims and their count
  have hcO := (bp0.hcnt (liftH G) sg0.core _ bga0 rs0 acc0 tM0 hbs0 hshape0.1).2.2.2
  have hok := O.pX.hok (s.hdr, s.verdict) (liftH G) root0 (acc0.claims.out ++ acc.claims.inp)
    (seg.closes.headD IncV.ozk0) t7 t'' h8
  rw [hX.htag, hX.hpt, hX.hlc'] at hok
  refine ⟨?_⟩
  rw [hpart]
  exact
    { tA := t7
      tH := t''
      zo := seg.closes.headD IncV.ozk0
      c := R.pf.sqAt (k + 1 + 1) + stpsSq u
      rs := rtPartsStps (R.pf.parts.drop (k + 1 + 1 + 1)) ((R.rd (s, segs)).2.drop (k + 1 + 1 + 1))
      prm := O.pX.prm
      ev := O.pX.ev
      cl := acc0.claims.out ++ acc.claims.inp
      root := root0
      hpl := hlen
      hdrop := td
      hpre := trem
      hctr := tctr
      hst := tst
      hvpos := rfl
      haB := by
        have hr : (rkR13 O.pX.rows (R.pf.off (k + 1) + 2)).rows = O.pX.rows := rfl
        rw [hgX, hr]
        simp only [RtPart.oBX]
        omega
      hlc := hX.hlc
      hqp := by rw [O.pX.hqp, hX.hQ]; rfl
      hnQ := by rw [O.pX.hnQ, hX.hQ]; rfl
      hnn := by rw [O.pX.hnn, hX.hN]; rfl
      hpow := by rw [O.pX.hnn]; exact O.pX.hpow
      hQ0 := by norm_num [rkR13]
      hm := by norm_num [rkR13]
      hspec := hX.hspec
      hok := hok
      hcnt := by rw [List.length_append, hcO, hcI]
      hrd := by
        show (rkAccBlk (Pk k) (R.pf.off (k + 1) + 5) (R.pf.off (k + 1) + (R.pf.part (k + 1)).pre)
            ((R.tr G (s, segs)).take (R.pf.off (k + 1 + 1) + p1.oX))).claims.out
          ++ (rkAccOutc W (R.pf.off (k + 1 + 1) + 2) (R.pf.off (k + 1 + 1) + p1.pre)
            ((R.tr G (s, segs)).take (R.pf.off (k + 1 + 1) + p1.oX))).claims.inp
          = acc0.claims.out ++ acc.claims.inp
        rw [hpart0, hread0 _ (rk_take_take_le _ _ _ hle0), hread1 _ (rk_take_take_le _ _ _ hle1)]
      hcan := og_closes_canon seg hcanX
      hcolX := hx }

end OutX

end ZK60.ProtocolClassify
