/-
D63 lane L47 (2026-11-10), part 5 (fork C): **LogUp's helper relations at the six hosts' cube points** (for `hhr`).

* `LkOK`, `lkOK_all`: the code's lookups' constants, coefficients and tags are words (checked);
* **`host_pair`**, **`host_single`**: a host's LogUp relation `κ` vanishing at a point IS `HelperRel`'s pair (single)
  relation of the lookup tuples read off the planes (`lkTupP`), at a canonical `α`;
* per host, the value list's positions hold the lookups' planes and the helpers (`dzc_planes`, `dzc_help`, … ,
  evaluated against L44's value lists), and the named relations: **`relL_pair`** (`SC_LZC`), **`relD_pair`**,
  **`relD_single`**, **`relQ_pair`**, **`relK_pair`**, **`relS_pair`**, **`relS_single`**, **`relF_pair`**,
  **`relF_single`**, **`relExp`** (`SC_SZC`'s exp tuple), **`relAct`** (`SC_FZC`'s ACT tuple).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockLookRelBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Look

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build (LkD denV Cst)
open ZK60.Exec.Slot.Build.Lay (LkW)
open ZK60.Circuit (gP GF tagW tagExp tagAct)
open ZK60.Layout
open ZK60.Exec.Slot.Compose (cstW_map_std)

/-! ## The code's lookups are words -/

/-- What the denominator lemma reads of a lookup. -/
def LkOK (l : LkW) : Prop :=
  -2 ^ 64 < l.cst ∧ l.cst < 2 ^ 64 ∧ tagW l.tag < 2 ^ 64 ∧ ∀ t ∈ l.terms, -2 ^ 64 < -t.2 ∧ -t.2 < 2 ^ 64

instance (l : LkW) : Decidable (LkOK l) := by
  unfold LkOK
  infer_instance

theorem lkOK_all : ∀ d : LkDom, ∀ l ∈ lookupsN cfgRungW16 d.dom, LkOK l := by
  intro d
  cases d <;> decide

theorem lkOK_getD (L : List LkW) (h : ∀ l ∈ L, LkOK l) (i : ℕ) : LkOK (L.getD i ⟨[], 0, 0⟩) := by
  rw [List.getD_eq_getElem?_getD]
  cases hL : L[i]? with
  | none =>
    show LkOK ⟨[], 0, 0⟩
    decide
  | some l => exact h l (List.mem_of_getElem? hL)

theorem terms_getD (L : List LkW) (Pt : ℕ × ℤ → Prop) (h : ∀ l ∈ L, ∀ t ∈ l.terms, Pt t) (i : ℕ) :
    ∀ t ∈ (L.getD i ⟨[], 0, 0⟩).terms, Pt t := by
  rw [List.getD_eq_getElem?_getD]
  cases hL : L[i]? with
  | none =>
    intro t ht
    simp at ht
  | some l => exact h l (List.mem_of_getElem? hL)

/-! ## A host's relation is `HelperRel`'s -/

section Host

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- The lookups of `L` through `shaped`, at the transcript `(β, γ, α)`, read in the field. -/
noncomputable def lksAt (k : ℕ) (shaped : ℕ → ℕ) (L : List LkW) (bga : Fp2 × Fp2 × Fp2) : List (LkD K) :=
  ((L.map (lkSymW shaped)).map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) k []))).map
    (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U))

