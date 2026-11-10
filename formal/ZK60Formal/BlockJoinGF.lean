/-
D63 lane L41 (2026-11-10), part 1: **the decoded rows of a committed matrix are base-field values** (finding L41-1).

The block's committed matrices `A` and `H` are matrices of Goldilocks words: L22's extraction `UxC` reads each entry
as `algebraMap GF K` of a base-field value. The extraction then DECODES each row in the extension field `K`
(`decodeRows` over the `K`-encoder `encG h Q`). The block's relations (`W16Rels`, `R13Rels`) and its witness
(`W16Data`) are over `GF`; lane L36's `W16Spec` (the tables are `algebraMap` of relation tables) and its `hcov` (the
lookups are `tupK` of base tuples) can only be met if the decoded entries are base-field values. This file proves
that they are, for every regular opening whose radius is the unique-decoding radius (`2e < d`):

* **`decodeRows_base`** (generic): for a `K`-encoder that is a base encoder with its scalars extended (`RowFormExt`)
  at base points, of minimum distance `d = N − (n + Q − 1)` with `2e < d`, every entry of the decoded rows of an
  embedded base matrix is an embedded base value. (Close: the closest codewords are unique, and the projection of
  each is a base codeword agreeing with it on the agreement set, so it IS that codeword; far: the decoded rows are
  `0`.)
* **`decode_encG_base`**: the same at the code's encoder `encG h Q` (the coset `7·G_{2^h}`, the interpolant rows on
  `G_{2^14}`);
* **`xAof_base`**, **`xHof_base`**: at W16R2's geometry `(h, Q, e) = (15, 280, 8052)` (`d = 16,105 > 2·8,052`), every
  entry of the `A` and `H` matrices L31's `csXof` reads is `algebraMap GF K` of a base value; **`xAof_base_r13`**,
  **`xHof_base_r13`**: the same at R13's geometry `(16, 280, e)` for every `e` with `2e < 48,873`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockDefineFinal
import ZK60Formal.BindingUCode
import ZK60Formal.OpenKnowChain

set_option autoImplicit false

namespace ZK60.Exec.Block.Join

open ZK60.Sound Code
open ZK60.Exec
open ZK60.Circuit (gP GF)

/-! ## The generic fact -/

section Generic

variable {F K : Type} [Field F] [Field K] [Algebra F K]

/-- **Decoded rows of an embedded base matrix are embedded base values** (at the unique-decoding radius). -/
theorem decodeRows_base {κ : Type} {n Q N : ℕ} (pts : Fin N → F) (hpts : Function.Injective pts)
    (R : RowForm F n) (RK : RowForm K n) (hext : RowFormExt R RK) (hn : 0 < n) (e : ℕ)
    (he : 2 * e < N - (n + Q - 1)) (U : κ → Fin N → F) (i : κ) (t : Fin (n + Q)) :
    ∃ g : F, decodeRows (encLin (Q := Q) (fun j => algebraMap F K (pts j)) RK) e
      (fun i j => algebraMap F K (U i j)) i t = algebraMap F K g := by
  classical
  set encK := encLin (Q := Q) (fun j => algebraMap F K (pts j)) RK with hencK
  have hptsK : Function.Injective (fun j => algebraMap F K (pts j)) :=
    fun a b hab => hpts ((algebraMap F K).injective hab)
  have hinjK : Function.Injective encK := by
    by_cases hN : n + Q ≤ N
    · exact encLin_injective hptsK RK hn hN
    · exfalso
      omega
  have hmd : MinDist (LinearMap.range encK) (N - (n + Q - 1)) := encLin_minDist _ hptsK RK hn
  unfold decodeRows
  by_cases hc : Close (LinearMap.range encK) e (fun i j => algebraMap F K (U i j))
  · obtain ⟨hV, S, hS, hUV⟩ := closeTable_spec hc
    set V := closeTable (LinearMap.range encK) e (fun i j => algebraMap F K (U i j)) with hVdef
    obtain ⟨c', ⟨v, rfl⟩, hcc⟩ := encLin_base_fact pts R RK hext (V i) (hV i) S
      (fun j hj => ⟨U i j, (hUV j hj i).symm⟩)
    have hW : encK (fun t => algebraMap F K (v t)) = V i := by
      refine hmd.eq_of_agree (LinearMap.mem_range_self _ _) (hV i) (S := S) (by omega) (fun j hj => ?_)
      rw [hencK, encLin_map_base pts R RK hext v j]
      exact (hcc j hj).symm
    refine ⟨v t, ?_⟩
    show decodeWord encK (V i) t = _
    rw [← hW, decodeWord_enc encK hinjK]
  · have h0 : closeTable (LinearMap.range encK) e (fun i j => algebraMap F K (U i j)) = 0 := by
      unfold closeTable
      simp only [hc, ↓reduceDIte]
    refine ⟨0, ?_⟩
    rw [h0]
    have : decodeWord encK (encK 0) = 0 := decodeWord_enc encK hinjK 0
    rw [map_zero] at this
    show decodeWord encK 0 t = _
    rw [this, map_zero]
    rfl

end Generic

/-! ## At the code's encoder -/

section Code

variable {K : Type} [Field K] [Algebra GF K]

