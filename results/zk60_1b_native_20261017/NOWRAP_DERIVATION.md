# Trained norm calibration: design and no-wrap derivation (native lane, 2026-10-17)

Status: implemented in the durable copy `ops/zkp-mvp/trained-1b/` (not in the
main tree, not committed). Proposed ruling **D24** (the `norm_tn` route),
recorded by the orchestrator; an independent adversarial review is owed.
This is a soundness/completeness argument for the norm and attention-output
relations only. It is not a privacy statement (D22 covers only the toy).

## 1. What changed, in plain words

The block's two RMS norms compute, per token row `x` and gain `g`,

    D = isqrt(sum_i x_i^2 + Ceps)
    y_i = floor((2 Cn g_i x_i + 2^tn D) / (2^(tn+1) D)) = round(g_i Cn x_i / (2^tn D))

and prove it with a remainder `rho` and its complement `sigma`, each held in
byte limbs. Every existing profile freezes `tn = 11, Cn = 1024, Ceps = 1`
(and the attention-output shift `sh_ao = 7`). At width 2048 that frozen rule
needs a 33-bit remainder window, i.e. five limbs, which the plane list cannot
express. The orchestrator's decision: instead of a fifth limb, **trained
profiles use `tn = 10`** (and, for width 4096, 9). The quotient keeps its
meaning with `Cn` halved, and the derived window is again 32 bits.

New per-profile fields of `Shape` (and of `private-block-kernel-shaped::Shape`):
`norm_tn`, `norm_cn_a` (norm_a), `norm_cn_m` (norm_m; the calibration
measures different values), `norm_ceps`, `sh_ao`, plus the flag
`trained_calibration`. Every registered profile keeps the frozen values; only
`Shape::with_trained_calibration` can change them, and only on the two
trained-calibration profiles (`...tinyllama-1.1b-t32-trained/1` and the
development rung `...rung-tc-t32-dev/1`).

## 2. The validator (`NormCalibration::derive_at_width`)

It computes and refuses; nothing is hard-coded per width:

* `D_max = isqrt(Ceps + width * 32768^2)` — signed int16 includes `-32768`
  (contract-review correction 1). The frozen 32767 formula is kept, untouched,
  for every existing profile, so their geometry and transcripts do not move.
* `2 * D_max < 2^24`: `D`, `a1`, `a2` keep three byte limbs (D16 items 1-3).
* `wrho = tn + 1 + bit_length(D_max)` must be in `25..=32`: exactly four
  remainder limbs (D16 items 3-4). Above 32 is refused by name, with the
  largest admissible `tn` in the message.
* the declared class: `tn` in 1..=16, `Cn` in 1..=2^20 (each norm), `Ceps` in
  1..=2^40, `sh_ao` in 0..=8, width at most 4096.

Results: max `tn` = 10 at width 2048 and 9 at width 4096 for every `Ceps` in
the class (`nowrap_check.json` `max_tn`). At the T3 constants (`tn 10, Cn_a
2672, Cn_m 4315, Ceps 129,746,337, sh_ao 7`): `D_max = 1,482,954`, window 32
(top limb full, correction C-6 applies). At the trained rung (width 384,
`tn 10, Ceps 33,554,467, sh_ao 6`): `D_max = 642,145`, window 31 (the top-limb
`scaled(.., 2)` lookup is live).

**Completeness gain over the lane-C dev shape**: the dev shape kept `tn = 11`
and overrode the window to 32, so honest rows with RMS above 23,170 were
refused. With the derived window every honest remainder fits for every int16
input: `rho, sigma <= den - 1 <= 2^(tn+1) D_max - 1 < 2^wrho`.

## 3. Binding

* The schedule's calibration line (`Layout::describe`, line 5) prints, at a
  trained profile, `calibration: trained norm tn=.. cn_a=.. cn_m=.. ceps=..
  ao=.. wrho=.. dmax=.. int16-endpoint=32768; ...`. The schedule digest is
  absorbed by every block transcript and every run transcript, so a verifier
  configured with any other `tn`, `Cn_a`, `Cn_m`, `Ceps` or `sh_ao` derives a
  different transcript and refuses (tested end to end: "expected statement
  mismatch" for each of the five single-constant variations, at the trained
  rung and at TinyLlama T32).
