/-
D63 lane L45 (2026-11-10), part 7: **the kinds data's readers at every part of the classify run, and the `A`, `H`
halves of `hopW` and all of `hMW` PROVED at every part** (deliverables 1 and 2 assembled).

`rkData` (L43) takes the parts' data `ps`, one accumulator reader per part `acc`, and the LogUp sum claims `lsc`. Here
they are BUILT for the classify run with D12a blocks (L34's `rtRunClassify` schedule: stage IN-C at part `0`, block
`k` at part `k + 1`, stage OUT-C at part `Lb + 1`):

* `RxMAH`, `rxSet`, `rxPs`, `rxDin`, `rxDblk`, `rxDout`: every part's `M`, `A`, `H` data the verifier's (mask-spec
  count, functional count, `M`'s root position, the R13 geometries at the roots' positions, the claim counts); the
  slots, squeeze runs and the closing opening `X` from `base` (the slot and draw lanes', deliverable 3's);
* `rxAcc`: stage IN-C's reader `rkAccInc`, block `k`'s L43 `rkAccBlk`, stage OUT-C's `rkAccOutc`; `rxLsc`;
* `rx_get0`, `rx_getBlk`, `rx_getOut`: the schedule's parts;
* **`rx_parts_AH`**: on an accepted run outside `EvXR` (with the run's OWN Merkle work), EVERY part's `A` and `H`
  meet `RhOpW` (the first two thirds of L43's `hopW`);
* **`rx_parts_M`**: EVERY part's `M` meets `RhMW` (L43's `hMW`, all of it).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunExtractBlk

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx)
open ZK60.Circuit (gP GF)

/-! ## The parts' data and readers -/

