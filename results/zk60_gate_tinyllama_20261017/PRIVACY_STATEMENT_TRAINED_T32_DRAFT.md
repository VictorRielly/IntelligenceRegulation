# Privacy statement for the trained TinyLlama-1.1B T32 profile — FINAL DRAFT for the security owner's decision (not accepted, not in force)

Drafted 2026-10-17 from about 12:50 UTC by the PRIVACY GATE lane, a
delegated Claude Opus 5.5 agent. It follows the form of
`docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md` (register D22).

**Round 6 consolidation (2026-10-19).** This version puts the whole page on
**one evidence basis: the native lane's R7 freeze**, the tree the statement
would name. It answers the independent privacy review's second round
(`results/zk60_privacy_review_trained_t32_20261017/REVIEW2.md`, Q-1 to
Q-8). Tree A, R5 and R5b, the trees earlier rounds measured, now appear only
in Appendix H, as history.

Three rulings and readings are cited where they apply:

- **D31**, the security owner's reading of the duplicate lookups;
- the soundness verdicts on the statement-writer path: D24 review rounds
  r5, r6 and r7, with R7 accepted;
- note N-r7-c on the backend self-report.

The round 5 text is kept byte for byte as
`PRIVACY_STATEMENT_TRAINED_T32_DRAFT.round5.md`.

**Final revision (2026-10-19, after 12:48 UTC).** This revision:

- puts G-7's terminal surjection on the R7 stage files (§0, §3 step 4);
- applies review round 3's two wording errata, E-1 and E-2
  (`REVIEW3.md`);
- cites D28, D29 and the D9 figures on Victor's sheet.

| Status | **FINAL DRAFT for the security owner's decision. NOT accepted, NOT in force, and NOT a privacy acceptance; nothing on this page establishes a privacy property.** It proposes a sentence and lists what that sentence would rest on, what changes at the trained layout, what has been measured at that layout, and what is still owed. Every step carries D22's caveat: the arguments it leans on were drafted, attacked and ruled for the TOY and for the 125M development shape. Each was re-read here **for the trained layout by me, and then by an independent reviewer in three rounds** (REVIEW.md, REVIEW2.md, REVIEW3.md). That is one attack per step, not a drafter / checker / ruling cycle. **Review round 3 (final):** "Yes, with one pending result and two wording errata". Once G-7's R7 terminal-surjection re-run lands with the expected figures, the reviewer sees nothing that should stop the security owner accepting a statement of this form. The re-run landed at 12:48 UTC with exactly those figures, and both errata are applied. The decision is the security owner's, and rulings are Victor's. D22 still covers only the toy block. |
|---|---|

**Labels.**

- [MEASURED]: a run happened and a record is cited (shared box, one run
  unless stated).
- [COUNTED]: arithmetic from the code and the shape.
- [ARGUED]: a drafted argument that survived one independent attack, as its
  disposition rules.
- [READ]: a fact read in a cited source line or document.
- **[MINE]**: my own reading or arithmetic for this page, checked by nobody.

The evidence is in `results/zk60_gate_tinyllama_20261017/`, called **EV**
below; its ledger is `EV/PROGRESS.md`. **R7** below always means the frozen
tree `results/zk60_1b_native_20261017/r7/frozen-tree/`
(2026-10-19T09:58:29Z, tree `36a8aed1…`).

## 0. In plain words

### What would be claimed

A verifier who receives an accepted private run of trained TinyLlama blocks
at 32 tokens learns nothing from its bytes about any of the following:

- the hidden input;
- the hidden output;
- the hidden activations;
- the hidden planes between blocks.

"Nothing" means beyond a distance of about 2^-70 per 22-block run. The claim
holds in the model Victor accepted for the toy (D19, D20, D21), plus D19b.

For an **admissible** input, whether the prover refuses depends on the input
only through a residual of about 2^-113. Admissible means R7's sealing
predicate (§2), which runs entirely before the run header. An inadmissible
input IS refused, and that refusal fact is outside the statement (P-8).

### What has been measured, on R7

The privacy gate (tools v8) ran on receipts captured from R7, at three
lengths:

- one-block runs (layer 0);
- two-block runs (layers 7–8);
- the full 22-block stack.

Each was run on the real held-out input `ho00` and on the all-zero input.

- **At L = 1 and 2: every check with every control family.** Each pass
  returns PASS with 0 unexplained leaves, at L = 1 and at L = 2, on both
  inputs.
- **At L = 22: the per-commitment and whole-run checks (pass A) on both
  inputs.**
- **The stage-47 root-rebuild check passes on R7.** It covers one stage, the
  boundary, and **a two-block run's stage loop** (Q-6).
- **One receipt comes from the R7 command-line tool's own path** (P-18):
  - proved by `stack-prove`;
  - verified by a fresh `stack-verify` process, which published the
    statement;
  - captured from that run directory.

  It passes the same gate: pass A and every check with every control
  family, both PASS. The gate also recomputes the layers 7–8 identity from
  the export, and it equals the identity the R7 verifier published.

- **The non-linear machine check and the terminal surjection pass (G-7).**
  NL-1 passes at the trained slot-IR export; its inputs (argument.rs,
  layout.rs, slot_ir.rs) are byte-identical in R7. The terminal surjection
  was run **on R7's own stage files**: the harness L = 1 dense and all-zero
  bundles, the L = 2 dense bundle (both stages) and the CLI bundle (both
  stages). In every one of those seven stage files:
  - A: 36 of 36 groups surjective, disclosed 0;
  - H: 8 of 9, with only the LogUp sum claim disclosing exactly the
    declared 2;
  - the endpoints and the boundary: disclosed 0.

One item carries over from R5b rather than being re-run:

- **The 22-block full-preimage and joint passes (pass F)** ran on R5b. R7
  moves no published byte of a run at this calibration, so they are carried
  by reading (§3 step 3, Q-1).

### What is not done (§10)

- **An integrated tree.** R7 is a frozen copy, not a commit, so the pin set
  of condition 7 is R7's 46 pins until an integrated tree replaces it.
- **No longer owed: the owner's confirmations are recorded** (REVIEW3
  E-1):
  - **D28**: CS-2 / CS-5 are not needed at the trained profiles (P-13);
  - **D29**: the census is a completeness item, not a condition (Q-7);
  - the D9 per-run and many-run figures are printed for Victor (P-22).
- The operating rules of §6 remain what a deployment must keep. The trained
  code can send tagged commitments to the GPU, so the statement is CPU-only
  by configuration (G-6).
- D19b and D23 are Victor's rulings, ACCEPTED 2026-10-17 19:28 UTC. D28,
  D29 and D31 are the security owner's readings of 2026-10-19. None of them
  is a privacy acceptance.

## 1. Scope — what a statement would cover

