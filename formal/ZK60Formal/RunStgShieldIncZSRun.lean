/-
D63 lane L63 (2026-11-18), part 68: **SIC_ZS's zero sum at every reading of an accepted run, and `hLI_stg`'s
conclusion with the sum facts at the readings** (item 4b, step 1 joined).

* `ssh_hDIC_all`: `ssh_hDIC` (`hDI_stg` at the repaired `ΦI`) at EVERY slot, through `ssh_defAll`;
* **`shd_zs_run`**: on an accepted run outside `EvXR` with no doomed `opA`, `M` or slot entrant, at every reading of
  stage IN-C, `Σ u = 0` of the `H_in` plane `u` at the run's view (`StgTrueAtC` assembled as the chain assembles it:
  `ssh_readI`, `ssh_AHAtI`, `ssh_iosOfIOC` of the IO claims `hIOC`, `ssh_MAtIO`; slot `3` by `shd_zs_of_phi`);
* `shd_hLI_of_rd`, **`shd_hLI_runR`**: `shd_hLI_of_sum`, `shd_hLI_run` with `ShdIncSumAt` required only at the
  readings.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIncZS

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun ZK60.Assembly
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)
open ZK60.RunShape (ClassifyRunPublicP)

/-! ## 1. `hDI_stg` at every slot -/

section DIall

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)
  (tag : MTag) (h64 : 64 ≤ Lq)

/-- **`ssh_hDIC` AT EVERY SLOT** of stage IN-C (part `0`), at `τ`'s view. -/
theorem ssh_hDIC_all (hU : U ^ 2 = algebraMap GF K 7) (n : ℕ) (hi : 0 < pf.parts.length) (hin : 0 < n)
    (Pof : List Fp2 → Block.BlockParams) (P0 : Block.BlockParams) (Vi : IncV) (n0 hdrLen m lc h Q e rA rH S : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K)
    (hP : ∀ ch, StgSame P0 (Pof ch)) (hgt : ∀ ch, (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hd : ∀ ch k, k < (Pof ch).geom.slots.length → 1 ≤ (Block.slotShape (Pof ch) k).2.2)
    (hhost : ∀ ch k hist dr df, (Pof ch).define k hist dr = .ok df →
      df.hosted = (stgHostIn k).map (fun x => (x.1, dr.getD x.2 Fp2.zero)))
    (hN : ∀ k, k < P0.geom.slots.length → 0 < stgN P0 k ∧ stgN P0 k * (Block.slotShape P0 k).2.2 + 2 ≤ 512)
    (hN64 : ∀ k, k < P0.geom.slots.length → stgN P0 k < 64)
    (hIOl : VwLoc (hdrLen + (7 + m)) csIO)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hS : D.sls 0 = stgSchedV P0 m hdrLen stgHostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (stgFstIC U hbij tag h64 P0 (vdWin Vi) n0 hdrLen m lc h Q e rA rH S csIO))
    (hns : ¬ (rtKsl key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ)
    (htrue : StgTrueAtC U key domain Pof m hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero))
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (fun v ch => ((vdWin Vi) (v.2.take n0)).bp (incCtx ((vdWin Vi) (v.2.take n0)).pub ch))
      (fun v k => StageV.incElog ((vdWin Vi) (v.2.take n0)).pub ((vdWin Vi) (v.2.take n0)).geo.bLogN k)
      (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + m) csIO) (stgMsv U tag h64 S (hdrLen + 3)) G lg τ) :
    ∀ hdr core ch rs, StgRd key domain Lq Pof m hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) G τ hdr core ch rs →
      ∀ k, k < P0.geom.slots.length → ∃ r, rs[k]? = some r ∧ r.draws.length = P0.draws k ∧
        stgΦBC U hbij P0 (Pof ch)
          (StageV.incElog ((vdWin Vi) (τ.take n0)).pub ((vdWin Vi) (τ.take n0)).geo.bLogN)
          (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + m) csIO
            (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ))
          (Fp2.zero, Fp2.zero, Fp2.zero) ((rs.take k).map Block.SlotRec.draws) k r.draws = 0 := by
  have hslot := ssh_slotStart key domain hs Lq hL pf rd hL64 hv U hbij D hD n 0 hi hin P0 Pof m hdrLen
    (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) stgHostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
    (stgFstIC U hbij tag h64 P0 (vdWin Vi) n0 hdrLen m lc h Q e rA rH S csIO) G lg τ hP hgt hS hns
  exact ssh_defAll U hbij hU key domain P0 Pof m hdrLen _ stgHostIn _ _ _ _ (stgRv U tag h64 S (hdrLen + 3))
    (stgMsv U tag h64 S (hdrLen + 3)) 512 G lg τ hP hgt hd hhost (fun _ _ _ => rfl)
    (fun k hk => ⟨(hN k hk).1, hN64 k hk, (hN k hk).2⟩) (stgMsv_mlin U tag h64 S (hdrLen + 3))
    (hdrLen + (7 + m)) le_rfl (vwLoc_vdWin Vi n0 _) (fun _ _ _ _ => rfl)
    (vwLoc_stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + m) _ (by omega) (by omega) csIO hIOl)
    (vwLoc_stgRv U tag h64 S (hdrLen + 3) _ (by omega)) (vwLoc_stgMsv U tag h64 S (hdrLen + 3) _ (by omega))
    hslot htrue (Or.inl (fun _ => rfl))