/-- **A host's pair relation `j`, vanishing, is `HelperRel`'s pair relation.** -/
theorem host_pair (bga : Fp2 × Fp2 × Fp2) (hα : bga.2.2.Canon) (k : ℕ) (shaped : ℕ → ℕ) (L : List LkW)
    (v : List K) (pl : ℕ → K) (h0 : ℕ) (hp : K) (j : ℕ) (hj : 2 * j + 1 < L.length) (hB : ∀ l ∈ L, LkOK l)
    (hv : ∀ l ∈ L, ∀ t ∈ l.terms, v.getD (shaped t.1) 0 = pl t.1) (hh : v.getD (h0 + 0 + j) 0 = hp)
    (hr : (lkRels (cstK U) v h0 0 (lksAt U k shaped L bga)).getD j 0 = 0) :
    hp * ((bga.2.2.toK U - ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) (lkTupP pl (L.getD (2 * j) ⟨[], 0, 0⟩)))
        * (bga.2.2.toK U - ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) (lkTupP pl (L.getD (2 * j + 1) ⟨[], 0, 0⟩))))
      = (bga.2.2.toK U - ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) (lkTupP pl (L.getD (2 * j) ⟨[], 0, 0⟩)))
        + (bga.2.2.toK U - ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U)
          (lkTupP pl (L.getD (2 * j + 1) ⟨[], 0, 0⟩))) := by
  have hlen : 2 * j + 1 < (lksAt U k shaped L bga).length := by
    unfold lksAt
    simp only [List.length_map]
    exact hj
  unfold lksAt at hr hlen
  rw [relLk_pair (cstK U) v h0 (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U)
      (ZK60.Exec.Slot.Build.LkD.map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) k []) (lkSymW shaped ⟨[], 0, 0⟩)))
      j 0 _ hlen, lks_getD, lks_getD, hh] at hr
  have hB1 := lkOK_getD L hB (2 * j)
  have hB2 := lkOK_getD L hB (2 * j + 1)
  rw [denV_lkSym U (histOf bga.1 bga.2.1 bga.2.2 []) hα k [] shaped _ hB1.1 hB1.2.1 hB1.2.2.1 hB1.2.2.2 v pl
      (terms_getD L _ hv (2 * j)),
    denV_lkSym U (histOf bga.1 bga.2.1 bga.2.2 []) hα k [] shaped _ hB2.1 hB2.2.1 hB2.2.2.1 hB2.2.2.2 v pl
      (terms_getD L _ hv (2 * j + 1)),
    (cstW_map_std U).one, (cstW_map_std U).negOne] at hr
  exact pair_of_rel hr

/-- **A host's odd last relation, vanishing, is `HelperRel`'s single relation.** -/
theorem host_single (bga : Fp2 × Fp2 × Fp2) (hα : bga.2.2.Canon) (k : ℕ) (shaped : ℕ → ℕ) (L : List LkW)
    (v : List K) (pl : ℕ → K) (h0 : ℕ) (hp : K) (m : ℕ) (hm : L.length = 2 * m + 1) (hB : ∀ l ∈ L, LkOK l)
    (hv : ∀ l ∈ L, ∀ t ∈ l.terms, v.getD (shaped t.1) 0 = pl t.1) (hh : v.getD (h0 + 0 + m) 0 = hp)
    (hr : (lkRels (cstK U) v h0 0 (lksAt U k shaped L bga)).getD m 0 = 0) :
    hp * (bga.2.2.toK U - ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) (lkTupP pl (L.getD (2 * m) ⟨[], 0, 0⟩)))
      = 1 := by
  have hlen : (lksAt U k shaped L bga).length = 2 * m + 1 := by
    unfold lksAt
    simp only [List.length_map]
    exact hm
  unfold lksAt at hr hlen
  rw [relLk_single (cstK U) v h0 (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U)
      (ZK60.Exec.Slot.Build.LkD.map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) k []) (lkSymW shaped ⟨[], 0, 0⟩)))
      m 0 _ hlen, lks_getD, hh] at hr
  have hB1 := lkOK_getD L hB (2 * m)
  rw [denV_lkSym U (histOf bga.1 bga.2.1 bga.2.2 []) hα k [] shaped _ hB1.1 hB1.2.1 hB1.2.2.1 hB1.2.2.2 v pl
      (terms_getD L _ hv (2 * m)), (cstW_map_std U).one, (cstW_map_std U).negOne] at hr
  exact single_of_rel hr

end Host

/-! ## The six hosts' value lists -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- The planes a domain's lookups read, read off `A` at the code's offsets. -/
noncomputable def plA (log : ℕ) (b : Fin log → Bool) : ℕ → K := fun q => aPl U P D (aOff cfgRungW16 q) log b

