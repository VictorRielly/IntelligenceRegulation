# Cycle 0157 — hybrid opening staging under a public scratch budget

Run `20261030T054123Z-a698c842`; started 2026-10-30T05:41:23Z; checkpoint 2026-10-30T05:51:31.603949+00:00.

**No measured proving improvement.** A public-budget hybrid stages all
supplied row-weight vectors once while retaining max-four output scratch.
It passed 388 synthetic Rust fixtures, 1,567 budget checks/controls and all
25 injected synchronous failure points. Python bigint references matched
1,764 Rust planner cases and 3,648 output limbs in 16 exported fixtures.

For a conditional historical T128 A opening with 57 vectors, H2D submissions
fall from 15 to 1 and device scratch allocation requests from 30 to 2.
Hybrid requested scratch is 4,256,080 B versus 1,273,664 B for serial reuse
and 18,149,712 B for full staging. D2H calls, launches, matrix scans,
arithmetic and transfer payload bytes are unchanged. These are synthetic
capacity/API counts, not native elapsed savings.

The 388 fixture dimensions cover rows 0/1/7/33, widths 1/3/17,
vector counts 0/1/4/5/12/13/57/59 and four synthetic value patterns;
four additional actual-row-count fixtures use width three. Patterns include
P-1, pure-imaginary and protected-tail inputs. Every fixture checks four
budget choices, including exact thresholds and one-byte-below. The native
host fold body (only parallel iteration made serial) and field are pinned.
The independent Rust reference uses u128 modular arithmetic; Python uses
unbounded whole sums. Three synthetic pad columns are checked with the
native host body; these are not generated PCS pads.

All 25 simulated allocation/upload/kernel/download failures return Err,
stop further work and release tracked scratch. Negative controls change
vector ordering, omit the final vector, reuse stale vector offsets, swap
extension limbs, mutate three protected tail rows and use a fresh call.
The plan oracle includes usize overflow, zero edges, insufficient budget
and full-staging-overflow with bounded serial fallback. This is a scratch
planner, not admission for zero rows, odd widths, extreme dimensions or
native i32/u32 launch casts. The 8,261 Python assertions include descriptor
capacity checks; the assertion count is not security evidence.

No real CUDA execution, pointer ABI, async error/panic/cancel handling,
Fiat–Shamir transcript, native refusal channel, receipt bytes, full-stack
proof or privacy acceptance was tested. The references are independently
authored in this lane, not externally reviewed. Output shadow copies and
sentinels are correctness instrumentation, outside the tracked device
scratch model. Actual allocator capacity, host flatten/output/conversion
coexistence, device peak and cancellation ownership remain unmeasured.

| Historical role | k / chunks | Serial scratch B | Hybrid scratch B | Full scratch B | H2D calls, baseline → hybrid |
|---|---:|---:|---:|---:|---:|
| A_nonDD | 57 / 15 | 1,273,664 | 4,256,080 | 18,149,712 | 15 → 1 |
| H_nonDD | 12 / 3 | 1,257,984 | 1,676,800 | 3,773,952 | 3 → 1 |
| A_DD | 59 / 15 | 1,265,856 | 4,253,456 | 18,671,376 | 15 → 1 |
| H_DD | 13 / 4 | 1,248,000 | 1,696,704 | 4,056,000 | 4 → 1 |

For B=ceil(k/4), hybrid scratch is
`16*(k*rows + min(k,4)*n)` requested bytes; serial reuse needs
`16*min(k,4)*(rows+n)`. It uploads `16*k*rows` bytes and downloads
`16*k*n` bytes, with B unchanged kernels/matrix scans. The public budget
limits only tracked requested device scratch, excluding matrix storage,
allocator rounding, pads, host output, host flattening and runtime state.

Installed cudarc synchronous copy wrappers explicitly call synchronize.
Hybrid therefore reduces copy-wrapper sync requests from 2B to B+1;
this is not a measurement of saved device wait time or guaranteed overlap.
The native field Fp2 has no repr(C); direct raw struct-byte upload lacks an
ABI guarantee. The batch API is absent from configured 12.4 bindings.
Keep explicit limb packing and do not change representation/dependencies.

