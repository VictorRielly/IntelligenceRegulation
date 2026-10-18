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
