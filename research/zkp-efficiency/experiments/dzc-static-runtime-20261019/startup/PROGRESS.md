# ZKP efficiency progress

Cycle 0079 — `20261019T111854Z-5ff11116`, 2026-10-19 UTC.

**Useful logical-storage result; no measured proving speedup.** Interleaving
D affine contributions with first endpoint use reduces the complete modeled
peak **77→27 Fp2 words (64.9%)**, with unchanged reads and arithmetic.
All 59 original tables, folds and finals remain. This compares unintegrated
prototypes; native compiler, resource and timing checks remain.

Thirty synthetic fixtures, 12 negative controls and 681 independent audit
checks pass, including aliases and value-independent scheduling. The main
check took 12.651 seconds on one Core Ultra 9 185H CPU thread.
[Experiment](experiments/dzc-use-driven-affine-20261019/README.md) and
[unapplied handoff](handoffs/20261019-dzc-use-driven-affine.md).

A new audit of retained 8B logs bounds the opportunity: context 128, 32 blocks,
one pass on 16 CPU threads, GPU off; total 471.580 seconds, proof region
370.137 seconds including witness 94.021 and block loading 17.408 seconds.
Sealing took 101.279 seconds; receipt 922,711,264 bytes. D used 44.833 seconds.
Eliminating ALL D would cap that CPU diagnostic at 1.105× faster. Candidate
speedup and the GPU ceiling remain unknown. Fresh verification took 34.587
seconds plus 11.599 seconds loading. Serialization, startup fraction and a
steady-state rate remain unisolated.

The distinct 8B context-32 next-token result now passed independent soundness
review; the reviewer verified it in 37.7 seconds. Trained privacy acceptance
remains pending. Five LIVE source records cover older Min-Reg scheduling,
recent quantization research and GitHub releases/docs; no external benchmark
was reproduced.

Next: static named-local Rust realization at SC_DZC / SumcheckRounds, followed
by owner checks of native allocation, whole-D time and complete-stack rates.

New target proofs/passes/positions: **0/0/0**, device none. Target steady and
total rates, startup fraction, witness/proof/serialization/verification clocks
remain unmeasured. No prefill, resident series or decode ran. Larger workloads
remain allowed; attention can grow quadratically with context.
Complete private 8B >=50/s remains unchanged and unachieved.
Only research files changed; no mask or opening reuse.

[Dated report](progress/20261019T111854Z-5ff11116.md). Saved reports do not establish delivery.
