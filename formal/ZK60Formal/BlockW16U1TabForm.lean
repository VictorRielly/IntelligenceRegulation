/-
D63 W16R2 Shieldstral port, Item (5e) (`BlockW16U1TabForm.lean`):
**`SC_TAB` (slot `19`) of the W16R2 Shieldstral (`export_u1`) slot program, its cube sum, and its
standalone named identity `formAt_tabU1`**, parametric in `(cnA, cnM)`.

Because `rawSlot (cfgU1 cnA cnM) 19 = rawSlot c0 19` by `rfl`, all 26 layers of `export_u1` share
the exact same slot `19` structure:
* `58` tables: `eq(τ)`, `16` triples `(A plane 56 + k, H plane 27 + k, pub k)` (`k < 16`), and
  `9` gates (`pub (16 + g)`, `g < 9`: `supp(Tab)`, ACT support, and the `7` narrow range sub-planes
  `[0, 1, 2, 3, 4, 5, 6]`);
* `tabIr` on the `16` triples with `μ` draws `14 .. 29`, `μ_pad` draw `30`, `ζ` draw `31`, and
  `20` pad planes in `tabPadIxU1` order (`spTabU1.dg = 22`).

Reuses `drT`, `tabSem_range`, `wsum_range`, and `padPls_flat` from `BlockTabSlot.lean`, and
`progW16_slot` from `BlockW16U1Base.lean` (so reserved mask rows are carried symbolically via
`numTabs_rawTabs19U1` and never read on the cube).

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.BlockW16U1TabBase
import ZK60Formal.BlockTabSlot

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16U1.Tab

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl hPl hTab_eval tabK_ph_cpt tabK_pa_cpt eqT_eval pubT_eval
  cstS_map toK_zpowW)
