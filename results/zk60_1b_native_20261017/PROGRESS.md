# NATIVE lane — trained TinyLlama-1.1B block, T=32 (2026-10-17 UTC)

Scope: make the native prover prove one trained TinyLlama block at T=32, then
do it. P1 (inputs/outputs/activations hidden, weights public). Not a model
pass; no privacy acceptance at this shape (D22 covers only the toy).

Writes only under `ops/zkp-mvp/trained-1b/` (durable working copy) and this
directory. No git. Every build/test/proof through
`scripts/zk60_resource_guard.py`.

## Log

- 01:39 UTC: lane opened. Read CLAUDE.md, ZK60_RESOURCE_PROTOCOL.md, last
  section of RECOVERY_COORDINATION.md, contract-review HANDOFF/evidence/
  check_contract.py, trained-calibration-next.txt, lane-C PROGRESS + recovered
  patch, ZK60_1B_CHECKPOINT.md.
- 01:41 UTC: working copy `ops/zkp-mvp/trained-1b/` = rsync of
  `ops/zkp-mvp/candidate/{hashline,zkp-core,private-block-kernel,
  private-block-kernel-shaped}` excluding `target/`; recovered patch applied
  cleanly (`patch -p1`, 9 files, no rejects). Manifest (188 files + patch
  sha256): `manifest_t0_copy_plus_patch.json`.
- 01:41-01:52 UTC (T1 baseline, BEFORE lane edits): guarded build job
  `n1-t1-lanec-fast` (debug, `lane_c_tinyllama_tests`): 7 passed, 2 ignored
  (`t1-lanec-fast.{log,guard.json}`, compile+run 42 s, peak 1.44 GiB).
  Guarded cpu job `n1-t1-full-release-lib` (`cargo test --release --lib`,
  test-threads 2, need 8 / cap 10 GiB): **493 passed, 10 failed, 19 ignored**,
  672 s, peak RSS 1.73 GiB (`t1-full-release-lib.{log,guard.json}`). The 10
  failures are all pre-existing and none is a frozen-receipt/frozen-profile
  pin: 3 missing fixture dirs relative to the copy (`review_tests::
  a_toy_receipt_made_before_the_lane_still_verifies`, `run_tests::
  the_retained_125m_statements...`, `slot_ir_tests::...drafter's_inventory`
  — they read `<crate>/../results/...`, absent in this copy and partly absent
  in the main tree); 6 profile-registry source scans (s24 x2, s25 x3, s33)
  broken by the lane-C prototype's new profile literals / module /
  hash call site (C2's 2026-09-30 baseline shows the same set); 1
  concurrency-flaky global counter (`s35_tests::the_two_rewritten_closures
  ...`: counts comparisons made by other threads too; same in C2's run).
  Every frozen pin passed: toy schedule digest, toy parameter line, slot-IR
  export digests at all 9 registered shapes, run header byte identity (R-5),
  parity vs the frozen kernel, frozen calibration copy.
  NOTE: the source-scan tests read sources at RUN time and saw some of my
  first T2 edits (the run started before them); their failure set is the
  same as C2's anyway.
- ~01:55-02:02 UTC (T2 implemented, see the design note in
  `NOWRAP_DERIVATION.md` when written): per-profile `norm_tn`, `norm_cn_a`,
  `norm_cn_m`, `norm_ceps`, `sh_ao` + `trained_calibration` flag on Shape;
  validator `NormCalibration::derive_at_width` (D_max with 32768 and Ceps,
  window must be 25..=32 bits, class bounds tn 1..=16, Cn 1..=2^20,
  Ceps 1..=2^40, sh_ao 0..=8, width <= 4096; computes max tn per width:
  10 @2048, 9 @4096). New profiles: block `...tinyllama-1.1b-t32-trained/1`,
  `...rung-tc-t32-dev/1`; run `...private-run-tinyllama-1.1b-t32-trained/1`,
  `...private-run-rung-tc-t32-dev/1`. Sites: shape.rs, layout.rs (describe
  calibration line, for_shape refusal of a non-door calibration), witness.rs
  (both norms), argument.rs (SC_TZC Ceps hosts, SC_DZC 2Cn_a/2Cn_m/2^tn/
  2^(tn+1)/2^sh_ao), slot_ir.rs (hosts, c0/c6, host_wo; labels unchanged),
  s35_tests.rs, kernel-shaped lib.rs (Shape fields + validator + both norms
  + AO), parity.rs (kernel_shape carries the calibration), pad.rs
  (test checker's hard-coded Ceps = 1 -> shape's), trained_statement.rs (v2:
  cn_a/cn_m, export provenance, manifest digest per layer), run.rs (run
  profiles), private_block.rs (`ExpectedIo::from_bytes_at`), norm_alias.rs
  (end-to-end alias at trained shapes), new `trained_calib_tests.rs`.
- 02:02 UTC: debug, guarded: `trained_calib_tests` + `norm_alias` 18 passed,
  0 failed, 4 ignored (heavy) (`t2-fast2.log`). Evidence of controls,
  audit and ladder: `t2-audit-and-ladder.log`.
  D16 status (coordinator's six points):
  1. D byte-limb pin, ceil(log256(Dmax+1)) limbs: DONE — LIMBS_ISQRT = 3,
     validator refuses 2*D_max >= 2^24; D_max = 1,482,954 at T3 constants
     (`the_validator_computes...`, `the_trained_norm_window_does_not_re_open_the_alias`).
  2. a1/a2 same treatment: DONE (same 3-limb pin, 2*D_max < 2^24 checked).
  3. never more than four limbs: DONE (isqrt 3, remainder exactly 4; a fifth
     is refused by the validator and by Ids::new).
  4. remainder window exact and <= 32: DONE — derived window 32 at TinyLlama
     (C-6, top limb full), 31 at the trained rung (top-limb scaled lookup 2
     live); den_max saturates the window (test asserts tightness).
  5. range audit re-run + wraparound premise: AUDIT DONE as a test
     (`every_committed_value_under_a_non_unit_coefficient_is_range_proved_at_the_trained_shapes`):
     every (slot, plane) under a non-unit public coefficient is classified
     (U8 lookup / limb-pinned / pair table), none unclassified, and the
     exposure set equals the frozen structural twin's (TinyLlama trained ==
     lane-C dev; rung-TC == rung-C6). Wraparound re-derivation: PENDING
     (NOWRAP_DERIVATION.md + nowrap_check.py).
  6. alias tamper tests reject at the new profile: DONE at the trained rung
     end to end (4 cases, catches at slot 2 and the LogUp claim, honest
     control verifies); at TinyLlama: test written
     (`native_the_half_p_alias_is_refused_end_to_end_at_the_trained_tinyllama_profile`),
     heavy run PENDING.
  Controls at the trained rung (end to end, from bytes): verifier with
  tn-1 / cn_a+1 / cn_m+1 / ceps+1 / sh_ao+1 refuses ("expected statement
  mismatch": the schedule digest moved); truncated and 3 mutated receipts
  refuse; witnesses honest under (tn-1, Cn/2), cn_m+7, ceps*4 rejected
  (slots 14, 14, 2). Bound one-block run at rung-TC verifies; rejected under
  each one-constant variation; a statement declaring another constant does
  not construct; an unbound run at the trained TinyLlama run profile does
  not construct.
  Counted ladder (trained TinyLlama geometry, rows/receipt only, NO peak):
  T32 lc12 A 1729 / H 1798 / 11,627,208 B (lc13 991/954/11,729,800);
  T64 lc13 15,445,848 B; T128 lc14 23,049,192 B; T256 lc14 35,522,536 B;
  T512 lc15 57,052,280 B (lc14 72,108,984 B > the 64 MiB wire cap). Full
  table in `t2-audit-and-ladder.log`.
- 02:04-02:12 UTC: release probe of the trained-dense bands
  (`t3-probe-bands.log`): at TinyLlama attn 16 refuses at the score, gate 16
  at the FFN gate; chose attn 8 / gate 12 / down 2 (max|q8| 43, |s8| 42,
  |g8| 100, |x2| 9,374). Registry: the lane-C dev shape/run profiles moved
  OUT of the `hashline-zk-mr1/` registry (renamed `unregistered-dev-twin/...`,
  test-only structural twin); the two trained block profiles and two trained
  run profiles registered in s24 / s25 / s33; `trained_statement.rs` pinned in
  the capture writer's source pins, `mvp_driver.rs` (pre-existing, unlisted)
  excused with a reason; CALL_SITES rows added for trained_statement (D9),
  mvp_driver (3, pre-existing) and trained_block (1). The s25 census caught a
  real equal-length pair: the first trained run profile string (56 B) put the
  transcript constructor at 68 B = the `pb-run-stage` absorb in the same keyed
  function; renamed to `...private-run-tinyllama-1.1b-t32-trained-statement/1`
  (66 B -> 78 B, nothing at 77-79). Registry/parity/new tests: 70+23 passed
  (`t2-registry*.log`).
- 02:15-02:22 UTC **T3 DONE** (release, guarded, shared box; [MEASURED] one
  run each): `native_t3_generic_trained_tinyllama_block_proves_and_verifies`
  (`t3-prove.log`, exit 0): TRUE TinyLlama T32 geometry, trained calibration
  tn 10 / Cn_a 2672 / Cn_m 4315 / Ceps 129,746,337 / sh_ao 7, dense
  synthetic weights, generic input, heads differ, upper hidden half 98.2%
  live; witness == independent kernel-shaped reference plane for plane;
  witness build 8.07 s, **prove 3.56 s, verify from bytes 0.32 s, receipt
  11,627,208 B (= counted), test-process VmHWM 375 MiB after witness / 821 MiB
  after prove**; guard peak 1.65 GiB includes the release compile. Controls:
  verifiers with tn-1 (frame length) / cn_a+1 / cn_m+1 / ceps+1 / sh_ao+1
  ("expected statement mismatch") refuse; truncation and 3 byte mutations
  refuse; witnesses honest under (tn-1, Cn/2), cn_m+7, ceps*4 rejected at
  slots 14, 14, 2. FRESH PROCESS (`t3-fresh-verify.log`, saved test binary
  `t3/hashline-lib-test-release.bin`, sha256 in `t3/SHA256SUMS`): rebuilt
  the public statement from the public recipe alone (block digest matches),
  verified the saved receipt in 0.38 s, VmHWM 163 MiB; all five wrong-constant
  verifiers refuse the same bytes.
  **D16 item 6 at TinyLlama DONE** (`t3-alias-tinyllama.log`): all four
  half-p alias cases rejected end to end (slot 2 x2, LogUp claim x2), honest
  control verifies (76 s for five width-2048 proofs).
- 02:22-02:28 UTC **T4 DONE**: production module
  `hashline/src/private_block/trained_block.rs` (strict bounded JSON parser,
  export reader, parity check, statement builder, `trained_prove_command` /
  `trained_verify_command`) + `examples/zk60_trained_block.rs` + test module
  `trained_block_tests.rs` (4 tests, all pass: round trip and digest binding,
  12 malformed-export refusals by name + RoPE opt-in, parity mismatch by
  count/position, CLI end to end with every control). Tiny export (rung-TC,
  synthetic, 1.1 MB) written to `tiny_export/round-trip/tiny-v1/`; CLI in
  separate processes (`t4-cli-prove.log`, `t4-cli-verify.log`): parity
  bit-exact, prove 3.3 s, verify 0.53 s fresh process, 3 inconsistent-witness
  + 12 statement/receipt controls refused, honest still verifies.
  The calibration lane's first smoke export (`export/a_smoke_T32_L3smoke/`,
  no profile.json / seq dirs yet at 02:28) uses exactly the manifest format
  the reader parses (layer, constants, arrays{file,dtype,shape,sha256}).
- 02:28 UTC: guarded full release `--lib` suite on the edited tree launched
  detached (`t5-full-release-lib.*`).
- 02:29-02:41 UTC: guarded full release `--lib` suite on the edited tree
  (`t5-full-release-lib.*`): **515 passed, 3 failed, 23 ignored**, 730 s,
  peak 1.91 GiB. The 3 failures were only the missing-fixture tests; with
  read-only fixture COPIES placed in `ops/zkp-mvp/trained-1b/results/`
  (sha256 in `fixture_copies.sha256`; toy receipts from the main tree's
  results, the 125M statements and drafter inventory from
  `~/wt-zk60-block125m/results/zk60_block125m_lane/`) all 3 pass
  (`t5-fixture-tests.log`): **the 4 archived pre-lane toy receipts still
  verify under this lane's verifier**, the retained 125M statements still
  regenerate their public weights, the slot-IR inventory agrees. So 518/518
  non-ignored lib tests pass. Also: hashline integration test
  `zk60_private_block` 4/4, kernel-shaped crate 5/5. The s35 global-counter
  test passed this time (it is concurrency-flaky, see the baseline note).
- 02:41 UTC: reader adapted to the calibration lane's ACTUAL writer
  (`b3_ladder.py`, read-only): `profile_constants` with `null` for per-layer
  constants + `per_layer_constants_differ` (a one-block run then takes its
  layer's manifest constants; a run's layers must agree), `calibration_tool`
  `sha256` as an object of per-file digests (canonical digest), layer objects
  `{layer, dir, manifest_sha256}` (each manifest checked against profile.json),
  sequence manifests (digest-checked), `metadata_out_of_proof.
  residual_scale_s_x`. Loader tests updated (14 refusals now incl. a null not
  in the per-layer list and a manifest digest mismatch; per-layer and
  no-seq-manifest exports accepted): all pass (`t4-loader-v2*.log`).
  Durable patch of the whole lane vs the candidate:
  `native-lane-vs-candidate.patch` (zkp-core and the frozen
  private-block-kernel untouched).
- 02:44-02:48 UTC: the calibration lane's SMOKE export has layers but no
  profile.json / sequences (its writer emits those only after a full 22-layer
  run). Reader compatibility shim in `smoke_shim/` (my profile.json per the
  writer's code + symlinks to its layer dirs, `make_smoke_shim.py`):
  `native_t5_a_real_exports_layers_load_and_its_trained_weights_prove`
  (`t5-smoke-weights.log`): all 3 real layers load — every array SHA-256,
  dtype/shape, exp member (e_s 1), SiLU member (-2,-11), RoPE tables equal
  to the native generator — constants tn 10 / cn_a 12509 / cn_m 4625 /
  ceps 711 / ao 7 pass the validator (window 32). TRAINED WEIGHTS of layer 0
  on SYNTHETIC inputs are admissible at |x| <= 64..8192 and one was PROVED and
  verified from bytes: prove 3.44 s, verify 0.31 s, 11,627,208 B, VmHWM
  839 MiB. NOT the trained-block milestone (synthetic input, no parity).
  T5 proper waits for an export with profile.json and a seq_* directory.
- 03:01 UTC: T5 is ready to run the moment an export with `profile.json`
  and a `seq_*` directory appears (the calibration lane's current ladder
  runs do not pass `--export`, so none is being written yet). FOR A
  SUCCESSOR: `results/zk60_1b_native_20261017/t5_run.sh <variant dir>
  <layer> <seq id, e.g. ho00>` proves with the SAVED release CLI
  (`t5/zk60_trained_block.release.bin`, sha256 in `t5/SHA256SUMS`, built
  from the sources in `manifest_final_sources.json`) as a guarded cpu job,
  then verifies in a fresh process with every control; evidence lands in
  `t5/<variant>-L<layer>-<seq>/`. Validated on the tiny export
  (`t5/tiny-v1-L0-s0/`: parity bit-exact, 3 + 12 controls refused,
  fresh-process verify exit 0). If parity fails, the CLI refuses with the
  count and first position of differing output words; localising the first
  differing RELATION needs the Python reference's intermediates (not in the
  export format).
- 03:22 UTC: the calibration lane's export `export/a_export_T32/` completed
  (profile.json, 22 layers, seq_ho00, seq_ho01; uniform constants tn 10 /
  cn_a 4511 / cn_m 2438 / ceps 259 / sh_ao 7, f_e 9, silu (-1,-10), e_s 2,
  theta 10000; model pin = the pinned TinyLlama revision/sha256). NOTE the
  writer's own fidelity record for this variant: held-out top-1 agreement
  0.14, ppl int 1430 vs float 24.5, 21 of 36 held-out sequences refused — the
  integer model is a poor approximation of the float model; that is the
  calibration lane's measurement and does not affect what is proved.
- 03:23-03:25 UTC **T5 DONE for one trained block** (`t5/a_export_T32-L0-ho00/`,
  saved release CLI, guarded, shared box with three calibration light jobs
  live; [MEASURED] one run): layer 0, held-out sequence ho00.
  PARITY: the native witness on the exported x_in reproduces the exported
  x_out **bit-exactly** (65,536 words; 12.7 s incl. the witness build).
  PROOF: one-block run BOUND to the trained-model statement (identity
  c670f74f...6618; binds profile.json sha256 2b5ded29..., tool digest
  12d3be97..., layer manifest d248b25c..., block digest 300cfe3a...):
  **prove 3.49 s, in-process verify 0.36 s, segment 11,627,288 B, process
  VmHWM 888 MiB after prove; guard child wall 67.7 s / peak RSS 1.06 GiB for
  the whole prove command incl. load, parity and the 3 controls.** FRESH
  PROCESS verify (rebuilt from the export's public files + statement pin;
  never opens seq_*): verify 0.33 s, load 0.74 s, VmHWM 211 MiB, exit 0.
  CONTROLS, all refused: inconsistent witness x3 (norm_a output +1 -> slot
  14; one q8 +1 -> slot 15; witness honest under cn_m+7 -> slot 14);
  statement mismatch x8 (verifier with tn-1 / cn_a+1 / cn_m+1 / ceps+1 /
  sh_ao+1, another export-profile digest, another layer index, one gamma_a
  word moved); receipt mutation x4 (3 byte flips, 1-byte truncation); honest
  still verifies. SCOPE: ONE block of 22, T = 32, CPU, shared box; NOT a
  model pass; NO privacy acceptance at this shape (D22 covers only the toy).
- 03:25 UTC: layers 1-21 of the same export/sequence launched detached, one
  guarded prove + fresh-process verify per layer, no controls
  (`t5_all_layers.sh`, evidence `t5/all/`).
- 03:25-03:4x UTC: ALL 22 LAYERS of `a_export_T32`, sequence ho00, each as an
  INDEPENDENT one-block bound run (`t5/all/TABLE.txt`, per-layer logs and
  guard JSON in `t5/all/a_export_T32-L<k>-ho00/`, layer 0 in
  `t5/a_export_T32-L0-ho00/` with the controls): parity bit-exact at every
  layer (65,536 words each), proved at every layer (3.2-4.2 s, segment
  11,627,288 B, VmHWM 872-895 MiB), verified at every layer in a fresh
  process (0.27-0.40 s). Some verify jobs waited for guard admission behind
  the calibration lane's light jobs (that is queueing, not compute). THIS IS
  NOT A STACK PROOF: 22 separate runs, each with its own prover-created
  endpoint commitments; nothing binds block k's output to block k+1's
  input. That is the next checkpoint item (one bound 22-block run).
  Final sources: `manifest_final_sources.json`; whole-lane patch vs the
  candidate: `native-lane-vs-candidate.patch` (sha256 b8b44290...).
  No job of this lane is running; lane closed.
- 03:46-03:57 UTC: FINAL guarded full release `--lib` suite on the final
  sources (`t6-final-release-lib.*`, waited 341 s for admission behind the
  calibration lane): **518 passed, 0 failed, 24 ignored** (fixture copies in
  place), 647 s, peak 1.9 GiB. Lane closed; nothing of mine is running.

## Round 2 (coordinator, 2026-10-17 ~08:10 UTC): pg_rot1 export, shifts, stack

- 08:10-08:45 UTC: read `export/pg_rot1_export_T32/` (README, profile.json
  b25ba5f5..., rotation.json): one calibration Cn_a 3999 / Cn_m 3122 / Ceps
  91255, shifts QKV 8 / S 6 / O 9 / AO 3 / G 8 / H 14 / Z 5, per-layer exp
  e_s and SiLU member, Hadamard-rotated residual basis. Code written (not
  yet compiled, see below):
  * R2-1: `NormCalibration` gains sh_qkv, sh_s, sh_o, sh_g, sh_h, sh_z with
    structure-preserving windows (one-limb sites 1..=8, AO 0..=8, two-limb O
    and product 9..=16), confirmed against `layout.rs::lookups_at` (scaled
    top-limb coefficients 2^(8-sh) / 2^(16-sh)) and every host relation in
    `argument.rs` (QZC/KVZC/SZC/FZC/DZC) and `slot_ir.rs`; witness, kernel
    crate, parity mapper, schedule lines, parameter line, statement (now
    schema v3: table keys per layer), loader. RoPE/F_P/F_E/up/residual stay
    fixed. `nowrap_check.py` extended to the shift windows.
  * R2-4: `protocol::single_block_profile_allowed` refuses every single-block
    entry point (prove, verify, encode, decode) at a trained-calibration
    profile; tests now prove trained blocks as one-block BOUND runs (a
    test-only constructor allows a synthetic-recipe statement at the trained
    profile; production still refuses it).
  * R2-2/R2-3: loader split into run-level constants and per-block table
    keys; rotation sign digest checked; `stack-prove` / `stack-verify` CLI
    subcommands (sealing pass with parity at every layer, bound run,
    directory sink, fresh-process verify, run-level controls, a
    `--lie-at-boundary` prover control).
- 08:19-08:45 UTC: BLOCKED ON ADMISSION. The calibration lane keeps four
  `light` jobs live (11.5 of 11.89 GiB declared budget; its queue scripts
  hold further jobs with 6 h waits), so my build (need 4 GiB) and even a
  0.5 GiB light Python check waited ~25 min; the D24 reviewer's build job
  (`r-fast`) is starved the same way and holds the heavy lock while queued.
  I stopped my two queued jobs (TaskStop; they had no child) and requeued
  the compile at my MEASURED need (2.5 GiB, cap 4; debug build peak 1.75 GiB).
- 08:45-09:00 UTC: the round-2 code compiled (`r2-compile.log`); fast tests
  `r2-fast.log` 74 passed / 2 failed: (a) s25's call-site census (the new
  `stack_context` is a second `blake3::hash(` in trained_block.rs: table row
  updated to 2, both contexts described); (b) the D16-5 audit's exposure
  equality at rung-TC vs rung-C6: sh_qkv = sh_g = 8 makes the top-limb pin's
  coefficient `2^(8-8) = 1`, so A_RQL/A_RKL/A_RVL/A_RGL leave the NON-UNIT
  list while still being U8 lookups. The audit now asserts the exposure only
  SHRINKS against the frozen twin and every plane that leaves sits under a
  shift at the top of its window (printed per plane). `r2-fast2.log`: 5/5
  incl. the audit, the rung alias test (D16 item 6 rejected at slot 2 and at
  the value-0 LogUp claim), every coefficient/shift control (11 verifier
  variants refuse) and the inconsistent-witness controls (incl. sh_z - 1).
- 09:00 UTC: `nowrap_check.py` (round 2): shift windows at their tops all
  below 2^36 (host down 2^36.0 the worst); pg_rot1 TinyLlama constants D_max
  1,482,910, window 32 (C-6), worst clause 2^48.011.

### D24 review findings (coordinator relay ~09:05 UTC) — fixes

The independent review (`results/zk60_d24_review_20261017/`) accepted the
D24 norm rule and did NOT accept the trained profile + loader until F-1 is
fixed. Each finding, its fix and its evidence:

- **F-1 BLOCKING, f_e unvalidated — FIXED.** Declared class
  `TRAINED_F_E_RANGE = 9..=16` plus the three-limb sigma_s rule
  `wrho_s = clog2(T) + f_e <= 24` (shape.rs). Checked (1) in the loader's
  `constants_of` (prover and verifier both load through it; the per-layer
  path too), (2) in `TrainedExport::shape_for` before and after the shape is
  built, (3) at the door `Shape::with_trained_calibration` via the new
  `Shape::check_trained_class`, (4) again in `Layout::for_shape` for every
  trained shape. Re-derivation: SC_SZC `c2 = mask e 2^9 - p Sum - sr`,
  `c3 = sg + sr + 1 - Sum`: over the class at EVERY T with a <= 24-bit
  window `|c2| < 2^34.003` (T32: 2^31.022), no all-equal-row wrapping
  forgery for any k != 0 (nowrap_check.py section 7; and the REVIEWER'S OWN
  functions re-run on the new class by `reviewer_nowrap_round2.py`, which
  imports reviewer_nowrap.py read-only: 100 (f_e, T) points, worst 2^34.003,
  margin 30 bits, no forgery; its T32 forgery threshold reproduced at 50).
  Permanent tests (`review_d24_tests.rs`, ported from the reviewer's scratch
  module, forge hook now thread-local and placed after the honest range
  check as in the review): A — the TinyLlama door admits exactly 9..=16 of
  0..=64 (no panic); E — the reviewer's f_e = 50 export (pinned model
  strings) is refused AT THE DOOR by `trained_prove_command` (no artifact
  written), `trained_verify_command` and `trained_stack_verify_command`
  (also f_e 8 and 17), every f_e in 9..=16 loads, the wrapping forgery
  (p 16 -> 527, sr' = sr - 511 Sum + P) builds a witness at a rung shape
  EDITED after the door to f_e 50 and both the bound-run prover and verifier
  refuse it at Layout::for_shape, and the wrap remainder is impossible at
  every admitted f_e; F (control) — the naive p + 1 forgery is rejected at
  "slot 17 [06 softmax zero-check]" at the rung (fast) and at the TinyLlama
  profile with f_e 9 (heavy, ignored, release). Loader refusal cases added:
  f_e 50 / 8 / 17-per-layer. The one-block and stack CLI verifiers gain an
  "f_e moved by one" control.
- **General rule — every export-chosen constant has a declared class.**
  norm tn/Cn/Ceps/sh_ao and the six windowed shifts (derive_at_width, at the
  door and in Layout::for_shape); f_e (above); exp e_s in -8..=8
  (`TRAINED_EXP_E_S_RANGE`; any finite e_s keeps the table in [0, 2^f_e], the
  class keeps the generator off its NaN overflow) in the loader's
  `table_keys_of` and in the statement's `check_self`; the SiLU member must
  be in the frozen int16-out registry (loader early + statement); RoPE base
  pinned to the geometry's 10000 (`TRAINED_ROPE_THETA`; loader and
  `check_honoured_by_code` at trained shapes; table values are in [-128, 128]
  for any base, so no premise depends on it); the fixed constants (sh_rope,
  sh_u, f_p, f_ro, sh_r2) were already checked equal; T = 32; tables checked
  against the generator members by value (kept). Loader refusal tests: e_s 9,
  rope_theta 500000.