/-- **One part's `M`, `A`, `H` data**: `M`'s mask-spec count, functional count and root position; `A`'s and `H`'s
geometries (with their roots' positions) and claim counts. -/
structure RxMAH where
  S : ℕ
  k : ℕ
  mpos : ℕ
  gA : RkGeo
  gH : RkGeo
  nA : ℕ
  nH : ℕ

/-- A part's data with its `M`, `A`, `H` fields set. -/
def rxSet {K : Type} {Lq : ℕ} (b : RkPart K Lq) (d : RxMAH) : RkPart K Lq :=
  { b with S := d.S, k := d.k, mpos := d.mpos, gA := d.gA, gH := d.gH, nA := d.nA, nH := d.nH }

/-- **The classify run's parts' data**: stage IN-C's at part `0`, block `k`'s at `k + 1` (`k < Lb`), stage OUT-C's at
`Lb + 1`. -/
def rxPs {K : Type} {Lq : ℕ} (base : ℕ → RkPart K Lq) (Lb : ℕ) (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH) :
    ℕ → RkPart K Lq
  | 0 => rxSet (base 0) din
  | i + 1 => if i < Lb then rxSet (base (i + 1)) (dblk i) else rxSet (base (i + 1)) dout

/-- Stage IN-C's data: roots at `5` (`A`), `8` (`M`), `9 + m` (`H`) after the part's start. -/
def rxDin (pf : RtProf) (S kM rA rH nA nH m : ℕ) : RxMAH :=
  ⟨S, kM, pf.off 0 + (5 + 3), rkR13 rA (pf.off 0 + 5), rkR13 rH (pf.off 0 + (5 + (4 + m))), nA, nH⟩

/-- Block `k`'s data: roots at `5`, `8`, `12` after part `k + 1`'s start. -/
def rxDblk (pf : RtProf) (k S kM rA rH nA nH : ℕ) : RxMAH :=
  ⟨S, kM, pf.off (k + 1) + (5 + 3), rkR13 rA (pf.off (k + 1) + 5), rkR13 rH (pf.off (k + 1) + (5 + 7)), nA, nH⟩

/-- Stage OUT-C's data: roots at `2`, `5`, `8` after part `Lb + 1`'s start. -/
def rxDout (pf : RtProf) (Lb S kM rA rH nA nH : ℕ) : RxMAH :=
  ⟨S, kM, pf.off (Lb + 1) + (2 + 3), rkR13 rA (pf.off (Lb + 1) + 2), rkR13 rH (pf.off (Lb + 1) + (2 + (4 + 2))), nA,
    nH⟩

/-- **The classify run's accumulator readers**: stage IN-C's, each block's (L31's `tAccRd`, L43's `rkAccBlk`), stage
OUT-C's, each at its part's absolute position on the run's transcript. -/
noncomputable def rxAcc (Win : List (TItem × Dig) → IncV) (Wout : List (TItem × Dig) → OutcV) (Pk : ℕ → Block.BlockParams)
    (pf : RtProf) (Lb : ℕ) : ℕ → List (TItem × Dig) → Block.Acc
  | 0 => rkAccInc Win (pf.off 0 + 5) (pf.off 0 + (pf.part 0).pre)
  | i + 1 => if i < Lb then rkAccBlk (Pk i) (pf.off (i + 1) + 5) (pf.off (i + 1) + (pf.part (i + 1)).pre)
      else rkAccOutc Wout (pf.off (i + 1) + 2) (pf.off (i + 1) + (pf.part (i + 1)).pre)

/-- **The classify run's LogUp sum claims.** -/
def rxLsc (lscIn lscOut : Block.ZClaim) (Pk : ℕ → Block.BlockParams) (Lb : ℕ) : ℕ → Block.ZClaim
  | 0 => lscIn
  | i + 1 => if i < Lb then (Pk i).logupSumClaim else lscOut

section Unfold

variable {K : Type} {Lq : ℕ} (base : ℕ → RkPart K Lq) (Lb : ℕ) (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH)
  (Win : List (TItem × Dig) → IncV) (Wout : List (TItem × Dig) → OutcV) (Pk : ℕ → Block.BlockParams) (pf : RtProf)
  (lscIn lscOut : Block.ZClaim)

theorem rxPs_blk (k : ℕ) (hk : k < Lb) : rxPs base Lb din dblk dout (k + 1) = rxSet (base (k + 1)) (dblk k) := by
  show (if k < Lb then rxSet (base (k + 1)) (dblk k) else rxSet (base (k + 1)) dout) = _
  rw [ite_eq_left hk]

theorem rxPs_out : rxPs base Lb din dblk dout (Lb + 1) = rxSet (base (Lb + 1)) dout := by
  show (if Lb < Lb then rxSet (base (Lb + 1)) (dblk Lb) else rxSet (base (Lb + 1)) dout) = _
  rw [ite_eq_right (lt_irrefl Lb)]

theorem rxAcc_blk (k : ℕ) (hk : k < Lb) :
    rxAcc Win Wout Pk pf Lb (k + 1) = rkAccBlk (Pk k) (pf.off (k + 1) + 5) (pf.off (k + 1) + (pf.part (k + 1)).pre) := by
  show (if k < Lb then rkAccBlk (Pk k) (pf.off (k + 1) + 5) (pf.off (k + 1) + (pf.part (k + 1)).pre)
    else rkAccOutc Wout (pf.off (k + 1) + 2) (pf.off (k + 1) + (pf.part (k + 1)).pre)) = _
  rw [ite_eq_left hk]

theorem rxAcc_out :
    rxAcc Win Wout Pk pf Lb (Lb + 1) = rkAccOutc Wout (pf.off (Lb + 1) + 2) (pf.off (Lb + 1) + (pf.part (Lb + 1)).pre) := by
  show (if Lb < Lb then rkAccBlk (Pk Lb) (pf.off (Lb + 1) + 5) (pf.off (Lb + 1) + (pf.part (Lb + 1)).pre)
    else rkAccOutc Wout (pf.off (Lb + 1) + 2) (pf.off (Lb + 1) + (pf.part (Lb + 1)).pre)) = _
  rw [ite_eq_right (lt_irrefl Lb)]

theorem rxLsc_blk (k : ℕ) (hk : k < Lb) : rxLsc lscIn lscOut Pk Lb (k + 1) = (Pk k).logupSumClaim := by
  show (if k < Lb then (Pk k).logupSumClaim else lscOut) = _
  rw [ite_eq_left hk]

theorem rxLsc_out : rxLsc lscIn lscOut Pk Lb (Lb + 1) = lscOut := by
  show (if Lb < Lb then (Pk Lb).logupSumClaim else lscOut) = _
  rw [ite_eq_right (lt_irrefl Lb)]

end Unfold

/-! ## The schedule's parts -/

section Get

variable {Hdr : Type} (V : RunV Hdr) (a : RtSeg (ClsStmt Hdr)) (f : ℕ → RtSeg (ClsStmt Hdr)) (c : RtSeg (ClsStmt Hdr))

theorem rx_get0 : (rtParts V a f c)[0]? = some a := rfl

theorem rx_getBlk (k : ℕ) (hk : k < V.L) : (rtParts V a f c)[k + 1]? = some (f k) := by
  show ((List.range V.L).map f ++ [c])[k]? = some (f k)
  rw [List.getElem?_append_left (by simp [hk]), List.getElem?_map, List.getElem?_range hk]
  rfl

theorem rx_getOut : (rtParts V a f c)[V.L + 1]? = some c := by
  show ((List.range V.L).map f ++ [c])[V.L]? = some c
  rw [List.getElem?_append_right (by simp), List.length_map, List.length_range, Nat.sub_self]
  rfl

end Get

theorem rx_part_of {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
    (R : RtRun V key domain Lq) (i : ℕ) (σ : RtSeg (ClsStmt Hdr)) (h : R.σs[i]? = some σ) : R.pf.part i = σ.p := by
  apply rh_part_eq
  show (R.σs.map (fun σ => σ.p))[i]? = some σ.p
  rw [List.getElem?_map, h]
  rfl

/-! ## `hopW`'s `A`, `H` halves and `hMW`, at every part -/

section Parts

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag)
  {Hdr : Type} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
  (Lb : ℕ) (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr)
  (inc : Hdr → IncV) (incG : Hdr → StageGeom) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
  (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **EVERY PART'S `A` AND `H` MEET `RhOpW`** on an accepted run outside the run's Merkle event, with the run's own
Merkle work, at the kinds data's readers built here: the first two thirds of L43's `hopW`, PROVED. -/
theorem rx_parts_AH
    (R : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : R.pf.Valid) (cx0 : IncCtx) (pin pout : RtPart) (I : RtInc Lq inc incG pin) (O : RtOutc Lq outc outcG pout)
    (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : R.σs = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hLb : Lb ≤ 26) (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom)
    (hIA : RkPcsR13 U tag I.pA) (hIH : RkPcsR13 U tag I.pH) (hOA : RkPcsR13 U tag O.pA) (hOH : RkPcsR13 U tag O.pH)
    (hBA : ∀ k, RkPcsR13 U tag (bp k).pA) (hBH : ∀ k, RkPcsR13 U tag (bp k).pH)
    (hfIA : 8 * I.pA.rows ≤ Lq) (hfIH : 8 * I.pH.rows ≤ Lq) (hfOA : 8 * O.pA.rows ≤ Lq) (hfOH : 8 * O.pH.rows ≤ Lq)
    (hfBA : ∀ k, 8 * (bp k).pA.rows ≤ Lq) (hfBH : ∀ k, 8 * (bp k).pH.rows ≤ Lq)
    (Win : List (TItem × Dig) → IncV) (Wout : List (TItem × Dig) → OutcV) (lscIn lscOut : Block.ZClaim)
    (mIn kIn kOut : ℕ) (hlscIn : ∀ hd, (inc hd).lay.logupSumClaim = lscIn)
    (hlscOut : ∀ hd v, (outc hd v).lay.logupSumClaim = lscOut) (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn)
    (base : ℕ → RkPart K Lq) (ps : ℕ → RkPart K Lq)
    (hps : ps = rxPs base Lb (rxDin R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
      (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
      (rxDout R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH))
    (acc : ℕ → List (TItem × Dig) → Block.Acc) (hacc : acc = rxAcc Win Wout Pk R.pf Lb)
    (lsc : ℕ → Block.ZClaim) (hlsc : lsc = rxLsc lscIn lscOut Pk Lb)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G)
      (A.run G).1 (A.run G).2 = .ok ())
    (hWin : Win ((R.tr G (A.run G)).take (R.pf.off 0 + pin.pre)) = inc (A.run G).1.hdr)
    (hWout : Wout ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + pout.pre)) = outc (A.run G).1.hdr (A.run G).1.verdict)
    (hX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (i : ℕ) (hi : i < R.pf.parts.length) :
    Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (ps i).gA (ps i).nA
        (fun hdr => (acc i hdr).claims.a) (R.pf.off i + (R.pf.part i).oA) (R.pf.off i + (R.pf.part i).oBA)
        (R.pf.off i + (R.pf.part i).oA + ((ps i).nA + (ps i).gA.rows)) (A.runLog G).2 G (R.tr G (A.run G)))
      ∧ Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (ps i).gH (ps i).nH
        (fun hdr => (acc i hdr).claims.h ++ [lsc i]) (R.pf.off i + (R.pf.part i).oH)
        (R.pf.off i + (R.pf.part i).oBH)
        (R.pf.off i + (R.pf.part i).oH + ((ps i).nH + (ps i).gH.rows)) (A.runLog G).2 G (R.tr G (A.run G))) := by
  subst hps hacc hlsc
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  rcases hrun : A.run G with ⟨s, segs⟩
  rw [hrun] at hE hWin hWout
  rcases i with _ | k
  · -- stage IN-C
    have hσ0 : R.σs[0]? = some (rtIncSeg inc incG cx0 pin) := by rw [hσ]; rfl
    have hpart : R.pf.part 0 = pin := rx_part_of R 0 _ hσ0
    have hA := rx_inc_opA U tag h64 hs hL R hv G s segs hE pin inc incG cx0 I hσ0 Win hWin hIA outcG sgeom Lb A hrun
      hX hfIA
    have hH := rx_inc_opH U tag h64 hs hL R hv G s segs hE pin inc incG cx0 I hσ0 Win hWin hIH lscIn (hlscIn s.hdr)
      (R.pf.off 0 + (5 + (4 + mIn))) (by rw [hmIn]) outcG sgeom Lb A hrun hX hfIH
    rw [hpart] at hA hH
    show Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (rkR13 I.pA.rows (R.pf.off 0 + 5)) I.nA
        (fun hdr => (rkAccInc Win (R.pf.off 0 + 5) (R.pf.off 0 + (R.pf.part 0).pre) hdr).claims.a)
        (R.pf.off 0 + (R.pf.part 0).oA) (R.pf.off 0 + (R.pf.part 0).oBA)
        (R.pf.off 0 + (R.pf.part 0).oA + (I.nA + I.pA.rows)) (A.runLog G).2 G (R.tr G (s, segs)))
      ∧ Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (rkR13 I.pH.rows (R.pf.off 0 + (5 + (4 + mIn))))
        I.nH (fun hdr => (rkAccInc Win (R.pf.off 0 + 5) (R.pf.off 0 + (R.pf.part 0).pre) hdr).claims.h ++ [lscIn])
        (R.pf.off 0 + (R.pf.part 0).oH) (R.pf.off 0 + (R.pf.part 0).oBH)
        (R.pf.off 0 + (R.pf.part 0).oH + (I.nH + I.pH.rows)) (A.runLog G).2 G (R.tr G (s, segs)))
    rw [hpart]
    exact ⟨hA, hH⟩
  · rw [hL2] at hi
    by_cases hk : k < Lb
    · -- block k
      have hk26 : k < 26 := by omega
      have hσb : R.σs[k + 1]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
          (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows)
            (bp k).pH.m (wXk k) (gXk k) (mXk k))) := by
        rw [hσ]
        exact rx_getBlk _ _ _ _ k hk
      have hpart := rx_part_of R (k + 1) _ hσb
      have hA := rx_blk_opA U tag h64 hs hL Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv G s segs hE
        k hk26 (bp k) (wXk k) (gXk k) (mXk k) hσb (hgeo k) (hBA k) incG outcG Lb A hrun hX (hfBA k)
      have hH := rx_blk_opH U tag h64 hs hL Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv G s segs hE
        k hk26 (bp k) (wXk k) (gXk k) (mXk k) hσb (hgeo k) (hBH k) incG outcG Lb A hrun hX (hfBH k)
      rw [hpart] at hA hH
      rw [rxPs_blk _ _ _ _ _ k hk, rxAcc_blk _ _ _ _ _ k hk, rxLsc_blk _ _ _ _ k hk, hpart]
      exact ⟨hA, hH⟩
    · -- stage OUT-C
      have hkL : Lb = k := by omega
      subst hkL
      have hσo : R.σs[Lb + 1]? = some (rtOutcSeg outc outcG pout) := by
        rw [hσ]
        exact rx_getOut _ _ _ _
      have hpart : R.pf.part (Lb + 1) = pout := rx_part_of R (Lb + 1) _ hσo
      have hA := rx_outc_opA U tag h64 hs hL R hv G s segs hE Lb pout outc outcG O hσo Wout hWout hOA incG sgeom A hrun
        hX hfOA
      have hH := rx_outc_opH U tag h64 hs hL R hv G s segs hE Lb pout outc outcG O hσo Wout hWout hOH lscOut
        (hlscOut s.hdr s.verdict) incG sgeom A hrun hX hfOH
      rw [hpart] at hA hH
      rw [rxPs_out, rxAcc_out, rxLsc_out, hpart]
      exact ⟨hA, hH⟩

