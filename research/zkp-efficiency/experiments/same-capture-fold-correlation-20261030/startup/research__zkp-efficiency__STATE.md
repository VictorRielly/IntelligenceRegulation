# ZKP efficiency explorer — durable state

Cycle 0159 COMPLETE: `20261030T074123Z-71d2f333`.
Started2026-10-30T07:41:23Z; checkpoint2026-10-30T07:55:01.314464+00:00.
Deadline08:01:23Z; next cycle no earlier than08:41:23Z.
Read AGENDA.md EVERY cycle.

**No measured proving improvement.** Current native fold body passes326mock
Rust fixtures with synthetic device/clock/types,110 successes and216 errors/
panics. Independent Python closed-form timing/bigint reference checks2,934
fields and2,154 output limbs; 8 corruption controls reject. Six explicit mock
cases show 32 arbitrary ticks of packing savings yielding 0 or 32 helper ticks saved.
This is source-boundary evidence,not native/proof/device/privacy performance.

The legacy counter omits GPUinitialization/mutex/clone before t0 and conversion/local
drops after sample; STATS wait is included; pre-sample errors do not aggregate.
cudarc sync wrappers cover earlier stream work; asyncfree may remain queued.
No source finding establishes a material omission from enclosing proof clocks.
No locks,dependencies,FS/RNG,masks,pads,private openings or profiles changed.

Global ranking:(1)verified complete high-end GPUresident1/2/4/8workloads;
(2) admitted context/DD/fidelity; (3) exclusive phase/capacity measurements.
All 88 prior hypotheses preserved; 89 tests 88; 90 adds a correlation obligation. Ceiling
N/(T-C_critical+A_added),unknown; no secs_fold-fraction Amdahl claim.

Next: owner measures complete verified high-end GPU workloads and fixed-context
resident 1/2/4/8 passes, with current admitted profile, exclusive phases, actual
capacity and startup/drain. For this seam, measure GPU initialization, mutex wait/hold,
packing, allocation, H2D, kernel, D2H, STATS wait, conversion, drop submission and
actual retirement. Reconcile with an enclosing independently verified workload;
do not insert synchronizations just to separate timers. If owner traces are
absent next cycle, test a values-free same-capture correlation adapter with
equal-count shuffled-role and missing/duplicate-ID controls (hypothesis 90).
No more packing/staging variants without measured materiality.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context: **none**; synthetic row-fold shapes use rows 0/1/3/7,
n 1/2/4/8 and k 1..4, plus malformed k 0/5. These are not model contexts.
Device: one affinity-pinned Intel Core Ultra 9 185H CPU worker; no GPU.
Witness / proof / serialization / verification / startup / initial-prefill
clocks, startup fraction, proof latency/bytes, steady-state and total-workload
proved-token rates: **unmeasured**. No long-context prefill, resident-model
proof passes or decode ran. Larger workloads remain allowed; context growth
can raise dense attention work quadratically. Complete private 8B **>=50
proved tokens/s remains unachieved**.

Carried historical CPU8B baseline, not rerun/reverified or newly counted:
T128,32layers,one16-thread pass,GPUoff,total478.737s,0.267370positions/s.
prove_run393.785s includes witness98.348s/load17.595s; preceding sealing84.824s
includes overlapping load27.151s/witness80.897s. Receipt922711264B;
verify42.709s plus13.681sload. Serialization,startup fraction and steady-state
rate unknown. Never sum nested or overlapping clocks. Shared-host one-block
RTX4070 results and current3B classifier receipts do not establish private 8B
high-end GPU throughput. No high-end GPU workload evidence was added here.

Six LIVE source records 1049→1055. See
source-records.jsonl/web-search-log.json for exact dates/URLs/licenses/errors.
NewProfilerpaper assessed; cudarc 0.13.9 commit e12b2d96877d0bae7266c01df14f257e95bb0020
inspected. Current StateSync 1.2.1 BSL license is version-specific; no reuse.
No upstream timing reproduced. Current native pins match at checkpoint.
Owner D46 safeguards, D47 funding hold and D48 release direction do not amend this target
or research permissions. No job liveness inferred or heavy run duplicated.

One CPU affinity, nice 19, 30 s CPU / 40 s alarm / 45 s parent / 384 MiB cap per stage;
compile estimate 300 MiB, other stages 64 MiB; auxiliary compiler threads unmeasured.
Correctness execution: prepare: 0.171s / 15,148KiB maxRSS; compile: 1.173s / 161,416KiB maxRSS; probe: 0.017s / 7,596KiB maxRSS; audit: 0.033s / 16,300KiB maxRSS.

[Experiment](experiments/fold-timer-attribution-20261030/README.md) ·
[Handoff](handoffs/20261030-fold-timer-attribution.md) ·
[Dated report](progress/20261030T074123Z-71d2f333.md).
Startup snapshots/index retained; previous findings and sources append-only.
Only research outside runtime written;no production/Git/receipt/calibration/
safety/instructions/reviewer edits,GPU/nativebuild/install/externalwrites/
messages/escalation/merge. Saved reports do not establish delivery.
