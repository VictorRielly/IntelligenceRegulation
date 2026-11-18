/-
D63 lane L63 (2026-11-18), part 56: **SIC_QZC's (INC-01's) clauses at every cube point from its define polynomial
vanishing everywhere** (item 4b, steps 2 and 3 of HANDOFF_20261118_2.md; generic in the stage's `IncV`).

INC-01 is `eq(τ, ·)·(μ0·logup + μ1·bos + μ2·tmpl + μ3·(1 − supp)·(tok + ζ·h_q))` (`incDefQZC_ok`). If its define
polynomial `stgΦBC` vanishes at every draw (what an alive define state gives, `stg_def_zero_of_alive`), then at the
draw `τ = b`'s bits with nonzero `μ`, `ζ` it is the batched value at the cube point `(b, 0)` (`stgΦBC_sa_eval`,
`cube_eqDraw_single`), and all four clauses and both pad planes vanish there (`clauses5_of_combo`).

* `incQzcRest`, `qzcPolyK`: INC-01's tables after `eq` and its polynomial read in `K`;
* **`inc_qzc_clauses`**: the five equations on the table values at `(b, 0)`, for every `b`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIncEval

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

section Qzc

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- INC-01's tables after its `eq` table (`incDefQZC_ok`): `supp_T`, `u0`, `π`, `κ`, `cq`, `A tok`, `H h_q`,
`B_in` at `(row bits, r_emb)`. -/
def incQzcRest (I : IncPub) (G : IncGeo) (cx : IncCtx) : List Block.Tab :=
  [.pub (supp I.tokens (2 ^ I.tiLog)),
   .pub (supp 1 (2 ^ I.tiLog)),
   .pub ((List.range (2 ^ I.tiLog)).map (fun t => if I.isTemplate t then Fp2.one else Fp2.zero)),
   .pub ((List.range (2 ^ I.tiLog)).map (fun t => kI (I.kappa t))),
   .pub ((List.range (2 ^ I.tiLog)).map (fun t => if I.ctlQ t then cx.beta.mul cx.beta else Fp2.zero)),
   .priv ⟨.a, [((incLay I G.bLogN).aOff incA_TOK, Fp2.one)], (incLay I G.bLogN).aLog.getD incA_TOK 0,
     rhoC 0 ((incLay I G.bLogN).aLog.getD incA_TOK 0),
     (incLay I G.bLogN).aMaskBase + 2 * ((incLay I G.bLogN).prefixA 1 + 0), 0⟩,
   .priv ⟨.h, [(((incLay I G.bLogN).hOff incH_Q).1, Fp2.one), (((incLay I G.bLogN).hOff incH_Q).2, Block.fp2U)],
     (incLay I G.bLogN).hLog.getD incH_Q 0, rhoC 0 ((incLay I G.bLogN).hLog.getD incH_Q 0),
     (incLay I G.bLogN).hMaskBase + 2 * ((incLay I G.bLogN).prefixH 1 + 0), 0⟩,
   .priv ⟨.out, [(0, Fp2.one)], I.bInLog, rhoC (I.tiLog - I.tBits) I.tiLog ++ fixedC cx.rEmb, G.bInRow, 0⟩]

/-- INC-01's polynomial read in `K`, at the batching `m0 … m3` and the pad fold `z` (`g 0` the `eq` table, `g (j+1)`
the `j`-th of `incQzcRest`). -/
def qzcPolyK (I : IncPub) (cx : IncCtx) (m0 m1 m2 m3 z : K) (g : ℕ → K) : K :=
  g 0 * ((((m0 * (g 7 * (cx.alpha.toK U - (((g 6 + cx.beta.toK U * g 8) + g 5) + cx.gEmb.toK U)) - g 1))
    + (m1 * (g 2 * (g 6 - (kI I.bos).toK U)))) + (m2 * (g 3 * (g 6 - g 4))))
    + (m3 * ((1 - g 1) * (g 6 + z * g 7))))

