# Privacy statement for the next-token proof (token-I/O run, public-row variant, mode (i), TinyLlama-1.1B T32), DRAFT v2: for privacy review round 5 (not accepted, not in force)

Drafted 2026-10-20 from 05:14 UTC and frozen at 05:20 UTC by the PRIVACY GATE
lane, a delegated Claude Opus 5.5 agent, at the coordinator's request (gate
round 11).

**This is draft v2.** It supersedes draft v1,
`EV/round9/PRIVACY_STATEMENT_NEXT_TOKEN_T32_DRAFT.md` (sha256 abccfc64…).
v1 is kept unchanged as history.

v2 does the following:

- moves the scope to the token lane's **frozen-r9** tree and the named CPU
  token binary **b56f1b71…**;
- folds in the round-10 addendum, D34 and D35, and the closed review items
  PR4-4, 7, 8, 9, 10, 15, 16 and 17;
- makes the wording edits PR4-6, 13, 14 and 17, and TR7-4;
- records REVIEW5 and REVIEW6 as the answer to PR4-11.

It follows the form of the trained statement in force,
`docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TRAINED_TINYLLAMA_T32.md` (register
**D33**). It is a separate draft beside D33, not an edit of it.

| Status | **DRAFT v2 for privacy review round 5. NOT accepted, NOT in force, and NOT a privacy acceptance. Nothing on this page establishes a privacy property.** It proposes a sentence for the next-token proof and lists what that sentence rests on, what is measured, and what is still owed. Draft v1 was attacked once, by privacy review round 4 (`results/zk60_privacy_review_trained_t32_20261017/REVIEW4.md`, verdict NOT YET, with a closed list PR4-12). This draft answers that list. The decision is the security owner's, and rulings are Victor's. |
|---|---|

**Labels.**

- [MEASURED]: a run happened and a record is cited. Shared box, one run
  unless stated.
- [COUNTED]: arithmetic from the code and the captured geometry.
- [READ]: a fact read in a cited source line or document.
- [ARGUED]: an argument that survived one independent attack in D33's record
  (the reviews named there). It is carried here only where the token stages
  do not change it.
- **[R4]**: a claim of draft v1 that privacy review round 4 checked and
  confirmed (section cited).
- **[MINE]**: my own reading or arithmetic for this page, checked by nobody.

**Sources.**

- **EV** is `results/zk60_gate_tinyllama_20261017/`, with ledger
  `EV/PROGRESS.md`.
- The token-gate report of record (gate round 7) is
  `EV/token_io/TOKEN_GATE_REPORT_T32_v10.md` (bcd01bb4…).
- **The round-10 addendum**:
  `EV/round9/PRIVACY_STATEMENT_NEXT_TOKEN_T32_DRAFT.ADDENDUM-20261020.md`
  (f2b6ac8d…). It was accepted by the coordinator as gate evidence.
- The design is `results/zk60_token_io_design_20261017/DESIGN.md` (v4).
- **frozen-r9** is the token lane's frozen round-9 tree:
  - `results/zk60_token_io_r1_20261017/frozen-r9/`;
  - 236 files, manifest `manifest_final_r9.sha256`, list sha256 `b666a991…`;
  - it is frozen-r7 (native R8 plus the token files) plus the token lane's
    rounds 8 and 9;
  - frozen 2026-10-20 03:00 UTC (`frozen-r9.FROZEN.txt`).
- **Code reviews of the token tree**, both in
  `results/zk60_token_io_review_r1_20261017/`:
  - REVIEW5 (round 6, on frozen-r7);
  - REVIEW6 (round 7, on frozen-r9).
- **Register:** D33 (the blocks' statement in force), D34 (the
  input-dependent refusal, priced) and D35 (which block-layer evidence
  carries to b4).

## 0. In plain words

### What would be claimed

Consider a verifier who receives an **accepted** next-token run of the
trained TinyLlama, as the integer model the export defines. The run covers,
under one transcript:

- the embedding lookup;
- the trained blocks;
- the final norm;
- the head;
- the greedy choice of the next token.

That verifier **is never given** any of these, and what it is given is
within a distance of about **2^-70.35 per 22-block run** (2^-74.43 at L = 1,
2^-73.62 at L = 2) of a distribution that does not depend on them:

- the prompt's token ids at positions 1 to 31;
- their embedding rows;
- the hidden activations and the planes between blocks;
- the final norm's values and the logits;
- **the next token itself.**

The next token is the **integer model's** next token: the greedy choice of
the approved integer version of the model, not of the float checkpoint. The
fidelity caveat is the calibration lane's.

The model of the claim is D33's: D19, D20, D21 and D19b, with the generator
assumption E-1 / X-1.

The verifier does see the public facts of the profile:

- T = 32 is the prompt length. In the public-row variant the prompt fills all
  32 positions.
- The token at position 0 is the profile's BOS (D25 T8).
- V = 32,000.
- The embedding table, the final-norm constants and the head, by digest.
- The run length L, the trained-model identity and the tier.

**The two owners are outside the adversary for their own endpoint** (DESIGN
§3.4):

- The **output owner** receives the output endpoint's decommitment, which
  unmasks the next token.
- The **input owner** holds the prompt.

Neither decommitment is ever published (D21), and no endpoint root is ever
referred to by a later artifact (D23).

**This page claims nothing about what an output owner who is not also the
input owner learns about the prompt beyond the token** (PR4-13). In the
usual deployment the two owners are one party, and then nothing is at stake.

### Which calibration and which code each claim covers

- **One calibration only: `pg_rot1_b4_T32_cal128`** (profile.json
  `826f7641…`). This is the export of every TinyLlama token capture.
- **It is not D33's calibration `pg_rot1_export_T32`, and this page does not
  extend D33.**
  - The two exports differ in Ceps (74,429 against 91,255), Cn_a (3,583
    against 3,999), Cn_m (2,873 against 3,122), sh_z (4 against 5) and the
    per-layer tables [READ].
  - `pg_rot1_export_T32` has no token-I/O inputs (no `embedding_int16.bin`,
    no final-norm calibration).
  - **D35** records which block-layer evidence carries from D33's
    calibration to b4.
