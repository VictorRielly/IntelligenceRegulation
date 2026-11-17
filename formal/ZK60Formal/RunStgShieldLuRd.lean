/-
D63 lane L63 (2026-11-17), part 46: **the readers of the concrete stage LogUp predicates, and the exact statements the
LogUp premises still need** (for lane L67b's `RunStgShieldLu.lean`, not edited).

* `shdEpad P`: stage IN-C's table `E` (the padded embedding) at the MSB column layout of the `d_pad = 2^12` cube:
  channel `i < 3072` of row `v` at `msbBits 12 i`, `0` on the 1024 pad columns. `shdEpad_hE` is `in_inSat`'s hypothesis
  `hE` at the column map `col i := msbBits 12 i`; `shdEpad_pad` is `in_pad_cols`'s `hEpad`.
* `shdIncData_X`: `shd_ΛI`'s `B_in` reader is the lane's `bxUxV` (the matrix of part 1's closing opening, pinned in
  `hcsI` at `ipos = off 0 + 2`) at rows `38`, read as plane `(offset 0, log 19)` at `Fin.append (msbBits 7 t) c`:
  the same matrix by definition (`rfl`), only the presentation differs.
* **The exact missing statements for `hLI_stg`, `hLO_stg`** (`ShdLuInAt`, `ShdLuOutAt`): at every reading of the stage,
  the stage's real LogUp relation holds at the drawn challenges (`∃ H, InLogUp …` for IN-C, `∃ H, ByteLogUp …` for OUT-C,
  with the readers' data at the head's view). They are definitions here, NOT premises of any top theorem. What is
  proved is only that each gives the premise in its `StgLkAtV` form (`stgLkAtV_of_luIn` through
  `stgLkIn_of_inLogUp`; `stgLkAtV_of_luOut` through `stgLkOut_two`). No theorem in the tree proves them for an accepted
  run (no run-level file uses `InLogUp` or `ByteLogUp`): that is the run-level form of `inc_stage_sound`'s phase 2
  (`incCube`: the slots' conclusions give the helper relations) for IN-C, and of `outc_stage_sound`'s byte LogUp for
  OUT-C (HANDOFF_20261117_5.md).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldLu
import ZK60Formal.RunStgShieldIOPin

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.StageX
open ZK60.Exec.StageV (tagU8)
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)

/-! ## 1. Stage IN-C's table at the MSB column layout -/

/-- **Stage IN-C's padded embedding table** on the column cube `Fin 12 → Bool` (`d_pad = 4096`): the column with MSB
index `j < 3072` holds `E[v][j]`, the other `1024` columns `0`. -/
noncomputable def shdEpad (P : InPublic shieldS0) (v : Fin P.V) (b : Fin 12 → Bool) : GF :=
  if h : msbIndex 12 b < 3072 then ((P.emb v ⟨msbIndex 12 b, h⟩ : ℤ) : GF) else 0

/-- `in_inSat`'s `hE` at the column map `col i := msbBits 12 i`. -/
theorem shdEpad_hE (P : InPublic shieldS0) :
    ∀ (v : Fin P.V) (i : shieldS0.Wid), shdEpad P v (msbBits 12 i.val) = (P.emb v i : GF) := by
  intro v i
  have hi3 : i.val < 3072 := i.isLt
  have hi : i.val < 2 ^ 12 := by omega
  have e : msbIndex 12 (msbBits 12 i.val) = i.val := msbIndex_msbBits 12 i.val hi
  unfold shdEpad
  split_ifs with h
  · congr 2
    exact Fin.ext e
  · exact absurd (show msbIndex 12 (msbBits 12 i.val) < 3072 by rw [e]; exact hi3) h

/-- `in_pad_cols`'s `hEpad`: off the image of the column map the table is `0`. -/
theorem shdEpad_pad (P : InPublic shieldS0) :
    ∀ (v : Fin P.V) b, b ∉ Set.range (fun i : shieldS0.Wid => msbBits 12 i.val) → shdEpad P v b = 0 := by
  intro v b hb
  unfold shdEpad
  split_ifs with h
  · refine absurd ⟨⟨msbIndex 12 b, h⟩, ?_⟩ hb
    exact msbBits_msbIndex 12 b
  · rfl

/-! ## 2. `shd_ΛI`'s `B_in` reader is the lane's `bxUxV` -/

/-- **`shd_ΛI`'s `B_in` reader is the pinned `B_in` matrix** (`bxUxV` at rows `38`, the matrix `hcsI` pins at
`ipos = off 0 + 2`), read as the plane `(offset 0, log 19)` at the bits `Fin.append (msbBits 7 t) c`. -/
theorem shdIncData_X {K : Type} [Field K] [Algebra GF K] {Lq : ℕ}
    (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0) (I : StageV.IncPub)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iB iA : ℕ) (v : StgVw Lq) (t : shieldS0.Tok) (c : Fin 12 → Bool) :
    (shdIncData U tag h64 P I Epad iB iA v).X t c
      = Exec.Block.Join.W16.piB K
          (Exec.Block.Join.planeZ U 14 38 256 (bxUxV tag Lq h64 38 iB v)
            ⟨.a, [(0, Fp2.one)], 19, [], 0, 0⟩ (Fin.append (msbBits 7 t.val) c)) :=
  rfl

