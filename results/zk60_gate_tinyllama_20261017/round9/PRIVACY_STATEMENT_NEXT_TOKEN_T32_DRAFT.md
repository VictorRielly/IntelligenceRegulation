# Privacy statement for the next-token proof (token-I/O run, public-row variant, mode (i), TinyLlama-1.1B T32): DRAFT for independent review (not accepted, not in force)

Drafted 2026-10-19 from about 23:50 UTC by the PRIVACY GATE lane, a
delegated Claude Opus 5.5 agent, at the coordinator's request (gate round 9).
It follows the form of the trained statement in force,
`docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TRAINED_TINYLLAMA_T32.md` (register
**D33**). It is a **separate draft beside D33, not an edit of it**.

| Status | **DRAFT for an independent privacy review. NOT accepted, NOT in force, and NOT a privacy acceptance; nothing on this page establishes a privacy property.** It proposes a sentence for the next-token proof and lists what that sentence would rest on, what is measured, and what is still owed. No step has yet been attacked by an independent reviewer: every argument below is either carried from D33's reviewed record (and says so) or is **[MINE]**, checked by nobody. The decision is the security owner's, and rulings are Victor's. |
|---|---|

**Labels.**

- [MEASURED]: a run happened and a record is cited (shared box, one run
  unless stated).
- [COUNTED]: arithmetic from the code and the captured geometry.
- [READ]: a fact read in a cited source line or document.
- [ARGUED]: an argument that survived one independent attack in D33's
  record (the reviews named there). It is carried here only where the token
  stages do not change it.
- **[MINE]**: my own reading or arithmetic for this page, checked by nobody.

**Sources.**

- **EV** is `results/zk60_gate_tinyllama_20261017/`; its ledger is
  `EV/PROGRESS.md`.
- The token-gate report of record is
  `EV/token_io/TOKEN_GATE_REPORT_T32_v10.md` (sha256 bcd01bb4…; gate round
  7, accepted by the coordinator as gate evidence).
- The design is `results/zk60_token_io_design_20261017/DESIGN.md` (v4).
- **frozen-r7** is the token lane's frozen round-7 tree,
  `results/zk60_token_io_r1_20261017/frozen-r7/`: 233 files, manifest
  `manifest_final_r7.sha256`, list sha256 `eb912dd5…`. It is native R8 plus
  the token files.

## 0. In plain words

### What would be claimed

Consider a verifier who receives an **accepted** next-token run of trained
TinyLlama: the embedding lookup, the 22 trained blocks, the final norm, the
head and the greedy choice of the next token, all under one transcript.
From the run's bytes, that verifier learns nothing about:

- the prompt's token ids at positions 1 to 31;
- their embedding rows;
- the hidden activations and the planes between blocks;
- the final norm's values and the logits;
- **the next token itself.**

"Nothing" means beyond a distance of about **2^-70.35 per 22-block run**
(2^-74.43 at L = 1, 2^-73.62 at L = 2). The model is D33's: D19, D20, D21,
plus D19b, with the generator assumption E-1 / X-1.

The verifier does learn the public facts of the profile:

- T = 32 is the prompt length. In the public-row variant the prompt fills
  all 32 positions.
- The token at position 0 is the profile's BOS (D25 T8).
- V = 32,000.
- The embedding table, the final-norm constants and the head, by digest.
- The run length L, the trained-model identity and the tier.

**The two owners are outside the adversary for their own endpoint** (DESIGN
§3.4):

- The **output owner** receives the next token and the output endpoint's
  decommitment from the prover over a private channel. That decommitment
  unmasks the IO-out terminal, which is a function of the token alone.
- The **input owner** holds the prompt.

Neither decommitment is ever published (D21), and no endpoint root is ever
referred to by a later artifact (D23).

### Which calibration each claim covers

- **The sentence covers one calibration only: `pg_rot1_b4_T32_cal128`**, the
  export the TinyLlama token captures used (profile.json sha256
  `826f7641…`).
- **It is not D33's calibration `pg_rot1_export_T32`, and this page does
  not extend D33.** The two exports differ in:
  - Ceps: 74,429 against 91,255;
  - Cn_a: 3,583 against 3,999;
  - Cn_m: 2,873 against 3,122;
  - sh_z: 4 against 5;
  - the per-layer tables [READ, both `profile.json`].
- **To extend D33 to the next token**, the token stages would have to be
  captured at `pg_rot1_export_T32`. That export has no token-I/O inputs:
  - no `embedding_int16.bin` [READ: directory listing];
  - no final-norm calibration for its last layer.

  The token lane or the calibration lane would have to build those
  (`TOKEN_IO_SPEC.md`) before a capture can be made.
