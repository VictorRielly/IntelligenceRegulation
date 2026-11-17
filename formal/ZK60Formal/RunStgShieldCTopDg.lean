/-
D63 lane L65 (2026-11-17), part 3: **the four `r0` entry conjuncts for `stgDefsV` at `sshDgI` / `sshDgO` (conditional on
`StgCsIODeg`), and `sshC_productionReadyL_epP_dg` instantiating `dgI := sshDgI`, `dgO := sshDgO` (`hD` unchanged)**.

* **`stgDefsV_valid_inC`**, **`stgDefsV_valid_out`**: under `StgCsIODeg` (lane L63's open `csIOI`/`csIOO` link) and the
  64-bit log bounds, every entry `sx` of `stgDefsV` on stage IN-C (`sshΦIC` at `sshDgI`) and stage OUT-C (`sshΦO` at
  `sshDgO`) meets the four entry-level `r0` conjuncts `SqCut`, `.Rbr`, `sx.e ≤ 80`, and `sx.n * sx.e ≤ 80 * 451` (the
  window `pf.off i ≤ sx.a ≤ pf.off (i + 1)` and `Pairwise` ordering conjuncts of `RtSqOk` remain in `hD`);
* **`sshC_productionReadyL_epP_dg`**: `sshC_productionReadyL_epP_claimsW` instantiated at `dgI := sshDgI` and
  `dgO := sshDgO`; **`hD` is unchanged** (this specialises the degree binders and discharges no premise until the stage
  `r0` conjuncts of `hD` are assembled from `stgDefsV_valid_inC` / `stgDefsV_valid_out` and `StgCsIODeg`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldCTopW
import ZK60Formal.RunStgShieldDg

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX
open ZK60.Exec.StageV
open ZK60.Circuit (gP GF)

section DefsValid

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] {L : ℕ}
variable (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (tag : MTag) (h64 : 64 ≤ L)

/-- **Every entry of stage IN-C's `stgDefsV` (`sshΦIC` at `sshDgI`) meets all four `D.Valid` `r0` conditions**:
`SqCut`, `.Rbr`, `e ≤ 80`, and `n * e ≤ 80 * 451`. -/
theorem stgDefsV_valid_inC (hU : U ^ 2 = algebraMap GF K 7)
    (P0 : Block.BlockParams) (Vi : IncV) (n0 hdrLen m lc h Q e rA rH : ℕ)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (absOf : QB L → Option (List UInt8))
    (hPin : ∀ cx, StgSame P0 (Vi.bp cx))
    (hlc : Vi.pub.lt ≤ lc)
    (hIO0 : StgCsIODeg U hbij Vi.pub.epLogN (IncPrivIO0 Vi.pub) csIO)
    (hIO1 : StgCsIODeg U hbij Vi.geo.bLogN (IncPrivIO1 Vi.pub) csIO)
    (hc0 : clog2 Vi.pub.inEpWords ≤ 64) (hc1 : Vi.pub.tiLog ≤ 64) (hc2 : Vi.pub.vocLog ≤ 64) :
    ∀ sx ∈ stgDefsV P0 m hdrLen absOf (sshΦIC U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH csIO) sshDgI,
      SqCut absOf sx ∧ sx.Rbr ∧ sx.e ≤ 80 ∧ sx.n * sx.e ≤ 80 * 451 := by
  intro sx hsx
  obtain ⟨k, _, rfl⟩ := List.mem_map.mp hsx
  have hcnt := ssh_inc_dg_count Vi.pub hc0 hc1 hc2 k
  have hn : (stgDefSqV P0 m hdrLen absOf (sshΦIC U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH csIO) sshDgI k).n
      = incDraws Vi.pub k := by
    show P0.draws k = incDraws Vi.pub k
    rw [(hPin (incCtx Vi.pub [])).1]; rfl
  refine ⟨stgDefSqV_cut P0 m hdrLen absOf _ sshDgI k,
    ssh_inc_rbrC U hbij tag h64 hU P0 Vi n0 hdrLen m lc h Q e rA rH csIO absOf hPin hlc hIO0 hIO1 k,
    hcnt.1, ?_⟩
  rw [hn]; exact hcnt.2

/-- **Every entry of stage OUT-C's `stgDefsV` (`sshΦO` at `sshDgO`) meets all four `D.Valid` `r0` conditions**:
`SqCut`, `.Rbr`, `e ≤ 80`, and `n * e ≤ 80 * 451`. -/
theorem stgDefsV_valid_out (hU : U ^ 2 = algebraMap GF K 7)
    (P0 : Block.BlockParams) (F : ℕ → OutcV) (n0 hdrLen lc h Q e rA rH : ℕ)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (absOf : QB L → Option (List UInt8))
    (hPout : ∀ b, StgSame P0 (F b).bp)
    (hlc : ∀ b, (F b).pub.lt ≤ lc)
    (hIO : ∀ b, StgCsIODeg U hbij (F b).geo.bLogN (OutcPrivIO (F b).pub) csIO)
    (hc0 : (F 0).pub.dBits ≤ 64) (hc1 : (F 0).pub.llo ≤ 64)
    (hc2 : (F 0).pub.ldo ≤ 64) (hc3 : (F 0).pub.ltab ≤ 64) :
    ∀ sx ∈ stgDefsV P0 2 hdrLen absOf (sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO) sshDgO,
      SqCut absOf sx ∧ sx.Rbr ∧ sx.e ≤ 80 ∧ sx.n * sx.e ≤ 80 * 451 := by
  intro sx hsx
  obtain ⟨k, _, rfl⟩ := List.mem_map.mp hsx
  have hcnt := ssh_outc_dg_count (F 0).pub hc0 hc1 hc2 hc3 k
  have hn : (stgDefSqV P0 2 hdrLen absOf (sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO) sshDgO k).n
      = outcDraws (F 0).pub k := by
    show P0.draws k = outcDraws (F 0).pub k
    rw [(hPout 0).1]; rfl
  refine ⟨stgDefSqV_cut P0 2 hdrLen absOf _ sshDgO k,
    ssh_outc_rbr U hbij tag h64 hU P0 F n0 hdrLen lc h Q e rA rH csIO absOf hPout hlc hIO k,
    hcnt.1, ?_⟩
  rw [hn]; exact hcnt.2

end DefsValid

namespace RunShapeP

section SshTopDg

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Exec.Link Code ZK60.RunShape
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV classifyProtocolExec incHeadDraws IncCtx)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)
open ZK60.D76 (classifyLeak LeaksAtMost productionReadyL_of_productionReady productionReadyL_of_productionReady_range)
open ZK60.ProtocolClassify (ClsHdrW clsHdrOf clsStart)

