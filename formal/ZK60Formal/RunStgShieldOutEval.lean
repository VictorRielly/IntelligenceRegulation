/-
D63 lane L63 (2026-11-19), L63 leg 12, part 80: **OUT-C's define polynomial `stgΦB` at one draw, and OUTC-06 TAB's
relation and pads at every cube point** (piece (iii) of step 1 of HANDOFF_20261119_1.md, TAB's part; the twins of
`stgΦBC_sa_eval` (RunStgShieldIncEval.lean), `inc_tzc_clauses` (RunStgShieldIncTzc.lean) and `shdTzcR_vals`
(RunStgShieldIncIdT.lean) at OUT-C, whose define polynomial `sshΦO` is `stgΦB`, not `stgΦBC`).

* **`stgΦB_sa_eval`**: a standalone define polynomial at one draw is its table side's cube sum;
* **`stgΦB_host_eval`**: a host define polynomial at one draw is its table side's cube sum minus the hosted slot's
  cube sum times `ν` (the second half of lane L65's `offZero_host_draw`, kept explicit at one `y`);
* `outcTabRest`; **`outc_tab_clauses`**: OUTC-06 TAB's relation `h·(α − tv) − m` and its two pads `(1 − supp)·m`,
  `(1 − supp)·h` at every cube point `(c, 0)`, from its define polynomial vanishing at every draw;
* **`outc_tab_vals`**: TAB's four table values at `(c, 0)` are `supp_256` at `c`, `tv = (c mod 256) + γ·TAG_U8`, the
  `A_out` multiplicity plane and the `H_out` helper `h_gu8` (`shdOutcA`, `shdOutcHd`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutCube

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

/-! ## 1. `stgΦB` at one draw -/

section Eval

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

open Classical in
/-- **A STANDALONE `stgΦB` AT ONE DRAW IS ITS TABLE SIDE'S CUBE SUM.** -/
theorem stgΦB_sa_eval {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P0 P : Block.BlockParams) (hP : StgSame P0 P)
    (lc h Q eC rA rH iA iH : ℕ) (pOk : Block.Priv → Prop)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : P.logCols ≤ lc) (hIOd : StgCsIODeg U hbij P.endpointLogN pOk csIO)
    (bga : Fp2 × Fp2 × Fp2) (hd : List (List Fp2)) (k n e sdeg m : ℕ)
    (hhd : hd.length = k) (hm : m ≤ P0.draws k) (hmn : m ≤ n)
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
          cubeSum (fun x : Fin (stgN P0 k) → K => polyK (fun idx => match idx with
            | 0 => eqDrawK m n e hm y x
            | j + 1 => (restTabs.map (stgTabK U hbij P
                (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) n e x)).getD j 0))
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
    congr 1; funext x; congr 1; funext idx
    cases idx with
    | zero => exact stgTabK_eq_draw U hbij P cs m n e hm hmn y x
    | succ j => rfl
  · have hfit' : ¬ tabsFit n (.eq ((stgWords U hbij y).take m) 0 :: restTabs) := fun hf => hfit (hfit_iff.mp hf)
    simp only [hfit, hfit', ↓reduceIte]
    unfold cubeSum; simp

open Classical in
/-- **A HOST `stgΦB` AT ONE DRAW IS ITS TABLE SIDE'S CUBE SUM MINUS `ν` TIMES THE HOSTED SLOT'S.** -/
theorem stgΦB_host_eval {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P0 P : Block.BlockParams) (hP : StgSame P0 P)
    (lc h Q eC rA rH iA iH : ℕ) (pOk : Block.Priv → Prop)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : P.logCols ≤ lc) (hIOd : StgCsIODeg U hbij P.endpointLogN pOk csIO)
    (bga : Fp2 × Fp2 × Fp2) (hd : List (List Fp2)) (k hSlot nuIdx n e sdeg m : ℕ)
    (hhd : hd.length = k) (hhSlot : hSlot < k) (hnu : nuIdx < P0.draws k)
    (hm : m ≤ P0.draws k) (hmn : m ≤ n)
    (hkind : P.kind k = .host) (hsh : Block.slotShape P k = (n, e, sdeg))
    (hdegH : IndDegLE (Block.slotShape P0 hSlot).2.2
      (stgSpT U hbij P0 P (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) bga hd hSlot))
    (restTabs : List Block.Tab) (poly : List Fp2 → Fp2) (y : Fin (P0.draws k) → K)
    (hdef : P.define k ⟨bga.1, bga.2.1, bga.2.2, hd⟩ (stgWords U hbij y)
      = .ok ⟨.eq ((stgWords U hbij y).take m) 0 :: restTabs, poly,
          [(hSlot, (stgWords U hbij y).getD nuIdx Fp2.zero)]⟩)
    (hok : ∀ t ∈ restTabs, TabPrivOK pOk t)
    (hcan : ∀ t ∈ restTabs, ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon)
    (polyK : (ℕ → K) → K)
    (hpK : ∀ vals : List Fp2, (∀ a ∈ vals, a.Canon) →
      (poly vals).toK U = polyK (fun idx => (vals.map (Fp2.toK U)).getD idx 0))
    (hpDeg : ∀ g : ℕ → (Fin (stgN P0 k) → K) → K,
      (∀ idx, IndDegLE 1 (g idx)) → IndDegLE sdeg (fun x => polyK (fun idx => g idx x))) :
    stgΦB U hbij P0 P (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) bga hd k (stgWords U hbij y)
      = (if tabsFit n restTabs then
          cubeSum (fun x : Fin (stgN P0 k) → K => polyK (fun idx => match idx with
            | 0 => eqDrawK m n e hm y x
            | j + 1 => (restTabs.map (stgTabK U hbij P
                (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) n e x)).getD j 0))
        else 0)
        - y ⟨nuIdx, hnu⟩ * cubeSum (stgSpT U hbij P0 P (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) bga hd hSlot) := by
  set cs := stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v with hcs
  have htake : (hd ++ [stgWords U hbij y]).take k = hd := by
    rw [List.take_append_of_le_length (by omega), List.take_of_length_le (by omega)]
  have hgetD : (hd ++ [stgWords U hbij y]).getD k [] = stgWords U hbij y := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_append_right (by omega)]
    simp [hhd]
  have hdef' : P.define k ⟨bga.1, bga.2.1, bga.2.2, (hd ++ [stgWords U hbij y]).take k⟩
      ((hd ++ [stgWords U hbij y]).getD k [])
      = .ok ⟨.eq ((stgWords U hbij y).take m) 0 :: restTabs, poly,
          [(hSlot, (stgWords U hbij y).getD nuIdx Fp2.zero)]⟩ := by
    rw [htake, hgetD]; exact hdef
  have hok' : ∀ t ∈ (.eq ((stgWords U hbij y).take m) 0 :: restTabs), TabPrivOK pOk t := by
    intro t ht; rcases List.mem_cons.mp ht with rfl | ht
    · intro p hp; cases hp
    · exact hok t ht
  have hcan' : ∀ t ∈ (.eq ((stgWords U hbij y).take m) 0 :: restTabs), ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon := by
    intro t ht pt s he; rcases List.mem_cons.mp ht with rfl | ht
    · cases he; exact fun a ha => stgWords_canon U hbij y a (List.mem_of_mem_take ha)
    · exact hcan t ht pt s he
  obtain ⟨heqSp, hdegSp⟩ := stgSpT_eval_and_deg U hbij hU tag h64 P0 P hP lc h Q eC rA rH iA iH pOk csIO v
    hlc hIOd bga (hd ++ [stgWords U hbij y]) k n e sdeg hsh _ _ _ hdef' hok' hcan' polyK hpK hpDeg
  have hSpH : stgSpT U hbij P0 P cs bga (hd ++ [stgWords U hbij y]) hSlot = stgSpT U hbij P0 P cs bga hd hSlot :=
    stgSpT_take U hbij P0 P cs bga (hd ++ [stgWords U hbij y]) hd hSlot (List.take_append_of_le_length (by omega))
  have hguard : IndDegLE (Block.slotShape P0 k).2.2 (stgSpT U hbij P0 P cs bga (hd ++ [stgWords U hbij y]) k)
      ∧ ∀ hk ∈ ([(hSlot, (stgWords U hbij y).getD nuIdx Fp2.zero)] : List (ℕ × Fp2)),
          IndDegLE (Block.slotShape P0 hk.1).2.2 (stgSpT U hbij P0 P cs bga (hd ++ [stgWords U hbij y]) hk.1) := by
    refine ⟨hdegSp, fun hk hmem => ?_⟩
    rw [List.mem_singleton] at hmem; subst hmem
    dsimp only
    rw [hSpH]; exact hdegH
  unfold stgΦB
  rw [hdef]
  dsimp only
  rw [ite_eq_left hguard, hkind, heqSp]
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero, hSpH,
    stgWords_getD_toK U hbij y nuIdx hnu]
  have hfit_iff : tabsFit n (.eq ((stgWords U hbij y).take m) 0 :: restTabs) ↔ tabsFit n restTabs := by
    constructor
    · exact fun hf t ht => hf t (List.mem_cons_of_mem _ ht)
    · intro hf t ht
      rcases List.mem_cons.mp ht with rfl | ht
      · show 0 + ((stgWords U hbij y).take m).length ≤ n
        rw [List.length_take, stgWords_length]; omega
      · exact hf t ht
  congr 1
  by_cases hfit : tabsFit n restTabs
  · have hfit' : tabsFit n (.eq ((stgWords U hbij y).take m) 0 :: restTabs) := hfit_iff.mpr hfit
    simp only [hfit, hfit', ↓reduceIte]
    congr 1; funext x; congr 1; funext idx
    cases idx with
    | zero => exact stgTabK_eq_draw U hbij P cs m n e hm hmn y x
    | succ j => rfl
  · have hfit' : ¬ tabsFit n (.eq ((stgWords U hbij y).take m) 0 :: restTabs) := fun hf => hfit (hfit_iff.mp hf)
    simp only [hfit, hfit', ↓reduceIte]
    unfold cubeSum; simp

end Eval

/-! ## 2. OUTC-06 TAB's relation and pads at every cube point -/

section Tab

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- OUTC-06 TAB's tables after its `eq` table (`outcDefTAB_ok`): `supp_256`, `tv`, `A mult`, `H h_gu8`. -/
def outcTabRest (O : OutcPub) (G : OutcGeo) (ch : List Fp2) : List Block.Tab :=
  [.pub (supp OutcPub.u8Len (2 ^ O.ltab)),
   .pub (tvTab (2 ^ O.ltab) ((ch.getD 0 Fp2.zero).mulBase (Fp.new (UInt64.ofNat tagU8)))),
   .priv ⟨.a, [((outcLay O G.bLogN).aOff ocC_MULT, Fp2.one)], (outcLay O G.bLogN).aLog.getD ocC_MULT 0,
     rhoC 0 ((outcLay O G.bLogN).aLog.getD ocC_MULT 0), (outcLay O G.bLogN).aMaskBase + 2 * ((outcLay O G.bLogN).prefixA 6 + 0),
     0⟩,
   .priv ⟨.h, [(((outcLay O G.bLogN).hOff ocH_GU8).1, Fp2.one), (((outcLay O G.bLogN).hOff ocH_GU8).2, Block.fp2U)],
     (outcLay O G.bLogN).hLog.getD ocH_GU8 0, rhoC 0 ((outcLay O G.bLogN).hLog.getD ocH_GU8 0),
     (outcLay O G.bLogN).hMaskBase + 2 * ((outcLay O G.bLogN).prefixH 6 + 0), 0⟩]

/-- **OUTC-06 TAB'S RELATION AND PADS AT EVERY CUBE POINT, from its define polynomial vanishing at every draw.** -/
theorem outc_tab_clauses {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P0 : Block.BlockParams) (Vo : OutcV) (hP : StgSame P0 Vo.bp) (ch : List Fp2) (hch : ∀ a ∈ ch, a.Canon)
    (lc h Q eC rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : Vo.pub.lt ≤ lc) (hd : List (List Fp2)) (hhd : hd.length = 6)
    (hzero : ∀ y : Fin (P0.draws 6) → K, stgΦB U hbij P0 Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
      (OutcV.bga ch) hd 6 (stgWords U hbij y) = 0)
    (lt : ℕ) (hlt0 : Vo.pub.ltab = lt) (c : Fin lt → Bool) :
    let r : ℕ → K := fun j => ((outcTabRest Vo.pub Vo.geo ch).map
      (stgTabK U hbij Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) lt 1
        (fun i : Fin (stgN P0 6) => (bit (cptS lt c i) : K)))).getD j 0
    r 3 * ((ch.getD 1 Fp2.zero).toK U - r 1) - r 2 = 0
      ∧ (1 - r 0) * r 2 = 0
      ∧ (1 - r 0) * r 3 = 0 := by
  subst hlt0
  intro r
  simp only [r]
  revert c
  set O := Vo.pub with hO
  set G := Vo.geo with hG
  set ltab := O.ltab with hltab
  set cs := stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v with hcs
  intro c
  set alpha := ch.getD 1 Fp2.zero with halpha_def
  have hdraws : P0.draws 6 = ltab + 3 := by rw [hP.1]; show ltab + 2 + 1 = ltab + 3; omega
  have hN : stgN P0 6 = ltab + 1 := by unfold stgN; rw [stg_slotShape hP]; rfl
  have halpha : alpha.Canon := Fp2.canon_getD hch 1
  have hj0 : ltab < P0.draws 6 := by omega
  have hj1 : ltab + 1 < P0.draws 6 := by omega
  have hj2 : ltab + 2 < P0.draws 6 := by omega
  have hIO_vac : StgCsIODeg U hbij Vo.bp.endpointLogN (fun _ => False) csIO :=
    fun _ _ _ _ _ _ _ _ _ hf => absurd hf id
  have hfit : tabsFit ltab (outcTabRest O G ch) := by
    intro t ht
    simp only [outcTabRest, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl | rfl | rfl
    · show (supp OutcPub.u8Len (2 ^ ltab)).length = 2 ^ ltab
      simp [supp]
    · show (tvTab (2 ^ ltab) _).length = 2 ^ ltab
      simp [tvTab]
    · trivial
    · trivial
  have hok : ∀ t ∈ outcTabRest O G ch, TabPrivOK (fun _ => False) t := by
    intro t ht
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_a_rho _ _ _ _
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_h_rho _ _ _ _ _
    exact absurd ht List.not_mem_nil
  have hcan : ∀ t ∈ outcTabRest O G ch, ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon := by
    intro t ht pt s he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    exact absurd ht List.not_mem_nil
  refine clauses3_of_combo (ZK60.Exec.two_ne_zero_K (K := K)) _ _ _ ?_
  intro μ0 μ1 ζ h0 h1 h2
  let y : Fin (P0.draws 6) → K := fun i =>
    if hi : i.val < ltab then bit (c ⟨i.val, hi⟩)
    else if i.val = ltab then μ0 else if i.val = ltab + 1 then μ1 else ζ
  have hy0 : y ⟨ltab, hj0⟩ = μ0 := by simp [y]
  have hy1 : y ⟨ltab + 1, hj1⟩ = μ1 := by simp [y]
  have hy2 : y ⟨ltab + 2, hj2⟩ = ζ := by simp [y]
  have hyb : ∀ a (ha : a < ltab), y ⟨a, by omega⟩ = bit (c ⟨a, ha⟩) := by
    intro a ha
    simp [y, ha]
  have hZ : ∀ i ∈ Z_range (P0.draws 6) ltab 3, y i ≠ 0 := by
    intro i hi
    simp only [Z_range, Finset.mem_filter, Finset.mem_univ, true_and] at hi
    by_cases e0 : i.val = ltab
    · have : i = ⟨ltab, hj0⟩ := Fin.ext e0
      rw [this, hy0]; exact h0
    by_cases e1 : i.val = ltab + 1
    · have : i = ⟨ltab + 1, hj1⟩ := Fin.ext e1
      rw [this, hy1]; exact h1
    · have : i = ⟨ltab + 2, hj2⟩ := Fin.ext (by show i.val = ltab + 2; omega)
      rw [this, hy2]; exact h2
  have hdef := outcDefTAB_ok U hbij hU O G ⟨(OutcV.bga ch).1, (OutcV.bga ch).2.1, (OutcV.bga ch).2.2, hd⟩ hdraws y hZ
  have hev := stgΦB_sa_eval U hbij hU tag h64 P0 Vo.bp hP lc h Q eC rA rH iA iH (fun _ => False) csIO v hlc hIO_vac
    (OutcV.bga ch) hd 6 ltab 1 3 ltab hhd (by omega) le_rfl rfl rfl (outcTabRest O G ch)
    (tabPoly (((stgWords U hbij y).drop ltab).take 2) ((stgWords U hbij y).getD (ltab + 2) Fp2.zero) alpha) y hdef
    hok hcan
    (fun g => g 0 * ((y ⟨ltab, hj0⟩ * (g 4 * (alpha.toK U - g 2) - g 3))
      + (y ⟨ltab + 1, hj1⟩ * ((1 - g 1) * (g 3 + y ⟨ltab + 2, hj2⟩ * g 4)))))
    (fun vals hv => by
      unfold tabPoly
      rw [Fp2.toK_mul U hU, Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU, Fp2.toK_mul U hU,
          vg_drop_take_toK U hbij y ltab 2 0 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y ltab 2 1 (by norm_num) (by omega),
          Fp2.toK_sub U _ _ (Fp2.canon_mul _ _) (vg_canon hv 3),
          Fp2.toK_mul U hU, Fp2.toK_sub U _ _ halpha (vg_canon hv 2),
          Fp2.toK_mul U hU, Fp2.toK_sub U _ _ Fp2.canon_one (vg_canon hv 1), Fp2.toK_one,
          Fp2.toK_add U _ _ (vg_canon hv 3) (Fp2.canon_mul _ _), Fp2.toK_mul U hU,
          stgWords_getD_toK U hbij y (ltab + 2) hj2]
      simp only [vg_toK_map]
      rfl)
    (fun g hg => by
      have hrel : IndDegLE 2 (fun x => g 4 x * (alpha.toK U - g 2 x) - g 3 x) :=
        IndDegLE.sub (IndDegLE.mul (hg 4) (IndDegLE.sub (IndDegLE.const _) (hg 2)))
          (IndDegLE.mono (hg 3) (by norm_num))
      have hpad : IndDegLE 2 (fun x => (1 - g 1 x) * (g 3 x + y ⟨ltab + 2, hj2⟩ * g 4 x)) :=
        IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) (hg 1))
          (IndDegLE.add (hg 3) (IndDegLE.cmul _ (hg 4)))
      exact IndDegLE.mono (IndDegLE.mul (hg 0) (IndDegLE.add (IndDegLE.cmul _ hrel) (IndDegLE.cmul _ hpad)))
        (by norm_num))
  rw [hzero y, ite_eq_left hfit] at hev
  set F : (Fin (stgN P0 6) → K) → K := fun x =>
    let r' : ℕ → K := fun j => ((outcTabRest O G ch).map (stgTabK U hbij Vo.bp cs ltab 1 x)).getD j 0
    (y ⟨ltab, hj0⟩ * (r' 3 * (alpha.toK U - r' 1) - r' 2))
      + (y ⟨ltab + 1, hj1⟩ * ((1 - r' 0) * (r' 2 + y ⟨ltab + 2, hj2⟩ * r' 3))) with hF
  have hcube := cube_eqDraw_single (M := P0.draws 6) (N := stgN P0 6) ltab (by omega) hN y c hyb F
  have hev' : (0 : K) = cubeSum (fun x : Fin (stgN P0 6) → K => eqDrawK ltab ltab 1 (by omega) y x * F x) := hev
  rw [hcube, hF] at hev'
  dsimp only at hev'
  rw [hy0, hy1, hy2] at hev'
  linear_combination (-1 : K) * hev'

end Tab

/-! ## 3. TAB's table values at `(c, 0)` -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- TAB's table values at `(c, 0)` on `N` variables (`outc_tab_clauses`' `r` at `ltab = 12`). -/
noncomputable def shdTabR (Vo : OutcV) (ch : List Fp2) (cs : Block.Cm → Block.ZClaim → K) (N : ℕ)
    (c : Fin 12 → Bool) (j : ℕ) : K :=
  ((outcTabRest Vo.pub Vo.geo ch).map
    (stgTabK U hbij Vo.bp cs 12 1 (fun i : Fin N => (bit (cptS 12 c i) : K)))).getD j 0

/-- `γ·TAG_U8` in `K`. -/
theorem gU8_toK (ch : List Fp2) :
    ((ch.getD 0 Fp2.zero).mulBase (Fp.new (UInt64.ofNat tagU8))).toK U
      = (ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF) := by
  rw [Fp2.toK_mulBase, Fp.new_toGF_ofNat _ (by unfold tagU8; norm_num)]

/-- **TAB'S TABLES AT `(c, 0)` ARE `supp_256`, `tv`, THE `A_out` MULTIPLICITY PLANE AND THE HELPER `h_gu8`.** -/
theorem outc_tab_vals (hU : U ^ 2 = algebraMap GF K 7) (O : OutcPub) (Vo : OutcV) (rA rH iA iH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (w : StgVw Lq) (ch : List Fp2)
    (hGb : Vo.geo.bLogN = 14) (hOL : outcLay Vo.pub 14 = outcLay O 14) (hltab : Vo.pub.ltab = 12)
    (hlc : 0 < Vo.bp.logCols) {N : ℕ} (hN : N = 13) (c : Fin 12 → Bool) :
    let cs := stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w
    shdTabR U hbij Vo ch cs N c 0 = (if msbIndex 12 c < 256 then 1 else 0)
      ∧ shdTabR U hbij Vo ch cs N c 1
        = ((msbIndex 12 c % 256 : ℕ) : K) + (ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF)
      ∧ shdTabR U hbij Vo ch cs N c 2 = shdOutcA U tag h64 O rA iA ocC_MULT w c
      ∧ shdTabR U hbij Vo ch cs N c 3 = (shdOutcHd U tag h64 O rH iH w).2.2.1 c := by
  intro cs
  set P' := Vo.bp with hP'
  have hidx : msbIndex 12 c < 2 ^ Vo.pub.ltab := by rw [hltab]; exact msbIndex_lt 12 c
  have hsn : 2 ^ Vo.pub.ltab = 2 ^ 12 := by rw [hltab]
  have hNlt : 12 < N := by omega
  have hal : (outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_MULT 0 = 12 := by
    rw [← hltab]; rfl
  have hhl : (outcLay Vo.pub Vo.geo.bLogN).hLog.getD ocH_GU8 0 = 12 := by
    rw [← hltab]; rfl
  have hpub : ∀ pv : List Fp2, pv.length = 2 ^ Vo.pub.ltab →
      stgTabK U hbij P' cs 12 1 (fun i : Fin N => (bit (cptS 12 c i) : K)) (.pub pv)
        = (pv.getD (msbIndex 12 c) Fp2.zero).toK U := by
    intro pv hpv
    exact stgTabK_pub_cptS U hbij P' cs 12 c hN pv (by rw [hpv, hsn])
  refine ⟨?_, ?_, ?_, ?_⟩
  · -- `supp_256`
    show stgTabK U hbij P' cs 12 1 _ (.pub (supp OutcPub.u8Len (2 ^ Vo.pub.ltab))) = _
    rw [hpub _ (by simp [supp]), supp_getD_toK U _ _ _ hidx]
    rfl
  · -- `tv`
    show stgTabK U hbij P' cs 12 1 _
      (.pub (tvTab (2 ^ Vo.pub.ltab) ((ch.getD 0 Fp2.zero).mulBase (Fp.new (UInt64.ofNat tagU8))))) = _
    rw [hpub _ (by simp [tvTab])]
    unfold tvTab
    rw [rangeMap_getD _ _ hidx]
    rw [Fp2.toK_add U _ _ (kI_canon _) (Fp2.canon_mulBase _ _),
      kI_nat_toK U _ (by have := msbIndex_lt 12 c; omega), gU8_toK U ch]
  · -- the `A_out` multiplicity plane
    show stgTabK U hbij P' cs 12 1 _
      (.priv ⟨.a, [((outcLay Vo.pub Vo.geo.bLogN).aOff ocC_MULT, Fp2.one)],
        (outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_MULT 0, rhoC 0 ((outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_MULT 0),
        (outcLay Vo.pub Vo.geo.bLogN).aMaskBase + 2 * ((outcLay Vo.pub Vo.geo.bLogN).prefixA 6 + 0), 0⟩) = _
    refine (stgTabK_priv_cptS U hbij hU P' cs rA ogStage.lc ogStage.Q
      (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA w) (by decide) 12 c hN _ (by intro _; rfl)
      (by exact List.cons_ne_nil _ _) (by show 0 < (outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_MULT 0; omega)
      (by simp [rhoC]) (by exact hlc)
      (by intro c' hc w' hw; simp [rhoC] at hc; obtain ⟨_, _, rfl⟩ := hc; cases hw)).trans ?_
    rw [privZ_eq_planeZ U _ _ _ _ 12 c hNlt _ [((outcLay O 14).aOff ocC_MULT, Fp2.one)] .a
      (by show [((outcLay Vo.pub Vo.geo.bLogN).aOff ocC_MULT, Fp2.one)] = _; rw [hGb, hOL]) hal rfl]
    rfl
  · -- the helper `h_gu8`
    show stgTabK U hbij P' cs 12 1 _
      (.priv ⟨.h, [(((outcLay Vo.pub Vo.geo.bLogN).hOff ocH_GU8).1, Fp2.one),
          (((outcLay Vo.pub Vo.geo.bLogN).hOff ocH_GU8).2, Block.fp2U)],
        (outcLay Vo.pub Vo.geo.bLogN).hLog.getD ocH_GU8 0, rhoC 0 ((outcLay Vo.pub Vo.geo.bLogN).hLog.getD ocH_GU8 0),
        (outcLay Vo.pub Vo.geo.bLogN).hMaskBase + 2 * ((outcLay Vo.pub Vo.geo.bLogN).prefixH 6 + 0), 0⟩) = _
    refine (stgTabK_priv_cptS U hbij hU P' cs rH ogStage.lc ogStage.Q
      (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w) (by decide) 12 c hN _ (by intro _; rfl)
      (by exact List.cons_ne_nil _ _) (by show 0 < (outcLay Vo.pub Vo.geo.bLogN).hLog.getD ocH_GU8 0; omega)
      (by simp [rhoC]) (by exact hlc)
      (by intro c' hc w' hw; simp [rhoC] at hc; obtain ⟨_, _, rfl⟩ := hc; cases hw)).trans ?_
    rw [privZ_eq_planeZ U _ _ _ _ 12 c hNlt _
      [(((outcLay O 14).hOff ocH_GU8).1, Fp2.one), (((outcLay O 14).hOff ocH_GU8).2, Block.fp2U)] .h
      (by show [(((outcLay Vo.pub Vo.geo.bLogN).hOff ocH_GU8).1, Fp2.one),
          (((outcLay Vo.pub Vo.geo.bLogN).hOff ocH_GU8).2, Block.fp2U)] = _; rw [hGb, hOL]) hhl rfl]
    rfl

end Vals

end ZK60.ProtocolClassify
