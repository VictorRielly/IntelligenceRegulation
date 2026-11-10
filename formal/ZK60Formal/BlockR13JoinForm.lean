/-
D63 lane L47 (2026-11-10), part R2: **R13's `SC_TAB` named identity** (deliverable 4, item 1) at the R13 rung and at
every layer of the app's Shieldstral T128 R13 block, for the certified polynomial `spTabR` (BlockR13JoinTab.lean).

The proof is generic in the configuration `c`: it needs only that the program's raw slot `19` is the shape
`rawSlotR c` (`eq(τ)`, three triples `(A` plane `t0 + k`, `H` plane `fh 8 + k`, value column`)`, the two gates; L13's
`tabIr` on the triples, draws `14 … 16`, `ζ` draw `18`, the pad groups `(10, [1, 4])`, `(10, [2, 5])`, `(11, [7])`,
`(11, [8])`), which is checked by evaluation at each configuration. The reserved mask rows the numbering assigns
(they depend on the earlier slots) are never needed: a table's value on the cube does not read them.

* `numProg_getD`: the numbered program's slot `k` is the raw slot `k` numbered from SOME claim sites;
* `drR`, `aTR`, `hTR`, `rawTabsR`, `irR`, `rawSlotR`; **`rawSlot19_rung`** (the R13 rung) and
  **`rawSlot19_shield`** (each of the 26 Shieldstral layers of `shieldExport`), by evaluation;
* `tabR_vals`: the value list at a cube point with the zero extension, entry by entry;
* **`tabR_cube`**: the slot's cube sum is `Σ_b eq(τ, b)·(Σ_k μ_k·cTabR_k(b) + μ_pad·Σ_j ζ^j·wTabR_j(b))`;
* **`tabR_formAt`** (any configuration with the raw slot's shape), **`tabR13_formAt_rung`** (an `IsRungR13`-shaped
  verifier at `cfgRungR13`), **`tabR13_formAt_shield`** (an `IsShieldR13`-shaped verifier, every layer of
  `shieldExport`): lane L36's `FormAt` at slot `19`, on any public tables whose slot-`19` tables are `restR13`'s.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13JoinTab
import ZK60Formal.BlockInstProf

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13T

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.Join.W16.Tab
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.Build (tabIr tabIr_eval tabSem padSem)
open ZK60.Exec.Slot.Compose (tabIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)

/-! ## The numbered program's slot -/

/-- **The numbered program's slot `k` is the raw slot `k` numbered from some claim sites.** -/
theorem numProg_getD (aB hB ioIn ioOut : ℕ) : ∀ (ss : List SlotS) (k ak hk : ℕ), k < ss.length →
    ∃ ak' hk', (DefW16.numProg aB hB ioIn ioOut ak hk ss).getD k SlotS.empty
      = DefW16.numSlot aB hB ioIn ioOut ak' hk' (ss.getD k SlotS.empty)
  | [], _, _, _, h => absurd h (Nat.not_lt_zero _)
  | _ :: _, 0, ak, hk, _ => ⟨ak, hk, rfl⟩
  | s :: ss, k + 1, ak, hk, h => by
    obtain ⟨a', h', e⟩ := numProg_getD aB hB ioIn ioOut ss k (ak + cmCountS .a s.tabs) (hk + cmCountS .h s.tabs)
      (by simp only [List.length_cons] at h; omega)
    exact ⟨a', h', e⟩

