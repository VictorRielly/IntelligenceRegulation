/-
D63 lane L63 (2026-11-19), L63 leg 12, part 79: **`hLO_stg` from OUT-C's byte-LogUp slot facts at every reading**
(pieces (ii) and (v) of step 1 of HANDOFF_20261119_1.md, stated so that the rest of `hLO_stg` is exactly the facts of
`ShdOutcSlotsT` and the two sum facts).

* `shdOutcHd`: the helpers `h_lo`, `h_d0 … h_d5`, `h_gu8`, `u` read as the `H_out` planes at a view (each the pair
  `(1, u)` of planes at the layout's `H` offsets, as LZC, DZC, TAB and ZS read them, all on the `2^12` cube);
* `shdOutcA`: an `A_out` plane at `(aOff p, 12)` before the base projection (`shdOutcLimb`, `shdOutcPl`,
  `shdOutcMult` are its projections, and `shdOutcA_alg` its embedding);
* **`outc_byteLogUp_of`**: LZC's single relation at every `Lo` entry, DZC's six pair relations at every `Do` entry,
  TAB's relation at its 256 live rows with its pad, the zero-sum row and the `H` opening's sum claim give
  `ByteLogUp` (the byte half of `outcCube`, StageOutCWhole.lean:699; the byte half reads no other public table, so no
  full `OutCLayout` is needed for `hLO_stg`);
* `ShdOutcSlotsT` (defined, not assumed): the clause equations LZC, DZC and TAB give at every reading, on the
  `A_out` planes and the helpers at one view `w`;
* **`shd_hLO_of_slotsT`**: with them and the two sum facts at the readings, `hLO_stg`'s conclusion
  `StgLkAtV … shd_ΛO …` (the data at the head's view is the data at `w = τ`'s view: `A_out` sits at `iA < hdrLen + 4`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutZero
import ZK60Formal.RunStgShieldIncJoin

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV (OutcPub outcLay ocC_LIMB ocC_X ocC_MULT ocH_LO ocH_D0 ocH_GU8 ocH_U tagU8)
open ZK60.Circuit (gP GF)

/-! ## 1. The `A_out` planes and the `H_out` helpers at a view -/

section Planes

variable {K : Type} [Field K] [Algebra GF K] {Lq : ℕ}

/-- **An `A_out` plane at `(aOff p, 12)` before the base projection**, at stage OUT-C's opening geometry. -/
noncomputable def shdOutcA (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (O : OutcPub) (rA iA p : ℕ) (w : StgVw Lq) :
    (Fin 12 → Bool) → K :=
  stgPlK U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA ((outcLay O 14).aOff p) 12 w

/-- **The helpers `h_lo`, `h_d0 … h_d5`, `h_gu8`, `u` as the `H_out` planes at the view `w`.** -/
noncomputable def shdOutcHd (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (O : OutcPub) (rH iH : ℕ) (w : StgVw Lq) :
    OutCHelpers K 12 12 12 12 :=
  (fun z => Block.Join.planeZ U ogStage.lc rH ogStage.Q
      (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w)
      ⟨.h, [(((outcLay O 14).hOff ocH_LO).1, Fp2.one), (((outcLay O 14).hOff ocH_LO).2, Block.fp2U)], 12, [], 0, 0⟩ z,
   fun k c => Block.Join.planeZ U ogStage.lc rH ogStage.Q
      (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w)
      ⟨.h, [(((outcLay O 14).hOff (ocH_D0 + k.val)).1, Fp2.one),
        (((outcLay O 14).hOff (ocH_D0 + k.val)).2, Block.fp2U)], 12, [], 0, 0⟩ c,
   fun c => Block.Join.planeZ U ogStage.lc rH ogStage.Q
      (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w)
      ⟨.h, [(((outcLay O 14).hOff ocH_GU8).1, Fp2.one), (((outcLay O 14).hOff ocH_GU8).2, Block.fp2U)], 12, [], 0,
        0⟩ c,
   fun j => Block.Join.planeZ U ogStage.lc rH ogStage.Q
      (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w)
      ⟨.h, [(((outcLay O 14).hOff ocH_U).1, Fp2.one), (((outcLay O 14).hOff ocH_U).2, Block.fp2U)], 12, [], 0, 0⟩ j)

variable (U : K) (tag : MTag) (h64 : 64 ≤ Lq)

/-- **The unprojected `A_out` plane is the embedded projected one** (`stgPlK_eq_alg` at stage OUT-C's geometry). -/
theorem shdOutcA_alg (O : OutcPub) (rA iA p : ℕ) (w : StgVw Lq) (b : Fin 12 → Bool) :
    shdOutcA U tag h64 O rA iA p w b
      = algebraMap GF K (stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA ((outcLay O 14).aOff p) 12
        w b) :=
  stgPlK_eq_alg U tag h64 _ _ _ _ _ _ _ _ ogStage_lc_le ogStage_h_le ogStage_radius w b

/-- A projected stage plane reads the view below `n > i`. -/
theorem vwLoc_stgPlB (lc h Q e rows i off log n : ℕ) (hi : i < n) :
    VwLoc n (fun v : StgVw Lq => stgPlB U tag h64 lc h Q e rows i off log v) := by
  intro v v' h1 h2
  have hx := stgIOX_loc (K := K) tag h64 lc h Q e rows i n hi v v' h1 h2
  funext b
  show stgPlB U tag h64 lc h Q e rows i off log v b = stgPlB U tag h64 lc h Q e rows i off log v' b
  unfold stgPlB
  rw [hx]

end Planes

/-! ## 2. The byte half of `outcCube` -/

section Byte

variable {K : Type} [Field K] [DecidableEq K]

theorem msbBits12_inj256 : Function.Injective (fun j : Fin 256 => msbBits 12 j.val) := by
  intro a b h
  have ha : a.val < 256 := a.isLt
  have hb : b.val < 256 := b.isLt
  have e := congrArg (msbIndex 12) h
  simp only at e
  rw [msbIndex_msbBits 12 a.val (by omega), msbIndex_msbBits 12 b.val (by omega)] at e
  exact Fin.ext e

/-- **THE BYTE HALF OF `outcCube`**: LZC's singles, DZC's pairs, TAB's live rows and pad, the zero-sum row and the sum
claim give the byte LogUp's relations, at the helpers read at the logical positions. -/
theorem outc_byteLogUp_of (φ : GF →+* K) (limb : (Fin 12 → Bool) → GF) (pl : Fin 12 → (Fin 12 → Bool) → GF)
    (mult : Fin 256 → K) (gT : K → K) (ω : K × K) (hd : OutCHelpers K 12 12 12 12)
    (hL : ∀ z, hd.1 z * (ω.2 - (φ (limb z) + gT ω.1)) = 1)
    (hP : ∀ (k : Fin 6) (c : Fin 12 → Bool),
      hd.2.1 k c * ((ω.2 - (φ (dLookB pl (pIdx1 k) c) + gT ω.1)) * (ω.2 - (φ (dLookB pl (pIdx2 k) c) + gT ω.1)))
        = (ω.2 - (φ (dLookB pl (pIdx1 k) c) + gT ω.1)) + (ω.2 - (φ (dLookB pl (pIdx2 k) c) + gT ω.1)))
    (hT : ∀ j : Fin 256, hd.2.2.1 (msbBits 12 j.val) * (ω.2 - byteTab (gT ω.1) j) = mult j)
    (hTpad : ∀ c, c ∉ Set.range (fun j : Fin 256 => msbBits 12 j.val) → hd.2.2.1 c = 0)
    (hzs : ∑ j, hd.2.2.2 j = 0) (hsum : OutCSum hd) :
    ByteLogUp φ limb (fun kc : Fin 6 × (Fin 12 → Bool) => dLookB pl (pIdx1 kc.1) kc.2)
      (fun kc : Fin 6 × (Fin 12 → Bool) => dLookB pl (pIdx2 kc.1) kc.2) mult gT ω
      ⟨hd.1, fun kc => hd.2.1 kc.1 kc.2, fun j => hd.2.2.1 (msbBits 12 j.val)⟩ := by
  refine ⟨fun z => hL z, fun kc => hP kc.1 kc.2, hT, ?_⟩
  have hs := hsum
  unfold OutCSum at hs
  rw [hzs, add_zero, cube_sum_of_pad (fun j : Fin 256 => msbBits 12 j.val) msbBits12_inj256 hd.2.2.1 hTpad] at hs
  show ∑ z, hd.1 z + ∑ kc : Fin 6 × (Fin 12 → Bool), hd.2.1 kc.1 kc.2 - ∑ j : Fin 256, hd.2.2.1 (msbBits 12 j.val) = 0
  rw [Fintype.sum_prod_type]
  exact hs

end Byte

/-! ## 3. The slot facts at every reading, and `hLO_stg` from them -/

section Join

variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K] {Lq : ℕ}

/-- DZC's denominator of lookup `j` on the unprojected `A_out` planes (`dzcDen` at a cube point). -/
noncomputable def shdOutcDen (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (O : OutcPub) (rA iA : ℕ) (w : StgVw Lq)
    (α g : K) (j : Fin 12) (c : Fin 12 → Bool) : K :=
  α - ((((dLookCst j : ℤ) : K) + g) + shdOutcA U tag h64 O rA iA (ocC_X + (dLookPl j).val) w c * ((dLookCoef j : ℤ) : K))

/-- **The OUT-C byte slots' clause equations at every reading** (defined, not assumed), on the `A_out` planes and the
helpers `hd` at one view `w`: LZC's single relation, DZC's six pair relations, TAB's relation and its helper pad. -/
def ShdOutcSlotsT (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams)
    (hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (tag : MTag) (h64 : 64 ≤ Lq) (O : OutcPub) (rA iA : ℕ)
    (w : StgVw Lq) (hd : OutCHelpers K 12 12 12 12) (G : QB Lq → Dig) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain Lq Pof 2 hdrLen bgaOf G τ hdr core ch rs →
    ch.length = 2
    ∧ (∀ z, hd.1 z * ((ch.getD 1 Fp2.zero).toK U - (shdOutcA U tag h64 O rA iA ocC_LIMB w z
        + (ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF))) - 1 = 0)
    ∧ (∀ (k : Fin 6) (c : Fin 12 → Bool),
        hd.2.1 k c * shdOutcDen U tag h64 O rA iA w ((ch.getD 1 Fp2.zero).toK U)
            ((ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF)) (pIdx1 k) c
          * shdOutcDen U tag h64 O rA iA w ((ch.getD 1 Fp2.zero).toK U)
            ((ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF)) (pIdx2 k) c
        - (shdOutcDen U tag h64 O rA iA w ((ch.getD 1 Fp2.zero).toK U)
            ((ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF)) (pIdx1 k) c
          + shdOutcDen U tag h64 O rA iA w ((ch.getD 1 Fp2.zero).toK U)
            ((ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF)) (pIdx2 k) c) = 0)
    ∧ (∀ c : Fin 12 → Bool, hd.2.2.1 c * ((ch.getD 1 Fp2.zero).toK U
          - (((msbIndex 12 c % 256 : ℕ) : K) + (ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF)))
        - shdOutcA U tag h64 O rA iA ocC_MULT w c = 0)
    ∧ (∀ c : Fin 12 → Bool, (1 - (if msbIndex 12 c < 256 then (1 : K) else 0)) * hd.2.2.1 c = 0)

variable (U : K) (tag : MTag) (h64 : 64 ≤ Lq)

omit [DecidableEq K] in
/-- A lookup's denominator on the unprojected planes is the byte LogUp's. -/
theorem shdOutcDen_eq (O : OutcPub) (iA : ℕ) (w : StgVw Lq) (α g : K) (j : Fin 12) (c : Fin 12 → Bool) :
    shdOutcDen U tag h64 O 76 iA w α g j c
      = α - (algebraMap GF K (dLookB (shdOutcPl U tag h64 O iA w) j c) + g) := by
  unfold shdOutcDen dLookB
  rw [shdOutcA_alg]
  simp only [map_add, map_mul, map_intCast]
  unfold shdOutcPl
  ring

/-- **The OUT-C slot facts at `τ`'s view and the two sum facts at the readings give `hLO_stg`'s conclusion**
(`StgLkAtV … shd_ΛO …`), the `A_out` root sitting below the head (`iA < hdrLen + 4`). -/
theorem shd_hLO_of_slotsT (O : OutcPub) (iA hdrLen : ℕ) (hA : iA < hdrLen + 4) (rH iH : ℕ)
    (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB Lq → Option (List UInt8))
    (G : QB Lq → Dig) (Lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (h : ShdOutcSlotsT U key domain Pof hdrLen bgaOf tag h64 O 76 iA (stgVw absOf Lg τ)
      (shdOutcHd U tag h64 O rH iH (stgVw absOf Lg τ)) G τ)
    (hsum : ∀ hdr core ch rs, StgRd key domain Lq Pof 2 hdrLen bgaOf G τ hdr core ch rs →
      OutCSum (shdOutcHd U tag h64 O rH iH (stgVw absOf Lg τ))
      ∧ ∑ j, (shdOutcHd U tag h64 O rH iH (stgVw absOf Lg τ)).2.2.2 j = 0) :
    StgLkAtV U key domain Pof 2 hdrLen bgaOf absOf (shd_ΛO U tag h64 O iA) G Lg τ := by
  refine stgLkAtV_of_luOut U key domain Pof hdrLen bgaOf absOf _ _ _ G Lg τ ?_
  intro hdr core ch rs hrd
  obtain ⟨hl, hL, hP, hT, hTp⟩ := h hdr core ch rs hrd
  obtain ⟨hS, hZ⟩ := hsum hdr core ch rs hrd
  refine ⟨hl, ?_⟩
  -- the data at the head's view is the data at `τ`'s view
  obtain ⟨h1, -⟩ := stg_rd_head key domain Pof 2 hdrLen bgaOf G τ hdr core ch rs hrd
  have hloc : ∀ off, stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 iA off 12
      (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)))
      = stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 iA off 12 (stgVw absOf Lg τ) := by
    intro off
    rw [← h1]
    exact vw_take absOf Lg (hdrLen + 4) (hdrLen + 4) le_rfl _
      (vwLoc_stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 iA off 12 (hdrLen + 4) hA) τ
  have eL : shdOutcLimb U tag h64 O iA
      (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)))
      = shdOutcLimb U tag h64 O iA (stgVw absOf Lg τ) := hloc _
  have eP : shdOutcPl U tag h64 O iA
      (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)))
      = shdOutcPl U tag h64 O iA (stgVw absOf Lg τ) := by
    funext p
    exact hloc _
  have eM : shdOutcMult U tag h64 O iA
      (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)))
      = shdOutcMult U tag h64 O iA (stgVw absOf Lg τ) := by
    funext j
    unfold shdOutcMult
    rw [hloc]
  show ∃ H, ByteLogUp (algebraMap GF K) (shdOutcLimb U tag h64 O iA _)
    (fun kc : Fin 6 × (Fin 12 → Bool) => dLookB (shdOutcPl U tag h64 O iA _) (pIdx1 kc.1) kc.2)
    (fun kc : Fin 6 × (Fin 12 → Bool) => dLookB (shdOutcPl U tag h64 O iA _) (pIdx2 kc.1) kc.2)
    (shdOutcMult U tag h64 O iA _) (fun g => g * algebraMap GF K (tagU8 : GF))
    ((ch.getD 0 Fp2.zero).toK U, (ch.getD 1 Fp2.zero).toK U) H
  rw [eL, eP, eM]
  set w := stgVw absOf Lg τ with hw
  set hd := shdOutcHd U tag h64 O rH iH w with hhd
  set γ := (ch.getD 0 Fp2.zero).toK U with hγ
  set α := (ch.getD 1 Fp2.zero).toK U with hα
  refine ⟨_, outc_byteLogUp_of (algebraMap GF K) (shdOutcLimb U tag h64 O iA w) (shdOutcPl U tag h64 O iA w)
    (shdOutcMult U tag h64 O iA w) (fun g => g * algebraMap GF K (tagU8 : GF)) (γ, α) hd
    (fun z => ?_) (fun k c => ?_) (fun j => ?_) (fun c hc => ?_) hZ hS⟩
  · -- LZC's single relation
    have e := hL z
    rw [shdOutcA_alg] at e
    show hd.1 z * (α - (algebraMap GF K (shdOutcLimb U tag h64 O iA w z) + γ * algebraMap GF K (tagU8 : GF))) = 1
    exact sub_eq_zero.mp e
  · -- DZC's pair relations
    have e := hP k c
    rw [shdOutcDen_eq, shdOutcDen_eq] at e
    show hd.2.1 k c * ((α - (algebraMap GF K (dLookB (shdOutcPl U tag h64 O iA w) (pIdx1 k) c)
        + γ * algebraMap GF K (tagU8 : GF))) * (α - (algebraMap GF K (dLookB (shdOutcPl U tag h64 O iA w) (pIdx2 k) c)
        + γ * algebraMap GF K (tagU8 : GF))))
      = (α - (algebraMap GF K (dLookB (shdOutcPl U tag h64 O iA w) (pIdx1 k) c) + γ * algebraMap GF K (tagU8 : GF)))
        + (α - (algebraMap GF K (dLookB (shdOutcPl U tag h64 O iA w) (pIdx2 k) c) + γ * algebraMap GF K (tagU8 : GF)))
    linear_combination e
  · -- TAB's relation at a live row
    have hj : j.val < 256 := j.isLt
    have e := hT (msbBits 12 j.val)
    rw [msbIndex_msbBits 12 j.val (by omega), Nat.mod_eq_of_lt hj, shdOutcA_alg] at e
    show hd.2.2.1 (msbBits 12 j.val) * (α - ((j.val : K) + γ * algebraMap GF K (tagU8 : GF)))
      = algebraMap GF K (stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 iA
          ((outcLay O 14).aOff ocC_MULT) 12 w (msbBits 12 j.val))
    exact sub_eq_zero.mp e
  · -- TAB's pad: off the live rows the helper is zero
    have hge : ¬ msbIndex 12 c < 256 := by
      intro hlt
      exact hc ⟨⟨msbIndex 12 c, hlt⟩, msbBits_msbIndex 12 c⟩
    have e := hTp c
    rw [ite_eq_right hge, sub_zero, one_mul] at e
    exact e

end Join

end ZK60.ProtocolClassify
