/-
D63 lane L63 (2026-11-19), L63 leg 12, part 85: **the `H_out` opening's value-0 LogUp sum claim gives `OutCSum`**
(piece (iv) of step 1 of HANDOFF_20261119_1.md, the first of the two sum facts; the OUT-C twin of
RunStgShieldIncSum.lean at part `Lb + 1`).

* **`shd_lsc_semO`**: `logup_sum_claim` of stage OUT-C's layout on a matrix is `Σ h_lo + Σ_k Σ h_d_k − Σ h_gu8 + Σ u`
  of the nine `H` planes (signs `[1, 1, 1, 1, 1, 1, 1, −1, 1]`, every log `12`; lane L47's `claimSem_empty`,
  `sum_planeZ2W`);
* **`shd_outcSum_of_lsc`**: if that claim's value is `0` at `shdOutcHd`'s matrix, `OutCSum` holds there;
* **`ssh_run_lscO`**: on an accepted run outside `EvXR` with no doomed `opA` entrant, part `Lb + 1`'s `H` opening makes
  its LogUp sum claim `lscOut` true of its decoded matrix (`ssh_run_lscI`'s proof at part `Lb + 1`);
* **`shd_outcSum_run`**: with `D = ebData …`, `OutCSum` of `shdOutcHd` at the run's whole view.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutAt
import ZK60Formal.RunStgShieldIncSum

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

section Lsc

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- The `H_out` plane at group `i` on a matrix (the pair `(1, u)` of planes at the layout's `H` offsets, log `12`). -/
noncomputable def outcHPl (O : OutcPub) (logN R Q : ℕ) (X : Fin R → Fin (2 ^ logN + Q) → K) (i : ℕ)
    (b : Fin 12 → Bool) : K :=
  Block.Join.planeZ U logN R Q X
    ⟨.h, [(((outcLay O 14).hOff i).1, Fp2.one), (((outcLay O 14).hOff i).2, Block.fp2U)], 12, [], 0, 0⟩ b

/-- **Stage OUT-C's `logup_sum_claim` on a matrix is `Σ h_lo + Σ_k Σ h_d_k − Σ h_gu8 + Σ u`** (rows of `2^12`, every
`H` log `12`). -/
theorem shd_lsc_semO (hU : U ^ 2 = algebraMap GF K 7) (O : OutcPub) (hllo : O.llo = 12) (hldo : O.ldo = 12)
    (hltab : O.ltab = 12) (hlt : O.lt = 12) (logN R Q : ℕ) (hln : logN = 12) (X : Fin R → Fin (2 ^ logN + Q) → K) :
    claimSem U R logN Q X (outcLay O 14).logupSumClaim
      = (∑ b, outcHPl U O logN R Q X 0 b)
        + (∑ b, outcHPl U O logN R Q X 1 b + ∑ b, outcHPl U O logN R Q X 2 b + ∑ b, outcHPl U O logN R Q X 3 b
          + ∑ b, outcHPl U O logN R Q X 4 b + ∑ b, outcHPl U O logN R Q X 5 b + ∑ b, outcHPl U O logN R Q X 6 b)
        - (∑ b, outcHPl U O logN R Q X 7 b) + (∑ b, outcHPl U O logN R Q X 8 b) := by
  have hz : (outcLay O 14).logupSumClaim.parts =
      [⟨((outcLay O 14).hOff 0).1, O.llo, kI 1, []⟩, ⟨((outcLay O 14).hOff 0).2, O.llo, (kI 1).mul Block.fp2U, []⟩,
       ⟨((outcLay O 14).hOff 1).1, O.ldo, kI 1, []⟩, ⟨((outcLay O 14).hOff 1).2, O.ldo, (kI 1).mul Block.fp2U, []⟩,
       ⟨((outcLay O 14).hOff 2).1, O.ldo, kI 1, []⟩, ⟨((outcLay O 14).hOff 2).2, O.ldo, (kI 1).mul Block.fp2U, []⟩,
       ⟨((outcLay O 14).hOff 3).1, O.ldo, kI 1, []⟩, ⟨((outcLay O 14).hOff 3).2, O.ldo, (kI 1).mul Block.fp2U, []⟩,
       ⟨((outcLay O 14).hOff 4).1, O.ldo, kI 1, []⟩, ⟨((outcLay O 14).hOff 4).2, O.ldo, (kI 1).mul Block.fp2U, []⟩,
       ⟨((outcLay O 14).hOff 5).1, O.ldo, kI 1, []⟩, ⟨((outcLay O 14).hOff 5).2, O.ldo, (kI 1).mul Block.fp2U, []⟩,
       ⟨((outcLay O 14).hOff 6).1, O.ldo, kI 1, []⟩, ⟨((outcLay O 14).hOff 6).2, O.ldo, (kI 1).mul Block.fp2U, []⟩,
       ⟨((outcLay O 14).hOff 7).1, O.ltab, kI (-1), []⟩,
       ⟨((outcLay O 14).hOff 7).2, O.ltab, (kI (-1)).mul Block.fp2U, []⟩,
       ⟨((outcLay O 14).hOff 8).1, O.lt, kI 1, []⟩, ⟨((outcLay O 14).hOff 8).2, O.lt, (kI 1).mul Block.fp2U, []⟩] := by
    have hr9 : List.range 9 = [0, 1, 2, 3, 4, 5, 6, 7, 8] := rfl
    show (List.range (outcLay O 14).hLog.length).flatMap (fun p =>
      [(⟨((outcLay O 14).hOff p).1, (outcLay O 14).hLog.getD p 0, kI ((outcLay O 14).hSign.getD p 0), []⟩ :
          Block.ZPart),
       ⟨((outcLay O 14).hOff p).2, (outcLay O 14).hLog.getD p 0, (kI ((outcLay O 14).hSign.getD p 0)).mul Block.fp2U,
         []⟩]) = _
    rw [show (outcLay O 14).hLog.length = 9 from rfl, hr9]
    simp only [List.flatMap_cons, List.flatMap_nil, List.cons_append, List.nil_append, List.append_nil]
    rfl
  have he : Block.Join.W16.Look.EmptyParts logN (outcLay O 14).logupSumClaim := by
    intro q hq
    have hq' : q ∈ (List.range (outcLay O 14).hLog.length).flatMap (fun p =>
        [(⟨((outcLay O 14).hOff p).1, (outcLay O 14).hLog.getD p 0, kI ((outcLay O 14).hSign.getD p 0), []⟩ :
            Block.ZPart),
         ⟨((outcLay O 14).hOff p).2, (outcLay O 14).hLog.getD p 0,
           (kI ((outcLay O 14).hSign.getD p 0)).mul Block.fp2U, []⟩]) := hq
    rw [show (outcLay O 14).hLog.length = 9 from rfl] at hq'
    obtain ⟨p, hp, hqp⟩ := List.mem_flatMap.mp hq'
    have hp9 : p < 9 := List.mem_range.mp hp
    have hlog : (outcLay O 14).hLog.getD p 0 = 12 := by
      interval_cases p
      · show O.llo = 12; exact hllo
      · show O.ldo = 12; exact hldo
      · show O.ldo = 12; exact hldo
      · show O.ldo = 12; exact hldo
      · show O.ldo = 12; exact hldo
      · show O.ldo = 12; exact hldo
      · show O.ldo = 12; exact hldo
      · show O.ltab = 12; exact hltab
      · show O.lt = 12; exact hlt
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hqp
    rcases hqp with rfl | rfl
    · exact ⟨rfl, by show logN ≤ (outcLay O 14).hLog.getD p 0; omega, kI_canon _⟩
    · exact ⟨rfl, by show logN ≤ (outcLay O 14).hLog.getD p 0; omega, Fp2.canon_mul _ _⟩
  rw [Block.Join.W16.Look.claimSem_empty U R logN Q X _ _ _ hz he, hz]
  unfold outcHPl
  rw [Block.Join.W16.Look.sum_planeZ2W U 12 logN R Q hln X .h _ _ 12 le_rfl [] 0 0,
    Block.Join.W16.Look.sum_planeZ2W U 12 logN R Q hln X .h _ _ 12 le_rfl [] 0 0,
    Block.Join.W16.Look.sum_planeZ2W U 12 logN R Q hln X .h _ _ 12 le_rfl [] 0 0,
    Block.Join.W16.Look.sum_planeZ2W U 12 logN R Q hln X .h _ _ 12 le_rfl [] 0 0,
    Block.Join.W16.Look.sum_planeZ2W U 12 logN R Q hln X .h _ _ 12 le_rfl [] 0 0,
    Block.Join.W16.Look.sum_planeZ2W U 12 logN R Q hln X .h _ _ 12 le_rfl [] 0 0,
    Block.Join.W16.Look.sum_planeZ2W U 12 logN R Q hln X .h _ _ 12 le_rfl [] 0 0,
    Block.Join.W16.Look.sum_planeZ2W U 12 logN R Q hln X .h _ _ 12 le_rfl [] 0 0,
    Block.Join.W16.Look.sum_planeZ2W U 12 logN R Q hln X .h _ _ 12 le_rfl [] 0 0]
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, Fp2.toK_mul U hU, kI_one_toK,
    kI_negOne_toK, hllo, hldo, hltab, hlt]
  simp only [add_mul, Finset.sum_add_distrib, mul_assoc, ← Finset.mul_sum]
  ring

