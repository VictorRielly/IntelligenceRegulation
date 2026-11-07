/-
D63 lane L20 (2026-11-07), part 4: **the block's total against the approved target** `εsTarget q = q·2^-100 + 2^-100`.

Arithmetic only (no protocol): every term of the block's knowledge bound, with the per-position count
(`CountW16Chain.lean`), is at most `(q + 1)·c/2^126` for an explicit `c` (`u126`), and the `c`'s add up to at most
`2^26`, i.e. `(q + 1)·2^-100`:

| term | bound used | `c` |
|---|---|---|
| a collision term `collBound T`, `T ≤ 2^22·(q + 1)` | `T²/2^256` | `2^14` |
| the slots' first term `(q·dmax + ND)/p²·(1 + p/2^128)²` | bias `≤ 2`, `p² ≥ 2^127` | `dmax + ND` |
| `M`: `q·maskEps + 3·maskEps`, `maskEps ≤ 2^-106` | | `3·2^20` |
| `opA`: `q·εA + εA`, `εA ≤ 2^-111` | | `2^15` |
| `opB`: `q·εB + εB`, `εB ≤ 2^-113` | | `2^13` |
| the extraction failure's fresh-hit term `(2T'² + (1 + nr)T')/2^256`, `nr ≤ 3` | | `2^16` |
| `εrel`, `εlk` | the other lanes' budgets | `crel`, `clk` |

* `u126`, `u126_add`, `u126_mono`, `u126_le_target`, `coll_le_u126`, `slots_le_u126`, `lin_le_u126`, `sched1_le_u126`,
  `sched3_le_u126`, `xfail_le_u126`;
