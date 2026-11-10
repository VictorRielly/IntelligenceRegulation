/-
D63 lane L43 (2026-11-10), part 5: **`hal_opB` and `hal_M` at the run's REAL block parts** (the real objects meet the
acceptance facts `RhOpW`, `RhMW` of `RunHalOpB.lean`, `RunHalM.lean`; only the extraction is left).

On an accepted run, at a part `i` of the schedule that is a D12a block `k` (`rtBlockSeg`, with L34's counts
`rtBlockPart` from the block's contract `RtBlk`), the facts `rh_opB_alive` and `rh_M_alive` ask are PROVED from the
acceptance, with the block's readers of `rkData` (`rkAccBlk`, `RunKindsDataBlk.lean`):

* the run's transcript from `M`'s, `A`'s and `H`'s windows is the trace of their steps on the transcript the verifier
  itself used (`rtTr_part`, L22's `blockSlots_tr`, L34's `rt_mask_tr`, `RtPcs.tr`), at the profile's counters, with the
  parse agreeing (finding L34-1 at the run, directly);
* `MaskOk` and `PcsOk` hold there (`maskField`, the openings' `RtPcs`), on the functionals and claims the reader
  returns (`rk_blk_run`), with the code's counts (`RtBlk.hcnt`), on canonical openings (`decodeSegment_spec`).

What is left is each opening's extraction (`RhXOk`, `RhXMOk`): every opened column that verifies against the root the
verifier used is the column extracted for the root the header absorbs at the opening's position. It is the audit's
class (a) bookkeeping premise GA-8 (the run's Merkle work `Vx`, `coreOf`, `rx` and the chain `C` of `EvXR` are free
parameters of the top theorem); outside `EvXR`, with `C`, `coreOf` the run's, L27's `opened_eq_extracted_run` gives it.

* `RhXOk`, `RhXMOk`: the extraction facts;
* **`rh_blk_opA`**, **`rh_blk_opH`**: `A`'s and `H`'s `RhOpW` at a block part, given their extraction;
* **`rh_blk_M`**: `M`'s `RhMW` at a block part, given its extraction.

The R13 numbers of the openings' parameters (`Q = 256`, `N = 2^16`, `log_cols = 14`, the coset points, the column
evaluator's `ColEncSpec`, the tag) are premises `RkPcsR13` on the block's `RtPcs`; at the code's R13 opening
(`pcsFieldR13`) the evaluator's spec is L28's `r13_colEnc_spec`.

D63 lane L48 (2026-11-10), edited in place under its brief's exception (finding L45-2): `RkPcsAt`, an opening
verifier's numbers at any code geometry `OGeo`, `RkPcsAt.hm`, and `RkPcsR13.at` (`RkPcsR13` is `RkPcsAt ogR13`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunKindsDataBlk
import ZK60Formal.RunHalM

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape)

/-! ## The extraction facts and the openings' R13 numbers -/

section Facts

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig)
  (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

/-- **An opening's extraction** at a header (GA-8): every sampled column of the opening `zo` that verifies against
`root` at depth `g.h`, with `g.rows` values, is the column extracted for the root the header absorbs at `g.ipos`. -/
def RhXOk (g : RkGeo) (P : List (QB Lq × Dig)) (G : QB Lq → Dig) (hdr : List (TItem × Dig)) (zo : Block.OpeningZk)
    (root : Dig) : Prop :=
  ∀ (k : ℕ), k < g.Q → k < zo.columns.length →
    ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.2.length = g.h →
    verifyPath (liftH G) tag root ((toOZ zo).columns.getD k (0, [], zeroDig, [])).1
      (saltLeaf (liftH G) tag (colDigest (liftH G) tag ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1)
        ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.1) ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.2
      = true →
    ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1.length = g.rows →
    (colX tag Lq h64 key domain hs hL g.h g.ipos P hdr ((toOZ zo).columns.getD k (0, [], zeroDig, [])).1).map
      Subtype.val = some ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1

/-- **`M`'s extraction** at a header: at every index `M`'s check samples on `tM`, the table extracted for the root the
header absorbs at `mpos` is the opened column. -/
def RhXMOk (S mpos : ℕ) (P : List (QB Lq × Dig)) (G : QB Lq → Dig) (hdr : List (TItem × Dig)) (tM : Tr)
    (mo : Block.MaskOpening) : Prop :=
  ∀ (j : Fin mQ)
    (hj : (idxOf mDom mQ (sqDs (liftH G) (runOps (liftH G) tM (stpsOps (mPre S mo))) 64)).getD j 0 < 2 ^ 12),
    rkColsM tag Lq h64 key domain hs hL mpos P hdr
        ⟨(idxOf mDom mQ (sqDs (liftH G) (runOps (liftH G) tM (stpsOps (mPre S mo))) 64)).getD j 0, hj⟩
      = (mo.columns.getD j ⟨0, [], zeroDig, []⟩).col

/-- **An opening verifier's R13 numbers** (L28's geometry `(16, 256, ·)`): `256` queries and pads, codewords of
`2^16`, `log_cols 14`, the coset points `7·G_{2^16}`, a column evaluator meeting `ColEncSpec`, the run's Merkle tag. -/
structure RkPcsR13 {ι : Type}
    {V : ι → (HIn → Dig) → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr} (pc : RtPcs V) :
    Prop where
  hQ : pc.Q = 256
  hN : pc.N = 2 ^ 16
  hlc : pc.prm.logCols = 14
  hlc' : pc.lc = 14
  hpt : pc.pt = cosetPt (rootFp 16)
  hspec : ColEncSpec U (RW (K := K)) 256 (cosetPt (rootFp 16)) pc.ev
  htag : pc.tag = tag

