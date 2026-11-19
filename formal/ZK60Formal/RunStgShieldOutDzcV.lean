/-
D63 lane L63 (2026-11-19), L63 leg 12, part 83: **DZC's pair term on the stage's tables is the `shdOutcDen` form of
`ShdOutcSlotsT`** (piece (iii) of step 1 of HANDOFF_20261119_1.md, DZC's identification; the twin of `outc_tab_vals`).

At the cube point `(c, 0)`, stage OUT-C's layout and `ldo = 12`:
* `outc_identA`, `outc_identH`: an `A_out` plane table and an `H_out` helper table at `(c, 0)` are `shdOutcA` and the
  helper plane (generic in the offset);
* `dzcRest_getD_plane`, `dzcRest_getD_helper`: DZC's table list at the plane and helper positions;
* `dzcLks_getD`: the code's lookup list is `(dLookPl, dLookCoef, dLookCst)`; `kI_int_toK`;
* **`outc_dzc_vals`**: `dzcPairG` on DZC's tables is `h_d_k·d1·d2 − (d1 + d2)` with `d1`, `d2` the denominators
  `shdOutcDen` of lookups `2k`, `2k + 1` on the `A_out` planes, `h_d_k` the `H_out` helper (`shdOutcHd`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutDzc

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

section Small

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- `kI v` is `v` in `K` (small `v`). -/
theorem kI_int_toK (v : ℤ) (h1 : -2 ^ 64 < v) (h2 : v < 2 ^ 64) : (kI v).toK U = (v : K) := by
  unfold kI
  rw [Fp2.toK_fromBase, Fp.toGF_fromI64 _ h1 h2]
  simp

/-- The code's lookup list `lookups_do` is `(dLookPl, dLookCoef, dLookCst)`. -/
theorem dzcLks_getD (j : Fin 12) : dzcLks.getD j.val (0, 0, 0) = ((dLookPl j).val, dLookCoef j, dLookCst j) := by
  fin_cases j <;> rfl

theorem dLookCst_bd (j : Fin 12) : -2 ^ 64 < dLookCst j ∧ dLookCst j < 2 ^ 64 := by
  unfold dLookCst
  split_ifs <;> norm_num

theorem dLookCoef_bd (j : Fin 12) : -2 ^ 64 < dLookCoef j ∧ dLookCoef j < 2 ^ 64 := by
  unfold dLookCoef
  split_ifs <;> norm_num

omit [Algebra GF K] in
/-- The `getD` of a mapped list at a valid index. -/
theorem getD_map_lt {α : Type} (l : List α) (f : α → K) (i : ℕ) (hi : i < l.length) (d : α) :
    (l.map f).getD i 0 = f (l.getD i d) := by
  rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hi]
  rfl

end Small

/-- DZC's table list at plane `p`. -/
theorem dzcRest_getD_plane (O : OutcPub) (G : OutcGeo) (p : ℕ) (hp : p < 12) :
    (outcDzcRest O G).getD (1 + p) (.pub [])
      = .priv ⟨.a, [((outcLay O G.bLogN).aOff (ocC_X + p), Fp2.one)], (outcLay O G.bLogN).aLog.getD (ocC_X + p) 0,
          rhoC 0 ((outcLay O G.bLogN).aLog.getD (ocC_X + p) 0),
          (outcLay O G.bLogN).aMaskBase + 2 * ((outcLay O G.bLogN).prefixA 5 + p), 0⟩ := by
  interval_cases p <;> rfl

/-- DZC's table list at pair helper `kk`. -/
theorem dzcRest_getD_helper (O : OutcPub) (G : OutcGeo) (kk : ℕ) (hk : kk < 6) :
    (outcDzcRest O G).getD (14 + kk) (.pub [])
      = .priv ⟨.h, [(((outcLay O G.bLogN).hOff (ocH_D0 + kk)).1, Fp2.one),
            (((outcLay O G.bLogN).hOff (ocH_D0 + kk)).2, Block.fp2U)],
          (outcLay O G.bLogN).hLog.getD (ocH_D0 + kk) 0, rhoC 0 ((outcLay O G.bLogN).hLog.getD (ocH_D0 + kk) 0),
          (outcLay O G.bLogN).hMaskBase + 2 * ((outcLay O G.bLogN).prefixH 5 + kk), 0⟩ := by
  interval_cases kk <;> rfl

theorem outcDzcRest_length (O : OutcPub) (G : OutcGeo) : (outcDzcRest O G).length = 20 := by
  simp [outcDzcRest, ocC_MULT, ocC_X]

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- **An `A_out` plane table at `(c, 0)` is `shdOutcA`.** -/
theorem outc_identA (hU : U ^ 2 = algebraMap GF K 7) (O : OutcPub) (Vo : OutcV) (rA rH iA iH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (w : StgVw Lq)
    (hGb : Vo.geo.bLogN = 14) (hOL : outcLay Vo.pub 14 = outcLay O 14)
    (hlc : 0 < Vo.bp.logCols) {N : ℕ} (hN : N = 13) (c : Fin 12 → Bool) (off mr : ℕ)
    (hlog : (outcLay Vo.pub Vo.geo.bLogN).aLog.getD off 0 = 12) :
    stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12 1
        (fun i : Fin N => (bit (cptS 12 c i) : K))
        (.priv ⟨.a, [((outcLay Vo.pub Vo.geo.bLogN).aOff off, Fp2.one)], (outcLay Vo.pub Vo.geo.bLogN).aLog.getD off 0,
          rhoC 0 ((outcLay Vo.pub Vo.geo.bLogN).aLog.getD off 0), mr, 0⟩)
      = shdOutcA U tag h64 O rA iA off w c := by
  have hNlt : 12 < N := by omega
  refine (stgTabK_priv_cptS U hbij hU Vo.bp _ rA ogStage.lc ogStage.Q
    (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA w) (by decide) 12 c hN _ (by intro _; rfl)
    (by exact List.cons_ne_nil _ _) (by show 0 < (outcLay Vo.pub Vo.geo.bLogN).aLog.getD off 0; omega)
    (by simp [rhoC]) (by exact hlc)
    (by intro c' hc w' hw; simp [rhoC] at hc; obtain ⟨_, _, rfl⟩ := hc; cases hw)).trans ?_
  rw [privZ_eq_planeZ U _ _ _ _ 12 c hNlt _ [((outcLay O 14).aOff off, Fp2.one)] .a
    (by show [((outcLay Vo.pub Vo.geo.bLogN).aOff off, Fp2.one)] = _; rw [hGb, hOL]) hlog rfl]
  rfl

/-- **An `H_out` helper table at `(c, 0)` is the helper plane.** -/
theorem outc_identH (hU : U ^ 2 = algebraMap GF K 7) (O : OutcPub) (Vo : OutcV) (rA rH iA iH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (w : StgVw Lq)
    (hGb : Vo.geo.bLogN = 14) (hOL : outcLay Vo.pub 14 = outcLay O 14)
    (hlc : 0 < Vo.bp.logCols) {N : ℕ} (hN : N = 13) (c : Fin 12 → Bool) (pl mr : ℕ)
    (hlog : (outcLay Vo.pub Vo.geo.bLogN).hLog.getD pl 0 = 12) :
    stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12 1
        (fun i : Fin N => (bit (cptS 12 c i) : K))
        (.priv ⟨.h, [(((outcLay Vo.pub Vo.geo.bLogN).hOff pl).1, Fp2.one),
            (((outcLay Vo.pub Vo.geo.bLogN).hOff pl).2, Block.fp2U)],
          (outcLay Vo.pub Vo.geo.bLogN).hLog.getD pl 0, rhoC 0 ((outcLay Vo.pub Vo.geo.bLogN).hLog.getD pl 0), mr, 0⟩)
      = Block.Join.planeZ U ogStage.lc rH ogStage.Q
          (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w)
          ⟨.h, [(((outcLay O 14).hOff pl).1, Fp2.one), (((outcLay O 14).hOff pl).2, Block.fp2U)], 12, [], 0, 0⟩ c := by
  have hNlt : 12 < N := by omega
  refine (stgTabK_priv_cptS U hbij hU Vo.bp _ rH ogStage.lc ogStage.Q
    (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w) (by decide) 12 c hN _ (by intro _; rfl)
    (by exact List.cons_ne_nil _ _) (by show 0 < (outcLay Vo.pub Vo.geo.bLogN).hLog.getD pl 0; omega)
    (by simp [rhoC]) (by exact hlc)
    (by intro c' hc w' hw; simp [rhoC] at hc; obtain ⟨_, _, rfl⟩ := hc; cases hw)).trans ?_
  rw [privZ_eq_planeZ U _ _ _ _ 12 c hNlt _
    [(((outcLay O 14).hOff pl).1, Fp2.one), (((outcLay O 14).hOff pl).2, Block.fp2U)] .h
    (by show [(((outcLay Vo.pub Vo.geo.bLogN).hOff pl).1, Fp2.one),
        (((outcLay Vo.pub Vo.geo.bLogN).hOff pl).2, Block.fp2U)] = _; rw [hGb, hOL]) hlog rfl]

/-- **DZC'S PAIR TERM ON THE STAGE'S TABLES IS THE `shdOutcDen` FORM.** -/
theorem outc_dzc_vals (hU : U ^ 2 = algebraMap GF K 7) (O : OutcPub) (Vo : OutcV) (rA rH iA iH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (w : StgVw Lq) (ch : List Fp2)
    (hGb : Vo.geo.bLogN = 14) (hOL : outcLay Vo.pub 14 = outcLay O 14) (hldo : Vo.pub.ldo = 12)
    (hlc : 0 < Vo.bp.logCols) {N : ℕ} (hN : N = 13) (c : Fin 12 → Bool) (k : Fin 6) :
    dzcPairG U ((ch.getD 1 Fp2.zero).toK U) (((ch.getD 0 Fp2.zero).mulBase (Fp.new (UInt64.ofNat tagU8))).toK U)
        (fun idx => ((outcDzcRest Vo.pub Vo.geo).map
          (stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12 1
            (fun i : Fin N => (bit (cptS 12 c i) : K)))).getD (idx - 1) 0) k.val
      = (shdOutcHd U tag h64 O rH iH w).2.1 k c
          * shdOutcDen U tag h64 O rA iA w ((ch.getD 1 Fp2.zero).toK U)
            ((ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF)) (pIdx1 k) c
          * shdOutcDen U tag h64 O rA iA w ((ch.getD 1 Fp2.zero).toK U)
            ((ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF)) (pIdx2 k) c
        - (shdOutcDen U tag h64 O rA iA w ((ch.getD 1 Fp2.zero).toK U)
            ((ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF)) (pIdx1 k) c
          + shdOutcDen U tag h64 O rA iA w ((ch.getD 1 Fp2.zero).toK U)
            ((ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF)) (pIdx2 k) c) := by
  set f := stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12 1
    (fun i : Fin N => (bit (cptS 12 c i) : K)) with hf
  set α := (ch.getD 1 Fp2.zero).toK U with hα
  have hgK : ((ch.getD 0 Fp2.zero).mulBase (Fp.new (UInt64.ofNat tagU8))).toK U
      = (ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF) := gU8_toK U ch
  -- the planes
  have hplane : ∀ p : ℕ, p < 12 → ((outcDzcRest Vo.pub Vo.geo).map f).getD (1 + p) 0
      = shdOutcA U tag h64 O rA iA (ocC_X + p) w c := by
    intro p hp
    rw [getD_map_lt (outcDzcRest Vo.pub Vo.geo) f (1 + p) (by rw [outcDzcRest_length]; omega) (.pub []),
      dzcRest_getD_plane Vo.pub Vo.geo p hp]
    refine outc_identA U hbij tag h64 hU O Vo rA rH iA iH csIO w hGb hOL hlc hN c (ocC_X + p) _ ?_
    rw [← hldo]
    interval_cases p <;> rfl
  -- the helpers
  have hhelp : ((outcDzcRest Vo.pub Vo.geo).map f).getD (14 + k.val) 0 = (shdOutcHd U tag h64 O rH iH w).2.1 k c := by
    rw [getD_map_lt (outcDzcRest Vo.pub Vo.geo) f (14 + k.val) (by rw [outcDzcRest_length]; omega) (.pub []),
      dzcRest_getD_helper Vo.pub Vo.geo k.val k.isLt]
    refine (outc_identH U hbij tag h64 hU O Vo rA rH iA iH csIO w hGb hOL hlc hN c (ocH_D0 + k.val) _ ?_).trans rfl
    rw [← hldo]
    have hk := k.isLt
    interval_cases (k.val) <;> rfl
  -- one lookup's denominator
  have hden : ∀ j : Fin 12,
      denK U α (((ch.getD 0 Fp2.zero).mulBase (Fp.new (UInt64.ofNat tagU8))).toK U)
          (fun idx => ((outcDzcRest Vo.pub Vo.geo).map f).getD (idx - 1) 0)
          (2 + (dzcLks.getD j.val (0, 0, 0)).1) (dzcLks.getD j.val (0, 0, 0)).2.1 (dzcLks.getD j.val (0, 0, 0)).2.2
        = shdOutcDen U tag h64 O rA iA w α ((ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF)) j c := by
    intro j
    rw [dzcLks_getD j]
    unfold denK shdOutcDen
    dsimp only
    rw [show 2 + (dLookPl j).val - 1 = 1 + (dLookPl j).val by omega, hplane (dLookPl j).val (dLookPl j).isLt,
      kI_int_toK U _ (dLookCst_bd j).1 (dLookCst_bd j).2,
      Fp.toGF_fromI64 _ (dLookCoef_bd j).1 (dLookCoef_bd j).2, map_intCast, hgK]
  have h1 : denK U α (((ch.getD 0 Fp2.zero).mulBase (Fp.new (UInt64.ofNat tagU8))).toK U)
      (fun idx => ((outcDzcRest Vo.pub Vo.geo).map f).getD (idx - 1) 0)
      (2 + (dzcLks.getD (2 * k.val) (0, 0, 0)).1) (dzcLks.getD (2 * k.val) (0, 0, 0)).2.1
      (dzcLks.getD (2 * k.val) (0, 0, 0)).2.2
      = shdOutcDen U tag h64 O rA iA w α ((ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF)) (pIdx1 k) c :=
    hden (pIdx1 k)
  have h2 : denK U α (((ch.getD 0 Fp2.zero).mulBase (Fp.new (UInt64.ofNat tagU8))).toK U)
      (fun idx => ((outcDzcRest Vo.pub Vo.geo).map f).getD (idx - 1) 0)
      (2 + (dzcLks.getD (2 * k.val + 1) (0, 0, 0)).1) (dzcLks.getD (2 * k.val + 1) (0, 0, 0)).2.1
      (dzcLks.getD (2 * k.val + 1) (0, 0, 0)).2.2
      = shdOutcDen U tag h64 O rA iA w α ((ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF)) (pIdx2 k) c :=
    hden (pIdx2 k)
  unfold dzcPairG
  dsimp only
  rw [h1, h2, show 15 + k.val - 1 = 14 + k.val by omega, hhelp]

end Vals

end ZK60.ProtocolClassify