theorem dzc_planes (b : Fin 14 → Bool) : ∀ l ∈ lookupsN cfgRungW16 .D, ∀ t ∈ l.terms,
    (Dzc.valsXD U P D Pb Lay B b).getD (Dzc.shD t.1) 0 = plA U P D 14 b t.1 := by
  have hnum : ∀ l ∈ lookupsN cfgRungW16 .D, ∀ t ∈ l.terms,
      8 ≤ t.1 ∧ t.1 ≤ 26 ∧ aOff cfgRungW16 t.1 = 131072 + (t.1 - 8) * 16384 := by decide +kernel
  intro l hl t ht
  obtain ⟨h1, h2, h3⟩ := hnum l hl t ht
  unfold plA
  rw [h3]
  generalize t.1 = q at h1 h2 ⊢
  interval_cases q <;> rfl

theorem dzc_help (b : Fin 14 → Bool) (j : ℕ) (hj : j < 10) :
    (Dzc.valsXD U P D Pb Lay B b).getD (26 + 0 + j) 0
      = hPl U P D (hOff cfgRungW16 (1 + j)).1 (hOff cfgRungW16 (1 + j)).2 14 b := by
  have hoff : ∀ j < 10, hOff cfgRungW16 (1 + j) = (32768 + 32768 * j, 49152 + 32768 * j) := by decide +kernel
  rw [hoff j hj]
  interval_cases j <;> rfl

theorem qzc_planes (b : Fin 15 → Bool) : ∀ l ∈ lookupsN cfgRungW16 .Q, ∀ t ∈ l.terms,
    (Qkv.valsXQ U P D Pb Lay B b).getD (Qkv.shQ t.1) 0 = plA U P D 15 b t.1 := by
  have hnum : ∀ l ∈ lookupsN cfgRungW16 .Q, ∀ t ∈ l.terms,
      27 ≤ t.1 ∧ t.1 ≤ 32 ∧ aOff cfgRungW16 t.1 = 442368 + (t.1 - 27) * 32768 := by decide +kernel
  intro l hl t ht
  obtain ⟨h1, h2, h3⟩ := hnum l hl t ht
  unfold plA
  rw [h3]
  generalize t.1 = q at h1 h2 ⊢
  interval_cases q <;> rfl

theorem qzc_help (b : Fin 15 → Bool) (j : ℕ) (hj : j < 3) :
    (Qkv.valsXQ U P D Pb Lay B b).getD (12 + 0 + j) 0
      = hPl U P D (hOff cfgRungW16 (11 + j)).1 (hOff cfgRungW16 (11 + j)).2 15 b := by
  have hoff : ∀ j < 3, hOff cfgRungW16 (11 + j) = (360448 + 65536 * j, 393216 + 65536 * j) := by decide +kernel
  rw [hoff j hj]
  interval_cases j <;> rfl

theorem kvzc_planes (b : Fin 14 → Bool) : ∀ l ∈ lookupsN cfgRungW16 .Kv, ∀ t ∈ l.terms,
    (Qkv.valsXK U P D Pb Lay B b).getD (Qkv.shK t.1) 0 = plA U P D 14 b t.1 := by
  have hnum : ∀ l ∈ lookupsN cfgRungW16 .Kv, ∀ t ∈ l.terms,
      33 ≤ t.1 ∧ t.1 ≤ 38 ∧ aOff cfgRungW16 t.1 = 638976 + (t.1 - 33) * 16384 := by decide +kernel
  intro l hl t ht
  obtain ⟨h1, h2, h3⟩ := hnum l hl t ht
  unfold plA
  rw [h3]
  generalize t.1 = q at h1 h2 ⊢
  interval_cases q <;> rfl

theorem kvzc_help (b : Fin 14 → Bool) (j : ℕ) (hj : j < 3) :
    (Qkv.valsXK U P D Pb Lay B b).getD (12 + 0 + j) 0
      = hPl U P D (hOff cfgRungW16 (14 + j)).1 (hOff cfgRungW16 (14 + j)).2 14 b := by
  have hoff : ∀ j < 3, hOff cfgRungW16 (14 + j) = (557056 + 32768 * j, 573440 + 32768 * j) := by decide +kernel
  rw [hoff j hj]
  interval_cases j <;> rfl