Eliminated work is limited to repeated allocation and upload submissions;
added costs are full-rho staging, offsets, possibly wider mutex lifetime,
earlier validation and host/device capacity. Complete-workload ceiling:
`N/(T-C_removed_exclusive+A_added)`. Free removal of exclusive fraction f
is bounded by `1/(1-f)`; f is unknown. No numerical private 8B GPU rate
follows. Falsify on negligible exclusive cost, failed capacity admission,
packing/mutex overhead erasing savings, or any native limb/order/pad/
proximity/lifetime/refusal/receipt/privacy mismatch.

Integration seam (review only): zkp-core/src/pcs.rs::fold_rows_multi_zk
already receives the complete ordered list, including fresh proximity.
The previous cycle's optional EncodedStore::fold_rows_opening default hook
can retain chunks-of-four behavior. A CUDA override would call a checked
opening-local plan, allocate rho/output scratch, upload explicit u64 limbs,
pass checked rho views to the unchanged max-four k_fold_rows kernel and
download each completed output prefix before reuse. Existing cudarc
htod_sync_copy_into/dtoh_sync_copy and slice APIs provide the required
synchronous primitives. The native override was not implemented/applied.
Prototype and patch location: hybrid.rs plus the prior cycle's
opening-hook-review-only.patch. Main/Claude reviews and integrates.

Budget selection uses only public shapes and configured scratch bytes;
select serial fallback before any device work. Never retry a failed launch
as fallback. Preserve every mask, pad, proximity vector, RNG draw, transcript
message and refusal/publication rule. Do not retain private-derived buffer
contents across openings/proofs. Optimized preflight and a wider mutex
lifetime may change malformed-input error timing and scheduling, which
owner native gates must check.

The ranked global queue remains: (1) complete verified high-end GPU
workloads and fixed-context resident 1/2/4/8-pass measurements; (2) admitted
context/DD/fidelity scaling; (3) exclusive phase and allocated-capacity
clocks. Local tested candidate 85 and new safe-packing question 86 remain
below those priorities. All 84 prior hypothesis records are preserved
exactly; new records refine 84 without overwriting its historical status.
No additional staging variation should outrank native bottleneck evidence.

Seven native LIVE primary-source records were appended (1,038 → 1,045).
The newly assessed older technique is CUDA 12.8 batched copying, documented
January 23, 2025: copies inside a batch are unordered, so dependent copies
are unsafe. The independent two-copy negative control shows aliasing
destinations produce schedule-dependent outputs. The inspected current
cuDF wrapper uses CUDA 13+ and explicit source lifetimes. Neither is a
drop-in for native cudarc 0.13.9 configured with CUDA 12.4 bindings.

The newly found October 20, 2026 ZKPU paper evaluates a cycle-accurate
simulator and synthesized hardware; it supplies no RTX 5090 result. MegaZK,
ZKProphet, the June NTT/SumCheck memory-budget comparison and a C++ CUDA
wrapper release were screened. No author performance was reproduced or
foreign code executed. Exact URLs, verified dates/nulls, inspected license
scope and fetch blockers are in sources-cycle.json and blockers.json. No
commit content was inspected: a wrapper release link resolved a full commit
target, but its fetch failed. Six of eight web response batches are saved;
the first two remain only in native tool history.

