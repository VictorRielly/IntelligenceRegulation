# Privacy gate on the token-I/O stages: R2 TinyLlama T32, L = 1 and 2 (gate round 7)

Written 2026-10-19 (from 18:05 UTC) by the PRIVACY GATE lane, a delegated
Claude Opus 5.5 agent.

| Status | **Gate evidence, NOT a privacy acceptance.** It measures DESIGN §4.2's items G-1..G-7 on four token-I/O run captures. Only the security review process can accept, and rulings are Victor's. |
|---|---|

**Labels.**

- [MEASURED]: a run happened and a record is cited (shared box, one run).
- [COUNTED]: arithmetic from the code and the shape.
- [READ]: read in a cited source line.
- [ARGUED]: a short argument stated where it is used.

EV below is `results/zk60_gate_tinyllama_20261017/`.

## 1. What was gated

| | |
|---|---|
| Captures (read in place, 0700, outside the repo) | `/home/victor/zk60-artifacts/token-io/captures/tinyllama-t32-L{1,2}-{dense,fixed}-pt1`. Schema `hashline-native-capture/6-token-run`; `L + 2` stages (IN, the blocks, OUT). dense = the export's held-out sequence `seq_ho00`, with parity at every layer; fixed = 32 copies of BOS (id 1), the gate's degenerate partner |
| Run profile | `hashline-zk-mr1/private-token-io-run-tinyllama-1.1b-t32-trained-statement-public-row/1`: public-row variant, mode (i), tier `mvp-95-whole-run (D27)` (stages 2^12 rate 1/4, token endpoints 2^8 rate 1/8, Q = 256) |
| Export | `pg_rot1_b4_T32_cal128` (R2's). It is not `pg_rot1_export_T32`. Layers 0 (L = 1) and 0–1 (L = 2) |
| Tree | The token lane's "uncommitted-token-io-r7c" (`ops/zkp-mvp/token-io/hashline/`) = native R8 + the token files + the step-A capture hooks. The bundles pin 52 files: **40 byte-identical to the R7 pins read in tools v8; 12 read for this round** (6 changed, 6 new; EV/token_io/readings/token_r7c_pin_readings.json, spot-checked). Pins are matched by file name. 0 refused |
| Tools | **v9** (EV/gate-tinyllama.tools.frozen.v9.sha256, e22425d3…). New: `zk60_native_rg_tokenio.py` (the token geometry, re-derived from public parameters), `zk60_native_rg_tokengate.py` (loader, replay, role adapter, G-items, controls) and `zk60_native_rg_tokenio_r7c_pins.py`. Every rank, mask and hash computation is the frozen block machinery. The 56 staged block records keep their verdicts under v9 |
| Records | `EV/token_io/r7c/token-r7c-{L1,L2}-{dense,fixed}.json`; queue `EV/token_io/token_queue.sh` (`.done` = 0, toolcheck 57 of 57, 62 unit tests OK) |
| Not built, so out of scope | The D26 two-site input endpoint (variant P) and its SHIFT / IO-s claims (**G-7**); variant F; mode (ii); the hidden-length variant. `token_io/run.rs` `variant_is_built` refuses every variant but the public row [READ] |

## 2. Results, item by item [MEASURED unless marked]

All four records are **PASS**:

- 0 false parts;
- the replay re-derives every challenge;
- every column is authenticated;
- every pin is read;
- every live control fires.

| | L1 dense | L1 fixed | L2 dense | L2 fixed |
|---|---|---|---|---|
| Status | **PASS** | **PASS** | **PASS** | **PASS** |
| Replay: challenges / positions / binding | 5,347 / 220 / yes | 5,347 / 220 / yes | 9,838 / 344 / yes | 9,838 / 344 / yes |
| Hash layer: columns authenticated | 3,328 | 3,328 | 4,352 | 4,352 |
| Wall / peak RSS | 78 s / 0.29 GiB | 76 s / 0.30 GiB | 93 s / 0.36 GiB | 88 s / 0.35 GiB |

### Re-derivation of the replay

The token stages' transcript is re-derived, never read from the bundle:

- **The header:** six absorbs, eight run-shape words with the true V,
  `calibration` = the token header's own word. The run binding reproduces.
- **Stage IN:** `pb-run-stage 0`, `pb-run-block` = the embedding digest, B_in,
  A-in, M. Then 3 LogUp challenges and the **11 r_emb coordinates**
  (clog2 d_pad), then H.
- **Stage OUT:** `pb-run-stage L+1`, `pb-run-block` = the head digest, A-out,
  M, then **2** challenges (gamma, alpha), then H.
- **Slots:** each new slot's definition draws, `pb-slot`, c, `pb-scalar`,
  masked rounds and `pb-term`.
- **Openings:** each opening's lambdas, proximity coefficients and column
  indices.

### G-1. Rank of every new hidden plane over the commitments that hold it

Each opening is ranked at its own geometry. The disclosed dimension is
identical on all four captures:

| Commitment | Planes (DESIGN §4.2) | Disclosed | Expected |
|---|---|---|---|
| A-in (stage IN, 17 rows) | tok, m | **0** | 0 |
| H-in (28 rows) | h_q, h_tab, u | **2** | 2 |
| E-token-in (6 rows, 2^8, one site) | tok (words 0..31) | **0** | 0 |
| B_in (boundary 0, 22 rows) | x_in = E[tok] | **0** | 0 |
| A-out (182 rows) | x, y, D, the limbs, e, λ, tok, M | **0** | 0 |
| H-out (110 rows) | the helpers, u | **2** | 2 |
| B_out (boundary L, 22 rows) | x_out of block L−1 | **0** | 0 |
| E-token-out (6 rows) | tok (one word) | **0** | 0 |
| M_in / M_out (12 / 26 rows) | mask coefficients | **0** | 0 |

- **The H figure.** Each H discloses exactly the public LogUp identity:
  `u_row_term.equals_public_logup_identity` and `per_indicator_equals_exact`
  hold on H-in and H-out, as on a block's H.
- **Exclusivity:** the 16 clauses hold on every commitment.
- **k0 = 0** everywhere.
- **Pad rank:** the pad block of B_in has full rank (255 / 255 at L1, 253 /
  253 at L2 fixed).
- **The block stages** inside the token run give the block figures (A 0,
  H 2, M 0).
- **On the reserved rows** (ruling M-8(a)), B_in and B_out have reserved block
  rank 6 of 6, disclosed 0, determinant ≠ 0, on all four captures.
- **Joint over the shared planes** [ARGUED]. The shared planes are:
  - tok, on A-in and E-token-in;
  - B_in, on its commitment and block 0's A;
  - B_out, on its commitment, block L−1's A and A-out's x row T−1;
  - the output tok, on A-out and E-token-out.

  Every holder discloses 0. Each commitment is blinded by its own reserved
  rows, pads and salts. So a functional combining two of them is free of
  blinding only if each part is, and the joint disclosure is bounded by the
  sum of the parts: 0. By ruling R-3, joint = sum of parts is a consistency
  check; independence of the blinding is G-R4's.

  The mixed-width identification (a 2^12-word A row against a 2^8-word
  endpoint row) is not modelled by the frozen run-wide joint system. So this
  item is argued from the computed per-commitment figures, not computed
  jointly.

### G-2. Partially fixed claim points on B_in and B_out

Every coordinate of every claim point is classed, on all four captures:

- **B_in, stage IN's claim (IN-01):**
  - column coordinates: **11 are entries of r_emb** (challenge-fixed, drawn
    after B_in, A-in and M_in), and 1 is the slot's own random coordinate;
  - row coordinates: random.
- **B_in, block 0's claim (slot 21):** all coordinates random.
- **B_out, block L−1's claim (slot 22):** all coordinates random.
- **B_out, stage OUT's claim (OUT-00):** **5 public bits**, the row T−1 = 31:
  4 row bits and **1 column bit**. Token row t's low bit lies in the column
  coordinate, because two token rows share one 2^12 commitment row. This is
  so at TinyLlama as well as 8B [COUNTED in `zk60_native_rg_tokenio.g2`;
  MEASURED here].
- **Masking:** each claim is masked on its own reserved pair (rows 16/17 and
  18/19), with the two mask parts sharing the claim's column key. With these
  points the reserved block keeps rank 6 of 6 and discloses 0 (G-1).

So the reserved pair still masks the claim at a partially fixed point,
including where the fixed bit falls in the pair's column tail. The frozen
per-commitment tools accept such points with no finding.

### G-3. CFS of stage IN and stage OUT

The frozen shape-driven mask / CFS port is run against each new stage's own
schedule:

| Stage | Slots | Functionals (= re-derived) | Entries recomputed | Differing | CFS | Leaves authenticated |
|---|---|---|---|---|---|---|
| IN | 4 | **8** | 5,352 | 0 | solved | 256 |
| OUT | 11 (2 hosted) | **20** | 9,326 | 0 | solved | 256 |
| a block stage | 23 | 34 | 16,155 | 0 | solved | 256 |

In every stage M discloses the 2 of its one published θ-batched functional
(Fp2), as predicted.

### G-4. Vocabulary pads, P-3 lifts, endpoint pad words

**Static [COUNTED]:**

- the vocabulary pads are 768 (32,000 → 32,768);
- P-3 lifts: Ti 32 → 4,096; Lo 18 → 4,096; Do 2,048 → 4,096; Tab 256 →
  4,096;
- endpoint pad words: 224 of 256 in the input plane, 255 of 256 in the
  output plane.

**On the captures,** every public table of the new stages is identified by its
SHA-256 against support vectors computed from the re-derived geometry. All
8 required pad-zero / support factors are present on all four captures:

| Slot | Support table found |
|---|---|
| IN-00 IO-in | supp(T = 32) over the 256-word endpoint plane |
| IN-01 query zero-check | supp(T) over Ti = 2^12, and the BOS position indicator |
| IN-02 table zero-check | **supp(V = 32,000) over 2^15**: the vocabulary pads |
| OUT-02 TZC | To's entry-0 indicator supp(1, 2) (`stage_out.rs:377`) |
| OUT-03 LZC | the live isqrt limb positions {2k : k < 9} over Lo = 2^12 (`stage_out.rs:400`) |
| OUT-05 DZC | supp(d_pad = 2,048) over Do = 2^12 (the P-3 lift) |
| OUT-06 VZC | **supp(V) over 2^15** |
| OUT-08 TAB | supp(256) over Tab = 2^12 |

- OUT-07 RSEL also carries supp(V), and OUT-10 IO-out the one-hot u0 over
  256 words.
- The tables left unidentified are challenge-dependent or public weights: tau,
  iota, the head fold `W'(r_j, ·)`, and the byte table values.
- **What is not checked:** the slot polynomials themselves. There is no port
  of the new stages' terminal identity, so that each pad term multiplies its
  plane is read from the code (`stage_in.rs` / `stage_out.rs` `define`), not
  computed.

### G-5. log(Tab) = row width

- **Stage OUT:** the byte-table histogram `A_MU8` and helper `H_GU8` sit at
  2^12 = the stage row width, on the captured plane index and in the
  re-derived geometry.
- **Stage IN:** it has no byte table, so the item does not apply.

### G-6. The D17 hard gate at the 2^8-word token endpoints

Each token endpoint is ranked at its own geometry (2^8 at rate 1/8, one site,
6 rows = 1 data + 5):

| Capture | E-token-in: disclosed | E-token-in: pad rank / distinct columns | E-token-out: disclosed | E-token-out: pad rank / distinct columns |
|---|---|---|---|---|
| L1 dense | **0** | 242 / 242 | **0** | 242 / 242 |
| L1 fixed | **0** | 245 / 245 | **0** | 243 / 243 |
| L2 dense | **0** | 244 / 244 | **0** | 232 / 232 |
| L2 fixed | **0** | 239 / 239 | **0** | 239 / 239 |

Both endpoints show exclusivity ok and a non-zero certifying minor. The
owner's decommitment is not in any capture.

### G-7. Out of scope

Variant P (D26's two-site endpoint) is not built.

## 3. Controls on the new stages (each predicted to fire; 31 live, all fire on every capture; 2 not applicable)

| Control | What it perturbs (an in-memory copy) | Result |
|---|---|---|
| TC-1 | the 16-clause exclusivity family on A-in, H-in, E-token-in and B_in | 24 / 24 sub-controls fire; 16 / 16 clauses exercised |
| TC-2 | the same on A-out, H-out, E-token-out and B_out | 24 / 24; 16 / 16 |
| TC-3, TC-4 | B_in, B_out: the two claims' pairs made one (shared pair) / one proximity row | disclosed 2 / 1 on each |
| TC-5a | stage IN's first r_emb entry + 1 | replay: "r_emb 0: challenge differs" |
| TC-5b | stage OUT recorded with 3 LogUp challenges | replay: "3 recorded, the stage draws 2" |
| TC-5c | stage IN's A-in / H-in swapped in the declared order | replay refuses |
| TC-6a..d | token_io.input_root flipped; B_out rows + 1; stage OUT plane index a_rows + 2; output endpoint "opened at stage 0" | integrity refuses each, by name |
| TC-7a..c | B_out's public row bit made random; B_in's r_emb coordinate replaced; B_in's two claims on one pair | G-2 refuses each |
| TC-8a, b | the vocabulary support table's digest replaced (IN-02); the Tab support's (OUT-08) | G-4 refuses: IN-02 / OUT-08 missing |
| TC-9 | round 8's mask controls on M_in and M_out: M1, M2, M3, M5, M6 | all fire. M4 (shortens a BILINEAR slot) is **not applicable** by name: a new stage has none |
| TC-10a, b | stage_out.rs pin moved; stage_in.rs pin dropped | the token pins refuse |
| TC-10c (positive) | run.rs at R7's read digest | accepted, as predicted |

## 4. What is NOT covered

- **Not run on these captures:**
  - L = 22 and the 8B token geometry. Those captures come from step B.
  - The joint figure over the shared planes is argued from the per-commitment
    figures (§2, G-1), not computed. The frozen run-wide joint system does
    not model a mixed-width identification.
- **Not ported:**
  - **The new slots' terminal identity**, and an NL-1 check of the new slots
    (a public table in every monomial). The gate replays and ranks the new
    slots, but does not evaluate their polynomials.
  - **The zero-data preimage / full preimage / joint arms** (stages 5, 11, 13)
    on the new commitments, and the terminal identity on the block stages
    inside a token run. The block stages' arms are the trained gate's.
- **The trained-calibration shape keys are absent** from token bundles. The
  token writer descends from the native capture writer and lacks the gate's
  patch (helper correction 1). The token gate does not use them; round 8
  must re-apply the patch.
- **Out of scope:**
  - G-7 and variant P;
  - variant F;
  - mode (ii);
  - the GPU path;
  - the CLI token path, which has no capture hooks (helper note);
  - any export other than `pg_rot1_b4_T32_cal128`.
- **None of this is a privacy acceptance.**
