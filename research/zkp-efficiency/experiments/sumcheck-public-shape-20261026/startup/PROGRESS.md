# ZKP efficiency progress

Cycle 0125 complete — `20261026T172925Z-dd337876` — 2026-10-26 UTC.

**No proving speedup measured.** A CPU model fuses leaf salting with the first
Merkle parent level while preserving every node and path. It passes 19,952 checks
across 120 synthetic cases, all 3,825 paths and 17 controls against the installed
independent BLAKE3 implementation. A separate cost/source audit passes 16,733
checks with 12 source pins. Both run on one core, under 1.3 seconds and 17 MiB RSS.
These are diagnostic clocks, not proving clocks.

The counted saving is 2 MiB (T128) or 4 MiB (T512) of logical reads per frozen R9
A/H commitment. No hashes or retained bytes disappear. Zero-filled output buffers
erase the saving. GPU construction adds transfers if all paths remain on the host.
An uncompiled, unapplied Rust patch and handoff are parked pending native clocks.
Ten LIVE queries produced eight source records. All 37 previous hypotheses remain;
two were refined and one added. Whole-prover GPU work retains priority.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context / accelerator: **none**. Device: one Intel Core Ultra 9 185H
CPU worker. Witness, proof, serialization, verification, startup and initial-prefill
clocks; startup fraction; proof latency/bytes; steady-state and total-workload
rates: **unmeasured**. No prefill, resident-model proof series or decode ran.
T128/T512 are geometry counts only; T512 is unregistered and LOW/HIGH layouts are
excluded. Larger workloads remain allowed; attention can grow quadratically.
The private 8B / >=50 proved tokens/s high-end GPU target remains unachieved.

Next owner action: measure salt/tree/path/transfer clocks and verified resident
1/2/4/8 workloads under shared locks. Next local action: audit repeated public
preprocessing in sumcheck/GKR, consulting prior cache and fraction-tree negatives.

[Experiment](experiments/commitment-salted-merkle-20261026/README.md),
[dated report](progress/20261026T172925Z-dd337876.md),
[handoff](handoffs/20261026-salted-merkle-fusion.md).
Saved reports do not establish delivery or supervisor liveness.

Final evidence audit: 1,477 checks PASS; 77 immutable artifacts, 12 source pins and required project-memory pins match. All 799 prior sources, 37 prior hypotheses and the full prior findings prefix remain. The patch applies in memory only; no native build/proof/GPU ran. Final checkpoint UTC: 2026-10-26T17:43:15.990147+00:00.
