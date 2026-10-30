# Research handoff — hybrid opening staging, 2026-10-30

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

Next: owner measurements of exclusive host packing, allocation, H2D,
kernel, D2H, conversion, synchronization and mutex-wait costs, with actual
current groups and enclosing independently verified workload time. If those
removable costs are negligible, park staging variants. A bounded local
follow-up can test safe direct c0/c1 packing into u64 staging to remove
per-rho temporary Vec allocations; it must not use raw Fp2 bytes.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context: none; cost accounting uses historical T128 standalone
R14 f_e9 groups. Device: one affinity-pinned Intel Core Ultra 9 185H CPU
worker, no accelerator. Witness, proof, serialization, verification,
startup and initial-prefill clocks, startup fraction, proof latency/bytes,
steady-state and total-workload proved-token rates: **unmeasured**.
No long-context prefill, resident-model pass series or decode ran. Larger
workloads remain allowed; longer attention can grow quadratically.
Complete private 8B **>=50 proved tokens/s remains unachieved**.

[Experiment](../experiments/hybrid-opening-budget-20261030/README.md) · [Code](../experiments/hybrid-opening-budget-20261030/hybrid.rs) · [Source pins](../experiments/hybrid-opening-budget-20261030/source-pins.json).
