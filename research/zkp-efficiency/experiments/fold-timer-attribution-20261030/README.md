# Fold timer attribution — cycle 0159

Run `20261030T074123Z-71d2f333`, checkpoint 2026-10-30T07:55:01.314464+00:00. **No measured proving improvement.**

The extracted native `dev_fold_rows` body passes326 synthetic Rust executions
against an independently authored Python closed-form clock and bigint payload
reference:110 successes,216injected errors/panics,20malformed shape fixtures,
2934field checks and2,154 output limbs. Eight corruption controls reject.
The native function text is verbatim; surrounding device,clock,field wrapper,
mutex and allocator types are deterministic mocks. This does not execute CUDA,
native synchronization/failure behavior,PCS,FS,masking,receipts or privacy gates.

Source findings: t0 starts after gpu(),mutex acquisition and dev clone.
The counter samples inside STATS lock, after download and before conversion
and local buffer/guard drops; errors before it skip aggregation. Installed
cudarc0.13.9 synchronizes each copy wrapper's stream. Its async free can be
queued after the counter sample. None of these source observations establishes
a material omission from an enclosing complete-proof clock.

Six explicit Rust fixtures demonstrate these arbitrary-tick examples:

| Example | Old | Changed | Interpretation |
|---|---:|---:|---|
| Packing40→8ticks, prior stream busy until100 | helper109 | helper109 | Saving is absorbed by prior queued work |
| Same packing change, initially idle stream | helper49 | helper17 | Only this schedule saves32ticks |
| Mutex wait0→30ticks | counter17,helper17 | counter17,helper47 | Legacy counter misses the wait |
| Output conversion0→96ticks | counter17,helper17 | counter17,helper113 | Legacy counter misses conversion |

These are simulated clock units, **not physical measurements or speedup
estimates**. Python-only cases additionally exercise stats wait and integer
timestamps beyond2^53; that does not validate native floating counters or clock
alignment. Native memory peaks,driver semantics,contention and timed benefit
are unknown. Local device drops in the mock have charged host costs,not real
CUDA reclamation. No lock-placement or buffering optimization is proposed.

The leading hypothesis refines88 with tested89. All 88 prior hypotheses are
preserved;90adds causal correlation requirements before cross-capture profiling.
Global priorities remain complete verified GPU work,admitted context/DD/fidelity,
then exclusive phase/capacity clocks. Baseline,eliminated work,added cost,
prerequisites,exactness,privacy,compatibility and falsifier are recorded in
`leading-hypothesis.json` and `ranking-current.json`. No proof work eliminated
this cycle. Ceiling `N/(T-C_critical+A_added)` is unknown; counter fractions are
not automatically removable critical-path fractions.

Integration seam: `hashline/src/gpu/cuda.rs::dev_fold_rows`; interface unchanged.
[MEASUREMENT.md](MEASUREMENT.md) specifies an owner observer through return/drop,
error coverage,causal device activity and enclosing verification. No production
patch or native observer exists. Main/Claude reviews and integrates any later
instrumentation; no merge here. Fresh masks,pads,proximity,openings,RNG/FS/order
and P1/P3 gates remain unchanged and untested by this mock.

LIVE primary search records6sources: NVIDIA Nsight (updated2026-09-09), exact
CUDA12.4 stream semantics (2024-03-05), newly assessed Operator Profiler paper
(v1July4,v2September29,2026 per arXiv), cudarc native0.13.9 plus current release,
October26 StateSync1.2.1 release/license, and ICICLE release compatibility.
The installed cudarc commit e12b2d96877d0bae7266c01df14f257e95bb0020 was inspected.
Current StateSync BSL terms are version-specific; no code reused. Profiler root
LICENSE returned404; newest dependency commit fetches cache-missed. Exact
URLs,publication/update evidence,licenses and blockers are in
`source-records.jsonl`/`web-search-log.json`; no foreign code executed and no
performance claim reproduced. Do not transfer inference/profiler speedups or
sparseMerkle GKR results to the complete private transformer.

Reproduce sequentially from the research root:

```sh
python3 -B experiments/fold-timer-attribution-20261030/run_bounded.py prepare
python3 -B experiments/fold-timer-attribution-20261030/run_bounded.py compile
python3 -B experiments/fold-timer-attribution-20261030/run_bounded.py probe
python3 -B experiments/fold-timer-attribution-20261030/run_bounded.py audit
```

`close` appends durable history and is not a reproduction target. Preserve
snapshots or use a separate research copy. Commands,seed202610300741,
pins,fixtures and resource logs are adjacent. Source snapshots contain code
and research memory only; all experiment inputs are synthetic. Rustc1.75.0,
opt-level2,onecodegenunit. OneCPUaffinity,nice19,30sCPU/40salarm/45sparent,
384MiBaddress cap per stage; estimated compile300 MiB / other stages 64 MiB. Auxiliary
compiler thread count is unmeasured; affinity permits one CPU at a time.
Correctness-execution clocks: prepare: 0.171s / 15,148KiB maxRSS; compile: 1.173s / 161,416KiB maxRSS; probe: 0.017s / 7,596KiB maxRSS; audit: 0.033s / 16,300KiB maxRSS. These are not proof or GPU benchmarks.

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

Next: owner measures complete verified high-end GPU workloads and fixed-context
resident 1/2/4/8 passes, with current admitted profile, exclusive phases, actual
capacity and startup/drain. For this seam, measure GPU initialization, mutex wait/hold,
packing, allocation, H2D, kernel, D2H, STATS wait, conversion, drop submission and
actual retirement. Reconcile with an enclosing independently verified workload;
do not insert synchronizations just to separate timers. If owner traces are
absent next cycle, test a values-free same-capture correlation adapter with
equal-count shuffled-role and missing/duplicate-ID controls (hypothesis 90).
No more packing/staging variants without measured materiality.

Owner D46 safeguards and D47/D48 funding/release direction do not amend the
private 8B target or this research lane's permissions. No job liveness inferred
or owner heavy run duplicated. Only research outside runtime written; no
production/Git/receipt/calibration/instruction/safety/reviewer modification,
GPU/native build/dependency install/foreign script/external write/message/
privilege escalation or merge. Saved reports do not establish user delivery.
