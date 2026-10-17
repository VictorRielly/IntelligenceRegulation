# Public static multiplication plans and blocked 3x2 coefficients

Cycle0051, run `20261017T012624Z-ea61e714`. Synthetic CPU algebra and cost
accounting only. No native proof, compiled Rust, GPU result or native speedup.
Main/Claude owns review and integration; this directory is a candidate artifact.

Question: can public per-round schedules extend cycle50's affine Karatsuba
without hiding the added dispatch, arithmetic or temporary costs? Baseline is
cycle50 fixed2x2 Karatsuba in the public-axis, suffix-weighted row factory.

`static_plan.py` compiles fixed-width SSA multiplication kernels. A public
canonical-zero trace of the unchanged bracket records each operand width;
plans are cached within the proof-definition object by the three public
axis-dependency bits. No witness is supplied to preparation. Replay uses the
ordered plans, preserves declared output widths and does not test coefficient
values. The module-global adapter is single-thread harness scaffolding.

Width3x2 (and2x3) replaces6Fp2mul+2add by5Fp2mul+3add+2sub. Width2x2
retains the prior3-product helper. Other widths retain schoolbook arithmetic.
`blocked_helper.rs` is an uncompiled native interface sketch. Planner inputs
are public; constant challenges remain proof-local, and no mask/commitment/
opening or transcript state is cached across proofs.

Command from the research directory:

```
python3 -B experiments/static-poly-plan-20261017/run.py
```

Seed `2026101751`. Final run: 12.121455s, 23,164KiB RSS,
one nice19 Intel Core Ultra9 185H CPU thread pinned to CPU0. Caps:59CPU/wall
seconds,512MiB address space; parent timeout60s. Estimated memory64MiB.
Initial passing run is retained under `initial-before-executed-opcode-counter/`.
The final refinement counts each actually replayed field operation and every
opcode step; it does not infer execution counts from the compiled counter.

100fixtures/600schedules pass5,832independent original-cube round samples,
16,272direct-MLE finals,400independent convolution values and40arbitrary
extension full-clause values. 600executed row-delta checks and8zero/random
value-independent schema/count checks pass. There are888sample1recoveries
and660explicitzero-factor fallbacks. Even/odd lookups,raggedchunks1/3/7,
debug/release,padded/unpadded and logical-head fixtures are retained. Five
arithmetic/order mutation detections and the schedule assertion pass. The
separate tuple-ring/cube oracle does not call candidate field/fold/cache code.

Illustrative hp16/kv4/qh12/T512/3limb schedule versus cycle50:

|Quantity|Before|After or added|
|---|---:|---:|
|Counted base products|4,861,984,108|4,708,629,913 (-3.1541%)|
|Total field API|3,138,956,955|3,200,298,633 (+1.9542%)|
|Fp2mul removed|—|30,670,839|
|Fp2add / sub added|—|30,670,839 / 61,341,678|
|Per-row width tests|226,492,362|0 in replay;162 in preparation|
|Plan cursor reads|—|226,492,362|
|Public pattern lookups|—|4,194,303|
|Interpreter opcode steps|—|1,042,546,425|

This is a useful dispatch negative: an interpreted plan replaces width tests
with other dispatch; it does not eliminate dynamic scheduling. Only reviewed
native direct helper/unrolled translation could remove that overhead.
Preparation traces3patterns,charging61base-scales,482adds,559mul,248subs,
90denominator-dispatch steps and9axis tests. Plan pointer storage1,296logical
bytes plus512logical SSA bytes; Python object overhead is larger. Fixed
output80logical bytes is unchanged. The kernel liveness model peaks at5
intermediate field words, excluding inputs and the full row; the interpreter
retains up to15field words per multiplication instead of releasing dead SSA.
Neither metric establishes native registers,code size,spills or peak memory.
Six shape/limb census cases remove2.9041–3.1541% base products and add
1.8075–1.9542% field API; preparation and dispatch are separately charged.

Break even requires saved multiplication cost to exceed one added add and two
added subs per blocked product, plus the net trace/plan/cursor/code/scratch
cost. Reject any oracle/refusal/bytes/RNG/PCS/privacy mismatch or enclosing
regression. Entire historical SC_SZC removal caps one old125M/T512 RTX4070
whole-test saving at28.317%; this is neither an8B ceiling estimate nor a
scaling factor for product counts. Actual complete ceiling is
`N/(T_complete - saved_product_time + added_arithmetic_and_schedule_time)`;
its inputs are unmeasured on an accepted8B proof.

Source copies and hashes: `copy-provenance.json`, `command.json`,
`startup-manifest.json`, `native-pins.json`. All10native/measurement pins
match cycle50. `execution.json` retains actual exit0. `result.json` retains
all rounds,dimensions,setup/census and proof accounting. `sources-cycle51.json`
retains LIVE primary sources,dates,license scope and exact fetch failures.

Accepted complete private8B proofs/passes/tokens0;proof contextnull,CPU only.
Steady-state/total-workload rates,startup seconds/fraction,witness/proof/
serialization/independentverification,latency/lag/drain unmeasured. No
long-context prefill,resident pass or decode proof. Larger workloads remain
allowed with quadratic attention,fresh masks and full privacy/coverage.

Next LOCAL: whole-row public SSA identity reuse,including shared affine sums
and structural squaring; charge graph construction,liveness and adds,never
private-value equality. Next OWNER: fixed-array translation and full native
masked/frozen/refusal/final/RNG/PCS/fresh-verifier gates,then guarded SC_SZC
subphase/peak/enclosing A/B with both witness paths. No heavy job queued here.
