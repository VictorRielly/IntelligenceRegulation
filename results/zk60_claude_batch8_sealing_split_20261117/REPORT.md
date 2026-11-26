# Batch 8: where the sealing pass's host time goes (solo `serve1`), and what could leave the forward chain

Author: Claude (one Sonnet agent at high effort, run for the Claude co-coordinator), 2026-11-17 UTC.
Saved by the co-coordinator from the agent's hand-back text: the agent's own write of this file was refused by its
harness, so the text below is the agent's, unchanged except for this note and the lines marked
**[coordinator]**. Not yet cross-reviewed.

Labels: MEASURED (log, trace, polled counter or sampler dump of this batch), RECOMPUTED (arithmetic on measured
numbers), CODE-READ, MODEL. No source change, no build, no git write.

## Summary

- The solo sealing pass is 2.183 s (n = 12, unsampled). The sampler split, converted at that figure:
  **(a) work that only finishes block k's witness: 1.065 s (48.8%)**; (b) work needed before block k+1's first
  product: 0.146 s (6.7%); (c) the middle of a block: 0.531 s (24.3%); (d) waiting on the device and the pool:
  0.440 s (20.2%).
- (a) is 88% of the 36 ms gap between blocks. Its largest item is the lookup-miss check CS-3, 0.728 s per pass.
  **Half of CS-3, 0.35 s per pass (16% of the pass), repeats a public check that the build of the same block has
  just run.** Frames named allocation or zeroing are 0.6% of the pass (0.013 s).
- `HL_GPU_WITNESS_VIEW=0` cuts the commit-to-start latency of the witness products from 0.242 s to 0.085 s per
  pass, but the pass does not get shorter: the saving reappears as host copy time.
- Block k+1 reads only one vector of block k (`trace.x2`), which exists before group (a) starts. Group (a) can in
  principle run off the forward chain; it needs a builder change, and hand-over order, refusal order, the Turn and
  the memory budget constrain it.
- MODEL: with (a) off the main line the solo pass would be about 1.15 s (free cores) to 1.6 s; beside a proof about
  1.9 to 2.3 s against 3.35 s. Removing only the repeated check: about 1.83 s solo.

**[coordinator] Checked by me in the source:** `protocol.rs:624-626` (`check_lookup_misses` begins with
`blk.check_for_shape(sh)?`), `private_block.rs:886-888` (`check_for_shape` returns `check_accuracy_for_shape(sh)`
on that branch), `witness.rs:84` (`build_for_block` calls `blk.check_accuracy_for_shape(sh)?`), and
`trained_block.rs:3047` (the sealing chain calls `check_lookup_misses(&ssh, lay, &cur.blk, &w)` with the same shape
and block the build used). Two things the agent did not report: a source-text gate at `r6_tests.rs:238` asserts
that the sealing chain contains exactly that call, so any change must keep it or change the gate with a reason;
and a further call of `check_accuracy_for_shape` exists at `trained_block.rs:1415`, which I did not read in
context. I did not re-run the sampler split.

**[coordinator] Cross-review by Antigravity, 2026-11-17 17:30 UTC (its entry of that time in
`ops/zkp-mvp/RECOVERY_COORDINATION.md`): STANDS WITH NOTES.** Hygiene and every headline number recompute. Read the
tables below with three corrections [Antigravity's figures, not re-derived by me]:
- **Group (a) is smaller in unsampled time.** The sampler does not slow all phases alike: on the sampled passes
  the GPU products run x1.02, the middle host phases x1.20 and the between-block gap x1.46. Deflating by phase,
  group (a) is about **0.95 s (43.5%)**, not 1.065 s, and the repeated public check about **0.28 to 0.31 s (13% to
  14%)**, not 0.349 s. The A33 stage 1 patch later measured -0.26 s on the solo pass, which fits the corrected
  figure.
- **Groups (b), (c), (d) shift.** A closure frame in the Q/K/V join was mis-unwrapped in `sample_split.py:61-66`:
  0.088 s of device wait and 0.009 s of Q/K/V preludes were counted as requantisation. Corrected shares at the
  report's scale: (a) 48.8% unchanged, (b) 7.1%, (c) 19.8%, (d) 24.3%.
- **The repeated check is not on identical arguments in every case.** `witness_for_block`
  (`trained_block.rs:1542-1550`) builds at the shape with its gate shift overwritten by the block's own data, and
  uses `build_shaped` when the block has no accuracy data; only CS-3 checks the block against the layer record's
  shape. They coincide in production, but a patch must keep the full check whenever they do not. (My summary line
  above, "the same shape and block", is true only under that condition.)
Also from the cross-review: the SealPool is 6.7 of 8 busy during the build's own host regions (the 2.9 of 8 below
is over the whole pass), and at DD profiles `assign_with` can refuse too, which matters for stage 2's refusal
order. The session-specific scratch path in `batch8_runner.py` has been replaced.

