/-
D63 lane L45 (2026-11-10), part 3: **`hal_opB` and `hal_M` at the run's two stages** (L43's `rh_blk_opA`,
`rh_blk_opH`, `rh_blk_M` for the blocks; finding L43-6).

At a part of an accepted run that is stage IN-C or stage OUT-C, the acceptance facts L43's `rh_opB_alive` and
`rh_M_alive` ask (`RhOpW`, `RhMW`) are PROVED from the acceptance, with the stages' readers (`rkAccInc`, `rkAccOutc`),
up to each opening's extraction. Unlike L43's block lemmas, the theorems here EXPOSE the opening whose extraction is
asked: it is the opening of the segment read off the bytes alone (`rtStageOf`), and the run's transcript absorbs its
root at a FIXED position (proved here); the extraction itself is discharged in `RunExtract*.lean` from the run's
Merkle event `EvXR` with the run's own Merkle work.

* `rs_get_app0`, `rs_get_app`, **`rs_stageRoot_get`**, **`rs_incPre_get`**, **`rs_outcPre_get`**: where a stage's
  single phase absorbs its three roots (IN-C: `5`, `8`, `9 + m`; OUT-C: `2`, `5`, `8`), `m` the head's challenges;
* **`rs_absAt_run`**: the run's transcript absorbs, at a part's position plus `j`, what the part's operations absorb
  at `j`;
* **`rs_inc_opA`**, **`rs_inc_opH`**, **`rs_inc_M`**: stage IN-C's `A`, `H` (with the LogUp sum claim) and `M`;
* **`rs_outc_opA`**, **`rs_outc_opH`**, **`rs_outc_M`**: stage OUT-C's.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStageRdRun
import ZK60Formal.RunHalBlk

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Exec.StageV ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)

/-! ## Where a stage's single phase absorbs its roots -/

theorem rs_get_app0 {α : Type} (l₁ l₂ : List α) (n : ℕ) (h : l₁.length = n) : (l₁ ++ l₂)[n]? = l₂[0]? := by
  subst h
  rw [List.getElem?_append_right (le_refl _), Nat.sub_self]

theorem rs_get_app {α : Type} (l₁ l₂ : List α) (n j : ℕ) (h : l₁.length = n) : (l₁ ++ l₂)[n + j]? = l₂[j]? := by
  subst h
  rw [List.getElem?_append_right (Nat.le_add_right _ _), Nat.add_sub_cancel_left]

/-- **A stage's head absorbs `A`'s root first, `M`'s fourth, `H`'s after the `m` challenges** (L15's
`stageRootOps`). -/
theorem rs_stageRoot_get (P : Block.BlockParams) (core : Block.Core) (m : ℕ) (rest : List Op) :
    (StageFS.stageRootOps P core m ++ rest)[0]? = some (Op.absorb Block.labA core.aRoot.toList)
      ∧ (StageFS.stageRootOps P core m ++ rest)[3]? = some (Op.absorb Block.labM core.maskRoot.toList)
      ∧ (StageFS.stageRootOps P core m ++ rest)[4 + m]? = some (Op.absorb Block.labH core.hRoot.toList) := by
  have e : StageFS.stageRootOps P core m ++ rest
      = Block.rootOpsA P core ++ (Block.drawOps m ++ (Block.rootOpsH P core ++ rest)) := by
    simp only [StageFS.stageRootOps, List.append_assoc]
  have h4 : (Block.rootOpsA P core).length = 4 := rfl
  have hm : (Block.drawOps m).length = m := List.length_replicate
  refine ⟨by rw [e]; rfl, by rw [e]; rfl, ?_⟩
  rw [e, rs_get_app _ _ 4 m h4, rs_get_app0 _ _ m hm]
  rfl

/-- **Stage IN-C's single phase** (the frame's five absorbs, the head, the slots) absorbs `A`'s root at `5`, `M`'s at
`8`, `H`'s at `9 + m`. -/
theorem rs_incPre_get (V : IncV) (cx0 : IncCtx) (core : Block.Core) (root : Dig) :
    (rtIncFrame V.pub.embDigest root V.geo.bRows V.geo.bLogN
        ++ (StageFS.stageRootOps (V.bp cx0) core (incHeadDraws V.pub) ++ Block.fullOps (V.bp cx0) 0 core.slots))[5]?
        = some (Op.absorb Block.labA core.aRoot.toList)
      ∧ (rtIncFrame V.pub.embDigest root V.geo.bRows V.geo.bLogN
        ++ (StageFS.stageRootOps (V.bp cx0) core (incHeadDraws V.pub)
          ++ Block.fullOps (V.bp cx0) 0 core.slots))[5 + 3]? = some (Op.absorb Block.labM core.maskRoot.toList)
      ∧ (rtIncFrame V.pub.embDigest root V.geo.bRows V.geo.bLogN
        ++ (StageFS.stageRootOps (V.bp cx0) core (incHeadDraws V.pub)
          ++ Block.fullOps (V.bp cx0) 0 core.slots))[5 + (4 + incHeadDraws V.pub)]?
        = some (Op.absorb Block.labH core.hRoot.toList) := by
  have h5 : (rtIncFrame V.pub.embDigest root V.geo.bRows V.geo.bLogN).length = 5 := rfl
  obtain ⟨g0, g3, gH⟩ := rs_stageRoot_get (V.bp cx0) core (incHeadDraws V.pub) (Block.fullOps (V.bp cx0) 0 core.slots)
  refine ⟨?_, ?_, ?_⟩
  · rw [rs_get_app0 _ _ 5 h5]
    exact g0
  · rw [rs_get_app _ _ 5 3 h5]
    exact g3
  · rw [rs_get_app _ _ 5 _ h5]
    exact gH

/-- **Stage OUT-C's single phase** (the frame's two absorbs, the head of two challenges, the slots) absorbs `A`'s
root at `2`, `M`'s at `5`, `H`'s at `8`. -/
theorem rs_outcPre_get (V : OutcV) (core : Block.Core) :
    (rtOutcFrame V.stageIndex V.pub.wDigest
        ++ (StageFS.stageRootOps V.bp core 2 ++ Block.fullOps V.bp 0 core.slots))[2]?
        = some (Op.absorb Block.labA core.aRoot.toList)
      ∧ (rtOutcFrame V.stageIndex V.pub.wDigest
        ++ (StageFS.stageRootOps V.bp core 2 ++ Block.fullOps V.bp 0 core.slots))[2 + 3]?
        = some (Op.absorb Block.labM core.maskRoot.toList)
      ∧ (rtOutcFrame V.stageIndex V.pub.wDigest
        ++ (StageFS.stageRootOps V.bp core 2 ++ Block.fullOps V.bp 0 core.slots))[2 + (4 + 2)]?
        = some (Op.absorb Block.labH core.hRoot.toList) := by
  have h2 : (rtOutcFrame V.stageIndex V.pub.wDigest).length = 2 := rfl
  obtain ⟨g0, g3, gH⟩ := rs_stageRoot_get V.bp core 2 (Block.fullOps V.bp 0 core.slots)
  refine ⟨?_, ?_, ?_⟩
  · rw [rs_get_app0 _ _ 2 h2]
    exact g0
  · rw [rs_get_app _ _ 2 3 h2]
    exact g3
  · rw [rs_get_app _ _ 2 _ h2]
    exact gH

