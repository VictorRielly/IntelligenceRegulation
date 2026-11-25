/-
D63 W16R2 Shieldstral port (`BlockW16U1LookRel.lean`):
**LogUp's helper relations and `hhr` premise (`hhr_core_u1`, `hhr_u1`, `hhr_shieldU1`) at the
installed W16R2 Shieldstral export `export_u1` (`W16R2_SHIELD_T128_H24`), PROVED.**

Mirrors `BlockLookRelHost.lean` + `BlockLookRelPer.lean` + `BlockLookRelW16.lean` +
`BlockLookRelFinal.lean` at the A29-uniform `export_u1` configuration `c0 = cfgShieldU1 0 0`
(parametric in per-layer `(cnA, cnM)` via `logupSumW16_cfgU1`):

* `lkOK_u1`: every lookup of `lookupsN c0 d.dom` across all six lookup domains has word-sized
  constants, coefficients, and tags (`LkOK`);
* `plAU1`, `dzcU1_planes`, `dzcU1_help`, `qzcU1_planes`, `qzcU1_help`, `kvzcU1_planes`,
  `kvzcU1_help`, `szcU1_planes`, `szcU1_help`, `fzcU1_planes`, `fzcU1_help`, `lzcU1_planes`,
  `lzcU1_help`: each host's value list exposes the domain's committed `A` planes and `H` helpers;
* `getD_rep8`, `lenRelS_u1`, **`relL_pairU1`**, **`relD_pairU1`**, **`relD_singleU1`**,
  **`relQ_pairU1`**, **`relK_pairU1`**, **`relS_pairU1`**, **`relS_singleU1`**, **`relF_pairU1`**,
  **`relF_singleU1`**, **`relExpU1`**, **`relActU1`**: vanishing of every host's LogUp / exp / ACT
  batch entry and of `SC_LZC`'s limb relation yields `HelperRel`'s pair or single relation;
* `lsWU1`, `sgWU1`, `lsTU1`, `lsWU1_eq`, `sgWU1_eq`, `logupSumU1_parts`, `sgWU1_canon`,
  `logupSumU1_empty`, `PSpU1`, **`logupSumU1_planes`**, **`hhr_sum_u1`**: over the `44` `H` planes
  (`0`: L, `1..10`: D, `11..13`: Q, `14..16`: Kv, `17..20`: S [3 pairs + 1 single], `21`: Exp,
  `22..25`: F [3 pairs + 1 single], `26`: Act, `27..42`: 16 negated `SC_TAB` helpers, `43`: `H_U`
  with zero sum from `SC_ZS`), `logupSumW16 c0` gives `Σ singles + Σ pairs − Σ table = 0`;
* **`hhr_core_u1`**, **`hhr_u1`**, **`hhr_shieldU1`**: LogUp's `hhr` premise for `AlkU1`, `TU1`,
  `mlkU1`, matching `block_knowledge_join_w16r2_shieldU1` in `BlockW16U1Base.lean`, given the
  verifier fact `hls : P.logupSumClaim = DefW16.logupSumW16 (cfgU1 cnA cnM)`.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.BlockW16U1Hosts
import ZK60Formal.BlockW16U1Help
import ZK60Formal.BlockW16U1LookBase
import ZK60Formal.BlockLookRelW16
import ZK60Formal.BlockR13LookRelBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16U1.Look

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl hPl cstK cstK_base)
open ZK60.Exec.Block.Join.W16.Look (LkOK lksAt host_pair host_single PairR SingleR getD_rep4
  logupSem_two EmptyParts claimSem_empty sum_planeZ2 sum_flatMap2 toK_negOne fromI64_canon)
open ZK60.Exec.Block.Join.R13H (splitS splitF)
open ZK60.Exec.Block.Join.W16U1
open ZK60.Exec.Block.Join.W16U1.Tab
open ZK60.Exec.Block.Join.W16U1.Help
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.W16R2 (segLn)
open ZK60.Exec.Slot.Build (szcExp szcDelta fzcAct)
open ZK60.Exec.Slot.Compose (cstW_map_std)
open ZK60.Circuit (GF tagExp tagAct)
open ZK60.RunShape.Shield (ShieldLayer shieldShape)
open ZK60.Layout

/-! ## 1. The code's lookups are words, and the six hosts' value lists at `export_u1` -/

/-- Every lookup of `lookupsN c0 d.dom` at `export_u1` has word-sized constants, coefficients, and tags. -/
theorem lkOK_u1 : ∀ d : LkDomU1, ∀ l ∈ lookupsN c0 d.dom, LkOK l := by
  intro d
  cases d <;> decide

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

/-- The planes a domain's lookups read at `export_u1`, read off `A` at `offU1`. -/
noncomputable def plAU1 (log : ℕ) (b : Fin log → Bool) : ℕ → K := fun q => aPl U P D (offU1 q) log b

theorem dzcU1_planes (b : Fin 19 → Bool) : ∀ l ∈ lookupsN c0 .D, ∀ t ∈ l.terms,
    (Dzc.valsXD_u1 U P D Pb Lay B b).getD (Dzc.shD t.1) 0 = plAU1 U P D 19 b t.1 :=
  Dzc.valsXD_u1_plane U P D Pb Lay B b

theorem dzcU1_help (b : Fin 19 → Bool) (j : ℕ) (hj : j < 10) :
    (Dzc.valsXD_u1 U P D Pb Lay B b).getD (26 + 0 + j) 0
      = hPl U P D (hOffU1 (1 + j)).1 (hOffU1 (1 + j)).2 19 b :=
  Dzc.valsXD_u1_help U P D Pb Lay B b j hj

theorem qzcU1_planes (b : Fin 19 → Bool) : ∀ l ∈ lookupsN c0 .Q, ∀ t ∈ l.terms,
    (Qkv.valsXQ_u1 U P D Pb Lay B b).getD (W16.Qkv.shQ t.1) 0 = plAU1 U P D 19 b t.1 := by
  have hnum : ∀ l ∈ lookupsN c0 .Q, ∀ t ∈ l.terms, 27 ≤ t.1 ∧ t.1 ≤ 32 := by decide +kernel
  intro l hl t ht
  obtain ⟨h1, h2⟩ := hnum l hl t ht
  generalize t.1 = q at h1 h2 ⊢
  interval_cases q <;> rfl

theorem qzcU1_help (b : Fin 19 → Bool) (j : ℕ) (hj : j < 3) :
    (Qkv.valsXQ_u1 U P D Pb Lay B b).getD (12 + 0 + j) 0
      = hPl U P D (hOffU1 (11 + j)).1 (hOffU1 (11 + j)).2 19 b := by
  interval_cases j <;> rfl