/-- **R13's slot `19`, numbered**: the raw slot numbered from some claim sites. -/
theorem progR13_slot19 (c : W16Cfg) (ioIn ioOut : ℕ) : ∃ ak hk, (DefR13.progR13 c ioIn ioOut).getD 19 SlotS.empty
    = DefW16.numSlot (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut ak hk (DefR13.rawSlot c 19) := by
  have hlen : 19 < (DefR13.rawProg c).length := by
    unfold DefR13.rawProg
    rw [List.length_map, List.length_range]
    decide
  obtain ⟨a, h, e⟩ := numProg_getD (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut (DefR13.rawProg c) 19 0 0 hlen
  refine ⟨a, h, ?_⟩
  show (DefW16.numProg (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut 0 0 (DefR13.rawProg c)).getD 19
    SlotS.empty = _
  rw [e]
  congr 1

/-! ## The raw slot -/

/-- The draws `off … off + n − 1` of slot `19`, as expressions. -/
def drR (off n : ℕ) : List Sym := (List.range n).map fun i => Sym.dr 19 (off + i)

/-- R13's multiplicity table `k` before the numbering (`A` plane `t0 + k`). -/
def aTR (c : W16Cfg) (k : ℕ) : TabS :=
  .priv ⟨.a, [(DefR13.aOff c ((DefR13.ids c).t0 + k), false)], 14, DefW16.rhoC 0 14, 0, 0⟩

/-- R13's helper table `k` before the numbering (`H` plane `fh 8 + k`). -/
def hTR (c : W16Cfg) (k : ℕ) : TabS :=
  .priv ⟨.h, [((DefR13.hOff c (DefR13.fh c 8 + k)).1, false), ((DefR13.hOff c (DefR13.fh c 8 + k)).2, true)], 14,
    DefW16.rhoC 0 14, 0, 0⟩

/-- R13's `SC_TAB` tables before the numbering. -/
def rawTabsR (c : W16Cfg) : List TabS :=
  [.eq (drR 0 14) 0, aTR c 0, hTR c 0, .pub 0, aTR c 1, hTR c 1, .pub 0, aTR c 2, hTR c 2, .pub 0, .pub 0, .pub 0]

/-- R13's `SC_TAB` IR (L44's transcription of `argument_accuracy.rs:416-444`). -/
def irR : ZK60.Exec.Slot.Ir Sym :=
  tabIr DefW16.cstS 0 .alpha [(1, 2, 3), (4, 5, 6), (7, 8, 9)] (drR 14 4) (fun j => Sym.pow (Sym.dr 19 18) j)
    [(10, [1, 4]), (10, [2, 5]), (11, [7]), (11, [8])]

/-- R13's raw `SC_TAB` slot. -/
def rawSlotR (c : W16Cfg) : SlotS := ⟨rawTabsR c, irR, [], [.dr 19 18]⟩

/-- **The R13 rung's raw slot `19`**, by evaluation. -/
theorem rawSlot19_rung : DefR13.rawSlot DefR13.cfgRungR13 19 = rawSlotR DefR13.cfgRungR13 := rfl

/-- **Every Shieldstral layer's raw slot `19`**, by evaluation, one layer at a time. -/
theorem rawSlot19_shield : ∀ L ∈ ZK60.RunShape.Shield.shieldExport,
    DefR13.rawSlot (DefR13.cfgShieldR13 L) 19 = rawSlotR (DefR13.cfgShieldR13 L) := by
  intro L hL
  simp only [ZK60.RunShape.Shield.shieldExport, List.mem_cons, List.not_mem_nil, or_false] at hL
  rcases hL with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> rfl

/-! ## The value list -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem tabRA_cpt (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (e : ℕ) (b : Fin 14 → Bool)
    (ev : Sym → Fp2) (pub : ℕ → List Fp2) (off m : ℕ) :
    tabK U P D 14 e (cpt 14 e b) (TabS.eval ev pub (.priv ⟨.a, [(off, false)], 14, DefW16.rhoC 0 14, m, 0⟩))
      = aPl U P D off 14 b := by
  rw [aTab_eval, tabK_pa_cpt U P D hrl 14 e b 14 (by norm_num) rfl, castB_rfl]

theorem tabRH_cpt (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .h) (e : ℕ) (b : Fin 14 → Bool)
    (ev : Sym → Fp2) (pub : ℕ → List Fp2) (re im m : ℕ) :
    tabK U P D 14 e (cpt 14 e b) (TabS.eval ev pub (.priv ⟨.h, [(re, false), (im, true)], 14, DefW16.rhoC 0 14, m, 0⟩))
      = hPl U P D re im 14 b := by
  rw [hTab_eval, tabK_ph_cpt U P D hrl 14 e b 14 (by norm_num) rfl, castB_rfl]

theorem tabRP_cpt (P : BlockParams) (D : CmData K P) (e : ℕ) (b : Fin 14 → Bool) (ev : Sym → Fp2)
    (pub : ℕ → List Fp2) (i : ℕ) :
    tabK U P D 14 e (cpt 14 e b) (TabS.eval ev pub (.pub i)) = ((pub i).getD (msbIndex 14 b) Fp2.zero).toK U := by
  rw [pubT_eval, tabK_pub_cpt]

end Vals

/-! ## The cube sum -/

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **R13's `SC_TAB` cube sum** (`n = 14`), for any configuration `c` and claim sites `ak`, `hk`:
`Σ_b eq(τ, b)·(Σ_k μ_k·cTabR_k(b) + μ_pad·Σ_j ζ^j·wTabR_j(b))`, `τ` draws `0 … 13`, `μ_k` draw `14 + k`, `μ_pad` draw
`17`, `ζ` draw `18`, on public tables whose slot-`19` tables are `restR13`'s. -/
theorem tabR_cube (c : W16Cfg) (P : BlockParams) (D : CmData K P) (hrlA : 0 < rowLog P .a) (hrlH : 0 < rowLog P .h)
    (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) (aB hB ioIn ioOut ak hk : ℕ) (hist : Hist) (dr : List Fp2)
    (pub : ℕ → List Fp2) (hpub : ∀ i, pub i = restR13 exp act nG 19 hist dr i) (n e : ℕ) (hn : n = 14)
    (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval ((irR.map (Sym.eval hist 19 dr)).map (Fp2.toK U))
      (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawTabsR c)).map (TabS.eval (Sym.eval hist 19 dr) pub)).map
        (tabK U P D n e x))) :
    cubeSum f = ∑ b : Fin 14 → Bool, eqPoly (fun a : Fin 14 => (dr.getD a Fp2.zero).toK U) (fun a => bit (b a))
      * (∑ k : Fin 3, (dr.getD (14 + (k : ℕ)) Fp2.zero).toK U
            * cTabR U c P D exp act nG (hist.beta, hist.gamma, hist.alpha) k b
        + (dr.getD 17 Fp2.zero).toK U
          * ∑ j : Fin 6, ((dr.getD 18 Fp2.zero).toK U) ^ (j : ℕ) * wTabR U c P D nG j b) := by
  subst hn
  have hir : ∀ v : List K, irEval ((irR.map (Sym.eval hist 19 dr)).map (Fp2.toK U)) v
      = v.getD 0 0 * (tabSem v (hist.alpha.toK U) (((drR 14 4).map (Sym.eval hist 19 dr)).map (Fp2.toK U)) 0
          [(1, 2, 3), (4, 5, 6), (7, 8, 9)]
        + padSem (ZK60.Exec.Slot.Build.cstW.map (Fp2.toK U)) v
          ((((drR 14 4).map (Sym.eval hist 19 dr)).map (Fp2.toK U)).getD 3
            (ZK60.Exec.Slot.Build.cstW.map (Fp2.toK U)).zero)
          (Fp2.toK U ∘ (Sym.eval hist 19 dr ∘ fun j => Sym.pow (Sym.dr 19 18) j)) 0
          [(10, [1, 4]), (10, [2, 5]), (11, [7]), (11, [8])]) := by
    intro v
    unfold irR
    rw [tabIr_map, tabIr_map, cstS_map, tabIr_eval _ (cstW_map_std U)]
    rfl
  have hmu : ∀ i, i < 4 → ∀ d : K, (((drR 14 4).map (Sym.eval hist 19 dr)).map (Fp2.toK U)).getD i d
      = (dr.getD (14 + i) Fp2.zero).toK U := by
    intro i hi d
    rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_map, drR, List.getElem?_map,
      List.getElem?_range hi]
    simp [Sym.eval, drawAt]
  have hzp : ∀ j, (Sym.eval hist 19 dr (Sym.pow (Sym.dr 19 18) j)).toK U = ((dr.getD 18 Fp2.zero).toK U) ^ j := by
    intro j
    rw [show Sym.eval hist 19 dr (Sym.pow (Sym.dr 19 18) j) = zpowW (dr.getD 18 Fp2.zero) j by simp [Sym.eval, drawAt],
      toK_zpowW U hU]
  set mu := ((drR 14 4).map (Sym.eval hist 19 dr)).map (Fp2.toK U) with hmuDef
  rw [cubeSum_split]
  refine Finset.sum_congr rfl (fun b _ => ?_)
  rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
  · show f (cpt 14 e b) = _
    rw [hf, hir]
    -- the value list, entry by entry
    set ev := Sym.eval hist 19 dr with hev
    have v0 : (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawTabsR c)).map (TabS.eval ev pub)).map
        (tabK U P D 14 e (cpt 14 e b))).getD 0 0
        = tabK U P D 14 e (cpt 14 e b) (.eq ((drR 0 14).map ev) 0) := rfl
    have v1 : (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawTabsR c)).map (TabS.eval ev pub)).map
        (tabK U P D 14 e (cpt 14 e b))).getD 1 0 = multTabR U c P D 0 b :=
      tabRA_cpt U P D hrlA e b ev pub _ _
    have v2 : (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawTabsR c)).map (TabS.eval ev pub)).map
        (tabK U P D 14 e (cpt 14 e b))).getD 2 0 = helpTabR U c P D 0 b :=
      tabRH_cpt U P D hrlH e b ev pub _ _ _
    have v3 : (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawTabsR c)).map (TabS.eval ev pub)).map
        (tabK U P D 14 e (cpt 14 e b))).getD 3 0 = ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U :=
      tabRP_cpt U P D e b ev pub 0
    have v4 : (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawTabsR c)).map (TabS.eval ev pub)).map
        (tabK U P D 14 e (cpt 14 e b))).getD 4 0 = multTabR U c P D 1 b :=
      tabRA_cpt U P D hrlA e b ev pub _ _
    have v5 : (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawTabsR c)).map (TabS.eval ev pub)).map
        (tabK U P D 14 e (cpt 14 e b))).getD 5 0 = helpTabR U c P D 1 b :=
      tabRH_cpt U P D hrlH e b ev pub _ _ _
    have v6 : (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawTabsR c)).map (TabS.eval ev pub)).map
        (tabK U P D 14 e (cpt 14 e b))).getD 6 0 = ((pub 1).getD (msbIndex 14 b) Fp2.zero).toK U :=
      tabRP_cpt U P D e b ev pub 1
    have v7 : (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawTabsR c)).map (TabS.eval ev pub)).map
        (tabK U P D 14 e (cpt 14 e b))).getD 7 0 = multTabR U c P D 2 b :=
      tabRA_cpt U P D hrlA e b ev pub _ _
    have v8 : (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawTabsR c)).map (TabS.eval ev pub)).map
        (tabK U P D 14 e (cpt 14 e b))).getD 8 0 = helpTabR U c P D 2 b :=
      tabRH_cpt U P D hrlH e b ev pub _ _ _
    have v9 : (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawTabsR c)).map (TabS.eval ev pub)).map
        (tabK U P D 14 e (cpt 14 e b))).getD 9 0 = ((pub 2).getD (msbIndex 14 b) Fp2.zero).toK U :=
      tabRP_cpt U P D e b ev pub 2
    have v10 : (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawTabsR c)).map (TabS.eval ev pub)).map
        (tabK U P D 14 e (cpt 14 e b))).getD 10 0 = ((pub 3).getD (msbIndex 14 b) Fp2.zero).toK U :=
      tabRP_cpt U P D e b ev pub 3
    have v11 : (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawTabsR c)).map (TabS.eval ev pub)).map
        (tabK U P D 14 e (cpt 14 e b))).getD 11 0 = ((pub 4).getD (msbIndex 14 b) Fp2.zero).toK U :=
      tabRP_cpt U P D e b ev pub 4
    have hlen : ((drR 0 14).map ev).length = 14 := by simp [drR]
    have heq : tabK U P D 14 e (cpt 14 e b) (.eq ((drR 0 14).map ev) 0)
        = eqPoly (fun a : Fin 14 => (dr.getD a Fp2.zero).toK U) (fun a => bit (b a)) := by
      rw [tabK_eqFull_cpt U P D 14 e b _ hlen]
      congr 1
      funext a
      simp [drR, hev, Sym.eval, drawAt]
    have hg0 : ((pub 3).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gateTabW nG 0 b) := by
      rw [hpub, rest19R13_gate_getD U exp act nG hist dr 3 (le_refl 3) (by norm_num) b]
    have hg1 : ((pub 4).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gateTabW nG 1 b) := by
      rw [hpub, rest19R13_gate_getD U exp act nG hist dr 4 (by norm_num) (by norm_num) b]
    have hc : ∀ k, k < 3 → ((pub k).getD (msbIndex 14 b) Fp2.zero).toK U
        = ZK60.Sound.fold (hist.beta.toK U) (hist.gamma.toK U) (tupK (tabTupE exp act nG k (msbIndex 14 b))) := by
      intro k hk
      rw [hpub]
      exact rest19R13_getD U hU exp act nG hist dr k hk b
    -- the batched relations, written out
    have hR : ∑ k : Fin 3, (dr.getD (14 + (k : ℕ)) Fp2.zero).toK U
            * cTabR U c P D exp act nG (hist.beta, hist.gamma, hist.alpha) k b
          + (dr.getD 17 Fp2.zero).toK U
            * ∑ j : Fin 6, ((dr.getD 18 Fp2.zero).toK U) ^ (j : ℕ) * wTabR U c P D nG j b
        = (dr.getD (14 + 0) Fp2.zero).toK U * (helpTabR U c P D 0 b * (hist.alpha.toK U
              - ZK60.Sound.fold (hist.beta.toK U) (hist.gamma.toK U) (tupK (tabTupE exp act nG 0 (msbIndex 14 b))))
            - multTabR U c P D 0 b)
          + (dr.getD (14 + 1) Fp2.zero).toK U * (helpTabR U c P D 1 b * (hist.alpha.toK U
              - ZK60.Sound.fold (hist.beta.toK U) (hist.gamma.toK U) (tupK (tabTupE exp act nG 1 (msbIndex 14 b))))
            - multTabR U c P D 1 b)
          + (dr.getD (14 + 2) Fp2.zero).toK U * (helpTabR U c P D 2 b * (hist.alpha.toK U
              - ZK60.Sound.fold (hist.beta.toK U) (hist.gamma.toK U) (tupK (tabTupE exp act nG 2 (msbIndex 14 b))))
            - multTabR U c P D 2 b)
          + (dr.getD (14 + 3) Fp2.zero).toK U
            * (((dr.getD 18 Fp2.zero).toK U) ^ 0
                * ((1 - algebraMap GF K (gateTabW nG 0 b)) * multTabR U c P D 0 b)
              + ((dr.getD 18 Fp2.zero).toK U) ^ 1
                * ((1 - algebraMap GF K (gateTabW nG 0 b)) * multTabR U c P D 1 b)
              + ((dr.getD 18 Fp2.zero).toK U) ^ 2
                * ((1 - algebraMap GF K (gateTabW nG 0 b)) * helpTabR U c P D 0 b)
              + ((dr.getD 18 Fp2.zero).toK U) ^ 3
                * ((1 - algebraMap GF K (gateTabW nG 0 b)) * helpTabR U c P D 1 b)
              + ((dr.getD 18 Fp2.zero).toK U) ^ 4
                * ((1 - algebraMap GF K (gateTabW nG 1 b)) * multTabR U c P D 2 b)
              + ((dr.getD 18 Fp2.zero).toK U) ^ 5
                * ((1 - algebraMap GF K (gateTabW nG 1 b)) * helpTabR U c P D 2 b)) := by
      rw [Fin.sum_univ_three, Fin.sum_univ_six]
      rfl
    rw [v0, heq]
    congr 1
    simp only [tabSem, padSem_eq_wsum _ (cstW_map_std U), padPls, wsum, List.map_cons, List.map_nil,
      List.cons_append, List.nil_append]
    rw [v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, hc 0 (by norm_num), hc 1 (by norm_num), hc 2 (by norm_num),
      hg0, hg1, hmu 0 (by norm_num), hmu 1 (by norm_num), hmu 2 (by norm_num), hmu 3 (by norm_num)]
    simp only [Function.comp_apply, hzp]
    rw [hR]
    ring
  · show f (bpt 14 e b y) = 0
    rw [hf, hir]
    show tabK U P D 14 e (bpt 14 e b y) (.eq ((drR 0 14).map (Sym.eval hist 19 dr)) 0) * _ = 0
    rw [tabK_eq_off U P D 14 e b y hy, zero_mul]

