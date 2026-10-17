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