theorem kvzcU1_planes (b : Fin 17 → Bool) : ∀ l ∈ lookupsN c0 .Kv, ∀ t ∈ l.terms,
    (Qkv.valsXK_u1 U P D Pb Lay B b).getD (W16.Qkv.shK t.1) 0 = plAU1 U P D 17 b t.1 := by
  have hnum : ∀ l ∈ lookupsN c0 .Kv, ∀ t ∈ l.terms, 33 ≤ t.1 ∧ t.1 ≤ 38 := by decide +kernel
  intro l hl t ht
  obtain ⟨h1, h2⟩ := hnum l hl t ht
  generalize t.1 = q at h1 h2 ⊢
  interval_cases q <;> rfl

theorem kvzcU1_help (b : Fin 17 → Bool) (j : ℕ) (hj : j < 3) :
    (Qkv.valsXK_u1 U P D Pb Lay B b).getD (12 + 0 + j) 0
      = hPl U P D (hOffU1 (14 + j)).1 (hOffU1 (14 + j)).2 17 b := by
  interval_cases j <;> rfl

theorem szcU1_planes (b : Fin 19 → Bool) : ∀ l ∈ lookupsN c0 .S, ∀ t ∈ l.terms,
    (Szc.valsXS_u1 U P D Pb Lay B b).getD (W16.Szc.shapedS t.1) 0 = plAU1 U P D 19 b t.1 := by
  have hnum : ∀ l ∈ lookupsN c0 .S, ∀ t ∈ l.terms, 39 ≤ t.1 ∧ t.1 ≤ 46 := by decide +kernel
  intro l hl t ht
  obtain ⟨h1, h2⟩ := hnum l hl t ht
  generalize t.1 = q at h1 h2 ⊢
  interval_cases q <;> rfl

theorem szcU1_help (b : Fin 19 → Bool) (j : ℕ) (hj : j < 5) :
    (Szc.valsXS_u1 U P D Pb Lay B b).getD (14 + 0 + j) 0
      = hPl U P D (hOffU1 (17 + j)).1 (hOffU1 (17 + j)).2 19 b := by
  interval_cases j <;> rfl

theorem fzcU1_planes (b : Fin 21 → Bool) : ∀ l ∈ lookupsN c0 .F, ∀ t ∈ l.terms,
    (Fzc.valsXF_u1 U P D Pb Lay B b).getD (Fzc.shF_u1 t.1) 0 = plAU1 U P D 21 b t.1 := by
  have hnum : ∀ l ∈ lookupsN c0 .F, ∀ t ∈ l.terms, 47 ≤ t.1 ∧ t.1 ≤ 55 := by decide +kernel
  intro l hl t ht
  obtain ⟨h1, h2⟩ := hnum l hl t ht
  generalize t.1 = q at h1 h2 ⊢
  interval_cases q <;> rfl

theorem fzcU1_help (b : Fin 21 → Bool) (j : ℕ) (hj : j < 5) :
    (Fzc.valsXF_u1 U P D Pb Lay B b).getD (12 + 0 + j) 0
      = hPl U P D (hOffU1 (22 + j)).1 (hOffU1 (22 + j)).2 21 b := by
  interval_cases j <;> rfl

theorem lzcU1_planes (b : Fin 14 → Bool) : ∀ l ∈ lookupsN c0 .L, ∀ t ∈ l.terms,
    (valsLU1 U P D b).getD (W16.Lk.shapedL t.1) 0 = plAU1 U P D 14 b t.1 := by
  have hnum : ∀ l ∈ lookupsN c0 .L, ∀ t ∈ l.terms, t.1 = 6 ∨ t.1 = 7 := by decide
  intro l hl t ht
  rcases hnum l hl t ht with h | h <;> (rw [h]; rfl)

theorem lzcU1_help (b : Fin 14 → Bool) :
    (valsLU1 U P D b).getD (3 + 0 + 0) 0 = hPl U P D (hOffU1 (0 + 0)).1 (hOffU1 (0 + 0)).2 14 b := rfl

end Vals

/-! ## 2. Every host's LogUp, exp, and ACT relations at `export_u1` -/

private theorem lenL_rel : (lookupsN c0 .L).length = 2 := by decide
private theorem lenD_rel : (lookupsN c0 .D).length = 19 := by decide
private theorem lenQ_rel : (lookupsN c0 .Q).length = 6 := by decide
private theorem lenK_rel : (lookupsN c0 .Kv).length = 6 := by decide
private theorem lenS_rel : (lookupsN c0 .S).length = 7 := by decide
private theorem lenF_rel : (lookupsN c0 .F).length = 7 := by decide

theorem getD_rep8 {R : Type} [CommRing R] (L : List R) (e : R) (hL : L.length = 4) :
    (List.replicate 4 0 ++ L ++ [e]).getD 8 0 = e := by
  rw [List.getD_eq_getElem?_getD,
    List.getElem?_append_right (by simp only [List.length_append, List.length_replicate, hL]; omega)]
  simp [hL]

theorem lenRelS_u1 {K : Type} [Field K] [Algebra GF K] (U : K) (bga : Fp2 × Fp2 × Fp2) (v : List K) :
    (lkRels (cstK U) v 14 0 (Szc.lksK_u1 U bga)).length = 4 := by
  rw [lkRels_length]
  simp only [Szc.lksK_u1, List.length_map, Szc.lksS17_u1_length]

section Per

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7) (P : BlockParams)
  (D : CmData K P)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
variable (bga : Fp2 × Fp2 × Fp2) (hα : bga.2.2.Canon)

include hα

/-- **`SC_LZC`'s relation at `export_u1`**: the limb pair (`H` plane `0`). -/
theorem relL_pairU1 (b : Fin 14 → Bool) (h0 : cLzcU1 U P D bga b = 0) :
    PairR U bga (hPl U P D (hOffU1 (0 + 0)).1 (hOffU1 (0 + 0)).2 14 b)
      (lkAtU1 U P D .L (2 * 0) b) (lkAtU1 U P D .L (2 * 0 + 1) b) := by
  unfold cLzcU1 at h0
  have hlen : (W16.Lk.lksLK U bga).length = 2 := by
    unfold W16.Lk.lksLK
    simp only [List.length_map]
    decide
  rw [logupSem_two _ _ _ _ _ hlen] at h0
  simp only [(cstW_map_std U).one, one_mul] at h0
  have hlks : W16.Lk.lksLK U bga = lksAt U 3 W16.Lk.shapedL (lookupsN c0 .L) bga := rfl
  rw [hlks] at h0
  exact host_pair U bga hα 3 W16.Lk.shapedL (lookupsN c0 .L) _ (plAU1 U P D 14 b) 3 _ 0 (by rw [lenL_rel]; omega)
    (lkOK_u1 .L) (lzcU1_planes U P D b) (lzcU1_help U P D b) h0

