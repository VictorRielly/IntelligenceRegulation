/-
D63 lane L55 (2026-11-10), part 7: **the top theorem's `hopX1` at the block parts that follow a block part
(`2 ≤ i ≤ Lb`), in its own form** (the kinds data `rxPs`, the readers `rxAcc`; the brief's deliverable 2).

* **`cb_hopX1_mid`**: on an accepted run outside L45's `EvXR`, for every `k` with `k + 1 < Lb`, the top theorem's
  closing-opening fact `EbXW` at part `k + 2` holds, from `cb_blk_opX`, when part `k + 2`'s closing geometry is the
  boundary's at R13 with the root at `off (k + 1) + 2` (`hgXk`) and `nOut (k) + nIn (k + 1)` claims (`hnXk`), each
  block's boundary opening has R13's numbers (`hXk`: met by the code's `bndOpen`, `cbBndPcs_r13`), and the blocks'
  closing widths are the run schedule's (`hwXk`, `hmXk`: as `rcRunClassifyAt` builds them).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunCloseBBlk
import ZK60Formal.RunEpBOpen

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom)
open ZK60.Circuit (gP GF)

section Mid

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag)
  {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
  (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **THE TOP THEOREM'S `hopX1` AT PARTS `2 … Lb`** (a block part after a block part), in its own form. -/
theorem cb_hopX1_mid (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (Lb : ℕ) (hLb : Lb ≤ 26)
    (bp : ∀ k, RtBlk Lq (Pk k)) (pp : ℕ → RtPart)
    (hσb : ∀ k, k < Lb → R.σs[k + 1]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k (pp k)))
    (hgeo : ∀ s k, (sgeom s k).g = (Pk k).geom)
    (hS : ∀ k, (pp k).S = (bp k).S) (hwA : ∀ k, (pp k).wA = (bp k).nA + (bp k).pA.rows)
    (hmA : ∀ k, (pp k).mA = (bp k).pA.m) (hwH : ∀ k, (pp k).wH = (bp k).nH + (bp k).pH.rows)
    (hmH : ∀ k, (pp k).mH = (bp k).pH.m)
    (pXk : ∀ k, RtPcs (fun (s : ClsStmt Hdr) H root cl o t => bndOpen H s k root cl o t))
    (hXk : ∀ k, RkPcsR13 U tag (pXk k))
    (hwXk : ∀ k, k + 1 < Lb → (pp (k + 1)).wX = (bp k).nOut + (bp (k + 1)).nIn + (pXk (k + 1)).rows)
    (hmXk : ∀ k, k + 1 < Lb → (pp (k + 1)).mX = (pXk (k + 1)).m)
    (hfitXk : ∀ k, 8 * (pXk k).rows ≤ Lq)
    (base : ℕ → RkPart K Lq) (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH)
    (hgXk : ∀ k, k + 1 < Lb → (base (k + 1 + 1)).gX = rkR13 (pXk (k + 1)).rows (R.pf.off (k + 1) + 2))
    (hnXk : ∀ k, k + 1 < Lb → (base (k + 1 + 1)).nX = (bp k).nOut + (bp (k + 1)).nIn)
    (Win : List (TItem × Dig) → IncV) (Wout : List (TItem × Dig) → OutcV) (rdx : List UInt8 → Option Dig)
    (incG outcG : Hdr → StageGeom) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (hrun : A.run G = (s, segs))
    (hXev : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G) :
    ∀ k, k + 1 < Lb →
      EbXW U tag Lq h64 key domain hs hL rdx (k + 1 + 1) (rtW R.pf.sqs) ((rxPs base Lb din dblk dout) (k + 1 + 1)).gX
        ((rxPs base Lb din dblk dout) (k + 1 + 1)).nX
        (fun hdr => rkPend (rxAcc Win Wout Pk R.pf Lb) (k + 1 + 1) hdr
          ++ ((rxAcc Win Wout Pk R.pf Lb) (k + 1 + 1) hdr).claims.inp)
        (R.pf.off (k + 1 + 1) + (R.pf.part (k + 1 + 1)).oX) (R.pf.off (k + 1 + 1) + (R.pf.part (k + 1 + 1)).oBX)
        (R.pf.off (k + 1 + 1) + (R.pf.part (k + 1 + 1)).oX + (((rxPs base Lb din dblk dout) (k + 1 + 1)).nX
          + ((rxPs base Lb din dblk dout) (k + 1 + 1)).gX.rows)) (A.runLog G).2 G (R.tr G (s, segs)) := by
  intro k hk
  have hk0 : k < Lb := by omega
  obtain ⟨w⟩ := cb_blk_opX U tag h64 hs hL Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv G s segs hE k
    (by omega) (bp k) (bp (k + 1)) (pp k) (pp (k + 1)) (hσb k hk0) (hσb (k + 1) hk) (fun s => hgeo s k)
    (fun s => hgeo s (k + 1)) (hS (k + 1)) (hwA (k + 1)) (hmA (k + 1)) (hwH (k + 1)) (hmH (k + 1)) (pXk (k + 1))
    (hXk (k + 1)) (hwXk k hk) (hmXk k hk) incG outcG Lb A hrun hXev (hfitXk (k + 1))
  have hg : ((rxPs base Lb din dblk dout) (k + 1 + 1)).gX = rkR13 (pXk (k + 1)).rows (R.pf.off (k + 1) + 2) := by
    rw [rxPs_blk base Lb din dblk dout (k + 1) hk]
    exact hgXk k hk
  have hn : ((rxPs base Lb din dblk dout) (k + 1 + 1)).nX = (bp k).nOut + (bp (k + 1)).nIn := by
    rw [rxPs_blk base Lb din dblk dout (k + 1) hk]
    exact hnXk k hk
  show Nonempty (RhOpW U tag Lq h64 key domain hs hL _ _ _ _ _ _ _ _ _ _)
  rw [hg, hn]
  refine ⟨{ w with hrd := ?_ }⟩
  show (rxAcc Win Wout Pk R.pf Lb (k + 1) _).claims.out ++ (rxAcc Win Wout Pk R.pf Lb (k + 1 + 1) _).claims.inp
    = w.cl
  rw [rxAcc_blk _ _ _ _ _ k hk0, rxAcc_blk _ _ _ _ _ (k + 1) hk]
  exact w.hrd

end Mid

end ZK60.ProtocolClassify
