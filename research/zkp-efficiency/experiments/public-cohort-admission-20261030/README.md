# Cycle0163 — public cohort capacity admission

Run `20261030T114123Z-38ad9454`; started2026-10-30T11:41:23Z; checkpoint2026-10-30T11:54:17.656204+00:00.

**No measured proving improvement.** The most useful local question was:
can independent ready-round cohorts be admitted safely while other commitment
owners remain live? The answer is conditional on complete capacity reserves;
round lengths alone give an unsafe admission decision.

The authored independent Python row-count oracle matches22 unchanged native
metadata bodies in216 Legacy/LowH24 and DD/nonDD public cases (2,160 numeric
comparisons). Native constructors, define, prover, transcript, PCS arithmetic,
privacy gates and GPU were not executed. The SC_SZC table inventory is a
source-screened use of private-site counts plus three equality tables, causal
mask and applicable supports, checked in both argument files; native define
was not run.20 small Rust Vec probes produce190 length/capacity observations;
truncate and clear preserve original capacity. Initial Python DD oracle omitted
the dictionary TABLE helper; native mismatch caught it. The failed reference
and corrected pass are retained; this was an experiment-oracle error, not a
production defect. Earlier allocation/pool/lifetime negatives remain binding.

The R13 H24 T128 metadata agrees with prior A4577/H4390 row counts. Its
SC_SZC cube has2^19 entries and28 Fp2 tables:224MiB per proof. All shapes
are metadata-only; no calibration/profile admission or actual workload is
inferred. In a SINGLE BLOCK with two endpoint owners, the following partial
requested-payload counts apply:

| Simultaneous proof jobs | A/H/endpoint systematic data + round tables | Plus complete CPU encoding payloads (including M encoding) |
|---:|---:|---:|
|1|1.322388GiB|5.738464GiB|
|2|2.644775GiB|11.476929GiB|
|4|5.289551GiB|22.953857GiB|

These columns are lower bounds/subtotals, **not actual fit, RSS or VRAM**.
The latter uses CPU Store::Host semantics and must never be assigned to GPU
residency. Excluded: public/resident model and other blocks, witnesses,
constructor/encode/open scratch, pads, salts, trees, remaining M/CFS buffers,
proof/serialization output, NTT caches, pools/oversizing, allocator/driver,
reserved quarantine and other processes. A whole32-block run has additional
boundary owners and lifecycle peaks. Missing measured/public reserves make
actual admission indeterminate, including on an RTX5090.

The symbolic gate and an independent offline allocation replay pass9 exact
cohort budget boundaries plus150 seeded randomized boundaries:4,560 assertions,
55 negative controls,10 retained traces. Controls cover premature retirement,
two outstanding stream-event tokens, stale owner/generation, invalid completion,
live-buffer free, duplicate proof owner, unknown reserve, corrupted capacity
and missing completion. After a slot finishes, table storage returns to an
idle pool without releasing capacity; a later proof may reuse that storage
only with a new generation. Its commitments are distinct and stay live until
the trusted driver certifies all downstream opening uses. Labels and events
are consistency checks, not authenticated completion or privacy proofs.

The decisive negative has background4,096B, known partial persistent payload
5,926,748,160B per proof and table capacity234,881,024B.
After one fold, the naïve length ledger admits proof2 at
12,205,821,952B. Actual modeled allocated capacity would
be12,323,262,464B:112MiB over its synthetic budget.
The correct gate refuses until completion/retirement permits safe reuse.
No actual large buffers were allocated for these projected values.

Baseline: sequential separate proofs, one admitted job. Eliminated work:
**zero field operations, zero fresh masking**; potentially amortizable native
launch/dispatch/idle barriers remain unmeasured. Added costs: simultaneous
PCS/witness state, routing, events, generations, reserves, failure isolation
and drain. End-to-end ceiling remains unknown N/(T-C_dispatch_critical+A_admit);
even free dispatch deletion is bounded by N/(T-C_dispatch_critical). A necessary
50/s condition is T-C_dispatch_critical+A_admit<=N/50. Falsify on any source/field/
transcript difference, incomplete owner/reserve, stale completion, actual
capacity cliff, or added cost exceeding exclusive launch savings.

Rank1 remains independently verified high-end-GPU fixed-context resident1/2/4/8
workloads. Rank2: admitted context/DD/fidelity scaling. Rank3: exclusive native
phase/capacity evidence. Local hypothesis95 is refined/tested; new96 asks for
whole-lifecycle reservation BEFORE witness/commit construction. If native data
remains absent, next local screen counts two-proof public phase envelopes with
simultaneous commit scratch, pooled idle and pending-release controls; it must
not invent timing or claim actual fit. Do not repeat toy batching variants.