Primary sources: [CUDA 12.8 copying](https://docs.nvidia.com/cuda/archive/12.8.0/cuda-runtime-api/group__CUDART__MEMORY.html),
[cuDF copy implementation](https://raw.githubusercontent.com/rapidsai/cudf/main/cpp/src/utilities/cuda_memcpy.cu),
[ZKPU](https://arxiv.org/abs/2610.27530),
[MegaZK](https://github.com/THU-HAS/MegaZK),
[ZKProphet](https://arxiv.org/abs/2509.22684),
[NTT/SumCheck comparison](https://arxiv.org/abs/2606.16146),
[CUDA wrapper releases](https://github.com/eyalroz/cuda-api-wrappers/releases).

Read-only owner context: MVP_STATUS at 05:30 reports recovery after
a disk-full crash, re-verification of existing public classifier receipts,
durable app storage and a testnet anchor. D46 adds drive/memory safeguards.
The decisions register's 02:13 classifier re-review still names C-7/C-8/C-9
conditions and says it is not a privacy acceptance. These are owner reports,
not reproduced or newly counted here; they do not amend the private 8B
target. No supervisor/job liveness is inferred and no heavy run duplicated.

Next: owner measurements of exclusive host packing, allocation, H2D,
kernel, D2H, conversion, synchronization and mutex-wait costs, with actual
current groups and enclosing independently verified workload time. If those
removable costs are negligible, park staging variants. A bounded local
follow-up can test safe direct c0/c1 packing into u64 staging to remove
per-rho temporary Vec allocations; it must not use raw Fp2 bytes.

Seed 202610300541. One CPU affinity, nice 19, one Rust codegen unit;
40-second CPU limit, 45-second alarm, 50-second parent timeout, 384 MiB
address-space cap per leaf. Estimated compile memory 300 MiB, other stages
96 MiB. Compiler auxiliary thread count not measured; one CPU could run
at a time. Final execution clocks: compile: 1.979 s / 168,228 KiB maximum RSS; probe: 0.166 s / 12,012 KiB maximum RSS; audit: 0.066 s / 16,116 KiB maximum RSS.
These shared-host correctness clocks are not witness/prover/GPU benchmarks.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context: none; cost accounting uses historical T128 standalone
R14 f_e9 groups. Device: one affinity-pinned Intel Core Ultra 9 185H CPU
worker, no accelerator. Witness, proof, serialization, verification,
startup and initial-prefill clocks, startup fraction, proof latency/bytes,
steady-state and total-workload proved-token rates: **unmeasured**.
No long-context prefill, resident-model pass series or decode ran. Larger
workloads remain allowed; longer attention can grow quadratically.
Complete private 8B **>=50 proved tokens/s remains unachieved**.

Carried historical CPU 8B baseline, not rerun/reverified/newly counted:
T128, 32 layers, one 16-thread pass, GPU off; total 478.737 s, 0.267370
positions/s. prove_run 393.785 s contains witness 98.348 s and load
17.595 s. Preceding sealing 84.824 s includes overlapping load 27.151 s
and witness 80.897 s. Receipt 922,711,264 B; verification 42.709 s plus
13.681 s load. Serialization, startup fraction and steady slope unknown.
Do not sum nested/overlapping clocks as exclusive phases.

Only research files outside runtime were written. No production,
Git metadata/operations, receipts, calibration, instructions, safety gates
or reviewer files changed. No GPU job, native build, install, downloaded
script execution, external write/message, purchase, escalation or merge.
Saved reports do not establish delivery to the user or supervisor liveness.

Reproduce after reviewing source drift, one stage at a time:

```sh
python3 -B experiments/hybrid-opening-budget-20261030/run_bounded.py prepare
python3 -B experiments/hybrid-opening-budget-20261030/run_bounded.py compile
python3 -B experiments/hybrid-opening-budget-20261030/run_bounded.py probe
python3 -B experiments/hybrid-opening-budget-20261030/run_bounded.py audit
```

Do not rerun record.py or close.py: they append durable ledgers/reports.
Preparation copies current source into this experiment; reproduce in a fresh
research copy to preserve retained evidence.

Closing document recheck: the decisions register changed during this cycle.
D47 (05:46 UTC) holds funding applications until Victor has a partner;
D48 (05:48 UTC) widens the intended open-source scope and removes the prior
patent-before-publication prerequisite. The diff is retained in
concurrent-decisions.diff. Neither changes the private 8B throughput target
or authorizes this research lane to publish, send messages or modify
production. No such action was taken.
