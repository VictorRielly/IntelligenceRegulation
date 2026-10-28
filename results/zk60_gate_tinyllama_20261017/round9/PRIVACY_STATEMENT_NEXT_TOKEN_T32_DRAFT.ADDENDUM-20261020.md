# Addendum, 2026-10-20: status of the next-token draft's owed list after gate round 10

Written 2026-10-20 (finished 04:32 UTC) by the PRIVACY GATE lane, a
delegated Claude Opus 5.5 agent. **Separate from the frozen draft**
`PRIVACY_STATEMENT_NEXT_TOKEN_T32_DRAFT.md` (sha256 abccfc64…), which is not
edited.

| Status | **Gate evidence, NOT a privacy acceptance.** It reports what gate round 10 measured against the draft's §10 and against review round 4's closed list (PR4-12, `results/zk60_privacy_review_trained_t32_20261017/REVIEW4.md`). Only the security review process can accept, and rulings are Victor's. |
|---|---|

EV is `results/zk60_gate_tinyllama_20261017/`. Labels as in the draft:
[MEASURED], [READ], [COUNTED], [MINE].

## Tools used

- **v12** (`EV/gate-tinyllama.tools.frozen.v12.sha256`, 38a68f60…). It
  added NL-1 S1–S5 on the new slots (`zk60_native_rg_tokennl.py`), the
  terminal surjection on the token stages (`zk60_native_rg_tokents.py`) and
  the calibration attribution (`zk60_native_rg_tokencal.py`).
- **v13** (9931389d…). It added the readings of the six pinned files the
  token lane's round 9 moved (`zk60_native_rg_tokenio_r9_pins.py`,
  pre-freeze).
- **v14** (a61eecef…). It added the token gate's export override, for a
  capture whose README names no export directory.
- **v15** (c3d9db18…). It added the frozen-r9 re-pin reading of `run.rs`
  (separate addendum,
  `EV/tk9/ZK60_PRIVACY_STATEMENT_REPIN_TK9_20261020.md`).
- **v16** (8e33c998…). It added the attribution reader's fix (PR4-9 below).

Each version is frozen with a snapshot, a manifest and patches. Where a new
check could pass vacuously, a failing-first control comes with it (below).
The unit suites ran 66 (v12), 67 (v13), 68 (v14), 70 (v15) and 72 (v16)
tests, all OK.

## The owed list, item by item

### §10 item 2 / PR4-7: NL-1 S3 / S4 / S5 and the terminal surjection on the 15 new slots — **DONE (measured)**

**NL-1** (`EV/round10/nl/nl-*.json`) [MEASURED]:

- All ten token captures, each **PASS**.
- The frozen `nl_check.py` (digests checked) is fed a slot IR built from
  the gate's transcription of `define`, in four challenge modes: the run's
  re-derived challenges and three random seeds.
- In every mode, on every capture:
  - F-0: the IR equals the transcription, 15/15;
  - **S1**: premise, a public factor in every monomial, degree, budget,
    15/15 each;
  - **S4**: miniature honest masked runs (chain, Fact 3.2, terminals =
    cd T + cm R, offset in Im R, the fibre test of Theorem 3.3), 15/15;
  - **S4**: the per-slot terminal map onto Fp2^m (random tails and a shared
    boolean tail), 15/15.
- **S3** (Fact 2.1, five regimes): 45/45 tight (TinyLlama) and 40/40 (8B).
- T-0, the same transcription against the Rust terminal polynomial: 15/15.
- **S5 controls (failing-first):**
  - N5-1: a monomial stripped of its public factors. The premise fails and
    the chain rejects, 15/15.
  - N5-2: the declared degree minus one. The chain rejects, 8/8 (the other
    7 slots have slack and are not applicable).
  - N5-3 (mask one degree short) and N5-4 (C7 / C8) fire.
  - F-1: one IR coefficient perturbed. F-0 fails, 15/15.

