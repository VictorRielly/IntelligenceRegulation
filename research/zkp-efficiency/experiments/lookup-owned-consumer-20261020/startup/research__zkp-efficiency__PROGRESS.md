# ZKP efficiency progress

Cycle0105 complete — `20261020T131854Z-4f8a9e18` — 2026-10-20 UTC.

**No proving speed improvement measured.** Adding an explicit layer consumer
raises the modeled one-column lookup rebuild at8B T128 from128MiB to208MiB,
with nearly twice the fraction-tree construction work and twice the leaves.
A148MiB per-column checkpoint plan needs3.87/3.88x treework (nonDD/DD).
These are selected arithmetic/fold arrays; complete proof memory/time remain
unknown. The newer LOW fidelity profile is outside this frozenR9 count.

Completed1515 probe checks/183tiny layer consumers; independent480 allocation
schedules,1440cost mutations,80direct-basis/alias cases andfive sourcepins.
Unmasked F65537 arithmetic only. One thread: probe3.665s/20808KiB;
audit0.319s/15404KiB. Eight LIVE queries/eight primary records include
ChimeraOctober16, SP1October10, and a new host/GPU Fiat-Shamir scheduling
negative. Author timings are not reproduced; source limits are retained.

New independently verified complete-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. New witness, proof, serialization,
verification, startup duration/fraction, steady-state and total-workload rates:
**unmeasured**. The CPU experiment clocks below measure research checking only.
No long-context prefill, repeated resident-model pass or decode was performed.
Larger workloads are allowed; increasing context can add quadratic attention.
Private 8B >=50 proved positions/s on RTX5090 or another named high-end GPU
remains unachieved.

Carried historical diagnostic, not rerun or independently reverified here:
non-DD 8B T128, L32, one 16-thread CPU pass, GPU off; total478.737s =
0.267370positions/s. prove_run393.785s encloses witness98.348s and load17.595s;
seal84.824s has overlapping subwork and is not an exclusive extra witness clock.
Receipt922711264B; fresh verification42.709s + public load13.681s;
recheck34.395s + load10.739s. Startup fraction, isolated serialization and
steady slope unknown. This baseline is not a high-end GPU result.

Next local: compare ownership transfer plus symbolic equality against this
consumer, including full folds and ordered source access. Owner priorities:
complete GPU clocks/capacity, independently verified fixed-context resident
1/2/4/8 passes and all-eleven FZC compiler A/B. Private GKR/CFS/PCS design and
full GPU costs remain blockers. Research-only writes, no GPU/native builds.

[Experiment](experiments/lookup-layer-consumer-20261020/README.md),
[handoff](handoffs/20261020-lookup-layer-consumer.md),
[dated report](progress/20261020T131854Z-4f8a9e18.md).
Saved reports do not establish delivery to the user or external messaging.
