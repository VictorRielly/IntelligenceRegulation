/-
D63 lane L63 (2026-11-18), part 50: **stage IN-C's LogUp predicate over the UNPROJECTED data** (finding L63-6, item 4 of
HANDOFF_20261118_1.md).

Finding L63-6 (ARGUED, see HANDOFF_20261118_2.md section 3): `shd_ΛI` (lane L67b's `RunStgShieldLu.lean`, not edited)
reads the token words, the `B_in` rows and the multiplicities through `piB`, a `GF`-linear projection `K → GF`, while
the stage's slots (SIC_QZC, SIC_TZC, through `stgCsv`'s `claimSem` of the decoded rows) constrain the UNPROJECTED values
in `K`. A run whose committed `A_MULT` (or `B_in`) values lie outside `GF`, whose helpers meet the slot relations over
`K` and whose `K`-valued LogUp identity holds at the drawn challenges (an escape, but an accepted run with no doomed
entrant of the eight earlier kinds) need not meet the PROJECTED identity there: `hLI_stg` at `shd_ΛI` is then false at
that run. The relation the slots give pointwise is the one over the `K`-valued data. This file states it:

* `incClearedPolyG φ D`: Antigravity's `incClearedPoly` at any ring map `φ : B →+* K` (`incClearedPoly_eq_G`: the old
  one is `φ := algebraMap GF K`); `incClearedPolyG_indDeg`;
* `stgLkInG φ Dof`, **`stgLkInG_rbr`** (`.Rbr` at `shdP_eI`), **`stgLkInG_of_inLogUp`** (bridge 1),
  **`not_stgLkInG_nil_of_not_inGood`** (bridge 2) at any `φ`;
* `stgPlK`, **`shdIncDataK`**: the `K`-valued IN-C data (`tok`, `X`, `m` the planes BEFORE `piB`; the public fields the
  images of `shdIncData`'s); `shdIncData_proj_*`: `shdIncData` is its projection (`rfl`);
* **`inGood_proj`**: `InGood (shdIncDataK …) → InGood (shdIncData …)` (a `K`-valued good lookup has base-field words,
  rows and classes, so the projection loses nothing); **`not_stgLkInK_nil_of_not_inGood`**: `¬ InGood (shdIncData …)`
  makes the `K`-valued LogUp entrant doomed (the `hdinX` direction is kept);
* `shd_ΛIK`, `ShdLuInAtK`, **`stgLkAtV_of_luInK`**: the corrected `ΛI` and the exact statement `hLI_stg` needs at it
  (defined, not assumed).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldLuRd

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open Finset
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.StageX
open ZK60.Exec.StageV (IncPub incLay incA_TOK incA_MULT tagEmb)
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)

/-! ## 1. The cleared LogUp polynomial at any ring map -/

section Gen

/-- Antigravity's `incClearedPoly` at any ring map `φ : B →+* K`. -/
noncomputable def incClearedPolyG {B K : Type} [Field B] [Field K] {ι κ : Type}
    [Fintype ι] [DecidableEq ι] [Fintype κ] [DecidableEq κ]
    (φ : B →+* K) (D : InData B ι κ 12) (y : Fin 15 → K) : K :=
  clearedFull
    (fun t => fold (y 0) (y 1) (qTup φ D (fun c => y ⟨3 + c.val, by omega⟩) t))
    (fun j => fold (y 0) (y 1) (tTup φ D (fun c => y ⟨3 + c.val, by omega⟩) j))
    (fun j => φ (D.m j))
    (y 2)

/-- The old polynomial is the one at `algebraMap GF K`. -/
theorem incClearedPoly_eq_G {K : Type} [Field K] [Algebra GF K] {ι κ : Type}
    [Fintype ι] [DecidableEq ι] [Fintype κ] [DecidableEq κ] (D : InData GF ι κ 12) :
    incClearedPoly (K := K) D = incClearedPolyG (algebraMap GF K) D :=
  rfl

