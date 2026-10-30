# Cycle0160 — same-capture fold attribution and completeness negative

20261030T084123Z-931751cb; checkpoint 2026-10-30T08:53:09.164593+00:00.

**No measured proving improvement.** The standalone Rust normalized trace
adapter passes225fixtures against an independent Python list-scan join and
endpoint-cell interval reference:182ordinary accepted,42malformed rejected,
and one deliberately accepted coherent-loss limitation. Comparisons cover
37,238numeric fields and6,495synthetic activity assignments. The42controls
include equal-count shuffled roles/folds,missing/duplicate IDs,wrong process/
context/stream/device,reported drops,unflushed data,unsupported graphs/runtime,
unknown timestamps and malformed shapes. API-to-activity fan-out remains valid.

Two-device/multistream records are synthetic IDs; **no GPU was used**.
In one explicit fixture the summed activity durations are42arbitrary ticks
while the same-device interval union is21. Neither is physical latency or
critical-path savings. Host and device domains stay separate; role unions
can overlap. The adapter is not a native parser or whole-function accountant.

The useful negative: coherently removing an entire call,its roster entry and
manifest counts passes both adapters. Local joins cannot authenticate capture
completeness. An independent invocation roster is required. Native collector
overhead,delivery/drop accumulation,unsupported/error coverage,clock alignment,
actual allocator retirement and complete-workload reconciliation are unmeasured.

Integration seam: hashline/src/gpu/cuda.rs::dev_fold_rows. Research candidate
adapter.rs::analyze consumes normalized private diagnostic metadata; SCHEMA.md
defines fields,selection limits and native collector obligations. No production
patch or native collector exists. GPU arithmetic,FS/RNG,masks,pads,openings,
transcripts and profiles are unchanged and untested by this metadata experiment.

Ranked queue:1complete verified high-endGPUresident workloads;2admitted
context/DD/fidelity scaling;3exclusive native phase/capacity evidence. All90
prior hypotheses preserved;91tests90,92adds independent-roster/drop obligations,
93refines an existing batching lead. No proof work eliminated; added costs are
observer/export/join overhead. The ceiling N/(T-C_critical+A_added) is unknown;
only measured safely removable critical-path time can supply C_critical.
Falsify promotion if collector ambiguity/perturbation,coverage/privacy mismatch
or no material safe-removable native cost remains.

Six LIVE primary records refresh CUPTI13.2.1(NVIDIA footerMarch16,2026),
gnark's exact October7release commit and its already-assessed September23batching
PR,MegaZK,September29operator-aware quantization,and the older nonlinear lookup
paper(metadata inspected;PDF403). gnark e974abb44722dd201a7f1949baeabca0fef5866e
release diff inspected; constituent implementation fetch cache-missed. README
license declarations are distinguished from blocked license-body inspection.
Exact dates,URLs,licenses,commit scope and fetch errors are recorded in
source-records.jsonl; no upstream performance reproduced or foreign code executed.
The batching lead was already assessed in cycle0093; the new work is the pinned
release refresh and concrete native dependency-census question.

Owner evidence: inspected current mandatory status/decision/coordination
documents and recent metadata. A bounded results inventory examined50,009paths
and hit its cap; it is not exhaustive. New r18fixed-entropy classifier3B batch/
singles diagnostics remain comparison/verification work in their own lane;
no new complete private8B high-endGPUphase capture was used or inferred absent
globally. No heavy job duplicated and no job liveness inferred.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context: **none**. Synthetic trace dimensions: 1..6 calls,
1..3 synthetic processes, two modeled devices, three modeled streams,
rows1..6, n1/2/4/8/16, k1..4, one/two APIs per phase and one/three
activities per API (all artificial; no physical device/context).
Device used: one affinity-pinned Intel Core Ultra 9 185H CPU worker; no GPU.
Witness / proof / serialization / verification / startup / initial-prefill
clocks, startup fraction, proof latency/bytes, steady-state and total-workload
proved-token rates: **unmeasured**. No long-context prefill, resident-model
proof passes or decode ran. Larger workloads remain allowed; increasing context
can increase dense-attention work quadratically. The complete private 8B
**>=50 proved tokens/s target remains unachieved**.

Carried historical CPU8B baseline, not rerun/reverified or newly counted:
T128, 32layers, one16-thread pass, GPUoff, total478.737s,
0.267370positions/s. prove_run393.785s includes witness98.348s/load17.595s;
preceding sealing84.824s includes overlapping load27.151s/witness80.897s.
Receipt922711264B; verify42.709s plus13.681sload. Serialization,startup
fraction and steady-state rate unknown. Never sum nested/overlapping clocks.
The shared-host one-block RTX4070 and current3B classifier receipts are
separate scopes; they do not establish private8B high-endGPU throughput.

Resource envelope per stage: one CPU affinity,nice19,30sCPU/40salarm/
45sparent,384MiBaddress cap; compile estimate300MiB,other stages64MiB.
Rustc1.75.0,opt-level2,onecodegenunit; auxiliary compiler thread count not
measured (oneCPUaffinity permits one CPU at a time). Correctness-execution
clocks: prepare 0.267s/23,708KiB; compile 3.750s/169,012KiB; audit 0.166s/23,536KiB. These are not proof benchmarks.

Owner: measure independently verified complete high-endGPU workloads at the
current admitted profile, including fixed-context resident1/2/4/8passes,
startup/drain,exclusive phases,actual capacity and failure/exclusion census.
Use the measurement interface only after collector/clock/drop/independent-roster
validation; no new synchronizations or private metadata publication.
Next bounded local experiment if those traces remain absent: a source-derived
23-slot compatibility census of(n,ext,degree),Points/challenge dependencies,
hosted masks and terminal/source bindings at argument.rs::argument/run_slot,
with an independent reference and shuffled-dependency control. Reuse cycle0093's
gnark assessment; do not port the scheduler or repeat packing/adapter variants.

Only research outside runtime written. No production/Git/receipt/calibration/
safety/instruction/reviewer edit, GPU/native build, dependency install, downloaded
script execution, external write/message, escalation or merge. The native owner
reviews and integrates any later patch. Saved reports do not establish delivery
or supervisor/job liveness. D46/D47/D48 do not amend this target or lane authority.

Reproduce sequentially from the research root:

```sh
python3 -B experiments/same-capture-fold-correlation-20261030/run_bounded.py prepare
python3 -B experiments/same-capture-fold-correlation-20261030/run_bounded.py compile
python3 -B experiments/same-capture-fold-correlation-20261030/run_bounded.py audit
```

`close.py` appends durable history; it is not a reproduction target.
Seed202610300841,fixtures,input/output,source pins,commands,hardware and capped
execution logs retained. Earlier222fixture result remains in initial-pass/;
the225fixture extension adds overlap,largeGPUclock and coherent-loss cases.
