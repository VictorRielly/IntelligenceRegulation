# ZKP efficiency progress

Cycle 0133 complete — `20261029T025649Z-b1039010`, 2026-10-29 UTC.

**No native proving speedup measured.** The validator already reads only
weights outside their allowed support. At the inspected 8B shape, that is
24 MiB per block check, entirely FFN padding; attention reads no weight
entries. One extra 32-layer sweep reads 768 MiB logically. Actual traffic
and elapsed benefit are unmeasured.

The synthetic immutable-owner contract passed 23,112 checks across 32
fixtures and 11,040 single-byte mutations. The independent source/cost
audit passed 201 checks. Controls demonstrate that a shape-only certificate
is unsafe. A checked immutable borrow could avoid repeated support scans;
every new owner retains its first scan. Table and provenance checks remain.
The harness took 6.33 s / 18,228 KiB RSS on one CPU worker. No native build,
GPU or proof ran.

Eight LIVE primary-source records added, 865 → 873. New leads include the
September semantic debloating paper, its separate artifact, MegaZK and older
RefinedRust. No author performance reproduced. All 49 prior hypotheses
retained; 51 now recorded. Top three remain complete GPU/resident workloads,
DD/fidelity context scaling, and exclusive phase/capacity clocks.

New verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context / accelerator: **none**. Witness, proof, serialization,
verification, startup/prefill, startup fraction, latency/bytes and steady /
total-workload rates: **unmeasured**. No long prefill, resident proof series
or decode. Private 8B at ≥50 proved tokens/s remains unachieved.

Owner next: measure same-owner support-check incidence and exclusive clocks
before implementation. Local next: independently test finite-field guards
and cumulative provenance for the new semantic method. No native checks
removed. R14 soundness acceptance at 03:05 UTC does not amend this target.

[Experiment](experiments/support-scan-capability-20261029/README.md) ·
[Handoff](handoffs/20261029-support-checked-borrow.md) ·
[Dated report](progress/20261029T025649Z-b1039010.md).
Only research outside runtime written. Reports do not imply notification
delivery or supervisor liveness. Checkpoint: 2026-10-29 03:11:33 UTC.

Final provenance audit: 240 checks PASS, 0.021492 s / 18,808 KiB RSS. Prior 865 sources, 49 hypotheses and findings preserved; eight native pins unchanged. Concurrent R14 decision update reread and snapshotted. Final checkpoint: 2026-10-29T03:12:53.012521+00:00.
