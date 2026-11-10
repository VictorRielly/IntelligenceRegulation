/-
D63 lane L47 (2026-11-10), part 1: **`SC_TAB`'s tables at the W16R2 rung, from the public data, and its certified
polynomial** (deliverable 1 and the lookup side's public tables of deliverable 2).

The code (`ops/zkp-mvp/gpu-metal/hashline/src/private_block/`, read 2026-11-10; nothing there is changed):
`argument_accuracy.rs::tab_w16` (738-782): per table `(multiplicity, helper, public value column)` the relation
`h·(α − t) − m`, the three histograms (bytes, exp, ACT) then one triple per range sub-plane; the pad groups (bytes and
exp under `supp(Tab)`, ACT under its support column, each narrow range family under its own); `argument.rs`
`table_values_u8_at`, `table_values_exp_at` (1953-1961), `accuracy_act.rs::table` (13-31), `range16.rs`
(`g_range`, `support`, `full`, `value`, `table_column`, `support_column`, 51-242), `pad.rs::closed_form_indicator`
(`Dom::L`: token and limb axes; `Dom::Tab`: `x < 256`).

* `tabSubS`, `supW`, **`tabTupW Pb nG k i`**: the code's table tuple of table `k` (`0` bytes, `1` exp, `2` ACT, `3 + j`
  range sub-plane `j`) at position `i`, over `GF` (`x`, tag, `y`, `z`); the ACT table's padding rows are group `0`'s row at
  `2048` (the code's `2048 + g_act`, equal because the code refuses an ACT table whose row `2048` is not `0`);
* `foldWd β γ u`: the fold `x + γ·tag + β·y + β²·z` in the code's word arithmetic; **`toK_foldWd`**: read in the field it
  IS `fold β γ (tupK u)` (no canonicity premise);
* `gateLW` (`supp(Dom::L)`: limb rows `x / 32 < 9`), `tabNarrow`, `gateTabW` (`supp(Dom::Tab)`: `x < 256`; the ACT support
  `x < nG·4096`; a narrow family's support `x < 2^w`);
* **`restW16 Pb nG`**: the lookup side's public tables (`rest` of `pubsW16 B rest`): `SC_LZC`'s support gate (slot 3),
  `SC_TAB`'s 17 folded value columns and 10 gates (slot 19), `SC_ZS`'s all-ones table (slot 20); its entries read in the
  field (`rest3_getD`, `rest19_getD`, `rest19_gate_getD`, `rest20_getD`);
* `helpTabW`, `multTabW`, **`cTabW`** (the 17 table relations `h_k·(α − fold(T_k)) − m_k`, read at `(β, γ, α)` only),
  `tabPadIx`, **`wTabW`** (the 22 pad planes `(1 − gate)·plane`), **`spTabW`**: `SC_TAB`'s certified polynomial (L23's
  `SlotPoly.zc` on these clauses; degree `24`); `spTabW_dg`, `spTabW_Gd`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockHostPub
import ZK60Formal.BlockLkGd

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Tab

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.DefW16
open ZK60.Circuit (gP GF tagW tagExp tagAct)
open ZK60.Layout

/-! ## The code's table tuples -/

/-- Each range sub-plane's index in its family (`range_planes`' `s`), in sub-plane order. -/
def tabSubS (c : W16Cfg) : List ℕ := c.fams.flatMap fun f => List.range f.2

/-- `range16::support` on a row of `2^14` columns: a family of width `w` has `min(2^w, 2^14)` true rows per
sub-plane. -/
def supW (w : ℕ) : ℕ := min (2 ^ w) (2 ^ 14)

