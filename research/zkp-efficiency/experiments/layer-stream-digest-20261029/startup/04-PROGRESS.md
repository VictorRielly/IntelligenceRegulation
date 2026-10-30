# ZKP efficiency progress

Cycle 0131 complete — `20261029T005649Z-c94ef085`, 2026-10-29 UTC.

**No 8B proving improvement found.** A public tied-table cache contract passes
1,717 synthetic checks, including 1,067 negative controls across 32 small
fixtures. The inspected seam applies to Shieldstral 3B; current Llama-3-8B
is untied and removes zero work there. The two source derivation sites may
share one authenticated result in a reviewed API. Runtime incidence and gain
are unmeasured; the owner's 17–18 s/load observation is for 3B.

Useful negatives: unchanged path/size/inode/mtime can hide changed bytes;
snapshot reuse changes the live loader's mutation/missing-file refusals;
public result fields cannot attest authentication; selected-row-only work
misses global multipliers. Exact rational arithmetic differs from specified
binary64 rounding in two fixtures, so retain the original quantizer.

CPU checking: 0.648750 s / 18,856 KiB RSS, one pinned
nice-19 Core Ultra 9 185H worker. Source/provenance audit: 724 checks
PASS, 0.008130 s / 20,908 KiB; seven native pins unchanged.
No native build, GPU or proof ran. Eight primary-source records added (857
total), including a newly assessed preprocessing paper and September cost
measurement note; no author performance reproduced. All 46 prior hypotheses
retained, two refined and two added; top three unchanged.

New independently verified full-stack proofs / passes / positions: **0/0/0**.
Actual model context/accelerator: **none**. Witness, proof, serialization,
verification, startup/initial-prefill clocks, startup fraction, latency/bytes,
steady-state and total-workload rates: **unmeasured**. No long prefill,
resident-model proof series or decode. Larger workloads remain allowed;
attention can grow quadratically. Private 8B >=50 proved tokens/s on RTX 5090
or another named high-end GPU remains unachieved.

Next local: audit current untied 8B public layer load/reload conversion and
digest lifetimes; test a bounded streaming projection with changed-layer
controls after checking prior loader findings. Owner first measures complete
exclusive phases and actual resident workloads. The conditional 3B interface
requires snapshot/refusal/security review and all native gates; no heavy job
queued. Research outside runtime only; main/Claude reviews/integrates, no merge.

[Experiment](experiments/public-derived-cache-20261029/README.md) ·
[Handoff](handoffs/20261029-public-derived-cache.md) ·
[Dated report](progress/20261029T005649Z-c94ef085.md).
Saved reports do not establish delivery or supervisor liveness.
Checkpoint UTC: 2026-10-29T01:10:59.526743+00:00.

Final reread: new D45 fixes one policy/threshold per classifier item; our
changed-parameter tests assert refusal and authorize no repeated-item probing.
The generic 8B target and agenda are unchanged.
