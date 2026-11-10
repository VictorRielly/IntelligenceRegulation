/-
D63 lane L55 (2026-11-10), part 11: **the top theorem's `hopX1` at parts `1` and `Lb + 1`, in its own form** (the kinds
data `rxPs`, the readers `rxAcc`; the brief's deliverable 2).

* **`cb_hopX1_one`**: at part `1` (block `0`, opening `B_in`), from `cb_inc_opX`, when part `1`'s closing geometry is
  the boundary's at R13 with the root at `off 0 + 2` (`hgX1`) and `I.nOut + nIn (0)` claims (`hnX1`), block `0`'s
  closing width is the run schedule's (`hwX0`, `hmX0`), and IN-C's reader is its verifier (`hWin`: `hW`'s first half);
* **`cb_hopX1_last`**: at part `Lb + 1` (stage OUT-C, opening `B_out`), from `cb_outc_opX`, when part `Lb + 1`'s
  closing geometry is the boundary's at R13 with the root at `off Lb + 2` (`hgXo`) and `nOut (Lb − 1) + O.nIn` claims
  (`hnXo`), OUT-C's closing width is the run schedule's (`hwXo`), `B_out`'s verifier has R13's numbers (`hOX`: met at
  the real stage, `rcOutcAt_pX_bnd_r13`), and OUT-C's reader is its verifier (`hWout`: `hW`'s second half);
* **`rcOutcAt_pX_bnd_r13`**: the real OUT-C's `B_out` verifier in L43's form `RkPcsR13`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunCloseBInc
import ZK60Formal.RunEpBOpen

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Exec.StageV ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)

section Real

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)

/-- **Stage OUT-C's `B_out` verifier at the real stage, in L43's form `RkPcsR13`** (`geo.bLogN = 14`, `blr = 2`,
`bq = 256`). -/
theorem rcOutcAt_pX_bnd_r13 (O : OutcPub) (geo : OutcGeo) (blk bd : Block.Dim) (idx lr q total pend : ℕ) (hq : 0 < q)
    (hbq : 0 < 256) (h15 : 2 ^ O.lt + q ≤ 2 ^ 15) (hb15 : 2 ^ geo.bLogN + 256 ≤ 2 ^ 15) (hb : geo.bLogN = 14) :
    RkPcsR13 U tag
      (rcOutcAt (Hdr := Hdr) Lq hL20 tag O geo blk bd idx lr 2 q 256 total pend hq hbq h15 hb15).pX :=
  rcPcsAt_bnd_r13 U tag _ _ _ (fun _ _ _ _ _ _ => rfl) hbq hb15 hb

end Real

