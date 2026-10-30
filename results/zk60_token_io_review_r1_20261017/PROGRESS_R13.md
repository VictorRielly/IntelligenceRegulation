# Review of token round 13 (R-C2) — progress ledger

Reviewer: independent soundness / code review of the frozen token tree `frozen-r13/`
(manifest_final_r13.sha256, list sha256 6edb1ce6…). Scratch copy (the only tree I edit):
`ops/zkp-mvp/token-io-review-r13-scratch/`. Evidence: `results/zk60_token_io_review_r1_20261017/r13/`.
Output: `REVIEW_R13.md`. Not a privacy review.

## Log (UTC from `date -u`)

- 23:45 started; read CLAUDE.md, LANE_RULES (all addenda), coordinator 10-26 20:10/20:11 and 10-28
  notes through 23:45 (lean memory: one >= 3 GiB job box-wide), REVIEW_R12B (§5 = the R-C2
  requirements the brief calls "§9"), token PROGRESS round 13.
- 23:46 frozen-r13/ copied (cp -a) to the scratch dir. Guard status: astra-gpu-benchmark-l00 (gpu,
  2.1 GiB) holds the heavy lock.
- 23:48 tree checks (r13/tree_check_r13.py -> tree_check_r13.json): frozen-r13 and scratch 257/257 = manifest
  (list sha256 6edb1ce6… recomputed); R12b frozen tree 229/229, tree 51de5b83… recomputed; 219 R12b files equal in
  the token tree, 10 differ, 0 missing; per-file diffs in r13/native_diffs/.
- 23:50 independent 3-way rebase check (r13/rebase_check_r13.py -> rebase_check_r13.json, rebase_residue/): my own
  `diff3 -m t8 n8 n12` reproduces the lane's merge exactly for private_block.rs, s24, trained_block.rs (0 residue);
  hash_domain_tests / run.rs / run_capture.rs / s25 residue = the 4 conflict hunks (summed lengths 24/26/23, run.rs
  keep-both) + round-13 edits (classifier pin 4->5, readme word, s25 dedup +6). 33 native-only files == R12b.
  Rebase source ops/zkp-mvp/token-io newest mtime 10-26 19:35Z (unchanged since the rebase).
- 23:51 coordinator D44 message: before every guarded launch check results/zk60_guard_fix_20261021/WINDOW_HOLD;
  none of my jobs live. Background watcher on the hold file started (no guarded job launched so far).
- 23:55 independent dev-rung reference r13/rv13_dev_tied_reference.py (hand-decoded BF16, exact Fractions AND binary64,
  -> rv13_dev_tied_reference.json; 1.1 s, 34 MB RSS, unguarded light): tensor bba6d094…, embedding c0e816c9…, dev margin
  24e6ff4c… all EQUAL the lane's pins; 0 exact-vs-f64 disagreements (8 exact half-up ties in the margin, both paths agree);
  swapped (41/40) row b4a059cd…, w + w' in {0,1}; refusals start at scale 2^-10 (15 words), 2^-12: 129.
- 00:00 scratch edits (scratch only): classify_tied.rs gets a cfg(test)-only RV13_MUT mutation switch (14 mutants; pristine
  copy r13/classify_tied.frozen.rs.orig, sha256 b0eb5047…); new review_r13_tests.rs (R1-R10 attacks) registered in token_io.rs.
- 00:04 queue r13/run_rv13.sh launched detached (hold-file check before every launch; heavy-clear wait before the build):
  build (need 4.1 / cap 5.0, from lane a1's 3.24 GiB from-scratch peak), baseline, cross-binary, 14 mutation runs
  (need 2.0 / cap 3.0 each). Marker r13/logs/queue.done.
- 00:07 rvtk13-build PASS (3m02s; test binary hashline-056050b1…, r13/logs/test-binary.sha256).
- 00:08 baseline (lane classifier tests + my R1-R10): 38 passed, 1 failed, 4 ignored. All lane tests and my R1-R9 pass
  (every doctored table / parameter / profile / statement / schema-1 / min-bits / tensor-file attack refused). The one
  failure is my own R10 expectation: under the PRODUCTION dev policy, 6 reviewer-chosen contents all give verdict 0; the
  fixture's verdict 1 needs the test-only swapped policy (recorded as a coverage note; R10 now records instead of asserting).
- 00:09 xbin (lane's frozen r12 04036e26… and r13 e320c237… binaries): PASS. Same trained identity under both
  (061340df…). r12 refuses r13 receipts; r13 refuses r12 receipts; r12 proves AND accepts a doctored (rehashed,
  swapped) margin row -> verdict flipped to flagged (R-C1's gap, demonstrated); r13 refuses that receipt with either tables.
- 00:10 added for a second build: R11 (end-to-end margin arithmetic vs float logit difference), R7b upgrade attack
  (R-C1 segments under an R-C2 statement).
RVTK13 VIEW CLEAR 2026-10-29T00:20:38Z
  (WINDOW_HOLD seen 00:10:42Z; my last guarded job mut-no-g ended 00:10:44Z; the queue sits in its hold loop, no rvtk13
  job live or waiting since then; budget 0 at 00:20:29Z. Remaining mutants g-twice .. floor-off resume after the hold.)
- 00:12-00:24 (window hold; read-only work): mutation results so far (rc1, skip-policy, skip-copies, skip-bound,
  skip-second-digest, no-g): all killed except skip-second-digest (only my R10, a baseline failure, failed) -> N-r13-2.
  Found while reading: the library entry points (prove/verify_classify_run_with, run_capture replay) take any
  ClassifierTables; only the CLI loader ties them; the gate's capture_a_classify_rung_run still builds R-C1-style tables
  (N-r13-1). Shieldstral prove/verify streams the checkpoint twice (load_export + recompute) (N-r13-5).
  REVIEW_R13.md drafted (mutation table and R11 pending). Queue part 2 (r13/run_rv13b.sh) prepared, launches after
  queue 1's queue.done.
- 00:34 hold lifted; queue 1 resumed and ended 00:38 (queue.done 0). Mutation table (r13/mutation_table.json):
  13 / 14 killed; only skip-second-digest survives (N-r13-2). Measured peaks: build from scratch 2.16 GiB (182 s),
  test batches <= 0.69 GiB.
- 00:38 queue 2 (r13/run_rv13b.sh: build2 + baseline2 + xbin2 + R11 g-mutants) launched; it waits for a box clear of
  non-light jobs (its build declares 3.7) while Astra's GPU layers and Sol's argument builds alternate on the lock.
- 00:50-00:54 queue 2: build2 PASS (174 s, 2.16 GiB); baseline2 40/0/4 (lane classifier tests + R1-R11); xbin2 PASS
  incl. the upgrade attack (R-C1 segments under an R-C2 statement refused by r13 binary and in process); R11: integer
  margin -174280 vs k*L -172950.5 with g once (0.8 %), -211252.5 twice, -138648.8 none; mutants no-g / g-twice each fail
  R11 (margin moves onto their hypothesis). queue2.done 0; no rvtk13 job live; TMPDIR fixture dir empty.
- 00:55 REVIEW_R13.md written: ACCEPTED on soundness for R-C2's scope, no required fixes; notes N-r13-1..12 (N-r13-1 API
  binding only in the CLI loader; N-r13-2 untested second digest check); gate re-capture list in §10. Not a privacy review.