end DIall

/-! ## 2. `Σ u = 0` at every reading of an accepted run -/

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

/-- **SIC_ZS AT EVERY READING OF AN ACCEPTED RUN**: `Σ u = 0` of the `H_in` plane at the run's view, at the registered
stage IN-C (`hinc`), from no doomed `opA`, `M` or slot entrant and the IO claims part `hIOC`. -/
theorem shd_zs_run
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
    (Win : List (TItem × Dig) → IncV) (Wout : List (TItem × Dig) → OutcV) (lscIn lscOut : Block.ZClaim)
    (mIn kIn kOut : ℕ) (hlscIn : ∀ hd, (inc hd).lay.logupSumClaim = lscIn)
    (hlscOut : ∀ hd v, (outc hd v).lay.logupSumClaim = lscOut) (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn)
    (hkIn : ∀ hd, (inc hd).lay.nFunctionals = kIn) (hkOut : ∀ hd v, (outc hd v).lay.nFunctionals = kOut)
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
    (hMk : ¬ (rtKM key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD).Dm n (A.runLog G).2 (R.tr G (A.run G)))
    (hns : ¬ (rtKsl key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD).Dm n (A.runLog G).2 (R.tr G (A.run G)))
    (hU : U ^ 2 = algebraMap GF K 7)
    (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ)
    (hinc : ∀ hd, inc hd = shdP_incV tag Rp embDigest embFold bInRow)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (hIOl : VwLoc (R.pf.off 0 + 5 + (7 + mIn)) csIO)
    (hS : D.sls 0 = stgSchedV (shdP_P0in tag Rp embDigest embFold bInRow) mIn (R.pf.off 0 + 5) stgHostIn
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (stgFstIC U hbij tag h64 (shdP_P0in tag Rp embDigest embFold bInRow)
        (vdWin (shdP_incV tag Rp embDigest embFold bInRow)) (R.pf.off 0 + pin.pre) (R.pf.off 0 + 5) mIn
        ogStage.lc ogStage.h ogStage.Q ogStage.e I.pA.rows I.pH.rows pin.S csIO))
    (hIOC : StgClaimsIOC U key domain (inc (A.run G).1.hdr) mIn (R.pf.off 0 + 5) (R.pf.off 0 + pin.pre)
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e I.pA.rows I.pH.rows (R.pf.off 0 + 5)
        (R.pf.off 0 + 5 + 4 + mIn) csIO) G (A.runLog G).2 (R.tr G (A.run G))) :
    ∀ hdr core ch rs, StgRd key domain Lq
        (fun ch => (shdP_incV tag Rp embDigest embFold bInRow).bp
          (incCtx (shdP_incV tag Rp embDigest embFold bInRow).pub ch)) mIn (R.pf.off 0 + 5)
        (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) G (R.tr G (A.run G)) hdr core ch rs →
      ∑ j, (shdIncHd U tag h64 (shdP_incV tag Rp embDigest embFold bInRow).pub ogStage.lc ogStage.h ogStage.Q
        ogStage.e I.pH.rows (R.pf.off 0 + 5 + 4 + mIn)
        (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (R.tr G (A.run G)))).2.2 j = 0 := by
  intro hdr core ch rs hrd
  subst hDe
  have hAH := ssh_AHAtI U hbij tag h64 hs hL hL64 Lb preA preB start inc incG outc outcG Pk sgeom check paths digest
    bRows bLogN bndCheck bndOpen R hv cx0 pin pout I O bp wXk gXk mXk hσ hLb hgeo ogStage ogStage_ok le_rfl
    hIA hIH hOA hOH hBA hBH hfIA hfIH hfOA hfOH hfBA hfBH Win Wout lscIn lscOut mIn kIn kOut hlscIn hlscOut hmIn
    base rdx eL hD n hn A G hE hWin hWout hX hA csIO
  have hIO := ssh_iosOfIOC U key domain (inc (A.run G).1.hdr) mIn (R.pf.off 0 + 5)
    (R.pf.off 0 + pin.pre) (hmIn _) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
    (fun v k => StageV.incElog ((vdWin (shdP_incV tag Rp embDigest embFold bInRow))
        (v.2.take (R.pf.off 0 + pin.pre))).pub
      ((vdWin (shdP_incV tag Rp embDigest embFold bInRow)) (v.2.take (R.pf.off 0 + pin.pre))).geo.bLogN k)
    (fun v k => (congrArg (fun W : IncV => StageV.incElog W.pub W.geo.bLogN k) (hinc (A.run G).1.hdr)).symm)
    _ G _ _ (I.hgt _) (fun cx k hk => (I.hgeomL _ cx k hk).1)
    (fun cx => by rw [← I.hpre (A.run G).1.hdr cx, hmIn]; omega) hIOC
  have hM := ssh_MAtIO (U := U) (hbij := hbij) (tag := tag) (h64 := h64) (hs := hs) (hL := hL) (hL64 := hL64)
    (Lb := Lb) (preA := preA) (preB := preB) (start := start) (inc := inc) (incG := incG) (outc := outc)
    (outcG := outcG) (Pk := Pk) (sgeom := sgeom) (check := check) (paths := paths) (digest := digest)
    (bRows := bRows) (bLogN := bLogN) (bndCheck := bndCheck) (bndOpen := bndOpen) (R := R) (hv := hv) (cx0 := cx0)
    (pin := pin) (pout := pout) (I := I) (O := O) (bp := bp) (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ)
    (hLb := hLb) (hgeo := hgeo) (gS := ogStage) (htI := htI) (htO := htO) (htB := htB) (hfIM := hfIM)
    (hfOM := hfOM) (hfBM := hfBM) (Win := Win) (Wout := Wout) (lscIn := lscIn) (lscOut := lscOut) (mIn := mIn)
    (kIn := kIn) (kOut := kOut) (hmIn := hmIn) (hkIn := hkIn) (hkOut := hkOut) (base := base) (rdx := rdx)
    (eL := eL) (hD := hD) (n := n) (hn := hn) (A := A) (G := G) (hE := hE) (hWin := hWin) (hWout := hWout)
    (hX := hX) (hM := hMk)
  have htrue := ssh_trueAtC_of_split _ _ _ _ _ _ _ _ _ _ _ _ _ _ _
    (ssh_readI key domain inc (shdP_incV tag Rp embDigest embFold bInRow) hinc (A.run G).1.hdr _ _
      (R.pf.off 0 + pin.pre) _ _ _ _ _) hAH hIO hM.1
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  have hall := ssh_hDIC_all key domain hs Lq hL R.pf R.rd hL64 hv U hbij _ hD tag h64 hU n (by omega) (by omega)
    (fun ch => (inc (A.run G).1.hdr).bp (incCtx (inc (A.run G).1.hdr).pub ch))
    (shdP_P0in tag Rp embDigest embFold bInRow) (shdP_incV tag Rp embDigest embFold bInRow)
    (R.pf.off 0 + pin.pre) (R.pf.off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e I.pA.rows I.pH.rows pin.S
    csIO (fun ch => by rw [hinc]; exact shdP_hPin tag Rp embDigest embFold bInRow (A.run G).1.hdr _)
    (fun _ => I.hgt _) (fun _ k hk => (I.hgeomL _ _ k hk).1) (fun _ => stg_hhIn inc _ _)
    (shdP_hNin tag Rp embDigest embFold bInRow) (shdP_hN64I tag Rp embDigest embFold bInRow)
    hIOl
    G (A.runLog G).2 (R.tr G (A.run G)) hS hns htrue
  have hrd' : StgRd key domain Lq (fun ch => (inc (A.run G).1.hdr).bp (incCtx (inc (A.run G).1.hdr).pub ch)) mIn
      (R.pf.off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) G (R.tr G (A.run G)) hdr core ch rs := by
    rw [hinc]; exact hrd
  have h3 : 3 < (shdP_P0in tag Rp embDigest embFold bInRow).geom.slots.length := by
    rw [shdP_P0in_slots tag Rp embDigest embFold bInRow]; decide
  obtain ⟨r, hr, hlen, hΦ⟩ := hall hdr core ch rs hrd' 3 h3
  rw [hinc] at hΦ
  have hrl : 3 < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  exact shd_zs_of_phi U hbij tag h64 hU Rp embDigest embFold bInRow _ _ I.pA.rows I.pH.rows (R.pf.off 0 + 5)
    (R.pf.off 0 + 5 + 4 + mIn) csIO _ _ ((rs.take 3).map Block.SlotRec.draws)
    (by rw [List.length_map, List.length_take]; omega) r.draws hΦ

end Run

/-! ## 3. `hLI_stg`'s conclusion with the sum facts at the readings -/

section SumRd

variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K] {Lq : ℕ}