/-- **`SC_DZC`'s relation `6 + j` at `export_u1`**: pair `j < 9` of `Dom::D` (`H` plane `1 + j`). -/
theorem relD_pairU1 (b : Fin 19 → Bool) (j : ℕ) (hj : j < 9) (h0 : Dzc.xcDzcU1 U P D Pb Lay B bga (6 + j) b = 0) :
    PairR U bga (hPl U P D (hOffU1 (1 + j)).1 (hOffU1 (1 + j)).2 19 b)
      (lkAtU1 U P D .D (2 * j) b) (lkAtU1 U P D .D (2 * j + 1) b) := by
  unfold Dzc.xcDzcU1 at h0
  rw [show 6 + j - 6 = j by omega] at h0
  exact host_pair U bga hα 14 Dzc.shD (lookupsN c0 .D) _ (plAU1 U P D 19 b) 26 _ j (by rw [lenD_rel]; omega)
    (lkOK_u1 .D) (dzcU1_planes U P D Pb Lay B b) (dzcU1_help U P D Pb Lay B b j (by omega)) h0

/-- **`SC_DZC`'s relation `15` at `export_u1`**: `Dom::D`'s odd last lookup (`18`, `H` plane `10`). -/
theorem relD_singleU1 (b : Fin 19 → Bool) (h0 : Dzc.xcDzcU1 U P D Pb Lay B bga 15 b = 0) :
    SingleR U bga (hPl U P D (hOffU1 (1 + 9)).1 (hOffU1 (1 + 9)).2 19 b) (lkAtU1 U P D .D (2 * 9) b) := by
  unfold Dzc.xcDzcU1 at h0
  exact host_single U bga hα 14 Dzc.shD (lookupsN c0 .D) _ (plAU1 U P D 19 b) 26 _ 9 lenD_rel
    (lkOK_u1 .D) (dzcU1_planes U P D Pb Lay B b) (dzcU1_help U P D Pb Lay B b 9 (by omega)) h0

/-- **`SC_QZC`'s relation `1 + j` at `export_u1`**: pair `j < 3` of `Dom::Q` (`H` plane `11 + j`). -/
theorem relQ_pairU1 (b : Fin 19 → Bool) (j : ℕ) (hj : j < 3) (h0 : Qkv.xcQzcU1 U P D Pb Lay B bga (1 + j) b = 0) :
    PairR U bga (hPl U P D (hOffU1 (11 + j)).1 (hOffU1 (11 + j)).2 19 b)
      (lkAtU1 U P D .Q (2 * j) b) (lkAtU1 U P D .Q (2 * j + 1) b) := by
  unfold Qkv.xcQzcU1 at h0
  rw [Nat.add_comm 1 j, List.getD_cons_succ] at h0
  exact host_pair U bga hα 15 W16.Qkv.shQ (lookupsN c0 .Q) _ (plAU1 U P D 19 b) 12 _ j (by rw [lenQ_rel]; omega)
    (lkOK_u1 .Q) (qzcU1_planes U P D Pb Lay B b) (qzcU1_help U P D Pb Lay B b j hj) h0

/-- **`SC_KVZC`'s relation `1 + j` at `export_u1`**: pair `j < 3` of `Dom::Kv` (`H` plane `14 + j`). -/
theorem relK_pairU1 (b : Fin 17 → Bool) (j : ℕ) (hj : j < 3) (h0 : Qkv.xcKvzcU1 U P D Pb Lay B bga (1 + j) b = 0) :
    PairR U bga (hPl U P D (hOffU1 (14 + j)).1 (hOffU1 (14 + j)).2 17 b)
      (lkAtU1 U P D .Kv (2 * j) b) (lkAtU1 U P D .Kv (2 * j + 1) b) := by
  unfold Qkv.xcKvzcU1 at h0
  rw [Nat.add_comm 1 j, List.getD_cons_succ] at h0
  exact host_pair U bga hα 16 W16.Qkv.shK (lookupsN c0 .Kv) _ (plAU1 U P D 17 b) 12 _ j (by rw [lenK_rel]; omega)
    (lkOK_u1 .Kv) (kvzcU1_planes U P D Pb Lay B b) (kvzcU1_help U P D Pb Lay B b j hj) h0

/-- **`SC_SZC`'s relation `4 + j` at `export_u1`**: pair `j < 3` of `Dom::S` (`H` plane `17 + j`). -/
theorem relS_pairU1 (b : Fin 19 → Bool) (j : ℕ) (hj : j < 3) (h0 : Szc.xcSzcU1 U P D Pb Lay B bga (4 + j) b = 0) :
    PairR U bga (hPl U P D (hOffU1 (17 + j)).1 (hOffU1 (17 + j)).2 19 b)
      (lkAtU1 U P D .S (2 * j) b) (lkAtU1 U P D .S (2 * j + 1) b) := by
  unfold Szc.xcSzcU1 at h0
  rw [getD_rep4 _ _ j (by rw [lenRelS_u1 U bga]; omega)] at h0
  exact host_pair U bga hα 17 W16.Szc.shapedS (lookupsN c0 .S) _ (plAU1 U P D 19 b) 14 _ j (by rw [lenS_rel]; omega)
    (lkOK_u1 .S) (szcU1_planes U P D Pb Lay B b) (szcU1_help U P D Pb Lay B b j (by omega)) h0

/-- **`SC_SZC`'s relation `7` at `export_u1`**: `Dom::S`'s odd last lookup (`6`, `H` plane `20`). -/
theorem relS_singleU1 (b : Fin 19 → Bool) (h0 : Szc.xcSzcU1 U P D Pb Lay B bga (4 + 3) b = 0) :
    SingleR U bga (hPl U P D (hOffU1 (17 + 3)).1 (hOffU1 (17 + 3)).2 19 b) (lkAtU1 U P D .S (2 * 3) b) := by
  unfold Szc.xcSzcU1 at h0
  rw [getD_rep4 _ _ 3 (by rw [lenRelS_u1 U bga]; omega)] at h0
  exact host_single U bga hα 17 W16.Szc.shapedS (lookupsN c0 .S) _ (plAU1 U P D 19 b) 14 _ 3 lenS_rel
    (lkOK_u1 .S) (szcU1_planes U P D Pb Lay B b) (szcU1_help U P D Pb Lay B b 3 (by omega)) h0

