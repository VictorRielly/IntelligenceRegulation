# A33 stage 1: the sealing chain's CS-3 does not repeat the block's public check

Author: Claude (one Sonnet agent, for the Claude co-coordinator), 2026-11-17 UTC. Branch `worktree-agent-a4d782b46866ea303`
(base `eee3eb57`), source and tests in one commit (`perf(a33): ...`), these results in a second. Not merged, not pushed, not yet
cross-reviewed. Labels: MEASURED (a log of this directory), CODE-READ (file:line, tree at the base commit unless "patched").

## 1. What changed, in one paragraph

`protocol::check_lookup_misses` (`protocol.rs:624`) is now three functions: the same public function (layout check,
`blk.check_for_shape(sh)`, then the scan), a new `pub(crate) check_lookup_misses_after_public_check` (`protocol.rs:638`: layout
check, then the scan; its doc comment states the precondition) and the private scan (`protocol.rs:643`, the old body from `let ids`
on, unchanged). `seal_chain` (`trained_block.rs:3053-3059`) calls the new function only when `build_checked` holds, otherwise the old
one. Every other caller (cli.rs, classify_cli.rs, classify_run.rs, token_io/run.rs, the tests) is untouched and runs the old function.

```
let build_checked = cur.blk.accuracy().is_some_and(|d| d.folds().gate.shift == ssh.accuracy_gate_shift);
```

**Deviation from the brief, with the reason (this is the finding of reading item 2).** The brief says the build and CS-3 run on
"identical arguments". They do not always. `witness_for_block` (`trained_block.rs:1543-1551`) builds a block that carries accuracy
data with `build_for_block(&local, ..)`, where `local = ssh.clone().with_accuracy_gate_shift(data.folds().gate.shift)`, but CS-3
checks `ssh`, whose gate shift comes from the layer's RECORD (`LayerRecord::shape_at`, `trained_statement.rs:557-561`). The two shapes
are equal only when the record's gate shift equals the block data's. `check_accuracy_for_shape` refuses a different one
(`private_block.rs:862-863`, "R13 public folded gate denominator differs from the stage shape"). Both production loaders set the
record's gate shift from the data (`trained_block.rs:1437`, `trained_statement.rs:615`), so in production the rule is always true; but
nothing in `seal_chain` enforces it, and a model whose record differs (a synthetic one, a doctored one) would be refused today by
CS-3's copy of the check, with CS-3's text. A plain "skip the check on the sealing chain" would have changed that refusal. With the
rule, that case still takes the old function. Also, a block with no accuracy data is built by `build_shaped`, not `build_for_block`
(`trained_block.rs:1549`); `build_shaped` runs the attention and feed-forward halves' checks only (`witness.rs:1129-1130`), not
`BlockPublic::check_for_shape` (accuracy-missing refusal, DD column), so the rule is false there and the old function runs too.

Second, smaller deviation: the new function keeps `lay.check_is_for_shape(sh)?` (a `Layout::for_shape` rebuild, not part of the
0.35 s), so the layout check and its refusal stay exactly where they were.

Diff stat (source commit): `protocol.rs +17`, `trained_block.rs +14 -2`, `r6_tests.rs +38 -1`, `run_fork_tests.rs +147`
(4 files, 214 insertions, 2 deletions). The production diff is 31 lines; the rest is tests. `zkp-core/src/pcs.rs` and
`hashline/src/gpu/metal.rs` are untouched.

## 2. The five reading items

1. **Is the check the build runs the check `check_for_shape` would run? Yes, in the one branch that can be skipped.**
   `build_for_block` (`witness.rs:80-91`) at a non-Legacy shape runs `blk.check_accuracy_for_shape(sh)?` (`:84`); at a Legacy shape
   `blk.check_for_shape(sh)?` (`:88`). `BlockPublic::check_for_shape` (`private_block.rs:886-904`) at a non-Legacy shape returns
   `check_accuracy_for_shape(sh)` (`:887-889`) and at a Legacy shape runs the two halves, the accuracy-is-none refusal and the DD
   column. So at a non-Legacy shape the two are the same function; `check_for_shape` does nothing more. `check_accuracy_for_shape`
   (`:852-874`) is exactly what the build runs (steps 1 to 9 of `witness.rs:125-128`). The remaining differences are the two cases in
   section 1 (record gate shift; no accuracy data), which the rule excludes. The pass is production's R13 stack, so it takes the new
   function on every block.
