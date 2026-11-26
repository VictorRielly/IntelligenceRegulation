/-
D63 W16R2 Shieldstral port, Item (5d) (`BlockW16U1TabBase.lean`):
**`SC_TAB`'s tables at `export_u1` (`nRange = 13`, `16` value columns, `9` gates, `20` pad planes,
`32` draws), the concrete public tables `restU1` / `pubsU1`, and `SC_TAB`'s certified polynomial
`spTabU1`.**

Reuses `tabSubS`, `supW`, `foldWd`, `toK_foldWd` from `BlockTabBase.lean`, and `Pub.pubsR13`,
`Pub.pubR_of`, `Pub.gateLS` from `BlockR13HostPub.lean`.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.BlockW16U1Base
import ZK60Formal.BlockTabBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16U1.Tab

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl hPl wordGF toK_wordGF cubeTab cubeTab_getD)
open ZK60.Exec.Block.Join.W16.Tab (tabSubS supW foldWd toK_foldWd)
open ZK60.Exec.Block.Join.R13H (PubR)
open ZK60.Exec.Block.Join.R13H.Pub (pubsR13 pubsR13_rest pubR_of gateLS)
open ZK60.Exec.Block.Join.W16U1
open ZK60.Exec.Block.DefW16
open ZK60.Circuit (gP GF tagW tagExp tagAct)
open ZK60.Layout

/-! ## 1. The code's table tuples at `export_u1` (`16` tables: `u8`, `exp`, `act`, `13` range) -/

/-- **The code's table tuple** of `SC_TAB`'s table `k < 16` at position `i < 2^14` for `export_u1`
(`c0`): `k = 0` bytes, `k = 1` exp, `k = 2` ACT, `k = 3 + j` range sub-plane `j < 13`. -/
def tabTupEU1 (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG k i : ℕ) : Tup GF :=
  if k = 0 then ⟨((i % 256 : ℕ) : GF), ((tagW 8 : ℕ) : GF), 0, 0⟩
  else if k = 1 then ⟨((i % 256 : ℕ) : GF), ((tagExp : ℕ) : GF), ((exp ((i % 256 : ℕ) : ℤ) : ℤ) : GF), 0⟩
  else if k = 2 then
    (if i < nG * 4096 then
      ⟨((i % 4096 : ℕ) : GF), ((tagAct : ℕ) : GF), ((act (i / 4096) ((i % 4096 : ℕ) : ℤ) : ℤ) : GF),
        ((i / 4096 : ℕ) : GF)⟩
    else ⟨((2048 : ℕ) : GF), ((tagAct : ℕ) : GF), ((act 0 ((2048 : ℕ) : ℤ) : ℤ) : GF), ((0 : ℕ) : GF)⟩)
  else
    ⟨(((tabSubS c0).getD (k - 3) 0 * 2 ^ 14 + i % supW ((subW c0).getD (k - 3) 0) : ℕ) : GF),
      ((tagW ((subW c0).getD (k - 3) 0) : ℕ) : GF), 0, 0⟩

/-- The `export_u1` table tuple at a block's public data. -/
def tabTupU1 {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG k i : ℕ) : Tup GF :=
  tabTupEU1 Pb.exp Pb.act nG k i

/-! ## 2. The gates at `export_u1` (`gateLU1`, `tabNarrowU1`, `gateTabU1`) -/

/-- **`supp(Dom::L)` at `export_u1`**: `x / 128 < 9` (`2^lt = 2^7 = 128` tokens, `9` limb rows). -/
def gateLU1 (b : Fin 14 → Bool) : GF := gateLS shU1 b

/-- The narrow range sub-planes at `export_u1` (`[0, 1, 2, 3, 4, 5, 6]`, widths `3, 4, 5, 6, 7, 12, 13`). -/
def tabNarrowU1 : List ℕ :=
  (List.range (nRange c0)).filter fun j =>
    !(ZK60.Exec.Slot.Build.Lay.fullW ((subW c0).getD j 0) c0.logCols)

theorem tabNarrowU1_eq : tabNarrowU1 = [0, 1, 2, 3, 4, 5, 6] := by decide

/-- **`SC_TAB`'s gate `g < 9`** at `export_u1`: `0` `supp(Dom::Tab)` (`x < 256`), `1` ACT support
(`x < nG·4096`), `2 + q` (`q < 7`) narrow range sub-plane `q`'s support (`x < 2^w`). -/
def gateTabU1 (nG g : ℕ) (b : Fin 14 → Bool) : GF :=
  if g = 0 then (if msbIndex 14 b < 256 then 1 else 0)
  else if g = 1 then (if msbIndex 14 b < nG * 4096 then 1 else 0)
  else (if msbIndex 14 b < supW ((subW c0).getD (tabNarrowU1.getD (g - 2) 0) 0) then 1 else 0)

/-! ## 3. The concrete public tables `restU1` and `pubsU1` -/