- **F-2 — FIXED.** `RunStatement::new` refuses when `rs.sh.trained_calibration`
  (or the trained run profiles by name), not on a "tinyllama" substring;
  review B made permanent (also a trained shape under a frozen run profile
  string). Single-block proofs at trained shapes already refuse (R2-4:
  `single_block_profile_allowed` in prove_inner_at / verify_inner_at and the
  receipt codec); `protocol::transcript` now also asserts it.
- **F-3 — FIXED.** `new_bound` requires `rs.sh.trained_calibration` (review
  C permanent: refused at rung-G); `check_self` keys on the trained TinyLlama
  profile's identity and requires the PINNED checkpoint source there (another
  checkpoint or a synthetic recipe is refused; the test-only synthetic
  waiver remains cfg(test)). Lane C's binding test moved from rung-G to the
  trained rung and now also asserts both refusals.
- **F-4 — FIXED.** `variant` comes from profile.json's `variant` field
  (required, plain name), not the directory name; review D permanent (same
  bytes under two directory names -> one identity; another variant -> another).
- **F-5 — FIXED.** `Layout::for_shape` re-runs `check_trained_class`
  (derive_at_width, derived window/D_max equality, f_e class, derived
  wrho_s) for trained shapes; review H permanent with 12 edits, all refused.
- **F-6 — FIXED.** `tinyllama_trained_ladder`, `tinyllama_t32_dev`,
  `tinyllama_t32_probe`, `TINYLLAMA_T32_DEV_PROFILE`,
  `RunShape::tinyllama_t32_dev` and `RUN_PROFILE_TINYLLAMA_T32_DEV` are
  cfg(test).
- **N-4 (note)**: the reachable tn range is 2..15; the declared class stays
  1..=16 (wider than reachable, which only over-bounds the derivation).
- The reviewer's corner test G is permanent too (bound runs): the norm class
  corner proves (segment 7,452,120 B) and its neighbours refuse.
- 09:14-09:18 UTC: guarded debug runs `r2-f1-fast.log` (58/60: lane C's
  rung-G binding test and review E's hook position) then `r2-f1-fast2.log`:
  16 passed, 0 failed (review A-H, lane C, loader refusals).
- 09:19 UTC: launched detached `r2_suite_and_build.sh`: full guarded release
  suite on the fixed tree, then the release CLI build copied to
  `r2/zk60_trained_block.release.bin` (+ .sha256).
- 09:19-09:30 UTC: the first full release suite on the fixed tree
  (`r2-full-release.log`) was KILLED by its own 6 GiB kernel cap (peak 5.87
  GiB at the 22-thread default) after 441 passes, and showed one failure:
  `s35_tests::the_two_rewritten_closures_equal_the_parent_closure_at_every_
  registered_shape`, which PASSES alone (`r2-s35.log`). Cause: it asserts an
  exact count of a PROCESS-WIDE comparison counter over its own walk, and
  every other test's slot definitions running in parallel add to it. Fixed
  test-side: the same count is also kept per thread and the assertion reads
  the thread's (the walk's definitions run on its own thread).
- 09:29-09:30 UTC: round-2 release CLI built, `r2/zk60_trained_block.release.bin`
  sha256 17d6ab10652dbbf8b22736532212453e8d68d73d056b7f2090b646d14cc791fe;
  the 157 source digests at that build are `r2/manifest_cli_sources.json`
  (later edits are test-only: s35_tests.rs, trained_stack_tests.rs).
- 09:28 UTC: stack controls made copy-free (each segment mutation in place
  and undone; no second 256 MB receipt copy resident). New test module
  `trained_stack_tests.rs` (R2-3 in the ordinary filter): a 3-layer chained
  rung export with PER-LAYER tables (e_s 0/1, SiLU (-3,-11)/(-4,-12)) proves
  through `stack-prove` as ONE bound run (parity bit-exact at every layer,
  receipt 22,434,344 B), `stack-verify --controls` accepts and its 11
  run-level controls refuse (swapped blocks x2, cn_a / sh_z / sh_qkv / f_e
  moved, another export digest, one block fewer, segment byte flip, segments
  swapped, truncation); a wrong pin, a 2-layer verifier, a foreign file and
  an existing out dir are refused; `--lie-at-boundary 1` fails to verify at
  "slot 22 [IO-out endpoint equality]" (`r2-stacktest.log`, 3/3 incl. s35).