2. **Nothing can change `cur.blk` or `ssh` between the build and CS-3.** `ssh` is an immutable `let` (`trained_block.rs:3019`);
   `cur` is an immutable binding (`:3007-3015`); `cur.blk` is a `LayerBlock` (`run_fork.rs:2552-2565`), `Owned(BlockPublic)` or
   `Shared(Arc<KeptBlock>)`, read through `Deref` only; `BlockPublic`, `AttentionPublic`, `FeedForwardPublic` and `AccuracyPublic`
   hold plain `Vec`, array and `Option` data (`private_block.rs:558-567, :740-746, :833-838`, `accuracy_public.rs:68-81`; grep for
   `Cell|Mutex|Atomic|OnceLock|RefCell|Rc` in them finds nothing). The build is `pool.run(|| witness_for_block(&ssh,&cur.blk,&x))`
   (`:3023`), the same `&ssh`, the same `&cur.blk`, returned before CS-3; `hand.block(k, cur.blk, ..)` moves the block only at
   `:3078`, after CS-3 (patched numbering). The one thing that differs is the shape `witness_for_block` hands the build (`local`),
   which is why `build_checked` compares gate shifts.
3. **A block that fails the public check is already refused by the build, before CS-3.** The build's error is returned at `:3035`
   (`let w = wres.map_err(..)?`) and CS-3 is reached only after it. Today's text for such a block:
   `the witness builder refuses layer {layer} (before the run header; ruling H-1): {e}` (e.g. `{e}` =
   `R13 public weights/gains must be symmetric int8`). Unchanged: the patched code does not touch that line, and the build runs
   first, so on a block failing the check CS-3 is never reached. Test: G3 below, equal text on the tree with and without the change.
   The H-1 ruling (`trained_block.rs:2822-2828`) fixes the first refusal in layer order with its text; no refusal moves.
4. **The second check is not documented as deliberate defence in depth.** Searched: comments at `protocol.rs:615-623`
   (CS-3 doc: "run on a witness BEFORE any proof exists ... the same counts `prove_core` computes", nothing on the block check),
   `trained_block.rs:3036-3039`, `witness.rs:115-148` (A16's note that the build checks once), `ZK60_DECISIONS.md` (D29, D68, D70,
   D71, D73 on H-1: they speak of the order and place of refusals, not of a repeated check), `R6_VERDICT.md` N-r5-a, A17 README
   (the preflight record of public checks, a different mechanism), A20 and A22 READMEs (`check_lookup_misses` named as the
   sealing pass's CS-3). The one "defence in depth" comment near these files is `protocol.rs:115` (the single-block transcript
   assert), unrelated. So no STOP.
5. **Source-text gates and other readers.** `r6_tests.rs:238` (old) pinned `check_lookup_misses(&ssh, lay, &cur.blk, &w)` in
   `seal_chain`; `token_io/cli_tests.rs:623` pins `check_lookup_misses(&ssh, &lay, &blk, &w)` in the token CLI's own `seal_chain`
   (`cli.rs:802`), which is not touched. No other test reads source text that mentions `check_lookup_misses` or `check_for_shape`.
   The tests that `include_str!` whole production files (`hash_domain_tests.rs`, `grow_tests.rs`, `s25_tests.rs`) scan for absorb
   labels, byte-string literal lengths and hash call counts; the change adds none; those suites pass (section 4, G2).

Gates added or changed in `r6_tests.rs`: the text gate (`:238-244`) now pins both CS-3 calls and the `build_checked` line (so the
call text pins the rule too); new `a33_the_sealing_pass_skips_the_public_check_only_after_the_build_ran_it` (`:252-`) pins the
precondition: `build_for_block` runs `check_accuracy_for_shape` / `check_for_shape` before it builds, `BlockPublic::check_for_shape`
at a non-Legacy shape is `check_accuracy_for_shape`, `witness_for_block` builds at the data's gate shift through `build_for_block`,
and in `seal_chain` the build, the rule and the scan come in that order. No other gate weakened or deleted.

## 3. New behavioural tests (`run_fork_tests.rs`, end of file; they run `seal_chain` through `a20_seal_summary_for_tests`)

