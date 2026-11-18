/-
D63 lane L63 (2026-11-18), part 53: **the stage planes are base-field values, so the `K`-valued IN-C data IS the
embedded projected data** (closes the question of `RunStgShieldLuK.lean`: `shd_ΛI` needs no change).

The extraction reads committed words as `algebraMap GF K` of Goldilocks words (`UxC`), and lane L41 proved that the
decoded rows of an embedded base matrix are embedded base values within the unique-decoding radius
(`decodeRows_base`), and that a plane with base coefficients of a base matrix is a base value (`planeZ_base`). So `piB`
loses nothing on the stage planes:

* **`stgIOX_base`**: every entry of the matrix a stage reads at a view (`stgIOX`) is a base value, at any geometry
  `(lc, h, Q, e)` with `lc, h ≤ 32` and `2e < 2^h − (2^lc + Q − 1)`;
* **`stgPlK_eq_alg`**: the unprojected plane is `algebraMap` of the projected one (`stgPlB`);
* `ogStage_radius`, `bin_radius`: stage IN-C's `A_in` geometry `(12, 14, 256, 6016)` (`12,032 < 12,033`, by one) and
  `B_in`'s `(14, 16, 256, 24448)` (`48,896 < 48,897`, by one) are within the radius;
* **`shdIncDataK_qTup`**, **`shdIncDataK_tTup`**, **`shdIncDataK_m`**: the `K`-valued data's query and table tuples and
  multiplicities are the projected data's under `algebraMap`;
* **`inLogUp_K_iff`**: `InLogUp (RingHom.id K) (shdIncDataK …) ω H ↔ InLogUp (algebraMap GF K) (shdIncData …) ω H`;
* **`stgLkInK_iff`**, **`shdLuInAt_of_K`**: the `K`-valued predicate is Antigravity's `stgLkIn` at `shdIncData`, and
  `ShdLuInAtK` at `shdIncDataK` gives `ShdLuInAt` at `shdIncData` (the statement `hLI_stg` needs, unchanged).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldLuK
import ZK60Formal.BlockJoinGF

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.StageX
open Code
open ZK60.Exec.StageV (IncPub incLay incA_TOK incA_MULT tagEmb)
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)

section Base

variable {K : Type} [Field K] [Algebra GF K] {Lq : ℕ}

/-- **Every entry of the matrix a stage reads at a view is a base value** (within the unique-decoding radius). -/
theorem stgIOX_base (tag : MTag) (h64 : 64 ≤ Lq) (lc h Q e rows i : ℕ) (hlc : lc ≤ 32) (hh : h ≤ 32)
    (he : 2 * e < 2 ^ h - (2 ^ lc + Q - 1)) (v : StgVw Lq) (r : Fin rows) (t : Fin (2 ^ lc + Q)) :
    ∃ g : GF, stgIOX (K := K) tag h64 lc h Q e rows i v r t = algebraMap GF K g := by
  have hext : RowFormExt (lagForm (Nat.two_pow_pos lc) (rootFp_isPrimitiveRoot (k := lc) hlc)) (RWL (K := K) lc) := by
    rw [RWL_of_le lc hlc]
    exact lagForm_ext _ _
  unfold stgIOX UxC
  exact Exec.Block.Join.decodeRows_base (Exec.Block.Join.ptsB h) (Exec.Block.Join.ptsB_injective h hh) _ (RWL lc)
    hext (Nat.two_pow_pos lc) e he _ r t

