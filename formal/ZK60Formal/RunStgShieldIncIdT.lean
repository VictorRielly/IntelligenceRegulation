/-
D63 lane L63 (2026-11-18), part 61: **SIC_TZC's tables at `(c, 0)` are `shdIncLay`'s fields** (item 4b, step 5's
first half at stage IN-C's layout).

At the claims' semantics `stgCsv … w` and the seventeen-bit cube point `(c, 0)`:
* **`shdTzcR_vals`**: the four table values are `supp_V` at `c`, the table `τ` at `c`'s row (`fold β γ` of the row's
  tuple `(v, TAG_EMB, E~(v, r_emb), ctl(v))`), the `A_in` multiplicity plane and the helper `h_tab`.

The table row's `E~(v, r_emb)` is the public `embFold`'s word (`incCtx`: `tauTable I (I.embFold r_emb) β g`); its value
is the padded embedding's multilinear extension at `r_emb` only when `embFold` is that fold: the announced premise
`hEmb` (finding L63-8, ruled 2026-11-18: an announced public-data premise). The vocabulary is pinned to `P.V = 2^17`
(`hVV`, finding L63-7, the same ruling), so no table row is padding.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIncIdQ
import ZK60Formal.RunStgShieldIncTzc

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- SIC_TZC's table values at `(c, 0)` on `N` variables (`inc_tzc_clauses`' `r` at `lv = 17`). -/
noncomputable def shdTzcR (Vi : IncV) (ch : List Fp2) (cs : Block.Cm → Block.ZClaim → K) (N : ℕ)
    (c : Fin 17 → Bool) (j : ℕ) : K :=
  ((incTzcRest Vi.pub Vi.geo (incCtx Vi.pub ch)).map
    (stgTabK U hbij (StageV.atLog (Vi.bp (incCtx Vi.pub ch)) (incElog Vi.pub Vi.geo.bLogN 2)) cs 17 1
      (fun i : Fin N => (bit (cptS 17 c i) : K)))).getD j 0

/-- The table `τ`'s row at a vocabulary id, read in `K`. -/
theorem tauRow_toK (hU : U ^ 2 = algebraMap GF K 7) (I : IncPub) (ef : List Fp2) (beta gEmb : Fp2)
    (hg : gEmb.Canon) (x : ℕ) (hx : x < 2 ^ 63) :
    ((((kI x).add (beta.mul (ef.getD x Fp2.zero))).add
        (if I.ctl x then beta.mul beta else Fp2.zero)).add gEmb).toK U
      = (x : K) + beta.toK U * (ef.getD x Fp2.zero).toK U
        + (if I.ctl x then beta.toK U ^ 2 else 0) + gEmb.toK U := by
  have hc : (if I.ctl x then beta.mul beta else Fp2.zero).Canon := by
    split_ifs
    · exact Fp2.canon_mul _ _
    · exact Fp2.canon_zero
  rw [Fp2.toK_add U _ _ (Fp2.canon_add _ _) hg, Fp2.toK_add U _ _ (Fp2.canon_add _ _) hc,
    Fp2.toK_add U _ _ (kI_canon _) (Fp2.canon_mul _ _), Fp2.toK_mul U hU, kI_nat_toK U x hx]
  congr 2
  split_ifs
  · rw [Fp2.toK_mul U hU, sq]
  · rw [Fp2.toK_zero]

