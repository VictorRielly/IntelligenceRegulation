# Research handoff: what would cut the GPU work per W16 8B block by 1.5× (2026-11-01)

From Claude, acting as the standing researcher (D50). **Read-only analysis.** No source file edited, no cargo, no git,
no benchmark. I ran two exact-arithmetic Python scripts in the session scratchpad; every formula they used is written
out below, so nothing depends on them.

Labels:
- **MEASURED**: a number from a log or the README, with its source.
- **MODEL**: arithmetic on measured parts, or an exact count from a code formula.
- **ESTIMATE**: judgement.

## Plain summary

- **No single change gets 1.5×.** The biggest is the commitment code: rate 1/2, with each row read as polynomial coefficients (so no inverse NTT). Modelled saving: 32 ms of the commitments' 55 ms of GPU time, ×1.24 on the 0.165 s.
- **Same bits at Q = 260.** That holds if the column test is counted at the proven Reed–Solomon unique-decoding radius (BCIKS20), not at today's general-code δ/3. Without that sign-off, Q = 413 and the opening bytes grow 29%. Either way it is a new opt-in profile. The hiding proof carries over unchanged.
- **The zero-checks are the bigger half:** 76 ms, of which slots 18 and 14 are 55%. Univariate skip and small-value rounds model at 0–20%, or worse, because an extension-field round here costs only 1.7–2.7× a base-field round. Byte-preserving kernel work models at −5 to −13 ms.
- **Not GPU levers:** Merkle arity, leaf grouping and merging commitments. GPU work scales with rows × encoded width. Linear-time codes (Brakedown, Blaze, Bolt) and WHIR/Ligerito do not fit this prover.
- **A bundle reaches the target.** Commitment change + kernel work + batching the equal-size zero-checks + a non-power-of-two F domain: −51 to −64 ms. That is ×1.44–1.64 on 0.165 s, or ×1.5–1.8 on the GPU kernels alone. Without the commitment change the rest gives only ×1.15–1.28.
- **Cheapest first test:** time the existing Metal commit at rate 1/2 on the real 2,504-row shape. It needs a test-only edit.

## 0. The baseline: where a block's GPU time goes

