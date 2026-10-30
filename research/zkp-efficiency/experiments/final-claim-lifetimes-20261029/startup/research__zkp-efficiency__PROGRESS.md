# ZKP efficiency progress

Cycle 0135 complete — `20261029T045649Z-6e004a83`, 2026-10-29 UTC.

**No native proving improvement found.** A split-coset encoder produces the
same tested hiding polynomial and output columns. At row length 16,384,
expansion rate 4 and 256 pad coefficients, it saves 2.32% of counted encoder
field multiplications after added scaling. Extra reads and layout costs are
unmeasured. When pad length equals row length, multiplication work increases.

The CPU models pass 21,424 small checks and 114,688 larger output checks,
including 15 retained synthetic native conformance rows and 13 deliberately
wrong controls. Small and larger checks took 0.610 and 1.181 seconds, using
17,308 and 43,100 KiB RSS on one Core Ultra 9 185H worker. A separate source
and evidence audit passed 101 checks. No native build, GPU or model run.

Nine LIVE primary-source records added, 882 → 891, with dates, licenses,
source pins and fetch limits recorded. Author performance was not reproduced.
All 51 prior hypotheses remain; the conditional encoder candidate is number 52.
Whole-prover GPU work and verified resident workloads remain higher priorities.

New verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context / accelerator: **none**. Witness, proof, serialization,
verification, startup / initial-prefill duration, startup fraction, proof
latency / bytes, steady-state and total-workload rates: **unmeasured**.
No long prefill, resident proof series or decode. Private 8B at ≥50 proved
tokens/s remains unachieved. Larger workloads remain allowed; longer contexts
can increase attention work quadratically.

Owner next: measure exclusive encoder and enclosing proof clocks and actual
eligible calls before building an adapter. Local next: inspect final-claim
evaluation lifetimes for a sumcheck/GKR seam, then test an independent Fp2
oracle with fresh-point, pad, order and tail controls. Main/Claude reviews and
integrates; no heavy job queued or merge performed.

[Experiment](experiments/ntt-coset-layout-20261029/README.md) ·
[Handoff](handoffs/20261029-split-coset-hiding-rows.md) ·
[Sources](experiments/ntt-coset-layout-20261029/sources-cycle.json).
Checkpoint: 2026-10-29T05:10:06.645692+00:00. Saved reports do not imply message delivery or supervisor liveness.

Final checkpoint: 2026-10-29T05:12:06.441625+00:00. Provenance audit: 152 checks PASS; all prior findings, 882 source records and 51 hypotheses preserved; eight native pins and required direction unchanged.