/-- **SIC_TZC'S TABLES AT `(c, 0)` ARE THE LAYOUT'S FIELDS** (with `hEmb`, `hVV`). -/
theorem shdTzcR_vals (hU : U ^ 2 = algebraMap GF K 7) (P : InPublic shieldS0) (Vi : IncV)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iB iA rA rH iH : ℕ) (hrA : rA = 41)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (w : StgVw Lq)
    (ch : List Fp2) (hl : ch.length = 15) (hch : ∀ a ∈ ch, a.Canon)
    (hvoc : Vi.pub.vocLog = 17) (hGb : Vi.geo.bLogN = 14) (hlc : ∀ cx, 0 < (Vi.bp cx).logCols)
    (hns : Vi.pub.numSpecial = P.ns) (hVV : P.V = 131072)
    (hEmb : ∀ rEmb : List Fp2, rEmb.length = 12 → (∀ a ∈ rEmb, a.Canon) → ∀ v : Fin P.V,
      ((Vi.pub.embFold rEmb).getD v Fp2.zero).toK U
        = mleAt (fun c => algebraMap GF K (Epad v c)) (fun c : Fin 12 => (rEmb.getD c Fp2.zero).toK U))
    (hv : Vi.pub.v = P.V) (hV : P.V ≤ 2 ^ 17) (htok : Vi.pub.tokens = 128)
    (hcq : ∀ t : shieldS0.Tok, Vi.pub.ctlQ t.val = decide (ctlPos P t = 1))
    {N : ℕ} (hN : N = 18) (c : Fin 17 → Bool) :
    let cs := stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w
    let L := shdIncLay U tag h64 P Vi.pub Epad iB iA w hv hV htok hcq
    let ω := incChalOf U ch
    shdTzcR U hbij Vi ch cs N c 0 = L.suppv c ∧ shdTzcR U hbij Vi ch cs N c 1 = L.tau ω c
      ∧ shdTzcR U hbij Vi ch cs N c 2 = L.m c
      ∧ shdTzcR U hbij Vi ch cs N c 3
          = (shdIncHd U tag h64 Vi.pub ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w).2.1 c := by
  intro cs L ω
  subst hrA
  set I := Vi.pub with hI
  set G := Vi.geo with hG
  set cx := incCtx I ch with hcx
  set P' := StageV.atLog (Vi.bp cx) (incElog I G.bLogN 2) with hP'
  set x : Fin N → K := fun i => (bit (cptS 17 c i) : K) with hx
  have hidx : msbIndex 17 c < 2 ^ I.vocLog := by rw [hvoc]; exact msbIndex_lt 17 c
  have hsn : 2 ^ I.vocLog = 2 ^ 17 := by rw [hvoc]
  have hNlt : 17 < N := by omega
  have hidxV : msbIndex 17 c < P.V := by rw [hVV]; exact msbIndex_lt 17 c
  have g0 : shdTzcR U hbij Vi ch cs N c 0 = stgTabK U hbij P' cs 17 1 x (.pub (supp I.v (2 ^ I.vocLog))) := rfl
  have g1 : shdTzcR U hbij Vi ch cs N c 1 = stgTabK U hbij P' cs 17 1 x (.pub cx.tauTab) := rfl
  have g2 : shdTzcR U hbij Vi ch cs N c 2 = stgTabK U hbij P' cs 17 1 x
      (.priv ⟨.a, [((incLay I G.bLogN).aOff incA_MULT, Fp2.one)], (incLay I G.bLogN).aLog.getD incA_MULT 0,
        rhoC 0 ((incLay I G.bLogN).aLog.getD incA_MULT 0),
        (incLay I G.bLogN).aMaskBase + 2 * ((incLay I G.bLogN).prefixA 2 + 0), 0⟩) := rfl
  have g3 : shdTzcR U hbij Vi ch cs N c 3 = stgTabK U hbij P' cs 17 1 x
      (.priv ⟨.h, [(((incLay I G.bLogN).hOff incH_TAB).1, Fp2.one),
          (((incLay I G.bLogN).hOff incH_TAB).2, Block.fp2U)],
        (incLay I G.bLogN).hLog.getD incH_TAB 0, rhoC 0 ((incLay I G.bLogN).hLog.getD incH_TAB 0),
        (incLay I G.bLogN).hMaskBase + 2 * ((incLay I G.bLogN).prefixH 2 + 0), 0⟩) := rfl
  have hpub : ∀ pv : List Fp2, pv.length = 2 ^ I.vocLog →
      stgTabK U hbij P' cs 17 1 x (.pub pv) = (pv.getD (msbIndex 17 c) Fp2.zero).toK U := by
    intro pv hpv
    exact stgTabK_pub_cptS U hbij P' cs 17 c hN pv (by rw [hpv, hsn])
  refine ⟨?_, ?_, ?_, ?_⟩
  · -- `supp_V`
    rw [g0, hpub _ (by simp [supp]), supp_getD_toK U _ _ _ hidx]
    rfl
  · -- the table `τ`
    have hgemb : cx.gEmb.Canon := Fp2.canon_mulBase _ _
    have hrE : cx.rEmb.length = 12 := by
      show (ch.drop 3).length = 12
      rw [List.length_drop, hl]
    have hrEc : ∀ a ∈ cx.rEmb, a.Canon := fun a ha => hch a (List.mem_of_mem_drop ha)
    rw [g1, hpub _ (by simp [cx, incCtx, tauTable]), show cx.tauTab = tauTable I (I.embFold cx.rEmb) cx.beta cx.gEmb
      from rfl]
    unfold tauTable
    dsimp only
    rw [rangeMap_getD _ _ hidx]
    have hidxv : msbIndex 17 c < I.v := by rw [hv]; exact hidxV
    rw [ite_eq_left hidxv, tauRow_toK U hU I _ _ _ hgemb _ (by have := msbIndex_lt 17 c; omega)]
    -- the layout's `τ`
    show _ = (if h : msbIndex 17 c < P.V then
      fold ω.1.1.1 ω.1.1.2 (tTup (RingHom.id K) (shdIncDataK U tag h64 P I Epad iB iA w) ω.2 ⟨msbIndex 17 c, h⟩)
      else 0)
    rw [dite_eq_left hidxV]
    have hE := hEmb cx.rEmb hrE hrEc ⟨msbIndex 17 c, hidxV⟩
    simp only [fold, tTup, RingHom.id_apply]
    have hgE : cx.gEmb.toK U = (ch.getD 1 Fp2.zero).toK U * algebraMap GF K ((tagEmb : ℕ) : GF) := by
      show ((ch.getD 1 Fp2.zero).mulBase (Fp.new (UInt64.ofNat tagEmb))).toK U = _
      rw [Fp2.toK_mulBase, Fp.new_toGF_ofNat _ (by unfold tagEmb; norm_num)]
    have hrK : (fun c : Fin 12 => (cx.rEmb.getD c Fp2.zero).toK U) = ω.2 := by
      funext c'
      show ((ch.drop 3).getD c'.val Fp2.zero).toK U = (ch.getD (3 + c'.val) Fp2.zero).toK U
      rw [List.getD_eq_getElem?_getD, List.getElem?_drop, ← List.getD_eq_getElem?_getD]
    rw [hrK] at hE
    rw [hE, hgE]
    have hctl : (if I.ctl (msbIndex 17 c) then (cx.beta.toK U) ^ 2 else 0)
        = (cx.beta.toK U) ^ 2 * algebraMap GF K ((ctl P (msbIndex 17 c) : ℕ) : GF) := by
      unfold IncPub.ctl ctl
      rw [hns]
      by_cases hc : msbIndex 17 c < P.ns
      · simp [hc]
      · simp [hc]
    rw [hctl]
    show (msbIndex 17 c : K) + _ * _ + _ + _ = algebraMap GF K ((msbIndex 17 c : ℕ) : GF)
      + (ch.getD 1 Fp2.zero).toK U * algebraMap GF K ((tagEmb : ℕ) : GF)
      + (ch.getD 0 Fp2.zero).toK U * mleAt (fun b => algebraMap GF K (Epad ⟨msbIndex 17 c, hidxV⟩ b)) ω.2
      + (ch.getD 0 Fp2.zero).toK U ^ 2 * algebraMap GF K ((ctl P (msbIndex 17 c) : ℕ) : GF)
    have hβ : cx.beta.toK U = (ch.getD 0 Fp2.zero).toK U := rfl
    rw [hβ]
    simp only [map_natCast]
    ring
  · -- the `A_in` multiplicity plane
    rw [g2]
    refine (stgTabK_priv_cptS U hbij hU P' cs 41 ogStage.lc ogStage.Q
      (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 41 iA w) (by decide) 17 c hN _ (by intro _; rfl)
      (by exact List.cons_ne_nil _ _) (by show 0 < I.vocLog; omega) (by simp [rhoC]) (by exact hlc cx)
      (by intro c' hc w' hw; simp [rhoC] at hc; obtain ⟨_, _, rfl⟩ := hc; cases hw)).trans ?_
    rw [privZ_eq_planeZ U _ _ _ _ 17 c hNlt _ [((incLay I 14).aOff incA_MULT, Fp2.one)] .a
      (by rw [hGb]) (by show I.vocLog = 17; exact hvoc) rfl]
    rfl
  · -- the helper `h_tab`
    rw [g3]
    refine (stgTabK_priv_cptS U hbij hU P' cs rH ogStage.lc ogStage.Q
      (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w) (by decide) 17 c hN _ (by intro _; rfl)
      (by exact List.cons_ne_nil _ _) (by show 0 < I.vocLog; omega) (by simp [rhoC]) (by exact hlc cx)
      (by intro c' hc w' hw; simp [rhoC] at hc; obtain ⟨_, _, rfl⟩ := hc; cases hw)).trans ?_
    rw [privZ_eq_planeZ U _ _ _ _ 17 c hNlt _
      [(((incLay I 14).hOff incH_TAB).1, Fp2.one), (((incLay I 14).hOff incH_TAB).2, Block.fp2U)] .h
      (by rw [hGb]) (by show I.vocLog = 17; exact hvoc) rfl]
    rfl

end Vals

end ZK60.ProtocolClassify