- `a33_a_block_that_fails_its_public_check_is_refused_by_the_build_with_the_builders_text`: three layers of the W16R2 rung's synthetic
  stack, layer 1's `gamma_a[0] = -128`; expects exactly `the witness builder refuses layer 1 (before the run header; ruling H-1):
  R13 public weights/gains must be symmetric int8`.
- `a33_a_record_at_another_gate_shift_is_still_refused_by_the_full_cs3_check`: layer 1's record carries another gate shift than its
  data (`build_checked` false); expects exactly `layer 1, in the sealing pass (before the run header; ruling H-1): R13 public folded
  gate denominator differs from the stage shape`. This is the case where CS-3's copy of the check IS the one that fires; the rule
  keeps it.
- `a33_the_honest_sealing_pass_summary` (rung) and `a33_the_8b_sealing_pass_summary_on_the_cpu_and_on_the_device` (8B, ignored,
  device): print the SHA-256 of the sealing pass's whole summary line (statement identity, block digests, records, every sealed
  plane and endpoint, stage shapes, kept witnesses and every plane of each), at two budgets, CPU and device.

## 4. Gates

Toolchain: no rustup toolchain exists on this Mac (`~/.rustup/toolchains` absent); the precedent's `/opt/homebrew/bin/cargo` is used.
All commands run through `guarded.py` (this directory), which runs `python3 -B /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class ... --wait-secs 21600 ... -- <leaf>`
with the default poll, and records `raw/<label>.status_pre.txt` (guard `status` and `pgrep -fl ds4-bench` before, `pgrep` after)
and `raw/<label>.guard.json`. Every guarded run, with its guard run id: `GUARD_RUNS.md`. `ds4-bench` was not running before or after any
run of this table, except where `GUARD_RUNS.md` says otherwise.

Paths below: `W` = the worktree's `ops/zkp-mvp/gpu-metal/hashline`. `BIN_P` = `W/target/release/deps/hashline-4ff65cafe9d88959`
(patched). `BIN_U` = the main checkout's `hashline-a90b6cf7715dc2a7` (unpatched, sha256 `aaaab7e6...acad11`, verified before every unpatched
run by `ab_run.py`, run read-only from where it is). `BIN_B` = a scratch build of the same tree with the one line
`if build_checked && false {` (the full CS-3 check always taken: the behaviour before the change, plus the new tests), built with
`CARGO_TARGET_DIR` in the scratchpad; used where a new test has to run on the old behaviour. The tree was restored by an edit and
`git diff` was empty before the commit.

**G1 build.** `cargo test --release --offline --locked -j 2 --features gpu-metal --manifest-path W/../Cargo.toml --lib --no-run --message-format=json`
(class build, need 8 / cap 16 GiB): exit 0, 177 s, peak 4.46 GiB, guard run `0595665f4131` (the first build, before the 8B test was added to the commit); the final
tree (`g1_build_patched2`, guard run `7d9ab9697c1a`): exit 0, 168 s, peak 4.45 GiB; the binary tested and timed below is this one.
`g2_focused_patched` and `g4_a33_*` ran on the first build (same production source, 3 a33 tests); the full suite, the 8B and
digest tests and every timing run ran on the final one. No-feature `cargo check --tests --offline --locked -j 2 --manifest-path W/Cargo.toml` (`g1_check_nofeature`):
exit 0, 14 s, guard run `9e52d7d110b0`. The build leaf is the one in `run_batch6_guarded.py:764-777` with the manifest path changed.

**G2 tests (BIN_P, class cpu, `HL_R13_LOADER_FIXTURES` = this worktree's `results/zk60_1b_native_20261017/r13/loader-fixtures`).**
Focused run `g2_focused_patched` (`--test-threads=8`, filters: `r6_tests::` `accuracy_proof_tests::` `fork::tests::a33_`
`a20_the_sealing_pass_is_the_same` `a19_production_d55_path_window_on_and_off_and_a_refused_chain_at_the_r13_rung`
`a20_production_d55_path_under_the_forms_off_and_on_at_the_r13_rung` `trained_stack_tests::` `pr4_4_` `hash_domain_tests::`
`grow_tests::` `s25_tests::` `cs_port_tests::` `accuracy_binding_tests::` `accuracy_profile_tests::`): 86 passed, 1 failed, 9 ignored.
The one failure, `trained_stack_tests::review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`, fails the same way on
the unpatched binary (`g2_stale_pid_baseline`, "a live pid's writing directory was removed": a process-id test on this host), so it is
not caused by the change. Included and passing: all `r6_tests` (the CS-3 test with its negative lookup-miss refusal, the text gate, the
new precondition gate), `accuracy_proof_tests` (the `check_lookup_misses` cases at `:55` and `:238-239`), the H-1 / sealing tests
(`a20_the_sealing_pass_is_the_same_under_every_load_setting_and_refuses_with_the_earliest_layer`: parity at layer 1 with load failures at
layers 2 and 3 refuses with layer 1's text, seven settings; the two production D55 paths at the R13 rung with a refused chain, which also
verify their receipts with a fresh `stack-verify`), the CLI text gate `pr4_4_`, the three source-scan suites.
FULL SUITE (`g2_full_suite_patched`, BIN_P, all non-ignored tests, `--test-threads=8`, class cpu, 627 s): 996 passed, 3 failed, 134 ignored.
The three failures are `private_block::review_tests::a_toy_receipt_made_before_f12_is_refused`,
`private_block::trained_block::accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces` and
`private_block::trained_stack_tests::review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`: the "known three" of
a16/s4.sh's note, and all three fail identically on the unpatched binary (`g2_three_known_unpatched`, 0 passed 3 failed). I did not
investigate them (unrelated to this change).
Not run: the ignored Metal variants `..._on_the_device` of the A19 / A20 production tests and the other a16/s4.sh ignored tests
(a16 8B form tests, a14 and a12 tables, a11/a7 byte tests, the rung goldens): they do not call CS-3 or the sealing chain (they test
the prover's later phases, untouched); `d55_ab_one_request_serial_against_forks` and `a22_stream_ab` are covered by G5, which runs the
production sealing pass and verifies every receipt.

**G3 negative control.** `g4_a33_patched` (BIN_P) and `g4_a33_baseline` (BIN_B), `--nocapture fork::tests::a33_`, same lines:
```
A33-REFUSAL weight: the witness builder refuses layer 1 (before the run header; ruling H-1): R13 public weights/gains must be symmetric int8
A33-REFUSAL record-gate: layer 1, in the sealing pass (before the run header; ruling H-1): R13 public folded gate denominator differs from the stage shape
```
Both tests assert these exact strings, and pass on both binaries. (The first case is refused by the build, so CS-3's copy cannot be
the one that fires; the second shows the cases where it is, still refused with CS-3's text.)

**G4 byte equality.**
- The sealing pass, whole, rung (`g4_a33_*`): SHA-256 of the summary line equals on the patched and the old-behaviour binary:
  `59560de93562...` (budget unlimited, 475 B line) and `6f1d6d0078e0...` (budget 0, 423 B).
- The sealing pass, whole, 8B synthetic stack, L4 (`g4_8b_seal_patched`, `g4_8b_seal_baseline`; class gpu, `HL_GPU_REQUIRED=1`):
  CPU = device = old behaviour at both budgets: `e395260d67c3...` (555 B) and `3fd2b15f515b...` (486 B). (Full 64-hex values in the logs.)
- The trained-block timing test (`g4_m4_trained_patched`, `g4_m4_trained_unpatched`; `m4_trained_accuracy_block_cpu_and_metal_digests_and_times`,
  the six profiles of a16/s4.sh, `HL_M4_PHASES=1 HL_M4_WARM_PASSES=1`): CPU digest = Metal digest in every pass, and patched = unpatched,
  for all six profiles (`compare_digests.py`: ALL EQUAL): R13_SHIELD `5a6193d3`, R13_8B `f590b01f`, W16_SHIELD `79f987ef`, W16_8B `a8258241`,
  W16R2_SHIELD `0e88d84f`, W16R2_8B `90003b76` (the list of a16/s4.sh). Note this test proves a block directly; it does not call
  `seal_chain`, so it shows the prover's bytes are unmoved, and the two sealing-pass rows above show the sealing pass's.
- The stream arm's receipts (G5 logs): every run prints `all N receipts verified from their run directories, 818728672 B each`, for the
  cold request and the warm passes (`receipts-verified lines` column below), on the patched and the unpatched binary alike. Receipts carry fresh
  randomness, so their bytes are not equal run to run; their size is.

**G5 timing A/B** (`ab_run.py`, class gpu; the leaf, environment and guard arguments of `run_batch7_guarded.py:871, 903-915`; not set: `HL_A27_GPU_TRACE`;
`analyze.py` parses the logs). Order A B A B (A = unpatched, B = patched), each run a cold request then 6 warm passes; n = 12 warm
passes per binary. Medians over warm passes; `[p25-p75]` is the pooled interquartile range, `[min-max]` the range. Other heavy jobs held the
lock before some runs (`waited` in `GUARD_RUNS.md`); none overlapped a run (one heavy job at a time).

`serve1` (solo request): sealing pass = `sealing pass` of request 0; request wall = `result` of request 0.

| run | binary | sealing pass s, median [min-max] | request wall s, median [min-max] |
|---|---|---|---|
| serve1_1A | unpatched | 2.179 [2.143-2.243] | 6.127 [6.019-6.251] |
| serve1_2B | patched | 1.926 [1.832-1.944] | 5.877 [5.765-6.000] |
| serve1_3A | unpatched | 2.269 [2.148-2.398] | 6.357 [6.100-6.587] |
| serve1_4B | patched | 1.916 [1.840-1.996] | 5.847 [5.633-6.113] |
| **pooled (n=12/12)** | unpatched | **2.188** [2.161-2.266] | **6.213** [6.092-6.333] |
| **pooled (n=12/12)** | patched | **1.927** [1.887-1.933] | **5.878** [5.780-5.933] |
| difference, patched minus unpatched | | **-0.262 s** (per-run-median pairs -0.253, -0.353) | **-0.335 s** (pairs -0.250, -0.510) |

The two binaries' sealing-pass ranges do not overlap (unpatched min 2.143 s, patched max 1.996 s). **The measured saving is 0.26 s
(about 12%), not the 0.35 s the sampler profile gave.** I do not know why; the profile's 0.35 s was a sampled share of the lane
thread's time (with the sampler attached), and the A/B is the wall clock of the pass. The request wall falls by a similar amount
(0.34 s); the proof is not slower.

`serve4` (two lanes, 4 requests per pass; cadence = (result of request 3 - result of request 0) / 3, s per request; steady tok/s as the stream prints it):

| metric | n | unpatched median [p25-p75] | patched median [p25-p75] | patched minus unpatched |
|---|---|---|---|---|
| steady cadence s/request | 12/12 | 3.689 [3.646-3.757] | 3.732 [3.665-3.750] | +0.044 (pairs +0.065, -0.029) |
| steady tok/s | 12/12 | 34.70 [34.07-35.11] | 34.30 [34.13-34.93] | -0.40 |
| sealing pass of request 0 (solo) s | 12/12 | 2.197 [2.181-2.232] | 1.911 [1.895-1.998] | -0.286 |
| sealing pass of requests 1-3 (beside a proof) s, mean | 12/12 | 3.442 [3.379-3.507] | 3.113 [3.010-3.166] | -0.329 |
| request 0 wall s | 12/12 | 6.480 [6.407-6.574] | 6.172 [6.121-6.226] | -0.308 |

Per run: `AB_TABLES_serve4.md`; solo: `AB_TABLES_serve1.md`; raw logs `raw/`. **The two-lane steady cadence and tok/s do not move**
(+0.04 s and -0.4 tok/s are inside the run-to-run spread; the per-run-median pairs have opposite signs). The sealing pass is shorter
there too, but at two lanes the stream is paced by the prover (about 3.7 s per request), not by the sealing pass, so the saving
shows in the first request's wall and in the sealing pass's own time, not in the steady rate.

## 5. What this does not show

- It does not show the saving at any other profile, model, T, or machine state; the A/B is the W16R2 8B T128 H24, 32-layer synthetic
  stack of Batch 7, on a Mac shared with other agents' jobs (one heavy job at a time, but not a quiesced box: the guard's `status`
  before each run lists other processes' RSS; two A and two B runs, six warm passes each).
- It does not show a steady-rate gain at two lanes (none was measured), nor at 6 requests / 3 lanes (not run).
- It does not show why 0.26 s was saved and not 0.35 s.
- The equality evidence is of the sealing pass's summary (hashes of every plane, endpoint, record, digest, shape; a hash of a hash
  line, equal on CPU, device and the old behaviour) and of the prover's digests; not a byte comparison of two complete receipts
  (receipts carry fresh randomness; stack-verify accepts each).
- `build_checked` is true on every block of production's R13 stack; the fallback path (the old function) is exercised only by the
  synthetic record-gate test, not by a real export.
- The a16/s4.sh ignored device tests listed above were not run on the final tree.
- It does not cover the other callers of `check_lookup_misses` (CLI, classifier, token run), which still repeat the check: the same
  saving may exist there, with its own precondition (`classify_cli.rs:568` builds with `build_for_block`; the token CLI, `cli.rs:796`, builds with `build_shaped`,
which does not run `BlockPublic::check_for_shape`, so there the check is not a repeat).

## 6. Files

`guarded.py` (guard wrapper), `ab_run.py` (A B A B), `analyze.py` (tables), `compare_digests.py` (G4), `collect_guard.py`
(`GUARD_RUNS.md`), `AB_TABLES_*.md`, `AB_METRICS_*.json`, `raw/*.log` (leaf output), `raw/*.guard.json` (guard terminal records
with run ids), `raw/*.status_pre.txt` (guard status and ds4-bench check around each run), `raw/*_binaries.txt`. `scrub.py` was run once over `raw/`: the four `g1_build_*.log` files (cargo JSON) are replaced by a one-line
summary (test executable, warning and error counts) and the agent scratch directory's path is written `<scratch>`.
