# W16: 16-bit range-check limbs for the R13 accuracy block (design, D54)

Status (2026-10-31 evening): **built as opt-in profiles and measured; not
reviewed.** Victor approved this direction on 2026-10-31 (D54). It is a new
proof format, built as separate profiles beside R13/R14 (`W16_RUNG_H24`,
`W16_SHIELD_T128_H24`, `W16_8B_T128_H24` in the gpu-metal tree, commits
9fcdac0c, 81291f49, 8416be7a). No existing profile changes a byte: the
development-shape digests, the trained R13 digests, the R13 run and golden
8/8 are unchanged (`logs/w16_gates.log`, `logs/tab/chain.log`).

**Measured** [Metal prove core, T128, warm passes n=3, shared Mac]:

| Block | R13 | W16 | |
|---|---:|---:|---:|
| Shieldstral | 0.654–0.667 s | 0.469–0.507 s | ×1.39 |
| Llama-3-8B | 0.605–0.631 s | 0.467–0.482 s | ×1.30 |
| Shieldstral, CPU only | 3.70 s | 1.54 s | ×2.4 |

Counted words at both trained shapes: `A` 40,976,384 (0.546 of R13), `H`
42,631,168 (0.593), lookups 32,276,480 (0.502). The first W16 build was ×1.2.
The table-helper slot then held 15 triples on the CPU (0.18 s); its device IR
(8416be7a) brought W16 to the estimate below.

Evidence for the review:
- the W16 rung core proves and verifies, and a changed root is refused;
- seven cheating-prover range attacks are rejected by the verifier;
- the W16 IR equals its closures at every redefined slot and group count;
- CPU and Metal digests are equal at both trained W16 shapes.

Still open: a run profile and receipt registration, the DD variants and the
privacy re-check (D54).

**Independent review, 2026-11-01** (`REVIEW_W16_20261101.md`, a separate reviewer agent, read-only; it ran only an
exact-arithmetic recount):
- **Verdict:** sound as built for the registered non-DD LowH24 profiles; nothing broken, no constraint dropped.
- **LogUp bound:** 2^-102.92 per block, against R13's 2^-102.00 under the same accounting; for a 32-block 8B run,
  2^-97.92.
- **Findings:**
  - **F1 (Medium) — FIXED 2026-11-01.** The R2-a / R2-4 name guards keyed on `TRAINED_CALIBRATION_PROFILES`, which
    excludes the W16 strings, so a non-door shape under a W16 string got past both. One predicate,
    `shape::is_trained_profile_string`, now serves both sites. Test
    `w16_review_f1_a_non_door_shape_under_a_w16_profile_string_is_refused`; gates in
    `results/zk60_metal_20261031/logs/m19g`.
  - **F2 (Low) — FIXED 2026-11-01.** `Layout::for_shape` refuses, by name, any lookup domain whose declared helper
    count is not ceil(lookups/2). This applies at every profile, and every registered shape passes
    (`results/zk60_metal_20261031/logs/m20g`).
  - **F4 (Low) — FIXED.** The tag test checks every actual `TAG_*` constant for distinctness and keeps 200..=224
    reserved for the range families.
  - **Still open (Low / Info):**
    - F3: three planned malicious controls missing (a moved width, a non-repeating pad, a histogram in a padded
      copy), plus single-limb and word overflow;
    - F5–F7: W16 DD paths untested, an RH-width literal unasserted, wording.
- **For the privacy re-check:** the 16-bit range histograms (12 multiplicity planes in A and their helpers in H at
  T128) are a much finer view of the hidden activations than the byte histograms, and must be listed.

**Where a W16 block's time goes** [MEASURED, one instrumented Metal pass, `logs/g_phases2.log`, 0.578 s wall against
R13's 0.807 s]:
- **Zero-checks:** F (slot 18) 0.072 s and D (slot 14) 0.054 s. Each is about half table building (0.031 / 0.019 s,
  copying committed planes into device tables) and half masked sumcheck.
