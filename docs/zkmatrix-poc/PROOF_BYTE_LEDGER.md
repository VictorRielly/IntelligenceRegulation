# The proof byte ledger — what the verifier must receive, counted to the byte

U-AG tranche, byte-ledger lane (PROGRESS_UAG.md, Agent GB; audit
2026-07-14 REMEDIATION_PLAN Phase 3 items 1-3 and 5). Written
2026-07-16 at e4cd608, paper-only. This document is the acceptance
yardstick for the Phase 3 aggregation effort: any candidate design
(AGGREGATION_LITERATURE.md, the GA lane) is priced against the numbers
here, and the tranche's exit gate (Section 5) asserts against them.

Every number is one of:

- **[MEASURED]** — a value recorded in this repo (cited inline:
  file + section/row), or
- **[DERIVED]** — my arithmetic on code-defined struct shapes and
  codec widths (cited to file:line), never a new measurement.

The one standing convention: **the proof is what the verifier
RECEIVES.** The monolithic harness constructs each wave's
`CtRoundProof`, verifies it, and drops it
(`ffn_layer_run`, zkmatrix-rs/src/bin/ring_matmul.rs — the wave loop
builds `proof_w` via `prove_ct_round` and drops it after
`verify_ct_round`); the audit's C-03 ruling
(codex-audit-2026-07-14/FINDINGS.md) is adopted verbatim: streaming
those objects to disk or network does not remove their wire bytes, and
GPU acceleration does not change the number of transmitted responses.

## 0. The shapes and widths everything below is built from

Commitment shape, both the layer rig and the P3 flagship
(ring_matmul.rs: `CS { kappa: 8, n_r: 26, msg_r: 8 }`; ring/commit.rs
`CommitShape`; audit C-03 uses the same): kappa = 8, n_r = 26,
msg_r = 8, ring dimension D = 128, q < 2^31 (q31 class).

Canonical wire widths — from the ONLY canonical codec the repo has,
the U-S P3 codec (PROGRESS_US.md P3-D2; ring_matmul.rs
`p3_encode_proof`/`p3_decode_proof` + `P3W`/`P3R`):

| item | encoding | bytes | source |
|---|---|---:|---:|
| field coefficient | u32, canonical `< q` checked | 4 | `P3W::poly` / `P3R::poly` |
| response coefficient | i64 | 8 | `P3W::i64v` |
| K-field limb (descents) | u64 (16 limbs/K-element = 128 B) | 8 | `us1_put_kelem` (ring_matmul.rs:9554) |
| revealed partial scalar | 12 B each on the wire | 12 | `LayerCost::reveal_shares` doc (ring_matmul.rs:15584) |
| length prefix | u32 LE | 4 | `P3W` |

Derived unit costs **[DERIVED** from those widths]:

| unit | formula | bytes |
|---|---|---:|
| one poly (D coeffs) | 4 + 128 x 4 | 516 |
| one commitment identity t1 + t2 | 2 x (4 + 8 x 516) | 8,264 |
| one opening: z response | 4 + 26 x (4 + 128 x 8) | 26,732 |
| one opening: w1 mask image | 4 + 8 x 516 | 4,132 |
| **one opening total (z + w1)** | | **30,864** (~30.1 KiB) |
| one linear ct-claim (h + w_claim) | 2 x 516 | 1,032 |
| one quad ring claim (gr pair + w_qring) | 3 x 516 | 1,548 |
| one K-element (descent wire, as shipped) | 16 x 8 | 128 |

The audit's C-03 table priced the same two opening arrays at 8 B per
coefficient ("fixed-width current-type accounting", TEST_EVIDENCE.md
"Performance evidence" section): z 26,624 + w1 8,192 = 34,816 B
(~34.0 KiB/opening, the figure WAVE_SHARE_MASKING_DESIGN.md 6.3
reuses). The canonical codec writes w1 coefficients as u32, so the
canonical per-opening cost is 30,864 B — **11.3% below the audit's
width assumption**. That correction cuts the other way in Section 1:
the audit's subtotal excluded components that more than make up the
difference.