/-- **SIC_QZC'S CLAUSES AND PADS AT EVERY CUBE POINT, from its define polynomial vanishing at every draw.** -/
theorem inc_qzc_clauses {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P0 : Block.BlockParams) (Vi : IncV) (ch : List Fp2) (hch : ∀ a ∈ ch, a.Canon)
    (hP : StgSame P0 (Vi.bp (incCtx Vi.pub ch)))
    (lc h Q eC rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : Vi.pub.lt ≤ lc) (hIO1 : StgCsIODeg U hbij Vi.geo.bLogN (IncPrivIO1 Vi.pub) csIO)
    (hd : List (List Fp2)) (hhd : hd.length = 1)
    (hzero : ∀ y : Fin (P0.draws 1) → K, stgΦBC U hbij P0 (Vi.bp (incCtx Vi.pub ch))
      (incElog Vi.pub Vi.geo.bLogN) (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
      (Fp2.zero, Fp2.zero, Fp2.zero) hd 1 (stgWords U hbij y) = 0)
    (tl : ℕ) (htl : Vi.pub.tiLog = tl) (b : Fin tl → Bool) :
    let r : ℕ → K := fun j => ((incQzcRest Vi.pub Vi.geo (incCtx Vi.pub ch)).map
      (stgTabK U hbij (StageV.atLog (Vi.bp (incCtx Vi.pub ch)) (incElog Vi.pub Vi.geo.bLogN 1))
        (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) tl 1
        (fun i : Fin (stgN P0 1) => (bit (cptS tl b i) : K)))).getD j 0
    r 6 * ((incCtx Vi.pub ch).alpha.toK U
        - (((r 5 + (incCtx Vi.pub ch).beta.toK U * r 7) + r 4) + (incCtx Vi.pub ch).gEmb.toK U)) - r 0 = 0
      ∧ r 1 * (r 5 - (kI Vi.pub.bos).toK U) = 0
      ∧ r 2 * (r 5 - r 3) = 0
      ∧ (1 - r 0) * r 5 = 0
      ∧ (1 - r 0) * r 6 = 0 := by
  subst htl
  intro r
  simp only [r]
  revert b
  set I := Vi.pub with hI
  set G := Vi.geo with hG
  set cx := incCtx I ch with hcx
  set tl := I.tiLog with htl'
  set cs := stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v with hcs
  intro b
  have hdraws : P0.draws 1 = tl + 5 := by rw [hP.1]; show tl + 4 + 1 = tl + 5; omega
  have hN : stgN P0 1 = tl + 1 := by unfold stgN; rw [stg_slotShape hP]; rfl
  have hbeta : cx.beta.Canon := Fp2.canon_getD hch 0
  have halpha : cx.alpha.Canon := Fp2.canon_getD hch 2
  have hgemb : cx.gEmb.Canon := Fp2.canon_mulBase _ _
  have hremb : ∀ a ∈ cx.rEmb, a.Canon := fun a ha => hch a (List.mem_of_mem_drop ha)
  have hj0 : tl < P0.draws 1 := by omega
  have hj1 : tl + 1 < P0.draws 1 := by omega
  have hj2 : tl + 2 < P0.draws 1 := by omega
  have hj3 : tl + 3 < P0.draws 1 := by omega
  have hj4 : tl + 4 < P0.draws 1 := by omega
  -- the tables fit the slot's `tl` main variables
  have hfit : tabsFit tl (incQzcRest I G cx) := by
    intro t ht
    simp only [incQzcRest, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
    · show (supp I.tokens (2 ^ tl)).length = 2 ^ tl
      simp [supp]
    · show (supp 1 (2 ^ tl)).length = 2 ^ tl
      simp [supp]
    · show ((List.range (2 ^ tl)).map _).length = 2 ^ tl
      simp
    · show ((List.range (2 ^ tl)).map _).length = 2 ^ tl
      simp
    · show ((List.range (2 ^ tl)).map _).length = 2 ^ tl
      simp
    · trivial
    · trivial
    · trivial
  have hok : ∀ t ∈ incQzcRest I G cx, TabPrivOK (IncPrivIO1 I) t := by
    intro t ht
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_a_rho _ _ _ _
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_h_rho _ _ _ _ _
    rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_inc_io1 I _ _ _ _ hremb
    exact absurd ht List.not_mem_nil
  have hcan : ∀ t ∈ incQzcRest I G cx, ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon := by
    intro t ht pt s he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    exact absurd ht List.not_mem_nil
  -- the batched value at `(b, 0)` vanishes for all nonzero `μ`, `ζ`
  refine clauses5_of_combo (ZK60.Exec.two_ne_zero_K (K := K)) _ _ _ _ _ ?_
  intro μ0 μ1 μ2 μ3 ζ h0 h1 h2 h3 h4
  let y : Fin (P0.draws 1) → K := fun i =>
    if hi : i.val < tl then bit (b ⟨i.val, hi⟩)
    else if i.val = tl then μ0 else if i.val = tl + 1 then μ1 else if i.val = tl + 2 then μ2
    else if i.val = tl + 3 then μ3 else ζ
  have hy0 : y ⟨tl, hj0⟩ = μ0 := by simp [y]
  have hy1 : y ⟨tl + 1, hj1⟩ = μ1 := by simp [y]
  have hy2 : y ⟨tl + 2, hj2⟩ = μ2 := by simp [y]
  have hy3 : y ⟨tl + 3, hj3⟩ = μ3 := by simp [y]
  have hy4 : y ⟨tl + 4, hj4⟩ = ζ := by simp [y]
  have hyb : ∀ a (ha : a < tl), y ⟨a, by omega⟩ = bit (b ⟨a, ha⟩) := by
    intro a ha
    simp [y, ha]
  have hZ : ∀ i ∈ Z_range (P0.draws 1) tl 5, y i ≠ 0 := by
    intro i hi
    simp only [Z_range, Finset.mem_filter, Finset.mem_univ, true_and] at hi
    have hi0 : ¬ i.val < tl := by omega
    by_cases e0 : i.val = tl
    · have : i = ⟨tl, hj0⟩ := Fin.ext e0
      rw [this, hy0]; exact h0
    by_cases e1 : i.val = tl + 1
    · have : i = ⟨tl + 1, hj1⟩ := Fin.ext e1
      rw [this, hy1]; exact h1
    by_cases e2 : i.val = tl + 2
    · have : i = ⟨tl + 2, hj2⟩ := Fin.ext e2
      rw [this, hy2]; exact h2
    by_cases e3 : i.val = tl + 3
    · have : i = ⟨tl + 3, hj3⟩ := Fin.ext e3
      rw [this, hy3]; exact h3
    · have : i = ⟨tl + 4, hj4⟩ := Fin.ext (by show i.val = tl + 4; omega)
      rw [this, hy4]; exact h4
  have hdef := incDefQZC_ok U hbij hU I G cx hdraws y hZ
  have hev := stgΦBC_sa_eval U hbij hU tag h64 P0 (Vi.bp cx) (incElog I G.bLogN) hP lc h Q eC rA rH iA iH
    (IncPrivIO1 I) csIO v hlc (Fp2.zero, Fp2.zero, Fp2.zero) hd 1 tl 1 4 tl hIO1 hhd (by omega) le_rfl rfl rfl
    (incQzcRest I G cx) _ y hdef hok hcan (qzcPolyK U I cx μ0 μ1 μ2 μ3 ζ)
    (fun vals hv => by
      have hz_eq : ((((stgWords U hbij y).drop (tl + 4)).take 1).getD 0 Fp2.zero).toK U = ζ := by
        rw [getD_take_lt _ 1 0 (by norm_num), getD_drop, ← hy4]
        exact stgWords_getD_toK U hbij y (tl + 4) hj4
      unfold qzcPolyK
      dsimp only
      rw [Fp2.toK_mul U hU,
          Fp2.toK_add U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
          Fp2.toK_add U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
          Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU, Fp2.toK_mul U hU, Fp2.toK_mul U hU,
          Fp2.toK_mul U hU, Fp2.toK_mul U hU, Fp2.toK_mul U hU,
          vg_drop_take_toK U hbij y tl 4 0 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y tl 4 1 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y tl 4 2 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y tl 4 3 (by norm_num) (by omega),
          Fp2.toK_sub U _ _ (Fp2.canon_mul _ _) (vg_canon hv 1),
          Fp2.toK_mul U hU,
          Fp2.toK_sub U _ _ halpha (Fp2.canon_add _ _),
          Fp2.toK_add U _ _ (Fp2.canon_add _ _) hgemb,
          Fp2.toK_add U _ _ (Fp2.canon_add _ _) (vg_canon hv 5),
          Fp2.toK_add U _ _ (vg_canon hv 6) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU,
          Fp2.toK_sub U _ _ (vg_canon hv 6) (kI_canon _),
          Fp2.toK_sub U _ _ (vg_canon hv 6) (vg_canon hv 4),
          Fp2.toK_mul U hU, Fp2.toK_sub U _ _ Fp2.canon_one (vg_canon hv 1), Fp2.toK_one,
          Fp2.toK_add U _ _ (vg_canon hv 6) (Fp2.canon_mul _ _), Fp2.toK_mul U hU,
          hz_eq]
      simp only [vg_toK_map, Nat.add_zero, hy0, hy1, hy2, hy3])
    (fun g hg => by
      unfold qzcPolyK
      have hq : IndDegLE 1 (fun x => ((g 6 x + cx.beta.toK U * g 8 x) + g 5 x) + cx.gEmb.toK U) :=
        IndDegLE.add (IndDegLE.add (IndDegLE.add (hg 6) (IndDegLE.cmul _ (hg 8))) (hg 5)) (IndDegLE.const _)
      have hl : IndDegLE 2 (fun x => g 7 x * (cx.alpha.toK U - (((g 6 x + cx.beta.toK U * g 8 x) + g 5 x)
          + cx.gEmb.toK U)) - g 1 x) :=
        IndDegLE.sub (IndDegLE.mul (hg 7) (IndDegLE.sub (IndDegLE.const _) hq)) (IndDegLE.mono (hg 1) (by norm_num))
      have hb : IndDegLE 2 (fun x => g 2 x * (g 6 x - (kI I.bos).toK U)) :=
        IndDegLE.mul (hg 2) (IndDegLE.sub (hg 6) (IndDegLE.const _))
      have htm : IndDegLE 2 (fun x => g 3 x * (g 6 x - g 4 x)) :=
        IndDegLE.mul (hg 3) (IndDegLE.sub (hg 6) (hg 4))
      have hpd : IndDegLE 2 (fun x => (1 - g 1 x) * (g 6 x + ζ * g 7 x)) :=
        IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) (hg 1)) (IndDegLE.add (hg 6) (IndDegLE.cmul _ (hg 7)))
      have hsum : IndDegLE 2 (fun x =>
          (((μ0 * (g 7 x * (cx.alpha.toK U - (((g 6 x + cx.beta.toK U * g 8 x) + g 5 x) + cx.gEmb.toK U)) - g 1 x))
            + (μ1 * (g 2 x * (g 6 x - (kI I.bos).toK U))))
            + (μ2 * (g 3 x * (g 6 x - g 4 x))))
            + (μ3 * ((1 - g 1 x) * (g 6 x + ζ * g 7 x)))) :=
        IndDegLE.add (IndDegLE.add (IndDegLE.add (IndDegLE.cmul _ hl) (IndDegLE.cmul _ hb)) (IndDegLE.cmul _ htm))
          (IndDegLE.cmul _ hpd)
      exact IndDegLE.mono (IndDegLE.mul (hg 0) hsum) (by norm_num))
  rw [hzero y, ite_eq_left hfit, ← hcs] at hev
  set F : (Fin (stgN P0 1) → K) → K := fun x =>
    let r' : ℕ → K := fun j => ((incQzcRest I G cx).map
        (stgTabK U hbij (StageV.atLog (Vi.bp cx) (incElog I G.bLogN 1)) cs tl 1 x)).getD j 0
    (((μ0 * (r' 6 * (cx.alpha.toK U - (((r' 5 + cx.beta.toK U * r' 7) + r' 4) + cx.gEmb.toK U)) - r' 0))
      + (μ1 * (r' 1 * (r' 5 - (kI I.bos).toK U)))) + (μ2 * (r' 2 * (r' 5 - r' 3))))
      + (μ3 * ((1 - r' 0) * (r' 5 + ζ * r' 6))) with hF
  have hcube := cube_eqDraw_single (M := P0.draws 1) (N := stgN P0 1) tl (by omega) hN y b hyb F
  have hev' : (0 : K) = cubeSum (fun x : Fin (stgN P0 1) → K => eqDrawK tl tl 1 (by omega) y x * F x) := hev
  rw [hcube, hF] at hev'
  dsimp only at hev'
  linear_combination (-1 : K) * hev'

end Qzc

end ZK60.ProtocolClassify