theorem RkPcsR13.hm {ι : Type}
    {V : ι → (HIn → Dig) → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr} {pc : RtPcs V}
    (h : RkPcsR13 U tag pc) : pc.m = 64 := by
  rw [← pc.hm, h.hQ]

/-- **An opening verifier's numbers at a code geometry `g`** (D63 lane L48, finding L45-2; `RkPcsR13` is the instance
`g = ogR13`): `g.Q` queries and pads, codewords of `2^g.h`, `log_cols g.lc`, the coset points `7·G_{2^g.h}`, a column
evaluator meeting `ColEncSpec` at the width's row form `RWL g.lc`, the run's Merkle tag. -/
structure RkPcsAt {ι : Type}
    {V : ι → (HIn → Dig) → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr} (g : OGeo)
    (pc : RtPcs V) : Prop where
  hQ : pc.Q = g.Q
  hN : pc.N = 2 ^ g.h
  hlc : pc.prm.logCols = g.lc
  hlc' : pc.lc = g.lc
  hpt : pc.pt = cosetPt (rootFp g.h)
  hspec : ColEncSpec U (RWL (K := K) g.lc) g.Q (cosetPt (rootFp g.h)) pc.ev
  htag : pc.tag = tag

theorem RkPcsAt.hm {ι : Type}
    {V : ι → (HIn → Dig) → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr} {g : OGeo}
    {pc : RtPcs V} (h : RkPcsAt U tag g pc) (hm : (g.Q + 3) / 4 = g.mI) : pc.m = g.mI := by
  rw [← pc.hm, h.hQ, hm]

/-- **`RkPcsR13` is `RkPcsAt` at R13's block geometry** (`RWL 14 = RW`). -/
theorem RkPcsR13.at {ι : Type}
    {V : ι → (HIn → Dig) → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr} {pc : RtPcs V}
    (h : RkPcsR13 U tag pc) : RkPcsAt U tag ogR13 pc where
  hQ := h.hQ
  hN := h.hN
  hlc := h.hlc
  hlc' := h.hlc'
  hpt := h.hpt
  hspec := by
    show ColEncSpec U (RWL (K := K) 14) 256 (cosetPt (rootFp 16)) pc.ev
    rw [RWL_14]
    exact h.hspec
  htag := h.htag

end Facts

theorem rh_part_eq (pf : RtProf) (i : ℕ) (p : RtPart) (h : pf.parts[i]? = some p) : pf.part i = p := by
  unfold RtProf.part
  rw [List.getD_eq_getElem?_getD, h]
  rfl

theorem rh_take_len (key : Option Dig) (domain : List UInt8) (Lq : ℕ) {α : Type} (pf : RtProf)
    (rd : α → List Op × List RtData) (G : QB Lq → Dig) (o : α) (h : RtGood Lq pf (rd o)) (i : ℕ) (u : List Stp)
    (tk : (rtTr key domain Lq pf rd G o).take (pf.off i + (stpsOps u).length)
      = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre pf (rd o) i ++ u))) :
    ((rtTr key domain Lq pf rd G o).take (pf.off i + (stpsOps u).length)).length = pf.off i + (stpsOps u).length := by
  rw [tk, Block.opTrace_length, stpsOps_append, List.length_append, (rtPre_facts Lq pf (rd o) h i).2.1]