* **`block_total_le_target`**: for `q < 2^100`, block and opening chains of at most `2^20` items, `M`, two openings
  (`A`, `H`), the extraction failure, the slots and the other lanes' `εrel ≤ (q + 1)·crel/2^126`,
  `εlk ≤ (q + 1)·clk/2^126` with `dmax + ND + crel + clk ≤ 2^25`: the sum is at most `εsTarget q`. The fixed part is
  `3,506,176 ≤ 2^22` of the `2^26`, so the budget left for the slots' rounds, L13's relations and LogUp is `2^25`
  (LogUp's `α` at about `2^-102.9` per query is about `2^23.1`).

Facts about the literal Goldilocks prime are stated for a variable `p` within `2^32` below `2^64` (L7-4). Only
`propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.CountW16Slots

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound
open scoped ENNReal

/-- `(q + 1)·c/2^126`. -/
noncomputable def u126 (q c : ℕ) : ℝ≥0∞ := (((q + 1) * c : ℕ) : ℝ≥0∞) / ((2 ^ 126 : ℕ) : ℝ≥0∞)

theorem u126_add (q a b : ℕ) : u126 q a + u126 q b = u126 q (a + b) := by
  unfold u126
  rw [ENNReal.div_add_div_same, ← Nat.cast_add, Nat.mul_add]

theorem u126_mono (q : ℕ) {a b : ℕ} (h : a ≤ b) : u126 q a ≤ u126 q b :=
  ENNReal.div_le_div_right (by exact_mod_cast Nat.mul_le_mul_left _ h) _

/-- **`(q + 1)·c/2^126` is below the target when `c ≤ 2^26`.** -/
theorem u126_le_target (q c : ℕ) (hc : c ≤ 2 ^ 26) : u126 q c ≤ εsTarget q := by
  rw [εsTarget_eq]
  unfold u126
  refine natCast_div_le_div (by positivity) (by positivity) ?_
  calc (q + 1) * c * 2 ^ 100 ≤ (q + 1) * 2 ^ 26 * 2 ^ 100 := by gcongr
    _ = (q + 1) * 2 ^ 126 := by ring

/-- **A collision term**: `collBound T ≤ (q + 1)·2^14/2^126` for `T ≤ 2^22·(q + 1)`, `q < 2^100`. -/
theorem coll_le_u126 (q t : ℕ) (hq : q < 2 ^ 100) (ht : t ≤ 2 ^ 22 * (q + 1)) : collBound t Dig ≤ u126 q (2 ^ 14) := by
  unfold collBound u126
  rw [card_dig, Fintype.card_prod, Fintype.card_fin]
  refine natCast_div_le_div (by positivity) (by positivity) ?_
  have hq1 : q + 1 ≤ 2 ^ 100 := hq
  calc t * (t - 1) / 2 * 2 ^ 126 ≤ t * t * 2 ^ 126 := by
        gcongr
        exact (Nat.div_le_self _ _).trans (Nat.mul_le_mul_left _ (Nat.sub_le _ _))
    _ ≤ (2 ^ 22 * (q + 1)) * (2 ^ 22 * (q + 1)) * 2 ^ 126 := by gcongr
    _ = (q + 1) * ((q + 1) * 2 ^ 170) := by ring
    _ ≤ (q + 1) * (2 ^ 100 * 2 ^ 170) := by gcongr
    _ = (q + 1) * 2 ^ 14 * (2 ^ 128 * 2 ^ 128) := by ring

/-- **The slots' first term**: `(q·dmax + ND)/p²·(1 + p/2^128)² ≤ (q + 1)·(dmax + ND)/2^126`. -/
theorem slots_le_u126 (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p) (q dmax ND : ℕ) :
    ((q * dmax + ND : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      ≤ u126 q (dmax + ND) := by
  have hb : (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2 ≤ ((2 : ℕ) : ℝ≥0∞) := by
    exact_mod_cast fp2_bias_pow_le_two hp1 (by norm_num)
  have hp0 : 0 < p := by omega
  calc ((q * dmax + ND : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      ≤ ((q * dmax + ND : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * ((2 : ℕ) : ℝ≥0∞) := mul_le_mul' le_rfl hb
    _ = (((q * dmax + ND) * 2 : ℕ) : ℝ≥0∞) / ((p ^ 2 * 1 : ℕ) : ℝ≥0∞) := by
        rw [← natCast_div_mul_div, Nat.cast_one, div_one]
    _ ≤ u126 q (dmax + ND) := by
        unfold u126
        refine natCast_div_le_div (mul_ne_zero (pow_ne_zero 2 (by omega)) one_ne_zero) (by positivity) ?_
        have hp : 2 ^ 127 ≤ p ^ 2 := le_trans (by norm_num) (Nat.pow_le_pow_left hp2 2)
        have h1 : q * dmax + ND ≤ (q + 1) * (dmax + ND) := by
          have e : (q + 1) * (dmax + ND) = (q * dmax + q * ND) + (dmax + ND) := by ring
          rw [e]
          exact Nat.add_le_add (Nat.le_add_right _ _) (Nat.le_add_left _ _)
        calc (q * dmax + ND) * 2 * 2 ^ 126 = (q * dmax + ND) * 2 ^ 127 := by ring
          _ ≤ (q + 1) * (dmax + ND) * 2 ^ 127 := Nat.mul_le_mul_right _ h1
          _ ≤ (q + 1) * (dmax + ND) * (p ^ 2 * 1) := by
              rw [mul_one]
              exact Nat.mul_le_mul_left _ hp

/-- **A sub-protocol charged `q + c` times**: `q·ε + c·ε ≤ (q + 1)·c·2^(126 − j)/2^126` for `ε ≤ 2^-j`, `c ≥ 1`. -/
theorem lin_le_u126 (q c j : ℕ) (hj : j ≤ 126) (hc : 1 ≤ c) (ε : ℝ≥0∞) (hε : ε ≤ (2⁻¹ : ℝ≥0∞) ^ j) :
    (q : ℝ≥0∞) * ε + (c : ℝ≥0∞) * ε ≤ u126 q (c * 2 ^ (126 - j)) := by
  calc (q : ℝ≥0∞) * ε + (c : ℝ≥0∞) * ε = ((q + c : ℕ) : ℝ≥0∞) * ε := by
        push_cast
        ring
    _ ≤ ((q + c : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ j := mul_le_mul' le_rfl hε
    _ = ((q + c : ℕ) : ℝ≥0∞) / ((2 ^ j : ℕ) : ℝ≥0∞) := by
        rw [inv_two_pow_eq, Nat.cast_one, ← mul_div_assoc, mul_one]
    _ ≤ u126 q (c * 2 ^ (126 - j)) := by
        unfold u126
        refine natCast_div_le_div (by positivity) (by positivity) ?_
        have e : 2 ^ (126 - j) * 2 ^ j = 2 ^ 126 := by rw [← pow_add, Nat.sub_add_cancel hj]
        have h1 : q + c ≤ (q + 1) * c := by
          rw [Nat.add_mul, one_mul]
          exact Nat.add_le_add_right (Nat.le_mul_of_pos_right q hc) c
        calc (q + c) * 2 ^ 126 ≤ (q + 1) * c * 2 ^ 126 := by gcongr
          _ = (q + 1) * (c * 2 ^ (126 - j)) * 2 ^ j := by
              rw [show (q + 1) * (c * 2 ^ (126 - j)) * 2 ^ j = (q + 1) * c * (2 ^ (126 - j) * 2 ^ j) by ring, e]

/-- **A one-round sub-protocol's schedule**: `q·ε + ε + collBound T + collBound (T + 1) ≤ (q + 1)·(2^(126−j) +
2·2^14)/2^126` for `ε ≤ 2^-j`, a chain of at most `2^20` items, `q < 2^100`. -/
theorem sched1_le_u126 (q ℓ j : ℕ) (hq : q < 2 ^ 100) (hℓ : ℓ ≤ 2 ^ 20) (hj : j ≤ 126) (ε : ℝ≥0∞)
    (hε : ε ≤ (2⁻¹ : ℝ≥0∞) ^ j) :
    (q : ℝ≥0∞) * ε + ε + collBound (q + ℓ + 1) Dig + collBound (q + ℓ + 1 + 1) Dig
      ≤ u126 q (2 ^ (126 - j) + 2 ^ 14 + 2 ^ 14) := by
  have h1 := lin_le_u126 q 1 j hj le_rfl ε hε
  rw [Nat.cast_one, one_mul, one_mul] at h1
  have hc1 := coll_le_u126 q (q + ℓ + 1) hq (by omega)
  have hc2 := coll_le_u126 q (q + ℓ + 1 + 1) hq (by omega)
  calc _ ≤ u126 q (2 ^ (126 - j)) + u126 q (2 ^ 14) + u126 q (2 ^ 14) := add_le_add (add_le_add h1 hc1) hc2
    _ = _ := by rw [u126_add, u126_add]

/-- **`M`'s schedule** (three rounds): `q·ε + 3·ε + collBound T + collBound (T + 1) ≤ (q + 1)·(3·2^(126−j) +
2·2^14)/2^126`. -/
theorem sched3_le_u126 (q ℓ j : ℕ) (hq : q < 2 ^ 100) (hℓ : ℓ ≤ 2 ^ 20) (hj : j ≤ 126) (ε : ℝ≥0∞)
    (hε : ε ≤ (2⁻¹ : ℝ≥0∞) ^ j) :
    (q : ℝ≥0∞) * ε + 3 * ε + collBound (q + ℓ + 1) Dig + collBound (q + ℓ + 1 + 1) Dig
      ≤ u126 q (3 * 2 ^ (126 - j) + 2 ^ 14 + 2 ^ 14) := by
  have h1 := lin_le_u126 q 3 j hj (by norm_num) ε hε
  have e3 : ((3 : ℕ) : ℝ≥0∞) = 3 := by norm_num
  rw [e3] at h1
  have hc1 := coll_le_u126 q (q + ℓ + 1) hq (by omega)
  have hc2 := coll_le_u126 q (q + ℓ + 1 + 1) hq (by omega)
  calc _ ≤ u126 q (3 * 2 ^ (126 - j)) + u126 q (2 ^ 14) + u126 q (2 ^ 14) := add_le_add (add_le_add h1 hc1) hc2
    _ = _ := by rw [u126_add, u126_add]

/-- **The extraction failure** (`extract_fail_run` with at most three roots, a run of `T' ≤ 2^22·(q + 1)` queries):
at most `(q + 1)·(2^14 + 2^16)/2^126`. -/
theorem xfail_le_u126 (q T' nr : ℕ) (hq : q < 2 ^ 100) (hT : T' ≤ 2 ^ 22 * (q + 1)) (hnr : nr ≤ 3) :
    collBound T' Dig + ((2 * T' * T' + (1 + nr) * T' : ℕ) : ℝ≥0∞) / Fintype.card Dig ≤ u126 q (2 ^ 14 + 2 ^ 16) := by
  have hc := coll_le_u126 q T' hq hT
  have hf : ((2 * T' * T' + (1 + nr) * T' : ℕ) : ℝ≥0∞) / Fintype.card Dig ≤ u126 q (2 ^ 16) := by
    unfold u126
    rw [card_dig, Fintype.card_prod, Fintype.card_fin]
    refine natCast_div_le_div (by positivity) (by positivity) ?_
    have hq1 : q + 1 ≤ 2 ^ 100 := hq
    have hsq : T' * T' ≤ 2 ^ 144 * (q + 1) := by
      calc T' * T' ≤ (2 ^ 22 * (q + 1)) * (2 ^ 22 * (q + 1)) := Nat.mul_le_mul hT hT
        _ = 2 ^ 44 * (q + 1) * (q + 1) := by ring
        _ ≤ 2 ^ 44 * (q + 1) * 2 ^ 100 := Nat.mul_le_mul_left _ hq1
        _ = 2 ^ 144 * (q + 1) := by ring
    have hlin : (1 + nr) * T' ≤ 2 ^ 144 * (q + 1) := by
      calc (1 + nr) * T' ≤ 4 * (2 ^ 22 * (q + 1)) := Nat.mul_le_mul (by omega) hT
        _ = 2 ^ 24 * (q + 1) := by ring
        _ ≤ 2 ^ 144 * (q + 1) := Nat.mul_le_mul_right _ (by norm_num)
    calc (2 * T' * T' + (1 + nr) * T') * 2 ^ 126 ≤ (2 * (2 ^ 144 * (q + 1)) + 2 ^ 144 * (q + 1)) * 2 ^ 126 := by
          rw [mul_assoc 2 T' T']
          exact Nat.mul_le_mul_right _ (Nat.add_le_add (Nat.mul_le_mul_left 2 hsq) hlin)
      _ = (q + 1) * (3 * (2 ^ 144 * 2 ^ 126)) := by ring
      _ ≤ (q + 1) * (4 * (2 ^ 144 * 2 ^ 126)) := Nat.mul_le_mul_left _ (Nat.mul_le_mul_right _ (by norm_num))
      _ = (q + 1) * 2 ^ 16 * (2 ^ 128 * 2 ^ 128) := by ring
  calc _ ≤ u126 q (2 ^ 14) + u126 q (2 ^ 16) := add_le_add hc hf
    _ = _ := u126_add _ _ _

/-- **The block's total is below the approved target, for every `q < 2^100`** (D63 lane L20; finding L16-1), for ANY
opening geometry: `M`'s error `≤ 2^-jM`, each regular opening's `opA` error `≤ 2^-jA` and `opB` error `≤ 2^-jB`.
With the per-position count, the block's knowledge bound is the sum of: `M`'s schedule, the `A` and `H` openings' two
schedules each, the extraction failure (`T' ≤ 2^22·(q + 1)` queries, at most three roots), the slots' schedule
(`(q·dmax + ND)/p²·(1 + p/2^128)²` and two collision terms), and L13's / LogUp's terms `εrel ≤ (q + 1)·crel/2^126`,
`εlk ≤ (q + 1)·clk/2^126`. If
`3·2^(126−jM) + 2·(2^(126−jA) + 2^(126−jB)) + 2^18 + 2^16 + dmax + ND + crel + clk ≤ 2^26`, the sum is at most `εsTarget q = q·2^-100 + 2^-100`. -/
theorem block_total_le_target (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p) (q : ℕ) (hq : q < 2 ^ 100)
    (ℓs ℓo : ℕ) (hℓs : ℓs ≤ 2 ^ 20) (hℓo : ℓo ≤ 2 ^ 20) (dmax ND : ℕ) (jM jA jB : ℕ) (hjM : jM ≤ 126)
    (hjA : jA ≤ 126) (hjB : jB ≤ 126)
    (maskE εAa εBa εAh εBh : ℝ≥0∞) (hmE : maskE ≤ (2⁻¹ : ℝ≥0∞) ^ jM)
    (hAa : εAa ≤ (2⁻¹ : ℝ≥0∞) ^ jA) (hBa : εBa ≤ (2⁻¹ : ℝ≥0∞) ^ jB)
    (hAh : εAh ≤ (2⁻¹ : ℝ≥0∞) ^ jA) (hBh : εBh ≤ (2⁻¹ : ℝ≥0∞) ^ jB)
    (T' nr : ℕ) (hT' : T' ≤ 2 ^ 22 * (q + 1)) (hnr : nr ≤ 3)
    (εrel εlk : ℝ≥0∞) (crel clk : ℕ) (hrel : εrel ≤ u126 q crel) (hlk : εlk ≤ u126 q clk)
    (hbud : 3 * 2 ^ (126 - jM) + 2 * (2 ^ (126 - jA) + 2 ^ (126 - jB)) + 2 ^ 18 + 2 ^ 16 + dmax + ND + crel + clk
      ≤ 2 ^ 26) :
    ((q : ℝ≥0∞) * maskE + 3 * maskE + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig)
      + (((q : ℝ≥0∞) * εAa + εAa + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig)
        + ((q : ℝ≥0∞) * εBa + εBa + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig))
      + (((q : ℝ≥0∞) * εAh + εAh + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig)
        + ((q : ℝ≥0∞) * εBh + εBh + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig))
      + (collBound T' Dig + ((2 * T' * T' + (1 + nr) * T' : ℕ) : ℝ≥0∞) / Fintype.card Dig)
      + (((q * dmax + ND : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + ℓs + 1) Dig + collBound (q + ℓs + 1 + 1) Dig)
      + εrel + εlk ≤ εsTarget q := by
  have hM := sched3_le_u126 q ℓo jM hq hℓo hjM maskE hmE
  have hA1 := sched1_le_u126 q ℓo jA hq hℓo hjA εAa hAa
  have hA2 := sched1_le_u126 q ℓo jB hq hℓo hjB εBa hBa
  have hH1 := sched1_le_u126 q ℓo jA hq hℓo hjA εAh hAh
  have hH2 := sched1_le_u126 q ℓo jB hq hℓo hjB εBh hBh
  have hX := xfail_le_u126 q T' nr hq hT' hnr
  have hS : ((q * dmax + ND : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      + collBound (q + ℓs + 1) Dig + collBound (q + ℓs + 1 + 1) Dig ≤ u126 q (dmax + ND + 2 ^ 14 + 2 ^ 14) := by
    calc _ ≤ u126 q (dmax + ND) + u126 q (2 ^ 14) + u126 q (2 ^ 14) :=
          add_le_add (add_le_add (slots_le_u126 p hp1 hp2 q dmax ND) (coll_le_u126 q _ hq (by omega)))
            (coll_le_u126 q _ hq (by omega))
      _ = _ := by rw [u126_add, u126_add]
  calc _ ≤ u126 q (3 * 2 ^ (126 - jM) + 2 ^ 14 + 2 ^ 14)
        + (u126 q (2 ^ (126 - jA) + 2 ^ 14 + 2 ^ 14) + u126 q (2 ^ (126 - jB) + 2 ^ 14 + 2 ^ 14))
        + (u126 q (2 ^ (126 - jA) + 2 ^ 14 + 2 ^ 14) + u126 q (2 ^ (126 - jB) + 2 ^ 14 + 2 ^ 14))
        + u126 q (2 ^ 14 + 2 ^ 16) + u126 q (dmax + ND + 2 ^ 14 + 2 ^ 14) + u126 q crel + u126 q clk :=
        add_le_add (add_le_add (add_le_add (add_le_add (add_le_add (add_le_add hM (add_le_add hA1 hA2))
          (add_le_add hH1 hH2)) hX) hS) hrel) hlk
    _ = u126 q (3 * 2 ^ (126 - jM) + 2 ^ 14 + 2 ^ 14
        + ((2 ^ (126 - jA) + 2 ^ 14 + 2 ^ 14) + (2 ^ (126 - jB) + 2 ^ 14 + 2 ^ 14))
        + ((2 ^ (126 - jA) + 2 ^ 14 + 2 ^ 14) + (2 ^ (126 - jB) + 2 ^ 14 + 2 ^ 14))
        + (2 ^ 14 + 2 ^ 16) + (dmax + ND + 2 ^ 14 + 2 ^ 14) + crel + clk) := by
        simp only [u126_add]
    _ ≤ εsTarget q := by
        refine u126_le_target q _ ?_
        generalize 2 ^ (126 - jM) = a at hbud ⊢
        generalize 2 ^ (126 - jA) = b at hbud ⊢
        generalize 2 ^ (126 - jB) = c at hbud ⊢
        calc _ = (3 * a + 2 * (b + c) + 2 ^ 16 + dmax + ND + crel + clk) + 13 * 2 ^ 14 := by ring
          _ ≤ (3 * a + 2 * (b + c) + 2 ^ 16 + dmax + ND + crel + clk) + 2 ^ 18 :=
              Nat.add_le_add_left (by norm_num) _
          _ = 3 * a + 2 * (b + c) + 2 ^ 18 + 2 ^ 16 + dmax + ND + crel + clk := by ring
          _ ≤ 2 ^ 26 := hbud

/-- **At W16R2's opening geometry** (`M ≤ 2^-106`, `opA ≤ 2^-111`, `opB ≤ 2^-113`): the budget left for the slots'
rounds, L13's relations and LogUp is `dmax + ND + crel + clk ≤ 2^25`. -/
theorem block_total_le_target_w16r2 (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p) (q : ℕ)
    (hq : q < 2 ^ 100) (ℓs ℓo : ℕ) (hℓs : ℓs ≤ 2 ^ 20) (hℓo : ℓo ≤ 2 ^ 20) (dmax ND : ℕ)
    (maskE εAa εBa εAh εBh : ℝ≥0∞) (hmE : maskE ≤ (2⁻¹ : ℝ≥0∞) ^ 106)
    (hAa : εAa ≤ (2⁻¹ : ℝ≥0∞) ^ 111) (hBa : εBa ≤ (2⁻¹ : ℝ≥0∞) ^ 113)
    (hAh : εAh ≤ (2⁻¹ : ℝ≥0∞) ^ 111) (hBh : εBh ≤ (2⁻¹ : ℝ≥0∞) ^ 113)
    (T' nr : ℕ) (hT' : T' ≤ 2 ^ 22 * (q + 1)) (hnr : nr ≤ 3)
    (εrel εlk : ℝ≥0∞) (crel clk : ℕ) (hrel : εrel ≤ u126 q crel) (hlk : εlk ≤ u126 q clk)
    (hbud : dmax + ND + crel + clk ≤ 2 ^ 25) :
    ((q : ℝ≥0∞) * maskE + 3 * maskE + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig)
      + (((q : ℝ≥0∞) * εAa + εAa + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig)
        + ((q : ℝ≥0∞) * εBa + εBa + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig))
      + (((q : ℝ≥0∞) * εAh + εAh + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig)
        + ((q : ℝ≥0∞) * εBh + εBh + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig))
      + (collBound T' Dig + ((2 * T' * T' + (1 + nr) * T' : ℕ) : ℝ≥0∞) / Fintype.card Dig)
      + (((q * dmax + ND : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + ℓs + 1) Dig + collBound (q + ℓs + 1 + 1) Dig)
      + εrel + εlk ≤ εsTarget q :=
  block_total_le_target p hp1 hp2 q hq ℓs ℓo hℓs hℓo dmax ND 106 111 113 (by norm_num) (by norm_num) (by norm_num)
    maskE εAa εBa εAh εBh hmE hAa hBa hAh hBh T' nr hT' hnr εrel εlk crel clk hrel hlk (by norm_num at hbud ⊢; omega)

end ZK60.Exec
