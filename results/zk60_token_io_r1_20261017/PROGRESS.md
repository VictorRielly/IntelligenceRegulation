# TOKEN I/O R1 implementation lane — PROGRESS

Lane: TOKEN I/O R1 IMPLEMENTATION (2026-10-17 evening). Brief: build rung R1 of
`results/zk60_token_io_design_20261017/DESIGN.md` v3 (public-row variant, tiny
vocabulary V = 300, rung_tc block geometry, 2 blocks) as one private run.
Binding rules: `ops/zkp-mvp/LANE_RULES_20261017.md`. No git writes; no privacy claim.

Write set (exclusive): `ops/zkp-mvp/token-io/` (working copy) and
`results/zk60_token_io_r1_20261017/` (this ledger, evidence, REPORT.md).

## Log (UTC from `date -u`)

- 20:00:08 lane start; read LANE_RULES, DESIGN v3, token_io_count.py v3, R0.
- 20:00:22 working copy: `cp -a` of `results/zk60_1b_native_20261017/r5/frozen-tree/`
  (frozen 2026-10-17T19:48:50Z, no target dirs) to `ops/zkp-mvp/token-io/`;
  all 217 files match `r5/manifest_frozen.json` byte for byte; baseline list
  written to `ops/zkp-mvp/token-io/BASELINE.sha256` (list sha256
  d6951f40d4bf44030ec1e1a41bd28386c69515f045df5a970776a9a0886e9680).
- 20:05 read the native tree (argument.rs, protocol.rs, run.rs, boundary.rs,
  endpoint_g.rs, wire.rs, layout.rs, shape.rs, trained_* tests, zk.rs mask API).
- 20:10 counter figures for R1 written BEFORE any construction:
  `counts/r1_counts.py` -> `counts/r1_counts.json` (imports token_io_count.py v3
  read-only; Model d384 / V300 / L2, stages at 2^12). [COUNTED]:
  stage IN A 10 / H 14 / M 12 rows, 98,304 elements, sites A 3 / H 3, 4 slots;
  stage OUT A 116 / H 50 / M 26 rows, 679,936 elements, sites A 45 / H 12,
  11 slots, 73,728 byte lookups; token endpoints 256 words, 1 site, 6 rows.
- 20:13 DESIGN FINDING TF-1 (limb count): at R1 (d 384, V_pad 512) the keyed
  window is 33 bits and the counter derives FIVE byte limbs; DESIGN 3.1 (A4)
  and the brief say SIX (true at TinyLlama 41 bits and 8B 44 bits, where the
  two agree). D24's F-1 bullet in DESIGN 4.1 says "the limb count is derived,
  never exported". Decision: the code derives `limbs = ceil(window/8)` (5 at
  R1, 6 at TinyLlama / 8B), matching the counter; soundness unchanged
  (delta in [0, 2^40), |identity| < 2^33, 2^40 + 2^33 < p, no pin needed by
  the C-4 argument). Recorded for the design owner; no check weakened.

## Implementation plan (fixed 20:13)

New code only, under `hashline/src/private_block/token_io.rs` and
`token_io/{stage_in,stage_out,run,tests}.rs`; two additive edits: `mod
token_io;` in `private_block.rs`, and one new run-profile arm in `run.rs`'s
CS-7 registry (`RUN_PROFILE_TOKEN_IO_RUNG_TC`). No existing relation, slot,
profile string or byte moves.

* Generic stage slot runner (a schedule-driven copy of `argument::run_slot`)
  reusing `Tab / Priv / Coord / SlotProof / Acc / Side`.
* Stage IN (4 slots): IO-in (256-word endpoint, supp_T), query zero-check
  (LogUp + BOS with its own `mu_bos` + pad, fresh mu each), table zero-check
  (clause + pad), ZS; LogUp sum on H_in. Domains lifted to 2^12.
* Stage OUT (11 slots): IO-in (B_out row T-1 at fixed public bits), SS
  (private) / TZC (host), LZC, HEAD (private) / VZC (host, keyed argmax A1,
  A5 host term, helpers, pad), DZC (final norm c0/c1/c2 + helpers + pad),
  RSEL (A2/A3/A6 with fresh c1/c2/c3), TAB, ZS, IO-out. Implementation note
  TI-1: the one-row domain To is laid out over 2 entries (log 1) because a
  log-0 claim has an empty point and `audit_claims` reads an all-empty-point
  claim as the sum claim; rows/sites/elements are unchanged (1 row each).
* Run: header -> stage IN (commits B_in, A, M, H; opens M A H, input token
  endpoint) -> L block stages unchanged (all four IO roles are two-site
  boundaries) -> stage OUT (opens M A H, B_out, output token endpoint).
  Segments: L + 2 files; block segments use the existing `wire` encoder.

- 20:22 first drafts of `token_io.rs`, `token_io/stage_in.rs`,
  `token_io/stage_out.rs` written (not yet compiled).