/-- **The lookup side's public tables at `export_u1`**: `SC_LZC`'s `supp(Dom::L)` (slot 3),
`SC_TAB`'s 16 value columns and 9 gates (slot 19), and `SC_ZS`'s all-ones table (slot 20). -/
def restEU1 (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) : PubTabs := fun s hist _ i =>
  if s = 3 then (if i = 0 then cubeTab 14 gateLU1 else [])
  else if s = 19 then
    (if i < 16 then (List.range (2 ^ 14)).map (fun idx => foldWd hist.beta hist.gamma (tabTupEU1 exp act nG i idx))
      else if i < 25 then cubeTab 14 (gateTabU1 nG (i - 16)) else [])
  else if s = 20 then (if i = 0 then cubeTab 14 (fun _ => 1) else [])
  else []

/-- The lookup side's public tables at a block's public data. -/
def restU1 {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ) : PubTabs :=
  restEU1 Pb.exp Pb.act nG

/-- **Every public table the W16R2 Shieldstral (`export_u1`) block program reads**, built from `Pb`,
`Lay`, `B`, and `nG` (reusing `Pub.pubsR13 c0`). -/
def pubsU1 {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay) (nG : ℕ) : PubTabs :=
  pubsR13 c0 Pb Lay B (restU1 Pb nG)

section Rest

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay) (nG : ℕ)

include hU in
/-- **The concrete `export_u1` public tables satisfy `PubR U c0`.** -/
theorem pubR_of_u1 : PubR U c0 (pubsU1 Pb Lay B nG) Pb Lay B :=
  pubR_of c0 Pb Lay B U hU (restU1 Pb nG)

/-- The concrete public tables at the lookup side's slots `3, 19, 20` are `restU1`'s. -/
theorem pubsU1_rest (s : ℕ) (hs : s = 3 ∨ s = 19 ∨ s = 20) (hist : Hist) (dr : List Fp2) (i : ℕ) :
    pubsU1 Pb Lay B nG s hist dr i = restU1 Pb nG s hist dr i :=
  pubsR13_rest c0 Pb Lay B (restU1 Pb nG) s hs hist dr i

