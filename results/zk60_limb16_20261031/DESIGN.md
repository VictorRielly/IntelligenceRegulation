# W16: 16-bit range-check limbs for the R13 accuracy block (design, D54)

Status: **design, not built.** Victor approved this direction on 2026-10-31 (D54).
It is a new proof format. It is built as a separate, opt-in profile beside
R13/R14, and no existing profile changes a byte. Counts below are exact, from the
layout formulas. Times are estimates from the M4l Metal phase profile.

## Why

At the trained T128 shapes (Shieldstral and Llama-3-8B), one accuracy block
commits:

- 75.0 M words in `A`, of which 64.3 M are read by byte lookups;
- 71.9 M words in `H`, of which 64.3 M are LogUp helpers, one per byte lookup.

Every bounded remainder is split into byte limbs. Each limb is a committed
plane, a lookup and half an `Fp2` helper. A bounded top limb is looked up a
second time, scaled: a scaled lookup alone does not bound a field element, so
the plain byte lookup has to stay alongside it. Both trained shapes have the
same padded domains (D, Q, S 2^19; Kv 2^17; F 2^21), so their counts are
identical.

`count.py` reproduces the measured sizes exactly from `shape.rs`
(`a_plane_doms`, `lookups_per_position`, `helpers`, `h_plane_doms`, LowH24,
non-DD, two softmax remainder limbs):

| | `A` words | `H` words | lookup words |
|---|---:|---:|---:|
| R13 now (measured, M4l PB-TIMING) | 74,989,568 | 71,925,760 | 64,258,048 |
| R13 now (counted) | 74,989,568 | 71,925,760 | 64,258,048 |
| **W16 (counted)** | **42,057,728 (−44%)** | **41,713,664 (−42%)** | **31,752,192 (−51%)** |

## The construction

**One tagged range table.**
- A lookup carries a width `w` as well as its linear form `Σ c_i·plane_i + cst`.
- The verifier draws a challenge `γ` with `α`, after `A` is committed.
- A query folds to `q + γ·w`. The table holds `v + γ·w` for every used width
  `w` and every `0 ≤ v < 2^w`.
- One more entry kind holds the symmetric int8 range `S8 + 127 ∈ [0, 254]`.
- One sum claim covers everything, as today.

**Sub-tables of exactly one row width.**
- The table is laid out as `Dom::Tab` planes of `2^log_cols` entries each:
  - width 16: 4 sub-planes at T128 (`log_cols = 14`), 2 at T256;
  - width 15: 2 sub-planes at T128;
  - the small widths: packed into one sub-plane.
- So `log(Dom::Tab) == log_cols` still holds. The privacy argument's lift
  condition (`layout.rs`, `domain_log_at`, ruling S-1) is unchanged.
- A single 2^16-entry table would sit above the T128 row width. That would
  reopen the argument's corollary on the bilinear slots, so it is not proposed.
- Padded positions of a sub-plane repeat an entry of the same width with
  multiplicity 0. This is P-3's rule, per sub-plane.

**Words are looked up directly.**
- A signed 16-bit word (`X, Y, AO, X1, YM, Z16, X2, Q8, QR8, O8, K8, V8, KR8, U16`)
  is one width-16 query on `word + 32768`. It needs no limb plane and no
  decomposition relation.
- A 24-bit signed word (`H16` at LowH24) keeps one committed top limb `t`:
  - one width-8 query on `t`;
  - one width-16 query on `H16 + 2^23 − 2^16·t`.

**Remainders.**
- A remainder of `b ≤ 16` bits is one plane and one width-`b` query.
- A remainder of `16 < b ≤ 24` bits is two planes `(lo, t)` and two queries:
  `lo` at width 16 and `t` at width `b − 16`.
- The full 24-bit norm remainders (`NR, NS, MR, MS`) take `t` at width 8.

## Group by group (LowH24 at the tested calibration)

| Domain | Group | Bits | R13 planes / queries | W16 planes / queries |
|---|---|---|---|---|
| D | X, Y, AO, X1, YM, Z, X2 (words + 2 limbs each) | 16 | 7 + 14 / 14 | 7 / 7 |
| D | NR, NS, MR, MS | 24 | 12 / 12 | 8 / 8 |
| D | RAL (ao) | 21 | 3 / 4 | 2 / 2 |
| D | RDL (down) | 20 | 3 / 4 | 2 / 2 |
| Q, Kv | Q / K, QR / KR, O / V (words + 2 limbs each) | 16 | 3 + 6 / 6 | 3 / 3 |
| Q, Kv | RQL / RKL (q, k) | 15 | 2 / 3 | 1 / 1 |
| Q, Kv | RO (pv) / RVL (v) | 12 / 16 | 2 / 3 | 1 / 1 |
| Q, Kv | RQRL / RKRL (rope) | 7 | 1 / 2 | 1 / 1 |
| F | G8, A16 (words, no byte lookup) | — | 2 / 0 | 2 / 0 |
| F | U16 + UL | 16 | 1 + 2 / 2 | 1 / 1 |
| F | RU (up) | 12 | 2 / 3 | 1 / 1 |
| F | RGL (gate shift) | 20 | 3 / 4 | 2 / 2 |
| F | H16 + HL | 24 | 1 + 3 / 3 | 1 + 1 / 2 |
| F | RH | 16 | 2 / 2 | 1 / 1 |
| S | S8 (symmetric int8) | — | 1 / 2 | 1 / 1 |
| S | ZSEL, E | — | 2 / 0 | 2 / 0 |
| S | RSL (score) | 18 | 3 / 4 | 2 / 2 |
| S | P + PL | 13 | 1 + 2 / 3 | 1 / 1 |
| S | SR, SG (wrho_s ≤ 16) | ≤ 16 | 4 / 6 | 2 / 2 |
| L | LIMB, LIMBM | 8 | 2 / 2 | 2 / 2 |