/-! ## 3. The exact statements `hLI_stg` and `hLO_stg` still need, and the bridges from them -/

section Need

variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K] {Lq : ℕ}

/-- **What `hLI_stg` needs at a run, stated exactly** (not assumed anywhere): at every reading of stage IN-C (`m = 15`)
the stage's LogUp relation holds at the drawn challenges `((β, γ), α), r_emb` for some helpers, of the data `Dof` reads
at the head's view. -/
def ShdLuInAt {V : ℕ} (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams)
    (hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB Lq → Option (List UInt8))
    (Dof : StgVw Lq → InData GF shieldS0.Tok (Fin V) 12)
    (G : QB Lq → Dig) (Lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain Lq Pof 15 hdrLen bgaOf G τ hdr core ch rs →
    ch.length = 15 ∧ ∃ H, InLogUp (algebraMap GF K)
      (Dof (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core))))
      ((((ch.getD 0 Fp2.zero).toK U, (ch.getD 1 Fp2.zero).toK U), (ch.getD 2 Fp2.zero).toK U),
        fun c : Fin 12 => (ch.getD (3 + c.val) Fp2.zero).toK U) H

/-- **`hLI_stg`'s conclusion from `ShdLuInAt`** (bridge 1, `stgLkIn_of_inLogUp`). -/
theorem stgLkAtV_of_luIn {V : ℕ} (U : K) (key : Option Dig) (domain : List UInt8)
    (Pof : List Fp2 → Block.BlockParams) (hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB Lq → Option (List UInt8)) (Dof : StgVw Lq → InData GF shieldS0.Tok (Fin V) 12)
    (G : QB Lq → Dig) (Lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (h : ShdLuInAt U key domain Pof hdrLen bgaOf absOf Dof G Lg τ) :
    StgLkAtV U key domain Pof 15 hdrLen bgaOf absOf (stgLkIn (K := K) Dof) G Lg τ := by
  intro hdr core ch rs hrd
  obtain ⟨hl, hlu⟩ := h hdr core ch rs hrd
  exact stgLkIn_of_inLogUp U Dof _ ch hl hlu

/-- **What `hLO_stg` needs at a run, stated exactly** (not assumed anywhere): at every reading of stage OUT-C (`m = 2`)
the byte LogUp relation holds at the drawn challenges `(γ, α)` for some helpers, of the planes the readers give at the
head's view. -/
def ShdLuOutAt (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams)
    (hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB Lq → Option (List UInt8))
    (limbOf : StgVw Lq → (Fin 12 → Bool) → GF)
    (plOf : StgVw Lq → Fin 12 → (Fin 12 → Bool) → GF)
    (multOf : StgVw Lq → Fin 256 → K)
    (G : QB Lq → Dig) (Lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain Lq Pof 2 hdrLen bgaOf G τ hdr core ch rs →
    ch.length = 2 ∧
    let v := stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core))
    ∃ H, ByteLogUp (algebraMap GF K) (limbOf v)
      (fun kc : Fin 6 × (Fin 12 → Bool) => dLookB (plOf v) (pIdx1 kc.1) kc.2)
      (fun kc : Fin 6 × (Fin 12 → Bool) => dLookB (plOf v) (pIdx2 kc.1) kc.2)
      (multOf v) (fun g => g * algebraMap GF K (tagU8 : GF))
      ((ch.getD 0 Fp2.zero).toK U, (ch.getD 1 Fp2.zero).toK U) H

/-- **`hLO_stg`'s conclusion from `ShdLuOutAt`** (bridge, `stgLkOut_two`). -/
theorem stgLkAtV_of_luOut (U : K) (key : Option Dig) (domain : List UInt8)
    (Pof : List Fp2 → Block.BlockParams) (hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB Lq → Option (List UInt8))
    (limbOf : StgVw Lq → (Fin 12 → Bool) → GF)
    (plOf : StgVw Lq → Fin 12 → (Fin 12 → Bool) → GF)
    (multOf : StgVw Lq → Fin 256 → K)
    (G : QB Lq → Dig) (Lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (h : ShdLuOutAt U key domain Pof hdrLen bgaOf absOf limbOf plOf multOf G Lg τ) :
    StgLkAtV U key domain Pof 2 hdrLen bgaOf absOf (stgLkOut limbOf plOf multOf) G Lg τ := by
  intro hdr core ch rs hrd
  obtain ⟨hl, hlu⟩ := h hdr core ch rs hrd
  exact (stgLkOut_two U limbOf plOf multOf _ ch hl).mpr hlu

end Need

end ZK60.ProtocolClassify
