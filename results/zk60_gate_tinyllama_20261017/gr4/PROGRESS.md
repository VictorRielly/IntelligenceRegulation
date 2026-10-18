# P-12 sub-lane: the stage-47 G-R4 root-rebuild check, ported to the trained TinyLlama T32 tree

Sub-lane of the privacy gate lane. Brief: port
`/home/victor/wt-zk60-block125m/hashline/src/private_block/gr4_check_tests.rs`
(stage 47, ruling LW-2) to the trained R5 tree and run it at the trained shape
(review `results/zk60_privacy_review_trained_t32_20261017/REVIEW.md` §2.2, §P-12).

**Nothing in this sub-lane is a privacy acceptance.** It is a machine check
that one owed condition (G-R4's value-level half) holds on the witnesses run;
only the security review process can accept anything, and rulings are Victor's.

Write set: `ops/zkp-mvp/trained-1b-gate-gr4/` (copy of the frozen R5 tree) and
this directory. Test-only addition; no prover or verifier relation changes.

## Log (UTC from `date -u`)

- 2026-10-17T21:37Z — started; read `ops/zkp-mvp/LANE_RULES_20261017.md`,
  REVIEW.md §2.2 and §P-12, the 125M `gr4_check_tests.rs` (449 lines).
- 2026-10-17T21:40Z — copy made: `rsync -a --exclude=target
  results/zk60_1b_native_20261017/r5/frozen-tree/ ops/zkp-mvp/trained-1b-gate-gr4/`.
  Verified against `r5/manifest_frozen.json`: 217 files in the manifest, 217
  in the copy, 0 extra, 0 missing, 0 sha256 mismatches; the manifest's
  `tree_sha256` recomputes (sorted `path sha256\n` lines) to
  d67fae7ef3d03bb6a30c89880ac41b6e4543b7f8b5df8040c8a29ba7404df952.
- 2026-10-17T21:47Z — read the trained tree (protocol.rs `prove_core` /
  `verify_core`, run.rs `prove_run_with` / `RunVerifier`, pcs/zk commit
  paths, boundary.rs, endpoint_g.rs, layout.rs, wire.rs, trained_block.rs,
  run_capture.rs header rebuild). Findings that shape the port:
  1. `protocol::transcript` asserts `single_block_profile_allowed`, so the
     single-block header cannot be built at the trained profile (R2-4).
  2. `RunStatement::transcript`, `stage_layout`, `seg_geom` and
     `run::position_tag` are PRIVATE to run.rs; a sibling test module cannot
     call them. The test-only accessors `RunStatement::binding()` and
     `capture_header()` exist (the run capture rebuilds the header from them
     and compares with the binding), so the header can be rebuilt from public
     words and checked against the binding, with no production edit.
  3. This tree's `zkp_core::rng::ZkRng` has NO `consumed_bytes()` accessor
     (the 125M lane added one to its zkp-core). It cannot be added test-only
     (a separate crate: its `cfg(test)` is off when hashline's tests build).
     Substitute: a NEXT-DRAW PROBE (the next 32 bytes of each generator, on
     the same seed, compared for equality) plus a fresh generator advanced by
     the prediction's COUNTED bytes, which must give the prover's probe; a
     generator advanced 16 bytes further must not (non-vacuity).
  4. Draw order in this tree, read: `commit_zk_owned_with_tag` draws pads
     (`rows*q`, `fp_vec` = repeated `fp`) then salts (`nn` x `bytes32`)
     BEFORE the backend offer and before `encode_buffer::encode_rows` (new
     path); `mask_commit_tagged` draws the 23 alpha vectors, per-row pads,
     b, u, salts, with `b[m] := -b[0]`; boundary and endpoint preparers fill
     every row above the data rows, then commit. H's zero-sum rows are a DATA
     plane below `h_mask_base`, so segments 8 and 9 are disjoint.
  5. LW-4's note carries forward to this tree [READ]: `CfsMask` derives
     `Clone` (zkp-core/src/sumcheck.rs:192) and `CommittedZk`'s `data`,
     `pads`, `salts` are `pub` (zkp-core/src/pcs.rs:591-606).
  Plan: a test-only module `src/private_block/gr4_trained_tests.rs` (child of
  `private_block`, one `mod` line) that builds a ONE-BLOCK BOUND RUN through
  the production constructors, rebuilds the run header from public words
  (checked = binding), replicates stage 0 of `prove_run_with` (locality
  absorbs, `prove_core` on a SEEDED generator, the two endpoint openings),
  encodes the segment with `wire::encode_segment` and verifies it with the
  production `run::verify_run`; then rebuilds A, M, H from the witness and the
  replayed stream with `encode_row_zk` / `hash_columns_keyed` /
  `salt_leaf_keyed` / `build_keyed`. The seeded receipt is never written to
  disk (a public seed makes its openings non-hiding).
- 2026-10-17T21:50Z — wrote
  `ops/zkp-mvp/trained-1b-gate-gr4/hashline/src/private_block/gr4_trained_tests.rs`
  (three `#[ignore]`d tests, the tree's convention for export-reading tests)
  and its `#[cfg(test)] mod gr4_trained_tests;` line in `src/private_block.rs`.
  No other file touched.
- 2026-10-17T21:51Z — build launched detached through the guard (class
  build, need 3, cap 5; heavy lock then held by `r5-ladder8b-T64-gpu`, so it
  queues). Markers: `gr4-build.done` (guard), `gr4-build.wrapper.done`
  (detach wrapper), `gr4-build.guard.json`, log `gr4-build.log`.
- 2026-10-17T22:04Z — build DONE, exit 0, first attempt (no warning in the
  new module). Queue wait 580.6 s, build 235.4 s, peak RSS 1.78 GiB
  [MEASURED, shared box, n=1]. Test binary
  `ops/zkp-mvp/trained-1b-gate-gr4/hashline/target/release/deps/hashline-62424158dd0cb79c`.
- 2026-10-17T22:10Z — patch and manifest written (sources final): 2 files
  differ from the frozen R5 tree (`private_block.rs` +4 lines,
  `gr4_trained_tests.rs` new); copy tree sha256 3f99de80...; binary and
  patch sha256 in `binaries_and_patch.sha256`.
- 2026-10-17T22:36Z — DENSE block test (layer 0, ho00) PASS, exit 0 (log
  `gr4-block-dense.log`). Queue wait 1857 s behind `r4-suite`; run 8.5 s;
  peak RSS 0.85 GiB (cgroup 0.88) [MEASURED, shared box, n=1].
- 2026-10-17T22:37Z — zero-input block test launched (need 2, cap 3.5).
- 2026-10-17T23:06Z — CLASS CHANGE, at the caller's (privacy-gate lane)
  direction: the dense test measured 8.5 s at 0.85 GiB, under the lane
  rules' heavy thresholds, and the heavy lock keeps going to other lanes'
  suites. The zero-input job, already queued as `cpu`, is left to run (not
  killed); the boundary test will be launched as class `light` (need 2,
  cap 3.5), one job at a time, after it finishes.
- 2026-10-17T23:22Z — session resumed after a pause (~23:10). No reboot
  (boot id unchanged). Ledger and files intact (no partial edit: the test
  module and the patch are as at 22:10). Zero-input guard (pid 184235,
  class cpu) still alive and queued for the heavy lock (not killed, per the
  caller); watcher re-armed on `gr4-block-zero.wrapper.done`.
- 2026-10-17T23:24Z — ZERO-INPUT block test PASS, exit 0 (log
  `gr4-block-zero.log`). Queue wait 2817 s; run 9.1 s; peak RSS 0.84 GiB
  (cgroup 0.89) [MEASURED, shared box, n=1].
- 2026-10-17T23:25Z — boundary test launched as class `light` (need 2,
  cap 3.5).
- 2026-10-17T23:34Z — BOUNDARY test PASS, exit 0 (log `gr4-boundary.log`).
  Queue wait 582 s; run 1.3 s; peak RSS 0.32 GiB (cgroup 0.41) [MEASURED,
  shared box, n=1]. All four launched jobs have their `.done` markers
  (build, dense, zero, boundary: all 0). NOTHING IS PENDING.

## Result (2026-10-17T23:35Z)

**The ported G-R4 root-rebuild check PASSED at the trained TinyLlama T32
shape**, on the trained export `pg_rot1_export_T32` (read-only), for layer 0
with the export's held-out sequence ho00 (the DENSE, generic witness; native
output parity bit-exact against the export, 65,536 words) and with the
ALL-ZERO input, and for the internal boundary B_0 of a two-block (layers
0 | 1) trained run with the dense plane and the all-zero plane.
**This is not a privacy acceptance**; it machine-checks one owed condition
(G-R4's value-level half, review §2.2 / P-12) on these witnesses only.

### What each test asserts, and the result lines

`gr4_trained_t32_block_{dense_ho00,zero}_commits_exactly_the_predicted_stream`
(both PASS, identical result lines):

| assertion | dense ho00 | all-zero |
|---|---|---|
| single-block receipt refused at the trained profile (why the adaptation is needed) | true | true |
| run header rebuilt from the statement's public words = run binding | true | true |
| seeded one-block bound run, stage 0 replicated, segment 11,627,288 B, verified by the PRODUCTION run verifier `run::verify_run` from its bytes | true | true |
| A root rebuilt (witness rows + histograms, seg 1 mask rows, seg 2 pads, seg 3 salts) | true | true |
| M root rebuilt (seg 4 alphas, seg 5 pads, seg 6 b/u with `b[m] := -b[0]` only, seg 7 salts) | true | true |
| H root rebuilt (LogUp rows from replayed challenges, seg 8 mask rows, seg 9 zero-sum rows, seg 10 pads, seg 11 salts) | true | true |
| replay stream ends where the prover's did (next-draw probe) | true | true |
| prover consumed exactly the predicted 38,455,872 bytes (fresh generator advanced by the count gives the prover's probe) | true | true |
| probe non-vacuity (a 16-byte shift differs) | true | true |
| H zero-sum rows below the segment-8 region (no discarded draw) | true | true |
| endpoint owners in situ: 51,712 drawn field values and 32,768 salts, all distinct | true | true |
| non-vacuity: AProxZero moves A / CopyAIntoH moves H / AlphaCopy moves M | true / true / true | true / true / true |

Layout at the trained shape [COUNTED, printed by the test]: A 1,729 rows (mask
region 242), H 1,798 rows (mask region 100), M 50 base rows, row width 2^12,
rate 4. The 38,455,872 predicted bytes decompose as A 15,859,712 + 7,081,984 +
524,288, M 31,328 (= 979 Fp2 alphas, matching the review's recount of
Σ L_s = 979) + 188,416 + 65,536 + 131,072, H 6,553,600 + 131,040 + 7,364,608 +
524,288 [COUNTED].

`gr4_trained_t32_boundary_commits_exactly_the_predicted_stream` (PASS), at the
run's own `boundary_spec(0)` of a two-block bound statement: geometry 22 rows =
16 data + 2x2 sites + 2, row width 2^12, rate 4, keyed (D19) tag, for both
planes (dense = block 0's native padded output on ho00, parity bit-exact, which
is what `prove_run` commits at B_0; and all-zero): root rebuilt = true; replay
ends where the preparer's did = true; preparer consumed exactly the predicted
1,007,616 bytes = true; probe non-vacuity = true; non-vacuity (site 1's first
reserved word := site 0's) moves the root = true.

### What was ported, what was adapted and why

- Ported from the 125M stage-47 file: the eleven-segment prediction (A, M, H
  rebuilt with `encode_row_zk` / `hash_columns_keyed` / `salt_leaf_keyed` /
  `build_keyed`, never through `commit_zk_owned_tagged` — whose host path in
  this tree is the new `encode_buffer::encode_rows`, so that path is
  cross-checked too — nor `mask_commit_tagged`), the three non-vacuity
  perturbations, the in-situ endpoint distinctness check, the seeded boundary
  rebuild. Per-row encoding in the rebuild runs rows in parallel (rows are
  independent; nothing is drawn there).
- Adapted: (1) the block is proved as a ONE-BLOCK BOUND RUN built with the
  production constructors (`TrainedExport::*`, `IoSpec::new_shaped`,
  `prepare_endpoints`, `RunStatement::new_bound`), because the trained
  profile refuses single-block receipts (R2-4). (2) The run header is rebuilt
  from `RunStatement::capture_header()` (test-only accessor) and checked equal
  to `binding()`; stage 0 of `prove_run_with` is replicated line for line
  (`run.rs:884-967` at L = 1), because `transcript()` / `stage_layout()` /
  `seg_geom()` / `position_tag()` are private to run.rs; the segment is
  encoded with `wire::encode_segment` and the production `run::verify_run`
  accepting it is the check that the replication is the run prover's.
  (3) `consumed_bytes()` does not exist in this tree's zkp-core and cannot be
  added test-only; replaced by the next-draw probe plus a fresh generator
  advanced by the counted bytes, with a shifted-generator non-vacuity check.
  (4) Comparisons use `assert!(a == b)`, never `assert_eq!`, so no root or
  probe can be printed even on failure (capture rule). (5) A boundary
  non-vacuity perturbation was added (the 125M boundary test had none).
- The seeded receipt is held in memory only and never written (under a public
  seed its openings are not hiding).

### What it does not cover

(a) Uses of drawn values outside the three commitments (the slot argument's
reads of alpha and of the reserved pairs) — bound by the verifier, which
accepted; soundness, not this check. (b) The endpoint generators (`from_os`):
in situ and order-blind only. (c) A run of L >= 2: `prove_run_with`'s stage
loop (B_k drawn from the run stream before A_k; the B_{k-1} opening) is not
replayed; the boundary preparer is checked alone on a seeded stream. (d) The
production entry `prove_run` (OS randomness) is not called; stage 0 is
replicated and verified. (e) Verification is from bytes but in the same
process, not a fresh process. (f) One layer (0) for the block, layers 0 | 1
for the boundary, one sequence (ho00) plus the all-zero input. (g) CPU host
path only (no `gpu-cuda` feature; the CUDA keyed commit offer is not
exercised). (h) The R5 tree (d67fae7e...); R5b must re-apply the patch and
re-run (the patch is test-only and touches no file the R5b CLI fix touches,
unless R5b edits `private_block.rs`'s module list).

### Re-applying to R5b

`patch -p0`-style application is awkward because the patch carries absolute
paths; simplest: copy `hashline/src/private_block/gr4_trained_tests.rs` from
`ops/zkp-mvp/trained-1b-gate-gr4/` and add the 4-line `mod` block after
`mod zero_witness_tests;` in `hashline/src/private_block.rs` (see the patch's
second hunk). Then build the lib test binary and run the three tests with
`--ignored --exact private_block::gr4_trained_tests::<name> --nocapture
--test-threads 1` (class `light`, need 2, cap 3.5 is enough: peak 0.85 GiB).

### Costs [MEASURED, shared box, n=1]

| job | class | queue wait | run | peak RSS |
|---|---|---|---|---|
| test-binary build | build | 580.6 s | 235.4 s | 1.78 GiB |
| dense block test | cpu | 1,857 s | 8.5 s (prove stage 3.45, run verify 0.42, one rebuild 1.09) | 0.85 GiB |
| zero block test | cpu | 2,817 s | 9.1 s (prove stage 4.14, run verify 0.34, one rebuild 0.97) | 0.84 GiB |
| boundary test | light | 582 s | 1.3 s | 0.32 GiB |

### Evidence (this directory)

`trained-1b-gate-gr4-vs-frozen-r5.patch` (diff -ruN --exclude=target against
`results/zk60_1b_native_20261017/r5/frozen-tree/`), `sources_manifest.json`
(218 files, copy tree sha256
3f99de80db94dd809a368f22b77afe7f578d275098d4e1a6c94cc2cb661778af; changed
`hashline/src/private_block.rs`, added
`hashline/src/private_block/gr4_trained_tests.rs`), `binaries_and_patch.sha256`
(test binary 642b9e08..., patch 21869af5...), and for each of `gr4-build`,
`gr4-block-dense`, `gr4-block-zero`, `gr4-boundary`: `.log`, `.done`,
`.wrapper.done`, `.guard.json`. Nothing failed.
