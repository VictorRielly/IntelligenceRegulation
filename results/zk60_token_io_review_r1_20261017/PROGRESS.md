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