open ZK60.Exec.Block.Join.W16.Tab (drT tabSem_range wsum_range padPls_flat)
open ZK60.Exec.Block.Join.W16U1
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build (tabIr tabIr_eval tabSem padSem)
open ZK60.Exec.Slot.Compose (tabIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open ZK60.Layout

/-! ## 1. Slot `19` (`SC_TAB`) at `export_u1`: raw slot and numbering -/

/-- `SC_TAB`'s multiplicity table `k < 16` (`A` plane `56 + k`) with mask row `m`. -/
def aT19U1 (m k : ℕ) : TabS :=
  .priv ⟨.a, [(offU1 (56 + k), false)], 14, DefW16.rhoC 0 14, m, 0⟩

/-- `SC_TAB`'s helper table `k < 16` (`H` plane `27 + k`) with mask row `m`. -/
def hT19U1 (m k : ℕ) : TabS :=
  .priv ⟨.h, [((hOffU1 (27 + k)).1, false), ((hOffU1 (27 + k)).2, true)], 14, DefW16.rhoC 0 14, m, 0⟩

/-- `SC_TAB`'s 58 raw tables at `export_u1` before numbering: `eq(τ)`, `16` triples
`(aPlane (56 + k), hTab (27 + k), pub 0)`, and `9` gates (`pub 0`). -/
def rawTabs19U1 : List TabS :=
  .eq (drT 0 14) 0
    :: (((List.range' 0 16).flatMap fun k => [aT19U1 0 k, hT19U1 0 k, .pub 0]) ++ List.replicate 9 (.pub 0))

/-- `SC_TAB`'s 58 tables at `export_u1` after numbering from claim sites `(ak, hk)`. -/
def numTabs19U1 (aB hB ak hk : ℕ) : List TabS :=
  .eq (drT 0 14) 0
    :: (((List.range' 0 16).flatMap fun k =>
          [aT19U1 (aB + 2 * (ak + k)) k, hT19U1 (hB + 2 * (hk + k)) k, .pub k])
        ++ (List.range' 16 9).map TabS.pub)

/-- `SC_TAB`'s numbered table at position `idx < 58`: `eq(τ)`, then per table `k < 16` its
multiplicity, helper, and public value column `k`, then the `9` gates (public tables `16 .. 24`). -/
def tab19U1At (aB hB ak hk idx : ℕ) : TabS :=
  if idx = 0 then .eq (drT 0 14) 0
  else if idx < 49 then
    (if (idx - 1) % 3 = 0 then aT19U1 (aB + 2 * (ak + (idx - 1) / 3)) ((idx - 1) / 3)
      else if (idx - 1) % 3 = 1 then hT19U1 (hB + 2 * (hk + (idx - 1) / 3)) ((idx - 1) / 3)
      else .pub ((idx - 1) / 3))
  else .pub (idx - 33)

/-- The `16` table-relation triples `(multiplicity, helper, value column)`. -/
def ts19U1 : List (ℕ × ℕ × ℕ) :=
  (List.range' 0 16).map fun k => (1 + 3 * k, 2 + 3 * k, 3 + 3 * k)

/-- The pad groups (`tab_w16`) at `export_u1`: bytes and exp under `supp(Tab)` (table `49`), ACT
under its support (`50`), and each of the `7` narrow range sub-planes `[0..6]` under its support
(`51 .. 57`). -/
def grp19U1 : List (ℕ × List ℕ) :=
  [(49, [1, 4]), (49, [2, 5]), (50, [7]), (50, [8]),
    (51, [10]), (51, [11]), (52, [13]), (52, [14]), (53, [16]), (53, [17]),
    (54, [19]), (54, [20]), (55, [22]), (55, [23]), (56, [25]), (56, [26]),
    (57, [28]), (57, [29])]

/-- `SC_TAB`'s IR at `export_u1`: `16` triples, `17` `μ` draws (`14 .. 30`, with `μ_pad` at `30`),
`ζ` draw `31`, and `20` pad planes across `grp19U1`. -/
def ir19U1 : ZK60.Exec.Slot.Ir Sym :=
  tabIr DefW16.cstS 0 .alpha ts19U1 (drT 14 17) (fun j => Sym.pow (Sym.dr 19 31) j) grp19U1

/-- Raw slot `19` is independent of `(cnA, cnM)` by `rfl`. -/
theorem rawSlot19_cfgU1 (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 19 = DefW16.rawSlot c0 19 :=
  DefW16.rawSlot_shieldU1_ne14 cnA cnM 19 (by decide)

/-- Raw slot `19` at `c0`, by evaluation. -/
theorem rawSlot19_c0 : DefW16.rawSlot c0 19 = ⟨rawTabs19U1, ir19U1, [], [.dr 19 31]⟩ := rfl

/-- **Raw slot `19` at `cfgU1 cnA cnM`** for every `(cnA, cnM)`. -/
theorem rawSlot19_u1 (cnA cnM : ℕ) :
    DefW16.rawSlot (cfgU1 cnA cnM) 19 = ⟨rawTabs19U1, ir19U1, [], [.dr 19 31]⟩ :=
  (rawSlot19_cfgU1 cnA cnM).trans rawSlot19_c0

theorem numTabs_rawTrips (aB hB ioIn ioOut ak0 hk0 : ℕ) : ∀ (n k : ℕ) (tail : List TabS),
    DefW16.numTabs aB hB ioIn ioOut (ak0 + k) (hk0 + k) k
      (((List.range' k n).flatMap fun j => [aT19U1 0 j, hT19U1 0 j, .pub 0]) ++ tail)
    = ((List.range' k n).flatMap fun j =>
        [aT19U1 (aB + 2 * (ak0 + j)) j, hT19U1 (hB + 2 * (hk0 + j)) j, .pub j])
      ++ DefW16.numTabs aB hB ioIn ioOut (ak0 + (k + n)) (hk0 + (k + n)) (k + n) tail
  | 0, _, _ => rfl
  | n + 1, k, tail => by
    rw [List.range'_succ, List.flatMap_cons, List.append_assoc]
    show aT19U1 (aB + 2 * (ak0 + k)) k :: hT19U1 (hB + 2 * (hk0 + k)) k :: TabS.pub k
      :: DefW16.numTabs aB hB ioIn ioOut (ak0 + k + 1) (hk0 + k + 1) (k + 1)
           (((List.range' (k + 1) n).flatMap fun j => [aT19U1 0 j, hT19U1 0 j, .pub 0]) ++ tail)
      = aT19U1 (aB + 2 * (ak0 + k)) k :: hT19U1 (hB + 2 * (hk0 + k)) k :: TabS.pub k
      :: (((List.range' (k + 1) n).flatMap fun j =>
            [aT19U1 (aB + 2 * (ak0 + j)) j, hT19U1 (hB + 2 * (hk0 + j)) j, .pub j])
          ++ DefW16.numTabs aB hB ioIn ioOut (ak0 + (k + (n + 1))) (hk0 + (k + (n + 1))) (k + (n + 1)) tail)
    rw [show ak0 + k + 1 = ak0 + (k + 1) by omega,
      show hk0 + k + 1 = hk0 + (k + 1) by omega,
      numTabs_rawTrips aB hB ioIn ioOut ak0 hk0 n (k + 1) tail,
      show k + 1 + n = k + (n + 1) by omega]

theorem numTabs_pubRep (aB hB ioIn ioOut : ℕ) : ∀ (m ak hk pk : ℕ),
    DefW16.numTabs aB hB ioIn ioOut ak hk pk (List.replicate m (.pub 0))
      = (List.range' pk m).map TabS.pub
  | 0, _, _, _ => rfl
  | m + 1, ak, hk, pk => by
    rw [List.replicate_succ, List.range'_succ, List.map_cons]
    show TabS.pub pk :: DefW16.numTabs aB hB ioIn ioOut ak hk (pk + 1) (List.replicate m (.pub 0))
      = TabS.pub pk :: (List.range' (pk + 1) m).map TabS.pub
    rw [numTabs_pubRep aB hB ioIn ioOut m ak hk (pk + 1)]

/-- Numbering `rawTabs19U1` from claim sites `(ak, hk)` yields `numTabs19U1 aB hB ak hk`. -/
theorem numTabs_rawTabs19U1 (aB hB ioIn ioOut ak hk : ℕ) :
    DefW16.numTabs aB hB ioIn ioOut ak hk 0 rawTabs19U1 = numTabs19U1 aB hB ak hk := by
  show TabS.eq (drT 0 14) 0
    :: DefW16.numTabs aB hB ioIn ioOut (ak + 0) (hk + 0) 0
         (((List.range' 0 16).flatMap fun k => [aT19U1 0 k, hT19U1 0 k, .pub 0]) ++ List.replicate 9 (.pub 0))
    = numTabs19U1 aB hB ak hk
  rw [numTabs_rawTrips aB hB ioIn ioOut ak hk 16 0 (List.replicate 9 (.pub 0)),
    numTabs_pubRep aB hB ioIn ioOut 9 (ak + (0 + 16)) (hk + (0 + 16)) (0 + 16)]
  rfl

/-- **Slot `19` of `progW16 (cfgU1 cnA cnM) ioIn ioOut`**, numbered from some claim sites `(ak, hk)`. -/
theorem slot19_u1 (cnA cnM ioIn ioOut : ℕ) : ∃ ak hk,
    (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut).getD 19 SlotS.empty
      = ⟨numTabs19U1 (DefW16.aDataRows (cfgU1 cnA cnM)) (DefW16.hDataRows (cfgU1 cnA cnM)) ak hk,
          ir19U1, [], [.dr 19 31]⟩ := by
  obtain ⟨ak, hk, hslot⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 19 (by norm_num)
  refine ⟨ak, hk, ?_⟩
  rw [hslot, rawSlot19_u1]
  simp only [DefW16.numSlot, numTabs_rawTabs19U1]

/-! ## 2. The pad groups in `wTabU1`'s order -/

/-- **The pad groups in `tab_w16`'s order at `export_u1` are `wTabU1`'s**: plane `j < 20` reads
gate `(tabPadIxU1 j).1` (table `49 + g`) and the helper (`2 + 3k`) or multiplicity (`1 + 3k`) of
table `k = (tabPadIxU1 j).2.2`. -/
theorem grp19U1_flat : grp19U1.flatMap (fun g => g.2.map fun p => (g.1, p))
    = (List.range' 0 20).map (fun j => (49 + (tabPadIxU1 j).1,
        if (tabPadIxU1 j).2.1 then 2 + 3 * (tabPadIxU1 j).2.2 else 1 + 3 * (tabPadIxU1 j).2.2)) := by
  decide +kernel

/-- **`SC_TAB`'s pad planes at `export_u1` in `wTabU1`'s order.** -/
theorem padPls_grp19U1 {R : Type} [CommRing R] (v : List R) : padPls v grp19U1
    = (List.range' 0 20).map (fun j => (1 - v.getD (49 + (tabPadIxU1 j).1) 0)
        * v.getD (if (tabPadIxU1 j).2.1 then 2 + 3 * (tabPadIxU1 j).2.2 else 1 + 3 * (tabPadIxU1 j).2.2) 0) := by
  rw [padPls_flat, grp19U1_flat, List.map_map]
  rfl

theorem tabPadIxU1_lt : ∀ j < 20, (tabPadIxU1 j).1 < 9 ∧ (tabPadIxU1 j).2.2 < 16 := by
  decide +kernel

/-! ## 3. The value list at a cube point with the zero extension -/

theorem numTabs19U1_vals {α β : Type} [Zero α] (aB hB ak hk : ℕ) (f : TabS → β) (g : β → α) (i : ℕ)
    (hi : i < 58) :
    (((numTabs19U1 aB hB ak hk).map f).map g).getD i 0 = g (f (tab19U1At aB hB ak hk i)) := by
  interval_cases i <;> rfl

theorem tab19U1At_mult (aB hB ak hk k : ℕ) (hk16 : k < 16) :
    tab19U1At aB hB ak hk (1 + 3 * k) = aT19U1 (aB + 2 * (ak + k)) k := by
  unfold tab19U1At
  rw [ite_eq_right (show ¬ (1 + 3 * k = 0) by omega), ite_eq_left (show 1 + 3 * k < 49 by omega),
    ite_eq_left (show (1 + 3 * k - 1) % 3 = 0 by omega)]
  have hdiv : (1 + 3 * k - 1) / 3 = k := by omega
  rw [hdiv]

theorem tab19U1At_help (aB hB ak hk k : ℕ) (hk16 : k < 16) :
    tab19U1At aB hB ak hk (2 + 3 * k) = hT19U1 (hB + 2 * (hk + k)) k := by
  unfold tab19U1At
  rw [ite_eq_right (show ¬ (2 + 3 * k = 0) by omega), ite_eq_left (show 2 + 3 * k < 49 by omega),
    ite_eq_right (show ¬ ((2 + 3 * k - 1) % 3 = 0) by omega),
    ite_eq_left (show (2 + 3 * k - 1) % 3 = 1 by omega)]
  have hdiv : (2 + 3 * k - 1) / 3 = k := by omega
  rw [hdiv]

theorem tab19U1At_col (aB hB ak hk k : ℕ) (hk16 : k < 16) :
    tab19U1At aB hB ak hk (3 + 3 * k) = .pub k := by
  unfold tab19U1At
  rw [ite_eq_right (show ¬ (3 + 3 * k = 0) by omega), ite_eq_left (show 3 + 3 * k < 49 by omega),
    ite_eq_right (show ¬ ((3 + 3 * k - 1) % 3 = 0) by omega),
    ite_eq_right (show ¬ ((3 + 3 * k - 1) % 3 = 1) by omega)]
  congr 1
  omega

theorem tab19U1At_gate (aB hB ak hk g : ℕ) (hg : g < 9) :
    tab19U1At aB hB ak hk (49 + g) = .pub (16 + g) := by
  unfold tab19U1At
  rw [ite_eq_right (show ¬ (49 + g = 0) by omega), ite_eq_right (show ¬ (49 + g < 49) by omega)]
  congr 1
  omega

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K)
variable (P : BlockParams) (D : CmData K P) (aB hB ak hk : ℕ) (pub : ℕ → List Fp2)
  (hist : Hist) (dr : List Fp2) (e : ℕ) (b : Fin 14 → Bool)

/-- The value list of `SC_TAB` at `export_u1` at a cube point with the zero extension. -/
noncomputable abbrev valsTU1 : List K :=
  ((numTabs19U1 aB hB ak hk).map (TabS.eval (Sym.eval hist 19 dr) pub)).map
    (tabK U P D 14 e (cpt 14 e b))

theorem tabU1_vals_eq :
    (valsTU1 U P D aB hB ak hk pub hist dr e b).getD 0 0
      = eqPoly (fun a : Fin 14 => (dr.getD a Fp2.zero).toK U) (fun a => bit (b a)) := by
  unfold valsTU1
  rw [numTabs19U1_vals aB hB ak hk _ _ 0 (by norm_num)]
  show tabK U P D 14 e (cpt 14 e b) (.eq ((drT 0 14).map (Sym.eval hist 19 dr)) 0) = _
  have hlen : ((drT 0 14).map (Sym.eval hist 19 dr)).length = 14 := by simp [drT]
  rw [tabK_eqFull_cpt U P D 14 e b _ hlen]
  congr 1
  funext a
  simp [drT, Sym.eval, drawAt]

theorem tabU1_vals_mult (hrl : 0 < rowLog P .a) (k : ℕ) (hk16 : k < 16) :
    (valsTU1 U P D aB hB ak hk pub hist dr e b).getD (1 + 3 * k) 0 = multTabU1 U P D k b := by
  unfold valsTU1
  rw [numTabs19U1_vals aB hB ak hk _ _ (1 + 3 * k) (by omega), tab19U1At_mult aB hB ak hk k hk16]
  unfold aT19U1
  rw [aTab_eval, tabK_pa_cpt U P D hrl 14 e b 14 (by norm_num) rfl, castB_rfl]
  rfl

theorem tabU1_vals_help (hrl : 0 < rowLog P .h) (k : ℕ) (hk16 : k < 16) :
    (valsTU1 U P D aB hB ak hk pub hist dr e b).getD (2 + 3 * k) 0 = helpTabU1 U P D k b := by
  unfold valsTU1
  rw [numTabs19U1_vals aB hB ak hk _ _ (2 + 3 * k) (by omega), tab19U1At_help aB hB ak hk k hk16]
  unfold hT19U1
  rw [hTab_eval, tabK_ph_cpt U P D hrl 14 e b 14 (by norm_num) rfl, castB_rfl]
  rfl

theorem tabU1_vals_col (k : ℕ) (hk16 : k < 16) :
    (valsTU1 U P D aB hB ak hk pub hist dr e b).getD (3 + 3 * k) 0
      = ((pub k).getD (msbIndex 14 b) Fp2.zero).toK U := by
  unfold valsTU1
  rw [numTabs19U1_vals aB hB ak hk _ _ (3 + 3 * k) (by omega), tab19U1At_col aB hB ak hk k hk16,
    pubT_eval, tabK_pub_cpt]

theorem tabU1_vals_gate (g : ℕ) (hg : g < 9) :
    (valsTU1 U P D aB hB ak hk pub hist dr e b).getD (49 + g) 0
      = ((pub (16 + g)).getD (msbIndex 14 b) Fp2.zero).toK U := by
  unfold valsTU1
  rw [numTabs19U1_vals aB hB ak hk _ _ (49 + g) (by omega), tab19U1At_gate aB hB ak hk g hg,
    pubT_eval, tabK_pub_cpt]

end Vals

/-! ## 4. `SC_TAB`'s cube sum at `export_u1` -/

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **`SC_TAB`'s cube sum at `export_u1`** (`n = 14`):
`Σ_b eq(τ, b)·(Σ_{k : Fin 16} μ_k·cTabU1_k(b) + μ_pad·Σ_{j : Fin 20} ζ^j·wTabU1_j(b))`,
with `τ` draws `0 .. 13`, `μ_k` draw `14 + k`, `μ_pad` draw `30`, `ζ` draw `31`; off the zero
extension the `eq` table is `0`. -/
theorem tabU1_cube (P : BlockParams) (D : CmData K P) (hrlA : 0 < rowLog P .a) (hrlH : 0 < rowLog P .h)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ)
    (aB hB ak hk : ℕ) (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2)
    (hcol : ∀ k, k < 16 → ∀ b : Fin 14 → Bool,
      ((pub k).getD (msbIndex 14 b) Fp2.zero).toK U
        = ZK60.Sound.fold (hist.beta.toK U) (hist.gamma.toK U) (tupK (tabTupU1 Pb nG k (msbIndex 14 b))))
    (hgate : ∀ g, g < 9 → ∀ b : Fin 14 → Bool,
      ((pub (16 + g)).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gateTabU1 nG g b))
    (n e : ℕ) (hn : n = 14) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval ((ir19U1.map (Sym.eval hist 19 dr)).map (Fp2.toK U))
      (((numTabs19U1 aB hB ak hk).map (TabS.eval (Sym.eval hist 19 dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = ∑ b : Fin 14 → Bool, eqPoly (fun a : Fin 14 => (dr.getD a Fp2.zero).toK U) (fun a => bit (b a))
      * (∑ k : Fin 16, (dr.getD (14 + (k : ℕ)) Fp2.zero).toK U
            * cTabU1 U P D Pb nG (hist.beta, hist.gamma, hist.alpha) k b
        + (dr.getD 30 Fp2.zero).toK U
          * ∑ j : Fin 20, ((dr.getD 31 Fp2.zero).toK U) ^ (j : ℕ) * wTabU1 U P D nG j b) := by
  subst hn
  have hir : ∀ v : List K, irEval ((ir19U1.map (Sym.eval hist 19 dr)).map (Fp2.toK U)) v
      = v.getD 0 0 * (tabSem v (hist.alpha.toK U) (((drT 14 17).map (Sym.eval hist 19 dr)).map (Fp2.toK U)) 0 ts19U1
        + padSem (ZK60.Exec.Slot.Build.cstW.map (Fp2.toK U)) v
          ((((drT 14 17).map (Sym.eval hist 19 dr)).map (Fp2.toK U)).getD ts19U1.length
            (ZK60.Exec.Slot.Build.cstW.map (Fp2.toK U)).zero)
          (Fp2.toK U ∘ (Sym.eval hist 19 dr ∘ fun j => Sym.pow (Sym.dr 19 31) j)) 0 grp19U1) := by
    intro v
    unfold ir19U1
    rw [tabIr_map, tabIr_map, cstS_map, tabIr_eval _ (cstW_map_std U)]
    rfl
  have hmu : ∀ i, i < 17 → ∀ d : K, (((drT 14 17).map (Sym.eval hist 19 dr)).map (Fp2.toK U)).getD i d
      = (dr.getD (14 + i) Fp2.zero).toK U := by
    intro i hi d
    rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_map, drT, List.getElem?_map,
      List.getElem?_range hi]
    simp [Sym.eval, drawAt]
  have hzp : ∀ j, (Sym.eval hist 19 dr (Sym.pow (Sym.dr 19 31) j)).toK U = ((dr.getD 31 Fp2.zero).toK U) ^ j := by
    intro j
    rw [show Sym.eval hist 19 dr (Sym.pow (Sym.dr 19 31) j) = zpowW (dr.getD 31 Fp2.zero) j by simp [Sym.eval, drawAt],
      toK_zpowW U hU]
  rw [cubeSum_split]
  refine Finset.sum_congr rfl (fun b _ => ?_)
  rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
  · show f (cpt 14 e b) = _
    rw [hf, hir]
    have h0 := tabU1_vals_eq U P D aB hB ak hk pub hist dr e b
    unfold valsTU1 at h0
    rw [h0]
    congr 1
    have hts : ts19U1.length = 16 := by decide
    rw [hts, hmu 16 (by norm_num), padSem_eq_wsum _ (cstW_map_std U), padPls_grp19U1, wsum_range]
    unfold ts19U1
    rw [tabSem_range]
    simp only [Nat.zero_add, Function.comp_apply]
    congr 1
    · refine Finset.sum_congr rfl (fun i _ => ?_)
      have hi := i.isLt
      have hm := tabU1_vals_mult U P D aB hB ak hk pub hist dr e b hrlA i hi
      have hh := tabU1_vals_help U P D aB hB ak hk pub hist dr e b hrlH i hi
      have hc := tabU1_vals_col U P D aB hB ak hk pub hist dr e b i hi
      unfold valsTU1 at hm hh hc
      rw [hmu i (by omega), hm, hh, hc, hcol i hi b]
      rfl
    · congr 1
      refine Finset.sum_congr rfl (fun j _ => ?_)
      obtain ⟨hg, hk16⟩ := tabPadIxU1_lt j j.isLt
      have hgt := tabU1_vals_gate U P D aB hB ak hk pub hist dr e b _ hg
      have hm := tabU1_vals_mult U P D aB hB ak hk pub hist dr e b hrlA _ hk16
      have hh := tabU1_vals_help U P D aB hB ak hk pub hist dr e b hrlH _ hk16
      unfold valsTU1 at hgt hm hh
      rw [hzp, hgt, hgate _ hg b]
      unfold wTabU1
      by_cases hb : (tabPadIxU1 (j : ℕ)).2.1 = true
      · rw [ite_eq_left hb, ite_eq_left hb, hh]
      · rw [ite_eq_right hb, ite_eq_right hb, hm]
  · show f (bpt 14 e b y) = 0
    rw [hf, hir, numTabs19U1_vals aB hB ak hk _ _ 0 (by norm_num)]
    show tabK U P D 14 e (bpt 14 e b y) (.eq ((drT 0 14).map (Sym.eval hist 19 dr)) 0) * _ = 0
    rw [tabK_eq_off U P D 14 e b y hy, zero_mul]

end Cube

/-! ## 5. `SC_TAB`'s standalone named identity `formAt_tabU1` and degree bound `hTdeg_u1` -/

section Form

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K]

/-- **`SC_TAB`'s standalone named identity at `export_u1`** (slot `19`, parametric in `(cnA, cnM)`):
a polynomial family whose value at slot `19` is `spTabU1`'s at the history's `(β, γ, α)` meets
`FormAt` there, for a verifier with `W16R2.shieldDraws` / `W16R2.shieldSlots` whose slot `19` is
standalone and whose slot-`19` public tables carry the `16` folded value columns and `9` gates. -/
theorem formAt_tabU1 (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) (P : BlockParams)
    (hdr : P.draws = W16R2.shieldDraws) (hsl : P.geom.slots = W16R2.shieldSlots)
    (cnA cnM ioIn ioOut : ℕ) (pubs : PubTabs)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ)
    (D : CmData K P) (hrlA : 0 < rowLog P .a) (hrlH : 0 < rowLog P .h)
    (hk19 : P.kind 19 = SlotKind.standalone)
    (hcol : ∀ hist dr k, k < 16 → ∀ b : Fin 14 → Bool,
      ((pubs 19 hist dr k).getD (msbIndex 14 b) Fp2.zero).toK U
        = ZK60.Sound.fold (hist.beta.toK U) (hist.gamma.toK U) (tupK (tabTupU1 Pb nG k (msbIndex 14 b))))
    (hgate : ∀ hist dr g, g < 9 → ∀ b : Fin 14 → Bool,
      ((pubs 19 hist dr (16 + g)).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gateTabU1 nG g b))
    (Φ : (k : ℕ) → Hist → (Fin (P.draws k) → K) → K)
    (hΦ : ∀ hist x, Φ 19 hist x = (spTabU1 U hcard P hdr D Pb nG (hist.beta, hist.gamma, hist.alpha)).Φ x)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) :
    FormAt U P (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs) Φ bga rs 19 := by
  intro r df hr _
  refine Or.inl ⟨hk19, ?_⟩
  rw [hΦ]
  have hs19 : slotShape P 19 = (14, 1, 3) := by
    simp only [slotShape, hsl]
    decide
  obtain ⟨ak, hk, hslot⟩ := slot19_u1 cnA cnM ioIn ioOut
  unfold spSum
  rw [tabU1_cube U hU P D hrlA hrlH Pb nG (DefW16.aDataRows (cfgU1 cnA cnM)) (DefW16.hDataRows (cfgU1 cnA cnM)) ak hk
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 19)) r.draws
    (pubs 19 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 19)) r.draws)
    (hcol _ _) (hgate _ _) (slotShape P 19).1 (slotShape P 19).2.1 (by rw [hs19]) _
    (fun x => by rw [polyS_seenOf U P D _ _ bga rs 19 r hr x, hslot])]
  rfl

/-- `formAt_tabU1` specialized to the concrete `export_u1` public tables `pubsU1 Pb Lay B nG`. -/
theorem formAt_tabU1_pubs (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) (P : BlockParams)
    (hdr : P.draws = W16R2.shieldDraws) (hsl : P.geom.slots = W16R2.shieldSlots)
    (cnA cnM ioIn ioOut : ℕ)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay) (nG : ℕ)
    (D : CmData K P) (hrlA : 0 < rowLog P .a) (hrlH : 0 < rowLog P .h)
    (hk19 : P.kind 19 = SlotKind.standalone)
    (Φ : (k : ℕ) → Hist → (Fin (P.draws k) → K) → K)
    (hΦ : ∀ hist x, Φ 19 hist x = (spTabU1 U hcard P hdr D Pb nG (hist.beta, hist.gamma, hist.alpha)).Φ x)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) :
    FormAt U P (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) (pubsU1 Pb Lay B nG)) Φ bga rs 19 :=
  formAt_tabU1 U hU hcard P hdr hsl cnA cnM ioIn ioOut (pubsU1 Pb Lay B nG) Pb nG D hrlA hrlH hk19
    (fun hist dr k hk b => by
      rw [pubsU1_rest Pb Lay B nG 19 (Or.inr (Or.inl rfl))]
      exact rest19U1_getD U hU Pb nG hist dr k hk b)
    (fun hist dr g hg b => by
      rw [pubsU1_rest Pb Lay B nG 19 (Or.inr (Or.inl rfl)),
        rest19U1_gate_getD U Pb nG hist dr (16 + g) (by omega) (by omega) b,
        show 16 + g - 16 = g by omega])
    Φ hΦ bga rs

/-- **`hTdeg` at `export_u1`**: `SC_TAB`'s certified polynomial has degree `22 ≤ 80`. -/
theorem hTdeg_u1 (U : K) (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws) {L : ℕ}
    (Dof : Cuts3 L → RootsO → CmData K P) {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ) :
    ∀ cu rt bga, (spTabU1 U (card_K_gt K) P hdr (Dof cu rt) Pb nG bga).dg ≤ 80 := by
  intro cu rt bga
  rw [spTabU1_dg]
  norm_num

end Form

end ZK60.Exec.Block.Join.W16U1.Tab