/-- **The code's table tuple** of `SC_TAB`'s table `k` at position `i` (`k = 0` bytes `(i mod 256, TAG_U8)`, `k = 1`
exp `(i mod 256, TAG_EXP, exp[i mod 256])`, `k = 2` ACT `(gate, TAG_ACT, act[G][gate], G)` on the `nG·4096` true rows and
group `0`'s row at `2048` elsewhere, `k = 3 + j` range sub-plane `j`: `(s·2^14 + i mod support, TAG_RANGE0 + w)`),
for the exp table `exp` and the scaled ACT tables `act` of the public data. -/
def tabTupE (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG k i : ℕ) : Tup GF :=
  if k = 0 then ⟨((i % 256 : ℕ) : GF), ((tagW 8 : ℕ) : GF), 0, 0⟩
  else if k = 1 then ⟨((i % 256 : ℕ) : GF), ((tagExp : ℕ) : GF), ((exp ((i % 256 : ℕ) : ℤ) : ℤ) : GF), 0⟩
  else if k = 2 then
    (if i < nG * 4096 then
      ⟨((i % 4096 : ℕ) : GF), ((tagAct : ℕ) : GF), ((act (i / 4096) ((i % 4096 : ℕ) : ℤ) : ℤ) : GF),
        ((i / 4096 : ℕ) : GF)⟩
    else ⟨((2048 : ℕ) : GF), ((tagAct : ℕ) : GF), ((act 0 ((2048 : ℕ) : ℤ) : ℤ) : GF), ((0 : ℕ) : GF)⟩)
  else
    ⟨(((tabSubS cfgRungW16).getD (k - 3) 0 * 2 ^ 14 + i % supW ((subW cfgRungW16).getD (k - 3) 0) : ℕ) : GF),
      ((tagW ((subW cfgRungW16).getD (k - 3) 0) : ℕ) : GF), 0, 0⟩

/-- The table tuple at a block's public data. -/
def tabTupW {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG k i : ℕ) : Tup GF :=
  tabTupE Pb.exp Pb.act nG k i

/-! ## The fold in the code's arithmetic -/

/-- **The fold `x + γ·tag + β·y + β²·z`** of a `GF` tuple in the code's word arithmetic (`g_u8`, `g_range`, `g_exp`,
`g_act` and the `β`, `β²` terms of `table_values_*`, `accuracy_act::table`). -/
def foldWd (β γ : Fp2) (u : Tup GF) : Fp2 :=
  Fp2.add (Fp2.add (Fp2.add (wordGF u.x) (Fp2.mul γ (wordGF u.tag))) (Fp2.mul β (wordGF u.y)))
    (Fp2.mul (Fp2.mul β β) (wordGF u.z))

section Fold

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **The word fold read in the field is the fold of the tuple read in the field.** -/
theorem toK_foldWd (β γ : Fp2) (u : Tup GF) :
    (foldWd β γ u).toK U = fold (β.toK U) (γ.toK U) (tupK u) := by
  unfold foldWd
  rw [Fp2.toK_add U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
    Fp2.toK_add U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
    Fp2.toK_add U _ _ (wordGF_canon _) (Fp2.canon_mul _ _),
    Fp2.toK_mul U hU, Fp2.toK_mul U hU, Fp2.toK_mul U hU, Fp2.toK_mul U hU,
    toK_wordGF, toK_wordGF, toK_wordGF, toK_wordGF]
  unfold ZK60.Sound.fold tupK
  ring

end Fold

/-! ## The gates -/

/-- **`supp(Dom::L)`** (`closed_form_indicator`: the token axis, which does not pad at the rung, and the limb axis
`3·LIMBS_ISQRT = 9` rows of `32`). -/
def gateLW (b : Fin 14 → Bool) : GF := if msbIndex 14 b / 32 < 9 then 1 else 0

/-- The narrow range sub-planes (those whose family is not full on a row), in sub-plane order. -/
def tabNarrow : List ℕ :=
  (List.range (nRange cfgRungW16)).filter fun j =>
    !(ZK60.Exec.Slot.Build.Lay.fullW ((subW cfgRungW16).getD j 0) cfgRungW16.logCols)

/-- **`SC_TAB`'s gate `g`**: `0` `supp(Dom::Tab)` (`x < 256`), `1` the ACT support (`x < nG·4096`), `2 + q` the support
column of the `q`-th narrow range sub-plane (`x < 2^w`). -/
def gateTabW (nG g : ℕ) (b : Fin 14 → Bool) : GF :=
  if g = 0 then (if msbIndex 14 b < 256 then 1 else 0)
  else if g = 1 then (if msbIndex 14 b < nG * 4096 then 1 else 0)
  else (if msbIndex 14 b < supW ((subW cfgRungW16).getD (tabNarrow.getD (g - 2) 0) 0) then 1 else 0)

/-! ## The lookup side's public tables -/

/-- **The lookup side's public tables at the rung** (`rest` of `pubsW16 B rest`): `SC_LZC`'s `supp(Dom::L)`,
`SC_TAB`'s 17 value columns (the tables' tuples folded with the history's `β`, `γ`) and 10 gates, `SC_ZS`'s all-ones
table; for the exp table `exp` and the scaled ACT tables `act`. -/
def restE (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) : PubTabs := fun s hist _ i =>
  if s = 3 then (if i = 0 then cubeTab 14 gateLW else [])
  else if s = 19 then
    (if i < 17 then (List.range (2 ^ 14)).map (fun idx => foldWd hist.beta hist.gamma (tabTupE exp act nG i idx))
      else if i < 27 then cubeTab 14 (gateTabW nG (i - 17)) else [])
  else if s = 20 then (if i = 0 then cubeTab 14 (fun _ => 1) else [])
  else []

