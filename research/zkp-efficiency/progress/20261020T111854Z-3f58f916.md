# ZKP efficiency progress

Cycle 0103 complete — `20261020T111854Z-3f58f916` — 2026-10-20 UTC.

**No proving speed improvement measured.** At the frozen R9 public count
fixture, U8 helper data is 420.25 MiB per 8B T128 block, 390.25 MiB with DD.
These are logical input bytes, not time or net savings. Even an exact
materialized fraction forest needs 3.10/2.88 GiB before proof scratch;
at the unregistered, COUNTED ONLY T512 anchor it needs 18.25/13.10 GiB.
This storage schedule is unsuitable as a memory-saving replacement. A
streaming/recomputation design must be priced before a private GKR prototype.
The 256-entry inverse cache depends on fresh challenges and is per attempt.

Completed: 1098 integer/synthetic checks, 46 fixtures and
13 controls; independent audit 1381 checks, 34 source mutation controls,
624 altered-count controls, 160 tiny topology checks and five unchanged pins.
One CPU thread: probe 0.008066 s / 16,248 KiB RSS.
No native build or GPU. Twelve LIVE queries produced six primary source
records, including newly screened older flookup. Dates, licenses, commit
scope and fetch failures retained. No author benchmark reproduced. Twenty
ranked hypotheses preserve prior negative findings.

New independently verified full-stack proofs/passes/positions: **0/0/0**.
Actual model context/device: none. Witness, proof, serialization, verification,
startup duration/fraction, steady-state and total-workload rates: **unmeasured**.
No long prefill, resident-model pass or decode. Private 8B >=50 proved tokens/s
on RTX 5090 or another named high-end GPU remains unachieved. Larger workloads
remain allowed; dense attention can grow quadratically with context length.

Blocked/unknown: complete GPU phase/capacity clocks and a private mixed-height
GKR/mask/opening design. DD privacy gate remains owed; D32 fidelity bar and
D33's narrow artifact scope retained. Next local: explicit streamed-forest
lifetime/recomputation census. Next owner: complete GPU phase clocks, verified
fixed-context resident 1/2/4/8 passes and all-eleven FZC compiler A/B.

[Experiment](experiments/lookup-helper-census-20261020/README.md),
[handoff](handoffs/20261020-lookup-helper-census.md),
[dated report](progress/20261020T111854Z-3f58f916.md).
Saved reports do not establish external message delivery.