**The terminal surjection** (`EV/round10/ts/ts-*.json`, through the G-7
helper's `ts_trained.py` with the row width set per role) [MEASURED]. On
every TinyLlama capture and on every 8B capture (all ten token captures):

| Role | Groups surjective | Disclosed |
|---|---|---|
| A_in | 3 / 3 | 0 |
| H_in | 3 / 4 | **2**: the LogUp sum group, joint component {2, 3} = 2 |
| E-token-in | 1 / 1 | 0 |
| A_out | 18 / 18 | 0 |
| H_out | 5 / 6 | **2**: joint {4, 5} = 2 |
| B_out | 2 / 2 | 0 |
| E-token-out | 1 / 1 | 0 |

This is the block stages' structure of record: A onto, H disclosing exactly
the declared zero-sum relation.

- PCS census: no identical claims and no equal published values, in any
  role.
- **Failing-first.** Every token group is a singleton, so the review's
  two-member controls cannot run on token roles. Control **TS-1** instead
  removes one claim's reserved pair. The group must disclose, and does on
  all 7 token roles (4,096 / 8,192 / 256 Fp), while the honest group
  discloses 0.
- **The block stage inside a token run, at the b4 export.** On TinyLlama
  L = 1, dense and fixed (`ts-block-*.json`), the review's own controls run
  on the block's A:
  - A: 36 / 36 groups surjective, disclosed 0;
  - H: 8 / 9, disclosed 2 (joint {7, 8} = 2);
  - Input: 2 / 2, disclosed 0.

  The controls behave as in the review of record: C1, C2 and G7-D3 fire;
  C3, C6 and C8 do not; G7-D1 is surjective; G7-D2 is short by 2 in rank and
  discloses 0. These are the figures of the D33 block stages, now inside a
  token capture.

### §10 item 3 / PR4-8: the stage-47 root-rebuild replay of the token stages — **DONE (measured)**

`EV/round10/r10-{l1,l2}_{dense_ho00,fixed}_*.log`, test-only
`gr4_token_tests.rs` in the gate's tk7 copy [MEASURED]. **All four PASS**:
L = 1 and L = 2, on the held-out prompt and on 32 × BOS, at the b4 export.

- `prove_token_run_with`'s body is replicated on ONE seeded stream:
  - stage IN (B_in, A_in, M_in, H_in);
  - each block (B_k+1, then the block);
  - stage OUT.
- The production `verify_token_run` accepts the run.
- **Every root is rebuilt** from the witness and one replay stream in the
  predicted order: stage IN 4/4, each block 4/4, stage OUT 3/3.
- The replay ends where the prover's generator did.
- **The prover consumed exactly the predicted bytes**: 54,185,024 (L = 1)
  and 93,648,512 (L = 2).
- 6/6 non-vacuity perturbations each move their root(s):
  - A_in's proximity word;
  - B_in drawn after A_in;
  - H_in's zero-sum rows from a reset;
  - a reset before stage OUT;
  - H_out ← A_out;
  - M_out's coefficient copied.
- The token endpoints, checked in situ: all drawn values and salts are
  distinct.
- **The draft's §4 draw count, confirmed by value [MEASURED].** The
  consumed bytes equal (counted draws − the endpoints' 5,632) × 16 + (salts −
  the endpoints' 4,096) × 32, exactly, at L = 1 and at L = 2.

### §10 item 4 / PR4-9 (narrowed): the b4 calibration attribution — **DONE (measured)**

The test-only `pr4_9_calibration_words_*` builds, for every export and layer
range the token captures used, from the EXPORT and the named TABLE files:

- the trained-model statement and its identity I;
- the token profile and its digest D.

It uses the production loaders, the capture test's own recipe, and never
a capture. The calibration word BLAKE3("hashline/token-io-calibration/v1"
‖ I ‖ D) equals the statement's own header word in all 5 cases.

`zk60_native_rg_tokencal.py` then compares it with every capture
(`EV/round10/cal/cal-all.json`) [MEASURED]: **10 of 10 PASS** (`EV/round10/cal/v16-cal-all.json`, tools
v16). On each capture:

- A1: the README's export and layer range name exactly one attribution;
- A2: the Python composition equals Rust's;
- A3: the word equals the absorbed `calibration`;
- A4: the replay reproduces the run binding;
- A5: the block digests are equal.

Its controls K1-K4 fire on every capture: a bit of the identity flipped,
another layer range, another export, and a bit of the profile digest
flipped.

| Capture | Word |
|---|---|
| TinyLlama L1 | 45537596… |
| TinyLlama L2 | 3287884a… |
| TinyLlama L22 | 5a89f1d3… |
| 8B L1 | c47635ce… |
| 8B L2 | c7e85519… |

**Correction, failing first.** The first run, with tools v12
(`cal-all.json`), refused the four L = 1 captures by A1 ("0 attribution
lines"):

- This was a parse limitation, not a mismatch. With `--nocapture`, libtest
  prints `test <name> ... ` with no newline, so each test's first printed
  object (the L = 1 line) follows that prefix. v12 read only lines that
  start with `{`.
- Tools **v16** read the object anywhere in the line. The new test
  `TokenCalAttributionParse` shows the fix and that A1 still refuses a
  bundle whose line is absent.

The CLI-path capture's word 45ce7431… = BLAKE3(tag ‖ 0f4cef3e… ‖ 5857be9d…)
(`EV/round10/cal/cli9-attribution.json`):

- 0f4cef3e… is the identity the named binary printed when it loaded its
  export view;
- 5857be9d… is the gate's recomputed b4 table digest;
- its block digests are the b4 export's layers 0 and 1.

The calibration-independent block controls carry by the security owner's
note, as review round 4 allows.

### PR4-5: the input-dependent refusal — **PRICED as D34** (security owner, 2026-10-20 00:16 UTC)

The draft's term 2·(768L + T + 256)/p² stands, as D34's accounting rule.
**One figure for the owner:** D34's text gives "about 2^-117.1 at L = 1".
The formula evaluates to 2·1,056/p² = 2^-116.96 [COUNTED], which is the
draft's §4 figure. The 0.14-bit difference is a printed approximation only.

### PR4-4 / F-T1: the sealing pass — **the token lane's fix is read in the frozen tree, and it draws nothing (measured)**

The token lane's round 9 adds a sealing pass to `prove_token_run_with`
before the run generator and header exist [READ, `token_io/run.rs`
4671d03e…]. It runs:

- stage IN's `lookup_misses`;
- each block's CS-3 `seal_check`;
- stage OUT's byte check;
- both token endpoints' planes checked against the witness.

The token CLI runs its own sealing chain (CS-6, the builder's chain, int16,
parity, CS-3; the next token taken from the builder) [READ, `token_io/cli.rs`
b9079130…].

No draw or absorb is added or moved. The D34 refusals stay where they were.
The six moved files are read in v13 (below).

**[MEASURED] The sealing pass draws nothing.** The token stage-47 replays
re-run on the gate's copy of frozen-r9 (tk9). The prover consumed exactly
the same 54,185,024 / 93,648,512 bytes as on frozen-r7.

The round-9 tree is now frozen: `frozen-r9/`, `manifest_final_r9` b666a991…,
suite s13 768 passed, 0 failed.

### PR4-10: the named CPU token binary and a CLI-path capture — **DONE (measured); the readings hold on the frozen tree**

- **Binary.** `results/zk60_token_io_r1_20261017/cli/zk60_token_io.r9.release.bin`,
  sha256 b56f1b71…, built by the token lane from `manifest_r9C`
  (b666a991…).
- **Capture.** `~/zk60-artifacts/token-io/captures/tinyllama-t32-L2-dense-pt1-cli-r9`,
  made P-18 style.
- **[READ] It pins six files that differ from frozen-r7** (round 9):
  - `private_block/run.rs` cc2c4204…;
  - `token_io.rs` 602597ad…;
  - `token_io/stage_in.rs` e4609b1a…;
  - `token_io/run.rs` 4671d03e…;
  - `token_io/load.rs` 8c041721…;
  - `token_io/cli.rs` b9079130….

  The token lane's working copy had exactly these digests when read, and
  so does frozen-r9 (below).
  **No change moves a receipt byte at T32** (each reading in
  `zk60_native_rg_tokenio_r9_pins.py`).
- **Gated, three ways** (`EV/round10/cli9/`):
  1. **v12 refuses as predicted:**
     - integrity names the six pins;
     - the new-slot terminals and the block terminals refuse before
       evaluating;
     - the joint assignment's C4 follows.

     NOT-OK, by name. This is the failing-first evidence for the re-pin.
  2. **v13** (the six read): every item passes except the block-stage
     terminals. Those were refused because the CLI capture's README names a
     prover-side export VIEW, not an export directory.
  3. **v14** (`--export pg_rot1_b4_T32_cal128`, the view's source):
     **PASS** (`v14-tokengate-cli9.json`, 653 s, 613 MB):
     - integrity: 52 pins, of which 40 are read as R7, 6 as the token
       round-7C readings and the six round-9 files as the round-9 readings;
       no refusal;
     - the run binding is reproduced; replay 9,838 challenges; hash layer
       4,352 columns;
     - the new-slot terminals 15/15 and NL-1 S1 15/15;
     - the block-stage terminals: every block slot equal, both blocks, with
       the calibration cross-checks X0-X10 equal (layers 0 and 1 by their
       gammas), and the 5 block-terminal controls (NC-0..NC-4) firing exactly
       as predicted;
     - full preimage: 2,503,403 view entries compared, 0 differing; 3,328
       salted leaves authenticated;
     - the joint figure 0 Fp (equal to the sum of parts), all four
       couplings respected;
     - G-1..G-6 ok (G-7 out of scope: only the public row is built);
     - the token controls: 38, all fire (2 not applicable: the one-short
       mask-length controls on M4, as on the harness captures).

     The gate's export override is recorded in the record
     (`export_override`), and the README's own text is kept as not
     transcript-bound.
- NL-1: PASS (v13, `v13-nl-cli9.json`). Surjection: as on the harness
  captures (`v12-ts-cli9.json`).
- **The round-9 tree is frozen, and the readings hold [MEASURED].**
  - `frozen-r9/` re-hashes 236 / 236 to `manifest_final_r9`. That manifest
    is manifest_r9C, b666a991…, the list the v13 readings were made on.
  - The six frozen digests equal the six v13 readings.
  - Against frozen-r7, 12 files changed and 3 were added. All are
    token-only except `run.rs`, which is re-read in the frozen-r9 re-pin
    addendum.
  - So PR4-10's capture is gated on readings of the frozen tree, not only
    of a working copy.

### PR4-2 (optional, on the D33 re-pin): the tk7 CLI run directory, captured and gated — **DONE (measured)**

`~/zk60-artifacts/tinyllama-cli-tk7-capture-dense-l2` (42.0 MB), captured
with the P-18 test ported to the tk7 copy:

- identity ef061000… = the CLI's published statement;
- the verified bytes equal `segments.json` entry for entry.

Gated as round 6 gated R7's (`EV/round10/cli/`): all PASS.

- Pass A and everything: PASS with 0 unexplained. Replay 9,002 / 251;
  terminals 46 / 46; full preimage 0 differing; mask 0; joint couplings
  respected; M9-3 fires.
- The prediction is validated, with 0 mismatches.
- Schema ok (222 keys); G-10 8 / 8; TL controls 18 / 18.
- **Every deterministic figure equals R7's P-18 capture**
  (`EV/round10/cli/compare_figures_tk7cli_r7cli.json`).

## Still owed (from PR4-12), and whose

| Item | State | Whose |
|---|---|---|
| PR4-4 | the fix is read in the frozen tree; the replays show it draws nothing | soundness of the fix: token review |
| PR4-7 | **done** | — |
| PR4-8 | **done** | — |
| PR4-9 | **done** (attribution); the owner's note for the calibration-independent block controls | security owner |
| PR4-10 | **done**; the readings are on the frozen tree | — |
| PR4-15 / 16 | the code is read (`cli.rs`); the draft's wording (R-1 / H-1, "Admissible", the CLI path) | token lane (done in code); a draft revision |
| PR4-11 | REVIEW5 (01:28 UTC): yes, the token CLI is demo-fit **on frozen-r7**, no soundness finding. The gate knows of no review of frozen-r9's round-8 / round-9 additions | token review |
| Wording PR4-6 / 13 / 14 / 17 | for a draft revision | gate |
| D34 figure | "about 2^-117.1" vs 2^-116.96 (printed approximation) | security owner |
| D33 on frozen-r9 | gate evidence in the tk9 addendum | security owner, Victor |

**None of this is a privacy acceptance.**
