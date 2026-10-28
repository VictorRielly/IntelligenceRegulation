# ZKP efficiency progress

Cycle 0119 complete — `20261021T031854Z-a1dbfeef` — 2026-10-21 UTC.

**No proving speedup measured.** A CPU ownership model passes 5,037 checks,
including 4,800 differential cases and 105 interleavings. Separate reference/source
checks agree. Safe scratch reuse needs recorded completion covering every use;
querying an unrecorded CUDA event can return success. Capacity is reserved before
launch, poison stops admission, and ambiguous free failures stay charged without retry.
These are model-tested constraints, not native CUDA behavior or a demonstrated bug.

Eight LIVE queries/seven primary records saved; all 34 hypotheses retained and rank 34
refined. Production decisions updates were read; product direction does not change
this lane's private 8B target. No native adapter or production edit.

New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: one Intel Core Ultra 9
185H CPU worker per experiment. Witness, proof, serialization and verification clocks:
**unmeasured**. Startup duration/fraction, steady-state rate and total-workload rate:
**unmeasured**. No long-context prefill, resident-model proof series or decode ran.
The 64-attempt budget trace is a synthetic ownership schedule, not 64 model passes.
Larger workloads remain allowed; longer contexts can increase attention work quadratically.
The complete private 8B target of >=50 proved tokens/s remains unachieved.

Next: source-backed exclusive clock and role schema with independent interval replay;
owner then measures allocation incidence and enclosing proof phases before any pool
promotion. Complete GPU clocks and verified resident 1/2/4/8 workloads stay first.

[Experiment](experiments/fzc-error-retirement-20261021/README.md),
[dated report](progress/20261021T031854Z-a1dbfeef.md),
[handoff](handoffs/20261021-fzc-error-retirement.md).
Saved files do not establish delivery or supervisor liveness.

Evidence integrity: 82 checks PASS; all 744 prior source records, the prior findings prefix and all 34 hypotheses retained. Four live/source-copy pins match. Finalized UTC: 2026-10-21T03:30:01.294817+00:00.