- **Llama-3-8B T32** (`llama3_8b_pg_rot1_b7voc0_T32`) is MEASURED at L = 1
  and 2 by the same token gate (§3), but it is **not in the sentence**. Its
  block layer has no gate of record: no NL-1 or terminal surjection at the 8B
  block slots, no block control families, no stage-47 replay at 8B, and no
  D33-style statement. Its figures are reported here as evidence for a later
  statement.

### What has been measured

The token gate (tools v10) ran on ten captures. They were made on the token
lane's capture trees, whose 52 pinned files have frozen-r7's digests:

- TinyLlama at L = 1, 2 and 22;
- 8B at L = 1 and 2;
- each on the held-out prompt `ho00` and on the degenerate admissible prompt
  of 32 BOS ids.

**All ten records are PASS** (`EV/token_io/v10/`):

- the replay re-derives every challenge;
- every new commitment discloses what DESIGN §4.2 predicts: H 2, everything
  else 0;
- the computed joint over the shared token planes is 0 (= the sum of the
  parts);
- the all-zero-data preimage of every commitment of the run reproduces the
  view: 0 differing entries, up to 24.9 M at L = 22;
- the new slots' terminal identity holds, 15 / 15, with NL-1's S1 premises,
  15 / 15;
- the block stages' terminal identity holds: 506 / 506 at L = 22;
- 36 / 36 live controls fire.

### What is not done (§10)

- **NL-1's S3 and S4 (the terminal surjection) on the 15 new slots.** They
  are not run. The block slots' S0–S5 were run at D33's calibration.
- **G-R4's root-rebuild replay of the token stages.** Not ported. Their draw
  discipline is read, not replayed.
- **The block layer at `pg_rot1_b4_T32_cal128`.** Measured by the token gate
  as listed above, but without the trained gate's block control families
  (TL, CT, GQ, P, M, X, C, CH, M9), its pin controls, G-10 or the
  calibration cross-check. Those ran at D33's calibration only.
- **The command-line token path.** It has no capture hooks, so no receipt
  from it was gated.
- **Findings F-T1 and F-T2 (§7)** are for the security owner. CS-3 is not in
  the token run's sealing pass, and the token stages' LogUp refusals depend
  on the input, a dependence that is counted.

## 1. Scope — what a statement would cover

| | |
|---|---|
| Run profile | `hashline-zk-mr1/private-token-io-run-tinyllama-1.1b-t32-trained-statement-public-row/1` (`token_io/run.rs` `RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32`). A blocks-only run may not carry it (`run.rs` `RunStatement::new_bound`, R8) |
| Block profile | `hashline-zk-mr1/private-block-tinyllama-1.1b-t32-trained/1`, the block shape of D33, unchanged |
| Variant and mode | **Public row, mode (i)**: one hidden next token per run, predicted at the public row T−1 = 31. `variant_is_built` refuses every other variant (`token_io/run.rs:165-170`) [READ] |
| Shape of the new stages | Stage IN: A_in 17 rows (9 data), H_in 28 (20 data), M_in 12 rows, 4 slots. Stage OUT: A_out 182 (82 data), H_out 110 (82 data), M_out 26 rows, 11 slots (2 hosted). Stage rows 2^12 at rate 1/4, Q = 256. Token endpoints: 2^8 words at rate 1/8, 6 rows (1 data), one site each. B_in and B_out have the block's internal-boundary geometry (22 rows, 16 data, two sites). The 7 byte limbs give a 53-bit window [MEASURED, every record; COUNTED in `zk60_native_rg_tokenio.py`] |
| Form | **A bound token run only.** One transcript; L + 2 segments; the header absorbs the token run's `calibration` word = BLAKE3("hashline/token-io-calibration/v1" ‖ the trained-model identity ‖ the token-profile digest), which binds the embedding digest, the head digest, the final-norm constants, V, BOS, the variant and the mode (`token_io/run.rs:303-308`) [READ] |
| Calibration | `pg_rot1_b4_T32_cal128` (profile.json `826f7641…`): tn 10; Cn_a 3,583; Cn_m 2,873; Ceps 74,429; shifts qkv 8 / score 6 / o 9 / ao 3 / gate 8 / product 14 / down 4; f_e 9. `per_layer_constants_differ = [exp_e_s, silu_member]`, so R8's per-layer calibration is inert [READ]. Token tables: embedding `fa499c31…`, head `9a28595c…` (per-row int8, 12-bit multipliers, D25 T4), final norm g0 127, Cn 5,664, tn 10, Ceps 74,429; BOS id 1 [READ, `run.json` `token_io`] |
| Lengths in evidence | L = 1 (layer 0), L = 2 (layers 0–1), L = 22 (all), each on `ho00` and on 32 × BOS |
| Hash rule | D19a tag. The token run **keeps its block shape's hash-tag key set**, and its transcript is separated by the run-profile string as domain (D17; design v4 TR-7) [READ] |
| Sealing | The prover seals both token endpoints before the header, after the whole honest forward pass (`token_io/run.rs:598-611, 1009-1013`; D18 option A) |
| Code | The token lane's capture trees, labelled `uncommitted-token-io-r7c` (TinyLlama L = 1, 2) and `…-r7d` (TinyLlama L = 22 and 8B). Every capture's 52 pinned files have frozen-r7's digests (`eb912dd5…`; the gate's token pin check is by digest): 40 equal D33's R7 pins, and 12 are read in `zk60_native_rg_tokenio_r7c_pins.py`. Every capture's pins are read by digest, 0 refused (TC-10 shows a moved or dropped pin refused). **No commit, no integrated tree.** Native R8 is accepted on soundness (D24 review r8). The token files' round-6 review (`results/zk60_token_io_review_r1_20261017/REVIEW5.md`) had no verdict yet when this was written |
| Path | **CPU only, as an operating rule** (D33 §1 "Path"). No GPU-built token receipt was captured or gated |
| Evidence path | **The test harness only**: `token_io/capture_tests.rs` `capture_a_tinyllama_token_run`, which runs the honest pipeline (`honest_pipeline_at`), `prove_token_run` and the production verifier with the recorder. The token CLI (`token_io/cli.rs`) shares the prover and verifier but **has no capture hooks**, so no CLI receipt was gated |
| Coverage over L | Draws per run = 2,329,764·L + 30,208·(L + 1) + 709,664 + 5,632 [COUNTED, §4]. The evidence covers {0}, {0, 1} and {0..21} |

