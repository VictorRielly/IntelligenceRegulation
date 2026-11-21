# A36: the next block's boundary commitment and first half made beside this block's second half, in the classifier run. Gate G0 only (correctness). Switch `HL_A36_CORE_AHEAD`, default OFF, NOT RULED

Written 2026-11-21 05:10 UTC by the implementation agent (Claude, Sonnet). Branch `worktree-agent-a3be4019d2dca3765`.
Base: the worktree was created at `e9e4654b`; `git merge perf/zk-batch-optimizations` said "Already up to date" (that branch is `e9e4654b`),
so head after the merge = `e9e4654b`. The change is uncommitted on top of it until the commit that carries this file.
Labels: **CODE-READ** (file and function), **MEASURED** (a guarded run here, log in `raw/`). **No timing was made or claimed.**

## 1. What changed

| file | change |
|---|---|
| `src/private_block/token_io/classify_run.rs` | the switch `a36_core_ahead()` (read as A35's is, through `a20_switch`; default 0); in `prove_classify_run_with`: `let ahead = a36_core_ahead() && blocks.resident();` then, if `ahead`, `(pending, prev) = prove_blocks_core_ahead(...)`, and the old block loop's range `0..l` became `0..(if ahead { 0 } else { l })`; new functions `core_ahead_stream`, `core_ahead_inputs`, `core_ahead_job`, `prove_blocks_core_ahead`; test-only counters |
| `src/private_block/hash_domain.rs` | `ROLE_RUN_CORE_AHEAD = 0x04`, the literal `SEED_USE_RUN_CORE_AHEAD` (58 bytes, the run stream's length), `run_core_ahead_seed_domain(profile)` |
| `src/private_block/token_io/run.rs` | one new DEFAULT trait method `TokenBlocks::resident_block(&self, k) -> Option<&BlockPublic>` (default `None`), implemented for `ResidentBlocks` and `KeptResidentBlocks` only. Only the trait and those two impls; no verifier code |
| `src/private_block/s25_tests.rs` | the generator census: 9 sites -> 10 and on-path 8 -> 9, with a new assertion that `classify_run.rs` has exactly two sites. **A pinned test edited; see section 7 (decision 1)** |
| `src/private_block/s26_tests.rs` | new test `a36_the_second_run_stream_has_its_own_domain_and_the_run_streams_length` |
| `src/private_block/token_io/classify_tests.rs` | new tests `a36_the_switch_follows_its_environment_variable_and_is_off_by_default` and `a36_core_ahead_proves_receipts_the_unchanged_verifier_accepts` (G0) |
| `src/private_block/token_io/classify_w16r2_tests.rs` | new test `a36_the_bytes_the_next_blocks_first_half_holds_at_the_w16r2_shieldstral_shape` (prints the memory figures) |

Not touched: any verifier function, `protocol.rs` (the existing `prove_core_before_with` / `prove_core_after_with` are used as they are), `trained_block.rs`,
`run_fork.rs`, `formal/`, `apps/`, `manifest.rs`, any existing switch's default.

**The off path is the old code.** The old loop `for k in 0..l { ... }` is textually untouched; only its range expression changed. With the switch off, or over a
loading source (`blocks.resident()` false: `ExportTokenBlocks`, i.e. `zk60_classify prove`), `ahead` is false, `prove_blocks_core_ahead` is never called, the
second generator is never made (no entropy read), and the loop runs for all `l` blocks on the one `rng` exactly as before. `a36_core_ahead()` is read once per run on
the request thread.

## 2. The mechanism (CODE-READ, `classify_run.rs`)

Per block `k`, `prove_blocks_core_ahead` does, in this order, on the calling (request) thread unless noted:

1. absorb `pb-run-stage`, `pb-run-block` (the loop's own first two absorbs);
2. take block `k`'s ahead state: made by the previous iteration's job; for `k = 0` made here by calling `core_ahead_job` inline (so block 0's first half runs before block 0's second half, as today);
3. absorb `B`'s root (`protocol::absorb_root(tr, b"B", ...)`, the loop's third absorb, at the same position: after the stage and block absorbs, before anything of the core);
4. read block `k+1`'s boundary plane and witness from `src` (`core_ahead_inputs`; `src` is `&mut dyn ClassifyRunSource`, not `Send`, so it cannot go to the worker; plane first, then witness, as the loop reads them);
5. `rayon::in_place_scope`: `spawn` block `k+1`'s `core_ahead_job` (on a worker of the pool the request already runs in; `in_place_scope` keeps the closure that follows on the calling thread, where `rayon::scope` could move it) and, on the calling thread, `prove_core_after_with` (block `k`'s second half: the first transcript use after step 3);
6. the scope joins; then, as in the loop: `io_claims`, `into_opening`, the segment, `encode_segment`, `sink`.

`core_ahead_job(j)` is, in the loop's order and with its refusal strings: `stage_block_kept` (CS-1/4/6), `boundary_spec(j+1)`, the plane length check, `boundary::prepare`
(B_(j+1)), `block_layout`, `stage_shape`, then `protocol::prove_core_before_with` (which "reads no transcript", `protocol.rs:2245`). It reads no transcript and
makes no absorb or squeeze; the transcript sees the same absorbs and squeezes in the same order as the loop. The first half's output (`CoreAhead`) is consumed
by `prove_core_after_with` (which checks the shape, layout and block address: `blk_at`, the same `&BlockPublic` because `resident_block(k)` returns the same slice element every time).

**Error precedence.** A job's `Err` (and any error of the reads in step 4) is held in a slot and returned at the start of the next iteration, after block `k`'s second
half, opening, encode and sink: the first error of the loop's own order is the one returned, and the sink order is unchanged. (The refusals themselves were already
checked once for every block by the sealing pass, before the header.)

