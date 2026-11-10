/-
D63 lane L47 (2026-11-10), part R1: **`SC_TAB`'s tables and certified polynomial at R13** (deliverable 4, item 1 at
the R13 rung and at every layer of the app's Shieldstral T128 R13 block), beside the W16R2 ones (`BlockTabBase.lean`).

R13's `SC_TAB` (`argument_accuracy.rs::tab`, 416-444; the code has no IR for it, finding L17-9; L44's `progR13`
transcribes it as L13's `tabIr`) has three tables only: the bytes, the exp table and the ACT table (R13 checks every
limb with a byte lookup; there is no range sub-plane), with the pad groups `(supp(Tab), [m₀, m₁])`,
`(supp(Tab), [h₀, h₁])`, `(ACT support, [m₂])`, `(ACT support, [h₂])`. The tables' tuples are W16R2's first three
(`tabTupE`, `k < 3`), so their fold and the gates are W16R2's (`foldWd`, `gateTabW`).

* **`restR13 exp act nG`**: the lookup side's public tables at R13 (slot 19's three value columns and two gates, slot
  20's all-ones table); `rest19R13_getD`, `rest19R13_gate_getD`, `rest20R13_getD`;
* `helpTabR c`, `multTabR c` (`H` plane `fh 8 + k`, `A` plane `t0 + k` of the configuration `c`), **`cTabR`** (the three
  table relations), **`wTabR`** (the six pad planes), **`spTabR`**: L23's `SlotPoly.zc` on them (degree `8`);
  `spTabR_dg`, `spTabR_Gd`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockTabBase
import ZK60Formal.BlockR13ProgOk

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13T

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.Join.W16.Tab
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Circuit (gP GF)

/-! ## The public tables -/

/-- **R13's lookup-side public tables**: `SC_TAB`'s three folded value columns (bytes, exp, ACT) and two gates
(`supp(Tab)`, the ACT support), `SC_ZS`'s all-ones table. -/
def restR13 (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) : PubTabs := fun s hist _ i =>
  if s = 19 then
    (if i < 3 then (List.range (2 ^ 14)).map (fun idx => foldWd hist.beta hist.gamma (tabTupE exp act nG i idx))
      else if i < 5 then cubeTab 14 (gateTabW nG (i - 3)) else [])
  else if s = 20 then (if i = 0 then cubeTab 14 (fun _ => 1) else [])
  else []

section Rest

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
variable (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ)

include hU in
/-- **R13's value column `k`, read in the field**: the fold of the table tuple at the history's `(β, γ)`. -/
theorem rest19R13_getD (hist : Hist) (dr : List Fp2) (k : ℕ) (hk : k < 3) (b : Fin 14 → Bool) :
    ((restR13 exp act nG 19 hist dr k).getD (msbIndex 14 b) Fp2.zero).toK U
      = fold (hist.beta.toK U) (hist.gamma.toK U) (tupK (tabTupE exp act nG k (msbIndex 14 b))) := by
  show ((if k < 3 then (List.range (2 ^ 14)).map (fun idx => foldWd hist.beta hist.gamma (tabTupE exp act nG k idx))
      else if k < 5 then cubeTab 14 (gateTabW nG (k - 3)) else []).getD (msbIndex 14 b) Fp2.zero).toK U = _
  rw [ite_eq_left hk, List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range (msbIndex_lt 14 b)]
  simp only [Option.map_some, Option.getD_some]
  exact toK_foldWd U hU _ _ _

/-- **R13's gate `i − 3`, read in the field.** -/
theorem rest19R13_gate_getD (hist : Hist) (dr : List Fp2) (i : ℕ) (h1 : 3 ≤ i) (h2 : i < 5) (b : Fin 14 → Bool) :
    ((restR13 exp act nG 19 hist dr i).getD (msbIndex 14 b) Fp2.zero).toK U
      = algebraMap GF K (gateTabW nG (i - 3) b) := by
  show ((if i < 3 then (List.range (2 ^ 14)).map (fun idx => foldWd hist.beta hist.gamma (tabTupE exp act nG i idx))
      else if i < 5 then cubeTab 14 (gateTabW nG (i - 3)) else []).getD (msbIndex 14 b) Fp2.zero).toK U = _
  rw [ite_eq_right (by omega), ite_eq_left h2, cubeTab_getD, toK_wordGF]

