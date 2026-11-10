/-
D63 lane L45 (2026-11-10), part 5: **the stages' `A`, `H`, `M` facts with the extraction discharged** (deliverables 1
and 2 joined at the stages).

At an accepted run outside the run's Merkle event `EvXR`, taken with the run's OWN Merkle work (`RunExtractWork.lean`:
`C := chainEncB …`, `coreOf := rxCoreOf`, `Vx := rxVx`, `rx := rxRoots`), the acceptance facts `RhOpW` of stage IN-C's
and stage OUT-C's `A` and `H`, and `RhMW` of their `M`, hold OUTRIGHT: `RunStageRdHal.lean` gives them up to the
extraction at the opening of the segment read off the bytes, and `rx_xok` / `rx_xmok` give that extraction (the
opening's root is among `rxRoots`, its columns are checked by `rxVx`, the run's transcript absorbs the root at the
geometry's position).

* **`rx_inc_opA`**, **`rx_inc_opH`**, **`rx_inc_M`** (stage IN-C, part `0`);
* **`rx_outc_opA`**, **`rx_outc_opH`**, **`rx_outc_M`** (stage OUT-C, part `Lb + 1`).

What each asks besides the acceptance: the stage's contract (`RtInc`, `RtOutc`), the reader's verifier read off the
transcript (`hW`, finding L45-1), the openings' R13 numbers (`RkPcsR13`, as L43), the rows' fit (`8·rows ≤ Lq`), and
for `H` the LogUp sum claim and for `M` the functional count the readers carry.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunExtractWork

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Exec.StageV ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)

