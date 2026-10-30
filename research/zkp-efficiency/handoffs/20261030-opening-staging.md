# Opening-local max-four staging — review only

**No measured proving improvement.** Opening-local serial scratch reuse
passed 436 synthetic Rust fixtures in three modes, including ordered
outputs and synthetic pad columns. All 42 injected synchronous failures
released simulated scratch. Independent Python bigint and bounded
scheduling references passed.

In a conditional historical R14 T128 example with 57 row-weight vectors,
serial reuse reduces device scratch allocation requests from 30 to 2
while retaining 1,273,664 bytes of requested scratch. Full staging also
reduces upload/download submissions from 15 each to 1 each, but requests
18,149,712 bytes of scratch. Neither saves matrix scans, kernel launches,
arithmetic, transfer payload bytes, masks, pads or proximity work. These
are synthetic API/capacity counts, not native elapsed savings.

Interface: add `EncodedStore::fold_rows_opening(rhos)` with an ordered
chunks-of-four default; replace only the device arm of
`fold_rows_multi_zk`. CUDA may override using two fresh opening-local
buffers. Retain the current kernel, ordered weights, all mask/proximity
rows and the existing pad fold. The default hook alone has no performance
benefit. Do not apply while owner source holds persist.

Patch: [review-only diff](../experiments/opening-staging-20261030/opening-hook-review-only.patch).
Implementation model: [staging.rs](../experiments/opening-staging-20261030/staging.rs).
Validation: [result](../experiments/opening-staging-20261030/result.json),
[costs](../experiments/opening-staging-20261030/cost-study.json),
[lifetime model](../experiments/opening-staging-20261030/lifetime-study.json).
The exact additive native Sync trait compiles in the standalone harness.
No native crate or CUDA override was built; no production diff was applied.

Validation scope: 436 Rust fixtures x three staging modes, with 175,772
scalar limb outputs per mode including three synthetic pad columns.
There are 143 controls: 130 default-hook counts, one error-stop case, six
shape/overflow cases and six value/order/proximity-position/protected-row/
fresh-call controls. Sixteen exported synthetic vectors match 1,344
independent Python bigint limbs. The final Python audit has 130,564
assertions, mostly descriptor-bound checks.

The exact additive native `EncodedStore: Sync` trait compiles in a
standalone mock harness; its default retains max-four calls and first-error
propagation. The native crate and review-only patch were not built/applied.
The root and held R14 whole files differ, but the scalar field and extracted
host fold, ZK wrapper, device fold and kernel bodies match.

The abstract lifetime model enumerates four batches across three FIFO
engines. One guarded slot has one safe order; two guarded slots have 89.
Without the reuse dependency, 454/462 one-slot schedules and 225/462
two-slot schedules corrupt generation tags. Six error cutpoints require
queued uses to drain before release. This is a bounded scheduling model,
not a CUDA race or cancellation proof.

No real CUDA arithmetic, ABI, device memory, asynchronous error handling,
Fiat–Shamir transcript, generated PCS pads, receipt byte parity, native
refusal behavior or privacy acceptance was tested. References were authored
in this lane, not independently reviewed by an external party. Zero rows,
zero vector counts and odd widths are primitive edges, not admitted profiles.

Before integration, measure actual public opening groups and exclusive
allocation/copy/lock/kernel/conversion/destruction costs, actual capacity
and enclosing verified workloads. Current `secs_fold` mixes most phases
and excludes lock wait; rho upload bytes are missing locally. Added
synchronization, startup and drain remain charged. Use current owner locks.

Copy-into-preallocated API/ABI and real asynchronous errors are untested.
Keep storage alive through all queued uses and error/panic/cancellation;
full staging changes error cadence and mutex scope. Publish nothing on
failure and never retry a failed launch. Mode selection uses public shape
and capacity before work. No cross-proof private contents or blinding reuse.
Exact proof bytes, refusals, soundness/privacy and independent receipt
verification must pass owner gates. Falsify on negligible exclusive savings,
capacity/lock/workload regression or any parity/lifetime failure.

Next: test full challenge-vector staging with bounded max-four output
scratch, using a public byte budget and independent offset, overflow,
failure, pad and fresh-call controls. This hybrid is untested. Owner
measurements of exclusive allocation and transfer-submission costs take
precedence; if they are negligible, park staging work.

Global priorities remain: (1) owner-verified complete workloads on a
named high-end GPU, including resident-model 1/2/4/8-pass measurements;
(2) admitted context/DD/fidelity scaling; (3) exclusive phase/capacity
clocks. The complete-workload ceiling is
`N / (T - C_removed_exclusive + A_added)`. Free removal of an exclusive
fraction f is bounded by `1 / (1-f)`; f is unknown. No numerical 8B GPU
rate follows from the API counts.