section Ends

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag)
  {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
  (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **THE TOP THEOREM'S `hopX1` AT PART `1`** (block `0`'s closing opening, `B_in`), in its own form. -/
theorem cb_hopX1_one (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (Lb : ℕ) (hLb1 : 0 < Lb)
    (pin : RtPart) (inc : Hdr → IncV) (incG : Hdr → StageGeom) (cx0 : IncCtx) (I : RtInc Lq inc incG pin)
    (hσ0 : R.σs[0]? = some (rtIncSeg inc incG cx0 pin))
    (Win : List (TItem × Dig) → IncV) (hWin : Win ((R.tr G (s, segs)).take (R.pf.off 0 + pin.pre)) = inc s.hdr)
    (bp : ∀ k, RtBlk Lq (Pk k)) (pp : ℕ → RtPart)
    (hσb : ∀ k, k < Lb → R.σs[k + 1]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k (pp k)))
    (hgeo : ∀ s k, (sgeom s k).g = (Pk k).geom)
    (hS : ∀ k, (pp k).S = (bp k).S) (hwA : ∀ k, (pp k).wA = (bp k).nA + (bp k).pA.rows)
    (hmA : ∀ k, (pp k).mA = (bp k).pA.m) (hwH : ∀ k, (pp k).wH = (bp k).nH + (bp k).pH.rows)
    (hmH : ∀ k, (pp k).mH = (bp k).pH.m)
    (pXk : ∀ k, RtPcs (fun (s : ClsStmt Hdr) H root cl o t => bndOpen H s k root cl o t))
    (hXk : ∀ k, RkPcsR13 U tag (pXk k))
    (hwX0 : (pp 0).wX = I.nOut + (bp 0).nIn + (pXk 0).rows) (hmX0 : (pp 0).mX = (pXk 0).m)
    (hfitXk : ∀ k, 8 * (pXk k).rows ≤ Lq)
    (base : ℕ → RkPart K Lq) (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH)
    (hgX1 : (base 1).gX = rkR13 (pXk 0).rows (R.pf.off 0 + 2)) (hnX1 : (base 1).nX = I.nOut + (bp 0).nIn)
    (Wout : List (TItem × Dig) → OutcV) (rdx : List UInt8 → Option Dig)
    (outcG : Hdr → StageGeom) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (hrun : A.run G = (s, segs))
    (hXev : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G) :
    EbXW U tag Lq h64 key domain hs hL rdx 1 (rtW R.pf.sqs) ((rxPs base Lb din dblk dout) 1).gX
      ((rxPs base Lb din dblk dout) 1).nX
      (fun hdr => rkPend (rxAcc Win Wout Pk R.pf Lb) 1 hdr ++ ((rxAcc Win Wout Pk R.pf Lb) 1 hdr).claims.inp)
      (R.pf.off 1 + (R.pf.part 1).oX) (R.pf.off 1 + (R.pf.part 1).oBX)
      (R.pf.off 1 + (R.pf.part 1).oX + (((rxPs base Lb din dblk dout) 1).nX
        + ((rxPs base Lb din dblk dout) 1).gX.rows)) (A.runLog G).2 G (R.tr G (s, segs)) := by
  obtain ⟨w⟩ := cb_inc_opX U tag h64 hs hL Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv G s segs hE pin
    inc incG cx0 I hσ0 Win hWin (bp 0) (pp 0) (hσb 0 hLb1) (fun s => hgeo s 0) (hS 0) (hwA 0) (hmA 0) (hwH 0) (hmH 0)
    (pXk 0) (hXk 0) hwX0 hmX0 outcG Lb A hrun hXev (hfitXk 0)
  have hP : rxPs base Lb din dblk dout 1 = rxSet (base 1) (dblk 0) := rxPs_blk _ _ _ _ _ 0 hLb1
  have hg : ((rxPs base Lb din dblk dout) 1).gX = rkR13 (pXk 0).rows (R.pf.off 0 + 2) := by
    rw [hP]
    exact hgX1
  have hn : ((rxPs base Lb din dblk dout) 1).nX = I.nOut + (bp 0).nIn := by
    rw [hP]
    exact hnX1
  show Nonempty (RhOpW U tag Lq h64 key domain hs hL _ _ _ _ _ _ _ _ _ _)
  rw [hg, hn]
  refine ⟨{ w with hrd := ?_ }⟩
  have hA1 : rxAcc Win Wout Pk R.pf Lb 1 = rkAccBlk (Pk 0) (R.pf.off 1 + 5) (R.pf.off 1 + (R.pf.part 1).pre) :=
    rxAcc_blk _ _ _ _ _ 0 hLb1
  show (rxAcc Win Wout Pk R.pf Lb 0 _).claims.out ++ (rxAcc Win Wout Pk R.pf Lb 1 _).claims.inp = w.cl
  rw [hA1]
  exact w.hrd

/-- **THE TOP THEOREM'S `hopX1` AT PART `Lb + 1`** (stage OUT-C's closing opening, `B_out`), in its own form. -/
theorem cb_hopX1_last (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (Lb : ℕ) (hLb1 : 0 < Lb)
    (hLb : Lb ≤ 26) (bp : ∀ k, RtBlk Lq (Pk k)) (pp : ℕ → RtPart)
    (hσb : ∀ k, k < Lb → R.σs[k + 1]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k (pp k)))
    (hgeo : ∀ s k, (sgeom s k).g = (Pk k).geom)
    (pout : RtPart) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom) (Oout : RtOutc Lq outc outcG pout)
    (hσo : R.σs[Lb + 1]? = some (rtOutcSeg outc outcG pout))
    (Wout : List (TItem × Dig) → OutcV)
    (hWout : Wout ((R.tr G (s, segs)).take (R.pf.off (Lb + 1) + pout.pre)) = outc s.hdr s.verdict)
    (hOX : RkPcsR13 U tag Oout.pX) (hwXo : ∀ k, k + 1 = Lb → pout.wX = (bp k).nOut + Oout.nIn + Oout.pX.rows)
    (hfitXo : 8 * Oout.pX.rows ≤ Lq)
    (base : ℕ → RkPart K Lq) (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH)
    (hgXo : ∀ k, k + 1 = Lb → (base (k + 1 + 1)).gX = rkR13 Oout.pX.rows (R.pf.off (k + 1) + 2))
    (hnXo : ∀ k, k + 1 = Lb → (base (k + 1 + 1)).nX = (bp k).nOut + Oout.nIn)
    (Win : List (TItem × Dig) → IncV) (rdx : List UInt8 → Option Dig)
    (incG : Hdr → StageGeom) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (hrun : A.run G = (s, segs))
    (hXev : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G) :
    EbXW U tag Lq h64 key domain hs hL rdx (Lb + 1) (rtW R.pf.sqs) ((rxPs base Lb din dblk dout) (Lb + 1)).gX
      ((rxPs base Lb din dblk dout) (Lb + 1)).nX
      (fun hdr => rkPend (rxAcc Win Wout Pk R.pf Lb) (Lb + 1) hdr
        ++ ((rxAcc Win Wout Pk R.pf Lb) (Lb + 1) hdr).claims.inp)
      (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oX) (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oBX)
      (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oX + (((rxPs base Lb din dblk dout) (Lb + 1)).nX
        + ((rxPs base Lb din dblk dout) (Lb + 1)).gX.rows)) (A.runLog G).2 G (R.tr G (s, segs)) := by
  obtain ⟨k, rfl⟩ : ∃ k, Lb = k + 1 := ⟨Lb - 1, by omega⟩
  obtain ⟨w⟩ := cb_outc_opX U tag h64 hs hL Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv G s segs hE k
    (by omega) (bp k) (pp k) pout (hσb k (by omega)) outc outcG Oout hσo (fun s => hgeo s k) Wout hWout hOX
    (hwXo k rfl) incG A hrun hXev hfitXo
  have hP : rxPs base (k + 1) din dblk dout (k + 1 + 1) = rxSet (base (k + 1 + 1)) dout := rxPs_out _ _ _ _ _
  have hg : ((rxPs base (k + 1) din dblk dout) (k + 1 + 1)).gX = rkR13 Oout.pX.rows (R.pf.off (k + 1) + 2) := by
    rw [hP]
    exact hgXo k rfl
  have hn : ((rxPs base (k + 1) din dblk dout) (k + 1 + 1)).nX = (bp k).nOut + Oout.nIn := by
    rw [hP]
    exact hnXo k rfl
  show Nonempty (RhOpW U tag Lq h64 key domain hs hL _ _ _ _ _ _ _ _ _ _)
  rw [hg, hn]
  refine ⟨{ w with hrd := ?_ }⟩
  have hAk : rxAcc Win Wout Pk R.pf (k + 1) (k + 1)
      = rkAccBlk (Pk k) (R.pf.off (k + 1) + 5) (R.pf.off (k + 1) + (R.pf.part (k + 1)).pre) :=
    rxAcc_blk _ _ _ _ _ k (by omega)
  have hAo : rxAcc Win Wout Pk R.pf (k + 1) (k + 1 + 1)
      = rkAccOutc Wout (R.pf.off (k + 1 + 1) + 2) (R.pf.off (k + 1 + 1) + (R.pf.part (k + 1 + 1)).pre) :=
    rxAcc_out _ _ _ _ _
  show (rxAcc Win Wout Pk R.pf (k + 1) (k + 1) _).claims.out
      ++ (rxAcc Win Wout Pk R.pf (k + 1) (k + 1 + 1) _).claims.inp = w.cl
  rw [hAk, hAo]
  exact w.hrd

end Ends

end ZK60.ProtocolClassify