## 0. What was run

- Date: 2026-11-17, 16:11Z to 16:19Z.
- HEAD: 4716c6b5fe8bfe86353d698c4ede29758075dbed. The Batch 7 review says the binary was built at 2df5f72d with no
  source change since; I did not diff.
- Binary: `.../hashline/target/release/deps/hashline-a90b6cf7715dc2a7`, sha256
  aaaab7e6fd38af59d406f201f94cfdb0325a3fe6adb3a04332873580f3acad11, verified before each run.
- Hardware (sysctl): Apple M3 Ultra, hw.ncpu 32, 256 GiB (274877906944 B), page size 16384.
- Leaf, environment and guard arguments are exactly Batch 7's `serve1`: `run_batch7_guarded.py` lines 903-915 for
  the environment, line 871 for `--need-gib 36 --cap-gib 48 --max-secs 420`, default poll.
- Added by this batch: `--wait-secs 21600`, `HL_GPU_WITNESS_VIEW=0` in the B arms, a 20 ms task-counter poll, a
  timestamped log tail, and `/usr/bin/sample`.
- Run order and guard run ids, all exit 0 (6 of the 8 allowed runs):

| run | guard run id | waited |
|---|---|---:|
| A1 | 2f631f980f9d | 0.1 s |
| S1 | f2b85d2e4af3 | 0.1 s |
| B1 | d82069df7283 | 0.1 s |
| A2 | 81d21ae25355 | 10.2 s |
| B2 | 81b2f60ed625 | 10.2 s |
| S2 | c7f7868c4ec7 | 5.1 s |

- n = 6 warm passes per run: 12 per arm for A, B and S. 8 passes (passes 2 to 5 of S1 and S2) are inside the
  sampler window.
- ds4-bench was absent before and after all 6 runs (in each `*.meta.json`).
- The heavy lock serialised these runs against other agents' Lean builds.
- Sampler: `/usr/bin/sample <pid> 30 2 -mayDie`, attached by pid at the end of pass 1. No permission problem.
- Sampler dumps (outside the repository, `/Users/victorrielly/zk60-artifacts/batch8_traces_20261117/`):

| file | size | sha256 |
|---|---:|---|
| `sample_s1_sampled.txt` | 53,376,351 B | e0c3cd3f4fbc67eb503b6b619985133d1e6d6f7749538c56cb6ca68e513f986a |
| `sample_s2_sampled.txt` | 56,504,406 B | d604b8b8a2dd410026eae72f4fd851da4f51ac28f354c6c3e81f7fabab03f33f |

- GPU traces, gz, in the same directory (sha256 of the gz):

| run | sha256 |
|---|---|
| A1 | 9102a419b491e9bd9b7a92f4001ae4518f1b3adf755e3c90636a872eee1ab4e1 |
| S1 | e9f40c7d88122ace4c0888e38fab256bf650b9087076312fb12344d64616cdd2 |
| B1 | 76fb1c1c474cb0253581dee0de9ba6afe7d00b2a5e745b3fd5beae6fb30fc713 |
| A2 | b97766e7673fa44f3db95b799a7849cc54b9509da6a72e5b3d7ac805146fa972 |
| B2 | 4613b1500c7142b01449c30b915154c07d7e81b13f9a0a0e0e01b3cfdc663f5a |
| S2 | 6b12484ef83300c3f59aa004e2c4d9d584fcb74b101b4505c1cbf0b80e0ed68c |

