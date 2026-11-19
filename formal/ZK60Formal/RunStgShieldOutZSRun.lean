/-
D63 lane L63 (2026-11-19), L63 leg 13, part 87: **OUTC-07 ZS's zero sum at every reading of an accepted run** (step 1
of HANDOFF_20261119_2.md joined; the OUT-C twin of `shd_zs_run`, RunStgShieldIncZSRun.lean, at part `Lb + 1`).

* **`shd_zsO_run`**: on an accepted run outside `EvXR` with no doomed `opA`, `M` or slot entrant, at every reading of
  stage OUT-C, `Σ u = 0` of the `H_out` plane `u` at the run's view. `StgTrueAt` is assembled as the chain assembles
  it (RunStgShieldClTrue.lean, `hTrO`): the reader `ssh_readO` (the verdict window `hWout`), the claims
  `ssh_claimsAt_of_split` of `ssh_AHAtO` and `ssh_ioOfIOCO` of the IO claims `hIOC`, and `M` by `ssh_MAtIO`; the host
  functionals by `ssh_hostAt_of_M`; slot `7` vanishes by `ssh_hDO_all` (its start state, `¬ rtKsl.Dm`) and gives the
  sum by `shd_zsO_of_phi`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutZS
import ZK60Formal.RunStgShieldTrOIO

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun ZK60.Assembly
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

