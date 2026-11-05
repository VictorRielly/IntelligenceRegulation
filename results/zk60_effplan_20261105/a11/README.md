# A11: why a fork's host work inflates under six-way concurrency, and the fix (2026-11-05)

The plan: `docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A11 (and A8, considered). Byte-preserving. It
builds on A7 (`../a7/README.md`), whose timeline showed the GPU idle 41–47% of the forks phase while the fork threads
were on the host.

Labels: [MEASURED] a number from a log in this directory; [INFERRED] derived from measured numbers; [ESTIMATE] a
judgement, not a measurement.

All runs: W16R2 8B T128, 32 blocks, the D55 fork run, `HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0`, shared Metal
queue, spin wait, on the shared M3 Ultra (24 performance + 8 efficiency cores).

## Plain summary

- **What inflates a fork's host work is the one global rayon pool shared by six forks, not the cores, the GPU or a
  lock of ours.** [MEASURED, `s1`]
  - The same 32 blocks cost about the same CPU at N = 1 and at N = 6 (88–108 CPU-seconds per call). At N = 6 the
    pool workers were still about half asleep, yet each fork waited about 3.5 times longer on its own parallel regions.
  - A pool worker waiting in a join of one fork's parallel region steals and runs whatever is queued, often another
    fork's task, and the first fork's region cannot finish until that task does. At N = 6, 69% of the pool's running
    samples were such nested jobs (up to 28 deep), against 41% at N = 1.
  - About a quarter of all CPU time was system time (23–36 CPU-seconds per call), most of it the pool's own sleeping
    and waking (`swtch_pri` yields, rayon's `wake_specific_thread` lock) [INFERRED: one pool per fork cut it to about 5
    s, while halving the page faults alone saved under 2 s].
- **The fix: each fork worker gets its own rayon pool** (`run_fork.rs`, `[A11]`; the new default, ceil(cores /
  workers) = 6 threads per fork at N = 6). [MEASURED, in-process, both arm orders, every pair favouring the fix]
  - **The 4-request stream: +16.9% steady state, 20.2 → 23.6 tok/s** (amortized +11.8%, 18.1 → 20.2).
  - **One request from its input: −4.5%, 9.03 → 8.62 s** (14.2 → 14.8 tok/s).
  - **Proof-only fork run: −10.6%, 4.91 → 4.39 s** (26.1 → 29.2 tok/s); −6.9% and −7.1% in the two earlier A/Bs.
  - System CPU −78%, user CPU −21%: a proof-only call costs about 60 CPU-seconds instead of 93.
  - The forks phase is now about 4.0 s, against the GPU-busy bound of about 2.8 s (A7).
- **Also found, smaller:**
  - each block's `A` and `H` host matrices (670 MB) came back from macOS as fresh pages, zero-filled on the fork
    thread alone; at N = 6 that was a quarter of the fork thread's own host time and about 40,000 page faults per
    block. Reusing them (a host-matrix pool, F1) halved the faults but **did not pay** (+0.2% alone, +2.8% with the
    fork pools), so it was **dropped**: its code is not in the tree; its A/Bs are kept here (`s2`, `s4`).
  - `Fp::from_u128` reduced with a generic 128-bit division (`__umodti3`), 3.8% of the pool's busy samples through
    the randomness stream. It now uses the Goldilocks reduction `mul` already uses: the same word for every input
    (tested), and always on.
- **No byte moves.** The goldens, the six trained digests and the receipt sizes are unchanged (§6), and new tests prove
  the seeded rung inside pools of 1, 2, 3 and 6 threads to the golden.
- **What is left:** the fork run is still host-bound. The largest remaining host cost is building the device slots'
  tables on the CPU (about 1.3 GB of extension words per block, §2.4). Moving that to the GPU is the next lever.

## 1. The method

- **The CPU meter** (`run_fork_tests.rs`, `a11_report`): every fork call prints the process's `getrusage` (user and
  system CPU, minor faults, context switches) and each fork worker's own thread CPU (`CLOCK_THREAD_CPUTIME_ID`)
  against its `prove_core` wall.
- **The phase clock in every fork** (A/B arm word `phases`): each fork's `timing::Phases` rows, summed over the 32
  forks (`timing.rs`, test-only `rows_for_test`). Diagnostic; no byte changes.
- **The sampler window** (`HL_A11_SAMPLE=K`): K proof-only fork calls back to back, between two file handshakes with
  `/usr/bin/sample` (2 ms), at N = 1 and N = 6 (`s1.sh`), and again after the fix (`s6.sh`). `sample_summary.py`
  gives every sample a role (a fork's main line: any stack holding `prove_core`; a rayon worker's other samples;
  other) and a state; `sample_chains.py` and `sample_nesting.py` answer the questions below. The raw call graphs (68 MB and 119 MB) are not committed; `derive_s1.py` wrote the small extracts
  `s1_*.txt`. The sampler slows the process by about 25% (the calls inside the window ran 12.8–13.2 s at N = 1, 6.2–7.5
  s at N = 6), so only the sample shares are used, never its absolute seconds.
- **The A/B** (`HL_D55_GPU_AB`, new words `fp<t>`/`fpauto`/`global` and `phases`; in the `s2`–`s4` builds also
  `pool`/`parzero`/`nopool` for the dropped F1; `HL_D55_AB_ALTERNATE=1` reverses the arm order in every odd pass). `pairs.py` gives each metric's paired change
  with the base first and with the test first, and their mean, which cancels A7's order bias.

## 2. What the profile found [MEASURED, `s1`]

### 2.1 Same work, compressed

One proof-only fork call each (`s1_d55.log`, the warm pass):

| | N = 1 | N = 6 |
|---|---:|---:|
| wall (forks phase) | 10.603 s (10.204) | 5.296 s (4.905) |
| process CPU: user + system | 67.2 + 26.6 = 93.8 s (8.8 cores) | 72.0 + 35.9 = 107.9 s (20.4 cores) |
| minor page faults | 302,892 | 1,706,761 |
| involuntary context switches | 962,080 | 840,044 |
| fork workers: `prove_core` summed / their own thread CPU, blocking wait | 10.19 s / 2.33 s | 26.46 s / 3.86 s |

The other two N = 6 calls of `s1` cost 95.9 and 88.1 CPU-seconds, and their fault counts were 1.12 M and 1.26 M, so the
CPU work is about the same at both N; the faults vary. With the blocking wait, a fork thread's own CPU is about 73 ms
per block alone and 121 ms at N = 6 [INFERRED]. The rest of its 318–826 ms per block is waiting: on the GPU or on the
rayon pool.

### 2.2 Where the fork threads wait (`s1_sample_N1.summary.txt`, `s1_sample_N6.summary.txt`)

| a fork's main-line samples (stacks holding `prove_core`) | N = 1 | N = 6 |
|---|---:|---:|
| waiting on its parallel regions (`in_worker_cold`: blocked until the pool finishes them) | 43% | **59%** |
| waiting on the GPU (`wait_done`) | 34% | 24% |
| its own host code | 23% | 17% |

Per block [INFERRED, the shares times the unsampled 322 / 819 ms per block]: pool waits about 0.14 → 0.48 s, GPU waits
0.11 → 0.20 s, own host code 0.075 → 0.14 s. The pool wait is most of the inflation.

The regions the forks waited on longest at N = 6 (`s1_chains_N6_fork_poolwait.txt`) were the device slots' table
builds (`run_slot`, `priv_table_fill`, `build_tables_at`), the lookup columns (`lookup_values_at`, 5x N = 1), the
public weight checks (`weights_vanish_off_support`, 5x), the store folds (`fold_rows_host_lazy`, `fold_rows_host`), the
randomness fill (`fill_fp`), the int8 weight folds (`fold_cols_i8`), the histograms and the upload copies.

The phase clock says the same, every phase 2–5x longer at N = 6 (`s1_d55.log`, `D55-AB A11 PHASE` lines; ms per
block, spin wait):

| phase | N = 1 | N = 6 |
|---|---:|---:|
| A: allocate + witness planes | 13.9 | 57.8 |
| A: lookup values + byte histogram | 12.1 | 39.6 |
| A commit | 24.1 | 58.2 |
| H: helper inverses (six domains) | 9.0 | 31.3 |
| H commit | 26.0 | 54.3 |
| slot 00 (row sums, the first slot: its definitions fold the weights) | 6.3 | 34.4 |
| slot 18, F zero-check | 41.9 | 77.4 |
| open A / open H | 21.7 / 16.9 | 39.1 / 48.1 |
| **all phases** | **322** | **819** |

### 2.3 Why the pool is slow while half idle

- **The rayon workers at N = 6:** 51% of their samples asleep; the other 49% inside jobs, but a large part of that
  waiting too: of the in-job samples, condition-variable waits 12%, yields (`swtch_pri`) 9%, mutex waits 6%. The
  mutex waits are rayon's own: 5,932 of the 6,787 lock-wait samples sit in `Sleep::wake_specific_thread`, the lock
  each wake-up takes (`s1_chains_N6_rayon_locks.txt`). Most of the rest is the system allocator's lock
  (`_xzm_malloc_large_huge`), taken by the per-split histograms of `w16_histograms`.
- **Nested stealing.** A worker blocked in a join keeps busy by running other queued jobs, and returns to its own
  join only when that job ends. Counting the `wait_until_cold` frames on each running sample (`s1_nesting_*.txt`): at
  N = 1, 41% of running samples are nested inside another job's join wait; at N = 6, 69%, up to 28 levels deep. With
  six independent forks on one pool, a fork's region is held up by other forks' tasks [INFERRED: the nesting, plus
  pool waits 3.5x longer while the pool is half idle].
- **The cost in CPU:** at N = 1 and N = 6 alike about 23–36 CPU-seconds per call are system time. After the fix it is
  about 5 (§5), so most of it was the pool's sleeping and waking, not page faults [INFERRED from §5: removing about 47%
  of the faults saved only 1.8 CPU-seconds of system time].

### 2.4 Smaller findings

- **The `A` and `H` matrices.** `vec![Fp::ZERO; rows x n]` for `A` (2501 x 2^14 words) and `H` (2602 x 2^14), 670 MB
  per block, written by the fork thread alone. At N = 6 these two fills were 26% of a fork thread's own host samples
  (`SpecFromElem::from_elem` 20%, `__bzero` 7%), 6% at N = 1 (`s1_chains_N*_fork_alloc.txt`). Freed after the
  openings, they went back to the kernel (`mach_vm_deallocate`), so every block faulted them in again: about 40,000
  faults per block, the bulk of N = 6's 1.1–1.7 M per call [INFERRED from the sizes].
- **`Fp::from_u128`** was `v % p` on `u128`, compiled to the generic software division: 3.8% of the pool's busy samples,
  all inside the randomness stream's draws (`fill_fp`, `s1_chains_N6_u128.txt`).
- **The device slots' tables are built on the CPU.** Slots 14–22 write about 81 M extension words per block (1.3 GB;
  slot 18 alone 2^21 x 19) into the device buffers, from the committed rows (A6 census, `../a7/s2_census.log`). This is
  the biggest parallel region the forks wait on. It is not changed here (§7).
- **The store folds (A8's target)**: the forks waited on them (`fold_rows_host_lazy`, `fold_rows_host`) for 389 of
  8,017 main-line samples at N = 1, about 5% of a block (about 15 ms of 322 ms [INFERRED]), and 760 of 14,995 at N = 6.
  Not pursued (§7).

## 3. What changed

**F5, one rayon pool per fork worker** (`private_block/run_fork.rs`, `[A11]`, the default).
- `prove_forks_inner` gives worker `w` its own pool (`hl-fork{w}-pool{i}` threads, made once per worker index and size,
  kept for the process; an idle rayon thread sleeps). The worker runs each of its forks' `prove_one` inside that pool
  (`install`), so the fork's parallel regions are worked by its own threads only.
- The size: `HL_D55_FORK_POOL` unset or `auto`, ceil(cores / workers) (6 at N = 6, 4 at N = 8 on this Mac); a run on
  one worker keeps the global pool. `HL_D55_FORK_POOL=0` restores the global pool (the pre-A11 path);
  `HL_D55_FORK_POOL=t` sets `t`.
- The fork worker's test switches (D55 review F5) are installed on the pool thread too, so every cheating-prover
  control still reaches `prove_core`.

**F2, `Fp::from_u128` by the Goldilocks reduction** (`zkp-core/src/field.rs`, always). `reduce128` is exact for every
128-bit input: 2^64 = 2^32 − 1 and 2^96 = −1 mod p, each step's carry or borrow corrected once, then one conditional
subtraction. The test `from_u128_is_the_canonical_residue_of_the_division` compares it with `v % p` on 400,000 random
words of every width and on the limb and multiple-of-p edges.

**F1, the host-matrix pool: measured, then dropped.** In the `s2`–`s4` builds, `prove_core` took `A` and `H` from a
small module (`host_pool.rs`) that reused a buffer of the same length, zeroed in parallel, and took it back after the
openings (tested equal to `vec!`, also on the seeded rung). It halved the page faults and paid nothing (§5), and a new
production module on the proving path also fails the path's module audits (`s24`, `s25`, `hash_domain` tests: "read
each new module, then list its edge here"; `s9_full.log`). So the module, its call sites and its A/B words were
removed: `protocol.rs` and `private_block.rs` are unchanged from the A7 tree.

**Diagnostics, test builds only:** the CPU meter, the per-fork phase sums, the sampler window, the A/B words and the
alternating order (`run_fork_tests.rs`); `ForkStats::fork_thread_cpu_s` / `fork_phases` and `thread_cpu_s`
(`run_fork.rs`, `#[cfg(test)]`); `Phases::rows_for_test` (`timing.rs`, `#[cfg(test)]`).