/-- **`SC_FZC`'s relation `2 + j` at `export_u1`**: pair `j < 3` of `Dom::F` (`H` plane `22 + j`). -/
theorem relF_pairU1 (b : Fin 21 → Bool) (j : ℕ) (hj : j < 3) (h0 : Fzc.xcFzcU1 U P D Pb Lay B bga (2 + j) b = 0) :
    PairR U bga (hPl U P D (hOffU1 (22 + j)).1 (hOffU1 (22 + j)).2 21 b)
      (lkAtU1 U P D .F (2 * j) b) (lkAtU1 U P D .F (2 * j + 1) b) := by
  unfold Fzc.xcFzcU1 at h0
  rw [ite_eq_right (show ¬ (2 + j = 1) by omega), show 2 + j - 2 = j by omega] at h0
  exact host_pair U bga hα 18 Fzc.shF_u1 (lookupsN c0 .F) _ (plAU1 U P D 21 b) 12 _ j (by rw [lenF_rel]; omega)
    (lkOK_u1 .F) (fzcU1_planes U P D Pb Lay B b) (fzcU1_help U P D Pb Lay B b j (by omega)) h0

/-- **`SC_FZC`'s relation `5` at `export_u1`**: `Dom::F`'s odd last lookup (`6`, `H` plane `25`). -/
theorem relF_singleU1 (b : Fin 21 → Bool) (h0 : Fzc.xcFzcU1 U P D Pb Lay B bga (2 + 3) b = 0) :
    SingleR U bga (hPl U P D (hOffU1 (22 + 3)).1 (hOffU1 (22 + 3)).2 21 b) (lkAtU1 U P D .F (2 * 3) b) := by
  unfold Fzc.xcFzcU1 at h0
  rw [ite_eq_right (show ¬ (2 + 3 = 1) by omega), show 2 + 3 - 2 = 3 by omega] at h0
  exact host_single U bga hα 18 Fzc.shF_u1 (lookupsN c0 .F) _ (plAU1 U P D 21 b) 12 _ 3 lenF_rel
    (lkOK_u1 .F) (fzcU1_planes U P D Pb Lay B b) (fzcU1_help U P D Pb Lay B b 3 (by omega)) h0

/-- **`SC_SZC`'s relation `8` at `export_u1`**: the exp tuple (`H` plane `21`). -/
theorem relExpU1 (hβ : bga.1.Canon) (b : Fin 19 → Bool) (h0 : Szc.xcSzcU1 U P D Pb Lay B bga 8 b = 0) :
    SingleR U bga (hPl U P D (hOffU1 21).1 (hOffU1 21).2 19 b) (expTupU1 U P D Pb Lay B b) := by
  unfold Szc.xcSzcU1 at h0
  rw [getD_rep8 _ _ (lenRelS_u1 U bga _)] at h0
  have hamd : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 17 [] W16.Szc.amdS).toK U
      = bga.2.2.toK U - bga.2.1.toK U * 129 := by
    show (Fp2.sub bga.2.2 (bga.2.1.mulBase (Fp.new (UInt64.ofNat 129)))).toK U = _
    rw [Fp2.toK_sub U _ _ hα (Fp2.canon_mulBase _ _), Fp2.toK_mulBase, Fp.new_toGF_ofNat 129 (by norm_num),
      map_natCast]
    norm_num
  have hnb : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 17 [] W16.Szc.nbS).toK U = -bga.1.toK U := by
    show (Fp2.neg bga.1).toK U = _
    rw [Fp2.toK_neg U _ hβ]
  have hb1 : (cstK U).base (-127) = -127 := by
    rw [cstK_base U (-127) (by norm_num) (by norm_num)]
    exact (map_intCast (algebraMap GF K) (-127)).trans (by norm_num)
  have hb2 : (cstK U).base 127 = 127 := by
    rw [cstK_base U 127 (by norm_num) (by norm_num)]
    exact (map_intCast (algebraMap GF K) 127).trans (by norm_num)
  have hhx : (Szc.valsXS_u1 U P D Pb Lay B b).getD 18 0
      = hPl U P D (hOffU1 21).1 (hOffU1 21).2 19 b := rfl
  unfold szcExp szcDelta at h0
  simp only [Szc.RSzU1, Szc.KSzU1] at h0
  rw [hamd, hnb, hb1, hb2, hhx] at h0
  unfold SingleR expTupU1 ZK60.Sound.fold
  have e3 : (Szc.valsXS_u1 U P D Pb Lay B b).getD 3 0 = algebraMap GF K (B.mask (splitS c0 b)) := rfl
  have e4 : (Szc.valsXS_u1 U P D Pb Lay B b).getD 4 0 = aPl U P D (offU1 39) 19 b := rfl
  have e8 : (Szc.valsXS_u1 U P D Pb Lay B b).getD 8 0 = aPl U P D (offU1 43) 19 b := rfl
  have e12 : (Szc.valsXS_u1 U P D Pb Lay B b).getD 12 0 = aPl U P D (offU1 4) 12 (hd12 b) := rfl
  rw [e3, e4, e8, e12] at h0
  have ht : ((tagExp : ℕ) : K) = 129 := by norm_num
  rw [ht]
  linear_combination h0

