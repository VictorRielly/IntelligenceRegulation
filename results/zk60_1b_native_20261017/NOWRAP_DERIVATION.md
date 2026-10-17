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