variable {S : BlockShape} {Hdr Coins : Type}
variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (Rr dR : ℕ) {pos : S.Tok → Fin dR × Fin (2 ^ 8)} (hpos : Function.Injective pos)
  (place : Fin dR → Fin Rr) (hplace : Function.Injective place) (tag : MTag)
local notation "CinR" =>
  epTokenCommit (St := ClsStmt Hdr) Rr dR hpos place (ZK60.ProtocolClassify.epxMsg Rr dR place pos)
    (ZK60.ProtocolClassify.epxMsg_place Rr dR place pos hplace) ZK60.ProtocolClassify.EpxSalt.pads
    ZK60.ProtocolClassify.EpxSalt.salts ZK60.ProtocolClassify.EpxSalt.paths ClsStmt.inRoot tag

/-- **THE STAGE-DEGREE-INSTANTIATED TOP THEOREM** (D63 lane L65): `sshC_productionReadyL_epP_claimsW` instantiated at
the concrete per-slot escape counts `sshDgI` (`[2, 2, 2, 1, …]`) and `sshDgO` (`[2, 1, 2, 1, 2, 12, 2, 1, …]`). **`hD`
is unchanged**: `stgDefsV_valid_inC` and `stgDefsV_valid_out` prove the four entry-level `r0` conjuncts conditionally on
`StgCsIODeg` (lane L63's open `csIOI`/`csIOO` link), and connecting them to `hD` is deferred to L65b. -/
theorem sshC_productionReadyL_epP_dg
    (Rp : ClassifyRunPublicP S)
    (Lq : ℕ)
    (Lb : ℕ)
    (preA preB : Hdr → Except String Unit)
    (start : (HIn → Dig) → ClsStmt Hdr → Tr)
    (inc : Hdr → IncV)
    (incG : Hdr → StageGeom)
    (Pk : ℕ → Exec.Block.BlockParams)
    (sgeom : ClsStmt Hdr → ℕ → Exec.Block.SegGeom)
    (check : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bRows bLogN : ℕ → ℕ)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr →
      Except String Tr)
    (outc : Hdr → ℕ → OutcV)
    (outcG : Hdr → StageGeom)
    (P : RunP Hdr (S.Tok → ℕ) Coins)
    (h64 : 64 ≤ Lq)
    (hr : 8 * (CinR).R ≤ Lq)
    (hon : HonestIn Coins (CinR))
    (U : K)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (key : Option Dig)
    (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq)
    (hL64 : Lq < 2 ^ 64)
    (Rn : RtRun (classifyRunV Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : (RtRun.pf Rn).Valid)
    (hw : Hdr → ClsHdrW)
    (hRn : ∀ s, RtRun.hdr Rn s = clsHdrOf hw s)
    (D : RtKData K Lq)
    (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (RtRun.pf Rn))
    {ι : Type}
    [Fintype ι]
    (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K)
    (kOf : ι → ℕ)
    (δOf : ι → ℝ≥0∞)
    (E0 : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S (ZK60.ProtocolClassify.EpxSalt Rr))
    {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpenP Rp Lq (classifyRunV Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) P (CinR) h64 hr hon U site kOf δOf εzk)
    (hU : U ^ 2 = algebraMap GF K 7)
    (cx0 : IncCtx)
    (pin pout : RtPart)
    (Iin : RtInc Lq inc incG pin)
    (Oout : RtOutc Lq outc outcG pout)
    (bp : ∀ k, RtBlk Lq (Pk k))
    (wXk gXk mXk : ℕ → ℕ)
    (hσ : RtRun.σs Rn = rtParts (classifyRunV Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom)
    (hIA : RkPcsAt U tag ogStage Iin.pA)
    (hIH : RkPcsAt U tag ogStage Iin.pH)
    (hOA : RkPcsAt U tag ogStage Oout.pA)
    (hOH : RkPcsAt U tag ogStage Oout.pH)
    (hBA : ∀ k, RkPcsR13 U tag (bp k).pA)
    (hBH : ∀ k, RkPcsR13 U tag (bp k).pH)
    (htI : Iin.tag = tag)
    (htO : Oout.tag = tag)
    (htB : ∀ k, (bp k).tag = tag)
    (hfIA : 8 * Iin.pA.rows ≤ Lq)
    (hfIH : 8 * Iin.pH.rows ≤ Lq)
    (hfOA : 8 * Oout.pA.rows ≤ Lq)
    (hfOH : 8 * Oout.pH.rows ≤ Lq)
    (hfBA : ∀ k, 8 * (bp k).pA.rows ≤ Lq)
    (hfBH : ∀ k, 8 * (bp k).pH.rows ≤ Lq)
    (hfIM : 8 * (2 * pin.S + 4) ≤ Lq)
    (hfOM : 8 * (2 * pout.S + 4) ≤ Lq)
    (hfBM : ∀ k, 8 * (2 * (bp k).S + 4) ≤ Lq)
    (Vi : IncV)
    (F : ℕ → OutcV)
    (hinc : ∀ hd, inc hd = Vi)
    (houtc : ∀ hd v, outc hd v = F v)
    (hchk : ∀ s : ClsStmt Hdr, check s 0 = .ok () → s.verdict ≤ 1)
    (hLb1 : 0 < Lb)
    (lscIn lscOut : Exec.Block.ZClaim)
    (mIn kIn kOut : ℕ)
    (hlscIn : ∀ hd, (inc hd).lay.logupSumClaim = lscIn)
    (hlscOut : ∀ hd v, (outc hd v).lay.logupSumClaim = lscOut)
    (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn)
    (hkIn : ∀ hd, (inc hd).lay.nFunctionals = kIn)
    (hkOut : ∀ hd v, (outc hd v).lay.nFunctionals = kOut)
    (base : ℕ → RkPart K Lq)
    (eL : ℕ)
    (hDe : D = ebData U tag Lq h64 key domain hs hL abRdIn (RtRun.pf Rn)
      (rxPs base Lb (rxDinG ogStage (RtRun.pf Rn) pin.S kIn Iin.pA.rows Iin.pH.rows Iin.nA Iin.nH mIn)
        (fun k => rxDblk (RtRun.pf Rn) k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA
          (bp k).nH)
        (rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut Oout.pA.rows Oout.pH.rows Oout.nA Oout.nH))
      (rxAcc (ZK60.ProtocolClassify.vdWin Vi) (ZK60.ProtocolClassify.vdWout F) Pk (RtRun.pf Rn) Lb) (rxLsc lscIn lscOut Pk Lb) eL)
    (pXk : ∀ k, RtPcs (fun (s : ClsStmt Hdr) H root cl o t => bndOpen H s k root cl o t))
    (hXk : ∀ k, ZK60.ProtocolClassify.RkPcsR13 U tag (pXk k))
    (hwXk : ∀ k, k + 1 < Lb → wXk (k + 1) = (bp k).nOut + (bp (k + 1)).nIn + (pXk (k + 1)).rows)
    (hmXk : ∀ k, k + 1 < Lb → mXk (k + 1) = (pXk (k + 1)).m)
    (hfitXk : ∀ k, 8 * (pXk k).rows ≤ Lq)
    (hgXk : ∀ k, k + 1 < Lb → (base (k + 1 + 1)).gX
      = ZK60.ProtocolClassify.rkR13 (pXk (k + 1)).rows ((RtRun.pf Rn).off (k + 1) + 2))
    (hnXk : ∀ k, k + 1 < Lb → (base (k + 1 + 1)).nX = (bp k).nOut + (bp (k + 1)).nIn)
    (hwX0 : wXk 0 = Iin.nOut + (bp 0).nIn + (pXk 0).rows)
    (hmX0 : mXk 0 = (pXk 0).m)
    (hgX1 : (base 1).gX = ZK60.ProtocolClassify.rkR13 (pXk 0).rows ((RtRun.pf Rn).off 0 + 2))
    (hnX1 : (base 1).nX = Iin.nOut + (bp 0).nIn)
    (hOX : ZK60.ProtocolClassify.RkPcsR13 U tag Oout.pX)
    (hwXo : ∀ k, k + 1 = Lb → pout.wX = (bp k).nOut + Oout.nIn + Oout.pX.rows)
    (hfitXo : 8 * Oout.pX.rows ≤ Lq)
    (hgXo : ∀ k, k + 1 = Lb → (base (k + 1 + 1)).gX
      = ZK60.ProtocolClassify.rkR13 Oout.pX.rows ((RtRun.pf Rn).off (k + 1) + 2))
    (hnXo : ∀ k, k + 1 = Lb → (base (k + 1 + 1)).nX = (bp k).nOut + Oout.nIn)
    (hgX0 : (base 0).gX = rkAt ogEp Iin.pX.rows 1)
    (hnX0 : (base 0).nX = Iin.nIn)
    (hXep : RkPcsAt U tag ogEp Iin.pX)
    (hfitX : 8 * Iin.pX.rows ≤ Lq)
    (hRr : Iin.pX.rows = Rr)
    (hL81 : 81 ≤ Lq)
    (hPk : ZK60.Exec.Block.Join.R13H.ShieldRunAt Pk Rp.blks Lb)
    (hoAK : ∀ k, k < Lb → (D.opA (k + 1)).lc = Exec.Block.rowLog (Pk k) .a)
    (hoHK : ∀ k, k < Lb → (D.opH (k + 1)).lc = Exec.Block.rowLog (Pk k) .h)
    (hoIK : ∀ k, k < Lb → (D.opX (k + 1)).lc = Exec.Block.rowLog (Pk k) .inp)
    (hoOK : ∀ k, k < Lb → (D.opX (k + 1 + 1)).lc = Exec.Block.rowLog (Pk k) .out)
    (hslB : ∀ k, k < Lb → D.sls (k + 1) = Exec.Block.blockSchedXB (Pk k) ((RtRun.pf Rn).off (k + 1) + 5)
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ((ZK60.ProtocolClassify.bwFslRun U tag Lq h64 Lb Pk (fun k => (bp k).S) D (RtRun.pf Rn)
        hoAK hoHK hoIK hoOK (ZK60.ProtocolClassify.shieldRunProg hPk) (ZK60.ProtocolClassify.shieldRunPubs hPk)) k))
    {ιL πL κL : ℕ → Type}
    [∀ k, Fintype (ιL k)]
    [∀ k, Fintype (πL k)]
    [∀ k, Fintype (κL k)]
    (AlkL : (k : ℕ) → List (QB Lq × Dig) × Option (List UInt8) → ιL k ⊕ (πL k ⊕ πL k) → Tup K)
    (TL : (k : ℕ) → κL k → Tup K)
    (mlkL : (k : ℕ) → List (QB Lq × Dig) × Option (List UInt8) → κL k → K)
    (P0in P0out : Exec.Block.BlockParams)
    (csIOI csIOO : StgVw Lq → Exec.Block.Cm → Exec.Block.ZClaim → K)
    (hIOI : ∀ v (cm : Exec.Block.Cm) (z : Exec.Block.ZClaim) (a : Fp2), csIOI v cm { z with value := a } = csIOI v cm z)
    (hIOO : ∀ v (cm : Exec.Block.Cm) (z : Exec.Block.ZClaim) (a : Fp2), csIOO v cm { z with value := a } = csIOO v cm z)
    (hNin : ∀ k, k < P0in.geom.slots.length → 0 < stgN P0in k ∧ stgN P0in k * (Exec.Block.slotShape P0in k).2.2 + 2 ≤ 512)
    (hNout : ∀ k, k < P0out.geom.slots.length → 0 < stgN P0out k ∧ stgN P0out k * (Exec.Block.slotShape P0out k).2.2 + 2 ≤ 512)
    (hN64I : ∀ k, k < P0in.geom.slots.length → stgN P0in k < 64)
    (hN64O : ∀ k, k < P0out.geom.slots.length → stgN P0out k < 64)
    (hIOlI : ZK60.ProtocolClassify.VwLoc ((RtRun.pf Rn).off 0 + 5 + (7 + mIn)) csIOI)
    (hIOlO : ZK60.ProtocolClassify.VwLoc ((RtRun.pf Rn).off (Lb + 1) + 2 + (7 + 2)) csIOO)
    (eI eO : ℕ)
    (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop)
    (hb0 : StgLists (base 0) (stgSchedV P0in mIn ((RtRun.pf Rn).off 0 + 5) ZK60.ProtocolClassify.stgHostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgFstIC U hbij tag h64 P0in (ZK60.ProtocolClassify.vdWin Vi) ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows pin.S csIOI))
      (stgDefsV P0in mIn ((RtRun.pf Rn).off 0 + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.sshΦIC U hbij tag h64 P0in Vi ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows csIOI) ZK60.ProtocolClassify.sshDgI) (stgLkSqV mIn ((RtRun.pf Rn).off 0 + 5) eI (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛI))
    (hbL : StgLists (base (Lb + 1)) (stgSchedV P0out 2 ((RtRun.pf Rn).off (Lb + 1) + 2) (ZK60.ProtocolClassify.stgHostOut P0out) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgFstO U hbij tag h64 P0out (ZK60.ProtocolClassify.vdWout F) ((RtRun.pf Rn).off (Lb + 1) + pout.pre) ((RtRun.pf Rn).off (Lb + 1) + 2) ogStage.lc ogStage.h ogStage.Q ogStage.e Oout.pA.rows Oout.pH.rows pout.S csIOO))
      (stgDefsV P0out 2 ((RtRun.pf Rn).off (Lb + 1) + 2) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.sshΦO U hbij tag h64 P0out F ((RtRun.pf Rn).off (Lb + 1) + pout.pre) ((RtRun.pf Rn).off (Lb + 1) + 2) ogStage.lc ogStage.h ogStage.Q ogStage.e Oout.pA.rows Oout.pH.rows csIOO) ZK60.ProtocolClassify.sshDgO) (stgLkSqV 2 ((RtRun.pf Rn).off (Lb + 1) + 2) eO (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛO))
    (hPin : ∀ hd cx, StgSame P0in ((inc hd).bp cx))
    (hPout : ∀ hd v, StgSame P0out (outc hd v).bp)
    (hTrIIO : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ZK60.ProtocolClassify.StgClaimsIOC U key domain (inc (A.run G).1.hdr) mIn ((RtRun.pf Rn).off 0 + 5) ((RtRun.pf Rn).off 0 + pin.pre) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows ((RtRun.pf Rn).off 0 + 5) ((RtRun.pf Rn).off 0 + 5 + 4 + mIn) csIOI) G (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hTrOIO : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ZK60.ProtocolClassify.StgClaimsIOCO U key domain (outc (A.run G).1.hdr (A.run G).1.verdict).bp ((RtRun.pf Rn).off (Lb + 1) + 2) ((RtRun.pf Rn).off (Lb + 1) + pout.pre) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e Oout.pA.rows Oout.pH.rows ((RtRun.pf Rn).off (Lb + 1) + 2) ((RtRun.pf Rn).off (Lb + 1) + 2 + 4 + 2) csIOO) G (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hR0_blk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ∀ k, k < Lb → ∀ sx ∈ D.r0 (k + 1), RaDefAtB U key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) sx)
    (hR1_blk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ∀ k, k < Lb → ∀ sx ∈ D.r1 (k + 1), RaDefAtB U key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) sx)
    (hH0_blk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ∀ k, k < Lb → ∀ sx ∈ D.h0 (k + 1), RaDefAtB U key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) sx)
    (hH1_blk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ∀ k, k < Lb → ∀ sx ∈ D.h1 (k + 1), RaDefAtB U key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) sx)
    (hLU_blk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ∀ k, k < Lb → ∀ sx ∈ D.lu (k + 1), RaLkAtB U key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (AlkL k) (TL k) (mlkL k) G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) sx)
    (hLI_stg : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      StgLkAtV U key domain (fun ch => (inc (A.run G).1.hdr).bp (ZK60.Exec.StageV.incCtx (inc (A.run G).1.hdr).pub ch)) mIn ((RtRun.pf Rn).off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛI G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hLO_stg : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      StgLkAtV U key domain (fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp) 2 ((RtRun.pf Rn).off (Lb + 1) + 2) OutcV.bga (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛO G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hdinS : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ InOkP Rp ((ZK60.ProtocolClassify.epxE (CinR) (ZK60.ProtocolClassify.epxMk Rr dR place hpos hplace ClsStmt.inRoot tag) pos (ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11)) E0) (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ZK60.ProtocolClassify.StgDoomAtV U key domain P0in (fun ch => (inc (A.run G).1.hdr).bp (ZK60.Exec.StageV.incCtx (inc (A.run G).1.hdr).pub ch)) mIn ((RtRun.pf Rn).off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) ZK60.ProtocolClassify.stgHostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgFstIC U hbij tag h64 P0in (ZK60.ProtocolClassify.vdWin Vi) ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows pin.S csIOI) (ZK60.ProtocolClassify.sshΦIC U hbij tag h64 P0in Vi ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows csIOI) ZK60.ProtocolClassify.sshDgI eI ΛI G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hblk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < Rp.blks.length),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      Nonempty (ZK60.ProtocolClassify.RdBlkR13B U D k (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.Exec.Block.card_K_gt K) Rp.blks[k].pub
        (((ZK60.ProtocolClassify.epxE (CinR) (ZK60.ProtocolClassify.epxMk Rr dR place hpos hplace ClsStmt.inRoot tag) pos (ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11)) E0) (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        (((ZK60.ProtocolClassify.epxE (CinR) (ZK60.ProtocolClassify.epxMk Rr dR place hpos hplace ClsStmt.inRoot tag) pos (ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11)) E0) (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1))))
    (hdoutS : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ OutOkP Rp ((classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768).ypub (A.runLog G).1.1)
        ((ZK60.ProtocolClassify.epxE (CinR) (ZK60.ProtocolClassify.epxMk Rr dR place hpos hplace ClsStmt.inRoot tag) pos (ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11)) E0) (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ZK60.ProtocolClassify.StgDoomAtV U key domain P0out (fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp) 2 ((RtRun.pf Rn).off (Lb + 1) + 2) OutcV.bga (ZK60.ProtocolClassify.stgHostOut P0out) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgFstO U hbij tag h64 P0out (ZK60.ProtocolClassify.vdWout F) ((RtRun.pf Rn).off (Lb + 1) + pout.pre) ((RtRun.pf Rn).off (Lb + 1) + 2) ogStage.lc ogStage.h ogStage.Q ogStage.e Oout.pA.rows Oout.pH.rows pout.S csIOO) (ZK60.ProtocolClassify.sshΦO U hbij tag h64 P0out F ((RtRun.pf Rn).off (Lb + 1) + pout.pre) ((RtRun.pf Rn).off (Lb + 1) + 2) ogStage.lc ogStage.h ogStage.Q ogStage.e Oout.pA.rows Oout.pH.rows csIOO) ZK60.ProtocolClassify.sshDgO eO ΛO G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hLay : ZK60.ProtocolClassify.StgInLay pos Vi.pub.tokens Vi.pub.inEpWords)
    (hdzW : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      (∃ (k : Fin dR) (i : Fin (2 ^ 8)), Vi.pub.tokens ≤ k.val * 2 ^ 8 + i.val
        ∧ k.val * 2 ^ 8 + i.val < Vi.pub.inEpWords ∧ ((CinR).decodeIn ((ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11)) (A.runLog G).2 (A.runLog G).1.1) 768).1 ((CinR).place k) i ≠ 0)
  →
      ZK60.ProtocolClassify.StgDoomAtV U key domain P0in (fun ch => (inc (A.run G).1.hdr).bp (ZK60.Exec.StageV.incCtx (inc (A.run G).1.hdr).pub ch)) mIn ((RtRun.pf Rn).off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) ZK60.ProtocolClassify.stgHostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgFstIC U hbij tag h64 P0in (ZK60.ProtocolClassify.vdWin Vi) ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows pin.S csIOI) (ZK60.ProtocolClassify.sshΦIC U hbij tag h64 P0in Vi ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows csIOI) ZK60.ProtocolClassify.sshDgI eI ΛI G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hzk : ∀ q R', q ≤ 2 ^ 64 → R' ≤ 2 ^ 64 → εzk q R' ≤ εzkTarget q R') :
    ProductionReadyL (classifyModelP Rp) (classifyArithP Rp) (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768)
      (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :=
  sshC_productionReadyL_epP_claimsW (Rr := Rr) (dR := dR) (hpos := hpos) (place := place) (hplace := hplace) (tag := tag)
    (Rp := Rp) (Lq := Lq) (Lb := Lb) (preA := preA) (preB := preB) (start := start)
    (inc := inc) (incG := incG) (Pk := Pk) (sgeom := sgeom) (check := check) (paths := paths)
    (digest := digest) (bRows := bRows) (bLogN := bLogN) (bndCheck := bndCheck) (bndOpen := bndOpen) (outc := outc)
    (outcG := outcG) (P := P) (h64 := h64) (hr := hr) (hon := hon) (U := U)
    (hbij := hbij) (key := key) (domain := domain) (hs := hs) (hL := hL) (hL64 := hL64)
    (Rn := Rn) (hv := hv) (hw := hw) (hRn := hRn) (D := D) (hD := hD)
    (ι := ι) (site := site) (kOf := kOf) (δOf := δOf) (E0 := E0) (εzk := εzk)
    (O := O) (hU := hU) (cx0 := cx0) (pin := pin) (pout := pout) (Iin := Iin)
    (Oout := Oout) (bp := bp) (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ)
    (hgeo := hgeo) (hIA := hIA) (hIH := hIH) (hOA := hOA) (hOH := hOH) (hBA := hBA)
    (hBH := hBH) (htI := htI) (htO := htO) (htB := htB) (hfIA := hfIA) (hfIH := hfIH)
    (hfOA := hfOA) (hfOH := hfOH) (hfBA := hfBA) (hfBH := hfBH) (hfIM := hfIM) (hfOM := hfOM)
    (hfBM := hfBM) (Vi := Vi) (F := F) (hinc := hinc) (houtc := houtc) (hchk := hchk)
    (hLb1 := hLb1) (lscIn := lscIn) (lscOut := lscOut) (mIn := mIn) (kIn := kIn) (kOut := kOut)
    (hlscIn := hlscIn) (hlscOut := hlscOut) (hmIn := hmIn) (hkIn := hkIn) (hkOut := hkOut) (base := base)
    (eL := eL) (hDe := hDe) (pXk := pXk) (hXk := hXk) (hwXk := hwXk) (hmXk := hmXk)
    (hfitXk := hfitXk) (hgXk := hgXk) (hnXk := hnXk) (hwX0 := hwX0) (hmX0 := hmX0) (hgX1 := hgX1)
    (hnX1 := hnX1) (hOX := hOX) (hwXo := hwXo) (hfitXo := hfitXo) (hgXo := hgXo) (hnXo := hnXo)
    (hgX0 := hgX0) (hnX0 := hnX0) (hXep := hXep) (hfitX := hfitX) (hRr := hRr) (hL81 := hL81)
    (hPk := hPk) (hoAK := hoAK) (hoHK := hoHK) (hoIK := hoIK) (hoOK := hoOK) (hslB := hslB)
    (ιL := ιL) (πL := πL) (κL := κL) (AlkL := AlkL) (TL := TL) (mlkL := mlkL)
    (P0in := P0in) (P0out := P0out) (csIOI := csIOI) (csIOO := csIOO) (hIOI := hIOI) (hIOO := hIOO)
    (hNin := hNin) (hNout := hNout) (hN64I := hN64I) (hN64O := hN64O) (hIOlI := hIOlI) (hIOlO := hIOlO)
    (dgI := ZK60.ProtocolClassify.sshDgI) (dgO := ZK60.ProtocolClassify.sshDgO)
    (eI := eI) (eO := eO) (ΛI := ΛI) (ΛO := ΛO)
    (hb0 := hb0) (hbL := hbL) (hPin := hPin) (hPout := hPout)
    (hTrIIO := hTrIIO) (hTrOIO := hTrOIO) (hR0_blk := hR0_blk)
    (hR1_blk := hR1_blk) (hH0_blk := hH0_blk) (hH1_blk := hH1_blk) (hLU_blk := hLU_blk) (hLI_stg := hLI_stg) (hLO_stg := hLO_stg)
    (hdinS := hdinS) (hblk := hblk) (hdoutS := hdoutS) (hLay := hLay) (hdzW := hdzW) (hzk := hzk)

end SshTopDg

end RunShapeP

end ZK60.ProtocolClassify