end Cube

/-! ## The named identity -/

section Form

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K]

/-- **R13's `SC_TAB` standalone named identity** at slot `19`, for any configuration whose raw slot `19` has
`rawSlotR`'s shape: a polynomial family whose value at slot `19` is `spTabR`'s at the history's `(β, γ, α)` meets
`FormAt` there, for a verifier whose slot `19` is standalone with the shape `(14, 1, 3)`, on public tables whose
slot-`19` tables are `restR13`'s. -/
theorem tabR_formAt (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) (c : W16Cfg)
    (hraw : DefR13.rawSlot c 19 = rawSlotR c) (P : BlockParams) (hd : P.draws 19 = 19)
    (hs19 : slotShape P 19 = (14, 1, 3)) (ioIn ioOut : ℕ) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) (pubs : PubTabs)
    (hrest : ∀ hist dr i, pubs 19 hist dr i = restR13 exp act nG 19 hist dr i) (D : CmData K P)
    (hrlA : 0 < rowLog P .a) (hrlH : 0 < rowLog P .h) (hkind : P.kind 19 = SlotKind.standalone)
    (Φ : (k : ℕ) → Hist → (Fin (P.draws k) → K) → K)
    (hΦ : ∀ hist x, Φ 19 hist x = (spTabR U c hcard P hd D exp act nG (hist.beta, hist.gamma, hist.alpha)).Φ x)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) :
    FormAt U P (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs) Φ bga rs 19 := by
  intro r df hr _
  refine Or.inl ⟨hkind, ?_⟩
  rw [hΦ]
  obtain ⟨ak, hk, hslot⟩ := progR13_slot19 c ioIn ioOut
  unfold spSum
  rw [tabR_cube U hU c P D hrlA hrlH exp act nG (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut ak hk
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 19)) r.draws (pubs 19 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 19)) r.draws)
    (fun i => hrest _ _ i) (slotShape P 19).1 (slotShape P 19).2.1 (by rw [hs19]) _
    (fun x => by rw [polyS_seenOf U P D _ _ bga rs 19 r hr x, hslot, hraw]; rfl)]
  rfl

