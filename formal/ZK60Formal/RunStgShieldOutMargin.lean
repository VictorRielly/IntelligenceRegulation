/-
D63 lane L63 (2026-11-20), L63 leg 14, part 93: **OUT-C's verdict margin in the base field** (item 4 of
HANDOFF_20261119_3.md section 6, second half: `OutCFacts`' last conjunct, through `margin_host_pd`).

From LZC's define polynomial vanishing at every draw (`outc_lzc_host`, `outc_lzc_cube`, `outc_pd_cube`): the public
tables `wTab`, `gTab`, `supp_1` read at the twelve-bit cube are `margin_host_pd`'s `Wd`, `Gm`, `u0`, at the live channels
`dpos i = msbBits 12 i`, the margin limbs `mpos j = msbBits 12 (32 + j)` and `To`'s entry `z0 = msbBits 12 0`, once the
public constants are in the code's `i64` range (`OutCPublic.Valid` gives them, and `b ≤ 1`).

* `msbBits12_eq_of`, `wTab_getD_toK`, `gTab_getD_toK`, `kc_toK`;
* **`outc_margin`**: `sigOf b · limbSum ml + (b + c) = Σ_i y_i · w_Δ(i)` with `y_i` the `A_out` plane `Y` at
  `msbBits 12 i` and `ml_j` the limb plane at `msbBits 12 (32 + j)`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutLzcH

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.Out (OutCPublic sigOf)

section Tabs

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem msbBits12_eq_of (a b : ℕ) (ha : a < 4096) (hb : b < 4096) (h : msbBits 12 a = msbBits 12 b) : a = b := by
  have e := congrArg (msbIndex 12) h
  rwa [msbIndex_msbBits 12 a (lt_of_lt_of_eq ha (by norm_num)),
    msbIndex_msbBits 12 b (lt_of_lt_of_eq hb (by norm_num))] at e

/-- `wTab`'s entry `i` in `K`. -/
theorem wTab_getD_toK (dpad : ℕ) (wl : List ℤ) (i : ℕ) (hi : i < dpad)
    (hb : i < wl.length → -2 ^ 64 < wl.getD i 0 ∧ wl.getD i 0 < 2 ^ 64) :
    ((wTab dpad wl).getD i Fp2.zero).toK U = if i < wl.length then ((wl.getD i 0 : ℤ) : K) else 0 := by
  unfold wTab
  rw [rangeMap_getD _ _ hi]
  by_cases h : i < wl.length
  · rw [ite_eq_left h, ite_eq_left h]
    exact kI_int_toK U _ (hb h).1 (hb h).2
  · rw [ite_eq_right h, ite_eq_right h]
    exact Fp2.toK_zero U

/-- `gTab`'s entry `z` in `K` (`2^(8·j)` within the code's range: `l ≤ 7`). -/
theorem gTab_getD_toK (hU : U ^ 2 = algebraMap GF K 7) (size lam l verdict z : ℕ) (hz : z < size) (hl : l ≤ 7) :
    ((gTab size lam l verdict).getD z Fp2.zero).toK U
      = if lam ≤ z ∧ z < lam + l then algebraMap GF K (sigOf verdict * (2 : GF) ^ (8 * (z - lam))) else 0 := by
  unfold gTab
  simp only []
  rw [rangeMap_getD _ _ hz]
  by_cases h : lam ≤ z ∧ z < lam + l
  · rw [ite_eq_left h, ite_eq_left h, Fp2.toK_mul U hU]
    have hm : 8 * (z - lam) ≤ 48 := by omega
    have hp : (2 : ℤ) ^ (8 * (z - lam)) ≤ 2 ^ 48 := pow_le_pow_right₀ (by norm_num) hm
    rw [kI_int_toK U _ (by have : (0 : ℤ) < 2 ^ (8 * (z - lam)) := by positivity
                           linarith) (by linarith)]
    by_cases hv : verdict = 1
    · simp [hv, sigOf, Fp2.toK_one, map_ofNat]
    · rw [ite_eq_right hv, Fp2.toK_neg U _ Fp2.canon_one, Fp2.toK_one]
      simp [hv, sigOf, map_ofNat]
  · rw [ite_eq_right h, ite_eq_right h]
    exact Fp2.toK_zero U

/-- LZC's host constant `b + c` in `K`. -/
theorem kc_toK (b : ℕ) (c : ℤ) (hb : b ≤ 1) (hc : |c| ≤ 2 ^ 33) :
    ((kI (b : ℤ)).add (kI c)).toK U = algebraMap GF K ((b : GF) + (c : GF)) := by
  have hc' := abs_le.mp hc
  rw [Fp2.toK_add U _ _ (kI_canon _) (kI_canon _), kI_nat_toK U b (by omega),
    kI_int_toK U c (by linarith) (by linarith), map_add, map_natCast, map_intCast]