## 4. Why no byte can move

- **F5.** Which threads run a parallel region, and how many, changes no word: every parallel iterator on the proving
  path is indexed or an exact field or integer reduction, so its result does not depend on the pool. The transcript,
  the randomness stream and the command buffers are each the fork's own, used in the same order on the one thread
  that runs `prove_one`. zkp-core's own tests already check encoding and the sumcheck rounds at several thread counts.
  New: `w16r2_tests::a11_w16r2_rung_golden_inside_small_rayon_pools` (CPU, in the suite: pools of 1, 2 and 3 threads
  and the global pool) and `a11_w16r2_rung_digests_in_per_fork_pools_on_the_device` (Metal, three concurrent proofs
  each in its own pool of 1, 2 and 6 threads) give the golden `96e4f0b6…` every time (`s10_pools_*.log`; the
  earlier form with the host-pool modes, `s3_pools_*.log`, `s9_pools_*.log`). The D55 receipts verify and keep their
  sizes (§5, §6).
- **F2.** The same canonical residue for every input (the test above; the six trained digests and the goldens
  unchanged).

## 5. The A/Bs, in-process, both arm orders [MEASURED]

N = 6, proof only unless said. "Base first" and "test first" are the passes in which that arm ran first; the last
column is their mean, which cancels the order bias. (n pairs, n favouring the test.)