- **The code is frozen-r9**, and the CPU binary is the token lane's named
  binary **`zk60_token_io.r9.release.bin`, sha256 b56f1b71…**
  (`results/zk60_token_io_r1_20261017/cli/`). It was built from manifest_r9C,
  which is frozen-r9's manifest (build note `zk60_token_io.r9.BUILD.txt`).
- **Llama-3-8B T32** (`llama3_8b_pg_rot1_b7voc0_T32`) is MEASURED at L = 1
  and 2 by the same token gate, but it is **not in the sentence**. Its block
  layer has no gate of record: no NL-1 or surjection at the 8B block slots,
  no block control families, no stage-47 replay at 8B.
- **T128** profiles exist in frozen-r9, but no T128 token receipt was
  captured or gated. They are **not in the sentence**.

### What has been measured

- **The token gate on ten harness captures**:
  - TinyLlama at L = 1, 2 and 22, and 8B at L = 1 and 2;
  - each on the held-out prompt `ho00` and on the degenerate admissible
    prompt of 32 BOS ids;
  - **all ten PASS** (gate round 7, tools v10).
- **The owed items closed in gate round 10** (the addendum), all [MEASURED]:
  - NL-1 S1–S5 and the terminal surjection on the 15 new slots, on all ten
    captures;
  - the stage-47 root-rebuild replay of the token stages (L = 1, 2), on
    frozen-r7 code and again on frozen-r9 code;
  - the b4 calibration attribution, 10 of 10;
  - the tk7 CLI capture.
- **One capture through the named binary's own CLI path**
  (`tinyllama-t32-L2-dense-pt1-cli-r9`):
  - TinyLlama L = 2, held-out prompt;
  - made P-18 style with no CLI hook;
  - pins exactly frozen-r9's 52 files;
  - **PASS** under the token gate (tools v14).
- **The token tree's soundness review** on frozen-r9 (REVIEW6): demo-fit,
  with nothing that affects soundness or leaks the prompt or the answer.

### What is still open (§10)

- Privacy review round 5 of this draft.
- The security owner's decision.
- Optional: re-capturing the ten harness captures on frozen-r9 (§1 "Code").

## 1. Scope — what a statement would cover

