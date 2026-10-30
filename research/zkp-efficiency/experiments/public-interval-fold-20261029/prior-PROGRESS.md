# ZKP efficiency progress

Cycle 0151 complete — `20261029T205649Z-c620e79d`, October 29, 2026.

**No native proving speedup measured.** Public indexed rowfold and packed
membership pass 109,512 exact comparisons, 376 controls and 1,206 independent
plan checks. Source logical matrix+rho+index operands fall about 91% at
frozen R13 8B/T128 A geometry; physical traffic and GPU/whole-proof gains
remain unknown. R14 differs. Reversing group order saves matrix reads but
raises plain indexed logical bytes 40.9%: packing needs the full objective.

Plan upload 38.6/37.3 KB and all other proof costs remain. Five LIVE source
records added; 72 prior hypotheses preserved, two added. Next: owner exclusive
fold/enclosing clocks; local public interval/list/dense differential.
Main/Claude reviews the uncompiled kernel sketch and integration seam.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual context and accelerator: **none**; modeled context T128; one pinned
Intel Core Ultra 9 185H CPU worker. Witness, proof, serialization,
verification, startup/initial-prefill duration and fraction, proof
latency/bytes, steady-state and total-workload rates: **unmeasured**.
No prefill, resident-model series or decode ran. Larger workloads remain
allowed; attention can grow quadratically with context. Complete private
8B **>=50 proved tokens/s remains unachieved**.

[Experiment](experiments/public-indexed-fold-20261029/README.md) ·
[Handoff](handoffs/20261029-public-indexed-fold.md) ·
[Dated report](progress/20261029T205649Z-c620e79d.md).
Saved reports do not establish delivery or supervisor liveness.