**F1: the host-matrix pool against the pre-A11 `vec!`** (`s2`, 8 passes, `s2_pairs.md`):

| metric | base first | test first | order bias solved out | means, base / test |
|---|---|---|---|---|
| proof wall | +0.0% (4, 2) | +0.3% (4, 2) | **+0.2%** | 4.954 / 4.960 s |
| forks phase | +0.2% (4, 2) | +0.7% (4, 2) | +0.5% | 4.587 / 4.606 s |
| system CPU | −8.1% (4, 4) | −7.1% (4, 4) | −7.6% | 23.3 / 21.5 s |
| minor faults | −47.5% (4, 4) | −46.2% (4, 4) | −46.9% | 1.17 M / 0.62 M |

**F5, the size of the per-fork pool** (`s3`: global against 6, 12, 24 threads; `s4`: against 4, 5, 6, 8 and 6 with
the host pool; 6 passes each; `s3_pairs_*.md`, `s4_pairs_*.md`):

| arm, against `global` | proof wall, order bias solved out (12 pairs: favour) | forks phase | user CPU | system CPU |
|---|---|---|---|---|
| fp4 (`s4`) | −1.4% (6: 4) | −2.1% | −26.7% | −82.6% |
| fp5 (`s4`) | −5.7% (6: 6) | −6.3% | −24.3% | −80.9% |
| **fp6** (`s3`) | **−7.1%** (6: 6) | −7.7% | −22.4% | −77.8% |
| **fp6** (`s4`) | **−6.9%** (6: 6) | −7.7% | −21.2% | −79.8% |
| fp8 (`s4`) | −6.7% (6: 6) | −7.4% | −17.0% | −70.5% |
| fp12 (`s3`) | −5.9% (6: 6) | −6.2% | −13.6% | −51.2% |
| fp24 (`s3`) | −4.6% (6: 5) | −4.8% | −6.0% | +19.6% |
| fp6 + host pool (`s4`) | −4.3% (6: 5) | −4.7% | −19.5% | −80.2% |

