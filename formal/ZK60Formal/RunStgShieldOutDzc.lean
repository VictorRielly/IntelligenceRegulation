/-
D63 lane L63 (2026-11-19), L63 leg 12, part 82: **OUTC-05 DZC's six pair-helper relations at every `Do` entry, from
its define polynomial vanishing at every draw** (piece (iii) of step 1 of HANDOFF_20261119_1.md, DZC's part).

DZC is standalone (`outcDefDZC_ok`): `eq·(g·(μ0·c0 + μ1·c1 + μ2·c2) + Σ_k μ_{3+k}·pair_k + μ9·(1 − g)·Σ_r ζ^r·plane_r)`.
At a Boolean `eq` point `(c, 0)` the batched value is affine in each `μ_{3+k}` with coefficient `pair_k(c)`, so two
batchings that differ only there (`μ_{3+k} = 2` against `1`, every other coordinate `1`) give `pair_k(c) = 0`.

The table side is read through the WHOLE table list (`stgΦB_sa_evalL`, no `match` on the table index): DZC's readers
sit at symbolic indices (`15 + k`, `2 + r`) on which a `match` would not reduce.

* `stgΦB_sa_evalL`: `stgΦB_sa_eval` with the table side read through the whole list;
* `dzcPairG`, `dzcHsK`, `dzcRestG`: DZC's pair term, its helper sum and its polynomial after the `eq` factor, read in
  `K` at the batching `m` (`m j` the draw after the `ldo` point coordinates);
* **`dzcRestG_pair`**: two batchings that differ only at `3 + k` differ by `(m'_{3+k} − m_{3+k})·pair_k`;
* `stgWords_take_congr`, `outcDzcRest`;
* **`outc_dzc_pairs`**: `pair_k = 0` at every cube point `(c, 0)` and every `k < 6`, the tables read after the `eq`
  table (index `idx − 1`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutLzc

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

/-! ## 1. `stgΦB` at one draw, the table side read through the whole list -/

section EvalL

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

open Classical in
/-- **A STANDALONE `stgΦB` AT ONE DRAW IS ITS TABLE SIDE'S CUBE SUM**, the tables read through the whole list
(the `eq` table first). -/
theorem stgΦB_sa_evalL {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P0 P : Block.BlockParams) (hP : StgSame P0 P)
    (lc h Q eC rA rH iA iH : ℕ) (pOk : Block.Priv → Prop)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : P.logCols ≤ lc) (hIOd : StgCsIODeg U hbij P.endpointLogN pOk csIO)
    (bga : Fp2 × Fp2 × Fp2) (hd : List (List Fp2)) (k n e sdeg m : ℕ)
    (hhd : hd.length = k) (hmn : m ≤ n)
    (hkind : P.kind k = .standalone) (hsh : Block.slotShape P k = (n, e, sdeg))
    (restTabs : List Block.Tab) (poly : List Fp2 → Fp2) (y : Fin (P0.draws k) → K)
    (hdef : P.define k ⟨bga.1, bga.2.1, bga.2.2, hd⟩ (stgWords U hbij y)
      = .ok ⟨.eq ((stgWords U hbij y).take m) 0 :: restTabs, poly, []⟩)
    (hok : ∀ t ∈ restTabs, TabPrivOK pOk t)
    (hcan : ∀ t ∈ restTabs, ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon)
    (polyK : (ℕ → K) → K)
    (hpK : ∀ vals : List Fp2, (∀ a ∈ vals, a.Canon) →
      (poly vals).toK U = polyK (fun idx => (vals.map (Fp2.toK U)).getD idx 0))
    (hpDeg : ∀ g : ℕ → (Fin (stgN P0 k) → K) → K,
      (∀ idx, IndDegLE 1 (g idx)) → IndDegLE sdeg (fun x => polyK (fun idx => g idx x))) :
    stgΦB U hbij P0 P (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) bga hd k (stgWords U hbij y)
      = if tabsFit n restTabs then
          cubeSum (fun x : Fin (stgN P0 k) → K => polyK (fun idx =>
            ((.eq ((stgWords U hbij y).take m) 0 :: restTabs).map (stgTabK U hbij P
              (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) n e x)).getD idx 0))
        else 0 := by
  set cs := stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v with hcs
  have htake : (hd ++ [stgWords U hbij y]).take k = hd := by
    rw [List.take_append_of_le_length (by omega), List.take_of_length_le (by omega)]
  have hgetD : (hd ++ [stgWords U hbij y]).getD k [] = stgWords U hbij y := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_append_right (by omega)]
    simp [hhd]
  have hdef' : P.define k ⟨bga.1, bga.2.1, bga.2.2, (hd ++ [stgWords U hbij y]).take k⟩
      ((hd ++ [stgWords U hbij y]).getD k [])
      = .ok ⟨.eq ((stgWords U hbij y).take m) 0 :: restTabs, poly, []⟩ := by
    rw [htake, hgetD]; exact hdef
  have hok' : ∀ t ∈ (.eq ((stgWords U hbij y).take m) 0 :: restTabs), TabPrivOK pOk t := by
    intro t ht; rcases List.mem_cons.mp ht with rfl | ht
    · intro p hp; cases hp
    · exact hok t ht
  have hcan' : ∀ t ∈ (.eq ((stgWords U hbij y).take m) 0 :: restTabs), ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon := by
    intro t ht pt s he; rcases List.mem_cons.mp ht with rfl | ht
    · cases he; exact fun a ha => stgWords_canon U hbij y a (List.mem_of_mem_take ha)
    · exact hcan t ht pt s he
  obtain ⟨heqSp, hdegSp⟩ := stgSpT_eval_and_deg U hbij hU tag h64 P0 P hP
    lc h Q eC rA rH iA iH pOk csIO v hlc hIOd bga (hd ++ [stgWords U hbij y]) k n e sdeg hsh _ _ _ hdef' hok' hcan'
    polyK hpK hpDeg
  have hguard : IndDegLE (Block.slotShape P0 k).2.2 (stgSpT U hbij P0 P cs bga (hd ++ [stgWords U hbij y]) k)
      ∧ ∀ hk ∈ ([] : List (ℕ × Fp2)), IndDegLE (Block.slotShape P0 hk.1).2.2
          (stgSpT U hbij P0 P cs bga (hd ++ [stgWords U hbij y]) hk.1) :=
    ⟨hdegSp, fun _ hm => absurd hm List.not_mem_nil⟩
  unfold stgΦB
  rw [hdef]
  dsimp only
  rw [ite_eq_left hguard, hkind]
  dsimp only
  rw [heqSp]
  have hfit_iff : tabsFit n (.eq ((stgWords U hbij y).take m) 0 :: restTabs) ↔ tabsFit n restTabs := by
    constructor
    · exact fun hf t ht => hf t (List.mem_cons_of_mem _ ht)
    · intro hf t ht
      rcases List.mem_cons.mp ht with rfl | ht
      · show 0 + ((stgWords U hbij y).take m).length ≤ n
        rw [List.length_take, stgWords_length]; omega
      · exact hf t ht
  by_cases hfit : tabsFit n restTabs
  · have hfit' : tabsFit n (.eq ((stgWords U hbij y).take m) 0 :: restTabs) := hfit_iff.mpr hfit
    simp only [hfit, hfit', ↓reduceIte]
    rfl
  · have hfit' : ¬ tabsFit n (.eq ((stgWords U hbij y).take m) 0 :: restTabs) := fun hf => hfit (hfit_iff.mp hf)
    simp only [hfit, hfit', ↓reduceIte]
    unfold cubeSum; simp

/-- The canonical words of two points that agree below `n` agree below `n`. -/
theorem stgWords_take_congr {N : ℕ} (y y' : Fin N → K) (n : ℕ) (h : ∀ i : Fin N, i.val < n → y i = y' i) :
    (stgWords U hbij y).take n = (stgWords U hbij y').take n := by
  unfold stgWords
  apply List.ext_getElem (by simp)
  intro i h1 h2
  have hi : i < n := by simp at h1; omega
  simp only [List.getElem_take, List.getElem_ofFn]
  exact congrArg _ (h _ hi)

end EvalL

/-! ## 2. DZC's polynomial after the `eq` factor, and one pair isolated -/

section Poly

variable {K : Type} [Field K] [Algebra GF K]

/-- DZC's pair term `k` (`h·d1·d2 − (d1 + d2)`, lookups `2k`, `2k + 1`) on a table reader `g`. -/
noncomputable def dzcPairG (U alphaK gK : K) (g : ℕ → K) (kk : ℕ) : K :=
  let d1 := denK U alphaK gK g (2 + (dzcLks.getD (2 * kk) (0, 0, 0)).1) (dzcLks.getD (2 * kk) (0, 0, 0)).2.1
    (dzcLks.getD (2 * kk) (0, 0, 0)).2.2
  let d2 := denK U alphaK gK g (2 + (dzcLks.getD (2 * kk + 1) (0, 0, 0)).1) (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.1
    (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.2
  ((g (15 + kk) * d1) * d2) - (d1 + d2)

/-- DZC's helper sum at the batching `m`. -/
noncomputable def dzcHsK (U alphaK gK : K) (m g : ℕ → K) : K :=
  ∑ kk ∈ Finset.range 6, if _hkk : kk < 6 then m (3 + kk) * dzcPairG U alphaK gK g kk else 0

/-- **DZC's polynomial after the `eq` factor** at the batching `m` (`m j` the `j`-th draw after the point). -/
noncomputable def dzcRestG (U alphaK gK kNumK kDvK kDenK : K) (m g : ℕ → K) : K :=
  let rh := lbK g 4
  let sg := lbK g 8
  let kd := g 14 * kDenK
  let c0 := (((g 2 * kNumK) + (g 14 * kDvK)) - (kd * g 5)) - rh
  let c1 := ((sg + rh) + 1) - kd
  let c2 := ((g 2 + (kI 32768).toK U) - g 3) - (g 4 * mbC 256)
  let clauses := (((m 0 * c0) + (m 1 * c1)) + (m 2 * c2))
  let padK := (1 - g 1) * (∑ r ∈ Finset.range 12, g (2 + r) * (m 10) ^ r)
  ((g 1 * clauses) + dzcHsK U alphaK gK m g) + (m 9 * padK)

/-- **Two batchings that differ only at `3 + k` differ by `pair_k`'s multiple.** -/
theorem dzcRestG_pair (U alphaK gK kNumK kDvK kDenK : K) (m m' g : ℕ → K) (k : ℕ) (hk : k < 6)
    (hs : ∀ j, j ≠ 3 + k → m' j = m j) :
    dzcRestG U alphaK gK kNumK kDvK kDenK m' g - dzcRestG U alphaK gK kNumK kDvK kDenK m g
      = (m' (3 + k) - m (3 + k)) * dzcPairG U alphaK gK g k := by
  have hS : dzcHsK U alphaK gK m' g - dzcHsK U alphaK gK m g = (m' (3 + k) - m (3 + k)) * dzcPairG U alphaK gK g k := by
    unfold dzcHsK
    rw [← Finset.sum_sub_distrib, Finset.sum_eq_single k]
    · simp only [hk, ↓reduceDIte]
      ring
    · intro b hb hbk
      have hb6 : b < 6 := Finset.mem_range.mp hb
      rw [hs (3 + b) (by omega)]
      simp only [hb6, ↓reduceDIte, sub_self]
    · intro h
      exact absurd (Finset.mem_range.mpr hk) h
  unfold dzcRestG
  dsimp only
  rw [hs 0 (by omega), hs 1 (by omega), hs 2 (by omega), hs 9 (by omega), hs 10 (by omega)]
  linear_combination hS

/-- `dzcPairG` reads its reader at three indices only. -/
theorem dzcPairG_congr (U alphaK gK : K) (g g' : ℕ → K) (kk : ℕ) (hg : ∀ i, 1 ≤ i → g i = g' i) :
    dzcPairG U alphaK gK g kk = dzcPairG U alphaK gK g' kk := by
  unfold dzcPairG denK
  rw [hg (2 + (dzcLks.getD (2 * kk) (0, 0, 0)).1) (by omega),
    hg (2 + (dzcLks.getD (2 * kk + 1) (0, 0, 0)).1) (by omega), hg (15 + kk) (by omega)]

end Poly

/-! ## 3. OUTC-05 DZC's pairs at every cube point -/

section Dzc

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- OUTC-05 DZC's tables after its `eq` table (`outcDefDZC_ok`): `supp`, the twelve `Do` planes, `D` (fixed), the six
pair helpers. -/
def outcDzcRest (O : OutcPub) (G : OutcGeo) : List Block.Tab :=
  .pub (supp O.d (2 ^ O.ldo)) :: (
    ((List.range' ocC_X (ocC_MULT - ocC_X)).zipIdx 0).map (fun p =>
      Block.Tab.priv ⟨.a, [((outcLay O G.bLogN).aOff p.1, Fp2.one)], (outcLay O G.bLogN).aLog.getD p.1 0,
        rhoC 0 ((outcLay O G.bLogN).aLog.getD p.1 0), (outcLay O G.bLogN).aMaskBase + 2 * ((outcLay O G.bLogN).prefixA 5 + p.2),
        0⟩)
    ++ [.priv ⟨.a, [((outcLay O G.bLogN).aOff ocC_D, Fp2.one)], (outcLay O G.bLogN).aLog.getD ocC_D 0,
        fixedC (List.replicate OutcPub.toLog Fp2.zero),
        (outcLay O G.bLogN).aMaskBase
          + 2 * ((outcLay O G.bLogN).prefixA 5 + (0 + (List.range' ocC_X (ocC_MULT - ocC_X)).length)), 0⟩]
    ++ ((List.range 6).zipIdx 0).map (fun p =>
      let pl := ocH_D0 + p.1
      Block.Tab.priv ⟨.h, [(((outcLay O G.bLogN).hOff pl).1, Fp2.one), (((outcLay O G.bLogN).hOff pl).2, Block.fp2U)],
        (outcLay O G.bLogN).hLog.getD pl 0, rhoC 0 ((outcLay O G.bLogN).hLog.getD pl 0),
        (outcLay O G.bLogN).hMaskBase + 2 * ((outcLay O G.bLogN).prefixH 5 + p.2), 0⟩))

/-- **OUTC-05 DZC'S PAIR RELATIONS AT EVERY CUBE POINT, from its define polynomial vanishing at every draw.** -/
theorem outc_dzc_pairs {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P0 : Block.BlockParams) (Vo : OutcV) (hP : StgSame P0 Vo.bp) (ch : List Fp2) (hch : ∀ a ∈ ch, a.Canon)
    (lc h Q eC rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : Vo.pub.lt ≤ lc) (hd : List (List Fp2)) (hhd : hd.length = 5)
    (hzero : ∀ y : Fin (P0.draws 5) → K, stgΦB U hbij P0 Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
      (OutcV.bga ch) hd 5 (stgWords U hbij y) = 0)
    (ld : ℕ) (hld0 : Vo.pub.ldo = ld) (c : Fin ld → Bool) (k : ℕ) (hk : k < 6) :
    dzcPairG U ((ch.getD 1 Fp2.zero).toK U) (((ch.getD 0 Fp2.zero).mulBase (Fp.new (UInt64.ofNat tagU8))).toK U)
      (fun idx => ((outcDzcRest Vo.pub Vo.geo).map
        (stgTabK U hbij Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) ld 1
          (fun i : Fin (stgN P0 5) => (bit (cptS ld c i) : K)))).getD (idx - 1) 0) k = 0 := by
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
  -- two batchings that differ only at `3 + k`
  let m1 : ℕ → K := fun _ => 1
  let m2 : ℕ → K := fun j => if j = 3 + k then 2 else 1
  have h2 : (2 : K) ≠ 0 := ZK60.Exec.two_ne_zero_K (K := K)
  have hm1 : ∀ j, j < 11 → m1 j ≠ 0 := fun _ _ => one_ne_zero
  have hm2 : ∀ j, j < 11 → m2 j ≠ 0 := by
    intro j _
    show (if j = 3 + k then (2 : K) else 1) ≠ 0
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
  have hp := dzcRestG_pair U (alpha.toK U) (gU8.toK U) (kNum.toK U) (kDv.toK U) (kDen.toK U) m1 m2 (gOf (yOf m1)) k hk
    (fun j hj => by
      show (if j = 3 + k then (2 : K) else 1) = 1
      exact ite_eq_right hj)
  rw [e1, e2, sub_zero] at hp
  have hm23 : m2 (3 + k) - m1 (3 + k) = 1 := by
    show (if 3 + k = 3 + k then (2 : K) else 1) - 1 = 1
    rw [ite_eq_left rfl]
    norm_num
  rw [hm23, one_mul] at hp
  have hcg : dzcPairG U (alpha.toK U) (gU8.toK U) (fun idx => ((outcDzcRest O G).map
        (stgTabK U hbij Vo.bp cs ldo 1 (fun i : Fin (stgN P0 5) => (bit (cptS ldo c i) : K)))).getD (idx - 1) 0) k
      = dzcPairG U (alpha.toK U) (gU8.toK U) (gOf (yOf m1)) k := by
    refine dzcPairG_congr U _ _ _ _ k (fun i hi => ?_)
    obtain ⟨j, rfl⟩ : ∃ j, i = j + 1 := ⟨i - 1, by omega⟩
    rfl
  rw [hcg]
  exact hp.symm

end Dzc

end ZK60.ProtocolClassify
