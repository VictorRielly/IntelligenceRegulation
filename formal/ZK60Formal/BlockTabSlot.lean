/-
D63 lane L47 (2026-11-10), part 3: **`SC_TAB` (slot `19`) of the W16R2 rung's program, and its cube sum**
(deliverable 1).

* `drT`, `aT19`, `hT19`, `tab19At`, `tabs19`, `ts19`, `grp19`, `ir19`, **`slot19_eq`**: the program's slot `19` at the
  rung, by evaluation (`eq(τ)`; per table `k < 17` the multiplicity `A` plane `58 + k`, the helper `H` plane `28 + k`
  and the public value column `k`; then the ten gates; L13's `tabIr` on the triples, the draws `14 … 31`, `ζ` draw `32`
  and the pad groups);
* `aOff_tab`, `hOff_tab`: the planes' offsets (`A` `1196032 + 16384·k`, `H` `1179648 + 32768·k`), evaluated;
* `tabSem_range`, `wsum_range`, `padPls_flat`, `grp19_flat`: the IR's two batched sums read position by position; the
  pad groups in `tab_w16`'s order ARE `wTabW`'s (`tabPadIx`), by evaluation;
* `tab_vals_eq`, `tab_vals_mult`, `tab_vals_help`, `tab_vals_col`, `tab_vals_gate`: the value list at a cube point with
  the zero extension, entry by entry;