- With four or six arms the A/B alternates the whole order, so `global` ran first or last; the "favour" counts are
  per pair. Means (`s4`): global 4.820 s, fp6 4.485 s, fp8 4.496 s.
- **fp6 + host pool against fp6** (`s4_pairs_fp6_vs_fp6pool.md`): +2.8% wall, 0 of 6 pairs faster, faults −36%. With
  §5's first table, this is why F1 was dropped.
- The default rule, ceil(32 / 6) = 6, is the best measured size at N = 6.

**F5, the default rule (`fpauto`, 6 threads per fork) against the global pool, with one request from its input and the
4-request stream** (`s5`, 6 passes, `s5_pairs.md`; each arm and pass: a proof-only call, one sealed request, one
stream):

| metric | base first | test first | order bias solved out | means, global / per-fork pools |
|---|---|---|---|---|
| proof-only wall | −8.4% (3, 3) | −12.7% (3, 3) | **−10.6%** | 4.906 / 4.385 s = 26.1 / 29.2 tok/s |
| forks phase | −9.4% (3, 3) | −13.5% (3, 3) | **−11.5%** | 4.541 / 4.016 s |
| one request from its input (sealed) | −4.1% (3, 3) | −5.0% (3, 3) | **−4.5%** | 9.033 / 8.623 s = 14.2 / 14.8 tok/s |
| stream of 4, steady state | +16.9% (3, 3) | +16.9% (3, 3) | **+16.9%** | 20.21 / 23.63 tok/s |
| stream of 4, amortized | +11.7% (3, 3) | +12.0% (3, 3) | **+11.8%** | 18.07 / 20.21 tok/s |
| user CPU (proof-only call) | −20.9% | −21.7% | −21.3% | 69.7 / 54.9 s |
| system CPU (proof-only call) | −77.0% | −78.0% | −77.5% | 23.0 / 5.2 s |