section Stages

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag)
  {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

/-- Stage IN-C's roots are the run's. -/
theorem rx_inRoot_mem (incG outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ)
    (coreOf : ClsStmt Hdr × ClsReceipt → ℕ → List Op × Block.Core) (o : ClsStmt Hdr × ClsReceipt) (seg : StageSeg)
    (hseg : rxInSeg incG o = some seg) :
    seg.core.aRoot ∈ runRoots 26 coreOf (rxRoots incG outcG sgeom Lb) o
      ∧ seg.core.hRoot ∈ runRoots 26 coreOf (rxRoots incG outcG sgeom Lb) o
      ∧ seg.core.maskRoot ∈ runRoots 26 coreOf (rxRoots incG outcG sgeom Lb) o := by
  unfold runRoots
  refine ⟨List.mem_append_right _ ?_, List.mem_append_right _ ?_, List.mem_append_right _ ?_⟩ <;>
    simp [rxRoots, hseg, rxStRoots]

/-- Stage OUT-C's roots are the run's. -/
theorem rx_outRoot_mem (incG outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ)
    (coreOf : ClsStmt Hdr × ClsReceipt → ℕ → List Op × Block.Core) (o : ClsStmt Hdr × ClsReceipt) (seg : StageSeg)
    (hseg : rxOutSeg outcG Lb o = some seg) :
    seg.core.aRoot ∈ runRoots 26 coreOf (rxRoots incG outcG sgeom Lb) o
      ∧ seg.core.hRoot ∈ runRoots 26 coreOf (rxRoots incG outcG sgeom Lb) o
      ∧ seg.core.maskRoot ∈ runRoots 26 coreOf (rxRoots incG outcG sgeom Lb) o := by
  unfold runRoots
  refine ⟨List.mem_append_right _ ?_, List.mem_append_right _ ?_, List.mem_append_right _ ?_⟩ <;>
    simp [rxRoots, hseg, rxStRoots]

/-- Stage IN-C's openings are among those `rxVx` checks. -/
theorem rx_inCols_mem (incG outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ)
    (o : ClsStmt Hdr × ClsReceipt) (seg : StageSeg) (hseg : rxInSeg incG o = some seg) :
    seg.core.aOpen.columns ∈ rxOpenings incG outcG sgeom Lb o
      ∧ seg.core.hOpen.columns ∈ rxOpenings incG outcG sgeom Lb o
      ∧ seg.core.maskOpen.columns ∈ rxOpenings incG outcG sgeom Lb o
      ∧ (seg.closes.headD IncV.ozk0).columns ∈ rxOpenings incG outcG sgeom Lb o := by
  refine ⟨?_, ?_, ?_, ?_⟩ <;> simp [rxOpenings, hseg, rxStCols]

/-- Stage OUT-C's openings are among those `rxVx` checks. -/
theorem rx_outCols_mem (incG outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ)
    (o : ClsStmt Hdr × ClsReceipt) (seg : StageSeg) (hseg : rxOutSeg outcG Lb o = some seg) :
    seg.core.aOpen.columns ∈ rxOpenings incG outcG sgeom Lb o
      ∧ seg.core.hOpen.columns ∈ rxOpenings incG outcG sgeom Lb o
      ∧ seg.core.maskOpen.columns ∈ rxOpenings incG outcG sgeom Lb o
      ∧ (seg.closes.headD IncV.ozk0).columns ∈ rxOpenings incG outcG sgeom Lb o := by
  refine ⟨?_, ?_, ?_, ?_⟩ <;> simp [rxOpenings, hseg, rxStCols]

/-- **STAGE IN-C'S `A` MEETS `RhOpW` OUTRIGHT** on an accepted run outside the run's Merkle event (with the run's own
Merkle work). -/
theorem rx_inc_opA (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (p : RtPart)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (cx0 : IncCtx) (I : RtInc Lq inc incG p)
    (hσ : R.σs[0]? = some (rtIncSeg inc incG cx0 p))
    (W : List (TItem × Dig) → IncV) (hW : W ((R.tr G (s, segs)).take (R.pf.off 0 + p.pre)) = inc s.hdr)
    (hA : RkPcsR13 U tag I.pA) (outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (hrun : A.run G = (s, segs))
    (hX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hfit : 8 * I.pA.rows ≤ Lq) :
    Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (rkR13 I.pA.rows (R.pf.off 0 + 5)) I.nA
      (fun hdr => (rkAccInc W (R.pf.off 0 + 5) (R.pf.off 0 + p.pre) hdr).claims.a)
      (R.pf.off 0 + (R.pf.part 0).oA) (R.pf.off 0 + (R.pf.part 0).oBA)
      (R.pf.off 0 + (R.pf.part 0).oA + (I.nA + I.pA.rows)) (A.runLog G).2 G (R.tr G (s, segs))) := by
  obtain ⟨seg, hof, habs, himp⟩ :=
    rs_inc_opA U tag h64 hs hL R hv G s segs hE 0 p inc incG cx0 I hσ W hW hA (A.runLog G).2
  have hseg : rxInSeg incG (A.run G) = some seg := by rw [hrun]; exact hof
  apply himp
  exact rx_xok tag Lq h64 key domain hs hL _ _ _ A G hX (rkR13 I.pA.rows (R.pf.off 0 + 5)) _ seg.core.aOpen
    seg.core.aRoot (rx_inRoot_mem incG outcG sgeom Lb _ _ seg hseg).1 habs hfit
    (rx_q_work tag Lq h64 incG outcG sgeom Lb (rxCoreOf sgeom) A G seg.core.aOpen.columns
      (rx_inCols_mem incG outcG sgeom Lb _ seg hseg).1 16 (by norm_num))

/-- **STAGE IN-C'S `H` MEETS `RhOpW` OUTRIGHT.** -/
theorem rx_inc_opH (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (p : RtPart)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (cx0 : IncCtx) (I : RtInc Lq inc incG p)
    (hσ : R.σs[0]? = some (rtIncSeg inc incG cx0 p))
    (W : List (TItem × Dig) → IncV) (hW : W ((R.tr G (s, segs)).take (R.pf.off 0 + p.pre)) = inc s.hdr)
    (hH : RkPcsR13 U tag I.pH) (lsc : Block.ZClaim) (hlsc : (inc s.hdr).lay.logupSumClaim = lsc)
    (hPos : ℕ) (hP : hPos = R.pf.off 0 + (5 + (4 + incHeadDraws (inc s.hdr).pub)))
    (outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (hrun : A.run G = (s, segs))
    (hX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hfit : 8 * I.pH.rows ≤ Lq) :
    Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (rkR13 I.pH.rows hPos) I.nH
      (fun hdr => (rkAccInc W (R.pf.off 0 + 5) (R.pf.off 0 + p.pre) hdr).claims.h ++ [lsc])
      (R.pf.off 0 + (R.pf.part 0).oH) (R.pf.off 0 + (R.pf.part 0).oBH)
      (R.pf.off 0 + (R.pf.part 0).oH + (I.nH + I.pH.rows)) (A.runLog G).2 G (R.tr G (s, segs))) := by
  obtain ⟨seg, hof, habs, himp⟩ :=
    rs_inc_opH U tag h64 hs hL R hv G s segs hE 0 p inc incG cx0 I hσ W hW hH lsc hlsc hPos hP (A.runLog G).2
  have hseg : rxInSeg incG (A.run G) = some seg := by rw [hrun]; exact hof
  apply himp
  exact rx_xok tag Lq h64 key domain hs hL _ _ _ A G hX (rkR13 I.pH.rows hPos) _ seg.core.hOpen
    seg.core.hRoot (rx_inRoot_mem incG outcG sgeom Lb _ _ seg hseg).2.1 habs hfit
    (rx_q_work tag Lq h64 incG outcG sgeom Lb (rxCoreOf sgeom) A G seg.core.hOpen.columns
      (rx_inCols_mem incG outcG sgeom Lb _ seg hseg).2.1 16 (by norm_num))

/-- **STAGE IN-C'S `M` MEETS `RhMW` OUTRIGHT.** -/
theorem rx_inc_M (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (p : RtPart)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (cx0 : IncCtx) (I : RtInc Lq inc incG p)
    (hσ : R.σs[0]? = some (rtIncSeg inc incG cx0 p))
    (W : List (TItem × Dig) → IncV) (hW : W ((R.tr G (s, segs)).take (R.pf.off 0 + p.pre)) = inc s.hdr)
    (htag : I.tag = tag) (kM : ℕ) (hkM : (inc s.hdr).lay.nFunctionals = kM)
    (outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (hrun : A.run G = (s, segs))
    (hX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hfit : 8 * (2 * p.S + 4) ≤ Lq) :
    Nonempty (RhMW tag Lq h64 key domain hs hL (rtW R.pf.sqs) p.S kM (R.pf.off 0 + (5 + 3))
      (fun hdr => (rkAccInc W (R.pf.off 0 + 5) (R.pf.off 0 + p.pre) hdr).fs
        ++ (rkAccInc W (R.pf.off 0 + 5) (R.pf.off 0 + p.pre) hdr).hostFs)
      (R.pf.off 0 + (R.pf.part 0).pre) (A.runLog G).2 G (R.tr G (s, segs))) := by
  obtain ⟨seg, tM, tA, fs, hof, habs, hok, himp⟩ :=
    rs_inc_M tag h64 hs hL R hv G s segs hE 0 p inc incG cx0 I hσ W hW htag kM hkM (A.runLog G).2
  have hseg : rxInSeg incG (A.run G) = some seg := by rw [hrun]; exact hof
  apply himp
  exact rx_xmok tag Lq h64 key domain hs hL _ _ _ A G hX p.S _ _ tM tA seg.core.maskOpen seg.core.maskRoot
    (fs.map toMF) hok (rx_inRoot_mem incG outcG sgeom Lb _ _ seg hseg).2.2 habs hfit
    (rx_q_work tag Lq h64 incG outcG sgeom Lb (rxCoreOf sgeom) A G seg.core.maskOpen.columns
      (rx_inCols_mem incG outcG sgeom Lb _ seg hseg).2.2.1 12 (by norm_num))

/-- **STAGE OUT-C'S `A` MEETS `RhOpW` OUTRIGHT** (part `Lb + 1`). -/
theorem rx_outc_opA (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (Lb : ℕ) (p : RtPart)
    (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom) (O : RtOutc Lq outc outcG p)
    (hσ : R.σs[Lb + 1]? = some (rtOutcSeg outc outcG p))
    (W : List (TItem × Dig) → OutcV)
    (hW : W ((R.tr G (s, segs)).take (R.pf.off (Lb + 1) + p.pre)) = outc s.hdr s.verdict)
    (hA : RkPcsR13 U tag O.pA) (incG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (hrun : A.run G = (s, segs))
    (hX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hfit : 8 * O.pA.rows ≤ Lq) :
    Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (rkR13 O.pA.rows (R.pf.off (Lb + 1) + 2)) O.nA
      (fun hdr => (rkAccOutc W (R.pf.off (Lb + 1) + 2) (R.pf.off (Lb + 1) + p.pre) hdr).claims.a)
      (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oA) (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oBA)
      (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oA + (O.nA + O.pA.rows)) (A.runLog G).2 G (R.tr G (s, segs))) := by
  obtain ⟨seg, hof, habs, himp⟩ :=
    rs_outc_opA U tag h64 hs hL R hv G s segs hE (Lb + 1) p outc outcG O hσ W hW hA (A.runLog G).2
  have hseg : rxOutSeg outcG Lb (A.run G) = some seg := by rw [hrun]; exact hof
  apply himp
  exact rx_xok tag Lq h64 key domain hs hL _ _ _ A G hX (rkR13 O.pA.rows (R.pf.off (Lb + 1) + 2)) _ seg.core.aOpen
    seg.core.aRoot (rx_outRoot_mem incG outcG sgeom Lb _ _ seg hseg).1 habs hfit
    (rx_q_work tag Lq h64 incG outcG sgeom Lb (rxCoreOf sgeom) A G seg.core.aOpen.columns
      (rx_outCols_mem incG outcG sgeom Lb _ seg hseg).1 16 (by norm_num))

/-- **STAGE OUT-C'S `H` MEETS `RhOpW` OUTRIGHT.** -/
theorem rx_outc_opH (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (Lb : ℕ) (p : RtPart)
    (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom) (O : RtOutc Lq outc outcG p)
    (hσ : R.σs[Lb + 1]? = some (rtOutcSeg outc outcG p))
    (W : List (TItem × Dig) → OutcV)
    (hW : W ((R.tr G (s, segs)).take (R.pf.off (Lb + 1) + p.pre)) = outc s.hdr s.verdict)
    (hH : RkPcsR13 U tag O.pH) (lsc : Block.ZClaim) (hlsc : (outc s.hdr s.verdict).lay.logupSumClaim = lsc)
    (incG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (hrun : A.run G = (s, segs))
    (hX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hfit : 8 * O.pH.rows ≤ Lq) :
    Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs)
      (rkR13 O.pH.rows (R.pf.off (Lb + 1) + (2 + (4 + 2)))) O.nH
      (fun hdr => (rkAccOutc W (R.pf.off (Lb + 1) + 2) (R.pf.off (Lb + 1) + p.pre) hdr).claims.h ++ [lsc])
      (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oH) (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oBH)
      (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oH + (O.nH + O.pH.rows)) (A.runLog G).2 G (R.tr G (s, segs))) := by
  obtain ⟨seg, hof, habs, himp⟩ :=
    rs_outc_opH U tag h64 hs hL R hv G s segs hE (Lb + 1) p outc outcG O hσ W hW hH lsc hlsc (A.runLog G).2
  have hseg : rxOutSeg outcG Lb (A.run G) = some seg := by rw [hrun]; exact hof
  apply himp
  exact rx_xok tag Lq h64 key domain hs hL _ _ _ A G hX (rkR13 O.pH.rows (R.pf.off (Lb + 1) + (2 + (4 + 2)))) _
    seg.core.hOpen seg.core.hRoot (rx_outRoot_mem incG outcG sgeom Lb _ _ seg hseg).2.1 habs hfit
    (rx_q_work tag Lq h64 incG outcG sgeom Lb (rxCoreOf sgeom) A G seg.core.hOpen.columns
      (rx_outCols_mem incG outcG sgeom Lb _ seg hseg).2.1 16 (by norm_num))

/-- **STAGE OUT-C'S `M` MEETS `RhMW` OUTRIGHT.** -/
theorem rx_outc_M (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (Lb : ℕ) (p : RtPart)
    (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom) (O : RtOutc Lq outc outcG p)
    (hσ : R.σs[Lb + 1]? = some (rtOutcSeg outc outcG p))
    (W : List (TItem × Dig) → OutcV)
    (hW : W ((R.tr G (s, segs)).take (R.pf.off (Lb + 1) + p.pre)) = outc s.hdr s.verdict)
    (htag : O.tag = tag) (kM : ℕ) (hkM : (outc s.hdr s.verdict).lay.nFunctionals = kM)
    (incG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (hrun : A.run G = (s, segs))
    (hX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hfit : 8 * (2 * p.S + 4) ≤ Lq) :
    Nonempty (RhMW tag Lq h64 key domain hs hL (rtW R.pf.sqs) p.S kM (R.pf.off (Lb + 1) + (2 + 3))
      (fun hdr => (rkAccOutc W (R.pf.off (Lb + 1) + 2) (R.pf.off (Lb + 1) + p.pre) hdr).fs
        ++ (rkAccOutc W (R.pf.off (Lb + 1) + 2) (R.pf.off (Lb + 1) + p.pre) hdr).hostFs)
      (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).pre) (A.runLog G).2 G (R.tr G (s, segs))) := by
  obtain ⟨seg, tM, tA, fs, hof, habs, hok, himp⟩ :=
    rs_outc_M tag h64 hs hL R hv G s segs hE (Lb + 1) p outc outcG O hσ W hW htag kM hkM (A.runLog G).2
  have hseg : rxOutSeg outcG Lb (A.run G) = some seg := by rw [hrun]; exact hof
  apply himp
  exact rx_xmok tag Lq h64 key domain hs hL _ _ _ A G hX p.S _ _ tM tA seg.core.maskOpen seg.core.maskRoot
    (fs.map toMF) hok (rx_outRoot_mem incG outcG sgeom Lb _ _ seg hseg).2.2 habs hfit
    (rx_q_work tag Lq h64 incG outcG sgeom Lb (rxCoreOf sgeom) A G seg.core.maskOpen.columns
      (rx_outCols_mem incG outcG sgeom Lb _ seg hseg).2.2.1 12 (by norm_num))

end Stages

end ZK60.ProtocolClassify
