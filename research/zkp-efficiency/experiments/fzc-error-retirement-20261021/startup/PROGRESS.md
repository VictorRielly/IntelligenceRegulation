# ZKP efficiency progress

Cycle 0118 complete — `20261021T021854Z-dc9711cc` — 2026-10-21 UTC.

**No proving speedup measured.** A synthetic FZC storage model passes 1,418 checks;
a separate audit agrees with its allocation counts. Conditional 32-attempt traces
reduce 96 host allocations to 3 (fixed shape) or 6 (changing shape). All proof
work and transfers remain. Growth increases transient host capacity; no peak-memory
or elapsed saving is established.

Safe reuse requires completion before clearing the current flag offset and exact
requested-length copy slices. The existing constructor stream sync may provide the
fence. Native allocation clocks, CUDA lifetime behavior and proof parity remain owed.
Five LIVE queries and seven primary records are saved; all 34 hypotheses are retained.

New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: one Intel Core Ultra 9
185H CPU worker per experiment. Witness, proof, serialization and verification clocks:
**unmeasured**. Startup duration/fraction, steady-state rate and total-workload rate:
**unmeasured**. No long-context prefill, resident-model proof series or decode ran.
The 32-attempt traces are synthetic allocation schedules, not 32 model passes.
Larger workloads remain allowed; longer contexts can increase attention work quadratically.
The complete private 8B target of >=50 proved tokens/s remains unachieved.

Next: bounded timeout/error retirement oracle, then owner allocation timing and
native parity under shared locks. Complete GPU clocks and verified fixed-context
resident 1/2/4/8 workloads remain the main priorities.

[Experiment](experiments/fzc-scratch-leases-20261021/README.md),
[dated report](progress/20261021T021854Z-dc9711cc.md),
[handoff](handoffs/20261021-fzc-scratch-leases.md). Saved files do not establish delivery.

Concurrent owner updates were read and saved: D33/D36 extend to frozen-r11; D38
selects a text classifier application. Eight DD captures passed the owner gate.
These do not establish a private 8B GPU rate or change this lane’s target.

Evidence integrity: 145 checks PASS; 50 artifact hashes and 10 live/source-copy pins match. All 737 prior source records, the prior findings prefix and all 34 hypothesis entries are retained. Concurrent owner updates were read and snapshotted. Finalized UTC: 2026-10-21T02:36:20.454182+00:00.