### Reproduction of Batch 7 (A arm, n = 12)

| quantity | Batch 7 | A arm | difference |
|---|---:|---:|---:|
| sealing pass | 2.215 s | 2.183 s (A1 2.190, A2 2.176) | -1.4% |
| request | 6.188 s | 6.185 s | 0% |
| commit-to-start, group-critical | 0.249 s | 0.242 s | -3% |
| P8 | about 1.17 s | 1.176 s | 0% |
| GPU busy | 0.370 s | 0.372 s | +1% |

Reproduces within 1.5%. The sampled runs are slower: sealing pass median 2.65 s (S1) and 2.80 s (S2), about +21% to
+28%. The unsampled A and B runs are the references.

## Q1. Sampler split (S1, S2)

**Threads.**
- Each request's sealing chain runs on a new lane thread, whose stack holds `trained_block::seal_chain`.
- `SealPool::run` (`trained_block.rs:2568-2573`) installs each build on the pool. The lane thread then parks in
  rayon `in_worker_cold` / `LockLatch::wait_and_reset`.
- The build's main line is the worker whose stack holds `witness_for_block`. It was always `hl-seal8-0`. The other
  7 workers run stolen halves of the parallel regions.
- Prover threads are excluded by construction: only lane samples with `seal_chain` and `hl-seal8-*` samples with
  `witness_for_block` are counted.
- Main line = lane samples outside the latch wait + in-pool main-line samples.
- Cross-check: lane latch-wait samples equal in-pool samples to 0.1% (2,222 against 2,220 in S1; 2,247 against
  2,245 in S2).

**Counts to seconds.**
- `sample` ran at about 3.3 ms per sample, not 2 ms.
- Per pass, seconds per sample = that pass's sealing wall (from the log, sampler included) / that lane thread's
  `seal_chain` samples.
- This gives 3.307 ms (S1) and 3.326 ms (S2) across 4 passes, ranging 3.1 to 3.8 ms per pass.
- This makes the total equal the wall by construction. It is not an independent total check. The independent
  checks are the lane-wait against in-pool agreement and the P8 comparison below.
- Pool-side classes are means over 4 passes, because the call graph has no time axis. Lane-side rows could be split
  per pass and are stable.
- Lane `seal_chain` samples per pass: S1 678, 859, 918, 905; S2 718, 1010, 898, 889.

**Perturbation.**
- Shares are close in the two sampled runs: (a) 47.8% and 49.8%.
- (a) + pre-product (b) = 55.5%, against the unsampled P8 share 1.176 / 2.183 = 53.9%, within 2 points.
- Shares are therefore reported, and converted to seconds at the unsampled 2.183 s.
- This assumes the sampler slows every group proportionally. The P8 agreement supports it for (a)+(b), not for (c)
  and (d) separately.

**Split (mean of S1 and S2; RECOMPUTED at 2.183 s):**

| group | s per pass | share | ms per block | content |
|---|---:|---:|---:|---|
| (a) witness-only | 1.065 | 48.8% (47.8, 49.8) | 33.3 | see below |
| (b) before the first product | 0.146 | 6.7% | 4.6 | the build's own `check_accuracy_for_shape` weight scan 0.128; norm_a 0.013; x-plane zero 0.004; Q/K/V preludes about 0 on the main line (it runs one of three parallel preludes) |
| (c) middle | 0.531 | 24.3% | 16.6 | scores, softmax, PV and other `build_with` code 0.354; Q/K/V requantisation and RoPE 0.114; norm_m 0.030; other products' preludes 0.034 |
| (d) waiting | 0.440 | 20.2% | 13.8 | device wait (`wait_done` spin) 0.416; parked in a join 0.024; anything else 0.001 |