| | |
|---|---|
| Run profile | `hashline-zk-mr1/private-token-io-run-tinyllama-1.1b-t32-trained-statement-public-row/1` (`token_io/run.rs` `RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32`). A blocks-only run may not carry it (`private_block/run.rs` `RunStatement::new_bound_from_digests`, which since round 8 refuses all five token profiles) [READ] |
| Block profile | `hashline-zk-mr1/private-block-tinyllama-1.1b-t32-trained/1`, the block shape of D33, unchanged |
| Variant and mode | **Public row, mode (i)**: one hidden next token per run, predicted at the public row T−1 = 31. `variant_is_built` refuses every other variant (`token_io/run.rs:165`) [READ] |
| Shape of the new stages | Stage IN: A_in 17 rows (9 data), H_in 28 (20 data), M_in 12 rows, 4 slots. Stage OUT: A_out 182 (82 data), H_out 110 (82 data), M_out 26 rows, 11 slots (2 hosted). Stage rows 2^12 at rate 1/4, Q = 256. Token endpoints: 2^8 words at rate 1/8, 6 rows (1 data), one site each. B_in and B_out have the block's internal-boundary geometry (22 rows, 16 data, two sites). The 7 byte limbs give a 53-bit window [MEASURED, every record; COUNTED] |
| Form | **A bound token run only.** One transcript and L + 2 segments. The header absorbs the run's `calibration` word = BLAKE3("hashline/token-io-calibration/v1" ‖ the trained-model identity ‖ the token-profile digest). That word binds the embedding digest, the head digest, the final-norm constants, V, BOS, the variant and the mode (`token_io/run.rs:303-308`) [READ]. It is recomputed from the export and the named tables in gate round 10 (PR4-9) [MEASURED] |
| Calibration | `pg_rot1_b4_T32_cal128` (profile.json `826f7641…`): tn 10; Cn_a 3,583; Cn_m 2,873; Ceps 74,429; shifts qkv 8 / score 6 / o 9 / ao 3 / gate 8 / product 14 / down 4; f_e 9. `per_layer_constants_differ = [exp_e_s, silu_member]`, so R8's per-layer calibration is inert [READ]. Token tables: embedding `fa499c31…`, head `9a28595c…` (per-row int8, 12-bit multipliers, D25 T4), final norm g0 127, Cn 5,664, tn 10, Ceps 74,429; BOS id 1 [READ, `run.json` `token_io`]. **The trained-model identity is the identity of the export the prover loaded.** A view of the export with profile.json's layer list cut to L has its own identity, but the same block files and constants. Example: the CLI capture's 2-layer view has identity 0f4cef3e… and word 45ce7431…, and its block digests equal the b4 layers 0 and 1 [MEASURED, round 10] |
| Lengths in evidence | L = 1 (layer 0), L = 2 (layers 0–1), L = 22 (all), each on `ho00` and on 32 × BOS (harness); L = 2 on `ho00` through the CLI |
| Hash rule | D19a tag. The token run **keeps its block shape's hash-tag key set**, and its transcript is separated by the run-profile string as domain (D17; design v4 TR-7) [READ] |
| Sealing | **Every input-provokable refusal comes before the run header**, at both production callers (frozen-r9; REVIEW6 §2.1). The full list is in §2 "Admissible" |
| Code | **frozen-r9**, 236 files, `b666a991…`. **Condition 7's pin set is frozen-r9's 52 pinned files**, each read: 40 equal D33's R7 pins; 6 are token r7c readings (`shape.rs`, `trained_statement.rs`, `trained_block.rs`, `private_block.rs`, `token_io/stage_out.rs`, the token writer `run_capture.rs` aaff4e6e); 6 are the round-9 readings (`zk60_native_rg_tokenio_r9_pins.py`: `private_block/run.rs` cc2c4204…, `token_io.rs` 602597ad…, `token_io/stage_in.rs` e4609b1a…, `token_io/run.rs` 4671d03e…, `token_io/load.rs` 8c041721…, `token_io/cli.rs` b9079130…). These were read pre-freeze on manifest_r9C, and the six frozen digests equal them [MEASURED]. **Evidence on two pin sets:** the ten harness captures were made on the token lane's capture trees with **frozen-r7's** 52 pins (`…-r7c`, `…-r7d`); the CLI capture has **frozen-r9's**. The harness evidence carries to frozen-r9 by reading and measurement (below). **No commit, no integrated tree**: a frozen copy with its 52 pins is condition 7's object, as for D33 (REVIEW4 §2.5) |
| Carry from frozen-r7 to frozen-r9 | [READ] None of the six round-9 changes moves a byte of a T32 token receipt (each reading's `moves_a_receipt_byte` is False). [READ, REVIEW6 §2.1] From the run generator and the header on, `prove_token_run_with` is frozen-r7's line for line; the moved `src.stage_in()` touches neither the transcript nor the generator. [MEASURED] The token stage-47 replays on frozen-r9 code (the gate's tk9 copy) consumed exactly the bytes they consumed on frozen-r7: 54,185,024 at L = 1 and 93,648,512 at L = 2. [MEASURED] The CLI capture under frozen-r9's pins passes the same gate, figure for figure where the shape is shared (§3) |
| Binary | **b56f1b71…** (the token CLI `zk60_token_io`, CPU only, gpu-cuda not compiled in). It was built in the token lane's working-copy path, so the statement names these bytes, not a rebuild |
| Path | **CPU only, as an operating rule** (D33 §1 "Path"). No GPU-built token receipt was captured or gated |
| Evidence paths | (1) **The test harness**: `token_io/capture_tests.rs` `capture_a_tinyllama_token_run`, with the honest pipeline, the generic prover and the production verifier with the recorder. (2) **The CLI path**: `capture_the_cli_verify_path_at_tinyllama_t32_l2`. The named binary's own processes ran `prove`; then `verify` accepted the run from a verifier copy without `seq_*` and published its statement. The run directory was then read with the CLI's own readers and verified with the recorder attached, with no CLI hook (P-18; PR4-10) [READ, the capture's README; MEASURED, the token lane's log `logs/c9-cli-capture.log`] |
| Coverage over L | Draws per run = 2,329,764·L + 30,208·(L + 1) + 709,664 + 5,632 [COUNTED, §4; R4 §2.1]. The evidence covers {0}, {0, 1} and {0..21} |

**Not in scope; each owes the argument again:**

- D33's calibration `pg_rot1_export_T32`, and every other calibration (F-6
  of the D24 review);
- **Llama-3-8B** (measured, not claimed) and **T128** (built, not gated);
- any T other than 32, and any prompt shorter than T. The public-row variant
  makes the prompt length public and equal to T;
- the hidden-length variant P (D25 T2, D26), variant F, and mode (ii). None
  is built, and G-7 of DESIGN §4.2 is owed for them;
- repeated one-token runs as a token stream (D25 T6: not a proved stream);
- the GPU path, and hidden weights (P3);
- that the embedding and head named by digest come from the checkpoint
  (D25 T7);
- soundness, which belongs to the code reviews and D24.

## 2. The statement (proposed sentence — not in force)

> In the random-oracle model for BLAKE3 (D19), read as BLAKE3's compression
> function being ideal also at a chaining value the adversary knows (D19b),
> and assuming the prover's generators' joint output is indistinguishable
> from uniform (E-1; X-1 across runs), consider a verifier who:
>
> - receives an **accepted** token-I/O run of the profile in §1, with L
>   blocks, written by the frozen-r9 code (the CPU binary b56f1b71…);
> - receives it bound to its trained-model statement and token profile;
> - has the export, the embedding and head tables, the context label and the
>   tier fixed before and independently of any hidden input;
> - is neither the input owner nor the output owner;
> - makes at most `q ≤ 2^128` hash queries.
>
> That verifier is never given any of the following, and its view is within
> about **2^-74.43 (L = 1), 2^-73.62 (L = 2), 2^-70.35 (L = 22)** per run of
> a distribution that depends on none of them:
>
> - the hidden prompt ids at positions 1 … T−1;
> - their embeddings;
> - the activations and internal boundary planes;
> - the final-norm values and the logits;
> - the integer model's next token.
>
> This holds for every **admissible** prompt.
>
> Whether an attempt on an admissible prompt is refused is not a function of
> the challenges alone. It may depend on the hidden prompt with probability
> at most **2^-116.96 / 2^-116.17 / 2^-112.93** per run (L = 1 / 2 / 22). This
> is a two-world distance, counted in the figures above (D34).
>
> Nothing is claimed about what an output owner who is not the input owner
> learns about the prompt beyond the token.

**Accepted** means the party who publishes the run has verified it itself in
a fresh process. It does so either with the named binary's `verify`, or with
`token_io::run::verify_token_run`. This is D33's Q-3 rule, transposed.

- The CLI's `verify` writes the run's statement itself, from its own
  rendering and the hashes of the verified bytes, and removes the prover's
  unverified copy (M-9 / r5_A) [READ, REVIEW4 §2.6].
- It did so in the CLI capture ("published_by: this verifier") [MEASURED].

**Admissible** means the prompt passes the token run's sealing predicate.
Under frozen-r9, every part of it is checked **before the run header**, so a
refused attempt has built no header and handed the sink nothing [READ,
`token_io/run.rs:748-775`; REVIEW6 §2.1].

**Generic prover** (`prove_token_run_with`; the harness path):

1. Stage IN's witness builder `honest_inputs` refuses an id ≥ V or a
   non-BOS position 0, before any commitment (`token_io/stage_in.rs:88-93`).
2. **The sealing pass**, before `ZkRng::from_os` (`run.rs:777`) and the
   header (`run.rs:780`):
   - stage IN's `lookup_misses` (`stage_in.rs:119`), which checks:
     - every id < V and BOS at 0;
     - each B_in row is the id's embedding row, with zero pads;
     - the pad positions are zero;
     - `m` is the prompt's histogram;
   - the input endpoint's committed words are the prompt plane;
   - for every block:
     - CS-1 / CS-4 / CS-6 (`stage_block_is_the_statements`);
     - **CS-3** (`protocol::check_lookup_misses`, through the source's
       `seal_check`) at the stage's own shape and layout;
   - stage OUT's byte-lookup check;
   - the output endpoint's words are the decided id's plane.
3. The witness builders' and the final norm's refusals (D20). These fire in
   the honest pipeline, before the endpoints are sealed.

**The CLI** (`prove_inner`, `token_io/cli.rs:612`; the named binary's path)
runs, in order:

1. the claimed directories;
2. `--prompt` refused, and the prompt file read (PR4-17);
3. ids and BOS;
4. B_in = the export's `x_in_L00`;
5. **`seal_chain`** (`cli.rs:728`). For each block, at its stage shape, it:
   - reloads the block (CS-6);
   - builds the witness from the builder's own chain;
   - checks int16 range;
   - checks bit-exact parity against the export;
   - runs CS-3.

   It then takes the next token from the builder's last plane, not from the
   export's reference;
6. D20;
7. the endpoints;
8. the statement;
9. the backend claim (Q-2);
10. the generic sealing pass above;
11. the header.

**What can still fail after the header** [READ, REVIEW6 §2.1, §4]:

- a block or `seq` file that changes between the two passes (the proving
  pass rebuilds and re-checks);
- a zero LogUp denominator, the input-dependent event D34 prices (§4);
- I/O errors.

None of these can be provoked by choosing the inputs: the denominator
event needs the challenges to hit, with the probability D34 counts. Even
then nothing is published:

- the sink contract holds every segment unpublished until the run returns
  Ok;
- the CLI's `Claimed` guard reports each removal and prints a failed removal
  loudly (`REMOVAL-FAILED`);
- a leftover `.incomplete/`, `.unverified-statement/` or owner directory is
  refused by name at the next `prove` (PR4-15).

## 3. What it rests on, step by step

Each step names:

- what D33 established;
- what is **new at the token stages**;
- what is MEASURED on the token captures;
- what is OWED.

### Step 1 — a reference prompt is admissible, proves and verifies

- **New here.** D33's reference was the all-zero input.
  - A zero token plane is **not admissible**, because position 0 must be the
    BOS id (T8). So the reference is the degenerate prompt of 32 BOS ids.
  - The all-zero-**data** preimages of step 3 are linear statements about
    blinding. They do not need the zero data to be an admissible prompt
    [MINE].
- **MEASURED.** The 32 × BOS prompt proves and verifies with the production
  verifier:
  - at L = 1, 2 and 22 (TinyLlama) and L = 1, 2 (8B);
  - each captured with the recorder
    (`/home/victor/zk60-artifacts/token-io/captures/*-fixed-pt1`).

  REVIEW6 §2.1 reports that every honest run on frozen-r9 passed the sealing
  pass, the CLI capture among them.
- **OWED.** Nothing.

### Step 2 — per commitment, the linear view discloses nothing (G-R1)

- **Argument of record:** the generic rank lemma as D33 carries it [ARGUED
  for D33's commitments]. It is a lemma about commitment geometry: rows,
  reserved pairs, groups, the proximity pair, and the pad count equal to the
  opened columns.
- **New here.** The new commitments use the same PCS, audit and
  reserved-pair discipline, and the same pad count.
  - S-1: stage OUT's byte table is at 2^12, the row width (G-5).
  - S-6: log T = 5 < 12.
  - C-4: the largest new L_s is 82, and 82 + 256 ≤ 512.
  - The token endpoints sit at a new geometry (2^8, rate 1/8, one site), so
    D17's rule-3 hard gate applies; that gate is G-6.
  - **The lemma's coverage of that endpoint holds [R4 §2.1]:**
    - 5 non-data rows against 2(G + 1) = 4 generators;
    - the pad-rank closed form at (2^8, 2^11) checked.
- **MEASURED** on every harness capture (`EV/token_io/v10/`). The CLI
  capture's per-commitment, G-2 and G-6 checks pass too
  (`EV/round10/cli9/v14-tokengate-cli9.json`):
  - A_in, A_out, E-token-in, E-token-out, B_in and B_out disclose **0**;
  - H_in and H_out disclose **2**, the exact public LogUp identity;
  - every block A discloses 0, every block H 2, and every boundary 0;
  - every M discloses 0;
  - k0 = 0, and the 16 exclusivity clauses hold;
  - B_in's and B_out's reserved blocks have rank 6 of 6;
  - G-2 (partially fixed claim points) is accepted;
  - G-6: both token endpoints disclose 0, with a full-rank pad block.
- **OWED.** Nothing.

### Step 3 — the gate constructs blinding that reproduces the view under all-zero data

- **The machinery**:
  - tools v10 (gate round 7), with the frozen ranks, preimages and hash code;
  - the token replay;
  - the new slots' terminal identity;
  - the block-stage terminal identity inside a token run;
  - a computed word-level joint over the shared planes;
  - the full preimage and joint assignment on every commitment.
- **MEASURED, harness** (TinyLlama, both prompts; gate round 7):

  | | L = 1 | L = 2 | L = 22 |
  |---|---|---|---|
  | Status | PASS / PASS | PASS / PASS | PASS / PASS |
  | All-zero-data preimage: commitments; entries; differing | 10; 1.38 M; 0 | 13; 2.50 M; 0 | **73**; 24.9 M; **0** |
  | Masking layer and CFS (G-3): differing functionals | 0 | 0 | 0 (24 stages) |
  | Joint assignment C1–C4 | respected | respected | respected |
  | Computed joint over the token planes | 0 = sum 0 | 0 | 0 |
  | Terminal identity: new slots / block slots | 15 / 15; 23 / 23 | 15 / 15; 46 / 46 | 15 / 15; **506 / 506** |
  | Controls (live / not applicable) | 36 / 2 | 36 / 2 | 36 / 2 |

  The two not-applicable controls are M4 on IN and OUT (no bilinear slot).
  The block terminals' own controls NC-0..NC-4 fire. The 8B records give
  the same verdicts at L = 1, 2.
- **MEASURED, the CLI capture, frozen-r9 pins** (round 10, tools v14,
  `--export pg_rot1_b4_T32_cal128`, the source of the view):
  - **PASS**, false parts none;
  - integrity: 52 pins all read, and no refusal;
  - the run binding is reproduced;
  - 9,838 challenges are re-derived, the same count as the harness L = 2;
  - the new-slot terminals hold, 15 / 15;
  - the block-stage terminals: every slot is equal, with the calibration
    cross-checks X0–X10 equal;
  - the full preimage: 0 of 2,503,403 entries differ;
  - the joint is 0, and all four couplings are respected;
  - 36 live controls fire.
- **Failing first:** tools v12, which carry no round-9 reading, refuse the
  CLI capture by naming the six moved pins.
- **The τ table and the head fold (PR4-6).** These are the two public tables
  of the new slots that the gate takes from the capture:
  - stage IN's τ, which folds the embedding;
  - stage OUT's `W'(r_j, ·)`, the head fold.

  Taking them is **not a gap in the view's analysis**:
  - NL-1 needs these tables to be public, and they are. The verifier
    computes them from the embedding and head the statement names by digest
    (T-3) and from the replayed challenges.
  - The captured tables are what the production verifier computed under the
    recorder, which sees only what `verify_token_run` hands it (REVIEW5
    §2.3; R4 §2.4).

  What a capture alone did not show was **attribution**: that the tables
  fold the named embedding and head. That is now closed by measurement
  (PR4-9). The absorbed calibration word, recomputed from the export and the
  named embedding and head files, equals the statement header in 5 of 5
  cases and on 10 of 10 captures (round 10, tools v16).

  The gate does not re-fold τ itself; R4 §2.4 lists that as optional (about
  32,768 × 2,048 field products).
- **The block layer at b4 (D35).**
  - **Run at b4 inside the token captures, and they fire:** the
    calibration-sensitive block controls:
    - NC-1, `sh_z` moved: fails exactly at slot 14;
    - NC-2, the frozen-calibration fallback: fails exactly at slots 2, 14,
      15, 16, 18;
    - NC-3, the cross-check;
    - NC-4, a per-layer table swap.
  - **Recorded by the security owner as carrying from pg_rot1:** CT, GQ, P,
    M, X, C, CH, M9, the pin controls and G-10. They test the tools and the
    block shape, not the calibration constants.
  - **Also measured at b4:** the block stage's terminal surjection inside
    the L = 1 captures (round 10), with A 36 / 36 (0), H 8 / 9 (2) and
    Input 2 / 2 (0).
- **OWED.** Nothing by this page's evidence rule.

### Step 4 — the joint law of all published field values is input-free (Theorem B)

**Argument of record:** D33's step 4 [ARGUED for the block stages]. That is
the joint-law composition, accepted as a reduction conditional on G-R1, G-R2,
G-R4 and G-R5. It is extended here to two more stages of the same transcript
[MINE; R4 found nothing against the extension].

- **G-R2, the new slots [MEASURED, round 10].** NL-1 S1–S5 and the terminal
  surjection were run on all ten harness captures.
  - **NL-1**, in four challenge modes (the run's re-derived challenges and
    three random seeds), all ten captures PASS, and so does the CLI capture
    (`EV/round10/cli9/v13-nl-cli9.json`):
    - F-0 (IR = transcription) holds 15 / 15;
    - S1 premises hold 15 / 15;
    - the S4 miniature masked runs (Fact 3.2, terminals = c_d T + c_m R, the
      fibre test of Theorem 3.3) hold 15 / 15;
    - the S4 per-slot terminal map onto Fp2^m holds 15 / 15;
    - S3 (Fact 2.1) holds 45 / 45 on TinyLlama and 40 / 40 on 8B;
    - T-0 (the transcription against the Rust polynomial) holds 15 / 15.
  - **NL-1's S5 controls, failing first:**
    - N5-1 fires 15 / 15;
    - N5-2 fires 8 / 8; the other 7 slots have slack and are not applicable;
    - N5-3 and N5-4 fire;
    - F-1 fires 15 / 15.
  - **The terminal surjection on the token stages' commitments.** A, B and E
    are onto with 0 disclosed. Each H discloses exactly its declared
    zero-sum relation:

    | Role | Groups surjective | Disclosed |
    |---|---|---|
    | A_in | 3 / 3 | 0 |
    | H_in | 3 / 4 | 2 (joint {2, 3}) |
    | E-token-in | 1 / 1 | 0 |
    | A_out | 18 / 18 | 0 |
    | H_out | 5 / 6 | 2 (joint {4, 5}) |
    | B_out | 2 / 2 | 0 |
    | E-token-out | 1 / 1 | 0 |

    The census finds no identical claims and no equal published values.
    Control TS-1 removes one claim's reserved pair; the group then
    discloses, on 7 of 7 roles, on every capture. The CLI capture shows the
    same structure.
  - **Observations, not findings** (draft v1): in IN-03 and OUT-09 one
    monomial's only public factor has a constant MLE, and in OUT-01, OUT-02
    and OUT-07 some monomials carry only indicator tables.
- **G-R4, the draw discipline [MEASURED, round 10; PR4-8].** The stage-47
  root-rebuild check is ported to the token stages.
  - One seeded stream replays `prove_token_run_with`'s proving pass: stage
    IN (B_in, A_in, M_in, H_in), each block (B_k+1, then the block), and
    stage OUT.
  - The production `verify_token_run` accepts the run.
  - Every root is rebuilt from the witness and the replay stream in the
    predicted order: stage IN 4 / 4, each block 4 / 4, stage OUT 3 / 3.
  - The replay ends where the prover's generator did.
  - **The prover consumed exactly the predicted bytes.**
  - 6 / 6 non-vacuity perturbations each move their roots.
  - The token endpoints (own generators, `endpoint_g::prepare`) are checked
    in situ: every drawn value and salt is distinct.
  - The check passes at L = 1 and 2, on both prompts, **on frozen-r7 code
    and on frozen-r9 code**, with equal byte counts.
- **R-1 / H-1, the production callers [READ; REVIEW6 §2.1].**
  - Every refusal of an inadmissible prompt happens before the header, at
    both callers (§2 "Admissible"). So H-1 holds by code for token runs.
  - Draft v1's F-T1 is closed by code (PR4-4).
  - REVIEW4 §2.2 noted that D29's reading then transfers; recording that is
    the security owner's.
  - The only refusal left after the header that depends on the input is the
    token stages' zero-LogUp-denominator event, priced by D34.
- **The owners (D25 T5) [READ; R4 §2.1].**
  - The prover hands each owner its endpoint's decommitment privately (rows,
    256 pads per row, salts). The owner re-encodes it and checks the root;
    the input owner also checks BOS.
  - The decommitment lets its holder unmask its endpoint's IO terminal, so
    each owner is outside the adversary for its own endpoint.
  - Each endpoint is opened exactly once.
  - **Nothing is claimed about one owner learning about the other's
    endpoint** (PR4-13).
- **The new channels (DESIGN §4.3) [MINE, checked against the captures].**
  - V and V_pad are public; the 768 vocabulary pads carry the pad-zero
    factor.
  - The token histogram is a hidden plane, claimed once and masked.
  - Ties are inside hidden δ limbs.
  - The low-entropy next token (one id among 2^15) is hidden by the
    endpoint's salts, pads and random rows, not by entropy (G-6, disclosed
    0).
  - The verifier's tables are functions of public data and challenges.
- **MEASURED.** The computed joint equals the sum of the parts (0 = 0) at
  every L. *Ruling R-3:* that equality is a consistency check, not evidence
  of independence.

### Step 5 — the hash layer adds nothing (G-R5)

- **Argument of record:** D33's step 5 (Lemma H^run, Route A^run) under D19b
  [ARGUED]. It is unchanged in kind: more roots, the same keyed roles.
- **New here.**
  - The TinyLlama T32 token run-profile string's transcript-constructor
    input differs from every other hash-input length of its run and lies one
    byte from none: 98 B (stage 25's W-2 census) [READ; R4 §2.1].
  - **C-R1 and C-R2 hold for the token absorbs [R4 §2.1]** (PR4-14). Every
    unkeyed BLAKE3 input on the token path is public and at least 96 B.
- **MEASURED** in every record:
  - every challenge is re-derived and the run binding is reproduced;
  - every opened column is re-hashed and re-authenticated under the derived
    keys;
  - no wrong hash rule reaches a root.

## 4. Residuals, sized [COUNTED; R4 §2.1]

- **Source:** `EV/round9/token_run_counts.py` and its outputs
  `EV/round9/token_run_counts.{L1L2,L22}.json`.
- **Method:** D33's formulas, each re-read for the token stages, applied to
  each capture's own geometry.
- **Controls on every TinyLlama capture:**
  - K-1: a block stage = D33's 2,329,764 draws;
  - K-2: a boundary = 30,208.
- frozen-r9 changes no draw. The figures below are unchanged from draft v1,
  and the stage-47 replays confirm the draw count by value.

**Draw sites** (PR4-14 wording):

- A hiding commitment draws (rows − data)·n + rows·Q.
- An H draws its zero-sum pair, 2(n − 1) field elements, **once, inside its
  data rows**.
- A masking commitment draws 2·ΣL_s + 2·N_slots·Q + 4,096.

| Term | L = 1 | L = 2 | L = 22 | Kind |
|---|---|---|---|---|
| Field draws per run | 3,105,476 | 5,465,448 | 52,664,888 | — |
| … of which stage IN / stage OUT / 2 token endpoints | 91,744 / 617,920 / 5,632 | the same | the same | — |
| Sampler bias (D9): draws × 2^-96 | **2^-74.43** | **2^-73.62** | **2^-70.35** | distance |
| Input-dependent refusal, two-world, 2·(768L + T + 256)/p² (**D34**) | 2^-116.96 | 2^-116.17 | 2^-112.93 | distance |
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

- **Confirmed by value [MEASURED, PR4-8].** The token stage-47 replays
  consumed exactly (counted draws − the endpoints' 5,632) × 16 + (salts − the
  endpoints' 4,096) × 32 bytes: 54,185,024 at L = 1 and 93,648,512 at L = 2.
  This holds on frozen-r7 and on frozen-r9.
- **Against D33** (blocks only, same block shape): 2^-74.82 / 2^-73.82 /
  2^-70.37. The token stages add about 0.72 M draws per run.
- **The refusal term (D34, 2026-10-20 00:16 UTC; figure wording corrected
  04:33 UTC).**
  - **What is refused:**
    - stage IN inverts only the prompt's own τ rows: at most T distinct,
      with q_t = τ(tok_t) and no position tag;
    - stage OUT inverts at most 256 byte values;
    - nothing is drawn or absorbed in between, the message is constant, and
      there is no retry.
  - **How it is priced:** as a counted two-world distance of
    2·(768L + 32 + 256)/p² per run. This replaces, for the token stages,
    D33's "refusal is a function of the challenges and public tables alone"
    sentence.
  - The reviewer's tight count is about 2^-117.14 at L = 1. This page
    carries the formula's 2^-116.96, as D34 does.
  - **D34 lapses** if the token stages draw or absorb between the
    inversions, retry an attempt, or add a position tag that changes the
    count. frozen-r9 does none of these [READ, REVIEW6 §2.1].
- **8B, measured but not claimed:**

  | | L = 1 | L = 2 |
  |---|---|---|
  | Draws | 4,662,142 | 8,437,408 |
  | Total distance | 2^-73.85 | 2^-72.99 |
  | Refusal, two-world | 2^-116.96 | 2^-116.17 |

## 5. Conditions — D33's, and those the token stages add

| # | Condition | State |
|---|---|---|
| 1–6 | D33's conditions 1–6: reserved pairs and exclusivity; pad count = opened columns; mask rounds and functional order; one opening per commitment; salted leaves; fresh OS randomness | Carried for the blocks. For the new commitments: exclusivity 16 / 16; the same PCS; the M arm re-derives every functional (G-3); one opening per commitment, **each token endpoint opened once**; one run generator plus two endpoint generators, **replayed** (PR4-8) |
| 7 | The gates' source pins; a change suspends step 3 | **frozen-r9's 52 pins**, each read (40 R7, 6 token r7c, 6 round-9). The token pin check is by digest; TC-10 and the v12 refusal of the CLI capture show a moved pin refused. **No integrated tree** |
| T-1 | The public-row variant only; T = prompt length; BOS at position 0 | Code fact (`variant_is_built`; `stage_in::honest_inputs`, `stage_in.rs:88-93`; `lookup_misses` again in the sealing pass) |
| T-2 | Each owner's decommitment is private and never published (D21); no endpoint root is registered or referred to later (D23) | An operating rule (§6). The code hands each decommitment over privately and publishes none. The CLI's default owner base is outside every artifacts tree (PR4-16) [READ, REVIEW6 §2.3] |
| T-3 | The run binds the embedding, the head, the final-norm constants, V, BOS, the variant and the mode through its calibration word | Code fact (`token_io/run.rs:290-308`). The word was recomputed from the named tables on 10 / 10 captures (PR4-9) [MEASURED] |
| T-4 | One opening per token endpoint, at the place the statement fixes | Code fact. Integrity control TC-6d refuses an endpoint "opened elsewhere" |
| T-5 | Every input-provokable refusal precedes the run header (H-1 for token runs) | Code fact at both callers (frozen-r9; REVIEW6 §2.1) |
| T-6 | D34's premises: no draw or absorb between the inversions; no retry; no position tag changing the count | Code fact (frozen-r9; REVIEW6 §2.1) |
| S | D33's shaped invariants for the blocks; for the new stages, S-1 (byte table at the row width) and C-4 (mask budget) | Measured (G-5; largest L_s 82) |
| D35 | The carried block families read no calibration constant; the block shape and tools are the D33 runs' | The security owner's note (D35). It lapses otherwise |
| P-4 | The export, the embedding and head tables and the context are fixed before and independently of any hidden input; no prompt is retried under another calibration, table or label | A HYPOTHESIS the sentence carries |

## 6. Hypotheses and operating rules

D33's §6 rules carry over, with these additions.

- **CPU only, the named binary.** A deployment runs **b56f1b71…**. Another
  binary, even one rebuilt from frozen-r9, is outside this statement until
  it is named.
- **Publication.**
  - Publish a token run only after one's own fresh-process verification,
    which the CLI's `verify` does (§2).
  - Never publish any of these: an owner's decommitment, the prompt, the
    next token, prover stdout, refusal text, or verifier output.
- **The owner base (PR4-16).**
  - Owners' decommitments live under the CLI's default
    `$HOME/zk60-owner-private/token-io/`, which is created 0700 and is
    outside every artifacts tree.
  - The base is never shipped or synced, and captures live elsewhere.
  - A base that already existed keeps its mode, so the operator checks it
    is 0700 (TR7-7).
  - Both decommitments sit on the prover host until delivery to the owners
    is implemented.
- **The prompt and the answer stay off command lines (PR4-17).**
  - The prompt reaches the CLI only through `--prompt-file` (a regular file
    of mode 0600 or 0400) or `--prompt-file -` (stdin). `--prompt` is
    refused.
  - `owner` writes the next token to a new 0600 file and prints it only
    with `--print`.
  - Wrappers follow the same rule. REVIEW6's TR7-3 found the demo's decode
    helper taking the answer id on its command line; the token lane is
    fixing it.
- **Leftovers (PR4-15).**
  - Never sync a run's parent directory while a `.incomplete/`,
    `.unverified-statement/` or owner directory sibling exists.
  - The CLI refuses a leftover by name and reports each removal; a failed
    removal is reported loudly.
- **Owners.** The input owner and the output owner are outside the adversary
  for their own endpoint. The private channel to each is assumed
  confidential and authentic.
- **One token per run** (D25 T6). Repeated runs are not a proved stream.
- **No endpoint root reuse** (D23).

## 7. Findings, with dispositions

| # | Finding (draft v1) | Disposition now |
|---|---|---|
| **F-T1** | CS-3 was not in the token run's sealing pass; the CLI had no block sealing pass (R4 §2.2, PR4-4) | **Closed by code in frozen-r9.** Both callers seal before the header: the generic prover's CS-3 through `seal_check`, and the CLI's `seal_chain` with the builder's chain, int16, parity and CS-3. The next token comes from the builder (REVIEW6 §2.1) |
| **F-T2** | The token stages' LogUp refusals depend on the input | **Priced by D34** (the security owner): 2·(768L + T + 256)/p², replacing the challenge-only refusal sentence for the token stages |
| F-T3 | The τ table and the head fold are taken from the capture | **Not a gap in the view's analysis** (PR4-6 wording, §3 step 3). Attribution is closed by PR4-9. A re-fold in the gate remains optional |
| F-T4 | The token capture writer lacks the gate's trained-calibration shape keys | Unchanged. The block terminals take the calibration from the export the capture's README names, cross-checked X1–X10 against the token header. For the CLI capture, whose README names a view, the gate takes the view's source export explicitly (tools v14 `--export`) |
| F-T5 | NL-1 S3 / S4 / S5 on the new slots not run | **Closed** (PR4-7, round 10) |
| F-T6 | G-R4's root-rebuild replay not ported | **Closed** (PR4-8, round 10; frozen-r7 and frozen-r9) |
| F-T7 | The block layer at b4 lacks the control families | **Closed by D35** plus the PR4-9 attribution |

**Noted from REVIEW6, none bearing on the sentence:**

- **TR7-5:** the CS-3 seal depends on each source calling `check`. All five
  in-tree sources do. Skipping it would only move the refusal behind the
  header, where `prove_core` keeps CS-3 and nothing is published.
- **TR7-1 and TR7-4:** presenter wording.
- **TR7-3:** an id on a command line (§6).
- **TR7-6:** the owner token file.
- **TR7-7:** the base mode (§6).

## 8. What must not be claimed, even if this came into force

- That the verifier "learned nothing" without the distance. Say it was never
  given the hidden values and that its view is within the stated distance of
  one that does not depend on them (TR7-4).
- That the next token is the float model's. It is the approved integer
  model's (TR7-4).
- That the prompt length is hidden. It is public (= T) in this variant.
- That the next token is hidden from its output owner, or the prompt from
  its input owner.
- Anything about what an output owner who is not the input owner learns
  about the prompt.
- That a sequence of runs proves a continuation (T6).
- Anything at another calibration, at 8B, at T128, at another T, on the
  GPU, for variants P / F / mode (ii), or for a binary other than b56f1b71….
- That the embedding and head are the checkpoint's (T7).
- That D33 covers the token stages, or that this draft covers D33's
  calibration.
- Soundness.

## 9. What would lapse or reopen it

- Anything in D33 §9 that touches the blocks.
- A change to any of frozen-r9's 52 pinned files, or another binary.
- A finding against any step of §3.
- A lapse condition of D34 or D35.
- An endpoint opened twice, or a decommitment published.
- An endpoint root referred to by a later artifact (D23).
- A GPU-built receipt.
- A token table or a calibration outside what the gate measured.
- A refusal provokable through the inputs after the header (T-5).

## 10. What is owed before the security owner could rule

**Closed since draft v1** (REVIEW4's PR4-12 list and its "should"):

| Item | How |
|---|---|
| PR4-4 (seal before the header, CLI path described) | frozen-r9's sealing passes; §2 now describes both callers (REVIEW6 §2.1) |
| PR4-5 (price the refusal) | **D34** |
| PR4-7 (NL-1 S3–S5, surjection on the 15 new slots) | round 10 [MEASURED] |
| PR4-8 (stage-47 replay of the token stages) | round 10, on frozen-r7 and frozen-r9 [MEASURED] |
| PR4-9 (b4 attribution; carried block controls) | round 10, 10 / 10 (tools v16) [MEASURED]; **D35** |
| PR4-10 (named binary, one CLI-path capture) | b56f1b71…; `tinyllama-t32-L2-dense-pt1-cli-r9`, PASS (tools v14) [MEASURED] |
| PR4-15 / 16 (loud removal, leftover refusal, owner base) | built in frozen-r9 (REVIEW6 §2.3); §6 rules |
| PR4-11 (the token tree's soundness verdict) | **REVIEW5** (round 6, 2026-10-20 01:28 UTC): yes, demo-fit on frozen-r7, no finding affecting soundness. **REVIEW6** (round 7, written 04:33–05:20 UTC by its own clock): **yes, frozen-r9 is demo-fit**; nothing found affects soundness or leaks the prompt or the answer; findings LOW / INFO only (TR7-1..7), which the token lane is fixing |
| Wording PR4-6, 13, 14, 17 and TR7-4 | §3 step 3; §0, §2, §3 step 4; §4, §3 step 5; §6; §0, §2, §8 |

**Still owed:**

1. **Privacy review round 5** of this draft (and of the frozen-r9 re-pin
   note `EV/tk9/ZK60_PRIVACY_STATEMENT_REPIN_TK9_20261020.md`, c4d88df1…).
2. **The security owner's decision**, which would name:
   - frozen-r9's 52 pins;
   - the binary b56f1b71…;
   - D34 and D35;
   - whether D29's reading is extended to token runs on the basis of T-5.
3. **Optional, by measurement.**
   - Re-capture the ten harness captures on frozen-r9 (the gate's tk9 copy
     builds and passes the token replays) and gate them. The carry from
     frozen-r7 now rests on the readings, REVIEW6 and the CLI capture
     (§1 "Carry").
   - Re-fold τ and the head in the gate (PR4-6).
   - The 8B block layer's gate, for a later 8B statement.

## 11. Evidence index

| What | Where |
|---|---|
| Draft v1 (history) | `EV/round9/PRIVACY_STATEMENT_NEXT_TOKEN_T32_DRAFT.md` (abccfc64…) |
| Round-10 addendum | `EV/round9/PRIVACY_STATEMENT_NEXT_TOKEN_T32_DRAFT.ADDENDUM-20261020.md` (f2b6ac8d…) |
| Token gate report (v10) and records | `EV/token_io/TOKEN_GATE_REPORT_T32_v10.md` (bcd01bb4…); `EV/token_io/v10/` |
| NL-1, surjection, attribution (round 10) | `EV/round10/nl/`, `EV/round10/ts/`, `EV/round10/cal/v16-cal-all.json` |
| Stage-47 token replays | `EV/round10/r10-{l1,l2}_*.log` (frozen-r7 code); `EV/tk9/tok-*.log` (frozen-r9 code) |
| The CLI-path capture and its gate | `/home/victor/zk60-artifacts/token-io/captures/tinyllama-t32-L2-dense-pt1-cli-r9/`; `EV/round10/cli9/` (v12 refusal, v13, v14 PASS) |
| Round-9 pin readings | `ops/zkp-mvp/gate-tinyllama/frozen_v16/scripts/zk60_native_rg_tokenio_r9_pins.py` |
| Tools | `EV/gate-tinyllama.tools.frozen.v16.sha256` (8e33c998…) and earlier manifests v10–v15 |
| Residual counts | `EV/round9/token_run_counts.py`, `.{L1L2,L22}.json` |
| frozen-r9 and the named binary | `results/zk60_token_io_r1_20261017/frozen-r9/`, `frozen-r9.FROZEN.txt`, `manifest_final_r9.sha256`; `cli/zk60_token_io.r9.release.bin`, `cli/zk60_token_io.r9.BUILD.txt` |
| Reviews | `results/zk60_privacy_review_trained_t32_20261017/REVIEW4.md`; `results/zk60_token_io_review_r1_20261017/REVIEW5.md`, `REVIEW6.md` |
| Register | `docs/zkmatrix-poc/ZK60_DECISIONS.md` D33, D34, D35 |
| D33 re-pins (gate evidence) | `EV/tk7/ZK60_PRIVACY_STATEMENT_REPIN_TK7_20261019.md`; `EV/tk9/ZK60_PRIVACY_STATEMENT_REPIN_TK9_20261020.md` |
| Design | `results/zk60_token_io_design_20261017/DESIGN.md` §§3.3–4.3 |
