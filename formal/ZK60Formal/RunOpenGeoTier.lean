/-
D63 lane L48 (2026-11-10), part 2: **the classify run's real opening geometries, named** (finding L45-2, decision
D77a).

The code's only registered token-I/O tier is `Tier::R1_MVP` (`token_io.rs:190`; `REGISTERED = [R1_MVP]`, `:196`; a
statement naming any other tier is refused by `Tier::check`): `opened_cols 256`, the stages at `stage_log_n 12`,
`stage_inv_rate 4`, the token endpoints at `ep_log_n 8`, `ep_inv_rate 8`. The pad count of every committed row is the
number of opened columns (`ZkOpts::standard`: `q_pad = num_col_checks`). So:

* `OTier`, **`tierR1`**: the tier's levers as the code holds them;
* **`ogStage`** `(14, 12, 256, 6016, 64)`: the stages' `A_in`, `H_in`, `A_out`, `H_out` (`stage_in_c.rs:43`,
  `classify.rs:680`: `lt = tier.stage_log_n`): `2^12` message columns, `256` pads, codewords of `2^12·4 = 2^14`;
* **`ogEp`** `(11, 8, 256, 768, 64)`: the classifier's input token commitment (`classify.rs:869`,
  `input_endpoint_spec`: `t.ep_log_n, t.ep_inv_rate, t.opened_cols`): `2^8` message columns, `256` pads, codewords of
  `2^8·8 = 2^11 = 2,048`;
* `ogStage_tier`, `ogEp_tier`: the geometries ARE the tier's (`2^h = 2^log_n · inv_rate`, `Q = opened_cols`, index
  squeezes `(Q + 3)/4`);