- Every pair of every metric favours the per-fork pools.
- Per-request latency inside the stream: 11.2–11.8 s with the global pool, 9.9–10.8 s with the per-fork pools (the first
  request 9.2–9.5 / 8.9–9.3 s).
- **The stream gains most** [INFERRED]: its next request's sealing pass (the witness builds on the global pool and
  the A4 GPU products) no longer shares one rayon pool with the forks, and the forks' parallel regions no longer wait
  behind the sealing pass's tasks.
- Receipts: all 48 stream receipts verified after their clocks, and each arm's first proof-only and sealed receipt;
  fork receipts 818,728,672 B in every call, D12a 818,728,480 B.

**The profile after** (`s6`: the final tree, N = 6; `global+phases` against `fpauto+phases`, then a sampler window
on the default; `s6_d55.log`, `s6_sample_N6.summary.txt`, `s6_nesting_N6.txt`):

| one proof-only call, N = 6 | global pool | per-fork pools (default) |
|---|---:|---:|
| wall (forks phase) | 5.051 s (4.703) | 4.471 / 4.684 s (4.118 / 4.323) |
| `prove_core` per block (phase sums) | 817 ms | 711 / 744 ms |
| process CPU: user + system | 69.9 + 21.2 s | 54.9 + 4.5 / 56.1 + 4.6 s |
| involuntary context switches | 782,370 | 120,323 / 126,440 |
| minor page faults | 1.18 M | 1.27 M / 1.28 M |