Proof-object shape (what a `CtRoundProof` carries per wave —
ring/ct_engine.rs:389-410): per plain commitment one `z` (n_r x D
i64) and one `w1` (kappa x D field elements); per linear ct-claim one
reveal poly `h` and one mask-image poly `w_claim`
(ct_engine.rs:666-681); per untwisted quadratic ring claim the
garbage pair `gr = (G1, G0)` plus `w_qring` (ct_engine.rs:399-400).
The layer rig's waves use exactly three claim classes: pin ct-claims,
zeta ct-claims with public scalar 0 (the post-Z1 ForcedZero form,
wave loop ~ring_matmul.rs:16756-16770), and one Hadamard
`QuadRingClaim` per value chunk (`quads_loc` capacity `c1 - c0`,
~16736). Ajtai/digit sections are empty on this path (`prove_ct_round`
called with `&[]` ajtai/digits).

### 0.1 Calibration: the model reproduces every measured artifact

Before using the unit costs above at scales nobody has serialized, they
are pinned against everything the repo HAS serialized or recorded:

**P3-EXIT whole files** (PROGRESS_US.md P3-EXIT, canonical statement +
proof bytes, [MEASURED]) vs this ledger's bottom-up sum of the same
components (`P3Layout` at `p3_layout`, ring_matmul.rs:10043; descent
K-element counts from `masked_transcript_totals`,
ring/gkr_masked.rs:1240, at the shipped 128 B/K-element):

| shape | n_commits [DERIVED] | modeled proof bytes | measured file | gap |
|---|---:|---:|---:|---:|
| 2^12 (dw 14) | 24 | 1,049,129 B = 1024.5 KiB | 1025 KiB | < 0.05% |
| 2^13 (dw 15) | 33 | 1,410,178 B = 1377.1 KiB | 1378 KiB | < 0.07% |
| 2^14 (dw 16) | 50 | 2,084,767 B = 2035.9 KiB | 2036 KiB | < 0.01% |
| 2^15 (dw 17) | 83 | 3,385,920 B = 3306.6 KiB | 3307 KiB | < 0.02% |

(The sub-KiB remainder in each row is the statement file — the
Statement v3 codec at the P3 shape is a handful of entries with 32-B
digests, manifest.rs `CommitmentEntry`.)

**IA-4 masked-descent B/el rows** (PROGRESS_UZ1.md IA-4, [MEASURED])
vs the analytic descent + reveal arithmetic (`masked_pass_bytes`,
gkr_masked.rs:1250, which models 64 B/K-element, plus 12 B x 9W
reveals):

| shape | analytic (descents + reveals)/el | IA-4 measured |
|---|---:|---:|
| 2^16 (dw 17, 43 waves) | (64,000 + 4,644)/65,532 = 1.047 | 1.047 |
| 2^18 (dw 19, 168 waves) | (74,624 + 18,144)/262,140 = 0.354 | 0.354 |
| 2^20 (dw 21, 670 waves) | (86,272 + 72,360)/1,048,572 = 0.151 | 0.151 |

Exact to three digits at every shape. The unit-cost model is therefore
trusted for the extrapolations in Sections 1-2. Note the honest
discrepancy it surfaces: **the shipped descent wire (`us1_put_kelem`)
writes 8 B/limb = 128 B/K-element, while the LKP-7/S2/IA-4 ledger
accounts at 64 B/K-element** (4 B/limb — sufficient, since every limb
is a canonical q31 coordinate). Both figures are carried below,
labeled.

**Audit C-03 opening counts** ([MEASURED] in
codex-audit-2026-07-14/FINDINGS.md C-03 table): at the measured 2^20
shape, 50,197 data + 38,050 g = 88,247 plain openings across 670
waves. Re-derived from code, exactly: n_el = 2^20 - 4 = 1,048,572;
X groups nx = ceil(n_el/1024) = 1,024; SiLU material = m + blinders +
witness-mask chunks + table-mask chunks = 2 + 15 + 4 = 21
(`mask_coeff_counts` at dw 21/dt 9 gives 956 and 230 K-elements ->
`kel_cms` 15 and 4, ring_matmul.rs:15241-15247); Y/UP/Z slot
commitments = 3 x 16,384 = 49,152; total data = 1,024 + 21 + 49,152 =
**50,197** — the audit's number to the digit. g-groups: a full
triple wave (25 triples = 75 data commitments at cap 75) carries
9 pins + 48 zeta + 25 x 8 x 2 = 400 R1 pads = 457 g-slots -> 58
groups (`r1_pad_count`, ct_engine.rs:541; UR1_PIN_COPIES = 9,
l_zeta = 24, 9 + 2 x 24 = 57 asserted at ring_matmul.rs:17495);
655 full + 1 partial triple wave + 14 X-material waves x 2 groups
gives ~38,046 ~ **38,050** g. Wave count 655 + 1 + 14 = **670** —
the measured wave count (PROGRESS_UZ1.md IA-4).