/-- The R13 rung's slot `19` draws `19` challenges. -/
theorem hd19_rung (P : BlockParams) (hdr : P.draws = ZK60.Exec.Block.R13.rungDraws) : P.draws 19 = 19 := by
  rw [hdr]
  decide

/-- The Shieldstral block's slot `19` draws `19` challenges. -/
theorem hd19_shield (P : BlockParams) (hdr : P.draws = ZK60.Exec.Block.R13.shieldDraws) : P.draws 19 = 19 := by
  rw [hdr]
  decide

/-- **At the R13 rung**: R13's `SC_TAB` named identity for a verifier with the rung's draws and schedule. -/
theorem tabR13_formAt_rung (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) (P : BlockParams)
    (hdr : P.draws = ZK60.Exec.Block.R13.rungDraws) (hsl : P.geom.slots = ZK60.Exec.Block.R13.rungSlots)
    (ioIn ioOut : ℕ) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) (pubs : PubTabs)
    (hrest : ∀ hist dr i, pubs 19 hist dr i = restR13 exp act nG 19 hist dr i) (D : CmData K P)
    (hrlA : 0 < rowLog P .a) (hrlH : 0 < rowLog P .h) (hkind : P.kind 19 = SlotKind.standalone)
    (Φ : (k : ℕ) → Hist → (Fin (P.draws k) → K) → K)
    (hΦ : ∀ hist x, Φ 19 hist x
      = (spTabR U DefR13.cfgRungR13 hcard P (hd19_rung P hdr) D exp act nG (hist.beta, hist.gamma, hist.alpha)).Φ x)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) :
    FormAt U P (polyS U P D (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut) pubs) Φ bga rs 19 :=
  tabR_formAt U hU hcard DefR13.cfgRungR13 rawSlot19_rung P (hd19_rung P hdr)
    (by simp only [slotShape, hsl]; decide) ioIn ioOut exp act nG pubs hrest D hrlA hrlH hkind Φ hΦ bga rs

