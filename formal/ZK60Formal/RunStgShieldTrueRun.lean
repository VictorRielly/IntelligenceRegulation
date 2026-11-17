/-
D63 lane L63 (2026-11-16), part 7: **`StgMAt` at both stages on an accepted run** (item (ii)).

* **`ssh_MAtIO`**: on an accepted run outside the run's Merkle event `EvXR`, with no doomed `M` entrant, the corrected
  `M` part (`fs ++ hostFs`) holds at every reading of stage IN-C and of stage OUT-C, over the view's extracted mask
  table (`stgMsv`, as the top theorem's `hTrI`, `hTrO`, `hHostO` state it).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldTrue

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx incCtx)
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

/-- **THE CORRECTED `M` PART AT BOTH STAGES, ON AN ACCEPTED RUN** outside `EvXR` with no doomed `M` entrant. -/
theorem ssh_MAtIO
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
    (hLb : Lb ≤ 26) (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom) (gS : OGeo)
    (htI : I.tag = tag) (htO : O.tag = tag) (htB : ∀ k, (bp k).tag = tag)
    (hfIM : 8 * (2 * pin.S + 4) ≤ Lq) (hfOM : 8 * (2 * pout.S + 4) ≤ Lq) (hfBM : ∀ k, 8 * (2 * (bp k).S + 4) ≤ Lq)
    (Win : List (TItem × Dig) → IncV) (Wout : List (TItem × Dig) → OutcV) (lscIn lscOut : Block.ZClaim)
    (mIn kIn kOut : ℕ) (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn) (hkIn : ∀ hd, (inc hd).lay.nFunctionals = kIn)
    (hkOut : ∀ hd v, (outc hd v).lay.nFunctionals = kOut)
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
    (hM : ¬ (rtKM key domain hs Lq hL R.pf R.rd hL64 hv U hbij _ hD).Dm n (A.runLog G).2 (R.tr G (A.run G))) :
    StgMAt U key domain (fun ch => (inc (A.run G).1.hdr).bp (incCtx (inc (A.run G).1.hdr).pub ch)) mIn
        (R.pf.off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (stgMsv U tag h64 pin.S (R.pf.off 0 + 5 + 3)) G (A.runLog G).2 (R.tr G (A.run G))
      ∧ StgMAt U key domain (fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp) 2 (R.pf.off (Lb + 1) + 2)
        OutcV.bga (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (stgMsv U tag h64 pout.S (R.pf.off (Lb + 1) + 2 + 3)) G (A.runLog G).2 (R.tr G (A.run G)) := by
  obtain ⟨h0, h1⟩ := ssh_run_M (U := U) (hbij := hbij) (tag := tag) (h64 := h64) (hs := hs) (hL := hL)
    (hL64 := hL64) (Lb := Lb) (preA := preA) (preB := preB) (start := start) (inc := inc) (incG := incG)
    (outc := outc) (outcG := outcG) (Pk := Pk) (sgeom := sgeom) (check := check) (paths := paths) (digest := digest)
    (bRows := bRows) (bLogN := bLogN) (bndCheck := bndCheck) (bndOpen := bndOpen) (R := R) (hv := hv) (cx0 := cx0)
    (pin := pin) (pout := pout) (I := I) (O := O) (bp := bp) (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ)
    (hLb := hLb) (hgeo := hgeo) (gS := gS) (htI := htI) (htO := htO) (htB := htB) (hfIM := hfIM) (hfOM := hfOM)
    (hfBM := hfBM) (Win := Win) (Wout := Wout) (lscIn := lscIn) (lscOut := lscOut) (mIn := mIn) (kIn := kIn)
    (kOut := kOut) (hkIn := hkIn) (hkOut := hkOut) (base := base) (rdx := rdx) (eL := eL) (hD := hD) (n := n)
    (hn := hn) (A := A) (G := G) (hE := hE) (hWin := hWin) (hWout := hWout) (hX := hX) (hM := hM)
  have hσ0 : R.σs[0]? = some (rtIncSeg inc incG cx0 pin) := by rw [hσ]; rfl
  have hp0 : R.pf.part 0 = pin := rx_part_of R 0 _ hσ0
  have hσo : R.σs[Lb + 1]? = some (rtOutcSeg outc outcG pout) := by
    rw [hσ]
    exact rx_getOut _ _ _ _
  have hpo : R.pf.part (Lb + 1) = pout := rx_part_of R (Lb + 1) _ hσo
  refine ⟨?_, ?_⟩
  · refine ssh_MAt U tag h64 key domain hs hL _ mIn (R.pf.off 0 + 5) _ pin.S (R.pf.off 0 + (5 + 3))
      (R.pf.off 0 + (R.pf.part 0).pre) (rxAcc Win Wout Pk R.pf Lb 0) G (A.runLog G).2 (R.tr G (A.run G))
      (fun _ => I.hgt _) (by omega) ?_ h0 ?_
    · rw [hp0, ← I.hpre (A.run G).1.hdr cx0]
      omega
    · intro hdr core ch rs hrd acc t' hacc
      have e1 : rxAcc Win Wout Pk R.pf Lb 0 ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).pre))
          = rsAccInc (inc (A.run G).1.hdr) (R.pf.off 0 + 5)
            ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).pre)) := by
        show rsAccInc (Win (((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).pre)).take
            (R.pf.off 0 + (R.pf.part 0).pre))) (R.pf.off 0 + 5)
            (((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).pre)).take (R.pf.off 0 + (R.pf.part 0).pre)) = _
        rw [List.take_take, min_self, hp0, hWin]
      rw [e1]
      exact ssh_inc_link key domain (inc (A.run G).1.hdr) mIn (R.pf.off 0 + 5) _ (hmIn _) G _ hdr core ch rs hrd
        (I.hgt _) (fun cx k hk => (I.hgeomL _ cx k hk).1)
        (fun cx => by rw [hp0, ← I.hpre (A.run G).1.hdr cx, hmIn]; omega) acc t' hacc
  · refine ssh_MAt U tag h64 key domain hs hL _ 2 (R.pf.off (Lb + 1) + 2) _ pout.S (R.pf.off (Lb + 1) + (2 + 3))
      (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).pre) (rxAcc Win Wout Pk R.pf Lb (Lb + 1)) G (A.runLog G).2
      (R.tr G (A.run G)) (fun _ => O.hgt _ _) (by omega) ?_ h1 ?_
    · rw [hpo, ← O.hpre (A.run G).1.hdr (A.run G).1.verdict]
      omega
    · intro hdr core ch rs hrd acc t' hacc
      have hg : (outc (A.run G).1.hdr (A.run G).1.verdict).bp.geom = (outc (A.run G).1.hdr (A.run G).1.verdict).geom :=
        rfl
      have e1 : rxAcc Win Wout Pk R.pf Lb (Lb + 1)
            ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).pre))
          = rsAccS (outc (A.run G).1.hdr (A.run G).1.verdict).bp 2 OutcV.bga (R.pf.off (Lb + 1) + 2)
            ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).pre)) := by
        rw [rxAcc_out]
        show rsAccS (Wout (((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).pre)).take
            (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).pre))).bp 2 OutcV.bga (R.pf.off (Lb + 1) + 2)
            (((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).pre)).take
              (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).pre)) = _
        rw [List.take_take, min_self, hpo, hWout]
      rw [e1, ssh_outc_link key domain _ (R.pf.off (Lb + 1) + 2) _ G _ hdr core ch rs hrd (O.hgt _ _)
        (fun k hk => (O.hgeomL _ _ k hk).1)
        (by rw [hpo, ← O.hpre (A.run G).1.hdr (A.run G).1.verdict, hg]; omega) acc t' hacc]
      exact ⟨rfl, rfl⟩

end Run

end ZK60.ProtocolClassify