end Tabs

section Margin

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- **OUT-C'S VERDICT MARGIN IN THE BASE FIELD**, from LZC's define polynomial vanishing at every draw. -/
theorem outc_margin (hU : U ^ 2 = algebraMap GF K 7) (O : OutcPub) (P0 : Block.BlockParams) (Vo : OutcV)
    (hP : StgSame P0 Vo.bp) (ch : List Fp2) (hch : ∀ a ∈ ch, a.Canon) (rA rH iA iH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (w : StgVw Lq)
    (hlt : Vo.pub.lt ≤ ogStage.lc) (hd : List (List Fp2)) (hhd : hd.length = 4)
    (hzero : ∀ y : Fin (P0.draws 4) → K, stgΦB U hbij P0 Vo.bp
      (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w)
      (OutcV.bga ch) hd 4 (stgWords U hbij y) = 0)
    (hGb : Vo.geo.bLogN = 14) (hOL : outcLay Vo.pub 14 = outcLay O 14) (hllo : Vo.pub.llo = 12)
    (hldo : Vo.pub.ldo = 12) (hdB : Vo.pub.dBits = 12) (hlift : Vo.pub.lift = 0) (hdPad : Vo.pub.dPad = 4096)
    (hlc : 0 < Vo.bp.logCols)
    {d : ℕ} (P : OutCPublic d) (b : ℕ) (hb : b ≤ 1) (hverd : Vo.pub.verdict = b) (hcc : Vo.pub.c = P.c)
    (hcb : |P.c| ≤ 2 ^ 33) (hlim : Vo.pub.limbs = P.limbs) (hlim7 : P.limbs ≤ 7) (hdd : Vo.pub.d = d)
    (hd4 : d ≤ 4096) (hwl : d ≤ Vo.pub.wDelta.length) (hwD : ∀ i : Fin d, Vo.pub.wDelta.getD i.val 0 = P.wΔ i)
    (hwb : ∀ i, |P.wΔ i| ≤ 32767) :
    sigOf b * limbSum (fun j : Fin P.limbs => stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA
        ((outcLay O 14).aOff ocC_LIMB) 12 w (msbBits 12 (32 + j.val)))
      + ((b : GF) + (P.c : GF))
      = ∑ i : Fin d, stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA ((outcLay O 14).aOff ocC_Y) 12 w
          (msbBits 12 i.val) * (P.wΔ i : GF) := by
  have h1 := outc_lzc_host U hbij hU tag h64 P0 Vo hP ch hch ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO
    w hlt hd hhd hzero
  rw [outc_lzc_cube U hbij tag h64 hU O P0 Vo hP rA rH iA iH csIO w hGb hOL hllo hlc,
    outc_pd_cube U hbij tag h64 hU O P0 Vo hP rA rH iA iH csIO w hlt (OutcV.bga ch) hd hGb hOL hldo hdB hlift hdPad
      hlc] at h1
  rw [hverd, hcc, kc_toK U b P.c hb hcb, hlim] at h1
  -- the positions
  have hdinj : Function.Injective (fun i : Fin d => msbBits 12 i.val) := fun a a' h =>
    Fin.ext (msbBits12_eq_of a.val a'.val (by omega) (by omega) h)
  have hminj : Function.Injective (fun j : Fin P.limbs => msbBits 12 (32 + j.val)) := fun a a' h =>
    Fin.ext (by have := msbBits12_eq_of (32 + a.val) (32 + a'.val) (by omega) (by omega) h; omega)
  have htl : (Vo.pub.wDelta.take Vo.pub.d).length = d := by
    rw [List.length_take, hdd]; omega
  refine ZK60.StageX.margin_host_pd (algebraMap GF K) b P.c
    (fun i : Fin d => stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA ((outcLay O 14).aOff ocC_Y) 12 w
      (msbBits 12 i.val)) P.wΔ (fun i : Fin d => msbBits 12 i.val) hdinj
    (fun c => shdOutcA U tag h64 O rA iA ocC_Y w c)
    (fun c => ((wTab Vo.pub.dPad (Vo.pub.wDelta.take Vo.pub.d)).getD (msbIndex 12 c) Fp2.zero).toK U)
    (fun i => shdOutcA_alg U tag h64 O rA iA ocC_Y w _) (fun i => ?_) (fun x hx => ?_)
    (fun j : Fin P.limbs => msbBits 12 (32 + j.val)) hminj (msbBits 12 0)
    (fun z => ((gTab (2 ^ 12) OutcPub.lamBase P.limbs b).getD (msbIndex 12 z) Fp2.zero).toK U)
    (fun z => ((supp 1 (2 ^ 12)).getD (msbIndex 12 z) Fp2.zero).toK U)
    (fun z => shdOutcA U tag h64 O rA iA ocC_LIMB w z)
    (fun j => stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA ((outcLay O 14).aOff ocC_LIMB) 12 w
      (msbBits 12 (32 + j.val)))
    (fun j => ?_) (fun z hz => ?_) (fun z => ?_) (fun j => shdOutcA_alg U tag h64 O rA iA ocC_LIMB w _) h1.symm
  · -- `Wd` at a live channel
    have hi := i.isLt
    show ((wTab Vo.pub.dPad (Vo.pub.wDelta.take Vo.pub.d)).getD (msbIndex 12 (msbBits 12 i.val)) Fp2.zero).toK U = _
    rw [msbIndex_msbBits 12 i.val (by omega), wTab_getD_toK U _ _ _ (by omega) (fun _ => by
      rw [List.getD_eq_getElem?_getD, List.getElem?_take, ite_eq_left (by omega), ← List.getD_eq_getElem?_getD,
        hwD i]
      have := abs_le.mp (hwb i)
      constructor <;> linarith)]
    rw [htl, ite_eq_left hi, List.getD_eq_getElem?_getD, List.getElem?_take, ite_eq_left (by omega),
      ← List.getD_eq_getElem?_getD, hwD i, map_intCast]
  · -- `Wd` off the live channels
    have hge : ¬ msbIndex 12 x < d := by
      intro hlt'
      exact hx ⟨⟨msbIndex 12 x, hlt'⟩, msbBits_msbIndex 12 x⟩
    have hx4 : msbIndex 12 x < Vo.pub.dPad := by rw [hdPad]; exact lt_of_lt_of_eq (msbIndex_lt 12 x) (by norm_num)
    show ((wTab Vo.pub.dPad (Vo.pub.wDelta.take Vo.pub.d)).getD (msbIndex 12 x) Fp2.zero).toK U = 0
    rw [wTab_getD_toK U _ _ _ hx4 (fun h => absurd (lt_of_lt_of_eq h htl) hge), htl, ite_eq_right hge]
  · -- `Gm` at a margin limb
    have hj := j.isLt
    show ((gTab (2 ^ 12) OutcPub.lamBase P.limbs b).getD (msbIndex 12 (msbBits 12 (32 + j.val))) Fp2.zero).toK U = _
    rw [msbIndex_msbBits 12 (32 + j.val) (by omega), gTab_getD_toK U hU _ _ _ _ _ (by omega) hlim7,
      ite_eq_left (by unfold OutcPub.lamBase; omega)]
    unfold OutcPub.lamBase
    rw [show 32 + j.val - 32 = j.val by omega]
  · -- `Gm` off the margin limbs
    have hge : ¬ (OutcPub.lamBase ≤ msbIndex 12 z ∧ msbIndex 12 z < OutcPub.lamBase + P.limbs) := by
      rintro ⟨h1', h2'⟩
      unfold OutcPub.lamBase at h1' h2'
      exact hz ⟨⟨msbIndex 12 z - 32, by omega⟩, by
        show msbBits 12 (32 + (msbIndex 12 z - 32)) = z
        rw [show 32 + (msbIndex 12 z - 32) = msbIndex 12 z by omega, msbBits_msbIndex]⟩
    show ((gTab (2 ^ 12) OutcPub.lamBase P.limbs b).getD (msbIndex 12 z) Fp2.zero).toK U = 0
    rw [gTab_getD_toK U hU _ _ _ _ _ (msbIndex_lt 12 z) hlim7, ite_eq_right hge]
  · -- `u0`
    show ((supp 1 (2 ^ 12)).getD (msbIndex 12 z) Fp2.zero).toK U = _
    rw [supp_getD_toK U _ _ _ (msbIndex_lt 12 z)]
    by_cases h0 : z = msbBits 12 0
    · rw [ite_eq_left h0, h0, msbIndex_msbBits 12 0 (by norm_num), ite_eq_left (by norm_num)]
    · rw [ite_eq_right h0, ite_eq_right]
      intro hlt'
      apply h0
      rw [← msbBits_msbIndex 12 z, show msbIndex 12 z = 0 by omega]

end Margin

end ZK60.ProtocolClassify
