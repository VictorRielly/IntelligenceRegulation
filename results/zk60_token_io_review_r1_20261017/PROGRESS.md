# Token I/O R1 — independent adversarial review — PROGRESS

Lane: TOKEN I/O R1 ADVERSARIAL REVIEW (2026-10-17 evening). Binding rules:
`ops/zkp-mvp/LANE_RULES_20261017.md`. No git writes; no privacy claim.

Write set (exclusive): `ops/zkp-mvp/token-io-review-r1/` (frozen copy),
`ops/zkp-mvp/token-io-review-r1-scratch/`, this directory.

## Log (UTC from `date -u`)

- 22:02:45 lane start; read LANE_RULES, the R1 REPORT and PROGRESS.
- 22:04 frozen copy: `rsync -a --exclude=target ops/zkp-mvp/token-io/ ->
  ops/zkp-mvp/token-io-review-r1/`; manifest
  `ops/zkp-mvp/token-io-review-r1.sha256` (224 files, list sha256
  8e1e29613fca8dd4afa6779ccd55bc29a0f703ced680f13fc1019211c306074f).
  All 223 entries of the author's `manifest_suite_start.sha256` (list sha256
  b9a55176...) match byte for byte; the one extra file is BASELINE.sha256.
  => the reviewed tree IS the suite-start tree.
