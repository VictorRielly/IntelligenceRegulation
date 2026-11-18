/-
D63 lane L63 (2026-11-18), part 57: **SIC_TZC's (INC-02's) relation and pads at every cube point from its define
polynomial vanishing everywhere** (item 4b, step 5's first half; generic in the stage's `IncV`; the twin of
`RunStgShieldIncQzc.lean`).

INC-02 is `eq(τ, ·)·(μ0·(h_tab·(α − τ) − m) + μ1·(1 − supp_V)·(m + ζ·h_tab))` (`incDefTZC_ok`).

* `incTzcRest`, `tzcPolyK`: INC-02's tables after `eq` and its polynomial read in `K`;
* **`inc_tzc_clauses`**: the three equations on the table values at `(c, 0)`, for every `c`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIncEval

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

section Tzc

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- INC-02's tables after its `eq` table (`incDefTZC_ok`): `supp_V`, `τ`, `A mult`, `H h_tab`. -/
def incTzcRest (I : IncPub) (G : IncGeo) (cx : IncCtx) : List Block.Tab :=
  [.pub (supp I.v (2 ^ I.vocLog)),
   .pub cx.tauTab,
   .priv ⟨.a, [((incLay I G.bLogN).aOff incA_MULT, Fp2.one)], (incLay I G.bLogN).aLog.getD incA_MULT 0,
     rhoC 0 ((incLay I G.bLogN).aLog.getD incA_MULT 0),
     (incLay I G.bLogN).aMaskBase + 2 * ((incLay I G.bLogN).prefixA 2 + 0), 0⟩,
   .priv ⟨.h, [(((incLay I G.bLogN).hOff incH_TAB).1, Fp2.one), (((incLay I G.bLogN).hOff incH_TAB).2, Block.fp2U)],
     (incLay I G.bLogN).hLog.getD incH_TAB 0, rhoC 0 ((incLay I G.bLogN).hLog.getD incH_TAB 0),
     (incLay I G.bLogN).hMaskBase + 2 * ((incLay I G.bLogN).prefixH 2 + 0), 0⟩]

/-- INC-02's polynomial read in `K`, at the batching `m0 m1` and the pad fold `z`. -/
def tzcPolyK (cx : IncCtx) (m0 m1 z : K) (g : ℕ → K) : K :=
  g 0 * ((m0 * (g 4 * (cx.alpha.toK U - g 2) - g 3)) + (m1 * ((1 - g 1) * (g 3 + z * g 4))))

