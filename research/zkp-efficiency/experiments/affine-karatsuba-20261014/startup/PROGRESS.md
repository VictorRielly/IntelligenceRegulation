# ZKP efficiency progress

Cycle 0048 — `20261013T052555Z-bb2755b6`, checkpoint 2026-10-13T05:42:56.250183+00:00 UTC.

**A softmax coefficient-reduction candidate passed synthetic checks; native
proving speed remains unmeasured.** Accumulating weighted coefficients before
evaluating the original samples removes a further 1.91% of counted base
multiplications and 3.41% of field API operations versus the prior row factory.
Added coefficient weights and part reductions are charged. A singleton
accounting regression keeps that round on the baseline. No sample, relation,
mask, private opening, degree or challenge change is proposed.

128 fixtures and 1,536 schedules pass 13,824 independent original-cube samples,
41,472 direct-MLE finals, 60 weighted-polynomial values, 144 counter checks
and seven controls. Final runtime 10.94 seconds, peak RSS 20,788 KiB, one
nice-19 Core Ultra 9 CPU thread. No native or GPU proof ran.
[Experiment](experiments/sc-szc-weighted-coefficients-20261013/README.md) and
[owner handoff](handoffs/20261013-sc-szc-weighted-coefficients.md) retain
commands, seed, source pins, costs, negative findings and the actual Rust seam.

LIVE sources assessed coefficient reduction and wire design, October 11
Plonky3 release-candidate metadata, zkLLMPoT composition and operator-benchmark
scope, and older Allspice static cost selection. Four source records saved.
Release-candidate source fetching failed; author claims remain unreproduced.

Next owner gate: fixed-array native translation, masked/frozen/refusal/final/
extension checks and fresh independent verification, then guarded enclosing
and peak-memory A/B. Compiler/spill costs and both recurring witness paths
remain unknown. Next local question: simplify row construction using public
mask/support axis dependencies while retaining every sample and declared width.

Accepted independently verified complete private 8B proofs, passes and tokens:
**0**. Proof context is null; device CPU only this cycle. Steady-state and total
rates, startup duration/fraction, witness, proof, serialization, independent
verification and latency/lag/drain clocks are unmeasured. No long-context
prefill, resident-model pass or decode proof ran. >=50/s remains unachieved;
larger workloads remain allowed with quadratic attention accounting, fresh
masks and complete coverage/privacy. No production/runtime/Git writes,
heavy job, GPU job, installation or external action. Saved reports do not
establish message delivery.
