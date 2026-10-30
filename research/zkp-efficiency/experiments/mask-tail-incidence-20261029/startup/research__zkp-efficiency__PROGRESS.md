# ZKP efficiency progress

Cycle 0137 complete — `20261029T065649Z-ae3c483b`, 2026-10-29 UTC.

**No native proving improvement measured.** A source-based CPU model replaces
four products per reserved-mask-pair coefficient with three, retaining every
private row read. It adds modular additions and subtraction dependencies;
equality-table construction, commitments and proof work remain.

The model passes **7,399 checks / 168 fixtures / 18 negative-control families**
in **3.984581 s / 32,852 KiB**. A separate source/count/patch audit passes
**495 checks**. Synthetic rows reach16,384 coefficients; these are not contexts.
The research Rust patch changes only `mask_eval`; it is uncompiled/unapplied.

Historical TinyLlama T128/L22 raw clocks show13.303s of135.809s GPU-assisted
prove_run in all enclosing extension phases. Even free whole-phase deletion
is only about1.109x proving-only there, using rounded displayed timers;
this arithmetic removes only a subset. No8B/high-endGPU projection follows.

Eight LIVE primary-source records appended,901→909: October28 polynomial
evaluation, current Jolt Atlas specs/license/history, and newly assessed older
matrix Karatsuba. No author gain reproduced. All54 prior hypotheses preserved;
two added. Whole-proverGPU/verified resident passes, admittedDD/fidelity context
scaling and exclusive phase/capacity clocks remain the top3.

Owner next: compiler-lowered baseline/paired4/paired3 and exclusive dot/Eq/
extension/enclosing clocks, then full native proof gates under shared locks.
Local next: actual private-tail incidence across all23slots, checking earlier
catalogs before pricing public preparation. No heavy job queued.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context / accelerator: none. The experiment used one CPU thread
on an Intel Core Ultra9 185H, with no GPU. Witness, proof, serialization,
verification, startup/initial-prefill duration and fraction, proof latency/
bytes, steady-state and total-workload rates: **unmeasured**. No long-context
prefill, resident-model proof series or decode ran. Larger workloads remain
allowed, with quadratic attention growth disclosed. Private8B ≥50 proved
tokens/s on RTX5090 or another named high-end GPU remains unachieved.

[Experiment](experiments/paired-mask-three-product-20261029/README.md) ·
[Handoff](handoffs/20261029-paired-mask-three-product.md) ·
[Dated report](progress/20261029T065649Z-ae3c483b.md).
Checkpoint: 2026-10-29T07:11:42.610314+00:00. Saved reports do not imply delivery or supervisor liveness.