* **`tab_cube`**: the slot's cube sum is `Σ_b eq(τ, b)·(Σ_k μ_k·cTabW_k(b) + μ_pad·Σ_j ζ^j·wTabW_j(b))`, with `τ` draws
  `0 … 13`, `μ_k` draw `14 + k`, `μ_pad` draw `31`, `ζ` draw `32`, on the public tables `pubsW16 B (restW16 Pb nG)`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockTabBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Tab

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build (tabIr tabIr_eval tabSem padSem)
open ZK60.Exec.Slot.Compose (tabIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open ZK60.Layout

/-! ## The slot -/

/-- The draws `off … off + n − 1` of slot `19`, as expressions. -/
def drT (off n : ℕ) : List Sym := (List.range n).map fun i => Sym.dr 19 (off + i)

/-- `SC_TAB`'s multiplicity table `k` (`A` plane `58 + k`, reserved pair `280 + 2k`). -/
def aT19 (k : ℕ) : TabS := .priv ⟨.a, [(1196032 + 16384 * k, false)], 14, DefW16.rhoC 0 14, 280 + 2 * k, 0⟩

/-- `SC_TAB`'s helper table `k` (`H` plane `28 + k`, reserved pair `164 + 2k`). -/
def hT19 (k : ℕ) : TabS :=
  .priv ⟨.h, [(1179648 + 32768 * k, false), (1196032 + 32768 * k, true)], 14, DefW16.rhoC 0 14, 164 + 2 * k, 0⟩

/-- `SC_TAB`'s table at position `idx`: `eq(τ)`, then per table `k` its multiplicity, helper and value column, then the
ten gates (public tables `17 … 26`). -/
def tab19At (idx : ℕ) : TabS :=
  if idx = 0 then .eq (drT 0 14) 0
  else if idx < 52 then
    (if (idx - 1) % 3 = 0 then aT19 ((idx - 1) / 3)
      else if (idx - 1) % 3 = 1 then hT19 ((idx - 1) / 3) else .pub ((idx - 1) / 3))
  else .pub (idx - 35)

/-- `SC_TAB`'s 62 tables at the rung (`tab19At` position by position, `tabs19_vals`). -/
def tabs19 : List TabS :=
  [.eq (drT 0 14) 0, aT19 0, hT19 0, .pub 0, aT19 1, hT19 1, .pub 1, aT19 2, hT19 2, .pub 2, aT19 3, hT19 3,
    .pub 3, aT19 4, hT19 4, .pub 4, aT19 5, hT19 5, .pub 5, aT19 6, hT19 6, .pub 6, aT19 7, hT19 7, .pub 7, aT19 8,
    hT19 8, .pub 8, aT19 9, hT19 9, .pub 9, aT19 10, hT19 10, .pub 10, aT19 11, hT19 11, .pub 11, aT19 12, hT19 12,
    .pub 12, aT19 13, hT19 13, .pub 13, aT19 14, hT19 14, .pub 14, aT19 15, hT19 15, .pub 15, aT19 16, hT19 16,
    .pub 16, .pub 17, .pub 18, .pub 19, .pub 20, .pub 21, .pub 22, .pub 23, .pub 24, .pub 25, .pub 26]

/-- The relations' table triples `(multiplicity, helper, value column)`. -/
def ts19 : List (ℕ × ℕ × ℕ) :=
  [(1, 2, 3), (4, 5, 6), (7, 8, 9), (10, 11, 12), (13, 14, 15), (16, 17, 18), (19, 20, 21), (22, 23, 24),
    (25, 26, 27), (28, 29, 30), (31, 32, 33), (34, 35, 36), (37, 38, 39), (40, 41, 42), (43, 44, 45), (46, 47, 48),
    (49, 50, 51)]

theorem ts19_eq : ts19 = (List.range' 0 17).map fun k => (1 + 3 * k, 2 + 3 * k, 3 + 3 * k) := by
  decide

/-- The pad groups (`tab_w16`): bytes and exp under `supp(Tab)` (table `52`), ACT under its support (`53`), each narrow
range sub-plane `q` under its own support (`54 + q`). -/
def grp19 : List (ℕ × List ℕ) :=
  [(52, [1, 4]), (52, [2, 5]), (53, [7]), (53, [8]), (54, [10]), (54, [11]), (55, [13]), (55, [14]), (56, [16]),
    (56, [17]), (57, [19]), (57, [20]), (58, [22]), (58, [23]), (59, [25]), (59, [26]), (60, [28]), (60, [29]),
    (61, [31]), (61, [32])]

/-- `SC_TAB`'s IR at the rung. -/
def ir19 : ZK60.Exec.Slot.Ir Sym :=
  tabIr DefW16.cstS 0 .alpha ts19 (drT 14 18) (fun j => Sym.pow (Sym.dr 19 32) j) grp19

/-- **The program's slot `19` at the rung**, by evaluation. -/
theorem slot19_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 19 SlotS.empty
    = ⟨tabs19, ir19, [], [.dr 19 32]⟩ := rfl

/-- The multiplicity planes' offsets. -/
theorem aOff_tab : ∀ k < 17, aOff cfgRungW16 (58 + k) = 1196032 + 16384 * k := by
  decide +kernel

/-- The helper planes' offsets. -/
theorem hOff_tab : ∀ k < 17, hOff cfgRungW16 (28 + k) = (1179648 + 32768 * k, 1196032 + 32768 * k) := by
  decide +kernel

/-! ## The batched sums, position by position -/

section Sums

variable {R : Type} [CommRing R]

theorem tabSem_range (v : List R) (alpha : R) (mu : List R) : ∀ (n j : ℕ),
    tabSem v alpha mu j ((List.range' j n).map fun k => (1 + 3 * k, 2 + 3 * k, 3 + 3 * k))
      = ∑ i : Fin n, mu.getD (j + i) 0
          * (v.getD (2 + 3 * (j + i)) 0 * (alpha - v.getD (3 + 3 * (j + i)) 0) - v.getD (1 + 3 * (j + i)) 0)
  | 0, _ => by simp [tabSem]
  | n + 1, j => by
    rw [List.range'_succ, List.map_cons]
    show mu.getD j 0 * (v.getD (2 + 3 * j) 0 * (alpha - v.getD (3 + 3 * j) 0) - v.getD (1 + 3 * j) 0)
        + tabSem v alpha mu (j + 1) ((List.range' (j + 1) n).map fun k => (1 + 3 * k, 2 + 3 * k, 3 + 3 * k)) = _
    rw [tabSem_range v alpha mu n (j + 1), Fin.sum_univ_succ]
    simp only [Fin.val_zero, add_zero, Fin.val_succ]
    congr 1
    refine Finset.sum_congr rfl (fun i _ => ?_)
    rw [show j + 1 + (i : ℕ) = j + ((i : ℕ) + 1) by omega]

theorem wsum_range (zp : ℕ → R) (F : ℕ → R) : ∀ (n j : ℕ),
    wsum zp j ((List.range' j n).map F) = ∑ i : Fin n, zp (j + i) * F (j + i)
  | 0, _ => by simp [wsum]
  | n + 1, j => by
    rw [List.range'_succ, List.map_cons, wsum, wsum_range zp F n (j + 1), Fin.sum_univ_succ]
    simp only [Fin.val_zero, add_zero, Fin.val_succ]
    congr 1
    refine Finset.sum_congr rfl (fun i _ => ?_)
    rw [show j + 1 + (i : ℕ) = j + ((i : ℕ) + 1) by omega]

theorem padPls_flat (v : List R) : ∀ gs : List (ℕ × List ℕ),
    padPls v gs = (gs.flatMap fun g => g.2.map fun p => (g.1, p)).map (fun q => (1 - v.getD q.1 0) * v.getD q.2 0)
  | [] => rfl
  | (s, ps) :: gs => by
    rw [padPls, padPls_flat v gs, List.flatMap_cons, List.map_append, List.map_map]
    rfl

end Sums

/-- **The pad groups in `tab_w16`'s order are `wTabW`'s**: plane `j` reads gate `(tabPadIx j).1` (table `52 + g`) and the
helper (`2 + 3k`) or the multiplicity (`1 + 3k`) of table `k = (tabPadIx j).2.2`. -/
theorem grp19_flat : grp19.flatMap (fun g => g.2.map fun p => (g.1, p))
    = (List.range' 0 22).map (fun j => (52 + (tabPadIx j).1,
        if (tabPadIx j).2.1 then 2 + 3 * (tabPadIx j).2.2 else 1 + 3 * (tabPadIx j).2.2)) := by
  decide +kernel

/-- **`SC_TAB`'s pad planes in `wTabW`'s order.** -/
theorem padPls_grp19 {R : Type} [CommRing R] (v : List R) : padPls v grp19
    = (List.range' 0 22).map (fun j => (1 - v.getD (52 + (tabPadIx j).1) 0)
        * v.getD (if (tabPadIx j).2.1 then 2 + 3 * (tabPadIx j).2.2 else 1 + 3 * (tabPadIx j).2.2) 0) := by
  rw [padPls_flat, grp19_flat, List.map_map]
  rfl

theorem tabPadIx_lt : ∀ j < 22, (tabPadIx j).1 < 10 ∧ (tabPadIx j).2.2 < 17 := by
  decide +kernel

/-! ## The value list -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

omit [Algebra GF K] in
theorem tabs19_vals {β : Type} (f : TabS → β) (g : β → K) (i : ℕ) (hi : i < 62) :
    ((tabs19.map f).map g).getD i 0 = g (f (tab19At i)) := by
  interval_cases i <;> rfl

theorem tab19At_mult (k : ℕ) (hk : k < 17) : tab19At (1 + 3 * k) = aT19 k := by
  unfold tab19At
  rw [ite_eq_right (show ¬ (1 + 3 * k = 0) by omega), ite_eq_left (show 1 + 3 * k < 52 by omega),
    ite_eq_left (show (1 + 3 * k - 1) % 3 = 0 by omega)]
  congr 1
  omega

theorem tab19At_help (k : ℕ) (hk : k < 17) : tab19At (2 + 3 * k) = hT19 k := by
  unfold tab19At
  rw [ite_eq_right (show ¬ (2 + 3 * k = 0) by omega), ite_eq_left (show 2 + 3 * k < 52 by omega),
    ite_eq_right (show ¬ ((2 + 3 * k - 1) % 3 = 0) by omega), ite_eq_left (show (2 + 3 * k - 1) % 3 = 1 by omega)]
  congr 1
  omega

theorem tab19At_col (k : ℕ) (hk : k < 17) : tab19At (3 + 3 * k) = .pub k := by
  unfold tab19At
  rw [ite_eq_right (show ¬ (3 + 3 * k = 0) by omega), ite_eq_left (show 3 + 3 * k < 52 by omega),
    ite_eq_right (show ¬ ((3 + 3 * k - 1) % 3 = 0) by omega), ite_eq_right (show ¬ ((3 + 3 * k - 1) % 3 = 1) by omega)]
  congr 1
  omega

theorem tab19At_gate (g : ℕ) (hg : g < 10) : tab19At (52 + g) = .pub (17 + g) := by
  unfold tab19At
  rw [ite_eq_right (show ¬ (52 + g = 0) by omega), ite_eq_right (show ¬ (52 + g < 52) by omega)]
  congr 1
  omega

variable (P : BlockParams) (D : CmData K P) {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtW CwW CgW CjW CdW CfW) (B : W16Pub S Pb Lay) (nG : ℕ) (hist : Hist) (dr : List Fp2) (e : ℕ)
  (b : Fin 14 → Bool)

/-- The value list at a cube point with the zero extension. -/
noncomputable abbrev valsT : List K :=
  (tabs19.map (TabS.eval (Sym.eval hist 19 dr) (pubsW16 Pb Lay B (restW16 Pb nG) 19 hist dr))).map
    (tabK U P D 14 e (cpt 14 e b))

theorem tab_vals_eq :
    (valsT U P D Pb Lay B nG hist dr e b).getD 0 0
      = eqPoly (fun a : Fin 14 => (dr.getD a Fp2.zero).toK U) (fun a => bit (b a)) := by
  unfold valsT
  rw [tabs19_vals _ _ 0 (by norm_num)]
  show tabK U P D 14 e (cpt 14 e b) (.eq ((drT 0 14).map (Sym.eval hist 19 dr)) 0) = _
  have hlen : ((drT 0 14).map (Sym.eval hist 19 dr)).length = 14 := by simp [drT]
  rw [tabK_eqFull_cpt U P D 14 e b _ hlen]
  congr 1
  funext a
  simp [drT, Sym.eval, drawAt]

theorem tab_vals_mult (hrl : 0 < rowLog P .a) (k : ℕ) (hk : k < 17) :
    (valsT U P D Pb Lay B nG hist dr e b).getD (1 + 3 * k) 0 = multTabW U P D k b := by
  unfold valsT
  rw [tabs19_vals _ _ (1 + 3 * k) (by omega), tab19At_mult k hk]
  unfold aT19
  rw [aTab_eval, tabK_pa_cpt U P D hrl 14 e b 14 (by norm_num) rfl, castB_rfl]
  unfold multTabW
  rw [aOff_tab k hk]

theorem tab_vals_help (hrl : 0 < rowLog P .h) (k : ℕ) (hk : k < 17) :
    (valsT U P D Pb Lay B nG hist dr e b).getD (2 + 3 * k) 0 = helpTabW U P D k b := by
  unfold valsT
  rw [tabs19_vals _ _ (2 + 3 * k) (by omega), tab19At_help k hk]
  unfold hT19
  rw [hTab_eval, tabK_ph_cpt U P D hrl 14 e b 14 (by norm_num) rfl, castB_rfl]
  unfold helpTabW
  rw [hOff_tab k hk]

include hU in
theorem tab_vals_col (k : ℕ) (hk : k < 17) :
    (valsT U P D Pb Lay B nG hist dr e b).getD (3 + 3 * k) 0
      = ZK60.Sound.fold (hist.beta.toK U) (hist.gamma.toK U) (tupK (tabTupW Pb nG k (msbIndex 14 b))) := by
  unfold valsT
  rw [tabs19_vals _ _ (3 + 3 * k) (by omega), tab19At_col k hk, pubT_eval, tabK_pub_cpt,
    pubsW16_rest Pb nG Lay B 19 (Or.inr (Or.inl rfl)), rest19_getD U hU Pb nG hist dr k hk b]

theorem tab_vals_gate (g : ℕ) (hg : g < 10) :
    (valsT U P D Pb Lay B nG hist dr e b).getD (52 + g) 0 = algebraMap GF K (gateTabW nG g b) := by
  unfold valsT
  rw [tabs19_vals _ _ (52 + g) (by omega), tab19At_gate g hg, pubT_eval, tabK_pub_cpt,
    pubsW16_rest Pb nG Lay B 19 (Or.inr (Or.inl rfl)),
    rest19_gate_getD U Pb nG hist dr (17 + g) (by omega) (by omega) b, show 17 + g - 17 = g by omega]

end Vals

/-! ## The cube sum -/

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **`SC_TAB`'s cube sum** (`n = 14`): `Σ_b eq(τ, b)·(Σ_k μ_k·cTabW_k(b) + μ_pad·Σ_j ζ^j·wTabW_j(b))`, with `τ` its draws
`0 … 13`, `μ_k` draw `14 + k`, `μ_pad` draw `31`, `ζ` draw `32`; off the zero extension the `eq` table is `0`. -/
theorem tab_cube (P : BlockParams) (D : CmData K P) (hrlA : 0 < rowLog P .a) (hrlH : 0 < rowLog P .h)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
    (B : W16Pub S Pb Lay) (nG : ℕ) (hist : Hist) (dr : List Fp2) (n e : ℕ) (hn : n = 14)
    (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval ((ir19.map (Sym.eval hist 19 dr)).map (Fp2.toK U))
      ((tabs19.map (TabS.eval (Sym.eval hist 19 dr) (pubsW16 Pb Lay B (restW16 Pb nG) 19 hist dr))).map
        (tabK U P D n e x))) :
    cubeSum f = ∑ b : Fin 14 → Bool, eqPoly (fun a : Fin 14 => (dr.getD a Fp2.zero).toK U) (fun a => bit (b a))
      * (∑ k : Fin 17, (dr.getD (14 + (k : ℕ)) Fp2.zero).toK U
            * cTabW U P D Pb nG (hist.beta, hist.gamma, hist.alpha) k b
        + (dr.getD 31 Fp2.zero).toK U
          * ∑ j : Fin 22, ((dr.getD 32 Fp2.zero).toK U) ^ (j : ℕ) * wTabW U P D nG j b) := by
  subst hn
  -- the IR read in the field
  have hir : ∀ v : List K, irEval ((ir19.map (Sym.eval hist 19 dr)).map (Fp2.toK U)) v
      = v.getD 0 0 * (tabSem v (hist.alpha.toK U) (((drT 14 18).map (Sym.eval hist 19 dr)).map (Fp2.toK U)) 0 ts19
        + padSem (ZK60.Exec.Slot.Build.cstW.map (Fp2.toK U)) v
          ((((drT 14 18).map (Sym.eval hist 19 dr)).map (Fp2.toK U)).getD ts19.length
            (ZK60.Exec.Slot.Build.cstW.map (Fp2.toK U)).zero)
          (Fp2.toK U ∘ (Sym.eval hist 19 dr ∘ fun j => Sym.pow (Sym.dr 19 32) j)) 0 grp19) := by
    intro v
    unfold ir19
    rw [tabIr_map, tabIr_map, cstS_map, tabIr_eval _ (cstW_map_std U)]
    rfl
  -- the weights
  have hmu : ∀ i, i < 18 → ∀ d : K, (((drT 14 18).map (Sym.eval hist 19 dr)).map (Fp2.toK U)).getD i d
      = (dr.getD (14 + i) Fp2.zero).toK U := by
    intro i hi d
    rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_map, drT, List.getElem?_map,
      List.getElem?_range hi]
    simp [Sym.eval, drawAt]
  have hzp : ∀ j, (Sym.eval hist 19 dr (Sym.pow (Sym.dr 19 32) j)).toK U = ((dr.getD 32 Fp2.zero).toK U) ^ j := by
    intro j
    rw [show Sym.eval hist 19 dr (Sym.pow (Sym.dr 19 32) j) = zpowW (dr.getD 32 Fp2.zero) j by simp [Sym.eval, drawAt],
      toK_zpowW U hU]
  set mu := ((drT 14 18).map (Sym.eval hist 19 dr)).map (Fp2.toK U) with hmuDef
  rw [cubeSum_split]
  refine Finset.sum_congr rfl (fun b _ => ?_)
  rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
  · show f (cpt 14 e b) = _
    rw [hf, hir]
    have h0 := tab_vals_eq U P D Pb Lay B nG hist dr e b
    unfold valsT at h0
    rw [h0]
    congr 1
    -- the relations
    have hts : ts19.length = 17 := by simp [ts19]
    rw [hts, hmu 17 (by norm_num), padSem_eq_wsum _ (cstW_map_std U), padPls_grp19, wsum_range]
    rw [ts19_eq, tabSem_range]
    simp only [Nat.zero_add, Function.comp_apply]
    congr 1
    · refine Finset.sum_congr rfl (fun i _ => ?_)
      have hi := i.isLt
      have hm := tab_vals_mult U P D Pb Lay B nG hist dr e b hrlA i hi
      have hh := tab_vals_help U P D Pb Lay B nG hist dr e b hrlH i hi
      have hc := tab_vals_col U hU P D Pb Lay B nG hist dr e b i hi
      unfold valsT at hm hh hc
      rw [hmu i (by omega), hm, hh, hc]
      rfl
    · congr 1
      refine Finset.sum_congr rfl (fun j _ => ?_)
      obtain ⟨hg, hk⟩ := tabPadIx_lt j j.isLt
      have hgt := tab_vals_gate U P D Pb Lay B nG hist dr e b _ hg
      have hm := tab_vals_mult U P D Pb Lay B nG hist dr e b hrlA _ hk
      have hh := tab_vals_help U P D Pb Lay B nG hist dr e b hrlH _ hk
      unfold valsT at hgt hm hh
      rw [hzp, hgt]
      unfold wTabW
      by_cases hb : (tabPadIx (j : ℕ)).2.1 = true
      · rw [ite_eq_left hb, ite_eq_left hb, hh]
      · rw [ite_eq_right hb, ite_eq_right hb, hm]
  · show f (bpt 14 e b y) = 0
    rw [hf, hir, tabs19_vals _ _ 0 (by norm_num)]
    show tabK U P D 14 e (bpt 14 e b y) (.eq ((drT 0 14).map (Sym.eval hist 19 dr)) 0) * _ = 0
    rw [tabK_eq_off U P D 14 e b y hy, zero_mul]

end Cube

end ZK60.Exec.Block.Join.W16.Tab