- 20:23 COORDINATOR (two changes, adopted before the head relation was built):
  (1) D25 T4 amended 20:21 UTC: per-row int8 head with integer multipliers
  `m_j in [1, 2^12]` (fidelity REPORT: `m_j = max(1, round(2^12 s_j / max s))`),
  `logits_j = m_j (y . W'_j)`; keyed window re-derived over the class:
  bits(2^v * 2 d 127^2 * 2^12 + V - 1) = 45 at R1 -> SIX byte limbs (53 at
  TinyLlama -> 7, 56 at 8B -> 7). TF-1 still stands (limbs derived), and at
  R1 the derived count is now six, matching the brief. Counter figures for
  test 1 are recomputed with the counter's own formulas and the amended
  logit bound (`logits_bound` substituted, read-only import).
  (2) D27 (20:22): tier levers come from the run profile: Q, stage row-width
  floor and rate, token-endpoint row width and rate, and the lookup challenge
  field (degree 2, F_p^2, the only one built) live in a `Tier` value of the
  token profile (R1 = today's constants), are carried in the statement's
  parameter line, and no new-stage code uses them as literals. Limitation
  recorded: the mask commitment M's Q is `zk.rs`'s fixed MASK_Q (a shared file
  this lane does not edit) for blocks and stages alike.
- 20:24 `counts/r1_counts.py` re-run with the amended bound (key
  `per_row_12bit_D25_T4_amended`), BEFORE the construction compiled: stage IN
  unchanged (A 10 / H 14 / M 12, 98,304 el.); stage OUT A 121 / H 50 / M 26,
  700,416 elements, sites A 47 / H 12, 11 slots, 77,824 byte lookups; window
  45 bits, 6 limbs.
- 20:25-20:38 code written: `token_io.rs` (Tier, TokenProfile door, tables with
  per-row multipliers, StageLayout, schedule-driven slot runner, wire,
  owner check), `token_io/stage_in.rs`, `token_io/stage_out.rs`,
  `token_io/run.rs` (statement, header, prover, verifier, honest pipeline),
  `token_io/tests.rs` (counts, two honest runs + owner checks, controls,
  door, D16 audit, the fresh-process pair), `token_io/r0_words.rs` (generated
  by `tools/gen_r0_words.py` from R0's vectors.json, digests checked).
  Additive edits: `private_block.rs` (`mod token_io;`), `run.rs` (profile
  constant `RUN_PROFILE_TOKEN_IO_RUNG_TC`, one CS-7 registry arm, one refusal
  of that string in `RunStatement::new_bound_from_digests`).
  `tools/crosscheck_r0.py`: R0's functions on the exported B_out row.
- 20:39 launched guarded `cargo check --tests` (detached; logs/c1-check.*).
- 21:24 check done (waited ~44 min for the heavy lock; 14 s of work, peak
  1.0 GiB): exit 0, ZERO errors, one unused import in token_io.rs (removed).
- 21:24 launched guarded `cargo test --release --lib token_io -- --nocapture
  --test-threads 2` (cpu class, need 4 / cap 7 GiB; logs/t1-tests.*).
- 21:39 t1-tests DONE (waited 866 s for admission; 325 s wall incl. the
  release build; peak RSS 1.83 GiB): **10 passed, 0 failed, 2 ignored**
  (`logs/t1-tests.log`). Test 1 counts equal the counter (stage IN A 10 H 14
  M 12, 98,304 el.; stage OUT A 121 H 50 M 26, 700,416 el., u8 77,824; window
  45, 6 limbs). Honest runs [MEASURED, shared box, n=1, test binary]:
  r0-model next token 24 (= independent reference), prove 4.41 s, verify
  0.64 s; generic next token 116 (= reference), top-2 margin 9,781,470,
  prove 3.22 s, verify 0.60 s; receipt 19,026,480 B in 4 segments
  [1,224,328 / 7,421,464 / 7,421,464 / 2,959,224] = the counted lengths;
  both owner checks rebuild both roots. EVERY control refused AS PREDICTED
  (49 control lines; #6/#8/#19 N/A at the public row; #20/#21 public-row
  analogues).
- 21:45 launched the fresh-process pair, part 1: `token_io_r1_prove_to_dir`
  (ignored test; TOKEN_IO_R1_OUT = runs/; logs/p1-prove-to-dir.*).
- 21:52 p1 DONE (exit 0): both fixtures written to `runs/{r0-model,generic}/`
  (4 segments each, 19,026,480 B; statement.txt; crosscheck.json; head).
  r0-model next token 24, prove 3.49 s, in-process verify 0.64 s; generic 116,
  3.65 s / 0.59 s [MEASURED, shared box, n=1]. `tools/crosscheck_r0.py runs/`
  -> ALL AGREE (R0's final_norm / head_logits x m_j / first_argmax on the
  exported B_out row gives the decommitted id in both;
  `runs/crosscheck_result.json`). Note: max |y| 11-12 under the refusal-free
  Cn (DESIGN C-7's ~2.5-bit resolution cost, visible here).
- 21:53 launched part 2: `token_io_r1_verify_from_dir` (fresh process,
  reads only the saved bytes + regenerated public model; logs/p2-*).
- 22:00 p2 DONE (exit 0): FRESH-PROCESS VERIFY from the saved bytes accepted
  both runs (r0-model 0.63 s, generic 0.59 s [MEASURED, shared box, n=1]);
  a one-bit change refused in both.
- 22:01 HAND-BACK forced by the harness before the full existing suite ran.
  NOT RUN: the full `cargo test --release --no-fail-fast` of this copy (the
  frozen toy / profile pin tests; baseline r5-suite2: 688 passed, 0 failed,
  29 ignored, lib 543). Next step (guarded, cpu, need 5 / cap 8, ~17 min):
  `cargo test --release --offline --locked -j2 --no-fail-fast --manifest-path
  ops/zkp-mvp/token-io/hashline/Cargo.toml -- --test-threads=8`; expected lib
  553 passed / 31 ignored. Nothing launched by this lane is pending.
- 22:02 COORDINATOR: finish item 4 (full suite); report saved as REPORT.md by
  the coordinator; independent review starts on a frozen copy -> NO SOURCE
  CHANGES after the suite starts unless the suite finds a defect.
- 22:02 source manifest at suite start: `manifest_suite_start.sha256` (223
  files, list sha256 b9a551761c1109317c67747ed8e9ea0601af1b6efd4c5e92a7f731bedb995e98);
  vs BASELINE: changed `private_block.rs`, `private_block/run.rs`; added the
  six `token_io*` files. Launched `s1-suite` (guarded cpu, need 5 / cap 8,
  `cargo test --release --offline --locked -j2 --no-fail-fast -- --test-threads=8`,
  the r5-suite2 command on this copy; logs/s1-suite.*).
- 22:36:29 s1-suite admitted and started (waited ~34 min for the heavy lock).

- 22:40 COORDINATOR: the independent review is in
  (`results/zk60_token_io_review_r1_20261017/REVIEW.md`: R1 sound as built,
  base for R2 with conditions). After the suite: fix TR-1..TR-4 test-first
  (failing-first controls), note TR-5..7 (zero To entry 1 of tok/M if cheap);
  then plan and build R2 (TinyLlama, 22 blocks).
- 22:43 R2 input export launched (light class, need 2.5 / cap 4 GiB; source
  untouched): `tools/export_head_r2.py` -> `r2_inputs/` (the fidelity lane's
  `build_heads`, read-only import; SHA-256 of the per-row int8 rows and the
  scales asserted equal to that lane's; multipliers by its rule).
- 22:44 R2 counter figures written BEFORE the R2 construction:
  `counts/r2_counts.py` -> `counts/r2_counts.json` (TinyLlama T32, mode (i),
  public row, per-row head, stages at 2^12) [COUNTED]: stage IN A 17 / H 28 /
  M 12 rows, 184,320 elements, sites A 3 / H 3; stage OUT A 182 / H 110 / M 26,
  1,196,032 elements, sites A 49 / H 13, 282,624 byte lookups; window 53 bits,
  7 limbs, 4 VZC helpers; token endpoints 256 words / 6 rows.

- 22:45 h1 head export DONE (22.5 s, peak 1.73 GiB): `r2_inputs/
  head_int8_perrow.bin` sha256 b99cbec5... = the fidelity lane's per-row rows,
  scales sha256 5eb2b350... = the lane's; `head_mult12.bin` (sha256
  7824019e..., m_j in [1027, 4096], 1,836 distinct); no -128 word;
  `head_manifest.json` carries Cn 5,664 (calibrated) / 1,024, g0 127, tn 10,
  Ceps 74,429.

- 22:57 s1-suite RESULT (exit 101): 29 targets, **692 passed, 6 failed, 31
  ignored** (lib 547 / 6 / 31; every integration target and doc-test ok, so
  the frozen toy pins, archived receipts and slot-IR digests all PASS). The 6
  failures are the registry / census discipline tests, all caused by the new
  profile string and the new module: s24 profile coverage + key sets, s24
  capture-writer source pins, s25 W-2 hash-input kinds, s25 W-7 registry
  count, s25 W-11 call-site census, s33 printable registry.
- 22:58 CENSUS FIXES (no census weakened or skipped; two strengthened):
  * token_io absorbs now use the block run's OWN labels (`pb-slot`,
    `pb-scalar`, `pb-term`; stage locality via `pb-run-stage` = 0 / L+1 and
    `pb-run-block` = the embedding / head digest), so the token run adds no
    label kind — only new data lengths, all in the W-2 table;
  * `token_io::registered_token_runs()` (test-only): the ONE list s24, s25
    and s33 read for token-I/O profiles;
  * s24: the token run profile is covered; its transcript is keyed by its
    BLOCK shape's key set (measured, as for every block run) and its would-be
    own keys are in the forward guard. **TR-7 decision: keep the block
    shape's key set** (the measured rule for every run profile; transcripts
    are separated by the run profile string as the domain). DESIGN 4.1's
    "own hash-tag key set" sentence should be amended (design lane).
  * s24 capture writer: `token_io.rs` is a production module and PINNED,
    with its three production submodules, in `run_capture::OWN_SOURCE_FILES`;
  * s25 W-11: three keyed tree-hash entry points added to the scan
    (strengthening); production SUBMODULES are now scanned (strengthening):
    six token_io call sites classified (TK1-TK6 statement digests, owner
    check P2-P4 recomputation); W-8: the sixth generator site
    (`prove_token_run`) acknowledged, and `prove_token_run` constructs exactly
    one generator (added to the per-prover check);
  * s25 W-2: `kinds_of_token` (every hash-input kind of the token run, from a
    real statement) checked by the same per-function rule; the loop now
    reports every undeclared pair at once (same assertion);
  * s33: the token profile is in the printable-ASCII registry;
  * hash_domain_tests label scan: the four token_io sources added.
  Files changed: token_io.rs, token_io/{stage_in,stage_out,run,tests}.rs,
  s24_tests.rs, s25_tests.rs, s33_tests.rs, hash_domain_tests.rs,
  run_capture.rs (list only).
- 22:59 launched targeted run `t2-census` (s24/s25/s33/hash_domain/token_io).
- ~23:10 session stopped (coordinator resumed 23:21); t2-census kept running
  detached.
- 23:24 t2-census RESULT (exit 0): **65 passed, 0 failed, 2 ignored** (the
  two ignored are the env-gated R1 prove-to-dir / verify-from-dir); all six
  previously failing census tests pass, nothing skipped or exempted.
- 23:24 source manifest at suite-2 start: `manifest_suite2_start.sha256`
  (223 files, list sha256 579bd6e0...; `tools/manifest.py`); vs suite-1
  manifest exactly the ten files of the 22:58 list changed.
- 23:24:51 launched `s2-suite` (guarded cpu, need 5 / cap 8, the same full
  command; logs/s2-suite.*). The census tests read source files at run time,
  so the working copy stays frozen until s2 ends; TR-1..TR-4 / R2 edits are
  prepared in `wip-src/` (a copy of hashline/src) and synced back after s2.

## R2 plan (22:44; TinyLlama-1.1B, T32, 22 trained blocks, mode (i), public row)

1. **Inputs.** Export `results/zk60_1b_calibration_20260929/export/
   pg_rot1_b4_T32_cal128` (22 layers, `embedding_int16.bin` 32,000 x 2,048,
   sha256 `ad68c716...`, `seq_ho00` token ids with BOS 1, `x_in_L00` = the
   embedded rows, the TOKEN_IO_SPEC check); the per-row head + multipliers from
   `r2_inputs/` (fidelity lane's rows, `b99cbec5...`); final norm g0 127,
   tn 10 (window 32 at d 2048), Ceps 74,429, **Cn 5,664 (calibrated, the
   reviewer's condition (b))**; BOS 1; V 32,000 (V_pad 2^15).
2. **Multi-row stage layout (new code, reviewer condition (a)).** Each stage
   domain gets its own log: `max(natural, stage row log)` (Voc / Vo = 15, Do =
   12 since d_pad 2^11 lifts to the row width, TL = 12); planes of 8 rows;
   VZC / RSEL / table zero-check cubes of 2^15; IO-in / HEAD cubes at the
   natural d_pad (2^11) with the lift bits fixed. The R1 door's "one stage row"
   refusal becomes a derived layout; `A_GROUPS` / `H_GROUPS` re-derived (the
   key structure is unchanged: one key per claim point). Failing-first controls
   at R2: the counted layout = `r2_counts.json`; the R2 rows of the 23-row
   table that touch the new planes (selector / limbs on entries >= 4096 of the
   Vo cube, a pad entry above V in the second row, histogram moved within the
   Voc rows, a limb in the 7th position not a byte).
3. **Run.** New run profile (D17) `...private-token-io-run-tinyllama-1.1b-t32-
   public-row/1`, registered for `Shape::tinyllama_trained(32, ...)` (CS-7),
   bound to a trained-model statement built from the export's records with
   THIS run profile (`TrainedExport::statement_of_records` logic, own profile).
   The 22 blocks loaded once with the native loader (`TrainedExport::
   load_layer`, every array SHA-checked); the honest pipeline keeps only the
   23 boundary planes (128 KiB each) and rebuilds each block's witness in its
   stage. Fidelity/parity: block 0's input plane equals `x_in_L00`, and every
   boundary equals the export's `x_out_Lk` (the native parity).
4. **D20.** With Cn 5,664 the final-norm int8 overflow is a live,
   input-dependent honest refusal (before any commitment, naming no position);
   a test shows it fires on a crafted row and not on seq_ho00 / ho36.
5. **Memory / time [MODEL until measured].** 22 padded blocks ~1.3 GB, tables
   ~0.2 GB (embedding 131 MB, head 66 MB), one witness at a time (~0.6 GB at
   d 2048 T32); the native 22-block stack prove took 88 s / 1.41 GiB (r5,
   history). Declare need 4 / cap 7 GiB for the first run; measure.
6. **Acceptance at R2.** Honest run on seq_ho00 (and ho36) proves and verifies
   in a fresh process; the decommitted id equals R0's reference on the native
   B_out row and the fidelity lane's integer-head token at the last position;
   counted layout = counter; R2 controls; existing pins re-run.

## Note for the design lane: TF-1 (limb count is DERIVED)

DESIGN v3 3.1 (A4) and 4.4 N-2 write "six byte limbs"; R0 hard-codes
`DELTA_LIMBS = 6`. The counter derives `ceil(window / 8)` and DESIGN 4.1's D24
bullet says "the limb count is derived, never exported". The two agree at
TinyLlama and 8B under the per-tensor head (41 / 44 bits -> 6) but not at R1
(33 bits -> 5). Under D25 T4 as amended (per-row multipliers in [1, 2^12]) the
window is bits(2^v * 2 d 127^2 * 2^12 + V - 1): 45 at R1 -> 6 limbs, 53 at
TinyLlama -> 7, 56 at 8B -> 7. Suggested text: "delta lies in L =
ceil(window / 8) byte limbs, the window derived over the declared class of d,
V and the head multipliers; no top-limb pin; no-wrap needs 2^(8L) + 2^window
< p." R1 implements exactly that (`TokenProfile::new`); R0's checker and the
counter's per-tensor bound should be updated for the per-row head (R2 counts).

- controls table: `logs/controls.md` / `logs/controls.json` (49 lines, 0 not
  as predicted), from `tools/controls_table.py logs/t1-tests.log`.
- Note: the harness refuses a REPORT.md written by this subagent ("return
  findings as text"); the report goes into the hand-back message for the
  coordinator to save as `REPORT.md`.

## Review fixes TR-1..TR-5, test first (prepared 23:25-23:40 during s2)

Prepared in copies (the working copy stays frozen until s2 ends):
* `wip-src/` = STAGE A: the five failing-first tests (`tr1_*` x2, `tr2_*`,
  `tr3_*`, `tr4_*`, `tr5_*`) plus API stubs WITHOUT enforcement:
  `Tier::REGISTERED` + B-1 floor constants (unused), `column_log2` /
  `hiding_opening_log2` / `mask_opening_log2`, mask dims derived from zk.rs
  (same values 1024 / 4096 / 12), `StageSegGeom::mask_checks()` (still the
  tier's Q), `Decommitment::of`, the statement's derived whole-run figure
  `WholeRun` (column + LogUp derived, floored, bound in the parameter line),
  `VerifierPolicy` argument (ignored), `owner_check_input/output` (root only),
  `stage_in/out::logup_size`. Expected: the six tr tests FAIL, every other
  test passes.
* `wip-src-b/` = STAGE B: the enforcement. Tier::check: Q != MASK_Q refused
  (TR-2), B-1 floors (stage row >= 2^12, stage <= 2^-103, endpoint <=
  2^-106), registered name+levers (TR-1); M opening sized by MASK_Q (TR-2);
  `variant_is_built` in endpoint_specs / TokenRunStatement::new / prover /
  verifier (TR-3); verifier refuses a statement below its policy minimum and
  a tier the door refuses before reading any segment (TR-1); owner checks
  with the plane rules (TR-4); head word -128 refused, class in describe()
  (TR-5); control #22 now predicted at the door.
* TR-6: decided with R2 (stage OUT is reworked for multi-row planes there;
  adding tok / M to TZC's pad fold costs 2 A sites = 4 A rows and moves the
  counts off the counter, so it is either done together with an amended
  counter or listed as a gate-checklist exception). TR-7: recorded 22:58.
* The R1 rung's derived whole-run figure [COUNTED, by hand before the run]:
  7 openings at 2^-96.13 (2 blocks x A, H + 3 boundaries, row width 2^10)
  dominate: 2^-93.31 -> floor 93 bits; the R1 tests use a 93-bit policy.

- 23:50 **s2-suite RESULT (exit 0): 29 targets, 698 passed, 0 failed, 31
  ignored** (lib 553 passed / 31 ignored; every integration target and
  doc-test ok). Against the r5-suite2 baseline 688 / 0 / 29: +10 passed and
  +2 ignored = exactly this lane's 12 token_io tests (10 run, the 2
  env-gated R1 fresh-process tests ignored). The frozen toy pins, archived
  receipts and slot-IR digests pass unchanged (they live in the integration
  targets and the lib's pin tests, none edited). Source = the 23:24 manifest
  (`manifest_suite2_start.sha256`, 579bd6e0...). Guard: waited 753 s for the
  heavy lock, ran 782 s, peak RSS 4.21 GiB (cgroup 4.83). Logs
  `logs/s2-suite.*`. -> the census fixes are complete; next the TR fixes.
- 23:51 STAGE A synced into the working copy (`manifest_stageA.sha256`,
  0ab564df...; vs suite-2: the five token_io files) and launched
  `t3-tr-failfirst` (guarded cpu 4 / 7 GiB: `cargo test --lib -- token_io`).
  Expected: tr1 x2, tr2, tr3, tr4, tr5 FAIL; every other token_io test passes.
- 23:56 t3-tr-failfirst RESULT (exit 101), exactly as predicted: 10 passed,
  **6 FAILED** = tr1 (door ADMITTED endpoints 2^8 rate 1/4), tr1 (a 94-bit
  policy ACCEPTED the 93-bit statement), tr2 (M opening sized by Q = 128),
  tr3 (a P statement was BUILT), tr4 (another prompt passed the input
  owner), tr5 (a -128 head word admitted); every R1 test passes with the
  stubs. Whole-run figure printed [COUNTED]: 17 openings, column 2^-93.32,
  LogUp (derived) 2^-106.63, total 2^-93.32, floor 93 bits.
- 23:57 STAGE B synced (`manifest_stageB.sha256`, a7b2a853...; vs A:
  token_io.rs, token_io/run.rs, token_io/tests.rs) and launched
  `t4-tr-fixed` (token_io + s24 / s25 / s33 / hash_domain / run_capture
  censuses; the parameter line and the profile text changed length).
- TR-6 DECISION (23:57): listed as a gate-checklist EXCEPTION for now, not
  coded: `tok` and `M` at To entry 1 (the TI-1 lift) are committed words no
  clause reads (reviewer: no soundness or privacy consequence). The fix (both
  in TZC's pad zeta-fold, +2 A sites = +4 A rows at R1 and R2, A_GROUPS
  unchanged) moves both rungs' counts off the counters, so it goes in with
  an amended counter in a follow-up, with its own failing-first control
  (tok[1] = 5, M[1] = 7 refused at OUT-02).

## R2 build (prepared 23:40-00:10 in `wip-src-c/`; C1 = the same with R1's one-row door, for the failing-first run)

* Multi-row stage layout: `TokenProfile::{ti,voc,lo,do,vo,tab}_log()` (each
  domain's padded log lifted UP to the stage row width; at R1 all 12, so R1's
  layout and bytes are unchanged); stage IN planes [tok Ti, m Voc] / [h_q Ti,
  h_tab Voc, u row]; stage OUT A [To x4, LIMB Lo, Do x12, Vo x(1+L), hist
  Tab], H [Lo, Do x6, Vo x hv(L), Tab, u]; slot cubes per domain (SS / DZC on
  Do, LZC on Lo, HEAD's r_j / VZC / RSEL on Vo, TAB on Tab). The R1 door's
  one-row refusal is replaced by the derived-layout checks (the input
  endpoint fits Ti; no domain above 2^17).
* New run profile (D17) `hashline-zk-mr1/private-token-io-run-tinyllama-
  1.1b-t32-trained-public-row/1`, CS-7 arm `Shape::tinyllama_trained(32, cal,
  f_e)`, in `TOKEN_IO_RUN_PROFILES` (blocks-only runs refuse it) and in
  `registered_token_runs()` (every census reads it; the W-2 census at the
  run's own L = 22 from a real statement, one synthetic block repeated).
* `token_io/r2_tests.rs` (test only): R2 counted layout = r2_counts.json;
  D20 at Cn 5,664; multi-row honest run + 7 multi-row controls (R2-1..R2-7:
  #1, #2, #12b, #15 on the second row of a two-row Vo plane, a pad limb above
  V, the histogram moved between Voc rows, a padded id in the second row);
  the ignored R2 run pair (prove to dir, fresh-process verify), streaming
  witnesses (only the 23 boundary planes are kept), parity against the
  export's x_in_L00 and every x_out_Lk, the decommitted token against an
  independent reference on the export's x_out_L21 row 31 (and
  `tools/crosscheck_r2.py`, R0's functions in numpy, afterwards).
* R2 derived whole-run figure [MODEL by hand]: 71 openings at 2^-103.69
  (44 block A/H, 23 boundaries, 4 stage) + 24 masks + 2 endpoints -> column
  ~2^-97.45; LogUp ~22 x 6.3 M lookups -> ~2^-101; total ~2^-97.3, floor 97
  (the counted test asserts >= 95 and prints it); the R2 verifier's policy is
  the D27 MVP level, 95 bits.
- 00:28 t4-tr-fixed came back with the SAME six failures at the same lines:
  the stage-B files were synced with `cp -a`, which kept their edit times
  (23:3x UTC), older than stage A's build (23:52), so cargo did not rebuild
  and the run tested stage A's binary. (Stage A itself WAS rebuilt: its
  files were newer than the previous build, and its new tests ran.) t4 is
  void. Re-synced stage B with fresh mtimes (`cp -r`, manifest unchanged
  a7b2a853...) and launched `t4b-tr-fixed` (same command). Rule from here:
  never sync with timestamp preservation.
- 00:45 **t4b-tr-fixed RESULT (exit 0): 71 passed, 0 failed, 2 ignored**
  (token_io 18 incl. the six tr tests, and every s24 / s25 / s33 /
  hash_domain / run_capture census): TR-1..TR-5 FIXED, each control failing
  first (t3) and passing after (t4b), no census weakened. (Passing tests'
  stderr is captured by the harness; the TR evidence lines are printed with
  --nocapture in the next run.)
- 00:46 STAGE C1 synced (`manifest_stageC1.sha256`, 47d39162...: the R2
  code with R1's one-row door kept) and launched `t5-r2-failfirst` (guarded
  cpu 4 / 7: `cargo test --lib -- token_io::r2_tests`). Expected: the R2
  counted layout, D20 and both multi-row tests FAIL at the R1 door (V_pad
  above one stage row); the two R2 run tests are ignored.
- 00:48 t5-r2-failfirst RESULT (exit 101), as predicted: **4 FAILED** at
  the R1 one-row door (counted layout and D20 at V_pad 32,768; both
  multi-row tests at V_pad 8,192), 2 ignored (the R2 run pair).
- 00:49 STAGE C synced (`manifest_stageC.sha256`, 41133421...; vs C1: the
  door only) and launched `t6-r2-built` (token_io incl. r2_tests + the
  censuses, --nocapture for the evidence lines).
- 01:02 t6-r2-built RESULT (exit 101): 74 passed, **1 failed**, 4 ignored.
  PASSED (evidence lines in logs/t6-r2-built.log): the R2 counted layout =
  r2_counts.json exactly (stage IN A 17 / H 28 / M 12, 184,320 el; stage
  OUT A 182 / H 110 / M 26, 1,196,032 el, 282,624 byte lookups, window 53,
  7 limbs) and the R2 whole-run figure [COUNTED] 97 openings, column
  2^-97.46, LogUp 2^-100.96, total 2^-97.33, floor 97 bits; D20 at Cn 5,664
  (refused before any commitment, no position named; admitted at Cn 1,024;
  a spread row admitted, |y| <= 27); the multi-row honest run (V 5,000,
  two-row vocabulary planes: proves 3.35 s, verifies, owners check, token
  1323 = reference) and the seven multi-row controls R2-1..R2-7 AS
  PREDICTED; every R1 test and the TR tests (evidence lines now printed).
  FAILED: s25 W-2 census for the NEW TinyLlama token profile: its transcript
  constructor input (12 + 76 = 88 B) equals the `schedule` absorb (48 + 8 +
  32 = 88 B), an undeclared equal-length pair under F_T. Fixed by choosing
  the profile string (not frozen; D17 new string), not by declaring:
  `hashline-zk-mr1/private-token-io-run-tinyllama-1.1b-t32-trained-
  statement-public-row/1` (86 chars, constructor 98 B: no kind of that
  length and none within one byte, from the full census printout; it also
  follows the block-run naming `-trained-statement`). Working copy =
  `manifest_stageC2.sha256` (1ef25c3c...; vs C: private_block/run.rs).
  Launched `t7-r2-census` (same filter, --nocapture).
- 01:09 **t7-r2-census RESULT (exit 0): 75 passed, 0 failed, 4 ignored**
  (token_io incl. r2_tests, every census incl. the TinyLlama token profile
  at L = 22). The R2 code is complete at stage C2.
- 01:10 launched `t8-r2-prove` (guarded cpu need 4.5 / cap 7.5 GiB, max
  30 min): the ignored `token_io_r2_prove_to_dir`, seq ho00, out
  `runs/r2/ho00/`. Then `t9-r2-verify` in a fresh process.
- 01:21 **t8-r2-prove RESULT (exit 0): THE FIRST R2 PROVING RUN.**
  TinyLlama-1.1B, the export's 22 trained blocks, T32, prompt seq ho00
  (BOS 1), embedding 32,000 x 2,048 int16, per-row int8 head with 12-bit
  multipliers, final norm g0 127 / tn 10 / Ceps 74,429 / **Cn 5,664
  (calibrated)**, tier R1_MVP, public-row variant: proved under the new
  profile `...tinyllama-1.1b-t32-trained-statement-public-row/1`; the
  output owner's check returns **next token 29914 = the in-test reference**
  (top-2 logit margin 191,997,655); B_in = the export's x_in_L00 and every
  boundary = the export's x_out_Lk (parity bit-exact at all 22). Receipt
  **255,258,816 B in 24 segments** (stage IN 1,267,576; 22 blocks x
  11,391,800; stage OUT 3,371,640 = the counted lengths); **prove 85.3 s**
  (blocks 3.4-4.1 s each, stage IN 0.51 s, stage OUT 0.90 s; witness
  rebuild 4.3 s of it), load 3.9 s, pipeline 4.7 s, **peak RSS 2.45 GiB**
  (cgroup 2.74) [MEASURED, shared box, n=1; waited 563 s for the lock].
  Derived whole-run figure [COUNTED]: 97 openings, column 2^-97.46, LogUp
  2^-100.96, total 2^-97.33, floor 97 bits (bound in the parameter line).
  Evidence `runs/r2/ho00/` (segments, statement.txt, crosscheck.json).
- 01:22 `tools/crosscheck_r2.py runs/r2` (R0's own final_norm / head_logits /
  first_argmax, numpy for the 32,000-row head, on the export's x_out_L21 row
  31): **29914, AGREES** with the decommitted id; the fidelity lane's
  per-row-12-bit integer head at the same position (s4_positions, T32
  cal_m1.50 pr_m12_tok) is also 29914, and so is its float head. D = 51,671,
  max |y| 49 (no D20 refusal on ho00 at Cn 5,664).
- 01:23 queued `tools/chain_after_r2.sh` (detached, every leaf guarded,
  exit files): t9 R2 fresh-process verify -> t10 / t11 R1 evidence re-run
  (prove-to-dir + fresh verify; the R1 transcripts moved with the census
  labels and the parameter line) -> s3 full suite on stage C2.
- Cosmetic note: `TokenProfile::describe()` still opens with the literal
  "token-io R1:" for every rung (transcript-bound text, harmless; renaming
  moves bytes, left for the next profile change).
- 01:25 **t9-r2-verify RESULT (exit 0): the R2 receipt verifies in a FRESH
  process** from the saved bytes (every public input rebuilt from the
  export's public files and the tables, no seq_* data; roots and context
  from statement.txt; parameter line and trained-statement identity equal)
  under a **95-bit verifier policy** (D27 MVP level; the statement's figure
  is 97): accepted in 10.6 s (load 4.9 s); a one-bit change refused
  [MEASURED, shared box, n=1].
- 01:25 R1 evidence re-run on the final code (the transcripts moved):
  t10 prove-to-dir (exit 0): r0-model token 24, generic token 116, 19,026,480
  B each, prove 3.68 / 3.93 s; t11 fresh-process verify (exit 0): both
  accepted (0.74 / 0.71 s), one-bit change refused; `crosscheck_r0.py runs`:
  ALL AGREE (24, 116) [MEASURED, shared box, n=1]. `runs/r0-model`,
  `runs/generic` now hold the final-code receipts.
- controls table regenerated from the final-code run t7 (`logs/controls.md`
  / `.json`; the t1 table kept as `controls_t1.*`): **56 lines, 55 AS
  PREDICTED, 0 not as predicted, 1 N/A (hidden-length rows)** = R1's 49 +
  R2-1..R2-7.
- 01:40 **s3-suite RESULT (exit 0) on the final tree: 29 targets, 708
  passed, 0 failed, 33 ignored** (lib 563 / 33; every integration target
  and doc-test ok, so the frozen toy pins, archived receipts and slot-IR
  digests are unchanged). Against s2 (698 / 31): +6 TR tests, +4 R2 unit
  tests, +2 ignored (the R2 run pair). Guard: ran 918 s, peak RSS 4.47 GiB.
  Final source = `manifest_final.sha256` (1ef25c3c..., = stage C2); vs the
  frozen BASELINE: changed private_block.rs, run.rs, run_capture.rs (list),
  s24 / s25 / s33 / hash_domain tests; added the seven token_io files.
  Nothing launched by this lane is pending.

## R3 plan (01:46; Llama-3-8B, T32, 32 blocks, mode (i), public row) — COORDINATOR ~01:42

Coordinator: R2 accepted (first trained next-token proof); an independent
review of R2 + the TR fixes runs on a frozen copy; build R3 test-first with
a GENERIC honest 8B witness, the V_pad 2^17 multi-row controls, counted
layout = counter, fresh-process verify under a 95-bit policy; wire the
loader to R2's table format for the trained tables the calibration lane
will deliver; stay inside the budget so the privacy gate's 6 GiB passes can
run beside this lane; report at the generic 8B proof or any blocker.

1. **Counter figures, written before the construction** (`counts/
   r3_counts.py` -> `r3_counts.json`, the design counter's own formulas,
   per-row head, stages at 2^12) [COUNTED]:
   * stage IN: A 41 / H 76 / M 12 rows, 479,232 elements, sites A 3 / H 3,
     4 slots; counter receipt 1,415,040 B; m and h_tab span 32 rows (Voc
     2^17);
   * stage OUT: A 374 / H 302 / M 26 rows, 2,768,896 elements, sites A 49 /
     H 13, 11 slots, 970,752 byte lookups; counter receipt 3,222,400 B;
   * keyed window 56 bits, 7 byte limbs, 8 vocabulary planes, 4 VZC
     helpers (TF-4); no-wrap 2^56 + 2^56 < p;
   * token endpoints 256 words / 6 rows (2^8 rate 1/8); BOS 128,000 (< V,
     the per-profile constant of D25 T8 / N-2);
   * final norm at d 4,096: D_max = isqrt(Ceps + 4096 * 32768^2) has 22 bits,
     so the window is exactly 32 only at tn = 9 (the 8B export's block tn);
   * block side (counter: 8B T32 row width 2^13): the native 32-block stack
     receipt 465,815,776 B; with token I/O about +4.6 MB.
2. **Fold cost [COUNTED / MODEL]:** the embedding fold (stage IN, prover and
   verifier) and the head fold (stage OUT, both) each touch V x d =
   525,336,576 weights once per run; R2's serial folds (65.5 M each) are made
   parallel (rayon over embedding rows; per-thread partial head columns
   summed), with an equality test against the serial form. MODEL: ~1-3 s
   each serial at 8B, well under 1 s on 16 threads.
3. **Memory [MODEL until measured]:** the int16 embedding 1.05 GB + int8
   head 0.53 GB + multipliers 1 MB resident in prover and verifier; 32 8B
   blocks (~0.24 GB each, 7.8 GB) CANNOT be resident -> **block streaming**:
   a `TokenBlocks` source (resident slice for R1/R2, one-block reload for
   R3), each block checked against the shape (CS-1/CS-4) and the statement's
   digest (CS-6) at its own stage before anything of it is absorbed; the
   witness source receives the stage's block. Native 8B T32 stack: 1.9-2.04
   GiB peak streaming. Expected R3 prover peak ~3.6-4 GiB; first run need 5 /
   cap 6.5 GiB, then re-declared from the measurement (target <= 5.5 so a
   6 GiB privacy-gate pass fits beside it in the 11.9 GiB budget). Tables are
   read in chunks (no 2x transient), SHA-256 streamed. Unit tests that need
   8B-sized tables share ONE lazily built copy per test process.
4. **The generic 8B witness:** the trained 8B T32 export's 32 blocks
   (streamed, SHA-checked loader, digest-checked reloads), prompt seq ho00
   (BOS 128000); a GENERIC dense int16 embedding (seeded, distinct rows)
   whose rows at the prompt's ids are planted with the export's x_in_L00 rows
   (so B_in = x_in_L00, the trained blocks see their real inputs, parity at
   all 32 layers); a generic dense per-row int8 head with multipliers over
   [1, 2^12]; final norm g0 127, tn 9, Ceps 78,617 (the export's block Ceps
   as stand-in), Cn 512 = refusal-free (g0 Cn = 127 * 2^tn). The planted rows
   and their ids are written to the run directory as part of the generic
   table's PUBLIC definition, so the fresh verifier rebuilds the table
   without reading seq_* data (consequence: this generic fixture does not
   hide the prompt ids; it is not a privacy run). Independent reference
   token in-test and in Python. When the calibration lane's trained tables
   land (R2's format: `embedding_int16.bin` [V, d] int16 LE,
   `head_int8_perrow.bin` [V, d] int8, `head_mult12.bin` [V] int64 LE, with
   SHA-256 in a manifest), the same harness runs the trained 8B
   next-token proof with their final-norm constants.
5. **New profile (D17):** `hashline-zk-mr1/private-token-io-run-llama-3-8b-
   t32-trained-statement-public-row/1` (or a variant), its length chosen so
   the transcript constructor collides with no hash-input length and sits
   one byte from none (checked against the full census printout before the
   build); CS-7 arm `Shape::llama3_8b_t32_trained(cal, f_e)`; in
   TOKEN_IO_RUN_PROFILES and registered_token_runs (census at L = 32).
6. **Tests (written first):** R3 counted layout = r3_counts.json (+ the
   derived whole-run figure >= 95); the V_pad 2^17 multi-row honest run and
   controls on the cheap fixture (rung-TC blocks, V = 128,256, BOS 128,000:
   32-row vocabulary planes; the R2 controls moved to the LAST row and to pad
   entries above V); streaming: a streamed run proves and verifies, a stream
   handing another block at stage k is refused by name (CS-6) on both sides;
   the parallel folds equal the serial ones; the table loader round-trips a
   small written set and refuses a wrong SHA; the R3 statement is refused
   (CS-7) until the profile is registered (the failing-first point for every
   R3-profile test); the ignored generic 8B pair (prove to dir, fresh verify
   under 95 bits). Failing-first run with the profile unregistered, then the
   registration.
7. **Acceptance:** the generic 8B run proves and verifies in a fresh process
   under a 95-bit policy; the decommitted token = the in-test reference = the
   Python reference; counted layout = counter; existing pins and every census
   green; no privacy figure.
- 01:47 counter figures written (`counts/r3_counts.py` -> `r3_counts.json`)
  before any R3 code: as in the plan above (A 41 / H 76 / M 12 and A 374 /
  H 302 / M 26, 970,752 byte lookups, window 56, 7 limbs; counter receipts
  1,415,040 B / 3,222,400 B; tables 1,050,673,152 B + 525,336,576 B; folds
  525,336,576 weights each). (Process note: one `sed -i` on my own new
  counter script slipped in at 01:47; not repeated.)
- 01:53 STAGE R3-A in the working copy (`manifest_r3A.sha256`, 432059df...):
  * streaming: `TokenBlocks` (+ `ResidentBlocks`), `prove_token_run_with` /
    `verify_token_run_with`; CS-1 / CS-4 / CS-6 per stage before the stage
    absorbs; `TokenRunSource::witness(k, blk)` receives the stage's block;
    the slice forms delegate (R1 / R2 unchanged in behaviour);
  * parallel `emb_fold`, `head_fold`, `logits` (rayon) with the serial
    forms kept as test references;
  * `RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32` =
    `hashline-zk-mr1/private-token-io-run-llama-3-8b-t32-trained-statement-
    public-row/1` (82 chars, constructor 94 B: no kind of that length and
    none within a byte in the census printout) — defined, NOT yet
    registered (CS-7 refuses it: the failing-first point);
  * tests.rs: per-profile census tables built once per process (OnceLock;
    the 8B pair 1.58 GB shared by the census and the R3 tests); census
    statements from ONE block and cloned records (no block clones: R2's
    census had been cloning 22 TinyLlama blocks, 1.25 GB, needlessly);
    `hashed_tables` (each word a hash of its index: parallel, and
    re-derivable in numpy); R3 constants (BOS 128,000; generic final norm g0
    127 / tn 9 / Ceps 78,617 / Cn 512 refusal-free; the export's block
    calibration);
  * `token_io/r3_tests.rs`: counted layout = r3_counts.json (+ whole run >=
    95, + the R3 statement: CS-7), the V_pad 2^17 honest run and controls
    R3-1..R3-8 (last row, pads above V, Llama-3 BOS), streaming + CS-6 on
    both sides, parallel = serial folds, the R2-format table loader
    (round trip, wrong SHA, wrong size), and the ignored R3 run pair
    (export blocks streamed, generic or trained tables, endpoints sealed
    from the export's words, parity per layer in the proving pass).
  Launched `t12-r3-failfirst` (guarded cpu 5 / 7: `-- token_io`).
  Expected: `r3_the_counted_layout_is_the_counters` FAILS at CS-7; the
  rest pass (the V_pad 2^17 controls are new controls on R2's layout code).
- 02:23 t12-r3-failfirst RESULT (exit 101), as predicted: 25 passed, **1
  FAILED** = `r3_the_counted_layout_is_the_counters` at ruling CS-7 (the R3
  profile is not registered); its layout asserts BEFORE the statement all
  held (8B counted layout = the counter). Passed [MEASURED, shared box,
  n=1]: the V_pad 2^17 honest run (V 128,256, BOS 128,000, 32-row
  vocabulary planes; stage IN A 41 / H 76, stage OUT A 374 / H 302 rows =
  the 8B counter's stage rows, since d_pad 512 lifts to the row width too;
  prove 5.59 s, receipt 20,252,512 B, token 88603 = reference) and controls
  R3-1..R3-8 ALL AS PREDICTED; streaming (CS-6 refused by name at stage 0
  on both sides; one load per stage); parallel folds = serial; the loader
  (round trip, wrong SHA, wrong size). Guard: waited 1,497 s (the lock and
  the budget: a 6 GiB privacy-gate job), ran 269 s, peak RSS 2.69 GiB.
- 02:24 STAGE R3-B: the profile registered (`tools/r3b_register.py`: CS-7
  arm `Shape::llama3_8b_t32_trained(cal, f_e)`, TOKEN_IO_RUN_PROFILES [3],
  registered_token_runs + the 8B entry; `manifest_r3B.sha256` b6df55fb...).
  Launched `t13-r3-built` (token_io + every census, --nocapture).
- 02:45 t13-r3-built RESULT (exit 101): 80 passed, **1 failed**: s25 W-8's
  "each prover constructs exactly one generator" still looked for the
  generator in `prove_token_run`, which now delegates to
  `prove_token_run_with` (the streaming form, where the ONE generator is
  made: the native lane's `prove_run` -> `prove_run_with` precedent). Fixed
  by pointing the census at `prove_token_run_with` (same assertions; the
  per-file generator-site census still bounds the file); not weakened.
  Everything else green, incl. **R3 counted layout = the counter** and the
  R3 statement under the registered profile [COUNTED]:
  * whole run (L = 32): 137 openings, column 2^-98.04, LogUp 2^-99.45,
    total 2^-97.58, **floor 97 bits**;
  * segments (the code's counted lengths): stage IN 1,415,192 B (counter
    1,415,040: +152 B, TF-2's slot rounds), 32 blocks x 14,547,080 B, stage
    OUT 4,363,320 B (counter 3,222,400), **total 471,285,072 B**.
  * **Design finding TF-6 (counter vs code receipt, stage OUT +1.14 MB):**
    the layout is identical (rows, sites, elements); the counter's stage-OUT
    receipt leaves out B_out's ONE opening, which the run carries in stage
    OUT (D12a: the second site's stage opens the boundary; 8B boundary at
    2^13: ~0.58 MB), and it counts fewer A opening groups than the code's 18
    distinct column keys (A opening ~2.2 MB at 374 rows). Note for the
    design lane; the code's counted lengths are what the wire enforces.
- 02:48 launched `tools/r3_chain.sh` (detached): t13b (the same census
  run, `manifest_r3B2.sha256` 10ce52c1...) and, only if green, the GENERIC
  8B run: t14 prove-to-dir (need 4.5 / cap 6.5 GiB) -> t15 fresh verify.
- 03:08 **t13b-r3-built RESULT (exit 0): 81 passed, 0 failed, 6 ignored**
  (token_io incl. r3_tests, every census incl. the 8B token profile at
  L = 32). Guard: waited 1,078 s, ran 261 s, peak RSS 3.10 GiB (the shared
  1.58 GB 8B tables + the V_pad 2^17 fixture).
- 03:14 **t14-r3-prove RESULT (exit 0): THE FIRST GENERIC Llama-3-8B
  NEXT-TOKEN PROOF** [MEASURED, shared box, n=1; a 6 GiB privacy-gate job
  live throughout]. The trained 8B T32 export's 32 blocks STREAMED one at a
  time (reloaded at their stage, digest-checked: CS-6), prompt seq ho00
  (BOS 128,000), the GENERIC hashed tables (int16 embedding with the
  prompt's rows planted from the export's x_in_L00, per-row int8 head with
  12-bit multipliers), final norm g0 127 / tn 9 / Ceps 78,617 / Cn 512, tier
  R1_MVP, profile `...llama-3-8b-t32-trained-statement-public-row/1`: the
  output owner's check returns **next token 75883 = the in-test reference**
  (top-2 logit margin 38,566,990); B_in = x_in_L00; parity bit-exact at all
  32 layers inside the proving pass. Receipt **471,285,072 B in 34 segments**
  (= the counted lengths: stage IN 1,415,192; 32 x 14,547,080; stage OUT
  4,363,320). **Prove 188.7 s** (witness rebuilds 18.2 s, block reloads
  16.3 s), digest pass 20.3 s, tables 0.5 s, total 229.2 s; **peak RSS
  3.39 GiB** (cgroup high-water 6.5 GiB incl. page cache of the 6.6 GB
  export; declared need 4.5 / cap 6.5 held). Whole run (as then counted)
  2^-97.58, floor 97. Evidence `runs/r3/generic-ho00/` (34 segments,
  statement.txt, crosscheck.json, generic_planted_rows.bin = the generic
  table's public definition).
- 03:14 **t15-r3-verify RESULT (exit 0): the generic 8B receipt verifies in
  a FRESH process** (every public input rebuilt from the export's public
  files, the tables re-derived from their definition + the planted rows,
  the blocks streamed; no seq_* data) **under a 95-bit policy**: accepted in
  47.0 s (block reloads 15.4 s), digest pass 19.8 s; a one-bit change
  refused; peak RSS 2.93 GiB [MEASURED, shared box, n=1].
- ~03:17 session stopped (usage limit); resumed 04:21. Working copy =
  `manifest_r3B2.sha256` exactly (re-checked 04:23: the tree t13b / t14 /
  t15 ran on; no partial edit; `model_at` / `census_statement` were
  completed and tested in R3-A/B). The review round-2 edits of 03:08-03:14
  live in `wip-r3c/` (uncompiled; synced and tested next).
- 04:24 `tools/crosscheck_r3.py runs/r3` (R0's own functions; the generic
  head RE-DERIVED in numpy from the hash definition, the export's x_out_L31
  row 31): **75883, AGREES** with the decommitted id; D = 64,474, max |y| 7
  (no D20 refusal on ho00 at the refusal-free Cn 512).

## Review round 2 (REVIEW2.md, coordinator ~03:05): folded into R3 as STAGE R3-C (04:25)

TR-1..TR-5 closed by the reviewer; R2 sound as built. The conditions and
the small items, each in the working copy (`manifest_r3C.sha256`,
c6f2cba0...; vs R3-B2: s25_tests, token_io.rs, run.rs, stage_out.rs,
tests.rs, r2_tests.rs, r3_tests.rs):
* STREAMING blocks: done in R3-A (`TokenBlocks`, one block resident,
  CS-1/4/6 at each stage before it absorbs; the 8B run at 3.39 GiB RSS).
* V_pad = 2^17 at the door's edge: new test `r3_v_pad_2_17_is_the_doors_edge`
  (V = 2^17 admitted with 32-row planes; V = 2^17 + 1 refused by name).
* BOS 128,000 per profile: R3's constant, the control R3-8, the R3 run.
* The new profile string through s25: done in R3-B (t13b green at L = 32);
  the new profile TEXT (R2-6) goes through the same census in t16.
* Own controls on the 32-row planes: R3-1..R3-8 (t12/t13b, all as
  predicted).
* **R2-1 (before any 8B figure is quoted):** the PCS-field and sumcheck
  terms are now bounded EXPLICITLY inside the total before the floor:
  `openings x 2^-113 + (L + 2) x 2^-117.2` (MEMO_G02's per-unit figures at
  its largest geometry, 8B T512 row width 2^15, which every registered token
  run is at or below), carried as `WholeRun::omitted_log2`; the R3 counted
  test asserts the bound is in the total and the floor holds. The 8B
  figure quoted below is the one WITH the bound.
* R2-2: stage IN's embedding lookup gets its own term `(N + R (2 + log2
  d_pad) + T log2 d_pad) / |F_p^2|` (a compressed-row collision has degree
  1 + log2 d_pad in (beta, r_emb), plus the B_in binding term).
* R2-3: `TokenRunStatement::whole_run` is private, read through
  `whole_run()`; the constructor is the only source.
* R2-4: `Tier::R1_MVP`'s doc states that "95" is D27's target at the named
  workload and that the statement's derived figure is what binds; the new
  profile's text says so in the transcript.
* R2-5: the run prover asks for the stage-OUT witness FIRST and runs its
  byte-lookup refusal before stage IN, so a refused witness publishes
  nothing (new control `r3_a_refused_stage_out_witness_emits_no_segment`:
  zero segments reach the sink); the R3 driver removes a refused run's
  directory; the sink contract is documented.
* R2-6: `describe_under(profile)` / `digest_under`: the R1 and R2 profiles
  keep their transcript texts byte for byte (their receipts stay valid);
  every later profile opens with `token-io:`, carries the tier-name note,
  says `two-internal-boundaries` on the block line and names the figure's
  bound. The R3 profile's text therefore moves -> the generic 8B run is
  re-proved (t17) and re-verified (t18) on the final tree.
Launched `tools/r3c_chain.sh` (detached): t16 (token_io + censuses) ->
t17 / t18 (the generic 8B run again) -> s4 (the full suite). The t14 run's
statement and cross-check are kept as `runs/r3-t14-generic-ho00-superseded/`
(segments removed) and `runs/r3/crosscheck_result_t14.json`.
- 04:29 **t16-r3c-built RESULT (exit 0): 83 passed, 0 failed, 6 ignored**
  (token_io incl. the two new controls, every census incl. the R3 profile's
  new text). The R1 / R2 floors are unchanged by the bound (93 / 97). **The
  8B figure, with the R2-1 bound in the total [COUNTED]:** 137 openings,
  column 2^-98.04, LogUp (R2-2 term included) 2^-99.44, PCS-field + sumcheck
  bound 2^-105.88, **total 2^-97.58, floor 97 bits**. The chain continues:
  t17 (generic 8B prove, the final text) -> t18 (fresh verify) -> s4.
- 04:34 **t17-r3-prove RESULT (exit 0): THE GENERIC Llama-3-8B NEXT-TOKEN
  PROOF ON THE FINAL TREE** (R3-C: the profile text with the R2-1 bound and
  the R2-6 wording) [MEASURED, shared box, n=1]: next token **75883** =
  the in-test reference (margin 38,566,990), receipt 471,285,072 B in 34
  segments (= the counted lengths), **prove 182.0 s** (witness 17.6 s, block
  reloads 15.8 s), digest pass 20.5 s, tables 0.5 s, total 219.5 s, **peak
  RSS 3.40 GiB** (cgroup 6.5 incl. the export's page cache), parity at all
  32 layers; the statement's parameter line now reads `whole-run-floor-97-
  bits-137-openings-column-plus-logup-derived-plus-pcs-field-and-sumcheck-
  bound` and `two-internal-boundaries`. Evidence `runs/r3/generic-ho00/`.
- 04:34 **t18-r3-verify RESULT (exit 0): verifies in a FRESH process under
  a 95-bit policy** in 44.6 s (block reloads 15.0 s; digest pass 18.8 s),
  peak RSS 2.94 GiB; a one-bit change refused [MEASURED, shared box, n=1].
- 04:36 cross-check of the re-proved run: `tools/crosscheck_r3.py` cannot
  run at this minute because the DESIGN lane's R0 reference
  (`results/zk60_token_io_design_20261017/r0/token_io_ref.py`, read-only
  for this lane) is mid-edit (a syntax error at its line 45, the keyed
  window formula); not mine to touch. The t17 run's `crosscheck.json` and
  `generic_planted_rows.bin` are byte-identical to t14's (same seq, same
  table definition, same token 75883), so the 04:24 cross-check result
  (`runs/r3/crosscheck_result_t14.json`: 75883, ALL AGREE) applies to it
  verbatim; the script is re-run when the reference file is whole again.
- 10-18 04:47 **s4-suite RESULT (exit 0) on the R3-C tree: 29 targets, 716
  passed, 0 failed, 35 ignored** (lib 571 / 35; every integration target
  and doc-test ok: the frozen toy pins, archived receipts and slot-IR digests
  unchanged). Against s3 (708 / 33): +8 run (R3 unit tests incl. the two
  round-2 controls), +2 ignored (the R3 run pair). Guard 736 s, peak RSS 6.21
  GiB (the suite now holds the shared 1.58 GB 8B tables for its census and
  R3 tests). Final source `manifest_final_r3.sha256` (c6f2cba0... = R3-C).
  Controls table regenerated from t16 (`logs/controls.md` / `.json`): **64
  lines, 63 as predicted, 0 elsewhere, 1 N/A** (R1's 49 + R2-1..7 + R3-1..8).
  The R0 reference file is whole again (it parses; edited by the design lane
  at 04:34 UTC).
- 10-18 ~04:50 usage limit; the box rebooted 10-18 21:29 (/tmp wiped,
  nothing of this lane running or lost: every artifact is under results/).

## 10-19 09:25 COORDINATOR: the trained Llama-3-8B next-token proof

The calibration lane's trained 8B token-I/O artifacts are ready
(`export/llama3_8b_pg_rot1_b7_T32/token_io/`: embedding 8b5a5fb1..., per-row
head f50ba1aa..., multipliers 9eafb7f4... in [859, 4096], final norm g0 127
/ tn 9 / Ceps 78,617 / **Cn 4,234 calibrated**; F2 met). Run the TRAINED 8B
proof on the b7 T32 export: real tables, calibrated final norm, BOS 128000,
cross-checked against the lane's integer and float heads, fresh verify at 95
bits, the R3 controls, counted lengths.

- 09:40 **BLOCKER FOUND AND ITS FIX PLANNED (no run yet):** the b7 export
  names `sh_s` PER LAYER (`per_layer_constants_differ` includes `sh_s`;
  layer 1 at 7, the other 31 at 6). This tree's loader (the R5 frozen base)
  refuses it ("one calibration per run"). The native lane's R6 (frozen
  2026-10-18 02:36, reviewed round r6 and ACCEPTED on soundness and the
  per-layer sh_s) supports it: `LayerRecord::sh_s` (bound by the trained
  identity only when present), `Shape::with_score_shift`, the run base =
  the mode, and each stage proved at `RunStatement::stage_shape(k)`.
  Plan: (1) REBASE this lane's tree onto the R6 frozen tree: R6 changed 18
  files vs this tree's R5 base, this lane changed 7 and added 8; only 4 are
  changed by both (`private_block.rs`, `run.rs`, `run_capture.rs`,
  `s24_tests.rs`) -> 3-way merge of exactly those (base = R5 frozen),
  R6's version of its other 14, this lane's version of its own; snapshot
  of the R3-C sources kept in `snap-r3c/`. (2) The token run gets R6's
  per-stage shapes: `TokenRunStatement::stage_shape(k)` from the trained
  statement's layer records (validated through `with_score_shift`), each
  block stage's layout, prover, verifier and witness at its stage shape,
  and the stage line naming a layer's own score shift (so it enters the
  schedule digest; runs without one are byte-unchanged). (3) Tests first: a
  per-layer sh_s token run (rung-TC blocks, one stage at another score
  shift) proves and verifies, a verifier at the run-wide shift for that
  stage refuses; R1 / R2 / R3-generic statements byte-unchanged. (4) Then
  the trained 8B run.
- 09:29 **STAGE R3-D: REBASED ON THE NATIVE R6 TREE** (working copy =
  `manifest_r3D.sha256`, 67327e11...): R6's version of its 14 own files
  (incl. `r6_tests.rs`, `ladder8b_tests.rs`, the trained loader with
  per-layer sh_s, `Shape::with_score_shift`, `LayerRecord::sh_s`); a 3-way
  merge (base = the R5 frozen tree) of the 4 shared files: `private_block.rs`,
  `run.rs`, `s24_tests.rs` clean, `run_capture.rs` with one conflict
  resolved as the UNION of both pin lists (`OWN_SOURCE_FILES` [21] = R5's 16
  + this lane's 4 token_io files + R6's `trained_block.rs`). Against the R6
  frozen tree the working copy now differs in exactly this lane's 7 changed
  and 8 added files. Merge products kept in `snap-merge/`, the R3-C
  sources in `snap-r3c/`.
- 09:29 per-stage score shifts in the token run (NATIVE R6 ported):
  `TokenRunStatement::stage_shape(k)` from the trained statement's layer
  records (each own sh_s validated through `with_score_shift`); block
  stage k's layout, CS-1/CS-4 check, prover (`prove_core`), verifier
  (`verify_core`) and witness (`TokenRunSource::witness(k, blk, sh)` now
  hands the stage shape) at that shape; the stage line names a layer's
  own shift (so the schedule digest binds it; runs without one are
  byte-unchanged); `honest_pipeline_at` / `downstream_at` build each block
  at its stage shape. New test `r3_a_layer_with_its_own_score_shift_is_
  proved_at_its_stage_shape` (rung blocks, layer 1 at another shift: the
  shift moves block 1's output; the run proves and verifies; controls R3-9
  receipt under the run-wide statement -> Binding, R3-10 block 1 witnessed
  at the run-wide shift under the per-layer statement (cheating prover) ->
  Block). (Not failing-first in the strict sense: the API did not exist
  before; its two controls are the refusals that must hold.)
- 09:30 launched `tools/r3d_chain.sh` (detached): t19 (token_io + every
  census + R6's r6_tests / trained_stack / trained_block / trained_statement)
  -> if green: **t20 the TRAINED 8B prove** (b7 T32 export; trained tables
  from `token_io/`; Cn 4,234 calibrated from `head_manifest.json`; need 4.5
  / cap 6.5) -> t21 fresh verify at 95 bits -> s5 full suite.
- 09:50 **t19-r3d-built RESULT (exit 0): 98 passed, 0 failed, 7 ignored** on
  the rebased tree (token_io incl. the per-layer score-shift test, every
  census, and R6's own r6_tests / trained_stack / trained_block /
  trained_statement). The trained 8B prove (t20) is starting.
- 10:05 **t20-r3-trained-prove RESULT (exit 0): THE TRAINED Llama-3-8B
  NEXT-TOKEN PROOF** [MEASURED, shared box, n=1]. Export
  `llama3_8b_pg_rot1_b7_T32` (32 trained blocks streamed one at a time,
  layer 1 at its own score shift 7 per the export, the others at 6);
  prompt seq ho00 (BOS 128,000); the calibration lane's TRAINED tables
  (embedding 8b5a5fb1..., per-row int8 head f50ba1aa..., multipliers
  9eafb7f4..., each SHA-256-checked by the streaming loader); final norm
  g0 127 / tn 9 / Ceps 78,617 / **Cn 4,234 (calibrated)**; tier R1_MVP; the
  R3 profile. B_in = the export's x_in_L00 (the trained embedding rows);
  parity bit-exact at all 32 layers inside the proving pass. The output
  owner's check returns **next token 11 = the in-test reference** (top-2
  margin of the scaled logits 146,646,590; D 64,004). Receipt **471,285,072
  B in 34 segments** (= the counted lengths). **Prove 191.7 s** (witness
  17.3 s, block reloads 14.3 s; block stages 5.2-6.3 s each), digest pass
  18.4 s, tables 1.8 s, total 230.5 s; **peak RSS 3.44 GiB** (cgroup 6.5 incl.
  page cache; need 4.5 / cap 6.5). Whole run [COUNTED, with the R2-1 bound]:
  floor 97 bits. Trained-statement identity 47f01943...; evidence
  `runs/r3/trained-ho00/`. The fresh verify (t21) runs next in the chain;
  the cross-check against the calibration lane's integer and float heads
  (`tools/crosscheck_r3_trained.py`, the lane's own `final_norm`,
  `int_logits`, `float_head` + R0's reference) is queued as a light job.
- 10:07 **x3 cross-check RESULT (exit 0): ALL FOUR AGREE ON 11.** The
  decommitted next token 11 = the calibration lane's INTEGER head (its own
  `final_norm` at Cn 4,234 + `int_logits` + per-row multipliers) = R0's
  reference (`final_norm` equal to the lane's, word for word; first
  maximum) = the lane's FLOAT head (TOKEN_IO_SPEC float path on the same
  row: s_out, inverse rotation, float32 RMSNorm with the checkpoint's norm
  weight, the checkpoint's bf16 lm_head), float top-2 margin **4.40
  logits** (well above D25 T4's 0.3); max |y| 61 (no D20 refusal at the
  calibrated Cn). `runs/r3/crosscheck_trained_result.json`, log
  `logs/x3-trained-crosscheck.*` (light guard).
- 10:07 **t21-r3-trained-verify RESULT (exit 0): the trained 8B receipt
  verifies in a FRESH process under a 95-bit policy** (every public input
  from the export's public files and the trained table files, the blocks
  streamed and digest-checked, no seq_* data): accepted in 43.4 s (block
  reloads 14.0 s), digest pass 17.7 s, tables 1.6 s; a one-bit change
  refused; peak RSS 2.96 GiB [MEASURED, shared box, n=1].
- Evidence that layer 1 was proved at ITS OWN score shift (7): the witness
  is built at the stage shape, and the proving pass checked every block's
  output against the export's x_out_Lk bit for bit; the export computed
  layer 1 with sh_s 7, so a witness at the run-wide 6 would have failed
  parity at layer 1 (as control R3-10 shows a verifier refusing exactly
  that case at slot 17).
- s5 (the full suite on the rebased tree) is still running in the chain.

## REPORT (10-19 10:10 UTC): TOKEN I/O R3, the trained Llama-3-8B next-token proof

**What was proved.** One private run under one transcript: stage IN (the
hidden prompt's 32 token ids -> the hidden embedded input through the
public int16 embedding table, BOS 128,000 forced), the 32 trained
Llama-3-8B blocks at T32 (the calibration lane's `llama3_8b_pg_rot1_b7_T32`
export, layer 1 at its own score shift), stage OUT (the final RMSNorm with a
uniform gain at the calibrated Cn 4,234, the raw-integer logits through the
public per-row int8 head with 12-bit multipliers, the keyed greedy argmax
over V = 128,256 padded to 2^17, numpy's first maximum), the hidden next
token sealed in the output token endpoint. The output owner's check returns
token 11; the calibration lane's integer head, R0's reference and the
lane's float head all give 11 (float margin 4.40 logits).

**Figures [MEASURED, shared box, n=1].** Prove 191.7 s (32 block stages
5.2-6.3 s each; stage IN 0.47 s; stage OUT about 1 s; witness rebuilds
17.3 s and block reloads 14.3 s inside it), digest pass 18.4 s, peak RSS
3.44 GiB with ONE block resident (streaming); fresh-process verify 43.4 s
(blocks reloaded 14.0 s), peak 2.96 GiB. Receipt 471,285,072 B in 34
segments, each equal to its counted length (stage IN 1,415,192; 32 blocks
x 14,547,080; stage OUT 4,363,320). [COUNTED] The derived whole-run figure
of the statement, with the PCS-field and sumcheck terms bounded explicitly
(review R2-1): column 2^-98.04, LogUp 2^-99.44 (stage IN's term per R2-2),
bound 2^-105.88, total 2^-97.58, **floor 97 bits** (the verifier's policy
was 95, D27's MVP level). The counted layout equals the design counter
(stage IN A 41 / H 76 / M 12; stage OUT A 374 / H 302 / M 26; window 56
bits, 7 limbs); the counter's stage-OUT receipt differs by B_out's opening
and the A-group count (TF-6, for the design lane).

**What carried it there (this lane, R3).** Block streaming (TokenBlocks:
one block resident, CS-1/4/6 at each stage before it absorbs; 32 resident
8B blocks would be 7.8 GB); parallel embedding and head folds (525 M
weights each, equal to the serial forms); the R2-format table loader
(chunked, SHA-256 streamed); the R3 profile string (chosen through the s25
length census); the rebase onto the native R6 tree for the per-layer score
shift, ported into the token run (per-stage shapes); the review round-2
items R2-1..R2-6.

**Controls.** 66 control lines across R1-R3, 65 refused where predicted,
0 elsewhere, 1 N/A (the hidden-length rows): R1's 49, R2-1..R2-7 on two-row
planes, R3-1..R3-8 on the LAST row of 32-row planes and pads above V plus
the Llama-3 BOS, R3-9 / R3-10 for the per-layer score shift; the round-2
controls (a refused stage-OUT witness emits zero segments; V = 2^17 admitted,
2^17 + 1 refused); streaming CS-6 on both sides.

**Earlier in this lane.** R1 (rung TC, V 300) and R2 (TinyLlama-1.1B, 22
blocks: token 29914, 255 MB, 85 s) as reported 10-18; the generic 8B run of
R3 (token 75883, the same counted receipt, 182 s) before the trained tables
existed.

**Not claimed.** No privacy figure (the G-1..G-7 rank / CFS gates on the
new stages are owed; TR-6 is a listed exception); the public-row variant
only (D26's hidden-length variant is the next rung); one sequence (ho00);
a shared box, n = 1.
- 10:16 **s5-suite RESULT (exit 0) on the rebased R3-D tree: 29 targets,
  729 passed, 0 failed, 37 ignored** (lib 584 / 37; every integration target
  and doc-test ok). Against the native R6 suite (r6-suite1: 700 / 0 / 31) the
  difference is exactly this lane's 29 run tests and 6 env-gated ignored
  ones (the R1, R2, R3 prove/verify pairs). Guard 567 s, peak RSS 6.18 GiB.
  Final source `manifest_final_r3d.sha256` (= R3-D, 67327e11...). Controls
  table regenerated from t19: **66 lines, 65 as predicted, 0 elsewhere, 1
  N/A**. Nothing launched by this lane is pending.

## Round 4 (coordinator 10:5x): review round 3 ACCEPTED R3; TR3-1..TR3-3 + a CLI

REVIEW3.md: R3 accepted as the trained Llama-3-8B next-token result. This
round (small, test-first, in this tree): TR3-1 (a mid-run refusal must leave
nothing in the sink: hold stage IN's segment, or pre-check every block's
CS-6 digest before the first segment); TR3-2 (the 8B table loader and the
streaming block source into the production module, real JSON parse of the
manifests, bounded reads, a truncated manifest refused by name, tests);
TR3-3 (a local assertion that each layer record's digest is its block's);
then a CLI (prove-to-dir / verify-from-dir with native R7's publication
rules: the verifier writes the statement, the backend allow-list).

- 11:00 plan:
  * adopt the native R7 freeze's two changed files (`trained_block.rs`,
    `trained_stack_tests.rs`: N-r6-b stale-writer cleanup and the Q-2
    backend allow-list), unchanged here, so this tree = R7 + this lane's
    15 files (checked: exactly those differ from `r7/frozen-tree/`);
  * TR3-1: the run prover checks every block (CS-1 / CS-4 / CS-6, the
    stage shape) BEFORE stage IN, in addition to the per-stage check
    (the defence against a block changing between the two); the CLI's
    sink writes `run.incomplete/` and renames it to `run/` only after Ok
    (on Err the directory is removed), so no refusal of any kind leaves
    segments behind; the sink contract documented;
  * TR3-2: `token_io/load.rs` (production): manifests through
    `run::read_regular_file_bounded` (regular file, bounded, no link
    followed) and `trained_block::parse_json` (strict); data files with the
    metadata-length check, exact chunked reads, streamed SHA-256; the export
    block source (`reload_block` + digest check) moved out of the tests;
  * TR3-3: `layers[k].block_digest == block_digests[k]` asserted where the
    shift is read (defensive: `check_against` already aligns them, so the
    refusal is not reachable from outside; noted);
  * CLI `token_io/cli.rs` + `examples/zk60_token_io.rs`: `prove`
    (prover-private prompt and hidden activations from the export's seq_*
    or a private dir; endpoints sealed from the export's words; parity per
    layer; segments into `<out>/run/`; an UNVERIFIED statement beside it;
    the owners' decommitments into a private dir), `verify` (refuses an
    export holding seq_*; pins the trained identity; rebuilds the statement
    from public files; the prover's statement must be the canonical
    rendering with an allowed backend; verifies; PUBLISHES `<out>/statement/`
    itself from the hashes of the bytes it verified; removes the unverified
    one; a second verify re-checks byte for byte), `owner` (the output
    owner's check against the published statement: prints the token).
- 11:02 T-A (failing first): `tr3_1_a_wrong_block_at_a_later_stage_is_
  refused_before_any_segment` (block 0 handed again at stage 1: must be
  refused with ZERO segments emitted) and `tr3_2_a_truncated_manifest_is_
  refused_by_name` (a head manifest cut inside a digest: must be an Err
  naming the file, not a panic). `manifest_r4A.sha256` (e0398172...).
  Launched `t22-tr3-failfirst`. Expected: both FAIL (2 segments emitted;
  the substring parser panics).
- 11:10 t22-tr3-failfirst RESULT (exit 101), as predicted: **2 FAILED**:
  TR3-1 "segments [0, 1] reached the sink before the refusal"; TR3-2 the
  substring parser panicked ("end byte index 100 is out of bounds") instead
  of refusing the truncated manifest.
- 11:12 STAGE T-B synced (`manifest_r4B.sha256`, 86f5958c...; vs T-A:
  private_block.rs (the CLI re-export), run_capture.rs (load.rs and cli.rs
  pinned: [23]), s25_tests.rs (CALL_SITES [20]: TK7 the loader's streamed
  SHA-256 of the public table files), token_io.rs (modules; decommitment file
  form), token_io/run.rs (TR3-1 pre-check, TR3-3 assertion, the sink
  contract, `context()`), r3_tests.rs (the production loaders; the load
  count 4 with the pre-check), trained_block.rs (VISIBILITY ONLY: `flags`,
  `flag`, `need`, `js`, `refuse_prover_private_entries`, `write_new`,
  `stack_context`, `render_segments_json`, `check_statement_dir`,
  `publish_statement_dir` -> pub(crate), no body changed); added
  `token_io/load.rs`, `token_io/cli.rs`, `token_io/cli_tests.rs`,
  `examples/zk60_token_io.rs`). Launched `t23-r4-built` (token_io + every
  census + trained_stack / trained_block tests, --nocapture).
- 11:15 **t23-r4-built RESULT (exit 0): 98 passed, 0 failed, 7 ignored**
  (token_io, every census, the native trained_stack / trained_block CLI
  tests over the visibility-widened helpers). TR3-1 (refused at stage 1's
  pre-check, **0 segments emitted**) and TR3-2 (the truncated manifest
  refused by name: "head_manifest.json: JSON: unterminated string at byte
  70") now pass; the production loader round trip, wrong digest, short file
  and a LINK in place of a table are refused by name; streaming test with 4
  loads (pre-check + stages). **CLI end to end on the tiny export:** prove
  -> verify (the VERIFIER publishes `<run>/statement/`, the unverified
  statement removed) -> second verify re-checks byte for byte -> owner
  reads token 165 = the reference; refused with nothing published: the
  owner before publication, a verifier handed the export with seq_* (P-5),
  a wrong pin, a tampered segment ("stage OUT A: pcs zk: column index ..."),
  a backend outside the build's names (R7 / Q-2); a prove into an existing
  directory refused.
- 11:16 launched `tools/r4_cli_demo.sh` (detached): build the CLI example
  (guarded build) -> **the 8B CLI demo on the b7 T32 export**: `prove`
  (prover-private seq_ho00) -> `verify` from a VERIFIER COPY of the export
  (public entries hard-linked, no seq_*), pinned to the trained identity the
  R3 harness derived (47f01943...) -> `verify` again (re-check) -> `owner`
  (the output decommitment against the published statement) -> s6 the full
  suite.
- 11:24 **THE 8B NEXT-TOKEN PROOF FROM THE COMMAND LINE** (`cli/`,
  [MEASURED, shared box, n=1]): CLI built from this tree
  (`cli/zk60_token_io.release.bin`, `cli/binaries.sha256`);
  * `prove` (b7 T32 export, prover-private seq_ho00, trained tables, BOS
    128000, Cn 4,234): exit 0, 34 segments / 471,285,072 B (= counted),
    prove 198.1 s (witness 16.8 s, block reloads 26.1 s incl. the TR3-1
    pre-check pass), digest pass ~20 s, total 236.1 s, VmHWM 3,426 MiB,
    parity at 32 layers, whole-run floor 97 bits; segments renamed into
    place after Ok; an UNVERIFIED statement beside the run;
  * `verify` from the VERIFIER COPY (public entries hard-linked, no seq_*),
    pinned to 47f01943... (the R3 harness's independent identity), policy
    95 bits: exit 0, verify 42.7 s (reloads 12.6 s), total 72.8 s, peak 2.78
    GiB; the statement PUBLISHED BY THE VERIFIER (`run-b7_T32-ho00/statement/`:
    statement.json + segments.json of the verified bytes), the unverified
    one removed;
  * `verify` again: `statement-checked` byte for byte, exit 0 (70.4 s);
  * `owner` (output decommitment from `run-b7_T32-ho00.owner-private/`,
    mode 0600, against the published statement): **next token 11**, exit 0
    (29.6 s, 1.77 GiB).
  The full suite (s6) runs next.
- 11:35 **s6-suite RESULT (exit 0) on the round-4 tree: 29 targets, 735
  passed, 0 failed, 37 ignored** (lib 590 / 37; every integration target and
  doc-test ok, pins unchanged). Against s5 (729 / 37): +2 the TR3 tests, +2
  the CLI end-to-end tests, +2 the native R7 tests adopted with its two files
  (N-r6-b, Q-2). Guard 655 s, peak RSS 6.03 GiB. Final source
  `manifest_final_r4.sha256` (= T-B, 86f5958c...; this tree = the native R7
  freeze + this lane's 19 files: 8 changed incl. the visibility-only
  trained_block.rs, 11 added). Nothing launched by this lane is pending.

## REPORT addendum (10-19 11:36 UTC): round 4

* **TR3-1 fixed** (failing first): the run prover checks EVERY block (CS-1 /
  CS-4 / CS-6 at its stage shape) before the first segment, besides the
  per-stage check; a block handed wrongly at stage 1 is refused with zero
  segments emitted. The sink contract is written on `prove_token_run_with`;
  the CLI builds `<out>.incomplete/` and renames it only after Ok.
* **TR3-2 fixed** (failing first): `token_io/load.rs` in production: the
  manifests read bounded from regular files and parsed strictly (a
  truncated manifest refused by name), the tables read with the length check,
  exact chunked reads and a streamed SHA-256 (a link refused), the export's
  public side and the streaming block source (digest check on reload); the
  R3 harness now uses them.
* **TR3-3**: the per-stage shift is read only after the record's digest is
  asserted to be its block's (defensive; `check_against` already aligns).
* **The CLI** `examples/zk60_token_io.rs` (`prove` / `verify` / `owner`)
  with the native R7 rules (the verifier writes the statement from the
  bytes it verified; the backend one of the build's names; a stale writer
  directory cleared or refused; a verifier refuses an export holding seq_*;
  the context label a deployment constant). **The trained 8B next-token proof
  from the command line**: prove 236 s total (3.4 GiB), verify from a
  verifier copy 73 s (2.8 GiB), statement published by the verifier,
  re-checked byte for byte, the owner reads token 11.
* Tests: 735 / 0 / 37 full suite. No privacy claim.

## Round 5 (coordinator ~11:55): review round 4's TR4-1 .. TR4-4 before the CLI demo

REVIEW4.md: prove and verify sound, nothing an audience sees leaks; fix
before a demo: TR4-1 (MEDIUM: `owner` trusted any `statement/` whose writer
line says verify: it printed token 11 over a tampered 8B copy), TR4-2
(MEDIUM: the pin covered only the trained blocks; the tables, BOS and final
norm came from the manifests handed to the verifier), TR4-3 (LOW, D21: the
owners' decommitments in a 0755 sibling directory inside the repo; MOVE the
demo's out of the repo), TR4-4 (INFO: no-follow table opens, owner files
before the final rename, an input-owner check).

- 12:05 T-A (failing first, `manifest_r5A.sha256`): the CLI ACCEPTS the new
  flags as stubs (`--owner-dir`, `--expect-token-profile`, `owner
  --min-bits`; ignored), and three tests: `tr4_1_...` (owner over a run
  flipped after publication; owner over a prover-written statement/: both
  must refuse), `tr4_2_...` (a run with every head multiplier moved, and one
  with half the Cn, verified under the APPROVED token profile's pin: must
  refuse, nothing published), `tr4_3_...` (decommitments in the given owner
  directory, 0700, none beside the run; an owner directory inside the run's
  parent refused). Launched `t24-tr4-failfirst` (`-- token_io::cli_tests`).
  Expected: the three tr4 tests FAIL, the two existing CLI tests pass.
- 12:10 TR4-3 data move DONE: the demo's
  `results/zk60_token_io_r1_20261017/cli/run-b7_T32-ho00.owner-private/`
  (input.dec, output.dec; 0600) MOVED OUT of the repository to
  **`/home/victor/zk60-artifacts/token-io/run-b7_T32-ho00.owner-private/`**
  (directories 0700); no `*owner-private` or `*.dec` remains under this
  lane's results directory (checked with find).
- 12:20 T-B prepared in `wip-r5b/` (not yet synced: t24 is still queued):
  * TR4-1: `check_run` = verify's check path (P-5, both pins, the found
    statement's writer, the canonical rendering, every segment re-read at
    its counted length and VERIFIED under `--min-bits`, and for a published
    statement `segments.json` = the verified bytes' hashes); `verify`,
    `owner` and the new `input-owner` all go through it; `owner` prints the
    token only after it;
  * TR4-2: `--expect-token-profile HEX` required by verify / owner /
    input-owner, compared with the rebuilt statement's token profile digest
    and refused by name; a new `profile` command prints both pins of an
    approved export + table set;
  * TR4-3: `--owner-dir`, default `$HOME/zk60-artifacts/token-io/<run>.
    owner-private`; refused inside the run's parent; created 0700;
  * TR4-4: the owners' files and the unverified statement written BEFORE the
    run is renamed into place (a failure removes all three); table opens with
    `O_NOFOLLOW | O_NONBLOCK`; `input-owner` (the input owner's check with
    its own `--prompt`);
  * `tools/r4_cli_demo.sh` rewritten for round 5 (profile -> prove with the
    default owner directory -> verify with both pins -> re-check -> owner ->
    input-owner -> full suite), run directory `cli/run-b7_T32-ho00-r5`.
- 12:50 t24 is WAITING: it holds the heavy lock while the guard's budget
  (11.9 GiB) is taken by another lane's light jobs (fp-* at 9.5-11 GiB); it
  starts when 4 GiB free up. Not restarted (rules: never restart a queued
  job; never SIGKILL a guard).
- 12:54 t24-tr4-failfirst RESULT (exit 101), as predicted: **3 FAILED**
  (TR4-1 "the owner printed a token over a run whose segment was flipped
  after publication"; TR4-2 "a run with another head verified under the
  approved token profile's pin"; TR4-3 "the decommitments are not in the
  given owner directory"), the two existing CLI tests pass.
- 12:56 STAGE T-B synced (`manifest_r5B.sha256`, 5f7d155e...; vs T-A:
  examples/zk60_token_io.rs, private_block.rs (re-exports `profile`,
  `input-owner`), token_io/cli.rs, cli_tests.rs, load.rs) and launched
  `tools/r5_chain.sh` (detached): t25 (token_io + every census + the native
  trained CLI tests) -> if green, `tools/r4_cli_demo.sh` (round-5 8B demo:
  build -> profile -> prove -> verify -> re-check -> owner -> input-owner ->
  s7 full suite).
- 13:02 **t25-r5-built RESULT (exit 0): 101 passed, 0 failed, 7 ignored**
  (token_io incl. the three TR4 tests and the input-owner / profile lines,
  every census, the native trained CLI tests): TR4-1 (owner over a run
  flipped after publication, and over a prover-written statement/: both
  refused), TR4-2 (another head; half the Cn: refused under the
  token-profile pin, nothing published), TR4-3 (decommitments in the given
  owner directory 0700 / files 0600, none beside the run; an owner directory
  inside the run's parent refused) now pass. The 8B demo chain continues.
- 13:14 **THE ROUND-5 8B CLI DEMO, END TO END** (`tools/r4_cli_demo.sh`,
  `cli/zk60_token_io.r5.release.bin`, `cli/binaries_r5.sha256`) [MEASURED,
  shared box, n=1]:
  * `profile` on the calibration lane's APPROVED export + `token_io/`
    tables: trained identity 47f01943... (= the R3 harness's, checked by the
    script), **token profile digest e8238cf1...** (recorded in
    `cli/token_profile_pin_b7_T32.txt`; V 128,256, BOS 128,000, final norm
    g0 127 / Cn 4,234 / tn 9 / Ceps 78,617, the three table SHA-256s);
  * `prove` (seq_ho00 prover-private; owner directory by DEFAULT
    `/home/victor/zk60-artifacts/token-io/run-b7_T32-ho00-r5.owner-private`,
    0700, files 0600, outside the repository): exit 0, 34 segments /
    471,285,072 B, prove 226.7 s (block reloads 37.0 s incl. the TR3-1
    pre-check), total 266.8 s, VmHWM 3,482 MiB, parity at 32 layers;
  * `verify` from the verifier copy with BOTH pins: exit 0, published by the
    verifier (verify 52.1 s, total 90.3 s, 2.80 GiB);
  * `verify` again: statement-checked, exit 0 (83.8 s);
  * `owner` with both pins (its full re-check of the published statement
    against every segment first): **next token 11**, exit 0 (82.6 s);
  * `input-owner` with the owner's own prompt (the 32 ho00 ids): input
    checked, exit 0 (83.6 s).
  The full suite (s7) runs last in the chain.
- 13:29 **s7 FULL SUITE (exit 0): 738 passed, 0 failed, 37 ignored** over
  29 targets (lib 593 / 0 / 37; s6 was 735 / 0 / 37, +3 TR4 tests), wall
  922 s, peak 6.0 GiB RSS / 6.2 GiB cgroup, no guard wait
  (`logs/s7-suite.log`, `logs/s7-suite.guard.json`). The round-5 chain
  (`logs/r5_chain.done`) is complete.
- 13:35 COORDINATOR ADD-ON (layer-0 refusals): the fidelity lane's
  exhaustive vocabulary scan (`results/zk60_fidelity_parity_20261019/runs/
  llama3-8b/vocab0_llama3_8b_pg_rot1_b7_T128.json`) finds two tokens that
  leave the int8 range at layer 0, site V: " ." (id 662) and "Tags"
  (id 16309). Task: a pre-check in the demo that names the token and
  refuses before proving, with a pointer to the fix (a layer-0
  recalibrated export). Coverage of the demo's b7_T32 export [COUNTED, file
  identity]: embedding_int16.bin is the same inode as T128's; layer_00
  gamma_a / wq / wk / wv / act / exp / gamma_m identical by SHA-256; the
  layer_00 manifests differ only in rope_cos / rope_sin / tables.rope
  (t_max 32 vs 128), and T32's RoPE tables are a byte prefix of T128's
  (positions a subset of the scanned ones). V has no RoPE. So the same two
  tokens refuse on b7_T32. Neither demo prompt (seq_ho00, seq_ho09)
  contains them. Plan (simplest first, keeps the demoed r5 binary):
  `tools/layer0_precheck.py` (`record`: fingerprints the scanned export's
  layer-0 inputs and writes `tools/layer0_refusals.json`; `check`: refuses
  a prompt with a listed token by name, exit 2, before anything is built
  or proved; an export whose fingerprint has no recorded scan is reported
  "not covered", exit 0) and the demo script runs it first.
- 13:36 LAYER-0 PRE-CHECK DONE (no binary change; the demoed r5 binary
  da48f6d4... stands):
  * `tools/layer0_precheck.py` (82ee7f9e...) `record` wrote
    `tools/layer0_refusals.json` (5633343a...; `logs/p5-record.log`): one
    entry, layer-0 fingerprint f8086a40... (embedding table + layer_00
    gamma_a / wq / wk / wv + manifest without RoPE), refusing 662 " ." and
    16309 "Tags" (site V, class 127), source scan path + SHA-256; matched
    exports b7_T128 (scanned) and b7_T32 (RoPE prefix checked).
  * `tools/test_layer0_precheck.py` (6c73f467...): 4 tests OK in 5.7 s
    (`logs/p5-precheck-tests.log`): ho00 / ho09 clear; a prompt with 662 at
    positions 1, 7 and 16309 at 3 refused by name with positions and the
    fix pointer on T32, T128 and the verifier copy (exit 2); a copy with
    one wv byte flipped is "not-covered" (exit 0) and `record` refuses it
    as an --also-export (exit 1, nothing written).
  * `tools/r4_cli_demo.sh` (4466800f...): the pre-check runs FIRST, before
    the build and the prove (logs/d0-precheck.{log,exit}); SEQ=<ID>
    (default ho00) or PROMPT_IDS=... selects the prompt; LOGS=<dir>
    redirects the logs. Exercised (`logs/precheck_exercise/`): ho00 with
    662 at position 5 and 16309 at 20 -> both named, d0 exit 2, script
    exit 1, nothing built or proved.
- 13:37 FINAL MANIFEST `manifest_final_r5.sha256` (231 files, 5f7d155e...;
  = T-B, i.e. the binary demoed and the suite s7 ran on; vs final r4:
  5 changed: examples/zk60_token_io.rs, private_block.rs, token_io/cli.rs,
  cli_tests.rs, load.rs).

## Round 5 REPORT (13:37 UTC)

Review round 4 (REVIEW4.md) fixed test-first; t24 failed exactly the three
new TR4 tests, t25 green (101 / 0 / 7); full suite s7 738 / 0 / 37.
- TR4-1 (MEDIUM) fixed: `owner` (and the new `input-owner`) runs verify's
  re-check path first (`check_run`, published statement required): the
  published statement must equal a fresh full verification of every
  segment byte for byte and `segments.json` must hash the bytes verified;
  a run flipped after publication and a prover-written `statement/` are
  refused before anything is printed.
- TR4-2 (MEDIUM) fixed: `--expect-token-profile HEX` (required on verify,
  owner, input-owner) pins the statement's token_profile_digest (tables,
  BOS, final norm); another head or half the Cn is refused by name, nothing
  published. `zk60_token_io profile` prints both pins for an approved
  export + tables.
- TR4-3 (LOW, D21) fixed: owner directory 0700 / files 0600; `--owner-dir`,
  default `$HOME/zk60-artifacts/token-io/<run>.owner-private`; an owner
  directory inside the run's parent is refused. The old demo directory was
  MOVED to `/home/victor/zk60-artifacts/token-io/run-b7_T32-ho00.owner-private/`
  (nothing owner-private remains under results/).
- TR4-4 (INFO) done: O_NOFOLLOW | O_NONBLOCK on table opens in load.rs;
  owner files written before the final rename (any failure removes them);
  `input-owner` command added.
- 8B CLI demo re-run end to end with the fixed binary (above, 13:14):
  profile, prove 266.8 s total, verify (published) 90.3 s, re-check 83.8 s,
  owner token 11, input-owner 32 tokens, all with both pins, exit 0.
- Coordinator add-on: layer-0 refusal pre-check in the demo (13:36).
No privacy acceptance is claimed.
