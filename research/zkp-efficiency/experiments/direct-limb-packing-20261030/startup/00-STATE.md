# ZKP efficiency explorer — durable state

Cycle 0157 COMPLETE: `20261030T054123Z-a698c842`.
Started 2026-10-30T05:41:23Z; checkpoint 2026-10-30T05:51:31.603949+00:00.
Deadline06:01:23Z; next cycle no earlier than06:41:23Z.
Read AGENDA.md EVERY cycle.

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

Next: owner measurements of exclusive host packing, allocation, H2D,
kernel, D2H, conversion, synchronization and mutex-wait costs, with actual
current groups and enclosing independently verified workload time. If those
removable costs are negligible, park staging variants. A bounded local
follow-up can test safe direct c0/c1 packing into u64 staging to remove
per-rho temporary Vec allocations; it must not use raw Fp2 bytes.

The ranked global queue remains: (1) complete verified high-end GPU
workloads and fixed-context resident 1/2/4/8-pass measurements; (2) admitted
context/DD/fidelity scaling; (3) exclusive phase and allocated-capacity
clocks. Local tested candidate 85 and new safe-packing question 86 remain
below those priorities. All 84 prior hypothesis records are preserved
exactly; new records refine 84 without overwriting its historical status.
No additional staging variation should outrank native bottleneck evidence.

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

Read-only owner context: MVP_STATUS at 05:30 reports recovery after
a disk-full crash, re-verification of existing public classifier receipts,
durable app storage and a testnet anchor. D46 adds drive/memory safeguards.
The decisions register's 02:13 classifier re-review still names C-7/C-8/C-9
conditions and says it is not a privacy acceptance. These are owner reports,
not reproduced or newly counted here; they do not amend the private 8B
target. No supervisor/job liveness is inferred and no heavy run duplicated.

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

Prior state/docs/results and history pins: experiments/hybrid-opening-budget-20261030/startup-index.json.
Sources1038→1045; all84prior hypotheses exactly preserved,85tested/86new.
Seven source records include dates/nulls,licenses and exactfetch blockers.

[Experiment](experiments/hybrid-opening-budget-20261030/README.md) · [Handoff](handoffs/20261030-hybrid-opening-budget.md) · [Dated report](progress/20261030T054123Z-a698c842.md).

Only research files outside runtime were written. No production,
Git metadata/operations, receipts, calibration, instructions, safety gates
or reviewer files changed. No GPU job, native build, install, downloaded
script execution, external write/message, purchase, escalation or merge.
Saved reports do not establish delivery to the user or supervisor liveness.

Closing document recheck: the decisions register changed during this cycle.
D47 (05:46 UTC) holds funding applications until Victor has a partner;
D48 (05:48 UTC) widens the intended open-source scope and removes the prior
patent-before-publication prerequisite. The diff is retained in
concurrent-decisions.diff. Neither changes the private 8B throughput target
or authorizes this research lane to publish, send messages or modify
production. No such action was taken.
