# A7: GPU timestamps and command queues (2026-11-05)

The plan: `docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A7 (H121). Byte-preserving.

Labels: [MEASURED] a number from a log in this directory; [INFERRED] derived from measured numbers.

## Plain summary

- **The fork run is not GPU-bound.** Over the forks phase of one W16R2 8B T128 request (32 blocks, N = 6 forks):
  - the GPU executes at least one command buffer only **53–59%** of the time; the rest is idle;
  - each fork thread spends about **60%** of its time on the host, between command buffers;
  - about 20 of the 32 cores are busy on average [MEASURED].
- **The shared queue does not serialise the GPU, but it caps it.**
  - Command buffers from the one process-wide queue overlap, but never more than 3 run at once.
  - A finished command buffer is seen complete **1.7 ms late** on average, in order behind the others.
  - Per-thread queues (opt-in) remove both: up to 6 at once, and **0.2 ms**.
- **Per-thread queues do not speed up the D55 wall, so they are not the default** [MEASURED, interleaved in one
  process, with the arm order run both ways]:
  - the proof-only fork run: about **+1.4%** (no gain);
  - the 4-request stream's steady state: about **−2.7%** (a small loss).
  - The default stays the shared queue. `HL_METAL_QUEUES=thread` is an opt-in, kept for later work (it is the
    shape the 5090 port needs).
- **A trap for later A/Bs:** in this harness the second arm of a pass ran about **4.5% faster**, whichever arm it
  was. My first conclusion, a 5.6% gain from per-thread queues, was that bias. Every in-process A/B must run both
  orders.
- **What limits the fork run now:** the fork threads' host work, about 0.5 s per block under six-way contention
  against 0.22 s uncontended. A6 was conditional on the kernels dominating, so it was **not implemented**. Its census
  found an exact, cheap cut for later (§6).
- **What changed by default: nothing.** The wait, the queue and the fold behave as before A7. What is new:
  - the diagnostics (GPU timeline, CPU meter, the in-process policy A/B);
  - two opt-ins: `HL_METAL_QUEUES=thread` and `HL_METAL_SPIN_US=n`.

## 1. What was added

**The GPU timeline** (`gpu/metal.rs`, `[A7]`). It is a diagnostic and never changes a byte. While it is on, every
completed command buffer records:
- its `GPUStartTime` and `GPUEndTime` (host time, seconds);
- the issuing thread, its queue and the call site (`commit`, `batch`, `round`, `fold`, `gather`, `devfold`, `wprod`);
- the host times at which it was begun, committed and seen complete.

The times are read after completion. When the timeline is off, the cost is one relaxed atomic load per command
buffer. `gpu_timeline_report` turns a window into:
- busy time (at least one command buffer executing) and idle time;
- the time at k command buffers at once;
- the idle gaps by size;
- per call site: GPU time, commit → GPU start, and GPU end → seen;
- per thread: the time in `run` against the host time between command buffers;
- per queue: whether its command buffers overlapped.

**In the D55 harness** (`run_fork_tests.rs`, test-only):
- `HL_D55_TIMELINE=1` reports the whole call and the forks phase (`[h0 + preflight + commit, + forks]`) of every timed
  call;
- every fork call prints the process's CPU-seconds (`getrusage`);
- `HL_D55_GPU_AB=<arm>,<arm>,...` runs an in-process A/B of GPU policies over `HL_D55_AB_PASSES` passes, interleaved,
  with optional sealed (`HL_D55_AB_SEALED=1`) and stream (`HL_D55_AB_PIPE=R`) arms; every stream receipt is verified.
  The arm words are `shared`/`thread`, `spin`/`block`/`spin<us>` and `hostfold`/`devfold`. **The arms run in the given
  order in every pass, so run each A/B in both orders** (§3).

**Queues** (`HL_METAL_QUEUES`):
- `shared` is the one process-wide queue, and **still the default**;
- `thread`, the opt-in, gives every thread its own queue. The queue is made at the thread's first command buffer and
  released when the thread ends; if Metal returns none, the thread uses the shared queue.
- The A4 witness products keep their own queue.

**Wait** (`HL_METAL_SPIN_US=n`, opt-in): spin `n` µs on the status, then block. The default (spin) and
`HL_METAL_SPIN=0` (block) are unchanged.

**Why no byte can move, in any mode.** `run_tagged` still waits for every command buffer on the thread that made it
before that thread goes on. So every later command buffer, on any queue, is committed after the earlier one completed,
and no read can run ahead of a write. The queue and the wait decide only which waiting command buffers the GPU may run
side by side, and how the host notices one finished. Device arithmetic, dispatch order inside a command buffer,
buffers and the transcript are all unchanged.

## 2. The measurement: GPU busy against wall [MEASURED]

W16R2 8B T128, 32 blocks, `HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_WORKERS=6`. Logs `s1_d55.log` and
`s2_d55.log`; every call's row is in `timeline_summary.md` (`summarize.py`).

**Uncontended, the serial D12a arm** (one thread, 32 blocks, 10.9–11.4 s per call):
- the GPU is busy 3.18–3.20 s (28–29%), that is **0.099 s of GPU per block**;
- the sumcheck batches take 2.19 s (68 ms per block), the commitments 0.99 s and the gathers 0.006 s;
- the host between command buffers is 7.0 s, about 0.22 s per block.

**The forks phase, N = 6, shared queue (the default)** (`s1`, `s2`; 8 calls):
- **The GPU is busy 2.79–2.85 s, 53–59% of a 4.8–5.3 s forks phase; it is idle 1.9–2.5 s.**
- At most **3** command buffers execute at once: the time at 1, 2 and 3 at once is about 0.7, 0.9–1.0 and
  1.0–1.15 s.
- 315–323 of about 515 command buffers start before the queue's earlier ones have all ended. So the one queue does
  not serialise them.
- **GPU end → seen**, summed over the phase: 0.68–0.97 s, about 1.7 ms per command buffer. Completions are noticed in
  order, behind longer command buffers that started earlier.
- **Commit → GPU start**, summed: 2.5–3.4 s. A batch waits 5–6 ms on average.
- Each of the six fork threads, over about 4.0–4.6 s active:
  - in `run` 1.4–1.9 s (GPU 0.86–1.18 s);
  - **host between command buffers 2.5–2.9 s, about 60%** (3.3 s in a process's first fork call);
  - that is about 0.47–0.62 s of host work per block, against 0.22 s uncontended.
- The process keeps 18–21 of 32 cores busy on average (the `D55-AB A7 CPU` lines).

**The gaps** (shared queue):
- 190–230 idle gaps per forks phase. 94–117 of them are 5 ms or longer, and they make up 1.77–2.30 s of the 1.94–2.52
  s idle.
- Gaps under 1 ms total under 15 ms.
- So the GPU is idle when every fork thread is on the host at once, not between a fork's rounds. The round latency and
  the one-threadgroup transcript kernel of H113 sit *inside* a command buffer and leave no gap at the command-buffer
  level.
- The longest gap is 0.17–0.22 s. It matches the phase's ramp, when all six forks build their A rows on the host
  before their first commitment [INFERRED].

**The same with per-thread queues** (opt-in, spin; 5 calls, `s1`, `s2`):
- GPU busy 61–64%;
- up to 6 command buffers at once (7 at N = 8);
- GPU end → seen 0.09–0.15 s summed, about 0.2 ms each;
- host between command buffers per thread unchanged, 2.3–2.8 s.

The union of GPU-busy time is the same, about 2.8 s, in both modes. It is the work, not the queue.

## 3. Does the queue change the wall? The interleaved A/B, both orders [MEASURED]

Each pass of `HL_D55_GPU_AB` runs the arms in order, in one process. The paired changes (per-thread against shared,
within a pass) come from `pairs.md` (`pairs.py`):

| Metric (N = 6) | shared first: stages 1, 2, 4, 5 | per-thread first: stage 6 | order bias solved out [INFERRED] |
|---|---|---|---|
| proof-only fork run, wall | **−3.2%** (13 pairs, 11 favour per-thread) | **+5.9%** (5 pairs, 1 favours per-thread) | per-thread **+1.4%**; the second arm of a pass **4.5% faster** |
| stream of 4, steady-state tok/s | **−1.9%** (8 pairs, 1 favours per-thread) | **−3.4%** (5 pairs, 0 favour) | per-thread **−2.7%** |
| stream of 4, amortized tok/s | −0.6% (8 pairs) | −1.6% (5 pairs) | per-thread −1.1% |
| one request from its input (sealed), wall | −0.9% (3 pairs, stage 4) | — | not resolved |

**The stage 5 and 6 values** (5 passes each, proof only and stream):

| | shared | per-thread |
|---|---:|---:|
| stage 5, shared first: proof only, mean | 5.223 s | 5.103 s |
| stage 5: stream steady, mean | 19.31 tok/s | 18.93 |
| stage 6, per-thread first: proof only, mean | 4.905 s | 5.195 s |
| stage 6: stream steady, mean | 20.24 tok/s | 19.55 |

**Reading:**
- On this box the per-thread queues buy no D55 wall, and they cost the stream a little.
- **A plausible mechanism for the stream loss** [INFERRED]: per-thread queues let a request's fork run take more of
  the GPU, up to 6 command buffers at once instead of 3. The next request's sealing pass, whose witness products run on their
  own queue, gets less. The stream's cadence is set by the sealing pass and the forks contending.
- The order bias (about 4.5% for the second arm of a pass) is unexplained. Every A/B in this directory before stage 6
  ran shared first.

**What the bias leaves unresolved.** These earlier A/Bs ran their arms in one order only:
- **spin against block against spin-200:** block and spin-200 save 8–10 CPU-seconds per call; the wall difference is
  within the bias. The default stays spin, which M5d measured best for one thread.
- **The device row fold:**
  - it moves about 0.5 s per thread of host fold onto the GPU (GPU busy 78%);
  - its own kernels cost more GPU than that, and commit → start grows;
  - measured −2.7% against per-thread spin, but as the fifth arm. It stays off. A8 (Gram folding) is the better route
    to that work.
- **N = 8 against N = 6:** 32 = 4 × 8, while N = 6 leaves a two-block tail.
  - Proof-only N = 8 ran 4.6–4.9 s against N = 6's 4.8–5.4 s.
  - But N = 8 always ran second within each arm.
  - Promising; it needs a both-orders A/B before any caller changes its worker count.

## 4. The D55 figures, before and after [MEASURED]

The default is unchanged by A7, so "after" runs the same code path as before. The final tree's figures are in
`s7_d55.log` (§5). For reference, stage 3 ran three separate processes, one after another, with
`HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1 HL_D55_PIPE=4` (2 calls per arm, 1 stream):

| | shared queue (`s3_d55_before.log`) | per-thread (`s3_d55_after.log`) | per-thread + spin 200 µs (`s3_d55_spin200.log`) |
|---|---:|---:|---:|
| proof only, the two calls | 5.213, 5.056 s | 5.061, 5.570 s | 5.137, 4.909 s |
| proof only, best / mean | 25.32 / 24.93 tok/s | 25.29 / 24.08 | 26.07 / 25.48 |
| one request from its input (sealed), best / mean | 9.551 s = 13.40 / 13.38 tok/s | 9.423 s = 13.58 / 13.52 | 9.125 s = 14.03 / 13.78 |
| stream of 4, steady / amortized | 19.32 / 17.37 tok/s | 18.47 / 16.86 | 19.28 / 17.22 |
| per-request latency in the stream | 9.60, 12.07, 12.21, 12.03 s | 9.58, 12.42, 12.36, 12.03 | 9.82, 11.99, 12.10, 11.86 |
| serial D12a, best / mean | 10.676 / 11.019 s | 10.763 / 10.987 | 10.873 / 10.985 |

Separate processes cannot resolve these differences. The after run's second proof-only call was slow in every phase,
preflight included (0.103 against 0.074–0.082 s). Today's streams give 18.5–20.8 tok/s steady across all runs. A4
measured 20.4–20.7 on this harness.

Every receipt the harness verifies was verified, in every D55 run in this directory:
- the first warm pass of every arm (the D12a verifier; the D55 verifier on 6 threads);
- every stream receipt, after the clock;
- in stages 4–6, every stream of every A/B pass.

Fork receipts are 818,728,672 B and D12a receipts 818,728,480 B, unchanged.

## 5. Acceptance [MEASURED]

**Stage 7** (`s7.sh`, `s7.progress`, `s7_*.log`) is the final tree, with the shared queue as the default. One guarded
job:
- **build:** rc 0. The **no-feature `cargo check --tests`** (no `gpu-metal`) is rc 0.
- **The full lib suite** (`--test-threads=8`, the R13 loader fixtures): **919 passed, 3 failed, 98 ignored**. The
  three failures are exactly the known ones (below). 98 ignored is A4's 96 plus this lane's two new ignored tests.
- **The A7 queue byte test** (`HL_GPU_REQUIRED=1`): six concurrent seeded W16R2 rung proofs give `96e4f0b6` six times
  on the shared queue and six times on per-thread queues. The timeline's clock order holds, and each thread used its
  own queue in `thread` mode.
- **The W16R2 rung golden** (`HL_GPU_REQUIRED=1`): CPU = Metal = `96e4f0b6…`.
- **The six post-F12 trained digests** (`HL_GPU_REQUIRED=1`, R13 / W16 / W16R2 at Shieldstral and 8B): 5a6193d3,
  f590b01f, 79f987ef, a8258241, 0e88d84f and 90003b76 are all present.
- **The D55 harness on the final default** (`s7_d55.log`; `HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1
  HL_D55_PIPE=4`):

| W16R2 8B T128, 32 blocks, N = 6 | final tree (`s7_d55.log`) | A4 merge, for reference (`../a4merge_d55.log`) |
|---|---:|---:|
| proof only, the two calls | 5.328, 5.098 s | — |
| proof only, best / mean | 25.11 / 24.55 tok/s | — |
| one request from its input (sealed), best / mean | 9.025 s = 14.18 / 14.11 tok/s | 13.8 tok/s |
| stream of 4, steady / amortized | 19.48 / 17.53 tok/s | 20.4 steady |
| per-request latency in the stream | 9.50, 12.19, 12.00, 11.89 s | — |
| serial D12a, best / mean | 10.866 / 10.884 s | — |

- **Receipts:** every receipt the harness verifies verified:
  - the D12a verifier on the first serial pass;
  - the D55 verifier on the first proof-only and the first sealed pass;
  - all 4 stream receipts after the clock.
- Fork receipts are 818,728,672 B and D12a receipts 818,728,480 B, unchanged.
- **The default path is the pre-A7 path.** Shared queue, spin wait, host fold; the timeline off costs one atomic load
  per command buffer. So these figures are the box's state today, not an A7 effect. The A4-merge figures are from an
  earlier box state.

**Earlier acceptance runs, with per-thread queues as the default** (`s3.sh`, and `s4.sh` after a harness-only change):
- build and the no-feature `cargo check --tests`: rc 0.
- **The full lib suite**: **919 passed, 3 failed, 98 ignored**, twice (`s3_full.log`, `s4_full.log`). The three
  failures are exactly the known ones:
  - `review_tests::a_toy_receipt_made_before_f12_is_refused`;
  - `trained_block::accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces`;
  - `trained_stack_tests::review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`.
- 98 ignored is A4's 96 plus this lane's two new ignored tests.
- **The A7 queue byte test** (`HL_GPU_REQUIRED=1`): six concurrent seeded W16R2 rung proofs give `96e4f0b6` six times
  on the shared queue and six times on per-thread queues. Each thread used its own queue, and the timeline's clock
  order holds.
- **The W16R2 rung golden** (`HL_GPU_REQUIRED=1`): CPU = Metal = `96e4f0b6…`.
- **The six post-F12 trained digests** (`HL_GPU_REQUIRED=1`): 5a6193d3, f590b01f, 79f987ef, a8258241, 0e88d84f and
  90003b76 are all present.

## 6. A6: not implemented; what its census found

A6 was conditional on A7 showing that the kernels dominate. They do not: the GPU is idle about 40% of the forks phase,
and the fork threads are on the host 60% of the time. The census
(`range16_tests::effplan_a6_census_of_the_device_slots`, `s2_census.log`, CPU only) is there for whoever takes it up.

**Slot 18 attains a lower degree than it declares.** Slot 18 is the F zero-check: 2^21 × 19 tables, the largest slot,
about 18% of a block. Its IR attains **degree 4** at W16R2 8B T128, but its declared degree, and so the round message,
is **5**. The same holds for slots 14 and 18 at the W16R2 rung. A round polynomial of degree ≤ 4 is fixed by its values
at 0..4, so its sixth value follows exactly:

    s(5) = s(0) − 5 s(1) + 10 s(2) − 10 s(3) + 5 s(4)

This is the same field element the device evaluates today. The IR's attained degree is a formal bound that holds for
any table values, because every table is affine along a pair's line.

So the device evaluates **one point more than it needs to**:
- later rounds: 4 points instead of 5 (−20% of slot 18's round kernel);
- round 0: 5 instead of 6.

That is about 5 ms of GPU per block [INFERRED: one fifth of slot 18's 25.9 ms device clock,
`handoffs/20261101-gpu-work-per-block.md`].

This is the "point at infinity" idea in its strongest form: the leading coefficient is identically zero, so no
infinity point needs evaluating either.

**Where it would go:**
- the generated kernel's point count (`metal_slot.rs`);
- the grid in `MetalRounds::round` and `batched_rounds` (`metal.rs`);
- `k_sc_part_reduce` and `k_sc_fs_step`, which recover s(D) after s(1) (`metal_kernels.metal`, pinned);
- the host sum of the unbatched path.

The host replay already checks every device round.

**Expected effect today:** under 1% of the D55 wall, since the GPU is not the limit. It matters once the host side is
cut, or on the 5090. The other slots attain their declared degrees; their term-degree histograms are in the census.

## 7. Files

- `gpu/metal.rs` [pinned] (`[A7]` sections):
  - `run_tagged` and the call-site tags;
  - the queue modes (`shared` the default, `thread` the opt-in);
  - the GPU timeline;
  - the wait policy (`HL_METAL_SPIN_US`);
  - the test hooks for the queue mode, the wait and the device fold.
- `gpu/mod.rs` [pinned]: test-only re-exports. The production build is unchanged in behaviour, but the file's digest
  moves.
- Tests:
  - `private_block/run_fork_tests.rs`: the harness timeline, the CPU meter and the GPU-policy A/B with sealed and
    stream arms;
  - `private_block/w16r2_tests.rs`: the six-thread queue byte test;
  - `private_block/range16_tests.rs`: the A6 census.
- This directory:
  - `run_stage.py` (the detached guarded runner);
  - `s1.sh` – `s7.sh` and their logs, progress files and guard records;
  - `summarize.py` → `timeline_summary.md`;
  - `pairs.py` → `pairs.md`.

**For the privacy gate.** Two pinned files changed digest: `src/gpu/metal.rs` and `src/gpu/mod.rs`.
`metal_kernels.metal` did **not** change. The new code:
- reads only command-buffer timestamps, the thread's serial number and the queue identity;
- prints no value;
- keeps no value;
- changes no buffer.

`D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.