include hU in
/-- **`SC_FZC`'s relation `1` at `export_u1`**: the ACT tuple (`H` plane `26`). -/
theorem relActU1 (hβ : bga.1.Canon) (b : Fin 21 → Bool) (h0 : Fzc.xcFzcU1 U P D Pb Lay B bga 1 b = 0) :
    SingleR U bga (hPl U P D (hOffU1 26).1 (hOffU1 26).2 21 b) (actTupU1 U P D Pb Lay B b) := by
  unfold Fzc.xcFzcU1 at h0
  rw [ite_eq_left rfl] at h0
  have hamq : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 18 [] W16.Fzc.amqS).toK U
      = bga.2.2.toK U - 2048 - bga.2.1.toK U * 134 := by
    show (Fp2.sub (Fp2.sub bga.2.2 (Fp2.fromBase (Fp.fromI64 2048)))
      (bga.2.1.mulBase (Fp.new (UInt64.ofNat 134)))).toK U = _
    rw [Fp2.toK_sub U _ _ (Fp2.canon_sub _ _ hα (Fp2.canon_fromBase _ (fromI64_canon _))) (Fp2.canon_mulBase _ _),
      Fp2.toK_sub U _ _ hα (Fp2.canon_fromBase _ (fromI64_canon _)), Fp2.toK_fromBase,
      Fp.toGF_fromI64 2048 (by norm_num) (by norm_num), Fp2.toK_mulBase, Fp.new_toGF_ofNat 134 (by norm_num),
      map_natCast, map_intCast]
    norm_num
  have hnb : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 18 [] W16.Fzc.nbS).toK U = -bga.1.toK U := by
    show (Fp2.neg bga.1).toK U = _
    rw [Fp2.toK_neg U _ hβ]
  have hnb2 : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 18 [] W16.Fzc.nb2S).toK U
      = -(bga.1.toK U * bga.1.toK U) := by
    show (Fp2.neg (Fp2.mul bga.1 bga.1)).toK U = _
    rw [Fp2.toK_neg U _ (Fp2.canon_mul _ _), Fp2.toK_mul U hU]
  have hfx : (Fzc.valsXF_u1 U P D Pb Lay B b).getD 16 0
      = hPl U P D (hOffU1 26).1 (hOffU1 26).2 21 b := rfl
  unfold fzcAct at h0
  simp only [W16.Fzc.rrF] at h0
  rw [hamq, hnb, hnb2, hfx] at h0
  have e3 : (Fzc.valsXF_u1 U P D Pb Lay B b).getD 3 0 = aPl U P D (offU1 47) 21 b := rfl
  have e6 : (Fzc.valsXF_u1 U P D Pb Lay B b).getD 6 0 = aPl U P D (offU1 50) 21 b := rfl
  have e17 : (Fzc.valsXF_u1 U P D Pb Lay B b).getD 17 0 = algebraMap GF K (B.grpCol (splitF c0 b)) := rfl
  rw [e3, e6, e17] at h0
  unfold SingleR actTupU1 ZK60.Sound.fold
  have ht : ((tagAct : ℕ) : K) = 134 := by norm_num
  rw [ht]
  linear_combination h0

end Per

/-! ## 3. The sum claim at `export_u1` (`44` `H` planes) -/

/-- The `H` planes' log sizes at `export_u1`. -/
def lsWU1 (hp : ℕ) : ℕ := c0.sh.logs ((hDoms c0).getD hp .Tab)

/-- The sum claim's signs at `export_u1` (`−1` on `SC_TAB`'s 16 helpers `27..42`). -/
def sgWU1 (hp : ℕ) : Fp2 :=
  if decide (fh c0 8 ≤ hp) && decide (hp < fh c0 8 + 3 + nRange c0) then Fp2.one.neg else Fp2.one

/-- The log sizes of the 44 `H` planes at `export_u1`, as a piecewise table:
`0`: L (14), `1..10`: D (19), `11..13`: Q (19), `14..16`: Kv (17), `17..20`: S (19), `21`: Exp (19),
`22..25`: F (21), `26`: Act (21), `27..42`: Tab (14), `43`: H_U (14). -/
def lsTU1 (hp : ℕ) : ℕ :=
  if hp < 1 then 14
  else if hp < 14 then 19
  else if hp < 17 then 17
  else if hp < 22 then 19
  else if hp < 27 then 21
  else 14

theorem lsWU1_eq : ∀ hp, hp < 44 → lsWU1 hp = lsTU1 hp := by decide +kernel

theorem sgWU1_eq (hp : ℕ) : sgWU1 hp = if 27 ≤ hp ∧ hp < 43 then Fp2.one.neg else Fp2.one := by
  have h1 : fh c0 8 = 27 := by decide +kernel
  have h2 : nRange c0 = 13 := by decide +kernel
  unfold sgWU1
  rw [h1, h2]
  by_cases h : 27 ≤ hp ∧ hp < 43
  · rw [ite_eq_left h]
    simp [h.1, show hp < 27 + 3 + 13 by omega]
  · rw [ite_eq_right h]
    by_cases h3 : 27 ≤ hp
    · simp [h3, show ¬ (hp < 27 + 3 + 13) by omega]
    · simp [h3]

theorem logupSumU1_parts : (logupSumW16 c0).parts = (List.range 44).flatMap fun hp =>
    [(⟨(hOffU1 hp).1, lsWU1 hp, sgWU1 hp, []⟩ : ZPart),
      ⟨(hOffU1 hp).2, lsWU1 hp, (sgWU1 hp).mul fp2U, []⟩] := by
  have hl : (hDoms c0).length = 44 := (DefW16.helpers_shieldU1 0 0).2
  unfold logupSumW16
  rw [hl]
  rfl

theorem sgWU1_canon (hp : ℕ) : (sgWU1 hp).Canon := by
  rw [sgWU1_eq]
  split_ifs
  · exact And.intro (Fp.neg_canon _ Fp2.canon_one.1) (Fp.neg_canon _ Fp2.canon_one.2)
  · exact Fp2.canon_one

theorem logupSumU1_empty : EmptyParts 14 (logupSumW16 c0) := by
  intro q hq
  rw [logupSumU1_parts] at hq
  obtain ⟨hp, hhp, hq⟩ := List.mem_flatMap.mp hq
  have hlt := List.mem_range.mp hhp
  have hls : 14 ≤ lsWU1 hp := by rw [lsWU1_eq hp hlt]; unfold lsTU1; split_ifs <;> omega
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hq
  rcases hq with rfl | rfl
  · exact ⟨rfl, hls, sgWU1_canon hp⟩
  · exact ⟨rfl, hls, Fp2.canon_mul _ _⟩

section Sum

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

/-- An `H` plane's sum over its cube at `export_u1`. -/
noncomputable def PSpU1 (P : BlockParams) (D : CmData K P) (hp log : ℕ) : K :=
  ∑ c : Fin log → Bool, hPl U P D (hOffU1 hp).1 (hOffU1 hp).2 log c