## 3. Randomness: which draws come from which stream (for a cryptographic reviewer)

Two `ZkRng`s INSIDE THE RUN (a classifier request also has the input endpoint's own stream, `seal_input`, so a whole request has **2 streams with the switch off and 3 with it on**: the endpoint's, the run's, and the A36 stream; Sol's table in review 492), both `ZkRng::from_os(domain)` (the same constructor, OS entropy), each its own derivation input:

* **Run stream `rng`** (the existing one, `classify_run.rs` in `prove_classify_run_with`, domain `run_seed_domain(profile)` = `…/one-stream-per-whole-run/v1/ ‖ 0x03 ‖ profile`): stage IN-C (`stage_in_c::prove`, before the loop, as today); **every block's second half** (`prove_core_after_with`: the H commitment, the zero-sum and opening masks, `open_zk`); stage OUT-C (`stage_out_c::prove`, after the loop). The boundary openings draw nothing (`into_opening` takes no generator).
* **A36 stream** (new, `core_ahead_stream`, domain `run_core_ahead_seed_domain(profile)` = `…/run-first-half-ahead-a36/v1/ ‖ 0x04 ‖ profile`; the literal and the role byte are each its own; 58-byte literal like the run stream's, so the derivation input has the run stream's length, 125/126/115 B, and adds no row to any length table): **every `boundary::prepare` of `B_1 … B_L`** (pads, salts, mask rows of the boundary commitments) and **every `prove_core_before_with`** (A's mask rows, A's commitment pads and salts, M's mask commitment).
* Order within each stream: the A36 stream's draws are block 0's job, block 1's job, ... in block order, each job `prepare` then `before`; the run stream's draws are in program order as described. Neither is ever derived from the other, cloned, split or fed from the other; `ZkRng` has no `Clone` (pinned by `s25_tests`).
* **Each stream is used by at most one thread at any time (CODE-READ and by types).** The run stream is a `&mut ZkRng` used only inside the calling thread's closure of step 5 (the `spawn` closure captures no reference to it). The A36 stream is held as `Option<ZkRng>` and moved by value (`take()`) into the job (block 0: an inline call on the caller; block `j+1`: the spawned closure), returned inside the job's result, and put back by the caller only after `in_place_scope` has joined the job; a missing stream is an error, not a second construction. So the two jobs of consecutive blocks never overlap on the A36 stream, and block `k`'s second half (run stream) overlaps only block `k+1`'s job (A36 stream).
* What this changes for the honest prover's model: today one run stream (besides the input endpoint's) serves all the prover's in-run draws in one program order; with the switch on, the same kinds of draws are split over two independent streams and their interleaving in time is not fixed (but each stream's own order is). It is a change to "ONE stream per whole run" (`SEED_USE_RUN`'s name, the memo's A-20 item 2, ruling R-2's condition) and to `prove_core_after_with`'s doc ("with `rng` the generator it drew from"; nothing checks it). That is why the switch stays off until the owner has ruled and Sol/Antigravity have said what it does to `O.zk`'s honest view.

## 4. Gate G0 (MEASURED; every leaf through the guard, one at a time; ids from `raw/*.guard.json`)

`W` = `ops/zkp-mvp/gpu-metal/hashline`. Cargo `/opt/homebrew/bin/cargo`. Final binary: the `--release --features gpu-metal` test binary built by guard run `da037221e8b2`.
`gates.py <group>` runs the steps below (`guarded.py` is A35's with the label prefix `a36`).

| gate | leaf | guard run id | exit | result |
|---|---|---|---|---|
| build | `cargo test --release --offline --locked -j 2 --features gpu-metal --lib --no-run` | `da037221e8b2` | 0 | 168 s, peak 4.49 GiB; the only warning naming a changed file is `token_io/run.rs:834` (an unused doc comment on text I did not touch) |
| no-feature check | `cargo check --tests --offline --locked -j 2` | `8c543e5acc9e` | 0 | 1.8 s (incremental; an earlier full run `6c4aafe7c7cc`, 15.5 s, exit 0) |
| the A36 tests (CPU) | `... --test-threads=1 --nocapture a36_` | `f5a92d7e776b` | 0 | 4 passed |
| generator census | `private_block::s25_tests::` | `a1b23f87e892` | 0 | 20 passed |
| domains | `private_block::s26_tests::` | `0ab15ef5742e` | 0 | 9 passed (8 + the new one) |
| hash-domain tests | `private_block::hash_domain::` | `26bd3c775e24` | 0 | 15 passed |
| classifier modules, switch OFF (`HL_A36_CORE_AHEAD=0`) | `private_block::token_io::classify` (every `classify*_tests` module, with `classify_capture_tests`' `gate19`, `r17`, `r18`, `w16r2`, `serve`, `cli`, `tied`, `r14`..`r16`) | `9155eb941d4a` | 0 | 101 passed, 12 ignored (the ignored ones need an export, a binary or env vars); `A36 path` printed 2 times: the G0 test's own two switch-on runs |
| classifier modules, switch ON in the environment (`HL_A36_CORE_AHEAD=1`) | the same filter | `9e705b5a9b57` | 0 | 101 passed, 12 ignored; **`A36 path` printed 58 times**: 58 classifier proofs in these tests went through `prove_blocks_core_ahead`, including the cheating-prover and tamper tests, and every one passed |
| Metal | the A36 tests with `HL_GPU_REQUIRED=1`, class gpu | `3f0a695f6d37` | 0 | 1 passed (`a36_core_ahead...`). **I cannot show from the log that the device carried these commitments**: peak VRAM 518 MiB equals the box's baseline; the shape is the tiny rung |

Earlier in the work: a first G0 run failed (`34a1b8d56f3b`, exit 101: the library fixture of `classify_cli_tests` has ONE block, so the test moved to `classify_tests`' two-block fixture); two empty-filter runs (`b48e78111dd8`, `5240ae3c1012`, 0 tests: the gate-19 tests are a child module of `classify_capture_tests` and so are inside the `classify` prefix).
The A35 README lists Metal tests for the fork path only (`a22::a35_...on_the_device`); none of them reaches the classifier path, so none was run.

**The G0 test** (`classify_tests::a36_core_ahead_proves_receipts_the_unchanged_verifier_accepts`, the two-block rung fixture the module already uses): a classifier run proved with the switch off and on over a resident slice, over the server's `KeptResidentBlocks` with the kept records handed, and over a loading source (a local non-resident `TokenBlocks`). Every receipt is accepted by the UNCHANGED `verify_classify_run` (over the verifier's own block slice), passes `owner_check_input`, has the counted segment lengths, and the same segment lengths in every run; a byte-flipped receipt made with the switch on is refused. Counters (thread-local, this thread): on a resident source one second stream, both blocks through the A36 path, and block 1's job ran on a thread other than the caller's (printed `1, 2, 1`); off, and over the loading source, `0, 0, 0` (the A36 path did not run). The switch is forced for the test per THREAD (`set_a36_core_ahead_for_test`), not process-wide as A35's: the ahead work runs on a pool worker, where other tests' thread-local tamper hooks (`protocol::moved_multiplicity` and kin) are not set, so a process-wide window would leak into concurrent tests of other threads.

## 5. Memory (CODE-READ, the test `a36_the_bytes_...` prints it)

At `W16R2_SHIELD_T128_H24` (`a_rows` 2501, `n` 16384 = 2^14, `inv_rate` 2, `m_rows` 50; the tick's 2,504 x 8,192 was ASSUMED, this is read from the layout):
the next block's committed A matrix is **327,811,072 B (312.6 MiB) of host words**; its **encoded matrix 655,622,144 B (625.2 MiB)** (on the host or on the device, wherever `commit_zk_owned_tagged` leaves it); the committed witness planes 296,030,208 B (282.3 MiB) (in the app the kept A24 witness is already resident, moved not copied); `CoreAhead::host_bytes` adds the derived lookup columns and M's encoding, which I did not count. So about 0.6 GiB of host words plus 0.6 GiB encoded, **per lane, one block early**, on top of the current block's own.

## 6. What I did NOT verify

* Any timing (none allowed). Whether the worker's first half really overlaps the device wait at the W16R2 shape, and whether memory contention eats the ceiling.
* Any run at the W16R2 Shieldstral shape or with the real export; only the synthetic rung and the tests above. The classifier modules were not run on the Metal device with a shape large enough to take the device path.
* The full 1148-test suite (only the classifier, census, domain and hash-domain groups, off and on).
* A one-thread pool, a pool where the request thread is not a worker (the tests are that case: the job ran on a global-pool worker), and a loaded pool where the job waits for a free worker. `in_place_scope` runs a still-waiting job at the scope's end, so a one-thread pool serialises (correct, slower); not exercised.
* Thread-local test hooks in the first half under the switch (`moved_multiplicity` and the misfile hook are read in `prove_core_before_with`, which now runs on a worker): none of the 58 switch-on proofs used one, so I do not know whether a hook test would still see its hook. Production does not use them.
* Phase diagnostics: the worker's first-half marks are reported on their own `prove-ahead` line (when `HL_PB_TIMING` is on), not merged into the block's `prove` report.
* `formal/`: not read; no claim about the Lean honest-prover model.

## 7. Decisions for the coordinator

1. **The generator census (`s25_tests`) pins 9 / 8 `ZkRng::from_os` sites and its own text says "classify the new one".** Rule 2 of the brief requires a second `from_os` in `classify_run.rs`, so the pinned numbers had to move (9 -> 10, 8 -> 9, plus "exactly two in `classify_run.rs`"). I put the second construction in its own function (`core_ahead_stream`) outside the body of `prove_classify_run_with`, so `the_generator_is_never_cloned_and_each_prover_constructs_exactly_one` (which counts one `from_os` in that body) is unchanged and green. A35 treated an edit of a pinned test as a stop condition; here it follows from the rule, so I made it and flag it.
2. **`TokenBlocks::resident_block` (in `token_io/run.rs`, which also holds the token-run verifier).** The run's `blocks.block(k)` returns a `BlockRef<'_>` tied to `&mut self`, so block `k` and block `k+1` cannot be held together (rule 5). The smallest change I found is this default `&self` method returning the same object for resident sources; loading sources keep `None` and fall back to the loop. Lifting that for the streaming `ExportTokenBlocks` would need a two-block cache (double the block weights resident): not done.
3. **`src` is not `Send`.** The witness (and the boundary plane) of block `k+1` is read on the request thread before the spawn; only `prepare` and the first half move to the worker. In the app the witness is a kept A24 witness (cheap, moved out of the kept slot); for a source that rebuilds it, the builder cost stays on the request thread. Lifting that needs `ClassifyRunSource: Send` (or a lock around `src`).
4. **Only `serve` takes the switch.** `zk60_classify prove` (`prove_with_public` with `shared = None`) uses `ExportTokenBlocks` (not resident), so `HL_A36_CORE_AHEAD=1` changes nothing there; `classify-serve` hands `KeptResidentBlocks` over its `srv.blocks`. This decides what T1 can be.
5. The switch is read once per process through `OnceLock` (as A35's): a server needs the environment variable set before its first request.

## 8. T1 (proposal from reading only; NOT run)

No `cargo test` runs a classifier request at the W16R2 Shieldstral shape (it needs the Shieldstral export and the tied tables). The named binary does, and only its resident server takes the switch (decision 4):
`zk60_classify serve --lanes 1 --lane-threads 5 --witness-gib 16 --dev-w16r2-public-content-only` (the flags of `results/zk60_a25_app_20261107/m1.sh` and `results/zk60_a28_app_20261107/stream_driver.py`, with `--lanes 1`), `--export`, `--tables`, `--policies` as that harness gives them, one T = 128 request line, under `scripts/zk60_resource_guard.py run --class gpu`, with `HL_A36_CORE_AHEAD=0`, `1`, `1`, `0` in four server launches (the first request of a server is cold: the harness should discard it or send one warm-up request before the timed one). Metric: the request's prove call (the `prove_classify_run_with` span; `cli_phase("prove", "the run (prove_classify_run_with ...)")` / `prove_s` in the request's event line). The receipts of the on-legs go through the server's own verifier unchanged. The coordinator's fixture decides; the single-process `prove` command is not an option.

## 9. Files

`gates.py` (the gate groups: build, check, g0, off, on, metal), `guarded.py`, `raw/` (each leaf's `.log`, `.guard.json`, `.status_pre.txt`, `.done`).

## 10. T1 (the pre-registered one-lane timing test; run 2026-11-21 05:24 to 05:31 UTC)

Rule (coordination entry of 2026-11-21T05:13:36Z, not changed): the on leg's median prove call at least 4% lower than its paired off leg's in BOTH pairs (leg 1 with 2, leg 3 with 4), and every on-leg receipt accepted by the unchanged verifier; anything else is a kill.
Labels: MEASURED (`raw/t1/`, `raw/t1.guard.json`); the numbers below are `t1_summary.py`'s output.

**Fixture** (also posted in the coordination file before the first timed request). The `zk60_classify` example built from this branch at `3879c471` (release, `gpu-metal`; guard run `9a1317fb8550`, exit 0), `t1_driver.py --legs 0,1,1,0 --warm 1 --timed 3 --verify-on`, one guarded gpu job (run `2e9339bdbcf4`, class gpu, exit 0, 412.6 s, peak RSS 27.45 GiB, peak VRAM 5811 MiB). Per leg a fresh server: `zk60_classify serve --export <a29-uniform-calibration/export_u1> --tables <export_u1>/token_io --policies <the three shieldstral moderate policies> --label zk60-classify-verdict --lanes 1 --lane-threads 5 --witness-cache-gib 16 --dev-w16r2-public-content-only`, with `HL_METAL_QUEUES=thread HL_METAL_SPIN_US=200 HL_A28_STAGGER_MS=300 HL_A26_KEPT=1 HL_A30_B3PAR=1 HL_A26_VERIFY_ONCE=0 HL_A28_SEAL_AHEAD=0` (the installed W16R2 profile's `native_settings`) and `HL_A36_CORE_AHEAD` = 0, 1, 1, 0. One warm-up request, then three timed requests, one at a time. Request: the public post `results/zk60_a24_app_20261107/posts/one.json` (14 content ids; the run's context is T = 128), category `sexual`, chunk 0. Activations from Astra's parameterized resident writer client on `export_u1`, run as my own writer process before any server started (closed; not on the clock; the installed app's services were not touched, nothing owner-private was read).
Two things differ from the installed app, both read-only choices: the binary is this branch's, and `export_u1` serves as the verifier's export too (`PUBLIC_DIR/verifier-export-w16r2-94643880` is not on this disk; the coordinator's batch-2 harness also used `export_u1` for both). The smoke (switch off, `raw/t1_smoke*`, guard `e7768f33fe7f`) first failed three times for fixture reasons (the old `native_low_h24_t128` export is refused under the W16R2 flag; the owner directory may not sit inside the run's parent directory; activations from the old one-shot writer fail the parity check against `export_u1`) and then proved and verified.

**Prove-call spans** (`prove_seconds` of the request's `proved` event = the span of `prove_classify_run_with`), seconds:

| leg | A36 | warm-up | timed 1 | timed 2 | timed 3 | median | timed whole-request wall (median) |
|---|---|---|---|---|---|---|---|
| 1 | off | 9.081 | 8.942 | 8.933 | 8.948 | **8.942** | 11.244 |
| 2 | on | 8.691 | 8.510 | 8.548 | 8.461 | **8.510** | 10.825 |
| 3 | on | 8.642 | 8.524 | 8.464 | 8.448 | **8.464** | 10.855 |
| 4 | off | 9.103 | 9.111 | 8.881 | 8.901 | **8.901** | 11.180 |

Ratios on / off: pair 1 (leg 2 / leg 1) **0.9517** (4.83% lower); pair 2 (leg 3 / leg 4) **0.9509** (4.91% lower). Whole-request wall medians point the same way (3.7% and 2.9% lower). Every segment's elapsed time is in `raw/t1/t1_results.json` (`segment_elapsed`, 28 segments a request); receipts are 669,561,472 B in every leg.

**Verification.** Every receipt of the two on legs (4 + 4, warm-ups included) was accepted by the unchanged verifier at the real shape: the binary's own `check-serve` (fresh verification, input-owner check, label; `--expect-statement` the prover's reported identity, `--min-bits 95`), 8 of 8 `checked`, about 6.1 s each (`leg2/3_*.checker.log`). The off legs were not verified (not required).

**Device evidence.** Guard peak VRAM 5811 MiB over a baseline of about 520 MiB; the Metal "Device Utilization %" (`ioreg`, 2 s samples) over each leg: mean 51.2, 53.5, 56.7, 51.3 %, max 82, 78, 78, 71 % (baseline 0 to 61 % at leg starts); `HL_GPU=1`, and every server's `serve-start` line reads "gpu: ON (Metal, Apple M3 Ultra, ... commitments on the device)" with the app's W16R2 statement identity `e2f3ed60...dde7` (`raw/t1/leg*_prover.log`). This is a trace of the device being busy during the runs, not a per-commitment count (`HL_PB_TIMING` stayed 0 so as not to perturb the clock).

**Disturbances.** None observed: `pgrep ds4-bench` empty before and after every leg; guard heavy lock free at launch; no failed request. The box was otherwise not quiesced beyond that (other agent processes were resident; no other guarded job ran). One timing run, no repeat. Within a leg the three timed values spread under 0.2% (legs 1 to 3) and 2.5% (leg 4, whose first timed request is 9.111 against 8.88 and 8.90).

**Verdict by the pre-registered rule: PASS** (both pairs at least 4% lower, all eight on-leg receipts verified). T2 (the app's stream: 6 lanes, 48 requests, off, on, on, off) is the coordinator's to request.

**Not measured / not shown.** Six lanes and the stream (memory and device contention at six lanes may eat or add to this: the model has no contention term); a request of 128 content ids (the post has 14; the proof's shape is T = 128 either way); the A36 path's use in these legs is established by the switch, the resident `serve` source and G0, not by a counter in the release binary; the off legs' receipts were not verified; no CPU-second comparison; whether the two on legs and two off legs differ in anything but the switch beyond the binary's process state (each leg is a fresh process).
Files: `t1_driver.py`, `t1_summary.py`, `raw/t1/`, `raw/t1_smoke/`, `raw/t1*.guard.json`.

## 11. S1: the phase reading at the T1 fixture (one lane, switch OFF, `HL_PB_TIMING=1`; run 2026-11-21 07:58 UTC)

A reading, not a speed test (the coordination entry of 2026-11-21T07:55:03Z, "S1, pre-registered"; its rule is not changed). **This run's prove-call times are not compared with T1's** (the diagnostic is on).
Labels: MEASURED (`raw/s1/`, `raw/s1.guard.json`); every figure below is `s1_summary.py`'s output.

**Command.** One guarded gpu job (run `8068faf34b1e`, class gpu, exit 0, 85 s, peak RSS 27.45 GiB, peak VRAM 4859 MiB; the guard showed the heavy lock free before the launch): `s1_driver.py --warm 1 --timed 3` (driver written for this reading; it reuses `t1_driver.py`'s paths, writer, request and settings). The same binary as T1 (`zk60_classify`, SHA-256 `d3eae116eba0c62b0c32fc1d42d0b279b778475d8c6ce1bfcf0ea8f4d6cf0e37`, checked; not rebuilt). One server launch: `zk60_classify serve --export <a29-uniform-calibration/export_u1> --tables <export_u1>/token_io --policies <the three shieldstral moderate policies> --label zk60-classify-verdict --lanes 1 --lane-threads 5 --witness-cache-gib 16 --dev-w16r2-public-content-only`, environment as T1's posted fixture (`HL_METAL_QUEUES=thread HL_METAL_SPIN_US=200 HL_A28_STAGGER_MS=300 HL_A26_KEPT=1 HL_A30_B3PAR=1 HL_A26_VERIFY_ONCE=0 HL_A28_SEAL_AHEAD=0`) with `HL_A36_CORE_AHEAD=0` and **`HL_PB_TIMING=1`** added. One warm-up request (not read), then three timed requests (`r1`..`r3`), one at a time; public post `one.json`, category sexual, chunk 0. A smoke of one request first (`raw/s1_smoke*`, guard `49956f7d4cf4`) confirmed that the lines appear.

**Where the lines go, and what `HL_PB_TIMING` does (CODE-READ, `timing.rs`, `classify_run.rs`).** `classify_run.rs` makes one `timing::Phases` recorder per block and calls `ph.report("prove", profile)` after the block, which `println!`s the block's table (`PB-TIMING prove [profile] ... wall W s`, one row per phase, `SUM OF PHASES`, halves) to the server's stdout, with `PB-SLOTSTEP` lines from `argument.rs` and one `PB-CLI` line for the pre-header pass. With one lane the lines between a request's send and its `served` line are that request's; the driver keeps them per request (`raw/s1/rK.timing.txt`, 4005 lines each). **It does nothing but read clocks and print**: `Phases::mark` is a clock read and a read of `/proc/self/status`, which does not exist on macOS (the read fails at once, RSS prints as NaN) and the clock restarts after it, so the reading's own cost lands in no phase; no device wait is added (`HL_METAL_TIMING`, which is a separate variable and was not set, is the one that touches the device). Per block that is 45 marks and about 150 printed lines to a pipe. **Resolution is 1 ms**: the table prints seconds to three decimals, so every value below is a whole millisecond (a median of 21.5 is the midpoint of two rows). Stage IN-C and OUT-C have no phase table in this log (only the blocks do: 26 tables a request, 78 in the three timed requests); the pre-header pass prints one `PB-CLI` line (2 to 3 ms).

**The whole table** (ms over the 78 block rows of the three timed requests; `n` rows each):

```
block tables read: 78 (expected 78); phase names: 45; rows per phase (min/max): 78/78
phase                                                           median ms    min ms    max ms    n
run: block load + statement check                                   0.000     0.000     0.000   78
run: boundary B_k commitment                                        6.000     6.000     6.000   78
run: witness (CliSource)                                            1.000     1.000     1.000   78
A: allocate + witness planes -> committed rows                      3.000     3.000     7.000   78
A: lookup values + the byte histogram                              12.000    11.000    13.000   78
A: exp/act indices + their two histograms                           2.000     2.000     2.000   78
A: mask + proximity rows (fresh randomness)                        11.000    10.000    13.000   78
A: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)          21.500    20.000    31.000   78
M: mask commit (zk::mask_commit, ONE call)                          4.000     3.000     4.000   78
H: LogUp helper inverses (six lookup domains)                      13.000    12.000    13.000   78
H: exp + activation helper inverses                                11.000    11.000    13.000   78
H: release the four witness buffers (S2 drops)                      1.000     0.000     2.000   78
H: the three table helpers                                          1.000     1.000     1.000   78
H: mask rows + the zero-sum rows                                    5.000     5.000     6.000   78
H: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)          22.500    21.000    29.000   78
slot 00 01 SS row sums norm_a (private)                             7.000     6.000     7.000   78
slot 01 01m SS row sums norm_m (private)                            7.000     6.000     7.000   78
slot 02 02 norm squares zero-check (hosts 01, 01m)                  0.000     0.000     0.000   78
slot 03 08 limb zero-check                                          3.000     2.000     3.000   78
slot 04 07 masked row sums + selector (private)                     7.000     7.000     8.000   78
slot 05 09Q matmul (private)                                        4.000     3.000     4.000   78
slot 06 09K matmul (private)                                        1.000     1.000     2.000   78
slot 07 09V matmul (private)                                        1.000     1.000     2.000   78
slot 08 10 score matmul (private, bilinear)                         1.000     1.000     1.000   78
slot 09 11 PV matmul (private, bilinear)                            1.000     1.000     1.000   78
slot 10 12 Wo matmul (private)                                      4.000     4.000     4.000   78
slot 11 13G gate matmul (private)                                   8.000     8.000    11.000   78
slot 12 13U up matmul (private)                                     8.000     8.000    11.000   78
slot 13 13D down matmul (private)                                  10.000    10.000    11.000   78
slot 14 03 D zero-check (hosts 12, 13D)                            20.000    19.000    25.000   78
slot 15 04 Q zero-check (hosts 09Q, 11)                             9.000     8.000    10.000   78
slot 16 05 KV zero-check (hosts 09K, 09V)                           5.000     4.000     5.000   78
slot 17 06 softmax zero-check (hosts 07, 10)                       10.000     9.000    11.000   78
slot 18 14 F zero-check (hosts 13G, 13U)                           28.000    27.000    32.000   78
slot 19 TAB table helper zero-check                                 6.000     5.000     7.000   78
slot 20 ZS zero-sum row                                             1.000     1.000     1.000   78
slot 21 IO-in endpoint equality                                     2.000     2.000     3.000   78
slot 22 IO-out endpoint equality                                    2.000     2.000     3.000   78
open M (zk::mask_open, ONE call)                                    3.000     3.000     3.000   78
open A (schedule audit + pcs::open_zk)                             22.000    22.000    25.000   78
open H (schedule audit + pcs::open_zk)                             24.000    24.000    30.000   78
run: boundary B_(k-1) opening                                       2.000     2.000     2.000   78
frame: encode segment                                               2.000     2.000     4.000   78
sink: segment to disk                                              21.000    19.000    26.000   78
run: drop block                                                     0.000     0.000     0.000   78
SUM OF THE MEDIANS                                                333.000
MEDIAN BLOCK WALL (the table's own wall)                          335.000   326.000   354.000   78

largest phases by median:
    28.000 ms  slot 18 14 F zero-check (hosts 13G, 13U)
    24.000 ms  open H (schedule audit + pcs::open_zk)
    22.500 ms  H: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)
    22.000 ms  open A (schedule audit + pcs::open_zk)
    21.500 ms  A: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)
    21.000 ms  sink: segment to disk
    20.000 ms  slot 14 03 D zero-check (hosts 12, 13D)
    13.000 ms  H: LogUp helper inverses (six lookup domains)

the five named phases:
  sink: segment to disk                    median 21.000 ms
  frame: encode segment                    median 2.000 ms
  run: boundary B_(k-1) opening            median 2.000 ms
  run: boundary B_k commitment             median 6.000 ms
  run: block load + statement check        median 0.000 ms

stage rows (IN-C, OUT-C) with phase tables: none in the log
PB-CLI prove lines in the timed requests: 3
  r1: PB-CLI prove | run sealing pass (every block loaded once, statement checks) | 0.003 s
  r2: PB-CLI prove | run sealing pass (every block loaded once, statement checks) | 0.002 s
  r3: PB-CLI prove | run sealing pass (every block loaded once, statement checks) | 0.002 s

writer-thread rule: sink median 21.000 ms -> ALIVE (>= 12 ms)
load + check median 0.000 ms -> under 2 ms
```

**The five named phases (medians over the 78 rows):** `sink: segment to disk` **21 ms** (min 19, max 26); `frame: encode segment` **2 ms** (2 to 4); `run: boundary B_(k-1) opening` **2 ms** (2 to 2); `run: boundary B_k commitment` **6 ms** (6 to 6); `run: block load + statement check` **0 ms** (below the 1 ms resolution; min 0, max 0). The sum of the 45 medians is 333 ms against a median block wall of 335 ms (the recorder's own, per block).

**Verdict by the posted rule: the writer-thread idea is ALIVE** (sink median 21 ms, at least 12 ms; the sink was 19 to 26 ms in every one of the 78 rows). **Load plus check is under 2 ms** (0 ms at 1 ms resolution, with the kept record: `HL_A26_KEPT=1`).

**Odd or worth knowing.** The block's own wall (335 ms median) is the request thread's serial time per block with the diagnostic on; the three largest phases other than the sink are `slot 18 F zero-check` (28 ms), `open H` (24 ms) and `H: commit` (22.5 ms). The sink at 21 ms is about 6% of the block's wall and larger than the opening, encode, boundary commitment and load plus check together (10 ms).

**NOT measured.** Six lanes, and several lanes flushing their segments at once (the sink's cost under shared disk bandwidth, which could be larger or smaller); the sink's cost on another disk or with the page cache cold; any speed effect of moving the write off the request thread; the switch ON (this is the OFF path only); the stage rows IN-C and OUT-C (no phase tables); a resolution finer than 1 ms.
Files: `s1_driver.py`, `s1_summary.py`, `raw/s1/` (per-request tables `r0..r3.timing.txt`, the server's log), `raw/s1.guard.json`, `raw/s1_smoke*`.

## 12. Sol's review 492 and the entropy-boundary change (2026-11-21 08:38 UTC)

**What Sol found** (`results/zk60_sol_20261105_w16r3/b3/A36_RANDOMNESS_REVIEW_492.md`, of commit `3879c471`): the split is sound on the successful fixed-witness path and the census edit is accepted for this opt-in branch, but the A36 stream was seeded inside `prove_blocks_core_ahead`, after `sink(0, bytes)` had already handed stage IN-C's frame to the sink, so with the switch on an entropy failure could follow a frame already handed to a sink. Sol asks that the switch-gated seed read move before the header, to recover the older fail-closed boundary (ruling R-2). Sol's count of streams per classifier request: 2 with the switch off or a loading source (the input endpoint's, the run's), 3 with it on and resident blocks (plus the A36 stream); section 3 above is corrected to say so.

**The change (only this).** In `prove_classify_run_with`, right after the run stream's `ZkRng::from_os`, the switch is decided once (`let ahead = a36_core_ahead() && blocks.resident();`) and, if on, the A36 stream is made there by `core_ahead_stream(st)` (`let stream_a: Option<ZkRng>`, `None` when off: no second OS read). It is handed to `prove_blocks_core_ahead` as a new by-value parameter `stream_a`; the construction inside that function is gone; the old block loop's range uses the same `ahead`. The `from_os` site stays inside `core_ahead_stream`, so the S25 census numbers (10 sites, 9 on-path, two in `classify_run.rs`) are unchanged and `s25_tests.rs` was not edited. Doc comments (`core_ahead_stream`, `prove_blocks_core_ahead`, `hash_domain.rs`) say where the stream is made. One new test, `classify_tests::a36_the_second_stream_is_seeded_before_the_header_and_before_segment_0`: (1) a source-order check in the S25 style (in `prove_classify_run_with` the call `core_ahead_stream(st)` is before `st.transcript()` and before the first `sink(`; `prove_blocks_core_ahead` has no `core_ahead_stream(` call and no `from_os`, and takes `stream_a`); (2) a run check on the thread counters: with the switch on, at the moment segment 0 reaches the sink one second stream is already recorded and the run header already built; with it off, none is ever made.

**Gates (each through the guard, one at a time; ids from `raw/*.guard.json`; all exit 0):**

| gate | guard run id | result |
|---|---|---|
| build (release test build, gpu-metal) | `39a4cc8d606f` | exit 0 |
| no-feature `cargo check --tests` | `020275a90ea9` | exit 0 |
| the A36 tests (CPU, `a36_`): G0 prove-then-verify, the new order test, the switch, domain and memory tests | `2a16a154e1c1` | 5 passed |
| S25 census | `4a6bb852a023` | 20 passed |
| S26 | `2ab587a89eb6` | 9 passed |
| hash-domain tests | `5cf53fb3c465` | 15 passed |
| classifier modules, switch off | `6459d3dfdb88` | 102 passed, 12 ignored (`A36 path` printed 3 times: the two G0 switch-on runs and the new test's) |
| classifier modules, `HL_A36_CORE_AHEAD=1` | `1dae4e7d68ea` | 102 passed, 12 ignored (`A36 path` printed 59 times) |
| A36 tests on the Metal device (class gpu) | `950f71a26920` | 1 passed |
| release `zk60_classify` with gpu-metal, as for T1 | `6988f3c59339` | exit 0 |
| smoke: resident server on the T1 fixture, `HL_A36_CORE_AHEAD=1`, one request, `check-serve` | `247a578e4684` | the request was proved and the receipt `checked` by `check-serve` at the real shape (`raw/g4_smoke_on*`); a correctness check, no timing is read from it or reported |

**New binary.** `ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify`, SHA-256 `97cc002bee86794e35055fb063f73367a450c96d9c4896578c6b8e42871e3ea0`.

**What T1 and S1 still stand on.** T1 and S1 were measured on the binary of commit `3879c471` (SHA-256 `d3eae116...0e37`) and were not re-run; this change moves one OS seed read from after stage IN-C to before the header and touches nothing inside the block loop.

## 13. T2: the stream test (2026-11-21 12:08 to 12:49 UTC)

Defined in the coordination entry of 2026-11-21T12:03:21Z (statistic, sets, rule and verification fixed there; nothing changed). Binary: this branch at `0368a718`, release `zk60_classify` with gpu-metal, SHA-256 `97cc002bee86794e35055fb063f73367a450c96d9c4896578c6b8e42871e3ea0` (verified before the run, not rebuilt). One binary for every leg; `HL_A36_CORE_AHEAD` is the only difference between legs. Labels: MEASURED (`raw/t2_setA/`, `raw/t2_setB/`, `raw/t2_summary.txt`, the guard records); every number below is `t2_summary.py`'s output.

**Commands.** Each set is one guarded detached gpu job (`t2_launch.py` starts `guarded.py` in its own session; marker `raw/<label>.done` holds the exit code; need 125 GiB, cap 200 GiB): set A `t2_launch.py t2_setA 6 5 0,1,1,0 48 125 200 6000`, guard run `f7269da6e7d6`, exit 0, 1126 s; set B (started after set A's marker) `t2_launch.py t2_setB 8 4 0,1,1,0 48 125 200 6000`, guard run `ed230e599c45`, exit 0, 1116 s. The smoke (switch off, 6 x 5, N + 6 requests; guard `dc7929810bb1`, exit 0; it showed all six lanes taking a request in the first 1.5 s and again at the end of the first wave, one receipt checked by `check-serve` and deleted; no rate is reported from it) preceded them. A leg is a fresh `zk60_classify serve --export <a29-uniform-calibration/export_u1> --tables <export_u1>/token_io --policies <the three shieldstral moderate policies> --label zk60-classify-verdict --lanes L --lane-threads T --witness-cache-gib 16 --dev-w16r2-public-content-only` with the T1 environment (`HL_METAL_QUEUES=thread HL_METAL_SPIN_US=200 HL_A28_STAGGER_MS=300 HL_A26_KEPT=1 HL_A30_B3PAR=1 HL_A26_VERIFY_ONCE=0 HL_A28_SEAL_AHEAD=0`) and `HL_A36_CORE_AHEAD` = 0, 1, 1, 0 in the legs' order. N + 48 requests (N = L): the eight public posts of `stream8.json` in rotation, category sexual, chunk 0 (activations from Astra's writer client on `export_u1`, my own process, closed before any server), all written to the server's stdin at once (the way the A28 stream driver feeds a server) so each lane always has a request waiting; the first N completions are warm-up. Completion times are `time.monotonic` at the driver when a `served` line is read. Verification: every on-leg receipt (54 at six lanes, 56 at eight) by the binary's own `check-serve` (3 lanes x 4 threads, `--expect-statement` the prover's identity, `--min-bits 95`) after the leg, each receipt deleted after its check; off legs deleted unverified (said here as the entry asks). Rate = 48 x 128 / (c[N+48] - c[N]) padded tokens per second.

**Set A (6 lanes x 5 threads, the test of record):**

| leg | A36 | rate, tok/s | mean prove call, s | median prove call, s | same-lane rate, tok/s | receipts verified | GPU util mean (ioreg, diagnostic) |
|---|---|---|---|---|---|---|---|
| 1 | off | 43.871 | 14.290 | 14.255 | 44.156 | not verified | 87.4 % |
| 2 | on | 37.975 | 16.782 | 16.773 | 38.232 | 54 of 54 checked, 0 failed | 89.9 % |
| 3 | on | 38.884 | 16.308 | 16.409 | 39.134 | 54 of 54 checked, 0 failed | 88.9 % |
| 4 | off | 42.996 | 14.650 | 14.784 | 43.193 | not verified | 85.4 % |

Gains: pair (leg 1, leg 2) 37.975 / 43.871 - 1 = **-13.44 %**; pair (leg 4, leg 3) 38.884 / 42.996 - 1 = **-9.57 %**. **Verdict by the rule: KILL at 6 lanes** (a gain under 3 % in either pair).

**Set B (8 lanes x 4 threads):**

| leg | A36 | rate, tok/s | mean prove call, s | median prove call, s | same-lane rate, tok/s | receipts verified | GPU util mean |
|---|---|---|---|---|---|---|---|
| 1 | off | 44.112 | 19.215 | 19.472 | 44.328 | not verified | 88.6 % |
| 2 | on | 43.376 | 19.481 | 18.756 | 43.419 | 56 of 56 checked, 0 failed | 90.0 % |
| 3 | on | 42.820 | 19.564 | 19.745 | 43.139 | 56 of 56 checked, 0 failed | 90.1 % |
| 4 | off | 46.387 | 18.098 | 18.005 | 46.621 | not verified | 90.3 % |

Gains: pair (leg 1, leg 2) **-1.67 %**; pair (leg 4, leg 3) **-7.69 %**. **Verdict by the rule: KILL at 8 lanes.**

All 440 requests (the warm-ups included) were `proved`; every on-leg receipt (220 of 220) was accepted by `check-serve`; no verification failed, so the correctness half of the rule holds and the kill is on speed alone.

**What disturbed a leg.** Nothing observed: `pgrep ds4-bench` empty before and after every leg; the guard showed the heavy lock free at each launch; free disk 163 to 166 GB before every leg (limit 80); no failed request; no guard stop. Peak memory (guard, whole job): set A 65.0 GiB RSS, 29.8 GiB VRAM; set B 83.3 GiB RSS, 38.4 GiB VRAM (the smoke: 57.8 GiB, 18.6 GiB). The legs of a pair differ by up to 2.0 % between the two off legs of set A and 5.2 % between the two off legs of set B, the noise level against which the gains must be read; the on legs are lower in all four pairs.

**NOT measured.** The GPU busy share (the ioreg mean above is a 2 s diagnostic sample over the prover's stream; the rule's busy-share half needs Astra's capture); Astra's driver and her 38.19 / 43.79 (a different driver; this lane's own off and on legs only are compared); the shared Metal queue (these legs use per-thread queues, `HL_METAL_QUEUES=thread`); private content (all requests are public); any category other than sexual or any chunk other than 0; the same-lane statistic is computed from the `lane` field of the `served` lines and is not part of the rule; why the on legs are slower at six lanes (not investigated: the first-half work moved to a pool worker competes for the lane's five threads and the memory system while the device is already the bottleneck is a hypothesis, not a finding).
Files: `t2_driver.py`, `t2_launch.py`, `t2_summary.py`, `raw/t2_setA/`, `raw/t2_setB/`, `raw/t2_smoke/`, `raw/t2_summary.txt`, `raw/t2_set*.guard.json`.