The DD profiles move P, SR and SG to `Dom::Dd`; the same mapping applies there.

## What it should buy (estimate)

The domain zero-checks (slots 14 to 18) read one table per `A` plane and one
per `H` helper on their domain. W16 cuts those tables by 42–57%:

| Zero-check | D | Q | Kv | S | F |
|---|---:|---:|---:|---:|---:|
| Tables read, now → W16 | 56 → 29 | 21 → 9 | 21 → 9 | 22 → 12 | 24 → 14 |

The estimate scales each M4l phase by its count ratio, on the instrumented run
(0.807 s wall):
- commitments, inverses and openings save 0.122 s;
- the five domain zero-checks go from 0.249 s to 0.132 s;
- in total, **about 0.24 s saved, ×1.42 per block**. The warm 0.656 s block
  would take about 0.46 s.

Receipts shrink with the rows: column openings carry every row, so their size
falls by roughly 43%. None of this is measured.

## Soundness points for the review

1. **Range.**
   - A width-`w` query proves its linear form lies in `[0, 2^w)`.
   - The decompositions remain:
     - for 24-bit values: `lo + 2^16·t`, with `lo` and `t` each range-checked;
     - for 16-bit words: `word + 32768` directly.
   - So each value's admitted set equals R13's.
   - Removing a limb plane also removes its recomposition relation. The
     relation becomes the query's linear form itself.
2. **Tag folding.**
   - `q` is fixed by `A` before `γ`. An out-of-range query collides with a
     table entry of another width only if `γ = (q − v′)/(w′ − w)`.
   - That is at most `N_tab` values of `γ`, so the probability is
     `≤ N_tab/p²`, with `N_tab ≈ 2^17`.
   - Without `γ`, fixed offsets would be unsound: `q = v′ + (w′ − w)·offset`
     is a value the prover can commit.
3. **LogUp bound.**
   - LogUp's error grows with table entries plus queries, over `p²`.
   - The range table grows from hundreds of entries to about 2^17.
   - The queries (about 2^25 under W16, 2^26 now) dominate either way, so the
     soundness bits barely move.
   - The review recounts the exact terms (R14's
     `(N + 4·T_d − 1)/p²` accounting).
4. **Padded table entries.** P-3's rule ("padded TABLE positions repeat an
   existing entry"), per sub-plane and per width. A width-13 sub-table padded
   to 2^14 must repeat width-13 entries only.
5. **Multiplicities.** One histogram plane per sub-plane. They are committed
   in `A` before every LogUp challenge, as MU8 is today (B-2).

## Privacy points

- Helper and multiplicity planes are committed and opened only through masked
  claims, as today. The sub-tables keep the lift condition.
- The privacy statements must be re-checked for the new plane list before any
  receipt uses the profile (D54).

## Plan (each stage keeps every existing profile byte-identical)

1. **Census.** A test that builds both layouts' counts from the code and
   asserts the table above.
2. **Table generalization.**
   - `Lk` gains a width tag.
   - The range table becomes a set of sub-planes.
   - Legacy and R13 use one width-8 table with no `γ` absorb, so their bytes
     stay the same (golden 8/8, the trained digests).
3. **W16 layout and witness.**
   - The `AccuracyIds` groups at the new counts.
   - The `shape.rs` plane, lookup and helper lists for the profile.
   - 16-bit decompositions.
   - Per-sub-plane histograms.
4. **Relations and verifier.** The decomposition identities in the domain
   zero-checks; the table slot over several sub-planes; the sum claim.
5. **Evidence.**
   - An honest proof verifies.
   - Malicious controls are refused:
     - a limb out of range;
     - a query moved to another width;
     - a non-repeating table pad;
     - a histogram moved to a padded copy.
   - CPU and Metal digests are equal.
   - The Metal IR covers the new zero-checks.
   - Measured times and receipt size.
6. **Independent review** (D24 class), then the privacy re-check.

## A second, separate lever seen while counting

Padding costs another large share:
- Shieldstral's feed-forward width 9,216 is padded to 16,384, and its model
  width 3,072 to 4,096.
- The F domain alone is 44% padding: about 6.4 M of W16's 31.8 M lookup words.
- 8B pads only F (14,336 → 16,384, 12.5%).

Non-power-of-two domains (a split such as 8,192 + 1,024, or rows that are known
zeros) would be a further protocol change. It is not part of W16.