theorem luk_indDeg_finsetProd {K : Type} [Field K] {α : Type} [DecidableEq α] {N d : ℕ}
    (s : Finset α) {f : α → (Fin N → K) → K} (hf : ∀ a ∈ s, IndDegLE d (f a)) :
    IndDegLE (s.card * d) (fun x => ∏ a ∈ s, f a x) := by
  induction s using Finset.induction_on with
  | empty =>
    simpa using (IndDegLE.const (n := N) (d := 0) (1 : K))
  | @insert a s hna ih =>
    have h1 : IndDegLE d (f a) := hf a (Finset.mem_insert_self a s)
    have h2 : IndDegLE (s.card * d) (fun x => ∏ b ∈ s, f b x) :=
      ih (fun b hb => hf b (Finset.mem_insert_of_mem hb))
    have hm := IndDegLE.mul h1 h2
    rw [Finset.card_insert_of_notMem hna, show (s.card + 1) * d = d + s.card * d by ring]
    simpa only [Finset.prod_insert hna] using hm

theorem luk_incFactor_indDeg {K : Type} [Field K] (c0 ctag cz : K) (P : (Fin 12 → Bool) → K) :
    IndDegLE 2 (fun y : Fin 15 → K =>
      y 2 - fold (y 0) (y 1) ⟨c0, ctag, mleAt P (fun c : Fin 12 => y ⟨3 + c.val, by omega⟩), cz⟩) := by
  let σ : Fin 12 → Fin 15 := fun c => ⟨3 + c.val, by omega⟩
  have hσ : Function.Injective σ := fun a b h => Fin.ext (by
    have hv := congrArg Fin.val h
    dsimp [σ] at hv
    omega)
  have hmle : IndDegLE 1 (fun y : Fin 15 → K => mleAt P (fun c => y (σ c))) :=
    ZK60.Sound.SlotW16.indDeg_sel (indDegLE_mleAt P) σ hσ
  have hy0 : IndDegLE 1 (fun y : Fin 15 → K => y 0) := ZK60.Sound.SlotW16.indDeg_coord 0
  have hy1 : IndDegLE 1 (fun y : Fin 15 → K => y 1) := ZK60.Sound.SlotW16.indDeg_coord 1
  have hy2 : IndDegLE 2 (fun y : Fin 15 → K => y 2) := IndDegLE.mono (ZK60.Sound.SlotW16.indDeg_coord 2) (by norm_num)
  have ht0 : IndDegLE 2 (fun _ : Fin 15 → K => c0) := IndDegLE.const c0
  have ht1 : IndDegLE 2 (fun y : Fin 15 → K => y 1 * ctag) :=
    IndDegLE.mono (IndDegLE.mul hy1 (IndDegLE.const (d := 0) ctag)) (by norm_num)
  have ht2 : IndDegLE 2 (fun y : Fin 15 → K => y 0 * mleAt P (fun c => y (σ c))) :=
    IndDegLE.mul hy0 hmle
  have ht3 : IndDegLE 2 (fun y : Fin 15 → K => y 0 ^ 2 * cz) := by
    have hp2 : IndDegLE 2 (fun y : Fin 15 → K => y 0 ^ 2) := by
      simpa using ZK60.Sound.SlotW16.indDeg_pow hy0 2
    simpa using IndDegLE.mul hp2 (IndDegLE.const (d := 0) cz)
  have hfold : IndDegLE 2 (fun y : Fin 15 → K =>
      fold (y 0) (y 1) ⟨c0, ctag, mleAt P (fun c => y (σ c)), cz⟩) := by
    unfold Sound.fold
    exact IndDegLE.add (IndDegLE.add (IndDegLE.add ht0 ht1) ht2) ht3
  exact IndDegLE.sub hy2 hfold