/-- `SC_ZS`'s all-ones table at R13, read in the field. -/
theorem rest20R13_getD (hist : Hist) (dr : List Fp2) (b : Fin 14 → Bool) :
    ((restR13 exp act nG 20 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = 1 := by
  show ((cubeTab 14 (fun _ => (1 : GF))).getD (msbIndex 14 b) Fp2.zero).toK U = _
  rw [cubeTab_getD, toK_wordGF, map_one]

end Rest

/-! ## The certified polynomial -/

section Poly

variable {K : Type} [Field K] [Algebra GF K] (U : K) (c : W16Cfg)

/-- R13's `SC_TAB` helper `k` (`H` plane `fh 8 + k` of the configuration). -/
noncomputable def helpTabR (P : BlockParams) (D : CmData K P) (k : ℕ) (b : Fin 14 → Bool) : K :=
  hPl U P D (DefR13.hOff c (DefR13.fh c 8 + k)).1 (DefR13.hOff c (DefR13.fh c 8 + k)).2 14 b

/-- R13's `SC_TAB` multiplicity `k` (`A` plane `t0 + k`: `MU8`, `MEXP`, `MACT`). -/
noncomputable def multTabR (P : BlockParams) (D : CmData K P) (k : ℕ) (b : Fin 14 → Bool) : K :=
  aPl U P D (DefR13.aOff c ((DefR13.ids c).t0 + k)) 14 b

/-- **R13's table relation `k`**, read at `bga = (β, γ, α)`: `h_k·(α − fold(T_k)) − m_k`. -/
noncomputable def cTabR (P : BlockParams) (D : CmData K P) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ)
    (bga : Fp2 × Fp2 × Fp2) (k : Fin 3) (b : Fin 14 → Bool) : K :=
  helpTabR U c P D k b * (bga.2.2.toK U - fold (bga.1.toK U) (bga.2.1.toK U) (tupK (tabTupE exp act nG k (msbIndex 14 b))))
    - multTabR U c P D k b

/-- **R13's pad plane `j < 6`**: `(1 − gate)·plane` (`m₀ m₁ h₀ h₁` under `supp(Tab)`, `m₂ h₂` under the ACT
support; W16R2's first six, `tabPadIx`). -/
noncomputable def wTabR (P : BlockParams) (D : CmData K P) (nG : ℕ) (j : Fin 6) (b : Fin 14 → Bool) : K :=
  (1 - algebraMap GF K (gateTabW nG (tabPadIx j).1 b))
    * (if (tabPadIx j).2.1 then helpTabR U c P D (tabPadIx j).2.2 b else multTabR U c P D (tabPadIx j).2.2 b)

/-- A draw vector of R13's `SC_TAB` (`τ` 0–13, `μ` 14–16, `μ_pad` 17, `ζ` 18). -/
def secTabR (ω : (K × K) × (Fin 3 → K)) (τ : Fin 14 → K) : Fin 19 → K :=
  fun i => if h : (i : ℕ) < 14 then τ ⟨i, h⟩ else if h2 : (i : ℕ) < 17 then ω.2 ⟨(i : ℕ) - 14, by omega⟩
    else if (i : ℕ) = 17 then ω.1.2 else ω.1.1

variable [Fintype K] [DecidableEq K] (hcard : 78 < Fintype.card K)

include hcard in
/-- **R13's `SC_TAB` certified polynomial** (L23's `SlotPoly.zc`): its start claim is that the three table relations
and the six pad planes vanish on the cube. -/
noncomputable def spTabR (P : BlockParams) (hd : P.draws 19 = 19) (D : CmData K P) (exp : ℤ → ℤ)
    (act : ℕ → ℤ → ℤ) (nG : ℕ) (bga : Fp2 × Fp2 × Fp2) : SlotPoly K (P.draws 19) :=
  SlotPoly.cast hd.symm
    (SlotPoly.zc (n := 14) (m := 6) (D := 19) (nc := 3) (cTabR U c P D exp act nG bga) (wTabR U c P D nG)
      (fun x => x 18) (fun x => x 17) (fun k => ⟨14 + (k : ℕ), by omega⟩) (fun i => Fin.castLE (by norm_num) i)
      (ZK60.Sound.SlotW16.indDeg_coord 18) (ZK60.Sound.SlotW16.indDeg_coord 17)
      (Fin.castLE_injective (by norm_num : 14 ≤ 19)) (by omega)
      (fun ω τ _ => ⟨secTabR ω τ, by simp [secTabR], funext fun k => by
          unfold secTabR
          have h1 : ¬ (14 + (k : ℕ) < 14) := by omega
          have h2 : 14 + (k : ℕ) < 17 := by omega
          simp only [h1, h2, ↓reduceDIte]
          exact congrArg ω.2 (Fin.ext (by simp)),
        funext fun i => by simp [secTabR]⟩))

theorem spTabR_dg (P : BlockParams) (hd : P.draws 19 = 19) (D : CmData K P) (exp : ℤ → ℤ)
    (act : ℕ → ℤ → ℤ) (nG : ℕ) (bga : Fp2 × Fp2 × Fp2) : (spTabR U c hcard P hd D exp act nG bga).dg = 8 := rfl

theorem spTabR_Gd (P : BlockParams) (hd : P.draws 19 = 19) (D : CmData K P) (exp : ℤ → ℤ)
    (act : ℕ → ℤ → ℤ) (nG : ℕ) (bga : Fp2 × Fp2 × Fp2) :
    (spTabR U c hcard P hd D exp act nG bga).Gd
      = ((∀ k b, cTabR U c P D exp act nG bga k b = 0) ∧ ∀ j b, wTabR U c P D nG j b = 0) := rfl

end Poly

end ZK60.Exec.Block.Join.R13T