section Run

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (tag : MTag)
  {Hdr : Type} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
  (hL64 : Lq < 2 ^ 64)
  (Lb : ℕ) (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr)
  (inc : Hdr → IncV) (incG : Hdr → StageGeom) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
  (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **OUTC-07 ZS AT EVERY READING OF AN ACCEPTED RUN**: `Σ u = 0` of the `H_out` plane at the run's view, at an OUT-C
schedule with `lt = 12`, from no doomed `opA`, `M` or slot entrant and the IO claims part `hIOC`. -/
theorem shd_zsO_run
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
    (hIA : RkPcsAt U tag ogStage I.pA) (hIH : RkPcsAt U tag ogStage I.pH) (hOA : RkPcsAt U tag ogStage O.pA)
    (hOH : RkPcsAt U tag ogStage O.pH)
    (hBA : ∀ k, RkPcsR13 U tag (bp k).pA) (hBH : ∀ k, RkPcsR13 U tag (bp k).pH)
    (hfIA : 8 * I.pA.rows ≤ Lq) (hfIH : 8 * I.pH.rows ≤ Lq) (hfOA : 8 * O.pA.rows ≤ Lq) (hfOH : 8 * O.pH.rows ≤ Lq)
    (hfBA : ∀ k, 8 * (bp k).pA.rows ≤ Lq) (hfBH : ∀ k, 8 * (bp k).pH.rows ≤ Lq)
    (htI : I.tag = tag) (htO : O.tag = tag) (htB : ∀ k, (bp k).tag = tag)
    (hfIM : 8 * (2 * pin.S + 4) ≤ Lq) (hfOM : 8 * (2 * pout.S + 4) ≤ Lq) (hfBM : ∀ k, 8 * (2 * (bp k).S + 4) ≤ Lq)
    (F : ℕ → OutcV) (Win : List (TItem × Dig) → IncV) (lscIn lscOut : Block.ZClaim)
    (mIn kIn kOut : ℕ) (hlscIn : ∀ hd, (inc hd).lay.logupSumClaim = lscIn)
    (hlscOut : ∀ hd v, (outc hd v).lay.logupSumClaim = lscOut) (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn)
    (hkIn : ∀ hd, (inc hd).lay.nFunctionals = kIn) (hkOut : ∀ hd v, (outc hd v).lay.nFunctionals = kOut)
    (base : ℕ → RkPart K Lq) (rdx : List UInt8 → Option Dig) (eL : ℕ)
    (D : RtKData K Lq)
    (hDe : D = ebData U tag Lq h64 key domain hs hL rdx R.pf
      (rxPs base Lb (rxDinG ogStage R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
        (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
        (rxDoutG ogStage R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH))
      (rxAcc Win (vdWout F) Pk R.pf Lb) (rxLsc lscIn lscOut Pk Lb) eL)
    (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) R.pf)
    (n : ℕ) (hn : R.pf.parts.length ≤ n)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G)
      (A.run G).1 (A.run G).2 = .ok ())
    (hWin : Win ((R.tr G (A.run G)).take (R.pf.off 0 + pin.pre)) = inc (A.run G).1.hdr)
    (hWout : vdWout F ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + pout.pre))
      = outc (A.run G).1.hdr (A.run G).1.verdict)
    (hX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hA : ¬ (rtKA key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD).Dm n (A.runLog G).2 (R.tr G (A.run G)))
    (hMk : ¬ (rtKM key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD).Dm n (A.runLog G).2 (R.tr G (A.run G)))
    (hns : ¬ (rtKsl key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD).Dm n (A.runLog G).2 (R.tr G (A.run G)))
    (hU : U ^ 2 = algebraMap GF K 7)
    (P0 : Block.BlockParams) (hPout : ∀ hd v, StgSame P0 (outc hd v).bp)
    (hN : ∀ k, k < P0.geom.slots.length → 0 < stgN P0 k ∧ stgN P0 k * (Block.slotShape P0 k).2.2 + 2 ≤ 512)
    (hN64 : ∀ k, k < P0.geom.slots.length → stgN P0 k < 64) (h7 : 7 < P0.geom.slots.length)
    (Op : OutcPub) (hGb : (outc (A.run G).1.hdr (A.run G).1.verdict).geo.bLogN = 14)
    (hOL : outcLay (outc (A.run G).1.hdr (A.run G).1.verdict).pub 14 = outcLay Op 14)
    (hlt : (outc (A.run G).1.hdr (A.run G).1.verdict).pub.lt = 12)
    (hlc : 0 < (outc (A.run G).1.hdr (A.run G).1.verdict).bp.logCols)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (hIOl : VwLoc (R.pf.off (Lb + 1) + 2 + (7 + 2)) csIO)
    (hS : D.sls (Lb + 1) = stgSchedV P0 2 (R.pf.off (Lb + 1) + 2) (stgHostOut P0)
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (stgFstO U hbij tag h64 P0 (vdWout F) (R.pf.off (Lb + 1) + pout.pre) (R.pf.off (Lb + 1) + 2)
        ogStage.lc ogStage.h ogStage.Q ogStage.e O.pA.rows O.pH.rows pout.S csIO))
    (hIOC : StgClaimsIOCO U key domain (outc (A.run G).1.hdr (A.run G).1.verdict).bp (R.pf.off (Lb + 1) + 2)
      (R.pf.off (Lb + 1) + pout.pre) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e O.pA.rows O.pH.rows (R.pf.off (Lb + 1) + 2)
        (R.pf.off (Lb + 1) + 2 + 4 + 2) csIO) G (A.runLog G).2 (R.tr G (A.run G))) :
    ∀ hdr core ch rs, StgRd key domain Lq (fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp) 2
        (R.pf.off (Lb + 1) + 2) OutcV.bga G (R.tr G (A.run G)) hdr core ch rs →
      ∑ j, (shdOutcHd U tag h64 Op O.pH.rows (R.pf.off (Lb + 1) + 2 + 4 + 2)
        (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (R.tr G (A.run G)))).2.2.2 j = 0 := by
  intro hdr core ch rs hrd
  subst hDe
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  have hAH := ssh_AHAtO (U := U) (hbij := hbij) (tag := tag) (h64 := h64) (hs := hs) (hL := hL) (hL64 := hL64)
    (Lb := Lb) (preA := preA) (preB := preB) (start := start) (inc := inc) (incG := incG) (outc := outc)
    (outcG := outcG) (Pk := Pk) (sgeom := sgeom) (check := check) (paths := paths) (digest := digest)
    (bRows := bRows) (bLogN := bLogN) (bndCheck := bndCheck) (bndOpen := bndOpen) (R := R) (hv := hv) (cx0 := cx0)
    (pin := pin) (pout := pout) (I := I) (O := O) (bp := bp) (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ)
    (hLb := hLb) (hgeo := hgeo) (gS := ogStage) (hgS := ogStage_ok) (hgSQ := le_rfl) (hIA := hIA) (hIH := hIH)
    (hOA := hOA) (hOH := hOH) (hBA := hBA) (hBH := hBH) (hfIA := hfIA) (hfIH := hfIH) (hfOA := hfOA)
    (hfOH := hfOH) (hfBA := hfBA) (hfBH := hfBH) (Win := Win) (Wout := vdWout F) (lscIn := lscIn)
    (lscOut := lscOut) (mIn := mIn) (kIn := kIn) (kOut := kOut) (hlscIn := hlscIn) (hlscOut := hlscOut)
    (hmIn := hmIn) (base := base) (rdx := rdx) (eL := eL) (hD := hD) (n := n) (hn := hn) (A := A) (G := G)
    (hE := hE) (hWin := hWin) (hWout := hWout) (hX := hX) (hA := hA) (csIO := csIO)
  have hM := ssh_MAtIO (U := U) (hbij := hbij) (tag := tag) (h64 := h64) (hs := hs) (hL := hL) (hL64 := hL64)
    (Lb := Lb) (preA := preA) (preB := preB) (start := start) (inc := inc) (incG := incG) (outc := outc)
    (outcG := outcG) (Pk := Pk) (sgeom := sgeom) (check := check) (paths := paths) (digest := digest)
    (bRows := bRows) (bLogN := bLogN) (bndCheck := bndCheck) (bndOpen := bndOpen) (R := R) (hv := hv) (cx0 := cx0)
    (pin := pin) (pout := pout) (I := I) (O := O) (bp := bp) (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ)
    (hLb := hLb) (hgeo := hgeo) (gS := ogStage) (htI := htI) (htO := htO) (htB := htB) (hfIM := hfIM)
    (hfOM := hfOM) (hfBM := hfBM) (Win := Win) (Wout := vdWout F) (lscIn := lscIn) (lscOut := lscOut) (mIn := mIn)
    (kIn := kIn) (kOut := kOut) (hmIn := hmIn) (hkIn := hkIn) (hkOut := hkOut) (base := base) (rdx := rdx)
    (eL := eL) (hD := hD) (n := n) (hn := hn) (A := A) (G := G) (hE := hE) (hWin := hWin) (hWout := hWout)
    (hX := hX) (hM := hMk)
  have hIO := ssh_ioOfIOCO U key domain (outc (A.run G).1.hdr (A.run G).1.verdict).bp (R.pf.off (Lb + 1) + 2)
    (R.pf.off (Lb + 1) + pout.pre) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
    (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e O.pA.rows O.pH.rows (R.pf.off (Lb + 1) + 2)
      (R.pf.off (Lb + 1) + 2 + 4 + 2) csIO) G (A.runLog G).2 (R.tr G (A.run G))
    (O.hgt _ _) (fun k hk => (O.hgeomL _ _ k hk).1)
    (by rw [← O.hpre (A.run G).1.hdr (A.run G).1.verdict]
        exact (fun a b => by omega : ∀ a b : ℕ, a + (11 + b) = a + 2 + (7 + 2) + b) _ _)
    hIOC
  have htrue := ssh_trueAt_of_split U key domain (fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp) 2
    (R.pf.off (Lb + 1) + 2) OutcV.bga (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
    (fun v _ => ((vdWout F) (v.2.take (R.pf.off (Lb + 1) + pout.pre))).bp)
    (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e O.pA.rows O.pH.rows (R.pf.off (Lb + 1) + 2)
      (R.pf.off (Lb + 1) + 2 + 4 + 2) csIO)
    (stgMsv U tag h64 pout.S (R.pf.off (Lb + 1) + 2 + 3)) G (A.runLog G).2 (R.tr G (A.run G))
    (ssh_readO key domain F _ _ _ _ _ _ _ (congrArg OutcV.bp hWout) (O.hgt _ _))
    (ssh_claimsAt_of_split U key domain _ _ _ _ _ _ G _ _ hAH hIO) hM.2
  have hhf := ssh_hostAt_of_M U key domain (fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp) 2
    (R.pf.off (Lb + 1) + 2) OutcV.bga (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
    (stgMsv U tag h64 pout.S (R.pf.off (Lb + 1) + 2 + 3)) G (A.runLog G).2 (R.tr G (A.run G)) hM.2
  have hall := ssh_hDO_all key domain hs Lq hL R.pf R.rd hL64 hv U hbij _ hD tag h64 hU n (Lb + 1) (by omega)
    (by omega) (fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp) P0 F (R.pf.off (Lb + 1) + pout.pre)
    (R.pf.off (Lb + 1) + 2) ogStage.lc ogStage.h ogStage.Q ogStage.e O.pA.rows O.pH.rows pout.S csIO
    (fun _ => hPout _ _) (fun _ => O.hgt _ _) (fun _ k hk => (O.hgeomL _ _ k hk).1)
    (fun _ => stg_hhOut outc P0 hPout (A.run G).1.hdr (A.run G).1.verdict) hN hN64 hIOl
    G (A.runLog G).2 (R.tr G (A.run G)) hS hns htrue hhf
  obtain ⟨r, -, -, hΦ⟩ := hall hdr core ch rs hrd 7 h7
  have hrl : 7 ≤ rs.length := by
    have hslen : core.slots.length = (outc (A.run G).1.hdr (A.run G).1.verdict).bp.geom.slots.length :=
      hrd.2.2.2.1.1
    obtain ⟨acc, t', hacc⟩ := hrd.2.2.2.2.1
    have hrsl : rs.length = core.slots.length :=
      (ssh_rd_facts key domain _ 2 (R.pf.off (Lb + 1) + 2) _ G _ hdr core ch rs hrd (O.hgt _ _)
        (fun k hk => (O.hgeomL _ _ k hk).1) acc t' hacc).1
    rw [hrsl, hslen, ← (hPout (A.run G).1.hdr (A.run G).1.verdict).2]
    omega
  exact shd_zsO_of_phi U hbij tag h64 hU P0 (outc (A.run G).1.hdr (A.run G).1.verdict) (hPout _ _) Op hGb hOL hlt
    hlc O.pA.rows O.pH.rows (R.pf.off (Lb + 1) + 2) (R.pf.off (Lb + 1) + 2 + 4 + 2) csIO _ _
    ((rs.take 7).map Block.SlotRec.draws) (by rw [List.length_map, List.length_take]; omega) r.draws hΦ

end Run

end ZK60.ProtocolClassify
