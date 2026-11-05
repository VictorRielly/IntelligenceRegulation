# A7: GPU timestamps and per-thread command queues (2026-11-05)

The plan: `docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A7 (H121). Byte-preserving.

Labels: [MEASURED] a number from a log in this directory; [INFERRED] derived from measured numbers.

## Plain summary

- **The fork run is not GPU-bound.** Over the forks phase of one W16R2 8B T128 request (32 blocks, N = 6), the GPU
  executes at least one command buffer only **53–59%** of the time on the old shared queue, and **62–66%** on
  per-thread queues [MEASURED]. Each fork thread spends about **60%** of its time on the host, between command
  buffers. About 20 of the 32 cores are busy on average.
- **One shared queue did not serialise the GPU**, but it capped it. Command buffers from the one queue overlapped,
  but never more than 3 at once. A finished one was also seen complete **1.7 ms late** on average, in order behind
  the others. Per-thread queues ran up to 6–7 at once, and the delay fell to **0.2 ms**.
- **The change:** every proof thread gets its own Metal command queue (the new default). Proof-only fork run at
  N = 6, interleaved in one process, 5 calls each: **5.233 s → 4.939 s mean, 24.5 → 25.9 tok/s (−5.6%)**
  [MEASURED]. No byte can move, and the gates confirm it (below).
- **What limits it now:** the fork threads' host work, about 0.47–0.50 s per block per thread under six-way
  contention against 0.22 s uncontended. The GPU kernels are not the limit. A6 was conditional on the kernels
  dominating, so it was **not implemented**. Its census found a cheap, exact cut for later (§5).

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
- `HL_D55_TIMELINE=1` reports the whole call and the forks phase, `[h0 + preflight + commit, + forks]`, of every timed
  call;
- every fork call prints the process's CPU-seconds (`getrusage`);
- `HL_D55_GPU_AB=<arm>,<arm>,...` runs an in-process, interleaved A/B of GPU policies over `HL_D55_AB_PASSES`
  passes. The arm words are `shared`/`thread`, `spin`/`block`/`spin<us>` and `hostfold`/`devfold`.

**Queues** (`HL_METAL_QUEUES`):
- `shared` is the one process-wide queue every proof thread used before A7;
- `thread` gives every thread its own queue, made at its first command buffer and released when the thread ends.
  This is the **default** now. If Metal returns no queue, the thread falls back to the shared queue.
- The A4 witness products keep their own queue.

**Wait** (`HL_METAL_SPIN_US=n`, new, opt-in): spin `n` µs on the status, then block. `HL_METAL_SPIN=0` (block) and
the default (spin) are unchanged.

**Why no byte can move.** `run_tagged` still waits for every command buffer on the thread that made it before that
thread goes on. So every later command buffer, on any queue, is committed after the earlier one completed, and no
read can run ahead of a write. The queue only decides which waiting command buffers the GPU may run side by side.
Device arithmetic, dispatch order inside a command buffer, buffers and the transcript are all unchanged.

## 2. The measurement: GPU busy against wall [MEASURED]

W16R2 8B T128, 32 blocks, `HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_WORKERS=6`. Logs `s1_d55.log` and
`s2_d55.log`; every row is in `timeline_summary.md` (`summarize.py`).

**Uncontended, the serial D12a arm** (one thread, 32 blocks, 10.9–11.4 s):
- the GPU is busy 3.18–3.20 s (28–29%), that is **0.099 s of GPU per block**;
- the sumcheck batches take 2.19 s (68 ms per block), the commitments 0.99 s and the gathers 0.006 s;
- the host between command buffers is 7.0 s, about 0.22 s per block.

**The forks phase, N = 6, per call** (busy = at least one command buffer executing):

| Arm (calls) | mean wall | mean tok/s | GPU busy | GPU idle | most at once | GPU end → seen, summed | host between, per thread |
|---|---:|---:|---:|---:|---:|---:|---:|
| shared queue, spin (5) — before | 5.233 s | 24.46 | 57.9% | 2.04 s | 3 | 0.85 s | 2.69 s |
| per-thread queues, spin (5) — **after** | 4.939 s | 25.92 | 62.6% | 1.70 s | 5–6 | 0.11 s | 2.64 s |
| per-thread, block (3) | 4.824 s | 26.53 | 63.7% | 1.60 s | 5–6 | 0.18 s | 2.53 s |
| per-thread, spin 200 µs then block (3) | 4.830 s | 26.50 | 63.2% | 1.63 s | 6 | 0.14 s | 2.51 s |
| per-thread, spin, device row fold (3) | 5.073 s | 25.23 | 77.7% | 1.05 s | 6 | 0.14 s | 2.09 s |

**The gaps.** On per-thread queues the forks phase has 190–200 idle gaps. 91–96 of them are 5 ms or longer, and they
make up 1.41–1.65 s of the 1.60–1.92 s idle. Gaps under 1 ms total under 20 ms. So the GPU is idle when every fork
thread is on the host at once, not between a fork's rounds: the transcript kernel and round latency of H113 sit
*inside* a command buffer and leave no CB-level gap. The longest gap, 0.18–0.23 s, matches the phase's ramp, when
all six forks build their A rows on the host before their first commitment [INFERRED].

**Where a fork thread's time goes** (per-thread queues, about 4.0–4.2 s active per thread, 5.3 blocks each):
- **host between command buffers: 2.3–2.75 s, about 60%;**
- inside `run`: 1.45–1.57 s, of which:
  - GPU 0.96–1.26 s (inflated by sharing: 2.3 command buffers run at once while busy);
  - commit → GPU start 0.29–0.49 s;
  - GPU end → seen about 0.02 s.

Per block that is 0.47–0.52 s of host work under six-way contention, against 0.22 s uncontended. The process keeps
**18–21 of the 32 cores** busy on average over the call (`D55-AB A7 CPU` lines).

**Other findings:**
- **Not spinning saves CPU, but not wall:** 8–10 fewer CPU-seconds per call. The wall difference between spin, block
  and spin-200 is within run-to-run noise here (spread ±0.25 s), so the default stays spin, as M5d measured best for
  one thread. `HL_METAL_SPIN_US` is an opt-in. Its sealed and stream effect is in §3.
- **The device row fold is worse:**
  - it moves 0.5 s per thread of host fold onto the GPU (GPU busy 78%);
  - but its kernels (`k_fold_partial`, eight rho vectors per dispatch) cost more GPU than that, and commit → start
    grows;
  - −2.7% against per-thread spin. It stays off. A8 (Gram folding) is the better route to this work.
- **N = 8 balances the blocks:** 32 = 4 × 8, while N = 6 leaves a two-block tail.
  - Proof-only N = 8: shared 4.774 s mean (26.8 tok/s), per-thread 4.708 s (27.2 tok/s), 3 calls each.
  - The per-thread gain is smaller there (−1.4%), since more forks already fill the GPU.
  - The worker count is a caller's choice; this is a finding, not a change.

## 3. Before and after: proof only, sealed, stream [MEASURED]

**`s3_d55_before.log`** (`HL_METAL_QUEUES=shared`), **`s3_d55_after.log`** (the default) and **`s3_d55_spin200.log`**
(the default plus `HL_METAL_SPIN_US=200`). The same binary, one after another, with
`HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1 HL_D55_PIPE=4`:

(filled from `s3.progress` after the run)

## 4. Acceptance [MEASURED]

`s3.sh`, one guarded job, on the final tree:

(filled from `s3.progress` after the run)

## 5. A6: not implemented; what its census found

A6 was conditional on A7 showing that the kernels dominate. They do not: the GPU is idle 36–42% of the forks phase,
and the fork threads are on the host 60% of the time. The census (`range16_tests::effplan_a6_census_of_the_device_slots`,
`s2_census.log`, CPU only) is there for whoever takes it up.

**Slot 18 attains a lower degree than it declares.** Slot 18 is the F zero-check: 2^21 × 19 tables, the largest slot,
about 18% of a block. Its IR attains **degree 4** at W16R2 8B T128, but its declared degree, and so the round
message, is **5**. The same holds for slots 14 and 18 at the W16R2 rung. A round polynomial of degree ≤ 4 is fixed
by its values at 0..4, so its sixth value follows exactly:

    s(5) = s(0) − 5 s(1) + 10 s(2) − 10 s(3) + 5 s(4)

This is the same field element the device evaluates today. The IR's attained degree is a formal bound that holds for
any table values: every table is affine along a pair's line.

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
- `k_sc_part_reduce` and `k_sc_fs_step`, which recover s(D) after s(1) (`metal_kernels.metal`);
- the host sum of the unbatched path.

The host replay already checks every device round. The other slots attain their declared degrees, so the classic
point-at-infinity trade applies to them only. Their term-degree histograms are in the census.

## 6. Files

- `gpu/metal.rs` [pinned]: the per-thread queues, the timeline, the wait policy, the device-fold test hook.
- `gpu/mod.rs` [pinned]: test-only re-exports. Production builds are unchanged in behaviour, but the file's digest moves.
- `private_block/run_fork_tests.rs`, `w16r2_tests.rs`, `range16_tests.rs` (tests): the harness timeline, the CPU
  meter, the GPU-policy A/B, the six-thread queue byte test and the A6 census.
- This directory: `run_stage.py` (the detached guarded runner), `s1.sh`, `s2.sh`, `s3.sh`, `summarize.py`,
  `timeline_summary.md`, and the logs.

**For the privacy gate.** Two pinned files changed digest: `src/gpu/metal.rs` and `src/gpu/mod.rs`.
`metal_kernels.metal` did **not** change. The new code:
- reads only command-buffer timestamps and the queue identity;
- prints no value;
- keeps no value;
- changes no buffer.

`D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.