* Frozen profiles print the old line byte for byte (tested against the
  literal at all nine registered shapes; the toy schedule digest, toy
  parameter line and slot-IR export digests at every registered shape are
  pinned by pre-existing tests).
* The trained-model statement (schema `zk60-trained-model-statement/2`)
  carries `norm-tn`, `norm-cn-a`, `norm-cn-m`, `norm-ceps`, `sh-ao`,
  `norm-wrho` and refuses any record whose constants differ from the shape's
  (`check_honoured_by_code`); its identity is the run's `"calibration"` absorb.

## 4. No-wrap derivation (Goldilocks `p = 2^64 - 2^32 + 1`)

Range facts the proof establishes for committed values (adversarial, not
honest): `x, x1, x2, ao, z16` in int16 (two U8 limbs plus a bias, clauses
c2/c3/c4/c8/c10); `y, nm` in `[-127, 127]` (two `sym` lookups); `D, Dm, a1,
a2` in `[0, 2^24)` (three U8 limbs, R2); `rho, sigma` in `[0, 2^wrho)` (four
U8 limbs plus the top-limb pin, or C-6); `ral` in `[0, 2^sh_ao)` (U8 plus
`scaled(.., 2^(8 - sh_ao))`); `o8` in `[-127, 127]`; gains and weights public
int8. Every bound below uses those facts and the class maxima (`tn 16, Cn
2^20, Ceps 2^40, sh_ao 8, width 4096, wrho 32`), and is computed exactly by
`nowrap_check.py` (`nowrap_check.json`, `class_corner_bounds`):

| clause | absolute bound | log2 |
|---|---|---|
| R1 `dsq - D^2` | `(2^24-1)^2` | 48.0 |
| R3 `2D - a1 - a2` | `4 (2^24-1)` | 26.0 |
| R4 `dsq + a1 - Ceps - S` (`S = sum x^2 <= w 2^30`) | `(2^24-1)^2 + 2^24 + 2^40 + 2^42` | 48.03 |
| C0/C6 `2 Cn g x + 2^tn D - 2^(tn+1) D y - rho` | `2^21 128 32768 + 2^16 2^24 + 2^17 2^24 127 + 2^32` | 48.04 |
| C1/C7 `sigma + rho + 1 - 2^(tn+1) D` | `2^33 + 2^41` | 41.0 |
| host SC_WO `2^sh_ao ao + ral - half - acc` (`|acc| <= d_pad 127 128`) | | 26.2 |

All are below `2^48.04`, about 16 bits under `p`. So each field equality is
an integer equality, and:

* R1-R4 give `D^2 + a1 = S + Ceps`, `a1, a2 >= 0`, `a1 + a2 = 2D`, hence
  `D = isqrt(S + Ceps)`; `Ceps >= 1` gives `D >= 1`, so `den > 0`;
* C1 gives `rho + sigma + 1 = den = 2^(tn+1) D`; with `sigma >= 0`,
  `0 <= rho <= den - 1`, so C0's `y` is THE floor quotient (uniqueness checked
  exhaustively on small analogues in `nowrap_check.py` section 4);
* host SC_WO gives `ao = round(acc / 2^sh_ao)` with the remainder in
  `[-2^(sh_ao-1), 2^(sh_ao-1))` (`sh_ao = 0`: `ral = 0`, `ao = acc`).

Why the class must be enforced: an unbounded `Cn` such as `(p-1)/2` makes a
nonzero integer residual vanish mod `p` (section 5 of the script). The class
is enforced at shape construction on BOTH sides (prover and verifier build
their shape through the same validator), and by the reference kernel.

The relations the trained constants do not enter (QKV/RoPE/score/softmax/PV,
the feed-forward and the residuals) are untouched; their premise in
`layout.rs` (lines ~610-676) is unchanged and was not re-derived here.

## 5. D16, item by item

1. `D` direct byte-limb pin with `ceil(log256(Dmax+1))` limbs: 3 limbs, the
   validator refuses `2 D_max >= 2^24` (1,482,954 and 642,145 here).