## 1. The component ledger at the measured 2^20 shape

The CURRENT proof, shipped mode: the post-Z1 masked layer rig
(`masked = true` is "the U-Z1 shipped mode", ring_matmul.rs:15596;
unmasked is the legacy [Z1-a] exhibit only). One 2^20 layer statement
(Lookup + Hadamard arm A), 670 waves + 1 closing round, all in the
canonical P3 widths of Section 0.

Object counts at this shape:

- openings: 88,247 pre-Z1 (audit C-03) + 670 shared-pad openings (one
  per pin-bearing wave, WAVE_SHARE_MASKING_DESIGN.md 2.2 rule 2;
  every wave is pin-bearing — reveals 6,030 = 9 x 670, IA-4) + 8
  closing-round openings (6 pad commitments + 2 closing g-groups,
  IA-4 / design 6.1) = **88,925** [MEASURED counts, DERIVED sum].
  The design-6.3 "+~506 cap-step g openings [MODEL]" never
  materialized: IA-4 measured the wave count unchanged at 670 (the
  cap term never bound).
- commitment identities on the wire: 50,197 data + 6 pads + 38,050
  wave g + 2 closing g = **88,255**.
- linear ct-claims: 9 pins x 670 + 48 zeta x ~656 chunk waves =
  6,030 + 31,488 = **37,518** + 9 closing zero-sum claims
  ([DERIVED]; cross-check: S2's pre-Z1 reveal ledger implies ~37,550
  linear claims — within 0.1%).
- quadratic ring claims (Hadamard): one per value chunk = **131,072**
  ([DERIVED from the wave loop]; exact, chunks = ceil(n_el/8)).
- masked descent pair: ONE per layer (witness dw 21 + table dt 9;
  "ONE masked descent pair", ring_matmul.rs:15591-15594) = 1,348
  K-elements ([DERIVED] via `masked_transcript_totals`).
- reveals: **6,030** x 12 B (IA-4, [MEASURED]).

### The ledger

| # | component | count x unit | bytes | MiB | share |
|---|---|---|---:|---:|---:|
| 1 | ct-opening responses `z` | 88,925 x 26,732 | 2,377,143,100 | 2,267.0 | 63.97% |
| 2 | ct-opening mask images `w1` | 88,925 x 4,132 | 367,438,100 | 350.4 | 9.89% |
| 3 | commitment identities `t1 + t2` | 88,255 x 8,264 | 729,339,320 | 695.6 | 19.63% |
| 4 | linear-claim layer `h + w_claim` | 37,527 x 1,032 | 38,727,864 | 36.9 | 1.04% |
| 5 | quad-claim layer `gr + w_qring` | 131,072 x 1,548 | 202,899,456 | 193.5 | 5.46% |
| 6 | masked descent pair (shipped 128 B/kel) | 1,348 kel + framing | 173,796 | 0.166 | 0.005% |
| 7 | pin reveals (post-Z1) | 6,030 x 12 | 72,360 | 0.069 | 0.002% |
| 8 | statement (v3 codec) | ~10 entries | ~2,048 [DERIVED] | 0.002 | ~0% |
| 9 | per-round framing/empty sections | 671 x ~64 | ~43,000 | 0.041 | 0.001% |
| | **TOTAL — one 2^20 layer proof** | | **3,715,839,044** | **3,543.7** | **100%** |

**3,715,839,044 B = 3,543.7 MiB = 3.46 GiB = 14,175x the 256 KiB
budget** (262,144 B; budget convention in Section 3).

Rows 1+2 (the openings, 73.86%) are the audit's subject; rows 3-5
(25.1%, ~926 MiB) are real wire bytes the audit's table explicitly did
not count.

### Reconciliation against the audit's 2.86 GiB table