Integration seam: frozen R13 `SumcheckRounds`, called from
`zk.rs::masked_prove_rounds` and `private_block/argument.rs::run_slot`.
Admission surrounds table construction and requires lifetime evidence from
`protocol.rs::prove_core` and each backend's allocation/completion API. Both
ClosureRounds and GroupedEqRounds truncate without shrinking. The owner
reviews and ports; no production patch or merge is supplied.

LIVE primary literature/repositories refreshed zkDuel (Oct26), MegaZK, gnark
v0.16.4 and CUDA/Rust docs. Newly assessed older STAlloc (v1Jul22/v2Nov25,2025)
requires non-overlapping address/lifetime intervals and actually free space;
its training results are not native proof evidence. Inspected implementation
commit3a9f97ff4896c46ffb65b229ba7347358b400387 has Apache2 headers; full license
body blocked and third-party notices unaudited. gnark release pin
e974abb44722dd201a7f1949baeabca0fef5866e is a release bump, not a tested GKR port.
Eight source records append to1,079 prior records. Exact/unknown dates, license
scope, pins, ACM403 and cache-miss URLs are in source-records.jsonl. No author
performance reproduced or downloaded code executed.

New independently verified full-stack proofs / complete-model passes / proved positions: **0 / 0 / 0**.
Actual model context: **none**. Device: one CPU affinity on Intel Core Ultra 9
185H, no GPU. Witness / proof / serialization / verification / startup /
initial-prefill clocks, startup fraction, proof latency/bytes, steady-state and
total-workload proved-token rates: **unmeasured**. No long-context prefill,
resident-model proof passes or decode ran. Metadata contexts17/32/64/127/128/
256/512 and synthetic cohort counts1/2/4 are not model runs or proved passes.
Larger workloads remain allowed; increased context can increase attention
quadratically. Complete private8B **>=50 proved tokens/s remains unachieved**.
No masks, pads, openings or private values reused for amortization.

Carried historical CPU8B baseline, not rerun/reverified/newly counted: T128/L32,
one16-thread GPU-off pass; total478.737s=0.267370positions/s. prove_run393.785s
includes witness98.348s/load17.595s. Preceding sealing84.824s contains overlapping
load27.151s/witness80.897s; never sum nested clocks. Receipt922,711,264B;
verify42.709s plus13.681s load. Startup fraction, serialization and steady slope
unknown. Current R18 classifier3B batch1418s vs singles1453s is a different
scope and is not private8B/high-end-GPU evidence; none counted here.

Each experiment stage: CPU affinity1,nice19,30s CPU/40s alarm/45s parent timeout,
384MiB address cap; audit estimate64MiB,compile300MiB. Final standalone Rust
compile1.278s/158,376KiB; audit0.171s/18,228KiB. Correctness execution clocks,
not proof clocks. Rustc1.75.0,one codegen unit; compiler helper-thread count
unobserved; one CPU affinity enforced. No dependency/native build or GPU run.
Commands,seed20261030163,input/source/artifact hashes and raw logs retained.

Only research outside runtime written. Production/Git/receipts/calibration/
safety/instructions/reviewer files untouched. No installation,foreign-code
execution,external write/message,purchase,escalation,merge or liveness claim.
Native owner/Claude reviews any integration. Reports do not establish delivery.

Reproduce sequentially from the research directory (prepare resets the local
hypothesis copy; use a fresh copy to preserve finalized reports):

```text
python3 experiments/public-cohort-admission-20261030/run_bounded.py prepare
python3 experiments/public-cohort-admission-20261030/run_bounded.py compile
python3 experiments/public-cohort-admission-20261030/run_bounded.py audit
```
`close.py` writes reports, not tests. See INTEGRATION.md for the interface.

Closing direction re-read: MVP_STATUS draft-version naming and DECISIONS C-9/security-owner/v3 text-check notes changed during this cycle. Exact diffs and current hashes retained; classifier privacy acceptance remains pending. No target or local experiment conclusion changed. Initial final-audit stop on document drift retained; this was an owner-document update, not a proof or experiment failure.

Final evidence audit PASS: 183 provenance/accounting checks, 10 unchanged native source pins, all 1,079 prior source records and prior FINDINGS bytes preserved; eight new source records. Closing checker schema assumptions were corrected for historical records and explicit current-cycle accounting; failed closing attempts retained. Final checkpoint 2026-10-30T11:56:44.181953+00:00.
