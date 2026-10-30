# Token review, round 16 — reviewer's ledger (UTC from `date -u`)

Scope: independent soundness / code review of `results/zk60_token_io_r1_20261017/frozen-r16/` (the real
Shieldstral-1.0-3B classifier on native R13). Not a privacy review. Scratch: `ops/zkp-mvp/token-io-review-r16-scratch/`.
Evidence: `results/zk60_token_io_review_r1_20261017/r16/`.

- 09:31:44 start. Read CLAUDE.md, LANE_RULES (all addenda: guard 88af4c63, lean-memory rule), register D27 / D37–D41 /
  D45 and the R13 / token 13–15 / gate 18 notes, native REVIEW_R13 (§6, §9, §10), token REVIEW_R13 and REVIEW_R14, the
  lane's round-16 ledger section, frozen-r16.FROZEN.txt, DESIGN_CLASSIFIER §17. No WINDOW_HOLD; guard idle (budget 0).
- 09:3x copied frozen-r16 to the scratch; `r16/tree_check_r16.py`: frozen-r16 and scratch = manifest_final_r16 (300
  files, list sha256 f42f8c6e…, 0 changed / missing / extra); native R13 frozen tree = its manifest (269, tree
  bb9eb212…); token vs native R13: 257 equal, 12 differ (the lane's list), 31 token-only, 0 native files absent;
  R12b -> R13 changed 67, of which 55 taken byte for byte and 12 are the token-touched ones; 0 files left at R12b bytes.
- 09:4x `r16/rebase_check_r16.py` (token delta over native at r15 vs at r16, per file): every r15 token edit survives
  the rebase; the only R13 lines absent from the token tree are those the token lane replaced (merged counters
  hash_domain 36, OWN_SOURCE_FILES 38, s25 count; the HL_R13_LOADER_FIXTURES paths). OWN_SOURCE_FILES: R13's 32 in
  R13's order, then the token entries, no duplicate.
- 09:4x code reading: classify.rs / classify_run.rs / classify_cli.rs / classify_tied.rs / load.rs / token run.rs,
  native run.rs / trained_block.rs / tied_tables(/derive.rs) diffs (saved in r16/diffs/).
  Observation for S1: `policy_shieldstral_card()` (`shieldstral-1.0-3b-card-unsafe/1`) is still in the production
  `registered_policies()` and carries the export's (yes, no, scale, c): to be shown live.
- 09:47 review tests written in the scratch only (`token_io/review_r16_tests.rs`, one `mod` line in token_io.rs;
  env-selected mutant hooks `bits-l` in classify.rs and `prehdr-cs6` in classify_run.rs, test builds only).
  Receipt for item 5: hard links of the lane's hate-run (28 segments + statement.json) in
  ~/zk60-artifacts/token-io/review-r16/hate-run-link/ (no copy, no write into the lane's directory).
- 09:48:43-09:51:54 **build** [MEASURED, r16/logs/rvtk16-build.*; guarded build, declared 2.8 / cap 4.0, box otherwise idle]:
  from scratch, compiled at the first try, 191 s, peak RSS 2.25 GiB / cgroup 2.26 GiB. Test binary hashline-ebd2a2ba….
- 09:54:47-09:56:36 **tests** [MEASURED, r16/logs/rvtk16-tests.*; declared 2.4 / cap 3.5; peak 1.65 GiB; 109 s]: the
  lane's 7 round-16 tests + my S1-S4, one thread: **11 passed, 0 failed, 1 ignored** (the activation writer).
  * S1: the T128 profile door ADMITS FOUR Shieldstral policies — the three moderate ones AND
    `shieldstral-1.0-3b-card-unsafe/1` (P0 84, chunk 43; the full statement constructor too); the real T128 export's
    classifier_margin_parameters equal the card's. Unregistered ids (strict-*, /2, self-harm) refused by name.
  * S2: every term printed; floors 96 (T128) / 95 (T256) for all four policies; `--min-bits` at the floor passes the
    floor door, floor + 1 is refused at it (verify_classify_run:235), at both profiles.
  * S3 (item 7): cheating prover, sealed input = the honest content: control VERIFIED; wrong boundary 1, a
    self-consistent chain from a wrong layer-1 input, and a chain from a wrong B_in each give a 4-segment receipt that the
    verifier REFUSES (block 0 slot 22 IO-out equality; stage IN-C H opening).
  * S4: a reused derivation without its row, or 3071 / 3073 wide, refused; under another statement digest refused at the
    bound-profile read; the stub proves no second stream.
- 09:57 `r16/bits_r16.py` [COUNTED] (first principles + REVIEW_R13's N, not the lane's WholeRun): T128 2^-96.86 ->
  96, T256 2^-95.91 -> 95 (margin 0.912 bit), equal to the code and the lane's claim at all four policies; N from the
  code's U8 + S + F counts equals REVIEW_R13 §6's at both T. Stage terms 2^-107.09 (IN-C), 2^-112.28 (OUT-C).
- 09:57:09 mutants (bits-l, prehdr-cs6) then the real verify queued (r16/logs/q-mut.*, q-verify.*).
- 09:57:09-10:00:21 **mutants** [MEASURED, r16/logs/rvtk16-mut-*.{log,guard.json}; 1.65 GiB each]: `bits-l` (the R13 block
  term charged once instead of L) SURVIVES all 7 lane tests (T128 floor 96 -> 98) and is killed only by my S2
  (N-r16-1); `prehdr-cs6` survives everything (the per-stage CS-6 at classify_run.rs:283 still refuses: N-r16-4).
  Lane's 4 mutant logs re-read: each killed by its test (r16/mutation_table_r16.json).
- 10:00:22-10:01:33 **real verify** [MEASURED, r16/logs/rvtk16-verify-hate.*; guarded cpu need 3.0 / cap 5.0; the ONLY
  checkpoint stream of this review]: frozen-tree binary dae5abd7… on the moderate-hate receipt (made by e94cecf9…)
  via hard links: exit 0, not-flagged, identity 29aeba6c…, floor 96, root 4cf9e8ae… = the lane's; verify 39.6 s, total
  71.1 s, peak RSS 2.25 GiB, cgroup 5.0 (the cap, page cache; no kill). Hard links removed afterwards (nlink back to 1).
- 10:02 frozen-r16 re-hashed after all runs: 300/300 match, no extra. Evidence tally of the lane: s20 934/0/68 (29
  binaries, recomputed), red r15 run, 4/4 mutants, r15 <-> r16 and r16 <-> r16-frozen cross-verify logs: all as claimed.
- 10:05 **REVIEW_R16.md written: ACCEPTED WITH FIXES on soundness for round 16's scope.** Required: F-1 (medium,
  D45(2) conformance): the production policy list still admits `shieldstral-1.0-3b-card-unsafe/1` at both R13
  Shieldstral profiles (four policies, not three). Notes N-r16-1..7; §10 lists what the privacy gate must capture.
  Nothing of this review is running (guard idle).
