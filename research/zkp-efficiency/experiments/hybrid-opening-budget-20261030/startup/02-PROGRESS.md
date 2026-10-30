# ZKP efficiency progress

Cycle 0156 complete — `20261030T015649Z-fd1dbb78`, October 30, 2026 UTC.

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

Next: test full challenge-vector staging with bounded max-four output
scratch, using a public byte budget and independent offset, overflow,
failure, pad and fresh-call controls. This hybrid is untested. Owner
measurements of exclusive allocation and transfer-submission costs take
precedence; if they are negligible, park staging work.

Six LIVE primary-source records saved; all 82 prior hypotheses retained.
Hypothesis 83 records this result; 84 proposes the hybrid.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: none. The cost study models T128;
correctness work used one pinned Intel Core Ultra 9 185H CPU worker.
Witness, proof, serialization, verification, startup and initial-prefill
clocks, startup fraction, proof latency/bytes, steady-state rate and
total-workload rate: **unmeasured**. No long-context prefill, resident-model
series or decode ran. Larger workloads remain allowed; longer attention
can grow quadratically. Complete private 8B **>=50 proved tokens/s remains
unachieved**.

[Experiment](experiments/opening-staging-20261030/README.md) ·
[Handoff](handoffs/20261030-opening-staging.md) ·
[Dated report](progress/20261030T015649Z-fd1dbb78.md).
Saved reports do not establish user delivery or supervisor liveness.