/-- **`shd_hLI_of_sum` with the two sum facts required only at the readings.** -/
theorem shd_hLI_of_rd (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0) (I : IncPub)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iB hdrLen rH iH : ℕ) (hB : iB < hdrLen + 4)
    (hv : I.v = P.V) (hV : P.V ≤ 2 ^ 17) (htok : I.tokens = 128)
    (hcq : ∀ t : shieldS0.Tok, I.ctlQ t.val = decide (ctlPos P t = 1))
    (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB Lq → Option (List UInt8))
    (G : QB Lq → Dig) (Lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hqt : ∀ hdr core ch rs, StgRd key domain Lq Pof 15 hdrLen bgaOf G τ hdr core ch rs →
      ch.length = 15
      ∧ QzcHolds (incQ (shdIncLay U tag h64 P I Epad iB hdrLen (stgVw absOf Lg τ) hv hV htok hcq) (incChalOf U ch)
          (shdIncHd U tag h64 I ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH (stgVw absOf Lg τ)))
        (incChalOf U ch).1.2 (incChalOf U ch).1.1.1
        ((shdIncLay U tag h64 P I Epad iB hdrLen (stgVw absOf Lg τ) hv hV htok hcq).g (incChalOf U ch))
        (shdIncLay U tag h64 P I Epad iB hdrLen (stgVw absOf Lg τ) hv hV htok hcq).bos
      ∧ TzcHolds (incT (shdIncLay U tag h64 P I Epad iB hdrLen (stgVw absOf Lg τ) hv hV htok hcq) (incChalOf U ch)
          (shdIncHd U tag h64 I ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH (stgVw absOf Lg τ))) (incChalOf U ch).1.2)
    (hsum : ∀ hdr core ch rs, StgRd key domain Lq Pof 15 hdrLen bgaOf G τ hdr core ch rs →
      ShdIncSumAt U tag h64 I rH iH (stgVw absOf Lg τ)) :
    StgLkAtV U key domain Pof 15 hdrLen bgaOf absOf (shd_ΛI U tag h64 P I Epad iB hdrLen) G Lg τ := by
  have hK : ShdLuInAtK U key domain Pof hdrLen bgaOf absOf (shdIncDataK U tag h64 P I Epad iB hdrLen) G Lg τ :=
    shdLuInAtK_of_slotsT U key domain Pof hdrLen bgaOf absOf (shdIncDataK U tag h64 P I Epad iB hdrLen)
      (stgVw absOf Lg τ) (shdIncLay U tag h64 P I Epad iB hdrLen (stgVw absOf Lg τ) hv hV htok hcq)
      (shdIncHd U tag h64 I ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH (stgVw absOf Lg τ)) G Lg τ
      (fun hdr core ch rs hrd => by
        obtain ⟨hl, hq, ht⟩ := hqt hdr core ch rs hrd
        exact ⟨hl, hq, ht, (hsum hdr core ch rs hrd).1, (hsum hdr core ch rs hrd).2⟩)
      (fun hdr core ch rs hrd =>
        shdIncDataK_head U tag h64 P I Epad iB hdrLen hB key domain Pof bgaOf absOf G Lg τ hdr core ch rs hrd)
  exact stgLkAtV_of_luIn U key domain Pof hdrLen bgaOf absOf (shdIncData U tag h64 P I Epad iB hdrLen) G Lg τ
    (shdLuInAt_of_K U tag h64 P I Epad iB hdrLen key domain Pof hdrLen bgaOf absOf G Lg τ hK)

