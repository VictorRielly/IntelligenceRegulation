/-
D63 lane L63 (2026-11-20), L63 leg 14, part 92: **OUTC-04 LZC's hosted sum: PD's cube sum is LZC's host term's**
(item 4 of HANDOFF_20261119_3.md section 6, the margin half of `RelPD`; the `ν` coordinate of `outc_lzc_clauses`' host
combo, whose proof up to `clauses_host_of_combo` is copied: there its third value `C = Hs − Cpd` was dropped).

* **`outc_lzc_host`**: from LZC's define polynomial vanishing at every draw, the host term's cube sum
  `Σ_x (G(x)·limb(x) + u0(x)·(b + c))` equals PD's cube sum `cubeSum (stgSpT … 3)`;
* `stgTabK_pub_ext1`: a public table vanishes where the extension bit is `1`;
* `outc_identAoff`: an `A_out` table at `(0…0, ρ)` (lift `0`) at `(c, 0)` is `shdOutcA`;
* **`outc_pd_cube`**: PD's cube sum is `Σ_c y(c)·w(c)` over the twelve-bit cube (`y` the `A_out` plane `Y`, `w` the
  `wTab` entry);
* **`outc_lzc_cube`**: the host term's cube sum is `Σ_z (G(z)·limb(z) + u0(z)·(b + c))` over the twelve-bit cube.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutIO
import ZK60Formal.RunStgShieldIncZS

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

