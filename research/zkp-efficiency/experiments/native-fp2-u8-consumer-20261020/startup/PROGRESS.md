# ZKP efficiency progress

Cycle0107 complete — `20261020T151854Z-beab78ce` — 2026-10-20 UTC.

**No proving speed improvement measured.** Budget-adaptive streaming lowers
the selected frozenR9 8B T128 lookup-array model from68.030 to36.022MiB.
Only nine leaf-layer services rescan; tree-node/fold counts stay unchanged,
while original leaf reads rise6.4–6.9%. Streaming every uncached layer instead
raises treework3.87->5.74x nonDD; the adaptive schedule avoids that penalty.
These are prospective consumer arrays/costs, not native proof memory or time.

Completed 2934 checks/225 tiny consumers/14 controls; independent
240 cost schedules/1680 mutations/70 original-MLE cases/9 pins pass.
Synthetic F65537 only, no private GKR/CFS/PCS. One thread;
probe 2.304s/31796KiB, audit 0.096s/16308KiB.
Eleven LIVE queries/eight primary records: Plonky3 implementation/release,
Chimera October16 revision and newly screened2012 GPU GKR residency method.
Author gains not reproduced; version/license/date/fetch scope recorded.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context/device: **none**. New witness, proof, serialization,
verification, startup duration/fraction, steady-state and total-workload rates:
**unmeasured**. CPU clocks here measure research checking only. No long-context
prefill, resident-model pass or decode was performed. Larger workloads remain
allowed; increasing context can increase attention work quadratically.
Private 8B >=50 proved positions/s on RTX 5090 or another named high-end GPU
remains unachieved.

Carried historical diagnostic, not rerun or independently reverified here:
non-DD 8B T128, L32, one 16-thread CPU pass, GPU off; total478.737s =
0.267370positions/s. prove_run393.785s encloses witness98.348s and load17.595s;
seal84.824s includes overlapping subwork. Receipt922711264B; fresh verification
42.709s + public load13.681s; recheck34.395s + load10.739s. Startup fraction,
isolated serialization and steady slope unknown. This is not a high-end GPU result.

Blockers: complete GPU phase/capacity evidence; reviewed private consumer,
ordered original-A links and terminal binding. Latest fidelity layouts are
excluded from these frozenR9 counts. Next local: native Fp2/U8 denominator
reader differential oracle. Next owner: verified resident1/2/4/8, DD context
scaling and all-eleven FZC compiler A/B under shared locks.

[Experiment](experiments/lookup-tiled-prefix-20261020/README.md),
[handoff](handoffs/20261020-lookup-tiled-prefix.md),
[dated report](progress/20261020T151854Z-beab78ce.md).
Research-only writes; saved reports do not establish external delivery.
