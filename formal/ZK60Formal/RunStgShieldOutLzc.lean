/-
D63 lane L63 (2026-11-19), L63 leg 12, part 81: **OUTC-04 LZC's single-lookup helper relation at every `Lo` entry,
from its define polynomial vanishing at every draw** (piece (iii) of step 1 of HANDOFF_20261119_1.md, LZC's part).

LZC hosts PD (`hosted = [(3, ν)]`, `outcDefLZC_ok`), so its define polynomial at a draw is its table side's cube sum
minus `ν` times PD's cube sum (`stgΦB_host_eval`). At a Boolean `eq` point `(z, 0)` the table side is
`μ0·helper(z) + μ1·pad(z) + ν·Σ host`, so the batched value is `μ0·A + μ1·B + ν·C` with `C` free of the draws; it
vanishes for all nonzero `μ0, μ1, ν`, hence `A = B = C = 0` (`clauses_host_of_combo`).

* `outcLzcRest`, `kI_zero_toK`, `fromI64_one_alg`, **`clauses_host_of_combo`**;
* **`outc_lzc_clauses`**: `h_lo·(α − (limb + γ·TAG_U8)) − 1 = 0` and `(1 − live)·limb = 0` at every cube point
  `(z, 0)`;
* **`outc_lzc_vals`**: LZC's limb and helper table values at `(z, 0)` are the `A_out` limb plane and the `H_out`
  helper `h_lo` (`shdOutcA`, `shdOutcHd`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutEval

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

section Small

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem kI_zero_toK : (kI 0).toK U = 0 := by
  unfold kI
  rw [Fp2.toK_fromBase, Fp.toGF_fromI64 _ (by norm_num) (by norm_num)]
  simp

theorem fromI64_one_alg : algebraMap GF K (Fp.fromI64 1).toGF = 1 := by
  rw [Fp.toGF_fromI64 _ (by norm_num) (by norm_num)]
  simp

omit [Algebra GF K] in
/-- **A host's batching**: two clauses and the hosted difference vanish when every batched value vanishes. -/
theorem clauses_host_of_combo (h2 : (2 : K) ≠ 0) (A B C : K)
    (h : ∀ μ0 μ1 ν : K, μ0 ≠ 0 → μ1 ≠ 0 → ν ≠ 0 → μ0 * A + μ1 * B + ν * C = 0) :
    A = 0 ∧ B = 0 ∧ C = 0 := by
  have e1 := h 1 1 1 one_ne_zero one_ne_zero one_ne_zero
  have e2 := h 2 1 1 h2 one_ne_zero one_ne_zero
  have e3 := h 1 2 1 one_ne_zero h2 one_ne_zero
  have hA : A = 0 := by linear_combination e2 - e1
  have hB : B = 0 := by linear_combination e3 - e1
  refine ⟨hA, hB, ?_⟩
  linear_combination e1 - hA - hB

end Small

section Lzc

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- OUTC-04 LZC's tables after its `eq` table (`outcDefLZC_ok`): `live`, `G`, `u0`, `A limb`, `H h_lo`. -/
def outcLzcRest (O : OutcPub) (G : OutcGeo) : List Block.Tab :=
  [.pub (liveTab (2 ^ O.llo) OutcPub.lamBase O.limbs),
   .pub (gTab (2 ^ O.llo) OutcPub.lamBase O.limbs O.verdict),
   .pub (supp 1 (2 ^ O.llo)),
   .priv ⟨.a, [((outcLay O G.bLogN).aOff ocC_LIMB, Fp2.one)], (outcLay O G.bLogN).aLog.getD ocC_LIMB 0,
     rhoC 0 ((outcLay O G.bLogN).aLog.getD ocC_LIMB 0), (outcLay O G.bLogN).aMaskBase + 2 * ((outcLay O G.bLogN).prefixA 4 + 0),
     0⟩,
   .priv ⟨.h, [(((outcLay O G.bLogN).hOff ocH_LO).1, Fp2.one), (((outcLay O G.bLogN).hOff ocH_LO).2, Block.fp2U)],
     (outcLay O G.bLogN).hLog.getD ocH_LO 0, rhoC 0 ((outcLay O G.bLogN).hLog.getD ocH_LO 0),
     (outcLay O G.bLogN).hMaskBase + 2 * ((outcLay O G.bLogN).prefixH 4 + 0), 0⟩]

/-- **OUTC-04 LZC'S HELPER RELATION AND PAD AT EVERY CUBE POINT, from its define polynomial vanishing at every
draw.** -/
theorem outc_lzc_clauses {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P0 : Block.BlockParams) (Vo : OutcV) (hP : StgSame P0 Vo.bp) (ch : List Fp2) (hch : ∀ a ∈ ch, a.Canon)
    (lc h Q eC rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : Vo.pub.lt ≤ lc) (hd : List (List Fp2)) (hhd : hd.length = 4)
    (hzero : ∀ y : Fin (P0.draws 4) → K, stgΦB U hbij P0 Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
      (OutcV.bga ch) hd 4 (stgWords U hbij y) = 0)
    (ll : ℕ) (hll0 : Vo.pub.llo = ll) (z : Fin ll → Bool) :
    let r : ℕ → K := fun j => ((outcLzcRest Vo.pub Vo.geo).map
      (stgTabK U hbij Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) ll 1
        (fun i : Fin (stgN P0 4) => (bit (cptS ll z i) : K)))).getD j 0
    r 4 * ((ch.getD 1 Fp2.zero).toK U - (r 3 + (ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF))) - 1 = 0
      ∧ (1 - r 0) * r 3 = 0 := by
  subst hll0
  intro r
  simp only [r]
  revert z
  set O := Vo.pub with hO
  set G := Vo.geo with hG
  set llo := O.llo with hllo
  set cs := stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v with hcs
  intro z
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
  -- the hosted slot's cube sum and the host term's cube sum do not depend on the draw
  set Cpd : K := cubeSum (stgSpT U hbij P0 Vo.bp cs (OutcV.bga ch) hd 3) with hCpd
  set Hs : K := cubeSum (fun x : Fin (stgN P0 4) → K =>
    let r' : ℕ → K := fun j => ((outcLzcRest O G).map (stgTabK U hbij Vo.bp cs llo 1 x)).getD j 0
    (r' 1 * r' 3) + (r' 2 * kc.toK U)) with hHs
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
  · exact ⟨hcl.1, hcl.2.1⟩
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
  -- the table side: `eq · (μ0·helper + μ1·pad)` plus `ν · host`
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

end Lzc

/-! ## LZC's limb and helper table values at `(z, 0)` -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- LZC's table values at `(z, 0)` on `N` variables (`outc_lzc_clauses`' `r` at `llo = 12`). -/
noncomputable def shdLzcR (Vo : OutcV) (cs : Block.Cm → Block.ZClaim → K) (N : ℕ) (z : Fin 12 → Bool) (j : ℕ) : K :=
  ((outcLzcRest Vo.pub Vo.geo).map
    (stgTabK U hbij Vo.bp cs 12 1 (fun i : Fin N => (bit (cptS 12 z i) : K)))).getD j 0

/-- **LZC'S LIMB AND HELPER TABLES AT `(z, 0)` ARE THE `A_out` LIMB PLANE AND THE HELPER `h_lo`.** -/
theorem outc_lzc_vals (hU : U ^ 2 = algebraMap GF K 7) (O : OutcPub) (Vo : OutcV) (rA rH iA iH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (w : StgVw Lq)
    (hGb : Vo.geo.bLogN = 14) (hOL : outcLay Vo.pub 14 = outcLay O 14) (hllo : Vo.pub.llo = 12)
    (hlc : 0 < Vo.bp.logCols) {N : ℕ} (hN : N = 13) (z : Fin 12 → Bool) :
    let cs := stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w
    shdLzcR U hbij Vo cs N z 3 = shdOutcA U tag h64 O rA iA ocC_LIMB w z
      ∧ shdLzcR U hbij Vo cs N z 4 = (shdOutcHd U tag h64 O rH iH w).1 z := by
  intro cs
  set P' := Vo.bp with hP'
  have hNlt : 12 < N := by omega
  have hal : (outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_LIMB 0 = 12 := by
    rw [← hllo]; rfl
  have hhl : (outcLay Vo.pub Vo.geo.bLogN).hLog.getD ocH_LO 0 = 12 := by
    rw [← hllo]; rfl
  refine ⟨?_, ?_⟩
  · -- the `A_out` limb plane
    show stgTabK U hbij P' cs 12 1 _
      (.priv ⟨.a, [((outcLay Vo.pub Vo.geo.bLogN).aOff ocC_LIMB, Fp2.one)],
        (outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_LIMB 0, rhoC 0 ((outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_LIMB 0),
        (outcLay Vo.pub Vo.geo.bLogN).aMaskBase + 2 * ((outcLay Vo.pub Vo.geo.bLogN).prefixA 4 + 0), 0⟩) = _
    refine (stgTabK_priv_cptS U hbij hU P' cs rA ogStage.lc ogStage.Q
      (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA w) (by decide) 12 z hN _ (by intro _; rfl)
      (by exact List.cons_ne_nil _ _) (by show 0 < (outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_LIMB 0; omega)
      (by simp [rhoC]) (by exact hlc)
      (by intro c' hc w' hw; simp [rhoC] at hc; obtain ⟨_, _, rfl⟩ := hc; cases hw)).trans ?_
    rw [privZ_eq_planeZ U _ _ _ _ 12 z hNlt _ [((outcLay O 14).aOff ocC_LIMB, Fp2.one)] .a
      (by show [((outcLay Vo.pub Vo.geo.bLogN).aOff ocC_LIMB, Fp2.one)] = _; rw [hGb, hOL]) hal rfl]
    rfl
  · -- the helper `h_lo`
    show stgTabK U hbij P' cs 12 1 _
      (.priv ⟨.h, [(((outcLay Vo.pub Vo.geo.bLogN).hOff ocH_LO).1, Fp2.one),
          (((outcLay Vo.pub Vo.geo.bLogN).hOff ocH_LO).2, Block.fp2U)],
        (outcLay Vo.pub Vo.geo.bLogN).hLog.getD ocH_LO 0, rhoC 0 ((outcLay Vo.pub Vo.geo.bLogN).hLog.getD ocH_LO 0),
        (outcLay Vo.pub Vo.geo.bLogN).hMaskBase + 2 * ((outcLay Vo.pub Vo.geo.bLogN).prefixH 4 + 0), 0⟩) = _
    refine (stgTabK_priv_cptS U hbij hU P' cs rH ogStage.lc ogStage.Q
      (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w) (by decide) 12 z hN _ (by intro _; rfl)
      (by exact List.cons_ne_nil _ _) (by show 0 < (outcLay Vo.pub Vo.geo.bLogN).hLog.getD ocH_LO 0; omega)
      (by simp [rhoC]) (by exact hlc)
      (by intro c' hc w' hw; simp [rhoC] at hc; obtain ⟨_, _, rfl⟩ := hc; cases hw)).trans ?_
    rw [privZ_eq_planeZ U _ _ _ _ 12 z hNlt _
      [(((outcLay O 14).hOff ocH_LO).1, Fp2.one), (((outcLay O 14).hOff ocH_LO).2, Block.fp2U)] .h
      (by show [(((outcLay Vo.pub Vo.geo.bLogN).hOff ocH_LO).1, Fp2.one),
          (((outcLay Vo.pub Vo.geo.bLogN).hOff ocH_LO).2, Block.fp2U)] = _; rw [hGb, hOL]) hhl rfl]
    rfl

end Vals

end ZK60.ProtocolClassify