/-- **At every layer of the app's Shieldstral T128 R13 block**: R13's `SC_TAB` named identity for a verifier with
the block's draws and schedule, at the layer's configuration `cfgShieldR13 L`. -/
theorem tabR13_formAt_shield (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K)
    (L : ZK60.RunShape.Shield.ShieldLayer) (hL : L ∈ ZK60.RunShape.Shield.shieldExport) (P : BlockParams)
    (hdr : P.draws = ZK60.Exec.Block.R13.shieldDraws) (hsl : P.geom.slots = ZK60.Exec.Block.R13.shieldSlots)
    (ioIn ioOut : ℕ) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) (pubs : PubTabs)
    (hrest : ∀ hist dr i, pubs 19 hist dr i = restR13 exp act nG 19 hist dr i) (D : CmData K P)
    (hrlA : 0 < rowLog P .a) (hrlH : 0 < rowLog P .h) (hkind : P.kind 19 = SlotKind.standalone)
    (Φ : (k : ℕ) → Hist → (Fin (P.draws k) → K) → K)
    (hΦ : ∀ hist x, Φ 19 hist x = (spTabR U (DefR13.cfgShieldR13 L) hcard P (hd19_shield P hdr) D exp act nG
      (hist.beta, hist.gamma, hist.alpha)).Φ x)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) :
    FormAt U P (polyS U P D (DefR13.progR13 (DefR13.cfgShieldR13 L) ioIn ioOut) pubs) Φ bga rs 19 :=
  tabR_formAt U hU hcard (DefR13.cfgShieldR13 L) (rawSlot19_shield L hL) P (hd19_shield P hdr)
    (by simp only [slotShape, hsl]; decide) ioIn ioOut exp act nG pubs hrest D hrlA hrlH hkind Φ hΦ bga rs

end Form

end ZK60.Exec.Block.Join.R13T
