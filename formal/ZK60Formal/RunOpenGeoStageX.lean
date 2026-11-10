/-
D63 lane L48 (2026-11-10), part 8: **the input token endpoint's opening at its REAL width `2^8`, at part `0` of the
run** (the first of L45's closing openings `hopX`; finding L45-2).

At part `0` (stage IN-C) the closing opening is the classifier's input token commitment: the stage verifier checks it
against the statement's input root `s.inRoot` on the claims the slots left on the endpoint (`acc.claims.inp`; nothing is
pending before part `0`), with the tier's endpoint parameters (`epVerify` = `pcsAt … pub.epLogN elr eq`: at R1_MVP
`2^8` columns, rate `1/8`, `256` checks). With the width a parameter, its acceptance facts are:

* **`rs_inc_opXG`**: at an accepted run, at ANY code geometry `g` whose numbers the endpoint verifier has
  (`RkPcsAt U tag g I.pX`; at R1_MVP `g = ogEp`, `rcIncAt_pX_ep`), the endpoint opening meets `RhOpW` as soon as it
  meets its extraction at the position `xPos` where the run's transcript absorbs `s.inRoot` (the claims read by
  `rkAccInc`, exactly the top theorem's part-`0` reader: nothing pending, then `claims.inp`);
* **`rx_inc_opX`**: the same OUTRIGHT outside the run's Merkle event `EvXR` with the run's own Merkle work (L45's
  `rxVx` checks the endpoint opening's columns; `rxRoots` lists `s.inRoot`), given that the run's transcript absorbs
  `s.inRoot` at `xPos` (`hInAbs`: the run header is a free parameter of L34's `rtRunClassify`, finding L45-1; where the
  header absorbs the input root is a fact of the header, left as this premise).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunExtractStage
import ZK60Formal.RunOpenGeoTier

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Exec.StageV ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)

/-- **The empty opening is canonical** (the default of a stage segment that closes nothing). -/
theorem og_ozk0_canon : Block.HidingCanon IncV.ozk0 :=
  ⟨fun _ hv => absurd hv List.not_mem_nil, fun _ hx => absurd hx List.not_mem_nil,
    fun _ hc => absurd hc List.not_mem_nil⟩

/-- **The closing opening of a decoded stage segment is canonical** (every closed opening is, or none is closed). -/
theorem og_closes_canon (seg : StageSeg) (h : ∀ o ∈ seg.closes, Block.HidingCanon o) :
    Block.HidingCanon (seg.closes.headD IncV.ozk0) := by
  cases hc : seg.closes with
  | nil => exact og_ozk0_canon
  | cons o os => exact h o (by rw [hc]; exact List.mem_cons_self)