* the radii at their LARGEST values (Victor's D77 (1), "the unique-decoding radius at its largest value"):
  **`ogStage_radius`** (`2·6016 + 2^12 + 256 = 2^14` exactly), **`ogEp_radius`** (`2·768 + 2^8 + 256 = 2^11`
  exactly), **`ogStage_e_largest`**, **`ogEp_e_largest`** (`2e + n + Q ≤ N` iff `e ≤ 6016`, resp. `e ≤ 768`);
* the column rounds: **`opB_eps_stage`** (`((2^14 − 6017)/2^14)^256 ≤ 2^-169`), **`opB_eps_ep`**
  (`((2^11 − 769)/2^11)^256 ≤ 2^-173`); the first rounds: **`opA_eps_stage`** (`2^14/p²·bias ≤ 2^-112`),
  **`opA_eps_ep`** (`2^11/p²·bias ≤ 2^-115`), for a variable `p` (L7-4);
* **`ogStage_ok`**, **`ogEp_ok`**: both meet `OGeo.Ok`.

`RunOpenGeoCheck.lean` (an executable, not imported) checks these against the code: the tier constants in the source,
and the stage and input-endpoint parameters `Dim::of(params)`, rates and pad counts that lane L29's export recorded on
a real classifier run (`results/zk60_lean_l29_20261107/corpus.txt`), with a negative control.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunOpenGeo

set_option autoImplicit false

namespace ZK60.Exec.Link

open ZK60.Sound
open ZK60.Exec
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## The tier and the two geometries -/

/-- **A token-I/O tier's levers**, as the code's `Tier` holds them (`token_io.rs:166`): the column checks `Q` (the ZK pads
of every committed row), the stages' row width and inverse rate, the token endpoints' row width and inverse rate. -/
structure OTier where
  openedCols : ℕ
  stageLogN : ℕ
  stageInvRate : ℕ
  epLogN : ℕ
  epInvRate : ℕ

/-- **The code's only registered tier, `R1_MVP`** (`token_io.rs:190`): `opened_cols 256`, `stage_log_n 12`,
`stage_inv_rate 4`, `ep_log_n 8`, `ep_inv_rate 8`. -/
def tierR1 : OTier := ⟨256, 12, 4, 8, 8⟩

/-- **The stages' code geometry** (`A_in`, `H_in`, `A_out`, `H_out` at R1_MVP): codewords of `2^14`, `2^12` message
columns, `256` queries and pads, the largest radius `6016`, `64` index squeezes. -/
def ogStage : OGeo := ⟨14, 12, 256, 6016, 64, by norm_num⟩

/-- **The input token commitment's code geometry** (`input_endpoint_spec` at R1_MVP): codewords of `2^11 = 2,048`,
`2^8` message columns, `256` queries and pads, the largest radius `768`, `64` index squeezes. -/
def ogEp : OGeo := ⟨11, 8, 256, 768, 64, by norm_num⟩

/-- **The stage geometry is the tier's**: `2^12` columns, `2^14 = 2^12·4` codeword symbols, `Q = opened_cols`, the code's
`(Q + 3)/4` index squeezes. -/
theorem ogStage_tier : ogStage.lc = tierR1.stageLogN ∧ 2 ^ ogStage.h = 2 ^ tierR1.stageLogN * tierR1.stageInvRate
    ∧ ogStage.Q = tierR1.openedCols ∧ ogStage.mI = (tierR1.openedCols + 3) / 4 := by
  refine ⟨rfl, ?_, rfl, ?_⟩
  · show 2 ^ 14 = 2 ^ 12 * 4
    norm_num
  · show 64 = (256 + 3) / 4
    norm_num

/-- **The input endpoint geometry is the tier's**: `2^8` columns, `2^11 = 2^8·8` codeword symbols, `Q = opened_cols`. -/
theorem ogEp_tier : ogEp.lc = tierR1.epLogN ∧ 2 ^ ogEp.h = 2 ^ tierR1.epLogN * tierR1.epInvRate
    ∧ ogEp.Q = tierR1.openedCols ∧ ogEp.mI = (tierR1.openedCols + 3) / 4 := by
  refine ⟨rfl, ?_, rfl, ?_⟩
  · show 2 ^ 11 = 2 ^ 8 * 8
    norm_num
  · show 64 = (256 + 3) / 4
    norm_num

/-! ## The radii at their largest values -/

/-- **The stages' unique-decoding radius**: `2·6016 + (2^12 + 256) = 2^14` exactly. -/
theorem ogStage_radius : 2 * ogStage.e + (2 ^ ogStage.lc + ogStage.Q) = 2 ^ ogStage.h := by
  show 2 * 6016 + (2 ^ 12 + 256) = 2 ^ 14
  norm_num

/-- **`6016` is the stages' largest radius**: `2e + (2^12 + 256) ≤ 2^14` exactly when `e ≤ 6016`. -/
theorem ogStage_e_largest (e : ℕ) : 2 * e + (2 ^ ogStage.lc + ogStage.Q) ≤ 2 ^ ogStage.h ↔ e ≤ ogStage.e := by
  show 2 * e + (2 ^ 12 + 256) ≤ 2 ^ 14 ↔ e ≤ 6016
  rw [show (2 : ℕ) ^ 12 + 256 = 4352 by norm_num, show (2 : ℕ) ^ 14 = 16384 by norm_num]
  omega

/-- **The input commitment's unique-decoding radius**: `2·768 + (2^8 + 256) = 2^11 = 2,048` exactly. -/
theorem ogEp_radius : 2 * ogEp.e + (2 ^ ogEp.lc + ogEp.Q) = 2 ^ ogEp.h := by
  show 2 * 768 + (2 ^ 8 + 256) = 2 ^ 11
  norm_num

/-- **`768` is the input commitment's largest radius** (D77 (1) at the real geometry, D77a): `2e + (2^8 + 256) ≤ 2^11`
exactly when `e ≤ 768`. -/
theorem ogEp_e_largest (e : ℕ) : 2 * e + (2 ^ ogEp.lc + ogEp.Q) ≤ 2 ^ ogEp.h ↔ e ≤ ogEp.e := by
  show 2 * e + (2 ^ 8 + 256) ≤ 2 ^ 11 ↔ e ≤ 768
  rw [show (2 : ℕ) ^ 8 + 256 = 512 by norm_num, show (2 : ℕ) ^ 11 = 2048 by norm_num]
  omega

/-! ## The column rounds and the first rounds -/

/-- `(10367/16384)^256 ≤ 2^-169` (`(N − (e + 1))/N` at `N = 2^14`, `e = 6016`, `Q = 256`: `2^-169.03`). -/
theorem stage_col_far_nat : (2 ^ 14 - (6016 + 1)) ^ 256 * 2 ^ 169 ≤ 1 * (2 ^ 14) ^ 256 := by
  rw [show (256 : ℕ) = 128 * 2 from rfl, pow_mul, pow_mul]
  norm_num

/-- `(1279/2048)^256 ≤ 2^-173` (`(N − (e + 1))/N` at `N = 2^11`, `e = 768`, `Q = 256`: `2^-173.88`). -/
theorem ep_col_far_nat : (2 ^ 11 - (768 + 1)) ^ 256 * 2 ^ 173 ≤ 1 * (2 ^ 11) ^ 256 := by
  rw [show (256 : ℕ) = 128 * 2 from rfl, pow_mul, pow_mul]
  norm_num

/-- **The stages' column round** (`opB`'s error at the stage geometry): at most `2^-169`. -/
theorem opB_eps_stage :
    (((Fintype.card (Fin (2 ^ 14)) - (6016 + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ 14))) ^ 256 * 1
      ≤ (2⁻¹ : ℝ≥0∞) ^ 169 := by
  rw [mul_one, Fintype.card_fin, inv_two_pow_eq, natCast_div_pow]
  exact natCast_div_le_div (by positivity) (by norm_num) stage_col_far_nat

/-- **The input commitment's column round** (`opB`'s error, and the column test's, at the endpoint geometry): at most
`2^-173`. -/
theorem opB_eps_ep :
    (((Fintype.card (Fin (2 ^ 11)) - (768 + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ 11))) ^ 256 * 1
      ≤ (2⁻¹ : ℝ≥0∞) ^ 173 := by
  rw [mul_one, Fintype.card_fin, inv_two_pow_eq, natCast_div_pow]
  exact natCast_div_le_div (by positivity) (by norm_num) ep_col_far_nat

/-- `2^-j ≤ 2^-i` for `j ≥ i`. -/
theorem og_inv_two_pow_le {i j : ℕ} (hj : i ≤ j) : (2⁻¹ : ℝ≥0∞) ^ j ≤ (2⁻¹ : ℝ≥0∞) ^ i := by
  rw [inv_two_pow_eq, inv_two_pow_eq]
  refine natCast_div_le_div (by positivity) (by positivity) ?_
  rw [one_mul, one_mul]
  exact Nat.pow_le_pow_right (by norm_num) hj

/-- **The stages' first round** (`opA`'s error at `N = 2^14`, `|F| = p²`, the `(λ, ρ)` bias over at most `2^61`
squeezes at most `2`): at most `2^-112`. Stated for a variable `p` (L7-4). -/
theorem opA_eps_stage {F : Type} [Fintype F] (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p)
    (hF : Fintype.card F = p ^ 2) {w0 : ℕ} (hw0 : w0 ≤ 2 ^ 61) :
    ((2 ^ 14 : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0)
      ≤ (2⁻¹ : ℝ≥0∞) ^ 112 := by
  have hb : (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0) ≤ ((2 : ℕ) : ℝ≥0∞) := by
    exact_mod_cast fp2_bias_pow_le_two hp1 (by omega)
  have hp0 : 0 < p := by omega
  calc ((2 ^ 14 : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0)
      ≤ ((2 ^ 14 : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * ((2 : ℕ) : ℝ≥0∞) := by
        rw [hF]
        exact mul_le_mul' le_rfl hb
    _ = ((2 ^ 14 * 2 : ℕ) : ℝ≥0∞) / ((p ^ 2 * 1 : ℕ) : ℝ≥0∞) := by
        rw [← natCast_div_mul_div, Nat.cast_one, div_one]
    _ ≤ (2⁻¹ : ℝ≥0∞) ^ 112 := by
        rw [inv_two_pow_eq]
        refine natCast_div_le_div (mul_ne_zero (pow_ne_zero 2 (by omega)) one_ne_zero) (by norm_num) ?_
        calc 2 ^ 14 * 2 * 2 ^ 112 = 2 ^ 127 := by norm_num
          _ ≤ (2 ^ 64 - 2 ^ 32) ^ 2 := by norm_num
          _ ≤ p ^ 2 := Nat.pow_le_pow_left hp2 2
          _ = 1 * (p ^ 2 * 1) := by ring

/-- **The input commitment's first round** (`N = 2^11`): at most `2^-115`. Stated for a variable `p` (L7-4). -/
theorem opA_eps_ep {F : Type} [Fintype F] (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p)
    (hF : Fintype.card F = p ^ 2) {w0 : ℕ} (hw0 : w0 ≤ 2 ^ 61) :
    ((2 ^ 11 : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0)
      ≤ (2⁻¹ : ℝ≥0∞) ^ 115 := by
  have hb : (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0) ≤ ((2 : ℕ) : ℝ≥0∞) := by
    exact_mod_cast fp2_bias_pow_le_two hp1 (by omega)
  have hp0 : 0 < p := by omega
  calc ((2 ^ 11 : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0)
      ≤ ((2 ^ 11 : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * ((2 : ℕ) : ℝ≥0∞) := by
        rw [hF]
        exact mul_le_mul' le_rfl hb
    _ = ((2 ^ 11 * 2 : ℕ) : ℝ≥0∞) / ((p ^ 2 * 1 : ℕ) : ℝ≥0∞) := by
        rw [← natCast_div_mul_div, Nat.cast_one, div_one]
    _ ≤ (2⁻¹ : ℝ≥0∞) ^ 115 := by
        rw [inv_two_pow_eq]
        refine natCast_div_le_div (mul_ne_zero (pow_ne_zero 2 (by omega)) one_ne_zero) (by norm_num) ?_
        calc 2 ^ 11 * 2 * 2 ^ 115 = 2 ^ 127 := by norm_num
          _ ≤ (2 ^ 64 - 2 ^ 32) ^ 2 := by norm_num
          _ ≤ p ^ 2 := Nat.pow_le_pow_left hp2 2
          _ = 1 * (p ^ 2 * 1) := by ring

/-! ## Both geometries meet the side conditions -/

/-- **The stage geometry meets `OGeo.Ok`** (`h = 14 ≤ 16`, the radius, the column round `≤ 2^-169 ≤ 2^-126`). -/
theorem ogStage_ok : ogStage.Ok := by
  have h1 : ogStage.h = 14 := rfl
  have h3 : ogStage.Q = 256 := rfl
  have h4 : ogStage.e = 6016 := rfl
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · show 14 ≤ 16
    norm_num
  · show 0 < 256
    norm_num
  · show 2 * 6016 + (2 ^ 12 + 256) ≤ 2 ^ 14
    norm_num
  · rw [h1, h3, h4]
    exact opB_eps_stage.trans (og_inv_two_pow_le (by norm_num))
  · show (256 + 3) / 4 = 64
    norm_num

/-- **The input endpoint geometry meets `OGeo.Ok`** (`h = 11 ≤ 16`, the radius, the column round
`≤ 2^-173 ≤ 2^-126`). -/
theorem ogEp_ok : ogEp.Ok := by
  have h1 : ogEp.h = 11 := rfl
  have h3 : ogEp.Q = 256 := rfl
  have h4 : ogEp.e = 768 := rfl
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · show 11 ≤ 16
    norm_num
  · show 0 < 256
    norm_num
  · show 2 * 768 + (2 ^ 8 + 256) ≤ 2 ^ 11
    norm_num
  · rw [h1, h3, h4]
    exact opB_eps_ep.trans (og_inv_two_pow_le (by norm_num))
  · show (256 + 3) / 4 = 64
    norm_num

end ZK60.Exec.Link
