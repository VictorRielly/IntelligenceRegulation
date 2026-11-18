/-
D63 lane L63 (2026-11-18), part 66: **the `H` opening's value-0 LogUp sum claim gives `IncSum`** (item 4b, step 1,
the first of `ShdIncSumAt`'s two facts).

* `zcB_leftW`, `zcB_rightW`, `core_rowKeyW`, **`sum_planeZ2W`**: lane L47's `core_rowKey`, `sum_planeZ2`
  (BlockLookSum.lean, rows of `2^14`) at any row width `w` (here `2^12`, stage IN-C's `H_in`), the same proofs;
* `kI_one_toK`, `kI_negOne_toK`; **`shd_lsc_sem`**: `logup_sum_claim` of stage IN-C's layout on a matrix is
  `Σ h_q − Σ h_tab + Σ u` of the three `H` planes (lane L47's `claimSem_empty`);
* **`shd_incSum_of_lsc`**: if that claim's value is `0` at `shdIncHd`'s matrix, `IncSum` holds there;
* **`ssh_run_lscI`**: on an accepted run outside `EvXR` with no doomed `opA` entrant, part `0`'s `H` opening makes
  its LogUp sum claim `lscIn` true of its decoded matrix (lane L46's `wr_rkOpen_sem` at the claim list's last entry;
  `ssh_run_AHI`'s proof);
* **`shd_incSum_run`**: with `D = ebData …` (`hDe`), `IncSum` of `shdIncHd` at the run's whole view.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIncNum
import ZK60Formal.RunStgShieldInAHRun
import ZK60Formal.BlockLookSum

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.Exec.Block.Join.W16.Look

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Circuit (gP GF)

section PlaneW

variable {K : Type} [Field K] [Algebra GF K] (U : K)

omit [Algebra GF K] in
theorem zcB_leftW (m w : ℕ) (x : Fin m → Bool) (y : Fin w → Bool) (a : Fin m) :
    zcB (K := K) (Fin.append x y) (a : ℕ) = bit (x a) := by
  unfold zcB
  have h : (a : ℕ) < m + w := by omega
  simp only [h, ↓reduceDIte]
  exact congrArg bit (Fin.append_left x y a)

omit [Algebra GF K] in
theorem zcB_rightW (m w : ℕ) (x : Fin m → Bool) (y : Fin w → Bool) (a : Fin w) :
    zcB (K := K) (Fin.append x y) (m + (a : ℕ)) = bit (y a) := by
  unfold zcB
  have h : m + (a : ℕ) < m + w := by omega
  simp only [h, ↓reduceDIte]
  exact congrArg bit (Fin.append_right x y a)

omit [Algebra GF K] in
/-- `core_rowKey` at rows of `2^w`. -/
theorem core_rowKeyW (w m off off' i t : ℕ) :
    ∑ c : Fin (m + w) → Bool,
        partRowK w off (m + w) (fun a => if h : a < m + w then (bit (c ⟨a, h⟩) : K) else 0) i
          * keyColK w off' (m + w) (fun a => if h : a < m + w then (bit (c ⟨a, h⟩) : K) else 0) t
      = inRows w off (m + w) i := by
  show ∑ c : Fin (m + w) → Bool, partRowK w off (m + w) (zcB (K := K) c) i * keyColK w off' (m + w) (zcB c) t
    = inRows w off (m + w) i
  have e : m + w - w = m := by omega
  unfold partRowK keyColK inRows
  rw [e]
  simp only [show w ≤ m + w by omega, ↓reduceIte]
  rw [sum_append (a := m) (b := w)]
  have hrow : ∀ (x : Fin m → Bool) (y : Fin w → Bool) (u : ℕ),
      eqPoly (fun a : Fin m => zcB (K := K) (Fin.append x y) (a : ℕ)) (bitsK m u)
        = if x = msbBits m u then 1 else 0 := by
    intro x y u
    have hz : (fun a : Fin m => zcB (K := K) (Fin.append x y) (a : ℕ)) = fun a => bit (x a) :=
      funext fun a => zcB_leftW m w x y a
    rw [hz]
    exact eqPoly_bit x (msbBits m u)
  have hcol : ∀ (x : Fin m → Bool) (y : Fin w → Bool),
      eqPoly (fun a : Fin w => zcB (K := K) (Fin.append x y) (m + (a : ℕ))) (bitsK w t)
        = if y = msbBits w t then 1 else 0 := by
    intro x y
    have hz : (fun a : Fin w => zcB (K := K) (Fin.append x y) (m + (a : ℕ))) = fun a => bit (y a) :=
      funext fun a => zcB_rightW m w x y a
    rw [hz]
    exact eqPoly_bit y (msbBits w t)
  by_cases hc : off / 2 ^ w ≤ i ∧ i < off / 2 ^ w + 2 ^ m
  · simp only [hc, and_self, ↓reduceIte, hrow, hcol]
    rw [Finset.sum_eq_single (msbBits m (i - off / 2 ^ w))
      (fun x _ hx => by simp only [hx, ↓reduceIte, zero_mul, Finset.sum_const_zero])
      (fun h => absurd (Finset.mem_univ _) h)]
    simp
  · simp only [hc, ↓reduceIte, zero_mul, Finset.sum_const_zero]

/-- **`sum_planeZ2` at rows of `2^w`**: an `H` plane's sum over its cube (`re + u·im`, slices at least a row wide). -/
theorem sum_planeZ2W (w logN R Q : ℕ) (hln : logN = w) (X : Fin R → Fin (2 ^ logN + Q) → K) (cm : Cm)
    (re im log : ℕ) (hlog : w ≤ log) (coords : List Coord) (mr er : ℕ) :
    ∑ c : Fin log → Bool, planeZ U logN R Q X ⟨cm, [(re, Fp2.one), (im, fp2U)], log, coords, mr, er⟩ c
      = ∑ i : Fin R, (inRows logN re log i + fp2U.toK U * inRows logN im log i) * rowS logN R Q X i := by
  subst hln
  obtain ⟨m, rfl⟩ : ∃ m, log = m + logN := ⟨log - logN, by omega⟩
  unfold planeZ privZ
  simp only [List.map_cons, List.map_nil, claimK, List.sum_cons, List.sum_nil, add_zero, Fp2.toK_one, one_mul]
  rw [Finset.sum_comm]
  refine Finset.sum_congr rfl (fun i _ => ?_)
  unfold rowS
  rw [Finset.mul_sum]
  simp only [Finset.mul_sum]
  rw [Finset.sum_comm]
  refine Finset.sum_congr rfl (fun t _ => ?_)
  by_cases ht : (t : ℕ) < 2 ^ logN
  · simp only [ht, ↓reduceIte, mul_one]
    rw [sum_lin2, core_rowKeyW logN m re re i t, core_rowKeyW logN m im re i t]
    ring
  · simp only [ht, ↓reduceIte, mul_zero, Finset.sum_const_zero]

end PlaneW

end ZK60.Exec.Block.Join.W16.Look

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)

section Lsc

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem kI_one_toK : (kI 1).toK U = 1 := by
  unfold kI
  rw [Fp2.toK_fromBase, Fp.toGF_fromI64 _ (by norm_num) (by norm_num)]
  simp

theorem kI_negOne_toK : (kI (-1)).toK U = -1 := by
  unfold kI
  rw [Fp2.toK_fromBase, Fp.toGF_fromI64 _ (by norm_num) (by norm_num)]
  simp

/-- **Stage IN-C's `logup_sum_claim` on a matrix is `Σ h_q − Σ h_tab + Σ u`** of the three `H` planes (rows of
`2^12`, the registered logs `12, 17, 12`). -/
theorem shd_lsc_sem (hU : U ^ 2 = algebraMap GF K 7) (I : IncPub) (hti : I.tiLog = 12) (hvoc : I.vocLog = 17)
    (hlt : I.lt = 12) (logN R Q : ℕ) (hln : logN = 12) (X : Fin R → Fin (2 ^ logN + Q) → K) :
    claimSem U R logN Q X (incLay I 14).logupSumClaim
      = (∑ b : Fin 12 → Bool, Block.Join.planeZ U logN R Q X
          ⟨.h, [(((incLay I 14).hOff incH_Q).1, Fp2.one), (((incLay I 14).hOff incH_Q).2, Block.fp2U)], 12, [], 0, 0⟩
            b)
        - (∑ c : Fin 17 → Bool, Block.Join.planeZ U logN R Q X
          ⟨.h, [(((incLay I 14).hOff incH_TAB).1, Fp2.one), (((incLay I 14).hOff incH_TAB).2, Block.fp2U)], 17, [],
            0, 0⟩ c)
        + (∑ j : Fin 12 → Bool, Block.Join.planeZ U logN R Q X
          ⟨.h, [(((incLay I 14).hOff incH_U).1, Fp2.one), (((incLay I 14).hOff incH_U).2, Block.fp2U)], 12, [], 0, 0⟩
            j) := by
  have hz : (incLay I 14).logupSumClaim.parts =
      [⟨((incLay I 14).hOff 0).1, I.tiLog, kI 1, []⟩, ⟨((incLay I 14).hOff 0).2, I.tiLog, (kI 1).mul Block.fp2U, []⟩,
       ⟨((incLay I 14).hOff 1).1, I.vocLog, kI (-1), []⟩,
       ⟨((incLay I 14).hOff 1).2, I.vocLog, (kI (-1)).mul Block.fp2U, []⟩,
       ⟨((incLay I 14).hOff 2).1, I.lt, kI 1, []⟩, ⟨((incLay I 14).hOff 2).2, I.lt, (kI 1).mul Block.fp2U, []⟩] := rfl
  have he : Block.Join.W16.Look.EmptyParts logN (incLay I 14).logupSumClaim := by
    intro q hq
    rw [hz] at hq
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hq
    rcases hq with rfl | rfl | rfl | rfl | rfl | rfl
    · exact ⟨rfl, by show logN ≤ I.tiLog; omega, kI_canon _⟩
    · exact ⟨rfl, by show logN ≤ I.tiLog; omega, Fp2.canon_mul _ _⟩
    · exact ⟨rfl, by show logN ≤ I.vocLog; omega, kI_canon _⟩
    · exact ⟨rfl, by show logN ≤ I.vocLog; omega, Fp2.canon_mul _ _⟩
    · exact ⟨rfl, by show logN ≤ I.lt; omega, kI_canon _⟩
    · exact ⟨rfl, by show logN ≤ I.lt; omega, Fp2.canon_mul _ _⟩
  rw [Block.Join.W16.Look.claimSem_empty U R logN Q X _ _ _ hz he, hz]
  rw [Block.Join.W16.Look.sum_planeZ2W U 12 logN R Q hln X .h _ _ 12 le_rfl [] 0 0,
    Block.Join.W16.Look.sum_planeZ2W U 12 logN R Q hln X .h _ _ 17 (by norm_num) [] 0 0,
    Block.Join.W16.Look.sum_planeZ2W U 12 logN R Q hln X .h _ _ 12 le_rfl [] 0 0]
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, Fp2.toK_mul U hU, kI_one_toK,
    kI_negOne_toK, hti, hvoc, hlt, incH_Q, incH_TAB, incH_U]
  simp only [add_mul, Finset.sum_add_distrib, mul_assoc, ← Finset.mul_sum]
  show _ = _ - _ + _
  ring

end Lsc

section IncSumV

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- **`IncSum` from the `H` opening's value-0 LogUp sum claim** at `shdIncHd`'s matrix. -/
theorem shd_incSum_of_lsc (hU : U ^ 2 = algebraMap GF K 7) (I : IncPub) (hti : I.tiLog = 12)
    (hvoc : I.vocLog = 17) (hlt : I.lt = 12) (rH iH : ℕ) (w : StgVw Lq)
    (h : claimSem U rH ogStage.lc ogStage.Q (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w)
      (incLay I 14).logupSumClaim = 0) :
    IncSum (shdIncHd U tag h64 I ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w) := by
  rw [shd_lsc_sem U hU I hti hvoc hlt ogStage.lc rH ogStage.Q rfl] at h
  exact h

end IncSumV

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

/-- **PART `0`'S `H` OPENING MAKES ITS LOGUP SUM CLAIM TRUE** of its decoded extracted matrix, on an accepted run
outside `EvXR` with no doomed `opA` entrant (`ssh_run_AHI`'s proof, at the claim list's last entry). -/
theorem ssh_run_lscI
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
    claimSem U I.pH.rows gS.lc gS.Q (decodeRows (encGL (K := K) gS.lc gS.h gS.Q) gS.e (UxC tag Lq h64 gS.h I.pH.rows
        (Block.cutO (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
          (Block.absAt ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).oH))
            (R.pf.off 0 + (5 + (4 + mIn)))) (A.runLog G).2)
        (Block.absAt ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).oH))
          (R.pf.off 0 + (5 + (4 + mIn)))))) lscIn = lscIn.value.toK U := by
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  have hi : 0 < R.pf.parts.length := by omega
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
    (hX := hX) (i := 0) (hi := hi) (hIA := hIA) (hIH := hIH) (hOA := hOA) (hOH := hOH) (hBA := hBA) (hBH := hBH)
    (hfIA := hfIA) (hfIH := hfIH) (hfOA := hfOA) (hfOH := hfOH) (hfBA := hfBA) (hfBH := hfBH) (lscIn := lscIn)
    (lscOut := lscOut) (hlscIn := hlscIn) (hlscOut := hlscOut) (hmIn := hmIn) (ps := _) (hps := rfl) (lsc := _)
    (hlsc := rfl)
  have ndA := wr_ndA key domain hs Lq hL R.pf R.rd hL64 hv U hbij _ hD n (A.runLog G).2 (R.tr G (A.run G)) hA 0
    hi hn
  have sH := wr_rkOpen_sem U hbij tag Lq h64 key domain hs hL
    ((rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
      (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
      (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH)) 0).gH
    ((rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
      (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
      (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH)) 0).nH
    (fun hdr => (rxAcc Win Wout Pk R.pf Lb 0 hdr).claims.h ++ [rxLsc lscIn lscOut Pk Lb 0]) _
    (rtW R.pf.sqs) _ (A.runLog G).2 (R.tr G (A.run G))
    (ndA _ (List.mem_cons_of_mem _ List.mem_cons_self)) (hlen _ oH.hpl) oH.hpre
    (by have h := oH.hcnt; rw [← oH.hrd] at h; exact h)
  have hv := sH (rxLsc lscIn lscOut Pk Lb 0) (List.mem_append_right _ List.mem_cons_self)
  simp only [wrOSem, rkOpen, UxW_eq_cut] at hv
  exact hv

/-- **`IncSum` AT THE RUN'S WHOLE VIEW**: with the run's kinds data `D = ebData …` (`hDe`), on an accepted run outside
`EvXR` with no doomed `opA` entrant, at stage IN-C's registered logs (`hti`, `hvoc`, `hlt`, `hbL`). -/
theorem shd_incSum_run
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
    (hU : U ^ 2 = algebraMap GF K 7) (hbL : (inc (A.run G).1.hdr).geo.bLogN = 14)
    (hti : (inc (A.run G).1.hdr).pub.tiLog = 12) (hvoc : (inc (A.run G).1.hdr).pub.vocLog = 17)
    (hlt : (inc (A.run G).1.hdr).pub.lt = 12) :
    IncSum (shdIncHd U tag h64 (inc (A.run G).1.hdr).pub ogStage.lc ogStage.h ogStage.Q ogStage.e I.pH.rows
      (R.pf.off 0 + 5 + 4 + mIn) (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2
        (R.tr G (A.run G)))) := by
  subst hDe
  have h := ssh_run_lscI U hbij tag h64 hs hL hL64 Lb preA preB start inc incG outc outcG Pk sgeom check paths digest
    bRows bLogN bndCheck bndOpen R hv cx0 pin pout I O bp wXk gXk mXk hσ hLb hgeo ogStage ogStage_ok le_rfl
    hIA hIH hOA hOH hBA hBH hfIA hfIH hfOA hfOH hfBA hfBH Win Wout lscIn lscOut mIn kIn kOut hlscIn hlscOut hmIn
    base rdx eL hD n hn A G hE hWin hWout hX hA
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  have hσ0 : R.σs[0]? = some (rtIncSeg inc incG cx0 pin) := by rw [hσ]; rfl
  have hp0 : R.pf.part 0 = pin := rx_part_of R 0 _ hσ0
  have hH : R.pf.off 0 + (5 + (4 + mIn)) < R.pf.off 0 + (R.pf.part 0).oH := by
    have hpre0 := I.hpre (A.run G).1.hdr cx0
    rw [hmIn] at hpre0
    rw [hp0]
    simp only [RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  rw [ssh_absAt_take _ _ _ hH] at h
  rw [← hlscIn (A.run G).1.hdr] at h
  have hz : ((inc (A.run G).1.hdr).lay.logupSumClaim.value).toK U = 0 := Fp2.toK_zero U
  rw [hz] at h
  have e : (inc (A.run G).1.hdr).lay = incLay (inc (A.run G).1.hdr).pub 14 := by
    show incLay (inc (A.run G).1.hdr).pub (inc (A.run G).1.hdr).geo.bLogN = _
    rw [hbL]
  rw [e] at h
  refine shd_incSum_of_lsc U tag h64 hU _ hti hvoc hlt I.pH.rows (R.pf.off 0 + 5 + 4 + mIn) _ ?_
  rw [show R.pf.off 0 + 5 + 4 + mIn = R.pf.off 0 + (5 + (4 + mIn)) by omega]
  exact h

end Run

end ZK60.ProtocolClassify