include hU in
/-- **The code's `logup_sum_claim` at `export_u1` on the `H` matrix is `Σ_{hp < 44} sign_hp·Σ_cube H_hp`.** -/
theorem logupSumU1_planes (P : BlockParams) (D : CmData K P) (hln : rowLog P .h = 14) :
    Link.claimSem U (D.rows .h) (rowLog P .h) (D.Q .h) (D.X .h) (logupSumW16 c0)
      = ((List.range 44).map fun hp => (sgWU1 hp).toK U * PSpU1 U P D hp (lsWU1 hp)).sum := by
  have he : EmptyParts (rowLog P .h) (logupSumW16 c0) := by rw [hln]; exact logupSumU1_empty
  obtain ⟨q0, qs, hz⟩ : ∃ q0 qs, (logupSumW16 c0).parts = q0 :: qs := by
    rw [logupSumU1_parts]
    exact ⟨_, _, rfl⟩
  rw [claimSem_empty U _ _ _ _ _ q0 qs hz he, logupSumU1_parts, sum_flatMap2]
  congr 1
  refine List.map_congr_left (fun hp hhp => ?_)
  have hlt := List.mem_range.mp hhp
  have hls : 14 ≤ lsWU1 hp := by rw [lsWU1_eq hp hlt]; unfold lsTU1; split_ifs <;> omega
  unfold PSpU1
  rw [show (∑ c : Fin (lsWU1 hp) → Bool, hPl U P D (hOffU1 hp).1 (hOffU1 hp).2 (lsWU1 hp) c)
      = ∑ c : Fin (lsWU1 hp) → Bool, planeZ U (rowLog P .h) (D.rows .h) (D.Q .h) (D.X .h)
          ⟨.h, [((hOffU1 hp).1, Fp2.one), ((hOffU1 hp).2, fp2U)], lsWU1 hp, [], 0, 0⟩ c from rfl,
    sum_planeZ2 U (rowLog P .h) (D.rows .h) (D.Q .h) hln (D.X .h) .h _ _ (lsWU1 hp) hls [] 0 0,
    Fp2.toK_mul U hU]
  simp only [add_mul, Finset.sum_add_distrib, mul_assoc, ← Finset.mul_sum]
  ring

include hU in
/-- **The sum of `HelperRel` at `export_u1`, from the code's sum claim and `H_U`'s zero sum (`hp = 43`).** -/
theorem hhr_sum_u1 (P : BlockParams) (D : CmData K P) (hln : rowLog P .h = 14)
    (hcl : Link.claimSem U (D.rows .h) (rowLog P .h) (D.Q .h) (D.X .h) (logupSumW16 c0) = 0)
    (hzs : ∑ b : Fin 14 → Bool, hPl U P D (hOffU1 43).1 (hOffU1 43).2 14 b = 0) :
    ∑ i : SgIxU1, hPl U P D (hOffU1 i.1.hp).1 (hOffU1 i.1.hp).2 i.1.log i.2
      + ∑ k : PrIxU1, hPl U P D (hOffU1 (k.1.fh + k.2.1)).1 (hOffU1 (k.1.fh + k.2.1)).2 k.1.log k.2.2
      - ∑ j : TbIxU1, helpTabU1 U P D j.1 j.2 = 0 := by
  rw [logupSumU1_planes U hU P D hln] at hcl
  have hcl' : ((List.range 44).map fun hp => (if 27 ≤ hp ∧ hp < 43 then (-1 : K) else 1) * PSpU1 U P D hp (lsTU1 hp)).sum
      = 0 := by
    rw [← hcl]
    congr 1
    refine List.map_congr_left (fun hp hhp => ?_)
    rw [lsWU1_eq hp (List.mem_range.mp hhp), sgWU1_eq]
    split_ifs
    · rw [toK_negOne]
    · rw [Fp2.toK_one]
  have hzs' : PSpU1 U P D 43 14 = 0 := hzs
  simp only [List.sum_range_succ, List.range_zero, List.map_nil, List.sum_nil, zero_add] at hcl'
  norm_num at hcl'
  simp only [lsTU1] at hcl'
  norm_num at hcl'
  have hS : ∑ i : SgIxU1, hPl U P D (hOffU1 i.1.hp).1 (hOffU1 i.1.hp).2 i.1.log i.2
      = PSpU1 U P D 10 19 + (PSpU1 U P D 20 19 + (PSpU1 U P D 25 21 + (PSpU1 U P D 21 19 + PSpU1 U P D 26 21))) := by
    rw [Fintype.sum_sigma, sum_sgKindU1]
    rfl
  have hPr : ∑ k : PrIxU1, hPl U P D (hOffU1 (k.1.fh + k.2.1)).1 (hOffU1 (k.1.fh + k.2.1)).2 k.1.log k.2.2
      = ∑ d : LkDomU1, ∑ j ∈ Finset.range d.np, PSpU1 U P D (d.fh + j) d.log := by
    rw [Fintype.sum_sigma]
    refine Finset.sum_congr rfl (fun d _ => ?_)
    rw [Fintype.sum_prod_type]
    exact Fin.sum_univ_eq_sum_range (fun j => PSpU1 U P D (d.fh + j) d.log) d.np
  have hTb : ∑ j : TbIxU1, helpTabU1 U P D j.1 j.2 = ∑ k ∈ Finset.range 16, PSpU1 U P D (27 + k) 14 := by
    rw [Fintype.sum_prod_type]
    exact Fin.sum_univ_eq_sum_range (fun k => PSpU1 U P D (27 + k) 14) 16
  rw [hS, hPr, hTb, sum_lkDomU1]
  simp only [LkDomU1.np, LkDomU1.fh, LkDomU1.log, Finset.sum_range_succ, Finset.sum_range_zero, zero_add]
  norm_num
  rw [hzs'] at hcl'
  linear_combination hcl'

end Sum

/-! ## 4. `hhr_core_u1`, `hhr_u1`, and `hhr_shieldU1` -/

section Core

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **`HelperRel` at `export_u1` from the vanishing relations, the sum claim, and `H_U`'s zero sum**,
on any committed data `D`. -/
theorem hhr_core_u1 (P : BlockParams) (D : CmData K P) (hln : rowLog P .h = 14)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay) (nG : ℕ)
    (bga : Fp2 × Fp2 × Fp2) (hα : bga.2.2.Canon) (hβ : bga.1.Canon)
    (hD : ∀ κ, 6 ≤ κ → κ < 16 → ∀ b, Dzc.xcDzcU1 U P D Pb Lay B bga κ b = 0)
    (hQ : ∀ κ, 1 ≤ κ → κ < 4 → ∀ b, Qkv.xcQzcU1 U P D Pb Lay B bga κ b = 0)
    (hK : ∀ κ, 1 ≤ κ → κ < 4 → ∀ b, Qkv.xcKvzcU1 U P D Pb Lay B bga κ b = 0)
    (hS : ∀ κ, 4 ≤ κ → κ < 9 → ∀ b, Szc.xcSzcU1 U P D Pb Lay B bga κ b = 0)
    (hF : ∀ κ, 1 ≤ κ → κ < 6 → ∀ b, Fzc.xcFzcU1 U P D Pb Lay B bga κ b = 0)
    (hLz : ∀ b, cLzcU1 U P D bga b = 0) (hT : ∀ k b, cTabU1 U P D Pb nG bga k b = 0)
    (hcl : Link.claimSem U (D.rows .h) (rowLog P .h) (D.Q .h) (D.X .h) (logupSumW16 c0) = 0)
    (hzs : ∑ b : Fin 14 → Bool, hPl U P D (hOffU1 43).1 (hOffU1 43).2 14 b = 0)
    (Alk : SgIxU1 ⊕ (PrIxU1 ⊕ PrIxU1) → Tup K) (hA : ∀ l, Alk l = AlkU1 (L := 0) U P Pb Lay B (fun _ => D) [] l)
    (m : TbIxU1 → K) (hm : ∀ j, m j = mlkU1 (L := 0) U P (fun _ => D) [] j) :
    ∃ Hh, HelperRel (fun l => ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) (Alk l))
      (fun j => ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) (TU1 Pb nG j)) m (bga.2.2.toK U) Hh := by
  refine ⟨⟨fun i => hPl U P D (hOffU1 i.1.hp).1 (hOffU1 i.1.hp).2 i.1.log i.2,
      fun k => hPl U P D (hOffU1 (k.1.fh + k.2.1)).1 (hOffU1 (k.1.fh + k.2.1)).2 k.1.log k.2.2,
      fun j => helpTabU1 U P D j.1 j.2⟩, ?_, ?_, ?_, ?_⟩
  · rintro ⟨s, b⟩
    show _ * (_ - ZK60.Sound.fold _ _ (Alk (.inl ⟨s, b⟩))) = 1
    rw [hA]
    cases s
    · exact relD_singleU1 U P D Pb Lay B bga hα b (hD 15 (by omega) (by omega) b)
    · exact relS_singleU1 U P D Pb Lay B bga hα b (hS (4 + 3) (by omega) (by omega) b)
    · exact relF_singleU1 U P D Pb Lay B bga hα b (hF (2 + 3) (by omega) (by omega) b)
    · exact relExpU1 U P D Pb Lay B bga hα hβ b (hS 8 (by omega) (by omega) b)
    · exact relActU1 U hU P D Pb Lay B bga hα hβ b (hF 1 (by omega) (by omega) b)
  · rintro ⟨d, j, b⟩
    unfold pairFst pairSnd
    show _ * ((_ - ZK60.Sound.fold _ _ (Alk (.inr (.inl ⟨d, j, b⟩))))
      * (_ - ZK60.Sound.fold _ _ (Alk (.inr (.inr ⟨d, j, b⟩)))))
      = (_ - ZK60.Sound.fold _ _ (Alk (.inr (.inl ⟨d, j, b⟩))))
        + (_ - ZK60.Sound.fold _ _ (Alk (.inr (.inr ⟨d, j, b⟩))))
    rw [hA, hA]
    have hj := j.isLt
    cases d
    · have hj0 : (j : ℕ) = 0 := by
        change (j : ℕ) < 1 at hj
        omega
      obtain ⟨j, hj'⟩ := j
      simp only at hj0
      subst hj0
      exact relL_pairU1 U P D bga hα b (hLz b)
    · exact relD_pairU1 U P D Pb Lay B bga hα b j (by change (j : ℕ) < 9 at hj; exact hj)
        (hD (6 + j) (by omega) (by change (j : ℕ) < 9 at hj; omega) b)
    · exact relQ_pairU1 U P D Pb Lay B bga hα b j (by change (j : ℕ) < 3 at hj; exact hj)
        (hQ (1 + j) (by omega) (by change (j : ℕ) < 3 at hj; omega) b)
    · exact relK_pairU1 U P D Pb Lay B bga hα b j (by change (j : ℕ) < 3 at hj; exact hj)
        (hK (1 + j) (by omega) (by change (j : ℕ) < 3 at hj; omega) b)
    · exact relS_pairU1 U P D Pb Lay B bga hα b j (by change (j : ℕ) < 3 at hj; exact hj)
        (hS (4 + j) (by omega) (by change (j : ℕ) < 3 at hj; omega) b)
    · exact relF_pairU1 U P D Pb Lay B bga hα b j (by change (j : ℕ) < 3 at hj; exact hj)
        (hF (2 + j) (by omega) (by change (j : ℕ) < 3 at hj; omega) b)
  · rintro ⟨k, b⟩
    rw [hm]
    have h := hT k b
    unfold cTabU1 at h
    show helpTabU1 U P D k b * (bga.2.2.toK U - ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U)
      (tupK (tabTupU1 Pb nG k (msbIndex 14 b)))) = multTabU1 U P D k b
    linear_combination h
  · exact hhr_sum_u1 U hU P D hln hcl hzs

