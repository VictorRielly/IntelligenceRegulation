/-
D63 lane L63 (2026-11-19), L63 leg 13, part 89: **OUTC-05 DZC's division clauses at every cube point** (a piece of
`hdoutC`, step 3 of HANDOFF_20261119_2.md: `RelDZC`'s `.inl j` clauses, the `μ0, μ1, μ2` coordinates of DZC's
batching; the twin of `outc_dzc_pairs`, RunStgShieldOutDzc.lean, whose proof up to the batching argument is copied).

* `dzcClG`: DZC's clause `j < 3` (`c0`, `c1`, `c2` of `dzcRestG`) on a table reader;
* `dzcRestG_clause`: two batchings that differ only at `j < 3` differ by `sD·c_j`'s multiple;
* `lbK_congr`, `dzcClG_congr`: the clauses read the reader at indices `≥ 1` only;
* **`outc_dzc_clauses`**: `sD·c_j = 0` at every cube point `(c, 0)`, `j < 3`, from DZC's define polynomial vanishing
  at every draw.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutDzc

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

section PolyCl

variable {K : Type} [Field K] [Algebra GF K]

/-- DZC's division clause `j` (`c0`, `c1`, `c2` of `dzcRestG`; `c2` for every `j ≥ 2`) on a table reader `g`. -/
noncomputable def dzcClG (U kNumK kDvK kDenK : K) (g : ℕ → K) (j : ℕ) : K :=
  if j = 0 then (((g 2 * kNumK) + (g 14 * kDvK)) - ((g 14 * kDenK) * g 5)) - lbK g 4
  else if j = 1 then ((lbK g 8 + lbK g 4) + 1) - (g 14 * kDenK)
  else ((g 2 + (kI 32768).toK U) - g 3) - (g 4 * mbC 256)