- **Commitments:** `A` 0.051 s and `H` 0.045 s.
- **Small slots:** the nine matmuls 0.054 s together; the norm row sums and limb check 0.042 s.
- **Openings:** 0.044 s.
- **The rest:** the IO endpoints 0.029 s; the exp/activation helper inverses 0.020 s; the table slot 0.008 s.

A `sample` of eight warm passes shows the prover thread waiting on the GPU (sumcheck rounds) and on rayon (table
builds) for most of its time. The byte-identical candidate it points to: have the first sumcheck round read the
committed planes in place instead of copying them into extension-field tables (about 0.05 s, estimated).

**Next levers after W16, ranked** (estimates against the 0.578 s instrumented block, not measured):
1. **TRIED, NO GAIN (M5a, 2026-11-01).** The plain-store plane tables were gathered on the device from the hiding
   commitments' resident data rows. It was byte-identical (61/0 unit tests, dev-shape bytes, trained digests, R13
   run, golden 8/8), but an A/B on one binary showed no gain [MEASURED, n=3 warm each, back to back, same conditions]:
   - all table builds: off 0.121 s, on 0.131 s;
   - warm prove core: off 0.565-0.592 s, on 0.580-0.628 s;
   - slot 18's build alone went from 0.037 to 0.029 s, and the per-slot dispatch overhead cancelled that out.

   Plane copies are therefore a small part of table building; eq tables and public copies dominate. Reverted; the
   diff is kept at `results/zk60_metal_20261031/m5a_plane_gather_negative.patch`, the A/B logs at
   `results/zk60_metal_20261031/logs/m5a/`. The next measurement is per-kind timing inside the table builds.

   *Superseded wording:* **Byte-identical: the first sumcheck round reads committed planes in place**, instead of copying each into an
   extension-field device table. About 0.05 s: slots 14 and 18 spend 0.050 s building tables.
2. **Byte-identical: the matmul slots' public weight folds on the GPU.** About 0.025 s: nine slots of 4-16 ms each,
   mostly an exact i8 transposed matrix-vector fold that is already parallel and deferred on the CPU. The verifier
   keeps the CPU fold; field addition is exact, so the order does not move a byte.
3. **Protocol: non-power-of-two domains.** About 10% at Shieldstral (its F axis is 44% padding), about 3% at 8B.
   Needs a ruling.
4. **Protocol: LogUp-GKR in place of the committed helpers.** After W16 the helpers cost about 0.13 s (commit,
   inverses, opening and their share of the zero-checks). A GKR proof adds about 25 masked layer sumchecks, roughly
   0.05-0.08 s on the GPU, so the net is about x1.1-1.2. That is smaller than the x1.37-1.57 the 2026-10-30 gap
   study priced before W16. Needs a zero-knowledge design (root blinding, masked layers) and a ruling. The standalone
   CPU prototype the explorer was handed (`research/zkp-efficiency/handoffs/20261030-deepprove-gap.md`) was never
   run: the explorer needs bubblewrap and is not installed on the Mac.

The sections below are the design as written before the build. Its counts and
estimate are what the measurements above check.

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
- A 24-bit signed word (`H16` at LowH24) keeps one committed, **signed** top
  limb `t = floor(H16 / 2^16)` in `[−128, 127]`:
  - one byte query on `t + 128`;
  - one width-16 query on `H16 − 2^16·t`.

  Together these prove `H16 + 2^23 ∈ [0, 2^24)`, as R13's three byte limbs
  do. The top is signed so that a padded position, where the pad rule holds
  both `H16` and `t` at zero, still hits both tables. An unsigned top would
  give `0 + 2^23 − 0`, outside the 16-bit table.

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
| S | S8 (symmetric int8) | — | 1 / 2 | 1 / 2 (kept: its two byte queries; a dedicated sym8 table would save one) |
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