- A fork's main line now runs on a thread of its own pool and works on its own parallel regions while it waits: of its
  samples, own host work 43% (its parallel regions now run partly on this thread), GPU waits 42%, its own fork's
  stolen tasks 12%, idle waits 4%.
- Nested stealing: 28% of the pool threads' running samples, from 69% (N = 6, global pool) and 41% (N = 1).
- The 68 rayon threads (32 global, 36 in the six fork pools) are 87% asleep.
- **What the host does now** [INFERRED from the main line's host samples]: the slots' table builds and eq cubes, the
  openings' store folds (`fold_rows_host_lazy` / `fold_rows_host`, about a fifth of the main line's host samples), the
  A/H zero-fills (`take_zeroed`, 8%), the randomness fill and the helper inverses.
- **The GPU share grew** (24% → 42% of the main line): the forks now reach the GPU sooner and more often at once, so
  each command buffer waits and runs longer. The forks phase, about 4.0–4.3 s, is still above A7's GPU-busy bound of
  about 2.8 s.

## 6. Acceptance [MEASURED]

**Stage 10** (`s10.sh`, `s10.progress`, `s10_*.log`, `s10.guard.json`) is the final tree, per-fork pools the default.
One guarded job (542 s, peak RSS 29.2 GiB):
- **build:** rc 0. **The no-feature `cargo check --tests`** (no `gpu-metal`): rc 0.
- **The full lib suite** (`--test-threads=8`, the R13 loader fixtures): **922 passed, 3 failed, 99 ignored**. The three
  failures are exactly the known ones:
  - `review_tests::a_toy_receipt_made_before_f12_is_refused`;
  - `trained_block::accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces`;
  - `trained_stack_tests::review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`.
  - 922 is A7's 919, plus A5's `requant_shift_form_equals_euclid` (the two lanes met in this tree), plus this lane's
    `a11_the_fork_pool_size_rule` and `a11_w16r2_rung_golden_inside_small_rayon_pools`. 99 ignored is A7's 98 plus
    `a11_w16r2_rung_digests_in_per_fork_pools_on_the_device`.
- **zkp-core's field tests:** 6 passed, `from_u128_is_the_canonical_residue_of_the_division` among them.
- **The A11 byte tests:** the seeded W16R2 rung in pools of 1, 2, 3 threads and on the global pool gives
  `96e4f0b6…` (CPU); three concurrent Metal proofs, each in its own pool of 1, 2 and 6 threads, give `96e4f0b6` nine
  times (`HL_GPU_REQUIRED=1`).
- **The A7 queue byte test** (`HL_GPU_REQUIRED=1`): `96e4f0b6` six times on the shared queue and six times on
  per-thread queues.
- **The W16R2 rung golden** (`HL_GPU_REQUIRED=1`): CPU = Metal = `96e4f0b6…`.
- **The six post-F12 trained digests** (`HL_GPU_REQUIRED=1`): 5a6193d3, f590b01f, 79f987ef, a8258241, 0e88d84f and
  90003b76 are all present.
- **The D55 harness on the final default** (`s10_d55.log`; `HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1
  HL_D55_PIPE=4`):

| W16R2 8B T128, 32 blocks, N = 6 | final tree (`s10_d55.log`) | A7's final tree, for reference (`../a7/s7_d55.log`) |
|---|---:|---:|
| proof only, the two calls | 4.418, 4.335 s | 5.328, 5.098 s |
| proof only, best / mean | 29.53 / 29.25 tok/s | 25.11 / 24.55 |
| one request from its input (sealed), best / mean | 8.088 s = 15.83 / 15.59 tok/s | 9.025 s = 14.18 / 14.11 |
| stream of 4, steady / amortized | 23.90 / 20.68 tok/s | 19.48 / 17.53 |
| per-request latency in the stream | 8.69, 10.19, 10.31, 10.03 s | 9.50, 12.19, 12.00, 11.89 |
| serial D12a, best / mean | 10.414 / 10.485 s | 10.866 / 10.884 |