**Not in scope; each owes the argument again:**

- D33's calibration `pg_rot1_export_T32`, and every other calibration
  (F-6 of the D24 review);
- **Llama-3-8B**: measured, not claimed (§0);
- any T other than 32, and any prompt shorter than T. The public-row variant
  makes the prompt length public and equal to T;
- the hidden-length variant P (D25 T2, D26), variant F, and mode (ii). None
  is built, and G-7 of DESIGN §4.2 is owed for them;
- repeated one-token runs as a token stream (D25 T6: not a proved stream);
- the GPU path; hidden weights (P3);
- that the embedding and head named by digest come from the checkpoint
  (D25 T7);
- soundness, which is the reviews'.

## 2. The statement (proposed sentence — not in force)

> In the random-oracle model for BLAKE3 (D19), read as BLAKE3's compression
> function being ideal also at a chaining value the adversary knows (D19b),
> and assuming the prover's generators' joint output is indistinguishable
> from uniform (E-1; X-1 across runs), consider a verifier who:
>
> - receives an **accepted** token-I/O run of the profile in §1, with L
>   blocks;
> - receives it bound to its trained-model statement and token profile;
> - has the export, the embedding and head tables, the context label and the
>   tier fixed before and independently of any hidden input;
> - is neither the input owner nor the output owner;
> - makes at most `q ≤ 2^128` hash queries.
>
> That verifier sees a view within about **2^-74.43 (L = 1), 2^-73.62
> (L = 2), 2^-70.35 (L = 22)** per run of a distribution that does not
> depend on any of the following:
>
> - the hidden prompt ids at positions 1 … T−1;
> - their embeddings;
> - the activations and internal boundary planes;
> - the final-norm values and the logits;
> - the next token.
>
> This holds for every **admissible** prompt. Whether an attempt on an
> admissible prompt is refused is, up to **2^-116.96 / 2^-116.17 /
> 2^-112.93** (two-world distance), a function of the verifier-visible
> challenges and the public tables alone.

**Accepted** means that the party who publishes the run has itself verified
it with the production token-run verifier
(`token_io::run::verify_token_run`), in a fresh process. This is D33's Q-3
rule, transposed. The token CLI's own publication path is not covered by
evidence (§10).

**Admissible** means that the prompt passes the token run's sealing predicate
[READ]:

- every id < V and position 0 = BOS, both refused before any commitment
  (`token_io/stage_in.rs:85-93`);
- the blocks' witness-builder refusals and the final norm's refusals, both
  in the honest pipeline before the endpoints are sealed
  (`token_io/run.rs:1009-1072`);
- stage OUT's byte-lookup check, before the first segment
  (`token_io/run.rs:727-735`);
