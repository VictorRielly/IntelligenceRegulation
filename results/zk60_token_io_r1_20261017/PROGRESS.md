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
