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

## Round 6 (coordinator ~14:28): review round 5's TR5-1 .. TR5-3

REVIEW4.md ROUND 5: the token CLI is DEMO-FIT, TR4-1..TR4-4 closed.
Follow-ups, test-first: TR5-1 (LOW: prove's error path runs
remove_dir_all(owner dir) even when ITS create failed because a rival prove
had created it, deleting the winner's decommitments; same for the
unverified-statement directory; the default owner directory is keyed by
the base name only), TR5-2 (wording: the pre-check's "clear" must print its
scope (layer-0 norm/Q/K/V/RoPE sites only, not layer-0 scores or later
layers); fix the docstring's "Layer-0 values depend on the token only";
treat d0-precheck.log as prover-private for non-calibration prompts),
TR5-3 (the demo must take the approved token-profile pin from an approval
record, not from `profile` over the prover's files; write that record for
b7_T32, pin e8238cf1...). Then the full suite.

- 14:30 T-A (failing first, `manifest_r6A.sha256`, 84765c1a...; vs final
  r5: cli.rs, cli_tests.rs): cli.rs gains only a `#[cfg(test)]` seam
  (`hooks::BEFORE_OWNER_FILES`, called just before the owners' files are
  written, with the owner and unverified directories) and
  `default_owner_dir(base, out)` factored out with the OLD behaviour
  (`<name>.owner-private`). Two tests: `tr5_1_a_prove_never_removes_an_
  owner_or_statement_directory_it_did_not_create` (a rival prove claims the
  owner directory, then in a second run the unverified-statement directory,
  in that window; whichever wins, the directory and the winner's files
  must survive) and `tr5_1_the_default_owner_directory_is_keyed_by_the_
  runs_path` (two runs named `same` in different directories must get
  different default owner directories; same run -> same directory, by
  canonical path). Launched `t26-tr5-failfirst` (detached, cpu guard,
  `--lib -- token_io::cli_tests`); it queues behind another lane's
  r8-suite on the heavy lock. Expected: both tr5 tests FAIL (owner case:
  "the directory a rival prove created is GONE"; key: "share one default
  owner directory"), the five existing CLI tests pass.
- 14:31 T-B prepared in `wip-r6b/` (cli.rs, cli_tests.rs, examples/
  zk60_token_io.rs; synced only after t26 finishes):
  * TR5-1: `prove` claims `<out>.incomplete/`, `<out>.unverified-statement/`
    and the owner directory (0700) ATOMICALLY at its start (`Claimed::dir`:
    the create fails if the directory exists -> "exists; ... must be new");
    a `Claimed` guard removes exactly the directories THIS process created
    on any refusal (Drop) and keeps them after the final rename; the old
    late `create_private_dir` + unconditional `remove_dir_all` cleanup is
    gone. The default owner directory is `<name>-<12 hex of SHA-256 of the
    canonical run path>.owner-private`, printed in the `proved` line. Test
    added to the race test: an existing owner directory is refused, left
    untouched, and nothing of the refused prove remains.
- 14:32 TR5-2 (test-first, python): 3 new/extended tests FAILED first
  (`logs/p6-precheck-failfirst.log`: no `scope` in "clear"; a RoPE table
  that is not a prefix of the scanned one still matched (exit 2); no RoPE
  prefixes in the list), then `tools/layer0_precheck.py` (ddb3fcb3...):
  "clear" now prints the scan's `scope` and `not_covered` ("the layer-0
  attention scores (they depend on pairs of tokens) and all later layers
  (they depend on the context): a clear prompt can still be refused by the
  prover, which is safe"); the docstring's "Layer-0 values depend on the
  token only" restated (norm_a/Q/K/V of a position depend on its token
  alone; scores and later layers not covered); `check` itself now requires
  the export's RoPE tables to be a byte prefix of the scanned export's (the
  list holds the SHA-256 of every row prefix; otherwise "not-covered",
  nothing claimed); the docstring says the log is prover-private for a
  non-calibration prompt. List re-recorded (`tools/layer0_refusals.json`,
  43d3e0e9...; same fingerprint f8086a40..., same two tokens;
  `logs/p6-record.log`). 5 tests OK (`logs/p6-precheck-tests.log`).
- 14:34 TR5-3: `tools/approval_record.py` (45917be6...) wrote
  `approvals/token_profile_approval_llama3_8b_pg_rot1_b7_T32.json`
  (95cc2971...; `logs/p6-approval-record.log`) at the coordinator's
  instruction, from the CALIBRATION LANE's own files: all 8 files of its
  `token_io/SHA256SUMS` re-hashed and matched, profile.json = its ledger's
  209b07ac..., V 128,256 / BOS 128,000 / final norm g0 127, Cn 4,234, tn 9,
  Ceps 78,617 from its head_manifest.json; pins: expect_statement 47f01943...
  (the R3 harness's), expect_token_profile e8238cf1... (round-5 `profile`,
  reproduced by the reviewer's p1/p2), with the evidence paths; "not a
  privacy acceptance and not a ruling". (Written in this lane's directory:
  the calibration lane's directory is outside my write set; it can adopt
  the file.)
- 14:35 `tools/r4_cli_demo.sh` (d52ec7a5...) for round 6: the pins are READ
  FROM THE APPROVAL RECORD (the record's export must be the demo's; the
  `profile` step is gone); the owner directory is read from prove's
  `proved` line; TAG (default r6) names the binary copy, run, log labels
  and marker; SEQ (calibration hold-out, default ho00) / SEQ_DIR /
  PROMPT_IDS; a non-calibration prompt (SEQ_DIR or PROMPT_IDS) is
  prover-private: its logs go to a 0700 `$HOME/zk60-artifacts/token-io/
  demo-logs-<TAG>/` and a LOGS inside the repository is refused.
  Exercised without building: (1) PROMPT_IDS + LOGS inside the repo ->
  refused, nothing written; (2) PROMPT_IDS (ho00 with 662 at 5, 16309 at
  20) -> logs in `/home/victor/zk60-artifacts/token-io/demo-logs-r6x/`
  (0700), d0 exit 2, script exit 1, nothing built or proved.
- 14:36 launched `tools/r6_chain.sh` (7f2fccf1..., detached; log
  `logs/r6_chain.log`, marker `logs/r6_chain.done`): waits for t26 ->
  syncs T-B (`manifest_r6B.sha256`, `logs/r6-sync.log`) -> t27-r6-built
  (token_io + censuses + native trained CLI tests) -> if green the round-6
  8B demo (TAG=r6: pre-check, build, prove, verify, re-check, owner,
  input-owner, s8 full suite). t26 still queued behind another lane's
  r8-suite on the heavy lock.
- 14:42 **t26-tr5-failfirst RESULT (exit 101), as predicted: 2 FAILED, 5
  passed** (waited 483 s for the heavy lock, ran 258 s, peak 1.93 GiB):
  TR5-1 race "REVIEW TR5-1 (owner): the directory a rival prove created is
  GONE after this prove's error path" (the old cleanup deleted the rival's
  owner directory and file); key "two runs named `same` in different
  directories share one default owner directory". The five existing CLI
  tests pass.
- 14:42:59 STAGE T-B synced by the chain (`manifest_r6B.sha256`,
  2d6626a6...; vs T-A: examples/zk60_token_io.rs, token_io/cli.rs,
  cli_tests.rs); t27-r6-built queued next.
- 14:50 **t27-r6-built RESULT (exit 0): 103 passed, 0 failed, 7 ignored**
  (t25 was 101 + the two TR5-1 tests; 426 s, peak 3.14 GiB, no wait; no
  warning from the lane's CLI files). Both TR5-1 tests pass: the rival
  loses its claim and this prove completes with its files; an existing
  owner directory is refused and untouched, nothing of the refused prove
  left; default owner directories keyed by the canonical run path. The
  round-6 demo started (d0 pre-check on seq_ho00: clear, exit 0).
- 15:11 **THE ROUND-6 8B CLI DEMO, END TO END** (`tools/r4_cli_demo.sh`
  TAG=r6, `cli/zk60_token_io.r6.release.bin` 3225e577...,
  `cli/binaries_r6.sha256`) [MEASURED, shared box, n=1], every step exit 0:
  * d0 layer-0 pre-check (seq_ho00): clear, with its scope line;
  * pins READ FROM `approvals/token_profile_approval_llama3_8b_pg_rot1_b7_
    T32.json` (47f01943... / e8238cf1...); no `profile` step;
  * prove (seq_ho00): run `cli/run-b7_T32-r6-ho00`, owner directory by
    DEFAULT `/home/victor/zk60-artifacts/token-io/run-b7_T32-r6-ho00-
    3d3a3b4113bd.owner-private` (keyed by the run's canonical path; 0700,
    files 0600; read by the script from the `proved` line); 34 segments /
    471,285,072 B, prove 243.2 s, total 297.5 s, VmHWM 3,451 MiB, parity 32,
    floor 97;
  * verify (verifier copy, both pins): published by this verifier, 97.0 s;
  * verify again: statement-checked, 103.4 s;
  * owner: **next token 11**, 99.4 s; input-owner: 32 prompt tokens
    checked, 97.4 s (each re-verified the published statement first).
  s8 full suite running last in the chain.
- 15:45 s8 (the full suite, need 6.5 GiB) is WAITING for budget since
  ~15:25: the fidelity lane's two light jobs commit 5.5-6 GiB (6.39 GiB
  free) and are refilled as they finish; the waiting guard holds the heavy
  lock. Not restarted (rules). Scheduling note sent to the coordinator
  (SendMessage main).
- 15:59 **s8 FULL SUITE (exit 0): 740 passed, 0 failed, 37 ignored** over
  29 targets (lib 595 / 0 / 37; s7 was 738 / 0 / 37, +2 TR5-1 tests); ran
  893 s after 2,001 s of budget wait (admitted 15:44:57), peak 6.01 GiB RSS
  / 6.26 GiB cgroup (`logs/r6-s8-suite.log`, `.guard.json`). Chain done
  (`logs/r6_chain.done`).
- 16:00 FINAL MANIFEST `manifest_final_r6.sha256` (231 files, 2d6626a6...
  = T-B: the tree t27, the r6 demo binary and s8 ran on; vs final r5:
  examples/zk60_token_io.rs, token_io/cli.rs, cli_tests.rs). No
  `*owner-private*` / `*.dec` under this lane's results directory.

## Round 6 REPORT (16:00 UTC)

- TR5-1 (LOW) fixed test-first (t26 failed exactly the two new tests;
  t27 103 / 0 / 7): `prove` claims `<out>.incomplete/`,
  `<out>.unverified-statement/` and the owner directory (0700) atomically
  at its start and removes, on any refusal, only directories this process
  created (a `Claimed` drop guard); the default owner directory is
  `<name>-<12 hex of SHA-256 of the canonical run path>.owner-private`.
- TR5-2 (INFO) done test-first (python, 5 tests): "clear" prints the scan's
  scope and what it does not cover; docstring restated; `check` requires
  the RoPE tables to be a byte prefix of the scanned ones; a
  non-calibration prompt's demo logs go to a 0700 directory outside the
  repository (a LOGS inside it is refused).
- TR5-3 (INFO) done: approval record `approvals/token_profile_approval_
  llama3_8b_pg_rot1_b7_T32.json` (from the calibration lane's own files and
  ledger, pins 47f01943... / e8238cf1...); the demo reads its pins from it
  and no longer runs `profile`.
- Round-6 8B demo end to end, all exit 0 (15:11 entry); s8 740 / 0 / 37.
No privacy acceptance is claimed.

## Round 7 (coordinator ~16:00): rebase onto native R8; the fidelity-improved 8B demo; TR5-3 (a)/(b)

Round 6 accepted. (1) Rebase onto native R8 (`results/zk60_1b_native_
20261017/r8/frozen-tree/`, tree 7f64276a..., frozen 14:38:35Z; R8 = R7 +
every export-chosen calibration constant per layer, D32): tree = R8 + this
lane's files; the token stages read the per-layer constants where they
apply (the block stages); the final norm and head keep their token_io
constants; targeted tests, s9. (2) The fidelity lane's
`exports/llama3_8b_pg_rot1_b7voc0_T32` (b7 + layer-0 vocabulary
recalibration; profile.json 82c7c752...c4f6; exhaustive layer-0 check 0 of
128,256 refuse): approval record, layer-0 refusal list, demo TAG=r7 on ho00,
next token against the fidelity lane's integer / float references (asked
for: `runs/llama3-8b/nexttoken_ho00_b7voc0_T32.json`). (3) TR5-3 (a) refuse
an explicit --owner-dir inside a git working tree; (b) accept the default
owner directory for a run directly under $HOME. Test-first.

