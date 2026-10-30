# ZKP efficiency progress

Cycle 0144 complete — `20261029T135649Z-1526011b`, October 29, 2026.

**No native proving improvement found.** Reusing public coordinate maps passes
9,450 comparisons and 3,150 fresh-mask checks across synthetic 1/2/4/8-pass
replays. The plan retains no challenge values or private data. The native
implementation already stores slot geometry; this experiment reuses only two
address maps currently rebuilt on each table call.

CPU helper timings are mixed: 21 of 36 final medians improved, versus 27
initially. These short shared-machine diagnostics establish no native or GPU
gain. Source accounting finds 15–16 unique map signatures among 201–209 sites
in an 8B T128 block, requiring about 271–273 KiB of tuple payload. All
147–154 million private-word reads per block remain. Exclusive native map,
table-building and enclosing-proof clocks are needed before integration.

The probe took 1.572 seconds and 12.2 MiB RSS. Accounting passes 16,972 checks;
the provenance audit passes 844. A control initially changed an unread word;
it was corrected, with the failure retained. All 60 prior hypotheses remain,
and hypothesis 61 was added. Nine LIVE primary-source records include newly
assessed Foundry 2026 and older dynamic graph parameter updates. A conditional
handoff is saved; no native patch or heavy job was queued.

Next: obtain native phase measurements, or continue with bounded arithmetic
accounting for fresh fixed-coordinate equality tables. Whole-prover GPU work
and independently verified resident workloads retain priority.

New independently verified full-stack proofs / model passes / proved positions:
**0 / 0 / 0**. Actual model context and accelerator: **none**. This cycle used
one pinned Intel Core Ultra 9 185H CPU worker. Witness, proof, serialization,
verification, startup and initial-prefill clocks, startup fraction, proof
latency/bytes, steady-state and total-workload token rates: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. Larger
workloads remain allowed; longer dense attention can increase work quadratically.
The complete private 8B target of at least 50 proved tokens/s on an RTX 5090
or another named high-end GPU remains **unachieved**.

[Experiment](experiments/resident-public-plan-20261029/README.md) ·
[Dated report](progress/20261029T135649Z-1526011b.md) ·
[Conditional handoff](handoffs/20261029-resident-public-map-plan.md).
Saved reports do not imply message delivery or supervisor liveness.