/-! ## The block's openings and `M` at the run -/

section Blk

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K) (tag : MTag)
  {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
  {S : BlockShape} {Salt Coins : Type}
  (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

omit [Fintype K] [DecidableEq K] in
/-- **`A`'s acceptance facts at a block part of an accepted run.** At part `i`, D12a block `k` with L34's counts, on
the run's transcript: `A` (its geometry R13's, its root's position `aPos`, its claims read by `rkAccBlk`) meets
`RhOpW` as soon as it meets its extraction at the opening the verifier opened. -/
theorem rh_blk_opA (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i k : ℕ)
    (bp : RtBlk Lq (Pk k)) (wX gX mX : ℕ)
    (hσi : R.σs[i]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
      (rtBlockPart (Pk k) bp.S (bp.nA + bp.pA.rows) bp.pA.m (bp.nH + bp.pH.rows) bp.pH.m wX gX mX)))
    (hgeo : ∀ s, (sgeom s k).g = (Pk k).geom) (hA : RkPcsR13 U tag bp.pA) (aPos : ℕ) (lg : List (QB Lq × Dig)) :
    ∃ (zo : Block.OpeningZk) (root : Dig),
      RhXOk tag Lq h64 key domain hs hL (rkR13 bp.pA.rows aPos) lg G
        ((R.tr G (s, segs)).take (R.pf.off i + (R.pf.part i).oA)) zo root →
      Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (rkR13 bp.pA.rows aPos) bp.nA
        (fun hdr => (rkAccBlk (Pk k) (R.pf.off i + 5)
          (R.pf.off i + (rtBlockPart (Pk k) bp.S (bp.nA + bp.pA.rows) bp.pA.m (bp.nH + bp.pH.rows) bp.pH.m wX gX
            mX).pre) hdr).claims.a)
        (R.pf.off i + (R.pf.part i).oA) (R.pf.off i + (R.pf.part i).oBA)
        (R.pf.off i + (R.pf.part i).oA + (bp.nA + bp.pA.rows)) lg G (R.tr G (s, segs))) := by
  set p := rtBlockPart (Pk k) bp.S (bp.nA + bp.pA.rows) bp.pA.m (bp.nH + bp.pH.rows) bp.pH.m wX gX mX with hpDef
  have hS : p.S = bp.S := rfl
  have hwA : p.wA = bp.nA + bp.pA.rows := rfl
  have hmA : p.mA = 64 := hA.hm U tag
  have hr13 : (rkR13 bp.pA.rows aPos).rows = bp.pA.rows := rfl
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
  -- the verifier's transcript before `A`
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
  have htA' : runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i ++ u))
      = tA := by
    rw [htA, htM, huDef, hgd, hS]
    simp only [stpsOps_append, stpsOps_opsStps, runOps_append, List.append_assoc]
  have hlen := rh_take_len key domain Lq R.pf R.rd G (s, segs) hgood i u tk
  rw [hul] at td trem hlen
  rw [htA'] at td tctr
  rw [List.append_assoc, hmA, hwA] at td tst
  have hcnt := (bp.hcnt (liftH G) sg.core _ bga rs acc tM hbs hshape.1).1
  have hle : R.pf.off i + p.pre ≤ R.pf.off i + p.oA := by simp only [RtPart.oA]; omega
  refine ⟨sg.core.aOpen, sg.core.aRoot, fun hx => ⟨?_⟩⟩
  rw [hpart] at hx ⊢
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
        rw [hgA]
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

omit [Fintype K] [DecidableEq K] in
/-- **`H`'s acceptance facts at a block part of an accepted run** (with the LogUp sum claim among its claims, as the
verifier passes them). -/
theorem rh_blk_opH (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i k : ℕ)
    (bp : RtBlk Lq (Pk k)) (wX gX mX : ℕ)
    (hσi : R.σs[i]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
      (rtBlockPart (Pk k) bp.S (bp.nA + bp.pA.rows) bp.pA.m (bp.nH + bp.pH.rows) bp.pH.m wX gX mX)))
    (hgeo : ∀ s, (sgeom s k).g = (Pk k).geom) (hH : RkPcsR13 U tag bp.pH) (hPos : ℕ) (lg : List (QB Lq × Dig)) :
    ∃ (zo : Block.OpeningZk) (root : Dig),
      RhXOk tag Lq h64 key domain hs hL (rkR13 bp.pH.rows hPos) lg G
        ((R.tr G (s, segs)).take (R.pf.off i + (R.pf.part i).oH)) zo root →
      Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (rkR13 bp.pH.rows hPos) bp.nH
        (fun hdr => (rkAccBlk (Pk k) (R.pf.off i + 5)
          (R.pf.off i + (rtBlockPart (Pk k) bp.S (bp.nA + bp.pA.rows) bp.pA.m (bp.nH + bp.pH.rows) bp.pH.m wX gX
            mX).pre) hdr).claims.h ++ [(Pk k).logupSumClaim])
        (R.pf.off i + (R.pf.part i).oH) (R.pf.off i + (R.pf.part i).oBH)
        (R.pf.off i + (R.pf.part i).oH + (bp.nH + bp.pH.rows)) lg G (R.tr G (s, segs))) := by
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
  have htH' : runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i ++ u))
      = tH := by
    rw [htH, htA, htM, huDef, hgd, hS, hwA, hmA']
    simp only [stpsOps_append, stpsOps_opsStps, runOps_append, List.append_assoc]
  have hlen := rh_take_len key domain Lq R.pf R.rd G (s, segs) hgood i u tk
  rw [hul] at td trem hlen
  rw [htH'] at td tctr
  rw [List.append_assoc, hmH, hwH] at td tst
  have hle : R.pf.off i + p.pre ≤ R.pf.off i + p.oH := by
    simp only [RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  refine ⟨sg.core.hOpen, sg.core.hRoot, fun hx => ⟨?_⟩⟩
  rw [hpart] at hx ⊢
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
        have hr13H : (rkR13 bp.pH.rows hPos).rows = bp.pH.rows := rfl
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

/-- **`M`'s acceptance facts at a block part of an accepted run**: from `M`'s window the run's transcript runs `M`'s
steps on the transcript the verifier checked `M` on, `MaskOk` holds there on the functionals the reader returns (the
block's functional count), given the extraction at `M`'s root. -/
theorem rh_blk_M (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i k : ℕ)
    (bp : RtBlk Lq (Pk k)) (wX gX mX : ℕ)
    (hσi : R.σs[i]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
      (rtBlockPart (Pk k) bp.S (bp.nA + bp.pA.rows) bp.pA.m (bp.nH + bp.pH.rows) bp.pH.m wX gX mX)))
    (hgeo : ∀ s, (sgeom s k).g = (Pk k).geom) (htag : bp.tag = tag) (mpos : ℕ) (lg : List (QB Lq × Dig)) :
    ∃ (tM : Tr) (mo : Block.MaskOpening),
      RhXMOk tag Lq h64 key domain hs hL bp.S mpos lg G ((R.tr G (s, segs)).take (R.pf.off i + (R.pf.part i).pre))
        tM mo →
      Nonempty (RhMW tag Lq h64 key domain hs hL (rtW R.pf.sqs) bp.S (Pk k).nFunctionals mpos
        (fun hdr => (rkAccBlk (Pk k) (R.pf.off i + 5)
          (R.pf.off i + (rtBlockPart (Pk k) bp.S (bp.nA + bp.pA.rows) bp.pA.m (bp.nH + bp.pH.rows) bp.pH.m wX gX
            mX).pre) hdr).fs
          ++ (rkAccBlk (Pk k) (R.pf.off i + 5)
          (R.pf.off i + (rtBlockPart (Pk k) bp.S (bp.nA + bp.pA.rows) bp.pA.m (bp.nH + bp.pH.rows) bp.pH.m wX gX
            mX).pre) hdr).hostFs)
        (R.pf.off i + (R.pf.part i).pre) lg G (R.tr G (s, segs))) := by
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
  have htM' : runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i ++ u))
      = tM := by
    rw [htM, huDef, hgd]
    simp only [stpsOps_append, stpsOps_opsStps, runOps_append]
  have hlen := rh_take_len key domain Lq R.pf R.rd G (s, segs) hgood i u tk
  rw [hul] at td trem hlen
  rw [htM'] at td tctr
  rw [List.append_assoc, hS] at td tst
  refine ⟨tM, sg.core.maskOpen, fun hx => ⟨?_⟩⟩
  rw [hpart] at hx ⊢
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