- 16:02 REBASE: R8 vs R7 = 10 files (r4_tests, r6_tests, r8_tests (new),
  review_d24_tests, run.rs, shape.rs, trained_block.rs, trained_stack_tests,
  trained_statement.rs, private_block.rs). This lane changed 8 R7 files;
  THREE overlap, merged by hand with `diff3 -m mine r7 r8` (0 conflicts;
  each merged file = R8 + exactly this lane's hunks, checked line for
  line): `private_block.rs` (the token_io module + CLI re-exports),
  `private_block/run.rs` (the three token-I/O run profiles, their shapes,
  the blocks-only refusal), `private_block/trained_block.rs` (pub(crate) on
  ten CLI helpers). The other seven R8 files copied as frozen. Check
  against r8/frozen-tree: 0 files only in R8; differing = exactly this
  lane's 8 changed files (private_block.rs, hash_domain_tests.rs, run.rs,
  run_capture.rs, s24/s25/s33_tests.rs, trained_block.rs) + 13 lane-only
  files (BASELINE.sha256, examples/zk60_token_io.rs, token_io.rs,
  token_io/*.rs).
- 16:07 T-A (failing first, `manifest_r7A.sha256`, 6e510047...): the token
  code compiles against R8 with R6's reading only (a record's own `sh_s` =
  `own[0]`; stage shapes still take only the score shift); cli.rs:
  `owner_dir_at(f, out, home)` factored out with the OLD rule. Three tests:
  `r7_a_layer_with_its_own_norm_and_shift_constants_is_proved_at_its_stage_
  shape` (block 1's record carries own norm/shift constants (R8's all-eleven
  calibration at the rung, or the norm constants, or cn_a, the first whose
  honest pipeline moves block 1): its stage shape must be that calibration,
  its schedule line must name each own constant, the receipt must verify,
  be refused under the run-wide statement, and the run-wide witness must be
  refused), `tr5_3_a_an_explicit_owner_dir_inside_a_git_working_tree_is_
  refused` (a `.git` directory or worktree `.git` file among the canonical
  ancestors: refused by name, nothing written), `tr5_3_b_the_default_owner_
  dir_is_accepted_for_a_run_directly_under_home`. Launched
  `t28-r7-failfirst` (`--lib -- token_io r8_tests r6_tests`). Expected: the
  three new tests FAIL; everything else (incl. R8's own r8_tests and the R6
  port test) passes.
- 16:09 T-B prepared in `wip-r7b/` (T-A copies of the three replaced files
  saved in `wip-r7a/`, = manifest_r7A): token_io/run.rs ported to R8
  (`stage_cal: Vec<NormCalibration>`; a record with own constants
  (`has_own`) -> `apply_own` on the run's calibration -> the trained door
  `with_layer_calibration`; `stage_shape(k)` = that calibration; the stage
  line names each own constant with R8's labels, R6's text for sh_s alone);
  cli.rs: the statement lists `layers_with_own_calibration` (each own
  constant under its export key, canonical order) and its schema is
  `zk60-token-io-run/2` (a /1 statement is refused by name); TR5-3 (a)
  `git_working_tree_of` on the canonical owner-dir parent (refused by name
  for an explicit --owner-dir), (b) the parent rule skipped only for the
  DEFAULT directory of a run whose canonical parent IS canonical $HOME.
  The final norm and head are untouched (token profile constants).
- 16:09 layer-0 list re-recorded with the fidelity lane's b7voc0_T32 scan
  (`logs/p7-record.log`): entries b7 (662, 16309; exports b7_T128, b7_T32)
  and b7voc0_T32 (fingerprint cd91e596..., refusing: NONE; profile.json
  82c7c752...c4f6 = the coordinator's value, checked). Pre-check tests: 6 OK
  (`logs/p7-precheck-tests.log`; new: the voc0 export is clear for ho00 and
  even for a prompt holding 662 and 16309).
- 16:10 `tools/r4_cli_demo.sh`: EXPORT selects the export (verifier copy,
  approval record and run names follow it), TAG default r7, the suite label
  `<TAG>-full-suite`. `tools/crosscheck_cli_next_token.py` (the R3
  cross-check for a CLI demo's token: calibration lane's integer head, R0,
  float head on the integer row). Launched `tools/r7_chain.sh` (detached;
  `logs/r7_chain.log`, marker `logs/r7_chain.done`): waits for t28 -> syncs
  T-B (`manifest_r7B.sha256`) -> t29-r7-built (token_io + censuses + trained
  stack/block + r4/r6/r8/d24 tests) -> build -> verifier copy of b7voc0_T32
  -> `profile` on that copy.
- 16:20 **t28-r7-failfirst RESULT (exit 101), as predicted: 3 FAILED, 48
  passed, 6 ignored** (waited 494 s, ran 294 s, peak 2.5 GiB): the R8 port
  test "ROUND 7: block stage 1 is not proved at its layer's own calibration
  (only sh_s was read)" (left = the run's calibration with only sh_s 6
  applied); TR5-3 (a) "an owner directory inside a git working tree was
  accepted" (prove exit 0); TR5-3 (b) "the default owner directory was
  refused for a run directly under $HOME". R8's own r8_tests / r6_tests and
  every other token_io test pass on the rebased tree with T-A. The chain
  synced T-B next.
- 16:21 the fidelity lane's references landed
  (`runs/llama3-8b/nexttoken_ho00_b7voc0_T32.json`): ho00 position 31,
  integer token 11 "," (margin C 313,660,358, ~9.51 logits), float model
  token 11 (margin 6.96 logits), agree.
- 16:20:57 STAGE T-B synced by the chain (`manifest_r7B.sha256`,
  e762b48a...; vs T-A: examples/zk60_token_io.rs, token_io/cli.rs,
  token_io/run.rs).
- 16:26 **t29-r7-built RESULT (exit 0): 132 passed, 0 failed, 10 ignored**
  (token_io + censuses + trained stack/block + r4 / r6 / r8 / d24 tests on
  the R8-based tree; 341 s, peak 3.06 GiB; no warning from token_io). The
  three round-7 tests pass: block 1 at its own constants in ALL ELEVEN
  fields (R8's all-eleven calibration at the rung was the first candidate
  and moved block 1) proved and verified at its stage shape, refused under
  the run-wide statement, the run-wide witness refused; TR5-3 (a) refusal
  text: "--owner-dir .../a-repo/sub/run.owner-private: inside the git
  working tree .../a-repo (.../a-repo/.git exists); the owners'
  decommitments are private (D21) and never sit in a repository (review
  TR5-3 (a))"; TR5-3 (b) accepted. Chain: CLI build next.
- 16:27 R8-based CLI built by the chain (71 s; `cli/zk60_token_io.r7.release
  .bin` db3d9825..., `cli/binaries_r7.sha256`); verifier copy
  `cli/verifier-export-llama3_8b_pg_rot1_b7voc0_T32` (hard links, no
  seq_*); `profile` on that copy (`logs/r7-profile-voc0.log`): trained
  identity c3fb8c5b767c0956...58c9 (binds this export's per-layer
  calibration), token profile digest e8238cf1... (= b7's: the tables, BOS
  and final norm are the calibration lane's b7_T32 files, same SHA-256s).
- 16:28 APPROVAL RECORD `approvals/token_profile_approval_llama3_8b_pg_rot1_
  b7voc0_T32.json` (`tools/approval_record.py`, `logs/p7-approval-record.
  log`): the 7 files of the export's rewritten token_io/SHA256SUMS
  re-hashed and matched; profile.json = 82c7c752...c4f6 (the fidelity
  ledger's and the coordinator's value); V 128,256, BOS 128,000, final norm
  g0 127 / Cn 4,234 / tn 9 / Ceps 78,617; pins c3fb8c5b... / e8238cf1...;
  approval = the coordinator's round-7 instruction; not a privacy acceptance
  and not a ruling.
- 16:28 DEMO TREE manifest `manifest_r7_demo.sha256` (= r7B, e762b48a...).
  Launched the round-7 demo (detached; `logs/r7_demo.log`): TAG=r7,
  EXPORT=b7voc0_T32, BIN=the r7 copy (no rebuild), seq ho00: pre-check
  (clear, no known refusing token), prove, verify, re-check, owner,
  input-owner, then the full suite (s9, label r7-full-suite) on the demo
  tree. Capture work (item 4) is staged in a copy until s9 has compiled.
- 16:41 **THE ROUND-7 8B DEMO ON THE FIDELITY-IMPROVED EXPORT, END TO END**
  (`tools/r4_cli_demo.sh` TAG=r7, EXPORT=b7voc0_T32, the R8-based binary
  `cli/zk60_token_io.r7.release.bin` db3d9825..., pins from the approval
  record) [MEASURED, shared box, n=1], every step exit 0:
  * d0 pre-check (ho00): clear, no known refusing token on this export;
  * prove: run `cli/run-llama3_8b_pg_rot1_b7voc0_T32-r7-ho00`, owner dir
    `/home/victor/zk60-artifacts/token-io/run-llama3_8b_pg_rot1_b7voc0_T32-
    r7-ho00-ef2b58a0591d.owner-private` (default, keyed); 34 segments /
    471,285,072 B, prove 219.2 s, total 264.5 s (after 156 s of guard wait),
    3.39 GiB, parity 32 layers, floor 97;
  * verify (published by this verifier) 80.7 s; re-check 78.4 s;
  * owner: **next token 11** (78.3 s); input-owner: 32 tokens (78.2 s).
  The fidelity lane's references for ho00 on this export
  (`runs/llama3-8b/nexttoken_ho00_b7voc0_T32.json`): integer 11 ","
  (margin ~9.51 logits), float model 11 (margin 6.96): both AGREE with the
  decommitted token. My public-file cross-check (calibration lane's integer
  head, R0, float head on the integer row) queued
  (`logs/p7-crosscheck-voc0.log`, out `runs/r7_crosscheck_voc0_ho00.json`).
  s9 (the full suite on the demo tree) compiling.
- 16:45 ITEM 4 (capture hooks for the gate) staged in `wip-r7c/`
  (run_capture.rs, run.rs, token_io.rs, token_io/{run,stage_in,stage_out,
  capture_tests}.rs); synced only after s9 has compiled.
- 16:50 ITEM 4 STEP A coded in `wip-r7c/` (synced by `tools/r7_capture_
  chain.sh` once the demo's suite has finished, since several tests read
  source files at run time):
  * run_capture.rs: `RunHeader.token: Option<TokenFacts>` (None for a block
    run: its bundle bytes do not move; the token run's header is rebuilt by
    `begin_run_with` from the same six words, so the header re-check holds
    for token runs too); `TokenFacts` (profile, V, V_pad, T, d, variant,
    mode, limbs, window/mult bits, embedding/head digests, BOS, final norm,
    s_in = s_out, tier, both endpoint specs, both roots, every boundary in
    token numbering 0 = B_in .. L = B_out, the r_emb length, the two stage
    layouts); `stage_begin_stage(k, "IN"|"BLOCK"|"OUT", ...)` replaying each
    stage prefix from the recorder's OWN transcript (IN: stage 0, the
    embedding digest, B_in, A, M, 3 LogUp + clog2(d_pad) r_emb draws, H;
    BLOCK: stage k, block k-1's digest, B_k, then a block's A/M/3/H; OUT:
    stage L+1, the head digest, A, M, 2 draws, H); `stage_slot` (the block
    slot replay at the stage schedule's (main, ext, degree), same record
    keys, private tables under the stage's role names, fixed coordinates as
    {"fixed": v}, public tables with values when asked, every private table
    located on the stage's plane table); the stage plane table
    (`stage_plane_index`: planes with names / log sizes / rows, the row
    bookkeeping, the schedule, per-slot planes OBSERVED); stage_end / take /
    run_accepted count L + 2 stages for a token run; `write_stage_token`,
    `write_run_token` (schema `hashline-native-capture/6-token-run`,
    `token_io`, `token_boundaries`, the token transcript program, "owner
    decommitments" in not_in_a_capture); 56 new allow-listed keys; the
    bundle writer handles L + 2 stage files and a token README.
  * hooks (all `#[cfg(test)]`, placed as run.rs / protocol.rs / argument.rs
    place theirs): `verify_token_run_with` (stage_begin_stage / stage_end
    around IN, every block and OUT; the boundary opening wrapped (role
    "Input", kind "B-in" at block 0 else "internal-boundary", claim sources
    = the previous stage's outgoing slot + this block's SC_IO_IN);
    run_accepted after OUT); `stage_in::verify` / `stage_out::verify`
    (start_slot before each definition; mask + pcs wrappers on M, A-in /
    H-in / E-token-in, A-out / H-out / B-out / E-token-out with claim
    sources); `run_stage_slot` (checkpoint before pb-slot, stage_slot after
    the accumulators, verify side only); `TokenRunStatement::capture_header`
    / `binding`.
  * tests (`token_io/capture_tests.rs`): the rung capture checked against
    itself (L + 2 files, kinds, slot counts 4 / 23 / 11, opening orders,
    segment pins, plane tables, fixed coordinates, allow-list, no owner
    decommitment: at most Q of an owner's salts (the opened columns') and
    none of its pad words); the prover's path records nothing with a
    recorder attached and seeded, the receipt verifies with and without
    one; a tampered run writes no bundle; `#[ignore]`d env-driven
    `capture_a_tinyllama_token_run` and `capture_a_llama3_8b_token_run`
    (HL_PB_CAPTURE_DIR / _BLOCKS / HL_PB_FIRST_LAYER / HL_PB_TOKEN_INPUT
    dense|fixed (fixed = T copies of BOS) / HL_RUN_CAPTURE_PUBLIC_TABLES /
    HL_TEST_SOURCE_COMMIT), streaming, dense checked against the export's
    activations at every layer.
- 16:52 **s9 FULL SUITE on the DEMO TREE (exit 0): 748 passed, 0 failed,
  37 ignored** over 29 targets (lib 603 / 0 / 37; s8 was 740: + R8's five
  r8_tests + the three round-7 tests), 707 s, peak 5.86 GiB RSS / 6.05 GiB
  cgroup, no wait (`logs/r7-full-suite.log`). Demo tree manifest:
  `manifest_r7_demo.sha256` (= r7B, e762b48a...).
- 16:53 STEP A synced by the chain (`manifest_r7C.sha256`, 4d4b7785...; vs
  the demo tree: run.rs, run_capture.rs, token_io.rs, token_io/run.rs,
  stage_in.rs, stage_out.rs changed; token_io/capture_tests.rs added).
- 17:09 **t30-capture RESULT (exit 0): 59 passed, 0 failed, 17 ignored**
  (`--lib -- token_io run_capture`: every token_io test, the 3 new capture
  tests, and the block run-capture tests (block bundles still pass their
  self-consistency, allow-list, with/without-recorder and two-encodings
  tests, i.e. block bundle bytes did not move); 758 s, compiled first time):
  the rung token capture (L = 2): run.json 42,695 B, stage files
  4,640,048 / 24,028,466 / 24,029,524 / 10,072,336 B (public tables inline),
  self-consistent; the prover records nothing with a recorder attached and
  seeded, the receipt verifies with and without one; a tampered run
  refused ("block 0: A: pcs zk: Merkle path for column 2658 fails"), no
  bundle.
- 17:11 THE PRODUCTION BINARY: the release CLI rebuilt from the capture
  tree (`cli/zk60_token_io.r7c.release.bin` b18ad304...) against the demo
  binary (db3d9825...): same length (2,241,232 B); 136 bytes differ, ALL in
  `.note.gnu.build-id` (20 B) and `.data.rel.ro` (110 single bytes: the
  panic-location line numbers of the source files that gained cfg(test)
  lines, e.g. +3, +8, +35); `.text` and `.rodata` byte-identical
  (`logs/r7c-binary-compare.txt`). The run_capture module is cfg(test), so
  a release build that compiles cannot call a hook. The token prover's
  randomness is OS-seeded (zkp-core `ZkRng::from_os`, endpoint_g::prepare),
  so "same seed, same receipt" is not available without touching shared
  files; the inertness test above stands in for it.
- 17:12 the gate captures started (TinyLlama T32, L = 1, dense first).
- 17:23 **STEP A GREEN: the gate's TinyLlama captures** [MEASURED], all
  exit 0, written to `/home/victor/zk60-artifacts/token-io/captures/`
  (0700, outside the repository; schema hashline-native-capture/6-token-run,
  arrays.bin, public tables' values, layers from 0):
  | bundle | L | prompt | prove | verify+record | peak | size |
  |---|---|---|---|---|---|---|
  | tinyllama-t32-L1-dense-pt1 | 1 | ho00 (parity at every layer) | 4.8 s | 1.7 s | 1.02 GiB | 36,935,581 B |
  | tinyllama-t32-L1-fixed-pt1 | 1 | 32 x BOS (id 1) | 4.5 s | 1.5 s | 0.98 GiB | 36,995,398 B |
  | tinyllama-t32-L2-dense-pt1 | 2 | ho00 | 7.5 s | 1.8 s | 1.14 GiB | 53,929,341 B |
  | tinyllama-t32-L2-fixed-pt1 | 2 | 32 x BOS | 7.9 s | 1.9 s | 1.13 GiB | 53,886,291 B |
  (`logs/cap-tinyllama-t32-*.log`). Each test also re-read its bundle
  (manifest lengths / SHA-256, allow-list, segment pins, kinds, slot
  counts, opening orders, no owner decommitment). Step-A tree manifest:
  `manifest_r7C.sha256` (4d4b7785...). Coordinator told (SendMessage),
  with the paths. Note: the checker's pad scan over arrays.bin is
  quadratic (most of each 160 s test); fixed before the L = 22 / 8B runs.
- 17:24 PUBLIC-FILE CROSS-CHECK of the r7 demo's token
  (`runs/r7_crosscheck_voc0_ho00.json`, `tools/crosscheck_cli_next_token.py`
  under a light guard): the calibration lane's integer head on the
  b7voc0_T32 export's x_out_L31 row 31: 11 (margin C 313,660,358, the same
  as the fidelity lane's); R0's reference: 11; the float head on that
  integer row: 11 (margin 9.55 logits). With the fidelity lane's integer
  (11) and float-model (11) references, all agree with the decommitted 11.
- 17:25 STEP B: the checker's owner-decommitment scan made linear (salts,
  JSON integers and arrays.bin words indexed once in hash sets;
  `index_json` in capture_tests.rs). Launched `tools/r7_capture_b_chain.sh`
  (detached; `logs/r7d_chain.log`, marker `logs/r7d_chain.done`):
  manifest r7D -> t31 (the three capture tests) -> TinyLlama L = 22 dense
  and fixed -> Llama-3-8B T32 (b7voc0_T32) L = 1 dense and fixed, all with
  the public tables' values. The step-B slot hook (stage_slot with fixed
  coordinates and public-table values), the new Geom roles and the claim
  sources were built in step A (the replay needs the slot hook to follow
  the transcript through IN / OUT); variant P's two-site input endpoint
  (D26 IO-s / SHIFT) is not built, so "both sites" / IO-s / SHIFT apply to
  no built geometry (the public-row endpoints have one site each; B_in and
  B_out list both of their sites).
- 17:32 t31-capture (exit 0): the three capture tests, 3 passed, 5.3 s
  (the scan was the earlier cost).
- 17:35 **TinyLlama WHOLE-MODEL captures (L = 22)** [MEASURED], exit 0:
  `tinyllama-t32-L22-dense-pt1` (ho00, parity at all 22 layers): prove
  66.8 s, verify+record 10.8 s, peak 3.02 GiB RSS / 3.15 GiB cgroup,
  384,939,747 B (arrays.bin 297,994,080 B, 24 stage files);
  `tinyllama-t32-L22-fixed-pt1` (32 x BOS): prove 67.9 s, verify+record
  11.0 s, peak 3.01 / 3.74 GiB, 384,536,509 B.
- 17:57 the 8B captures (need 7 GiB) WAIT for budget since ~17:40: the
  fidelity lane's two light jobs (5.5 GiB) are refilled as they end; the
  waiting guard holds the heavy lock. Not restarted. Scheduling note sent
  to the coordinator (SendMessage).
- 18:22 **Llama-3-8B T32 captures (b7voc0_T32, L = 1)** [MEASURED], exit 0,
  admitted 18:20 after 2,738 s of budget wait (the coordinator held the
  fidelity lane to one job): `llama3-8b-t32-L1-dense-pt1` (ho00, parity
  at layer 0): load 13.7 s, prove 16.1 s, verify+record 11.1 s, peak
  3.18 GiB RSS / 3.64 GiB cgroup, 57,068,865 B; `llama3-8b-t32-L1-fixed-pt1`
  (32 x BOS, id 128,000): prove 16.3 s, verify+record 11.5 s, peak 3.19 /
  3.88 GiB, 57,079,375 B. Step-B tree manifest `manifest_r7D.sha256`
  (f895e16b...; vs r7C: capture_tests.rs, the linear scan).
- 18:23 launched `tools/r7_final_chain.sh` (detached): the 8B captures at
  L = 2 too (an internal boundary at the 8B geometry; L = 1 held 3.2 GiB),
  then the final manifest and the full suite s10 on the final tree.
- 18:27 **Llama-3-8B T32 captures at L = 2** [MEASURED], exit 0:
  `llama3-8b-t32-L2-dense-pt1`: prove 21.0 s, verify+record 12.1 s, peak
  3.50 GiB RSS / 3.55 GiB cgroup, 79,971,541 B; `llama3-8b-t32-L2-fixed-pt1`:
  prove 20.5 s, verify+record 12.2 s, peak 3.49 / 3.84 GiB, 79,929,663 B.
  FINAL MANIFEST `manifest_final_r7.sha256` (233 files, f895e16b... = r7D;
  vs the demo tree: run.rs, run_capture.rs, token_io.rs, token_io/run.rs,
  stage_in.rs, stage_out.rs changed, token_io/capture_tests.rs added).
  s10 (the full suite on the final tree) queued.
- 18:43 s10 (the full suite on the final tree) exit 101: 750 passed, ONE
  failed, 39 ignored — `s25_tests::every_hash_call_site_in_the_lanes_own_
  sources_is_classified`: "src/private_block/run_capture.rs: 8 call(s) of
  `sha256_hex(` and the stage-25 call-kind table declares 6". The token
  capture added two SHA-256 call sites (the token stage file's segment
  digest, the token run file's endpoint-policy digest), same kind as the
  six (C1, SHA-256 over bytes the bundle pins). Fixed by classifying them
  (s25_tests.rs CALL_SITES row 6 -> 8 with the reason), not by weakening
  the census. Relaunched the final manifest + s11 (`tools/r7_s11_chain.sh`).
- 19:08 **s11 FULL SUITE on the FINAL TREE (exit 0): 751 passed, 0
  failed, 39 ignored** over 29 targets (lib 606 / 0 / 39; s9 + the three
  capture tests; + the two `#[ignore]`d gate captures), 677 s after 722 s
  of budget wait, peak 6.13 GiB RSS / 6.26 GiB cgroup (`logs/s11-suite.log`).
  FINAL MANIFEST `manifest_final_r7.sha256` (233 files, eb912dd5...; vs the
  demo tree: run.rs, run_capture.rs, s25_tests.rs, token_io.rs,
  token_io/run.rs, stage_in.rs, stage_out.rs changed, token_io/capture_
  tests.rs added). Final tree vs `r8/frozen-tree`: 0 files only in R8; 8
  R8 files carry lane changes (private_block.rs, hash_domain_tests.rs,
  run.rs, run_capture.rs, s24_tests.rs, s25_tests.rs, s33_tests.rs,
  trained_block.rs); 14 lane-only files (BASELINE.sha256,
  examples/zk60_token_io.rs, token_io.rs, token_io/*.rs incl. the new
  capture_tests.rs). No owner-private data under this lane's results.

## Round 7 REPORT (19:09 UTC)

1. Rebase onto native R8: tree = R8 + this lane's files (three overlap
   files merged by hand with diff3, 0 conflicts: private_block.rs, run.rs,
   trained_block.rs). The token run reads each block stage's whole R8
   calibration from its record (stage_cal, with_layer_calibration, R8's
   schedule clauses); the final norm and head keep the token profile's
   constants; the token statement's schema is zk60-token-io-run/2
   (layers_with_own_calibration). Test-first: t28 failed exactly the 3 new
   tests; t29 132 / 0 / 10; s9 (demo tree) 748 / 0 / 37.
2. Fidelity-improved 8B demo on b7voc0_T32 (approval record with pins
   c3fb8c5b... / e8238cf1..., layer-0 list: no refusing token), TAG=r7,
   every step exit 0: next token 11 = the fidelity lane's integer (11) and
   float-model (11) references = my public-file cross-check (integer head
   11, R0 11, float head on the integer row 11).
3. TR5-3 (a) explicit --owner-dir inside a git working tree refused by
   name; (b) the default owner directory accepted for a run directly under
   $HOME. Test-first (t28 -> t29).
4. Gate capture hooks: step A green (t30 59 / 0 / 17; TinyLlama L = 1, 2
   dense / fixed captures); step B (slot hook built in A; TinyLlama L = 22
   and Llama-3-8B L = 1, 2 captures, peak <= 3.5 GiB). Hooks cfg(test),
   inert on the prover, release .text / .rodata byte-identical. s11 on
   the final tree 751 / 0 / 39.
No privacy acceptance is claimed.

## Round 8 (coordinator ~19:10): the 128-token next-token proof

Round 7 accepted; review round 6 (reviewer a62f05d, REVIEW5.md) of rounds 6
and 7 started. Freeze the round-7 tree. Then: (1) next-token profiles at
T = 128 for Llama-3-8B and TinyLlama (DESIGN v3's first geometry, T <= 128,
column half bit; count the whole-run floor, target >= 95 bits, D27;
test-first: completeness on a generic dense witness, a T32 statement refused
under a T128 profile and the reverse); (2) exports: 8B b7voc0_T128 (stack
identity 5585f5ee..., token_io/ hard-linked from b7: approval record from the
data files and SHA256SUMS, stale wording noted); TinyLlama dg_rot1_T128
(report exactly what token_io is missing, if any); the newest 8B
dg_rot1_voc0_T128 (approval record prepared; prove only after the
coordinator confirms it beats b7voc0); (3) demo chains at T128 on ho00,
guard needs from measured peaks (8B T128 stack 6.7 GiB), alone on the heavy
lock; (4) references from the fidelity lane + my public-file cross-check;
(5) proof time per prompt token T128 vs T32 (264.5 s / 32), MEASURED, box
state; full suite and manifest.

- 19:11 FROZEN: `frozen-r7/` = the round-7 tree (233 files, every entry
  re-hashed against `manifest_final_r7.sha256`: match; BASELINE.sha256 and
  target/ excluded as by the manifest tool); note `frozen-r7.FROZEN.txt`.
- 19:14 TinyLlama dg_rot1_T128 had no token_io/: told the coordinator
  exactly what was missing (head_int8_perrow.bin, head_mult12.bin,
  head_manifest.json with bos and final_norm at this export's tn 10 /
  Ceps 74,429 and a Cn calibrated on its own final residual, plus
  calib_final_xhat_rot_absmax.bin, and token_io.json naming them). 19:2x:
  the fidelity lane added them (head files byte-identical to R2's, Cn 5,664
  confirmed, 0 final-norm violations on 96 held-out sequences). The 8B
  dg_rot1_voc0_T128 export is confirmed better than b7 (ppl ratio 1.281 /
  1.277 vs 1.63 / 1.77): demo it after b7voc0_T128. References landed:
  8B b7voc0_T128 ho00 integer 11 (margin ~0.55 logits) / float 11 (12.31);
  TinyLlama dg_T128 integer 491 (~2.26) / float 491 (10.01).
- 19:16 T-A (failing first, `manifest_r8A.sha256`, 3475006f...): two tests
  in a new `token_io/t128_tests.rs` (`t128_profiles_exist_and_their_whole_
  run_floor_reaches_95_bits`: each T128 block shape has its own token
  profile, the input endpoint is one 256-word row, the derived whole-run
  figure at L = 22 / 32 >= 95 bits, printed beside T32; `t128_a_dense_
  tinyllama_run_proves_and_t32_and_t128_are_not_interchangeable`: a dense
  TinyLlama T128 run (L = 1, prompt over the whole vocabulary, generic
  tables) proves, verifies, counted length, both owners check; a T32 run
  likewise; each receipt refused under the other's statement; each shape
  refused under the other T's profile).
- 19:28 **t32-r8-failfirst RESULT (exit 101), as predicted: both FAILED**
  at "ROUND 8: TinyLlama T128 has no token-I/O run profile: ... no
  token-I/O run profile is registered for the block profile
  hashline-zk-mr1/private-block-tinyllama-1.1b-t128-trained-block/1"
  (waited 451 s, 280 s, peak 1.98 GiB).
- 19:29 T-B (`wip-r8b/`): run.rs `RUN_PROFILE_TOKEN_IO_TINYLLAMA_T128`
  ("hashline-zk-mr1/private-token-io-run-tinyllama-t128-trained-statement-
  public-row/1", constructor 94 B; the "-1.1b-t128-" spelling would give 99
  B, the length of another kind of the TinyLlama run) and
  `RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T128` (constructor 95 B), both in
  TOKEN_IO_RUN_PROFILES and the run-shape table; load.rs maps the two T128
  block profiles to them; registered_token_runs and the census helpers
  (tests.rs) carry them.
- 19:29 STAGE T-B synced (`manifest_r8B.sha256`, bc32cd4a...; vs T-A:
  run.rs, token_io.rs, token_io/load.rs, token_io/tests.rs).
- 19:30 layer-0 list re-recorded (`logs/p8-record.log`): b7 (662, 16309),
  b7voc0_T32 (none), dg_rot1_voc0_T128 (none, its own scan); b7voc0_T128's
  layer 0 matches the scanned variant l8_b7_voc0 but its RoPE tables are
  not a prefix of the variant's, so `record` refused it as covered: its
  pre-check says "not-covered" (nothing claimed). TinyLlama dg_T128: no
  scan, not-covered. Pre-check tests: 7 OK (`logs/p8-precheck-tests.log`).
  `tools/r4_cli_demo.sh`: PROVE_NEED / PROVE_CAP / VERIFY_NEED / VERIFY_CAP
  (defaults the T32 values), max-secs 3600.
- 19:31 launched `tools/r8_chain.sh` (detached; `logs/r8_chain.log`): t33
  (token_io + censuses + native trained / r8 tests) -> the round-8 CLI ->
  verifier copies of b7voc0_T128, dg_rot1_voc0_T128, tinyllama_dg_rot1_T128
  -> `profile` on each copy.
- 20:02 reference (c) landed (`runs/llama3-8b/nexttoken_ho00_dg_voc0_T128.json`):
  8B dg_rot1_voc0_T128 ho00 integer 11 "," (margin ~3.69 logits), float 11
  (12.31). t33 waits for budget (fidelity + gate light jobs).
- 20:16 the coordinator holds the other lanes to ~3.8 GiB of light jobs
  for this round; release marker agreed as `logs/r8_round.done` (exit
  code) because part A (`tools/r8_chain.sh`, already running) writes
  `logs/r8_chain.done` before the demos. Launched part B,
  `tools/r8_round.sh` (detached; `logs/r8_round.log`): waits for part A ->
  checks t33 and the three profiles -> the three approval records
  (`tools/approval_record.py`; pins from `profile` over the VERIFIER
  copies; profile.json against the fidelity ledger's values; b7voc0_T128's
  stale token_io wording recorded) -> the demos one after another (8B
  b7voc0_T128 TAG=r8 and dg_rot1_voc0_T128 TAG=r8dg at prove 8 / cap 10,
  checks 6 / 8; TinyLlama dg_rot1_T128 TAG=r8tl at 4 / 6, 3 / 5) -> the 8B
  public-file cross-checks -> final manifest -> s12 -> `r8_round.done`.
- 20:23 the coordinator's order: the gate lane's running queue could not
  take the hold (its TinyLlama L22 jobs at 6.5 GiB light, then 8B jobs at
  4-4.5), so the TinyLlama T128 demo goes FIRST (prove need 4.2 / cap 6
  from the measured TinyLlama T128 peak 3.6 GiB; checks 3.5 / 5), then the
  8B T128 demos when room opens (declarations kept at 8 / 10 and 6 / 8),
  each guarded step waiting at most until 23:00 UTC (`WAIT_SECS`, new in
  `tools/r4_cli_demo.sh`); past 23:00 the 8B demos are skipped and the round
  reports what it has. Part B was still waiting for part A: its remaining
  lines were replaced IN PLACE (same inode, the bytes up to its wait loop
  unchanged) by `exec bash tools/r8_round_v2.sh` (the reordered part B).
- 20:24 **t33-r8-built RESULT (exit 0): 116 passed, 0 failed, 9 ignored**
  (waited 2,753 s for budget, ran 396 s, peak 6.27 GiB; the censuses
  s24 / s25 / s33 with the two new profiles pass: no W-2 collision). The two
  round-8 tests pass:
  * WHOLE-RUN FIGURES [COUNTED, derived by the statement]: TinyLlama T32
    (L 22) 2^-97.33 -> 97 bits; **TinyLlama T128 (L 22) 2^-97.82 -> 97
    bits** (column 2^-98.98, LogUp 2^-98.67); Llama-3-8B T32 (L 32)
    2^-97.58 -> 97 bits; **Llama-3-8B T128 (L 32) 2^-96.78 -> 96 bits**
    (column 2^-98.53, LogUp 2^-97.30: at T128 the stack's lookup term sets
    the figure, as DESIGN 4.4 says); all >= D27's 95. The input endpoint is
    one 256-word row at T128 (DESIGN v3's first geometry).
  * dense TinyLlama T128 (L 1): proves in 11.4 s (27,846,216 B) vs T32 5.6 s
    (16,031,016 B) [MEASURED, test build, shared box]; both verify, both
    owners check; T32 receipt under the T128 statement and the reverse:
    "token I/O wire: this segment belongs to another run"; each shape
    refused under the other T's profile.
- 22:26 PART A done (`logs/r8_chain.done`): the round-8 CLI
  `cli/zk60_token_io.r8.release.bin` (6b601c14..., `cli/binaries_r8.sha256`;
  its build waited ~50 min for the heavy lock); verifier copies of the three
  T128 exports; `profile` over each copy (the first waited 5,650 s for
  budget): b7voc0_T128 trained identity 23e0e365..., token profile
  1806fcc3...; dg_rot1_voc0_T128 4a99091a... / 5c4668be...; TinyLlama
  dg_rot1_T128 0f2467fc... / 13679e42... (the T128 profiles' token profile
  digests differ from the T32 ones: the digest is taken under the run
  profile). The in-place hand-over worked: part B now runs as
  `r8_round_v2.sh`. APPROVAL RECORDS written (`approvals/token_profile_
  approval_{llama3_8b_pg_rot1_b7voc0_T128, llama3_8b_dg_rot1_voc0_T128,
  tinyllama_dg_rot1_T128}.json`, `logs/p8-approval-records.log`): each
  export's own token_io SHA256SUMS re-hashed and matched (8 / 6 / 6 files),
  profile.json = the fidelity ledger's value, pins from the verifier-copy
  `profile`; b7voc0_T128's records the stale hard-linked wording (data
  correct). The TinyLlama T128 demo has started (pre-check: not-covered).
- 22:27 the coordinator's forecast: the gate's queue keeps the TinyLlama
  prove (4.2) out until ~23:30, so part B will skip the 8B demos at 23:00;
  then, after part B's suite and `r8_round.done`, the 8B demos run as a
  follow-up chain with its own marker. Launched `tools/r8_8b.sh` (detached,
  `logs/r8_8b.log`): waits for `logs/r8_round.done`, then each 8B T128 demo
  part B did not complete (TAGs r8x / r8dgx, prove 8 / 10, checks 6 / 8),
  each followed by its public-file cross-check; marker `logs/r8_8b.done`.
  New `tools/crosscheck_int_next_token.py` (R0's integer semantics on any
  export's last-layer row T - 1 with its own token_io head; for TinyLlama).
- 22:38 **THE TINYLLAMA T128 NEXT-TOKEN DEMO, END TO END** (TAG=r8tl,
  EXPORT=tinyllama_dg_rot1_T128, the round-8 binary 6b601c14..., pins from
  its approval record) [MEASURED, shared box: the gate lane's L22 job and
  one fidelity job ran beside it; n=1], every step exit 0:
  * pre-check: not-covered (no vocabulary scan for this export);
  * prove (ho00, 128 tokens): run `cli/run-tinyllama_dg_rot1_T128-r8tl-
    ho00`, owner dir `/home/victor/zk60-artifacts/token-io/run-tinyllama_
    dg_rot1_T128-r8tl-ho00-a5e544c2a5c1.owner-private`; 24 segments /
    502,462,848 B; prove 186.0 s, total 192.5 s (after 444 s of budget
    wait), peak 3.70 GiB RSS / 4.32 GiB cgroup, parity 22 layers, floor 97;
  * verify (published by this verifier) 23.4 s; re-check 22.9 s; owner:
    **next token 491** (23.2 s); input-owner: 128 tokens (22.7 s).
  The fidelity lane's references: integer 491 "by" (margin ~2.26 logits),
  float model 491 (10.01): both AGREE. My integer cross-check queued
  (`tools/crosscheck_int_next_token.py`).
- 22:41 TinyLlama T128 integer cross-check (`runs/r8_crosscheck_tinyllama_
  dg_rot1_T128_ho00.json`): R0's integer semantics on x_out_L21 row 127
  with the export's own head: 491 (second 304), margin C 53,591,880
  (11.4 % of the top value), max |y| 57; agrees with the decommitted 491.
  Part B moved on to the 8B b7voc0_T128 demo (its prove waits for budget,
  at most until 23:00 UTC).
- 23:56 PART B ENDED (`logs/r8_round.done` = 0, the other lanes released):
  the 8B b7voc0_T128 demo's prove was refused by its guard at the 23:00
  cutoff ("could not take /tmp/zk-heavy.lock within 1357s", exit 70;
  nothing proved, nothing written); the dg demo was skipped (past the
  cutoff); **s12 FULL SUITE (exit 0): 753 passed, 0 failed, 39 ignored**
  over 29 targets (s11 + the two T128 tests), 750 s after 2,624 s of
  budget wait, peak 7.11 GiB RSS / 7.17 GiB cgroup (`logs/s12-suite.log`).
  FINAL MANIFEST `manifest_final_r8.sha256` (234 files, bc32cd4a... = r8B;
  vs final r7: run.rs, token_io.rs, token_io/load.rs, token_io/tests.rs
  changed, token_io/t128_tests.rs added). The follow-up 8B chain
  (`tools/r8_8b.sh`, marker `logs/r8_8b.done`) started on the release.
- PROOF TIME PER PROMPT TOKEN [MEASURED, shared box, n=1 each]: TinyLlama
  T128 (CLI, dg_rot1_T128, 22 blocks): prove 186.0 s / total 192.5 s for
  128 tokens = 1.45 / 1.50 s per token; TinyLlama T32 (R2 harness,
  pg_rot1_b4, 2026-10-18): prove 85.3 s for 32 = 2.67 s per token (x2.18
  the time for x4 the tokens). Llama-3-8B T32 (CLI, b7voc0_T32, round 7):
  prove 219.2 s / total 264.5 s for 32 = 6.85 / 8.27 s per token; 8B T128
  pending (follow-up chain).

## Round 9 (coordinator, queued ~00:00; coded during the 8B follow-up's waits)

(1) F-T1 (gate finding): every token-stage witness (IN, OUT, endpoints)
passes its lookup-miss / consistency check in a SEALING PASS before any run
header, alongside the blocks' CS-3 check, so a refused token run writes
nothing; test-first. (2) A capture through the CLI token path (the CLI's
own verify-from-dir on a `prove` output, recorded through the round-7
hooks), TinyLlama T32 L = 2, under ~/zk60-artifacts/token-io/captures/.
(3) A named token CPU binary (release, round-9 tree; sha256 in a binaries
file; a note of its build flags and features, CPU backend only). (4) Full
suite, manifest, freeze the round-9 tree. Started after the 8B addendum's
chain is running (the demos use the r8 binary copy; source edits cannot
reach them).

- 00:04 T-A (failing first, `manifest_r9A.sha256`, 4778f71b...): a
  test-only run-header counter in `prove_token_run_with` (`run_headers()`),
  and `token_io/r9_tests.rs`: a stage-IN lookup miss (B_in row 1 not
  E[tok_1]); a stage-OUT lookup miss (a looked limb 300; R2-5's existing
  pre-header check, a control); a block-1 exp lookup miss (CS-3); an input
  endpoint sealed over another prompt and an output endpoint over another
  token; each must be refused with NO header built and NO segment sunk;
  the honest run proves with exactly one header. Launched
  `t34-r9-failfirst`. Expected: stage IN, block and endpoint tests FAIL;
  the stage-OUT control and the honest run pass.

### Round 9, widened by privacy review round 4 (coordinator ~00:15; replaces the list above)

PR4-4 (seal the token CLI: one sealing pass before any header — builder,
stage IN / OUT, int16, bit-exact parity at every layer, CS-3 on every
witness, the next token from the integer pipeline; F-T1 subsumed), PR4-10
(a named CPU token binary + one CLI-path capture, P-18 style, NO new CLI
hooks, TinyLlama T32 L = 2), PR4-15 (a refused run's removal not silent; a
killed run's `<out>.incomplete/` refused by name with how to clear it),
PR4-16 (owner decommitments under `~/zk60-owner-private/token-io/`, 0700;
report — not delete — the existing owner-private directories), PR4-17 (no
prompt on the command line: `--prompt-file` 0600 or stdin; `owner` writes
the token to a 0600 file, stdout only with `--print`), then full suite,
manifest, freeze round 9. Test-first; starts for real after the 8B
addendum; staged meanwhile (nothing below touches the working copy, which
t34 has yet to compile, or any script the running r8_8b chain uses).

- 00:36 staged (no build yet; heavy lock held by the waiting 8B prove):
  `wip-r9b/` (T-B: the generic sealing pass in `prove_token_run_with` with
  `TokenRunSource::seal_check`, `stage_in::lookup_misses`, endpoint-plane
  checks; the CLI's `seal_chain` (builder chain, int16, parity vs x_out at
  every layer, CS-3; stage shape derived exactly as
  `TokenRunStatement::stage_shape`), `read_prompt_file` (0600 / stdin),
  `--prompt` refused (exit 2), `OWNER_BASE = zk60-owner-private`, removal
  events + `REMOVAL-FAILED`, `leftover_refusal`, `owner --token-out /
  --print`; `cli_tests.rs` moved to prompt files, per-call token files and
  the new base; the CLI capture test rewritten P-18 style: CLI prove, CLI
  verify (exit 0), then the run directory read with the CLI's own
  `public_inputs` / `found_statement` / `statement_of` / counted segments
  and `verify_token_run_with` run with the recorder attached — no hook
  remains (`cli_capture` gone)). `wip-r9a2/` (T-A2 stubs + the failing-first
  CLI tests). `wip-r9-tools/`: `layer0_precheck.py --prompt-file` (0600
  checked) test-first — the new test FAILED on the old tool, then 8/8 OK on
  the staged copy [MEASURED, bounded Python]; `r9_cli_demo.sh` (prompt file
  under `~/zk60-owner-private/token-io/prompts/`, owner `--token-out`
  without `--print`, private logs under the new base, a leftover
  `<run>[.incomplete|.unverified-statement]` stops the demo before any
  guard with `rm -r` instructions). `tools/r4_cli_demo.sh` and
  `tools/layer0_precheck.py` stay as they are until `r8_8b.done` (the
  running chain calls both).
- 00:33 sent the coordinator the budget picture (two fidelity jobs, 5.5 GiB,
  vs the 8 GiB prove); coordinator: HOLD #3 at 00:23 (fp-L_combo2_lam0
  started 00:17, before it; nothing refills). 00:35:55 the 8B T128 prove
  (`tio-r8x-d3-cli-prove`) STARTED after 2,366 s of admission wait.
- PR4-16 inventory [COUNTED, `ls` 00:35], NOT deleted (the coordinator asks
  Victor): under `~/zk60-artifacts/token-io/`, all 0700:
  `run-b7_T32-ho00.owner-private` (10-19 04:21 PDT),
  `run-b7_T32-ho00-r5.owner-private` (06:08), `run-b7_T32-r6-ho00-3d3a3b4113bd.owner-private`
  (08:04), `run-llama3_8b_pg_rot1_b7voc0_T32-r7-ho00-ef2b58a0591d.owner-private`
  (09:35), `run-tinyllama_dg_rot1_T128-r8tl-ho00-a5e544c2a5c1.owner-private`
  (15:35) — the five — plus `run-llama3_8b_pg_rot1_b7voc0_T128-r8x-ho00-aca5d59eaa0c.owner-private`
  (created 17:35 PDT by the running r8 binary, which predates PR4-16; the
  r8dgx demo will add one more) and `demo-logs-r6x/` (a private-prompt
  demo's logs). `~/zk60-owner-private/` does not exist yet.
- 00:41 the round-9 chain is staged, NOT launched (it goes after the 8B
  addendum): `tools/r9_chain.sh` (marker `logs/r9_chain.done` = the first
  failing step's number, 0 = all passed) waits for t34 AND `r8_8b.done`,
  then: t34's failures checked to be exactly the expected three
  (`tools/r9_expect.py`, new: the FAILED set must equal the expected set,
  at least one test passing); the working copy checked = manifest_r9A;
  sync T-A2 (= manifest_r9B) -> t35 (cli_tests; exactly the seven pr4_*
  fail) -> sync T-B (= manifest_r9C) -> t36 (token_io module, all pass) ->
  t37 (staged tools applied, pre-check tests) -> b9 (the named CPU binary
  `cli/zk60_token_io.r9.release.bin`, `binaries_r9.sha256`, build note
  `zk60_token_io.r9.BUILD.txt`: command, toolchain rustc/cargo 1.97.1,
  default features (no gpu-cuda), release profile, no rustflags, source =
  manifest_r9C) -> c9 (the CLI capture with that binary: its own `prove`
  and `verify` processes, then the run directory verified in the test with
  the recorder attached; capture
  `~/zk60-artifacts/token-io/captures/tinyllama-t32-L2-dense-pt1-cli-r9`,
  prover-side work tree `~/zk60-owner-private/token-io-cli-capture-r9`) ->
  s13 full suite (need 7.5 / cap 9.5; s12 peaked 7.11) ->
  manifest_final_r9. The capture test gained an optional
  `HL_PB_CLI_BIN` / `HL_PB_CLI_BIN_SHA256` (the named binary as a
  subprocess; the hash is computed by the launcher, so no new hash call
  site enters the census).
- 00:41 8B T128 prove (r8x) at segment 17 / 34, 258.6 s, RSS 8.07 GiB
  (need 8 / cap 10); fp-L_combo2_lam250 (2.5 GiB) admitted beside it at
  00:36 (10.5 of 11.9 GiB).
- 00:44 8B T128 (r8x, b7voc0_T128, r8 binary 6b601c14...) PROVED [MEASURED,
  shared box: one 2.5-3 GiB fidelity job beside it, guard 8 / cap 10]:
  prove 464.7 s, total 501.6 s for 128 tokens = 3.63 / 3.92 s per token
  (8B T32: 6.85 / 8.27 s per token; x0.53 / x0.47 per token); 34
  segments, receipt 928,442,704 B; witness 76.5 s, block load 35.8 s;
  parity bit-exact at 32 layers; whole-run floor 96 bits; VmHWM 8,175 MiB
  (guard peak 7.97 GiB); admission wait 2,366 s. Verify steps follow.
- 00:50 r8x demo complete, every step exit 0 [MEASURED]: verify (publishes
  statement/) 56.4 s verify / 91.7 s total, peak 3.27 GiB; re-check 56.5 /
  89.1 s; owner: decommitted next token 11 = both references (integer 11,
  margin ~0.55; float 11); input-owner confirmed the prompt. (The r8
  binary prints the token in the owner log; PR4-17's 0600 token file is
  round-9 code.) r8dgx demo and the cross-checks follow in the chain.
- 00:50 r8x public-file cross-check (`runs/r8_crosscheck_llama3_8b_pg_rot1_b7voc0_T128_ho00.json`)
  [MEASURED]: decommitted 11 = calibration lane's integer head 11 = R0
  integer 11 = float head on the integer row 11; integer top-2 margin C
  18,135,586; float-head top-2 margin 0.611 logits (the fidelity lane's
  ~0.55 is its own float reference's). r8dgx pre-check exit 0 (clear).
- 00:54 t34 (F-T1 failing first, working copy = manifest_r9A) exit 101 as
  expected [MEASURED: 212.6 s, peak 1.96 GiB, after 2,720 s waiting for the
  heavy lock]; `tools/r9_expect.py`: exactly the expected three FAILED
  (stage-IN miss, block-1 exp miss, endpoint over another prompt / token),
  the stage-OUT control and the honest run passed. What the old prover
  did: the stage-IN lookup miss and the input endpoint sealed over another
  prompt were NOT refused by the prover at all (the run proved; the
  verifier's own checks are a separate matter, not exercised by this
  test); the block-1 exp miss was refused by CS-3 only AFTER the run header
  ("refused (private block: ruling CS-3 ...) only AFTER the run header was
  built"). This is the gap the sealing pass (T-B) closes.
- 01:06 8B T128 (r8dgx, dg_rot1_voc0_T128, r8 binary) PROVED [MEASURED,
  shared box: a 3 GiB fidelity job and a 0.6 GiB gate job beside it]:
  prove 488.6 s, total 529.2 s for 128 tokens = 3.82 / 4.13 s per token;
  34 segments, receipt 928,442,704 B (= b7voc0's: same geometry); witness
  85.2 s, block load 35.6 s; parity bit-exact at 32 layers; floor 96
  bits; VmHWM 8,104 MiB (guard 7.89 GiB); admission wait 390.5 s.
- 01:12 r8dgx demo complete, every step exit 0 [MEASURED]: verify 58.8 s /
  95.1 s total (peak 3.31 GiB); re-check 57.1 / 91.5 s; owner: next token
  11; input-owner confirmed the 128-token prompt. Cross-check
  (`runs/r8_crosscheck_llama3_8b_dg_rot1_voc0_T128_ho00.json`): 11 = lane
  integer head 11 = R0 integer 11 = float head 11; integer top-2 margin C
  121,758,846; float-head margin 3.662 logits (fidelity lane ~3.69).
  01:12:56 `logs/r8_8b.done` = 0. ROUND 8 ADDENDUM complete: 8B T128 per
  token [MEASURED, shared box, not quiesced] b7voc0 3.63 / 3.92 s, dg
  3.82 / 4.13 s (prove / total) vs 8B T32 6.85 / 8.27 s; TinyLlama T128
  1.45 / 1.50 s. New owner-private dirs from the r8 binary (pre-PR4-16):
  `run-llama3_8b_pg_rot1_b7voc0_T128-r8x-ho00-aca5d59eaa0c.owner-private`,
  `run-llama3_8b_dg_rot1_voc0_T128-r8dgx-ho00-ba0c666497f4.owner-private`
  (not deleted).
- 01:13 the 8B addendum SENT to the coordinator (SendMessage). 01:13:35
  ROUND 9 CHAIN LAUNCHED (setsid nohup; `logs/r9_chain.log`, marker
  `logs/r9_chain.done`): t34 expectation re-checked ok; working copy =
  manifest_r9A (changed 0); T-A2 synced (cli.rs stubs + cli_tests.rs) =
  `manifest_r9B.sha256`; t35 queued on the heavy lock.
- 01:15 COORDINATOR (on t34): the old prover not refusing a stage-IN miss
  or an input endpoint over another prompt is an H-1 matter; the question
  is whether the VERIFIER rejects what such a prover produces (else a
  soundness bug). Add early: run the round-8 prover path to completion
  without the sealing check, show `verify` REJECTS naming the failing
  check (expected: stage-IN LogUp; endpoint IO claim); say where a prover
  stops; if any output VERIFIES, stop and report at once.
- 01:17 `token_io/r9v_tests.rs` (new; `#[cfg(test)] mod r9v_tests;` added
  to the working copy's token_io.rs while t35 still waited for the lock):
  V1 t34's exact stage-IN miss (B_in row 1 word 3 + 1, downstream as the
  honest pipeline made it) -> predicted stage IN LogUp; V2 the same miss
  with everything downstream re-derived (R1 #16b's consistent forger) ->
  stage IN LogUp; V3 t34's input endpoint over another prompt -> stage IN
  slot SI_IO; V4 t34's output endpoint over another token -> stage OUT slot
  SO_IOOUT. Each case runs the PLAIN prover (on a build without the
  sealing pass = the round-8 path) and the CHEATING prover (no honest
  refusal, the sealing pass included), lets it finish if it can, verifies
  what it made; a verify Ok PANICS ("A RUN FROM A PROVER WITHOUT THE
  SEALING CHECK VERIFIED"); every rejection must be at the predicted site;
  each case must reach the verifier at least once. Related R1 controls
  already green since round 1: #16b (InLogUp), #10a (SI_IO), #9 (SO_IOOUT),
  all with the cheating prover.
- 01:17 old-code evidence: a snapshot of the working copy (= manifest_r9B +
  r9v; run.rs is the round-8 prover, no sealing pass) at
  `r9v-old/token-io/` (hashline, zkp-core, both kernel crates; diff -rq
  identical to the working copy); `t35v-r9-verifier-oldpath` launched
  (guard cpu 3 / 5 GiB, CARGO_TARGET_DIR = the lane's target, so the chain's
  later T-B sync cannot reach it). The T-B build runs the same file in t36
  (plain prover refused by the seal; cheating prover = the old path).
- 01:30 t35v (round-8 prover code, snapshot r9v-old/) exit 0 [MEASURED:
  236.1 s, peak 2.01 GiB, waited 523.6 s]: NOTHING VERIFIED. 8 of 8 runs (V1-V4
  x plain / cheating prover) FINISHED and were REJECTED by `verify` at the
  predicted site: V1 (t34's exact stage-IN miss) and V2 (the consistent
  forger) at "stage IN H (the LogUp sum claim is part of this opening): pcs
  zk: group 3: <v, c> != combined claim"; V3 (input endpoint over another
  prompt) at "stage IN slot 00 [IN-00 IO-in: token endpoint = supp_T tok
  (whole padded plane)]: sumcheck round 0: s(0) + s(1) != claim"; V4
  (output endpoint over another token; the old plain prover did not refuse
  it either) at "stage OUT slot 10 [OUT-10 IO-out ...]: sumcheck round 0".
  The t34 gap is refusal timing (H-1), not soundness; agrees with REVIEW5
  §2.5 (RV6-8). Reported to the coordinator.
- 01:20 COORDINATOR: REVIEW5 landed (demo-fit on frozen-r7, nothing
  affecting soundness). Fold in: TR6-1 (= PR4-17, input-owner too), TR6-2
  (= PR4-4: stage-IN consistency + every block's CS-3 before the first
  segment), TR6-3 (check the DEFAULT owner directory for a git working tree
  when $HOME is a repo), TR6-4 / TR6-6 (voc0 approval record wording; the
  pre-check's "coming" text), TR6-7 (CLI README: /1-statement runs
  re-check only with the r6 binary).
- 01:30 TR6-3 staged into wip-r9b (copied 01:30:36, after t35 started at
  01:30:19 on the T-A2 working copy, before the chain's T-B sync). FINDING:
  this box's `$HOME` holds a STUB `.git` (`/home/victor/.git`: only
  `info/`, Jun 12; no HEAD / objects / refs: git itself walks past it).
  The TR5-3 (a) rule (any `.git` entry = a working tree) therefore already
  refuses every explicit `--owner-dir` under `$HOME` (it would have refused
  c9's), and TR6-3 as worded would refuse every default. Applied git's own
  rule, to explicit AND default: a `.git` directory holding `HEAD`, or a
  `.git` file starting `gitdir:` (any other `.git` entry counts,
  conservatively); a stub without HEAD does not count. NOT detected:
  GIT_DIR / --git-dir work trees (documented). Tests: TR5-3 (a)'s fixture
  now writes `.git/HEAD`; new `tr6_3_the_default_owner_directory_is_checked_for_a_git_working_tree`
  (repo $HOME refused, worktree-file $HOME refused, stub accepted for
  default and explicit). Flagged to the coordinator for review.
- 01:31 coordinator: V1-V4 accepted (matches REVIEW5); TR6-3 APPROVED as
  built (git's rule, default + explicit, stub accepted and tested);
  document the GIT_DIR / --git-dir gap; do not touch `$HOME/.git`.
- 01:31 TR6-3 failing first on the old code: the same test added to the
  snapshot's (T-A2) cli_tests; `t35w-tr63-failfirst` launched (filter
  `cli_tests::tr6_3` + `cli_tests::tr5_3`; expected: tr6_3 FAILS — the
  default accepted inside a repo `$HOME` — tr5_3_* pass).
- 01:33 TR6-4 (wording only; values unchanged, checked field by field):
  `tools/approval_record.py` named every record after the first one (b7
  T32, calibration lane); now `record` names the export, `written_by`
  says "this export's own token_io/ files and its SHA256SUMS", key
  `token_io_SHA256SUMS_sha256`. The four records written for fidelity-lane
  exports (b7voc0_T32 5367a930 -> 9ccb9962, b7voc0_T128 c995594f ->
  2f91ab30, dg_T128 601bd085 -> 165eab37, tinyllama_T128 916bbcd5 ->
  b42ed9fc; first 8 hex of the file sha256) corrected the same way, each
  with a `wording_corrected` note holding its old file sha256; the voc0_T32
  record's evidence gains the reviewer's independent reproduction of
  expect_statement c3fb8c5b... (TR6-4's "second derivation"). The b7_T32
  record (the calibration lane's own export) unchanged.
- 01:33 TR6-6: `tools/layer0_refusals.json` "fix" now points at the landed
  b7voc0_T32 export and its approval record (was "... is coming");
  checked: the pre-check prints it. The staged r9 demo header says the
  same, and documents the TR6-3 rule and the GIT_DIR / --git-dir gap.
- 01:33 TR6-7: `cli/README.md` (new, at the coordinator's request): the
  binaries with their sha256 (each checked against the file), and which
  binary re-checks which run: schema `/1` runs (r4 / r5 / r6) ONLY with
  `zk60_token_io.r6.release.bin`; schema `/2` runs (r7, r8) with r7 or
  later; the round-9 interface changes.
- 01:34 t35 (PR4 CLI tests failing first, working copy = manifest_r9B + r9v)
  exit 101 as expected [MEASURED: 232.1 s, peak 1.97 GiB, waited 1,003 s];
  `t35-expect`: exactly the seven pr4_* FAILED, 9 passed. Failures as
  designed: PR4-15 the leftover refusal lacks `rm -r`; PR4-16 the default
  under zk60-artifacts; PR4-17 `--prompt` accepted, `--token-out` unknown;
  PR4-4 parity mismatch and extreme input refused only AFTER the header, no
  `seal_chain`. T-B synced at 01:34 (incl. TR6-3 and the example's doc
  header) = `manifest_r9C.sha256` (b666a991...; vs r9B: 9 changed, r9v
  added). t36 (token_io module) STARTED 01:34:13.
- 01:40 t36 (token_io module on the T-B tree, manifest_r9C) exit 0
  [MEASURED: 366.4 s, peak 6.07 GiB]: 61 passed, 0 failed, 9 ignored —
  incl. the seven pr4_* (now green), tr6_3, the five r9_* (every
  inadmissible witness refused BEFORE the header; the honest run proves
  with one header) and both r9v_* (on the sealed build the cheating prover
  = the old path finishes and is rejected at the predicted sites; nothing
  verifies). 01:40 t37: the staged tools applied (layer0_precheck.py
  --prompt-file, its test, r9_cli_demo.sh); pre-check tests 8/8 OK.
  b9 (the named binary) queued. 01:41 `t38-r9v-sealed` queued: r9v again
  with --nocapture on the sealed build, to record each path's outcome.
- 01:44 t35w (TR6-3 failing first, old-code snapshot) exit 101 as expected
  [MEASURED: 221.3 s, peak 2.0 GiB]: tr6_3 FAILED with "REVIEW TR6-3: the
  default owner directory inside a git working tree ($HOME a repository)
  was accepted"; tr5_3_a / tr5_3_b passed on the old code. On the T-B tree
  tr6_3 passes (t36).
- 01:44 HANDBACK FORCED by the harness while the round-9 chain is still
  running: b9 (named binary build) STARTED 01:44:02; then c9 (CLI capture),
  s13 (full suite), manifest_final_r9 run unattended inside
  `tools/r9_chain.sh` (marker `logs/r9_chain.done` = first failing step,
  0 = all passed); `t38-r9v-sealed` queued (marker `logs/t38-r9v-sealed.done`).
  Still owed after those land: record b9 / c9 / s13 / manifest_final_r9;
  freeze `frozen-r9/` from manifest_final_r9; the round-9 report.
- 01:45 b9 exit 0: the named round-9 CPU binary built; b56f1b7152e617e8753c21aa9c77fa5de19862df759081cce514d0766c8d4851 (cli/binaries_r9.sha256; note cli/zk60_token_io.r9.BUILD.txt). c9 (CLI capture) next in the chain.
- 01:45 t38 (r9v, sealed build, --nocapture) exit 0: the PLAIN prover is
  now refused in the sealing pass, before any header, in all four cases
  (V1/V2 "stage IN: the witness's embedding lookup misses", V3 / V4 "the
  input / output token endpoint's sealed plane is not the stage
  witnesses'"); the CHEATING prover (= the old path) finishes and verify
  rejects at the predicted sites (stage IN H LogUp; IN-00; OUT-10).
- 01:45 c9 exit 0 [MEASURED: 22.4 s, guard peak 1.15 GiB]: the CLI-path
  capture with the NAMED binary b56f1b71... as its own processes:
  TinyLlama T32 L = 2 view, `prove` sealed (2 blocks, parity at 2 layers,
  0.59 s) and proved (4 segments, 27,422,816 B, 7.5 s prove / 11.2 s total,
  floor 100 bits), `verify` published the statement (2.3 s / 4.2 s); then
  the run directory read with the CLI's own readers and verified with the
  recorder attached (P-18, no CLI hook; 4.6 s); bundle at
  `~/zk60-artifacts/token-io/captures/tinyllama-t32-L2-dense-pt1-cli-r9/`
  (run.json 42,260 B; stage files 2,551,215 / 3,605,078 / 3,609,108 /
  4,916,549 B; arrays.bin 39,231,584 B; README.md, manifest.json). The
  prover-side work tree (export view, owners' decommitments) stays under
  `~/zk60-owner-private/token-io-cli-capture-r9/`. s13 next.
- 02:58 (coordinator relay) / 03:00 recorded: s13 full suite on the T-B
  tree exit 0 [MEASURED: 770.6 s, peak 6.86 GiB, admission wait 3,524 s]:
  768 passed, 0 failed, 40 ignored over 29 test binaries.
  `manifest_final_r9.sha256` written by the chain: 236 files, list sha256
  b666a991... = manifest_r9C (changed 0); vs final_r8: 9 changed, 2 added.
  `logs/r9_chain.done` = 0.
- 03:01 FROZEN: `frozen-r9/` copied from the working copy and re-hashed:
  236 of 236 match manifest_final_r9, none missing, none extra
  (`frozen-r9.FROZEN.txt`). vs frozen-r7: 12 changed, 3 added, 0
  removed; ONE block/run file, `private_block/run.rs` (round 8, additive:
  the two T128 token-run profile constants, TOKEN_IO_RUN_PROFILES 3 -> 5,
  two run-shape match arms; no existing line changed); the other 14 are
  token-only (token_io.rs, token_io/{capture_tests, cli, cli_tests, load,
  r2_tests, r3_tests, run, stage_in, tests}.rs changed; r9_tests, r9v_tests,
  t128_tests added; examples/zk60_token_io.rs changed). Round 9 complete;
  report sent.

## Round 10 (coordinator ~03:05 UTC 2026-10-20): the presenter demo kit

Victor will show it to investors. (1) `tools/demo_present.sh`: one command,
default 8B T32 b7voc0 + ho00 prompt file, precheck -> prove -> verify ->
owner -> input-owner with plain-language narration, elapsed times and
proof size; options TinyLlama (fast) and 8B T128; guarded, detached, logs
outside the repo. (2) `DEMO_PRESENTER.md`: one page — what is shown, what
each step proves / hides, honest measured numbers, what NOT to claim
(D33's scope only; next-token statement in review; fidelity below the D32
bar; no GPU), five-question Q&A. (3) A TinyLlama dry run, transcript saved.
Frozen-r9 binary b56f1b71...; no prover code changes.

- 03:10 facts gathered: tokenizers on disk (Llama-3:
  local-models/zk60-llama3-8b/tokenizer.json via `tokenizers` 0.21;
  TinyLlama: ~/models/tinyllama-1.1b-chat-fe8a4ea1/tokenizer.model via the
  calibration lane's spm_bpe.py); both ho00 prompts are the opening of the
  Apache License 2.0 text; 8B b7voc0_T32 ho00 next token 11 = ",". The
  TinyLlama fast option = the R2 export pg_rot1_b4_T32_cal128 (+ r2_inputs
  heads), which has NO approval record yet (split layout: embedding in the
  export root, head in r2_inputs; both manifests carry every table's
  sha256). Measured step times: 8B T32 CLI prove 264.5 s (peak 3.39 GiB),
  verifying steps ~80 s (2.8 GiB); TinyLlama T32 prove ~98 s (2.45 GiB),
  verify ~28 s.
- 03:09 tools written (no prover code touched): `tools/demo_decode.py`
  (owner-side id -> text, Llama-3 tokenizer.json / TinyLlama spm_bpe;
  refuses a prompt file not 0600); `tools/approval_record.py` gains a
  split-layout mode (`--emb DIR --head DIR`: each binary table re-hashed
  against the sha256 its own manifest records); the TinyLlama option's
  approval record `approvals/token_profile_approval_pg_rot1_b4_T32_cal128.json`
  ("coordinator, round-10 instruction: the presenter demo's TinyLlama
  option"; export profile 826f7641... = the calibration ledger's; 5 table
  files checked; pins from `zk60_token_io profile`, r9 binary, over the
  verifier copy `~/zk60-artifacts/token-io/demo-present/verifier-export-pg_rot1_b4_T32_cal128`:
  identity 78ccaba5..., token profile 5857be9d...; scope note: b4 is
  outside D33). `tools/demo_present.sh` (one command; 8b-t32 default /
  tinyllama / 8b-t128; checks the r9 binary's sha256; pins from the
  approval record; ho00 written to a 0600 prompt file and decoded for the
  owner; pre-check -> prove -> verify (public copy) -> owner (token to a
  0600 file, decoded) -> input-owner; plain-language lines, times, proof
  size, an inference comparison and a D33 footnote; detaches itself
  (setsid nohup) and follows its transcript; every heavy step guarded;
  everything outside the repo: transcript / logs / prompt under
  `~/zk60-owner-private/token-io/demo-present/<TAG>/` (0700), the proof under
  `~/zk60-artifacts/token-io/demo-present/run-<TAG>`).
  `DEMO_PRESENTER.md` drafted (TinyLlama cells filled from the dry run).
- 03:09 TinyLlama dry run launched (TAG tinyllama-dryrun-r10); its prove
  step waits for the heavy lock (another lane's build holds it).
- 03:21 TinyLlama DRY RUN 1 (TAG tinyllama-dryrun-r10) exit 0 [MEASURED]:
  every step passed; prove 71.5 s (85.9 s with loading; sealing pass 7.5 s),
  receipt 255,258,816 B, 24 segments, floor 97; verify 10.6 s; owner opened
  token 29914 "/" (the prompt ends "http://www.apache.org"); input-owner
  confirmed; work 132.1 s (prove 85.9, verify 16.4, owner 14.8, input-owner
  15.1; peaks <= 1.26 GiB) after a 551.6 s guard wait. Then the script:
  summary splits work from waiting; the 8b-t128 option uses the dg export
  (best 8B fidelity, own approval record, clear pre-check; same speed).
- 03:47 DRY RUN 2 on the final script (TAG tinyllama-dryrun-r10b) exit 0:
  prove 68 s (81 s), verify 10 s, token "/", 130 s of work (1,538 s wall,
  1,408 s waiting for the guard). Transcript (outside the repo):
  `~/zk60-owner-private/token-io/demo-present/tinyllama-dryrun-r10b/transcript.txt`.
  Header estimates updated: 8B T32 ~9-10 min, 8B T128 ~15-16 min [MODEL:
  r7 / r8 step times + the round-9 sealing pass, ~+20% from the TinyLlama
  ratio]. `DEMO_PRESENTER.md` final (95 lines). Round 10 complete.
- 03:55 coordinator: round 10 ACCEPTED; the TinyLlama b4 approval record
  CONFIRMED for demo use (not a privacy acceptance; b4 outside D33); keep
  8b-t128 on dg. Edit made: DEMO_PRESENTER.md's speed line now says reaching
  50 needs the whole prover on the GPU near hardware limits plus some design
  changes (speed plan §5). Round 10 closed; stopping.

## Round 11 (coordinator ~05:05 UTC 2026-10-20): demo polish (REVIEW6)

REVIEW6: frozen-r9 demo-fit, nothing affecting soundness or leaks. Items:
TR7-1 (ratios labelled by what they cover; the reviewer's measured r9 8B T32
288.7 s / 36.9 s sealing / 208.6 s prove), TR7-4 (wording: "never given",
D33's exact scope in Q4, "the integer model's next word"), TR7-3
(`demo_decode.py --id-file`), TR7-5 (test: the CLI's copied stage-shape
derivation = the library's at every registered profile), TR7-6 (`owner`
refuses an existing token-out before re-verifying), TR7-7 (a looser
pre-existing owner base: refuse or tighten; say which), TR7-2 (dry-run both
8B options through demo_present.sh), full suite, manifest, freeze r11.

- 05:18 T-A (failing first; manifest_r11A 03807bce...): cli.rs gains a
  test-only re-verification counter (`check_runs()`, bumped at check_run's
  start) and a STUB `cli_stage_shape` (returns the run's shape);
  `token_io/r11_tests.rs` (new): at every registered profile, layers with
  none / the score shift / every non-window field at once / tn alone /
  ceps alone own (admissible neighbours probed at that shape), CLI
  derivation == `TokenRunStatement::stage_shape(k)`, and every own layer
  changes the shape (non-vacuity); cli_tests: `tr7_6_...` (existing
  explicit and default token files refused with NO re-verification started,
  untouched; a fresh path re-verifies once) and `tr7_7_...` (a pre-existing
  base at 0755 / 0750 ends 0700 at both levels; a base that is a file is
  refused).
- 05:21 t39 exit 101 as designed [MEASURED 212.9 s, peak 1.98 GiB]: exactly
  the 3 new tests FAILED — TR7-5 at the rung's layer 1 (stub), TR7-7 "the
  pre-existing base ... was left looser than 0700", TR7-6 "the owner
  re-verified BEFORE refusing the existing --token-out".
- 05:20 TR7-3 test-first (Python): `tools/test_demo_decode.py` (new) FAILED
  on the old tool (--id-file unknown; the prompt-file control passed), then
  `demo_decode.py --id-file` (exactly one id, 0600 required) -> 2/2 OK.
  `demo_present.sh` reads the answer through `--id-file $OD/next_token`
  (the id never on a command line); TR7-4 narration ("was never given the
  prompt or the answer (*)", "(*) and the proof is designed so the verifier
  learns nothing about them ...", "the integer model's next word"); the
  8b-t128 prove declared need 8.5 / cap 10 (r8 peak 7.97 GiB + margin).
  DEMO_PRESENTER.md: TR7-1 ratios labelled (whole next-word proof 8B T32
  ~135x prove / ~186x with loading on the r9 binary [the reviewer's run];
  8B T128 ~87-94x [r8 binary]; 32 layers alone, quiet box ~100x / ~77x),
  the ~320 s estimate replaced by 288.7 s; TR7-4 (verifier "never given";
  "exact integer version"; Q4 names D33's scope: pg_rot1, R7 build,
  extension pending Victor, the TinyLlama option b4 on r9 code outside).
- 05:22 T-B synced (manifest_r11B): `cli_stage_shape` real (as
  `TokenRunStatement::stage_shape`: the run's shape when the layer's
  calibration equals the run's, else with_layer_calibration) and used by
  `seal_chain`; TR7-6: `owner_inner` resolves the token path FIRST and
  refuses an existing one before `check_run` (create-new still closes the
  race); TR7-7: CHOSE TIGHTEN — `tighten_to_0700` on both base levels
  after DirBuilder (a looser pre-existing directory set to 0700, printed as
  `{"event":"owner-base-tightened","path":...,"was":"755","now":"700"}`;
  not a directory, or not tightenable, refused). Example doc header updated.
  t40 (token_io module) launched.
- 05:23 `tools/r11_chain.sh` launched (marker `logs/r11_chain.done`: 0, or
  40 / 14 / 11 for the failing step): waits for t40, then s14 (full suite,
  need 7.5 / cap 9.5), then b11 (the named r11 CPU binary
  `cli/zk60_token_io.r11.release.bin`, `binaries_r11.sha256`,
  `zk60_token_io.r11.BUILD.txt`), manifest_r11C. HANDBACK FORCED by the
  harness here. Still owed after the chain: switch demo_present.sh to the
  r11 binary (BIN / BIN_SHA / "round-11" wording), TR7-2 dry runs of
  8b-t32 and 8b-t128 through demo_present.sh (transcripts under
  ~/zk60-owner-private/token-io/demo-present/), DEMO_PRESENTER.md's 8B
  rows from those runs, manifest_final_r11, frozen-r11/, the report.
- 06:56 (coordinator relay) r11_chain.done = 0: t40 (token_io module, T-B)
  exit 0, 64 passed / 0 failed / 9 ignored [353.2 s, peak 6.11 GiB]; s14
  full suite exit 0, 771 passed / 0 failed / 40 ignored over 29 test
  binaries [668.6 s, peak 6.89 GiB, admission wait 3,014 s]; b11: the named
  round-11 CPU binary `cli/zk60_token_io.r11.release.bin` sha256
  0c9f247c0f91162177f8ed90285f8664cc4dd36ebd8934dc650804bafe5c2c6b
  (`cli/binaries_r11.sha256`, `cli/zk60_token_io.r11.BUILD.txt`; the cargo
  build took 13 s: s14's `cargo test --release` had already rebuilt the
  release example from the same source); manifest_r11C = r11B (d8075d76...).
- 06:57 demo_present.sh pinned to the r11 binary (BIN / BIN_SHA / "frozen
  round-11 CPU build"; the 8B T32 estimate from the reviewer's 288.7 s).
  TR7-2 dry runs launched (`tools/r11_dryruns.sh`, marker
  `logs/r11_dryruns.done` = "<8b-t32 exit> <8b-t128 exit>"). The wrapper
  sent each presenter window's copy to logs/ inside the repo (a duplicate of
  the transcript, prompt text included): moved at once to the run's 0700
  folder as `window.log` (the 8b-t128 one moved by a watcher when it
  appears); nothing of the runs stays in the repo.
- 07:31 manifest_final_r11 (237 files, list sha256 d8075d76... = r11C) and
  FROZEN `frozen-r11/`: 237 of 237 re-hashed match, none missing, none extra
  (`frozen-r11.FROZEN.txt`). vs frozen-r9: 4 changed + 1 added, all
  token-only (example doc header, token_io.rs mod line, cli.rs,
  cli_tests.rs, r11_tests.rs); no block / run file changed since frozen-r9.
- 07:29 the 8b-t32 dry run's prove waits for admission (need 4.5; budget
  10.5 of 11.9 held by gate-r9 and fidelity light jobs) since 06:57.
- 07:57 the first 8b-t32 dry run STOPPED: its prove guard refused (exit
  70) after the default 1-h wait (fidelity's 8B stack eval at 5 GiB + gate
  light jobs filled the budget); nothing proved. The wrapper then started
  8b-t128 (prove need 8.5, 1-h wait), which cannot be stopped here (no
  kill); it waits for the heavy lock / budget and will refuse by ~08:58
  unless room opens. COORDINATOR (07:58): relaunch 8b-t32 with a >= 4-h
  wait (gate lane held until its marker appears); run 8b-t128 only when
  fidelity's four 8B stack runs are done or the guard shows room, same long
  wait; declarations stay at measured peaks.
- 07:59 8b-t32 RELAUNCHED: TAG 8b-t32-dryrun-r11b, WAIT_SECS 14400,
  window output in the private demo-present folder; marker
  `~/zk60-owner-private/token-io/demo-present/8b-t32-dryrun-r11b/demo.done`
  (sent to the coordinator).
- 08:00 HANDBACK FORCED by the harness while the 8B dry runs wait for
  admission (8b-t32-dryrun-r11b, 4-h wait; the first 8b-t128 with a 1-h
  wait, which refuses by ~08:58 unless room opens). Owed when resumed:
  record the 8b-t32 run; relaunch 8b-t128 (TAG 8b-t128-dryrun-r11b,
  WAIT_SECS 14400) when fidelity's 8B stack runs are done or the guard
  shows room, unless the first attempt ran; put the measured 8B rows on
  DEMO_PRESENTER.md; send the round-11 report.
- 09:01 (coordinator relay; recorded from the runs' own logs) TR7-2 DONE,
  both through `demo_present.sh` on the r11 binary, every step exit 0,
  token 11 "," at both lengths [MEASURED, n = 1]:
  * 8b-t128 (TAG 8b-t128-dryrun-r11, the first attempt; admitted after
    2,326 s when fidelity's 5 GiB job ended; one 2 GiB fidelity light job
    beside it): prove 437.3 s / 568.5 s with loading (sealing pass 90.6 s),
    receipt 928,442,704 B, floor 96, peak 7.99 GiB (VmHWM 8,213 MiB, within
    the 8.5 / 10 declaration); verify 55.0 s (87.6 s total); owner 89.8 s,
    input-owner 88.9 s; 839 s of work.
  * 8b-t32 (TAG 8b-t32-dryrun-r11b, 4-h wait; admitted after 3,052 s; no
    other guarded job during the prove): prove 216.8 s / 295.8 s (sealing
    36.3 s), receipt 471,285,072 B, floor 97, peak 3.39 GiB; verify 49.8 s
    (81.4 s total); owner 78.8 s, input-owner 78.3 s; 538 s of work.
  DEMO_PRESENTER.md: the 8B columns are these runs; ratios [COUNTED] vs the
  8-bit engine (1.55 s / 5.6 s): whole next-word proof ~140x (prove) to
  ~191x (with loading) at 32 tokens, ~78x to ~102x at 128; 32 layers alone,
  quiet box ~100x / ~77x; verify 50 / 55 s; peaks 3.4 / 8.0 GiB; 0.11 /
  0.23 tokens/s; the reviewer's r9 288.7 s agrees within 3%. demo_present.sh
  header times now measured. Round 11 complete.

## Round 12 (coordinator, 2026-10-21): the classifier verdict stage — design first

D38 (Shieldstral-1.0-3B, text only; statement z_yes − z_no > c; disclosure = verdict +
model + policy). D36 extended to frozen-r11 / 0c9f247c... Paper first; the adversarial check
follows (routed by the coordinator); implementation after it, on frozen-r11, test-first.

- 02:41 DESIGN v1 written: `classifier/DESIGN_CLASSIFIER.md`.
  * Input: stage IN plus one template clause with its own fresh coefficient,
    μ_tmpl·π(t)·(tok(t) − κ(t)), generalising BOS. The endpoint holds the whole plane;
    the owner check is extended to the template. n is public (public-row variant; T in a
    profile class, since blocks already run tokens < t_pad). Tokenisation-boundary stability
    is an open check item. Hidden length is sketched via D26's selector.
  * Output: stage OUT-C. Final norm (tn 10 at width 3072), then ONE margin slot MRG,
    Σ y·w_Δ − σΣ λ·256^k = σb + c, with w_Δ = m_yes W'_yes − m_no W'_no public and tied.
    5 byte limbs (window 40 bits derived, |Δ| ≤ 2^38.56). b is PUBLIC and absorbed by the
    statement transcript; no output endpoint. Soundness via the integer identity, which is
    complete incl. the tie (= not flagged).
  * Leaks: only b. Rule O-1: one threshold per (content, policy), since k thresholds
    reveal k bits. The refusal channel as D20 / D34.
  * Binding: RECOMMEND the input endpoint root + the input-owner decommitment + public
    re-tokenisation; this needs a D23 amendment (Victor). A plain hash in the statement is
    rejected (unsound: unchecked). The in-circuit hash (D18-B) is the end state.
  * F6 sketch: counted with the layout replica (native ladder method) on Shieldstral's
    padded domains, `classifier/f6_count.py` / `.json`. Gain 2.1–4.9x where
    npow2(n+1) < npow2(n+91) (e.g. n = 32 / 48 / 64 / 200), 1.0x at n = 128 / 256. Verifier:
    a template K/V cache verified once per (model, template). Gate questions G1–G5.
  * Test-first plan R-C0 / R-C1 / R-C2. CLI: new classify-* subcommands (the frozen
    next-token commands stay byte-identical).
- Waiting for the adversarial check (no code this round until it returns).
- 03:06 COORDINATOR: the adversarial check landed (`classifier/check/CHECK.md`):
  buildable with fixes. The margin identity and b's binding hold. HIGH C-1 (lone-space
  boundary, 9/24) and C-2 (control-token injection under the HF path) were shown with the real
  tokenizer. Write DESIGN v2 (B-1, B-2, B-3; difference-row option; minor fixes; F6
  corrections; seeded randomness as an option only); leave the ruling sections (B-4/5/6/8)
  as marked options; start the R-C0 Python reference for the ruling-free parts.
- 03:06 DESIGN v2 written (`classifier/DESIGN_CLASSIFIER.md`; v1 kept as
  `DESIGN_CLASSIFIER.v1.md`, f9fe043f...):
  * B-1 split adopted: prefix to ':' (84 ids) ‖ tekken.encode(' ' + content) ‖ [/INST].
  * B-2: the tekken plain-text encoder pinned by digest, plus an in-circuit ctl column
    (β²·ctl) in the stage-IN tuple; c(t) = ctl(κ(t)) at template positions, 0 at content.
  * B-3: the verifier re-derives w_Δ, s_Δ, the yes/no ids and c and compares; the int16
    difference row is ADOPTED (B_Δ 2^33.57, L 5; the two-row form recorded with a
    min/max m ≥ 2^-4 door).
  * Minor fixes: c = ⌊θ/κ⌋ exact; Ceps < 2^40; the |w_Δ| typo.
  * F6 gains corrected (2.00 / 4.13 / 2.06 / ~1.93–2.00×); the prefix guarantee moves into
    the cache; P0 is a bound RoPE offset.
  * Option S (seeded endpoint randomness, a 32-byte opening) written up for the security
    owner, not adopted.
  * Marked [RULING PENDING]: B-4 refusal rule, B-5 n public (and the hidden-length variant
    now needs in-circuit length binding), B-6 policy list, B-8 D23 text incl. D39 anchoring
    and transferability. B-7 is recorded by the coordinator.
- 03:06 R-C0 (`classifier/rc0/`), test-first: test_classifier_ref.py written
  first, FAILED (no module), then classifier_ref.py -> 20 / 20 OK [RAN, about 3 s]:
  * margin: honest b = 0/1, tie, Δ = c ± 1, extreme |Δ| = B_Δ, L = 5 derived for both forms;
    a flipped b is refused by the byte lookups and accepted without them; no 5-byte value
    flips; a non-zero limb pad is refused (accepted without the pad clause); a proof for one
    b fails under the other; the transcript seed absorbs b; the two-row form and its ratio
    door;
  * door: a swapped w_Δ with a self-made digest is refused (a trusting verifier accepts it);
    yes/no ids and c come from the profile;
  * template clause: a changed id is refused; the shared-coefficient cancellation is ACCEPTED,
    the fresh coefficient refuses it; a content control id is refused with the ctl column and
    accepted without it; template control ids are fine;
  * tokenizer: the B-1 split equals Mistral's reference on 67/67 contents; prefix 84 ids,
    last piece '>:'; suffix [4]; content ids always ≥ 1000; the lone-space literal prefix
    (85) is unstable; yes 13059 / no 2649. Pinned ids are in rc0/template_ids.json.
  * Owed: T < T_pad pad rows (with R-C1) and the ruling-dependent parts.

## Round 12, part 2 (coordinator): R-C1 in Rust on frozen-r11 — the ruling-independent parts

Margin slot (int16 row, 5 limbs), public verdict in the transcript, template clause, ctl
column, B-3 door, classify-* CLI; rulings behind named switches at the recommended
defaults (n public, fixed policy list, endpoint-root binding, fail-closed); next-token
commands byte-identical. Product update (D37 revised): N category proofs per item, both
outcomes published -> design addendum §12 (v2.1): linking N proofs = N decommitments over
the same content under option R, or ONE (content, seed) under option S. Native
interface for Shieldstral noted (model pin 003ec7e2..., tied tensor 67a138c1...; five
statement fields; T128 fits the laptop, so content <= ~40 tokens at P0 = 84) for R-C2.

- 03:28 code written (new files, plus additive lines in three pinned files):
  * private_block/run.rs: RUN_PROFILE_CLASSIFY_RUNG_TC (65 chars, = the token rung's length),
    CLASSIFY_RUN_PROFILES, and its rung_tc arm.
  * token_io.rs: four production mod lines and one test mod line.
  * New files: token_io/classify.rs (ruling switches; policy registry with the rung dev
    policy and Shieldstral's card policy, 84 pinned ids; ClassifierTables; the
    ClassifierProfile door; ClassifyRunStatement whose transcript absorbs the verdict;
    whole-run figure), stage_in_c.rs (fork of stage_in plus the template clause with its
    own mu and the β²·ctl column), stage_out_c.rs (final norm; margin limbs in pad entries
    32..37 of the isqrt-limb plane; PD private slot Σ y·w_Δ hosted by LZC with host term
    ν(σ g limb + u0(b + c)); no Vo domain, no output endpoint; seal_check),
    classify_run.rs (sealing pass, prove, verify, pipeline, owner check), and
    classify_tests.rs (R-C1: honest runs at both verdicts and the tie; other-verdict
    refusal; four cheating-prover forgeries each refused at its site and refused before the
    header by the honest prover; door; switches).
  * Note on test-first: R-C1's tests mirror the R-C0 forgery vectors written test-first in
    round 12 part 1; the Rust tests and code were written in the same step, before any
    compile.
- 03:28 cargo check: one error in classify.rs (temporary), then one in the tests
  (borrow), both fixed. r12-t1 (classify_tests) launched. (A label clash with an old
  'c1-check' log in logs/ made my first waiter return early; round-12 jobs now use r12-*
  names.)

- 03:39 **D41 (chunks) folded into the design:** DESIGN_CLASSIFIER.md §13 (v2.2).
  * Split rule: encode the whole content once; chunk size per category `T − P0 − S`, so
    every chunk proof sits at the profile's T. The card template gives 43 / 171 / 427 at
    T128 / T256 / T512 [COUNTED].
  * Overlap: public, one per deployment profile. The last chunk is end-aligned. Short
    content is refused (route noted).
  * B-1 at a cut: the input is defined on ids (prefix ‖ c[a:b] ‖ suffix). A mid-content
    chunk has no leading-space convention; template pinning and the control-id column
    still hold. The quality question goes to F11.
  * Linking: L-R bundle now (content plus one endpoint decommitment per (category,
    chunk); ~10.8 MB for 3 × 40 [MODEL]); L-S seed later.
  * Label: OR over the chunks, fail-closed. The leak is the flagged range and N.
- 03:45 **R-C1 code, chunk layer and CLI (not yet compiled; both test jobs queued on the
  heavy lock, held by other lanes):**
  * classify.rs: CHUNK_OVERLAPS (rung: 4), ChunkPlan, chunk_ranges, ChunkRef.
    ClassifyRunStatement::new_chunk derives the range; the transcript absorbs
    `classify-chunk`; the profile text names the chunk size and overlap.
  * classify_cli.rs (new): prove (whole content, `--chunk J`, the sealing chain with
    parity), verify (B-3: the canonical statement is re-rendered from the verifier's own
    inputs byte for byte, then the segments are verified and the statement published),
    input-owner (the chunk's slice of the whole content), label (OR over verified chunk
    runs, fail-closed). Every refusal prints the fail-closed app-outcome line.
  * classify_cli_tests.rs (new): e2e at both verdicts (w / −w); refusals (other tables,
    a consistently flipped verdict, a tampered segment, `--content`, unknown policy,
    control id before any header, wrong length); the tables loader; chunks (27 ids →
    [0,23) + [4,27): prove, verify, owner, label; fail-closed on a missing, repeated or
    tampered chunk; a re-labelled chunk refused).
  * classify_tests.rs gains two chunk tests.
  * examples/zk60_classify.rs (new).
  * Additive line in pinned private_block.rs (pub use of the four commands); one more
    production mod line and one test mod line in token_io.rs.
  * Jobs: r12-t1-classify (classify_tests) and r12-t2-cli (classify_cli_tests).
- 04:48 **r12-t1-classify ran:** the tree compiled, including the CLI and chunk code, with no
  errors. 10 of 12 passed, all [MEASURED, logs/r12-t1-classify.log]:
  * every forgery: refused by the verifier at its predicted site, and by the honest prover
    before the header;
  * the tie (Δ = c = 5,269,429: verdict 0);
  * the door, and the switches;
  * both D41 chunk tests (chunk 1 of 2 [4, 27) proves, verifies and owner-checks; read as
    chunk 0 or under another total, the wire refuses "this segment belongs to another
    run"; index 2 is refused at the door).
  * Stage OUT-C layout [COUNTED]: A 76 rows, H 38 rows at 2^12 (466,944 elements); margin
    window 34 bits, 5 limbs.
  * The two failures are a FIXTURE property, not a code fault: with c = 0 every generic
    content had a positive margin, because the synthetic blocks keep the last row near the
    fixed suffix token's. Fix: `both_verdicts` registers a test policy with c = the least
    observed margin (as the tie test does), giving one content per verdict. Re-run queued
    (r12-t3-classify) behind r12-t2-cli; the heavy lock is held by another lane's
    r12-t2-run.
- 05:05 **R-C1 green** [MEASURED, logs/r12-t2-cli.log, logs/r12-t3-classify.log]:
  * classify_cli_tests 6 / 6 on the first run: e2e at verdicts [0, 1]; the B-3 door
    (other margin vector), a consistently flipped verdict, a tampered segment; `--content`
    exit 2; unknown policy; control id before any header; wrong length; existing
    directory; the tables loader; D41 chunks (27 ids → [0, 23) + [4, 27), proved,
    verified, owner-checked, labelled; fail-closed on missing, repeated and tampered
    chunks; a re-labelled chunk refused); the aggregation rule.
  * classify_tests 12 / 12 after the fixture fix. Honest rung runs: verdict 0 at margin
    5,214,444 and verdict 1 at 5,269,429 under c = 5,214,444; 4 segments
    [1,224,328; 7,421,464; 7,421,464; 2,489,016] B; floor 93 bits.
  * Pinned files against frozen-r11: 0 lines removed, 27 added
    (classifier/rc1_pinned_files_additive.diff).
  * manifest_r12B: 245 files (list sha256 edbffc75…) vs manifest_final_r11: 3 changed
    (private_block.rs, run.rs, token_io.rs; additive only), 8 added (examples/zk60_classify.rs
    and seven token_io/classify* / stage_*_c files). No block or run relation file changed.
- 05:05 freeze chain tools/r12_chain.sh launched (s15 full suite, then the b12 zk60_classify
  binary, then manifest_r12C).
- 05:30 coordinator: tio-s15-suite (7.5 GiB) took the heavy lock before budget admission and
  holds it until the fidelity 5 GiB job ends. I can't stop it by my own means (setsid launch;
  the guard has no cancel; no signals), so it is left running; answered via SendMessage. Rule
  from now on: every launch polls `zk60_resource_guard.py check` until "OK to start now"
  before `run` (r8_stack.sh pre() pattern). The chain's b12 build step (need 3 GiB) still
  runs the old way; the running script is not edited.

## 2026-10-26 (resumed after the usage stop)

- 06:32 (10-21) the chain's s15 full suite exited 101 [MEASURED, logs/s15-suite.log: 638
  passed, 6 failed, 40 ignored; 979 s; peak 6.63 GiB]. The b12 build never ran.
- 17:33 cause: the six failures are the REGISTRY GATES, which did not yet know the new
  classifier run profile and its hash and generator sites. They are not code faults:
  * s24 profile coverage;
  * s25: the hash-input census; the call-kind table (classify.rs's 7 `blake3::Hasher::new(`
    sites); the generator scan (a 7th `ZkRng::from_os` site, `prove_classify_run_with`);
    the twelve-key registry count;
  * s33 printable registry.
- Fix, registered the way the token profiles were, with the classifier's own list:
  * classify.rs (cfg(test)): `registered_classify_runs()` and
    `census_classify_statement()`;
  * s24 / s33: the classifier run profile in the covered lists;
  * s25:
    - the call-kind row CL1-CL7 (the table grows 20 → 21);
    - generator sites 6 → 7, plus `token_io/classify_run.rs` in the list;
    - the prover-body check for `prove_classify_run_with`;
    - on-path generators 5 → 6;
    - the registry count;
    - `kinds_of_classify`: the token census with IN-C / OUT-C, ONE endpoint, the
      classifier header's two labels (`classify-verdict` 1 B, `classify-chunk` 56 B,
      declared beside the shared label table so no other profile's length set moves),
      and CL1-CL7.
  * The census found NO undeclared equal-length pair at the classifier profile [MEASURED,
    r12-t5].
- 17:42 r12-t5 (registry + classifier tests): 49 / 50; the last is a second generator count
  (5 → 6), fixed; r12-t6 re-run launched (pre-check, then guard).
- cli/README.md: "The classifier CLI" section written for Astra's A3: commands, arguments,
  files, the JSON-line output contract per event, exit codes, the statement's fields, and
  how an app drives it (per category × chunk: prove, verify, label; fail-closed).
- 17:55 r12-t6 (s24 / s25 / s33): 32 / 32 passed [MEASURED; 369 s, peak 2.44 GiB]. With
  r12-t5's 18 / 18 classifier tests (classify_tests 12, classify_cli_tests 6), all 50 are
  green.
- 17:56 coordinator: Sol's native R12 proofs hold a window. No guarded cpu or build job may be
  declared above 2.5 GiB until "native window released", so the full suite waits.
- Prepared for the freeze:
  * tools/r12_chain.sh (re-run form): the pre-check before each guarded step; suite s16;
    manifest_r12B2 (r12B of 10-21 kept); marker logs/r12_chain2.done.
  * tools/r12_freeze.py: computes the changes against frozen-r11 and writes
    classifier/rc1_changed_files_vs_r11.diff.
  * Computed check [COUNTED, the tree now, list sha256 f2436b15…]: 6 changed, 8 added.
    Production files insert-only: private_block.rs −0 +2, run.rs −0 +12, token_io.rs
    −0 +13. Registry tests: s24 −0 +4, s33 −0 +2, s25 −5 +142. The 5 removed lines are
    s25's counts and the call-site table length. The claim "removed lines only in registry
    test files" HOLDS.
- 17:56 capture hooks (gate round 16, §4 subset), written in staging and applied to a scratch
  COPY of the tree, so the tree stays at the freeze candidate. The changes:
  * run_capture.rs, insert-only (0 lines removed, +564):
    - ClassifyFacts and RunHeader.classify;
    - the header re-check absorbs `classify-verdict` / `classify-chunk`;
    - classifier stage branches (IN-C / BLOCK / OUT-C replay);
    - the classifier stage and run writers;
    - schema `hashline-native-capture/7-classify-run`;
    - the classifier source pins, for classifier bundles only;
    - 30 new allow-list keys.
  * stage_in_c.rs / stage_out_c.rs: start_slot; the checkpoint + mask / pcs wrappers on M,
    A, H and E-token-in / B-out; capture_planes (OUT-C roles A-out / H-out / B-out /
    "none").
  * classify_run.rs: stage_begin_stage / stage_end / the boundary pcs / run_accepted.
  * classify.rs: capture_header and binding.
  * New classify_capture_tests.rs: 4 fast tests and the env-driven
    capture_a_classify_rung_run.
  * One line each in run.rs / token_io/run.rs (`classify: None`) and token_io.rs (the
    module).
  * Test job r12-c1-copy (declared 2.5 GiB, inside the window rule).
- 18:14 coordinator: native window released. Freeze chain re-run launched (tools/r12_chain.sh:
  pre-check, s16 at need 7.5 / cap 9.5 from s15's 6.63 GiB peak, then the b12 build, then
  manifest_r12C; marker logs/r12_chain2.done). manifest_r12B2 = list sha256 f2436b15….
- 18:16 r12-c1-copy (the capture hooks in the scratch copy): 4 / 4 passed on the first
  compile [MEASURED, logs/r12-c1-copy.log]:
  * the rung L=2 verdict-1 bundle is self-consistent: run.json 44,183 B, stage files
    [4,732,027; 24,029,485; 24,029,113; 8,370,244] B;
  * D41 chunk 1 of 2 [4, 27) at the tie is captured (arrays.bin 9.08 MB);
  * the hooks are inert on the prover, and the run verifies the same with and without a
    recorder;
  * a tampered run and a run read as verdict 0 are refused, and no bundle is written.
  The shared-recorder regression (token capture + run capture tests) runs after the suite,
  so it does not compete with the suite's admission.
- 18:16 s16 started (guard admitted after 122 s on the heavy lock).
- 18:20 coordinator, about the base: native R12 is frozen by Sol (tree 1e406781…, D24 review
  pending). **R-C1 sits on native R8** (the round-7 rebase; my lane rounds 8–12 did not move
  the native base). Rebase probe, built in scratch (`tio-r12` = the R-C1 tree + capture hooks
  + native R8→R12):
  * 37 native files changed; 31 copied as frozen; 6 overlap (private_block.rs, run.rs,
    run_capture.rs, s24_tests, s25_tests, trained_block.rs), merged with diff3;
  * 3 conflicts, all adjacency (both sides inserted run profiles, source-pin entries or
    call-site rows). Resolved as keep-both plus the summed array lengths (OWN_SOURCE_FILES
    24 = 24 entries; CALL_SITES 22 = 22 rows).
  * Compile and tests wait until after the chain and the scheduling holds.
- 18:23 coordinator scheduling, both acknowledged by SendMessage:
  * (a) after S16, no new hand-run guarded job until a `sol-` job starts or 3 min pass. The
    chain's own b12 step may race Sol's waiting job; the guard polls each second, so Sol is
    likely first.
  * (b) the D42 guard-swap window: no hand-run guarded job until "S3 WINDOW CLOSED".
    Remaining chain: b12 (seconds to minutes), then unguarded seconds; natural end about
    18:35. No HOLD file in the chain.
- 18:32 **ROUND 12 R-C1 FROZEN** (frozen-r12.FROZEN.txt):
  * s16 [MEASURED]: exit 0, 789 passed, 0 failed, 40 ignored, 29 test binaries; 898.5 s;
    peak 6.77 GiB.
  * Binary cli/zk60_classify.r12.release.bin, sha256 04036e269a5c…; build note
    zk60_classify.r12.BUILD.txt.
  * manifest_final_r12 = r12C = r12B2: 245 files, list sha256 f2436b15…. frozen-r12/: 245 of
    245 re-hashed match, none missing, none extra.
  * vs frozen-r11: 6 changed (production files insert-only; the registry test s25 loses 5
    count lines) and 8 added; diff in classifier/rc1_changed_files_vs_r11.diff.
  * Native base R8 (rebase to R12 probed in scratch). cli/README.md binaries table gains the
    r12 classifier binary.
- 18:34 freeze reported to the coordinator (SendMessage). Capture hooks applied to the working
  tree (tools: scratchpad apply script; originals checked first). Every hooked file is byte
  for byte the scratch copy that passed r12-c1-copy. Tree test batch and rung captures
  (tools/r12_capture.sh: pre-check then guard; t4 = token_io::classify + token capture +
  run_capture tests; then 7 captures to ~/zk60-artifacts/token-io/captures/classify-rung-*)
  wait for "S3 WINDOW CLOSED" (the D42 guard swap).
- 19:02 coordinator: S3 window closed (new guard 87138bda…: a job waits for admission before
  taking the heavy lock; the pre-check is optional). Launched:
  * tools/r12_capture.sh (t4 tree batch with the hooks, then 7 rung captures);
  * tools/r12_probe_r12.sh: the rebase probe tio-r12's FULL suite, --no-fail-fast, need
    7.5 / cap 9.5 from s16's 6.77 GiB.
- 19:07 **the gate's capture hooks (§4 minimal subset) are GREEN on the tree** (R-C1 + hooks,
  native R8) [MEASURED]:
  * r12-t4 tree batch: 40 passed, 0 failed, 13 ignored (classify incl. the 4 capture tests;
    the token capture and run_capture tests unchanged).
  * 7 rung captures in ~/zk60-artifacts/token-io/captures/, schema 7-classify-run, public
    tables with values: classify-rung-L1-{v0,v1,vtie} (~21.3 MB), classify-rung-L2-{v0,v1,vtie}
    (~31.9 MB), classify-rung-L2-v1-chunk1o27 (D41 [4, 27)). Each 2–4 s, peak 0.19 GiB, 56
    source pins (the classifier's four included).
  * Reported to the coordinator.
- 19:07 R12 probe first suite: 1 compile error. R12's `Provenance.rope_scaling` (F1) was
  missing in token_io/load.rs; the same field went into r2_tests / capture_tests. Fixed in the
  probe with `ex.rope_scaling` (encoded only for a scaled RoPE, so pre-R12 statements keep
  their bytes). Re-run r12-probe-r12b queued. (A `sed -i` slip renamed labels in my own probe
  script; the .bak is removed and no sed -i from here on.)
- 19:33 R12 probe second suite: compiles; 669 passed, 5 failed [MEASURED, r12-probe-r12b.log]:
  * 3 failures are artifacts of the scratch location (token-io/results/ was not copied;
    those tests read retained files there);
  * 2 are REAL and come from the capture hooks, so they affect the working tree too (the
    tree's t4 filter did not reach them):
    - hash_domain's absorb-label scan: run_capture.rs absorbs `classify-verdict`. The scan
      had never covered the classifier sources.
    - s25's call-kind row: run_capture.rs has 11 `sha256_hex(` sites, the table said 8
      (the hooks add the classifier stage segment, the run file's endpoint-policy digest
      and the extra source pins).
  * Fix (scratchpad hook_registry_fix.py):
    - hash_domain_tests: scan the four classifier sources (lane list 18 → 22); admit the
      two classifier header labels ONLY in token_io/classify.rs and run_capture.rs;
    - s25: row 8 → 11 with the reason.
- 19:40 P-18 written (scratchpad p18_patch.py):
  * classify_cli.rs: `door()` (the B-3 re-render and the segment reads, returned as
    `DoorPassed`), shared by check_run; the CLI carries no capture hook;
  * classify_cli_tests: the fixture `Cc` becomes pub(super);
  * classify_capture_tests: `check_classify_bundle_parts` and the env-driven
    `capture_the_classify_cli_verify_path` (the named binary's prove / verify as its own
    processes, then the door plus the recorder).
- Both patches applied to the probe (and token-io/results copied in) and to the working tree.
  The tree and the probe now differ by exactly the 37 native R8→R12 files plus the 3
  Provenance-fix files. Probe third suite r12-probe-r12c queued.
- 20:10 coordinator: native R12 D24 review ACCEPTED WITH FIXES; Sol makes R12b with F1 (tied
  table declared, not checked), F2 and F3. The final R-C1 freeze sits on R12b (small
  re-merge expected: trained_block.rs). Answered (SendMessage) the F1 question on the
  classifier side:
  * load_classifier_tables (classify_cli.rs) has the same declared-not-checked pattern
    for (1) margin_int16.bin, which in R-C1 is a GIVEN table, not derived from the tied
    tensor (R-C2), (2) the embedding via token_io.json (source_tensor not read) and (3)
    classifier.json's bos and final norm (not bound to the export's).
  * Proposed: Sol's R12b exposes a recompute from the pinned tensor (embedding, and the
    int16 yes-minus-no row with the quantizer spelled out) plus the export's final norm.
    R-C2 then derives w from the pinned tensor and the policy's yes / no ids (no
    margin_int16.bin trusted), with tests for doctored tables carrying consistent
    digests.
- 2026-10-28 21:10 UTC (coordinator, resuming after the 10-26 20:33 UTC stop;
  token agent a1739f8 died with the session): **probe third suite r12-probe-r12c
  GREEN** — exit 0, 819 passed / 0 failed / 53 ignored [MEASURED,
  logs/r12-probe-r12c.log, finished 10-26 20:27 UTC]. The two real failures of
  r12b (hash_domain classifier label scan, s25 call-kind row 8 → 11) are fixed
  in both the probe and the working tree. Next: wait for Sol's R12b (S1b:
  F1 tied-tensor recompute + classifier tables, F2, F3, N-7), re-merge
  (trained_block.rs expected), suite, freeze R-C1 on R12b; then R-C2 (the
  classifier verifier re-derives w and the embedding from the pinned tensor
  via Sol's public function; doctored tables with consistent digests refused).
