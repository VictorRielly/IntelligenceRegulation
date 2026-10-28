# ZKP efficiency progress

Cycle 0126 complete — `20261026T182925Z-b116a67c` — 2026-10-26 UTC.

**No proving speedup measured.** A CPU arithmetic model replaces repeated
round-interpolation denominators with fixed inverse factorials and finite
differences. It passes 6,244 checks: 108 fixtures, 1,836 evaluation
points and 40 synthetic masked sumcheck chains covering 120 rounds, plus ten
control types. A separate source/count audit passes 66 checks.
The checks use a separately authored Vandermonde/direct-cube oracle; the
transcript is a SHA256 mock. No native proof or privacy gate ran.

At degree 5, source-level work changes from 36 extension-field products and
six base-field inversions to five products and no inversions, adding 15
extension-field subtractions. The candidate adds a 96-byte stack buffer,
initialization/copy and dispatch. Compiler effects and end-to-end benefit are
unknown. The base R12 8B T128 block verifier has only 370 interpolation calls
(388 with DD32); this removes no dense cube scans, folds, commitments or masks.
The uncompiled, unapplied Rust patch is parked for native clocks.

Model: 1.096540 s / 15,268 KiB RSS;
audit: 0.004663 s / 17,332 KiB RSS. Both
used one Intel Core Ultra 9 185H CPU core, nice 19, 30-second CPU/alarm caps,
256 MiB address-space cap and a 64 MiB memory estimate. Diagnostic clocks only.
Seven primary-source records were appended from 13 LIVE result batches.
All 38 prior hypotheses remain; two were refined and one added.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context / accelerator: **none**. Witness, proof, serialization,
verification, startup and initial-prefill clocks; startup fraction; proof
latency/bytes; steady-state and total-workload rates: **unmeasured**. No long
prefill, resident-model proof series or decode ran. Larger workloads remain
allowed; attention can grow quadratically. The complete private 8B / >=50
proved tokens/s high-end GPU target remains unachieved.

Next owner action: native interpolation/constructor and enclosing proof clocks,
then verified fixed-context resident 1/2/4/8 workloads under shared locks.
Next local test: build the 256 distinct challenge-encoded lookup rows once
within each proof, then tile them, preserving fresh challenges and all refusals.

[Experiment](experiments/sumcheck-public-shape-20261026/README.md),
[dated report](progress/20261026T182925Z-b116a67c.md),
[handoff](handoffs/20261026-finite-difference-interpolation.md).
Saved reports do not establish user-message delivery or supervisor liveness.

Final integrity audit: 721 checks PASS; 78 immutable artifacts and 15 tested code pins match. Patch applies in memory only. Final checkpoint UTC: 2026-10-26T18:46:18.351388+00:00.