/-- `SC_LZC`'s gate, read in the field. -/
theorem rest3U1_getD (hist : Hist) (dr : List Fp2) (b : Fin 14 → Bool) :
    ((restU1 Pb nG 3 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gateLU1 b) := by
  show ((cubeTab 14 gateLU1).getD (msbIndex 14 b) Fp2.zero).toK U = _
  rw [cubeTab_getD, toK_wordGF]

/-- `SC_ZS`'s all-ones table, read in the field. -/
theorem rest20U1_getD (hist : Hist) (dr : List Fp2) (b : Fin 14 → Bool) :
    ((restU1 Pb nG 20 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = 1 := by
  show ((cubeTab 14 (fun _ => (1 : GF))).getD (msbIndex 14 b) Fp2.zero).toK U = _
  rw [cubeTab_getD, toK_wordGF, map_one]

include hU in
/-- **`SC_TAB`'s value column `k < 16`, read in the field.** -/
theorem rest19U1_getD (hist : Hist) (dr : List Fp2) (k : ℕ) (hk : k < 16) (b : Fin 14 → Bool) :
    ((restU1 Pb nG 19 hist dr k).getD (msbIndex 14 b) Fp2.zero).toK U
      = fold (hist.beta.toK U) (hist.gamma.toK U) (tupK (tabTupU1 Pb nG k (msbIndex 14 b))) := by
  show ((if k < 16 then (List.range (2 ^ 14)).map (fun idx => foldWd hist.beta hist.gamma (tabTupU1 Pb nG k idx))
      else if k < 25 then cubeTab 14 (gateTabU1 nG (k - 16)) else []).getD (msbIndex 14 b) Fp2.zero).toK U = _
  rw [ite_eq_left hk, List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range (msbIndex_lt 14 b)]
  simp only [Option.map_some, Option.getD_some]
  exact toK_foldWd U hU _ _ _

/-- **`SC_TAB`'s gate `i - 16` (`16 ≤ i < 25`), read in the field.** -/
theorem rest19U1_gate_getD (hist : Hist) (dr : List Fp2) (i : ℕ) (h1 : 16 ≤ i) (h2 : i < 25) (b : Fin 14 → Bool) :
    ((restU1 Pb nG 19 hist dr i).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gateTabU1 nG (i - 16) b) := by
  show ((if i < 16 then (List.range (2 ^ 14)).map (fun idx => foldWd hist.beta hist.gamma (tabTupU1 Pb nG i idx))
      else if i < 25 then cubeTab 14 (gateTabU1 nG (i - 16)) else []).getD (msbIndex 14 b) Fp2.zero).toK U = _
  rw [ite_eq_right (by omega), ite_eq_left h2, cubeTab_getD, toK_wordGF]

end Rest

/-! ## 4. `SC_TAB`'s certified polynomial at `export_u1` -/

section Poly

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- `SC_TAB`'s helper `k < 16` (`H` plane `27 + k`: `fh c0 8 = 27`). -/
noncomputable def helpTabU1 (P : BlockParams) (D : CmData K P) (k : ℕ) (b : Fin 14 → Bool) : K :=
  hPl U P D (hOffU1 (27 + k)).1 (hOffU1 (27 + k)).2 14 b

/-- `SC_TAB`'s multiplicity `k < 16` (`A` plane `56 + k`: `idsW.t0 = 56`). -/
noncomputable def multTabU1 (P : BlockParams) (D : CmData K P) (k : ℕ) (b : Fin 14 → Bool) : K :=
  aPl U P D (offU1 (56 + k)) 14 b

/-- **`SC_TAB`'s table relation `k < 16`** at a cube point, read at `bga = (β, γ, α)`:
`h_k·(α − fold(T_k)) − m_k`. -/
noncomputable def cTabU1 (P : BlockParams) (D : CmData K P) {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (nG : ℕ) (bga : Fp2 × Fp2 × Fp2) (k : Fin 16) (b : Fin 14 → Bool) : K :=
  helpTabU1 U P D k b * (bga.2.2.toK U - fold (bga.1.toK U) (bga.2.1.toK U) (tupK (tabTupU1 Pb nG k (msbIndex 14 b))))
    - multTabU1 U P D k b

/-- The pad plane `j < 20`: its gate, whether it is a helper (else a multiplicity), and its table,
in `tab_w16`'s order: `m₀ m₁ h₀ h₁` under `supp(Tab)`, `m₂, h₂` under ACT support, then
`m_{3+q}, h_{3+q}` under narrow family `q < 7`. -/
def tabPadIxU1 (j : ℕ) : ℕ × Bool × ℕ :=
  if j < 4 then (0, decide (2 ≤ j), j % 2)
  else if j < 6 then (1, decide (j = 5), 2)
  else (2 + (j - 6) / 2, decide ((j - 6) % 2 = 1), 3 + tabNarrowU1.getD ((j - 6) / 2) 0)

/-- **`SC_TAB`'s pad plane `j < 20`**: `(1 − gate)·plane`. -/
noncomputable def wTabU1 (P : BlockParams) (D : CmData K P) (nG : ℕ) (j : Fin 20) (b : Fin 14 → Bool) : K :=
  (1 - algebraMap GF K (gateTabU1 nG (tabPadIxU1 j).1 b))
    * (if (tabPadIxU1 j).2.1 then helpTabU1 U P D (tabPadIxU1 j).2.2 b else multTabU1 U P D (tabPadIxU1 j).2.2 b)

/-- A draw vector of `SC_TAB` at `export_u1` (`τ` 0–13, `μ` 14–29, `μ_pad` 30, `ζ` 31). -/
def secTabU1 (ω : (K × K) × (Fin 16 → K)) (τ : Fin 14 → K) : Fin 32 → K :=
  fun i => if h : (i : ℕ) < 14 then τ ⟨i, h⟩ else if h2 : (i : ℕ) < 30 then ω.2 ⟨(i : ℕ) - 14, by omega⟩
    else if (i : ℕ) = 30 then ω.1.2 else ω.1.1

variable [Fintype K] [DecidableEq K] (hcard : 78 < Fintype.card K)

include hcard in
/-- **`SC_TAB`'s certified polynomial at `export_u1`** (`SlotPoly.zc` on `16` table relations and
`20` pad planes over `32` draws; degree `22`). -/
noncomputable def spTabU1 (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws) (D : CmData K P)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ) (bga : Fp2 × Fp2 × Fp2) :
    SlotPoly K (P.draws 19) :=
  SlotPoly.cast (by rw [hdr]; decide)
    (SlotPoly.zc (n := 14) (m := 20) (D := 32) (nc := 16) (cTabU1 U P D Pb nG bga) (wTabU1 U P D nG)
      (fun x => x 31) (fun x => x 30) (fun k => ⟨14 + (k : ℕ), by omega⟩) (fun i => Fin.castLE (by norm_num) i)
      (ZK60.Sound.SlotW16.indDeg_coord 31) (ZK60.Sound.SlotW16.indDeg_coord 30)
      (Fin.castLE_injective (by norm_num : 14 ≤ 32)) (by omega)
      (fun ω τ _ => ⟨secTabU1 ω τ, by simp [secTabU1], funext fun k => by
          unfold secTabU1
          have h1 : ¬ (14 + (k : ℕ) < 14) := by omega
          have h2 : 14 + (k : ℕ) < 30 := by omega
          simp only [h1, h2, ↓reduceDIte]
          exact congrArg ω.2 (Fin.ext (by simp)),
        funext fun i => by simp [secTabU1]⟩))

theorem spTabU1_dg (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws) (D : CmData K P)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ) (bga : Fp2 × Fp2 × Fp2) :
    (spTabU1 U hcard P hdr D Pb nG bga).dg = 22 := rfl

theorem spTabU1_Gd (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws) (D : CmData K P)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ) (bga : Fp2 × Fp2 × Fp2) :
    (spTabU1 U hcard P hdr D Pb nG bga).Gd
      = ((∀ k b, cTabU1 U P D Pb nG bga k b = 0) ∧ ∀ j b, wTabU1 U P D nG j b = 0) := rfl

end Poly

end ZK60.Exec.Block.Join.W16U1.Tab
