# ZKP efficiency progress

Cycle0123 complete — `20261021T071854Z-0fa6988f` — 2026-10-21 UTC.

**No proving speedup measured.** A CPU model preserves BLAKE3 column hashes while
reducing temporary hash-state requests by38MiB per frozen T128 commitment or68–72MiB
at counted T512. Pooled backing may stay allocated. Initializing the logical stack
in its first launch also removes the explicit full-state clear in the model;
actual GPU benefit remains unknown. Masks and salts are unchanged.

Hash/state model: **328,043 checks, 27 synthetic matrix shapes and 11 control types PASS**.
Independent labelled-subtree/source/cost audit: **1,050,682 checks, 1,024 chunk counts,
seven native source pins PASS**. This researcher authored both models; the cryptographic
reference is independently implemented in the already-installed `blake3` 1.0.9 package,
one thread. Final checker clocks/RSS: 4.605481s/29,724KiB and
1.341245s/15,532KiB. These are diagnostic clocks, not proof clocks.
Every leaf has one-core affinity, nice19, 30s CPU/alarm, 35s parent timeout,
256MiB address-space limit and 64MiB estimated experiment memory.

Nine LIVE queries/eight primary records retained. All35 prior hypotheses preserved;
two added. An uncompiled no-memset patch and review handoff are saved. Native
hash/receipt/privacy gates, actual capacity and complete GPU timing remain blocked
by this research lane's CPU-only scope; they are owner work.

New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Device: one Intel Core Ultra 9 185H CPU
worker. Witness, proof, serialization, verification and startup clocks, startup fraction,
steady-state and total-workload rates: **unmeasured**. No long-context prefill,
resident-model proof series or decode ran. T128/T512 are counted geometry only;
T512 is unregistered and LOW/HIGH fidelity layouts are excluded. Larger workloads
remain allowed; attention can grow quadratically. The complete private8B / >=50
proved tokens/s target on RTX5090 or a named high-end GPU remains unachieved.

Next: test public launch-position-derived stack length locally. Owner priority
remains complete GPU phases/capacity and verified resident1/2/4/8 workloads.

[Experiment](experiments/commitment-leaf-buffer-20261021/README.md),
[dated report](progress/20261021T071854Z-0fa6988f.md),
[handoff](handoffs/20261021-streaming-blake3-state.md).
Saved reports do not establish message delivery or supervisor liveness.

Final evidence audit: 302 checks PASS; 61 immutable artifacts and seven live source pins match. All782 prior sources,10562 prior findings lines and35prior hypotheses retained. Finalized UTC: 2026-10-21T07:37:06.437012+00:00.