- 09:33 UTC: the round-2 CLI on the REVIEWER'S forged artifact
  (`trained-1b-review-r1-scratch/review_out/{export,artifact}-fe50`, read
  only) with --controls: exit 1, refused at the door ("f_e 50 is outside its
  declared class 9..=16 ... review finding F-1"); `r2/review-fe50-recheck/`.
- 09:33-09:44 UTC: full guarded release suite again at 8 test threads
  (`r2-full-release2.log`): lib 527 passed / 0 failed / 25 ignored, every
  integration target ok; guard child wall 677 s, peak RSS 4.21 GiB.
- 09:34 UTC: `nowrap_check.py` (section 7, softmax) and
  `reviewer_nowrap_round2.py` both PASS; NOWRAP_DERIVATION.md section 8.

### R2-2 and R2-3 on pg_rot1_export_T32 (CPU, round-2 CLI 17d6ab10...)

- 09:44-09:47 UTC, **R2-2** (`r2_pg.sh` -> `r2_run.sh`, evidence
  `r2/pg_rot1_export_T32-L{0,21}-{ho00,ho01}/`): parity BIT-EXACT (65,536
  words) for layer 0 and layer 21 on both held-out sequences; each proves as
  a bound one-block run (prove 2.3-2.5 s, segment 11,627,288 B, VmHWM about
  880 MiB) and verifies in a FRESH process (0.24-0.26 s). Layer 0 / ho00 and
  layer 21 / ho01 ran every control: 3 inconsistent-witness controls refused
  at prove time and 19 verifier controls refused (every calibration constant
  and windowed shift moved, f_e moved, another export digest, another layer,
  one gamma word, segment mutations and truncation), the honest segment
  still verifying. Statement identities: layer 0 f9c03305..., layer 21
  5481437... (the run context is per layer, the identity per export+layer).
- 09:47-09:57 UTC, **R2-3 THE STACK** (`r2_stack.sh ho00`, evidence
  `r2/stack-pg_rot1-ho00-cpu/`): ALL 22 pg_rot1 TinyLlama blocks as ONE bound
  run at T32, [MEASURED, shared box, n=1, CPU]:
  * sealing pass: parity BIT-EXACT at every one of the 22 layers against the
    export's x_out (block k's output IS block k+1's input by construction),
    230.6 s;
  * proving pass (`prove_run`, 22 segments into the run directory): 282.6 s,
    of which witness rebuild 223.0 s (about 10 s per block: the single-thread
    witness builder dominates; the proofs themselves are about 60 s);
    in-process verify from the directory 4.9 s; total 528.9 s; VmHWM 2,200
    MiB; guard child wall 529.0 s, peak RSS 2.15 GiB (cgroup 2.6 GiB);
  * receipt 250,855,088 B in 22 segments (11,320,120-11,698,968 B each; lengths and
    SHA-256 in `run/statement/segments.json`);
  * statement identity 68ad19c83a3ae1a345f1a5a8b5dcdc02679fc71e89a4d1eb19d55eb446b9f487
    (binds the export profile digest b25ba5f5..., the tool digest, every
    layer's block digest, manifest digest, SiLU member and exp e_s, the one
    calibration, f_e and the RoPE base).
  * FRESH-PROCESS verify of the directory with `--controls`: verified in
    4.9 s (load 10.3 s), guard wall 34.4 s, peak RSS 1.57 GiB; all 11
    run-level controls REFUSED (blocks 10/11 swapped in the statement; the
    verifier's block list swapped; cn_a + 1; sh_z, sh_qkv and f_e moved;
    another export digest; one block fewer; a byte of segment 11 flipped;
    segments 10/11 swapped; the last segment truncated) and the honest run
    still verifies.
  * the prover-side boundary lie (`--layers 0..3 --lie-at-boundary 1`,
    `r2/stack-pg_rot1-ho00-lie/`): parity bit-exact, then the run FAILS to
    verify at "slot 22 [IO-out endpoint equality]" as it must (guard wall
    67.8 s).
  Scope, unchanged: the 22 transformer blocks only (embedding, final norm,
  LM head, token selection NOT covered, D13); NO privacy acceptance at this
  shape (D22 covers only the toy); float fidelity is the calibration lane's
  measurement (held-out top-1 0.698 for pg_rot1).
- The run directories hold the segment bytes (240 MB + 33 MB); the
  committable record is `statement/segments.json` (lengths + SHA-256),
  `statement.json`, `expected.bin` and the logs.

### R2-5 GPU readiness

- Fail-closed (code from earlier this round, now exercised): `gpu::required()`
  (`HL_GPU_REQUIRED=1`), a decline counter, `gpu::declined(site, err)` which
  logs, counts and PANICS when the GPU is required (every decline site in
  `gpu/mod.rs` seams, `zk.rs`, `pcs.rs`, `wcache.rs`, `layer.rs` routes
  through it; `cuda.rs`'s internal device-to-device fallbacks unchanged),
  and `gpu::require_live()` at the top of `stack-prove`. Evidence: the CPU
  binary with `HL_GPU=1 HL_GPU_REQUIRED=1` refuses before loading anything
  ("HL_GPU_REQUIRED=1 but the GPU path is not live: gpu: off (built without
  --features gpu-cuda)", `r2/gpu-required-on-cpu-binary/`).
- Wire cap per profile: `wire::wire_ceiling(sh)` is 256 MiB at the trained
  profiles (64 MiB elsewhere, unchanged); T512 lc14's counted segment is
  above 64 MiB and below the new ceiling (ladder test).
- 09:58-10:02 UTC: GPU-feature CLI built (guarded, 70 s;
  `r2/zk60_trained_block.gpu.release.bin` sha256
  0d2027a10f01109786178102c0dd1640390b0eaa0434c5ad01cc8e438b57d7f9; the
  feature-gated decline routing compiles).
- 10:02-10:12 UTC: ONE GPU-assisted run of the same 22-block stack
  (`r2_stack_gpu.sh ho00`, guard class gpu, `HL_GPU=1 HL_GPU_REQUIRED=1`,
  evidence `r2/stack-pg_rot1-ho00-gpu/`): run header "gpu: ON — NVIDIA
  GeForce RTX 4070 Laptop GPU (sm_89, 36 SMs, 8.6 GB)", 0 declines, every
  keyed ZK commitment on the device; same statement identity 68ad19c8...,
  same receipt length 250,855,088 B; verified in a FRESH process by the CPU
  binary (4.98 s). Guard: wall 545.2 s, peak RSS 1.99 GiB, peak VRAM 1,281
  MiB, drained at once.

| 22-block pg_rot1 stack, T32 [MEASURED, shared box, n=1] | CPU | GPU-assisted |
|---|---|---|
| sealing pass (witnesses + parity, all layers) | 230.6 s | 229.9 s |
| proving pass `prove_run` | 282.6 s | 296.0 s |
| of which witness rebuild | 223.0 s | 228.0 s |
| proofs proper (difference) | 59.6 s | 68.1 s |
| in-process verify | 4.9 s | 4.9 s |
| total (load + both passes + verify) | 528.9 s | 545.1 s |
| fresh-process verify | 4.9 s (+ 10.3 s load) | 5.0 s (+ 9.8 s load, CPU binary) |
| receipt | 250,855,088 B | 250,855,088 B |
| peak RSS (guard) / VRAM | 2.15 GiB / - | 1.99 GiB / 1,281 MiB |

  Reading: the GPU does not help this stack today. The single-thread
  witness builder is about 10 s per block and runs TWICE (sealing pass and
  proving pass), 86% of the wall; the proofs proper are about 2.7 s per block
  on the CPU and the device path (commitments only) did not beat it at this
  size (68 vs 60 s, n=1, shared box with the calibration lane's jobs live).
  The obvious next levers are a parallel witness builder and not rebuilding
  each witness in the proving pass (keep the sealing pass's witnesses when
  memory allows, or seal from the export's x_out instead of a full witness).
- 10:13-10:16 UTC: the heavy TinyLlama tests in release (`r2-heavy-tinyllama.log`,
  3/3, guard wall 162 s, peak 1.05 GiB): review F at the TinyLlama profile
  (pg calibration, f_e 9) — the naive p + 1 forgery is rejected at "slot 17
  [06 softmax zero-check]"; D16 item 6 at the pg TinyLlama calibration —
  all four half-p norm aliases rejected (slot 2, and the value-0 LogUp claim
  on H); T3 generic witness at the TinyLlama trained profile proves (2.54 s)
  and every coefficient/shift control and inconsistent-witness control
  refuses.
- 10:17 UTC: `r2/round2-vs-review-r1.patch` — every source change since the
  frozen review copy `ops/zkp-mvp/trained-1b-review-r1/` (round-2 shifts,
  R2-4, the loader/stack, the GPU fail-closed routing and the F-1..F-6
  fixes), for the focused re-review.

**Round 2 status at hand-back (10:17 UTC):** R2-1 done (shifts per profile,
windows, audit, nowrap); R2-2 done (pg_rot1 L0 and L21, both sequences,
parity bit-exact, proofs, fresh verifies, controls); R2-3 done (22-block
bound stack proved, fresh-process verified, 11 run-level controls refuse,
boundary-lie control fails to verify); R2-4 done (no single-block receipt at
a trained profile; transcript asserts it); R2-5 done (fail-closed, per-profile
wire cap, one GPU-assisted 22-block run: no speed-up at this size). D24
review F-1..F-6 fixed with permanent tests; full release suite green
(lib 527 / 0 / 25 ignored). No job of mine is running.

## Round 3 (coordinator, 2026-10-17 ~10:17 UTC): witness speed, context ladder

Re-review of round 2 (frozen copy `ops/zkp-mvp/trained-1b-review-r2/`): no
blocking or serious finding; two minor conditions, done FIRST:

- **R2-a — FIXED.** `Layout::for_shape` now refuses (1) any shape whose
  profile string is in `TRAINED_CALIBRATION_PROFILES` while its trained flag
  is false (a `Shape::new` under a trained string skips the door), and (2) a
  softmax window above 24 bits at EVERY shape (`Shape::check_softmax_window`:
  `wrho_s <= 24` and `clog2(T) + f_e <= 24`; the registered frozen shapes
  have 14..=18). `single_block_profile_allowed` also refuses on the profile
  string, not only on the flag. The reviewer's `r2_1` is permanent and
  refusing (`review_d24_tests::review_r2_1_...`): the non-door shape at f_e
  50 and at f_e 12 is refused by `Layout::for_shape`; the wrapping forgery
  builds a witness but the single-block prover refuses (R2-4) and the
  verifier refuses at its entry; a frozen rung-C6 edited to f_e 50 (with and
  without its window) or to a 25-bit window is refused.
- **R2-b — FIXED.** `check_against` no longer waives the "trained TinyLlama
  profile carries the pinned checkpoint" rule for every test build
  (`cfg!(test)`): the waiver is a test-build-only FIELD set only by the
  explicit test-only constructor `new_synthetic_at_trained_profile_for_tests`
  (not encoded, absent in production builds). Test `review_r2_b_...`: a
  production-constructed statement given a synthetic source is refused by
  `check_against` in `cargo test`; the test-only constructor's statement
  passes.
- 10:22-10:24 UTC: guarded debug run `r3-r2ab-fast.log` (95 passed, 0
  failed); 10:24-10:38 UTC: full guarded release suite on that tree
  (`r3-suite-r2ab.log`): lib 529 passed / 0 failed / 25 ignored, all
  integration targets ok (674 passed in all); guard wall 820 s, peak RSS 4.22
  GiB. (Compiled before any round-3 R3-x edit.)

### R3-1 witness speed (bit-exact)

- (a) `witness.rs`: the matrix products (`matmul` for Wq/Wk/Wv/Wo, and
  `matmul_in_out` for Wg/Wu/Wd) run in PARALLEL with rayon over chunks of
  each output row (a power-of-two divisor of the row stride, so no chunk
  straddles rows), and `matmul_in_out` now reads each weight row
  contiguously (loop order row, i, j; the round-2 form walked `w` at stride
  `outer`). Products are formed in i32 (every call site's `x` is int8 or
  int16, so `|x w| < 2^30`) and widened to i64 before accumulating; any word
  with `|x| >= 2^23` takes the exact i64 path. The score products run one
  parallel task per padded head slot. Integer sums are exact, so no plane
  moves: `witness_speed_tests` checks the parallel products equal the
  round-2 sequential ones verbatim (`matmul_reference`) on random int8,
  int16, zero-sprinkled and 2^40-sized inputs at rung-TC and rung-C6 (fast)
  and at TinyLlama T64 dimensions (heavy, release); the frozen receipts,
  slot-IR digests and kernel parity tests of the suite still hold. The
  softmax and norm loops stay sequential (small at these T).
- (b) the stack builds every witness ONCE: the endpoints are sealed from the
  export's own words (layer 0's x_in, the last layer's x_out, padded), and
  each block's witness is built in the proving pass and checked against the
  export's x_out of its layer BEFORE its segment is proved (block 0's input
  plane and the last block's output plane are asserted equal to the sealed
  endpoints). A parity failure aborts the run and removes the run
  directory. No pipelining: the witness is now 5% of the wall, so
  overlapping it with the proofs (which already use every thread) would
  gain little. Threads are explicit: every round-3 run sets
  `RAYON_NUM_THREADS=16` and prints `rayon_threads` in its log.
- (c) parity stays mandatory at every layer; receipts are unchanged in
  length and statement identity per honest run (same identity for the same
  export, layers and label; segment bytes differ only by fresh randomness).
- **Before/after per block** [MEASURED, shared box, n=1, 16 threads], same
  export (`pg_rot1_b4_T32_cal128`), layer 0, ho00, one-block CLI (`parity`
  event = sequence load + witness + parity): round-2 CLI **7.581 s** ->
  round-3 CLI **0.143 s** (53x); same statement identity c3b0d468...,
  same segment length 11,627,288 B (`r3/one-{before,after}-...`). In the
  22-block stack: round 2 built each witness twice, 10.1 s each (sealing
  230.6 s + rebuild 223.0 s of 529 s); round 3 builds it once, 0.122 s per
  block at T32, 0.231 s at T64, 0.583 s at T128.

### R3-2 context ladder profiles

- Registered `hashline-zk-mr1/private-block-tinyllama-1.1b-t64-trained/1`
  (row width 2^13) and `...-t128-trained-block/1` (2^14), run profiles
  `...-t64-trained-statement/1` and `...-t128-trained-statement/1`; one
  profile per shape (D17), 21 endpoint rows each, the smallest counted
  receipt of the admissible widths. The T128 block string carries a
  `-block` suffix because at 60 bytes its transcript constructor (71 B)
  would collide in length with the `pb-term` absorb in the same keyed
  function (`s25_tests` census refused it; at 66 bytes it is 77 B, free).
  `Shape::tinyllama_trained(T, cal, f_e)` (T32 is byte-identical to round 2),
  `RunShape::tinyllama_trained`, the same declared classes and the softmax
  rule (T64 window 15 bits, T128 16 bits, both two limbs); any other T is
  refused by name. `TINYLLAMA_TRAINED_PROFILES` carries the pinned-checkpoint
  rule to all three; the registries, census and statement tests cover them.
- Reader: the B4 writer names no `geometry`, so the geometry is the TinyLlama
  profile of the export's `T` (32/64/128; anything else refused; a named
  geometry must match its T). Hard-linked weight files are ordinary files:
  no digest check moved; `read_bounded` now REFUSES symbolic links
  (`symlink_metadata`). Test `the_reader_maps_t_to_the_registered_tinyllama_profiles`.
- One block of each b4 export (layer 0, ho00, round-3 CLI, 16 threads):
  T64 parity bit-exact (131,072 words) 0.295 s, prove 3.0 s, segment
  15,445,928 B, peak RSS 1.64 GiB; T128 parity bit-exact (262,144 words)
  0.609 s, prove 5.7 s, segment 23,049,272 B, peak RSS 3.39 GiB; each
  verified in a fresh process.
- **T256 / T512 not registered (memory gate + no export).** Measured
  one-block peak RSS doubles per T doubling (0.85 -> 1.64 -> 3.39 GiB), so
  T256 projects to about 7 GiB per block (stack about 9-10 GiB with the 1.25
  GB of blocks) and T512 to about 14 GiB, above this 15 GiB shared box. No
  T256/T512 export exists. Counted layouts stand (T256 at 2^15: 38.8 MB per
  segment, under the 256 MiB trained wire cap).

### R3-3 the ladder (22-block pg_rot1_b4 stacks, CPU and GPU)

10:48-11:03 UTC, scripts `r3_ladder_cpu.sh ho00` (CPU: T32, T64, T128, each
verified in a FRESH process with all 11 run-level controls, plus the
boundary-lie control on a 3-block T128 stack) and `r3_stack_gpu.sh <export>
ho00` (one GPU pass per invocation, launched one after another;
`HL_GPU=1 HL_GPU_REQUIRED=1`, header "gpu: ON — NVIDIA GeForce RTX 4070
Laptop GPU", 0 declines; verified in a fresh process by the CPU binary).
Same weights at every rung (the calibration lane's b4 family, cal128).
Table generated by `r3_ladder_table.py` from the logs and guard records
(`r3/LADDER.md`, `r3/ladder.json`) [MEASURED, shared box, n=1,
RAYON_NUM_THREADS=16 in round 3; round-2 rows used the 22-thread default]:

| rung | mode | total wall (s) | sealing (s) | witness (s) [per block] | proofs only (s) | in-proc verify (s) | fresh verify (s) | receipt (B) | peak RSS (GiB) | peak VRAM (MiB) | positions/s total | positions/s proofs |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| T32 (r2 ref) | CPU r2 | 529.0 | 230.648 | 222.999 [10.136] | 59.6 | 4.872 | 4.886 | 250,855,088 | 2.15 | - | 0.06 | 0.537 |
| T32 (r2 ref) | GPU r2 | 545.2 | 229.941 | 227.97 [10.362] | 68.1 | 4.901 | 4.979 | 250,855,088 | 1.99 | 1281 | 0.059 | 0.47 |
| T32  | CPU | 56.2 | 0.022 | 2.683 [0.122] | 40.2 | 3.015 | 3.152 | 250,855,088 | 2.15 | - | 0.569 | 0.797 |
| T32  | GPU | 60.8 | 0.023 | 2.774 [0.126] | 40.8 | 3.376 | 3.431 | 250,855,088 | 1.98 | 1281 | 0.527 | 0.785 |
| T64  | CPU | 84.9 | 0.013 | 5.085 [0.231] | 64.8 | 5.074 | 4.925 | 333,316,880 | 2.92 | - | 0.754 | 0.987 |
| T64  | GPU | 89.3 | 0.042 | 5.246 [0.238] | 63.5 | 5.097 | 5.011 | 333,316,880 | 2.31 | 2529 | 0.717 | 1.008 |
| T128  | CPU | 168.6 | 0.05 | 12.831 [0.583] | 136.2 | 9.042 | 11.1 | 497,665,904 | 4.82 | - | 0.759 | 0.94 |
| T128  | GPU | 142.8 | 0.045 | 12.872 [0.585] | 107.1 | 8.742 | 8.451 | 497,665,904 | 3.03 | 3105 | 0.896 | 1.195 |
T32 CPU r2 threads default (22) controls 11 declines 0 id 68ad19c83a3ae1a3 load 10.203 fresh-verify wall 34.4

Columns: total wall = guard child wall of the prove job (load about 9-10 s,
sealing, proving pass, in-process verify); witness = the single witness
pass (round 2: the rebuild only; its sealing pass rebuilt them all again);
proofs only = prove_run minus witness; positions/s = T / total wall and
T / proofs only. Statement identities: T32 9b71dfb0..., T64 c2a42c61...,
T128 53a5667d... (CPU and GPU runs of a rung agree). All CPU fresh verifies
ran the 11 run-level controls (all refused); the T128 boundary lie fails at
"slot 22 [IO-out endpoint equality]". Reading: the single parallel witness
pass took the T32 stack from 529 s to 56 s; the proofs now dominate (72% at
T32, 81% at T128); the GPU (commitments only) is level at T32/T64 and 21%
faster in the proofs at T128 (107 vs 136 s), with peak VRAM 1.3 / 2.5 /
3.1 GiB. Throughput rises from 0.57 to 0.76 positions/s (CPU) and 0.90
(GPU) at T128.

### Round-3 validation

- 11:03-11:16 UTC: full guarded release suite on the round-3 tree
  (`r3-suite-final.log`): lib 531 passed / 0 failed / 27 ignored, every
  integration target ok (676 passed in all); guard wall 766 s, peak RSS 4.16
  GiB. Same sources as both round-3 CLIs (`r3/manifest_cli_sources.json`:
  no file changed since the CPU build; the GPU build used the same tree).
- 11:16-11:18 UTC: heavy round-3 and TinyLlama tests in release
  (`r3-heavy.log`, 5/5, RAYON_NUM_THREADS=16): the parallel products equal
  the sequential ones at TinyLlama T64 dimensions; witness per block (dense
  synthetic words, best of 3) 0.134 s at T32, 0.285 s at T64, 0.607 s at
  T128; review F (naive p + 1) rejected at slot 17; the D16 item-6 half-p
  aliases rejected at the pg TinyLlama calibration; the T3 generic TinyLlama
  block proves (2.28 s) with every control refusing.
- Binaries: `r3/zk60_trained_block.release.bin` sha256 3a106486...,
  `r3/zk60_trained_block.gpu.release.bin` sha256 5c7a6c9f...
- `r3/round3-vs-review-r2.patch`: every source change since the frozen
  re-review copy `ops/zkp-mvp/trained-1b-review-r2/` (R2-a, R2-b, R3-1,
  R3-2); `r2/round2-vs-review-r1.patch` is kept.
- Disk: the round-3 run directories hold about 2.2 GB of segment bytes
  (`r3/stack-*/run/segment-*.bin`); the committable record is each run's
  `statement/segments.json` (lengths and SHA-256), `statement.json`,
  `expected.bin`, the logs and guard records.

**Round 3 status at hand-back:** R2-a and R2-b fixed with permanent tests;
R3-1 done (one parallel witness pass, 53x per block at T32, parity per layer
kept); R3-2 done for T64 and T128 (T256/T512 not registered: memory gate and
no export); R3-3 ladder measured at T32/T64/T128 on CPU and GPU, every run
verified in a fresh process. No job of mine is running.

## Round 4 (coordinator, 2026-10-17 ~11:20 UTC): Llama-3-8B at T=32

### R4-1 the trained Llama-3-8B profile

- Registered `hashline-zk-mr1/private-block-llama-3-8b-t32-trained/1` and
  run profile `hashline-zk-mr1/private-run-llama-3-8b-t32-trained-statement/1`
  (one per shape, D17; the s24/s25/s33 registry and hash-length census pass
  with them). `Shape::llama3_8b_t32_trained(cal, f_e)`: T32, width 4096, FFN
  14336 padded to 16384, 32 query heads of 128 over 8 key-value heads (group
  4, no padded head slot), row width 2^13 (21 endpoint rows), through the
  SAME trained door and declared classes. Counted layouts
  (`r4_tests::the_llama3_8b_counted_layouts`): 2^11 28,970,648 B; 2^12
  17,878,872 B; **2^13 14,856,216 B (registered, smallest)**; 2^14 18,374,872
  B; 2^15 30,177,688 B; 2^16 refused (Kv lifted by P-3). The validator
  DERIVES tn <= 9 at width 4096 (D_max 2,097,152, window 32, C-6); tn 10 is
  refused by name.
- RoPE base pinned PER PROFILE (`shape::trained_rope_theta`): 10000 for the
  TinyLlama profiles and the rung, 500000 for Llama-3-8B; the loader's
  `constants_of` and the statement's `check_honoured_by_code` refuse any
  other. The Rust generators reproduce the calibration lane's 8B table
  digests exactly: RoPE T32 head_dim 128 base 500000 d937dca078d3...,
  exp head_dim 128 f_e 9 e_s 1 a28d48125914..., e_s 2 423a43e7b2cf...
- Pinned-checkpoint rule for the 8B profile: `ModelSource::llama3_8b()`
  (NousResearch/Meta-Llama-3-8B rev 315b20096dc791d381d514deb5f8bd9c8d6d3061,
  config sha256 2430cee7..., 8,030,261,248 parameters, 32 layers; weights
  digest = SHA-256 of the canonical shard list `name hex\n` in name order =
  7b8447563053...). `ModelSource::pinned_for_profile` carries each trained
  profile's pin (TinyLlama x3, Llama-3-8B); another checkpoint or a synthetic
  recipe at the 8B profile is refused, and the TinyLlama pin at the 8B
  profile (or vice versa) too.
- Reader: an export naming no geometry is the geometry of its MODEL (the
  pinned Llama-3-8B repo -> the 8B profile, which fixes T = 32; otherwise
  TinyLlama at its T); the model block may carry `sha256` (one file) or
  `shards_sha256` (the B5 writer's four shards -> the canonical digest);
  exactly one is required; repo, revision and digest must equal the pin.
- `RunStatement::new_bound_from_digests` (the statement from the block
  digests alone, for runs whose blocks cannot all be resident; `new_bound`
  delegates to it); the registry census builds its L = 22 trained runs from
  one block's digest (22 clones of an 8B block would be 5 GB).

### R4-2 one generic block at the true 8B T32 geometry (memory gate)

- Test `r4_tests::native_r4_2_generic_llama3_8b_block_proves_verifies_and_every_control_refuses`
  (release, guarded; evidence `r4/generic/`): dense synthetic words, every
  query head and all 8 key-value groups live and different, the upper
  hidden half 98% live, the witness equal to the independent shape-driven
  kernel. Bands: TinyLlama's attn 8 refuses at the score at width 4096; the
  test picks the first admissible of a fixed list (attn 6 / gate 8 / down 2).
  Calibration: the B5 smoke constants with Cn_a 6380 / Cn_m 6672 (the
  smoke's Cn_m 834 gave max|y_m| 6 on synthetic words; the generic check asks
  >= 8); witness max |y_a| 43, |y_m| 46, |q8| 74, |s8| 93, |g8| 107.
- Memory gate: the FIRST run at need 6 / cap 9 GiB (as directed) measured
  peak RSS 1.94 GiB with the block proved (it then failed in a control
  helper whose shift move left its window at sh_h 16; fixed: moves now stay
  inside their windows). The completed run used need 3 / cap 5 GiB:
  [MEASURED, shared box, n=1, 16 threads] witness 0.57 s, **prove 4.68 s,
  verify from bytes 1.34 s, segment 14,856,296 B, peak RSS 1.95 GiB** (guard
  2.10 GiB); 11 coefficient / shift / receipt controls and 4
  inconsistent-witness controls refuse (tn-1 & Cn/2, cn_m+7 and sh_z-1 at
  slot 14; ceps x4 at slot 2). FRESH-process verify of the saved segment
  1.22 s, peak 924 MiB, the 11 verifier controls refuse there too. One 8B
  block at T32 fits this laptop with large margin. (An earlier attempt of
  mine waited for admission at need 6 while HOLDING the heavy lock; I
  stopped it with SIGTERM — the guard's documented graceful path — and
  re-queued at the measured need.)

### R4-4 phase breakdown of the T128 TinyLlama proofs

`HL_PB_TIMING=1` (the existing phase clock, `private_block/timing.rs`), one
guarded run each of the 22-block pg_rot1_b4_T128 stack with the round-3
CLIs (`r4_phases.sh cpu|gpu`); summed over the 22 per-block tables by
`r4_phase_table.py` into `r4/PHASES_T128.md` [MEASURED, shared box, n=1,
16 threads]:

| share of the block walls | CPU (152.2 s) | GPU (134.8 s) |
|---|---|---|
| zero-check sumchecks, slots 14 D / 18 F / 17 softmax / 15 Q / 16 KV | 27.5 / 17.6 / 11.5 / 8.0 / 4.4 s = 45% | 25.4 / 19.5 / 11.8 / 8.0 / 3.9 s = 51% |
| commitments A + H (encode + Merkle) | 16.6 + 18.1 s = 23% | 4.0 + 3.6 s = 6% |
| A: witness planes -> committed rows (allocation + conversion) | 17.7 s = 12% | 21.2 s = 16% |
| H: LogUp helper inverses (+ exp/act) | 6.9 + 1.4 s = 5% | 8.8 + 1.8 s = 8% |
| openings A + H | 5.2 + 3.6 s = 6% | 9.2 + 3.0 s = 9% |
| norm, lookup tables, endpoints, the rest | about 9% | about 10% |

Inside the slots, the masked sumcheck body (`zk.rs`) is most of each
(slot 14 21.1 of 27.5 s, slot 18 14.6 of 17.6 s), the extension rounds
the rest; table building is under 1 s per slot. Reading for the speed plan:
the GPU today accelerates only the commitments (34.7 -> 7.6 s); the
sumchecks (45-51%) all run on the CPU in both; the plane-to-row conversion
(12-16%) and the LogUp inverses (5-8%) are CPU work too; the GPU run's
openings and conversion are slower than the CPU run's (device-host
traffic). So: (1) the five zero-check sumchecks on the device, (2) a
parallel plane-to-row conversion, (3) batched parallel inverses.

### R4-3 the trained Llama-3-8B export: parity, one block, the 32-block stack

Export `results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_T32/`
(calibration lane, independently verified; no geometry key, model block with
`shards_sha256` -> the 8B profile; tn 9, Cn_a 2266, Cn_m 1557, Ceps 78617,
shifts qkv 8 / s 6 / ao 3 / g 8 / h 14 / z 5, f_e 9, RoPE 500000, per-layer
e_s and SiLU member). Round-4 CLIs (`r4/`, CPU sha256 ca736d48..., GPU
9b1ae93b...; sources `r4/manifest_cli_sources.json`, unchanged since).

- **Streaming blocks (needed for the 8B stack).** `run::BlockSource` (a slice,
  or a one-block cache), `prove_run_with` / `verify_run_with` /
  `verify_run_from_dir_with` (the slice forms delegate; the proving and
  verifying paths are otherwise unchanged). The stack CLI now (1) runs a
  DIGEST PASS (each layer loaded, its record and block digest kept, the block
  dropped), (2) builds the run statement from the digests
  (`new_bound_from_digests`), (3) proves with ONE block resident: a shared
  `BlockCache` reloads block k from the export when the witness source first
  asks (every array SHA-256-checked, tables against their generator members)
  and refuses it unless its digest is the statement's; the prover reads the
  same cached block, (4) verifies with a fresh cache, one block and one
  segment resident; the run-level controls stream the same way (an order
  map for the swapped-block controls). `trained_stack_tests` (3-layer rung
  stack, 11 controls, the boundary lie) passes on it (`r4-stream-fast.log`).
- **Parity and one trained block** (`r3_one.sh r4 ...`, `r3/one-r4-llama3_8b_pg_rot1_T32-*`,
  16 threads) [MEASURED, shared box, n=1]: parity BIT-EXACT (131,072 words)
  at layer 0 and layer 31 on BOTH held-out sequences (ho00 licence, ho36
  FineWeb), 0.53-0.63 s each; each block proves as a bound one-block run in
  3.1-3.6 s, segment 14,856,296 B, peak RSS 2.37-2.40 GiB with the controls
  run (1.91 without), and verifies in a FRESH process (0.39-0.53 s after a
  2.8-3.0 s layer load). Layer 0 / ho00 and layer 31 / ho36: 3
  inconsistent-witness controls refused at prove time and all 19 verifier
  controls refused in the fresh process (`verify-controls.log`).
- **THE 32-BLOCK Llama-3-8B STACK AT T=32, ONE BOUND RUN**
  (`r4_stack.sh cpu|gpu ho00`, `r4/stack-llama3_8b_pg_rot1_T32-ho00-{cpu,gpu}/`):
  parity BIT-EXACT at all 32 layers inside the proving pass; receipt
  465,815,776 B (32 segments); statement identity 259dad7cb2c9739e44cfdf5c27c4c87090458cf330e9d39b592221094ae3537f
  (CPU and GPU agree); verified in a FRESH process from the directory; the
  CPU run's verify ran all 11 run-level controls (all refused, the honest
  run still verifies). GPU: "gpu: ON — NVIDIA GeForce RTX 4070 Laptop GPU",
  `HL_GPU_REQUIRED=1`, 0 declines, peak VRAM 2,369 MiB.

Table (`r4_table.py` -> `r4/TABLE.md`, `r4/table.json`; [MEASURED, shared
box, n=1, RAYON_NUM_THREADS=16]; "block loads" = reloading each block from
the export inside the proving pass; proofs only = prove_run - witness -
block loads; "crypto only" = fresh verify minus its block loads):

| run | mode | blocks | total wall (s) | digest pass (s) | witness (s) [per block] | block loads in proving pass (s) | proofs only (s) [per block] | in-proc verify (s) | fresh verify (s) [crypto only] | receipt (B) | peak RSS (GiB) | peak VRAM (MiB) | positions/s total | positions/s proofs |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TinyLlama T32 (r3) | CPU | 22 | 56.2 | 9.703 | 2.683 [0.122] | 0.0 | 40.2 [1.83] | 3.015 | 3.152 [3.2] | 250,855,088 | 2.15 | - | 0.569 | 0.797 |
| TinyLlama T32 (r3) | GPU | 22 | 60.8 | 9.147 | 2.774 [0.126] | 0.0 | 40.8 [1.85] | 3.376 | 3.431 [3.4] | 250,855,088 | 1.98 | 1281 | 0.527 | 0.785 |
| TinyLlama T128 (r3) | CPU | 22 | 168.6 | 9.714 | 12.831 [0.583] | 0.0 | 136.2 [6.19] | 9.042 | 11.1 [11.1] | 497,665,904 | 4.82 | - | 0.759 | 0.94 |
| TinyLlama T128 (r3) | GPU | 22 | 142.8 | 9.393 | 12.872 [0.585] | 0.0 | 107.1 [4.87] | 8.742 | 8.451 [8.5] | 497,665,904 | 3.03 | 3105 | 0.896 | 1.195 |
| Llama-3-8B T32 | CPU | 32 | 384.5 | 83.012 | 18.629 [0.582] | 79.222 | 110.2 [3.44] | 93.356 | 96.103 [13.3] | 465,815,776 | 1.9 | - | 0.083 | 0.29 |
| Llama-3-8B T32 | GPU | 32 | 391.3 | 79.49 | 18.109 [0.566] | 77.997 | 117.7 [3.68] | 92.741 | 90.935 [13.2] | 465,815,776 | 1.57 | 2369 | 0.082 | 0.272 |

Reading: one Llama-3-8B block at T32 costs 3.4 s of proofs (CPU), against
1.8 s for a TinyLlama block, and the whole 32-block stack fits in 1.9 GiB
of RAM by streaming. The new overhead is loading the 8B weights: about 2.5 s
per layer, done three times (digest pass 83 s, proving pass 79 s, in-process
verify 83 s), which makes the total 385 s against 110 s of proofs; the
fresh verifier's cryptography is 13 s of its 96 s. Levers: skip the
in-process verify in production runs (the fresh verify is the check), keep
the digest-pass records so the proving-pass reload need not recompute the
padded-word SHA-256 (`LayerRecord::of_block`), and hash the arrays once. The
GPU (commitments only) is level with the CPU at this size (117.7 vs 110.2 s
of proofs), as at TinyLlama T32/T64; R4-4 says why (sumchecks 45-51% on the
CPU in both).

### Round-4 validation

- 13:12-13:23 UTC: the first full release suite on the round-4 tree
  (`r4-suite-final.log`): 534 passed, 1 failed —
  `s25_tests::the_generator_is_never_cloned_and_each_prover_constructs_exactly_one`,
  a SOURCE census that looks for the run's one `ZkRng::from_os` inside
  `fn prove_run(`; round 4 moved that body into `prove_run_with` (`prove_run`
  delegates). The census row now names `prove_run_with` (test-only edit;
  the round-4 binaries are unaffected, their sources differ from
  `r4/manifest_cli_sources.json` in `s25_tests.rs` only).
- 13:23-13:31 UTC: full guarded release suite again (`r4-suite-final2.log`):
  lib 535 passed / 0 failed / 29 ignored, every integration target ok (680
  passed in all); guard wall 503 s, peak RSS 4.21 GiB.
- `r4/round4-vs-r3.patch`: every source change of round 4 against the
  round-3 tree (reconstructed as the frozen `trained-1b-review-r2` copy plus
  `r3/round3-vs-review-r2.patch`, checked file for file against
  `r3/manifest_cli_sources.json`); `r3/round3-vs-review-r2.patch` is kept.

**Round 4 status at hand-back:** R4-1 done (8B profile, per-profile RoPE,
pinned 8B checkpoint, reader); R4-2 done (memory gate: one 8B block 1.95
GiB, 4.7 s prove); R4-3 done (parity at layers 0 and 31 on both sequences,
trained blocks proved and fresh-verified with all controls, the 32-block
Llama-3-8B stack at T32 proved as ONE bound run on CPU and GPU and verified
in a fresh process with the run-level controls); R4-4 done (T128 phase
breakdown). No job of mine is running.

## Round 5 (coordinator, 2026-10-17 ~13:30 UTC): CS port, run hygiene + byte counters, re-measure

Amendment (ZK60_SPEED_PLAN_20261017.md): R5-3 DROPPED (it was never started
in this tree: no plane-to-row or batched-inverse change exists here). R5-2
became the speed plan's task 1 (skip in-process verify by default, hash the
weights once and in parallel, reuse the digest-pass records with no TOCTOU,
per-phase byte counters, witness and conversion reported apart). No GPU
sumcheck work in this tree.

### R5-1 the 125M lane's later rulings (port, source applied 13:40-14:16 UTC)

Read-only source: `/home/victor/wt-zk60-block125m` (its stage 40-44 tests and
`ZK60_SHAPED_REFUSAL_CENSUS.md`). What this tree now carries:

- CS-1 + S38-F1(a): `FeedForwardPublic::check_words` / `check_for_shape`
  (the feed-forward statement against the shape it is proved at; `act[128]`
  must be 0 where `Dom::F` pads). Called by `new_shaped`, the witness
  builder, `prove_inner_at`, `prove_core`, `verify_bytes_at`,
  `verify_inner_at`, `verify_core`.
- CS-3: the honest prover refuses a lookup miss (U8 / exp / act) by family
  name, never a count, before its `A` commitment (`refuse_lookup_misses`).
  The `#[cfg(test)]` `CheatingProver::on()` switch turns it off; the tamper
  harnesses (`tamper.rs`, `norm_alias.rs` incl. this tree's bound-run alias
  helper, `rung_tests::assert_verifier_rejects`, `review_tests::outcome`,
  the run tamper loop in `run_tests.rs`) prove with it on, as in the 125M
  lane, so the verifier still has to speak.
- CS-4: attention `check_words` / `check_for_shape`; `IoSpec::check_for_shape`
  (plane, construction, parameters, hash tag) at every prover and verifier
  entry, before anything is hashed. `hash_tag_tests` ported (each verifier
  is handed its own rule's policy; the other rule's policy is refused by
  CS-4's name).
- CS-6: the run's blocks must be the statement's, refused BY NAME before
  anything is absorbed — count first (`blocks.len() == L`), then
  `blocks[k].digest() == st.block_digests[k]` for every k. In `prove_run_with`
  / `RunVerifier::start` (hence `prove_run`, `verify_run`, `verify_run_with`,
  `verify_run_from_dir`, `verify_run_from_dir_with`) and the run-statement
  file reader. STREAMING ADAPTATION: a `BlockSource` cannot hand every block
  up front without loading all of them, so the trait gained `count()`,
  `fit_the_shape()` and `are_the_statements()`; the trained `BlockCache`
  answers `are_the_statements` with its digest-pass list against
  `st.block_digests()` (CS-6 by name, before absorption), and every reload is
  compared with that digest again (no TOCTOU). Each block is still built
  through `new_shaped` at the shape, and `prove_core` / `verify_core`
  re-run CS-1/CS-4 before the stage commits.
- CS-7: `RunShape::new` refuses a run profile not registered for its block
  shape (frozen seven by equality; TinyLlama T32/T64/T128, rung-TC and the
  8B T32 profile through the trained door at the shape's own calibration and
  f_e). `RunShape` fields are private (accessors `sh()`, `l()`, `profile()`).
- CS-8: `Shape::check_constructed` (rebuilds and compares, naming the fields
  that differ), `Layout::check_is_for_shape`, IoSpec scale pin; called first
  at every single-block entry and in both shared bodies.
- CS-9: `Shape::new` refuses a registered block profile string at any shape
  but its own, by name (release builds also refuse unregistered strings;
  test builds admit them, as in the 125M lane). The registry is the nine
  frozen constructors plus `trained_geometry` (TinyLlama T32/T64/T128, the
  8B T32 profile and rung-TC at the requested f_e). Tests that wrote a
  registered string at another geometry now reach the same value by a
  test-side field write (`review_tests` head layout, `review_d24` r2_1).
- G-2: `run_capture::SHARED_SOURCE_FILES` now pins
  `zkp-core/src/pcs/encode_buffer.rs` and
  `zkp-core/src/sumcheck/{rounds,grouped}.rs` (26 files).
- Tests: `cs_port_tests.rs` (one named test per ruling, adapted to this
  tree's shapes; the 125M lane's `s40`-`s44` files assume the 125M capture
  and k8 rung, which this tree does not have) plus the edits above.

### R5-2 (speed plan task 1) run hygiene + byte counters (source applied)

- In-process verify OFF by default (`stack-prove --verify-in-process` turns
  it on; `--lie-at-boundary` forces it). The `proved` event says
  `in_process_verified`.
- Weights hashed once and in parallel: the nine `LayerRecord::of_block`
  word hashes run in parallel; the array loads of a layer run in parallel;
  `pad_matrix` is parallel. The proving pass's `BlockCache` reloads WITHOUT
  the per-array SHA-256 (`reload_block`) and checks each reloaded block's
  public digest against the digest-pass record (the soundness check stays;
  only the duplicate file hash goes). `weights_vanish_off_support` runs a
  parallel pre-scan and falls back to the sequential loop on a violation (same
  first error).
- Phase clock (HL_PB_TIMING=1): new `run (witness, boundary)` half; marks
  "run: block load + witness (the source)", "run: boundary B_k commitment",
  "run: witness hand-over" separate witness/conversion from the stage
  commitments; every row carries bytes and GB/s (A/H commitments
  8 * rows * n * inv_rate, openings 8 * rows * n, inverses 16 per word,
  sumcheck slots 16 * table terms).

### Round 5 resumed (evening session, after the 18:21 UTC reboot)

- 18:28 UTC: resumed from this ledger + `ops/zkp-mvp/LANE_RULES_20261017.md`.
  Nothing of mine running; `r5-suite-a` never started (exit 70, refused at
  the 14:59:48 UTC shutdown). 20 sources were edited after `r5-compile`
  (13:43 UTC), so that compile does not cover the R5 tree.
- `r5/round5-vs-review-r3.patch` (2,440 lines, 22 files): every source change
  of round 5 against the frozen `ops/zkp-mvp/trained-1b-review-r3/` copy
  (= the round-4 tree incl. the s25 census fix; checked file for file against
  `r4/manifest_cli_sources.json`).
- 18:30 UTC: queued `r5_build.sh r5b` (detached; guarded build jobs: CPU CLI,
  release test binaries `--no-run`, GPU-feature CLI; source manifest
  `r5/manifest_r5b.json`, tree a0b503d7...). Another lane's
  `b1-testbin-debug` held the heavy lock at queue time.
- 18:33 UTC: queued `r5_chain.sh` (detached): waits for the builds, then the
  full guarded release suite (`r5-suite`), then the task-1 acceptance runs
  (`r5_stack.sh`: Llama-3-8B T32 ho00 CPU, TinyLlama T32 and T128 ho00 CPU,
  HL_PB_TIMING=1, no in-process verify, fresh-process verify with
  `--controls`). The 8B prove cap is 9 GiB (R4's sat at its 6 GiB cap: the
  kernel cap counts page cache).
- 18:38-18:39 UTC: `r5b-cli-build` exit 0 (58 s) — compiled BEFORE the r3_6
  fix below, so it is superseded.
- 18:40-18:41 UTC **review r3 finding r3_6 (verifier DoS, coordinator
  relay) FIXED**: `run::read_segment_bounded` (run.rs) computes the
  verifier's own counted length `wire::segment_len(stage_layout(k),
  seg_geom(k))` first, refuses it above `wire_ceiling`, refuses anything
  `symlink_metadata` does not call a regular file and any length != counted,
  BEFORE opening; opens with `O_NOFOLLOW | O_NONBLOCK` (x86-64 Linux; no libc
  dependency, so the flags are the arch's constants), re-checks the opened
  file (`fstat`: regular, length), reads through `take(want + 1)` and
  re-checks the length. `verify_run_from_dir_with` and the CLI's
  `stack_controls` (via the honest run statement) read only through it.
  Tests: `run_tests::review_r3_6_a_symlink_fifo_or_overlong_segment_file_is_refused_before_it_is_read`
  (/dev/zero symlink, FIFO, counted + 1 B, 512 MiB sparse; each refused by
  name from metadata; honest run verifies before and after) and four CLI
  cases added to `trained_stack_tests::the_stack_cli_proves_three_chained_layers...`
  (stack-verify refuses a /dev/zero segment, a FIFO, one byte too long, a
  FIFO with `--controls`; the restored run verifies). The queued suite
  compiles the fixed tree; `r5_stack.sh` rebuilds both CLIs once from it
  (`r5_build_cli2.sh`, marker `r5_cli2.done`) before the first acceptance run.
- 18:48-19:02 UTC `r5-suite` (guarded, 846 s, peak RSS 4.58 GiB): lib **542
  passed / 1 failed / 29 ignored**; cargo stopped before the integration
  targets. The one failure, `cs_port_tests::cs6_the_run_prover_and_verifiers_refuse_blocks_that_are_not_the_statements`,
  was the TEST's own error: its final honest control re-ran
  `prepare_endpoints` (fresh randomness, other endpoint roots) but proved
  under the first statement, so the honest run failed with "expected
  endpoint root mismatch". Fixed 19:03 UTC (test only): the control builds
  its statement from the fresh owners' policy, proves, verifies, and the
  verifier still refuses the other block under it (CS-6 by name). Every CS-6
  refusal assertion before it had passed.
- 19:03 UTC queued `r5_suite2.sh r5-suite2` (detached, `--no-fail-fast`).
- 19:07-19:08 UTC `r5_build_cli2.sh`: CPU CLI rebuilt (29 s), GPU CLI already
  current (built 18:46-18:47 from the fixed tree); both binaries carry the
  r3_6 refusal texts. `r5/zk60_trained_block.release.bin` sha256 c066a382...,
  `.gpu.release.bin` 2bd95f1b... (`r5/binaries.sha256`). Called "cli2" below.
- 19:08-19:12 UTC **Llama-3-8B T32 ho00 stack, R5 cli2, CPU** (guard child
  wall 267.8 s, peak RSS 2.04 GiB, cgroup 4.84 GiB of the 9 GiB cap)
  [MEASURED, SHARED BOX, n=1 — three calibration-lane `light` Python jobs
  were live and using about 4.3 cores, plus another lane's build]:
  statement identity **259dad7c...** (unchanged), receipt 465,815,776 B,
  **all 32 segment lengths equal R4's** `segments.json`; parity bit-exact at
  all 32 layers; in-process verify OFF. Digest pass **25.5 s** (R4 83.0;
  target <= 20), proving-pass block loads **24.2 s** (R4 79.2; target <= 30),
  witness 30.5 s (0.95 s/block; R4 0.58, contention), proofs only 187.3 s
  (5.85 s/block; R4 3.44 — contention: slot 14 at 88.9 ns per element-term
  against the model's 63.8), **total 267.8 s** (R4 384.5; target <= 180, NOT
  met on this shared run). Byte counters: A 13,901,824 words, H 14,401,536,
  lookups 11,714,560 per block = the counted layout.
- 19:12-19:15 UTC fresh-process verify of that run with `--controls` (193 s
  wall, R4 456 s): verified (45.8 s, of which block loads 23.8 s); **11
  run-level controls refused**, honest still verifies. FINDING (mine, R5-1
  port): four of them (norm_cn_a + 1, sh_z, sh_qkv, f_e) were refused by the
  streaming `BlockCache::fit_the_shape` ("the block cache was built for the
  shape ...", whole-shape equality) instead of by the run binding R4 reached
  ("this segment belongs to another run"): a WEAKER control. Fixed
  19:15-19:18 UTC in `trained_block.rs`: `fit_the_shape` compares the block
  statement's geometry (profile, axes, padded axes; calibration constants are
  not in a block's words, `f_e` is CS-4's per-block re-check), and
  `stack_controls` now FAILS a calibration control whose buildable verifier
  is refused by anything but the wire's statement binding (`private run
  wire:` — the run tag, or the counted length when the layout moves; R3's
  TinyLlama T128 f_e control was the latter). Needs a CLI rebuild ("cli3")
  and a re-run of the 8B verify.
- 19:15-19:18 UTC TinyLlama T32 ho00 stack, cli2, CPU [shared box, n=1]:
  identity **9b71dfb0...** (unchanged), receipt 250,855,088 B, fresh verify
  accepted, 11 controls refused (same four by the cache guard).
- Source manifest after these edits: `r5/manifest_r5_1918.json` (tree
  d67fae7e...).
- 19:23-19:27 UTC TinyLlama T128 ho00 stack, cli2, CPU, HL_PB_TIMING=1
  [shared box, n=1]: identity 53a5667d... (unchanged), receipt 497,665,904 B,
  all 22 segment lengths equal R3's; wall 189.6 s, proofs 168.6 s (R3 136.2;
  contention), digest pass 2.0 s (R3 9.7), witness 16.7 s; fresh verify
  accepted, 11 controls refused (four by the cache guard, as above).
  **Byte counters = counted totals** (`r5_bytes_check.py`, every one of the
  22 tables): A 1993 rows = **32,653,312 words** (the plan's number), H 2182
  rows = 35,749,888, U8 lookups 28,999,680, exp + act pairs 1,572,864;
  A / H commit bytes 8 x words x rate 4, openings 8 x words, inverses 16 B
  per word (`r5/bytes_check_tinyllama_T128.txt`; the same check passes on
  the 8B T32 run, `r5/bytes_check_8b_T32.txt`). The slot rows print
  element-terms as `2^(main + ext) x tables` (the sumcheck cube times its
  table count), which is NOT the speed plan's `size x terms` convention
  (e.g. slot 18 at TinyLlama T128: 44,040,192 printed vs 1,048,576 x 17 =
  17,825,792); both are recorded.
- `r5_table.py` -> `r5/table.json`: identity, receipt bytes and every segment
  length equal the previous round's run of the same stack for 8B T32,
  TinyLlama T32 and TinyLlama T128.
- 19:28 UTC launched `r5_freeze_and_remeasure.sh` (detached): waits for
  `r5-suite2`; only if it is green AND it started after the 19:18 edit AND
  the working tree still equals `manifest_r5_1918.json`: copies the tree to
  `r5/frozen-tree/` (manifest `r5/manifest_frozen.json`, `r5/FROZEN.txt`),
  rebuilds both CLIs ("cli3", cli2's kept in `r5/cli2/`), re-runs the 8B T32
  CPU stack with fresh verify + 11 controls (`r5/stack-...-ho00-cpu-cli3/`),
  and re-verifies the TinyLlama T32 run with cli3 controls.
- 19:31-19:48 UTC **`r5-suite2` GREEN** (guarded, 1,028 s, peak RSS 4.90
  GiB; started 19:31:35, after the last edit; `--no-fail-fast`): **29
  targets, 688 passed, 0 failed, 29 ignored** (lib 543 / 0 / 29; every
  integration target and doc-test ok). Includes the frozen toy pins (toy
  schedule digest, parameter line, 2,816,472-byte receipt), the archived
  receipts and slot-IR digests, all `cs_port_tests` (CS-1/3/4/6/7/8/9,
  S38-F1(a); cs6 passes), the r3_6 regression tests, the s24/s25/s33
  registry and census tests (`r5-suite2.log`).

**R5 tree frozen for review at 2026-10-17T19:48:50Z, sha256 manifest `results/zk60_1b_native_20261017/r5/manifest_frozen.json`** (tree d67fae7ef3d03bb6a30c89880ac41b6e4543b7f8b5df8040c8a29ba7404df952; source copy `r5/frozen-tree/`, equal to the working copy at the freeze; `r5/FROZEN.txt`; every source change against `ops/zkp-mvp/trained-1b-review-r3/` in `r5/round5-vs-review-r3.patch`, 2,695 lines, 23 files).
- 19:48-20:10 UTC (`r5_freeze_and_remeasure.sh`): freeze done; "cli3" built
  from the frozen tree (source manifest before and after = d67fae7e...):
  `r5/zk60_trained_block.release.bin` sha256 67652c92..., `.gpu.release.bin`
  fdce3c8a... (copies in `r5/cli3/`; cli2's in `r5/cli2/`); both carry the
  r3_6 texts and the CONTROL-WEAK guard.
- 20:10-20:13 UTC **Llama-3-8B T32 ho00 stack, cli3 (the frozen R5 tree),
  CPU** (`r5/stack-llama3_8b_pg_rot1_T32-ho00-cpu-cli3/`) [MEASURED, shared
  box n=1: one other lane's `light` job (tl-v4-l22-dense-f) live throughout,
  fid-s7 for the first 40 s; quieter than the 19:08 run]: identity
  **259dad7c...**, receipt 465,815,776 B, **all 32 segment lengths equal
  R4's**, parity bit-exact at 32 layers, in-process verify off. **Digest pass
  15.3 s** (R4 83.0; target <= 20: MET), **proving-pass block loads 16.0 s**
  (R4 79.2; target <= 30: MET), witness 21.4 s (0.67 s/block), proofs only
  118.8 s (3.71 s/block; R4 3.44), **total wall 171.6 s** (guard child wall
  172 s; R4 384.5; target <= 180: MET), peak RSS 2.04 GiB. Byte counters =
  counted totals (32 tables). Phase table with ns per unit and GB/s:
  `r5/PHASES_8B_T32_cli3.md`.
- 20:11 UTC (after cli3 was built, so the frozen tree and its binaries are
  untouched): applied the task-3 source (scratch patch script
  `apply_8b_profiles.py`, every pattern matched once): Llama-3-8B T64 / T128
  block profiles `hashline-zk-mr1/private-block-llama-3-8b-t{64,128}-trained/1`
  and run profiles `...private-run-llama-3-8b-t{64,128}-trained-statement/1`
  (D17: one per shape; same door, classes, RoPE 500000, pinned checkpoint;
  row widths 2^13 / 2^14 = the smallest counted receipts, 37 endpoint rows),
  `Shape::llama3_8b_trained(T, ...)`, test-only `Shape::llama3_8b_at`,
  `Geometry::Llama3_8B(T)` in the export reader (an 8B export with T 32 / 64
  / 128 maps to its profile; T32's scope text unchanged), registries
  (CS-7 / CS-9 / `TRAINED_CALIBRATION_PROFILES` / pinned source / census
  lists), and `ladder8b_tests.rs`. **PENDING INDEPENDENT REVIEW of the T64
  and T128 profiles.**
- 20:14-20:21 UTC `t3-lib` (guarded release lib suite on that tree, 407 s,
  peak 4.88 GiB): **545 passed / 0 failed / 31 ignored**, including the s25
  hash-length census and s24 / s33 registry tests over the two new profile
  pairs (no new equal-length pair), `the_llama3_8b_t64_and_t128_counted_layouts`
  (Rust counted A / H rows and receipts = the speed plan's replica: T64 2^13
  A 3229 / H 3534 / 21,697,512 B; T128 2^14 A 3405 / H 3790 / 29,300,856 B)
  and `the_t_dependent_nowrap_clauses_hold_at_the_8b_t64_and_t128_shapes`
  (c2 / c3 / pv / host-PV below p/2 at every f_e in 9..=16 at T64 and T128;
  the class-wide `nowrap_check.py` already covers every T with wrho_s <= 24).
- 20:21-20:26 UTC **task 3, generic dense Llama-3-8B block at T64, CPU**
  (`r5/ladder8b-T64-cpu/`, guarded release test
  `ladder8b_tests::native_ladder8b_generic_block_proves_verifies_and_every_control_refuses`,
  HL_PB_TIMING=1, 16 threads) [MEASURED, shared box n=1: tl-v4 `light` job
  live]: bands attn 6 / gate 8 / down 2 (TinyLlama's attn 8 refuses at the
  score, as at T32); generic witness (heads and all 8 KV groups differ, upper
  hidden half 98.2% live, max|y_a| 43, |y_m| 46, |s8| 103, equal to the
  independent shape-driven kernel); witness 1.51 s; prove (one-block bound
  run, statement + endpoints + block) 5.07 s, of which the block's
  PB-TIMING wall 4.27 s; verify from bytes 1.17 s; segment 21,697,592 B
  (counted receipt 21,697,512 + the run frame); peak RSS 3.85 GiB (guard
  3.90). Every control refused: 11 verifier coefficient / shift controls (tn-1
  by the counted length, the rest "this segment belongs to another run"),
  truncation and 3 mutations, R2-4, and 4 inconsistent witnesses rejected by
  the VERIFIER (slot 14 x3, slot 2; CS-3 did not pre-empt them). FRESH-process
  verify 1.24 s, peak 931 MiB, verifier controls refused there too.
- 20:26 UTC the T128 CPU ladder job (need 7 / cap 10) took the heavy lock and
  then waited for ADMISSION (budget: two other lanes' `light` jobs, 6 + 4
  GiB) — the guard holds its locks while it waits for admission, so it blocks
  every heavy job until the 6 GiB `light` job ends. My SIGTERM to that queued
  guard (its documented graceful path) was refused by the session classifier;
  it is left to start by itself. Lesson for my later big jobs: pre-check
  `zk60_resource_guard.py check --class cpu --need-gib N` for the budget
  before queueing on the lock.
- 21:03-21:10 UTC **task 3, generic dense Llama-3-8B block at T128, CPU**
  (`r5/ladder8b-T128-cpu/`) [MEASURED, n=1; the ONLY guarded job live — a
  quiet box]: bands attn 6 / gate 8 / down 2; generic witness (max|s8| 112,
  upper half 98.2% live, equal to the independent kernel); witness 2.38 s;
  prove 8.92 s, of which the block's PB-TIMING wall 8.15 s; verify from bytes
  1.37 s; segment 29,300,936 B (counted 29,300,856 + frame); peak RSS 7.07
  GiB (guard 7.14); every control refused (as at T64: 11 verifier controls by
  the wire binding, truncation, 3 mutations, R2-4, 4 inconsistent witnesses
  by the verifier at slots 14 / 2); FRESH-process verify 1.45 s, peak 939
  MiB, verifier controls refused. Phase table: `r5/ladder8b-T128-cpu/prove.log`
  (first PB-TIMING table) and `r5/ladder8b.json` (`r5_ladder_table.py`).
- Against the plan's written predictions (CPU, per block): T64 block 4.27 s
  vs 5.47 (-22%), T128 8.15 s vs 10.60 (-23%); T128 groups: commit 2.84 vs
  2.72 (+5%), zero-checks 3.34 vs 5.05 (-34%; D 1.25 / F 1.12 / S 0.40 /
  Q 0.35 / Kv 0.22 vs 2.15 / 1.43 / 0.53 / 0.57 / 0.37), inverses 0.55 vs
  0.67 (-17%), openings 0.48 vs 0.69 (-30%), conversion 0.21 vs 0.34 (-40%),
  rest 0.73 vs 1.14 (-35%); witness 2.38 vs 2.51 (-5%); receipt 29.30 MB vs
  29.3 (exact); peak 7.1 GiB vs 6.3 (+13%, the test process also holds the
  kernel-parity buffers). T-SCALING: T64 -> T128 block wall x1.91 measured vs
  x1.94 modelled; the softmax slot grows x1.74 (model x2.42): S-domain cost
  grows SLOWER than counted, not faster (the plan's section-7 worry).
  More than 15% off in several groups, so a refit (below) is owed.
- Refit, first pass (`r5/refit/`: copies of the plan's `cost_model.py`,
  `projection.py`, `layout.py`, originals' sha256 in `originals.sha256`;
  `refit.py` re-derives every coefficient with the plan's own formulas from
  the quiet 8B T128 block): it fits 8B T64 to -3.1% but UNDER-predicts the
  stacks (8B T32 cli3 stack per block 3.65 s measured vs 2.51 refit, -31%;
  TinyLlama r3 stacks -13..-20%), which the plan's TinyLlama-stack fit
  matched within 9%. Reading: a quiet one-block run is 20-30% cheaper per
  block than a block inside a stack on this shared box (contention during the
  stack runs, and cache / allocation effects of the streaming stack); the
  T-scaling agrees. The projection refit is therefore re-calibrated on a
  STACK at 8B T128 (task 4) before the section-5 numbers are re-run.
- 21:13-21:15 UTC fresh-process verify of the cli3 8B T32 run with
  `--controls` (116 s wall; R4 456 s): verified in 26.5 s, of which block
  loads 13.1 s (cryptography 13.4 s; R4 13.3); **11 run-level controls
  refused, honest still verifies**; the four calibration controls are refused
  by the wire binding again ("this segment belongs to another run", as in R4).
  21:15-21:16 UTC TinyLlama T32 run re-verified with cli3 `--controls`: 11
  refused, the same four by the binding; honest verifies (6.0 s).
- **TASK 1 / SPEED-PLAN TASK 1 ACCEPTANCE: MET** (frozen R5 tree, cli3, laptop
  CPU, shared box n=1): 8B T32 identity 259dad7c... unchanged; all 32 segment
  lengths = R4; fresh verify accepts and 11 controls refuse; TinyLlama T32
  identity 9b71dfb0... unchanged; byte counters = counted totals (A
  32,653,312 words at TinyLlama T128); digest pass 15.3 s (<= 20), proving-
  pass loads 16.0 s (<= 30), total 8B T32 wall 171.6 s (<= 180).
- 21:13 UTC launched `r5_t4_stack.sh 7.5 10.5 ho00` (detached; task 4): cli4
  build from the working copy (manifest `r5/cli4/manifest.json`, tree
  beb54f9d...), a budget pre-check OUTSIDE the lock, then one guarded cpu
  stack-prove of `llama3_8b_pg_rot1_b6_T128` (32 blocks, HL_PB_TIMING=1) and a
  fresh-process verify with the 11 controls.
- 21:27-21:36 UTC **task 4 (stretch): THE FIRST PRIVATE 32-BLOCK
  Llama-3-8B STACK AT T=128, ONE BOUND RUN, CPU** — "PENDING INDEPENDENT
  REVIEW OF THE T128 PROFILE", and run with "cli4" = the R5 frozen tree + the
  T64/T128 profiles (`r5/cli4/`, binary sha256 in `r5/cli4/binary.sha256`),
  i.e. BEFORE the R5b CLI changes below; it had already started when the
  privacy-review relay (P-1, "do this before task 4") arrived at ~21:29, and
  a queued/running guard cannot be stopped from this session (kill refused).
  Export `results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_b6_T128`
  (calibration lane: VERIFIED 18:37 UTC; tn 9, Cn_a 2092 / Cn_m 1424, Ceps
  78617, shifts qkv 8 / s 6 / ao 3 / g 8 / h 14 / z 4, f_e 9, RoPE 500000,
  per-layer e_s and SiLU member) [MEASURED, shared box n=1: a calibration
  `light` job live]: parity BIT-EXACT at all 32 layers (524,288 words each);
  statement identity 6aba46fbd12d14b053a0ec4afb29ba7b7dbad5ef4fe327213474a737b6e3fe24;
  receipt **922,711,264 B** (32 segments, 28.55-29.57 MB); guard wall **487.3
  s**, peak RSS 6.48 GiB (cgroup 8.6 of the 10.5 cap); digest pass 15.1 s,
  witness 97.3 s (3.04 s/block), block loads 12.3 s, proofs only 362.1 s
  (11.3 s/block); 0.263 positions/s total, 0.353 proofs only.
  21:36-21:39 UTC FRESH-process verify with `--controls` (180 s wall): verified
  (38.7 s, of which loads 15.3 s: cryptography 23.4 s); **11 run-level
  controls refused** (f_e by the counted length — the T128 layout moves),
  honest still verifies. Evidence `r5/stack-llama3_8b_pg_rot1_b6_T128-ho00-cpu/`.
- ~21:29 UTC coordinator relay: the independent privacy review
  (`results/zk60_privacy_review_trained_t32_20261017/REVIEW.md`) found P-1
  BLOCKING in the frozen R5 `stack-prove` (endpoints sealed from the export's
  words, so builder / parity refusals happen mid-run after segments exist —
  ruling H-1; and `statement/` written without a verification — M-9 /
  D12b(1)), plus P-3 (free `--label`, C-R1/C-R4/C-R5), P-5 (hidden input
  inside the verifier's export), P-6 (counts / positions in refusals), P-7
  (backend not in the artifact). To be fixed and frozen as R5b together with
  review round r4's findings (pending). Work in progress in scratch copies
  (applied to the working copy only after the queued GPU test build has
  compiled, so the task-3 GPU arm runs the task-3 tree).
- Refit, second pass (`r5/refit/refit.py`, `refit_stack.json`): calibrated on
  the 32-block TRAINED 8B T128 stack (task 4; per-block block wall 11.20 s,
  light contention): the PLAN's model is within -5.3% of that stack in total
  (10.60 vs 11.20 s) and within 15% in every group but the commitment
  (commit 2.72 vs 3.42 s, -21%; zero-checks 5.05 vs 5.10, -1%; inverses -5%;
  openings +5%; conversion +6%; rest +13%). The stack refit fits the 8B T32
  stack to -9% and the TinyLlama r3 stacks to +2 / +16 / +12%, but
  over-predicts the quiet 8B T64 one-block by 31%. So: block cost inside a
  stack on this shared laptop is ~37% above a quiet one-block run (8.15 s),
  the commitment being the most contention-sensitive phase; the T-scaling
  (T64 -> T128 x1.91 one-block) agrees with the model everywhere.
- Projection re-run with both refits (`r5/refit/projection_output_{stack,onebl}.txt`,
  copies of the plan's scripts, `G0` and the per-layer load made overridable;
  load per layer per pass = R5's measured 0.49 s instead of 2.5 s): the
  roofline columns are unchanged (counted bytes); section-5 anchored central
  at T512: S0 today's code 0.62 (plan) -> 0.59 (stack refit) / 0.80
  (one-block refit); S3 whole prover on the GPU 6.89 -> 6.61 / 8.56; S5 with
  triangle + zkAttn 9.36 -> 9.38 / 11.83 positions/s. 8B laptop CPU cold pass
  at T128: 470 s modelled (stack refit, R5 loads) vs 487 s measured (task 4).
  The plan's verdict stands: 50 positions/s needs the roofline regime.
- 21:44-21:48 UTC `t3-gpu-testbuild` (191 s): it compiled the working copy
  AFTER the R5b edits were applied (21:42), so the GPU test binary
  (`r5/ladder8b-testbin/lib-test.gpu`, sha256 in `binaries.sha256`) carries the
  R5b CLI code; the ladder test exercises only the library prover, which R5b
  does not touch.
- 21:48-21:52 UTC **task 3, generic 8B block at T64, GPU arm** (`r5/ladder8b-T64-gpu/`,
  `HL_GPU=1 HL_GPU_REQUIRED=1`, "gpu: ON — NVIDIA GeForce RTX 4070 Laptop GPU",
  0 declines, controls skipped by design): witness 1.57 s, prove 7.66 s, verify
  from bytes 1.63 s, segment 21,697,592 B (= the CPU arm's), peak RSS 2.38 GiB,
  **peak VRAM 4,417 MiB — OVER the lane's 4 GiB limit** (coordinator flag,
  21:53). Reading: at T64 both encoded matrices (A 3229 x 32768 x 8 B = 846
  MB, H 926 MB) stay under `HL_GPU_CHUNK_BYTES` (1 GiB) and so ride the
  RESIDENT path, plus their data rows and the context. At T128 the default
  would chunk (1.78 / 1.99 GB encodings), but the T128 GPU arm is NOT run as
  queued: at 21:53 I made `lib-test.gpu` non-executable so the chain's queued
  `r5_ladder.sh 128 gpu` fails at exec without touching the GPU (a queued
  guard cannot be stopped from this session). Next: re-run T64 with the
  chunked path forced (`HL_ZK_CHUNK=force`, same proof bytes per cuda.rs),
  read its peak, and run T128 forced only if that peak projects <= 4 GiB.

### R5b (privacy review P-1, P-3, P-5, P-6, P-7; review r4 pending)

Applied to the working copy at 21:42 UTC (developed in scratch copies, the
pre-edit tree is `r5/manifest_before_r5b.json`, tree beb54f9d...): files
`trained_block.rs`, `trained_block_tests.rs`, `trained_stack_tests.rs`,
`examples/zk60_trained_block.rs` (usage text only).

- **P-1 (a), ruling H-1 — refusal before the header.** `stack-prove` now runs
  ONE digest-and-sealing pass before anything of the run exists
  (`seal_and_record`): per layer, the full checked load and digest (the
  next layer's load beside the current witness build, two blocks resident),
  the witness BUILT by the witness builder from the previous block's output
  (its refusals), and parity against the export's `x_out` at EVERY layer;
  block 0's input plane must equal the export's `x_in`. Only then are the
  endpoints (the builder's own first-input / last-output planes) committed,
  the run statement bound and the run directory created. The witnesses are
  kept for the proving pass up to `--witness-cache-gib` (default 4); any
  not kept is rebuilt from its sealed input and refused, loudly, unless its
  output is the sealed one (`StackSource::witness_of`). The R3-1 speed gain
  is kept (one witness build per block when the budget holds them).
- **P-1 (b), M-9 / D12b(1) — a statement only after a verification.** With
  `--verify-in-process` the statement goes to `<out>/statement/` after the
  in-process verify; WITHOUT it (the default) the prover's statement goes
  BESIDE the run, `<out>.unverified-statement/` (+ `UNVERIFIED.txt`), and
  `stack-verify` promotes it to `<out>/statement/` only after its
  fresh-process verification (and `--controls`, if asked) passed, after
  checking that statement.json carries its own identity / context / policy
  and that segments.json names every verified segment by length and SHA-256
  (one rename). A failed run's removal is now checked (`fail_run`: a failed
  removal is reported in the refusal and on stderr).
- **P-3 / C-R4, C-R1:** `--label` admits only the deployment constant
  (`zk60-trained-stack`, `zk60-trained-block`), refused by name otherwise, on
  the provers and the verifiers; the two context hashes refuse a 40-byte
  input (C-R1; two unkeyed call sites kept, as the s25 census records).
  C-R5 holds by code (no tagged commitment on an unkeyed device path).
- **P-5:** `--seq-dir DIR` (a prover-private directory outside the export) as
  the alternative to `--seq ID`; BOTH verifiers refuse an export directory
  holding any `seq_*` entry ("hand the verifier a copy of the public files").
  Real-export verifier copies (plain copies, no hard links to another lane's
  inodes) for the re-runs: `r5b/verifier-exports/` (8.8 GB, disposable;
  not evidence).
- **P-6 / K-2:** parity refusals carry no count, position or value (the
  stack names the layer only); sequence-file refusals print no digest or size.
- **P-7:** `statement.json` (block and stack) records `backend`
  (`gpu::label()`), `gpu_declines`, and (stack) `prover_verified_in_process`.
- Tests: `trained_stack_tests` (free label refused before anything exists;
  default run writes only the unverified statement; a verifier refuses the
  seq-holding export; a wrong pin, a shorter range and a tampered
  segments.json do not promote; `--controls` verification promotes; the
  promoted run re-verifies; `--verify-in-process` + `--seq-dir`; an
  inadmissible chain (layer-1 parity) refused with NO run directory and no
  statement; the lie control leaves no statement anywhere; the r3_6 cases),
  `trained_block_tests` (parity text, verifier copy, label, both / one of
  --seq and --seq-dir, backend in statement.json).
- 21:52-21:57 UTC `r5b-check1` (guarded release lib build + the touched
  tests: trained_block_tests, trained_stack_tests, review_e, s25_tests,
  cs_port_tests, review_r3_6, trained_calib_tests): **36 passed, 0 failed, 4
  ignored (heavy)**. The full suite and the R5b freeze wait for review r4's
  findings (coordinator).
- 21:58-22:00 UTC **review round r4** (`results/zk60_d24_review_20261017/R4_VERDICT.md`,
  read 21:58): R5 ACCEPTED on soundness; r3_3 and r3_6 CLOSED; N-r4-b (the
  geometry-only `fit_the_shape`) accepted. Folded into R5b:
  - **r4_A (verifier DoS, new in R5):** `load_array_checked` now checks the
    manifest's dtype and shape against the code's expected alternatives
    BEFORE any read, bounds the manifest size by `MAX_ARRAY_BYTES`, and reads
    with the EXACT length (refused from metadata otherwise), on the digest,
    reload, RoPE and sequence paths. Test
    `trained_block_tests::review_r4_a_an_oversized_or_misdeclared_array_is_refused_before_it_is_read`
    (255 MiB sparse arrays refused by name, layer named, < 5 s; reload path
    too; a misdeclared wk shape refused before the read).
  - **r4_B (pre-existing race):** `run::read_regular_file_bounded` (the
    segment reader's discipline: lstat type / length before the open,
    `O_NOFOLLOW | O_NONBLOCK`, fstat re-check, `take(max + 1)`, length
    re-check) now backs `trained_block::read_bounded` (every export /
    artifact file) and `mvp_driver`'s `read_bounded` and its artifact segment
    scan. Test `run_tests::review_r4_b_the_bounded_file_reader_refuses_before_opening_or_reading`.
  - **N-r4-e:** array-load refusals name the layer.
  - N-r4-a (statement without verification) is P-1 (b) above.
- 22:00 UTC queued `r5b-suite1` (full release suite, `--no-fail-fast`;
  source manifest `r5/manifest_r5b-suite1.json`, tree 0a07d19a...).
- 22:12-22:29 UTC **`r5b-suite1` GREEN** (guarded full release suite,
  `--no-fail-fast`, 1,066 s, peak RSS 4.95 GiB; started after the last edit
  of 22:00; source tree 0a07d19a... = `r5/manifest_r5b-suite1.json`): **29
  targets, 692 passed, 0 failed, 31 ignored** (lib 547 / 0 / 31). Includes
  the frozen toy pins and archived receipts, the CS ports, the r3_6 / r4_A /
  r4_B regressions, the P-1 / P-3 / P-5 / P-6 / P-7 CLI tests, the
  s24 / s25 / s33 registry and census tests over the two new 8B profiles, and
  the ladder8b counted-layout and no-wrap tests.

**R5b tree frozen for review at 2026-10-17T22:30:00Z, sha256 manifest `results/zk60_1b_native_20261017/r5b/manifest_frozen.json`** (tree 0a07d19aa821f20c2d80b9a27168ab84b94ae14dbd8331596085a488c1f2950c; source copy `r5b/frozen-tree/`, equal to the working copy; `r5b/FROZEN.txt`; every change against the R5 freeze in `r5b/r5b-vs-r5.patch`, 2,000 lines, 12 files: the R5b privacy / r4 fixes AND the task-3 8B T64 / T128 profiles + `ladder8b_tests`, which are PENDING INDEPENDENT REVIEW).
- 22:51-22:53 UTC R5b CLIs built from the frozen tree (source manifest after
  the builds = 0a07d19a...): `r5b/zk60_trained_block.release.bin` sha256
  1a341478..., `.gpu.release.bin` 1c5ca1d1... (`r5b/binaries.sha256`); both
  carry the R5b refusal texts.
- 22:52-22:58 UTC **Llama-3-8B T32 ho00 stack on R5b, CPU**
  (`r5b/stack-llama3_8b_pg_rot1_T32-ho00-cpu/`) [MEASURED, shared box n=1: a
  calibration `light` job live]: the sealing pass (load + digest + witness +
  parity, BEFORE the header) 37.2 s, all 32 witnesses kept (3.03 GB of the 4
  GiB budget); identity **259dad7c...**, receipt 465,815,776 B, **all 32
  segment lengths = R4's**; proving pass 154.4 s (block reloads 19.1 s, no
  witness rebuilt, proofs 135.3 s); **total wall 192.0 s** (R5 cli3: 171.6 s
  — the difference is in the proofs, 135 vs 119 s, with the light job live;
  the sealing pass costs what the R5 digest pass + witness pass cost, 37.2 vs
  36.7 s); peak RSS 4.73 GiB (the kept witnesses; R5 2.04). The prover wrote
  only `run.unverified-statement/`. Fresh-process verify from the verifier's
  copy of the export (no seq_*; 142 s wall): verified (32.2 s, loads 17.0 s),
  **11 run-level controls refused**, honest still verifies, and the statement
  was PROMOTED to `run/statement/` (the unverified directory is gone).
- 22:58-23:00 UTC TinyLlama T32 ho00 stack on R5b, CPU
  (`r5b/stack-pg_rot1_b4_T32_cal128-ho00-cpu/`) [shared box n=1]: identity
  **9b71dfb0...** (unchanged), receipt 250,855,088 B, sealing pass 6.8 s, 22
  witnesses kept, total wall 65.7 s, peak RSS 2.18 GiB; fresh verify from the
  verifier's copy: verified, 11 controls refused, statement promoted.
- 23:21 UTC resume check (coordinator relay said a partial r4_A / r4_B edit
  might exist): NONE — the working copy equals the R5b freeze (tree
  0a07d19a..., `r5b/manifest_check_2321.json`); the r4_A / r4_B / N-r4-e edits
  were completed at 21:58-22:00, compiled and passed in `r5b-suite1`, and are
  in R5b.
- 23:05-23:19 UTC **task 3, GPU arm under the 4 GiB limit (chunked commit
  forced, `HL_ZK_CHUNK=force`)** [MEASURED, shared box n=1: a calibration
  `light` job live]: T64 (`r5/ladder8b-T64-gpu-chunked/`) peak VRAM **737
  MiB**, witness 1.64 s, prove 7.37 s, block wall 6.17 s, segment 21,697,592 B,
  verify 1.52 s; T128 (`r5/ladder8b-T128-gpu-chunked/`) peak VRAM **1,345
  MiB**, peak RSS 3.66 GiB, witness 3.75 s, prove 10.50 s, block wall **9.12
  s vs the plan's GPU-arm 8.78 s (+4%)**, segment 29,300,936 B (= CPU), verify
  1.81 s; both "gpu: ON — RTX 4070 Laptop", 0 declines, and each segment
  verified in a FRESH process by the CPU test binary with the verifier
  controls refusing. The resident T128 GPU arm was never run (its guard
  exited 126 at exec: binary disabled, 0 s, no VRAM).
- **Phase ladder (`r5/LADDER8B.md`, `r5/ladder8b.json`)**, block wall per
  block (PB-TIMING, run rows excluded) vs the plan's prediction: T64 CPU 4.27 s
  vs 5.47 (-22%); T64 GPU resident 6.55 vs 4.78 (+37%; 4,417 MiB); T64 GPU
  chunked 6.17 vs 4.78 (+29%); T128 CPU 8.15 vs 10.60 (-23%); T128 GPU chunked
  9.12 vs 8.78 (+4%). Keyed GPU commit: 6.43 ns per committed element at T128
  (plan 5.06), 12.5 ns at T64 (fixed costs dominate). The GPU arms' host-side
  phases (zero-checks 3.5 / 5.3 s, openings 0.68 / 0.89 s) ran with a light
  job live, so GPU vs CPU here is confounded by contention; the openings are
  slower on the GPU arm, as in R4-4 (device-host traffic). A GPU-arm G0 refit
  (3.0 s) is contention-dominated and NOT used in the projection (the
  projection outputs above use the plan's GPU constants).
- 23:24-23:37 UTC **task 4 ON R5b: the 32-block Llama-3-8B T128 trained
  stack with the R5b CLI** (`r5b/stack-llama3_8b_pg_rot1_b6_T128-ho00-cpu/`;
  PENDING INDEPENDENT REVIEW OF THE T128 PROFILE) [MEASURED, shared box n=1:
  the calibration lane's T128 `light` job live]: the sealing pass BEFORE the
  header 105.3 s (witness 103.3 s, 3.2 s/block), parity bit-exact at all 32
  layers; `--witness-cache-gib 0` (a T128 witness is ~0.45 GB, 32 would be
  ~14 GB), so the proving pass rebuilt all 32 (122.7 s, each checked equal
  to the sealed output); identity **6aba46fb...** (= the pre-R5b run),
  receipt 922,711,264 B, **all 32 segment lengths = the pre-R5b run's**;
  proving pass 501.1 s (loads 21.2 s, proofs 357.3 s = 11.2 s/block); **total
  wall 606.7 s** (pre-R5b 487.3 s: the extra is the second witness build),
  peak RSS 6.55 GiB. Fresh verify from the verifier's copy (186 s wall):
  verified (43.9 s, loads 18.5 s), **11 run-level controls refused**, the
  statement promoted to `run/statement/`.
- 23:37 UTC coordinator relay (privacy-gate lane draft section 5a, review r4
  note N-r4-d): added to the capture writer's source pins (`run_capture.rs`):
  `src/gpu/mod.rs`, `src/tables_v3.rs`, `../zkp-core/src/tables.rs`
  (SHARED_SOURCE_FILES, 26 -> 29) and `src/private_block/trained_block.rs`
  (OWN_SOURCE_FILES 16 -> 17; removed from NOT_ON_THE_RUNS_PATH, 3 -> 2);
  `gpu/cuda.rs`, `gpu/kernels.cu` (gpu-cuda feature only) and `layer.rs` /
  `wcache.rs` (older FFN provers) stay off, with the reason in a comment;
  `s24_tests::the_capture_writer_pins_every_run_layer_source_it_depends_on`
  asserts both the new pins and the exclusions with their reasons. Both files
  are `#[cfg(test)]` modules: no production byte and no CLI moves (the R5b
  CLIs of 22:51 stand). The P-fixes match the gate's operating rules: C-R4
  allow-listed label, P-5 no `seq_*` in the verifier's export copy (refused),
  P-6 parity refusal without count / position, P-7 backend recorded in
  `statement.json`.
- 23:39 UTC queued `r5b_refreeze.sh`: the full suite on that tree
  (`r5b-suite2`, manifest tree 44013397...), then — only if green and the
  tree has not moved — the R5b RE-FREEZE superseding the 22:30 copy (kept as
  `r5b/frozen-tree-2230-superseded/`).
- **NEXT ROUND (R6), item 1** (coordinator relay 23:49 UTC, from the
  calibration lane's `results/zk60_8b_calibration_20261017/B6_REPORT.md`; NOT
  in R5b): make the softmax score shift `sh_s` a PER-LAYER export constant
  instead of run-wide — in the trained statement, the schedule digest and the
  importer, validated per layer at the trained door, with the no-wrap clauses
  re-checked over the class (one-limb window 1..=8). Layer 1 at SH_S 7 lifts
  8B T128 held-out top-1 0.651 -> 0.673 and cuts KL 0.61 -> 0.50, with no
  layout, table or plane change. Goes with the review of the 8B T64 / T128
  profiles.
- 23:58-00:06 UTC `r5b-suite2` GREEN (guarded full release suite,
  `--no-fail-fast`, 481 s, peak RSS 4.39 GiB, tree 44013397... at its start):
  **29 targets, 692 passed, 0 failed, 31 ignored** (lib 547 / 0 / 31).

**R5b tree frozen for review at 2026-10-18T00:06:31Z, sha256 manifest `results/zk60_1b_native_20261017/r5b/manifest_frozen.json`** (tree 440133975de99fe06d091e4393bb5192f1d726c39f60cbbaef53326498b881d9; source copy `r5b/frozen-tree/`; `r5b/FROZEN.txt`; all changes against the R5 freeze in `r5b/r5b-vs-r5.patch`, 2,099 lines). It SUPERSEDES the 22:30:00Z R5b freeze above (copy kept as `r5b/frozen-tree-2230-superseded/`, `r5b/manifest_frozen-2230-superseded.json`): the only files changed are `run_capture.rs` and `s24_tests.rs` (the N-r4-d source pins; both `#[cfg(test)]`), so the R5b CLIs (`r5b/zk60_trained_block.release.bin` 1a341478..., `.gpu.release.bin` 1c5ca1d1...) and every R5b measurement above stand for this tree.

**Status at hand-back (00:07 UTC 2026-10-18):** task 1 green (R5 suite 688 / 0 / 29, R5 frozen 19:48:50Z; speed-plan task-1 acceptance met on R5 cli3: digest 15.3 s, loads 16.0 s, total 171.6 s, identities and lengths unchanged, 11 controls refused); R5b (privacy review P-1/P-3/P-5/P-6/P-7, review r4 r4_A/r4_B/N-r4-e, N-r4-d pins, and the task-3 8B T64/T128 profiles — those PENDING INDEPENDENT REVIEW) green and frozen 00:06:31Z; 8B T32 on R5b 192.0 s (shared box), TinyLlama T32 65.7 s, both identities unchanged, statements promoted only by fresh-process verifies; task 3 ladder measured at T64 / T128 on CPU and on the GPU arm (chunked, 737 / 1,345 MiB VRAM; the resident T64 arm hit 4,417 MiB, over the limit), refit and projection re-run (`r5/refit/`); task 4: the first private 32-block Llama-3-8B T128 stack proved and fresh-verified with 11 controls refused, on the pre-R5b CLI (487 s) and again on R5b (607 s), identity 6aba46fb... both times. No job of mine is running or queued; `r5/ladder8b-testbin/lib-test.gpu` is left non-executable on purpose (it is the binary of the resident GPU arm).

## Round 6 (coordinator, 2026-10-18 ~00:10 UTC): per-layer sh_s; quiet-box re-measure

Live tree `ops/zkp-mvp/trained-1b/` (R5b stays frozen at
`N/r5b/frozen-tree/`, tree 44013397..., for the reviewer and the gate).

- Item 1: per-layer `sh_s` (statement, schedule digest, importer; validated
  per layer at the trained door; no-wrap over the class; run-wide exports
  keep loading and keep their identities; a per-layer test with layer 1 at a
  different shift, bit-exact against an independent reference). Then tell
  the coordinator the export format, so the calibration lane can write
  `llama3_8b_pg_rot1_b7_T{32,64,128}`; then the 8B T128 stack on b7.
- Item 2: quiet-box re-measure of 8B T32 and T128 on R5b. 00:11 UTC queued
  `r6_quiet.sh` (detached): each run starts only when the guard `status`
  shows no guarded job and a free heavy lock; `r6_quiet_label.py` then labels
  it "quiet box" / "shared box" from the guard history (`box_label.json`).
- 00:12-00:17 UTC item 2, 8B T32 quiet run (R5b CLI, cache 4 GiB): stack
  prove 156.4 s wall, peak RSS 4.74 GiB; fresh verify 124.2 s, exit 0.
  The first label said "shared box" from a boundary tie (t16-r2-ladder's
  history end 00:12:46 truncated to the second = our start second; the
  heavy lock serializes heavy jobs). `r6_quiet_label.py` now treats overlaps
  <= 1.5 s as boundary ties (recorded in `box_label.json`): **quiet box**
  (guarded jobs only). T128 waits for the next quiet window.
- 00:19 UTC item 1 source edits complete (uncompiled until now): shape.rs
  `Shape::with_score_shift` (trained shapes only, window 1..=8, CS-8 rebuild +
  trained class); trained_statement.rs `LayerRecord.sh_s: Option<u32>`
  (encoded as `sh-score-layer` only when present -> run-wide identities
  unchanged; refused when equal to the run's or outside the window); run.rs
  per-stage shapes (`stage_sh_s`, `stage_shape(k)`, stage line suffix only when
  it differs, prove/verify cores at the stage shape); trained_block.rs
  importer (`sh_s` in `per_layer_constants_differ` + profile `sh_s` null; run
  base = the mode, ties to the smaller; per-layer witness shapes in the sealed
  chain; statement.json layer objects carry `"sh_s"` only when own). Tests:
  new `r6_tests.rs` (window/frozen, layout moves only in the calibration line,
  no-wrap over the class at 8B T128, canonical statement + identity binding,
  two-block bound run with block 1 at 6: proves/verifies, run-wide verifier
  and a 7-verifier refuse, a cheating 5-witness is rejected), and in
  trained_stack_tests a 3-layer per-layer export (layer 1 at 6, an
  independent kernel-shaped reference checked bit-exact against the witness)
  that stack-proves, verifies with controls, and a flattened copy re-pinned
  is refused. 00:19 queued `r6_check.sh r6-check1` (guarded, waits on the
  heavy lock behind another lane's build).
- 00:36 UTC review round r5 in (`results/zk60_d24_review_20261017/R5_VERDICT.md`):
  R5b ACCEPTED on soundness; 8B T64/T128 profiles ACCEPTED. Added to R6:
  r5_A (medium: stack-verify's promotion not bound to what was verified),
  N-r5-a (CS-3 miss refusal in the sealing pass), N-r5-c (label the P-7
  fields as prover claims), N-r5-d (rename the early `run_header` event;
  scope text "PENDING INDEPENDENT REVIEW" -> accepted). The first R6 check
  (r6-check1) compiled mid-edit and failed on two protocol.rs names and a
  test import (fixed); r6-check2 queued 00:48.
- R6 edits for the verdict (live tree, 00:40-00:50 UTC):
  * r5_A: `run::verify_run_from_dir_hashed_with` returns (length, SHA-256)
    of EXACTLY the bytes each step verified. `stack-verify` now: refuses a
    statement directory that is a symlink or holds anything but its files
    (`check_statement_dir`); reads expected.bin once (must be canonical);
    after the verify (and controls) requires the found statement.json to be
    byte for byte its own rendering with the writer and prover self-reports
    it names, and the found segments.json to be the verified hashes; for an
    unverified statement it then WRITES `<run>/statement/` itself into a
    fresh `statement.writing-<pid>` and renames it (refusing an existing
    target), then removes the prover's directory (re-checked, never
    followed); an existing statement/ is only checked (byte for byte).
    `promote_statement` is gone. The in-process path publishes the same way,
    its segments.json from the hashes it verified (must equal the sink's).
    Statement schema `zk60-trained-stack-run/2`: `statement_written_by`
    (three writers) and `prover_reported: {backend, gpu_declines, what}`.
    A test-only hook runs a writer of the run directory between the verify
    and the statement checks (r5_3 (b)).
  * N-r5-a: `protocol::check_lookup_misses` (the exp/act histograms factored
    into helpers shared with prove_core) runs in `seal_and_record` on every
    sealed witness, one layout per score shift.
  * N-r5-c: block statement too: schema `zk60-trained-block-run/2` with
    `prover_reported`.
  * N-r5-d: stdout `run_header` -> `prover_start`; SCOPE_8B_LONGER and two
    shape.rs comments now say accepted by review round 5.
  * Tests: trained_stack_tests `review_r5_3_the_published_statement_is_bound_
    to_what_was_verified` ((b) race refused, (b') verified hashes published,
    (c) 4 forgeries refused, (e) 5 edits of an existing statement/ refused,
    (d) symlinked dir refused); r6_tests CS-3 sealing check; existing stack
    test updated (+ a fresh verify of the in-process statement/).
  * sh_s window no-wrap, class-wide: `r6/r6_nowrap_sh_s.py` [COUNTED]:
    the score host relation (the only relation with sh_s constants) stays
    below 2^21.03 at sh_s 1..=8 for head_dim 64 and 128 (p/2 ~ 2^63; margin
    about 2^41); also the Rust test at the 8B T128 shape.
- 00:52 UTC **r6-check2 GREEN**: 68 passed, 0 failed, 7 ignored (heavy) of
  the targeted filters (r6_tests 6, trained_stack_tests incl. the per-layer
  export and review_r5_3, trained_block_tests, trained_statement, review_e,
  s24, s25, cs_port, trained_calib, review_d24, r4) [MEASURED 209 s wall,
  peak RSS 1.76 GiB, shared box]. Tree 83f1fdcb... (219 files; R5b + r6_tests.rs).
- 00:53 UTC sent the coordinator the export-format change (profile sh_s null
  + "sh_s" in per_layer_constants_differ + per-layer manifest constants.sh_s
  in 1..=8; base = the mode). Calibration lane writes b7 T128 first.
- 00:53 UTC queued (detached): `r6_compat.sh` (R6 CPU CLI build; the R5b
  proof bytes of 8B T32 and TinyLlama T32 copied into r6/compat-<v>/ with an
  R6-layout unverified statement via r6_compat_prepare.py, then R6
  stack-verify pinned to 259dad7c... / 9b71dfb0... twice: publish, then the
  byte re-check; then the R6 GPU CLI build) -> `r6_suite.sh r6-suite1`
  (full release suite) -> `r6_freeze.sh` (freezes only if the suite is green,
  the tree did not move and the CLI was built from the same tree) and
  `r6_b7_queue.sh` (waits, no lock, for the calibration lane's verify marker
  logs/*verify*llama3_8b_pg_rot1_b7_T128*.done = 0 with "errors": [] /
  "ok": true, checks the per-layer format, then `r6_stack.sh` on b7 T128 with
  a real verifier copy, prove -> verify --controls -> byte re-check).
- 01:03 UTC R6 CPU CLI built (78 s): `r6/zk60_trained_block.release.bin`
  from tree 83f1fdcb....
- 01:22-01:24 UTC **compat GREEN: R5b proofs verify under R6, run-wide
  identities unchanged** [MEASURED, shared box n=1]: 8B T32 (R5b quiet run's
  32 segments, 465,815,776 B) pinned to 259dad7c...: verified (load 15.7 s,
  verify 36.7 s), statement published by the verifier, re-check against it
  (statement-checked) exit 0; TinyLlama T32 (22 segments, 250,855,088 B)
  pinned to 9b71dfb0...: verified (7.7 s), published, re-checked exit 0.
  Since the transcript absorbs the run schedule digest, an R5b proof
  verifying under R6 also shows the run-wide schedule digest is unchanged.
  The re-laid unverified statement (r6_compat_prepare.py) passed R6's
  byte-for-byte check, so the re-layout was exact.
- 01:41 UTC calibration lane: b7 T128 VERIFIED (profile.json sha256
  040eb5cf..., layer 1 sh_s 7, others 6). My queue's format sanity check
  failed on its own bug (`p["layers"]` is a list; log kept as
  r6/b7_queue-1-failed-sanity-bug.out); fixed and relaunched 01:42: format
  OK ({1: 7}, base 6), sequence ho00, r6_stack.sh started (verifier copy,
  then the guarded prove; L22 passes have budget priority, the guard queues).
- 02:19 UTC R6 GPU CLI built (68 s, after a 53 min wait on the heavy lock):
  `r6/binaries.sha256`: CPU c17abef1..., GPU ffcb0bf6....
- 02:24-02:35 UTC **r6-suite1 GREEN**: full release suite, 29 test targets,
  700 passed, 0 failed, 31 ignored (heavy/env) [MEASURED 695 s wall, peak
  RSS 4.94 GiB, shared box].
- **R6 tree frozen for review at 2026-10-18T02:36:11Z, sha256 manifest
  `results/zk60_1b_native_20261017/r6/manifest_frozen.json`** (tree
  83f1fdcbdcda3687815a76d5dc7714bf6b49d413ccfd9bc5b595bd898406cc33; copy
  `r6/frozen-tree/`, note `r6/FROZEN.txt`, patch `r6/r6-vs-r5b.patch` 1,610
  lines; the CLIs above were built from this tree; R5b stays frozen).

### Session resume 04:21 UTC (usage-limit stop at ~03:17 UTC)

- The two guarded jobs that exited 1 at 03:17 are the REVIEW lane's (its
  own CLI `results/zk60_d24_review_20261017/r6/zk60_trained_block.review-r6.release.bin`,
  its scratch verifier copies), not this lane's; both are expected
  refusals, neither is an R6 incompatibility:
  * `r6-8b-b6-under-r6` (46 s): the reviewer's R6 CLI stack-verified the
    R5b b6 T128 run (`r5b/stack-llama3_8b_pg_rot1_b6_T128-ho00-cpu/run`, 32
    blocks, 922,711,264 B) pinned to 6aba46fb...: event `verified` (load
    12.6 s, verify 33.4 s) — so the run-wide b6 T128 proof bytes, identity
    and schedule digest are unchanged under R6 — then `rejected` at the
    statement check: that run's `statement/statement.json` is schema
    `zk60-trained-stack-run/1` and R6's r5_A rule accepts an existing
    `statement/` only byte for byte as the R6 rendering (schema /2). That
    is the rule working, not a proof failure; it is why the compat runs
    re-lay the R5b statement (r6_compat_prepare.py) before the R6 verify.
    An R5b-format `statement/` is never silently accepted under R6.
  * `r6-8b-b7-identity` (12 s): the reviewer's R6 CLI rebuilt the b7 T128
    trained statement from its scratch verifier copy with
    `--expect-statement 0000...` (an identity probe) and refused at the pin,
    before touching any artifact: "the rebuilt trained statement
    97c4acda9da994c11790c2c8ec93b44beecb21501686b7e25965d2c18f970566 is not
    the pinned 0000...". This gives the b7 T128 identity the native run
    below must reproduce. The artifact it named (`r6/stack-llama3_8b_pg_rot1_
    b7_T128-ho00-cpu/run`) did not exist yet (the prove had not been
    admitted), which a verifier would also refuse; the pin refusal came first.
- My detached jobs survived the stop (setsid): `r6_b7_queue.sh` ->
  `r6_stack.sh` (pids 300443/300460) is still in its budget pre-check
  (need 7.5 GiB; the gate's `tl-r5b-l22-zero-f` holds 6 of 11.89 GiB since
  03:38, so 13.5 > 11.89 blocks admission until it ends; the heavy lock is
  free); `r6_quiet.sh` (pid 236185) still waits for a quiet box for the T128
  re-measure. No `.done` for either yet. The 7.5 GiB need stays: the R5b
  b6 T128 prove peaked at 6.55 GiB RSS / 8.47 GiB cgroup.
- 04:23 UTC no partial edit: the working copy's manifest tree is
  83f1fdcb... = the R6 freeze (219 files; scratch manifest, not kept). The
  review lane opened its round 6 on the frozen copy at 02:37 (its ledger
  line 647 on); its b7 identity probe is the 97c4acda... above.
- 04:3x UTC review round r6 ACCEPTED R6 on soundness and the per-layer sh_s
  (`results/zk60_d24_review_20261017/R6_VERDICT.md`). Notes carried:
  N-r6-a (operating rule): evidence of a verification is a `stack-verify`
  log line or a re-run, never a directory's existence. N-r6-c: R5b-written
  statements need re-layout under R6 (`r6/r6_compat_prepare.py`). The
  reviewer re-verifies the b7 T128 stack from its own copy once it lands
  (expected identity 97c4acda9da994c1...).

NEXT ROUND (R7), item 1 — N-r6-b: a `statement.writing-<pid>` left by a
killed verifier blocks every later verify of that run (publish_statement_dir
refuses to create it) until removed by hand; refuse it by name with a hint
naming the file, or remove a stale one whose pid is dead (and only then).

### Session resume 2026-10-19 09:25 UTC (weekly usage stop ~05:00 UTC 10-18; box rebooted 21:29 UTC 10-18)

Both detached chains finished before the stop/reboot (guard times below
converted to UTC; the guard log prints PDT).

- **(1) 8B b7 T128 stack, per-layer sh_s (layer 1 at 7, run base 6), R6 CLI**
  (`r6/stack-llama3_8b_pg_rot1_b7_T128-ho00-cpu/`, `report.json`,
  `r6/b7_vs_b6quiet_phases.txt`) [MEASURED, n=1, **shared box**: the
  calibration lane's light `b5-b7_T32` export overlapped the whole prove,
  `box_label.json`]:
  * prove 04:50:34-04:58:26 UTC 10-18, exit 0: identity
    **97c4acda9da994c11790c2c8ec93b44beecb21501686b7e25965d2c18f970566** (= the
    reviewer's independent probe); parity **bit-exact at every layer** (all 32,
    seq ho00, against the calibration lane's integer reference, so layer 1's
    witness at SH_S 7 equals it); 32 segments, 922,711,264 B (= the b6 T128
    receipt: sh_s moves no plane or count); total 471.6 s = sealing pass
    101.3 s (with the N-r5-a CS-3 check) + prove_run 370.1 s (of which witness
    rebuilds 94.0 s, block loads 17.4 s); load 32.9 s; VmHWM 6,599 MiB, guard
    peak RSS 6.43 GiB / cgroup 8.69 GiB (cap 10.5).
  * fresh verify with controls (verifier copy, no seq_*): verified (load
    11.6 s, verify 34.6 s, guard wall 146.5 s incl. controls), **11/11
    run-level controls refused**, statement published BY THE VERIFIER
    (schema /2, `statement_written_by` stack-verify, layer object
    `{"layer": 1, ..., "sh_s": 7}`, run `sh_s` 6), unverified dir removed.
  * byte re-check (second verify against the published statement/):
    verified (32.3 s), `statement-checked`, exit 0.
  * phases (summed over 32 blocks): commit 116.5 s (31.6%; H commit 44.6,
    A commit 39.8), run/witness 95.4 s, residual zero-check 44.8 s, FF 43.8 s,
    attention 42.6 s, openings 15.9 s.
- **(2) quiet-box re-measure (R5b CLI)** [MEASURED, n=1]:
  * 8B T32 (`r5b/stack-llama3_8b_pg_rot1_T32-ho00-cpu-quiet`), prove
    00:12:46-00:15:22 UTC 10-18, **quiet box** (one boundary tie only):
    total 156.2 s = sealing 29.3 + prove_run 126.8 s (witnesses kept, cache 4);
    load 28.2 s; VmHWM 4,854 MiB; fresh verify 29.3 s. Shared-box R5b run
    for comparison: 191.8 s total / prove_run 154.4 s -> the shared box cost
    about 18% here.
  * 8B b6 T128 (`r5b/stack-llama3_8b_pg_rot1_b6_T128-ho00-cpu-quiet`), prove
    05:10:19-05:17:32 UTC 10-18, **quiet box** (the only "overlap" is its own
    verify starting in the same second): total 432.5 s = sealing 74.2 +
    prove_run 358.3 s (witness rebuilds 92.3 s, cache 0); load 27.2 s; VmHWM
    6,716 MiB, guard peak RSS 6.56 GiB / cgroup 7.8 GiB; fresh verify 33.1 s.
    Shared-box R5b run: 606.6 s total / prove_run 501.1 s -> about 29% here.
  * b7 (R6, shared) vs b6 quiet (R5b): prove_run 370.1 vs 358.3 s (x1.033),
    sealing 101.3 vs 74.2 s. Not separable at n=1: the b7 run shared the box
    with a calibration export, and R6's sealing pass adds the CS-3 miss check
    (~0.07 s per block at T128 by the prove-side phase "A: lookup values +
    the byte histogram" 0.036 s/block + exp/act 0.02 s/block, i.e. ~2-3 s of
    the 27 s); the receipt is identical.

## Round 7 (coordinator, 2026-10-19 09:25 UTC): N-r6-b, kept small

- 09:30 UTC edits (live tree, from the R6 freeze): trained_block.rs
  `clear_stale_writing_dirs(art)`, called by `stack-verify` right after the
  identity pin and the context, before the run directory is listed. Each
  `statement.writing-<pid>` entry: REMOVED when it is a real directory
  holding only expected.bin / statement.json / segments.json (regular files)
  and `/proc/<pid>` is absent (stdout event `stale-statement-writing-removed`);
  REFUSED by name with what to do otherwise (live pid, a link or file, other
  contents, a name that is not `<digits>`). A removal publishes nothing; a
  writer in another pid namespace whose directory is removed fails its own
  rename. Test `review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_
  refused_by_name` (live pid refused and kept, foreign file refused and kept,
  link refused and not followed, odd name refused, the killed-verifier case
  removed then verified + published + re-verified).
- 09:31 UTC queued `r7_chain.sh` (detached): targeted check -> CPU + GPU CLI
  builds -> full suite -> R7 freeze (only if green, tree unchanged since the
  check, CLIs from the same tree). Check tree 7ef76971....
- 09:4x UTC R7 item 2 (coordinator, privacy review round 2 Q-2): R6's
  `prover_reported.backend` was any printable string <= 256 chars,
  republished by the verifier (a C-R4-class free published field). Now
  `BACKENDS` = three build constants: `BACKEND_CPU_BUILD` = "gpu: off (built
  without --features gpu-cuda)" (byte for byte the R5b / R6 CPU builds'
  value, so their statements stay valid), `BACKEND_CUDA_BUILD_CPU_PATH`,
  `BACKEND_CUDA`; `backend_of_this_process()` picks one from the build and
  `gpu::enabled()` only (the device's description stays on prover stdout);
  `check_prover_reported` (backend in the list, declines 0 on the CPU path,
  <= 4096 with the device; refusal names the rule and the byte length, never
  echoes the text) runs in the prover before it writes a stack or block
  statement and in the verifier's `ProverClaims::of_statement` before any
  publication. Field stays labelled `prover_reported`. Test
  `privacy_q2_the_published_backend_is_one_of_the_builds_names` (300-char and
  unknown names refused end to end, nothing published; all three real names
  accepted, published, re-checked).
- The first R7 chain (09:31) was launched before Q-2; its freeze step
  refuses a moved tree, so it cannot freeze the wrong tree. A second chain
  starts after it ends.
- 09:45 UTC first R7 chain: check 46/46 (incl. N-r6-b), CLIs, full suite
  702/0 green, then **refused to freeze** ("the tree moved
  (manifest_check)": Q-2 landed after its check), as designed; outputs kept in
  `r7/attempt1-before-q2/`.
- 09:46-09:58 UTC second chain on the complete tree (N-r6-b + Q-2): targeted
  check 47 passed / 0 failed (incl. `review_n_r6_b_...`, `privacy_q2_...`,
  `review_r5_3_...`); CPU + GPU CLIs (`r7/binaries.sha256`: CPU e51cc6a4...,
  GPU 416dc64e...); **full suite 702 passed, 0 failed, 31 ignored** (29
  targets) [MEASURED 353 s wall, peak RSS 4.35 GiB, shared box].
- **R7 tree frozen for review at 2026-10-19T09:58:29Z, sha256 manifest
  `results/zk60_1b_native_20261017/r7/manifest_frozen.json`** (tree
  36a8aed17ea1ec9ca2dec89155edebcb19048f3a63789ded6ab74cc275c43520; copy
  `r7/frozen-tree/`, note `r7/FROZEN.txt`, patch `r7/r7-vs-r6.patch` 331
  lines, two files: trained_block.rs, trained_stack_tests.rs; CLIs built
  from this tree; R6 stays frozen).

## Round 8 (coordinator; opened 2026-10-19 13:31 UTC): every export-chosen calibration constant per layer (D32, fidelity)

The fidelity lane's `dg` variant (per-layer Cn + per-layer free shifts +
per-layer tables, zero new planes) closes ~52% of TinyLlama's log-perplexity
gap; it varies norm_cn_a, norm_cn_m, sh_ao, sh_h, sh_s, sh_z. R8 generalises
R6's mechanism from `sh_s` to all eleven NormCalibration constants (norm_tn,
norm_cn_a, norm_cn_m, norm_ceps, sh_ao, sh_qkv, sh_s, sh_o, sh_g, sh_h, sh_z),
classes unchanged. Out of scope, with reasons: `f_e` (moves the softmax
sigma_s limb count, so the plane list and the counted receipt: a structural
constant, not a calibration within a fixed layout); `rope_theta`, `sh_rope`,
`sh_u`, `f_p`, `f_ro`, `sh_r2` (pinned by the relations or the model, not
export choices); `exp_e_s` / `silu_member` are already per-block table keys.
Start tree = the R7 freeze (36a8aed1..., working copy unchanged).
- 13:3x UTC R8 edits (live tree):
  * shape.rs `Shape::with_layer_calibration(cal)`: trained shapes only;
    `derive_at_width` (every class unchanged: tn / cn / ceps / four-limb norm
    window, sh_ao <= 8, each shift in its window), then CS-8 rebuild, trained
    class, and `Ids` / `HIds` rebuilt and compared (plane list unmoved);
    `with_score_shift` is now its sh_s special case.
  * trained_statement.rs: `LayerRecord.own: [Option<i64>; 11]` over
    `OWN_FIELDS` (canonical order, sh_s FIRST with R6's labels:
    sh-score-layer / "score shift"), helpers `cal_field`, `apply_own`,
    `own_of`, `has_own`; encoding adds one label per own constant only;
    check_self refuses an own value equal to the run's and validates the
    layer's whole calibration at the door.
  * run.rs: `stage_cal: Vec<NormCalibration>`; stage line appends one clause
    per own constant ("; {label} {v} (the layer's own; the run's is {b})", so
    an sh_s-only stage line is R6's text); `stage_shape` via the door.
  * trained_block.rs loader: `per_layer_cal_fields()` (the OWN_FIELDS keys in
    `per_layer_constants_differ`); run base = the most common combination of
    the listed fields over the run's layers (ties: smallest in canonical
    order, sh_s first -> R6's base for sh_s-only exports); `masked` compares
    every non-listed constant; each layer's own fields recorded and its whole
    calibration validated at the door; sealing-pass witnesses at the layer's
    calibration (layout cache keyed by calibration); statement.json layer
    objects add each own constant under its export key (sh_s first).
  * tests: r8_tests.rs (door over every class incl. refusals, layout counts
    unmoved and only the constants' schedule lines change; statement labels /
    canonical refusal / identity per field; no-wrap over each class at all
    six trained profiles; two-block library run with block 1 own in all
    eleven fields, run-wide / shifts-only / norm-only verifiers refuse);
    trained_stack_tests `r8_a_fully_per_layer_calibration_proves_verifies_
    and_every_constant_is_bound` (4 layers, layer 1 own in all eleven, layer 2
    in seven; x_out = the independent reference kernel's at each layer's
    constants, asserted bit-exact against the native witness and again by
    stack-prove's parity; verify with controls; for EACH of the eleven, a
    verifier export with that one constant flattened, own statement pinned,
    is refused); R6 test literals ported.
  * `r8/r8_nowrap_classes.py` [COUNTED]: every clause with a per-layer
    constant, over its whole class, at all six trained profiles: worst 2^43.09
    (the norm quotient's x g Cn term), p/2 ~ 2^63, margin ~2^19.
- 13:37 UTC `r8_chain.sh` launched (check -> CLIs -> compat re-verifies of
  b7 (97c4acda...), 8B T32 and TinyLlama T32 under R8 -> suite -> freeze).
- 13:42 UTC first R8 check: 74 passed, 1 failed — my own door test expected
  tn 11 (and ceps 2^40) to be admissible at the rung; the door REFUSED them:
  a norm window of exactly 32 bits needs no scaled top-limb pin, so the H
  plane list moves (52 -> 50 at the rung). That is the plane-list guard in
  `with_layer_calibration` working; the test now lists them as refusals
  ("moves the plane list"). Consequence for exports, sent to the
  coordinator: at the trained profiles the norm window is exactly 32 bits
  (TinyLlama tn 10 at width 2048, 8B tn 9 at width 4096), so per-layer
  norm_tn must stay the run's (lower moves the plane list, higher leaves the
  class), while norm_ceps is free over its class (bits(D_max) stays). The
  fully per-layer 4-layer stack test PASSED on this first run. Outputs kept in
  `r8/attempt1-tn-test/`; chain relaunched 13:43 UTC (check tree 7f64276a...).
- 13:44 UTC export format sent to the coordinator (eleven keys; null in
  profile_constants + listed; manifest values; classes; the 32-bit-window
  rule for tn; base = most common combination; parity unchanged).
- 13:43-13:51 UTC R8 targeted check: 75 passed, 0 failed, 7 ignored (heavy)
  — all six new R8 tests plus the R6/R7 ones. CPU + GPU CLIs
  (`r8/binaries.sha256`: CPU e95fc03c..., GPU 3eba4de0...).
- 13:52-13:54 UTC **compat GREEN under R8** [MEASURED, shared box]: the R8
  CLI re-verified, read-only (`statement-checked`, byte check against the R6
  published statement/), the R6 **b7 T128 per-layer-sh_s run, pin
  97c4acda...** (verify 44.4 s) — so an sh_s-only per-layer identity AND its
  stage schedule lines are unchanged under R8 — and the run-wide 8B T32
  (259dad7c..., 36.0 s) and TinyLlama T32 (9b71dfb0..., 8.6 s) runs.
- 14:25-14:38 UTC **r8-suite GREEN**: 29 targets, 707 passed, 0 failed, 31
  ignored [MEASURED 809 s wall, peak RSS 4.40 GiB, shared box].
- **R8 tree frozen for review at 2026-10-19T14:38:35Z, sha256 manifest
  `results/zk60_1b_native_20261017/r8/manifest_frozen.json`** (tree
  7f64276abeceff666ff1269754bec83e0b0867b5d2812ae469bf76324d92ffb9, 220
  files; copy `r8/frozen-tree/`, note `r8/FROZEN.txt`, patch
  `r8/r8-vs-r7.patch` 1,042 lines over 10 files; CLIs built from this tree;
  R7 stays frozen).
- Owed after R8 (not blocking the freeze): the Python-reference parity at
  per-layer constants on a real export — the first per-layer export the
  fidelity lane writes in this format, run through `stack-prove` (parity is
  bit-exact against the export's x_out at every layer or refused).
- 14:45 UTC (coordinator) the fidelity lane's two per-layer exports in the
  R8 format (`results/zk60_fidelity_parity_20261019/exports/`):
  `tinyllama_dg_rot1_T128` (profile sha256 b01a6db1...; per-layer exp_e_s,
  norm_cn_a, norm_cn_m, sh_ao, sh_h, sh_s, sh_z, silu_member; run-wide tn 10,
  ceps 74429, qkv 8, gate 8, o 9, f_e 9) and `llama3_8b_pg_rot1_b7voc0_T128`
  (26fc103b...; per-layer exp_e_s, sh_s, silu_member). Queued
  `r8_fid_runs.sh` (detached): `r8_stack.sh` (the R6 stack script with the
  R8 CLI and r8/ paths) on each, seq ho00: prove (parity bit-exact at every
  layer against the Python reference's x_out, or refused) -> fresh verify
  --controls from a real seq-free verifier copy (the verifier publishes) ->
  byte re-check; then `r6/r6_b7_report.py` (now also lists every layer's own
  constants and the run calibration) and the box label.
- 15:59-16:04 UTC **(1) TinyLlama dg T128, per-layer, R8 CLI**
  (`r8/stack-tinyllama_dg_rot1_T128-ho00-cpu/report.json`) [MEASURED, n=1,
  **shared box**: the fidelity lane's light `fp-L_vocab0_8b_voc0_T32`
  overlapped 88 s of the prove]. Admitted after a 48 min budget wait.
  * identity **caf6ced22fbb87a94c1f571a96faf278815668996863146805c9d2eea76c9165**;
    **parity bit-exact at every layer (22 of 22, seq ho00) against the
    export's x_out — the Python integer reference (tlcalib.i_block) at each
    layer's own constants: R8's owed parity check, PASSED**; receipt
    497,665,904 B (= the run-wide pg_rot1_b4 T128 receipt: per-layer
    constants move no plane).
  * prove total 183.2 s = sealing 22.8 s + prove_run 160.3 s (witness
    rebuilds 3.2 s: 18 of 22 witnesses kept, 4.11 GB); VmHWM 7,700 MiB,
    guard peak RSS **7.52 GiB against a declared need of 5.5 (cap 8)**: the
    4 GiB witness cache dominates at TinyLlama T128; the R5 T128 run peaked
    at 3.63 GiB. No harm (min available 3.84 GiB) but the need was
    under-declared: future TinyLlama T128 stacks declare need 8 with cache 4,
    or use cache 0-1.
  * fresh verify with controls: verified (13.9 s), **11/11 controls refused**,
    statement published by the verifier; byte re-check: verified (12.5 s),
    statement-checked.
  * the run's calibration (base) = the most common combination of the six
    per-layer fields; every layer's combination is distinct, so the tie goes
    to the smallest in canonical order (sh_s first): layer 7's (sh_s 5,
    cn_a 2361, cn_m 598, sh_ao 4, sh_h 16, sh_z 4; run-wide tn 10, ceps 74429,
    qkv 8, o 9, gate 8). The other 21 layers record their own differing
    fields in statement.json (e.g. layer 0: sh_s 6, cn_a 1253, cn_m 1444,
    sh_ao 7, sh_h 14, sh_z 8); the table keys exp_e_s / silu_member per layer
    as before.
- 16:04-16:16 UTC **(2) 8B b7voc0 T128 (b7 with layer 0 recalibrated over
  the whole vocabulary), R8 CLI**
  (`r8/stack-llama3_8b_pg_rot1_b7voc0_T128-ho00-cpu/report.json`)
  [MEASURED, n=1, **quiet box** by the guard history (guarded jobs only)]:
  * identity **5585f5eed7a24a559ce76ddbd0413ddffd877637efb07d29bbd9408b4fc5a3b4**;
    **parity bit-exact at every layer (32 of 32, seq ho00)** against the
    export's x_out (the Python integer reference at each layer's constants);
    receipt 922,711,264 B (= b6 / b7).
  * prove total 478.7 s = sealing 84.8 s + prove_run 393.8 s (witness
    rebuilds 98.3 s, cache 0); load 27.2 s; VmHWM 6,849 MiB, guard peak RSS
    6.69 GiB / cgroup 9.76 GiB (cap 10.5).
  * fresh verify with controls: verified (42.7 s), **11/11 controls
    refused**, published by the verifier; byte re-check verified (34.4 s).
  * per-layer statement: run calibration tn 9, cn_a 2092, cn_m 1424, ceps
    78617, ao 3, qkv 8, score 6, o 9, gate 8, product 14, down 4, f_e 9; ONE
    layer with own constants: layer 1 `sh_s` 7 (as b7); layer 0's
    recalibration is in its words and table keys (exp_e_s 2, SiLU [-4, -12]),
    not in a calibration constant.
  * against the quiet R5b b6 T128 run (432.5 s total, prove_run 358.3 s) this
    is x1.10 on prove_run, and every phase is ~8-10% slower alike (commit
    121.3 vs 111.7 s, residual 49.9 vs 43.3 s, ...). R8 changes no kernel and
    31 of 32 stages use the run shape unchanged, so a uniform slowdown at n=1
    points to machine state (clocks, unguarded load), not R8; not a
    measured regression.
  * phase tables: `r8/fid_runs_phases.txt`.

## Round 9 (coordinator, 2026-10-19 ~16:2x UTC): build DD (per-row division dictionary) exactly as D30

Spec: `docs/zkmatrix-poc/ZK60_DECISIONS.md` D30 (conditions 1-6) +
`results/zk60_gpt_nonlinear_review_20261018/dd_check/CHECK.md` B-1..B-8,
E-1..E-4, P-4 + REVIEW.md §R2.4. Requirements: profile-gated (off by
default, existing receipts byte-identical), cap refusal at the door, every
slot constrained, tuples + multiplicities in A before beta/gamma/alpha,
distinct tag with beta^2 for P, table helper in the single value-0 sum claim
(sign -1), each plane opened at its own site, prover inverts every slot;
tests first (completeness on a generic honest witness; mutations D-3, D-4,
D-8, helper out of the sum claim, cap exceeded); counts and measurements DD
on/off; freeze R9 (r8/frozen-tree untouched); write set = tree + r9/ +
ledger. Not a soundness or privacy acceptance.

- 16:2x UTC n_col per layer for every current export (`r9/r9_ncol.py` ->
  `r9_ncol.json`) [COUNTED]: TinyLlama worst 24 (8/14/24 at e_s 3/2/1),
  8B b6/b7/b7voc0 worst 19 (6/11/19), the older 8B pg_rot1_T32 (e_s 1)
  exactly 32 (no slack). All within cap 32.
- Plan sent to the coordinator: Sum key (D30 allows row id or Sum; CHECK
  S-4's option), cap 32, Standalone dictionary slot appended last (slot 23,
  present only on DD profiles so non-DD transcripts do not move), DD profile
  strings for TinyLlama T128 / 8B T128 (+ a small dev rung for tests); DD
  profiles must have an unpadded dictionary domain (refused by name
  otherwise; B-3 vacuous there); byte-identity of existing receipts shown by
  seeded proofs (golden digests from an R8 copy built under r9/) plus R8
  receipts verifying under R9 — receipts use OS randomness, so re-proving
  never repeats bytes.
- 16:5x UTC **R8 golden digests recorded** (check (a)), `r9/r8-golden-tree/`
  = a copy of `r8/frozen-tree/` plus the test file `r9/r9_golden_tests.rs`
  (seeded `ZkRng::new` in test code only; one block through
  `protocol::prove_core` with a fixed transcript prefix and deterministic
  endpoint data; digest of the three roots, every slot proof, the three
  openings, the IO claims, the absorb order and the final transcript state):
  TinyLlama T128 `782b64c97a88cba4c6c34a2fecb73132f26d5f54adc9bd159f3d6cf9df4205c0`
  (23 slots, 69 absorbs), Llama-3-8B T128 (bands attn 6 / gate 8)
  `05a22d72a892aff5fb2e35da4d0ab0c894d696f2e6afa542b6ecece5aeb9f4db`.
- 17:0x-17:3x UTC R9 build, first pass (live tree; uncompiled until the
  guard admits the check):
  * shape.rs: three DD profiles (TinyLlama T128 `...-t128-trained-ddict/1`,
    8B T128 `...-llama-3-8b-t128-ddict32/1`, dev rung `...-rung-dd-t32-dev/1`
    T32/d256/f512/8 heads of 32/2 KV; lengths equal existing ones), `DD_CAP`
    32, field `dd_cap` derived from the profile in `Shape::build`,
    `check_dd_geometry` (unpadded dictionary: refused by name), `Dom::Dd`
    sizes, DD plane lists (S keeps 5 planes; Dd = P_dict, P limbs, rho/sigma
    limbs, M_dd, below the histograms), lookups (S 4; Dd = the division
    limbs + pins), claim sites (SZC + the tuple helper; SC_DD = Dd planes +
    A_SUM, Dd helpers + the table helper), `n_slots` 23/24, `m_rows`,
    `n_functionals` 34/36, `lookup_doms`, A/H groups +2/+1, receipt bytes;
    BASE_DEGREE[SC_DD] = 4; trained registries / rope theta / pinned sources
    extended; DD constructors.
  * layout.rs: `Dom::Dd`, `SC_DD` = 23, `MAX_SLOTS` 24, `TAG_DD` = 141,
    SLOT_NAMES/KINDS (Standalone), Ids/HIds DD segment tables (`pdict`,
    `mdd`, `stuple`, `first_dd`, `gdd`; `is_table` includes `gdd`), DD
    lookups, per-profile slot prefix, `describe` adds the dictionary line
    (cap, e-column rule, key Sum, tuple with TAG_DD, every slot constrained,
    multiplicities in A, table helper in the sum claim, cap refusal) and the
    24th slot line only on a DD profile.
  * argument.rs: `Ctx.g_dd`; `SC_SZC` DD arm (c0, c1, byte helpers, exp
    pair, the tuple helper `h (alpha - (gTAG + Sum + beta mask E + beta^2
    P)) - 1`; no division clauses); `SC_DD` (c2/c3/c4 at every slot with the
    public e column, the byte helpers, the table helper `g (alpha - tau) -
    M_dd`); the argument loops over `n_slots`; test-only lapse switches
    (D-3 gate, D-4 key, sum-claim exclusion).
  * protocol.rs: dictionary tuple builders, the tuple and table helper
    columns (every slot inverted, `inverses` refuses a zero), DD miss count
    + named refusal in prove_core AND the sealing-pass check, the D-8 hook,
    `g_dd` in both Ctx, the lapse in `logup_sum_claim`.
  * witness.rs: no per-entry limbs at DD; per row the dictionary (sorted
    {0} U outputs padded with 0; floor quotient, remainders, limbs at every
    slot; M_dd on the first slot holding the value); test-only mutation
    witnesses (D-3, D-4, wrong P) recomputing the PV accumulator.
  * private_block.rs: `dd_e_column` / `dd_e_column_of` (cap refusal by
    name) and the DD check in `BlockPublic::check_for_shape`.
  * run.rs (DD run profiles, `rung_dd`), trained_block.rs (`--dd` on all four
    commands, DD geometries, SCOPE_DD, cap refusal at the loader),
    trained_statement.rs (pinned sources), pad.rs / hash_domain.rs /
    timing.rs / wire.rs (24th slot, m_rows), test literals.
  * tests: r9_golden_tests.rs (goldens above), r9_tests.rs (gate / check
    (c), DD door, cap 32 passes / 33 refuses, over-cap refused before any
    header, completeness on a generic dense witness vs the independent
    kernel + one-block bound run, mutations D-3 / D-4 / sum claim (pass the
    lapse, rejected as built), D-8 (rejected), T128 DD counts).
- 18:2x UTC **r9 type check clean** (lib + tests, after porting the test
  literals: Ctx.g_dd, lookup_doms() now a Vec, the 24-slot arrays, the
  registry list) and **r9_tests 10/10 GREEN on the first run**, then
  tightened (the prover must produce a receipt; the verdict is the
  verifier's) and re-run with output, 10/10 [MEASURED 197 s incl. build]:
  * completeness: generic dense block at the DD rung (exp e_s 2, heads that
    differ): witness == the independent reference kernel bit for bit, every
    slot the floor quotient, multiplicities count every entry once, zero
    dictionary misses; one-block bound run proves and verifies (segment
    5,619,992 B).
  * D-3 (unconstrained slot): passes the lapse; as built rejected by the
    verifier at slot 23 (the dictionary zero-check). D-4 (row key dropped):
    passes the lapse; as built rejected at H's value-0 sum claim group. The
    dictionary helpers out of the sum claim: passes the lapse; as built
    rejected at the sum claim group. D-8 (counts chosen after alpha):
    rejected at slot 23 (`g (alpha - tau) - M_dd` against the committed
    M_dd). Over-cap block (e_s 0: 44 slots): refused at the run statement
    by name, before any header; the witness builder and the block check
    refuse too. Cap: 8B T32 e_s 1 table (n_col exactly 32) passes; 33
    refused by name. Padded DD shape refused by name.
  * counted at T128 [COUNTED, layout]: TinyLlama committed 68,403,200 ->
    63,848,448 elements (-6.66%), U8 lookups 28,999,680 -> 25,460,736
    (-12.20%), A rows 1993 -> 1871, H rows 2182 -> 2026; Llama-3-8B committed
    117,882,880 -> 113,328,128 (-3.86%), U8 51,937,280 -> 48,398,336
    (-6.81%); the counted receipt grows slightly (23,049,192 -> 23,284,200 B
    and 29,300,856 -> 29,535,864 B: one more slot, its sites and two groups).
- 19:0x UTC first full R9 suite (r9-suite0): 712 passed, 5 failed — all
  registry / census coverage (the s24 / s25 / s33 profile registries did not
  list the six new DD profile strings; the pad degree-range test iterated the
  24-entry slot array of a non-DD shape) and the capture writer's slot list
  (bounded to `n_slots`). Fixed by registering the DD shapes / runs in
  `trained_calib_tests::registered_trained_{shapes,runs}` (+ the run-shape
  helper for the DD rung); 22:28 UTC census rerun 46/46 green (s24, s25 —
  the hash-input census now measures every DD profile's kinds — s33, pad).
- 22:31 UTC `r9_chain.sh` launched (check -> seeded golden on the live tree
  -> CPU + GPU CLIs -> R8 receipts under the R9 CLI -> `--dd` refusal probe
  -> DD runs on the two exports -> full suite -> freeze; check tree
  af90c703..., 222 files).
- 22:3x UTC **counts vs the review's model** (`r9/r9_counts.py`, which is
  dd_check.py part B's counts() parameterised by geometry) [COUNTED]: the
  model reproduces the review's anchor (8B T512: 663,257,088 -> 525,172,736
  committed, -20.82%; U8 -28.25%; element-terms -20.11%), and at T128 it
  equals the BUILT layout exactly (A rows, H rows, U8 totals) for both
  profiles: Llama-3-8B T128 committed -3.86%, U8 -6.81%, element-terms
  -3.88%; TinyLlama T128 committed -6.66%, U8 -12.20%, element-terms -6.92%.
  T128 is where the dictionary is 1/4 of the score domain (T512: 1/16), so
  the saving scales down as the proposal said (its pre-correction T128
  figure was -4.3% at 8B).
- `r9_chain.sh` results (chain.done = 0; guard lines in `r9/chain.out`; the
  chain waited for admission behind other lanes' jobs between steps):
  - 23:57:03 UTC targeted check (r9_tests, trained_stack/block, r6, r8,
    s24/s25/s33, pad, trained_statement, review_e_, cs_port) green, 47 s.
  - 02:57:49 UTC **check (a)** seeded golden on the live tree: the R9 digests
    EQUAL the R8 goldens recorded from `r9/r8-golden-tree/` (a copy of
    r8/frozen-tree + the golden test): TinyLlama T128 782b64c9...4205c0,
    Llama-3-8B T128 05a22d72...f4db; 23 slots, 69 absorbs each (no 24th slot).
  - 02:58:59 / 03:00:16 UTC CPU and GPU CLIs (`r9/binaries.sha256`: CPU
    53c2ccac941a7dae..., GPU fc19b342da3ea0b7...).
  - 03:00:32 / 03:01:23 UTC **check (b)**: the R9 CLI (no `--dd`) verifies
    both R8 T128 receipts read-only against their published statements
    (TinyLlama 497,665,904 B, caf6ced2..., 16 s; 8B 922,711,264 B,
    5585f5ee..., 51 s); its statement rendering is byte for byte the R8
    statement, segments.json included, so the counted segment lengths are
    equal.
  - `--dd` refusal probe at the 8B T32 export: exit 1, no run directory,
    "DD (D30) is registered only at TinyLlama T128, Llama-3-8B T128 and the
    DD development rung, not at Llama3_8B(32)".
  - DD runs (R9 CLI `--dd`, CPU, HL_PB_TIMING on), fidelity-lane exports,
    parity bit-exact at every layer, verify `--controls` 11/11 refused,
    statement published by the verifier, byte re-check passed:
    TinyLlama dg T128 prove 04:23:36-04:25:54Z, identity d5721276...2e4b,
    prove total 137.7 s / prove_run 123.0 s (R8 off: 183.2 / 160.3 s),
    peak RSS 7.28 GiB, verify 10.7 s, receipt 502,836,080 B (off
    497,665,904); Llama-3-8B b7voc0 T128 prove 04:29:24-04:37:19Z, identity
    4da580bd...2520, prove total 474.9 s / prove_run 391.8 s (off 478.7 /
    393.8 s), peak RSS 6.56 GiB, verify 37.5 s, receipt 930,231,520 B (off
    922,711,264). [MEASURED] shared box, n=1: TinyLlama overlapped
    fp-L_export_l8_dg_w16u (light, 73 s) and gate-tk7-cli-l2-dense-everything
    (light, 138 s); 8B overlapped gate-tk7-cli-tl-controls (light, 13 s).
    The TinyLlama -23% is NOT a DD effect: every phase fell ~25%, feed-forward
    (21.5 -> 16.4 s) and residual (29.1 -> 22.3 s) included, which DD does not
    touch, so it is box state between the R8 and R9 runs; at 8B the phases
    are flat (attention 46.6 -> 47.6 s, commit 121.3 -> 118.4 s). Tables:
    `r9/stack-*-dd/dd_vs_off.json` (`r9/r9_measure.py`).
  - DD on/off counts per run [COUNTED from HL_PB_TIMING]: committed words
    TinyLlama 68,403,200 -> 63,848,448 (-6.66%), 8B 117,882,880 ->
    113,328,128 (-3.86%); byte lookups 28,999,680 -> 25,460,736 (-12.2%),
    51,937,280 -> 48,398,336 (-6.81%); zero-check element-terms (runtime
    convention) 122,977,536 -> 116,948,224 (-4.9%), 217,315,584 ->
    211,286,272 (-2.77%), slot 23 adds 4,456,448 per run.
  - 04:52:07 UTC full suite: 29 targets, 717 passed, 0 failed, 33 ignored
    (681 s); manifest unchanged since the check (af90c703...).
- **R9 tree frozen for review at 2026-10-20T04:52:07Z, sha256 manifest
  results/zk60_1b_native_20261017/r9/manifest_frozen.json** (tree
  af90c703ed7b2791d1771dd6e443edf4339bf5fa84a32e0d4a57ed38c3b0a41a, 222
  files; copy `r9/frozen-tree/`; `r9/FROZEN.txt`; `r9/r9-vs-r8.patch`, 2911
  lines, 28 files). r8/frozen-tree re-hashed after the freeze: 220 files,
  tree 7f64276a... unchanged. NOT a soundness or privacy acceptance; D30's
  next steps are the independent soundness review, then rank lemma / NL-1 /
  gate passes on DD captures.

## Round 10 (coordinator, 2026-10-20 ~05:00 UTC): weight-range levers, paper and counting only

Coordinator: R9 accepted as built and frozen (D24 review r9 running on it).
R10 = cost, from R9's layout, (a) two-byte requant remainders at the matmul
output sites, (b) per-output-channel public 12-bit multipliers, (c) cheaper
variants, at TinyLlama T128 / 8B T128 / 8B T512, against R9 non-DD and DD;
name the planes, ranges, slots and the D24 / D30 re-reads. No prover code.

- 05:0x-05:21 UTC `r10/r10_weight_range_cost.py`: a replica of R9's counting
  (shape.rs plane lists / lookups / helpers / claim sites / slots / totals /
  receipt rows; argument.rs per-slot tables) with each weight-matmul site's
  remainder as a parameter. ANCHOR (asserted): it equals every size the
  prover printed in HL_PB_TIMING for the four R9-tree T128 runs (A/H words,
  U8, mask rows, all 23/24 slots' element-terms), the review's 8B T512
  anchor (663,257,088 / 525,172,736) and the fidelity lane's earlier (a)
  count to the element (TinyLlama 70,860,800 committed, receipt +307,312 B).
- 05:15 UTC `r10/r10_word_use.py` (guarded, light, 29 s, 0.44 GiB) on the
  8B dg, TinyLlama dg and 8B b7voc0 exports [COUNTED]: unused bits k_t
  q/k 1-3, v 0-1, ao 0 (dg) / 0-3 (b7voc0), g 0-2, up 0-4, z 0-3; so (a)
  needs two bytes at q/k/v/g, z two bytes with a union pin (sh 4-10), a NEW
  one-byte up remainder (sh_u 0-4), ao unchanged; (b) needs s 12-23: three
  bytes at q/k/v/g/z, ao three with union (s 15), up two.
- Results [COUNTED, committed / U8 / element-terms vs R9 non-DD, TinyLlama
  T128 | 8B T128 | 8B T512]: (a) exact need +8.29/+13.79/+6.55 | +9.59/
  +15.65/+7.60 | +6.73/+10.61/+5.15; (a) without up +3.59 | +4.20 | +2.91
  committed; (c2) narrow per-channel multipliers in (a)'s windows (+ ao two
  bytes) +8.72 | +10.06 | +7.05; (c3) int12 words +9.53 | +10.98 | +7.70;
  (b) exact need +19.07 | +21.96 | +15.39; (b) three bytes everywhere +22.95
  | +26.44 | +18.57. Prove time [MODEL, phase-scaled]: 8B T128 (a) need
  +6.0% total (+8.3% argument), (b) need +13.6% (+18.6%). Per-group
  multipliers cost the same as per-channel at equal width; the fused up
  (int24 u + three-byte product remainder) is dominated. D24 must be re-read
  (new windows, no-wrap up to 2^48 for (b), the new up host clause, the
  multiplier fold and binding, D31 pairs); D30's construction is untouched
  (recount its N-dependent lookup term and D27's bound).
- 05:21 UTC written: `r10/WEIGHT_RANGE_COST.md` (+ `r10_weight_range_cost.json`
  / `.out`, `r10_word_use.json`). Not a soundness or privacy acceptance.

## Round 11 (coordinator, 2026-10-20): activation-side levers, paper and counting only

Coordinator: the fidelity lane measured that (c2) captures the whole weight
lever at 8B (dg 1.28 -> 1.17 / 1.15); every activation site float gives
1.13 / 1.11; D32's 1.01 needs both. Count (1) norm outputs int12/int16,
(2) attention core (F_P 10-12, score window, PV), (3) gate/SiLU output and the
product remainder, (4) residual (only if cheap), alone and on top of (c2), at
TinyLlama T128 / 8B T128 / 8B T512, against R9 non-DD and DD; give the
stacked full-parity total.

- ~06:00-07:00 UTC `r11/r11_activation_cost.py`: R10's replica (anchor
  re-asserted) + S-domain extras, isqrt limbs, public tables per slot, and a
  window calculator (L = ceil(max shift / 8), one pin if min >= 8(L-1));
  self-checks: the empty configuration == R9, c2 == R10 a3_1.
- Findings [COUNTED]: F_P 10-12 costs nothing (p stays two limbs to F_P 15;
  sh_o = F_P stays in 9..=16; DD's P_dict limbs unchanged, cap independent of
  F_P); norm outputs int16 via tn - 8 cost the norms nothing net (window 32 ->
  24, one remainder limb fewer per norm offsets the y/nm limbs) and are
  cheaper than int12 (cn x 16); their cost is the downstream windows (on c2:
  q/k/v/g three bytes, up two). Per-group SiLU: 0 planes / 0 lookups as
  claimed, but one public group column (+1.3-2.0% element-terms). SiLU input
  int12: free (4096-row table inside Dom::Tab). Finer SiLU output -> product
  remainder three bytes: +4.3/+4.9/+3.6% committed on c2 (F domain). Score
  int12 makes DD infeasible (cap). Residual int24: +4.9-7.1% alone, needs a
  fifth norm limb (D16) unless combined with the tn route; not in LOW/MID.
- Stacks vs R9 non-DD (committed; time [MODEL]): (c2) +10.06% 8B T128 / +7.05%
  T512; LOW (c2 + norm int16 + F_P 12 + attention words + per-group SiLU +
  SiLU input int12) +22.35% (time +15.1%) / +17.88%; MID (+ product three
  bytes) +27.74% (+17.8%) / +21.70%; HIGH +29.16% (+18.9%) / +26.10%; + residual
  +35.36% / +28.46%. TinyLlama T128: LOW +20.98, MID +25.68, HIGH +27.74.
- 07:01 UTC written: `r11/ACTIVATION_COST.md` (+ `r11_activation_cost.json` /
  `.out`). Not a soundness or privacy acceptance.

## Round 12 (coordinator, 2026-10-21 ~02:25 UTC): Shieldstral-1.0-3B (D38) — F1 / F2 / F3 and its profiles

Coordinator: build, test-first, on top of R9 (DD kept): F2 head_dim decoupled
from d / heads in every block relation, the loader and the door (existing
profiles byte-identical, checks a-c as in R9); F1 YaRN / llama3 RoPE as public
tables only, verified against transformers; F3 tied embeddings in the loader
and statement (both quantisations bound to one tensor digest; token lane on
the head side); registered Shieldstral T128 / T256 profiles (non-DD and DD)
with counted floors and n_col vs cap, a generic dense witness at Shieldstral's
shapes; the cost per proof at T 128 / 256 / 512 with and without DD; freeze
R12. Later input (multimodal lane): confirm the padding facts and memory at
T128 / T256, cost a split-width layout as a paper R12b.

- 02:30 UTC working tree == R9 freeze (af90c703...). Pins fetched from the HF
  API and files at revision 003ec7e2...: config.json sha256 a0b11229...,
  model.safetensors LFS 87753e30..., the safetensors header (tied: no
  lm_head; `language_model.model.embed_tokens.weight` BF16 [131072, 3072] at
  bytes [61008, 805367376)); its raw-byte SHA-256 67a138c1... (streamed from
  the HF range AND read from the prep lane's local copy: equal). Copies in
  `r12/reference/`, with transformers main's `modeling_rope_utils.py`.
- 02:4x UTC `r12/r9-golden-tree/` = r9/frozen-tree + `r12_golden_tests.rs`
  (the four T128 shapes incl. DD, seeded, + statement identities) +
  `r12_prefix_tests.rs` (the failing-first record on R9); recording job queued.
- 03:0x UTC built (live tree): `rope.rs` (YaRN / llama3 inv_freq by the
  transformers formulas in binary64; the unscaled case IS the frozen
  generator; an attention factor != 1 refused by name); Shape::q_width /
  q_pad, the d_pad == h_pad*head_dim refusal removed, Wo's fold over the query
  axis (argument, witness, pad indicators, attention statement, kernel crate,
  loader, test helpers); profiles SHIELDSTRAL_T128/T256 (+ DD) at 65 bytes,
  run profiles at 67, the decoupled-head dev rung (T32 / d192 / q512) at 47 /
  45; pins (source, RoPE base and transform, tied tensor); the statement's
  rope-scaling and tied-embedding fields (encoded only when present); loader
  geometries shieldstral-3b-t128 / -t256 / rung-hd-t32-dev, rope_scaling and
  tied_embeddings reading, token_io manifests streamed and checked.
- 03:1x UTC `r12/rope_reference.py` [COUNTED]: transcription == torch f32 ==
  installed transformers 4.48 to ~1e-7 relative; T512 table SHA-256 YaRN
  261b32b8..., llama3 hd128 9475db38..., hd64 be90a500...; YaRN moves 22,650 of
  65,536 entries vs unscaled at theta 1e6; f32 frequencies would move 2.
- 03:25 UTC first r12 test run: 14 passed, 1 failed — the T256 row width: the
  smallest counted receipt is 2^15 (45,011,240 B vs 48,025,704 at 2^14, for
  +2.3% committed). Registered T256 at 2^15 (task 3's rule).
- [COUNTED, R10 replica] the Shieldstral block = the 8B block at the same T and
  row width (committed and U8 identical; element-terms +0.5%: d 3072 pads to
  4096, one support table); padding facts and memory sent to the coordinator.
- 03:3x UTC coordinator (urgent, F1): do not validate YaRN against 4.48.1's
  default path. Checked: the prover implements transformers MAIN's formula
  (original_max 16384, attention factor from mscale = 1.0, truncate); my 4.48
  comparison used the known-good workaround config. Against the prep lane's
  `crosscheck/rope_tables_reference.npz` (sha256 ffcb1b29...): inverse
  frequencies BITWISE equal; split 21 / 27 / 16 (43 of 64 pairs move); the
  2^7 integer tables differ in 0 of 65,536 (T512) and 0 of 262,144 (T2048)
  entries; float cos / sin bitwise equal. New test pins the prep lane's T2048
  digest 5e370a8c... (T512 digest equal to mine, 261b32b8..., independently).
- 04:0x UTC `r12/r12_cost.py` [COUNTED replica + MODEL time / memory] and
  `r12/SHIELDSTRAL_COST.md`: Shieldstral block == 8B block (committed, U8) at
  every T; 26-block prove [M] T128 279 s / 277 s DD, T256 623 / 582 s, T512
  1,473 / 1,260 s; peak [M] T128 6.7 GiB, T256 15.5 / 14.0 GiB (does not fit
  the laptop path); split width (R12b, paper) -17..-25% committed, T256 peak
  12.3 / 10.8 GiB; relations touched and re-reads listed.
- 04:1x UTC the box is saturated by other lanes (budget 10.6 / 11.9 GiB, three
  cpu jobs queued on the heavy lock): r12-t2-run (2.5 GiB) and the R9-copy
  golden run (7.5 GiB) wait for admission.