| | |
|---|---|
| Block profile | `hashline-zk-mr1/private-block-tinyllama-1.1b-t32-trained/1` (`shape.rs` `TINYLLAMA_T32_TRAINED_PROFILE`) |
| Run profile | `hashline-zk-mr1/private-run-tinyllama-1.1b-t32-trained-statement/1` (`run.rs` `RUN_PROFILE_TINYLLAMA_T32_TRAINED`) |
| Shape | 32 tokens; width 2048; hidden 5632 (padded to 8192); 32 query heads of 64 over 4 key-value heads. Rows are 2^12 wide at rate 1/4, with 256 opened columns. Endpoints have 21 rows (16 data + 5); a boundary has 22. Per stage, A has 1,729 rows (1,487 data, 120 claims, 36 groups) and H has 1,798 rows (50 claims, 9 groups) [MEASURED, every record] |
| Form | **Only a BOUND RUN.** A single-block receipt is refused at a trained-calibration profile (R2-4, `protocol::single_block_profile_allowed`). "One block" means a run with L = 1. The run header absorbs the trained-model statement's identity as its `calibration` word (`RunStatement::new_bound`) |
| Calibration | `pg_rot1_export_T32` (profile.json sha256 `b25ba5f5…`), the model at revision `fe8a4ea1`. tn 10; Cn_a 3999; Cn_m 3122; Ceps 91,255; shifts qkv 8 / score 6 / o 9 / ao 3 / gate 8 / product 14 / down 5; f_e 9. `per_layer_constants_differ = [exp_e_s, silu_member]`, so `sh_s` is run-wide and R6/R7's per-layer score-shift path is inert here [READ]. Over the 22 layers there are 7 distinct SiLU members and 2 distinct exp tables. The residual basis is rotated by a public randomized Hadamard map |
| Lengths in evidence | L = 1 (layer 0), L = 2 (layers 7–8), L = 22 (all; statement identity `68ad19c8…`, the same statement the native lane's 22-block stack proved, recomputed independently by the gate) |
| Hash rule | D19a tag: keyed BLAKE3, with four keys derived from the block profile (re-derived by the gate and equal to the declared keys) |
| Sealing | The prover, at proof time (D18, option A) |
| Code | **R7**, the native lane's freeze (2026-10-19T09:58:29Z, tree `36a8aed1…`, 219 files). R7 = R6 + N-r6-b + Q-2, and R6 = R5b + the r5_A fix + CS-3 in the sealing pass + the per-layer score-shift path. **Accepted on soundness** in D24 review round r7 (`results/zk60_d24_review_20261017/R7_VERDICT.md`), after r5 (`R5_VERDICT.md`) and r6 (`R6_VERDICT.md`). Copied to `ops/zkp-mvp/trained-1b-gate-r7/` (219 of 219 files equal the manifest; tree digest reproduced) plus the test-only capture code and the stage-47 module. Both are mounted under the unpinned `run_capture_tests.rs`, so the only pinned file that differs from R7 is `run_capture.rs`, at `31557a27` (the capture additions every round carries). Sources manifest `EV/r7/trained-1b-gate-r7.sources.v1.sha256` (7d6f1abe…). The CPU command-line binary is `r7/zk60_trained_block.release.bin`, sha256 `e51cc6a4…` (`r7/binaries.sha256`). **No commit, no integrated tree.** A statement names R7 and its 46 pins until an integrated tree replaces it (§5, condition 7) |
| Path | **CPU only: an OPERATING RULE, not a fact the artifact proves** (P-7, Q-4). CPU and CUDA paths draw identically and produce receipts of the same form. R7's published `statement.json` carries `prover_reported` {backend, gpu_declines, what}: the prover's **self-report**, which no verifier can check (its own `what` field says so). Since Q-2 the backend is one of three fixed build constants, so it carries no free text. Note N-r7-c: a CPU prover may still name one of the two device constants. What makes the scope true is the deployment running the CPU binary named by digest above (§6) |
| Evidence path | **Six bundles from the TEST HARNESS** (`run_capture_tests.rs`: the `TrainedChain` witness source, `prove_run`, `new_bound`), **plus one from the command-line path (P-18).** The R7 `stack-prove` (`StackSource`, `prove_run_with(CacheBlocks)`, `new_bound_from_digests`) proved layers 7–8 on ho00 from a prover-private `--seq-dir`. A fresh `stack-verify` process verified it and printed `statement-published`, the statement written "by stack-verify, from its own rendering and the hashes of the verified bytes". The bundle was captured from that run directory by a test that calls the CLI's own `run::verify_run_from_dir_hashed_with` and checks the published statement and `segments.json` entry by entry (`EV/r7cli/`). The two paths share the prover core [READ, review P-18] |
| Coverage over L | Draws per run = 2,329,764·L + 30,208·(L−1) + 51,712 [COUNTED, review P-19]. The CLI accepts any contiguous `--layers A..B`; the evidence covers {0}, {7, 8} and {0..21}. The recommended object is the full 22-layer stack; L = 1 and 2 are diagnostics |

**Not in scope; each owes the argument again:**

- any other calibration under the same profile string. Finding F-6 of the
  D24 review: one profile string covers a family of calibrations, which the
  statement identity separates. The gate read pg_rot1 only; D31 is a
  reading of pg_rot1's constants;
- any T other than 32;
- the GPU path (G-6);
- hidden weights (P3; NL-7 says the non-linear argument does not carry);
- sealing in advance (D8, D11, D18 option B);
- joining two finished runs (D12a);
- the embedding, final norm, LM head and token selection (D13; outside the
  proved stack);
- soundness, which is the D24 review's (R7 accepted, r7).

## 2. The statement (proposed sentence — not in force)

> In the random-oracle model for BLAKE3 (D19), read as BLAKE3's compression
> function being ideal also at a chaining value the adversary knows (D19b,
> accepted by Victor 2026-10-17 19:28 UTC), and assuming the prover's
> generators' joint output is indistinguishable from uniform (E-1; X-1 across
> runs), a verifier who receives an **accepted** run directory of this
> profile with L blocks, bound to its trained-model statement, with the
> export, the context label and the prover-reported fields fixed before and
> independently of any hidden input (P-4, C-R4, Q-2), and who makes at most
> `q ≤ 2^128` hash queries, sees a view within about **2^-74.8 (L = 1),
> 2^-73.8 (L = 2), 2^-70.4 (L = 22)** per run of a distribution that does
> not depend on the hidden run input, output, activations or internal
> boundary planes — for every **admissible** hidden run input, admissibility
> being a joint condition on all L blocks (R-1.1). Whether an attempt on an
> admissible input is refused is, up to **2^-117.4 / 2^-116.4 / 2^-113.0**
> (two-world distance), a function of the verifier-visible challenges and
> the public tables alone.

**Accepted (M-9 / D12b(1), Q-3)** means that the party who publishes the
directory has itself run `stack-verify` on it, in a fresh process, and seen
`statement-published` or `statement-checked`. The existence of a
`statement/` directory, or the writer label inside it, never shows that a
verification happened. That label is unauthenticated (N-r6-a): a prover can
write a canonical `statement/` naming `stack-verify` as its writer. A
directory that does not verify is a rejected receipt (D21).

**Admissible (P-8, Q-7)** means that the input passes R7's sealing
predicate. Every part of it runs before the run header (ruling H-1, a fact
of the code since R6):

- the trained door;
- the witness builder's refusal sites at these constants;
- bit-exact parity against the Python reference at every layer
  (`PARITY_REFUSAL`, R7 `trained_block.rs:2083`);
- **ruling CS-3's lookup-miss check on every sealed witness**
  (`protocol::check_lookup_misses`, called in the sealing pass at R7
  `trained_block.rs:2075`).

Whether an input is admissible depends on the data. A missing receipt
discloses that bit to anyone who expected one, so the refusal fact is
outside every statement (RUN.md §5.2).

The numbers are [COUNTED] (§4) and were recounted independently by the
review (REVIEW.md §3: every figure equal). The structure is the run
statement of `ZK60_HASH_LAYER_AND_FS_LIFT_RUN_DISPOSITION.md` §1 at this
shape. The sentence stands or falls with §3's five steps and the conditions
of §5.

## 3. What it would rest on, step by step, at the trained layout

For each step the text gives four things: the argument of record; **what
changes at the trained layout**; what is MEASURED on R7; what is OWED.

The layout changes that matter:

- **(a) The pad set is {F, L, Tab}.** D, Ht, Kv, Q, S and T are exact powers
  of two. At 125M the pad set was {Ht, L, D, Q, S, Tab}. Dom::F pads here
  and did not at 125M: 2,560 of 8,192 per token, 81,920 positions.
- **(b) Per-profile constants.** The D24 norm (tn, two separate Cn, Ceps)
  and seven windowed requantization shifts are now shape fields. They are
  read by the relations of slots 02, 14, 15, 16, 17 and 18, and they set the
  top-limb coefficients of `lookups_at` (`2^(8-sh)`, `2^(16-sh)`).
- **(c) Per-layer public tables** (exp `e_s`, SiLU member, weight folds).
- **(d) The rotated basis.** A public change of basis of the residual stream,
  folded into the public weights.
- **(e) Identical lookup pairs (G-7, read; D31).** At sh_qkv = sh_g = 8 the
  scaled top-limb lookup of RQL, RKL, RVL and RGL has coefficient 1, so it
  equals a byte lookup already in the list. G-7 read this at the trained
  export. pg_rot1 has four identical pairs: F RGL 0/1, Q RQL 2/3, Kv RKL 2/3
  and RVL 6/7; the frozen twin at sh = 7 has none. Helpers pair lookups
  (2k, 2k+1), so each identical pair lands in **one** helper, whose relation
  has two equal denominators (`h·d² − 2d`). The four are H[19] (slot 15),
  H[26] and H[28] (slot 16) and H[39] (slot 18).
  - There is no duplicated H plane, no repeated terminal coordinate and no
    repeated table.
  - No two published claim values are equal in any capture [MEASURED,
    `EV/g7/`].
  - The earlier description, "two H helper planes with identical values and
    two equal terminals", was my unchecked reading and **does not occur**.
  - The security owner keeps the pairs as read and does not restrict the
    declared class (**D31**, register 2026-10-19 10:29 UTC). D31 reopens if
    a capture ever shows a duplicated plane, a repeated terminal coordinate
    or equal published values from these pairs.
- **(f) Code lineage.** The trained line branched before the 125M lane's
  stages 36–45. R7 carries the native lane's port of the CS rulings and
  S38-F1(a) (round 5) and the gate's test-only port of the stage-47 check.
  It still lacks the stage-36 draw observers, so draws are COUNTED (§4).

### Step 1 — the all-zero input is admissible, proves and verifies

- **Argument.** None is needed beyond the run. The zero chain is zero at
  every block: x = 0, so every norm is 0, attention is 0, the residual is 0
  and the FFN is 0. Ceps > 0 keeps the norm's denominator non-zero.
- **Changes here.** Real weights, and the zero plane on them.
- **MEASURED on R7.** The all-zero plane on the trained blocks passes R7's
  sealing predicate, proves, and verifies with the production run verifier.
  It was captured with the recorder attached (`EV/r7/capture-r7-*-zero.*`,
  bundles `~/zk60-artifacts/tinyllama-trained-r7-capture-zero-{l1,l2,l22}`):
  - L = 1 in 3 s;
  - L = 2 in 7 s;
  - **L = 22, all 22 trained blocks as one bound run**, in 77 s at a peak of
    2.47 GiB.
- **OWED.** Nothing for this step at L = 1, 2 and 22.

### Step 2 — per commitment, the linear view discloses nothing (G-R1)

**Argument of record:** `ZK60_GENERIC_RANK_LEMMA_SHAPED.md`, accepted with
changes S-1…S-6 [ARGUED, its disposition], plus the four closures GS-4,
GS-5, GS-11 and GS-12 (`ZK60_GS4_GS5_GS11_GS12_CLOSURES.md`, ruled GC-1 and
GC-2).

**What changes here [MINE].** The lemma is about commitment geometry: rows,
reserved pairs, groups, the proximity pair, and a pad count equal to the
opened columns. It is not about the relations' coefficients, so (b), (c),
(d) and (e) do not enter it. Its shape invariants hold, checked against the
bundles:

- S-1, `log(Dom::Tab) == log_cols`: 12 = 12.
- S-3, head_dim 64 < row width 4096.
- S-6, `log T` = 5 < 12.
- C-4, the mask budget: the largest `L_s` is 97, and 97 + 256 ≤ 512.

Of the four closures:

