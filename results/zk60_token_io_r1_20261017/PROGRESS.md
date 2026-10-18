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