2. `a1, a2`: same three-limb pin.
3. never more than four limbs: isqrt 3, remainder 4; a fifth is refused by
   the validator and by `Ids::new`.
4. remainder window exact and at most 32: derived, tight (den_max >
   2^(wrho-1) asserted), 32 at TinyLlama, 31 at the trained rung.
5. audit re-run: the test
   `every_committed_value_under_a_non_unit_coefficient_is_range_proved_at_the_trained_shapes`
   walks the slot IR of all 23 slots at both trained shapes, lists every
   (slot, committed plane) under a non-unit public coefficient, classifies
   each (U8 lookup on its own domain / byte-limb pinned with U8 limbs / public
   pair table), finds none unclassified, and asserts the exposure set equals
   the frozen structural twin's (TinyLlama trained = lane-C dev shape; rung-TC
   = rung-C6). Listing: `t2-audit-and-ladder.log` (`D16-5 AUDIT` lines).
   Wraparound premise: section 4 above.
6. alias tamper tests: generalised to any shape (`norm_alias.rs`,
   `write_alias_at`, shape's `tn`, `Ceps`, both `Cn`, strides) and run end to
   end through the real prover/verifier; see PROGRESS.md for the TinyLlama run.

## 6. Open points for the reviewer

* `y = round(g Cn x / (2^tn D))` keeps its meaning when `tn` and `Cn` are both
  halved; odd `Cn` cannot be halved exactly, so a calibration must be stated
  at the `tn` it is used at (the export carries `norm_tn` explicitly).
* A single-block receipt at the trained TinyLlama profile absorbs the
  synthetic calibration LITERAL (only runs are bound to a model statement);
  the trained-model route is the bound run (`RunStatement::new_bound`), and an
  unbound run at the trained run profile is refused. The single-block path is
  used here only for the synthetic T3 checks.
* The softmax probability scale `F_P = 9` (a fidelity limit, not soundness)
  and the wire segment cap (64 MiB; T512 at row width 2^14 counts 72 MB) are
  unchanged.

## 7. Round 2 (2026-10-17): the requantization shifts per profile

The pg_rot1 export needs QKV 8 / AO 3 / gate 8 / down 5 (frozen 7 / 7 / 7 / 6).
`NormCalibration` now also carries `sh_qkv`, `sh_s`, `sh_o`, `sh_g`, `sh_h`,
`sh_z` (with `sh_ao`). **Structure-preserving windows**, read off the code,
not off a summary:

* `layout.rs::lookups_at`: each biased remainder `r + 2^(sh-1)` is ONE byte
  limb at the Q/K/V (`A_RQL`, `A_RKL`, `A_RVL`), score (`A_RSL`), AO
  (`A_RAL`), gate (`A_RGL`) and down (`A_RDL`) sites — `byte(r)` plus
  `scaled(r, 2^(8 - sh))` — and TWO limbs at the PV output (`A_RO0/1`) and the
  product (`A_RH0/1`) — `byte(l0)`, `byte(l1)`, `scaled(l1, 2^(16 - sh))`.
  So one-limb sites admit `1..=8` (AO `0..=8`: `scaled(r, 256)` pins r = 0)
  and two-limb sites `9..=16`; inside a window only the `scaled` coefficient
  moves. The frozen values give exactly the historical literals 2, 4, 2, 4,
  128, 4 (pinned by the unchanged slot-IR export digests and toy schedule).
* `argument.rs` host relations (`SC_QZC`/`SC_KVZC`: Q, K, V, PV; `SC_SZC`:
  score; `SC_FZC`: gate host and the product clause f0; `SC_DZC`: AO and
  down hosts) and their `slot_ir.rs` twins read `2^sh` and `2^(sh-1)` from
  the shape (labels unchanged so no IR digest of a registered shape moves).
* Fixed: the RoPE shift (coupled to `F_RO`), `F_P`, `F_E`'s window logic, the
  up shift (0: there is no remainder plane), the residual shifts (0).

**No-wrap, at the top of every window** (`nowrap_check.py`
`shift_window_bounds_log2`, class maxima width 4096, T 512, head_dim 128,
f_pad 16384): host `2^sh q + r - 2^(sh-1) - acc` with q in its class,
`r < 2^sh`, and `acc` the hosted claim's integer value from range-proved
factors and public int8 weights. Worst case is the down host, about 2^36;
all far below p. Exactness of the round-half-up quotient for every `sh` in
1..=16 is checked exhaustively on small accumulators.

**D16 item 5 re-run** at the new constants: the range audit now also walks
the pg_rot1 calibration at the TinyLlama geometry and rung-TC carries every
shift off its frozen value; nothing may be unclassified and the exposure may
only SHRINK against the frozen twin. It does shrink, benignly: at a shift of
8 (pg's QKV and gate) the top-limb pin `scaled(r, 2^(8-8))` has coefficient
1, so A_RQL / A_RKL / A_RVL / A_RGL leave the NON-UNIT list while each is
still a U8 lookup (the audit prints each such plane).

**R2-4**: every single-block entry point refuses a trained-calibration shape
(`protocol::single_block_profile_allowed`), so no trained-profile receipt can
carry the synthetic calibration literal; a trained block proves as a bound
run (one block or the whole stack).

## 8. Round 2, review finding F-1: the softmax exp precision `f_e`

The D24 review found `f_e` an unvalidated export constant: the quotient
clause of `SC_SZC`, `c2 = mask e 2^F_P - p Sum - rho_s`, has the integer
bound `2^(f_e+9) + (2^10 - 1) T 2^f_e + 2^wrho_s`, which reaches `p` at
`f_e = 49` (T = 32); at `f_e = 50` the reviewer forged one quotient
(p 16 -> 527, `rho_s' = rho_s - 511 Sum + P`, so `c2 = -P`) and the CLI
verified it. Fix: the declared class `f_e in 9..=16` (9 is the approved
calibration value; up to 16 for the calibration lane's finer-exp test) WITH
the three-limb softmax window `wrho_s = clog2(T) + f_e <= 24`, checked by the
loader, the shape door and `Layout::for_shape` on both sides.

**Re-derivation over the class** (adversarial facts: `e in [0, 2^f_e]` from
the two-column exp lookup against a table checked to lie in `[0, 2^f_e]`;
`Sum <= T 2^f_e`; `p < 2^(F_P+1)` from its limbs and top pin; `rho_s, sigma_s
in [0, 2^wrho_s)` from `ls` limbs and the top pin `1 << (8 ls - wrho_s)`):
for every `(f_e, T)` with `f_e in 9..=16` and `clog2(T) + f_e <= 24` (100
points, T from 1 to 2^15):

* `|c2| < 2^34.003` (at T = 32: `2^31.022`), `c3 = sigma_s + rho_s + 1 - Sum`
  and the PV accumulator `T (2^10 - 1) 127` far smaller; all far below
  `p / 2`, so `c2 = 0` and `c3 = 0` hold over the integers;
* `Sum <= T 2^f_e <= 2^wrho_s`, so `rho_s in [0, Sum)` and `p` is the floor
  quotient (the exactness argument of section 4 / layout.rs);
* no all-equal-row wrapping forgery exists for any `k != 0` and any
  `|delta| < 2^10` (`rho_s - delta Sum + k P` is never in `[0, Sum)`).

Checked by `nowrap_check.py` section 7 and, independently, by the reviewer's
own `softmax_bounds` / `softmax_forgery` re-run on the new class
(`reviewer_nowrap_round2.py`, which imports `reviewer_nowrap.py` read-only):
same 100 points, worst `2^34.003`, margin about 30 bits, no forgery; the
reviewer's T32 forgery threshold (f_e 50) reproduced. `F_P` stays 9.

The other export-chosen constants and their declared classes: exp `e_s` in
`-8..=8` (any finite `e_s` keeps the table in `[0, 2^f_e]` with `E[0] =
2^f_e`, asserted by `exp_member`; the class keeps the generator away from its
NaN overflow), the SiLU member in the frozen int16-out registry (values in
`[-32767, 32767]`, inside the product clause's int16 premise), the RoPE base
pinned to the geometry's 10000 (table values `round(2^7 cos/sin)` lie in
`[-128, 128]` for any base, so no premise depends on it), the fixed
constants (`sh_rope`, `sh_u`, `f_p`, `f_ro`, `sh_r2`) equal to the code's.
