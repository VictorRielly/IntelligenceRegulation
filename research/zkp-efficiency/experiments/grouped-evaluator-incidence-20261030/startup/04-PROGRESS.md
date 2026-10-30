# ZKP efficiency progress

Cycle 0167 COMPLETE — `20261030T154123Z-20600a3e`, checkpoint 2026-10-30T15:58:05Z.

**No measured proving improvement.** An exact Goldilocks warp-sum model passed
53,030 checks and 29 negative controls, plus a separate 243-check evidence audit.
It covers 10,530 warp cases, 96 block cases and 36 Fp2 polynomial rounds.
The main CPU check took 0.872 seconds and about 20 MiB of memory.

The useful negative: the inspected current trained/R14 private slot factories
select CPU evaluators. Optimizing the legacy CUDA reducer removes no work
from those slots today. In a conditional 128-thread, five-value reducer, modeled
shared scratch falls from 10,240 to 320 bytes and tail barriers from eight to
one. Added collective, carry and register costs remain unknown. The CUDA
sketch is uncompiled; these counts establish no device or proving speedup.

New independently verified full-stack proofs / model passes / proved positions:
**0 / 0 / 0**. Actual context: **none**. Device: **one CPU affinity, Intel Core
Ultra 9 185H; no GPU**. Witness, proof, serialization, verification, startup and
initial-prefill clocks, startup fraction, proof latency/bytes, steady-state and
total-workload rates: **unmeasured**. No prefill, resident proof series or decode
ran. Larger workloads remain allowed; attention can grow quadratically. The
private 8B **>=50 proved tokens/s target remains unachieved**. No mask or private
opening reuse is proposed.

LIVE sources searched: zkDuel and its artifact, CUDA 11/Ampere warp reduction,
current PTX/CUB/CCCL, the retained carry-arithmetic negative and CUDA 13.3's
binary-field limitation. Nine source records appended; cache misses and
timeouts retained. All 100 previous hypotheses and prior findings preserved.
An explicit carry-boundary refinement passed after a corrected syntax error;
the failed attempt is retained.

Next: establish a real private GPU evaluator and exclusive phase costs before
porting the helper. The highest priority remains complete, independently
verified high-end GPU resident 1/2/4/8 workloads. Next local study: count the
actual grouped evaluator's arithmetic and traffic from current public shapes.

[Experiment](experiments/arithmetic-intensity-screen-20261030/README.md) ·
[Handoff](handoffs/20261030-exact-warp-reduction.md) ·
[Dated report](progress/20261030T154123Z-20600a3e.md).
Saved reports do not establish user-message delivery.