- ruling CS-3's lookup-miss check on every block witness. **At a token run
  CS-3 runs only inside `prove_core`, after the header and after earlier
  segments exist** (F-T1). Nothing is published, because the sink contract
  holds every segment unpublished until the run returns Ok
  (`token_io/run.rs:690-701`; the CLI's `<out>.incomplete/`).

## 3. What it would rest on, step by step

Each step names what D33 established, what is **new at the token stages**,
what is MEASURED on the token captures, and what is OWED.

### Step 1 — a reference prompt is admissible, proves and verifies

- **New here.** D33's reference was the all-zero input. A zero token plane
  is **not admissible**, because position 0 must be the BOS id (T8;
  `stage_in.rs:92`). So the reference is the degenerate prompt of 32 BOS
  ids. The all-zero-**data** preimages of step 3 are linear statements about
  blinding. They do not need the zero data to be an admissible prompt
  [MINE].
- **MEASURED.** The 32 × BOS prompt proves and verifies with the production
  verifier at L = 1, 2 and 22 (TinyLlama) and L = 1, 2 (8B). Each was
  captured with the recorder (`/home/victor/zk60-artifacts/token-io/captures/*-fixed-pt1`).
- **OWED.** Nothing.

### Step 2 — per commitment, the linear view discloses nothing (G-R1)

- **Argument of record:** the generic rank lemma as D33 carries it [ARGUED
  for D33's commitments]. The lemma is about commitment geometry: rows,
  reserved pairs, groups, the proximity pair, and the pad count equal to the
  opened columns.
- **New here [MINE].** The new commitments use the same PCS, the same
  audit, the same reserved-pair discipline and the same pad count. The shape
  invariants hold:
  - S-1: stage OUT's byte table is at 2^12 = the row width (G-5); stage IN
    has no byte table.
  - S-6: log T = 5 < 12.
  - C-4: the largest new L_s is 82 (stage OUT, rounds 16, degree 5), and
    82 + 256 ≤ 512.
  - The token endpoints sit at a NEW geometry (2^8, rate 1/8, one site), so
    D17's rule-3 hard gate applies. That gate is G-6, measured below.
- **MEASURED** (`EV/token_io/v10/token-v10-tinyllama-t32-L{1,2,22}-{dense,fixed}-pt1.json`),
  on every capture:
  - A_in, A_out, E-token-in, E-token-out, B_in and B_out disclose **0**;
  - H_in and H_out disclose **2**, the exact public LogUp identity;
  - every block A discloses 0, H 2, and every boundary 0;
  - every M discloses 0;
  - k0 = 0; the 16 exclusivity clauses hold on every commitment;
  - the reserved blocks of B_in and B_out have rank 6 of 6.
  - G-2: the partially fixed claim points are accepted with no finding.
    B_in's stage-IN claim has 11 r_emb column coordinates. B_out's stage-OUT
    claim has 5 public bits (row T−1), one of them in the column coordinate.
  - G-6: both token endpoints disclose 0, with a full-rank pad block of 231
    to 245 distinct columns.
- **OWED.** Nothing by measurement. The lemma's coverage of a 2^8 endpoint
  with one site rests on the same derivation (n = 256, Q = 256), and has not
  been read by a reviewer [MINE].

### Step 3 — the gate constructs blinding that reproduces the view under all-zero data

- **New here.** Tools v10 (EV `gate-tinyllama.tools.frozen.v10.sha256`,
  167391ec…) extend the frozen machinery to the new stages:
  - the token replay;
  - the new slots' terminal identity (`zk60_native_rg_tokenterminals.py`);
  - the block-stage terminal identity inside a token run
    (`zk60_native_rg_tokenblocks.py`);
  - **a computed word-level joint** over the shared planes (a 2^12-word
    stage row identified with a 2^8-word endpoint row);
  - the full preimage and the joint assignment on every commitment.

  Every rank, preimage and hash computation is the frozen code's.
- **MEASURED**, on all six TinyLlama captures:

  | | L = 1 dense / fixed | L = 2 dense / fixed | L = 22 dense / fixed |
  |---|---|---|---|
  | Status | PASS / PASS | PASS / PASS | PASS / PASS |
  | All-zero-data preimage, every commitment: commitments, entries, differing | 10, 1,376,986 / 1,384,340, 0 | 13, 2,500,124 / 2,493,904, 0 | **73**, 24,883,666 / 24,834,113, **0** |
  | Masking layer and CFS (G-3), per stage: functionals, differing | IN 8, OUT 20, block 34; 0 | the same; 0 | the same at 24 stages; 0 |
  | Joint assignment C1–C4 | respected | respected | respected |
  | Computed joint over tok / B_in / B_out | 0 = sum 0, 133,153 word pairs | 0 | 0 |
  | Terminal identity: new slots / block slots | 15 / 15; 23 / 23 | 15 / 15; 46 / 46 | 15 / 15; **506 / 506** |
  | Controls (live / not applicable) | 36 / 2 | 36 / 2 | 36 / 2 |
  | Costs (wall, peak) | 714 / 653 s, 0.55 GiB | 862 / 832 s, 0.60 GiB | 3,756 / 3,429 s, 1.75 GiB |

  The two not-applicable controls are M4 on IN and OUT (no bilinear slot).
  The block terminals' own controls NC-0..NC-4 fire (NC-4 from L = 2).
  The 8B records give the same verdicts at L = 1, 2 (§0; the report §2).
- **What the taken tables do not establish.** Two public tables of the new
  slots are taken from the capture: stage IN's τ table, which folds the
  embedding, and stage OUT's head fold `W'(r_j, ·)`. They are checked for
  length, sha256 and builder structure only, because no bundle carries the
  embedding or the head. That they fold **the statement's** tables rests on
  the verifier's own computation from the tables the statement names by
  digest, not on this gate [READ: the gate report §2.1].
- **OWED.** Nothing by this page's evidence rule.

### Step 4 — the joint law of all published field values is input-free (Theorem B)

**Argument of record:** D33's step 4 (the joint-law composition, accepted as
a reduction conditional on G-R1, G-R2, G-R4 and G-R5) [ARGUED for the block
stages]. It is extended here to two more stages of the same transcript
[MINE].

- **G-R2, the new slots [MEASURED in part].**
  - NL-1's S1 premises hold on all 15 new slots:
    - a public table factor in every monomial, with the affine 1 − supp
      split by the expansion;
    - product degree ≤ the declared degree;
    - the private-terminal count equals the slot's terminals;
    - one extension round with every private table in round 0.
  - Observations, which are not findings: in IN-03 and OUT-09 one
    monomial's only public factor has a constant MLE (the all-ones factor of
    a zero-sum slot), and in OUT-01, OUT-02 and OUT-07 some monomials carry
    only indicator tables.
  - **NL-1's S3 (Fact 2.1), S4 (onto: the terminal surjection) and S5 on the
    new slots are NOT run** (OWED, §10). The block slots' S0–S5 and their
    terminal surjection were measured at D33's calibration. At b4 the
    coefficients that differ (Ceps, Cn_a, Cn_m, sh_z) are non-zero public
    constants. The four identical lookup pairs of D31 occur here too
    (sh_qkv = sh_g = 8), and no new pair arises (sh_z = 4 gives coefficient
    16) [MINE, from `profile.json`].
- **G-R4, the draw discipline [READ, not replayed].** The token stages draw
  in the block's pattern:
  - mask rows by `rng.fp()` from the mask base, then
    `commit_zk_owned_tagged` (pads, then salts);
  - H's zero-sum pair re-drawn;
  - one `mask_commit_tagged` per stage;
  - B_in by `boundary::prepare`;
  - all on **one** OS-seeded run generator, the same stream as the blocks
    (`token_io/run.rs:744, 758, 786, 815`; `stage_in.rs:303-362`;
    `stage_out.rs:672-727`);
  - the two token endpoints on their own generators (`endpoint_g::prepare`,
    `run.rs:609-610`).

  **The stage-47 root-rebuild check is not ported to the token stages**
  (OWED). D33's review held that "the reading suffices" is not enough
  (P-12).
- **R-1 / H-1, the production caller [READ].** The honest pipeline builds
  every witness first:
  - stage IN's witness, each block's witness at its stage shape, and the
    final norm, head and keyed argmax (`token_io/run.rs:1009-1072`);
  - with every witness builder's refusal;
  - then the endpoints are sealed (`run.rs:606-611`).

  Inside `prove_token_run_with`, before the first segment:
  - the variant is checked;
  - the tables are checked against the statement's digests;
  - the owners are checked against the statement's roots;
  - stage OUT's byte-miss refusal runs;
  - every block's CS-1 / CS-4 / CS-6 runs (`run.rs:703-740`).

  **Two refusal kinds can occur after the header** (F-T1, F-T2):
  - CS-3 in `prove_core`;
  - the token stages' zero-LogUp-denominator refusals.

  The sink contract keeps every segment unpublished until Ok, so **no
  refusal publishes anything** (D20 / D21). D33's "every refusal of an
  inadmissible chain happens before the header" (H-1 by code) does **not**
  hold at a token run.
- **The owners (D25 T5) [READ].** The prover hands each owner its endpoint's
  decommitment (rows, 256 pads per row, salts) privately
  (`stage_in.rs:390`, `OwnerHandoff`). The owner re-encodes, checks the root,
  and (the input owner) checks BOS at position 0. The decommitment lets its
  holder unmask its endpoint's IO terminal, so **each owner is outside the
  adversary for its own endpoint** (DESIGN §3.4). Opening an endpoint twice
  would recover a 512-coefficient row (D11), and the code opens each
  exactly once.
- **The new channels (DESIGN §4.3) [MINE, checked against the captures].**
  - **V and V_pad** are public. The vocabulary pads (768) carry the
    pad-zero factor (G-4).
  - **The token histogram m** is a hidden plane like the byte histograms,
    claimed once and masked; A_in discloses 0.
  - **Ties** are inside hidden δ limbs (the transcript's shape does not
    change).
  - **The low-entropy next token** (one id among 2^15) is hidden by the
    endpoint's salts, pads and five random rows, not by entropy (G-6
    measures disclosed 0).
  - **The verifier's tables** (τ, ι, supports, u0) are functions of public
    data and challenges.
- **MEASURED.**
  - The computed joint equals the sum of the parts (0 = 0) at every L.
  - The whole-run block joint stays the block figure.

  > *Ruling R-3 applies:* joint = sum of parts is a consistency check, not
  > evidence of independence.

### Step 5 — the hash layer adds nothing (G-R5)

- **Argument of record:** D33's step 5 (Lemma H^run, Route A^run) under
  D19b [ARGUED]. Unchanged in kind: more roots, the same keyed roles.
- **New here [READ].** The two token run-profile strings were chosen so that
  their transcript-constructor inputs differ from every other hash-input
  length, and lie one byte from none of them: 98 B at TinyLlama and 94 B at
  8B (stage 25's W-2 census; `private_block/run.rs:97-115`). C-R1 and C-R2 are to be
  re-read for the token absorbs (OWED as a reading).
- **MEASURED**, in every record:
  - every challenge is re-derived and the run binding reproduced (5,347 /
    9,838 / 99,658 challenges at L = 1, 2, 22);
  - every opened column is re-hashed and re-authenticated under the derived
    keys (3,328 / 4,352 / 24,832 columns);
  - no wrong hash rule reaches a root.

## 4. Residuals, sized [COUNTED]

**Source:** `EV/round9/token_run_counts.py`; outputs
`EV/round9/token_run_counts.{L1L2,L22}.json`.

**Method.** D33's formulas (the frozen `counts/run_hash_counts.py`), each
re-read for the token stages, applied to **each capture's own geometry**.
Two controls hold on every TinyLlama capture: K-1, a block stage = D33's
2,329,764 draws, and K-2, a boundary = D33's 30,208.

**Draw sites.** A hiding commitment draws (rows − data)·n + rows·Q. An H
re-draws its zero-sum pair, 2(n − 1). A masking commitment draws
2·ΣL_s + 2·N_slots·Q + 4,096.

**Measured transcript queries.** These come from an instrumented replay that
counts every absorb and squeeze on every transcript instance, an over-count.

| Term | L = 1 | L = 2 | L = 22 | Kind |
|---|---|---|---|---|
| Field draws per run | 3,105,476 | 5,465,448 | 52,664,888 | — |
| … of which stage IN / stage OUT / 2 token endpoints | 91,744 / 617,920 / 5,632 | the same | the same | — |
| Sampler bias (D9): draws × 2^-96 | **2^-74.43** | **2^-73.62** | **2^-70.35** | distance |
| Input-dependent refusal, two-world, 2·(768L + T + 256)/p² | 2^-116.96 | 2^-116.17 | 2^-112.93 | distance |
| Salt guessing, q·N_leaf·2^-256 (N_leaf 147,456 / 200,704 / 1,265,664) | 2^-110.8 | 2^-110.4 | 2^-107.7 | distance |
| Transcript pre-query (A = 7,173 / 12,502 / 119,082, measured) | 2^-115.2 | 2^-114.4 | 2^-111.1 | distance |
| Leaf-input / transcript-input collisions | 2^-222.7 / 2^-231.4 | 2^-221.8 / 2^-229.8 | 2^-216.5 / 2^-223.3 | distance |
| Generator, in-model alternative (6q·2^-256, ASSUMED) | 2^-125.4 | 2^-125.4 | 2^-125.4 | assumption |
| Generator-key row, 3·4·2^-256 | 2^-252.4 | 2^-252.4 | 2^-252.4 | distance |
| Constructor vs absorb, (A + q)·2^-256 | 2^-128.0 | 2^-128.0 | 2^-128.0 | distance |
| **Total distance** | **2^-74.43** | **2^-73.62** | **2^-70.35** | |
| Refusal on degenerate challenges, (3L + 7)/p | 2^-60.7 | 2^-60.3 | 2^-57.8 | **liveness, not distance** |
| 10^6 runs, linear | 2^-54.5 | 2^-53.7 | 2^-50.4 | distance |

**Notes.**

- **Against D33** (blocks only, at the same block shape): 2^-74.82 /
  2^-73.82 / 2^-70.37. The token stages add about 0.72 M draws per run.
- **The refusal term is NEW in kind** (F-T2) [READ]. D33's blocks invert
  their whole tables on every attempt, so their refusal fact depends only on
  the challenges and the public tables (D33 §4). The token stages do not:
  - stage IN inverts only the prompt's positions and the table rows of
    non-zero multiplicity (`stage_in.rs:336-346`);
  - stage OUT inverts only the occurring byte limbs and the non-zero
    histogram rows (`stage_out.rs:566-577, 700-711`).

  Both refuse with "discard attempt" after B_in / A_in / M_in (A_out /
  M_out) exist. The input-dependent part is bounded by the arguments either
  world can reach, at most T table rows at stage IN and 256 byte values at
  stage OUT, each hit with probability 1/p². The count above uses D33's
  two-world convention, 2C/p².
- **8B, measured but not claimed** (§0):

  | | L = 1 | L = 2 |
  |---|---|---|
  | Draws | 4,662,142 | 8,437,408 |
  | Total distance | 2^-73.85 | 2^-72.99 |
  | Refusal, two-world | 2^-116.96 | 2^-116.17 |

## 5. Conditions — D33's, and those the token stages add

| # | Condition | State at the token captures |
|---|---|---|
| 1–6 | D33's conditions 1–6 (reserved pairs and exclusivity; pad count = opened columns; mask rounds and functional order; one opening per commitment; salted leaves; fresh OS randomness) | Carried for the blocks. For the new commitments: exclusivity 16 / 16 measured; pad count = opened columns by the same PCS; the M arm re-derives every functional (G-3); one opening per commitment, **the token endpoints each opened once** (input at stage IN, output at stage OUT); one run generator plus two endpoint generators [READ] |
| 7 | The gates' source pins; a change suspends step 3 | **frozen-r7's 52 pins**, every one read (40 D33 / R7 + 12 token r7c). TC-10 shows a moved or dropped token pin refused. **No integrated tree** |
| T-1 | The public-row variant only; T = prompt length; BOS at position 0 | Code fact: `variant_is_built`, `stage_in.rs:85-93` |
| T-2 | Each owner's decommitment is private and never published (D21); no endpoint root is registered or referred to later (D23) | An operating rule (§6). The code hands each decommitment over in `OwnerHandoff` and publishes none [READ] |
| T-3 | The run binds the embedding, the head, the final-norm constants, V, BOS, the variant and the mode through its calibration word | Code fact (`token_io/run.rs:290-308`) |
| T-4 | One opening per token endpoint, at the place the statement fixes | Code fact; integrity control TC-6d refuses an endpoint "opened elsewhere" |
| S | D33's shaped invariants for the blocks; for the new stages, S-1 (byte table at the row width) and C-4 (mask budget) | Measured (G-5; largest L_s 82) |
| P-4 | The export, the embedding and head tables and the context are fixed before and independently of any hidden input; no prompt is retried under another calibration, table or label | A HYPOTHESIS the sentence carries |

## 6. Hypotheses and operating rules

D33's §6 rules carry over, with these additions:

- **CPU only.** The deployment runs a CPU build of frozen-r7 (or an
  integrated tree that replaces it). No token CPU binary is named by digest
  in this draft. Naming one is owed before a statement can be in force.
- **Publication.** Publish a token run only after one's own fresh-process
  verification. Never publish an owner's decommitment, the prompt, the next
  token, prover stdout, refusal text or verifier output.
- **Owners.** The input owner and the output owner are outside the
  adversary for their own endpoint. The private channel to each is assumed
  confidential and authentic.
- **One token per run** (D25 T6). Repeated runs are not a proved stream, and
  nothing links run k + 1's prompt to run k's output.
- **No endpoint root reuse** (D23).

## 7. Findings, with dispositions (new in this draft; none has been reviewed)

| # | Finding | Proposed disposition |
|---|---|---|
| **F-T1** | **CS-3 is not in the token run's sealing pass.** The token pipeline (`honest_pipeline_at` / `downstream_at`) and `prove_token_run_with`'s pre-checks do not call `check_lookup_misses`. A block witness's lookup miss is refused only inside `prove_core`, after the header and after stage IN's segment exists [READ: no `lookup_misses` call in `token_io/`; R7's trained CLI calls it in its sealing pass, `trained_block.rs:2075`] | Nothing is published (sink contract). Admissibility includes CS-3. "Every refusal before the header" is not claimed for token runs. For the security owner: accept the weaker form, or ask the token lane to run CS-3 in the token sealing pass, as R6 did for the trained CLI (N-r5-a) |
| **F-T2** | **The token stages' LogUp refusals depend on the input.** Only witness-side arguments are inverted (§4 note), after the stage's first commitments | Counted as a distance term at D33's convention: 2^-116.96 at L = 1. For the security owner: accept the term, or have stage IN and stage OUT invert their whole tables on every attempt, as the blocks do, which would make the refusal fact challenge-only |
| F-T3 | The τ table and the head fold are taken from the capture and checked by digest and structure only | §3 step 3. Not a gap in the view's analysis. It records that the gate does not re-fold the 65.5 M-entry head |
| F-T4 | The token capture writer lacks the gate's trained-calibration shape keys | The block terminals take the calibration from the export the capture's README names, cross-checked X1–X10 against the token header and the layout description (report §2.3) |
| F-T5 | NL-1's S3 / S4 / S5 on the 15 new slots are not run | OWED (§10) |
| F-T6 | G-R4's root-rebuild replay of the token stages is not ported | OWED (§10) |
| F-T7 | The block layer at `pg_rot1_b4_T32_cal128` lacks the trained gate's block control families, its pin controls, G-10 and the export cross-check | OWED (§10), or a capture at D33's calibration (§0) |

## 8. What must not be claimed, even if this came into force

- That the prompt length is hidden. It is public (= T) in this variant.
- That the next token is hidden from its output owner, or the prompt from
  its input owner.
- That a sequence of runs proves a continuation (T6).
- Anything at another calibration, at 8B, at another T, on the GPU, or for
  variants P / F / mode (ii).
- That the embedding and head are the checkpoint's (T7).
- That D33 covers the token stages, or that this draft covers D33's
  calibration.
- Soundness.

## 9. What would lapse or reopen it

- Anything in D33 §9 that touches the blocks;
- a change to any of frozen-r7's 52 pinned files;
- a finding against any step of §3 or against F-T1 / F-T2's dispositions;
- an endpoint opened twice, or a decommitment published;
- an endpoint root referred to by a later artifact (D23);
- a GPU-built receipt;
- a token table or a calibration outside what the gate measured.

## 10. What is owed before the security owner could rule

1. **An independent privacy review of this draft**, attacking each step.
2. **NL-1's S3 / S4 / S5 on the new slots** (F-T5): the terminal surjection
   of stage IN and stage OUT on captured stage files.
3. **G-R4 for the token stages** (F-T6): port the stage-47 root-rebuild
   replay to stage IN, stage OUT, B_in and the token endpoints.
4. **The block layer at b4** (F-T7): the trained gate's control families,
   pin controls, G-10 and the export cross-check on block bundles at
   `pg_rot1_b4_T32_cal128`. Alternatively, the token-I/O inputs and token
   captures at D33's calibration, which would let a statement extend D33.
5. **F-T1 and F-T2:** the security owner's disposition.
6. **A named CPU token binary**, and a capture through the token CLI's own
   path (it needs capture hooks), as P-18 did for D33.
7. **The token tree's round-6 soundness verdict** (`REVIEW5.md`), and an
   integrated tree.

## 11. Evidence index

| What | Where |
|---|---|
| Token gate report (v10) | `EV/token_io/TOKEN_GATE_REPORT_T32_v10.md` (bcd01bb4…) |
| Records and summary | `EV/token_io/v10/token-v10-*.json`, `token-v10-summary.json` (31e7b40e…) |
| Tools | `EV/gate-tinyllama.tools.frozen.v10.sha256` (167391ec…); `ops/zkp-mvp/gate-tinyllama/frozen_v10/` |
| Token pin readings | `ops/zkp-mvp/gate-tinyllama/frozen_v10/scripts/zk60_native_rg_tokenio_r7c_pins.py`; `EV/token_io/readings/token_r7c_pin_readings.json` |
| Residual counts | `EV/round9/token_run_counts.py`, `EV/round9/token_run_counts.{L1L2,L22}.json` |
| Captures (read in place, outside the repo) | `/home/victor/zk60-artifacts/token-io/captures/` |
| Design | `results/zk60_token_io_design_20261017/DESIGN.md` §§3.3–4.3 |
| D33 (the blocks' statement in force, at another calibration) | `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TRAINED_TINYLLAMA_T32.md` |
| D33's re-pin onto frozen-r7 (gate evidence) | `EV/tk7/ZK60_PRIVACY_STATEMENT_REPIN_TK7_20261019.md` |