section LzcHost

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **OUTC-04 LZC'S HOSTED SUM, from its define polynomial vanishing at every draw**: the host term's cube sum is PD's
cube sum. -/
theorem outc_lzc_host {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P0 : Block.BlockParams) (Vo : OutcV) (hP : StgSame P0 Vo.bp) (ch : List Fp2) (hch : ∀ a ∈ ch, a.Canon)
    (lc h Q eC rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : Vo.pub.lt ≤ lc) (hd : List (List Fp2)) (hhd : hd.length = 4)
    (hzero : ∀ y : Fin (P0.draws 4) → K, stgΦB U hbij P0 Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
      (OutcV.bga ch) hd 4 (stgWords U hbij y) = 0) :
    cubeSum (fun x : Fin (stgN P0 4) → K =>
      (((outcLzcRest Vo.pub Vo.geo).map (stgTabK U hbij Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
          Vo.pub.llo 1 x)).getD 1 0
        * ((outcLzcRest Vo.pub Vo.geo).map (stgTabK U hbij Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
          Vo.pub.llo 1 x)).getD 3 0)
      + (((outcLzcRest Vo.pub Vo.geo).map (stgTabK U hbij Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
          Vo.pub.llo 1 x)).getD 2 0 * ((kI Vo.pub.verdict).add (kI Vo.pub.c)).toK U))
      = cubeSum (stgSpT U hbij P0 Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) (OutcV.bga ch) hd 3) := by
  set O := Vo.pub with hO
  set G := Vo.geo with hG
  set llo := O.llo with hllo
  set cs := stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v with hcs
  let z : Fin llo → Bool := fun _ => false
  set alpha := ch.getD 1 Fp2.zero with halpha_def
  set gU8 := (ch.getD 0 Fp2.zero).mulBase (Fp.new (UInt64.ofNat tagU8)) with hgU8_def
  set kc := (kI O.verdict).add (kI O.c) with hkc_def
  have hdraws : P0.draws 4 = llo + 3 := by rw [hP.1]; show llo + 2 + 1 = llo + 3; omega
  have hN : stgN P0 4 = llo + 1 := by unfold stgN; rw [stg_slotShape hP]; rfl
  have halpha : alpha.Canon := Fp2.canon_getD hch 1
  have hgU8 : gU8.Canon := Fp2.canon_mulBase _ _
  have hj0 : llo < P0.draws 4 := by omega
  have hj1 : llo + 1 < P0.draws 4 := by omega
  have hj2 : llo + 2 < P0.draws 4 := by omega
  have hIO_vac : StgCsIODeg U hbij Vo.bp.endpointLogN (fun _ => False) csIO :=
    fun _ _ _ _ _ _ _ _ _ hf => absurd hf id
  have hfit : tabsFit llo (outcLzcRest O G) := by
    intro t ht
    simp only [outcLzcRest, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl | rfl | rfl | rfl
    · show (liveTab (2 ^ llo) OutcPub.lamBase O.limbs).length = 2 ^ llo
      simp [liveTab]
    · show (gTab (2 ^ llo) OutcPub.lamBase O.limbs O.verdict).length = 2 ^ llo
      simp [gTab]
    · show (supp 1 (2 ^ llo)).length = 2 ^ llo
      simp [supp]
    · trivial
    · trivial
  have hok : ∀ t ∈ outcLzcRest O G, TabPrivOK (fun _ => False) t := by
    intro t ht
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_a_rho _ _ _ _
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_h_rho _ _ _ _ _
    exact absurd ht List.not_mem_nil
  have hcan : ∀ t ∈ outcLzcRest O G, ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon := by
    intro t ht pt s he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    exact absurd ht List.not_mem_nil
  have hk0 := kI_zero_toK U
  have hf1 := fromI64_one_alg (K := K)
  have hgK : gU8.toK U = (ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF) := gU8_toK U ch
  set Cpd : K := cubeSum (stgSpT U hbij P0 Vo.bp cs (OutcV.bga ch) hd 3) with hCpd
  set Hs : K := cubeSum (fun x : Fin (stgN P0 4) → K =>
    (((outcLzcRest O G).map (stgTabK U hbij Vo.bp cs llo 1 x)).getD 1 0
      * ((outcLzcRest O G).map (stgTabK U hbij Vo.bp cs llo 1 x)).getD 3 0)
    + (((outcLzcRest O G).map (stgTabK U hbij Vo.bp cs llo 1 x)).getD 2 0 * kc.toK U)) with hHs
  have hcl := clauses_host_of_combo (ZK60.Exec.two_ne_zero_K (K := K))
    (((outcLzcRest O G).map
        (stgTabK U hbij Vo.bp cs llo 1 (fun i : Fin (stgN P0 4) => (bit (cptS llo z i) : K)))).getD 4 0
      * (alpha.toK U - (((outcLzcRest O G).map
        (stgTabK U hbij Vo.bp cs llo 1 (fun i : Fin (stgN P0 4) => (bit (cptS llo z i) : K)))).getD 3 0
        + (ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF))) - 1)
    ((1 - ((outcLzcRest O G).map
        (stgTabK U hbij Vo.bp cs llo 1 (fun i : Fin (stgN P0 4) => (bit (cptS llo z i) : K)))).getD 0 0)
      * ((outcLzcRest O G).map
        (stgTabK U hbij Vo.bp cs llo 1 (fun i : Fin (stgN P0 4) => (bit (cptS llo z i) : K)))).getD 3 0)
    (Hs - Cpd) ?_
  · exact sub_eq_zero.mp hcl.2.2
  intro μ0 μ1 ν h0 h1 h2
  let y : Fin (P0.draws 4) → K := fun i =>
    if hi : i.val < llo then bit (z ⟨i.val, hi⟩)
    else if i.val = llo then μ0 else if i.val = llo + 1 then μ1 else ν
  have hy0 : y ⟨llo, hj0⟩ = μ0 := by simp [y]
  have hy1 : y ⟨llo + 1, hj1⟩ = μ1 := by simp [y]
  have hy2 : y ⟨llo + 2, hj2⟩ = ν := by simp [y]
  have hyb : ∀ a (ha : a < llo), y ⟨a, by omega⟩ = bit (z ⟨a, ha⟩) := by
    intro a ha
    simp [y, ha]
  have hZ : ∀ i ∈ Z_range (P0.draws 4) llo 3, y i ≠ 0 := by
    intro i hi
    simp only [Z_range, Finset.mem_filter, Finset.mem_univ, true_and] at hi
    by_cases e0 : i.val = llo
    · have : i = ⟨llo, hj0⟩ := Fin.ext e0
      rw [this, hy0]; exact h0
    by_cases e1 : i.val = llo + 1
    · have : i = ⟨llo + 1, hj1⟩ := Fin.ext e1
      rw [this, hy1]; exact h1
    · have : i = ⟨llo + 2, hj2⟩ := Fin.ext (by show i.val = llo + 2; omega)
      rw [this, hy2]; exact h2
  have hdef := outcDefLZC_ok U hbij hU O G ⟨(OutcV.bga ch).1, (OutcV.bga ch).2.1, (OutcV.bga ch).2.2, hd⟩ hdraws y hZ
  have hev := stgΦB_host_eval U hbij hU tag h64 P0 Vo.bp hP lc h Q eC rA rH iA iH (fun _ => False) csIO v hlc hIO_vac
    (OutcV.bga ch) hd 4 3 (llo + 2) llo 1 4 llo hhd (by norm_num) hj2 (by omega) le_rfl rfl rfl
    (outc_pd_spT_deg U hbij tag h64 hU P0 Vo hP lc h Q eC rA rH iA iH csIO v hlc (OutcV.bga ch) hd)
    (outcLzcRest O G)
    (lzcPoly (((stgWords U hbij y).drop llo).take 2) ((stgWords U hbij y).getD (llo + 2) Fp2.zero) alpha gU8 kc) y
    hdef hok hcan
    (fun g =>
      let helperK := 0 + 1 * ((g 5 * denK U (alpha.toK U) (gU8.toK U) g 4 1 0) - 1)
      let padK := (1 - g 1) * g 4
      let hostK := (g 2 * g 4) + (g 3 * kc.toK U)
      (g 0 * ((y ⟨llo, hj0⟩ * helperK) + (y ⟨llo + 1, hj1⟩ * padK))) + (y ⟨llo + 2, hj2⟩ * hostK))
    (fun vals hv => by
      unfold lzcPoly
      rw [Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU, Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU, Fp2.toK_mul U hU,
          vg_drop_take_toK U hbij y llo 2 0 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y llo 2 1 (by norm_num) (by omega),
          Fp2.toK_add U _ _ Fp2.canon_zero (Fp2.canon_mul _ _), Fp2.toK_zero,
          Fp2.toK_mul U hU, Fp2.toK_one,
          Fp2.toK_sub U _ _ (Fp2.canon_mul _ _) Fp2.canon_one, Fp2.toK_one,
          Fp2.toK_mul U hU, denW_toK U vals alpha gU8 halpha hgU8 4 1 0,
          Fp2.toK_mul U hU, Fp2.toK_sub U _ _ Fp2.canon_one (vg_canon hv 1), Fp2.toK_one,
          Fp2.toK_mul U hU, stgWords_getD_toK U hbij y (llo + 2) hj2,
          Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU, Fp2.toK_mul U hU]
      simp only [vg_toK_map, Nat.add_zero])
    (fun g hg => by
      have hh : IndDegLE 2 (fun x => (0 : K) + 1 * ((g 5 x * denK U (alpha.toK U) (gU8.toK U) (fun idx => g idx x) 4 1 0) - 1)) :=
        IndDegLE.add (IndDegLE.const 0)
          (IndDegLE.cmul 1 (IndDegLE.sub (IndDegLE.mul (hg 5) (indDegLE_denK U _ _ g hg 4 1 0)) (IndDegLE.const 1)))
      have hp : IndDegLE 2 (fun x => (1 - g 1 x) * g 4 x) :=
        IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) (hg 1)) (hg 4)
      have hho : IndDegLE 2 (fun x => (g 2 x * g 4 x) + (g 3 x * kc.toK U)) :=
        IndDegLE.add (IndDegLE.mul (hg 2) (hg 4)) (IndDegLE.mono (IndDegLE_mulc (hg 3) _) (by norm_num))
      exact IndDegLE.mono (IndDegLE.add
        (IndDegLE.mul (hg 0) (IndDegLE.add (IndDegLE.cmul _ hh) (IndDegLE.cmul _ hp)))
        (IndDegLE.mono (IndDegLE.cmul _ hho) (by norm_num))) (by norm_num))
  rw [hzero y, ite_eq_left hfit] at hev
  set F : (Fin (stgN P0 4) → K) → K := fun x =>
    let r' : ℕ → K := fun j => ((outcLzcRest O G).map (stgTabK U hbij Vo.bp cs llo 1 x)).getD j 0
    (y ⟨llo, hj0⟩ * (0 + 1 * ((r' 4 * (alpha.toK U - (((kI 0).toK U + gU8.toK U)
        + r' 3 * algebraMap GF K (Fp.fromI64 1).toGF))) - 1)))
      + (y ⟨llo + 1, hj1⟩ * ((1 - r' 0) * r' 3)) with hF
  set Hf : (Fin (stgN P0 4) → K) → K := fun x =>
    let r' : ℕ → K := fun j => ((outcLzcRest O G).map (stgTabK U hbij Vo.bp cs llo 1 x)).getD j 0
    (r' 1 * r' 3) + (r' 2 * kc.toK U) with hHf
  have hev' : (0 : K) = cubeSum (fun x : Fin (stgN P0 4) → K =>
      eqDrawK llo llo 1 (by omega) y x * F x + y ⟨llo + 2, hj2⟩ * Hf x) - y ⟨llo + 2, hj2⟩ * Cpd := hev
  have hsplit : cubeSum (fun x : Fin (stgN P0 4) → K =>
      eqDrawK llo llo 1 (by omega) y x * F x + y ⟨llo + 2, hj2⟩ * Hf x)
      = cubeSum (fun x : Fin (stgN P0 4) → K => eqDrawK llo llo 1 (by omega) y x * F x)
        + y ⟨llo + 2, hj2⟩ * cubeSum Hf := by
    unfold cubeSum
    rw [Finset.sum_add_distrib, Finset.mul_sum]
  have hcube := cube_eqDraw_single (M := P0.draws 4) (N := stgN P0 4) llo (by omega) hN y z hyb F
  rw [hsplit, hcube] at hev'
  have hHs' : cubeSum Hf = Hs := rfl
  rw [hHs', hF] at hev'
  dsimp only at hev'
  rw [hy0, hy1, hy2, hk0, hf1, hgK] at hev'
  linear_combination (-1 : K) * hev'

end LzcHost

/-! ## The two cube sums on the twelve-bit cube -/

section Cubes

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **A public table vanishes where the extension bit is `1`.** -/
theorem stgTabK_pub_ext1 (P : Block.BlockParams) (cs : Block.Cm → Block.ZClaim → K) {N : ℕ} (n : ℕ) (hN : N = n + 1)
    (pv : List Fp2) (w : Fin N → Bool) (hw : w ⟨n, by omega⟩ = true) :
    stgTabK U hbij P cs n 1 (fun i => (bit (w i) : K)) (.pub pv) = 0 := by
  unfold stgTabK stgTabW
  dsimp only
  have hs : Block.selK n 1 (fun i : Fin N => (bit (w i) : K)) = 0 := by
    unfold Block.selK Block.yeK
    rw [Finset.prod_range_one, Nat.add_zero, xg_bitv w n (by omega), hw]
    simp [bit]
  split_ifs
  · rw [hs, zero_mul]
  · rfl

variable (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- **An `A_out` table at `(0…0, ρ)` with lift `0` at `(c, 0)` is `shdOutcA`.** -/
theorem outc_identAoff (hU : U ^ 2 = algebraMap GF K 7) (O : OutcPub) (Vo : OutcV) (rA rH iA iH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (w : StgVw Lq)
    (hGb : Vo.geo.bLogN = 14) (hOL : outcLay Vo.pub 14 = outcLay O 14)
    (hlc : 0 < Vo.bp.logCols) {N : ℕ} (hN : N = 13) (c : Fin 12 → Bool) (off mr : ℕ)
    (hlog : (outcLay Vo.pub Vo.geo.bLogN).aLog.getD off 0 = 12) :
    stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12 1
        (fun i : Fin N => (bit (cptS 12 c i) : K))
        (.priv ⟨.a, [((outcLay Vo.pub Vo.geo.bLogN).aOff off, Fp2.one)], (outcLay Vo.pub Vo.geo.bLogN).aLog.getD off 0,
          fixedC (List.replicate 0 Fp2.zero) ++ rhoC 0 12, mr, 0⟩)
      = shdOutcA U tag h64 O rA iA off w c := by
  have hc : fixedC (List.replicate 0 Fp2.zero) ++ rhoC 0 12 = rhoC 0 ((outcLay Vo.pub Vo.geo.bLogN).aLog.getD off 0) := by
    rw [hlog]; rfl
  rw [hc]
  exact outc_identA U hbij tag h64 hU O Vo rA rH iA iH csIO w hGb hOL hlc hN c off mr hlog

/-- **PD'S CUBE SUM IS `Σ_c y(c)·w(c)`** over the twelve-bit cube (`d_bits = 12`, lift `0`, `d_pad = 4096`). -/
theorem outc_pd_cube (hU : U ^ 2 = algebraMap GF K 7) (O : OutcPub) (P0 : Block.BlockParams) (Vo : OutcV)
    (hP : StgSame P0 Vo.bp) (rA rH iA iH : ℕ) (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (w : StgVw Lq)
    (hlt : Vo.pub.lt ≤ ogStage.lc) (bga : Fp2 × Fp2 × Fp2) (hd : List (List Fp2))
    (hGb : Vo.geo.bLogN = 14) (hOL : outcLay Vo.pub 14 = outcLay O 14) (hldo : Vo.pub.ldo = 12)
    (hdB : Vo.pub.dBits = 12) (hlift : Vo.pub.lift = 0) (hdPad : Vo.pub.dPad = 4096) (hlc : 0 < Vo.bp.logCols) :
    cubeSum (stgSpT U hbij P0 Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) bga hd 3)
      = ∑ c : Fin 12 → Bool, shdOutcA U tag h64 O rA iA ocC_Y w c
          * ((wTab Vo.pub.dPad (Vo.pub.wDelta.take Vo.pub.d)).getD (msbIndex 12 c) Fp2.zero).toK U := by
  have hIO_vac : StgCsIODeg U hbij Vo.bp.endpointLogN (fun _ => False) csIO :=
    fun _ _ _ _ _ _ _ _ _ hf => absurd hf id
  have heq := (stgSpT_eval_and_deg U hbij hU tag h64 P0 Vo.bp hP ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH
    (fun _ => False) csIO w hlt hIO_vac bga hd 3 Vo.pub.dBits 1 2 rfl
    [.priv ⟨.a, [((outcLay Vo.pub Vo.geo.bLogN).aOff ocC_Y, Fp2.one)], (outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_Y 0,
       fixedC (List.replicate Vo.pub.lift Fp2.zero) ++ rhoC 0 Vo.pub.dBits,
       (outcLay Vo.pub Vo.geo.bLogN).aMaskBase + 2 * ((outcLay Vo.pub Vo.geo.bLogN).prefixA 3 + 0), 0⟩,
     .pub (wTab Vo.pub.dPad (Vo.pub.wDelta.take Vo.pub.d))]
    pdPoly [] (outcDefPD_ok Vo.pub Vo.geo)
    (fun t ht => by
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_a_fixed_rho _ _ _ _ _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
      exact absurd ht List.not_mem_nil)
    (fun t ht pt s he => by
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      exact absurd ht List.not_mem_nil)
    (fun g => g 0 * g 1)
    (fun vals _ => by unfold pdPoly; rw [Fp2.toK_mul U hU, vg_toK_map, vg_toK_map])
    (fun g hg => IndDegLE.mul (hg 0) (hg 1))).1
  rw [heq]
  rw [hdB, hlift]
  have hN : stgN P0 3 = 13 := by unfold stgN; rw [stg_slotShape hP]; show Vo.pub.dBits + 1 = 13; omega
  have hwl : (wTab Vo.pub.dPad (Vo.pub.wDelta.take Vo.pub.d)).length = 2 ^ 12 := by
    simp [wTab, hdPad]
  have hfit : tabsFit 12
      [.priv ⟨.a, [((outcLay Vo.pub Vo.geo.bLogN).aOff ocC_Y, Fp2.one)], (outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_Y 0,
         fixedC (List.replicate 0 Fp2.zero) ++ rhoC 0 12,
         (outcLay Vo.pub Vo.geo.bLogN).aMaskBase + 2 * ((outcLay Vo.pub Vo.geo.bLogN).prefixA 3 + 0), 0⟩,
       .pub (wTab Vo.pub.dPad (Vo.pub.wDelta.take Vo.pub.d))] := by
    intro t ht
    rcases List.mem_cons.mp ht with rfl | ht
    · trivial
    rcases List.mem_cons.mp ht with rfl | ht
    · exact hwl
    · exact absurd ht List.not_mem_nil
  simp only [hfit, ↓reduceIte]
  rw [cube_sel_split 12 hN _ (fun w' hw' => by
    show _ * stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12 1 _ (.pub (wTab Vo.pub.dPad (Vo.pub.wDelta.take Vo.pub.d))) = 0
    rw [stgTabK_pub_ext1 U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12 hN _ w' hw', mul_zero])]
  refine Finset.sum_congr rfl (fun c _ => ?_)
  show stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12 1 (fun i : Fin (stgN P0 3) => (bit (cptS 12 c i) : K)) (.priv ⟨.a, [((outcLay Vo.pub Vo.geo.bLogN).aOff ocC_Y, Fp2.one)],
      (outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_Y 0, fixedC (List.replicate 0 Fp2.zero) ++ rhoC 0 12,
      (outcLay Vo.pub Vo.geo.bLogN).aMaskBase + 2 * ((outcLay Vo.pub Vo.geo.bLogN).prefixA 3 + 0), 0⟩)
    * stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12 1 (fun i : Fin (stgN P0 3) => (bit (cptS 12 c i) : K)) (.pub (wTab Vo.pub.dPad (Vo.pub.wDelta.take Vo.pub.d))) = _
  rw [outc_identAoff U hbij tag h64 hU O Vo rA rH iA iH csIO w hGb hOL hlc hN c ocC_Y _ (by rw [← hldo]; rfl),
    stgTabK_pub_cptS U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12 c hN _ hwl]

/-- **THE HOST TERM'S CUBE SUM** over the twelve-bit cube (`llo = 12`): `Σ_z (G(z)·limb(z) + u0(z)·kc)`. -/
theorem outc_lzc_cube (hU : U ^ 2 = algebraMap GF K 7) (O : OutcPub) (P0 : Block.BlockParams) (Vo : OutcV)
    (hP : StgSame P0 Vo.bp) (rA rH iA iH : ℕ) (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (w : StgVw Lq)
    (hGb : Vo.geo.bLogN = 14) (hOL : outcLay Vo.pub 14 = outcLay O 14) (hllo : Vo.pub.llo = 12)
    (hlc : 0 < Vo.bp.logCols) (kc : K) :
    cubeSum (fun x : Fin (stgN P0 4) → K =>
      (((outcLzcRest Vo.pub Vo.geo).map (stgTabK U hbij Vo.bp
          (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) Vo.pub.llo 1 x)).getD 1 0
        * ((outcLzcRest Vo.pub Vo.geo).map (stgTabK U hbij Vo.bp
          (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) Vo.pub.llo 1 x)).getD 3 0)
      + (((outcLzcRest Vo.pub Vo.geo).map (stgTabK U hbij Vo.bp
          (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) Vo.pub.llo 1 x)).getD 2 0 * kc))
      = ∑ z : Fin 12 → Bool,
          (((gTab (2 ^ 12) OutcPub.lamBase Vo.pub.limbs Vo.pub.verdict).getD (msbIndex 12 z) Fp2.zero).toK U
              * shdOutcA U tag h64 O rA iA ocC_LIMB w z
            + ((supp 1 (2 ^ 12)).getD (msbIndex 12 z) Fp2.zero).toK U * kc) := by
  have hN : stgN P0 4 = 13 := by unfold stgN; rw [stg_slotShape hP]; show Vo.pub.llo + 1 = 13; omega
  have hgl : (gTab (2 ^ 12) OutcPub.lamBase Vo.pub.limbs Vo.pub.verdict).length = 2 ^ 12 := by simp [gTab]
  have hsl : (supp 1 (2 ^ 12)).length = 2 ^ 12 := by simp [supp]
  have hr1 : ∀ x : Fin (stgN P0 4) → K, ((outcLzcRest Vo.pub Vo.geo).map (stgTabK U hbij Vo.bp
      (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) Vo.pub.llo 1 x)).getD 1 0
      = stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12 1 x
          (.pub (gTab (2 ^ 12) OutcPub.lamBase Vo.pub.limbs Vo.pub.verdict)) := by
    intro x
    show stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) Vo.pub.llo 1 x (.pub (gTab (2 ^ Vo.pub.llo) OutcPub.lamBase Vo.pub.limbs Vo.pub.verdict))
      = _
    rw [hllo]
  have hr2 : ∀ x : Fin (stgN P0 4) → K, ((outcLzcRest Vo.pub Vo.geo).map (stgTabK U hbij Vo.bp
      (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) Vo.pub.llo 1 x)).getD 2 0
      = stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12 1 x
          (.pub (supp 1 (2 ^ 12))) := by
    intro x
    show stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) Vo.pub.llo 1 x (.pub (supp 1 (2 ^ Vo.pub.llo))) = _
    rw [hllo]
  simp only [hr1, hr2]
  rw [cube_sel_split 12 hN _ (fun w' hw' => by
    rw [stgTabK_pub_ext1 U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12 hN _ w' hw', stgTabK_pub_ext1 U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12 hN _ w' hw', zero_mul,
      zero_mul, add_zero])]
  refine Finset.sum_congr rfl (fun z _ => ?_)
  have h3 := (outc_lzc_vals U hbij tag h64 hU O Vo rA rH iA iH csIO w hGb hOL hllo hlc hN z).1
  have h3' : ((outcLzcRest Vo.pub Vo.geo).map (stgTabK U hbij Vo.bp
      (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) Vo.pub.llo 1
      (fun i : Fin (stgN P0 4) => (bit (cptS 12 z i) : K)))).getD 3 0
      = shdOutcA U tag h64 O rA iA ocC_LIMB w z := by
    rw [← h3]
    unfold shdLzcR
    rw [hllo]
  rw [h3', stgTabK_pub_cptS U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12 z hN _ hgl, stgTabK_pub_cptS U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12 z hN _ hsl]

end Cubes

end ZK60.ProtocolClassify