/-- **Two batchings that differ only at a clause coordinate `j < 3` differ by `sD·c_j`'s multiple.** -/
theorem dzcRestG_clause (U alphaK gK kNumK kDvK kDenK : K) (m m' g : ℕ → K) (j : ℕ) (hj : j < 3)
    (hs : ∀ i, i ≠ j → m' i = m i) :
    dzcRestG U alphaK gK kNumK kDvK kDenK m' g - dzcRestG U alphaK gK kNumK kDvK kDenK m g
      = (m' j - m j) * (g 1 * dzcClG U kNumK kDvK kDenK g j) := by
  have hS : dzcHsK U alphaK gK m' g = dzcHsK U alphaK gK m g := by
    unfold dzcHsK
    refine Finset.sum_congr rfl (fun kk _ => ?_)
    split_ifs
    · rw [hs (3 + kk) (by omega)]
    · rfl
  unfold dzcRestG dzcClG
  dsimp only
  rw [hS, hs 9 (by omega), hs 10 (by omega)]
  have h20 : (2 : ℕ) ≠ 0 := by norm_num
  have h21 : (2 : ℕ) ≠ 1 := by norm_num
  interval_cases j
  · rw [hs 1 (by omega), hs 2 (by omega)]
    simp only [↓reduceIte]
    ring
  · rw [hs 0 (by omega), hs 2 (by omega)]
    simp only [one_ne_zero, ↓reduceIte]
    ring
  · rw [hs 0 (by omega), hs 1 (by omega)]
    simp only [h20, h21, ↓reduceIte]
    ring

/-- `lbK` reads its reader at indices `≥ 2` only. -/
theorem lbK_congr (g g' : ℕ → K) (p : ℕ) (hg : ∀ i, 1 ≤ i → g i = g' i) : lbK g p = lbK g' p := by
  unfold lbK
  exact Finset.sum_congr rfl (fun kk _ => by rw [hg (2 + (p + kk)) (by omega)])

/-- `dzcClG` reads its reader at indices `≥ 1` only. -/
theorem dzcClG_congr (U kNumK kDvK kDenK : K) (g g' : ℕ → K) (j : ℕ) (hg : ∀ i, 1 ≤ i → g i = g' i) :
    dzcClG U kNumK kDvK kDenK g j = dzcClG U kNumK kDvK kDenK g' j := by
  unfold dzcClG
  rw [lbK_congr g g' 4 hg, lbK_congr g g' 8 hg, hg 2 (by omega), hg 3 (by omega), hg 4 (by omega),
    hg 5 (by omega), hg 14 (by omega)]

end PolyCl

section DzcCl

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **OUTC-05 DZC'S DIVISION CLAUSES AT EVERY CUBE POINT, from its define polynomial vanishing at every draw**
(`sD·c_j = 0`, `j < 3`). -/
theorem outc_dzc_clauses {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P0 : Block.BlockParams) (Vo : OutcV) (hP : StgSame P0 Vo.bp) (ch : List Fp2) (hch : ∀ a ∈ ch, a.Canon)
    (lc h Q eC rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : Vo.pub.lt ≤ lc) (hd : List (List Fp2)) (hhd : hd.length = 5)
    (hzero : ∀ y : Fin (P0.draws 5) → K, stgΦB U hbij P0 Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
      (OutcV.bga ch) hd 5 (stgWords U hbij y) = 0)
    (ld : ℕ) (hld0 : Vo.pub.ldo = ld) (c : Fin ld → Bool) (j : ℕ) (hj : j < 3) :
    ((outcDzcRest Vo.pub Vo.geo).map
        (stgTabK U hbij Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) ld 1
          (fun i : Fin (stgN P0 5) => (bit (cptS ld c i) : K)))).getD 0 0
      * dzcClG U ((kI (2 * Vo.pub.g0 * Vo.pub.cn)).toK U) ((kI (2 ^ Vo.pub.tn)).toK U)
        ((kI (2 ^ (Vo.pub.tn + 1))).toK U)
        (fun idx => ((outcDzcRest Vo.pub Vo.geo).map
          (stgTabK U hbij Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) ld 1
            (fun i : Fin (stgN P0 5) => (bit (cptS ld c i) : K)))).getD (idx - 1) 0) j = 0 := by
  subst hld0
  revert c
  set O := Vo.pub with hO
  set G := Vo.geo with hG
  set ldo := O.ldo with hldo
  set cs := stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v with hcs
  intro c
  set alpha := ch.getD 1 Fp2.zero with halpha_def
  set gU8 := (ch.getD 0 Fp2.zero).mulBase (Fp.new (UInt64.ofNat tagU8)) with hgU8_def
  set kNum := kI (2 * O.g0 * O.cn) with hkNum
  set kDv := kI (2 ^ O.tn) with hkDv
  set kDen := kI (2 ^ (O.tn + 1)) with hkDen
  have hdraws : P0.draws 5 = ldo + 11 := by rw [hP.1]; show ldo + 10 + 1 = ldo + 11; omega
  have hN : stgN P0 5 = ldo + 1 := by unfold stgN; rw [stg_slotShape hP]; rfl
  have halpha : alpha.Canon := Fp2.canon_getD hch 1
  have hgU8 : gU8.Canon := Fp2.canon_mulBase _ _
  have hIO_vac : StgCsIODeg U hbij Vo.bp.endpointLogN (fun _ => False) csIO :=
    fun _ _ _ _ _ _ _ _ _ hf => absurd hf id
  have hfit : tabsFit ldo (outcDzcRest O G) := by
    intro t ht
    rcases List.mem_cons.mp ht with rfl | ht
    · show (supp O.d (2 ^ ldo)).length = 2 ^ ldo
      simp [supp]
    · rcases List.mem_append.mp ht with ht12 | ht3
      · rcases List.mem_append.mp ht12 with ht1 | ht2
        · obtain ⟨_, _, rfl⟩ := List.mem_map.mp ht1; trivial
        · rcases List.mem_cons.mp ht2 with rfl | ht2
          · trivial
          · exact absurd ht2 List.not_mem_nil
      · obtain ⟨_, _, rfl⟩ := List.mem_map.mp ht3; trivial
  have hok : ∀ t ∈ outcDzcRest O G, TabPrivOK (fun _ => False) t := by
    intro t ht
    rcases List.mem_cons.mp ht with rfl | ht
    · exact tabPrivOK_pub _ _
    · rcases List.mem_append.mp ht with ht12 | ht3
      · rcases List.mem_append.mp ht12 with ht1 | ht2
        · obtain ⟨_, _, rfl⟩ := List.mem_map.mp ht1
          exact tabPrivOK_a_rho _ _ _ _
        · rcases List.mem_cons.mp ht2 with rfl | ht2
          · exact tabPrivOK_a_fixed _ _ _ _ _
          · exact absurd ht2 List.not_mem_nil
      · obtain ⟨_, _, rfl⟩ := List.mem_map.mp ht3
        exact tabPrivOK_h_rho _ _ _ _ _
  have hcan : ∀ t ∈ outcDzcRest O G, ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon := by
    intro t ht pt s he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_append.mp ht with ht12 | ht3
    · rcases List.mem_append.mp ht12 with ht1 | ht2
      · obtain ⟨_, _, rfl⟩ := List.mem_map.mp ht1; cases he
      · rcases List.mem_cons.mp ht2 with rfl | ht2; · cases he
        exact absurd ht2 List.not_mem_nil
    · obtain ⟨_, _, rfl⟩ := List.mem_map.mp ht3; cases he
  -- the draw of a batching `m`
  let yOf : (ℕ → K) → Fin (P0.draws 5) → K := fun m i =>
    if hi : i.val < ldo then bit (c ⟨i.val, hi⟩) else m (i.val - ldo)
  have hym : ∀ (m : ℕ → K) (j : ℕ) (hj : ldo + j < P0.draws 5), yOf m ⟨ldo + j, hj⟩ = m j := by
    intro m j hj
    simp [yOf]
  have hyb : ∀ (m : ℕ → K) a (ha : a < ldo), yOf m ⟨a, by omega⟩ = bit (c ⟨a, ha⟩) := by
    intro m a ha
    simp [yOf, ha]
  have hmu_lt : ∀ kk, kk < 10 → ldo + kk < P0.draws 5 := fun kk hkk => by omega
  have hzeta_lt : ldo + 10 < P0.draws 5 := by omega
  -- the table reader at `(c, 0)` through the whole list, at a draw `y`
  let gOf : (Fin (P0.draws 5) → K) → ℕ → K := fun y idx =>
    ((.eq ((stgWords U hbij y).take ldo) 0 :: outcDzcRest O G).map
      (stgTabK U hbij Vo.bp cs ldo 1 (fun i : Fin (stgN P0 5) => (bit (cptS ldo c i) : K)))).getD idx 0
  have hall : ∀ m : ℕ → K, (∀ j, j < 11 → m j ≠ 0) →
      dzcRestG U (alpha.toK U) (gU8.toK U) (kNum.toK U) (kDv.toK U) (kDen.toK U) m (gOf (yOf m)) = 0 := by
    intro m hm
    have hZ : ∀ i ∈ Z_range (P0.draws 5) ldo 11, yOf m i ≠ 0 := by
      intro i hi
      simp only [Z_range, Finset.mem_filter, Finset.mem_univ, true_and] at hi
      have hnl : ¬ i.val < ldo := by omega
      show (if hi : i.val < ldo then bit (c ⟨i.val, hi⟩) else m (i.val - ldo)) ≠ 0
      simp only [hnl, ↓reduceDIte]
      exact hm _ (by omega)
    have hdef := outcDefDZC_ok U hbij hU O G ⟨(OutcV.bga ch).1, (OutcV.bga ch).2.1, (OutcV.bga ch).2.2, hd⟩ hdraws
      (yOf m) hZ
    have hev := stgΦB_sa_evalL U hbij hU tag h64 P0 Vo.bp hP lc h Q eC rA rH iA iH (fun _ => False) csIO v hlc
      hIO_vac (OutcV.bga ch) hd 5 ldo 1 5 ldo hhd le_rfl rfl rfl (outcDzcRest O G)
      (dzcPoly (((stgWords U hbij (yOf m)).drop ldo).take 10) ((stgWords U hbij (yOf m)).getD (ldo + 10) Fp2.zero)
        alpha gU8 kNum kDv kDen) (yOf m) hdef hok hcan
      (fun g => g 0 * dzcRestG U (alpha.toK U) (gU8.toK U) (kNum.toK U) (kDv.toK U) (kDen.toK U) m g)
      (fun vals hv => by
        unfold dzcRestG dzcHsK dzcPairG
        unfold dzcPoly
        obtain ⟨hzc, hzeq⟩ := zfoldW_toK U hU vals ((stgWords U hbij (yOf m)).getD (ldo + 10) Fp2.zero)
        let muW := ((stgWords U hbij (yOf m)).drop ldo).take 10
        let denF := fun (l : ℕ × ℤ × ℤ) => denW vals alpha gU8 (2 + l.1) l.2.1 l.2.2
        obtain ⟨hhsc, hhseq⟩ := foldl_range_add_toK U
          (fun kk =>
            let d1 := denF (dzcLks.getD (2 * kk) (0, 0, 0))
            let d2 := denF (dzcLks.getD (2 * kk + 1) (0, 0, 0))
            (vg muW (3 + kk)).mul ((((vg vals (15 + kk)).mul d1).mul d2).sub (d1.add d2)))
          (fun _ => Fp2.canon_mul _ _) 6
        rw [Fp2.toK_mul U hU,
            Fp2.toK_add U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
            Fp2.toK_add U _ _ (Fp2.canon_mul _ _) hhsc,
            Fp2.toK_mul U hU,
            Fp2.toK_add U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
            Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
            Fp2.toK_mul U hU, Fp2.toK_mul U hU, Fp2.toK_mul U hU,
            vg_drop_take_toK U hbij (yOf m) ldo 10 0 (by norm_num) (by omega), hym m 0,
            vg_drop_take_toK U hbij (yOf m) ldo 10 1 (by norm_num) (by omega), hym m 1,
            vg_drop_take_toK U hbij (yOf m) ldo 10 2 (by norm_num) (by omega), hym m 2,
            Fp2.toK_sub U _ _ (Fp2.canon_sub _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _)) (lbW_canon _ _),
            Fp2.toK_sub U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
            Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
            Fp2.toK_mul U hU, Fp2.toK_mul U hU, Fp2.toK_mul U hU, Fp2.toK_mul U hU,
            Fp2.toK_sub U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
            Fp2.toK_add U _ _ (Fp2.canon_add _ _) Fp2.canon_one,
            Fp2.toK_add U _ _ (lbW_canon _ _) (lbW_canon _ _), Fp2.toK_one, Fp2.toK_mul U hU,
            Fp2.toK_sub U _ _ (Fp2.canon_sub _ _ (Fp2.canon_add _ _) (vg_canon hv 3)) (mb_canon _ _),
            Fp2.toK_sub U _ _ (Fp2.canon_add _ _) (vg_canon hv 3),
            Fp2.toK_add U _ _ (vg_canon hv 2) (kI_canon _), mb_toK,
            hhseq,
            Fp2.toK_mul U hU, vg_drop_take_toK U hbij (yOf m) ldo 10 9 (by norm_num) (by omega), hym m 9,
            Fp2.toK_mul U hU, Fp2.toK_sub U _ _ Fp2.canon_one (vg_canon hv 1), Fp2.toK_one,
            hzeq, stgWords_getD_toK U hbij (yOf m) (ldo + 10) hzeta_lt, hym m 10,
            lbW_toK U vals 4, lbW_toK U vals 8]
        simp only [vg_toK_map]
        congr 2
        congr 1
        refine Finset.sum_congr rfl (fun kk hkk => ?_)
        have hk6 : kk < 6 := Finset.mem_range.mp hkk
        simp only [hk6, ↓reduceDIte]
        rw [Fp2.toK_mul U hU,
            vg_drop_take_toK U hbij (yOf m) ldo 10 (3 + kk) (by omega) (by omega), hym m (3 + kk),
            Fp2.toK_sub U _ _ (Fp2.canon_mul _ _) (Fp2.canon_add _ _),
            Fp2.toK_mul U hU, Fp2.toK_mul U hU,
            Fp2.toK_add U _ _ (denW_canon _ _ _ halpha _ _ _) (denW_canon _ _ _ halpha _ _ _),
            denW_toK U vals alpha gU8 halpha hgU8, denW_toK U vals alpha gU8 halpha hgU8, vg_toK_map])
      (fun g hg => by
        have hrh := indDegLE_lbK g hg 4
        have hsg := indDegLE_lbK g hg 8
        have hkd : IndDegLE 1 (fun x => g 14 x * kDen.toK U) := IndDegLE_mulc (hg 14) _
        have hc0 : IndDegLE 2 (fun x => (((g 2 x * kNum.toK U) + (g 14 x * kDv.toK U))
            - ((g 14 x * kDen.toK U) * g 5 x)) - lbK (fun idx => g idx x) 4) :=
          IndDegLE.sub (IndDegLE.sub
            (IndDegLE.mono (IndDegLE.add (IndDegLE_mulc (hg 2) _) (IndDegLE_mulc (hg 14) _)) (by norm_num))
            (IndDegLE.mul hkd (hg 5))) (IndDegLE.mono hrh (by norm_num))
        have hc1 : IndDegLE 2 (fun x => ((lbK (fun idx => g idx x) 8 + lbK (fun idx => g idx x) 4) + 1)
            - (g 14 x * kDen.toK U)) :=
          IndDegLE.mono (IndDegLE.sub (IndDegLE.add (IndDegLE.add hsg hrh) (IndDegLE.const 1)) hkd) (by norm_num)
        have hc2 : IndDegLE 2 (fun x => ((g 2 x + (kI 32768).toK U) - g 3 x) - (g 4 x * mbC 256)) :=
          IndDegLE.mono (IndDegLE.sub (IndDegLE.sub (IndDegLE.add (hg 2) (IndDegLE.const _)) (hg 3))
            (IndDegLE_mulc (hg 4) _)) (by norm_num)
        have hcl : IndDegLE 2 (fun x =>
            (((m 0 * ((((g 2 x * kNum.toK U) + (g 14 x * kDv.toK U)) - ((g 14 x * kDen.toK U) * g 5 x))
              - lbK (fun idx => g idx x) 4))
              + (m 1 * (((lbK (fun idx => g idx x) 8 + lbK (fun idx => g idx x) 4) + 1) - (g 14 x * kDen.toK U))))
              + (m 2 * (((g 2 x + (kI 32768).toK U) - g 3 x) - (g 4 x * mbC 256))))) :=
          IndDegLE.add (IndDegLE.add (IndDegLE.cmul _ hc0) (IndDegLE.cmul _ hc1)) (IndDegLE.cmul _ hc2)
        have hhs : IndDegLE 3 (fun x => dzcHsK U (alpha.toK U) (gU8.toK U) m (fun idx => g idx x)) := by
          unfold dzcHsK
          refine indDegLE_finset_sum (Finset.range 6) _ (fun kk hkk => ?_)
          have hk6 : kk < 6 := Finset.mem_range.mp hkk
          simp only [hk6, ↓reduceDIte]
          unfold dzcPairG
          have hd1 := indDegLE_denK U (alpha.toK U) (gU8.toK U) g hg
            (2 + (dzcLks.getD (2 * kk) (0, 0, 0)).1) (dzcLks.getD (2 * kk) (0, 0, 0)).2.1
            (dzcLks.getD (2 * kk) (0, 0, 0)).2.2
          have hd2 := indDegLE_denK U (alpha.toK U) (gU8.toK U) g hg
            (2 + (dzcLks.getD (2 * kk + 1) (0, 0, 0)).1) (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.1
            (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.2
          exact IndDegLE.cmul _ (IndDegLE.sub (IndDegLE.mul (IndDegLE.mul (hg (15 + kk)) hd1) hd2)
            (IndDegLE.mono (IndDegLE.add hd1 hd2) (by norm_num)))
        have hzf : IndDegLE 1 (fun x => ∑ r ∈ Finset.range 12, g (2 + r) x * (m 10) ^ r) :=
          indDegLE_finset_sum (Finset.range 12) _ (fun r _ => IndDegLE_mulc (hg (2 + r)) _)
        have hpad : IndDegLE 3 (fun x => m 9 * ((1 - g 1 x) * (∑ r ∈ Finset.range 12, g (2 + r) x * (m 10) ^ r))) :=
          IndDegLE.mono (IndDegLE.cmul _ (IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) (hg 1)) hzf)) (by norm_num)
        have hall3 : IndDegLE 3 (fun x =>
            dzcRestG U (alpha.toK U) (gU8.toK U) (kNum.toK U) (kDv.toK U) (kDen.toK U) m (fun idx => g idx x)) := by
          unfold dzcRestG
          exact IndDegLE.add (IndDegLE.add (IndDegLE.mul (hg 1) hcl) hhs) hpad
        exact IndDegLE.mono (IndDegLE.mul (hg 0) hall3) (by norm_num))
    rw [hzero (yOf m), ite_eq_left hfit] at hev
    have he0 : ∀ x : Fin (stgN P0 5) → K,
        ((.eq ((stgWords U hbij (yOf m)).take ldo) 0 :: outcDzcRest O G).map (stgTabK U hbij Vo.bp cs ldo 1 x)).getD 0 0
          = eqDrawK ldo ldo 1 (by omega) (yOf m) x :=
      fun x => stgTabK_eq_draw U hbij Vo.bp cs ldo ldo 1 (by omega) le_rfl (yOf m) x
    have hev' : (0 : K) = cubeSum (fun x : Fin (stgN P0 5) → K => eqDrawK ldo ldo 1 (by omega) (yOf m) x
        * dzcRestG U (alpha.toK U) (gU8.toK U) (kNum.toK U) (kDv.toK U) (kDen.toK U) m (fun idx =>
          ((.eq ((stgWords U hbij (yOf m)).take ldo) 0 :: outcDzcRest O G).map
            (stgTabK U hbij Vo.bp cs ldo 1 x)).getD idx 0)) := by
      refine hev.trans (congrArg cubeSum (funext fun x => ?_))
      rw [← he0 x]
    have hcube := cube_eqDraw_single (M := P0.draws 5) (N := stgN P0 5) ldo (by omega) hN (yOf m) c (hyb m)
      (fun x : Fin (stgN P0 5) → K =>
        dzcRestG U (alpha.toK U) (gU8.toK U) (kNum.toK U) (kDv.toK U) (kDen.toK U) m (fun idx =>
          ((.eq ((stgWords U hbij (yOf m)).take ldo) 0 :: outcDzcRest O G).map
            (stgTabK U hbij Vo.bp cs ldo 1 x)).getD idx 0))
    rw [hcube] at hev'
    exact hev'.symm
  -- two batchings that differ only at the clause coordinate `j`
  let m1 : ℕ → K := fun _ => 1
  let m2 : ℕ → K := fun i => if i = j then 2 else 1
  have h2 : (2 : K) ≠ 0 := ZK60.Exec.two_ne_zero_K (K := K)
  have hm1 : ∀ i, i < 11 → m1 i ≠ 0 := fun _ _ => one_ne_zero
  have hm2 : ∀ i, i < 11 → m2 i ≠ 0 := by
    intro i _
    show (if i = j then (2 : K) else 1) ≠ 0
    split_ifs
    · exact h2
    · exact one_ne_zero
  have hW : gOf (yOf m2) = gOf (yOf m1) := by
    have e : (stgWords U hbij (yOf m2)).take ldo = (stgWords U hbij (yOf m1)).take ldo :=
      stgWords_take_congr U hbij (yOf m2) (yOf m1) ldo (fun i hi => by
        show (if hi : i.val < ldo then bit (c ⟨i.val, hi⟩) else m2 (i.val - ldo))
          = (if hi : i.val < ldo then bit (c ⟨i.val, hi⟩) else m1 (i.val - ldo))
        simp only [hi, ↓reduceDIte])
    funext idx
    show ((.eq ((stgWords U hbij (yOf m2)).take ldo) 0 :: outcDzcRest O G).map _).getD idx 0
      = ((.eq ((stgWords U hbij (yOf m1)).take ldo) 0 :: outcDzcRest O G).map _).getD idx 0
    rw [e]
  have e1 := hall m1 hm1
  have e2 := hall m2 hm2
  rw [hW] at e2
  have hp := dzcRestG_clause U (alpha.toK U) (gU8.toK U) (kNum.toK U) (kDv.toK U) (kDen.toK U) m1 m2
    (gOf (yOf m1)) j hj
    (fun i hi => by
      show (if i = j then (2 : K) else 1) = 1
      exact ite_eq_right hi)
  rw [e1, e2, sub_zero] at hp
  have hm23 : m2 j - m1 j = 1 := by
    show (if j = j then (2 : K) else 1) - 1 = 1
    rw [ite_eq_left rfl]
    norm_num
  rw [hm23, one_mul] at hp
  have hgi : ∀ i, 1 ≤ i → (fun idx => ((outcDzcRest O G).map
      (stgTabK U hbij Vo.bp cs ldo 1 (fun i : Fin (stgN P0 5) => (bit (cptS ldo c i) : K)))).getD (idx - 1) 0) i
        = gOf (yOf m1) i := by
    intro i hi
    obtain ⟨j', rfl⟩ : ∃ j', i = j' + 1 := ⟨i - 1, by omega⟩
    rfl
  rw [dzcClG_congr U _ _ _ _ _ j hgi]
  exact hp.symm

end DzcCl

end ZK60.ProtocolClassify