- **Receipts:** every receipt the harness verifies verified (the D12a verifier on the first serial pass, the D55
  verifier on the first proof-only and sealed passes, all 4 stream receipts after the clock). Fork receipts
  818,728,672 B and D12a receipts 818,728,480 B, unchanged.
- The A7 column is another process on another day's box state; the in-process A/Bs of §5 are the measurement of
  the change. The two agree in direction and roughly in size.

**Stage 9** (`s9.sh`, `s9_*.log`), the same acceptance with the host-matrix pool still in the tree (off by default),
passed everything except five module audits, which a new production module fails until it is listed by review:
`hash_domain::tests::every_absorb_label_on_the_path_is_in_the_table`,
`s24_tests::the_capture_writer_pins_every_run_layer_source_it_depends_on` and three `s25_tests` ("the production
module graph of the path moved"). With F1 measured as no gain, the module was removed rather than listed (§3).

## 7. What was not done

- **The device slots' tables on the GPU.** The largest host region left (§2.4). It is a new device kernel set (a
  gather from the committed rows already in device memory, the eq tables, the folded planes), byte-preserving by exact
  field arithmetic, but a project of its own.
- **A8 (Gram-matrix folding of the store folds).** The folds were about 5% of a fork's main line before the fix, less
  than the pool effect, and A8 needs its own design (the same values from a different summation), so it was not
  attempted. After the fix they are about 8% of the main line (1,179 of 14,673 samples, `s6_sample_N6.summary.txt`),
  so A8 is now a better-placed next step than it was.
- **The verifier's fork threads** (`verify_run_with_forks`) still share the global pool. Not measured here; the same
  change may apply.
- **N = 8 with per-fork pools of 4**, against N = 6: a caller's choice (its worker count), not measured here.
- **The spin-wait:** `HL_METAL_SPIN_US` was not re-tested with the per-fork pools.
- **The page faults** are still about 1.2 M per call (the host-matrix pool, which halved them, did not pay and was
  dropped). If the host side shrinks enough for them to matter, reusing the big host buffers is the known cut.

## 8. Files

- `ops/zkp-mvp/gpu-metal/hashline/src/private_block/run_fork.rs`: `[A11]` the per-fork pools (the default) and their
  size rule; test-only: each fork's thread CPU and phase rows.
- `ops/zkp-mvp/gpu-metal/zkp-core/src/field.rs`: `from_u128` by `reduce128`, and its test.
- `ops/zkp-mvp/gpu-metal/hashline/src/private_block/timing.rs`: test-only `rows_for_test`.
- Tests: `run_fork_tests.rs` (the CPU meter, the phase sums, the sampler window, the A/B words, the alternating order,
  `a11_the_fork_pool_size_rule`); `w16r2_tests.rs` (the two rung tests).
- This directory: `s1.sh`–`s6.sh`, `s9.sh`, `s10.sh`, their logs, progress files and guard records; `run_stage.py`,
  `watch.py`, `pairs.py`, `sample_summary.py`, `sample_chains.py`, `sample_nesting.py`, `derive_s1.py`; the small
  extracts of the two sampler windows (`s1_*.summary.txt`, `s1_chains_*.txt`, `s1_nesting_*.txt`,
  `s6_sample_N6.summary.txt`, `s6_nesting_N6.txt`). The raw `sample` call graphs (68–119 MB) are not committed.

**For the privacy gate.** Changed digests: `run_fork.rs` and zkp-core's `field.rs` (production), `timing.rs`
(test-only code). `protocol.rs`, `private_block.rs`, `gpu/metal.rs`, `gpu/mod.rs` and `metal_kernels.metal` did
**not** change. The new code reads and keeps no value: the pools decide only which threads run the same work, and
`from_u128` returns the same word. `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.