**Group (a) detail:**

| item | s per pass | share | where it runs |
|---|---:|---:|---|
| CS-3 `check_lookup_misses` total | 0.728 | 33.3% | lane thread, outside the pool; its parallel parts run on the global pool |
| of which `BlockPublic::check_accuracy_for_shape` (weight scan, `check_words`, registry check) | 0.349 | 16.0% | reached via `protocol.rs:626` `blk.check_for_shape` then `private_block.rs:886-889` |
| of which `w16_histograms_cols` | 0.250 | 11.5% | |
| of which `looked_built` 0.059, exp 0.035, `accuracy_act::histogram` 0.031, `Layout::for_shape` 0.003 | 0.128 | 5.8% | |
| `assign_with` | 0.302 | 13.8% | pool main line |
| of which limb planes and scatter loops (`fill_planes` and closures) | 0.289 | 13.2% | |
| of which frames named allocation or zeroing (`zeros`, `__bzero`, large malloc, calloc) | 0.013 | 0.6% | |
| `padded_plane` 0.007, `true_words` 0.016, inlined flat-map 0.012, other lane code (seq comparison, hand) 0.001 | 0.036 | 1.7% | lane thread |

**What this says.**
- (a) is about 1.07 s of 2.18 s.
- (a) is 88% of the gap: P8 is 1.176 s, and (a) + pre-product (b) = 1.065 + 0.145 = 1.21 s.
- The gap is not mostly allocation. Frames that name allocation or zeroing are 0.6%, in line with A16's 0.05 to
  0.10 s. First-touch faults inside `fill_planes` are not separable, because the sampler sees user stacks only.
- CS-3 is a third of the pass. Half of it (0.35 s) repeats the public check `build_for_block` already ran on the
  same block (`witness.rs:84`).
- That repeat is CODE-READ, not run: `check_lookup_misses` (`protocol.rs:624-626`) calls `blk.check_for_shape`,
  which for non-Legacy stacks is `check_accuracy_for_shape` (`private_block.rs:886-889`).

**SealPool workers.**
- Average workers running during a sealing pass: 2.90 (S1) and 2.80 (S2) of 8, or 3.28 and 3.19 counting the
  device-wait spin.
- The 8 are asleep 84% of the 28 s window.
- The pool is idle while the lane runs CS-3 (about a third of each pass), because CS-3 uses the global pool.
- Non-sleeping worker samples are 11,019 (S1) and 11,204 (S2):

| class | S1 | S2 |
|---|---:|---:|
| rayon parallel-iterator chunk bodies, no project frame named (62%) | about 6,800 | about 7,000 |
| main line on worker 0 | 1,313 | 1,288 |
| device-wait spin | 1,281 | 1,367 |
| named `assign_with` closures | 959 | 932 |
| `quantized_with` closures | about 116 | about 117 |

## Q2. Page faults and system time

- The harness prints `getrusage` per request only. The process's own task counters (`proc_pidinfo`
  PROC_PIDTASKINFO, the numbers `top` shows) were read every 20 ms from outside.
- They are aligned to the GPU trace, which is on the same monotonic clock (checked).
- Method check: polled request sys 13.54 s equals the log's 13.5 s.
- Window per pass: first Q/K/V begin to last Wd done, widened by half the 34 ms bookend residual per side. Nothing
  else is running in a solo request then.
- Figures are process-wide: SealPool, global pool, loaders and Metal driver threads are all included.

| per solo sealing chain (A arm, n = 12) | median | IQR |
|---|---:|---:|
| page faults | 571,400 | 2,150 |
| sys CPU | 8.3 s | 0.58 |
| user CPU | 12.9 s | 0.20 |