end SumRd

section RunR

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)

/-- **`shd_hLI_run` with the two sum facts required only at the readings.** -/
theorem shd_hLI_runR (hU : U ^ 2 = algebraMap GF K 7) (n : ℕ) (hi : 0 < pf.parts.length) (hin : 0 < n)
    (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0) (P0 : Block.BlockParams) (Vi : IncV)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (n0 hdrLen iB rA rH rX : ℕ) (hB : iB < hdrLen + 4)
    (hrA : rA = 41) (hrX : rX = 38)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (hIOl : VwLoc (hdrLen + (7 + 15)) csIO)
    (hcsO : ∀ w z, csIO w .out z = claimSem U rX 14 256 (bxUxV tag Lq h64 rX iB w) z)
    (hIO1 : StgCsIODeg U hbij Vi.geo.bLogN (IncPrivIO1 Vi.pub) csIO)
    (hR : D.r0 0 = stgDefsV P0 15 hdrLen (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (sshΦIC U hbij tag h64 P0 Vi n0 hdrLen 15 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH csIO) sshDgI)
    (hP : ∀ ch, StgSame P0 (Vi.bp (incCtx Vi.pub ch)))
    (hgt : ∀ ch, (Vi.bp (incCtx Vi.pub ch)).geom.slots.length = (Vi.bp (incCtx Vi.pub ch)).geom.terms.length)
    (hgeom : ∀ ch k, k < (Vi.bp (incCtx Vi.pub ch)).geom.slots.length →
      1 ≤ (Block.slotShape (Vi.bp (incCtx Vi.pub ch)) k).2.2)
    (hsl : 3 ≤ P0.geom.slots.length) (hd1 : 0 < P0.draws 1) (hd2 : 0 < P0.draws 2)
    (hti : Vi.pub.tiLog = 12) (hvoc : Vi.pub.vocLog = 17) (htB : Vi.pub.tBits = 7) (hbIn : Vi.pub.bInLog = 19)
    (hGb : Vi.geo.bLogN = 14) (hlt : Vi.pub.lt ≤ ogStage.lc) (hlc : ∀ cx, 0 < (Vi.bp cx).logCols)
    (hbos : Vi.pub.bos < 2 ^ 63) (hkap : ∀ t, Vi.pub.kappa t < 2 ^ 63)
    (hns : Vi.pub.numSpecial = P.ns) (hVV : P.V = 131072)
    (hEmb : ∀ rEmb : List Fp2, rEmb.length = 12 → (∀ a ∈ rEmb, a.Canon) → ∀ v : Fin P.V,
      ((Vi.pub.embFold rEmb).getD v Fp2.zero).toK U
        = mleAt (fun c => algebraMap GF K (Epad v c)) (fun c : Fin 12 => (rEmb.getD c Fp2.zero).toK U))
    (hvP : Vi.pub.v = P.V) (hV : P.V ≤ 2 ^ 17) (htok : Vi.pub.tokens = 128)
    (hcq : ∀ t : shieldS0.Tok, Vi.pub.ctlQ t.val = decide (ctlPos P t = 1))
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hno : ¬ (rtKR0 key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ)
    (hsum : ∀ hdr core ch rs, StgRd key domain Lq (fun ch => Vi.bp (incCtx Vi.pub ch)) 15 hdrLen
        (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) G τ hdr core ch rs →
      ShdIncSumAt U tag h64 Vi.pub rH (hdrLen + 4 + 15)
        (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ)) :
    StgLkAtV U key domain (fun ch => Vi.bp (incCtx Vi.pub ch)) 15 hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero))
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (shd_ΛI U tag h64 P Vi.pub Epad iB hdrLen) G lg τ :=
  shd_hLI_of_rd U tag h64 P Vi.pub Epad iB hdrLen rH (hdrLen + 4 + 15) hB hvP hV htok hcq key domain
    (fun ch => Vi.bp (incCtx Vi.pub ch)) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero))
    (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) G lg τ
    (shd_inc_qt_run key domain hs Lq hL pf rd hL64 hv U hbij D hD hU n hi hin tag h64 P P0 Vi Epad n0 hdrLen iB rA rH
      rX hrA hrX csIO hIOl hcsO hIO1 hR hP hgt hgeom hsl hd1 hd2 hti hvoc htB hbIn hGb hlt hlc hbos hkap hns hVV hEmb
      hvP hV htok hcq G lg τ hno) hsum

end RunR

end ZK60.ProtocolClassify
