# ZKP efficiency progress

Cycle 0127 complete — `20261026T192925Z-2a61ec3c` — 2026-10-26 UTC.

**No proving speedup measured.** A synthetic experiment builds the 256 distinct
exp/activation rows with fresh proof challenges, then copies them into the
longer public table. It passes 3,353 checks across 204 cases and 2,264,184
output entries. A separate source/cost audit passes 158 checks.

At current R12 T128, the pair's source-level Fp2 products fall from 32,768
to 512. Its 524,288-byte output stays the same, and copying adds 354,816 net
logical read bytes per pair. Native timing is needed to resolve this tradeoff.
The research patch is uncompiled and unapplied; R13 LOW+h24 is excluded.

Checking clocks: model 9.169534 s / 56,076 KiB RSS; source audit 0.010463 s /
16,976 KiB RSS. One Intel Core Ultra 9 185H worker, nice 19, 30-second CPU/alarm
cap, 256 MiB address-space cap and 96 MiB memory estimate. No GPU use.

Seven primary-source records append the ledger to 821. LIVE search covered
Celer, current SP1 releases/GPU LogUp-GKR, Logup*, Rust's copy API and a blocked
TenseUp refresh. Celer's prototype explicitly omits blinding, so it fails the
privacy compatibility filter. No author benchmark was reproduced. All 39
prior hypotheses remain; two were refined and two added.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context / accelerator: **none**. Witness, proof, serialization,
verification, startup and prefill clocks; startup fraction; proof latency/bytes;
steady-state and total-workload rates: **unmeasured**. No long prefill, resident
proof series or decode ran. Longer workloads remain allowed; attention can
grow quadratically. The private 8B / >=50 proved tokens/s target is unachieved.

Next owner action: native constructor, SC_TAB and enclosing proof clocks;
correctness/privacy gates if material; then verified resident 1/2/4/8 workloads
under shared locks. Next local test: actual periodic SC_TAB descriptors,
including full Fp2 points, extension, terminal and refusal controls.

[Experiment](experiments/lookup-row-tiling-20261026/README.md),
[handoff](handoffs/20261026-fresh-lookup-row-tiling.md),
[dated report](progress/20261026T192925Z-2a61ec3c.md).
Only research outside runtime written. Saved reports do not establish user
notification or supervisor liveness. Checkpoint UTC: 2026-10-26T19:43:01.123699+00:00.

Final evidence audit: 731 checks PASS; 50 immutable artifacts and 9 tested current native pins match. Two patch hunks apply in memory only. All 814 prior sources, 39 prior hypotheses and prior findings preserved. Final checkpoint UTC: 2026-10-26T19:44:02.280925+00:00.