- Whole request (n = 10): 1.24 M faults, 13.5 s sys.
- The B arm is the same: 568.8k faults, 8.25 s sys.
- 571k faults at a 16 KiB page is 8.9 GiB of faulted pages per pass. Sys 8.3 s is 61% of the request's sys and 3.8
  cores' worth over the 2.2 s chain.
- Inside the between-block gaps (52.6% of chain wall): 50.4% of faults, 69.5% of sys, 65.5% of user CPU
  (`gap_counters.py`, 31 gaps x 12 passes; only totals are meaningful at 20 ms resolution).
- So faults follow wall time evenly, and sys is concentrated in the gaps (5.7 s sys per pass).
- How much sys is page-fault service against thread yields, wake-ups and Metal driver calls is not known, and is
  not estimated.

## Q3. `HL_GPU_WITNESS_VIEW=0` (A B A B, 6 warm passes each, GPU trace on)

**What the switch does (CODE-READ, `gpu/metal.rs`).**
- `witness_options()` at line 4546: anything but `0` means view.
- With the view (default), `weight_buffer` (4743-4759) gives the device a no-copy page view of the weights
  (`pages_view`, 4712).
- `result_plane` (4768-4782) allocates a zeroed page-aligned `Vec<i64>` with a writable page view, so the kernel
  writes in place.
- With `=0`, the weights are copied in parallel 1 MiB chunks into a pooled buffer, and the output goes to a pooled
  buffer that is scattered into the plane after `done` (4872).
- Both the copy and the scatter lie outside the `begin`..`done` stamps.

| arm | sealing pass, median (run medians) | request | critical commit-to-start | sum of 224 buffers | per-buffer median |
|---|---:|---:|---:|---:|---:|
| A default (A1, A2) | 2.183 s (2.190, 2.176) | 6.185 s | 0.242 s | 0.454 s | 1.40 ms |
| B `=0` (B1, B2) | 2.229 s (2.184, 2.289) | 6.238 s | 0.085 s | 0.146 s | 0.64 ms |

- Computed with Batch 7's `partition_wprod_group` (imported unedited), and for the sum as `recompute_wait.py` does
  (GPUStart minus committed).
- By product, median ms, A then B:

| product | A | B |
|---|---:|---:|
| Q | 0.92 | 0.72 |
| K | 0.94 | 0.69 |
| V | 1.47 | 0.66 |
| Wo | 0.96 | 0.62 |
| Wg | 1.50 | 0.62 |
| Wu | 2.37 | 0.59 |
| Wd | 2.28 | 0.64 |

- The page-view reading is supported: without the view the latency is 0.6 to 0.7 ms for every product, independent
  of weight size. A residual 0.085 s remains.
- **The sealing pass does not shorten:** +0.046 s (+2.1%), inside the run-to-run spread (A1 2.190, B1 2.184, A2
  2.176, B2 2.289; B2 drifted up from 2.20 to 2.48 across its passes).
- The saved 0.157 s reappears as host time:
  - P1+P3+P5+P7 fall 0.608 to 0.463 s.
  - P2+P4+P6 rise 0.407 to 0.512 s.
  - P8 rises 1.176 to 1.235 s.
  - These are medians of separate series and do not add exactly.
- The weight copy and output scatter cost about what the page view cost, so there is no net gain and no reason to
  change the default.
- Page faults are unchanged between arms.

## Q4. Dependency (CODE-READ)

**What block k+1 reads.**
- In `seal_chain` (`trained_block.rs:2970-3098`), block k+1's build is
  `pool.run(|| witness_for_block(&ssh, &cur.blk, &x))` (3020-3033).
- It reads only: `x`, its own `cur` (taken at 3010), `ssh`, and the `pool`.
- `x` is set at 3060 from `true_words` (3055) of `padded_plane(&w, A_X2)` (3051).
- Plane A_X2 is exactly `trace.x2`, computed in `build_with` by "residual 2" (`witness_accuracy.rs:1080`, returned
  at 1106) and written by `assign_with` at `witness_accuracy.rs:1264`.
- So block k+1 needs only that one vector (about 4 MiB of i64), which exists when `build_with` returns, before
  `assign_with` (`witness.rs:75`).