end Lsc

section OutSumV

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- **`OutCSum` from the `H` opening's value-0 LogUp sum claim** at `shdOutcHd`'s matrix. -/
theorem shd_outcSum_of_lsc (hU : U ^ 2 = algebraMap GF K 7) (O : OutcPub) (hllo : O.llo = 12) (hldo : O.ldo = 12)
    (hltab : O.ltab = 12) (hlt : O.lt = 12) (rH iH : ℕ) (w : StgVw Lq)
    (h : claimSem U rH ogStage.lc ogStage.Q (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w)
      (outcLay O 14).logupSumClaim = 0) :
    OutCSum (shdOutcHd U tag h64 O rH iH w) := by
  rw [shd_lsc_semO U hU O hllo hldo hltab hlt ogStage.lc rH ogStage.Q rfl] at h
  have e6 : ∑ k : Fin 6, ∑ c, (shdOutcHd U tag h64 O rH iH w).2.1 k c
      = ∑ b, outcHPl U O ogStage.lc rH ogStage.Q (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w) 1 b
        + ∑ b, outcHPl U O ogStage.lc rH ogStage.Q (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w) 2 b
        + ∑ b, outcHPl U O ogStage.lc rH ogStage.Q (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w) 3 b
        + ∑ b, outcHPl U O ogStage.lc rH ogStage.Q (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w) 4 b
        + ∑ b, outcHPl U O ogStage.lc rH ogStage.Q (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w) 5 b
        + ∑ b, outcHPl U O ogStage.lc rH ogStage.Q (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w) 6 b := by
    rw [Fin.sum_univ_six]
    rfl
  unfold OutCSum
  rw [e6]
  exact h