/-- **The run's transcript absorbs, at a part's position plus `j`, what the part's operations absorb at `j`**: if the
transcript cut at `e` is the trace of `pre0 ++ ops` (`pre0` the `off` operations before the part), then at any cut `a`
past the position, the entry `off + j` absorbs what `ops[j]` absorbs. -/
theorem rs_absAt_run (τ : List (TItem × Dig)) (H : HIn → Dig) (t0 : Tr) (pre0 ops : List Op) (off e a j : ℕ)
    (l x : List UInt8) (htk : τ.take e = opTrace H t0 (pre0 ++ ops)) (hlen : pre0.length = off) (hje : off + j < e)
    (hja : off + j < a) (hj : ops[j]? = some (Op.absorb l x)) :
    Block.absAt (τ.take a) (off + j) = some x := by
  rw [Exec.Link.absAt_take _ _ _ hja, ← Exec.Link.absAt_take _ _ _ hje, htk, Block.opTrace_append,
    Exec.Link.absAt_append_right' _ _ _ _ (by rw [Block.opTrace_length]; exact hlen)]
  exact rs_absAt_opTrace H _ ops j l x hj

/-! ## Stage IN-C's openings and `M` -/

section Inc

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag)
  {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

theorem rs_incPre_eq (VI : IncV) (cx0 : IncCtx) (seg : StageSeg) (root : Dig) (hgd : seg.bRoot.getD zeroDig = root) :
    (rtIncData VI cx0 seg).pre
      = rtIncFrame VI.pub.embDigest root VI.geo.bRows VI.geo.bLogN
        ++ (StageFS.stageRootOps (VI.bp cx0) seg.core (incHeadDraws VI.pub)
          ++ Block.fullOps (VI.bp cx0) 0 seg.core.slots) := by
  show rtIncFrame VI.pub.embDigest (seg.bRoot.getD zeroDig) VI.geo.bRows VI.geo.bLogN
    ++ (StageFS.stageRootOps (VI.bp cx0) seg.core (incHeadDraws VI.pub)
      ++ Block.fullOps (VI.bp cx0) 0 seg.core.slots) = _
  rw [hgd]

theorem rs_incPre_len (VI : IncV) (cx0 : IncCtx) (seg : StageSeg) :
    5 + (4 + incHeadDraws VI.pub) < (rtIncData VI cx0 seg).pre.length := by
  show 5 + (4 + incHeadDraws VI.pub) < (rtIncFrame VI.pub.embDigest (seg.bRoot.getD zeroDig) VI.geo.bRows VI.geo.bLogN
    ++ (StageFS.stageRootOps (VI.bp cx0) seg.core (incHeadDraws VI.pub)
      ++ Block.fullOps (VI.bp cx0) 0 seg.core.slots)).length
  rw [List.length_append, List.length_append, StageFS.stageRootOps_length]
  have h5 : (rtIncFrame VI.pub.embDigest (seg.bRoot.getD zeroDig) VI.geo.bRows VI.geo.bLogN).length = 5 := rfl
  omega

/-- **Stage IN-C's `A`: its acceptance facts at an accepted run, given its extraction.** At part `i` (stage IN-C with
the contract `I`), the opening of the segment read off the bytes (`rtStageOf`) has its root absorbed at
`off i + 5`, and `A` (its geometry R13's at that root position, its claims read by `rkAccInc`) meets `RhOpW` as soon
as it meets its extraction there. -/
theorem rs_inc_opA (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i : ℕ) (p : RtPart)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (cx0 : IncCtx) (I : RtInc Lq inc incG p)
    (hσi : R.σs[i]? = some (rtIncSeg inc incG cx0 p))
    (W : List (TItem × Dig) → IncV) (hW : W ((R.tr G (s, segs)).take (R.pf.off i + p.pre)) = inc s.hdr)
    (hA : RkPcsR13 U tag I.pA) (lg : List (QB Lq × Dig)) :
    ∃ seg : StageSeg, rtStageOf (incG s.hdr) (segs.getD i []) = some seg
      ∧ Block.absAt ((R.tr G (s, segs)).take (R.pf.off i + (R.pf.part i).oA)) (R.pf.off i + 5)
          = some seg.core.aRoot.toList
      ∧ (RhXOk tag Lq h64 key domain hs hL (rkR13 I.pA.rows (R.pf.off i + 5)) lg G
          ((R.tr G (s, segs)).take (R.pf.off i + (R.pf.part i).oA)) seg.core.aOpen seg.core.aRoot →
        Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (rkR13 I.pA.rows (R.pf.off i + 5)) I.nA
          (fun hdr => (rkAccInc W (R.pf.off i + 5) (R.pf.off i + p.pre) hdr).claims.a)
          (R.pf.off i + (R.pf.part i).oA) (R.pf.off i + (R.pf.part i).oBA)
          (R.pf.off i + (R.pf.part i).oA + (I.nA + I.pA.rows)) lg G (R.tr G (s, segs)))) := by
  obtain ⟨seg, root, recs, acc, t4, t5, t6, t7, t', hof, hcanC, hshape, -, hrdi, hpi, hbr, hsl, -, h5, h6, -, -,
    hread⟩ := rs_inc_run R hv G s segs hE i p inc incG cx0 hσi (I.hgeo s.hdr) (I.hgt s.hdr)
      (fun cx k hk => (I.hgeomL s.hdr cx k hk).1) W hW
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  have hpart : R.pf.part i = p := rh_part_eq R.pf i p hpi
  have hpd : RtPartOk Lq p (rtIncData (inc s.hdr) cx0 seg) := rk_forall₂_getElem? hgood.2.2.2 i p _ hpi hrdi
  have hgA : seg.core.aOpen.groupVecs.length = p.gA := hpd.2.2.1
  have hgd : seg.bRoot.getD zeroDig = root := by rw [hbr]; rfl
  have hpre_eq := rs_incPre_eq (inc s.hdr) cx0 seg root hgd
  have hd1 : ∀ cx j, j < seg.core.slots.length → 1 ≤ (Block.slotShape ((inc s.hdr).bp cx) j).2.2 :=
    fun cx j hj => (I.hgeomL s.hdr cx j (by rw [← hshape.1]; exact hj)).1
  have ht4 := rt_incSlots_tr (liftH G) (inc s.hdr) seg.core _ recs acc t4 hsl hd1 cx0
  rw [I.hPm s.hdr] at h5
  have ht5 := (rt_mask_tr I.tag p.S (liftH G) _ _ _ t4 t5 h5).1
  have hmA : p.mA = 64 := by rw [← I.hmA]; exact hA.hm U tag
  have hwA : p.wA = I.nA + I.pA.rows := I.hwA.symm
  set u := opsStps (rtIncData (inc s.hdr) cx0 seg).pre ++ mStps p.S seg.core.maskOpen with huDef
  obtain ⟨tk, td, trem, tctr, tst⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood i p
    (rtIncData (inc s.hdr) cx0 seg) hpi hrdi u
    (pcsStps p.wA p.mA seg.core.aOpen ++ (pcsStps p.wH p.mH seg.core.hOpen
      ++ pcsStps p.wX p.mX (seg.closes.headD IncV.ozk0)))
    (by rw [huDef]; simp only [rtPartStps, rtIncData, List.append_assoc])
  have hul : (stpsOps u).length = p.oA := by
    rw [huDef, stpsOps_append, List.length_append, stpsOps_opsStps, stpsOps_mStps_length, hpd.1]
    rfl
  have hlpre : (stpsOps (rtPre R.pf (R.rd (s, segs)) i)).length = R.pf.off i := (rtPre_facts Lq R.pf _ hgood i).2.1
  have hp5 := rs_incPre_len (inc s.hdr) cx0 seg
  have hpl1 := hpd.1
  rw [hpd.1] at hp5
  have hle : R.pf.off i + p.pre ≤ R.pf.off i + p.oA := by simp only [RtPart.oA]; omega
  -- the root's position
  have habs : Block.absAt ((R.tr G (s, segs)).take (R.pf.off i + p.oA)) (R.pf.off i + 5)
      = some seg.core.aRoot.toList := by
    have tk' := tk
    rw [hul, stpsOps_append] at tk'
    refine rs_absAt_run (R.tr G (s, segs)) (liftH G) _ _ (stpsOps u) (R.pf.off i) _ _ 5 Block.labA _ tk' hlpre
      (by omega) (by omega) ?_
    have hlt : 5 < (rtIncData (inc s.hdr) cx0 seg).pre.length := by omega
    rw [huDef, stpsOps_append, stpsOps_opsStps, List.getElem?_append_left hlt, hpre_eq]
    exact (rs_incPre_get (inc s.hdr) cx0 seg.core root).1
  have ht5' : runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i ++ u))
      = t5 := by
    rw [ht5, ht4, huDef, hpre_eq]
    simp only [stpsOps_append, stpsOps_opsStps, runOps_append, List.append_assoc]
  have hlen := rh_take_len key domain Lq R.pf R.rd G (s, segs) hgood i u tk
  rw [hul] at td trem hlen
  rw [ht5'] at td tctr
  rw [List.append_assoc, hmA, hwA] at td tst
  have hcnt := (I.hcnt s.hdr (liftH G) seg.core _ recs acc t4 hsl hshape.1).1
  refine ⟨seg, hof, by rw [hpart]; exact habs, fun hx => ⟨?_⟩⟩
  rw [hpart] at hx ⊢
  have hok := I.pA.hok s.hdr (liftH G) seg.core.aRoot acc.claims.a seg.core.aOpen t5 t6 h6
  rw [hA.htag, hA.hpt, hA.hlc'] at hok
  have hr13 : (rkR13 I.pA.rows (R.pf.off i + 5)).rows = I.pA.rows := rfl
  exact
    { tA := t5
      tH := t6
      zo := seg.core.aOpen
      c := R.pf.sqAt i + stpsSq u
      rs := (pcsStps p.wH p.mH seg.core.hOpen ++ pcsStps p.wX p.mX (seg.closes.headD IncV.ozk0))
        ++ rtPartsStps (R.pf.parts.drop (i + 1)) ((R.rd (s, segs)).2.drop (i + 1))
      prm := I.pA.prm
      ev := I.pA.ev
      cl := acc.claims.a
      root := seg.core.aRoot
      hpl := hlen
      hdrop := td
      hpre := trem
      hctr := tctr
      hst := tst
      hvpos := rfl
      haB := by
        rw [hgA, hr13]
        have := I.hwA
        simp only [RtPart.oBA]
        omega
      hlc := hA.hlc
      hqp := by rw [I.pA.hqp, hA.hQ]; rfl
      hnQ := by rw [I.pA.hnQ, hA.hQ]; rfl
      hnn := by rw [I.pA.hnn, hA.hN]; rfl
      hpow := by rw [I.pA.hnn]; exact I.pA.hpow
      hQ0 := by norm_num [rkR13]
      hm := by norm_num [rkR13]
      hspec := hA.hspec
      hok := hok
      hcnt := hcnt
      hrd := by
        show (rkAccInc W (R.pf.off i + 5) (R.pf.off i + p.pre)
          ((R.tr G (s, segs)).take (R.pf.off i + p.oA))).claims.a = acc.claims.a
        rw [hread ((R.tr G (s, segs)).take (R.pf.off i + p.oA)) (rk_take_take_le _ _ _ hle)]
      hcan := hcanC.2.2.1
      hcolX := hx }

/-- **Stage IN-C's `H`** (with the LogUp sum claim among its claims, as the verifier passes them): its root absorbed at
`off i + 9 + m`, `RhOpW` given its extraction. -/
theorem rs_inc_opH (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i : ℕ) (p : RtPart)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (cx0 : IncCtx) (I : RtInc Lq inc incG p)
    (hσi : R.σs[i]? = some (rtIncSeg inc incG cx0 p))
    (W : List (TItem × Dig) → IncV) (hW : W ((R.tr G (s, segs)).take (R.pf.off i + p.pre)) = inc s.hdr)
    (hH : RkPcsR13 U tag I.pH) (lsc : Block.ZClaim) (hlsc : (inc s.hdr).lay.logupSumClaim = lsc)
    (hPos : ℕ) (hP : hPos = R.pf.off i + (5 + (4 + incHeadDraws (inc s.hdr).pub))) (lg : List (QB Lq × Dig)) :
    ∃ seg : StageSeg, rtStageOf (incG s.hdr) (segs.getD i []) = some seg
      ∧ Block.absAt ((R.tr G (s, segs)).take (R.pf.off i + (R.pf.part i).oH)) hPos = some seg.core.hRoot.toList
      ∧ (RhXOk tag Lq h64 key domain hs hL (rkR13 I.pH.rows hPos) lg G
          ((R.tr G (s, segs)).take (R.pf.off i + (R.pf.part i).oH)) seg.core.hOpen seg.core.hRoot →
        Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (rkR13 I.pH.rows hPos) I.nH
          (fun hdr => (rkAccInc W (R.pf.off i + 5) (R.pf.off i + p.pre) hdr).claims.h ++ [lsc])
          (R.pf.off i + (R.pf.part i).oH) (R.pf.off i + (R.pf.part i).oBH)
          (R.pf.off i + (R.pf.part i).oH + (I.nH + I.pH.rows)) lg G (R.tr G (s, segs)))) := by
  obtain ⟨seg, root, recs, acc, t4, t5, t6, t7, t', hof, hcanC, hshape, -, hrdi, hpi, hbr, hsl, -, h5, h6, h7, -,
    hread⟩ := rs_inc_run R hv G s segs hE i p inc incG cx0 hσi (I.hgeo s.hdr) (I.hgt s.hdr)
      (fun cx k hk => (I.hgeomL s.hdr cx k hk).1) W hW
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  have hpart : R.pf.part i = p := rh_part_eq R.pf i p hpi
  have hpd : RtPartOk Lq p (rtIncData (inc s.hdr) cx0 seg) := rk_forall₂_getElem? hgood.2.2.2 i p _ hpi hrdi
  have hgA : seg.core.aOpen.groupVecs.length = p.gA := hpd.2.2.1
  have hgH : seg.core.hOpen.groupVecs.length = p.gH := hpd.2.2.2.1
  have hgd : seg.bRoot.getD zeroDig = root := by rw [hbr]; rfl
  have hpre_eq := rs_incPre_eq (inc s.hdr) cx0 seg root hgd
  have hd1 : ∀ cx j, j < seg.core.slots.length → 1 ≤ (Block.slotShape ((inc s.hdr).bp cx) j).2.2 :=
    fun cx j hj => (I.hgeomL s.hdr cx j (by rw [← hshape.1]; exact hj)).1
  have ht4 := rt_incSlots_tr (liftH G) (inc s.hdr) seg.core _ recs acc t4 hsl hd1 cx0
  rw [I.hPm s.hdr] at h5
  have ht5 := (rt_mask_tr I.tag p.S (liftH G) _ _ _ t4 t5 h5).1
  obtain ⟨hcA, hcH, -, -⟩ := I.hcnt s.hdr (liftH G) seg.core _ recs acc t4 hsl hshape.1
  have ht6 := (I.pA.tr s.hdr (liftH G) seg.core.aRoot acc.claims.a seg.core.aOpen t5 t6 h6 I.nA hcA).1
  have hmH : p.mH = 64 := by rw [← I.hmH]; exact hH.hm U tag
  have hwA : p.wA = I.nA + I.pA.rows := I.hwA.symm
  have hmA : p.mA = I.pA.m := I.hmA.symm
  have hwH : p.wH = I.nH + I.pH.rows := I.hwH.symm
  set u := opsStps (rtIncData (inc s.hdr) cx0 seg).pre ++ mStps p.S seg.core.maskOpen
      ++ pcsStps p.wA p.mA seg.core.aOpen with huDef
  obtain ⟨tk, td, trem, tctr, tst⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood i p
    (rtIncData (inc s.hdr) cx0 seg) hpi hrdi u
    (pcsStps p.wH p.mH seg.core.hOpen ++ pcsStps p.wX p.mX (seg.closes.headD IncV.ozk0))
    (by rw [huDef]; simp only [rtPartStps, rtIncData, List.append_assoc])
  have hul : (stpsOps u).length = p.oH := by
    rw [huDef, stpsOps_append, stpsOps_append, List.length_append, List.length_append, stpsOps_opsStps,
      stpsOps_mStps_length, stpsOps_pcsStps_length, hpd.1, hgA]
    simp only [RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have hlpre : (stpsOps (rtPre R.pf (R.rd (s, segs)) i)).length = R.pf.off i := (rtPre_facts Lq R.pf _ hgood i).2.1
  have hp5 := rs_incPre_len (inc s.hdr) cx0 seg
  have hpl1 := hpd.1
  rw [hpd.1] at hp5
  have hle : R.pf.off i + p.pre ≤ R.pf.off i + p.oH := by
    simp only [RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have habs : Block.absAt ((R.tr G (s, segs)).take (R.pf.off i + p.oH)) hPos = some seg.core.hRoot.toList := by
    have tk' := tk
    rw [hul, stpsOps_append] at tk'
    rw [hP]
    refine rs_absAt_run (R.tr G (s, segs)) (liftH G) _ _ (stpsOps u) (R.pf.off i) _ _ _ Block.labH _ tk' hlpre
      (by omega) (by omega) ?_
    have hlt : 5 + (4 + incHeadDraws (inc s.hdr).pub) < (rtIncData (inc s.hdr) cx0 seg).pre.length := by omega
    rw [huDef, stpsOps_append, stpsOps_append, stpsOps_opsStps, List.append_assoc, List.getElem?_append_left hlt,
      hpre_eq]
    exact (rs_incPre_get (inc s.hdr) cx0 seg.core root).2.2
  have ht6' : runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i ++ u))
      = t6 := by
    rw [ht6, ht5, ht4, huDef, hpre_eq, hwA, hmA]
    simp only [stpsOps_append, stpsOps_opsStps, runOps_append, List.append_assoc]
  have hlen := rh_take_len key domain Lq R.pf R.rd G (s, segs) hgood i u tk
  rw [hul] at td trem hlen
  rw [ht6'] at td tctr
  rw [List.append_assoc, hmH, hwH] at td tst
  refine ⟨seg, hof, by rw [hpart]; exact habs, fun hx => ⟨?_⟩⟩
  rw [hpart] at hx ⊢
  have hok := I.pH.hok s.hdr (liftH G) seg.core.hRoot (acc.claims.h ++ [(inc s.hdr).lay.logupSumClaim])
    seg.core.hOpen t6 t7 h7
  rw [hH.htag, hH.hpt, hH.hlc', hlsc] at hok
  rw [hlsc] at hcH
  have hr13 : (rkR13 I.pH.rows hPos).rows = I.pH.rows := rfl
  exact
    { tA := t6
      tH := t7
      zo := seg.core.hOpen
      c := R.pf.sqAt i + stpsSq u
      rs := pcsStps p.wX p.mX (seg.closes.headD IncV.ozk0)
        ++ rtPartsStps (R.pf.parts.drop (i + 1)) ((R.rd (s, segs)).2.drop (i + 1))
      prm := I.pH.prm
      ev := I.pH.ev
      cl := acc.claims.h ++ [lsc]
      root := seg.core.hRoot
      hpl := hlen
      hdrop := td
      hpre := trem
      hctr := tctr
      hst := tst
      hvpos := rfl
      haB := by
        rw [hgH, hr13]
        have := I.hwH
        simp only [RtPart.oBH]
        omega
      hlc := hH.hlc
      hqp := by rw [I.pH.hqp, hH.hQ]; rfl
      hnQ := by rw [I.pH.hnQ, hH.hQ]; rfl
      hnn := by rw [I.pH.hnn, hH.hN]; rfl
      hpow := by rw [I.pH.hnn]; exact I.pH.hpow
      hQ0 := by norm_num [rkR13]
      hm := by norm_num [rkR13]
      hspec := hH.hspec
      hok := hok
      hcnt := hcH
      hrd := by
        show (rkAccInc W (R.pf.off i + 5) (R.pf.off i + p.pre)
          ((R.tr G (s, segs)).take (R.pf.off i + p.oH))).claims.h ++ [lsc] = acc.claims.h ++ [lsc]
        rw [hread ((R.tr G (s, segs)).take (R.pf.off i + p.oH)) (rk_take_take_le _ _ _ hle)]
      hcan := hcanC.2.2.2
      hcolX := hx }

/-- **Stage IN-C's `M`**: its root absorbed at `off i + 8`, the verifier's `MaskOk` on the reader's functionals, and
`RhMW` given its extraction. -/
theorem rs_inc_M (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i : ℕ) (p : RtPart)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (cx0 : IncCtx) (I : RtInc Lq inc incG p)
    (hσi : R.σs[i]? = some (rtIncSeg inc incG cx0 p))
    (W : List (TItem × Dig) → IncV) (hW : W ((R.tr G (s, segs)).take (R.pf.off i + p.pre)) = inc s.hdr)
    (htag : I.tag = tag) (kM : ℕ) (hkM : (inc s.hdr).lay.nFunctionals = kM) (lg : List (QB Lq × Dig)) :
    ∃ (seg : StageSeg) (tM tA : Tr) (fs : List Block.MaskFunctional),
      rtStageOf (incG s.hdr) (segs.getD i []) = some seg
      ∧ Block.absAt ((R.tr G (s, segs)).take (R.pf.off i + (R.pf.part i).pre)) (R.pf.off i + (5 + 3))
          = some seg.core.maskRoot.toList
      ∧ MaskOk (liftH G) tag (rootFp 9) (rootFp 12) seg.core.maskRoot p.S (fs.map toMF) (toMO seg.core.maskOpen) tM tA
      ∧ (RhXMOk tag Lq h64 key domain hs hL p.S (R.pf.off i + (5 + 3)) lg G
          ((R.tr G (s, segs)).take (R.pf.off i + (R.pf.part i).pre)) tM seg.core.maskOpen →
        Nonempty (RhMW tag Lq h64 key domain hs hL (rtW R.pf.sqs) p.S kM (R.pf.off i + (5 + 3))
          (fun hdr => (rkAccInc W (R.pf.off i + 5) (R.pf.off i + p.pre) hdr).fs
            ++ (rkAccInc W (R.pf.off i + 5) (R.pf.off i + p.pre) hdr).hostFs)
          (R.pf.off i + (R.pf.part i).pre) lg G (R.tr G (s, segs)))) := by
  obtain ⟨seg, root, recs, acc, t4, t5, t6, t7, t', hof, hcanC, hshape, -, hrdi, hpi, hbr, hsl, hnf, h5, -, -, -,
    hread⟩ := rs_inc_run R hv G s segs hE i p inc incG cx0 hσi (I.hgeo s.hdr) (I.hgt s.hdr)
      (fun cx k hk => (I.hgeomL s.hdr cx k hk).1) W hW
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  have hpart : R.pf.part i = p := rh_part_eq R.pf i p hpi
  have hpd : RtPartOk Lq p (rtIncData (inc s.hdr) cx0 seg) := rk_forall₂_getElem? hgood.2.2.2 i p _ hpi hrdi
  have hgd : seg.bRoot.getD zeroDig = root := by rw [hbr]; rfl
  have hpre_eq := rs_incPre_eq (inc s.hdr) cx0 seg root hgd
  have hd1 : ∀ cx j, j < seg.core.slots.length → 1 ≤ (Block.slotShape ((inc s.hdr).bp cx) j).2.2 :=
    fun cx j hj => (I.hgeomL s.hdr cx j (by rw [← hshape.1]; exact hj)).1
  have ht4 := rt_incSlots_tr (liftH G) (inc s.hdr) seg.core _ recs acc t4 hsl hd1 cx0
  rw [I.hPm s.hdr] at h5
  have hok : MaskOk (liftH G) I.tag (rootFp 9) (rootFp 12) seg.core.maskRoot p.S
      ((acc.fs ++ acc.hostFs).map toMF) (toMO seg.core.maskOpen) t4 t5 := by
    rw [maskField, mapErr_ok, w16r2MCheck_ok_iff] at h5
    exact h5
  rw [htag] at hok
  set u := opsStps (rtIncData (inc s.hdr) cx0 seg).pre with huDef
  obtain ⟨tk, td, trem, tctr, tst⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood i p
    (rtIncData (inc s.hdr) cx0 seg) hpi hrdi u
    (mStps p.S seg.core.maskOpen ++ (pcsStps p.wA p.mA seg.core.aOpen ++ (pcsStps p.wH p.mH seg.core.hOpen
      ++ pcsStps p.wX p.mX (seg.closes.headD IncV.ozk0))))
    (by rw [huDef]; simp only [rtPartStps, rtIncData])
  have hul : (stpsOps u).length = p.pre := by
    rw [huDef, stpsOps_opsStps, hpd.1]
  have hlpre : (stpsOps (rtPre R.pf (R.rd (s, segs)) i)).length = R.pf.off i := (rtPre_facts Lq R.pf _ hgood i).2.1
  have hp5 := rs_incPre_len (inc s.hdr) cx0 seg
  have hpl1 := hpd.1
  rw [hpd.1] at hp5
  have habs : Block.absAt ((R.tr G (s, segs)).take (R.pf.off i + p.pre)) (R.pf.off i + (5 + 3))
      = some seg.core.maskRoot.toList := by
    have tk' := tk
    rw [hul, stpsOps_append] at tk'
    refine rs_absAt_run (R.tr G (s, segs)) (liftH G) _ _ (stpsOps u) (R.pf.off i) _ _ _ Block.labM _ tk' hlpre
      (by omega) (by omega) ?_
    rw [huDef, stpsOps_opsStps, hpre_eq]
    exact (rs_incPre_get (inc s.hdr) cx0 seg.core root).2.1
  have ht4' : runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i ++ u))
      = t4 := by
    rw [ht4, huDef, hpre_eq]
    simp only [stpsOps_append, stpsOps_opsStps, runOps_append]
  have hlen := rh_take_len key domain Lq R.pf R.rd G (s, segs) hgood i u tk
  rw [hul] at td trem hlen
  rw [ht4'] at td tctr
  rw [List.append_assoc] at td tst
  refine ⟨seg, t4, t5, acc.fs ++ acc.hostFs, hof, by rw [hpart]; exact habs, hok, fun hx => ⟨?_⟩⟩
  rw [hpart] at hx ⊢
  exact
    { tM := t4
      tA := t5
      mo := seg.core.maskOpen
      c := R.pf.sqAt i + stpsSq u
      rs := (pcsStps p.wA p.mA seg.core.aOpen ++ (pcsStps p.wH p.mH seg.core.hOpen
          ++ pcsStps p.wX p.mX (seg.closes.headD IncV.ozk0)))
        ++ rtPartsStps (R.pf.parts.drop (i + 1)) ((R.rd (s, segs)).2.drop (i + 1))
      root := seg.core.maskRoot
      fs := acc.fs ++ acc.hostFs
      hpl := hlen
      hdrop := td
      hpre := trem
      hctr := tctr
      hst := tst
      hcan := hcanC.2.1
      hok := hok
      hk := hnf.trans hkM
      hrd := by
        show (rkAccInc W (R.pf.off i + 5) (R.pf.off i + p.pre) ((R.tr G (s, segs)).take (R.pf.off i + p.pre))).fs
          ++ (rkAccInc W (R.pf.off i + 5) (R.pf.off i + p.pre)
            ((R.tr G (s, segs)).take (R.pf.off i + p.pre))).hostFs = acc.fs ++ acc.hostFs
        rw [hread ((R.tr G (s, segs)).take (R.pf.off i + p.pre)) (rk_take_take_le _ _ _ le_rfl)]
      hcols := hx }

end Inc

/-! ## Stage OUT-C's openings and `M` -/

section Outc

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag)
  {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

theorem rs_outcPre_len (VO : OutcV) (seg : StageSeg) : 2 + (4 + 2) < (rtOutcData VO seg).pre.length := by
  show 2 + (4 + 2) < (rtOutcFrame VO.stageIndex VO.pub.wDigest
    ++ (StageFS.stageRootOps VO.bp seg.core 2 ++ Block.fullOps VO.bp 0 seg.core.slots)).length
  rw [List.length_append, List.length_append, StageFS.stageRootOps_length]
  have h2 : (rtOutcFrame VO.stageIndex VO.pub.wDigest).length = 2 := rfl
  omega

/-- **Stage OUT-C's `A`**: its root absorbed at `off i + 2`, `RhOpW` given its extraction. -/
theorem rs_outc_opA (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i : ℕ) (p : RtPart)
    (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom) (O : RtOutc Lq outc outcG p)
    (hσi : R.σs[i]? = some (rtOutcSeg outc outcG p))
    (W : List (TItem × Dig) → OutcV)
    (hW : W ((R.tr G (s, segs)).take (R.pf.off i + p.pre)) = outc s.hdr s.verdict)
    (hA : RkPcsR13 U tag O.pA) (lg : List (QB Lq × Dig)) :
    ∃ seg : StageSeg, rtStageOf (outcG s.hdr) (segs.getD i []) = some seg
      ∧ Block.absAt ((R.tr G (s, segs)).take (R.pf.off i + (R.pf.part i).oA)) (R.pf.off i + 2)
          = some seg.core.aRoot.toList
      ∧ (RhXOk tag Lq h64 key domain hs hL (rkR13 O.pA.rows (R.pf.off i + 2)) lg G
          ((R.tr G (s, segs)).take (R.pf.off i + (R.pf.part i).oA)) seg.core.aOpen seg.core.aRoot →
        Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (rkR13 O.pA.rows (R.pf.off i + 2)) O.nA
          (fun hdr => (rkAccOutc W (R.pf.off i + 2) (R.pf.off i + p.pre) hdr).claims.a)
          (R.pf.off i + (R.pf.part i).oA) (R.pf.off i + (R.pf.part i).oBA)
          (R.pf.off i + (R.pf.part i).oA + (O.nA + O.pA.rows)) lg G (R.tr G (s, segs)))) := by
  obtain ⟨cr, seg, ch, recs, acc, t4, t5, t6, t7, t', -, hof, hcanC, hshape, -, hrdi, hpi, hsl, -, h5, h6, -, -,
    hread⟩ := rs_outc_run R hv G s segs hE i p outc outcG hσi (O.hgeo s.hdr s.verdict) (O.hgt s.hdr s.verdict)
      (fun k hk => (O.hgeomL s.hdr s.verdict k hk).1) W hW
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  have hpart : R.pf.part i = p := rh_part_eq R.pf i p hpi
  have hpd : RtPartOk Lq p (rtOutcData (outc s.hdr s.verdict) seg) := rk_forall₂_getElem? hgood.2.2.2 i p _ hpi hrdi
  have hgA : seg.core.aOpen.groupVecs.length = p.gA := hpd.2.2.1
  have hd1 : ∀ j, j < seg.core.slots.length → 1 ≤ (Block.slotShape (outc s.hdr s.verdict).bp j).2.2 :=
    fun j hj => (O.hgeomL s.hdr s.verdict j (by rw [← hshape.1]; exact hj)).1
  have ht4 := rt_outcSlots_tr (liftH G) (outc s.hdr s.verdict) seg.core _ ch recs acc t4 hsl hd1
  rw [O.hPm s.hdr s.verdict] at h5
  have ht5 := (rt_mask_tr O.tag p.S (liftH G) _ _ _ t4 t5 h5).1
  have hmA : p.mA = 64 := by rw [← O.hmA]; exact hA.hm U tag
  have hwA : p.wA = O.nA + O.pA.rows := O.hwA.symm
  set u := opsStps (rtOutcData (outc s.hdr s.verdict) seg).pre ++ mStps p.S seg.core.maskOpen with huDef
  obtain ⟨tk, td, trem, tctr, tst⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood i p
    (rtOutcData (outc s.hdr s.verdict) seg) hpi hrdi u
    (pcsStps p.wA p.mA seg.core.aOpen ++ (pcsStps p.wH p.mH seg.core.hOpen
      ++ pcsStps p.wX p.mX (seg.closes.headD IncV.ozk0)))
    (by rw [huDef]; simp only [rtPartStps, rtOutcData, List.append_assoc])
  have hul : (stpsOps u).length = p.oA := by
    rw [huDef, stpsOps_append, List.length_append, stpsOps_opsStps, stpsOps_mStps_length, hpd.1]
    rfl
  have hlpre : (stpsOps (rtPre R.pf (R.rd (s, segs)) i)).length = R.pf.off i := (rtPre_facts Lq R.pf _ hgood i).2.1
  have hp5 := rs_outcPre_len (outc s.hdr s.verdict) seg
  have hpl1 := hpd.1
  rw [hpd.1] at hp5
  have hle : R.pf.off i + p.pre ≤ R.pf.off i + p.oA := by simp only [RtPart.oA]; omega
  have habs : Block.absAt ((R.tr G (s, segs)).take (R.pf.off i + p.oA)) (R.pf.off i + 2)
      = some seg.core.aRoot.toList := by
    have tk' := tk
    rw [hul, stpsOps_append] at tk'
    refine rs_absAt_run (R.tr G (s, segs)) (liftH G) _ _ (stpsOps u) (R.pf.off i) _ _ 2 Block.labA _ tk' hlpre
      (by omega) (by omega) ?_
    have hlt : 2 < (rtOutcData (outc s.hdr s.verdict) seg).pre.length := by omega
    rw [huDef, stpsOps_append, stpsOps_opsStps, List.getElem?_append_left hlt]
    exact (rs_outcPre_get (outc s.hdr s.verdict) seg.core).1
  have ht5' : runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i ++ u))
      = t5 := by
    rw [ht5, ht4, huDef]
    simp only [rtOutcData, stpsOps_append, stpsOps_opsStps, runOps_append, List.append_assoc]
  have hlen := rh_take_len key domain Lq R.pf R.rd G (s, segs) hgood i u tk
  rw [hul] at td trem hlen
  rw [ht5'] at td tctr
  rw [List.append_assoc, hmA, hwA] at td tst
  have hcnt := (O.hcnt s.hdr s.verdict (liftH G) seg.core _ ch recs acc t4 hsl hshape.1).1
  refine ⟨seg, hof, by rw [hpart]; exact habs, fun hx => ⟨?_⟩⟩
  rw [hpart] at hx ⊢
  have hok := O.pA.hok (s.hdr, s.verdict) (liftH G) seg.core.aRoot acc.claims.a seg.core.aOpen t5 t6 h6
  rw [hA.htag, hA.hpt, hA.hlc'] at hok
  have hr13 : (rkR13 O.pA.rows (R.pf.off i + 2)).rows = O.pA.rows := rfl
  exact
    { tA := t5
      tH := t6
      zo := seg.core.aOpen
      c := R.pf.sqAt i + stpsSq u
      rs := (pcsStps p.wH p.mH seg.core.hOpen ++ pcsStps p.wX p.mX (seg.closes.headD IncV.ozk0))
        ++ rtPartsStps (R.pf.parts.drop (i + 1)) ((R.rd (s, segs)).2.drop (i + 1))
      prm := O.pA.prm
      ev := O.pA.ev
      cl := acc.claims.a
      root := seg.core.aRoot
      hpl := hlen
      hdrop := td
      hpre := trem
      hctr := tctr
      hst := tst
      hvpos := rfl
      haB := by
        rw [hgA, hr13]
        have := O.hwA
        simp only [RtPart.oBA]
        omega
      hlc := hA.hlc
      hqp := by rw [O.pA.hqp, hA.hQ]; rfl
      hnQ := by rw [O.pA.hnQ, hA.hQ]; rfl
      hnn := by rw [O.pA.hnn, hA.hN]; rfl
      hpow := by rw [O.pA.hnn]; exact O.pA.hpow
      hQ0 := by norm_num [rkR13]
      hm := by norm_num [rkR13]
      hspec := hA.hspec
      hok := hok
      hcnt := hcnt
      hrd := by
        show (rkAccOutc W (R.pf.off i + 2) (R.pf.off i + p.pre)
          ((R.tr G (s, segs)).take (R.pf.off i + p.oA))).claims.a = acc.claims.a
        rw [hread ((R.tr G (s, segs)).take (R.pf.off i + p.oA)) (rk_take_take_le _ _ _ hle)]
      hcan := hcanC.2.2.1
      hcolX := hx }

/-- **Stage OUT-C's `H`** (with the LogUp sum claim): its root absorbed at `off i + 8`, `RhOpW` given its
extraction. -/
theorem rs_outc_opH (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i : ℕ) (p : RtPart)
    (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom) (O : RtOutc Lq outc outcG p)
    (hσi : R.σs[i]? = some (rtOutcSeg outc outcG p))
    (W : List (TItem × Dig) → OutcV)
    (hW : W ((R.tr G (s, segs)).take (R.pf.off i + p.pre)) = outc s.hdr s.verdict)
    (hH : RkPcsR13 U tag O.pH) (lsc : Block.ZClaim) (hlsc : (outc s.hdr s.verdict).lay.logupSumClaim = lsc)
    (lg : List (QB Lq × Dig)) :
    ∃ seg : StageSeg, rtStageOf (outcG s.hdr) (segs.getD i []) = some seg
      ∧ Block.absAt ((R.tr G (s, segs)).take (R.pf.off i + (R.pf.part i).oH)) (R.pf.off i + (2 + (4 + 2)))
          = some seg.core.hRoot.toList
      ∧ (RhXOk tag Lq h64 key domain hs hL (rkR13 O.pH.rows (R.pf.off i + (2 + (4 + 2)))) lg G
          ((R.tr G (s, segs)).take (R.pf.off i + (R.pf.part i).oH)) seg.core.hOpen seg.core.hRoot →
        Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (rkR13 O.pH.rows (R.pf.off i + (2 + (4 + 2))))
          O.nH (fun hdr => (rkAccOutc W (R.pf.off i + 2) (R.pf.off i + p.pre) hdr).claims.h ++ [lsc])
          (R.pf.off i + (R.pf.part i).oH) (R.pf.off i + (R.pf.part i).oBH)
          (R.pf.off i + (R.pf.part i).oH + (O.nH + O.pH.rows)) lg G (R.tr G (s, segs)))) := by
  obtain ⟨cr, seg, ch, recs, acc, t4, t5, t6, t7, t', -, hof, hcanC, hshape, -, hrdi, hpi, hsl, -, h5, h6, h7, -,
    hread⟩ := rs_outc_run R hv G s segs hE i p outc outcG hσi (O.hgeo s.hdr s.verdict) (O.hgt s.hdr s.verdict)
      (fun k hk => (O.hgeomL s.hdr s.verdict k hk).1) W hW
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  have hpart : R.pf.part i = p := rh_part_eq R.pf i p hpi
  have hpd : RtPartOk Lq p (rtOutcData (outc s.hdr s.verdict) seg) := rk_forall₂_getElem? hgood.2.2.2 i p _ hpi hrdi
  have hgA : seg.core.aOpen.groupVecs.length = p.gA := hpd.2.2.1
  have hgH : seg.core.hOpen.groupVecs.length = p.gH := hpd.2.2.2.1
  have hd1 : ∀ j, j < seg.core.slots.length → 1 ≤ (Block.slotShape (outc s.hdr s.verdict).bp j).2.2 :=
    fun j hj => (O.hgeomL s.hdr s.verdict j (by rw [← hshape.1]; exact hj)).1
  have ht4 := rt_outcSlots_tr (liftH G) (outc s.hdr s.verdict) seg.core _ ch recs acc t4 hsl hd1
  rw [O.hPm s.hdr s.verdict] at h5
  have ht5 := (rt_mask_tr O.tag p.S (liftH G) _ _ _ t4 t5 h5).1
  obtain ⟨hcA, hcH, -⟩ := O.hcnt s.hdr s.verdict (liftH G) seg.core _ ch recs acc t4 hsl hshape.1
  have ht6 := (O.pA.tr (s.hdr, s.verdict) (liftH G) seg.core.aRoot acc.claims.a seg.core.aOpen t5 t6 h6 O.nA hcA).1
  have hmH : p.mH = 64 := by rw [← O.hmH]; exact hH.hm U tag
  have hwA : p.wA = O.nA + O.pA.rows := O.hwA.symm
  have hmA : p.mA = O.pA.m := O.hmA.symm
  have hwH : p.wH = O.nH + O.pH.rows := O.hwH.symm
  set u := opsStps (rtOutcData (outc s.hdr s.verdict) seg).pre ++ mStps p.S seg.core.maskOpen
      ++ pcsStps p.wA p.mA seg.core.aOpen with huDef
  obtain ⟨tk, td, trem, tctr, tst⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood i p
    (rtOutcData (outc s.hdr s.verdict) seg) hpi hrdi u
    (pcsStps p.wH p.mH seg.core.hOpen ++ pcsStps p.wX p.mX (seg.closes.headD IncV.ozk0))
    (by rw [huDef]; simp only [rtPartStps, rtOutcData, List.append_assoc])
  have hul : (stpsOps u).length = p.oH := by
    rw [huDef, stpsOps_append, stpsOps_append, List.length_append, List.length_append, stpsOps_opsStps,
      stpsOps_mStps_length, stpsOps_pcsStps_length, hpd.1, hgA]
    simp only [RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have hlpre : (stpsOps (rtPre R.pf (R.rd (s, segs)) i)).length = R.pf.off i := (rtPre_facts Lq R.pf _ hgood i).2.1
  have hp5 := rs_outcPre_len (outc s.hdr s.verdict) seg
  have hpl1 := hpd.1
  rw [hpd.1] at hp5
  have hle : R.pf.off i + p.pre ≤ R.pf.off i + p.oH := by
    simp only [RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have habs : Block.absAt ((R.tr G (s, segs)).take (R.pf.off i + p.oH)) (R.pf.off i + (2 + (4 + 2)))
      = some seg.core.hRoot.toList := by
    have tk' := tk
    rw [hul, stpsOps_append] at tk'
    refine rs_absAt_run (R.tr G (s, segs)) (liftH G) _ _ (stpsOps u) (R.pf.off i) _ _ _ Block.labH _ tk' hlpre
      (by omega) (by omega) ?_
    have hlt : 2 + (4 + 2) < (rtOutcData (outc s.hdr s.verdict) seg).pre.length := by omega
    rw [huDef, stpsOps_append, stpsOps_append, stpsOps_opsStps, List.append_assoc, List.getElem?_append_left hlt]
    exact (rs_outcPre_get (outc s.hdr s.verdict) seg.core).2.2
  have ht6' : runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i ++ u))
      = t6 := by
    rw [ht6, ht5, ht4, huDef, hwA, hmA]
    simp only [rtOutcData, stpsOps_append, stpsOps_opsStps, runOps_append, List.append_assoc]
  have hlen := rh_take_len key domain Lq R.pf R.rd G (s, segs) hgood i u tk
  rw [hul] at td trem hlen
  rw [ht6'] at td tctr
  rw [List.append_assoc, hmH, hwH] at td tst
  refine ⟨seg, hof, by rw [hpart]; exact habs, fun hx => ⟨?_⟩⟩
  rw [hpart] at hx ⊢
  have hok := O.pH.hok (s.hdr, s.verdict) (liftH G) seg.core.hRoot
    (acc.claims.h ++ [(outc s.hdr s.verdict).lay.logupSumClaim]) seg.core.hOpen t6 t7 h7
  rw [hH.htag, hH.hpt, hH.hlc', hlsc] at hok
  rw [hlsc] at hcH
  have hr13 : (rkR13 O.pH.rows (R.pf.off i + (2 + (4 + 2)))).rows = O.pH.rows := rfl
  exact
    { tA := t6
      tH := t7
      zo := seg.core.hOpen
      c := R.pf.sqAt i + stpsSq u
      rs := pcsStps p.wX p.mX (seg.closes.headD IncV.ozk0)
        ++ rtPartsStps (R.pf.parts.drop (i + 1)) ((R.rd (s, segs)).2.drop (i + 1))
      prm := O.pH.prm
      ev := O.pH.ev
      cl := acc.claims.h ++ [lsc]
      root := seg.core.hRoot
      hpl := hlen
      hdrop := td
      hpre := trem
      hctr := tctr
      hst := tst
      hvpos := rfl
      haB := by
        rw [hgH, hr13]
        have := O.hwH
        simp only [RtPart.oBH]
        omega
      hlc := hH.hlc
      hqp := by rw [O.pH.hqp, hH.hQ]; rfl
      hnQ := by rw [O.pH.hnQ, hH.hQ]; rfl
      hnn := by rw [O.pH.hnn, hH.hN]; rfl
      hpow := by rw [O.pH.hnn]; exact O.pH.hpow
      hQ0 := by norm_num [rkR13]
      hm := by norm_num [rkR13]
      hspec := hH.hspec
      hok := hok
      hcnt := hcH
      hrd := by
        show (rkAccOutc W (R.pf.off i + 2) (R.pf.off i + p.pre)
          ((R.tr G (s, segs)).take (R.pf.off i + p.oH))).claims.h ++ [lsc] = acc.claims.h ++ [lsc]
        rw [hread ((R.tr G (s, segs)).take (R.pf.off i + p.oH)) (rk_take_take_le _ _ _ hle)]
      hcan := hcanC.2.2.2
      hcolX := hx }

/-- **Stage OUT-C's `M`**: its root absorbed at `off i + 5`, the verifier's `MaskOk`, `RhMW` given its
extraction. -/
theorem rs_outc_M (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i : ℕ) (p : RtPart)
    (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom) (O : RtOutc Lq outc outcG p)
    (hσi : R.σs[i]? = some (rtOutcSeg outc outcG p))
    (W : List (TItem × Dig) → OutcV)
    (hW : W ((R.tr G (s, segs)).take (R.pf.off i + p.pre)) = outc s.hdr s.verdict)
    (htag : O.tag = tag) (kM : ℕ) (hkM : (outc s.hdr s.verdict).lay.nFunctionals = kM) (lg : List (QB Lq × Dig)) :
    ∃ (seg : StageSeg) (tM tA : Tr) (fs : List Block.MaskFunctional),
      rtStageOf (outcG s.hdr) (segs.getD i []) = some seg
      ∧ Block.absAt ((R.tr G (s, segs)).take (R.pf.off i + (R.pf.part i).pre)) (R.pf.off i + (2 + 3))
          = some seg.core.maskRoot.toList
      ∧ MaskOk (liftH G) tag (rootFp 9) (rootFp 12) seg.core.maskRoot p.S (fs.map toMF) (toMO seg.core.maskOpen) tM tA
      ∧ (RhXMOk tag Lq h64 key domain hs hL p.S (R.pf.off i + (2 + 3)) lg G
          ((R.tr G (s, segs)).take (R.pf.off i + (R.pf.part i).pre)) tM seg.core.maskOpen →
        Nonempty (RhMW tag Lq h64 key domain hs hL (rtW R.pf.sqs) p.S kM (R.pf.off i + (2 + 3))
          (fun hdr => (rkAccOutc W (R.pf.off i + 2) (R.pf.off i + p.pre) hdr).fs
            ++ (rkAccOutc W (R.pf.off i + 2) (R.pf.off i + p.pre) hdr).hostFs)
          (R.pf.off i + (R.pf.part i).pre) lg G (R.tr G (s, segs)))) := by
  obtain ⟨cr, seg, ch, recs, acc, t4, t5, t6, t7, t', -, hof, hcanC, hshape, -, hrdi, hpi, hsl, hnf, h5, -, -, -,
    hread⟩ := rs_outc_run R hv G s segs hE i p outc outcG hσi (O.hgeo s.hdr s.verdict) (O.hgt s.hdr s.verdict)
      (fun k hk => (O.hgeomL s.hdr s.verdict k hk).1) W hW
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  have hpart : R.pf.part i = p := rh_part_eq R.pf i p hpi
  have hpd : RtPartOk Lq p (rtOutcData (outc s.hdr s.verdict) seg) := rk_forall₂_getElem? hgood.2.2.2 i p _ hpi hrdi
  have hd1 : ∀ j, j < seg.core.slots.length → 1 ≤ (Block.slotShape (outc s.hdr s.verdict).bp j).2.2 :=
    fun j hj => (O.hgeomL s.hdr s.verdict j (by rw [← hshape.1]; exact hj)).1
  have ht4 := rt_outcSlots_tr (liftH G) (outc s.hdr s.verdict) seg.core _ ch recs acc t4 hsl hd1
  rw [O.hPm s.hdr s.verdict] at h5
  have hok : MaskOk (liftH G) O.tag (rootFp 9) (rootFp 12) seg.core.maskRoot p.S
      ((acc.fs ++ acc.hostFs).map toMF) (toMO seg.core.maskOpen) t4 t5 := by
    rw [maskField, mapErr_ok, w16r2MCheck_ok_iff] at h5
    exact h5
  rw [htag] at hok
  set u := opsStps (rtOutcData (outc s.hdr s.verdict) seg).pre with huDef
  obtain ⟨tk, td, trem, tctr, tst⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood i p
    (rtOutcData (outc s.hdr s.verdict) seg) hpi hrdi u
    (mStps p.S seg.core.maskOpen ++ (pcsStps p.wA p.mA seg.core.aOpen ++ (pcsStps p.wH p.mH seg.core.hOpen
      ++ pcsStps p.wX p.mX (seg.closes.headD IncV.ozk0))))
    (by rw [huDef]; simp only [rtPartStps, rtOutcData])
  have hul : (stpsOps u).length = p.pre := by
    rw [huDef, stpsOps_opsStps, hpd.1]
  have hlpre : (stpsOps (rtPre R.pf (R.rd (s, segs)) i)).length = R.pf.off i := (rtPre_facts Lq R.pf _ hgood i).2.1
  have hp5 := rs_outcPre_len (outc s.hdr s.verdict) seg
  have hpl1 := hpd.1
  rw [hpd.1] at hp5
  have habs : Block.absAt ((R.tr G (s, segs)).take (R.pf.off i + p.pre)) (R.pf.off i + (2 + 3))
      = some seg.core.maskRoot.toList := by
    have tk' := tk
    rw [hul, stpsOps_append] at tk'
    refine rs_absAt_run (R.tr G (s, segs)) (liftH G) _ _ (stpsOps u) (R.pf.off i) _ _ _ Block.labM _ tk' hlpre
      (by omega) (by omega) ?_
    rw [huDef, stpsOps_opsStps]
    exact (rs_outcPre_get (outc s.hdr s.verdict) seg.core).2.1
  have ht4' : runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i ++ u))
      = t4 := by
    rw [ht4, huDef]
    simp only [rtOutcData, stpsOps_append, stpsOps_opsStps, runOps_append]
  have hlen := rh_take_len key domain Lq R.pf R.rd G (s, segs) hgood i u tk
  rw [hul] at td trem hlen
  rw [ht4'] at td tctr
  rw [List.append_assoc] at td tst
  refine ⟨seg, t4, t5, acc.fs ++ acc.hostFs, hof, by rw [hpart]; exact habs, hok, fun hx => ⟨?_⟩⟩
  rw [hpart] at hx ⊢
  exact
    { tM := t4
      tA := t5
      mo := seg.core.maskOpen
      c := R.pf.sqAt i + stpsSq u
      rs := (pcsStps p.wA p.mA seg.core.aOpen ++ (pcsStps p.wH p.mH seg.core.hOpen
          ++ pcsStps p.wX p.mX (seg.closes.headD IncV.ozk0)))
        ++ rtPartsStps (R.pf.parts.drop (i + 1)) ((R.rd (s, segs)).2.drop (i + 1))
      root := seg.core.maskRoot
      fs := acc.fs ++ acc.hostFs
      hpl := hlen
      hdrop := td
      hpre := trem
      hctr := tctr
      hst := tst
      hcan := hcanC.2.1
      hok := hok
      hk := hnf.trans hkM
      hrd := by
        show (rkAccOutc W (R.pf.off i + 2) (R.pf.off i + p.pre)
            ((R.tr G (s, segs)).take (R.pf.off i + p.pre))).fs
          ++ (rkAccOutc W (R.pf.off i + 2) (R.pf.off i + p.pre)
            ((R.tr G (s, segs)).take (R.pf.off i + p.pre))).hostFs = acc.fs ++ acc.hostFs
        rw [hread ((R.tr G (s, segs)).take (R.pf.off i + p.pre)) (rk_take_take_le _ _ _ le_rfl)]
      hcols := hx }

end Outc

end ZK60.ProtocolClassify