/-- **SIC_TZC'S RELATION AND PADS AT EVERY CUBE POINT, from its define polynomial vanishing at every draw.** -/
theorem inc_tzc_clauses {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P0 : Block.BlockParams) (Vi : IncV) (ch : List Fp2) (hch : ∀ a ∈ ch, a.Canon)
    (hP : StgSame P0 (Vi.bp (incCtx Vi.pub ch)))
    (lc h Q eC rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : Vi.pub.lt ≤ lc)
    (hd : List (List Fp2)) (hhd : hd.length = 2)
    (hzero : ∀ y : Fin (P0.draws 2) → K, stgΦBC U hbij P0 (Vi.bp (incCtx Vi.pub ch))
      (incElog Vi.pub Vi.geo.bLogN) (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
      (Fp2.zero, Fp2.zero, Fp2.zero) hd 2 (stgWords U hbij y) = 0)
    (lv : ℕ) (hlv0 : Vi.pub.vocLog = lv) (c : Fin lv → Bool) :
    let r : ℕ → K := fun j => ((incTzcRest Vi.pub Vi.geo (incCtx Vi.pub ch)).map
      (stgTabK U hbij (StageV.atLog (Vi.bp (incCtx Vi.pub ch)) (incElog Vi.pub Vi.geo.bLogN 2))
        (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) lv 1
        (fun i : Fin (stgN P0 2) => (bit (cptS lv c i) : K)))).getD j 0
    r 3 * ((incCtx Vi.pub ch).alpha.toK U - r 1) - r 2 = 0
      ∧ (1 - r 0) * r 2 = 0
      ∧ (1 - r 0) * r 3 = 0 := by
  subst hlv0
  intro r
  simp only [r]
  revert c
  set I := Vi.pub with hI
  set G := Vi.geo with hG
  set cx := incCtx I ch with hcx
  set lv := I.vocLog with hlv
  set cs := stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v with hcs
  intro c
  have hdraws : P0.draws 2 = lv + 3 := by rw [hP.1]; show lv + 2 + 1 = lv + 3; omega
  have hN : stgN P0 2 = lv + 1 := by unfold stgN; rw [stg_slotShape hP]; rfl
  have halpha : cx.alpha.Canon := Fp2.canon_getD hch 2
  have hj0 : lv < P0.draws 2 := by omega
  have hj1 : lv + 1 < P0.draws 2 := by omega
  have hj2 : lv + 2 < P0.draws 2 := by omega
  have hIO_vac : StgCsIODeg U hbij (incElog I G.bLogN 2) (fun _ => False) csIO :=
    fun _ _ _ _ _ _ _ _ _ hf => absurd hf id
  have hfit : tabsFit lv (incTzcRest I G cx) := by
    intro t ht
    simp only [incTzcRest, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl | rfl | rfl
    · show (supp I.v (2 ^ lv)).length = 2 ^ lv
      simp [supp]
    · show (tauTable I (I.embFold cx.rEmb) _ _).length = 2 ^ lv
      simp [tauTable, hlv]
    · trivial
    · trivial
  have hok : ∀ t ∈ incTzcRest I G cx, TabPrivOK (fun _ => False) t := by
    intro t ht
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_a_rho _ _ _ _
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_h_rho _ _ _ _ _
    exact absurd ht List.not_mem_nil
  have hcan : ∀ t ∈ incTzcRest I G cx, ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon := by
    intro t ht pt s he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    exact absurd ht List.not_mem_nil
  refine clauses3_of_combo (ZK60.Exec.two_ne_zero_K (K := K)) _ _ _ ?_
  intro μ0 μ1 ζ h0 h1 h2
  let y : Fin (P0.draws 2) → K := fun i =>
    if hi : i.val < lv then bit (c ⟨i.val, hi⟩)
    else if i.val = lv then μ0 else if i.val = lv + 1 then μ1 else ζ
  have hy0 : y ⟨lv, hj0⟩ = μ0 := by simp [y]
  have hy1 : y ⟨lv + 1, hj1⟩ = μ1 := by simp [y]
  have hy2 : y ⟨lv + 2, hj2⟩ = ζ := by simp [y]
  have hyb : ∀ a (ha : a < lv), y ⟨a, by omega⟩ = bit (c ⟨a, ha⟩) := by
    intro a ha
    simp [y, ha]
  have hZ : ∀ i ∈ Z_range (P0.draws 2) lv 3, y i ≠ 0 := by
    intro i hi
    simp only [Z_range, Finset.mem_filter, Finset.mem_univ, true_and] at hi
    by_cases e0 : i.val = lv
    · have : i = ⟨lv, hj0⟩ := Fin.ext e0
      rw [this, hy0]; exact h0
    by_cases e1 : i.val = lv + 1
    · have : i = ⟨lv + 1, hj1⟩ := Fin.ext e1
      rw [this, hy1]; exact h1
    · have : i = ⟨lv + 2, hj2⟩ := Fin.ext (by show i.val = lv + 2; omega)
      rw [this, hy2]; exact h2
  have hdef := incDefTZC_ok U hbij hU I G cx hdraws y hZ
  have hev := stgΦBC_sa_eval U hbij hU tag h64 P0 (Vi.bp cx) (incElog I G.bLogN) hP lc h Q eC rA rH iA iH
    (fun _ => False) csIO v hlc (Fp2.zero, Fp2.zero, Fp2.zero) hd 2 lv 1 4 lv hIO_vac hhd (by omega) le_rfl rfl rfl
    (incTzcRest I G cx) _ y hdef hok hcan (tzcPolyK U cx μ0 μ1 ζ)
    (fun vals hv => by
      have hz_eq : ((((stgWords U hbij y).drop (lv + 2)).take 1).getD 0 Fp2.zero).toK U = ζ := by
        rw [getD_take_lt _ 1 0 (by norm_num), getD_drop, ← hy2]
        exact stgWords_getD_toK U hbij y (lv + 2) hj2
      unfold tzcPolyK
      dsimp only
      rw [Fp2.toK_mul U hU, Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU, Fp2.toK_mul U hU,
          vg_drop_take_toK U hbij y lv 2 0 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y lv 2 1 (by norm_num) (by omega),
          Fp2.toK_sub U _ _ (Fp2.canon_mul _ _) (vg_canon hv 3),
          Fp2.toK_mul U hU, Fp2.toK_sub U _ _ halpha (vg_canon hv 2),
          Fp2.toK_mul U hU, Fp2.toK_sub U _ _ Fp2.canon_one (vg_canon hv 1), Fp2.toK_one,
          Fp2.toK_add U _ _ (vg_canon hv 3) (Fp2.canon_mul _ _), Fp2.toK_mul U hU, hz_eq]
      simp only [vg_toK_map, Nat.add_zero, hy0, hy1])
    (fun g hg => by
      unfold tzcPolyK
      have hrel : IndDegLE 2 (fun x => g 4 x * (cx.alpha.toK U - g 2 x) - g 3 x) :=
        IndDegLE.sub (IndDegLE.mul (hg 4) (IndDegLE.sub (IndDegLE.const _) (hg 2)))
          (IndDegLE.mono (hg 3) (by norm_num))
      have hpad : IndDegLE 2 (fun x => (1 - g 1 x) * (g 3 x + ζ * g 4 x)) :=
        IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) (hg 1)) (IndDegLE.add (hg 3) (IndDegLE.cmul _ (hg 4)))
      exact IndDegLE.mono
        (IndDegLE.mul (hg 0) (IndDegLE.add (IndDegLE.cmul _ hrel) (IndDegLE.cmul _ hpad))) (by norm_num))
  rw [hzero y, ite_eq_left hfit, ← hcs] at hev
  set F : (Fin (stgN P0 2) → K) → K := fun x =>
    let r' : ℕ → K := fun j => ((incTzcRest I G cx).map
        (stgTabK U hbij (StageV.atLog (Vi.bp cx) (incElog I G.bLogN 2)) cs lv 1 x)).getD j 0
    (μ0 * (r' 3 * (cx.alpha.toK U - r' 1) - r' 2)) + (μ1 * ((1 - r' 0) * (r' 2 + ζ * r' 3))) with hF
  have hcube := cube_eqDraw_single (M := P0.draws 2) (N := stgN P0 2) lv (by omega) hN y c hyb F
  have hev' : (0 : K) = cubeSum (fun x : Fin (stgN P0 2) → K => eqDrawK lv lv 1 (by omega) y x * F x) := hev
  rw [hcube, hF] at hev'
  dsimp only at hev'
  linear_combination (-1 : K) * hev'

end Tzc

end ZK60.ProtocolClassify