end Core

section Final

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **LogUp's `hhr` premise at W16R2 Shieldstral (`export_u1`), parametric in `(cnA, cnM)`**:
on every accepting outcome whose helper-layer start claims (`HGdU1`) hold, the committed `H` planes
are helpers satisfying every relation and the sum of `HelperRel` for `AlkU1`, `TU1`, `mlkU1`, given
the verifier fact `hls : P.logupSumClaim = DefW16.logupSumW16 (cfgU1 cnA cnM)`. -/
theorem hhr_u1 (U : K) (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) (hL20 : 2 ^ 20 ≤ L)
    (P : BlockParams) (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsShieldW16 P tag rowsOf)
    (cnA cnM ioIn ioOut : ℕ) (pubs : PubTabs)
    (hdef : P.define = defineS (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs)
    (hlc : P.logCols = 14) (hls : P.logupSumClaim = DefW16.logupSumW16 (cfgU1 cnA cnM)) (hdrLen : ℕ)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K) (rE QE : Cm → ℕ)
    (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
    (A : OC (QB L) Dig (List Op × Core)) :
    ∀ G bga rs acc, AccT U key domain hs hL P hdrLen
      (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
        (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs))
      (Link.csShieldW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      HGdU1 U P (algShapeU1 P hP.hdr)
        (dtU1 Pb Lay B P hP.hdr
          (fun cu rt => xtU1 U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt))
          (xcU1 U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt) Pb Lay B)
          (pwcU1 U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt) Pb Lay B))
        (fun cu rt => dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt) Pb S.nG
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U)
          (AlkU1 U P Pb Lay B (dofAU1 tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A)
            (cutsOf key domain hs hL A G).1 l))
        (fun j => ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) (TU1 Pb S.nG j))
        (mlkU1 U P (dofAU1 tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A)
          (cutsOf key domain hs hL A G).1) (bga.2.2.toK U) Hh := by
  intro G bga rs acc hT hG
  obtain ⟨hα, hβ⟩ := R13H.LookRel.bga_canon_R U key domain hs hL P (by rw [hP.hsl]; decide) _ pubs hdef hdrLen _ _ _
    A G bga rs acc hT
  obtain ⟨hHost, hLz, hTab, hHU⟩ := hG
  have hx : ∀ k, k ∈ algHosts → ∀ κ (hκ : κ < segLn (ZK60.Exec.Slot.W16R2.draws shU1 k) .mu
      - segLn (ZK60.Exec.Slot.W16R2.draws shU1 k) .zeta), relCount k ≤ κ →
      ∀ b : Fin (tauU1 k) → Bool,
        xcU1 U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt) Pb Lay B k
          (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga κ b = 0 := by
    intro k hk κ hκ hr b
    have e := (hHost k hk).1 ⟨κ, hκ⟩ b
    rwa [dtU1_cl_xc Pb Lay B P hP.hdr _ _ _ k _ _ bga ⟨κ, hκ⟩ b hr] at e
  have hD := fun κ (h1 : 6 ≤ κ) (h2 : κ < 16) (b : Fin 19 → Bool) =>
    hx 14 (by decide) κ (by show κ < 16; exact h2) (by show 6 ≤ κ; exact h1) b
  have hQ := fun κ (h1 : 1 ≤ κ) (h2 : κ < 4) (b : Fin 19 → Bool) =>
    hx 15 (by decide) κ (by show κ < 4; exact h2) (by show 1 ≤ κ; exact h1) b
  have hK := fun κ (h1 : 1 ≤ κ) (h2 : κ < 4) (b : Fin 17 → Bool) =>
    hx 16 (by decide) κ (by show κ < 4; exact h2) (by show 1 ≤ κ; exact h1) b
  have hS := fun κ (h1 : 4 ≤ κ) (h2 : κ < 9) (b : Fin 19 → Bool) =>
    hx 17 (by decide) κ (by show κ < 9; exact h2) (by show 4 ≤ κ; exact h1) b
  have hF := fun κ (h1 : 1 ≤ κ) (h2 : κ < 6) (b : Fin 21 → Bool) =>
    hx 18 (by decide) κ (by show κ < 6; exact h2) (by show 1 ≤ κ; exact h1) b
  have hcl0 := hT.2.1.2.2
  rw [hls, logupSumW16_cfgU1] at hcl0
  have hcl : Link.claimSem U ((dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE (cutsOf key domain hs hL A G)
      (rootsOf (A.run G).2)).rows .h) (rowLog P .h) ((dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
      (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).Q .h) ((dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
      (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X .h) (logupSumW16 c0) = 0 := by
    have e : Link.claimSem U ((dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)).rows .h) (rowLog P .h) ((dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).Q .h) ((dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X .h) (logupSumW16 c0)
        = Link.csShieldW16 U tag hL20 csE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) .h
          (logupSumW16 c0) :=
      claimSem_cast14 U 2606 280 P.logCols hlc
        (Link.xHof tag L (Link.le64_of_le20 hL20) 15 280 8052 2606 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        _
    exact e.trans (hcl0.trans (Fp2.toK_zero U))
  have hfun : aPl U P (dofAU1 tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A
      (cutsOf key domain hs hL A G).1)
      = aPl U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE (cutsOf key domain hs hL A G)
          (rootsOf (A.run G).2)) := by
    funext off log b
    exact dofAU1_aPl U key domain hs hL tag hL20 P hlc rE QE XE A G off log b
  refine hhr_core_u1 U hU P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE (cutsOf key domain hs hL A G)
    (rootsOf (A.run G).2)) (show P.logCols = 14 from hlc) Pb Lay B S.nG bga hα hβ hD hQ hK hS hF hLz.1 hTab.1 hcl
    hHU _ (fun l => ?_) _ (fun j => ?_)
  · rcases l with ⟨s, b⟩ | ⟨d, j, b⟩ | ⟨d, j, b⟩
    · cases s <;> (simp only [AlkU1, sgTupU1, lkAtU1, lkTupU1, expTupU1, actTupU1]; rw [hfun])
    · simp only [AlkU1, lkAtU1, lkTupU1]
      rw [hfun]
    · simp only [AlkU1, lkAtU1, lkTupU1]
      rw [hfun]
  · simp only [mlkU1, multTabU1]
    rw [hfun]

/-- **LogUp's `hhr` premise at any layer `Ly : ShieldLayer` of W16R2 Shieldstral (`export_u1`)**,
directly matching `block_knowledge_join_w16r2_shieldU1`'s `hhr` premise (with `S := shieldShape Ly`,
`cnA := Ly.cnA`, `cnM := Ly.cnM`). -/
theorem hhr_shieldU1 (Ly : ShieldLayer) (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (tag : MTag)
    (rowsOf : Cm → ℕ) (hP : Link.IsShieldW16 P tag rowsOf) (ioIn ioOut : ℕ) (pubs : PubTabs)
    (hdef : P.define = defineS (DefW16.progW16 (cfgU1 Ly.cnA Ly.cnM) ioIn ioOut) pubs)
    (hlc : P.logCols = 14) (hls : P.logupSumClaim = DefW16.logupSumW16 (cfgU1 Ly.cnA Ly.cnM))
    (hdrLen : ℕ) (csE : Cuts3 L → RootsO → Cm → ZClaim → K) (rE QE : Cm → ℕ)
    (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (Pb : ZK60.Block.BlockPublic (shieldShape Ly))
    (Lay : W16Layout (shieldShape Ly) CtU1 CwU1 CgU1 CjU1 CdU1 CfU1)
    (B : W16Pub (shieldShape Ly) Pb Lay) (A : OC (QB L) Dig (List Op × Core)) :
    ∀ G bga rs acc, AccT U key domain hs hL P hdrLen
      (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
        (DefW16.progW16 (cfgU1 Ly.cnA Ly.cnM) ioIn ioOut) pubs))
      (Link.csShieldW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      HGdU1 U P (algShapeU1 P hP.hdr)
        (dtU1 Pb Lay B P hP.hdr
          (fun cu rt => xtU1 U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt))
          (xcU1 U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt) Pb Lay B)
          (pwcU1 U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt) Pb Lay B))
        (fun cu rt => dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt) Pb (shieldShape Ly).nG
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U)
          (AlkU1 U P Pb Lay B (dofAU1 tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A)
            (cutsOf key domain hs hL A G).1 l))
        (fun j => ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) (TU1 Pb (shieldShape Ly).nG j))
        (mlkU1 U P (dofAU1 tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A)
          (cutsOf key domain hs hL A G).1) (bga.2.2.toK U) Hh :=
  hhr_u1 U hU key domain hs hL hL20 P tag rowsOf hP Ly.cnA Ly.cnM ioIn ioOut pubs hdef hlc hls hdrLen
    csE rE QE XE Pb Lay B A

end Final

end ZK60.Exec.Block.Join.W16U1.Look