/-- The base points of the code's coset `7·G_{2^h}`. -/
def ptsB (h : ℕ) : Fin (2 ^ h) → GF := fun j => (cosetPt (rootFp h) j).toGF

theorem ptsB_injective (h : ℕ) (hh : h ≤ 32) : Function.Injective (ptsB h) := by
  intro a b hab
  have ha : (a : ℕ) < 2 ^ 64 := lt_of_lt_of_le a.isLt (Nat.pow_le_pow_right (by norm_num) (by omega))
  have hb : (b : ℕ) < 2 ^ 64 := lt_of_lt_of_le b.isLt (Nat.pow_le_pow_right (by norm_num) (by omega))
  have h' : (cosetPt (rootFp h) a).toGF = (cosetPt (rootFp h) b).toGF := hab
  rw [Link.cosetPt_toGF _ _ ha, Link.cosetPt_toGF _ _ hb] at h'
  have hω : IsPrimitiveRoot (rootFp h).toGF (2 ^ h) := rootFp_isPrimitiveRoot hh
  exact cosetPts_injective (N := 2 ^ h) seven_ne_zero_GF hω h'

/-- The base row form whose scalar extension is `Link.RW`: the interpolant on `G_{2^14}` over `GF`. -/
noncomputable def RWB : RowForm GF (2 ^ 14) :=
  lagForm (by norm_num) (rootFp_isPrimitiveRoot (k := 14) (by norm_num))

theorem RWB_ext : RowFormExt RWB (Link.RW (K := K)) :=
  lagForm_ext (by norm_num) (rootFp_isPrimitiveRoot (k := 14) (by norm_num))

/-- **The code's decoded rows of an embedded base matrix are embedded base values** at every regular geometry within
the unique-decoding radius. -/
theorem decode_encG_base {κ : Type} (h Q e : ℕ) (hh : h ≤ 32) (he : 2 * e < 2 ^ h - (2 ^ 14 + Q - 1))
    (U : κ → Fin (2 ^ h) → GF) (i : κ) (t : Fin (2 ^ 14 + Q)) :
    ∃ g : GF, decodeRows (Link.encG (K := K) h Q) e (fun i j => algebraMap GF K (U i j)) i t = algebraMap GF K g :=
  decodeRows_base (ptsB h) (ptsB_injective h hh) RWB (Link.RW (K := K)) RWB_ext (by norm_num) e he U i t

/-- **Every entry of the `A` matrix L31's `csXof` reads is a base value** (any geometry within the unique-decoding
radius). -/
theorem xAof_base (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (h Q e rA : ℕ) (hh : h ≤ 32)
    (he : 2 * e < 2 ^ h - (2 ^ 14 + Q - 1)) (cu : Cuts3 L) (rt : RootsO) (i : Fin rA) (t : Fin (2 ^ 14 + Q)) :
    ∃ g : GF, Link.xAof (K := K) tag L h64 h Q e rA cu rt i t = algebraMap GF K g := by
  unfold Link.xAof Link.UxC
  exact decode_encG_base h Q e hh he _ i t

/-- **Every entry of the `H` matrix L31's `csXof` reads is a base value.** -/
theorem xHof_base (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (h Q e rH : ℕ) (hh : h ≤ 32)
    (he : 2 * e < 2 ^ h - (2 ^ 14 + Q - 1)) (cu : Cuts3 L) (rt : RootsO) (i : Fin rH) (t : Fin (2 ^ 14 + Q)) :
    ∃ g : GF, Link.xHof (K := K) tag L h64 h Q e rH cu rt i t = algebraMap GF K g := by
  unfold Link.xHof Link.UxC
  exact decode_encG_base h Q e hh he _ i t

/-- W16R2's geometry `(15, 280, 8052)` is within the unique-decoding radius: `2·8,052 < 16,105`. -/
theorem w16r2_unique_radius : 2 * 8052 < 2 ^ 15 - (2 ^ 14 + 280 - 1) := by norm_num

/-- R13's geometry `(16, 280, e)` is within the unique-decoding radius for every `e ≤ 24,436`. -/
theorem r13_unique_radius (e : ℕ) (he : e ≤ 24436) : 2 * e < 2 ^ 16 - (2 ^ 14 + 280 - 1) := by
  norm_num
  omega

/-- **W16R2's `A` matrix entries are base values.** -/
theorem xAof_base_w16 (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (rA : ℕ) (cu : Cuts3 L) (rt : RootsO) (i : Fin rA)
    (t : Fin (2 ^ 14 + 280)) :
    ∃ g : GF, Link.xAof (K := K) tag L h64 15 280 8052 rA cu rt i t = algebraMap GF K g :=
  xAof_base tag L h64 15 280 8052 rA (by norm_num) w16r2_unique_radius cu rt i t

/-- **W16R2's `H` matrix entries are base values.** -/
theorem xHof_base_w16 (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (rH : ℕ) (cu : Cuts3 L) (rt : RootsO) (i : Fin rH)
    (t : Fin (2 ^ 14 + 280)) :
    ∃ g : GF, Link.xHof (K := K) tag L h64 15 280 8052 rH cu rt i t = algebraMap GF K g :=
  xHof_base tag L h64 15 280 8052 rH (by norm_num) w16r2_unique_radius cu rt i t

end Code

end ZK60.Exec.Block.Join