section IncX

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag)
  {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

/-- **Stage IN-C's closing opening (the input token endpoint) at ANY code geometry `g`**: at part `i` of an accepted
run (stage IN-C with the contract `I`), the closing opening of the segment read off the bytes meets `RhOpW` (its
claims: nothing pending, then the slots' claims on the endpoint, read by `rkAccInc`) as soon as it meets its
extraction at the statement's input root, absorbed at `xPos`. -/
theorem rs_inc_opXG (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i : ℕ) (p : RtPart)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (cx0 : IncCtx) (I : RtInc Lq inc incG p)
    (hσi : R.σs[i]? = some (rtIncSeg inc incG cx0 p))
    (W : List (TItem × Dig) → IncV) (hW : W ((R.tr G (s, segs)).take (R.pf.off i + p.pre)) = inc s.hdr)
    (g : OGeo) (hg : g.Ok) (hX : RkPcsAt U tag g I.pX) (xPos : ℕ) (lg : List (QB Lq × Dig)) :
    ∃ seg : StageSeg, rtStageOf (incG s.hdr) (segs.getD i []) = some seg
      ∧ (RhXOk tag Lq h64 key domain hs hL (rkAt g I.pX.rows xPos) lg G
          ((R.tr G (s, segs)).take (R.pf.off i + (R.pf.part i).oX)) (seg.closes.headD IncV.ozk0) s.inRoot →
        Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (rkAt g I.pX.rows xPos) I.nIn
          (fun hdr => [] ++ (rkAccInc W (R.pf.off i + 5) (R.pf.off i + p.pre) hdr).claims.inp)
          (R.pf.off i + (R.pf.part i).oX) (R.pf.off i + (R.pf.part i).oBX)
          (R.pf.off i + (R.pf.part i).oX + (I.nIn + I.pX.rows)) lg G (R.tr G (s, segs)))) := by
  obtain ⟨seg, root, recs, acc, t4, t5, t6, t7, t', hof, hcanC, hshape, hcanX, hrdi, hpi, hbr, hsl, -, h5, h6, h7, h8,
    hread⟩ := rs_inc_run R hv G s segs hE i p inc incG cx0 hσi (I.hgeo s.hdr) (I.hgt s.hdr)
      (fun cx k hk => (I.hgeomL s.hdr cx k hk).1) W hW
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  have hpart : R.pf.part i = p := rh_part_eq R.pf i p hpi
  have hpd : RtPartOk Lq p (rtIncData (inc s.hdr) cx0 seg) := rk_forall₂_getElem? hgood.2.2.2 i p _ hpi hrdi
  have hgA : seg.core.aOpen.groupVecs.length = p.gA := hpd.2.2.1
  have hgH : seg.core.hOpen.groupVecs.length = p.gH := hpd.2.2.2.1
  have hgX : (seg.closes.headD IncV.ozk0).groupVecs.length = p.gX := hpd.2.2.2.2.1
  have hgd : seg.bRoot.getD zeroDig = root := by rw [hbr]; rfl
  have hpre_eq := rs_incPre_eq (inc s.hdr) cx0 seg root hgd
  have hd1 : ∀ cx j, j < seg.core.slots.length → 1 ≤ (Block.slotShape ((inc s.hdr).bp cx) j).2.2 :=
    fun cx j hj => (I.hgeomL s.hdr cx j (by rw [← hshape.1]; exact hj)).1
  have ht4 := rt_incSlots_tr (liftH G) (inc s.hdr) seg.core _ recs acc t4 hsl hd1 cx0
  rw [I.hPm s.hdr] at h5
  have ht5 := (rt_mask_tr I.tag p.S (liftH G) _ _ _ t4 t5 h5).1
  obtain ⟨hcA, hcH, hcI, -⟩ := I.hcnt s.hdr (liftH G) seg.core _ recs acc t4 hsl hshape.1
  have ht6 := (I.pA.tr s.hdr (liftH G) seg.core.aRoot acc.claims.a seg.core.aOpen t5 t6 h6 I.nA hcA).1
  have ht7 := (I.pH.tr s.hdr (liftH G) seg.core.hRoot (acc.claims.h ++ [(inc s.hdr).lay.logupSumClaim])
    seg.core.hOpen t6 t7 h7 I.nH hcH).1
  have hmX : p.mX = g.mI := by rw [← I.hmX]; exact hX.hm U tag hg.hm
  have hwA : p.wA = I.nA + I.pA.rows := I.hwA.symm
  have hmA : p.mA = I.pA.m := I.hmA.symm
  have hwH : p.wH = I.nH + I.pH.rows := I.hwH.symm
  have hmH : p.mH = I.pH.m := I.hmH.symm
  have hwX : p.wX = I.nIn + I.pX.rows := I.hwX.symm
  set u := opsStps (rtIncData (inc s.hdr) cx0 seg).pre ++ mStps p.S seg.core.maskOpen
      ++ pcsStps p.wA p.mA seg.core.aOpen ++ pcsStps p.wH p.mH seg.core.hOpen with huDef
  obtain ⟨tk, td, trem, tctr, tst⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood i p
    (rtIncData (inc s.hdr) cx0 seg) hpi hrdi u (pcsStps p.wX p.mX (seg.closes.headD IncV.ozk0))
    (by rw [huDef]; simp only [rtPartStps, rtIncData, List.append_assoc])
  have hul : (stpsOps u).length = p.oX := by
    rw [huDef, stpsOps_append, stpsOps_append, stpsOps_append, List.length_append, List.length_append,
      List.length_append, stpsOps_opsStps, stpsOps_mStps_length, stpsOps_pcsStps_length, stpsOps_pcsStps_length,
      hpd.1, hgA, hgH]
    simp only [RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have hle : R.pf.off i + p.pre ≤ R.pf.off i + p.oX := by
    simp only [RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have ht7' : runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i ++ u))
      = t7 := by
    rw [ht7, ht6, ht5, ht4, huDef, hpre_eq, hwA, hmA, hwH, hmH]
    simp only [stpsOps_append, stpsOps_opsStps, runOps_append, List.append_assoc]
  have hlen := rh_take_len key domain Lq R.pf R.rd G (s, segs) hgood i u tk
  rw [hul] at td trem hlen
  rw [ht7'] at td tctr
  rw [hmX, hwX] at td tst
  refine ⟨seg, hof, fun hx => ⟨?_⟩⟩
  rw [hpart] at hx ⊢
  have hok := I.pX.hok s.hdr (liftH G) s.inRoot acc.claims.inp (seg.closes.headD IncV.ozk0) t7 t' h8
  rw [hX.htag, hX.hpt, hX.hlc'] at hok
  have hr : (rkAt g I.pX.rows xPos).rows = I.pX.rows := rfl
  exact
    { tA := t7
      tH := t'
      zo := seg.closes.headD IncV.ozk0
      c := R.pf.sqAt i + stpsSq u
      rs := rtPartsStps (R.pf.parts.drop (i + 1)) ((R.rd (s, segs)).2.drop (i + 1))
      prm := I.pX.prm
      ev := I.pX.ev
      cl := acc.claims.inp
      root := s.inRoot
      hpl := hlen
      hdrop := td
      hpre := trem
      hctr := tctr
      hst := tst
      hvpos := rfl
      haB := by
        rw [hgX, hr]
        have := I.hwX
        simp only [RtPart.oBX]
        omega
      hlc := hX.hlc
      hqp := by rw [I.pX.hqp, hX.hQ]; rfl
      hnQ := by rw [I.pX.hnQ, hX.hQ]; rfl
      hnn := by rw [I.pX.hnn, hX.hN]; rfl
      hpow := by rw [I.pX.hnn]; exact I.pX.hpow
      hQ0 := hg.hQ0
      hm := hg.hm
      hspec := hX.hspec
      hok := hok
      hcnt := hcI
      hrd := by
        show [] ++ (rkAccInc W (R.pf.off i + 5) (R.pf.off i + p.pre)
          ((R.tr G (s, segs)).take (R.pf.off i + p.oX))).claims.inp = acc.claims.inp
        rw [hread ((R.tr G (s, segs)).take (R.pf.off i + p.oX)) (rk_take_take_le _ _ _ hle), List.nil_append]
      hcan := og_closes_canon seg hcanX
      hcolX := hx }

/-- **The statement's input root is one of the run's roots** (`rxRoots` lists it). -/
theorem rx_stmtInRoot_mem (incG outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ)
    (coreOf : ClsStmt Hdr × ClsReceipt → ℕ → List Op × Block.Core) (o : ClsStmt Hdr × ClsReceipt) :
    o.1.inRoot ∈ runRoots 26 coreOf (rxRoots incG outcG sgeom Lb) o := by
  unfold runRoots
  refine List.mem_append_right _ ?_
  simp [rxRoots]

/-- **THE INPUT TOKEN ENDPOINT'S OPENING MEETS `RhOpW` OUTRIGHT AT PART `0`**, at ANY code geometry `g` with at most
`256` queries (at R1_MVP `g = ogEp`: `2^8` columns, rate `1/8`), on an accepted run outside the run's Merkle event
with the run's own Merkle work, given that the run's transcript absorbs the statement's input root at `xPos`
(`hInAbs`). -/
theorem rx_inc_opX (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (p : RtPart)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (cx0 : IncCtx) (I : RtInc Lq inc incG p)
    (hσ : R.σs[0]? = some (rtIncSeg inc incG cx0 p))
    (W : List (TItem × Dig) → IncV) (hW : W ((R.tr G (s, segs)).take (R.pf.off 0 + p.pre)) = inc s.hdr)
    (g : OGeo) (hg : g.Ok) (hgQ : g.Q ≤ 256) (hX : RkPcsAt U tag g I.pX) (xPos : ℕ)
    (outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (hrun : A.run G = (s, segs))
    (hXev : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hfit : 8 * I.pX.rows ≤ Lq)
    (hInAbs : Block.absAt ((R.tr G (s, segs)).take (R.pf.off 0 + (R.pf.part 0).oX)) xPos = some s.inRoot.toList) :
    Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (rkAt g I.pX.rows xPos) I.nIn
      (fun hdr => [] ++ (rkAccInc W (R.pf.off 0 + 5) (R.pf.off 0 + p.pre) hdr).claims.inp)
      (R.pf.off 0 + (R.pf.part 0).oX) (R.pf.off 0 + (R.pf.part 0).oBX)
      (R.pf.off 0 + (R.pf.part 0).oX + (I.nIn + I.pX.rows)) (A.runLog G).2 G (R.tr G (s, segs))) := by
  obtain ⟨seg, hof, himp⟩ :=
    rs_inc_opXG U tag h64 hs hL R hv G s segs hE 0 p inc incG cx0 I hσ W hW g hg hX xPos (A.runLog G).2
  have hseg : rxInSeg incG (A.run G) = some seg := by rw [hrun]; exact hof
  have hroot : s.inRoot ∈ runRoots 26 (rxCoreOf sgeom) (rxRoots incG outcG sgeom Lb) (A.run G) := by
    have h := rx_stmtInRoot_mem incG outcG sgeom Lb (rxCoreOf sgeom) (A.run G)
    rw [hrun] at h
    rw [hrun]
    exact h
  apply himp
  exact rx_xok tag Lq h64 key domain hs hL _ _ _ A G hXev (rkAt g I.pX.rows xPos) _ (seg.closes.headD IncV.ozk0)
    s.inRoot hroot hInAbs hfit
    (fun k hk => rx_q_work tag Lq h64 incG outcG sgeom Lb (rxCoreOf sgeom) A G (seg.closes.headD IncV.ozk0).columns
      (rx_inCols_mem incG outcG sgeom Lb _ seg hseg).2.2.2 g.h (by have := hg.hh; omega) k (lt_of_lt_of_le hk hgQ))

end IncX

end ZK60.ProtocolClassify