- GS-5's formula is derived for any n and Q; here n = 4096 and Q = 256.
- GS-11 holds: M's geometry is identical (50 rows, 34 functionals).
- GS-4 holds: exclusivity is 16 of 16 on every commitment.
- **GS-12 is NOT vacuous here** (Dom::F pads; 81,920 padded positions per
  block). Its closure rests on three things:
  1. every admitted witness carries `(g8, a16) = (0, 0)` at a padded F
     position;
  2. ruling **S38-F1(a)** refuses `act[128] ≠ 0` wherever F pads;
  3. ruling **CS-3** refuses any activation miss before the first
     commitment.

  **R7 carries both rulings** [READ: S38-F1(a) in the statement checks of
  `private_block.rs`; CS-3 in the sealing pass and again in `prove_core`
  before the first A mask draw, R7 `protocol.rs:987`]. They are tested by
  the native suite and reviewed in r5.

  The door also requires every layer's `act` to equal a frozen SiLU member,
  and every member has `act[128] = round(silu(0)) = 0` (zkp-core
  `tables.rs`, pinned and read). The gate measures `act[128] = 0` per stage
  against the export itself (E4).

  A padded F position carries the constant pair (128, 0). If `act[128] ≠ 0`
  every proof would fail **for every input**: a liveness question, not a
  disclosure channel (P-15).

**MEASURED on R7** (pass A records `EV/r7/l1/r7-l1-{dense,zero}-a.json`,
`EV/r7/l2/r7-l2-{dense,zero}-a.json`, `EV/r7/l22/r7-l22-{dense,zero}-a.json`,
and the CLI bundle `EV/r7/cli/r7-cli-l2-dense-a.json`):

- A disclosed 0 everywhere (rank 74 of the 74 generators on the non-data
  rows).
- H disclosed 2, computed equal to the public LogUp identity (exact u* =
  per-indicator).
- Both endpoints 0.
- Every internal boundary 0, with its reserved block of rank 6 of 6; at
  L = 22, all 21 boundaries.
- M 0.
- k0 = 0 everywhere; exclusivity 16 of 16 on every commitment.
- The H-pad cross-check has full rank.

These figures are the same for the dense, all-zero and CLI bundles:
confirmed on every R7 record listed (disclosed dimension as expected on every commitment; whole-run joint = sum of parts, 2 = 2, 4 = 4, 44 = 44).

**OWED.** Nothing for this step. The lemma's own errata at this shape:
none expected [MINE].

### Step 3 — the gate constructs blinding that reproduces the view under the all-zero input

**What changes here.** The tools had to be ported:

- the source digests re-read and re-pinned with readings (tools v8: R7's six
  changed pins read against R5b, `zk60_native_rg_tinyllama_r7_pins.py`);
- the terminal identity reading the per-bundle calibration;
- D24's window in the prediction;
- control CT-5 generalised to the first padded domain;
- the one-block predictor branch.

The port moves no frozen figure. Run on the frozen rung-K4 bundle with
controls, the original and ported tools agree on 5,261 record fields with 0
unexplained differences (Appendix H). Tools v7 and v8 change no verdict of
any of the 56 staged records (`EV/v7/verdicts-unchanged-v7.json`,
`EV/v8/verdicts-unchanged-v8.json`).

A failing-first probe confirms the pins are live. The frozen v7 driver,
which has no R7 readings, refuses R7's `run.rs` and suspends every stage
(`EV/r7/probe_before_repin/`).

**MEASURED on R7.**

| Item | L = 1 dense / zero | L = 2 dense / zero | L = 2 CLI-path (dense) | L = 22 dense / zero |
|---|---|---|---|---|
| Pass | everything (every stage, every control family) | everything | everything | pass A |
| Status | **PASS / PASS**, 0 unexplained | **PASS / PASS**, 0 unexplained | **PASS**, 0 unexplained | **PASS / PASS**, 0 unexplained |
| Per-commitment preimage from zero data: entries, differing | 1,132,108 / 1,130,559, 0 | 2,253,304 / 2,249,505, 0 | 2,249,640, 0 | (pass F, R5b, below) |
| Masking layer and CFS: entries, differing | 16,155, 0 (each) | 32,310, 0 (each) | 32,310, 0 | (pass F, R5b) |
| One joint assignment: entries, differing | 1,148,263 / 1,146,714, 0; four couplings respected | 2,285,614 / 2,281,815, 0; four couplings respected | 2,281,950, 0; four couplings respected | (pass F, R5b) |
| Terminal identity at the trained constants | 23 of 23 | 46 of 46 | 46 of 46 | **506 of 506** |
| Control families | CT 9/9, GQ 13/13, P 6/6, M 6/6, X 23/23, C5 and C6 fire (C1–C4 not applicable by name at L = 1), CH 7/7 (CH-6 firing), M9 3/3 with M9-3 ok | CT 9/9, GQ 13/13, P 6/6, M 6/6, X 24/24, C 6/6, CH 7/7 (CH-6 firing), M9 3/3 with M9-3 ok | the same as L = 2 | (pass A has no controls; on R5b, pass T and pass F, Appendix H) |
| Costs | 826 s / 736 s; 0.69 / 0.70 GiB | 833 s / 994 s; 0.76 / 0.70 GiB | 1,039 s; 0.74 GiB | 551 s / 460 s; 5.3 / 5.5 GiB |

The tables above are R7 records:

- `EV/r7/l1/r7-l1-{dense,zero}-everything.json`;
- `EV/r7/l2/r7-l2-{dense,zero}-everything.json`;
- `EV/r7/cli/r7-cli-l2-dense-everything.json`;
- `EV/r7/l22/r7-l22-{dense,zero}-a.json`.

Each has a `.status.json` beside it.

**Also on R7:**

- the port's own TL controls (TL ok on L = 1 dense, L = 2 dense and zero and the CLI bundle, the same per control as on R5b);
- G-10 (8 of 8 at L = 1, 2, 22 and on the CLI bundle);
- the pin controls PC-0..PC-11 (12 of 12 exact on R7 L = 1, PC-9 = PC-9b firing);
- the closed schema over the six harness bundles and the CLI bundle
  (every key on the allow-list, no forbidden word, `arrays.bin` covered exactly: ok on all seven);
- the export cross-check, stage 14, in every pass (ok on every record, 0 findings; at L = 22 the recomputed identity equals the independent statement's `68ad19c8…`; at L = 2 the recomputed identity equals the R7 verifier's published `trained_statement_identity` `ef061000…` for both the CLI bundle and the harness bundle, `EV/r7/cli/e3-vs-cli-statement-*`);
- dense against zero at L = 2 (16 of 128 figures differ, all of them sampled-column figures: distinct opened columns, pad margin, pad block).

**The 22-block full preimage and joint assignment (pass F) and pass T are
R5b's, carried by reading.** This is what review round 2 asked for: "a full
22-block pass F is owed again only if a hunk turns out to move a published
byte" (REVIEW2 Q-1). Tools v8 read every R7 hunk in a pinned file against
R5b [READ, §5 condition 7], and none moves a draw, an absorb or a published
byte at this calibration:

- run.rs's `stage_shape(k)` is the run shape when `sh_s` is run-wide;
- the schedule-line clause is added only when a layer's `sh_s` differs;
- protocol.rs's CS-3 loops moved into helpers with identical bodies;
- shape.rs adds an unused method;
- trained_statement.rs encodes `sh-score-layer` only when it is present.

The R7 pass A records at L = 22 re-derive every challenge and the run
binding on R7 bytes (98,822 challenges, 2,731 positions, binding reproduced, on both inputs).

The R5b pass F figures:

- dense: 67 of 67 commitments, 24,605,616 entries, 0 differing; mask
  355,410, 0; joint 24,961,026, 0, with the four couplings respected; P 6/6,
  M 6/6, C 6/6, CH 7/7, M9-1/2; ok true, PASS;
- all-zero: 24,631,921 / 0; 355,410 / 0; 24,987,331 / 0; ok true, PASS.

R5b pass T at L = 22 gave CT 9/9 and GQ 13, with M9-3 firing; its one false
item was G-4's old criterion, since repaired (Appendix H).

**OWED.** Nothing for step 3 by this page's evidence rule. An R7 pass F at
L = 22 would replace a carried figure with a measured one (about 70 min per
input at 5.5 GiB). It is optional: the reading says it would move nothing.

### Step 4 — the joint law of all published field values is input-free (Theorem B)

**Argument of record:** `ZK60_JOINT_LAW_COMPOSITION_RUN.md`, accepted as a
REDUCTION (R-1…R-7). It is conditional on four things:

- G-R1 (step 2);
- G-R2 (the slot closures);
- G-R4 (cross-role independence of the blinding);
- G-R5 (step 5).

The non-linear channel's algebraic half is NL-1
(`ZK60_NONLINEAR_CHANNEL_SHAPED_DISPOSITION.md`). The law of the blinding
(G-R4) is `ZK60_BLINDING_LAW_GR4_DISPOSITION.md` (LW-1…LW-4).

**What changes here, and what is measured.**

- **G-R2, the slot closures [MINE].** The trained relations differ from the
  125M ones by coefficients only. The argument for every slot (`argument.rs`,
  byte-identical from R5b to R7) is the 125M argument with frozen literals
  replaced by shape fields:
  - SC_TZC: Ceps;
  - SC_DZC: 2Cn_a, 2Cn_m, 2^tn, 2^(tn+1), 2^sh_ao, 2^sh_z;
  - SC_FZC: sh_h and sh_g;
  - SC_QZC and SC_KVZC: sh_qkv and sh_o;
  - SC_SZC: sh_s.

  Each is a non-zero public constant. So the structure NL-1 rests on is
  unchanged: a public table in every monomial, degree within the declared
  degree, the mask covering each slot. The bilinear slots 08/09 carry stage
  20's repaired definition.