/-- **The lookup side's public tables** at a block's public data. -/
def restW16 {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ) : PubTabs := restE Pb.exp Pb.act nG

section Rest

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ)

/-- The concrete public tables at the lookup side's slots are `restW16`'s. -/
theorem pubsW16_rest (Lay : W16Layout S CtW CwW CgW CjW CdW CfW) (B : W16Pub S Pb Lay) (s : ℕ)
    (hs : s = 3 ∨ s = 19 ∨ s = 20) (hist : Hist) (dr : List Fp2) (i : ℕ) :
    pubsW16 Pb Lay B (restW16 Pb nG) s hist dr i = restW16 Pb nG s hist dr i := by
  rcases hs with rfl | rfl | rfl <;> rfl

/-- `SC_LZC`'s gate, read in the field (L44's `hgate`). -/
theorem rest3_getD (hist : Hist) (dr : List Fp2) (b : Fin 14 → Bool) :
    ((restW16 Pb nG 3 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gateLW b) := by
  show ((cubeTab 14 gateLW).getD (msbIndex 14 b) Fp2.zero).toK U = _
  rw [cubeTab_getD, toK_wordGF]

/-- `SC_ZS`'s all-ones table, read in the field (L44's `hones`). -/
theorem rest20_getD (hist : Hist) (dr : List Fp2) (b : Fin 14 → Bool) :
    ((restW16 Pb nG 20 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = 1 := by
  show ((cubeTab 14 (fun _ => (1 : GF))).getD (msbIndex 14 b) Fp2.zero).toK U = _
  rw [cubeTab_getD, toK_wordGF, map_one]

include hU in
/-- **`SC_TAB`'s value column `k`, read in the field**: the fold of the table tuple at `(β, γ)` of the history. -/
theorem rest19_getD (hist : Hist) (dr : List Fp2) (k : ℕ) (hk : k < 17) (b : Fin 14 → Bool) :
    ((restW16 Pb nG 19 hist dr k).getD (msbIndex 14 b) Fp2.zero).toK U
      = fold (hist.beta.toK U) (hist.gamma.toK U) (tupK (tabTupW Pb nG k (msbIndex 14 b))) := by
  show ((if k < 17 then (List.range (2 ^ 14)).map (fun idx => foldWd hist.beta hist.gamma (tabTupW Pb nG k idx))
      else if k < 27 then cubeTab 14 (gateTabW nG (k - 17)) else []).getD (msbIndex 14 b) Fp2.zero).toK U = _
  rw [ite_eq_left hk, List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range (msbIndex_lt 14 b)]
  simp only [Option.map_some, Option.getD_some]
  exact toK_foldWd U hU _ _ _

/-- **`SC_TAB`'s gate `i − 17`, read in the field.** -/
theorem rest19_gate_getD (hist : Hist) (dr : List Fp2) (i : ℕ) (h1 : 17 ≤ i) (h2 : i < 27) (b : Fin 14 → Bool) :
    ((restW16 Pb nG 19 hist dr i).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gateTabW nG (i - 17) b) := by
  show ((if i < 17 then (List.range (2 ^ 14)).map (fun idx => foldWd hist.beta hist.gamma (tabTupW Pb nG i idx))
      else if i < 27 then cubeTab 14 (gateTabW nG (i - 17)) else []).getD (msbIndex 14 b) Fp2.zero).toK U = _
  rw [ite_eq_right (by omega), ite_eq_left h2, cubeTab_getD, toK_wordGF]

end Rest

/-! ## `SC_TAB`'s certified polynomial -/

section Poly

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- `SC_TAB`'s helper `k` (`H` plane `28 + k`, `HIds::table_helpers` then `range_helpers`). -/
noncomputable def helpTabW (P : BlockParams) (D : CmData K P) (k : ℕ) (b : Fin 14 → Bool) : K :=
  hPl U P D (hOff cfgRungW16 (28 + k)).1 (hOff cfgRungW16 (28 + k)).2 14 b

/-- `SC_TAB`'s multiplicity `k` (`A` plane `58 + k`: `MU8`, `MEXP`, `MACT`, then the range sub-planes). -/
noncomputable def multTabW (P : BlockParams) (D : CmData K P) (k : ℕ) (b : Fin 14 → Bool) : K :=
  aPl U P D (aOff cfgRungW16 (58 + k)) 14 b

/-- **`SC_TAB`'s table relation `k`** at a cube point, read at `bga = (β, γ, α)`: `h_k·(α − fold(T_k)) − m_k`. -/
noncomputable def cTabW (P : BlockParams) (D : CmData K P) {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (nG : ℕ) (bga : Fp2 × Fp2 × Fp2) (k : Fin 17) (b : Fin 14 → Bool) : K :=
  helpTabW U P D k b * (bga.2.2.toK U - fold (bga.1.toK U) (bga.2.1.toK U) (tupK (tabTupW Pb nG k (msbIndex 14 b))))
    - multTabW U P D k b

/-- The pad plane `j < 22`: its gate, whether it is a helper (else a multiplicity) and its table, in `tab_w16`'s order:
`m₀ m₁ h₀ h₁` under `supp(Tab)`, `m₂`, `h₂` under the ACT support, then `m_{3+q}`, `h_{3+q}` under narrow family `q`. -/
def tabPadIx (j : ℕ) : ℕ × Bool × ℕ :=
  if j < 4 then (0, decide (2 ≤ j), j % 2)
  else if j < 6 then (1, decide (j = 5), 2)
  else (2 + (j - 6) / 2, decide ((j - 6) % 2 = 1), 3 + tabNarrow.getD ((j - 6) / 2) 0)

/-- **`SC_TAB`'s pad plane `j`**: `(1 − gate)·plane`. -/
noncomputable def wTabW (P : BlockParams) (D : CmData K P) (nG : ℕ) (j : Fin 22) (b : Fin 14 → Bool) : K :=
  (1 - algebraMap GF K (gateTabW nG (tabPadIx j).1 b))
    * (if (tabPadIx j).2.1 then helpTabW U P D (tabPadIx j).2.2 b else multTabW U P D (tabPadIx j).2.2 b)

/-- A draw vector of `SC_TAB` (`τ` 0–13, `μ` 14–30, `μ_pad` 31, `ζ` 32). -/
def secTabW (ω : (K × K) × (Fin 17 → K)) (τ : Fin 14 → K) : Fin 33 → K :=
  fun i => if h : (i : ℕ) < 14 then τ ⟨i, h⟩ else if h2 : (i : ℕ) < 31 then ω.2 ⟨(i : ℕ) - 14, by omega⟩
    else if (i : ℕ) = 31 then ω.1.2 else ω.1.1

variable [Fintype K] [DecidableEq K] (hcard : 78 < Fintype.card K)

include hcard in
/-- **`SC_TAB`'s certified polynomial** (L23's `SlotPoly.zc`; draws `τ` 0–13, `μ` 14–30 on the 17 relations, `μ_pad` 31,
`ζ` 32): its start claim is that the 17 table relations and the 22 pad planes vanish on the cube. -/
noncomputable def spTabW (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (D : CmData K P)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ) (bga : Fp2 × Fp2 × Fp2) :
    SlotPoly K (P.draws 19) :=
  SlotPoly.cast (by rw [hdr]; decide)
    (SlotPoly.zc (n := 14) (m := 22) (D := 33) (nc := 17) (cTabW U P D Pb nG bga) (wTabW U P D nG)
      (fun x => x 32) (fun x => x 31) (fun k => ⟨14 + (k : ℕ), by omega⟩) (fun i => Fin.castLE (by norm_num) i)
      (ZK60.Sound.SlotW16.indDeg_coord 32) (ZK60.Sound.SlotW16.indDeg_coord 31)
      (Fin.castLE_injective (by norm_num : 14 ≤ 33)) (by omega)
      (fun ω τ _ => ⟨secTabW ω τ, by simp [secTabW], funext fun k => by
          unfold secTabW
          have h1 : ¬ (14 + (k : ℕ) < 14) := by omega
          have h2 : 14 + (k : ℕ) < 31 := by omega
          simp only [h1, h2, ↓reduceDIte]
          exact congrArg ω.2 (Fin.ext (by simp)),
        funext fun i => by simp [secTabW]⟩))

theorem spTabW_dg (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (D : CmData K P)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ) (bga : Fp2 × Fp2 × Fp2) :
    (spTabW U hcard P hdr D Pb nG bga).dg = 24 := rfl

theorem spTabW_Gd (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (D : CmData K P)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ) (bga : Fp2 × Fp2 × Fp2) :
    (spTabW U hcard P hdr D Pb nG bga).Gd
      = ((∀ k b, cTabW U P D Pb nG bga k b = 0) ∧ ∀ j b, wTabW U P D nG j b = 0) := rfl

end Poly

end ZK60.Exec.Block.Join.W16.Tab