omit [Field K] [Algebra GF K] in
/-- **EVERY PART'S `M` MEETS `RhMW`** on an accepted run outside the run's Merkle event, with the run's own Merkle
work, at the kinds data's readers built here: L43's `hMW`, PROVED. -/
theorem rx_parts_M
    (R : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : R.pf.Valid) (cx0 : IncCtx) (pin pout : RtPart) (I : RtInc Lq inc incG pin) (O : RtOutc Lq outc outcG pout)
    (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : R.σs = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hLb : Lb ≤ 26) (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom)
    (htI : I.tag = tag) (htO : O.tag = tag) (htB : ∀ k, (bp k).tag = tag)
    (hfIM : 8 * (2 * pin.S + 4) ≤ Lq) (hfOM : 8 * (2 * pout.S + 4) ≤ Lq) (hfBM : ∀ k, 8 * (2 * (bp k).S + 4) ≤ Lq)
    (Win : List (TItem × Dig) → IncV) (Wout : List (TItem × Dig) → OutcV)
    (mIn kIn kOut : ℕ) (hkIn : ∀ hd, (inc hd).lay.nFunctionals = kIn)
    (hkOut : ∀ hd v, (outc hd v).lay.nFunctionals = kOut)
    (base : ℕ → RkPart K Lq) (ps : ℕ → RkPart K Lq) (rIA rIH rOA rOH : ℕ) (rBA rBH : ℕ → ℕ)
    (hps : ps = rxPs base Lb (rxDin R.pf pin.S kIn rIA rIH I.nA I.nH mIn)
      (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (rBA k) (rBH k) (bp k).nA (bp k).nH)
      (rxDout R.pf Lb pout.S kOut rOA rOH O.nA O.nH))
    (acc : ℕ → List (TItem × Dig) → Block.Acc) (hacc : acc = rxAcc Win Wout Pk R.pf Lb)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G)
      (A.run G).1 (A.run G).2 = .ok ())
    (hWin : Win ((R.tr G (A.run G)).take (R.pf.off 0 + pin.pre)) = inc (A.run G).1.hdr)
    (hWout : Wout ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + pout.pre)) = outc (A.run G).1.hdr (A.run G).1.verdict)
    (hX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (i : ℕ) (hi : i < R.pf.parts.length) :
    Nonempty (RhMW tag Lq h64 key domain hs hL (rtW R.pf.sqs) (ps i).S (ps i).k (ps i).mpos
      (fun hdr => (acc i hdr).fs ++ (acc i hdr).hostFs) (R.pf.off i + (R.pf.part i).pre) (A.runLog G).2 G
      (R.tr G (A.run G))) := by
  subst hps hacc
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  rcases hrun : A.run G with ⟨s, segs⟩
  rw [hrun] at hE hWin hWout
  rcases i with _ | k
  · have hσ0 : R.σs[0]? = some (rtIncSeg inc incG cx0 pin) := by rw [hσ]; rfl
    have hpart : R.pf.part 0 = pin := rx_part_of R 0 _ hσ0
    have hM := rx_inc_M tag h64 hs hL R hv G s segs hE pin inc incG cx0 I hσ0 Win hWin htI kIn (hkIn s.hdr) outcG sgeom
      Lb A hrun hX hfIM
    rw [hpart] at hM
    show Nonempty (RhMW tag Lq h64 key domain hs hL (rtW R.pf.sqs) pin.S kIn (R.pf.off 0 + (5 + 3))
      (fun hdr => (rkAccInc Win (R.pf.off 0 + 5) (R.pf.off 0 + (R.pf.part 0).pre) hdr).fs
        ++ (rkAccInc Win (R.pf.off 0 + 5) (R.pf.off 0 + (R.pf.part 0).pre) hdr).hostFs)
      (R.pf.off 0 + (R.pf.part 0).pre) (A.runLog G).2 G (R.tr G (s, segs)))
    rw [hpart]
    exact hM
  · rw [hL2] at hi
    by_cases hk : k < Lb
    · have hk26 : k < 26 := by omega
      have hσb : R.σs[k + 1]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
          (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows)
            (bp k).pH.m (wXk k) (gXk k) (mXk k))) := by
        rw [hσ]
        exact rx_getBlk _ _ _ _ k hk
      have hpart := rx_part_of R (k + 1) _ hσb
      have hM := rx_blk_M tag h64 hs hL Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv G s segs hE k hk26
        (bp k) (wXk k) (gXk k) (mXk k) hσb (hgeo k) (htB k) incG outcG Lb A hrun hX (hfBM k)
      rw [hpart] at hM
      rw [rxPs_blk _ _ _ _ _ k hk, rxAcc_blk _ _ _ _ _ k hk, hpart]
      exact hM
    · have hkL : Lb = k := by omega
      subst hkL
      have hσo : R.σs[Lb + 1]? = some (rtOutcSeg outc outcG pout) := by
        rw [hσ]
        exact rx_getOut _ _ _ _
      have hpart : R.pf.part (Lb + 1) = pout := rx_part_of R (Lb + 1) _ hσo
      have hM := rx_outc_M tag h64 hs hL R hv G s segs hE Lb pout outc outcG O hσo Wout hWout htO kOut
        (hkOut s.hdr s.verdict) incG sgeom A hrun hX hfOM
      rw [hpart] at hM
      rw [rxPs_out, rxAcc_out, hpart]
      exact hM

end Parts

end ZK60.ProtocolClassify