- **NL-1 and the terminal surjection at the trained export (G-7)
  [MEASURED, `EV/g7/`].**
  - **The trained slot-IR export**
    (`g7/export/slot_ir_tl_t32_trained_pg_rot1.json`, a63b3f35…) was
    reached through the trained door over all 22 layers. It equals the
    `define` closure at 4,048 random points over 22 layers × 23 slots, each
    layer on its real public statement.
  - **`nl_check.py` S0–S5: PASS.**
    - S1: 23 of 23 on premise, public factor and degree.
    - Budgets Σ L 979, dim C 956, kernel 23; the worst slot is 97, and
      97 + 256 ≤ 512.
    - S3 (Fact 2.1): 230 of 230.
    - S4: onto Fp2^m at 23 of 23. The identical-pair slots 15 / 16 / 18
      have m = 15 / 13 / 17 at Fp-rank 30 / 26 / 34.
    - S5: 12 of 12 controls.

    `nlc_check`'s symbolic expansion, host coupling and terminal count
    agree with the captures (A 120 claims; H 49 + the LogUp sum claim).
  - **Terminal surjection at the trained width, on R7's stage files**
    [MEASURED, `EV/g7/r7/ts_trained.json`, `g7-ts-r7.log`; 2,986 s, 0.54
    GiB]. Seven stage files were checked:
    - `tinyllama-trained-r7-capture-dense-l1` stage 0;
    - `…-zero-l1` stage 0;
    - `…-dense-l2` stages 0 and 1;
    - the CLI-path `tinyllama-cli-r7-capture-dense-l2` stages 0 and 1.

    In **every** one of those stage files:
    - A: 36 of 36 groups surjective, disclosed 0, with ranks 2(4096 + m)
      from 8,192 to 8,260.
    - H: 8 of 9. Group 8, the LogUp sum claim, discloses exactly 2: the
      declared zero-sum relation. Its joint component on the zero-sum rows
      1696/1697 gives 16,388 / 16,382 / 16,384 / 2. That is the same
      structure as the review of record's toy figures (1,028 / 1,022 /
      1,024 / 2).
    - The input endpoint, the output endpoint and the boundary B_0 (stage
      1's two-group input) are surjective, disclosed 0.
    - The verifier's identity kills every blinding and data generator.
    - The PCS census finds no identical claims and no equal published
      values in any role.

    The figures equal the R5b run's group for group
    (`EV/g7/r7/compare_r5b_r7.json`). The controls on a real two-member
    group are as in the review of record:
    - C1 (shared pair), C2 (cm = 0) and G7-D3 (a non-exact copy) fire;
    - C3, C6, C8 and G7-D1 (a duplicate with its own pair, surjective)
      do not;
    - G7-D2, a probe of two **identical** coordinates, leaves the rank 2
      short of "onto" but discloses 0. So the step's strict "onto" wording
      would need care for such a slot, but none exists at this export
      (D31).
  - **Carries to R7:** argument.rs, layout.rs, slot_ir.rs, pad.rs and
    witness.rs are byte-identical from R5b to R7 [checked].
- **G-R4 [MINE, from the readings; MEASURED below].** The draw discipline:
  - no draw site of `zk.rs`'s masking functions moved;
  - the PCS pads and salts are drawn in the same order, before any branch,
    and `encode_buffer.rs` (pinned since R5b, G-2) reads them only after
    they are drawn;
  - `masked_prove_rounds` publishes the same CfsMasker's rounds;
  - there is one generator per run (R-2) and one per endpoint.

  The independent review advises against "the reading suffices": ruling
  R-3's counterexample and LW-2's mutations m1, m2 and m4 pass every count
  and sum, and only the root-rebuild check catches them (P-12). **The
  stage-47 root-rebuild check is ported (test-only) and passes on R7**
  [MEASURED, `EV/r7/gr4-*.log`; all five also pass on R5b, `EV/q6/`]:
  - **One block, layer 0, dense ho00 and all-zero.** This is a one-block
    BOUND run with the header rebuilt from public words equal to the
    binding.
    - Stage 0 is proved on a SEEDED generator under
      `RunStatement::stage_shape(0)`, and its segment verifies with the
      production run verifier.
    - The A, M and H roots REBUILT from the witness and the predicted
      stream segments equal the prover's. The prover consumed exactly the
      predicted 38,455,872 bytes.
    - Three non-vacuity perturbations each move their root.
    - The endpoint owners' 51,712 drawn values and 32,768 salts are all
      distinct.
  - **Boundary B_0** (22 rows, 2^12, rate 4, keyed tag), dense and zero:
    the root is rebuilt; the preparer consumed exactly 1,007,616 bytes; a
    copied reserved word moves the root.
  - **A two-block run, layers 0 | 1, dense and all-zero (Q-6, new in round
    6).**
    - The run is proved stage by stage on ONE seeded stream: B_0, then
      stage 0, then stage 1 on the same stream, then the B_0 opening with
      the pending claims, then the output endpoint. This replicates
      `prove_run_with`'s loop. Both segments verify with the production
      `run::verify_run`, which re-derives the stage layouts and replays the
      two-stage chain.
    - **All seven roots (B_0, A_0, M_0, H_0, A_1, M_1, H_1) are rebuilt
      from one replay stream.** The stream ends where the prover's did, and
      **the prover consumed exactly the predicted 77,919,360 bytes**
      (1,007,616 + 2 × 38,455,872, predicted before the run).
    - Non-vacuity, 5 of 5:
      - a stream reset before stage 1 moves A_1;
      - B_0 drawn after the block's draws moves B_0 and A_0;
      - m1 / m2 / α on stage 1 move A_1 / H_1 / M_1.
    - About 15 s, 1.04 GiB.

  What it does not cover:
  - L ≥ 3 (stage k ≥ 2 runs the same loop body with B_{k−1} incoming and
    B_k outgoing, but it is not replayed);
  - the production `prove_run` on OS randomness (stages are replicated; the
    production verifier accepting them shows the replication is the run
    prover's);
  - the endpoint generators (in situ, order-blind);
  - the GPU path.

  LW-4's note carries forward: `CfsMask` derives `Clone`, and
  `CommittedZk`'s `data` / `pads` / `salts` are `pub`. Cross-stage reuse is
  covered at the type level by the generator not being `Clone`, and now by
  the L = 2 replay's reset perturbation. Not a privacy result.
- **R-1/H-1 and M-9: the production caller.** R7's command-line tool,
  read in R5b → R6 → R7 and reviewed in r5, r6 and r7:
  - **H-1.** The chain is sealed by the witness builder's own pass, with its
    refusals, bit-exact parity and **CS-3's lookup-miss check**, all BEFORE
    the run header. R6 moved CS-3 into the sealing pass (N-r5-a), so
    "every refusal of an inadmissible chain happens before the header" is a
    fact of the code (R7 `trained_block.rs:2075, 2083`).
  - **Removal.** A run that did not complete is removed, and a failed
    removal is reported loudly.
  - **Statement writing (r5_A, closed in r6).** `stack-prove` writes its
    statement to `<out>.unverified-statement/` only. `stack-verify`, in a
    fresh process, writes `<run>/statement/` **itself**, from its own
    rendering and the hashes of exactly the segment bytes it verified
    (`run::verify_run_from_dir_hashed_with`), and removes the prover's copy.
  - **Stale statements (N-r6-b, closed in r7).** A stale
    `statement.writing-<pid>` left by a dead verifier is removed without
    publishing anything, or refused by name.
  - **The writer label is unauthenticated (N-r6-a).** Publication therefore
    follows the operational rule of §2 and §6 (Q-3), never the directory's
    existence.
  - **The CLI path is MEASURED once** (P-18): `statement-published` at
    L = 2, captured and gated (step 3).
- **R-5, interior scales.** These are constants of the approved
  calibration: the trained statement's own `block_scales` pair, (0, 0) for
  pg_rot1. `new_with_calibration` refuses any other pair, and every capture
  carries `[0, …, 0]`.
- **The refusal census (GN-1 / GS-14) is completeness, not privacy (Q-7;
  D29).** With CS-3 in the sealing pass, R7's
  `prove_core` has these fallible calls after admission:
  - shape checks;
  - `refuse_lookup_misses` (CS-3), never reached by an admissible witness;
  - the LogUp `inverses` (the S-4 event);
  - `argument(…)`, whose refusals depend on the challenges only;
  - `check_opening`, which depends on the challenges only.

  So for an admissible input, whether an attempt is refused is a function
  of the challenges and the public tables: the §2 clause, now by code
  [READ, REVIEW2 Q-7]. The census sub-lane's site-by-site reading at the
  trained constants was made on R5b's lines (`EV/census/PROGRESS.md`). It
  holds on R7 because R7 changes only `trained_block.rs` from R6, and R6's
  `prove_core` and its fallible calls are what REVIEW2 Q-7 read (REVIEW3
  E-2). The census at the
  trained constants would answer how many honest inputs are refused. That
  is utility. Its design is recorded for R7 (§10b).

  CS-2 and CS-5 are unnecessary at trained profiles, on code facts (review
  P-13; **D28**, the security owner's construction reading, register
  2026-10-19 09:31 UTC):
  - the trained shape passes no window overrides;
  - the door refuses a norm-window override;
  - `check_trained_class` requires `norm_wrho` and `wrho_s` to equal their
    derived values exactly (32 and 14), re-checked in `Layout::for_shape`;
  - width is capped at `TRAINED_WIDTH_MAX = 4096`.

**MEASURED on R7.**

- The terminal identity at the trained constants: 23 of 23 (L = 1), 46 of 46 (L = 2, harness and CLI), **506 of 506 (L = 22)**, on both inputs.
- It is not vacuous. Control family TL moves each of the eleven trained
  constants one step inside its class, and **exactly** the slots the Rust
  reads it in stop matching. Restoring the frozen constants breaks exactly
  slots {02, 14, 15, 16, 18} (TL ok on L = 1 dense, L = 2 dense and zero and the CLI bundle, the same per control as on R5b).
- **M9-3, the unpadded-domain control, now passes its own criterion (G-4,
  tightened per Q-8; tools v7).** For each of D, Kv, Q, S and T there are
  two arms:
  - **Indicator arm** (the pad state forced everywhere): the host slot
    refuses by the public-table count, and exactly the slots
    `pad::indicator_slots` lists stop.
  - **Draw-count arm** (only the host's pad flag forced, so the table count
    agrees): the host refuses on the **definition-draw count**, two draws
    over the capture's, and only the host stops. The counts are D 48/46,
    Kv 24/22, Q 28/26, S 32/30, T 15/13.
- The whole-run linear joint figure equals the sum of parts at L = 1, 2 and
  22 (2 = 2, 4 = 4, 44 = 44).

  > *Ruling R-3 applies:* "joint = sum of parts" is a consistency check of
  > the model, not evidence of independence.

**OWED.** Nothing for step 4 by evidence. The census is a completeness item
(§10b).

### Step 5 — the hash layer adds nothing; the lift to the hashed protocol (G-R5)

**Argument of record:** Lemma H^run and Route A^run
(`ZK60_HASH_LAYER_AND_FS_LIFT_RUN.md`, core accepted with changes H-1…H-8).
The model is D19 plus **D19b (ACCEPTED by Victor 2026-10-17 19:28 UTC,
`docs/zkmatrix-poc/ZK60_DECISIONS.md`)**. This profile is TAGGED, so it
cannot rest on D19 as worded alone.

**What changes here [MINE].** The counts are new (§4): 4L + 1 roots, the
leaf and query totals. The key set is derived from the new profile strings.

H-8 (constructor length against the squeeze length) was a live hazard at
this profile. The first trained run-profile string would have put the
transcript-constructor input at 68 B, equal to a `pb-run-stage` absorb. The
native lane caught it with the s25 census and lengthened the string to 66 B
(constructor 78 B, nothing at 77–79).

Position tags and H-5 are unchanged in code (run.rs absorb sequence, read
again for R7). GS-7 and the explicit L = 2 hybrid stay open as bookkeeping,
as at 125M.

**MEASURED on R7**, in every record:

- the derived keys equal the declared ones;
- every challenge is re-derived and the run binding reproduced, with every
  position tag re-derived: 4,511, 9,002 and **98,822** at L = 1, 2 and 22;
- every opened column is re-hashed and re-authenticated under the derived
  keys: 1,280, 2,304 and **22,784 columns (162.2 MB)**;
- four wrong hash rules never reach a root (cross-rule probe).

**Re-read independently (REVIEW.md §2.3).** The lemma and the lift carry
with these counts, under conditions now in §5:

- **C-R1:** no 40-byte input to the unkeyed function.
- **C-R4:** the context label is a statement constant. R7's `label_of`
  admits only the allow-listed `zk60-trained-stack`.
- **C-R5:** no tagged commitment on an unkeyed device path.
- **Q-2 (new):** the `prover_reported` fields are build constants. R7's
  verifier admits only the three backend constants before publishing.

C-R2 holds: the constructor inputs are 78 B (run) and 70 B (block), neither
47.

**OWED.** Nothing by ruling: D19b is accepted. Route B (G-H1) is not needed
by a Route-A statement and stays unruled.

## 3b. The independent review, finding by finding

**Round 1** (2026-10-17, `REVIEW.md`, P-1..P-22). Final states as round 2
read them (REVIEW2 §2), plus round 6's closures:

| # | Severity | State |
|---|---|---|
| P-1 | BLOCKING (native) | **Closed in code**: R5b's sealing before the header and removal, R6's verifier-written statement (r5_A) and CS-3 in sealing, R7's stale-dir handling (N-r6-b). Reviewed in r5, r6 and r7. Text on R7 (§2, §3 step 4, §6) |
| P-2 | BLOCKING (gate) | **Closed** (tools v5+: pins enforced, stages suspended, PASS needs explained leaves; PC-0..PC-11; R7's pins read in v8) |
| P-3 | must-fix | Closed. C-R4's allow-list is in R7; Q-2 is its analogue for `prover_reported` |
| P-4 | must-fix | Closed as a hypothesis of §2 |
| P-5 | must-fix | Closed, with the §6 rule (`--seq-dir`; the verifier refuses `seq_*`; the P-18 capture ran this way) |
| P-6 | must-fix | Closed, with the §6 rule (count-free `PARITY_REFUSAL`; prover stdout private) |
| P-7 | must-fix | Closed as wording (Q-4): a self-report, labelled, limited to three constants (Q-2), N-r7-c noted |
| P-8 | must-fix | Closed; admissibility now includes CS-3 (Q-7) |
| P-9, P-10, P-11 | must-fix (gate) | Closed (export cross-check, closed schema, classifier). M9-3's criterion was repaired in v7 (G-4 / Q-8) |
| P-12 | must-fix | **Closed at run scope for L ≤ 2** (Q-6): stage, boundary and a two-block stage loop, on R7 and R5b |
| P-13 | must-fix | **Closed by D28** (CS-2 / CS-5 not needed at the trained profiles). The census is completeness (**D29**) |
| P-14..P-17, P-19, P-22 | wording | Closed. P-22: the D9 figures are printed for Victor (`ZK60_RULINGS_FOR_VICTOR_20261017.md`, 2026-10-19 09:31 UTC; §4) |
| P-18 | wording | **Closed by evidence**: one CLI-path capture at L = 2, gated |
| P-20, P-21 | gate | Closed (TL-4, G10-5..G10-8) |

**Round 2** (2026-10-19, `REVIEW2.md`, Q-1..Q-8):

| # | Severity | Where it landed | State |
|---|---|---|---|
| Q-1 | must-fix (procedural) | §1 Code; §3; §5 condition 7; tools v8 | **Done on R7, the tree after R6** (the coordinator chose R7 so as to include Q-2). Six changed pins read; re-gated at L = 1, 2 in full and L = 22 pass A, both inputs; the CLI-path capture on R7 |
| Q-2 | must-fix | §2 sentence; §5 row Q-2; §6 | **Code repair in R7** (backend one of three constants; checked by both provers and by the verifier before publishing; reviewed r7). Condition kept: the fields are build constants |
| Q-3 | must-fix (wording) | §2 "Accepted"; §6 M-9 | Done: publish only after one's own `stack-verify` reports `statement-published` or `statement-checked` |
| Q-4 | must-fix (wording) | §1 Path; §6 CPU only | Done: a self-report, not an audit; N-r7-c noted; the binary named by digest |
| Q-5 | must-fix (wording) | the whole page | Done: one basis (R7), with R5b's L = 22 pass F carried by reading as Q-1 allows; tree A / R5 / R5b moved to Appendix H; §8 corrected |
| Q-6 | must-fix | §3 step 4 | **Done**: the stage-47 replay extended to L = 2, PASS on R7 and R5b |
| Q-7 | reading | §2 admissible; §3 step 4; §10b | Done in text, and **D29** records the census as a completeness item |
| Q-8 | tool wording | tools v7 | **Done**, tightened: the indicator arm by an exactly-matched mechanism, the draw-count arm on the definition-draw count. Not loosened to "any refusal by name" |

## 4. Residuals, sized [COUNTED]

Source: `ops/zkp-mvp/gate-tinyllama/counts/run_hash_counts.py`, a copy of
the lane's counting script with the TinyLlama shape added. Every old figure
of the original script reproduces byte for byte. Its parameter line equals
the bundle's character for character, and its squeeze model equals the
measured final counter. Output: `EV/run_hash_counts_tinyllama.json`.

The draw totals are a COUNT, because the in-situ observers of lane stages
36/46 do not exist in this tree. The stage-47 replay confirms them by value
where it runs: 38,455,872 bytes for one stage, 1,007,616 for a boundary and
77,919,360 for a two-block run. Per-block draws are 2,329,764, per boundary
30,208 and per endpoint 25,856.

| Term | L = 1 | L = 2 | L = 22 | Kind |
|---|---|---|---|---|
| Field draws per run | 2,381,476 | 4,741,448 | 51,940,888 | — |
| Sampler bias (D9): draws × 2^-96 | **2^-74.82** | **2^-73.82** | **2^-70.37** | distance |
| Input-dependent refusal (S-4): L·768/p², one world | 2^-118.42 | 2^-117.42 | 2^-113.96 | — |
| … as a two-world distance (2·L·768/p²) | 2^-117.42 | 2^-116.42 | 2^-112.96 | distance |
| Salt guessing, q·N_leaf·2^-256 (q = 2^128) | 2^-111.9 | 2^-111.1 | 2^-107.8 | distance |
| Transcript pre-query | 2^-115.5 | 2^-114.5 | 2^-111.0 | distance |
| Leaf-input / transcript-input collisions | 2^-224.8 / 2^-231.9 | 2^-223.2 / 2^-230.0 | 2^-216.6 / 2^-223.1 | distance |
| Generator, in-model alternative (6q·2^-256, ASSUMED) | 2^-125.4 | 2^-125.4 | 2^-125.4 | assumption |
| Generator-key row, 3·4·2^-256 | 2^-252.4 | 2^-252.4 | 2^-252.4 | distance |
| Tag-key collision, C(m,2)·2^-256 at today's m profiles (D19b model) | zero by the s24 all-profile test (≤ 2^-246 for m up to ~40) | | | distance |
| Constructor vs absorb, B10: (A + q)·2^-256 | 2^-128.00 | 2^-128.00 | 2^-128.00 | distance |
| **Total distance** | **2^-74.82** | **2^-73.82** | **2^-70.37** | |
| Refusal on degenerate challenges, (3L+1)/p | 2^-62.0 | 2^-61.19 | 2^-57.93 | **liveness, not distance** (one base-field determinant per opening) |
| 2^20 runs, linear | 2^-54.8 | 2^-53.8 | 2^-50.4 | distance |
| 10^6 runs, linear (P-16) | 2^-54.89 | 2^-53.89 | 2^-50.44 | distance |

**Notes (review P-16).**

- The L = 1 column is not in `EV/run_hash_counts_tinyllama.json`, which
  computes L = 2 and 22 only. It comes from the review's independent recount
  (`results/zk60_privacy_review_trained_t32_20261017/recount/`), which also
  reproduces every other figure here.
- H's "50 claims" are 49 reserved site pairs plus the pairless LogUp sum
  claim. The zero-sum pair is drawn once, inside H's data rows, not
  re-drawn.
- **For the owner (P-22):** D9 was accepted at about 2^-75 (toy), 2^-72.9
  (125M) and about 2^-72 (8B) per proof. This statement's figure is
  2^-70.37 per 22-block run, about 2^-50.4 over a million runs and 2^-40.5
  over a billion. **Printed for Victor** at the end of
  `docs/zkmatrix-poc/ZK60_RULINGS_FOR_VICTOR_20261017.md` (2026-10-19 09:31
  UTC, "no ruling needed").

**Why an S-4 refusal does not depend on the data.** The S-4 count (≤ 768
distinct inverted arguments per block) is unchanged by the per-layer tables
(c). Each block's three tables still have 256 rows each, and the run total
is L × 768. For an admissible witness, *whether* a zero-denominator refusal
happens is a function of the challenges and the public tables. *Which* line
returns first depends on the data. In R7 `protocol.rs` the order is:

- CS-3 refuses any miss after the three histograms and before the first A
  mask draw (:987), and the sealing pass ran the same check before the
  header;
- the challenges are drawn (:1040-1042);
- the 256 byte-table denominators are inverted (:1051, a table build that
  never refuses);
- the witness-side byte helpers, `exp_den` and `act_den` follow
  (:1052-1073);
- the three whole tables are inverted at :1098-1104.

For every admitted witness, every witness-side argument is a table row, and
the whole tables are inverted on every attempt that reaches :1098. Nothing
is absorbed or drawn in between, and the refusal message is identical.
Which line returns first, and the time taken, are out of scope (D20).

## 5. Conditions — the toy's seven and the shaped ones, at R7

| # | Condition | State at R7 |
|---|---|---|
| 1 | One reserved pair per claim site, weights `(cm, cm·U)`; H's zero-sum pair the one exception; `audit_claims`' exclusivity is the whole defence | Code fact (the shared audit, unchanged). MEASURED 16 of 16 on every commitment at L = 1, 2, 22; the exclusivity controls fire |
| 2 | Pad count = opened columns | Code fact; MEASURED pad margins 0–4, H-pad ranks full |
| 3 | `d + 1` values per round; exact-row-span assertions; zero-mask refusal; declared order of the 34 mask functionals | MEASURED (mask arm 34 of 34, M1…M6). The prover's round evaluator changed (`masked_prove_rounds`); the published rounds did not (replay) |
| 4 | One opening per commitment; a refusal is terminal | Code fact (`PreparedBoundary::into_opening` consumes the owner). **CS-3 runs in the sealing pass before the header and again in `prove_core` before the first A mask draw** (R7 `trained_block.rs:2075`, `protocol.rs:987`) |
| 5 | Every Merkle leaf salted with 32 fresh bytes; no unsalted digest published | Code fact on the CPU path. **On a gpu-cuda build with HL_GPU=1 the unsalted columns of tagged commitments are hashed on the device** (G-6), which this page does not cover |
| 6 | Fresh OS randomness per run; no seeded configuration | One generator per run (R-2) plus two endpoints; the generator domains carry role and spec (`endpoint_g.rs`, `hash_domain.rs`) |
| 7 | The gates' source pins; a change suspends step 3 | **R7's 46 pins, every one read** (tools v8: the 40 that equal R5b's keep their readings; the six R7 changed are read in `zk60_native_rg_tinyllama_r7_pins.py` against R5b). G-2's three prover files and N-r4-d's three are required from this writer (`run_capture.rs` 31557a27). The failing-first probe shows a moved pin suspends every stage it affects. **No integrated tree**: until one exists, the pin set is R7's |
| S | Shaped invariants: S-1, S-3, S-6, C-4; D24's window; F-1's f_e class; R-5 interior scales; M-1 boundary geometry derived; H-8 constructor lengths | Present and exercised. CS-1, CS-3, CS-4, CS-6…CS-9 and S38-F1(a) are present in R7 (native round 5 port; the native R7 suite has 557 lib tests passed and 0 failed, `results/zk60_1b_native_20261017/r7/r7-suite.log`; reviewed). CS-2 / CS-5 are not needed at trained profiles (P-13; **D28**) |
| C-R1 | No 40-byte input to the unkeyed BLAKE3 function (P-3) | Holds [READ, review]: the stack context is ≥ 71 B, the trained identity is SHA-256, the run public statement is 29 + 32L B |
| C-R4 | The context label is a deployment constant, never derived from a request or a hidden input (P-3) | **R7: enforced** [READ]: `label_of` admits only `zk60-trained-stack` and refuses any other label by C-R4's name. A deployment still keeps it a constant (§6) |
| Q-2 | The `prover_reported` fields (backend, GPU-decline count) are build constants, never derived from a request or an input | **R7: enforced** [READ; reviewed r7]: `check_prover_reported` admits one of three backend constants, and `gpu_declines` 0 on the CPU path (≤ 4096 with the device). Both provers check before writing, and the verifier checks before publishing. No refusal echoes backend text (N-r7-b: one echoes a prover-chosen NUMBER, in local verifier output only) |
| C-R5 | No tagged commitment on an unkeyed device path (P-3) | Holds [READ, review]: `commit_zk_device` is not called from `private_block`. The keyed device path (G-6) is scoped out by the CPU-only rule |
| P-4 | The export (`profile.json`, the layer manifests, every file whose digest enters the trained statement) and the context are fixed before, and independently of, any hidden input. No hidden input is in the calibration or held-out set, and no input is retried under another calibration or label | A HYPOTHESIS the sentence carries (§2). `profile.json` carries held-out sequence names and statistics, and the identity binds its digest |

### 5a. Pin-list completeness beyond G-2 (review r4 note N-r4-d), file by file

Review r4 (`results/zk60_d24_review_20261017/R4_VERDICT.md`, N-r4-d) noted
that the capture pin list left out five things: the GPU code, `layer.rs`,
`wcache.rs`, `tables_v3.rs` and zkp-core `tables.rs`. Each was decided from
the source [READ, 2026-10-17]. The decisions hold for R7, whose digests for
these files equal R5b's.

| File | On the CPU-path prover's route at the trained profile? | Decision |
|---|---|---|
| `hashline/src/gpu/mod.rs` | **Yes.** `src/pcs.rs` (pinned) takes its backend from `gpu::backend()`. Without `gpu-cuda`, the `#[cfg(not(feature = "gpu-cuda"))]` seam returns `zkp_core::pcs::Cpu` (never takes over) and `enabled()` is the constant false. The CLI also calls `gpu::require_live / label / declines` | **Pinned** (`SHARED_SOURCE_FILES`) and READ (`SHARED_NR4D_PINS`, required from this writer; PC-10 / PC-11) |
| `hashline/src/gpu/cuda.rs`, `kernels.cu` | **No, provably, on a binary built without `gpu-cuda`:** `#[cfg(feature = "gpu-cuda")] mod cuda;` (gpu/mod.rs:19-20), so neither is compiled | Not pinned for a CPU statement; the CPU-only rule (§6) is what makes this true. A GPU statement must pin both (G-6) |
| `hashline/src/layer.rs` | **No.** Only zk.rs's FFN layer provers import it. None of the functions the private block calls uses a `layer` item; zk.rs is pinned | Not pinned; reason recorded here |
| `hashline/src/wcache.rs` | **No.** The weight cache serves zk.rs's v3 FFN path only | Not pinned; reason recorded here |
| `hashline/src/tables_v3.rs` and `zkp-core/src/tables.rs` | **Not on the prover / verifier relation**: the activation table is a public word of the block statement, recovered and checked by the gate (E4). **But on the trained DOOR's route**: the door admits only an `act` equal to a frozen SiLU member | **Pinned** and READ (row 128 is g = 0, and silu(0) = 0 in every SiLU member). The evidence does not depend on them: E4 measures `act[128] = 0` per stage |

## 6. Hypotheses and operating rules

- **D18:** the prover seals both endpoints at proof time. The stack CLI
  commits the first input plane and the last output plane it built (H-1).
- **D19** (accepted) and **D19b** (accepted by Victor 2026-10-17 19:28
  UTC): the model of the tag.
- **D20** (accepted): timing, memory and power are out of scope. A 22-block
  run adds per-stage wall clock and high-water marks to what an observer
  could time. The sealing pass's duration grows with L.
- **D21** (accepted): a rejected receipt is never transmitted, and a
  retained capture counts as publishing. The captures of this evidence are
  of held-out calibration data that the export itself stores in the
  repository (`seq_ho00/x_in_L*.bin`), so they publish nothing new.
- **M-9 / D12b(1), stated operationally (Q-3).** A run directory is
  published only by a party that has itself run `stack-verify` on it, in a
  fresh process, and seen `statement-published` or `statement-checked`.
  - Never publish because a `statement/` directory exists, or because of
    the writer label inside it: the label is unauthenticated (N-r6-a).
  - A directory that does not verify is a rejected receipt (D21) and is
    removed by whoever launched the run. R7's `stack-prove` removes an
    incomplete run itself and reports a failed removal loudly.
- **Refusal reasons and verifier output stay local (P-6).**
  - R7's parity refusal is one fixed text with no count, position or value.
  - The sequence-file refusal prints no digest, size or value (ruling K-2).
  - Witness-build refusals print the layer and the check site, and
    per-segment stdout events show how far a run got. So `stack-prove`'s
    stdout and stderr from a run on a hidden input are prover-private,
    never retained in a published log or capture.
  - `stack-verify`'s refusals can echo a prover-chosen number (N-r7-b), so
    verifier output is not republished either.
  - The diagnostics `HL_PB_BASEFIELD` and `HL_PB_TIMING` are
    prover-private.
- **The verifier's copy of the export contains no `seq_*` directory, and
  none is ever published (P-5).**
  - In R7 the prover reads the hidden input and the parity reference from a
    prover-private `--seq-dir`.
  - A verifier refuses an export directory holding a `seq_*` entry.
  - The P-18 capture ran exactly so: a prover-private copy of `seq_ho00`,
    and a verifier export with both `seq_*` directories dropped.
- **CPU only (P-7, Q-4).**
  - `prover_reported.backend` in the published statement is the prover's
    **self-report**. CPU and GPU receipts have the same form, so no verifier
    can audit it.
  - Since Q-2 it is one of three fixed build constants, so it carries no
    free text. Note N-r7-c: a CPU prover may still name one of the two
    device constants.
  - The scope is made true by the deployment running the CPU binary named by
    digest (R7 `binaries.sha256`: `zk60_trained_block.release.bin`
    `e51cc6a4…`). A statement of this page covers a run whose published
    self-report is the CPU constant AND whose prover ran that binary.
- **The context label and the prover-reported fields are deployment
  constants** (C-R4, Q-2). The export and the context are fixed before any
  hidden input (P-4).
- **D23** (ACCEPTED by Victor 2026-10-17 19:28 UTC): an accepted run's two
  endpoint roots are never registered, republished or referred to by a later
  artifact. **This is directly in play for the stack.** Proving the
  embedding or the LM head in a SEPARATE receipt that refers to this run's
  input or output root would put that root under D8/D11 and lapse this
  statement. Such proofs must live inside the same run, one transcript
  (D12a).
- **D31** (the security owner's reading, 2026-10-19): pg_rot1's identical
  lookup pairs are kept as read. Reopen on a duplicated plane, a repeated
  terminal coordinate or equal published values from those pairs.
- **E-1 / X-1:** separate OS entropy reads are independent and uniform,
  within and across runs (LW-3).

## 7. Findings, with dispositions

| # | Finding | Disposition |
|---|---|---|
| **G-1** | The trained line branched before the 125M lane's stages 36–45 and lacked the CS rulings, S38-F1(a), the stage-36 observers and the stage-47 check | **Closed for the statement.** R7 carries the CS ports and S38-F1(a); it was captured, its pins were read, and it was re-gated. The stage-47 check is ported (test-only) and passes on R7, including L = 2 (Q-6). The stage-36 observers stay absent, so draws are COUNTED and the stage-47 replay confirms them by value |
| **G-2** | `encode_buffer.rs`, `sumcheck/rounds.rs`, `sumcheck/grouped.rs` were on the prover path and pinned by no bundle | **Closed**: pinned by the writer since R5b and required by the gate (`SHARED_G2_PINS`) |
| **G-3** | Channel text called trained captures "a public synthetic fixture" | Done (tools v3) |
| **G-4** | M9-3 fired, but its own criterion was false at every shape | **Closed in tools v7**, tightened per Q-8 (two arms; §3 step 4). On R7 M9-3 passes at L = 1 and 2 (5 of 5 domains, both arms, on all five R7 everything passes) |
| **G-5** | At L = 1 the run-control stage raised | Done (tools v3) |
| **G-6** | Ruling T-8 no longer holds: tagged commitments can go to the CUDA backend | **Scope limit.** The statement is CPU-only by configuration. A GPU statement needs the DC-B device-buffer review, the CUDA files pinned and GPU-path captures |
| **G-7** | The draft supposed duplicated helper planes and equal terminals at sh = 8 | **Closed by reading and ruling**: G-7 measured four identical lookup pairs, each inside one helper with two equal denominators; no duplicated plane, no repeated coordinate, no equal published values; NL-1 and the terminal surjection pass at the trained export. **D31** keeps them and does not restrict the class |
| **G-8** | GS-12 non-vacuous and its two refusals absent | **Closed**: S38-F1(a) and CS-3 are in R7; `act[128] = 0` measured per stage (E4) |
| **G-9** | My prediction misses (see EV) | Rounds 1-5 in Appendix H. Round 6: the Q-6 byte count was predicted exactly (77,919,360), and so were the v7 re-runs (M9-3 moving and nothing else, leaf diff) and the failing-first probe on R7. One miss: my first verdicts script recomputed pin-control records' pins from the on-disk manifest (script error, corrected before use) |
| **G-10** | The run integrity pass did not compare endpoint opening roots | Repaired (tools v4, widened v5); 8 of 8 on R7 (8 of 8 at L = 1, 2, 22 and on the CLI bundle) |
| **G-11** | "FAIL" printed for an arms-only pass | Addressed by the status classifier (tools v4/v5) without changing any `ok` |
| **G-12** | Pins recorded but not enforced | Repaired (tools v5) |
| **G-13** | No export cross-check, no closed schema | Repaired (tools v5) |
| **G-14** | (Round 6; called "G-11" in the v8 source comment and two ledger entries.) The driver's TOOLS list, i.e. a record's `tool_sha256`, omitted `zk60_native_rg_m125controls.py` (M9-1..M9-3) and six other imported modules | **Repaired in tools v8.** Records made with v7 are tied to the code by their queue's manifest toolcheck (53 of 53) |

## 8. What must not be claimed, even if this came into force

- That TinyLlama or "a 1B model" is private in general.
- That any other calibration or token count is covered. D31 is a reading
  of pg_rot1's constants, not of the class.
- That the GPU path is covered.
- That the full model (embedding, LM head, sampling) is covered.
- That soundness was reviewed here. It was reviewed in the D24 review
  rounds, R7 accepted in r7.
- That a constructed preimage is the LAW of the blinding. It exhibits
  existence only; the law is G-R4's job.
- That every 22-block figure was measured on R7. The full preimage and
  joint passes at L = 22 were measured on R5b and carry to R7 by reading
  (§3 step 3).
- That the stage-47 check covers runs longer than two blocks, or the
  production `prove_run` on OS randomness.
- That the backend field audits the path. It is a self-report (Q-4,
  N-r7-c).
- That a `statement/` directory shows a verification happened (Q-3,
  N-r6-a).
- That this is a proof re-derived by the security owner.
- That the refusal FACT is covered. Whether an input is admissible is
  outside every statement (P-8).
- That the evidence path is mainly the CLI's. Six bundles come from the
  capture harness, which shares the prover core with the CLI. One bundle,
  at L = 2, comes from the CLI's own path (P-18).

## 9. What would lapse or reopen it

- A change to any condition of §5.
- A change to any file of the pin set (R7's 46 pins, or an integrated
  tree's).
- A finding against any step of §3.
- A calibration or export outside what the gate measured (G-7, G-8, D31).
- A GPU-built receipt (G-6).
- A later artifact referring to an accepted run's endpoint roots (D23).
- A reversal of D19b, or a published weakness in BLAKE3 as a random
  function or in the OS generator.
- An independent reader finding that a Python port differs from the Rust it
  claims to port. In particular: the per-bundle calibration transcription
  (`zk60_native_rg_terminals.Calibration`, cross-checked against the export
  by stage 14), and the Q-6 replication of `prove_run_with`'s loop (checked
  by the production verifier's acceptance).
- A deployment that does any of the following:
  - derives the context label or a prover-reported field from a request
    (C-R4, Q-2);
  - ships the export with `seq_*` (P-5);
  - publishes refusal text, verifier output or the stdout of a hidden run
    (P-6, N-r7-b);
  - publishes a directory it did not itself verify (Q-3);
  - runs a binary other than the named CPU build (P-7, Q-4).

## 10. What is owed before the security owner could rule, and what is closed

### 10a. Closed (rounds 2–6)

Each line names its record. None of this is a privacy acceptance. Older rows
(tree A, R5b) are summarised in Appendix H.

| Item | Closed by | Evidence |
|---|---|---|
| **Q-1: the named tree's pins read and the gate re-run on it** (round 6) | R7 copied and verified; six changed pins read (tools v8); failing-first probe; six captures; L = 1, 2 everything on both inputs, L = 22 pass A on both; schema, G-10, pin controls, TL, export — every record PASS with 0 unexplained leaves and no pin moved | `EV/r7/`, `EV/gate-tinyllama.tools.frozen.v8.sha256` (e047fb59…), captures `~/zk60-artifacts/tinyllama-trained-r7-capture-*` |
| **P-18: one capture through the CLI's own path** (round 6) | R7 `stack-prove` → fresh `stack-verify` "statement-published" (identity `ef061000…`), captured from the run directory and gated pass A and every check with every control family, both PASS, and the gate recomputes the layers 7–8 identity from the export equal to the one the R7 verifier published | `EV/r7cli/` (helper ledger, inputs, patch, sources df989c33…), `EV/r7/cli/`, bundle `~/zk60-artifacts/tinyllama-cli-r7-capture-dense-l2` |
| **Q-6: G-R4's machine check at run scope** (round 6) | The stage-47 replay of a two-block run: 7 roots from one stream, 77,919,360 bytes exactly, 5 of 5 non-vacuity; PASS on R7 and R5b, both inputs | `EV/r7/gr4-run_l2_*.log`, `EV/q6/` |
| **G-7: NL-1 and the terminal surjection at the trained export** (round 6) | Both pass. The surjection is on R7's own stage files, including the CLI bundle (A 36/36 disclosed 0, H 8/9 with the declared 2, endpoints and boundary 0), and equal to the R5b run group for group. The duplicate is read as identical lookup pairs inside single helpers; **D31** | `EV/g7/`, `EV/g7/r7/`, register D31 |
| **G-4 / Q-8, PC-9b** (round 6) | Tools v7: M9-3 in two arms; PC-9b fires on R5b; 56 records' verdicts unchanged; re-runs move only M9-3 (leaf diff, other differences 0) | `EV/v7/`, `EV/gate-tinyllama.tools.frozen.v7.sha256` (b33a2f55…) |
| **Statement-writer path reviewed** | D24 review: r5 (R5b: H-1 holds, M-9 holds for the honest prover; r5_A raised), r6 (r5_A closed: the verifier writes the statement; R6 accepted), r7 (N-r6-b closed, Q-2 holds; R7 accepted on soundness; notes N-r7-a..d) | `results/zk60_d24_review_20261017/R5_VERDICT.md`, `R6_VERDICT.md`, `R7_VERDICT.md` |
| **Independent privacy review, rounds 1–3** | Round 1: two blockers, both closed. Round 2: "close, not yet acceptable"; nothing leaks; Q-1..Q-8 folded (§3b). **Round 3 (final): "Yes, with one pending result and two wording errata."** The result is G-7 on R7, which landed at 12:48 UTC as expected. The errata E-1 and E-2 are applied | `REVIEW.md`, `REVIEW2.md`, `REVIEW3.md` |
| D19b, D23 | **Closed by ruling** (Victor, 2026-10-17 19:28 UTC) | register |
| P-13: CS-2 / CS-5 | **Closed by D28** (security owner's construction reading, 2026-10-19 09:31 UTC): every window at a trained profile is derived and checked exactly, and the width is capped at 4096 | register D28 |
| Q-7: the census's role | **Closed by D29** (security owner's reading, 2026-10-19 09:31 UTC): a completeness item, not a condition, under R6's sealing-pass CS-3; reopen if any refusal can occur after the run header | register D29 |
| P-22: the D9 figures for Victor | **Printed** (2026-10-19 09:31 UTC): 2^-70.4 per 22-block run, 2^-60.4 / 2^-50.4 / 2^-40.5 over a thousand / million / billion runs | `docs/zkmatrix-poc/ZK60_RULINGS_FOR_VICTOR_20261017.md` (end) |
| D31: the identical lookup pairs | Security owner's reading (2026-10-19 10:29 UTC): kept as read, class not restricted | register D31 |

### 10b. Still owed

1. **An integrated tree and its pin set** (condition 7). R7 is a frozen
   copy, not a commit. Until it is integrated, the statement names R7 and
   its 46 pins [integrator + gate; a re-read of any changed pin when it
   lands].
2. *(Closed: D28, D29 and the D9 figures, §10a.)*
3. **Completeness, not privacy (D29):** the refusal census at the trained
   constants on R7. The census sub-lane recorded its design (nine tests; 66
   blocks over ho00, ho01 and zero, expected 66 of 66 admitted and
   accepted), and it should be re-based on R7 (`EV/census/PROGRESS.md`).
   Note the fact it reported: ho01 has never been proved through all 22
   layers on the post-port code.
4. *Optional:* R7 pass F (and pass T) at L = 22. This would replace carried
   figures with measured ones. The reading says nothing would move (§3 step
   3).
5. G-6 stays a scope limit: a GPU statement needs its own review (DC-B), the
   CUDA files pinned, and GPU-path captures.

## 11. Evidence index (EV = `results/zk60_gate_tinyllama_20261017/`)

| What | Where |
|---|---|
| Ledger, results, costs | `EV/PROGRESS.md` |
| **R7 (this page's basis)** | `EV/r7/`: copy verification, patch and sources, pin list, heavy / light / CLI queues, failing-first probe, stage-47 logs (`gr4-*.log`), records `l1/`, `l2/`, `l22/`, `cli/`, schema. Gate copy `ops/zkp-mvp/trained-1b-gate-r7/` |
| R7 captures (outside the repo) | `/home/victor/zk60-artifacts/tinyllama-trained-r7-capture-{dense,zero}-{l1,l2,l22}`; CLI path `tinyllama-cli-r7-capture-dense-l2` (run directory `tinyllama-cli-r7-run-l2`, inputs `tinyllama-cli-r7-seq-ho00`, `tinyllama-cli-r7-verifier-export`) |
| P-18 sub-lane | `EV/r7cli/` (ledger, `bundle_summary.json`, inputs, patch, sources, pins), copy `ops/zkp-mvp/trained-1b-gate-r7-cli/` |
| G-7 sub-lane | `EV/g7/` (ledger, trained slot-IR export, NL-1 and NLC runs, surjection runs on R5b, fidelity controls), **`EV/g7/r7/` (the terminal surjection on R7's stage files, including the CLI bundle; `compare_r5b_r7.json`)**, copy `ops/zkp-mvp/trained-1b-gate-g7/` |
| Q-6 on R5b | `EV/q6/` |
| Census design (completeness) | `EV/census/PROGRESS.md`, copy `ops/zkp-mvp/trained-1b-gate-census/` (unedited R5b) |
| Tools | `ops/zkp-mvp/gate-tinyllama/` (`frozen_v1/` … `frozen_v8/`; `scripts/` = v8). Manifests `EV/gate-tinyllama.tools.frozen{,.v2,…,.v8}.sha256`; patches `EV/gate-tinyllama-vs-original.v{1..8}.patch`, `EV/gate-tinyllama-v{3..7}-to-v{4..8}.{scripts,tests}.patch`; freeze helper `EV/v4/freeze.py` |
| Tools v7 / v8 evidence | `EV/v7/` (probe, leaf diffs, pin controls, G-10, verdicts), `EV/v8/verdicts-unchanged-v8.json` |
| Pin readings | `scripts/zk60_native_rg_tinyllama_pins.py` (tree A), `_r5_pins.py`, `_r5b_pins.py`, `_r7_pins.py` |
| Reviews | `results/zk60_privacy_review_trained_t32_20261017/REVIEW.md`, `REVIEW2.md`, `REVIEW3.md`, `recount/`; `results/zk60_d24_review_20261017/R{4,5,6,7}_VERDICT.md` |
| Sized terms | `EV/run_hash_counts_tinyllama.json` |
| History (tree A, R5, R5b) | Appendix H; `EV/l1/`, `EV/l2/`, `EV/l22/`, `EV/p2/`, `EV/v4/`, `EV/v5/`, `EV/gr4/`, `EV/r5/`, `EV/r5b/`; the round 5 draft `PRIVACY_STATEMENT_TRAINED_T32_DRAFT.round5.md` |

## Appendix H. History: the trees measured before R7

These figures are kept for the record. They are not the basis of the
statement above (Q-5), except the R5b L = 22 pass F and pass T figures,
which §3 step 3 carries by reading.

- **Tree A** (`ops/zkp-mvp/trained-1b-gate/`, pre-port, 2026-10-17).
  - Captures: L = 1, 2 and 22 (dense, and zero as `…-zero-l22r2`).
  - Every linear figure as on R7.
  - L = 22 zero arms: 24,650,287 / 0 per-commitment; joint 25,005,697 / 0;
    ARMS-ONLY by unrequested controls.
  - L = 22 dense pass F (tools v4): 24,621,305 / 0; joint 24,976,715 / 0;
    PASS.
  - The port's rung-K4 equivalence: 5,261 leaves, 0 unexplained
    (`EV/equivalence/`, `EV/p2/`, `EV/v4/`, `EV/v5/equivalence-k4-v5r.json`).
  - Its CLI broke none of H-1's sealing rule but left failed directories in
    place; its label was free (C-R4 live).
  - Records: `EV/l1/`, `EV/l2/`, `EV/l22/`, `EV/p2/`, `EV/v4/`, `EV/v5/`.
- **R5** (`d67fae7e…`): superseded by P-1 before any capture. Its readings
  are kept in `_r5_pins.py`. The stage-47 port first passed on R5's prover
  core (`EV/gr4/`).
- **R5b** (`44013397…`, frozen 2026-10-18T00:06:31Z).
  - Captures at L = 1, 2, 22, dense and zero.
  - Tools v6: pass A PASS at L = 1, 2 and 22 zero.
  - Everything passes at L = 1, 2, NOT-OK solely by G-4's old criterion.
  - L = 22 pass T: CT 9/9, GQ 13, M9-3 firing, G-4 the one false item.
  - L = 22 pass F dense and zero: PASS (figures in §3 step 3). Costs 4,113 s
    and 3,572 s at about 5.5 GiB.
  - TL 18/18, TL-4 3/3, G-10 8/8, export and schema ok.
  - Stage-47 PASS; Q-6 PASS (`EV/q6/`).
  - Tools v7 re-runs: PASS at L = 1, 2 (`EV/v7/`).
  - Records: `EV/r5b/`, `EV/v7/`.
- **Prediction misses, rounds 1–5** (G-9 as written then):
  - TL-1's slot 17;
  - the L = 1 root count;
  - the L = 22 manifest file count;
  - the v4 equivalence's explained-leaf count;
  - pass F's peak and verdict (CH-6's by-name skip);
  - TL-4's stage pair;
  - the v5 queue's equivalence script;
  - PC-9's construction on an R5b writer, corrected as PC-9b.

  Each is recorded in EV.
