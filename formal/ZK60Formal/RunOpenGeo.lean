/-
D63 lane L48 (2026-11-10), part 1: **an opening's message width as a parameter** (finding L45-2, decision D77a).

Every regular opening of the run model (L34's `RtOpen`, L43's `RkGeo`, `rkOpen`, `RhOpW`, `rh_opB_alive`) fixed its
message width at `2^14`: the interpolant `RW` on `G_{2^14}`, the encoder `encG h Q` on `Fin (2^14 + Q)`, the claims'
groups at `log_cols 14`. That is the BLOCK geometry at R13. The code's only registered token-I/O tier opens the two
stages at `2^12` and the classifier's input commitment at `2^8` (`token_io.rs:190`). This file gives the width as a
parameter `lc`; the block geometry is the instance `lc = 14`:

* **`RWL`**: the row form at width `2^lc`, the interpolant on `G_{2^lc}` for `lc ≤ 32` (the field's two-adic range);
  `RWL_of_le`, **`RWL_14`** (`RWL 14 = RW`);
* **`encGL`**: the encoder at a geometry `(lc, h, Q)` (`2^lc` message columns, `Q` pads, `2^h` codeword symbols at the
  coset `7·G_{2^h}`); **`encGL_14`** (`encGL 14 h Q = encG h Q`), **`encGL_injective`**;
* `OGeo`: an opening's code geometry `(h, lc, Q, e, mI)` (codeword `2^h`, message `2^lc`, `Q` queries and pads,
  radius `e`, `mI` index squeezes); `OGeo.Ok`: its numeric side conditions (`h ≤ 16`, `Q > 0`, the unique-decoding
  radius `2e + 2^lc + Q ≤ 2^h`, the column round within `2^-126`);
* **`ogR13`**, **`ogR13_ok`**: the block geometry at R13, `(16, 14, 256, 24448, 64)`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.LinkW16GlueR13

set_option autoImplicit false

namespace ZK60.Exec.Link

open ZK60.Sound
open ZK60.Exec
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## The row form and the encoder at a width -/

section Width

variable {K : Type} [Field K] [Algebra GF K]

/-- **The row form at message width `2^lc`**: the interpolant on `G_{2^lc} = ⟨ω_{2^lc}⟩` (the code's inverse NTT on a
row, `rootFp lc` its root), for `lc ≤ 32`. Above `32` the field has no root of that order and no commitment of the code
is that wide; the coefficient form stands in so that the definition is total. -/
noncomputable def RWL (lc : ℕ) : RowForm K (2 ^ lc) :=
  if h : lc ≤ 32 then
    lagForm (Nat.two_pow_pos lc) ((rootFp_isPrimitiveRoot h).map_of_injective (algebraMap GF K).injective)
  else coefForm (Nat.two_pow_pos lc)

/-- At a width in the field's two-adic range the row form is the interpolant. -/
theorem RWL_of_le (lc : ℕ) (h : lc ≤ 32) :
    RWL (K := K) lc
      = lagForm (Nat.two_pow_pos lc) ((rootFp_isPrimitiveRoot h).map_of_injective (algebraMap GF K).injective) :=
  dite_eq_left h

/-- **The block geometry's row form is L28's `RW`.** -/
theorem RWL_14 : RWL (K := K) 14 = RW := RWL_of_le 14 (by norm_num)

/-- **The row encoder at a geometry `(lc, h, Q)`** (L10's `encLin`: `2^lc` message columns, `Q` pads, at the coset
`7·G_{2^h}`). -/
noncomputable def encGL (lc h Q : ℕ) : (Fin (2 ^ lc + Q) → K) →ₗ[K] (Fin (2 ^ h) → K) :=
  encLin (Q := Q) (ptsG h) (RWL lc)

/-- **At the block geometry it is L28's `encG`.** -/
theorem encGL_14 (h Q : ℕ) : encGL (K := K) 14 h Q = encG h Q := by
  unfold encGL encG
  rw [RWL_14]

/-- **The radius's side conditions**, for the code facts at any width (`n = 2^lc` message columns, `N = 2^h` symbols):
from `2e + (n + Q) ≤ N` and `Q > 0`, the radius is below half the minimum distance `N − (n + Q − 1)`, the correlated
agreement bound `2e + (n + Q − 1) + 1 ≤ N`, the encoder's length `n + Q ≤ N`, and `e + 1 ≤ N`. -/
theorem og_side {n Q N e : ℕ} (hQ : 0 < Q) (he : 2 * e + (n + Q) ≤ N) :
    2 * e < N - (n + Q - 1) ∧ 2 * e + (n + Q - 1) + 1 ≤ N ∧ n + Q ≤ N ∧ e + 1 ≤ N := by
  omega

/-- The encoder is injective when the code is at least as long as the clear vector (`2^lc + Q ≤ 2^h`, `h ≤ 32`). -/
theorem encGL_injective (lc h Q : ℕ) (hh : h ≤ 32) (hN : 2 ^ lc + Q ≤ 2 ^ h) :
    Function.Injective (encGL (K := K) lc h Q) :=
  encLin_injective (ptsG_injective h hh) (RWL lc) (Nat.two_pow_pos lc) hN

end Width

/-! ## An opening's code geometry -/

/-- **An opening's code geometry**: codewords of `2^h` symbols, `2^lc` message columns, `Q` queries and pads, decoding
radius `e`, `mI` index squeezes (`Q ≤ 4·mI`: one index per quarter digest). -/
structure OGeo where
  h : ℕ
  lc : ℕ
  Q : ℕ
  e : ℕ
  mI : ℕ
  hQm : Q ≤ mI * 4

/-- **The geometry's numeric side conditions**: `h ≤ 16`, at least one query, the unique-decoding radius
(`2e + (2^lc + Q) ≤ 2^h`), and the column round within `2^-126`. -/
structure OGeo.Ok (g : OGeo) : Prop where
  hh : g.h ≤ 16
  hQ0 : 0 < g.Q
  he : 2 * g.e + (2 ^ g.lc + g.Q) ≤ 2 ^ g.h
  hεB : (((Fintype.card (Fin (2 ^ g.h)) - (g.e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ g.h))) ^ g.Q * 1
    ≤ (2⁻¹ : ℝ≥0∞) ^ 126
  hm : (g.Q + 3) / 4 = g.mI

/-- **The block geometry at R13** (L28): codewords of `2^16`, `2^14` message columns, `256` queries and pads, radius
`24448`, `64` index squeezes. -/
def ogR13 : OGeo := ⟨16, 14, 256, 24448, 64, by norm_num⟩

/-- R13's block geometry meets the conditions (`2·24448 + 2^14 + 256 = 2^16`; the column round `≤ 2^-172`). -/
theorem ogR13_ok : ogR13.Ok := by
  have h1 : ogR13.h = 16 := rfl
  have h3 : ogR13.Q = 256 := rfl
  have h4 : ogR13.e = 24448 := rfl
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · show 16 ≤ 16
    exact le_rfl
  · show 0 < 256
    norm_num
  · show 2 * 24448 + (2 ^ 14 + 256) ≤ 2 ^ 16
    norm_num
  · rw [h1, h3, h4]
    exact opB_eps_r13u
  · show (256 + 3) / 4 = 64
    norm_num

end ZK60.Exec.Link