- It does not read `assign_with`'s other planes, the CS-3 result, `lays`, `outs`, `kept`, `shapes`, `metas`,
  `digests`, the budget counters, or `hand`.

**Could group (a) run elsewhere, bytes and order unchanged?** In principle yes. Group (a) is `assign_with`
(`witness.rs:86`), CS-3 (`trained_block.rs:3047`), `padded_plane` (3051), `true_words` (3055), the seq compare
(3056-3058) and the hand-over (3066, 3069). What blocks or constrains it:

1. **Builder interface.**
   - `build_for_block` (`witness.rs:80-91`) returns a finished `Witness`.
   - x2 is visible only after `assign_with` (`witness_accuracy.rs:1122, 1264`).
   - A split needs x2 or the `Trace` returned early.
   - Both files are privacy-pinned (a16 README section 8) and under Astra's source pin per the Batch 7 review. This
     is a source change, not a switch.
   - The early copy must apply the same int16 conversion and refusal as `padded_plane` (`trained_block.rs:1597`).
2. **Borrow and move.**
   - CS-3 borrows `&cur.blk` and `lay` (3047).
   - `hand.block` moves `cur.blk` (3066), and `cur.record` is moved into `metas` (3062).
   - `lay` borrows from `lays`, which is `push`ed on a new calibration shape (3040-3046).
   - `w` goes to `hand.witness` (3069) and `kept` (3081-3085) only after the checks pass.
3. **`hand` is not `Send`.**
   - `hand: &mut dyn SealHand` (2970).
   - The hand-over closure holds `&mut next` (`run_fork.rs:2652-2657`).
   - Hand calls must stay on the lane thread, after joining the deferred task.
4. **Hand-over order.**
   - `plan_hand_over` refuses out-of-order blocks (`run_fork.rs:2654-2656`).
   - `SealedBlocks::put` is set-once (`run_fork.rs:2427-2429`).
   - `D55Hand::block` runs before `witness` (`trained_block.rs:2789-2806`).
   - The budget decision is sequential state (3067-3086).
   - In this stream the window is 0, so the witness is handed straight back. With a window above 0 the fork parts
     start at hand-over (`run_fork.rs:2658-2663`), so a deferral shifts when fork work starts.
5. **Refusal order.**
   - The H-1 ruling (`trained_block.rs:2822-2828`) fixes the first refusal in layer order, with its text.
   - Candidates: build error (3035), CS-3 (3047), parity (3058).
   - Layer k+1's load error (`cur?` at 3015) must not pre-empt layer k's.
   - A speculative k+1 build must be discarded if k's deferred check fails.
   - Helpers must be joined before return (scope at 3000, `StopLoads` at 3004).
6. **Turn and end of pass.**
   - Seal Turn entered at `trained_block.rs:4399`, left at `sealed` (4271-4277) after `seal_chain` returns.
   - The pass end reads `outs`, `first`, `last`, `kept` (3090-3095).
   - All deferred work must finish first, so the last block's (a) (about 33 ms) stays on the chain.
7. **Memory.**
   - `budget_bytes` (3068-3081, `HL_A19_BUDGET_GIB=32`) counts kept and handed witnesses.
   - A deferral holds one more block's planes plus the next build's trace at once.
   - Plane size is not settled (the Batch 7 review gives 169 MiB to 670 MB). Peak RSS was 28.7 to 29.7 GiB, under
     the guard's 36. Not tested.
8. **Cores.**
   - The SealPool has 8 threads (`trained_block.rs:2543-2573`), and `assign_with` runs in it. CS-3 runs on the lane
     thread with the global pool.
   - A deferred (a) competes with block k+1's regions (there is room: 2.9 of 8 running) and, beside a proof, with
     the prover's host phases.