/-- **`incClearedPolyG φ D` has individual degree `≤ 2 · (|ι| + |κ|)`.** -/
theorem incClearedPolyG_indDeg {B K : Type} [Field B] [Field K] {ι κ : Type}
    [Fintype ι] [DecidableEq ι] [Fintype κ] [DecidableEq κ]
    (φ : B →+* K) (D : InData B ι κ 12) :
    IndDegLE (2 * (Fintype.card ι + Fintype.card κ)) (incClearedPolyG φ D) := by
  have hfA : ∀ t : ι, IndDegLE 2 (fun y : Fin 15 → K =>
      y 2 - fold (y 0) (y 1) (qTup φ D (fun c => y ⟨3 + c.val, by omega⟩) t)) :=
    fun t => luk_incFactor_indDeg (φ (D.tok t)) (φ D.tag) (φ (D.cq t)) (fun b => φ (D.X t b))
  have hfT : ∀ j : κ, IndDegLE 2 (fun y : Fin 15 → K =>
      y 2 - fold (y 0) (y 1) (tTup φ D (fun c => y ⟨3 + c.val, by omega⟩) j)) :=
    fun j => luk_incFactor_indDeg (φ (D.vid j)) (φ D.tag) (φ (D.ctl j)) (fun b => φ (D.E j b))
  have hs1 : IndDegLE (2 * (Fintype.card ι + Fintype.card κ)) (fun y : Fin 15 → K =>
      ∑ i : ι, (∏ i' ∈ Finset.univ.erase i,
          (y 2 - fold (y 0) (y 1) (qTup φ D (fun c => y ⟨3 + c.val, by omega⟩) i')))
        * (∏ j : κ, (y 2 - fold (y 0) (y 1) (tTup φ D (fun c => y ⟨3 + c.val, by omega⟩) j)))) := by
    refine ZK60.Sound.SlotW16.indDeg_sum (fun i => ?_)
    have hpA := luk_indDeg_finsetProd (Finset.univ.erase i) (fun i' _ => hfA i')
    have hpT := luk_indDeg_finsetProd (Finset.univ : Finset κ) (fun j _ => hfT j)
    refine IndDegLE.mono (IndDegLE.mul hpA hpT) ?_
    have hcA : (Finset.univ.erase i).card ≤ Fintype.card ι := (Finset.card_erase_le).trans (by simp)
    have hcT : (Finset.univ : Finset κ).card = Fintype.card κ := Finset.card_univ
    omega
  have hs2 : IndDegLE (2 * (Fintype.card ι + Fintype.card κ)) (fun y : Fin 15 → K =>
      ∑ j : κ, φ (D.m j) *
        ((∏ i : ι, (y 2 - fold (y 0) (y 1) (qTup φ D (fun c => y ⟨3 + c.val, by omega⟩) i)))
          * (∏ j' ∈ Finset.univ.erase j,
              (y 2 - fold (y 0) (y 1) (tTup φ D (fun c => y ⟨3 + c.val, by omega⟩) j'))))) := by
    refine ZK60.Sound.SlotW16.indDeg_sum (fun j => IndDegLE.cmul (φ (D.m j)) ?_)
    have hpA := luk_indDeg_finsetProd (Finset.univ : Finset ι) (fun i _ => hfA i)
    have hpT := luk_indDeg_finsetProd (Finset.univ.erase j) (fun j' _ => hfT j')
    refine IndDegLE.mono (IndDegLE.mul hpA hpT) ?_
    have hcA : (Finset.univ : Finset ι).card = Fintype.card ι := Finset.card_univ
    have hcT : (Finset.univ.erase j).card ≤ Fintype.card κ := (Finset.card_erase_le).trans (by simp)
    omega
  unfold incClearedPolyG clearedFull
  exact IndDegLE.sub hs1 hs2

theorem luk_inA_fold_eq {B K : Type} [Field B] [Field K] {V : ℕ} (φ : B →+* K)
    (D : InData B shieldS0.Tok (Fin V) 12) (β γ : K) (r : Fin 12 → K) :
    (fun l => fold β γ (inA φ D r l))
      = Sum.elim (fun t => fold β γ (qTup φ D r t)) (Sum.elim Empty.elim Empty.elim) := by
  funext l
  rcases l with t | e | e
  · rfl
  · exact e.elim
  · exact e.elim

end Gen

/-! ## 2. The stage IN-C predicate at any ring map: `.Rbr` and the two bridges -/

section Pred

variable {B K : Type} [Field B] [Field K] [Algebra GF K] {Lq V : ℕ}

/-- **Stage IN-C's LogUp predicate at the ring map `φ`**: `szSt` of the cleared polynomial of the data `Dof v`. -/
noncomputable def stgLkInG (φ : B →+* K) (Dof : StgVw Lq → InData B shieldS0.Tok (Fin V) 12)
    (v : StgVw Lq) (τ : List (List UInt8 × K)) : Prop :=
  Exec.szSt (incClearedPolyG φ (Dof v)) τ

/-- The old predicate is the one at `algebraMap GF K`. -/
theorem stgLkIn_eq_G (Dof : StgVw Lq → InData GF shieldS0.Tok (Fin V) 12) :
    stgLkIn (K := K) Dof = stgLkInG (algebraMap GF K) Dof :=
  rfl

/-- **`.Rbr` at `shdP_eI = 2^19`** at any ring map, whenever `V ≤ 2^17`. -/
theorem stgLkInG_rbr [Fintype K] [DecidableEq K] (φ : B →+* K) (hdrLen : ℕ) (absOf : QB Lq → Option (List UInt8))
    (Dof : StgVw Lq → InData B shieldS0.Tok (Fin V) 12) (hV : V ≤ 2 ^ 17) :
    (stgLkSqV 15 hdrLen shdP_eI absOf (stgLkInG φ Dof)).Rbr := by
  refine stgLkSqV_rbr 15 hdrLen shdP_eI absOf _ (fun v τ mg hlt hns => ?_)
  have hdeg : IndDegLE shdP_eI (incClearedPolyG φ (Dof v)) := by
    refine IndDegLE.mono (incClearedPolyG_indDeg φ (Dof v)) ?_
    have hc1 : Fintype.card shieldS0.Tok = 128 := Fintype.card_fin 128
    have hc2 : Fintype.card (Fin V) = V := Fintype.card_fin V
    rw [hc1, hc2]
    unfold shdP_eI
    omega
  exact Exec.szSt_escape _ hdeg τ mg hlt hns

/-- **Bridge 1 at any ring map**: `∃ H, InLogUp φ` at `ch` (`ch.length = 15`) gives the predicate at the full list. -/
theorem stgLkInG_of_inLogUp [DecidableEq K] (U : K) (φ : B →+* K)
    (Dof : StgVw Lq → InData B shieldS0.Tok (Fin V) 12) (v : StgVw Lq)
    (ch : List Fp2) (hl : ch.length = 15)
    (hlu : ∃ H, InLogUp φ (Dof v)
      ((((ch.getD 0 Fp2.zero).toK U, (ch.getD 1 Fp2.zero).toK U), (ch.getD 2 Fp2.zero).toK U),
        fun c : Fin 12 => (ch.getD (3 + c.val) Fp2.zero).toK U) H) :
    stgLkInG φ Dof v (ch.map (fun c => ([], c.toK U))) := by
  unfold stgLkInG
  have hmap : ch.map (fun c => (([] : List UInt8), c.toK U))
      = (ch.map (fun c => c.toK U)).map (fun c => ([], c)) := by
    rw [List.map_map]; rfl
  rw [hmap, Exec.szSt_full_map _ [] (ch.map (fun c => c.toK U)) (by rw [List.length_map, hl])]
  have hget : ∀ i : ℕ, i < 15 → (ch.map (fun c => c.toK U)).getD i 0 = (ch.getD i Fp2.zero).toK U := by
    intro i hi
    have hi' : i < ch.length := by omega
    rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_map,
      List.getElem?_eq_getElem hi']
    rfl
  obtain ⟨H, hH⟩ := hlu
  unfold InLogUp at hH
  rw [luk_inA_fold_eq] at hH
  unfold incClearedPolyG
  have h0 : (ch.map (fun c => c.toK U)).getD (0 : Fin 15).val 0 = (ch.getD 0 Fp2.zero).toK U := hget 0 (by omega)
  have h1 : (ch.map (fun c => c.toK U)).getD (1 : Fin 15).val 0 = (ch.getD 1 Fp2.zero).toK U := hget 1 (by omega)
  have h2 : (ch.map (fun c => c.toK U)).getD (2 : Fin 15).val 0 = (ch.getD 2 Fp2.zero).toK U := hget 2 (by omega)
  have hr : (fun c : Fin 12 => (ch.map (fun x => x.toK U)).getD (3 + c.val) 0)
      = (fun c : Fin 12 => (ch.getD (3 + c.val) Fp2.zero).toK U) :=
    funext fun c => hget (3 + c.val) (by omega)
  dsimp only
  rw [h0, h1, h2, hr]
  exact clearedFull_eq_zero_of_helperRel hH

/-- **Bridge 2 at any ring map**: with `V ≤ 2^17` and injective ids, `¬ InGood (Dof v)` dooms the entrant. -/
theorem not_stgLkInG_nil_of_not_inGood [Fintype K] [DecidableEq K] (φ : B →+* K)
    (Dof : StgVw Lq → InData B shieldS0.Tok (Fin V) 12) (v : StgVw Lq)
    (hV : V ≤ 2 ^ 17) (hvid : Function.Injective (Dof v).vid) (hbad : ¬ InGood (Dof v)) :
    ¬ stgLkInG φ Dof v [] := by
  classical
  set D := Dof v
  intro hall
  rw [stgLkInG, Exec.szSt_nil] at hall
  let yOf : InChal K 12 → Fin 15 → K := fun ω i =>
    if i.val = 0 then ω.1.1.1
    else if i.val = 1 then ω.1.1.2
    else if i.val = 2 then ω.1.2
    else ω.2 ⟨i.val - 3, by omega⟩
  have hy_eval : ∀ ω : InChal K 12,
      clearedFull
        (fun t => fold ω.1.1.1 ω.1.1.2 (qTup φ D ω.2 t))
        (fun j => fold ω.1.1.1 ω.1.1.2 (tTup φ D ω.2 j))
        (fun j => φ (D.m j)) ω.1.2 = 0 := by
    intro ω
    have h := hall (yOf ω)
    unfold incClearedPolyG at h
    have hr : (fun c : Fin 12 => yOf ω ⟨3 + c.val, by omega⟩) = ω.2 := by
      funext c
      dsimp [yOf]
      rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega)]
      exact congrArg ω.2 (Fin.ext (by dsimp; omega))
    have h0 : yOf ω 0 = ω.1.1.1 := rfl
    have h1 : yOf ω 1 = ω.1.1.2 := rfl
    have h2 : yOf ω 2 = ω.1.2 := rfl
    rw [h0, h1, h2, hr] at h
    exact h
  let Ep : InChal K 12 → Prop := fun ω =>
    (∃ t : shieldS0.Tok, ω.1.2 - fold ω.1.1.1 ω.1.1.2 (qTup φ D ω.2 t) = 0)
      ∨ (∃ j : Fin V, ω.1.2 - fold ω.1.1.1 ω.1.1.2 (tTup φ D ω.2 j) = 0)
  let El : InChal K 12 → Prop := fun ω => (∃ H, InLogUp φ D ω H) ∧ ¬ InGood D
  have hcover : ∀ ω : InChal K 12, True → Ep ω ∨ El ω := by
    intro ω _
    by_cases hp : Ep ω
    · exact Or.inl hp
    · refine Or.inr ⟨?_, hbad⟩
      have hA : ∀ t : shieldS0.Tok, ω.1.2 - fold ω.1.1.1 ω.1.1.2 (qTup φ D ω.2 t) ≠ 0 :=
        fun t ht => hp (Or.inl ⟨t, ht⟩)
      have hT : ∀ j : Fin V, ω.1.2 - fold ω.1.1.1 ω.1.1.2 (tTup φ D ω.2 j) ≠ 0 :=
        fun j hj => hp (Or.inr ⟨j, hj⟩)
      obtain ⟨H, hH⟩ := helperRel_of_clearedFull_eq_zero (hy_eval ω) hA hT
      refine ⟨H, ?_⟩
      unfold InLogUp
      rw [luk_inA_fold_eq]
      exact hH
  have hcTok : Fintype.card shieldS0.Tok = 128 := Fintype.card_fin 128
  have hcFin : Fintype.card (Fin V) = V := Fintype.card_fin V
  have hEp : pr Ep ≤ ((128 + V : ℕ) : ℝ≥0∞) / Fintype.card K := by
    refine pr_prod_le_right _ (fun r => pr_prod_le _ (fun bg => ?_))
    let A0 : shieldS0.Tok → K := fun t => fold bg.1 bg.2 (qTup φ D r t)
    let T0 : Fin V → K := fun j => fold bg.1 bg.2 (tTup φ D r j)
    refine prob_le_of_card_filter _ (128 + V) ?_
    have hsub : Finset.univ.filter (fun α : K => Ep ((bg, α), r))
        ⊆ Finset.univ.image A0 ∪ Finset.univ.image T0 := by
      intro α hα
      simp only [Finset.mem_filter, Finset.mem_univ, true_and, Ep] at hα
      rcases hα with ⟨t, ht⟩ | ⟨j, hj⟩
      · exact Finset.mem_union_left _ (Finset.mem_image.mpr ⟨t, Finset.mem_univ t, (sub_eq_zero.mp ht).symm⟩)
      · exact Finset.mem_union_right _ (Finset.mem_image.mpr ⟨j, Finset.mem_univ j, (sub_eq_zero.mp hj).symm⟩)
    have hc1 : (Finset.univ.image A0).card ≤ 128 :=
      Finset.card_image_le.trans (by rw [Finset.card_univ, hcTok])
    have hc2 : (Finset.univ.image T0).card ≤ V :=
      Finset.card_image_le.trans (by rw [Finset.card_univ, hcFin])
    exact (Finset.card_le_card hsub).trans ((Finset.card_union_le _ _).trans (Nat.add_le_add hc1 hc2))
  have hN : Fintype.card shieldS0.Tok < ringChar K := by
    rw [hcTok, ZK60.Exec.ringChar_eq_gP]
    unfold gP
    norm_num
  have hEl : pr El ≤ (((128 + 4 * V - 1) + 128 * 12 : ℕ) : ℝ≥0∞) / Fintype.card K := by
    have h := in_lookup_sound φ D hvid hN
    rwa [hcTok, hcFin] at h
  have h1 : (1 : ℝ≥0∞) = pr (fun _ : InChal K 12 => True) := by
    unfold pr
    rw [PMF.toOuterMeasure_apply_fintype]
    have hi : ∀ ω : InChal K 12,
        {x : InChal K 12 | True}.indicator (PMF.uniformOfFintype (InChal K 12)) ω
          = (Fintype.card (InChal K 12) : ℝ≥0∞)⁻¹ := fun _ => by simp
    simp only [hi, Finset.sum_const, Finset.card_univ, nsmul_eq_mul]
    exact (ENNReal.mul_inv_cancel (by exact_mod_cast Fintype.card_ne_zero) (ENNReal.natCast_ne_top _)).symm
  have hle : (1 : ℝ≥0∞)
      ≤ (((128 + V) + ((128 + 4 * V - 1) + 128 * 12) : ℕ) : ℝ≥0∞) / Fintype.card K := by
    calc (1 : ℝ≥0∞) = pr (fun _ : InChal K 12 => True) := h1
      _ ≤ pr (fun ω => Ep ω ∨ El ω) := pr_mono hcover
      _ ≤ pr Ep + pr El := pr_or_le Ep El
      _ ≤ ((128 + V : ℕ) : ℝ≥0∞) / Fintype.card K
          + (((128 + 4 * V - 1) + 128 * 12 : ℕ) : ℝ≥0∞) / Fintype.card K := add_le_add hEp hEl
      _ = (((128 + V) + ((128 + 4 * V - 1) + 128 * 12) : ℕ) : ℝ≥0∞) / Fintype.card K := by
          rw [ENNReal.div_add_div_same, ← Nat.cast_add]
  have hK : ((128 + V) + ((128 + 4 * V - 1) + 128 * 12)) < Fintype.card K := by
    have hgf : Fintype.card GF ≤ Fintype.card K :=
      Fintype.card_le_of_injective _ (algebraMap GF K).injective
    have hgP : Fintype.card GF = gP := ZMod.card gP
    unfold gP at hgP
    omega
  have hlt1 : (((128 + V) + ((128 + 4 * V - 1) + 128 * 12) : ℕ) : ℝ≥0∞) / Fintype.card K < 1 := by
    have hK0 : (Fintype.card K : ℝ≥0∞) ≠ 0 := by exact_mod_cast Fintype.card_ne_zero
    rw [ENNReal.div_lt_iff (Or.inl hK0) (Or.inl (ENNReal.natCast_ne_top _)), one_mul]
    exact_mod_cast hK
  exact not_lt_of_ge hle hlt1

end Pred

/-! ## 3. The `K`-valued IN-C data and its projection -/

section DataK

variable {K : Type} [Field K] [Algebra GF K] {Lq : ℕ}

/-- The stage plane at `(off, log)` of the matrix extracted at view position `i`, BEFORE the base projection
(`stgPlB` is `piB` of it). -/
noncomputable def stgPlK (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (lc h Q e rows i off log : ℕ)
    (v : StgVw Lq) (b : Fin log → Bool) : K :=
  Exec.Block.Join.planeZ U lc rows Q (stgIOX tag h64 lc h Q e rows i v) ⟨.a, [(off, Fp2.one)], log, [], 0, 0⟩ b

theorem stgPlB_eq_piB (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (lc h Q e rows i off log : ℕ)
    (v : StgVw Lq) (b : Fin log → Bool) :
    stgPlB U tag h64 lc h Q e rows i off log v b
      = Exec.Block.Join.W16.piB K (stgPlK U tag h64 lc h Q e rows i off log v b) :=
  rfl

/-- **Stage IN-C's data over `K`**: the token words, the `B_in` rows and the multiplicities are the planes `shdIncData`
projects (`A_in` at `iA`, `B_in` at `iB`), unprojected; the public fields are the images of `shdIncData`'s. -/
noncomputable def shdIncDataK (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0) (I : IncPub)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iB iA : ℕ) (v : StgVw Lq) :
    InData K shieldS0.Tok (Fin P.V) 12 where
  tag := algebraMap GF K (shdIncData U tag h64 P I Epad iB iA v).tag
  tok t := stgPlK U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 41 iA
    ((incLay I 14).aOff incA_TOK) 12 v (msbBits 12 t.val)
  X t c := stgPlK U tag h64 14 16 256 24448 38 iB 0 19 v (Fin.append (msbBits 7 t.val) c)
  cq t := algebraMap GF K ((shdIncData U tag h64 P I Epad iB iA v).cq t)
  vid j := algebraMap GF K ((shdIncData U tag h64 P I Epad iB iA v).vid j)
  E j c := algebraMap GF K ((shdIncData U tag h64 P I Epad iB iA v).E j c)
  ctl j := algebraMap GF K ((shdIncData U tag h64 P I Epad iB iA v).ctl j)
  m j := stgPlK U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 41 iA
    ((incLay I 14).aOff incA_MULT) 17 v (msbBits 17 j.val)

variable (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0) (I : IncPub)
  (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iB iA : ℕ) (v : StgVw Lq)

theorem shdIncData_proj_tok (t : shieldS0.Tok) :
    (shdIncData U tag h64 P I Epad iB iA v).tok t
      = Exec.Block.Join.W16.piB K ((shdIncDataK U tag h64 P I Epad iB iA v).tok t) :=
  rfl

theorem shdIncData_proj_X (t : shieldS0.Tok) (c : Fin 12 → Bool) :
    (shdIncData U tag h64 P I Epad iB iA v).X t c
      = Exec.Block.Join.W16.piB K ((shdIncDataK U tag h64 P I Epad iB iA v).X t c) :=
  rfl

theorem shdIncData_proj_m (j : Fin P.V) :
    (shdIncData U tag h64 P I Epad iB iA v).m j
      = Exec.Block.Join.W16.piB K ((shdIncDataK U tag h64 P I Epad iB iA v).m j) :=
  rfl

/-- **A `K`-valued good lookup is a good lookup of the projection**: its token words are table ids (in `GF`), its rows
embedding rows (in `GF`), so `piB` returns them; the classes are images of `GF` words, and `algebraMap` is injective. -/
theorem inGood_proj (h : InGood (shdIncDataK U tag h64 P I Epad iB iA v)) :
    InGood (shdIncData U tag h64 P I Epad iB iA v) := by
  intro t
  obtain ⟨j, hid, hX, hc⟩ := h t
  refine ⟨j, ?_, ?_, ?_⟩
  · rw [shdIncData_proj_tok]
    have e : (shdIncDataK U tag h64 P I Epad iB iA v).tok t
        = algebraMap GF K ((shdIncData U tag h64 P I Epad iB iA v).vid j) := hid.symm
    rw [e, Exec.Block.Join.W16.piB_alg]
  · funext c
    rw [shdIncData_proj_X]
    have e : (shdIncDataK U tag h64 P I Epad iB iA v).X t c
        = algebraMap GF K ((shdIncData U tag h64 P I Epad iB iA v).E j c) := congrFun hX c
    rw [e, Exec.Block.Join.W16.piB_alg]
  · exact (algebraMap GF K).injective hc

/-- The ids of the `K`-valued data are distinct (`V ≤ 2^17 < p`). -/
theorem shdIncDataK_vid_injective (hP : P.Valid) :
    Function.Injective (shdIncDataK U tag h64 P I Epad iB iA v).vid := by
  intro a b hab
  exact inDataOf_vid_injective P hP 12 _ _ _ _ _ ((algebraMap GF K).injective hab)

/-- **`hdinX`'s direction at the `K`-valued predicate**: a projection that is not a good lookup dooms the entrant. -/
theorem not_stgLkInK_nil_of_not_inGood [Fintype K] [DecidableEq K] (hP : P.Valid)
    (hbad : ¬ InGood (shdIncData U tag h64 P I Epad iB iA v)) :
    ¬ stgLkInG (RingHom.id K) (shdIncDataK U tag h64 P I Epad iB iA) v [] :=
  not_stgLkInG_nil_of_not_inGood (RingHom.id K) (shdIncDataK U tag h64 P I Epad iB iA) v hP.V2
    (shdIncDataK_vid_injective U tag h64 P I Epad iB iA v hP)
    (fun hg => hbad (inGood_proj U tag h64 P I Epad iB iA v hg))

end DataK

/-! ## 4. The corrected `ΛI` and the exact statement `hLI_stg` needs at it -/

section NeedK

variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K] {Lq : ℕ}

/-- **The corrected `ΛI`**: the `K`-valued IN-C LogUp predicate. -/
noncomputable def shd_ΛIK (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0) (I : IncPub)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iB iA : ℕ) :
    StgVw Lq → List (List UInt8 × K) → Prop :=
  stgLkInG (RingHom.id K) (shdIncDataK U tag h64 P I Epad iB iA)

/-- **`hLuStg`'s IN-C half at the corrected `ΛI`** (the `.Rbr` and the escape budget, as `shd_hLuStg`). -/
theorem shd_hLuStgIK [Fintype K] (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (absOf : QB Lq → Option (List UInt8))
    (P : InPublic shieldS0) (hV : P.V ≤ 2 ^ 17) (I : IncPub) (Epad : Fin P.V → (Fin 12 → Bool) → GF)
    (iB hdrIn : ℕ) :
    (stgLkSqV 15 hdrIn shdP_eI absOf (shd_ΛIK U tag h64 P I Epad iB hdrIn)).Rbr
      ∧ shdP_eI ≤ 2 ^ 26 ∧ 15 * shdP_eI ≤ 3 * 2 ^ 26 :=
  ⟨stgLkInG_rbr (RingHom.id K) hdrIn absOf _ hV, by unfold shdP_eI; norm_num, by unfold shdP_eI; norm_num⟩

/-- **What `hLI_stg` needs at the corrected `ΛI`, stated exactly** (not assumed anywhere): at every reading of stage
IN-C (`m = 15`) the stage's LogUp relation over the `K`-valued data holds at the drawn challenges for some helpers. -/
def ShdLuInAtK {V : ℕ} (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams)
    (hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB Lq → Option (List UInt8))
    (Dof : StgVw Lq → InData K shieldS0.Tok (Fin V) 12)
    (G : QB Lq → Dig) (Lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain Lq Pof 15 hdrLen bgaOf G τ hdr core ch rs →
    ch.length = 15 ∧ ∃ H, InLogUp (RingHom.id K)
      (Dof (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core))))
      ((((ch.getD 0 Fp2.zero).toK U, (ch.getD 1 Fp2.zero).toK U), (ch.getD 2 Fp2.zero).toK U),
        fun c : Fin 12 => (ch.getD (3 + c.val) Fp2.zero).toK U) H

/-- **`hLI_stg`'s conclusion at the corrected `ΛI` from `ShdLuInAtK`.** -/
theorem stgLkAtV_of_luInK {V : ℕ} (U : K) (key : Option Dig) (domain : List UInt8)
    (Pof : List Fp2 → Block.BlockParams) (hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB Lq → Option (List UInt8)) (Dof : StgVw Lq → InData K shieldS0.Tok (Fin V) 12)
    (G : QB Lq → Dig) (Lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (h : ShdLuInAtK U key domain Pof hdrLen bgaOf absOf Dof G Lg τ) :
    StgLkAtV U key domain Pof 15 hdrLen bgaOf absOf (stgLkInG (RingHom.id K) Dof) G Lg τ := by
  intro hdr core ch rs hrd
  obtain ⟨hl, hlu⟩ := h hdr core ch rs hrd
  exact stgLkInG_of_inLogUp U (RingHom.id K) Dof _ ch hl hlu

end NeedK

end ZK60.ProtocolClassify
