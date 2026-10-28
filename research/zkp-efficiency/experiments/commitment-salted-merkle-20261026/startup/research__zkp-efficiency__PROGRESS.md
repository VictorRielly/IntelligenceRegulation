# ZKP efficiency progress

Cycle 0124 complete — `20261021T081854Z-3ffe311a` — 2026-10-21 UTC.

**No proving speedup measured.** The CPU model preserves keyed and unkeyed BLAKE3
hashes while deriving temporary stack length from public chunk position. The candidate
removes counter storage, counter traffic and state clearing; it adds a popcount on each
continued launch per column. Extra requested storage savings are only 0.25 MiB at
counted T128 or 0.5 MiB at T512 per commitment. Actual pooled memory and elapsed time
may not improve. Hash compressions and CV traffic are unchanged.

The model passes **1,528 checks**, 30 unkeyed and 19 keyed shapes, 109 restart cases
and 26 controls against installed independent blake3. A separate interval/source audit
passes **1,835,886 checks** over 262,144 prefixes and nine native source pins. Both
use one CPU core, under nine seconds and 24 MiB RSS. A keyed-flag error in the model
was caught, corrected and retained as a control. Alternative uncompiled patches and
a handoff are saved. Seven LIVE queries produced nine primary source records.
All 37 hypotheses remain; two were refined.

New verified full-stack proofs / passes / positions: **0 / 0 / 0**. Actual model
context and accelerator: **none**. Device: one Intel Core Ultra 9 185H CPU worker.
Witness, proof, serialization and verification clocks; startup duration/fraction;
proof latency/bytes; steady-state and total-workload rates: **unmeasured**.
No long-context prefill, resident-model passes or decode ran. T128/T512 are frozen
R9 geometry counts; T512 is unregistered and current LOW/HIGH layouts are excluded.
Larger workloads remain allowed; attention can grow quadratically with context.
The private 8B / >=50 proved tokens/s GPU target remains unachieved.

Next: count keyed host salt/Merkle costs before proposing more hash scheduling work.
Owner work: native hash/receipt/privacy/failure-retirement gates, complete GPU clocks
and independently verified resident 1/2/4/8 workloads under shared locks.

[Experiment](experiments/commitment-public-frontier-20261021/README.md),
[dated report](progress/20261021T081854Z-3ffe311a.md),
[handoff](handoffs/20261021-public-blake3-frontier.md).
Saved reports do not establish message delivery.

Final evidence audit: 579 checks PASS; 70 immutable artifacts, nine tested native source pins and two next-seam inspection pins match. Both native patch alternatives parse against their snapshots with only the declared code changes. All 790 prior sources, 37 prior hypotheses and the full prior findings prefix are preserved. Finalized UTC: 2026-10-21T08:35:23.509218+00:00.
