# ZKP efficiency progress

Cycle0168 COMPLETE — `20261030T164123Z-9635c75b`, checkpoint 2026-10-30T16:57:01.181607+00:00.

**No measured proving improvement.** The useful candidate is dictionary-based
softmax grouping: current source selects the generic evaluator there, while
the following non-dictionary branch already selects grouped equality rounds.
A 16-fixture CPU arithmetic projection matches generic and independent
original-cube equations. All original tables/folds/finals remain. The row
scan/fold census, including equality weighting, removes36 Fp2 multiplies,
7 mul_base,47 additions and15 subtractions per row pair. Group setup,
inversions/recovery,degree completion and enclosing costs remain unpriced.
This is not a timing or net whole-proof result; native gates are unexecuted.

The initial 64-fixture non-DD study found no distinct host-only interpolation
columns: its savings overlap the earlier symbolic-equality proposal. It is
demoted. Across both arms:80 fixtures,14 negative controls,14,924 named check
entries. The separate saved-evidence audit passes2347 checks.
Main checking process:1.676428s / 22012KiB RSS,
one low-priority CPU thread,30s CPU/40s alarm/45s parent/256MiB address-space
caps,64MiB estimate. An audit JSON-list/tuple conversion failure was corrected;
the failed source/logs and successful replay are retained. Prior partial DD
costs are superseded by the census that charges weighting and accumulation.

New independently verified full-stack proofs / complete-model passes / proved positions: **0 / 0 / 0**.
Actual model context: **none**; actual model passes: **0**. Device: **one CPU
affinity on Intel Core Ultra9 185H; no GPU**. Witness, proof, serialization,
verification, startup and initial-prefill clocks; startup fraction; proof
latency/bytes; steady-state and total-workload proved-token rates: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. Synthetic
n=0/1/2/3 cubes and allocation-free n=7/14/23 counts are not model contexts.
Larger workloads remain allowed; attention can grow quadratically with context.
Complete private8B **>=50 proved tokens/s on RTX5090 or another named high-end
GPU remains unachieved**. No mask/pad/private-opening reuse or weaker privacy.

LIVE sources: new older [Giraffe2017](https://eprint.iacr.org/2017/242) full-cost
accounting and its GPL-3.0-or-later README notice; refreshed
[sumcheck2026](https://eprint.iacr.org/2026/587),
[Akita factor boundary](https://layerzero-labs.github.io/akita/foundations/eq-factored-sumcheck.html),
[cuPQC0.6](https://nvidia.github.io/cuPQC/releases/v0.6/) and
[zkDuel Oct26](https://arxiv.org/abs/2610.37710). Ten exact source records
append1122->1132; dates,unknowns,license/history failures and uninspected commit
references retained. No author performance reproduced or foreign code executed.

Next owner action: confirm actual DD slot incidence and exclusive group/slot
costs, then native masked/transcript/RNG/receipt/refusal and fresh-process
complete-stack verification before an enclosing A/B under current shared locks.
Next local: extend DD projection across actual admitted score shifts/range
descriptors and shorter Ht spans, with source-derived degree/lookup controls.
Priority remains complete verified high-endGPU resident1/2/4/8 workloads,
admitted context/fidelity scaling,and exclusive native phase/capacity evidence.

[Experiment](experiments/grouped-evaluator-incidence-20261030/README.md) ·
[Handoff](handoffs/20261030-dictionary-softmax-grouping.md) ·
[Dated report](progress/20261030T164123Z-9635c75b.md).
Saved reports do not establish user-message delivery or supervisor liveness.