end OutSumV

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

/-- **PART `Lb + 1`'S `H` OPENING MAKES ITS LOGUP SUM CLAIM TRUE** of its decoded extracted matrix, on an accepted
run outside `EvXR` with no doomed `opA` entrant (`ssh_run_lscI`'s proof at stage OUT-C). -/
theorem ssh_run_lscO
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
    (gS : OGeo) (hgS : gS.Ok) (hgSQ : gS.Q ≤ 256)
    (hIA : RkPcsAt U tag gS I.pA) (hIH : RkPcsAt U tag gS I.pH) (hOA : RkPcsAt U tag gS O.pA)
    (hOH : RkPcsAt U tag gS O.pH)
    (hBA : ∀ k, RkPcsR13 U tag (bp k).pA) (hBH : ∀ k, RkPcsR13 U tag (bp k).pH)
    (hfIA : 8 * I.pA.rows ≤ Lq) (hfIH : 8 * I.pH.rows ≤ Lq) (hfOA : 8 * O.pA.rows ≤ Lq) (hfOH : 8 * O.pH.rows ≤ Lq)
    (hfBA : ∀ k, 8 * (bp k).pA.rows ≤ Lq) (hfBH : ∀ k, 8 * (bp k).pH.rows ≤ Lq)
    (Win : List (TItem × Dig) → IncV) (Wout : List (TItem × Dig) → OutcV) (lscIn lscOut : Block.ZClaim)
    (mIn kIn kOut : ℕ) (hlscIn : ∀ hd, (inc hd).lay.logupSumClaim = lscIn)
    (hlscOut : ∀ hd v, (outc hd v).lay.logupSumClaim = lscOut) (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn)
    (base : ℕ → RkPart K Lq) (rdx : List UInt8 → Option Dig) (eL : ℕ)
    (hD : (ebData U tag Lq h64 key domain hs hL rdx R.pf
      (rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
        (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
        (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH))
      (rxAcc Win Wout Pk R.pf Lb) (rxLsc lscIn lscOut Pk Lb) eL).Valid
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) R.pf)
    (n : ℕ) (hn : R.pf.parts.length ≤ n)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G)
      (A.run G).1 (A.run G).2 = .ok ())
    (hWin : Win ((R.tr G (A.run G)).take (R.pf.off 0 + pin.pre)) = inc (A.run G).1.hdr)
    (hWout : Wout ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + pout.pre)) = outc (A.run G).1.hdr (A.run G).1.verdict)
    (hX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hA : ¬ (rtKA key domain hs Lq hL R.pf R.rd hL64 hv U hbij _ hD).Dm n (A.runLog G).2 (R.tr G (A.run G))) :
    claimSem U O.pH.rows gS.lc gS.Q (decodeRows (encGL (K := K) gS.lc gS.h gS.Q) gS.e (UxC tag Lq h64 gS.h O.pH.rows
        (Block.cutO (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
          (Block.absAt ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oH))
            (R.pf.off (Lb + 1) + (2 + (4 + 2)))) (A.runLog G).2)
        (Block.absAt ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oH))
          (R.pf.off (Lb + 1) + (2 + (4 + 2)))))) lscOut = lscOut.value.toK U := by
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  have hi : Lb + 1 < R.pf.parts.length := by omega
  have hlen : ∀ (a : ℕ), ((R.tr G (A.run G)).take a).length = a → a ≤ (R.tr G (A.run G)).length := by
    intro a h
    rw [List.length_take] at h
    omega
  obtain ⟨-, ⟨oH⟩⟩ := rx_parts_AHG (U := U) (gS := gS) (hgS := hgS) (hgSQ := hgSQ) (tag := tag) (h64 := h64)
    (hs := hs) (hL := hL) (Lb := Lb) (preA := preA) (preB := preB) (start := start) (inc := inc) (incG := incG)
    (outc := outc) (outcG := outcG) (Pk := Pk) (sgeom := sgeom) (check := check) (paths := paths) (digest := digest)
    (bRows := bRows) (bLogN := bLogN) (bndCheck := bndCheck) (bndOpen := bndOpen) (R := R) (hv := hv) (cx0 := cx0)
    (pin := pin) (pout := pout) (I := I) (O := O) (bp := bp) (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ)
    (hLb := hLb) (hgeo := hgeo) (Win := Win) (Wout := Wout) (mIn := mIn) (kIn := kIn) (kOut := kOut)
    (base := base) (acc := _) (hacc := rfl) (A := A) (G := G) (hE := hE) (hWin := hWin) (hWout := hWout)
    (hX := hX) (i := Lb + 1) (hi := hi) (hIA := hIA) (hIH := hIH) (hOA := hOA) (hOH := hOH) (hBA := hBA) (hBH := hBH)
    (hfIA := hfIA) (hfIH := hfIH) (hfOA := hfOA) (hfOH := hfOH) (hfBA := hfBA) (hfBH := hfBH) (lscIn := lscIn)
    (lscOut := lscOut) (hlscIn := hlscIn) (hlscOut := hlscOut) (hmIn := hmIn) (ps := _) (hps := rfl) (lsc := _)
    (hlsc := rfl)
  have ndA := wr_ndA key domain hs Lq hL R.pf R.rd hL64 hv U hbij _ hD n (A.runLog G).2 (R.tr G (A.run G)) hA (Lb + 1)
    hi hn
  have sH := wr_rkOpen_sem U hbij tag Lq h64 key domain hs hL
    ((rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
      (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
      (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH)) (Lb + 1)).gH
    ((rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
      (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
      (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH)) (Lb + 1)).nH
    (fun hdr => (rxAcc Win Wout Pk R.pf Lb (Lb + 1) hdr).claims.h ++ [rxLsc lscIn lscOut Pk Lb (Lb + 1)]) _
    (rtW R.pf.sqs) _ (A.runLog G).2 (R.tr G (A.run G))
    (ndA _ (List.mem_cons_of_mem _ List.mem_cons_self)) (hlen _ oH.hpl) oH.hpre
    (by have h := oH.hcnt; rw [← oH.hrd] at h; exact h)
  have hv := sH (rxLsc lscIn lscOut Pk Lb (Lb + 1)) (List.mem_append_right _ List.mem_cons_self)
  simp only [wrOSem, rkOpen, UxW_eq_cut] at hv
  rw [rxPs_out, rxLsc_out] at hv
  exact hv

/-- **`OutCSum` AT THE RUN'S WHOLE VIEW**: with the run's kinds data `D = ebData …` (`hDe`), on an accepted run outside
`EvXR` with no doomed `opA` entrant, at stage OUT-C's registered logs, the claim `lscOut` the layout's (`hlscO`). -/
theorem shd_outcSum_run
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
    (Win : List (TItem × Dig) → IncV) (Wout : List (TItem × Dig) → OutcV) (lscIn lscOut : Block.ZClaim)
    (mIn kIn kOut : ℕ) (hlscIn : ∀ hd, (inc hd).lay.logupSumClaim = lscIn)
    (hlscOut : ∀ hd v, (outc hd v).lay.logupSumClaim = lscOut) (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn)
    (base : ℕ → RkPart K Lq) (rdx : List UInt8 → Option Dig) (eL : ℕ)
    (D : RtKData K Lq)
    (hDe : D = ebData U tag Lq h64 key domain hs hL rdx R.pf
      (rxPs base Lb (rxDinG ogStage R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
        (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
        (rxDoutG ogStage R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH))
      (rxAcc Win Wout Pk R.pf Lb) (rxLsc lscIn lscOut Pk Lb) eL)
    (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) R.pf)
    (n : ℕ) (hn : R.pf.parts.length ≤ n)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G)
      (A.run G).1 (A.run G).2 = .ok ())
    (hWin : Win ((R.tr G (A.run G)).take (R.pf.off 0 + pin.pre)) = inc (A.run G).1.hdr)
    (hWout : Wout ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + pout.pre)) = outc (A.run G).1.hdr (A.run G).1.verdict)
    (hX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hA : ¬ (rtKA key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD).Dm n (A.runLog G).2 (R.tr G (A.run G)))
    (hU : U ^ 2 = algebraMap GF K 7) (Op : OutcPub) (hlscO : lscOut = (outcLay Op 14).logupSumClaim)
    (hllo : Op.llo = 12) (hldo : Op.ldo = 12) (hltab : Op.ltab = 12) (hlt : Op.lt = 12) :
    OutCSum (shdOutcHd U tag h64 Op O.pH.rows (R.pf.off (Lb + 1) + 2 + 4 + 2)
      (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (R.tr G (A.run G)))) := by
  subst hDe
  have h := ssh_run_lscO U hbij tag h64 hs hL hL64 Lb preA preB start inc incG outc outcG Pk sgeom check paths digest
    bRows bLogN bndCheck bndOpen R hv cx0 pin pout I O bp wXk gXk mXk hσ hLb hgeo ogStage ogStage_ok le_rfl
    hIA hIH hOA hOH hBA hBH hfIA hfIH hfOA hfOH hfBA hfBH Win Wout lscIn lscOut mIn kIn kOut hlscIn hlscOut hmIn
    base rdx eL hD n hn A G hE hWin hWout hX hA
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  have hσo : R.σs[Lb + 1]? = some (rtOutcSeg outc outcG pout) := by
    rw [hσ]
    exact rx_getOut _ _ _ _
  have hpo : R.pf.part (Lb + 1) = pout := rx_part_of R (Lb + 1) _ hσo
  have hH : R.pf.off (Lb + 1) + (2 + (4 + 2)) < R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oH := by
    have hpre0 := O.hpre (A.run G).1.hdr (A.run G).1.verdict
    rw [hpo]
    simp only [RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  rw [ssh_absAt_take _ _ _ hH] at h
  have hz : (lscOut.value).toK U = 0 := by rw [hlscO]; exact Fp2.toK_zero U
  rw [hz, hlscO] at h
  refine shd_outcSum_of_lsc U tag h64 hU Op hllo hldo hltab hlt O.pH.rows (R.pf.off (Lb + 1) + 2 + 4 + 2) _ ?_
  rw [show R.pf.off (Lb + 1) + 2 + 4 + 2 = R.pf.off (Lb + 1) + (2 + (4 + 2)) by omega]
  exact h

end Run

end ZK60.ProtocolClassify
