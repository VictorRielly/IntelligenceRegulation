# ZKP efficiency progress

Cycle0116 complete — `20261021T001854Z-77f04b06` — 2026-10-21 UTC.

**No proving speedup measured.** An exact Goldilocks inverse-size helper passes
200 synthetic rows and an independent 1,601-check audit. It removes 127
source-level field multiplies per actual host inverse; GPU already calculates
once per batch and fuses row normalization. Zero device launches/transfers/bytes
disappear. The illustrative CPU row-encode multiply share is0.018895%, not time.
This is a low-priority cleanup. Nine LIVE queries/nine source records retained;
31 ranked hypotheses preserve prior negatives.

New completed independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: Intel Core Ultra 9 185H CPU,
one worker, no GPU. Witness, proof, serialization and verification clocks: **unmeasured**.
Startup duration/fraction, steady-state and total-workload proved rates: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. Synthetic row lengths
1..32 and conditional T32/T64/T128, L1/L2/L32, 1/2/4/8-pass schedules are diagnostics.
Larger workloads remain allowed; attention can grow quadratically with context.
The complete private 8B >=50 proved tokens/s target remains unachieved.

Next: assess the existing sumcheck CPU-tail policy's pack/copy/round schedule.
Owner whole-GPU clocks and verified resident1/2/4/8 workloads remain priorities.
D32's amended fidelity bar and D37's classifier direction were read; narrow
D33/D36 token-lane acceptance does not cover 8B/GPU/DD/new fidelity profiles.

[Experiment](experiments/public-inverse-scale-20261021/README.md),
[dated report](progress/20261021T001854Z-77f04b06.md),
[handoff](handoffs/20261021-public-inverse-scale.md). Saved files do not establish external delivery.

Evidence-integrity audit PASS: 76 artifact hashes and 18 source pins; prior 718
source records, prior findings prefix and prior 29 hypotheses preserved. Exact
latest check count and completion UTC: experiments/public-inverse-scale-20261021/artifact-audit-result.json.
Concurrent main decisions update retained as read-only evidence.