/-- **The unprojected stage plane is the embedded projected one.** -/
theorem stgPlK_eq_alg (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (lc h Q e rows i off log : ℕ) (hlc : lc ≤ 32)
    (hh : h ≤ 32) (he : 2 * e < 2 ^ h - (2 ^ lc + Q - 1)) (v : StgVw Lq) (b : Fin log → Bool) :
    stgPlK U tag h64 lc h Q e rows i off log v b
      = algebraMap GF K (stgPlB U tag h64 lc h Q e rows i off log v b) := by
  have hmem : stgPlK U tag h64 lc h Q e rows i off log v b ∈ Exec.Block.Join.baseR K := by
    refine Exec.Block.Join.planeZ_base U lc rows Q _ (fun r t => ?_)
      (⟨.a, [(off, Fp2.one)], log, [], 0, 0⟩ : Block.Priv) (fun sc hsc => ?_) b
    · obtain ⟨g, hg⟩ := stgIOX_base (K := K) tag h64 lc h Q e rows i hlc hh he v r t
      exact ⟨g, hg.symm⟩
    · simp only [List.mem_singleton] at hsc
      subst hsc
      rw [Fp2.toK_one]
      exact (Exec.Block.Join.baseR K).one_mem
  obtain ⟨g, hg⟩ := hmem
  rw [stgPlB_eq_piB, ← hg, Exec.Block.Join.W16.piB_alg]

theorem ogStage_radius : 2 * ogStage.e < 2 ^ ogStage.h - (2 ^ ogStage.lc + ogStage.Q - 1) := by
  show 2 * 6016 < 2 ^ 14 - (2 ^ 12 + 256 - 1)
  norm_num

theorem bin_radius : 2 * 24448 < 2 ^ 16 - (2 ^ 14 + 256 - 1) := by norm_num

theorem ogStage_lc_le : ogStage.lc ≤ 32 := by show 12 ≤ 32; norm_num

theorem ogStage_h_le : ogStage.h ≤ 32 := by show 14 ≤ 32; norm_num

variable (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0) (I : IncPub)
  (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iB iA : ℕ) (v : StgVw Lq)

theorem shdIncDataK_tok (t : shieldS0.Tok) :
    (shdIncDataK U tag h64 P I Epad iB iA v).tok t
      = algebraMap GF K ((shdIncData U tag h64 P I Epad iB iA v).tok t) :=
  stgPlK_eq_alg U tag h64 _ _ _ _ _ _ _ _ ogStage_lc_le ogStage_h_le ogStage_radius v _

theorem shdIncDataK_X (t : shieldS0.Tok) (c : Fin 12 → Bool) :
    (shdIncDataK U tag h64 P I Epad iB iA v).X t c
      = algebraMap GF K ((shdIncData U tag h64 P I Epad iB iA v).X t c) :=
  stgPlK_eq_alg U tag h64 14 16 256 24448 38 iB 0 19 (by norm_num) (by norm_num) bin_radius v _

theorem shdIncDataK_m (j : Fin P.V) :
    (shdIncDataK U tag h64 P I Epad iB iA v).m j
      = algebraMap GF K ((shdIncData U tag h64 P I Epad iB iA v).m j) :=
  stgPlK_eq_alg U tag h64 _ _ _ _ _ _ _ _ ogStage_lc_le ogStage_h_le ogStage_radius v _

theorem shdIncDataK_qTup (r : Fin 12 → K) (t : shieldS0.Tok) :
    qTup (RingHom.id K) (shdIncDataK U tag h64 P I Epad iB iA v) r t
      = qTup (algebraMap GF K) (shdIncData U tag h64 P I Epad iB iA v) r t := by
  have hX : (fun b => (RingHom.id K) ((shdIncDataK U tag h64 P I Epad iB iA v).X t b))
      = (fun b => algebraMap GF K ((shdIncData U tag h64 P I Epad iB iA v).X t b)) := by
    funext b
    rw [RingHom.id_apply, shdIncDataK_X]
  unfold qTup
  rw [hX, RingHom.id_apply, shdIncDataK_tok]
  rfl

theorem shdIncDataK_tTup (r : Fin 12 → K) (j : Fin P.V) :
    tTup (RingHom.id K) (shdIncDataK U tag h64 P I Epad iB iA v) r j
      = tTup (algebraMap GF K) (shdIncData U tag h64 P I Epad iB iA v) r j :=
  rfl

/-- **The `K`-valued LogUp relation is the projected one.** -/
theorem inLogUp_K_iff [DecidableEq K] (ω : InChal K 12) (H : Helpers shieldS0.Tok Empty (Fin P.V) K) :
    InLogUp (RingHom.id K) (shdIncDataK U tag h64 P I Epad iB iA v) ω H
      ↔ InLogUp (algebraMap GF K) (shdIncData U tag h64 P I Epad iB iA v) ω H := by
  have hA : (fun l => fold ω.1.1.1 ω.1.1.2 (inA (RingHom.id K) (shdIncDataK U tag h64 P I Epad iB iA v) ω.2 l))
      = (fun l => fold ω.1.1.1 ω.1.1.2 (inA (algebraMap GF K) (shdIncData U tag h64 P I Epad iB iA v) ω.2 l)) := by
    funext l
    rcases l with t | e | e
    · show fold _ _ (qTup _ _ _ t) = fold _ _ (qTup _ _ _ t)
      rw [shdIncDataK_qTup]
    · exact e.elim
    · exact e.elim
  have hm : (fun j => (RingHom.id K) ((shdIncDataK U tag h64 P I Epad iB iA v).m j))
      = (fun j => algebraMap GF K ((shdIncData U tag h64 P I Epad iB iA v).m j)) := by
    funext j
    rw [RingHom.id_apply, shdIncDataK_m]
  unfold InLogUp
  rw [hA, hm]
  rfl

/-- **The `K`-valued predicate is Antigravity's `stgLkIn` at `shdIncData`** (the cleared polynomials agree). -/
theorem stgLkInK_iff (τ : List (List UInt8 × K)) :
    stgLkInG (RingHom.id K) (shdIncDataK U tag h64 P I Epad iB iA) v τ
      ↔ stgLkIn (K := K) (shdIncData U tag h64 P I Epad iB iA) v τ := by
  have hpoly : incClearedPolyG (RingHom.id K) (shdIncDataK U tag h64 P I Epad iB iA v)
      = incClearedPoly (K := K) (shdIncData U tag h64 P I Epad iB iA v) := by
    funext y
    rw [incClearedPoly_eq_G]
    unfold incClearedPolyG
    have hq : (fun t => fold (y 0) (y 1)
          (qTup (RingHom.id K) (shdIncDataK U tag h64 P I Epad iB iA v) (fun c => y ⟨3 + c.val, by omega⟩) t))
        = (fun t => fold (y 0) (y 1)
          (qTup (algebraMap GF K) (shdIncData U tag h64 P I Epad iB iA v) (fun c => y ⟨3 + c.val, by omega⟩) t)) := by
      funext t
      rw [shdIncDataK_qTup]
    have hm : (fun j => (RingHom.id K) ((shdIncDataK U tag h64 P I Epad iB iA v).m j))
        = (fun j => algebraMap GF K ((shdIncData U tag h64 P I Epad iB iA v).m j)) := by
      funext j
      rw [RingHom.id_apply, shdIncDataK_m]
    rw [hq, hm]
    rfl
  unfold stgLkInG stgLkIn
  rw [hpoly]

end Base

section Need

variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K] {Lq : ℕ}

/-- **`ShdLuInAtK` at the `K`-valued data gives `ShdLuInAt` at `shdIncData`**, the exact statement `hLI_stg` needs at
`shd_ΛI` (unchanged). -/
theorem shdLuInAt_of_K (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0) (I : IncPub)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iB iA : ℕ) (key : Option Dig) (domain : List UInt8)
    (Pof : List Fp2 → Block.BlockParams) (hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB Lq → Option (List UInt8)) (G : QB Lq → Dig) (Lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (h : ShdLuInAtK U key domain Pof hdrLen bgaOf absOf (shdIncDataK U tag h64 P I Epad iB iA) G Lg τ) :
    ShdLuInAt U key domain Pof hdrLen bgaOf absOf (shdIncData U tag h64 P I Epad iB iA) G Lg τ := by
  intro hdr core ch rs hrd
  obtain ⟨hl, H, hH⟩ := h hdr core ch rs hrd
  exact ⟨hl, H, (inLogUp_K_iff U tag h64 P I Epad iB iA _ _ H).mp hH⟩

end Need

end ZK60.ProtocolClassify