theorem szc_planes (b : Fin 14 → Bool) : ∀ l ∈ lookupsN cfgRungW16 .S, ∀ t ∈ l.terms,
    (Szc.valsX U P D B b).getD (Szc.shapedS t.1) 0 = plA U P D 14 b t.1 := by
  have hnum : ∀ l ∈ lookupsN cfgRungW16 .S, ∀ t ∈ l.terms,
      39 ≤ t.1 ∧ t.1 ≤ 48 ∧ aOff cfgRungW16 t.1 = 737280 + (t.1 - 39) * 16384 := by decide +kernel
  intro l hl t ht
  obtain ⟨h1, h2, h3⟩ := hnum l hl t ht
  unfold plA
  rw [h3]
  generalize t.1 = q at h1 h2 ⊢
  interval_cases q <;> rfl

theorem szc_help (b : Fin 14 → Bool) (j : ℕ) (hj : j < 6) :
    (Szc.valsX U P D B b).getD (16 + 0 + j) 0
      = hPl U P D (hOff cfgRungW16 (17 + j)).1 (hOff cfgRungW16 (17 + j)).2 14 b := by
  have hoff : ∀ j < 6, hOff cfgRungW16 (17 + j) = (655360 + 32768 * j, 671744 + 32768 * j) := by decide +kernel
  rw [hoff j hj]
  interval_cases j <;> rfl

theorem fzc_planes (b : Fin 15 → Bool) : ∀ l ∈ lookupsN cfgRungW16 .F, ∀ t ∈ l.terms,
    (Fzc.valsF U P D Pb Lay B b).getD (Fzc.shF t.1) 0 = plA U P D 15 b t.1 := by
  have hnum : ∀ l ∈ lookupsN cfgRungW16 .F, ∀ t ∈ l.terms,
      49 ≤ t.1 ∧ t.1 ≤ 57 ∧ aOff cfgRungW16 t.1 = 901120 + (t.1 - 49) * 32768 := by decide +kernel
  intro l hl t ht
  obtain ⟨h1, h2, h3⟩ := hnum l hl t ht
  unfold plA
  rw [h3]
  generalize t.1 = q at h1 h2 ⊢
  interval_cases q <;> rfl

theorem fzc_help (b : Fin 15 → Bool) (j : ℕ) (hj : j < 5) :
    (Fzc.valsF U P D Pb Lay B b).getD (12 + 0 + j) 0
      = hPl U P D (hOff cfgRungW16 (23 + j)).1 (hOff cfgRungW16 (23 + j)).2 15 b := by
  have hoff : ∀ j < 5, hOff cfgRungW16 (23 + j) = (851968 + 65536 * j, 884736 + 65536 * j) := by decide +kernel
  rw [hoff j hj]
  interval_cases j <;> rfl

theorem lzc_planes (gL : (Fin 14 → Bool) → GF) (b : Fin 14 → Bool) : ∀ l ∈ lookupsN cfgRungW16 .L, ∀ t ∈ l.terms,
    (Lk.valsL U P D gL b).getD (Lk.shapedL t.1) 0 = plA U P D 14 b t.1 := by
  have hnum : ∀ l ∈ lookupsN cfgRungW16 .L, ∀ t ∈ l.terms,
      6 ≤ t.1 ∧ t.1 ≤ 7 ∧ aOff cfgRungW16 t.1 = 98304 + (t.1 - 6) * 16384 := by decide +kernel
  intro l hl t ht
  obtain ⟨h1, h2, h3⟩ := hnum l hl t ht
  unfold plA
  rw [h3]
  generalize t.1 = q at h1 h2 ⊢
  interval_cases q <;> rfl

theorem lzc_help (gL : (Fin 14 → Bool) → GF) (b : Fin 14 → Bool) :
    (Lk.valsL U P D gL b).getD (3 + 0 + 0) 0
      = hPl U P D (hOff cfgRungW16 (0 + 0)).1 (hOff cfgRungW16 (0 + 0)).2 14 b := by
  rw [show hOff cfgRungW16 (0 + 0) = (0, 16384) by decide +kernel]
  rfl

end Vals

end ZK60.Exec.Block.Join.W16.Look
