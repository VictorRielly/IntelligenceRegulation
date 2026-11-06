# A19: A13's window from production's D55 path (2026-11-05)

The plan: `docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A19. Byte-preserving. It follows A18
(`../a18/README.md`, §6 "What is left", first bullet) on perf `3577a374` (A18 merged).

Labels: [MEASURED] a number from a log in this directory; [CODE] read from the source; [INFERRED] derived from measured
numbers; [ESTIMATE] a judgement, not a measurement.

All timing runs: W16R2 8B T128, 32 blocks, N = 6 fork workers, `HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0`, the
witness budget the Mac's default (32 GiB) unless named, on the shared M3 Ultra. Every stage was one guarded job (the
shared heavy lock). Every timing stage waited for a quiet GPU (no `ds4-bench`) and recorded that none ran at its end
(`s2.progress`, `s3.progress`). No clock below was taken beside one. The model is the D55 harness's synthetic block
(diagonal public weights at the 8B geometry), as in A3–A18; there is no trained 8B export on the Mac.

## 1. Plain summary

- **Production's D55 path can now make each fork's before-challenge part during its sealing pass.** `stack-prove
  --d55-workers` runs a new function, `d55_seal_and_prove`. It makes the parts from a `ForkPlan` (built from the run
  shape before the statement exists) against the sealing pass's own block objects. The window stays **off by
  default** (`HL_D55_AHEAD` unset or 0).
- **Why it stays off** [MEASURED, through production's function, 6 passes, both orders, quiet GPU]:
  - window 16: one request from its input **−0.4%** (15.29 → 15.22 s). The prove call is −4.0% and its forks phase
    −5.1%, but the sealing pass is +0.9% and sys CPU +15.5%. Peak footprint 43–52 → 53–56 GiB;
  - window 16 with loads that only copy the block (the harness's lighter sealing pass): one request **−1.0%**;
  - window 32 with the budget raised to 64 GiB: one request **−1.0%** (6 of 6 pairs, but inside the ±2% noise floor),
    prove call −9.4%, sys CPU +34%, peak footprint 73–77 GiB;
  - by the kill rule (one request beyond ±2% in most pairs, no metric regressing, footprint within the guard), no
    window qualifies. Production has no stream form, and the stream is where A18 measured its +5.0%.
- **A separate production win, on by default: the fork run proves with the sealing pass's own blocks**
  (`HL_A19_SHARE`; `0` restores the second load) [MEASURED, 6 passes, 6 of 6 pairs]. One request from its input
  **−20.7%** (19.26 → 15.28 s): the second load of all 32 blocks took 4.15 s. Byte-preserving: each block is the
  sealing pass's fully checked load, and its digest is the statement's. The real export's reload also reads and pads
  files, so in production the saving is at least this [INFERRED].
- **What production's request really costs** [MEASURED, this model]: one request is about 15.3 s, not the harness's
  5.4 s:
  - its sealing pass is 9.1 s. Each layer's load (a block copy and the layer record's hashes, which production's load
    also makes) slows the witness build beside it about 5× (8.1 s of builds; 1.7 s with copy-only loads);
  - writing the 818 MB receipt takes about 1.9 s;
  - the preflight re-hashes 32 distinct blocks (0.30 s; the harness's single block 0.08 s).
  These, not the forks phase, are production's next levers (§9).
- **No byte moves** (§3), on the CPU and on Metal:
  - through the planned path at the W16R2 rung and through `stack-prove` / `stack-verify` themselves at the R13 rung
    (the registered D55 profile). With seeded generators, every receipt verifies in a fresh verifier, its head is the
    replayed commit phase's, and every interior fork equals that fork proved whole. This holds at windows 0–9, with the
    blocks shared and reloaded;
  - every receipt of every A/B call was 818,728,672 B.
- **H-1 holds** (§6). Every refusal of an inadmissible chain is still the sealing pass's, with the same string, before
  anything exists. A chain refused partway through drops every part it made: tested on the planned path and through
  `stack-prove`, at windows 0, 1 and L.
- **Acceptance on the final tree** (§5).

## 2. The cause, and what changed

### 2.1 The cause [CODE]

A13's window had two entry points, `seal_ahead` and `prove_run_with_forks_sealing`. Both take a `ForkRun`, which borrows
the run statement. Production's D55 path can build that statement only after the whole sealing pass, because its
endpoints are the sealed chain's first and last planes. The path then:
1. built the `ForkRun`;
2. created the run directory;
3. loaded every block a second time (`load_fork_blocks`);
4. called `prove_run_with_forks`.

So no part could be made before the statement existed. A parked part also needs its block to be the very object its
fork finishes with, and the second load never gave it that.

A part needs none of the statement:
- **its stage's shape:** the shape the sealing pass built its witness at (the layer record's `shape_at`);
- **its stage's layout:** `Layout::for_shape` of that shape, with the two IO tabs at the reserved pairs the run's
  schedule gives them. These rows depend on the run shape alone (`RunStatement::in_site` / `out_site`, through
  `BoundarySpec::mask_row`);
- **its generator's domain:** the D55 profile string, a function of the base run profile;
- **its block:** the object the fork proves with.

### 2.2 `run_fork.rs` (the `[A19]` section after A13's)

- **`fork_profile`:** `ForkRun::new`'s profile derivation, moved out unchanged (the same checks in the same order, so
  the same refusals). `ForkRun::new` and `ForkPlan::for_run` both call it.
- **`ForkPlan::for_run(run shape, context, opt-in)`:** the D55 profile, the block count, the NTT domain and each
  stage's `[in, out]` IO rows. The rows come from the same `BoundarySpec` construction `RunStatement::boundary_spec`
  makes. A boundary's rows depend on its geometry only, and production pins every boundary scale to 0.
- **`SealedBlocks`:** a fixed vector of `OnceLock<BlockPublic>`. Each block is set once by the sealing pass and then
  read, at a stable address, by the parts and the forks. It is a `ForkBlocks`.
- **`prove_run_with_forks_planned(plan, blocks, seal, then)`:** production's one request, in one scope:
  - the side workers start;
  - the caller's sealing pass hands each admitted witness over with its shape (`plan_hand_over`: inside the window it
    is queued; outside it, it is handed back);
  - the continuation `then` receives the sealing pass's result and a `Planned`. With no plan, or window 0, it is
    `seal` then `then`, with no side worker;
  - a refusal anywhere stops the side workers and drops the slots before the function returns.
- **`Planned::check(&ForkRun)`:** before the caller creates anything, it compares the plan's profile, block count, NTT
  domain and every stage's IO rows with the fork run's, and every stage shape handed over with the statement's
  `stage_shape`. **`Planned::prove`** checks again, refuses another blocks object once any witness was handed over,
  and runs `prove_forks_inner` with the slots.
- **`ForkCtx`:** it takes each fork's stage and generator domain from `Stages::Run` (the fork run) or `Stages::Plan`
  (the plan and the handed shapes). `ForkLate` now carries the fork run.
- **`ForkCtx::finish`:** a part made during the sealing pass is held against its fork's own stage
  (`ForkRun::is_the_stage`: the shape, and the layout's two IO rows) before `prove_core_after_with`. That function
  still refuses another block object, shape or layout.
- **Test builds only:** `ForkHooks.parts` and `A19Count` / `A19Counting` (a per-test count of parts made and still
  alive, carried into the side workers), and `ForkPlan::with_profile_for_test` / `with_rows_swapped_for_test`.

### 2.3 `trained_block.rs` (the D55 production path; D12a's behaviour unchanged)

- **The sealing pass is `seal_chain`**, R5b's body unchanged, over a `StackModel`. The model is production's
  `ExportStack` (the export, the run's private sequence, its run constants and shape) or, in tests, a synthetic stack.
  - After every check of block `k` (the builder's refusals, CS-3's lookup misses, the parity check), it offers the
    block and the witness to a `SealHand`.
  - `NoHand` (D12a) drops the block and hands the witness back, so D12a's sealing pass is the old one.
  - `D55Hand` keeps the block in `SealedBlocks` (when shared) and offers the witness to the window.
  - `seal_and_record` (D12a's entry) is `ExportStack::new`, then `seal_chain(NoHand)`, then the statement, as before.
- **The witness budget counts each part.** A witness is offered to the window only if the budget holds it as a part:
  its witness bytes plus `A`'s host rows and their encoding, `8 · a_rows · n · (1 + inv_rate)`, an estimate of the host
  and device bytes. Otherwise the old keep-or-rebuild rule applies. At 8B T128 that is about 1.28 GB a part: window 16
  budgets 20.5 GB of parts plus 4.7 GB of kept witnesses inside the 32 GiB default [MEASURED].
- **`stack-prove --d55-workers N` runs `stack_prove_d55`.** This is `d55_seal_and_prove` (measured in §4), then the D55
  tail (in-process verification or the unverified statement beside the run, and the `proved` event).
  `d55_seal_and_prove` does, in the old order with the old refusals:
  1. the plan (none when the window is 0 or the blocks are not shared, or if the run shape or context cannot be made:
     that run proves without a window and meets the same refusal where it always did);
  2. the sealing pass;
  3. the model's statement and the `loaded` / `sealed` / `parity` events;
  4. the endpoints and the bound statement;
  5. D60's door (`ForkRun::new`) and the `d55` event;
  6. **`Planned::check`** (new, before anything exists);
  7. the run directory;
  8. the blocks (shared, or `load_fork_blocks_of` when `HL_A19_SHARE=0`);
  9. `Planned::prove`, the frames, D60 F3's marker and the `d55-proved` event.

  A failure after the directory exists removes it (`fail_run`), as before. The D12a body of `stack_prove_inner` lost
  its now-unreachable D55 branches.
- **`StackSource`** takes its rebuilds' blocks from `StackBlocks`: D12a's one-block cache (unchanged), the sealed
  blocks, or the model's checked reload.
- **`HL_A19_SHARE`** (default on; `0` restores the second load, and the window then stays off).
- **Events:** `sealed` (D55 only) gains `d55_window`, `d55_parts`, `d55_part_bytes` and `d55_shared_blocks`;
  `d55-proved` gains `ahead_parked` and `ahead_taken_back`. These are prover-private stdout (P-6) and public values.
- **Test builds only:** `stack_prove_inner_for_tests`, a hook after the sealing pass and one after the fork run's
  proof (`a19_sealed_hook_for_tests`, `a19_proved_hook_for_tests`), and `set_a19_share_for_test`.

### 2.4 Tests (`run_fork_tests.rs`, the `[A19]` block at the end; `w16r2_tests.rs` unchanged)

- `a19_planned_parts_equal_whole_forks_and_every_control_refuses_at_the_w16r2_rung` (suite) and `…_on_the_device`
  (ignored).
- `a19_production_d55_path_window_on_and_off_and_a_refused_chain_at_the_r13_rung` (suite) and `…_on_the_device`
  (ignored).
- `a19_production_d55_ab` (ignored): the A/B through `d55_seal_and_prove` on the synthetic stack, with the
  `A19Synth` model.
- **Helpers outside the block:** `write_r13_multi_layer_export` (the D60 F2 export writer, moved out of its tooling
  test, with an optional flipped `x_out`) and a process-wide `a19_knobs()` lock that A18's `a18_check_paths` now also
  takes. The window's switches are the process's, so the suite's tests that set them run one at a time.

## 3. The byte evidence [MEASURED]

**Why no byte can move** [CODE]:
- A13's argument still holds: every fork is the same calls on the same inputs in the same order. Its one generator is
  built in `ForkCtx::prove_one` under its per-`k` domain and moved by value with its parked fork.
- A19 adds one equality: a part made from the plan is the part the fork run's own stage would have made.
  - its shape, layout rows and generator domain are the fork run's (`Planned::check`, and `is_the_stage` again at the
    finish);
  - every other input is the same object: the witness the sealing pass built, and the block it built it against;
  - the NTT tables are made from the same log.
- The shared blocks are the sealing pass's own loads, whose digests are the statement's (the record's digest is the
  statement's entry; the preflight re-hashes every block, CS-6). The reload (`HL_A19_SHARE=0`) refused any block whose
  digest was not the statement's.

**The planned path at the W16R2 rung** (`s1.progress`). Its first run failed one control: stage 0's two reserved
pairs are the same row, so swapping them moved nothing; the control now swaps stage 1's. `s1`'s later steps rebuilt
with that fix and passed it, in the fork-run suite on the CPU and in the device test:
- seeded generators, the statement made only in the continuation (production's order), L = 4;
- CPU: N = 1 and 3 at windows 0, 1, 2, 4 and 9. Metal: N = 1, 3 and 6 at windows 0, 2 and 4;
- every receipt verifies at 61,301,184 B. The parts handed over are `min(window, L)`, split between parked and taken
  back whole. The head equals the replayed commit phase, and both interior forks equal those forks proved whole.
  On Metal at window 4 all four forks parked, so both interior comparisons are parked forks.

**Production's path at the R13 rung** (`stack-prove --d55-workers N --d55-test-receipt-not-for-publication` on a
4-layer R13 export written from the `r13-h24-wide` fixture, the registered D55 profile, seeded generators):
- CPU: (window 0, N 2, shared), (0, 2, reloaded), (2, 2), (4, 1), (4, 3). Metal: (0, 3, shared), (0, 3, reloaded),
  (2, 3), (4, 2), (4, 6);
- each receipt verifies in a fresh `stack-verify --d55-workers`;
- inside the run, through the after-proof hook: its head is the replayed commit phase. Both interior forks equal those
  forks proved whole on the run's own statement, against the blocks it proved with and witnesses rebuilt from the
  export's sequence;
- forks parked plus taken back equal the window (0 when reloaded), and L + 1 generators. Every part made was dropped
  by the end of its run.

**Every A/B call** (§4): 148 calls, each receipt 818,728,672 B. The cold call and each arm's first pass were verified
from the run directory (12 receipts).

**Suite and audits on the work-in-progress tree** (`s1.progress`):
- the D55 fork-run suite: 28 passed. This includes D60 F3's CLI test through the new `stack-prove` path, the tamper
  families, A17's turncoat and A18's and A19's suite tests;
- the trained-stack CLI tests: 5 passed, and the one known failure;
- A18's parked-forks tests on the CPU and on Metal.

## 4. The A/Bs through production's path [MEASURED]

`a19_production_d55_ab`: `trained_block::d55_seal_and_prove`, the function `stack-prove --d55-workers` runs, on the
synthetic 32-block stack. One request per call, from its input:
- the sealing pass from the first layer's load (each load a distinct copy of the block, its layer record hashed as
  production's load hashes it; production also reads and hashes the export's files, so this load is a lower bound);
- then the statement, the fork run, the run directory and the 818 MB receipt written into it.

Method: 6 passes after one cold call, the arm order reversed in odd passes (`HL_D55_AB_ALTERNATE=1`). The tables come
from `../a11/pairs.py --alternate --n 6`, `../a15/seal_pairs.py` and `prod_table.py`. "sealed wall" is the request;
"proof wall" is its prove call; "forks phase" is the prove call's forks. Cells read "mean change (pairs, pairs
favouring the test arm)".

### 4.1 The window, window 16 (stage 2a; `s2a_pairs.md`, `s2a_seal.md`)

| metric | base first | test first | order bias solved out | means, no window / window 16 |
|---|---|---|---|---|
| **one request from its input** | −0.7% (3, 2) | −0.1% (3, 2) | **−0.4%** | 15.287 / 15.224 s |
| its prove call | −4.7% (3, 3) | −3.4% (3, 2) | −4.0% | 4.158 / 3.988 s |
| its forks phase | −5.6% (3, 3) | −4.6% (3, 3) | −5.1% | 3.581 / 3.394 s |
| its sealing pass | +0.9% (3, 0) | +0.9% (3, 0) | +0.9% | 9.114 / 9.198 s |
| sealing pass user / sys CPU | | | +11.7% / +24.7% | |
| request user / sys CPU | | | +0.3% / +15.5% | |
| minor faults | | | +11.0% | |
| peak footprint | | | | 43.1–51.5 / 52.9–56.1 GiB |

### 4.2 The window with copy-only loads (stage 2c; `s2c_*`; `HL_A19_SYNTH_LOAD=copy`)

The harness's lighter sealing pass, which joins these numbers to A18's.

| metric | order bias solved out | means, no window / window 16 |
|---|---|---|
| **one request from its input** | **−1.0%** (base first −0.4% (3, 2), test first −1.6% (3, 3)) | 8.552 / 8.465 s |
| its prove call | −4.8% (6 of 6) | 4.188 / 3.986 s |
| its forks phase | −5.9% (6 of 6) | 3.594 / 3.383 s |
| its sealing pass | +4.3% (0 of 6 lower) | 2.357 / 2.457 s |
| request sys CPU | +18.9% | |
| peak footprint | | 43.0–51.3 / 53.0–56.1 GiB |

### 4.3 The whole window, window 32, budget 64 GiB (stage 3; `s3_*`)

Production's long sealing pass leaves the side workers slack, so the whole window was tried instead of window 8 (which
the plan names only if 16 wins). At the default 32 GiB budget, about 26 parts fit.

| metric | order bias solved out | means, no window / window 32 |
|---|---|---|
| **one request from its input** | **−1.0%** (base first −1.1% (3, 3), test first −0.9% (3, 2)) | 15.274 / 15.125 s |
| its prove call | −9.4% (6 of 6) | 4.202 / 3.806 s |
| its forks phase | −10.9% (6 of 6) | 3.615 / 3.220 s |
| its sealing pass | +2.3% (0 of 6 lower) | 9.066 / 9.277 s |
| sealing pass user / sys CPU | +24.0% / +58.5% | |
| request sys CPU, minor faults | +33.9%, +28.0% | |
| peak footprint | | 43.0–66.7 / 73.4–76.7 GiB |

### 4.4 The blocks: shared against loaded again, window 0 (stage 2b; `s2b_*`)

| metric | base first | test first | order bias solved out | means, reloaded / shared |
|---|---|---|---|---|
| **one request from its input** | −20.7% (3, 3) | −20.6% (3, 3) | **−20.7%** | 19.259 / 15.277 s |
| the fork blocks' second load | | | | 4.149 / 0 s |
| its prove call | −0.6% (3, 1) | −1.0% (3, 3) | −0.8% | 4.168 / 4.134 s |
| its sealing pass | +2.0% (3, 0) | +2.0% (3, 0) | +2.0% | 8.940 / 9.120 s |
| request user / sys CPU | | | −4.8% / +7.8% | |
| peak footprint | | | | 42.9–43.5 / 42.9–43.4 GiB |

The shared blocks stay resident through the sealing pass, which the reload's blocks never were. The peak, in the fork
run, is unchanged. The sealing pass's +2.0% (6 of 6) is probably the cost of keeping all 32 blocks resident beside
the builds [INFERRED]; the request still gains 4.0 s.

### 4.5 Where production's request goes (`prod_table.py` over the four logs; means of 6 passes)

| arm | one request | sealing pass (loads beside it / witness builds) | prove call (forks) | directory to receipt written |
|---|---:|---|---|---:|
| no window, hashing loads | 15.29 s | 9.11 s (8.36 / 8.13) | 4.16 s (3.58) | 6.11 s |
| no window, copy loads | 8.55 s | 2.36 s (0.44 / 1.68) | 4.19 s (3.59) | 6.13 s |
| reloaded blocks, hashing loads | 19.26 s | 8.94 s | 4.17 s, plus 4.15 s of reload | 10.30 s |

- The load's record hashing beside each build slows the build about 5× (8.1 s against 1.7 s for 32 builds), so the
  sealing pass is load-bound [MEASURED].
- Writing the receipt takes about 1.9 s (directory to receipt written, less the prove call).
- The preflight is 0.30 s against the harness's 0.08 s: 32 distinct blocks to re-hash instead of one cached digest.

## 5. Acceptance on the final tree [MEASURED]

(Stage 9: `s9.sh`, which is `check_a18merge.sh`'s whole list pointed at this worktree plus A19's tests, a non-test
library build and production's path on the default; `s9.progress`.)

One guarded job, 05:11–05:34 UTC, the GPU quiet at both clocks.

- **Builds:** the test binary rc 0. The no-feature `cargo check --tests` rc 0. The production (non-test) library build
  rc 0; its one new warning in this lane's files (`prove_run_with_forks` unused outside the tests, since production
  reaches the prover through `Planned::prove`) now carries a dead-code attribute (stage 10).
- **The full lib suite** (`--test-threads=8`, the R13 loader fixtures; `raw/s9_full.log`): 940 passed, **4 failed**,
  116 ignored. Three failures are the known ones:
  - `review_tests::a_toy_receipt_made_before_f12_is_refused`;
  - `trained_block::accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces`;
  - `trained_stack_tests::review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`.

  The fourth was R6's source audit `r6_tests::the_sealing_pass_lookup_miss_check_refuses_by_the_cs3_name`, which read
  the CS-3 check in the text of `fn seal_and_record(`. That body is now `seal_chain`, so the audit now reads it there
  and checks that both entries run it (§10). **Stage 10** (`s10.sh`) reruns the build, the no-feature check, the
  full suite, R6's audit by name and the non-test build on the final tree. At hand-back it was **queued on the heavy
  lock and had not run**: the final tree's suite result is NOT yet recorded here (`s10.progress` will hold it).
- **zkp-core's lib tests:** 81 passed, 2 ignored.
- **A19's device tests:** the planned path and its controls, and production's path (window off and on, blocks shared
  and reloaded, the refused chain). Both pass.
- **Every earlier lane's byte test passes:**
  - A18: the rung golden under every setting (CPU and Metal, three entries); the 8B block `90003b760eb7ad80` in every
    proof; the parked forks on the device;
  - A16: the 8B witness planes `5808a1cd` in every form, CPU and device products;
  - A17: the rung golden and the 8B block;
  - A15: the 8B chain in every pool;
  - A14: the 8B private tables, the rung golden and the 8B block;
  - A8's rung test; A12's census and rung modes; A11's pool tests (CPU and Metal); A7's queue test.
- **The W16R2 rung golden** (`HL_GPU_REQUIRED=1`): CPU = Metal = `96e4f0b6f34f7876…`.
- **The six post-F12 trained digests:** 5a6193d3, f590b01f, 79f987ef, a8258241, 0e88d84f and 90003b76 are all
  present. **The 8B core proof `90003b760eb7ad80`** is present.
- **The D55 harness on the default** (window off; `s9_d55.log`; another process at another time from A18's
  acceptance, so for reference only):

| W16R2 8B T128, 32 blocks, N = 6 | this run | A18's acceptance |
|---|---:|---:|
| proof only, best | 4.006 s = 31.95 tok/s | 3.844 s = 33.30 |
| one request from its input, best | 5.577 s = 22.95 tok/s | 5.454 s = 23.47 |
| stream of 4, steady / amortized | 32.63 / 28.92 tok/s | 33.38 / 29.44 |
| serial D12a, best | 9.333 s | 9.154 s |

  The harness's proof-only path changed only in where `prove_one` reads its stage (the same statement calls through
  `Stages::Run`). The 2–4% between the two processes, D12a's serial run included, is the run-to-run variance on the
  shared Mac seen before (A15's note) [INFERRED].
- **Production's path on the default** (window off, blocks shared; `s9_prod.log`): one request 15.452 s best =
  8.28 tok/s, 15.572 s mean (stage 2's 15.29 s mean is the same arm in another process).
- **Receipts:** every receipt verified: 818,728,672 B for the fork run and 818,728,480 B for D12a. The four stream
  receipts verified after the clock in 9.6 s; production's cold call and first pass verified from their run
  directories.

## 6. The default decision

- **The window stays OFF by default** (`HL_D55_AHEAD` unset or 0). Through production's own function, one request
  moves −0.4% at window 16, −1.0% at window 16 with the lighter loads, and −1.0% at window 32 with a doubled budget.
  None clears the ±2% noise floor of these A/Bs. Each costs sys CPU (+15–34%) and peak footprint (+10 to +30 GiB).
  - The parts take 4–9% off the prove call. But production's request is dominated by its sealing pass (9.1 s) and its
    receipt write, and the side workers' CPU lengthens the sealing pass by about as much as they save [INFERRED].
  - A stream is where A18 measured +5.0% (the sealing side then had slack beside the previous request's forks), and
    production has no stream form.
  - With the window off, nothing is handed to a window, no side worker starts, and no byte, path or wording of the fork
    run changes. Production's path at window 0 is the planned path with no plan: `seal_chain`, then the continuation.
- **The shared blocks are ON by default** (`HL_A19_SHARE` unset). One request −20.7% in every pair, the peak
  unchanged, no byte moved. `0` restores the second load.

## 7. H-1 (ruling D29) with the window on: the argument

**The claim.** With `HL_D55_AHEAD > 0`, every refusal of an inadmissible chain still happens in the sealing pass (or
in the statement checks after it), before the run header exists and before anything of the run is created. A chain
refused at any point drops every part made for it before `stack-prove` returns.

1. **The refusals and their order are the old ones** [CODE]. The sealing pass is `seal_chain`, R5b's body unchanged,
   in the same order:
   - the model's checked load (CS-1/CS-4 at the trained door);
   - the witness builder's refusals;
   - CS-3's lookup-miss check on the sealed witness;
   - the parity check;
   - the first-plane check;
   - the model's statement.

   Then come, as before: the context, `IoSpec`, the endpoints, the bound statement (CS-6/CS-7, the model statement's
   checks) and D60's door. The strings are unchanged. The plan is made before the sealing pass but cannot refuse: a
   plan that cannot be made is no plan, so the run proves without a window and meets the same refusal, if any, at its
   old place (the profile derivation is `ForkRun::new`'s own). Tested: a chain whose layer 1 fails parity is refused
   with window 0's string at windows 0, 1 and L, through `stack-prove`.
2. **One new check, `Planned::check`, cannot be provoked by input.** It runs after D60's door and before the run
   directory. It compares two derivations of public words: the plan from the run shape against the statement, and the
   handed stage shapes against `stage_shape`. The handed shape is the shape the witness was built at, which must
   already equal the stage's shape for a run to verify. A mismatch would mean the two derivations drifted in the
   build, and it is refused before anything exists.
3. **A part is made only from an admitted witness, and nothing of it leaves the process before the header** [CODE].
   - The hand-over sits after every check of that block, at the point where the witness was kept before.
   - A part reads no transcript and absorbs nothing. It draws only from its fork's own generator, built in
     `prove_one` under its per-`k` domain (`from_os`; s25's census holds: two `from_os` sites in `run_fork.rs`). It
     commits `A` and `M` in memory.
   - Its frame is written only by the fork run, after its rest, under the run header, into the run directory, which
     exists only after every check above.
4. **A refused chain drops its parts** [CODE, tested].
   - The refusal returns from the sealing closure, or from the continuation before the proof. The slots are marked
     stopped; the side workers start nothing new and stop after any part in progress. The scope joins them, and the
     slots, with every parked part, queued witness, generator and opening, are dropped before
     `prove_run_with_forks_planned` returns.
   - The run directory is created only in the continuation, after the statement and both checks, so a refused chain
     never creates one. No new output is printed.
   - Tested on the planned path: two parts made, then the pass refuses. The refusal comes back verbatim, the
     continuation never runs, and 0 parts are alive.
   - Tested through `stack-prove` at windows 0, 1 and L: nothing created, 0 parts alive.
5. **A part's own refusals are prove_core's, at the same fork, under the same conditions.** These are CS-8, CS-1/CS-4
   (a part has no preflight record, so it checks its block itself), the witness shape, CS-3 and DD. An admitted
   witness cannot meet them, because the sealing pass made the same checks. If one did, it would be that fork's error
   in the forks phase (`Slot::Failed`), exactly where it would be without the window. The window adds no refusal after
   the header and moves none later.
6. **The window's schedule reads no hidden value.** Whether a witness is handed over depends on `k`, the window and
   the budget. The budget's terms are witness and `A` sizes, which are functions of the shape. The sealing pass's
   running time was already input-dependent (which layer refuses), and the parts change only how much CPU runs beside
   it.

## 8. For the privacy gate

- **Production digests that moved:**
  - `private_block/run_fork.rs` (a source pin of the D55 capture): `fork_profile`, `ForkCtx::stages`,
    `ForkLate::fr`, `ForkRun::is_the_stage`, and the `[A19]` section (`ForkPlan`, `SealedBlocks`, `Planned`,
    `plan_hand_over`, `prove_run_with_forks_planned`);
  - `private_block/trained_block.rs`: the sealing pass as `seal_chain` over a `StackModel`, `d55_seal_and_prove`,
    `stack_prove_d55`, `StackBlocks` and `HL_A19_SHARE`.

  `protocol.rs`, `argument*.rs`, `witness*.rs`, `run.rs`, `gpu/*` and zkp-core are unchanged.
- **No new path whose time depends on a hidden value** (§7.6). The plan holds public words. `SealedBlocks` holds public
  blocks. A parked part holds what A13's part held: the witness, the commitments' openings and the generator. It is
  dropped like A13's.
- **W-8(5)'s wording, if the window is ever turned on:** "built in its worker" becomes "built by the thread that starts
  the fork's proof (a side worker during the sealing pass), moved with the parked fork". This is A13's note, now
  reachable from production when `HL_D55_AHEAD > 0`. There is one generator per fork and `L + 1` per run. Off by
  default, it moves nothing.
- **The shared blocks** change which object the fork run reads: the sealing pass's load (every array SHA-256-checked)
  instead of a reload (hashes skipped, digest compared). The bytes are the same. The preflight still re-hashes every
  block against the statement (CS-6).
- **Printed:** the `sealed` and `d55-proved` events gain public counts (§2.3), on prover-private stdout. No new module,
  generator, absorb label or byte-string literal is on the block path; the s24, s25, `hash_domain` and C-H4' audits
  pass in the suite.
- `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

## 9. What is left

- **Production's sealing pass is load-bound** [MEASURED, this model]. Each layer's load hashes the layer record (the
  nine padded-word SHA-256s and the block digest of `LayerRecord::of_block`) beside the witness build, and the builds
  slow about 5×: 9.1 s per 32-layer request against 2.4 s with copy-only loads. The real load also reads and hashes the
  export's files and pads them. Candidates:
  - the record kept per manifest digest for a resident model (the digest pass made once, not per request);
  - the load's hashing on a pool that does not contend with the builder (A15's lesson);
  - a two-wide load.
  These live in `trained_statement.rs` and in `trained_block.rs`'s loader, outside A19's lane.
- **The receipt write** (about 1.9 s for 818 MB) is on the request's clock. It could overlap the join or stream frames
  as forks finish.
- **The preflight's CS-6 re-hash of 32 distinct blocks** (0.30 s). `SealedBlocks` could carry the sealing pass's own
  digest for each block it set (the same object, digested once). That would need a ruling, since CS-6 then rests on
  the sealing pass's hash.
- **A stream form of production** (several requests per process). That is where the window measured +5.0% (A18).
  There is none today; a server form would be the place to turn the window on, re-measured there.
- **The fork path's short parallel regions run sequentially** (A18 §6, second bullet). Not tried: those regions are in
  `protocol.rs` and `accuracy_act.rs`, outside this lane's files.
- **Not measured:** a trained 8B export (none is on the Mac; the synthetic block is the model), and any machine but
  this one.

## 10. Merge-conflict risks against perf

- **`trained_block.rs`:** `seal_and_record`'s body moved into `seal_chain`, a lane editing the sealing pass (A16's
  builder calls, A15's pool) must make its change there. `stack_prove_inner` lost its D55 branches, which moved into
  `stack_prove_d55` / `d55_seal_and_prove`, so a lane editing the D55 CLI path needs a hand merge. `StackSource::new`
  takes a `StackBlocks`.
- **`run_fork.rs`:** `ForkCtx` lost `fr` (now `stages`); `ForkLate` gained `fr`. A lane building a `ForkCtx` (tests
  included) must use the new fields. `ForkRun::new`'s derivation moved into `fork_profile`.
- **`run_fork_tests.rs`:** the `[A19]` block is appended. A18's `ForkCtx` literals were updated, and
  `a18_check_paths` takes the new `a19_knobs()` lock. The D60 F2 writer is now `write_r13_multi_layer_export`.
- **`r6_tests.rs` (outside this lane's declared files, one test):** R6's source audit
  `the_sealing_pass_lookup_miss_check_refuses_by_the_cs3_name` read the CS-3 check in the text of
  `fn seal_and_record(`. That body is now `seal_chain`, so the audit now reads `seal_chain` and checks that D12a's
  `seal_and_record` and the D55 path's `d55_seal_and_prove` both run it (stage 9 found it; stage 10 is the suite
  after the change).
- `protocol.rs` and `w16r2_tests.rs` are untouched.

## 11. This directory

- **Stage scripts:**
  - `b.sh` (a compile check);
  - `s1.sh` (the byte evidence and suites on the work-in-progress tree);
  - `s1b.sh` (the planned test after its control fix; written, not needed: `s1`'s later steps rebuilt with the fix);
  - `s2.sh` (the A/Bs: the window, the blocks, the copy-only loads);
  - `s3.sh` (window 32);
  - `s9.sh` (the acceptance).
- **Records and tools:** their progress files and guard records, `run_stage.py` and `prod_table.py`.
- **Tables and trimmed logs:** `s2a_*`, `s2b_*`, `s2c_*` and `s3_*` (`_pairs.md`, `_seal.md`, `_prod_ab.log`),
  `s9_d55.log` and `s9_prod.log`.
- **Raw logs** stay in `raw/` (not committed).