- 22:05-22:15 read DESIGN v3 (§0-§8), CHECK2's N-table, D12/D17/D18/D23-D27,
  then the code: token_io.rs (Tier, door, tables, StageLayout,
  run_stage_slot vs argument::run_slot line by line, wire, owner check),
  stage_in.rs, stage_out.rs, run.rs, tests.rs; the additive edits in
  private_block.rs / run.rs (diffed against the R5 frozen tree: additive).
  Static result so far: transcript order and every relation of DESIGN 2.3 /
  3.1 present with fresh coefficients; run composition (B_in / B_out
  two-site, one opening each; token endpoints one site, one opening) right.
  Candidate findings: verifier accepts unbuilt variants P/F (prover-only
  refusal); Tier door admits weak tiers (B-1 hole geometry), no minimum-tier
  policy (D27); Tier Q != 256 breaks the stage wire (M opening counted with
  the tier's Q, zk.rs opens MASK_Q); owner_rebuild_root checks no plane
  semantics; head word class (-128) not declared; To entry 1 of tok / M not
  pad-zeroed.
- 22:18 scratch tree `ops/zkp-mvp/token-io-review-r1-scratch/tree/` = the
  frozen copy + `token_io/run/review_tests.rs` (my tests, a child of
  token_io::run) + one `mod review_tests;` line in run.rs. The frozen copy
  is untouched.
- 22:20:36 launched detached `ops/zkp-mvp/token-io-review-r1-scratch/launch_r1.sh`
  (marker `logs/launch_r1.done`): guarded build (build class, need 3 / cap 5)
  -> guarded `cargo test --release --lib token_io -- --test-threads 2
  --nocapture` (cpu, need 4 / cap 7; author's 10 + my 11) -> the
  fresh-process pair (cpu, need 3 / cap 6, TOKEN_IO_R1_OUT = scratch/runs).
  Queued behind the heavy lock (r5b-suite1 holding).
- 22:23:40 added RV-31..33 (vocabulary / isqrt-limb pad terms) to
  review_tests.rs BEFORE the build started (log still "waiting for lock").
  Test list: RV-01..33 controls (must refuse, asserted) + findings printed
  as `REVIEW-R1 FINDING` (TR-To1, TR-owner, TR-head, TR-tier, TR-variant).
- 22:25 further static notes: run hash-tag key set = the block shape's
  (`Shape::hash_tag`, as every run profile) although DESIGN 4.1 says "own
  hash-tag key set" (informational); fidelity REPORT: T4 passed at the
  calibration-rule Cn (5,664), NOT the refusal-free Cn R1 uses (93.7 %), so
  R2 reactivates the D20 final-norm refusal class (R2 note). Whole-
  commitment term 2^-93.32 re-derived: 7 x 2^-96.13 (4 block A/H + 3
  boundaries) dominates.
- 22:25 review_tests.rs: tier cases wrapped in catch_unwind (a zkp-core
  assert at rate 1/2 must not hide the later cases). Still before the build.
- 22:27 REVIEW.md drafted (static sections 3.1 transcript table, 3.2
  relation table, 3.4 privacy smell test); verdict / findings / test
  sections wait for the run. Waiters: background `until` on
  `logs/launch_r1.done`, Monitor on the step markers. Job still waiting for
  the heavy lock (r5b-suite1).
- 22:30:03 build started; 22:33:48 b1-build exit 0 (225 s, waited 553 s,
  peak 1.84 GiB).
- 22:36:03 t1-tests exit 0: 22 passed / 0 failed / 2 ignored (author 10 +
  mine 12); RV-01..33 all refused as predicted (RV-28/29 completeness
  accepted as predicted); author's control lines 0 NOT AS PREDICTED.
  Findings demonstrated: TR-variant (P and F statements ACCEPT a public-row
  receipt), TR-tier (endpoint rate 1/4 = 2^-67.34 and rate 1/2 = 2^0, stage
  2^9 = 2^-86.28 all admitted AND verify; Q = 128 / 1 admitted but the run
  fails at "token I/O wire: opening shape"), TR-owner (semantically bad
  planes rebuild their roots), TR-head (-128 admitted; harmless at R1 /
  TinyLlama / 8B by exact arithmetic), TR-To1 (accepted).
- 22:36:18 fresh-process pair exit 0 / 0 (both fixtures, one-bit change
  refused); launch_r1.done = 0. NOTHING OF MINE PENDING.
- 22:36:20 the author's tio-s1-suite (full existing suite) started (not
  mine; result not seen).
- 22:39 REVIEW.md final: verdict sound as built / faithful except TR-1
  (MEDIUM), TR-2 (LOW-MEDIUM), TR-3, TR-4 (LOW), TR-5..7 INFO, TR-8
  acceptance gaps, TR-9 R2 notes; R2 base yes with conditions (a)-(e).

## ROUND 2 (2026-10-18 UTC): TR fixes + rung R2 (TinyLlama-1.1B, 22 blocks, T32)

Brief (coordinator): re-review `ops/zkp-mvp/token-io/` at the lane's
`manifest_final.sha256`; TR-1..TR-5 fixes; R2 multi-row layout; whole-run
figure and VerifierPolicy; the D20 refusal at the calibrated Cn; re-verify
the R2 honest run with my own binary in a fresh process; own tamper tests at
R2. Write REVIEW2.md. Same write set plus `ops/zkp-mvp/token-io-review-r2/`,
`ops/zkp-mvp/token-io-review-r2-scratch/`.

- 01:41:57 round 2 start.
- 01:43 frozen copy `ops/zkp-mvp/token-io-review-r2/` (rsync, no target);
  manifest `ops/zkp-mvp/token-io-review-r2.sha256` (225 files, list sha256
  5c4e14b84407ae3830ee4480feced5258c5f69fc71528c648ce1eb8fb0d8bcfb). All 224
  entries of the lane's `manifest_final.sha256` (file sha256 1ef25c3c...)
  match byte for byte; the extra file is BASELINE.sha256. => the reviewed
  tree IS the lane's final tree.
- 01:44-01:50 read the lane's ledger (census fixes, TR-1..TR-5 test-first,
  R2 plan / build / run), and the code diffs r1-tree -> r2-tree:
  token_io.rs (registered tiers + B-1 floors + Q == MASK_Q in Tier::check;
  column/hiding/mask opening log2; head -128 refused; derived multi-row
  stage domains; M opening sized from zk.rs), stage_in/out (per-domain logs,
  multi-row planes, logup_size, `pb-*` labels with stage locality words),
  run.rs (WholeRun derived in TokenRunStatement::new and bound in the
  parameter line; VerifierPolicy; variant_is_built in specs / statement /
  prover / verifier; owner_check_input / owner_check_output), private_block
  run.rs (TinyLlama token profile, TOKEN_IO_RUN_PROFILES), r2_tests.rs.
  Static: each TR fix closes its finding; the whole-run figure is DERIVED
  from levers inside the constructor (no claim input), the LogUp term uses
  the checked (N + 3R - 1)/|F_p^2| convention (= N + 2303 for blocks;
  stage IN reuses it with R = V: no term for r_emb's degree, negligible);
  the floor is not margin-checked (comment says it is); multi-row row counts
  re-derived by hand = the counter (IN 17/28, OUT 182/110).
- 01:47 saved R2 receipt fingerprint (lane runs/r2/ho00): 24 segments,
  255,258,816 B, sha256 over per-segment sha256s 687b6cba3defd72f...;
  statement.txt sha256 6341f768f9e5e6b7...
- 01:50 scratch `ops/zkp-mvp/token-io-review-r2-scratch/tree/` = frozen r2
  copy + `token_io/run/review_tests.rs` (rv2_a1..a4 cheap; rv2_b (two real
  layers, R2 tables / profile / multi-row: 12 forgeries), rv2_c1 (lane's
  saved ho00 receipt, fresh process, probes), rv2_c2 (two full-scale
  forgeries); B/C #[ignore]) + one `mod review_tests;` line.
- 01:51:59 launched detached `launch_r2.sh` (marker `logs2/launch_r2.done`):
  build (build 3/5) -> token_io tests incl. lane's R2 unit tests + my A
  (cpu 4/7) -> my B/C `rv2_ --ignored --test-threads 1` (cpu 5/8) -> the
  lane's `token_io_r2_verify_from_dir` on THEIR saved bytes with MY binary
  (cpu 4/7). Queued (heavy lock held; budget 9.5/11.9 GiB committed).
- 02:44:54 build started (waited ~53 min: the lane's own R3 fail-first job
  and others held the lock); 02:48:09 build exit 0 (3m07s; no warning from
  my file).
- 02:50:24 t1 token_io exit 0: 24 passed / 0 failed / 7 ignored (lane 16
  R1+TR + 4 R2 unit + my 4 A); 71 AS PREDICTED, 0 NOT. My round-1 probes
  now all REFUSED: rate 1/4, rate 1/2, stage 2^9, Q 128, Q 1, stronger
  unregistered levers, F_p^3 at the door AND the statement; -128; P / F
  relabelled forged receipts refused by the verifier ("variant is not
  built"); owner checks refuse my round-1 planes, the wrong owner and
  another run's statement; an inflated whole-run figure (120 on the
  prover's statement) refused by binding, and by policy. Only the
  in-process mutated statement object itself is accepted (TR2-figure,
  info: the verifier derives its own; nothing reads the figure from bytes).
- 02:57:05 t2-r2scale exit 0 (400 s, peak 2.84 GiB): rv2_b 12/12 refused
  as predicted (two real layers, R2 tables / profile / 8-row planes, Cn
  5,664 admitted on the 2-layer row, max |y| 55; honest 2-layer token
  25608, 12.0 s, floor 100 bits); rv2_c1: the lane's ho00 receipt VERIFIES
  with my binary in a fresh process (8.9 s, 95-bit policy; derived 97 bits:
  97 openings, column 2^-97.457, logup 2^-100.957, total 2^-97.335) and 10
  probes refused (98-bit policy with/without segments, inflated 120,
  Cn 1,024, ho36 context, roots swapped, 21-layer prefix, segments 5/6
  swapped, a stage IN bit flip, a changed head multiplier); rv2_c2: full
  22-layer forgeries A6-only across rows (86.7 s) and m to a padded entry,
  both refused as predicted.
- 02:57:35 t3 lane's token_io_r2_verify_from_dir with MY binary on the
  lane's bytes: accepted 9.1 s, one-bit change refused. launch_r2.done = 0.
  NOTHING OF MINE PENDING.
- 03:00 REVIEW2.md final: TR-1..TR-5 closed (probes re-run), TR-6
  exception, TR-7 decision; R2 sound as built at the level tested; new
  findings R2-1 LOW (floor margin not enforced), R2-2..R2-6 INFO; verdict:
  R2 may stand as the trained-model next-token result (with the stated
  wording / limits); base for R3 yes, conditionally (streaming blocks,
  V_pad 2^17 edge, census, R2-1, own controls, G-gates owed).

## ROUND 3 (2026-10-19 UTC): rebase onto native R6, per-layer shifts, rung R3 (Llama-3-8B)

Brief: review `ops/zkp-mvp/token-io/` at `manifest_final_r3d.sha256`: the
merge onto the R6 freeze (tree = R6 + the lane's 15 files; no R6 fix lost),
streaming (CS-6 digest checks on reload, no TOCTOU), per-layer shifts, the
8B tables loader, the V_pad 2^17 edge, the whole-run figure, re-verify the
trained receipt with my binary in a fresh process, own tamper tests at R3
shape. Write REVIEW3.md. Write set + `ops/zkp-mvp/token-io-review-r3/`,
`ops/zkp-mvp/token-io-review-r3-scratch/`.

- 10:18:29 round 3 start.
- 10:19 frozen copy `ops/zkp-mvp/token-io-review-r3/` (rsync, no target);
  manifest `ops/zkp-mvp/token-io-review-r3.sha256` (228 files, list sha256
  4ab62df1861ad4b049ceba0a6f36518e6a43eabaaed03c7c98a54d77583d7234). All 227
  entries of `manifest_final_r3d.sha256` (file sha256 67327e11...) match;
  the extra file is BASELINE.sha256.
- 10:25 MERGE VERIFIED: R6 frozen tree intact (219 entries of
  r6/manifest_frozen.json match). Review tree vs R6: exactly the lane's 15
  files (7 changed: private_block.rs, run.rs, run_capture.rs, s24, s25, s33,
  hash_domain_tests; 8 added: token_io.rs + token_io/{r0_words, r2_tests,
  r3_tests, run, stage_in, stage_out, tests}.rs) + BASELINE.sha256. R6's 18
  changed files: its 14 others byte-identical in the tree; s25 / s33 /
  hash_domain_tests untouched by R6 (R5 == R6). My own 3-way merge
  (`git merge-file -p`, stdout only; ours = snap-r3c, base = R5 frozen,
  theirs = R6) equals the tree's private_block.rs, run.rs, s24_tests.rs
  byte for byte; run_capture.rs has 2 conflict regions, resolved by keeping
  BOTH sides (16 + 4 token_io + R6's trained_block.rs = [21]). No R6 change
  lost. Products in `ops/zkp-mvp/token-io-review-r3-scratch/merge/`.
- 10:22-10:26 read the lane's ledger (R3 plan, R3-A/B/C, round-2 items
  folded, the rebase R3-D, per-layer shift port, generic and trained 8B
  runs, s5 729/0/37) and the code diffs r2-tree -> r3-tree: token_io.rs
  (R3 profile entries, parallel folds with serial references,
  describe_under / digest_under keeping R1/R2 texts byte for byte),
  stage_out.rs (byte_misses, asked first), run.rs (WholeRun with the R2-2
  stage-IN term and the R2-1 omitted bound 137*2^-113 + 34*2^-117.2 =
  2^-105.88 before the floor; private whole_run; stage_sh_s from the
  trained statement's records, validated by with_score_shift, named in the
  stage lines; TokenBlocks streaming with CS-1/4/6 per stage on the SAME
  object that is then proved / verified: no TOCTOU between check and use;
  BlockPublic::digest() hashes the in-memory words each call), r3_tests.rs
  (loader: metadata length check BEFORE reading, exact-length chunked reads
  with streamed SHA-256, refusal on mismatch; ExportBlocks: reload +
  digest check vs the digest pass, one resident). Omitted-term constants =
  MEMO_G02 (2^-113 per opening, 2^-117.2 per block, at 8B T512); the 8B
  LogUp term agrees with RECOUNT's derived stack figure.
- 10:27 saved trained receipt fingerprint (lane runs/r3/trained-ho00): 34
  segments, 471,285,072 B, sha256 over per-segment sha256s eda3752ca537...;
  statement.txt sha256 e02c8199...
- 10:27 scratch `ops/zkp-mvp/token-io-review-r3-scratch/tree/` = frozen r3
  + `token_io/run/review_tests.rs` (rv3_a1 per-layer shift probes, rv3_a2
  wrong block mid-run on both sides + segments emitted; rv3_b 15 controls
  at R3 shape on the b7 export's layers 0-1 (layer 1 at its own shift) with
  the TRAINED tables; rv3_c1 the saved trained receipt in a fresh process +
  an independent whole-run recount + 9 probes; rv3_c2 one full-scale
  trained forgery).
- 10:27:50 launched detached `launch_r3.sh` (marker `logs3/launch_r3.done`):
  build -> token_io tests (lane's incl. R3 units + my A; cpu 5/8) -> my B/C
  `rv3_ --ignored --test-threads 1` (cpu 5.5/8) -> the lane's
  `token_io_r3_verify_from_dir` (env as their t21) on THEIR bytes with MY
  binary (cpu 4.5/7). Heavy lock held by another lane at launch.
- 10:30:43 build started; 10:33:43 build exit 0 (3m02s, no warning from my
  file).
- 10:35:58 t1 token_io exit 0: 31 passed / 0 failed / 9 ignored (lane 29 +
  my 2 A); 72 AS PREDICTED, 0 NOT. RV3-A1 per-layer probes refused
  (binding; the trained door refuses own == run's and 40); RV3-A2 a wrong
  block at stage 1 refused by name on both sides; the honest prover had
  already emitted 2 segments (TR3-1, LOW).
- 10:54:15 t2 R3-scale exit 0 (1,097 s, peak RSS 3.97 GiB, cgroup 8.0 with
  page cache): rv3_b 15/15 refused as predicted (b7 layers 0-1, layer 1 at
  own shift 7, TRAINED tables, Cn 4,234 admitted max |y| 71; honest
  two-layer token 28246, 31.0 s); rv3_c1: the lane's trained receipt
  VERIFIES with my binary in a fresh process (37.7 s, 95-bit policy); my
  independent recount = the code's figure (137 openings, column 2^-98.045,
  logup 2^-99.441, omitted 2^-105.883, total 2^-97.575, floor 97, margin
  0.575 bits); 9 probes refused; rv3_c2: full 32-layer trained forgery
  (A6-only at id 53,488, honest 11) proved in 170.5 s and refused at RSEL.
- 10:55:45 t3 the lane's token_io_r3_verify_from_dir with MY binary on the
  lane's bytes: accepted 41.8 s, one-bit change refused. launch_r3.done = 0.
  NOTHING OF MINE PENDING; frozen r3 copy re-checked (228 entries, 0
  mismatch).
- 10:58 REVIEW3.md final: merge verified; R3 sound as built at the level
  tested; R2-1..R2-6 closed; TR3-1 LOW (mid-run refusals after segments
  reached the sink), TR3-2 / TR3-3 INFO; verdict: R3 may stand as the
  trained 8B next-token result (stated wording / limits).

## ROUND 4 (2026-10-19 UTC): TR3 fixes + the token CLI (prove / verify / owner)

Brief: review `ops/zkp-mvp/token-io/` at `manifest_final_r4.sha256`
(native R7 + the lane's 19 files): TR3-1..3 fixes; the CLI
`examples/zk60_token_io.rs` + `token_io/cli.rs` (prove / verify / owner:
publication races, owner decommitment readability / leakage, refusal texts,
partial runs, verify for the wrong export); re-run the 8B CLI demo
artefacts (`results/zk60_token_io_r1_20261017/cli/`) through my own binary.
Verdict: is the token CLI fit for a demo? Write set + token-io-review-r4/,
token-io-review-r4-scratch/.

- 11:37:18 round 4 start.
- 11:38 frozen copy `ops/zkp-mvp/token-io-review-r4/`; manifest
  `ops/zkp-mvp/token-io-review-r4.sha256` (232 files, list sha256
  1beca5cae036dccd4281410a62c3ccf0ea7302e7ea1acf96e6f5bfa8e59dbae6). All 231
  entries of `manifest_final_r4.sha256` (file sha256 86f5958c...) match; the
  extra file is BASELINE.sha256.
- 11:39 base verified: R7 freeze intact (219 entries of r7/manifest_frozen.json);
  review tree vs R7 = exactly the lane's 19 files (8 changed: private_block.rs,
  run.rs, run_capture.rs, s24, s25, s33, hash_domain_tests, trained_block.rs;
  11 added: examples/zk60_token_io.rs, token_io.rs, token_io/{r0_words,
  r2_tests, r3_tests, run, stage_in, stage_out, tests, load, cli, cli_tests}.rs);
  R7 vs R6 = trained_block.rs + trained_stack_tests.rs only; the lane's
  trained_block.rs vs R7 = VISIBILITY ONLY (10 fn signatures -> pub(crate)).
- 11:40-11:43 read: token_io/run.rs (TR3-1 pre-check of every block before
  the first segment; TR3-3 digest assertion; sink contract), token_io.rs
  (Decommitment file codec: lengths checked before allocation), load.rs
  (bounded strict manifests; regular-file, length-checked, chunked,
  SHA-streamed tables; note: File::open without O_NOFOLLOW after the
  symlink_metadata check, SHA-bound), cli.rs (prove / verify / owner), R7
  helpers (check_statement_dir, publish_statement_dir, clear_stale_
  writing_dirs, read_regular_file_bounded with O_NOFOLLOW|O_NONBLOCK).
  Static candidates: (1) the verify / owner pin is the TRAINED identity only;
  the token stages' tables, BOS, final norm come from the manifests handed
  to the verifier (unpinned); (2) `owner` checks against `<run>/statement/`
  without verifying the run (a prover-written statement/ or a tampered
  receipt are not detected by the owner command); (3) the owners'
  decommitments are a SIBLING of the run directory, directory mode 0755,
  files 0600; in the demo they sit inside results/ (not git-ignored:
  `git check-ignore` exit 1) = a retained bundle (D21); (4) no input-owner
  command; (5) a kill mid-prove leaves `<out>.incomplete/` (refused on
  retry; nothing verifiable).
- 11:44 scratch `ops/zkp-mvp/token-io-review-r4-scratch/tree/` = frozen r4 +
  `token_io/cli/review_tests.rs` (a child of token_io::cli: rv4_1 pin,
  rv4_2 owner, rv4_3 refusal texts, rv4_4 partial runs / placement, rv4_5
  wrong export + a publication race) + one `mod review_tests;` line in
  cli.rs; `prep_b8.py` (scratch artefact dirs hard-linking the lane's 8B
  segments read-only; one tampered copy; a reconstructed unverified
  statement for an independent publication).
- 11:45:11 launched detached `launch_r4.sh` (marker `logs4/launch_r4.done`):
  test build + CLI build (build class) -> token_io tests (cpu 5/8) -> prep
  -> my CLI binary on the 8B artefacts: c1 verify re-check, c2 verify
  publish (compare with the lane's published files), c3 owner, c4 verify
  tampered, c5 owner tampered, c6 --min-bits 98, c7 the prover's export
  (seq_*), c8 owner with input.dec (each cpu-guarded).
- 11:48 / 11:49 builds exit 0; 11:51:19 t1 token_io exit 0: 38 passed / 0
  failed / 6 ignored; 77 AS PREDICTED, 0 NOT. Demonstrated: TR4-pin (a run
  proved with another head, or another Cn, verified AND published under the
  same identity pin); TR4-owner (owner exit 0 after a tampered segment and
  over a prover-written statement/); placement (sibling dir 755, files
  600). Clean: refusal texts (263 / 4321 / x9y not echoed), mid-run
  refusal leaves nothing, wrong export refused, the publication race
  leaves exactly statement/.
- 11:52-11:57 my CLI binary (sha256 4bf20de7...) on the 8B artefacts: c1
  re-check exit 0; c2 independent publication byte-identical to the lane's
  statement.json and segments.json; c3 owner token 11; c4 tampered copy
  refused at block 19; c5 owner over it: token 11 (TR4-owner at 8B); c6
  --min-bits 98 refused; c7 prover export refused (P-5); c8 input.dec
  refused. launch_r4.done = 0. NOTHING OF MINE PENDING.
- 12:00 REVIEW4.md final: TR3-1..3 closed; CLI sound for prove / verify, no
  hidden-data leak on published outputs; TR4-1 MEDIUM (owner does not
  re-verify), TR4-2 MEDIUM (pin misses the token stages' constants), TR4-3
  LOW (owner-private sibling, 0755 dir, inside results/), TR4-4 INFO.
  Verdict: fit for a demo after the two small fixes (or an explicit
  verify-then-owner procedure and a shown table-SHA check).

## ROUND 5 (2026-10-19 UTC): confirmation of the TR4 fixes

Object: `ops/zkp-mvp/token-io/` at `manifest_final_r5.sha256` (sha256
5f7d155e...); 5 files changed against r4 (`token_io/cli.rs`, `cli_tests.rs`,
`load.rs`, `src/private_block.rs`, `examples/zk60_token_io.rs`). Write set:
`ops/zkp-mvp/token-io-review-r5/` (+ `.sha256`), `ops/zkp-mvp/token-io-review-r5-scratch/`,
this directory (`logs5/`, the review document).

- 13:39:23 start. Frozen copy `ops/zkp-mvp/token-io-review-r5/` from the lane
  tree; equal to `manifest_final_r5.sha256` [COUNTED]. Read the 5 diffs.
  Static: TR4-1 `owner` / new `input-owner` call `check_run(published_only)`
  (identity pin, token-profile pin, canonical statement, every segment
  re-verified, segments.json equal to the hashes seen) before printing;
  TR4-2 `--expect-token-profile` required (verify / owner / input-owner),
  compared with `st.tp.digest_under(profile)` rebuilt from the tables;
  TR4-3 `owner_dir_of`: `--owner-dir` or `$HOME/zk60-artifacts/token-io/<name>.owner-private`
  (base 0700), refused when its canonical parent is under the run's
  canonical parent; dir 0700 / files 0600; TR4-4 tables opened
  O_NOFOLLOW|O_NONBLOCK after an lstat regular-file check, re-checked by
  fstat; owner files and the unverified statement written before the final
  rename. Candidate: prove's error path `remove_dir_all(&owners_dir)` also
  runs when `create_private_dir` failed because the directory ALREADY
  EXISTS (another prove created it after this one's existence check):
  it would delete another run's decommitments (the default owner dir is
  keyed by the run's base name only). Probe written (RV5-3 collision).
- 13:45 scratch tree + `review_tests.rs` (RV5-1 owner/input-owner re-verify;
  RV5-2 token-profile pin; RV5-3 placement, symlinked parent, same-name
  collision) + `prep_b8_r5.py` (art-unverified, art-forged, art-r5,
  tables-mult with one head multiplier changed and its manifest SHA
  updated, tables-link with a symlinked embedding) + `launch_r5.sh`.
- 13:47:17 launched detached `launch_r5.sh` (marker `logs5/launch_r5.done`);
  queued behind the heavy lock (another lane's r8-check).
- 13:46-13:49 layer-0 pre-check (light, unguarded python): the lane's 4 unit
  tests OK; b7_T32 ho00 prompt `clear` exit 0; a prompt with 662 / 16309
  refused exit 2, each named (id, text, positions, site V, the fix); b7_T64
  and b6_T64 with the b7 embedding match the b7 fingerprint (their layer_00
  manifest without RoPE and weights are byte-identical to b7's) and refuse
  by name; non-b7 8B T32 `not-covered`; TinyLlama 1B `not-covered` (and
  exit 1 with no token_io/ embedding); the fidelity lane's voc0 variant
  `not-covered`; a malformed prompt exit 1. Logs `logs5/precheck/`.
- 13:54-14:00 builds (scratch tree = frozen r5 + the cfg(test)-only review
  module) exit 0; my CLI binary sha256 51269365... (the lane's r5 binary
  da48f6d4...; they differ by the embedded build path).
- 14:00:13-14:03:20 t1 token_io (cpu-guarded, peak rss 2.50 GiB): 39
  passed / 0 failed / 6 ignored (the lane's 36 incl. tr4_1..tr4_3 + my 3);
  78 AS PREDICTED, 0 NOT [MEASURED]. RV5-1: owner before any verifier
  published refused; owner / input-owner after an honest verify OK; another
  prompt refused ("the sealed input plane is not the owner's prompt"); owner
  and input-owner after a tampered segment refused (stage OUT A pcs);
  owner over a prover-written statement/ refused (segments.json not the
  hashes this verifier verified). RV5-2: another head / half Cn under the
  approved token-profile pin refused, nothing published; the same runs
  accepted only under their OWN tables' pin (by design: the pin is the
  verifier's choice); no pin refused. RV5-3: --owner-dir in the run's
  parent, in a subdirectory of it, and through a symlink to it refused;
  owner dir 0700, files 0600. FINDING TR5-1 REPRODUCED: two proves naming
  the same owner directory at once: one exit 0, the other refused "File
  exists", and the owner directory is GONE afterwards: a completed run
  without its owners' decommitments (prove's error path removes an owner
  directory it did not create).
- 14:03-14:25 my CLI binary on the 8B artefacts (each cpu-guarded, peak rss
  <= 2.86 GiB): p1/p2 `profile` on the prover export and the verifier copy
  both e8238cf1...7132 = the lane's pin file; p3 one-multiplier tables
  8b4a8b1e...; p4 symlinked embedding refused (not a regular file); c1/c2
  owner / input-owner over art-tamper refused (block 19 pcs; round 4 printed
  token 11); c3 unverified-only refused; c4 prover-written statement/
  refused; c5 wrong pin / c6 no pin refused; c7 one-multiplier tables under
  the approved pin refused (pin), c8 under their own pin refused (statement
  not canonical); c9 owner token 11, c10 input-checked, c11 wrong prompt
  refused; the lane's r5 run (hard-linked copy): c12 statement-checked, c13
  token 11, c14 input-checked; c15 the round-4 output.dec over the r5 run
  refused (root not rebuilt). launch_r5.done = 0.
- 14:25 frozen r5 copy re-checked: 231 entries, 0 mismatches. Guard status:
  no trv5-* job. NOTHING OF MINE PENDING.
- 14:27 REVIEW4.md ROUND 5 section written. Verdict: the token CLI is
  demo-fit now; TR4-1..4 closed; new TR5-1 LOW (prove's cleanup deletes an
  owner directory it did not create: concurrent proves sharing an owner dir,
  reproduced), TR5-2 INFO (pre-check: "clear" omits its scope; RoPE not
  read at check; not-covered exits 0; refusal log names prompt tokens),
  TR5-3 INFO (explicit --owner-dir may sit inside the repo; --out under
  $HOME needs --owner-dir; the approved token-profile pin must come from
  the approval record, not a profile run on the prover's files).

## ROUND 6 (2026-10-19 UTC): the token lane's rounds 6 and 7 (REVIEW5.md)

Object: `manifest_final_r7.sha256` (233 files, list eb912dd5...), the frozen
copy `results/zk60_token_io_r1_20261017/frozen-r7/` (coordinator, 19:11Z).
My copy `ops/zkp-mvp/token-io-review-r7/` (+ `.sha256`, list 5baa8e79...,
made 19:11 from the lane tree before round 8 moved it): all 233 entries match
the manifest, and every file equals frozen-r7's [COUNTED]. Write set: that
copy, `ops/zkp-mvp/token-io-review-r7-scratch/`, this directory (`logs6/`,
REVIEW5.md).

- 19:10 start; read the lane ledger's round-6 / round-7 sections.
- 19:12-19:15 R8 rebase, by diff3 (mine = my r5 copy, base = R7 frozen-tree,
  theirs = R8 frozen-tree): `private_block.rs`, `trained_block.rs` (and
  s24 / s33 / hash_domain_tests) = the 3-way merge exactly; `run.rs` = the
  merge + 2 lines (`token: None` in the block run's capture header);
  `s25_tests.rs` = the merge + the census row 6 -> 8; `run_capture.rs` R7 ==
  R8, all lane changes; every other file = R8 byte for byte; 0 files only in
  R8 [COUNTED].
- 19:15-19:19 static: cli.rs (Claimed guard; owner_dir_at; git_working_tree_of;
  default key = 12 hex of SHA-256 of the canonical run path; schema /2,
  `/1` refused by name), token_io/run.rs (stage_cal from each record via
  apply_own + with_layer_calibration, used by prove / verify / layouts; the
  stage lines name each own constant; mirrors native run.rs), the hooks
  (all `#[cfg(test)]`, no Result, no-ops when no recorder: `checkpoint`
  returns None, `with` returns None; arguments are layout-derived; segment
  count checked before `&segments[k]`; `slots.get(s)?` before `&slots[s]`),
  the census (the 2 new `sha256_hex(` sites mirror the block writer's
  segment / expected_bytes digests). Approval record: all 7 token_io file
  SHA-256s and SHA256SUMS (216d13e4...) re-hashed from the fidelity export,
  profile.json 82c7c752...c4f6 = the fidelity ledger's 15:48 entry, the
  verifier copy = hard links of the export minus seq_*; the fidelity lane's
  nexttoken JSON (integer 11, margin C 313,660,358; float 11) = the lane's
  cross-check JSON.
- 19:20:57 launched detached `launch_r6.sh` (marker `logs6/launch_r6.done`):
  builds -> t1 my review tests (cli::review_r6: concurrent proves, mid-run
  refusal, stale claim, placement edges; r3_tests::review_r6: per-field
  cheating at block 1, receipt under other records, swapped layer
  calibrations, hostile receipts with/without a recorder) -> t2 the lane's
  token_io tests -> 8B probes on the r7 demo run (profile x3, re-check,
  independent publication + compare, owner, input-owner, b7 identity pin,
  b7 export, schema /1, own-calibration edits, tamper, owner on tamper, the
  r6 /1 run).
- 19:21-19:40 static, continued: the pre-check (`tools/layer0_precheck.py`
  ddb3fcb3..., list 8f8341b3...): the lane's 6 python tests OK; voc0 ho00
  `clear` with `scope` and `not_covered`; voc0 with 662 / 16309 `clear`
  (no refusing token on that export); b7_T32 with 662 / 16309 exit 2 by
  name; the fidelity lane's T128 voc0 variant (same layer-0 fingerprint,
  RoPE 128 rows) `not-covered` by the new RoPE-prefix rule; b7_T64 exit 2.
  The demo reads both pins from the approval record (export path checked).
  Release binaries r7 (demo tree) vs r7c (capture tree): .text, .rodata,
  .eh_frame byte-identical; 136 bytes differ in all (build-id + .data.rel.ro)
  [COUNTED]. The guard's history keeps `cmd[:8]` (the demo's prompt sits
  beyond it).
- 22:28 UTC (the guard's local 15:28 PDT): the build was admitted after
  11,268 s of heavy-lock wait (other lanes); builds exit 0 (232 s / 76 s);
  my CLI binary 9a22336d... .
- 23:41:33-23:42:29 t1 my review tests (cpu-guarded, peak 1.47 GiB): 6
  passed / 0 failed; every CONTROL AS PREDICTED [MEASURED]: RV6-1 two real
  concurrent proves (same owner dir; same --out), twice each: one exit 0,
  the other refused at its claim, the winner's run / statement /
  decommitments intact, the loser leaves nothing; RV6-2 mid-run refusal
  leaves nothing, a stale `.incomplete/` refused and kept; RV6-3 git tree
  through a symlink refused, default for a run under $HOME (via a symlink)
  accepted, a run in $HOME/zk60-artifacts refused; NOTE: the default owner
  dir is accepted when $HOME is itself a git working tree. RV6-4 all eleven
  own fields: a block-1 witness with ANY one field put back to the run's
  value, under the per-layer statement, refused at block 1 (11 of 11);
  RV6-5 the honest receipt under 13 other record sets refused ("belongs to
  another run"); RV6-6 swapped layer calibrations refused at block 0, and
  the honest receipt under swapped records refused; RV6-7 62 hostile
  receipts without and with a recorder: 0 panics, 0 accepted, 0 bundles.
- 23:57:11-00:00:21 t2 the lane's token_io tests on the frozen tree
  (cpu-guarded, after 882 s of lock wait; peak 2.43 GiB): 44 passed / 0
  failed / 8 ignored, 67 AS PREDICTED / 0 NOT [MEASURED] (incl. the three
  capture tests: the bundle self-consistency with the owner-decommitment
  scan, the prover-path inertness, a tampered run writes no bundle). 8B
  probes started 00:00:21.
- 00:00-01:15 8B probes so far (my binary 9a22336d..., each cpu-guarded):
  p1 `profile` on the FIDELITY lane's export and p2 on the verifier copy:
  identity c3fb8c5b..., token profile e8238cf1... = the approval record's
  pins; p3 on the b7_T32 copy: 47f01943... (the b7 record's pin holds under
  the R8 code); c1 re-check statement-checked; c2 an independent
  publication from the rebuilt unverified statement: statement.json and
  segments.json byte-identical to the lane's; c3 owner token 11; c4
  input-owner 32 tokens; c5 the b7 identity pin refused; c6 the b7 export +
  b7 pins over the voc0 run refused (context).
- ~01:05 COORDINATOR (t34): on the frozen-r7 prover path (i) a stage-IN
  lookup miss and (ii) an input endpoint sealed over another prompt are not
  refused by the prover; does the VERIFIER reject every such receipt?
  Static answer: yes (stage IN: tok, m, B_in and the endpoint root are all
  fixed before beta / gamma / alpha / r_emb; the LogUp sum claim is fixed
  to 0 by the verifier and checked inside the H opening; every stage-IN
  slot is standalone, so its sum is bound to 0 through the M opening; the
  B_in claim from IN-01 is opened with block 0's B_in opening). Empirical:
  the lane's DESIGN 6.1 controls in my t2 run on the frozen tree (#7, #10a
  at IN-00; #16a/b/c2/d at the LogUp H opening; #16c at IN-02; #4/#5 at
  IN-01). Added RV6-8 (the HONEST prover path, no cheating flag: (i-a/b/c)
  lookup misses, (ii-a/b/c) foreign / padded / BOS-changed endpoint, and a
  consistent other-prompt control); `launch_r6b.sh` (detached, marker
  `logs6/launch_r6b.done`) rebuilds and runs it after launch_r6.
- 01:15-01:21 the rest of the 8B probes: c7 statement with schema /1
  refused by name; c8 `layers_with_own_calibration` emptied and c9 layer 1's
  own sh_s 7 -> 6 both refused (not the canonical statement); c10 one byte
  of segment-002 (block 1, the layer with its own sh_s) refused at block 1;
  c11 owner over it refused; c12 the lane's r6 run (/1) refused by name
  under the r7 binary. launch_r6.done = 0 (01:21:16). 15 probes, peak RSS
  <= 2.83 GiB.
- 01:21:57-01:25:56 launch_r6b: test build (218 s) then t3 RV6-8 (21 s):
  on the HONEST prover path every t34 forgery produced a receipt, and the
  verifier refused all six [MEASURED]: (i-a) a changed id with B_in row =
  E[old], (i-b) one changed B_in word, (i-c) an id >= V: "stage IN H (the
  LogUp sum claim is part of this opening)"; (ii-a) the endpoint over
  another prompt, (ii-b) a nonzero pad word, (ii-c) position 0 changed:
  "stage IN slot 00 [IN-00 IO-in ...]"; the consistent other-prompt
  control ACCEPTED. launch_r6b.done = 0.
- 01:26 both copies (mine, frozen-r7) re-checked against the manifest: 0
  mismatches. Guard status: no trv6-* job. NOTHING OF MINE PENDING.
- 01:28 REVIEW5.md final. Verdict: demo-fit. TR5-1..3 closed; the R8 rebase
  exact; per-layer calibration enforced (11 of 11 fields) and bound; the
  capture hooks inert / compiled out, no decommitment path, the census
  bump a real classification; the voc0 approval record and cross-check
  verified; the r7 8B demo re-verified (independent publication
  byte-identical, token 11). t34: the verifier rejects (i) and (ii) (static
  argument + the lane's controls + RV6-8). Findings: TR6-1 LOW (private
  prompt on argv), TR6-2 LOW (sink contract gaps, the t34 cases; prover
  hygiene), TR6-3..7 INFO.

## ROUND 7 (2026-10-20 UTC): frozen-r9 (the lane's rounds 8, 9, 10) -> REVIEW6.md

Object: `results/zk60_token_io_r1_20261017/frozen-r9/` (236 files =
`manifest_final_r9.sha256`, list b666a991...). Write set: this directory
(`logs7/`, REVIEW6.md), `ops/zkp-mvp/token-io-review-r9-scratch/`, and a
0700 scratchpad directory for the 8B run's prompt file and owner directory
(outside every git tree, as the CLI requires).

- 04:33 start: frozen-r9 re-hashed, 236 of 236 match, none missing, none
  extra [COUNTED]. Read the lane ledger's rounds 8-10. vs frozen-r7: 12
  changed, 3 added; private_block/run.rs additive only (two T128 profile
  constants, TOKEN_IO_RUN_PROFILES 3 -> 5, two run-shape arms); token_io.rs
  (3 test modules, the census helpers' T128 rows); load.rs (the two T128
  block profiles mapped).
- 04:34-04:38 static: the generic sealing pass (`prove_token_run_with`):
  stage IN `lookup_misses`, the input endpoint plane, every block's CS-1/4/6
  and CS-3 through `seal_check`, stage OUT byte misses and the output
  endpoint plane, ALL before `ZkRng::from_os` and `st.transcript()`; the
  proving pass from the header on is r7's line for line (the only moved
  line: `src.stage_in()`, which touches no transcript). The CLI's
  `seal_chain` (builder chain from x_in_L00, int16, parity at every layer,
  CS-3) and the next token from the builder's last plane; `--prompt`
  refused; `read_prompt_file` (0600 / stdin); owner `--token-out` /
  `--print`; OWNER_BASE `zk60-owner-private`; git's rule (`.git` dir with
  HEAD, `gitdir:` file) for explicit and default; PR4-15 removal events and
  `leftover_refusal`. Demo kit read (`tools/demo_present.sh`,
  `DEMO_PRESENTER.md`) against the CPU baseline README and D27 / D33.
- 04:40:00 launched detached `launch_r7.sh` (marker `logs7/launch_r7.done`):
  builds -> t1 my review tests (cli_tests::review_r7: prompt-file edges,
  owner token file, git-rule edges, owner-base modes) -> t2 the lane's
  token_io tests (r9_*, r9v_*, t128_*, pr4_*) -> an 8B T32 end-to-end: prove
  with the lane's NAMED r9 binary (the presenter demo's), verify / owner /
  input-owner with my binary, a re-check with the r9 binary.
- 04:52-04:57 builds exit 0 (219 s / 75 s); my binary eb1c2b74...; the
  lane's named r9 binary = b56f1b71... (the frozen note's) [COUNTED].
- 04:57:02-04:57:06 t1 my review tests: 4 passed / 0 failed, every CONTROL
  AS PREDICTED [MEASURED]. RV7-1 prompt file: 0600 / 0400 accepted; 0640,
  a symlink, a FIFO (no block), an empty and a malformed file refused (no
  entry echoed); `--prompt=ids` refused (exit 2); NOTE `--label --prompt`
  also exits 2 (harmless false positive). RV7-2: owner's default token file
  `next_token` 0600 beside the decommitment; NOTE a second owner call with
  the default path exits 1 AFTER a full re-verification (create_new); an
  existing --token-out is never overwritten. RV7-3 git rule: stub (no HEAD)
  accepted; .git dir with HEAD, `gitdir:` file, .git symlink refused; the
  DEFAULT refused under a repo $HOME, accepted under a stub $HOME; NOTE a
  non-gitfile .git file and a dangling HEAD are accepted (git does not take
  either for a repository either). RV7-4: a fresh base is 0700 / 0700; NOTE
  a pre-existing 0755 ~/zk60-owner-private stays 0755 (the owner dir itself
  is 0700).
- 04:57:06-05:00:37 t2 the lane's token_io tests on my build (peak 5.89
  GiB): 61 passed / 0 failed / 9 ignored; 71 AS PREDICTED / 0 NOT
  [MEASURED]. The five r9_* (every inadmissible witness refused before the
  header; the honest run builds exactly one header); r9v V1-V4: the plain
  prover STOPS in the sealing pass, the cheating prover (= the old path)
  finishes and verify REJECTS at stage IN H (LogUp) / IN-00 / OUT-10;
  t128: floors TinyLlama T128 2^-97.82 -> 97, 8B T128 2^-96.78 -> 96 (T32:
  97 / 97); T32 and T128 receipts each refused under the other's statement,
  each shape refused under the other T's profile; the seven pr4_* and tr6_3
  pass. 8B T32 end-to-end started 05:00:37 (prove, the lane's r9 binary).
- 05:00:37-05:10:54 the 8B T32 end-to-end [MEASURED, guard 0 s wait]: e1
  prove with the lane's NAMED r9 binary b56f1b71... (the presenter demo's)
  on b7voc0_T32 ho00 from a 0600 prompt file: sealed in 36.9 s (parity at
  32 layers, block load 17.1 s), prove 208.6 s, total 288.7 s, 34 segments,
  471,285,072 B, floor 97, peak 3.39 GiB; e2 my binary verify published
  (48.0 s / 79.9 s); e3 owner with --token-out: next token 11 in a 0600
  file, no token in the log; e4 input-owner 32 tokens; e5 re-check with
  the r9 binary statement-checked. The r9 statement equals the round-7
  run's except the two endpoint-root lines. launch_r7.done = 0.
- 05:12 frozen-r9 re-hashed: 0 mismatches. Guard status: no trv7-* job.
  NOTHING OF MINE PENDING.
- 05:20 REVIEW6.md final. Verdict: frozen-r9 is demo-fit. The sealing pass
  (generic + CLI) precedes the header for every input-provokable refusal,
  changes no transcript byte or draw, cannot be switched off in release,
  refuses no honest input; T128 floors 97 / 96, one 256-word endpoint row,
  cross-T refusals both ways; PR4-15/16/17 and TR6-3 as built; r9v V1-V4
  re-run and sound. Findings: TR7-1 LOW (the presenter page's "about 100x"
  is the 32-block quiet-box ratio; the demo's next-word proof is ~135x
  prove / ~186x with loading at 8B T32 on r9); TR7-2..7 INFO (8B options
  not dry-run through the script on r9, 8b-t128 not at all; the answer id
  on demo_decode's argv; three phrases slightly over the record; the CS-3
  seal's dependence on sources / the CLI's copied stage-shape derivation;
  a second default-path owner call fails after re-verifying; a
  pre-existing owner base keeps a loose mode).