Audit C-03 (codex-audit-2026-07-14/FINDINGS.md, table row "measured
2^20"; arithmetic reproduced in TEST_EVIDENCE.md): z 2,240.65 MiB +
w1 689.43 MiB = **2,930.08 MiB** for 88,247 openings at 8 B per
coefficient. Verdict: **confirmed as exact arithmetic on its stated
widths and counts** — this ledger reproduces 50,197 + 38,050 = 88,247
from code independently (Section 0.1). Two corrections in opposite
directions convert it into the canonical-wire number:

| adjustment | delta |
|---|---:|
| audit subtotal (z + w1, 8 B fixed width, 88,247 openings) | 2,930.08 MiB |
| w1 at the canonical u32 width (+ codec prefixes) | -332.6 MiB |
| post-Z1 pad/closing openings (+678 openings) | +20.0 MiB |
| **canonical openings subtotal (rows 1+2)** | **2,617.4 MiB** |
| + commitment identities (row 3, NOT in audit table) | +695.6 MiB |
| + claim layer (rows 4+5, NOT in audit table) | +230.4 MiB |
| + descents/reveals/statement/framing (rows 6-9) | +0.3 MiB |
| **canonical complete artifact** | **3,543.7 MiB** |

Net verdict: the audit's headline UNDERSTATES the true canonical
artifact by ~21% (2,930 -> 3,544 MiB), even though its width
assumption overstated the arrays it did count by ~11%. The audit
itself flagged the exclusions ("This still excludes h, claim masks,
quadratic proof fields, public commitments, masked descents, partials,
framing, and the statement" — C-03); this ledger prices them.

Components the audit's table did NOT count, now priced:

1. **Commitment identities (695.6 MiB, 19.6%)** — the single largest
   omission. The verifier cannot derive commitments; the P3 format
   carries them in the proof (`P3Proof.t1s/t2s`,
   ring_matmul.rs:10306-10312). Every g-group and pad commitment is
   an identity too.
2. **The quadratic claim layer (193.5 MiB)** — 3 polys per Hadamard
   chunk claim (R1 masking garbage pair + linear mask image).
3. **The linear claim layer (36.9 MiB)** — h + w_claim per pin/zeta
   claim; the post-Z1 zeta claims still send their masked reveal
   polys even though their 12-B scalars left the wire (design 2.4
   deletes the scalar wire, not the claims).
4. Masked descents, reveals, statement, framing (~0.3 MiB combined —
   genuinely negligible at this shape, which is exactly why the
   pre-C-03 reports mistook their sum for "the transcript").

### Scale-check: do the P3-EXIT measured files extrapolate to this?

Yes — same unit costs, different object counts. The P3 flagship is a
SINGLE ct-round over 24..83 commitments with 9 claims; its measured
files (1025..3307 KiB) are reproduced to <0.07% by the same per-object
prices that give 3,543.7 MiB at the 670-wave layer shape (Section
0.1). Per element, the P3 flagship reads ~256 B/el at 2^12 falling to
~103 B/el at 2^15 (fixed material amortizing); the multi-wave layer
sits at 3,715,839,044 / 1,048,572 = **3,544 B/el**. The 34x-per-element
gap is structural, not codec-level: the layer rig opens ~133
commitments per wave in EACH of 670 waves with a fresh z + w1 pair,
where the P3 flagship opens its 83 commitments once. The
audit's projection and the measured codec agree wherever they overlap;
neither is in error — the object COUNT is the problem. (The
masking-design estimate of "~137-commitment rounds", WSMD 6.4, is
133-134 by this count: 75 data + 58 g + 1 pad; immaterial.)

## 2. Scale-out: the full 512 x 11008 layer and the 32-layer pass

The audit's projection unit (C-03): one 512 x 11008 activation tensor,
n_el = 5,636,096 (~5.6e6 el). ALL numbers here are [DERIVED] from the
Section 0/1 formulas at that shape — accounting projections in the
audit's sense, NOT a claim that this box can run them (the 2^22
serialize wall and the 15 GiB box stand, PROGRESS_UZ1.md IA-4 /
PROGRESS_UR.md S2; 5.6e6 el = 2^22.4 is past the wall). Rig
parameters at this shape: dw = 24, dt = 9; nx = 5,504; chunks =
704,512; slot commitments = 3 x 88,064 = 264,192; SiLU material =
2 + 19 + 4 = 25; n_data = 269,721; waves W = 3,523 triple + 74
X-material = 3,597; g-groups = 204,460; pad commitments =
ceil(9W/1024) = 32; openings = 269,721 + 204,460 + 3,597 + 34 =
477,814; identities = 474,215.

Cross-check against the audit: 474,181 pre-pad openings x the audit's
34,816 B = 15.37 GiB — the audit's "~15.4 GiB for only these arrays"
reproduced [its linear extrapolation and this shape derivation agree
to 0.1%].

| # | component | count x unit | bytes | share |
|---|---|---|---:|---:|
| 1 | `z` responses | 477,814 x 26,732 | 12,772,923,848 | 63.98% |
| 2 | `w1` images | 477,814 x 4,132 | 1,974,327,448 | 9.89% |
| 3 | identities | 474,215 x 8,264 | 3,918,912,760 | 19.63% |
| 4 | linear claims (32,373 pins + 169,104 zeta + 9) | 201,486 x 1,032 | 207,933,552 | 1.04% |
| 5 | quad claims | 704,512 x 1,548 | 1,090,584,576 | 5.46% |
| 6 | descent pair (dw 24 + dt 9, 1,651 kel) | shipped width | 212,871 | 0.001% |
| 7 | reveals | 32,373 x 12 | 388,476 | 0.002% |
| 8-9 | statement + framing | | ~235,000 | 0.001% |
| | **TOTAL — one 512 x 11008 layer** | | **19,965,518,531 B = 18.59 GiB** | |

- **One complete FFN-layer-scale statement: 18.59 GiB = 76,162x the
  256 KiB budget.**
- **32-layer pass: 638,896,592,992 B = 595.0 GiB = 2,437,197x** (the
  audit's z/w1-only 492 GiB is inside this, C-03).

### Which component is THE wall

The shares are scale-invariant (every dominant component is linear in
el): the ct-round layer — openings + identities + claim polys, rows
1-5 — is **99.997%** of the artifact at every shape from 2^16 up. The
expected headline "ct openings ~99%+" is right if "opening" means the
whole per-commitment-per-wave round material; split finely it is:
openings 73.9%, identities 19.6%, claim layer 6.5%. All three are
O(commitments x waves) or O(chunks); all three must be aggregated —
compressing z alone leaves ~4.9 GiB at FFN-layer scale. The already-
sublinear components (descents, reveals, statement: 0.003%) are the
proof's future skeleton: a descent pair + an aggregate opening
argument + a statement is the natural post-aggregation shape.

Honest footnote on the audit unit: 512 x 11008 is ONE activation
tensor of one FFN matmul; TARGET_CONTRACT.md Section 1's workload has
three such matmuls per layer plus Hadamard/requant edges, so "32
layers x one tensor" (the audit's and this document's unit) is a LOWER
bound on the naive pass.

## 3. The 256 KiB budget, decomposed

Budget line: TARGET_CONTRACT.md Section 4 — "Proof size budget:
<= 256 KB serialized"; the 2026-07-14 audit computes against 256 KiB.
The discrepancy is recorded, unresolved, and immaterial at 5-6 orders
of magnitude (RANGE_AGGREGATION_DESIGN.md Section 0, exit 3); this
ledger uses **262,144 B (256 KiB)** — the harder reading — and every
"x-over" factor above is against it. Verifier line: **<= 2 s
single-threaded on the CPU reference machine, statement validation
included, p95 over >= 20 warm runs** (TARGET_CONTRACT.md Section 4).

### 3.1 Proposed allocation (one complete FFN-layer statement)

A budget split is a design decision; this one is a PROPOSAL sized so
that each line is achievable by at least one known succinctness
technique class, and so the sum is exactly 256 KiB. The aggregation
design round (U-AG2) may rebalance it; the TOTAL and the verifier
line may not move.

| allocation | budget | today (Section 2) | required factor |
|---|---:|---:|---:|
| statement (v3 codec, complete layer) | 8 KiB | ~4 KiB | 1x (headroom 2x) |
| aggregated openings + claim layer (rows 1+2+4+5) | 92 KiB | 16,045,769,424 B | **170,323x** |
| commitment identity binding (row 3) | 32 KiB | 3,918,912,760 B | **119,595x** |
| masked descent pair (row 6) | 108 KiB | 212,871 B (shipped width) | **1.92x** |
| aggregated claim right-hand sides (row 7) | 4 KiB | 388,476 B | **94.8x** |
| slack / framing / future edges | 12 KiB | — | — |
| **total** | **256 KiB** | **19,965,518,531 B** | **76,162x** |

Reading the table:

- **Openings + claims (170,323x).** No coefficient-width trick
  touches this: i32/varint packing of z buys ~1.75x (P3-EXIT already
  records "i32/varint packing would ~halve it"; z coefficients are
  Gaussian at sigma ~ 2^17.4 at the 134-commitment bundle
  [`derive_ct_round_params`, ct_engine.rs:293], so ~3 B/coeff is the
  entropy floor of the current object). The COUNT of transmitted
  responses must fall from ~478k openings to O(1)/O(log) — a genuine
  aggregated/recursive opening argument, which is precisely
  REMEDIATION_PLAN Phase 3 item 2.
- **Identities (119,595x).** The aggregate must bind ~474k
  commitments without shipping them — e.g. the statement carries a
  succinct binding (Merkle/hash accumulator root over the ordered
  commitment list, the `wide_digest` pattern generalized —
  commit.rs:311) and the opening argument proves consistency AGAINST
  that binding. Shipping identities is as fatal as shipping openings.
- **Descents (1.92x).** A pure codec fix: the us1 dump writes
  8 B/limb; canonical q31 limbs need 4 (Section 0.1). At 4 B/limb the
  dw 24 pair is 103.2 KiB — fits its line with <5 KiB spare, which is
  why the line is 108 KiB. NOTE, flagged for U-AG2: at the shipped
  width the pair alone is 207.9 KiB — 81% of the entire budget. And
  this allocation holds for ONE layer statement: a 32-layer PASS at
  one descent pair per layer costs 32 x 103.2 KiB = 3.2 MiB — if the
  contract budget binds the whole pass (TARGET_CONTRACT Section 3-4
  read together), cross-layer descent aggregation/folding is ALSO
  mandatory, not optional.
- **Reveals (94.8x).** 12 B x 9 x W is linear in waves; at FFN-layer
  scale the post-Z1 pin reveals ALONE (379.4 KiB) already exceed the
  whole budget. The aggregate must replace per-wave right-hand sides
  with O(1) aggregated claims — which the Z1 privacy constraint
  independently demands (Section 4, R3). Bytes and privacy point at
  the same design move.

### 3.2 The verifier budget's implication

Measured verify at 2^20: 187.4 us/el = 196.5 s (U-R S2 arm-A row,
reproduced in codex-audit-2026-07-14/TEST_EVIDENCE.md "Performance
evidence"; [NOISY-SHARED]) — **~98x over the 2 s budget at 2^20**, and
linear extrapolation to 5.6e6 el gives ~1,056 s, **~528x over**. The
rule this forces:

> An aggregation candidate that emits 0 proof bytes but leaves the
> verifier re-running the per-wave opening checks (88,925 checks at
> 2^20; 477,814 at FFN-layer scale, each an A1 x z matvec + norm
> check) FAILS Phase 3. Verifier work must be sublinear in
> (commitments x waves) — polylog or O(sqrt) class — not just the
> wire bytes.

Corollary for the candidate survey (GA lane): "verifier cost" is a
first-class pricing axis, equal to proof bytes, exactly as
REMEDIATION_PLAN Phase 3 says ("selected by proof-size and
verifier-cost MODELS, not prover time").

### 3.3 A resource-budget corollary nobody has stated yet

The C-04 fix gave the P3 decoder a total-resource cap:
`P3_MAX_TOTAL_SCALARS = 1 << 30` (ring_matmul.rs:10721). The honest
2^20 layer artifact fits (~0.63e9 charged scalars [DERIVED]). The
honest FFN-layer-scale LINEAR artifact does not: its z scalars alone
are 477,814 x 3,328 = 1.59e9 > 2^30. **The current security posture
and the current proof shape are already incompatible at target scale:
either the resource cap would have to be raised to admit a 18.6 GiB
"proof" (wrong direction), or the proof must shrink to fit the cap
(the Phase 3 direction).** The aggregate artifact must fit under the
EXISTING total-scalar discipline without raising it.

## 4. Requirements sheet — the Phase 3 exit test

An aggregation design/implementation closes Phase 3 only when every
box below is checked. Sources: REMEDIATION_PLAN.md Phase 3 items 1-5
+ exit line; TARGET_CONTRACT.md Section 4; WAVE_SHARE_MASKING_DESIGN.md
Sections 7.1 and 6.3; RANGE_AGGREGATION_DESIGN.md Section 0 exit 3;
PROGRESS_US.md P3-D2/D4.

- [ ] **R1 — bytes, analytic.** A written size model (this document's
  unit-cost style, every constant cited) shows the COMPLETE artifact —
  statement + commitment binding + aggregated openings + claim
  aggregation + descents + any reveals — at
  **<= 262,144 B at the complete-FFN-layer scale (512 x 11008,
  5.6e6 el)**, with the 32-layer-pass number also stated and the
  budget's pass-vs-layer scope decided and recorded (Section 3.1
  descent note). Analytic FIRST: "analytic <= 256 KiB path required
  BEFORE any production serializer" (REMEDIATION Phase 3 item 3 and
  PROGRESS_UAG.md header).
- [ ] **R2 — verifier.** Verifier model and (once built) measurement:
  **<= 2 s single-threaded p95, statement validation included**
  (TARGET_CONTRACT Section 4). Verifier work sublinear in
  commitments x waves (Section 3.2); no per-wave opening re-checks.
- [ ] **R3 — Z1 privacy.** The aggregator does NOT re-expose per-wave
  right-hand sides: "any future aggregation scheme (Phase 3) must
  PRESERVE the pad structure or re-derive the privacy argument —
  an aggregator that re-exposes per-wave right-hand sides undoes Z1"
  (WAVE_SHARE_MASKING_DESIGN.md Section 7.1). Concretely: no
  per-wave sigma values, no per-wave functional images of private Y
  coefficients on the wire; the Z1 simulator argument (design
  Section 3) must extend to the aggregated transcript, and the
  rank/recovery battery class (design Section 5) must have an
  aggregated-transcript analogue.
- [ ] **R4 — canonical encoding discipline.** The aggregate codec
  extends the P3 discipline unchanged (PROGRESS_US.md P3-D2/D4;
  audit C-04): versioned magic, LE length-prefixed fields, absolute
  caps AND bytes-remaining guards on every length, canonical `< q`
  coordinates rejected-not-reduced, ONE total resource budget at or
  below the existing `P3_MAX_TOTAL_SCALARS` (Section 3.3), trailing
  bytes rejected, panic-free decode under the malformed-input fuzz
  battery, and the statement decoded from its OWN file — proof bytes
  never choose the proposition.
- [ ] **R5 — soundness reduction, reviewed.** A written soundness
  reduction for the aggregated opening argument (knowledge error
  stated, extraction argument in the Q4_LEMMAS transcription style),
  reviewed independently — Phase 3's exit line is "meets the byte
  and verifier budgets **with a reviewed soundness reduction**"
  (REMEDIATION_PLAN.md), and the standing independent-cryptographer
  review obligation (Phase 2.5; WSMD Section 7.7) covers the new
  composition.
- [ ] **R6 — the hard budget gate is in the suite.** Section 5's test
  exists, runs fail-closed, and is green — it is the fail-closed
  security exit 3 of RANGE_AGGREGATION_DESIGN.md Section 0 ("checked
  fail-closed on the serialized artifact ... gates any full GPU
  backend"). A freeze row may pin its constants for reproducibility
  but green freeze output closes nothing (Section 0's M-02 rule).

## 5. The hard budget-test spec (audit Phase 3 item 5)

Spec only — implementation belongs to the tranche that lands the
aggregate. Two tiers, because the target shape does not run on the
15 GiB reference box (2^22 serialize wall, PROGRESS_UR.md S2 B-D2 /
PROGRESS_UZ1.md IA-4).

**Name.** `[U-AG-B1] budget-gate` (suite-permanent battery leg +
`budget-gate` subcommand).

**What it builds and serializes.** The COMPLETE artifact for one
layer statement at the gated shape, through the canonical codec —
statement.bin + proof.bin, where proof.bin contains every component of
the Section 1 ledger: all commitment identities (or their succinct
binding, post-aggregation), the aggregated opening object (today: all
670 per-wave `CtRoundProof`s + the closing round — which is exactly
why the gate is RED today), both masked descents, all claim-layer
objects, all reveals. It reuses the P3 encoder/decoder discipline and
the fresh-process `verify <statement.bin> <proof.bin>` path (P3-D3) —
the bytes asserted are the bytes a real verifier consumes, not an
accounting printout. This extends the multi-wave PARTIAL recorded at
P3-EXIT (PROGRESS_US.md): the wave orchestration must serialize into
the artifact rather than construct-verify-drop.

**Tier A — measured gate (runs in the suite).**
- Shape: the largest runnable measured shape, 2^20 arm A, masked
  (shipped mode); serialized execution, `systemd-run MemoryMax=10G`,
  per the shared-box discipline (PROGRESS_UZ1.md IA-4 method).
- Assert 1 (bytes): `statement.bin.len() + proof.bin.len() <= 262_144`
  — a hard `assert!`/process-exit failure, no warning path.
- Assert 2 (model pin): `|modeled_bytes(shape) - file_bytes| == 0`
  where `modeled_bytes` is this ledger's closed-form model compiled
  into the test — Section 0.1 proves byte-exact modeling is
  attainable. Any codec or shape drift breaks the pin loudly.
- Assert 3 (verifier): fresh-process verify wall-clock p95 <= 2 s
  single-threaded over >= 20 warm runs at the gated shape
  (TARGET_CONTRACT Section 4 statistic; p50 reported alongside).
- Assert 4 (decode discipline): the artifact round-trips through the
  bounded decoder under the existing total-resource cap (R4).

**Tier B — analytic gate (same test binary, no big run).**
- Evaluates the pinned model (validated byte-exact by Tier A/Assert 2)
  at 512 x 11008 and at 32 x that layer; asserts the layer number
  <= 262,144 B and prints the pass number against the recorded budget
  scope decision (R1).

**Status semantics.** The gate enters the suite RED (today's artifact
is 14,175x over at Tier A's shape) and STAYS in the suite; Phase 3
closes only when it is green (R6). It must not be skipped, warned, or
downgraded to a report line: the audit's Phase 3 item 5 is "keep a
hard test that FAILS when the complete artifact exceeds its budget",
and the design docs classify it as a fail-closed security exit, not a
freeze row (RANGE_AGGREGATION_DESIGN.md Section 0).

## Appendix — number provenance quick table

| number | value | source |
|---|---|---|
| openings @2^20 (pre-Z1) | 88,247 = 50,197 + 38,050 | audit FINDINGS C-03 [MEASURED]; re-derived Section 0.1 |
| waves @2^20 / FFN | 670 / 3,597 | IA-4 [MEASURED] / [DERIVED] |
| audit z+w1 subtotal | 2,930.08 MiB | audit FINDINGS C-03 / TEST_EVIDENCE |
| canonical complete @2^20 | 3,543.7 MiB | this ledger Section 1 [DERIVED] |
| FFN-layer / 32-layer | 18.59 GiB / 595.0 GiB | Section 2 [DERIVED]; audit's 15.4/492 GiB subsumed |
| P3 measured files | 1025/1378/2036/3307 KiB @2^12..15 | PROGRESS_US P3-EXIT [MEASURED] |
| masked-descent B/el | 1.047/0.354/0.151 @2^16/18/20 | PROGRESS_UZ1 IA-4 [MEASURED] |
| reveals post-Z1 | 9/wave x 12 B | IA-4 + ring_matmul.rs:15584 |
| budget | 256 KiB / KB note | TARGET_CONTRACT S4; RANGE_AGGREGATION_DESIGN S0.3 |
| verify @2^20 | 187.4 us/el = 196.5 s | TEST_EVIDENCE performance row [MEASURED, NOISY-SHARED] |
| per-opening canonical | 30,864 B | Section 0 [DERIVED from P3 codec] |
| commitments/wave | ~133 (75 data + 58 g + 1 pad) | Section 0.1 [DERIVED]; WSMD 6.4 says ~137 |
