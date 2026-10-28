# ZKP efficiency progress

Cycle 0122 complete — `20261021T061854Z-553803c5` — 2026-10-21 UTC.

**No proving speedup measured.** Sharing a byte decomposition across related
checks preserves the tested range conditions, but dense bit storage still
costs 4.82–5.46 times the native helper data. This representation is demoted.

A smaller lead survives: two identical checks at frozen T128 can potentially
be removed together with one helper plane. Per block, that saves 8.25 MiB
without DD or 2.25 MiB with DD, including reserved mask rows. The counted
A+H payload falls 0.92% or 0.26%; T512 saves nothing. These are conditional
inventory reductions, with native timing and profile review still open.

The synthetic experiment passed 872,684 checks and 26 control types. An
independent source and cost audit passed 219 checks against six pinned native
files. Nine LIVE searches produced nine source records. All 34 prior
hypotheses remain; rank 25 was refined and rank 35 added.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and GPU: **none**. Device: one Intel Core Ultra 9 185H CPU
worker. Witness, proof, serialization, verification and startup clocks,
startup fraction, steady-state rate and total-workload rate: **unmeasured**.
No prefill, resident-model proof series or decode ran. Contexts are symbolic;
T512 is unregistered. Longer workloads remain allowed, with quadratic attention
costs. The private 8B / ≥50 proved tokens/s GPU target remains unachieved.

Next: inspect exact duplicates in the owner's actual fidelity profile and count
all receipt and mask costs. Owner GPU phases, capacity and verified resident
1/2/4/8 runs remain first. No production changes or mask reuse.

[Experiment](experiments/affine-u8-source-sharing-20261021/README.md),
[dated report](progress/20261021T061854Z-553803c5.md),
[handoff](handoffs/20261021-affine-u8-sharing.md).
Saved reports do not establish message delivery or supervisor liveness.

Final evidence audit: 1453 checks PASS; 54 immutable artifacts and six native source pins match. All 773 prior sources, 10,447 prior findings lines and 34 prior hypotheses retained. Finalized UTC: 2026-10-21T06:34:54.132760+00:00.
