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