**Two cheaper facts found on the way (not asked):**
- (i) CS-3's repeated `check_accuracy_for_shape` costs 0.35 s per solo pass (16%) and needs no thread. Removing it
  is a source change. Whether the duplicate is deliberate defence in depth, and what the H-1 and CS-3 gates
  require, was not assessed.
- (ii) Group (b)'s own `check_accuracy_for_shape` (0.13 s) depends only on block k+1's public data. In principle it
  could run on the A20 loader threads (`LoadAhead`, `trained_block.rs:2905-2928`). Same caveat.

## Q5. Bound (MODEL)

Solo inputs (MEASURED): pass 2.183 s, (a) 1.065 s (33.3 ms per block), the rest 1.118 s (34.9 ms per block).

| MODEL | pass |
|---|---:|
| (a) of blocks 0 to 30 leaves the main line, cores free, deferred stage costs the same as today | 2.183 - 1.065 x 31/32 = about 1.15 s |
| deferred stage 1.5x slower, so it becomes the limit (32 x 33.3 ms x 1.5) | about 1.6 s |
| no threads, only CS-3's repeated check removed (0.349 s) | about 1.83 s |

- Solo pass would be about 1.15 to 1.6 s (-27% to -47%). The floor is the chain's 1.118 s plus the last block's (a).
- **Beside a proof** (Batch 7 figures, not re-measured: pass 3.35 s, host phases x1.3 to x1.4, queue wait +0.46 s,
  kernel +0.07 s):
  - Scaling (a) by 1.37 gives about 1.46 s, leaving about 1.89 s on the chain.
  - MODEL: about 1.9 s if the deferred (a) finds free cores, about 2.3 s if it runs 1.5x slower
    (32 x 45.6 ms x 1.5 = 2.2 s), against 3.35 s.
- **What it cannot do:**
  - The GPU part stays: +0.46 s queue wait (87 to 97% behind running prover work) and +0.07 s kernel.
  - Total CPU work does not shrink (about 21 CPU-seconds per sealing pass), so beside a proof it competes with the
    prover's host phases and could lengthen them (not measured).
  - Gaps are longer when the prover is in its host phases, so the deferred work meets its worst cores at those
    moments.
- In the two-lane stream the cadence is prover-bound today (stall 0.000 s), so a faster sealing pass shows only as
  slack until the prover gets faster.

## What this does not show

- No prototype ran. Whether the deferral overlaps, and the slowdown factor (1.0 to 1.5), are the MODEL's free
  parameter.
- The sampler adds 21% to 28%. Proportional scaling is supported for (a)+(b), not for (c) and (d) separately. The
  table seconds are shares x the unsampled pass.
- `sample` sees user stacks only.
  - Fault service time inside `fill_planes` or CS-3 is not separable. The 0.6% allocation row is a lower bound.
  - Sys time is not attributed between faults and yields.
- Pool-side rows are 4-pass means. norm_a and norm_m were separated by call-site offsets in `build_with` (3680 and
  11812, source order), not by label.
- The Q/K/V preludes on the main line show about 0 samples, so group (b) is understated.
- Global-pool threads running CS-3's parallel regions were not attributed.
- The fixture is the synthetic stack (one block repeated 32 times), not a trained export.
- Q3: n = 12 per arm from two processes, fixed A B A B, trace on. B2 drifted. The +0.046 s pass-time difference is
  not separable from noise. The commit-to-start drop (-0.157 s) is large against its spread.
- Nothing ran beside a proof. Q5's beside-a-proof half borrows Batch 7's figures.

## Files

`BATCH8_METRICS.json` (per-pass values behind every table), `batch8_runner.py`, `procpoll.py`, `sampleparse.py`,
`sample_split.py`, `analyze_runs.py`, `aggregate.py`, `gap_counters.py`, `final_tables.py`, `worker_jobs.py`, the
six runs' `.log`, `.guard.json`, `.meta.json`, `.pass.json`, `.linetimes.tsv`, `.counters.tsv.gz`,
`.guard_status_pre.txt`, the two `.split.json` / `.split.txt`, and five small `explore*.py` scratch scripts.
