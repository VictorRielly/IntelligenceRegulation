# ZKP efficiency progress

Cycle0106 complete — `20261020T141854Z-e43b78d7` — 2026-10-20 UTC.

**No proving speed improvement measured.** A tested ownership-transfer and
factorized-equality consumer lowers the selected8B T128 top16 per-column
array model from148.005 to68.029MiB. It still needs3.870/3.885x treework and
5.664x leaf generations (nonDD/DD) versus one forest build. Full-column cache
only falls208.005->192.029MiB; retained checkpoints cannot be overwritten.
No native/device fit, net proof-memory or time saving established.

Completed3383checks/244tiny consumers; independent260allocation
schedules,1300cost mutations,90original-MLE cases and9sourcepins.
Synthetic F65537 only, no private GKR/CFS/PCS. One thread, probe
21.746s/33928KiB; audit0.360s/15872KiB.
Ten LIVE queries/ten primary records include new olderCTY11 and an author
tensor-factor discussion, recent Chimera/SP1 refreshes; no author gain reproduced.
License/commit/paper-fetch limits retained in source records.

New independently verified full-stack proofs / passes / positions: **0 /0 /0**.
Actual model context/device: **none**. New witness/proof/serialization/verification
clocks, startup duration/fraction, steady-state and total-workload rates:
**unmeasured**. Research CPU clocks measure checking only. No long-context
prefill, repeated resident-model pass or decode performed. Larger workloads
remain allowed; attention work can increase quadratically with context.
Private8B >=50 proved positions/s on RTX5090 or another named high-end GPU
remains unachieved.

Carried historical diagnostic, not rerun or independently reverified here:
non-DD 8B T128, L32, one16-thread CPU pass, GPUoff. Total478.737s =
0.267370positions/s; prove_run393.785s encloses witness98.348s and load17.595s;
seal84.824s includes overlapping subwork. Receipt922711264B; fresh verification
42.709s + public load13.681s; recheck34.395s + load10.739s. Startup fraction,
isolated serialization and steady slope unknown. This is not a high-end GPU result.

Blockers: complete GPU phase/capacity evidence and a reviewed private protocol
for this proposed consumer. Next local: tiled first-round consumer with full
source/reconstruction accounting. Next owner: verified resident1/2/4/8,
DD context scaling and all-eleven FZC compiler A/B under shared locks.

[Experiment](experiments/lookup-owned-consumer-20261020/README.md),
[handoff](handoffs/20261020-lookup-owned-consumer.md),
[dated report](progress/20261020T141854Z-e43b78d7.md).
Research-only writes; saved reports do not establish external delivery.