W16_8B_T128_H24, Metal, warm. The commitments come from `results/zk60_metal_20261031/logs/m12/commit_1.log` (last
pass). The device rounds come from `logs/m13/slot_0.log` (third pass, the Gruen-off arm, i.e. HEAD's kernels). All
MEASURED.

| Part | ms per block | Note |
|---|---:|---|
| Forward NTT, A (2,504 rows, 2^14 → 2^16) | 17 | about half multiply-bound (README:811) |
| Forward NTT, H (2,606 rows) | 18 | |
| Inverse NTT, A + H (size 2^14) | 5 + 5 | |
| Column leaf hash, A + H | 3 + 3.5 | |
| Rest of the two "gpu total" clocks | 3.5 | 27 and 28 ms totals |
| **Commitments** | **55** | README M10 said about 65 before M11–M12 |
| Slot 18, F zero-check (19 tables × 2^21, degree 5) | 25.9 | "batch + replay" clock |
| Slot 14, D zero-check (36 × 2^19, degree 4) | 15.6 | |
| Slot 17, softmax (19 × 2^19, degree 4) | 8.0 | |
| Slot 15, Q (15 × 2^19, degree 4) | 6.0 | |
| Slot 19, TAB (58 × 2^14, degree 3) | 5.1 | almost all fixed cost: 2^14 entries |
| Slot 16, KV (15 × 2^17, degree 4) | 3.6 | |
| Six small slots: 00, 01, 03, 04, 21, 22 | 11.9 | 1.4–2.5 ms each, mostly fixed cost |
| **Device rounds** | **76** | the run's own counter says 0.074 s |
| Store folds, A (37 row vectors) + H (10) | 8.4 + 8.4 | **on the host CPU by default** (`hashline/src/gpu/metal.rs:687-695`) |
| Column gathers | 1 + 1 | |
| **Sum** | **≈150** | README M10 (line 783): about 165 |

Four caveats change how to read "GPU work per block":

1. The store folds run on the CPU, so the GPU kernels alone are about **131 ms** (55 + 76).
2. The round clocks are host wall clocks around a command-buffer wait. They include GPU idle time: a one-threadgroup
   transcript kernel runs between every pair of rounds (`metal.rs:2013`).
3. One process-wide command queue serves every proof thread (`metal.rs:57`, `:82`). Six proofs at once saturate at
   1/5.54 = **0.180 s per block** (README:778), which is above the 0.131–0.150 s summed. So the true GPU-busy time per
   block is **not measured**. Part of the ceiling may be queue serialisation, not kernel work.
4. I keep the README's 0.165 s as the denominator, so the 1.5× target is **≤ 0.110 s**. Each ×-figure below is also
   given against 0.150 s and 0.131 s where it matters.

## Ranked table

Proof bytes are those of the A + H openings per block. Today that is 23.3 MB [MODEL, from `OpeningZk::size_bytes`,
`zkp-core/src/pcs.rs:616-620`, with the measured rows and fold counts]. Verifier work is the A + H PCS work only:
today 121 M base-field operations [MODEL]. Effort is in focused lane-days [ESTIMATE].

| # | Candidate | GPU change per block | Column bits per opening (run of 129) | Proof bytes | Verifier PCS work | Format | Effort |
|---|---|---:|---|---|---|---|---|
| 1 | **Rate 1/2 + coefficient-form rows, Q = 260, δ/2 accounting** | **−32 ms** [MODEL] | 105.61 → 105.93 (98.6 → 98.9) | +0.16 MB (+0.7%) | −30% | new opt-in profile + security-owner sign-off | 8–14 |
| 1b | The same at Q = 413, today's δ/3 accounting | −32 ms [MODEL] | 105.64 (98.6) | +6.7 MB (+29%) | ±0 | new opt-in profile; no accounting change | 7–12 |
| 2 | Zero-check kernels: point at infinity, affine extraction, shared loads | −5 to −13 ms [ESTIMATE] | unchanged | unchanged | unchanged | **byte-preserving** | 5–10 |
| 3 | Batch equal-size zero-checks (fewer claim points) | −8.5 to −14.5 ms (device −3..−9, host fold −5, commit −0.5) [MODEL/ESTIMATE] | unchanged in form | −6.7 MB | about −50% [ESTIMATE] | new profile + review | 10–20 |
| 4 | Non-power-of-two F domain (14,336 = 2^13 + 2^12 + 2^11) | −7.5 ms (−5.6 after #1) [MODEL] | unchanged | −0.6 MB | −6% | new profile + ruling | 10–15 |
| 5 | Pruned coset NTT (skip butterflies on the zero padding) | −2.2 ms [MODEL]; already inside #1's figure | unchanged | unchanged | unchanged | **byte-preserving** | 2–3 |
| 6 | Rate 1/4 at δ/2, Q = 157 | 0 | 106.0 | −4.2 MB (−18%) | −20% | new profile + the same sign-off | 3–5 (proof size only) |
| 7 | Univariate skip (Gruen) | 0 to −12 ms [MODEL] | recount | small | small | new format and ZK redesign | 20–40; **not recommended** |
| 8 | Small-value first rounds (BDDT) | worse for degree ≥ 3 [MODEL] | — | — | — | byte-preserving | **not recommended** for heavy slots |
| 9 | Helper triples (one Fp2 helper per 3 lookups) | ≈ −2 ms net [MODEL] | LogUp unchanged | −1.2 MB | small | new profile | **not recommended** |
| 10 | Degree cut on slot 18 (commit one product plane) | ≈ −2 ms net [MODEL] | — | +1% | — | new profile | **not recommended** |
| 11 | Merkle arity 4/8, leaf grouping, Merkle cap | 0 on the GPU | — | arity 4: +0.13 MB; grouping: ×k column bytes | — | — | **not a GPU lever** |
| 12 | Merge A/H/M, or merge across blocks | 0 on the GPU | +0.4 bits if M joins A | −0.13 MB per merged pair | — | — | **not a GPU lever**; A and H cannot merge |
| 13 | Rate 1/8 | **+44 ms** [MODEL] | 105.73 at Q = 213 | −1.3 MB | — | new profile | no |
| 14 | Linear-time codes (Brakedown, Blaze, Bolt) | ≤ −25 ms before the distance penalty [ESTIMATE] | needs Q ≈ 700–2,200 | +18–82 MB (columns ×2.7–8.6) [MODEL] | ×3–8 | new PCS + new hiding proof | no |
| 15 | WHIR / STIR / Ligerito | ≥ 0 (more prover work) | — | far smaller | far faster | new PCS | proof-size track only |

## 1. The commitment's code rate and shape

### Mechanism

Each row of `A` and `H` is a Reed–Solomon codeword. Today the encoding is:
- an inverse NTT of size n = 2^14, from the row's values on the subgroup to coefficients;
- the hiding pad `Z_n · g_pad`;
- a coset shift;
- a forward NTT of size nn = 4n = 2^16 (`pcs.rs:657-677`, `:557-569`).

The verifier opens Q = 256 random columns (`hashline/src/private_block/protocol.rs:73`).

**Three changes, which can be taken separately:**

1. **Rate 1/2 (inv_rate 2).** The forward NTT shrinks to 2^15 and the hashed bytes halve. Q must rise unless the
   accounting changes (below).
2. **Coefficient-form rows.** Read the row's n values as the coefficients of the message polynomial, so the inverse NTT
   disappears. The ZK encoding is already non-systematic: the codeword lives on a coset disjoint from the subgroup
   (`pcs.rs:559-568`). Nothing reads data out of a codeword position. The code is still RS(n + Q, nn), the encoding is
   still injective and linear, and `<v, c> = value` is a statement about the data matrix, not the polynomial. So
   soundness and the hiding lemma are unchanged.
   - The hiding lemma needs only two facts: Z_n(η) ≠ 0 on the coset, and a Vandermonde matrix on any Q points.
   - The roots change, so this is a new profile.
3. **Pruned coset NTT.** Only n + Q of the nn inputs are nonzero. With bit-reversed input (`metal_kernels.metal:238-282`)
   the first log2(inv_rate) stages multiply by zero. Doing inv_rate coset NTTs of size n gives the same codeword with
   12.5% fewer butterflies at rate 1/4. This one is **byte-preserving**.

### Soundness arithmetic [MODEL, exact]

- **Today** (`pcs.rs:16-19`; δ = 1 − (n+Q)/nn for the ZK code):
  - per opening (1 − δ/3)^Q;
  - at n = 2^14, nn = 2^16, Q = 256: δ = 0.7461, so (1 − 0.2487)^256 = **2^-105.61**;
  - over the 129 openings of a 32-block run (`results/zk60_soundness_recount_20261017/MEMO_G02.md` §2): **2^-98.60**.
- **Rate 1/2 under δ/3:** Q = 413 gives δ = 0.4874 and 2^-105.64.
- **Rate 1/2 under δ/2:** Q = 260 gives δ = 0.4921 and (1 − 0.2461)^260 = **2^-105.93**.
- **At T512** (n = 2^15, D27's named workload):
  - today 2^-105.93 at Q = 256;
  - rate 1/2 needs Q = 258 at δ/2 (2^-106.10), or Q = 409 at δ/3 (2^-106.11).
- **The δ/2 count is proven, not conjectured.**
  - BCIKS20 Theorem 1.2 (unique-decoding part) and Theorem 1.7 (correlated agreement over affine spaces) give error
    ε_U = n/q for δ ≤ (1 − ρ)/2.
  - The proximity row weights here are uniform in Fp2^rows (`pcs.rs:954`, `challenge_fp2_vec(rows)`), so the
    affine-space case applies. That gives nn/|Fp2| = 2^15/2^128 = **2^-113** per opening, against about 2^-113 today.
  - The two-phase argument then gives (1 − δ/2)^Q for both the proximity check and the evaluation check:
    - if the matrix is δ/2-far, the random combination is δ/2-far except with probability ε_U;
    - if it is δ/2-close, a wrong clear vector differs from the decoded one on at least δ − δ/2 of the columns.
  - BCIKS20 also covers randomness from the extension field: the decoded codewords lie in the base-field code (remark
    after its Theorem 1.4).
  - Today's δ/3 is the Roth–Zémor bound for general linear codes, which Brakedown uses.
  - The δ/2 analysis is specific to Reed–Solomon codes. Diamond–Gruen (2024/1351) leave δ/2 open for general codes.
- **Whole run (D27):** unchanged. The column term stays at or below today's at both T128 and T512, and the run is
  bound by LogUp: W16 T128 is 2^-97.92 for 32 blocks (`results/zk60_limb16_20261031/REVIEW_W16_20261101.md` §1).
- **Do not go beyond unique decoding.** The Johnson-regime error ε_J grows with n² and is too weak with Fp2 challenges.
  The up-to-capacity conjectures were disproved in 2025–2026 (Crites–Stewart 2025/2046; ePrint 2026/782).

### GPU time [MODEL on the MEASURED split]

The forward NTT is split as 8.7 ms multiply (scaling with nn·log nn) + 8.3 ms memory (scaling with nn), per README:811.
The hash scales with nn.

| Configuration | A + H commitment GPU | Change |
|---|---:|---:|
| Today: rate 1/4, systematic | 55.0 ms | — |
| Rate 1/4, pruned NTT (byte-preserving) | 52.8 ms | −2.2 |
| Rate 1/4, coefficient form | 45.0 ms | −10.0 (the two MEASURED 5 ms inverses) |
| Rate 1/2, systematic (forward 17 → 8.2 ms, hash halves) | 33.7 ms | −21.3 |
| **Rate 1/2, coefficient form, pruned** (forward 8.0 + 8.4, hash 1.5 + 1.75) | **23.1 ms** | **−31.9** |
| Rate 1/8, systematic | 98.7 ms | +43.7 |

- **Against 0.165 s:** −32 ms gives 0.133 s, ×1.24. Against 0.150 s it is ×1.27; against the 0.131 s of kernels, ×1.32.
- **Side effects** [MODEL]:
  - The encoded matrices halve: 1.31 + 1.37 GB → 0.66 + 0.68 GB per proof in flight. More concurrent proofs fit.
  - The CPU Merkle tree and salting halve: a 2^16-leaf keyed tree takes 2.4–4.0 ms (README M9).
  - One request gets faster too: the A and H commit phases are 0.041 + 0.038 s on the phase clock
    (`logs/m15g/phases.log`, last pass). The block goes from about 0.358 to about 0.32 s, about 12.4 tokens/s.

### Proof size and verifier [MODEL]

Proof bytes are per block, A + H openings. The verifier work counts the encoding of 47 clear vectors (each Fp2 = two
base NTTs) plus the column checks (Q × rows × vectors).

| | Clear vectors | Columns | Total | Verifier encode | Column checks | Verifier total |
|---|---:|---:|---:|---:|---:|---:|
| Today, 1/4, Q 256 | 12.51 MB | 10.75 MB | 23.26 MB | 60.1 M | 60.8 M | 120.8 M ops |
| 1/2, Q 260, coefficient form | 12.52 | 10.90 | 23.42 | 23.1 | 61.7 | 84.8 (−30%) |
| 1/2, Q 413, coefficient form | 12.63 | 17.31 | 29.94 | 23.1 | 98.1 | 121.2 (±0) |
| 1/4, Q 157 (δ/2; size only) | 12.44 | 6.59 | 19.03 | 60.1 | 37.3 | 97.4 (−19%) |

The 1/4 Q 157 row repeats the gap study's proof-size lever (`results/zk60_deepprove_gap_20261030/GAP_ANALYSIS.md`,
"Proof size": Q 256 → about 158).

### Other row × column shapes

The committed words are fixed by the layout, so changing the width trades NTT depth against proof bytes:
- **Narrower rows (n = 2^13):** about 6% fewer multiplies, about −1.5 ms. Columns double in height (+10.8 MB) while clear
  vectors halve (−6.3 MB).
- **Wider rows (n = 2^15):** the opposite.

Both also move W16's invariant `log(Dom::Tab) == log_cols` (the 2^14-wide sub-tables, `DESIGN.md` "Sub-tables of
exactly one row width") and the privacy lift condition S-1. **Not a lever.**

### Format, privacy, scope

- **Format.** New opt-in profiles (D54 convention). `inv_rate` and `Q` are already in the profile string
  (`protocol.rs:134`).
  - The δ/2 accounting needs the security owner's sign-off and a register entry. D27 already keeps "column checks Q"
    as a profile parameter.
  - Variant 1b needs M's Q split from A/H's Q: M's column ceiling is 390 at T512 (MEMO_G02 §3.2).
- **Privacy (D1).** Unchanged in form: the same pad lemma, the same clear-vector structure, the same coset rule
  (generator 7 is not in G_{2^15}; `coset_powers` asserts it). The joint-view / NL-1 gates must be re-run at the new
  geometry, as for any Q change.
- **Scope (D13).** Unchanged.
- **Byte identity.** Old profiles keep their bytes. The new encoding is one flag on the CPU (`encode_row_zk`,
  `encode_buffer`, `verify_zk`), in Metal (the head reads the data directly) and later in CUDA.

### Falsification test (cheap)

The Metal kernels already pass equality at rates 2/4/8 (README:37). The timing bench
`m2_keyed_commit_timing_at_block_sizes` (`hashline/tests/zk60_metal_commit.rs:228-260`) hard-codes `inv_rate: 4`.
- **Test-only edit:** add (log_cols 14, rows 2,504) at inv_rate 2 and 4.
- **Run:** through the guard (class gpu) with `HL_METAL_TIMING=1`, warm, n ≥ 3.
- **Prediction:** rate-1/2 GPU total 27 → 16.7 ms, systematic: inverse 5, forward 8.2, hash 1.5.
- **Kill:** above 19 ms (0.70×).

### Effort [ESTIMATE]

6–10 lane-days for the flag, profiles, goldens, CPU = Metal digests and malicious controls (a far matrix, a wrong
column). Add 2–4 days for the δ/2 lemma and its review.

## 2. Merkle and leaf hashing

- **What it costs** [MEASURED]:
  - The column-leaf BLAKE3 is the only GPU part: 3 + 3.5 ms per block (`logs/m12/commit_1.log`), 4% of 0.165 s. It
    scales with encoded bytes, so rate 1/2 halves it (already counted in §1).
  - The salting and the tree run on the CPU (`pcs.rs:743-744`, `:790-791`; tree 2.4–4.0 ms, README M9).
- **Leaf grouping** (k columns per leaf): fewer leaves, but each opened column must ship its k − 1 neighbours, about
  20 KB each. Column bytes ×k. **No.**
- **Arity 4 or 8:** the same hashed input; the path grows from 16 × 32 B to 8 × 3 × 32 B. +0.13 MB per block. No GPU
  effect.
- **Merkle cap** (publish 2^8 subtree roots): −8 levels per path, about −0.13 MB per block for an 8 KB cap. No GPU
  effect.
- **A cheaper leaf** (fingerprint the column instead of hashing it): loses binding. **No.**
- **Format:** any of these is a new profile. **Verdict:** not a GPU lever. **Falsifier:** none needed; the measured hash
  share already bounds it at ≤ 6.5 ms.

## 3. Fewer or merged commitments per block

**Mechanism and limit.** GPU commitment work is proportional to committed rows × nn × (NTT depth + hashing). Stacking
matrices into one commitment does not change the rows. So merging saves only per-commitment fixed costs (one tree, one
proximity vector, one set of paths, 0.13 MB) and **no GPU time**.
- **A and H cannot merge.** H is built after α, which is drawn after A's root (`REVIEW_W16_20261101.md` §1).
- **M** (50 rows, CPU, 5 + 3 ms) could join A. That removes 32 openings per run: column term 2^-98.60 → about 2^-99.0.
  No GPU effect.
- **Merging across blocks** saves no GPU work either.

**What does cut GPU work is committing fewer rows** [MODEL; rows from `results/zk60_limb16_20261031/count.py` with the
W16 lists]:
- **Non-power-of-two F (#4).** F planes are 9 × 128 = 1,152 of A's 2,504 rows, and F helpers 10 × 128 = 1,280 of H's
  2,606. Each F row is one token's 16,384 hidden entries, of which 14,336 are real, so the padding is 12.5% of the
  columns in every F row.
  - Split each F plane into widths 2^13 + 2^12 + 2^11 (64 + 32 + 16 rows instead of 128). That needs split
    zero-checks over 2^20, 2^19 and 2^18.
  - Saving: A −144 rows, H −160 rows, so commitments −3.3 ms. Slot 18 −12.5% × 25.9 = −3.2 ms. Folds −1.0 ms.
    **Total −7.5 ms** (−5.6 ms after #1).
  - New profile and ruling (DESIGN.md lever 3).
  - **Falsifier:** a CPU count in `count.py` style, then the slot-18 time on a split shape.
- **Fewer claim sites.** Each site owns a reserved pair of mask rows: A has about 222 mask and proximity rows (8.9%).
  Batching equal-size zero-checks (§4) removes some sites: about −50 rows, −0.5 ms after #1 [ESTIMATE].
- **Helper triples (#9).** One Fp2 helper per 3 lookups instead of 2:
  - H data rows 2,502 → 1,910 (−23%): H commitment −6.4 ms, H fold −1.9 ms;
  - but every domain zero-check gains one degree: +20–25% evaluations on 59 ms of slots 14–18, partly offset by fewer
    tables, about +6 ms;
  - **net about −2 ms.** Not worth a new format.
- **LogUp-GKR retiring H:** already settled as marginal (`handoffs/20261101-logup-gkr-w16.md`, ×1.07–1.25 per block).
  Not redone.
- **Derived instead of committed linear planes** (gap study DP-1, ×1.05–1.12): waits for masked layer claims. Not
  redone.

## 4. Sumcheck work

**Which kernels dominate** [MEASURED, §0; README M10 line 785]: slot 18 (F) 26 ms and slot 14 (D) 16 ms are 55% of the
device rounds. Then come slot 17 (8), 15 (6), 19 (5) and 16 (4), and six small slots that are mostly fixed cost (12).

Two measured facts shape everything below:
- **The body's arithmetic is what remains** in the later rounds. Loads and line values are about a fifth of the kernel
  (README:322-327, M4g).
- **An extension-field round costs only 1.7–2.7× a base-typed round per pair-point** [MEASURED, `logs/m4j_split.log`,
  R13]: slot 18 round 0 0.026 s against later rounds 0.045 s; slot 14 0.021 against 0.056. Both cover about 2^(n−1)
  pairs. The raw multiply ratio is larger (Fp2 34.7 against Goldilocks 149 G/s, README:976-977), but eq and hosted
  tables are already extension-valued in round 0.

**Byte-preserving levers (#2), −5 to −13 ms together [ESTIMATE]:**
- **Point at infinity in place of point D.**
  - Today each round evaluates s at 0, 2..D and recovers s(1) from the claim.
  - Instead, evaluate the leading coefficient: the top-degree homogeneous part of the polynomial at the slopes hi − lo.
    Lower-degree clauses drop out of that point.
  - Then recover s(D) exactly from s(0), s(1), s(2..D−1) and the leading coefficient. The absorbed message (16(D+1)
    bytes of evaluations) is the same field elements, so no byte moves.
  - Gain about (1 − top-degree share)/D of the evaluation body: −2 to −5 ms on slots 14–18. Unlike Gruen (M13), it
    launches no extra points.
  - **Falsifier:** a CPU-only census of the top-degree share of node multiplies per slot from the `slot_ir_accuracy.rs`
    builders. Drop it if slot 18's share is above 70%. Then a `kbench/` A/B on slot 18's dumped library.
- **Affine extraction** (README open item 2): fold affine subexpressions as derived tables. W16 has shorter linear forms
  than R13, so −3 to −8 ms.
- **Shared pair loads across the point-threads** (threadgroup memory): bounded by the 20% floor, so ≤ −4 ms.

**Protocol levers:**
- **Batch the equal-size zero-checks (#3).** Slots 14, 15 and 17 are all 2^19, with their hosted matmul claims ready
  beforehand. Fold in the 2^19 small slots where the hosting order allows (21, 22; 00 and 01 only if slot 02 moves).
  - Benefits:
    - one eq table;
    - one transcript step per round;
    - one final point.
  - So A's 36 opening groups fall to about 11 [ESTIMATE]. The host fold drops about −5 ms, clear vectors −6.7 MB per
    block, verifier column checks and encodes about −50%.
  - The small slots' 12 ms device clock is mostly fixed cost. The GPU-busy part of it is unknown, so −3 to −9 ms.
  - Costs: a new slot order and profile string (D17), and a review. The CFS masking is per sumcheck, so it carries
    over with fewer M rows.
  - **Falsifier:** count groups and claim sites from the layout on the CPU; read GPU timestamps for slots 00, 01, 21,
    22 (H113's test).
- **Univariate skip (#7, Gruen 2024/108 §5).** Replace rounds 0..k−1 with one univariate round in the base field.
  - The cost model: the skip round evaluates D(2^k − 1)/2^k points per entry, against today's D/2, plus a
    low-degree-extension pass. The extension rounds left are 2^-(k−1) of today's.
  - With round 0 at 0.29–0.38 of a heavy slot (logs/m4j_split.log, less the pre-M6 latency), the slot costs
    **0.78–0.96** of today, i.e. −2 to −12 ms.
  - It also makes the first round polynomial degree D(2^k − 1). That needs a matching CFS mask, so more M rows. Every
    hosted claim and PCS column-weight builder gets Lagrange weights in k coordinates. **Not worth a new format here.**
    It pays where the extension/base gap is 10× or more, as in small fields.
- **Small-value rounds (#8, BDDT 2025/1117).** Byte-preserving, since the round messages are the same.
  - Round 1 then needs (D+1)^2 base evaluations per pair against today's D extension evaluations: for D = 4, 25 against
    4 × (1.7–2.7) = 7–11.
  - Worse at every D ≥ 3; break-even only near D = 2, where the slots are tiny.
  - **H115 should be narrowed accordingly.** Its 2.4× was measured on a degree-2 GKR leaf layer.
- **Degree cut on slot 18 (#10).** Commit one product plane on F, so degree 5 → 4.
  - Slot 18: −(1 − 4/5 × 20/19) × 25.9 = −4.1 ms. One more F plane: +128 A rows, +1.8 ms.
  - Net about −2 ms, and M13 shows point-count cuts deliver less than counted. No.
- **Gruen's eq factor:** settled negative (M13). Not redone.

## 5. The 2024–2026 literature against this exact cost

| Work | What it offers | Effect on this block's GPU work | Fits the hiding commitment? | Fits CPU/GPU byte identity? | Verdict |
|---|---|---|---|---|---|
| BCIKS20, *Proximity Gaps for RS Codes* (FOCS 2020 / JACM) | proven gap up to the unique-decoding radius, ε = n/q (Thms 1.2, 1.7) | enables #1 at Q = 260 | yes: an accounting change only | yes | **adopt, with sign-off** |
| Diamond–Gruen 2024/1351 (CiC 2025) | interleaving preserves unique-decoding gaps; δ/2 for general linear codes left open | confirms δ/2 is an RS-only fact | — | — | keep RS |
| Angeris–Evans–Roh 2024/1399 | Ligero with logarithmic (tensor) randomness | none: the fold costs the same | yes | yes | no GPU lever |
| Crites–Stewart 2025/2046; ePrint 2026/782 | disprove the list-decoding / near-capacity gap conjectures (BCIKS CA, WHIR MCA, DEEP-FRI) | rules out conjectured Q cuts | — | — | stay in the proven regime |
| Brakedown (CRYPTO 2023), Orion (CRYPTO 2022) | linear-time expander codes; code switching | encoding is random sparse gathers. The FPGA study 2024/1918 names random off-chip access as the bottleneck. Low distance means Q ≈ 700–2,200 at δ/3 (relative distance 0.3–0.1) | no ready pad lemma (our lemma uses the MDS property); Orion's ZK needed corrections (explorer note `progress/20261017T232105Z-d713e393.md`) | yes (seeded codes) | **no** |
| Blaze (Eurocrypt 2025, 2024/1609); Bolt (2026/310); block-accumulate codes (2025/1828) | RAA / sketched linear-time codes with code switching; Bolt claims a commit 3–4× faster than RS-based | binary fields (GF(2^k)); our arithmetic is integer-modular over Goldilocks (Binius-class settled no). Even a free encoding saves at most the NTTs (45 ms) before the Q penalty | not addressed in the abstracts | yes | **no** |
| WHIR (2024/1586), STIR | RS proximity IOPs: few queries, very fast verifier | the prover encodes, then re-encodes folded polynomials: at least Ligero's work | no ZK WHIR found; zkDeepFold (USENIX Sec 2025) and Diamond 2025/1015 show related ZK designs exist | yes | proof-size track only |
| Ligerito (2025/1187) | recursive Ligero with sumcheck; any code with evaluable generator rows | SPIN (2026/2317) reports it proves slower than a Brakedown-style commitment | unclear | yes | proof-size track only |
| Gruen 2024/108 | univariate skip; eq-factor split | §4: 0–20% on heavy slots; eq split settled negative | needs a new mask degree | yes | no |
| Bagad–Dao–Domb–Thaler 2025/1117 | small-value sumcheck, prover-only | §4: worse for D ≥ 3 at our field ratio | yes | yes (same messages) | no for heavy slots |

**The one idea from this literature that pays is cheap.** Count the RS column test at the radius RS codes provably
allow, and spend the gain on rate instead of queries. Code switching and linear-time codes buy proof size or CPU speed
in other settings. Here they cost hiding, field compatibility and query count.

## What the bundle reaches [MODEL; ranges carry the ESTIMATE rows]

Savings, applied in order so they do not overlap:
- **#1:** −31.9 ms.
- **#4:** −5.6 ms after #1 (commit −1.4, slot 18 −3.2, fold −1.0).
- **#2:** −4.8 to −12.4 ms (scaled by 0.95 for #4's cut to slot 18).
- **#3:** −8.5 to −14.5 ms.

Total **−50.8 to −64.4 ms**. The resulting ratios:
- against 0.165 s: 0.114–0.101 s, **×1.44–1.64**;
- against the 0.150 s component sum: ×1.51–1.75;
- against the 0.131 s of GPU kernels alone (excluding the host-fold parts): ×1.52–1.80.

Without #1, the rest gives −21.6 to −35.6 ms, ×1.15–1.28. **The commitment change is the piece no bundle can do
without.** On the RTX 5090 the same proportions apply: the NTT and hash halve, and the kernels are the same algorithms.

## Recommended next experiment

**Measure rate 1/2 on the real A shape before any design work.**
- **The edit (test-only):** add (log_cols 14, rows 2,504) at inv_rate 2 and inv_rate 4 to the ignored bench
  `m2_keyed_commit_timing_at_block_sizes` (`hashline/tests/zk60_metal_commit.rs:228-260`). The Metal kernels already
  pass equality at rates 2/4/8 (README:37).
- **The run:** through the resource guard (class gpu) with `HL_METAL_TIMING=1`, warm, n ≥ 3. Read the component split.
- **Prediction** [MODEL]: GPU total 27 → 16.7 ms, systematic: inverse 5, forward 8.2, hash 1.5.
- **Kill rule:** above 19 ms (0.70×). The inverse NTT's 5 ms is already measured, so the coefficient-form part needs no
  experiment.
- **In parallel, on paper:** the security owner checks a one-page lemma. It states that for this exact construction
  (uniform Fp2 proximity row weights, `pcs.rs:954`; Q columns; RS(n + Q, nn) on a coset), the column test fails with
  probability at most (1 − δ/2)^Q + nn/|Fp2| per opening, by BCIKS20 Theorem 1.7 (unique-decoding part).
- **If both pass:** build the coefficient-form flag and an opt-in W16 rate-1/2 profile (#1). Then do the byte-preserving
  zero-check work (#2, starting with the infinity-point census).
- **Also worth one day:** GPU timestamps under six-way concurrency, with one command queue per proof thread against
  today's single queue (`metal.rs:57`, `:82`). Both arms are byte-preserving. This turns the 0.165 s figure into
  measured GPU-busy time and shows whether part of the ceiling is queue serialisation rather than kernel work.

**Proposed hypothesis numbers** (not yet in STATE.md, which ends at H116):
- H117: rate 1/2 + coefficient form (#1);
- H118: the δ/2 accounting, also the proof-size lever #6;
- H119: the point at infinity (#2);
- H120: equal-size zero-check batching (#3);
- H121: per-proof command queues and GPU-busy attribution.

## Obligations and limits

- Any protocol item above:
  - keeps every mask, pad, RNG draw and refusal until a ruling;
  - needs a new profile string (D17) and the D54 gates (goldens, CPU = GPU digests, malicious controls, an independent
    review);
  - needs the joint-view / NL-1 gates re-run on new captures.
- None of this is a privacy acceptance. D1 and D13 are unchanged.
- **Not measured here:**
  - the round-0 share at HEAD (I used R13's M4j split less the pre-M6 latency);
  - the top-degree node share per slot;
  - GPU-busy time under concurrency;
  - the W16 receipt itself (bytes are counted from the size formula);
  - the W16 T512 LogUp count.
- **Not duplicated:** LogUp-GKR, D56, Gruen's eq factor, the gap study, D55 concurrency, Sol's lanes.
- Proved positions and full-stack proofs from this note: **0 / 0**. The private 8B at ≥ 50 proved tokens/s remains
  unachieved.

## Sources

**Repository (read for this note):**
- `results/zk60_metal_20261031/README.md`: M10 (lines 769-786), M11 (788-816), M12, M13 (857-888), M4g floor
  (322-327), headline (955-966), M18 (968-1000); `D56_FIELD_SWITCH_STUDY.md` §2.4, §3.1.
- Logs in `results/zk60_metal_20261031/logs/`:
  - `m12/commit_1.log`: commit components, folds, gathers;
  - `m13/slot_0.log`: per-slot batch clocks;
  - `m13/cost.log`: node multiplies per slot;
  - `m15g/phases.log`: phase clock;
  - `m4j_split.log`: round 0 against later rounds.
- `ops/zkp-mvp/gpu-metal/zkp-core/src/pcs.rs`: 1-19, 557-584, 616-677, 702-754, 936-976, 1016-1045.
- `ops/zkp-mvp/gpu-metal/hashline/src/gpu/metal.rs`: 50-90, 196-236, 673-697, 1980-2020.
- `ops/zkp-mvp/gpu-metal/hashline/src/gpu/metal_kernels.metal`: 238-330.
- `ops/zkp-mvp/gpu-metal/hashline/src/private_block/protocol.rs`: 41, 73, 134.
- `ops/zkp-mvp/gpu-metal/hashline/tests/zk60_metal_commit.rs`: 222-260.
- `results/zk60_soundness_recount_20261017/MEMO_G02.md` §2, §3.2.
- `results/zk60_limb16_20261031/DESIGN.md`, `count.py` and `REVIEW_W16_20261101.md` §1.
- `results/zk60_deepprove_gap_20261030/GAP_ANALYSIS.md` (DP-5, DP-8, "Proof size").
- `research/zkp-efficiency/handoffs/20261101-logup-gkr-w16.md`.
- `docs/zkmatrix-poc/ZK60_DECISIONS.md`: D1, D13, D17, D27, D54, D55, D56.

**External:**
- Ben-Sasson, Carmon, Ishai, Kopparty, Saraf, *Proximity Gaps for Reed–Solomon Codes* (FOCS 2020; JACM 2023):
  https://sites.math.rutgers.edu/~sk1233/GS-FRI.pdf , https://dl.acm.org/doi/pdf/10.1145/3614423 . Theorems 1.2 and
  1.7 were read from the PDF.
- Diamond, Gruen, *Proximity Gaps in Interleaved Codes*: https://eprint.iacr.org/2024/1351 (CiC:
  https://cic.iacr.org/p/1/4/8)
- Angeris, Evans, Roh, *A Note on Ligero and Logarithmic Randomness*: https://eprint.iacr.org/2024/1399
- Crites, Stewart, *On Reed–Solomon Proximity Gaps Conjectures*: https://eprint.iacr.org/2025/2046
- *Failure of proximity gaps close to capacity*: https://eprint.iacr.org/2026/782
- Ben-Sasson et al., *On Proximity Gaps for Reed–Solomon Codes* (2025): https://eccc.weizmann.ac.il/report/2025/169/
- Khatam, *Proximity Gaps for Multilinear Evaluation for All Linear Codes*: https://eprint.iacr.org/2024/1843
- Brehm, Chen, Fisch, Resch, Rothblum, Zeilberger, *Blaze: Fast SNARKs from Interleaved RAA Codes*:
  https://eprint.iacr.org/2024/1609
- *Bolt: Faster SNARKs from Sketched Codes*: https://eprint.iacr.org/2026/310
- *Block-Accumulate Codes*: https://eprint.iacr.org/2025/1828
- *Accelerating Hash-Based Polynomial Commitment Schemes* (FPGA): https://eprint.iacr.org/2024/1918
- Arnon, Chiesa, Fenzi, Yogev, *WHIR*: https://eprint.iacr.org/2024/1586
- Novakovic, Angeris, *Ligerito*: https://eprint.iacr.org/2025/1187 ; *SPIN*: https://eprint.iacr.org/2026/2317.pdf
- Diamond, *Zero-Knowledge Polynomial Commitment in Binary Fields*: https://eprint.iacr.org/2025/1015
- *DeepFold* (USENIX Security 2025): https://www.usenix.org/system/files/usenixsecurity25-guo-yanpei.pdf
- Gruen, *Some Improvements for the PIOP for ZeroCheck*: https://eprint.iacr.org/2024/108
- Bagad, Dao, Domb, Thaler, *Speeding Up Sum-Check Proving*: https://eprint.iacr.org/2025/1117
- Brakedown (Golovnev, Lee, Setty, Thaler, Wahby, CRYPTO 2023) and Orion (Xie, Zhang, Song, CRYPTO 2022): cited from the
  repo's earlier notes. Not re-fetched.
