# Use-driven D affine contributions — cycle 0079

Run `20261019T111854Z-5ff11116`, 2026-10-19 UTC. **Useful logical-lifetime
improvement; no native proving speedup measured.** Consuming each combined
affine term when its source is first needed by other work lowers the current
unpadded D catalogs' complete logical peak **77→27 Fp2 words (64.94%)**.
This saves 800 logical bytes per active row worker, including all live
original endpoints, construction high-value temporary and five-word round
accumulator. Python keeps graph/cache/oracle values; its RSS does not
implement the modeled releases. This is not a register, VRAM or latency result.

The comparison baseline is cycle78's **unintegrated coefficient prototype**
with first-use endpoint construction, streamed helper pairs, and affine
contributions front-loaded before bilinear/helper work. It is not an A/B
against the installed native sample evaluator. The proposed native adapter
needs the preceding coefficient/lazy/streaming work too.

`run.py::lazy_row(raw,p,use_driven=True)` accepts the current MSB low/high
pairs and the proof-local plan from `prior-run.py::plan`, returning five
row coefficients. A memoized endpoint's combined affine coefficient is
consumed exactly once at first use. Public affine-only sources are drained
after helper work. All alias weights are combined by table index before this
step. Endpoint fetches precede capture of the updated clause accumulator;
otherwise an implementation could accidentally discard a just-added term.
No branch depends on a field value, and zero coefficients keep their work.

Run from the research directory:

```bash
python3 experiments/dzc-use-driven-affine-20261019/run.py
python3 experiments/dzc-use-driven-affine-20261019/audit.py
python3 experiments/dzc-use-driven-affine-20261019/cost_accounting.py
```

Commands/results retained in execution JSON, logs and result JSON. Each script
sets one nice19 CPU affinity, 59s CPU/wall, 512MiB address space. Main compiles
only the small captured local Rust reference, one codegen unit, opt-level0,
no Cargo/dependency install/GPU. Final main **12.651142s**, RSS56024KiB;
compiler134256KiB. Audit **0.587274s**, RSS27840KiB. Cost audit0.021398s,
RSS21592KiB. Device: Intel Core Ultra9 185H CPU0, WSL2. These correctness-test
clocks are not an optimized baseline/candidate performance comparison.

Thirty synthetic fixtures, N2/8/32, seed2026101979: 1,950 candidate coefficients,
2,145 captured-Rust grid and390 off-grid comparisons,90 round messages,
1,845 original cube finals,30 final relations,30 permutations/aliases,
30 affine-only drains,390 operation/read censuses and value-independent traces.
Twelve controls detect duplicate affine application, lost aliased weights,
missing affine-only drain, no memoization, wrong helper pairing/order, lost
degree, stale mu/claim, wrong MSB order and missing padding support.
Independent **681-check audit** uses interval sweeps/direct live sets and an
exact source/weight census for every affine contribution. Six live source
pins remain unchanged. Reference: complete captured Rust D/catalog with exact
u128 field and Shape/Layout substitutes, plus independent Python clauses/
direct cube. Actual admission/challenges/RNG/transcript/masks/PCS/proofs remain
owner gates. Synthetic alpha/g_u8 are fixture constants, not reusable setup.

| Current unpadded T128 catalog, per row pair | Cycle78 baseline | Candidate |
|---|---:|---:|
|Complete logical peak, Fp2 words|77|27|
|Endpoint words at the peak|54|4|
|Derived words at the peak|18|18|
|Round accumulator words|5|5|
|Original endpoint reads/differences|118/59|118/59|
|Coefficient+endpoint add/sub/mul/base calls|272/209/331/72|272/209/331/72|
|Combined affine source weights consumed|33|33|
|Original full tables/folds/finals|59|59|

Original folds remain a separate challenge-dependent pass:118 reads,59 writes,
59 each add/sub/mul per row pair. Combined counts331/268/390/72 exclude common
round reduction, conversion, plan and enclosing proof work. No table added or
removed. Both actual public T128 catalogs have35 A columns,34 lookups and17
helpers, four limbs/32bits, unpadded D. The counted N524288/19round geometry was
never allocated or proved here.

Limits and negatives: generic padded catalogs only93→87 words (five-limb
101→95), because their later pad sum keeps source pairs live. This is not a
trained padding benchmark. Retaining candidate endpoints until function end
raises the peak to136 words. Candidate recomputation without memoization raises
reads118→138/differences59→69; baseline's no-memo control is198/99. Alias/fallback
controls reject uncharged omissions. No native scalar scratch, compiler
allocation, dispatch cost, memory latency or physical spills are modeled.

Baseline/eliminated/added/ceiling: remove early source lifetimes only, with
unchanged field arithmetic and original-table work. Charge public dependency
planning, first-use/alias dispatch, accumulator maintenance, static code size
and native compiler scheduling/spills. Native adapter cost is moderate on top
of unintegrated prerequisites; whole-prover integration remains substantial.
`new_total = old_total - old_affected_D + new_D + all_integration_costs`.
No measured conversion from27 logical words to seconds exists.

NEW clock accounting reads, without re-running, three retained full 8B T128
CPU diagnostics. Latest R6/b7:32 blocks,one pass,16 Rayon threads,GPUoff,
**471.580s total**,370.137s proof region (nested witness94.021/load17.408),
sealing101.279s,receipt922711264B. D phase **44.833s**,9.507% of total.
Deleting ALL D at zero cost caps this diagnostic at **1.105058×** and
**0.299944 diagnostic positions/s** (baseline0.271428). This is not this
candidate's prediction, accepted private throughput, GPU bound or steady slope.
R5b shared606.598s/D61.164s and quiet432.539s/D43.292s remain separately labeled.
Fresh R6 verify34.587s plus load11.599s; guard146.473062s includes controls.
Recheck32.311s plus load9.903s,guard42.276335s. Serialization/startup fraction/
steady slope are unisolated. Sealing fraction is not a startup measurement.
Clock parser independently matches32 D rows/32 blocks; source hashes retained.

Latest distinct owner next-token diagnostic remains context32/32blocks,one CPU
pass:191.7s proving,nested witness17.3s,230.5s test total,fresh verify43.4s,
471285072B. R3 independent soundness review now permits the result to stand;
reviewer fresh verify37.7s/second route41.8s. Privacy gate remains pending.
No receipt was reverified by this researcher; do not mix its clocks with R6.

Sources: LIVE rotation covered lookup/softmax and arithmetic/quantization.
[Bits Under ZK-LLM](https://arxiv.org/abs/2609.36437) was refreshed with its
excluded-clock/small-model scope; the older
[Min-Reg scheduling paper](https://arxiv.org/abs/2303.06855) is newly assessed
and motivates checking native latency/resource tradeoffs. DeepProve's concrete
softmax prose/current README/custom license and current Plonky3 release/mask
RNG PR were inspected; known packed-sumcheck README refreshed. Five records,
exact dates/license/commit/access failures in source-records.json. No foreign
implementation or author benchmark reproduced.

Falsify on any coefficient/sample/final/degree/transcript/RNG/refusal/privacy
mismatch, duplicated or lost alias term, value-dependent scheduling, extra
uncharged reads, no actual native resource reduction, or enclosing regression.
Next local experiment: emit static named Rust locals from the public first-use
schedule and compare lowered scalar lifetimes/full arithmetic against the
77-word baseline; keep proof-local coefficients as runtime parameters. Then
owner checks actual compiler allocation and full D timing under shared locks.

Seam: SC_DZC / SumcheckRounds; see the
[unapplied handoff](../../handoffs/20261019-dzc-use-driven-affine.md).
No native edits or merge. Preserve original helper, host/padding terms,
pending/recovery, all original folds/finals, fresh per-proof masks/openings and
joint-view privacy. D30 dictionary remains a separate unbuilt profile.

New target full-stack proofs/passes/positions **0/0/0**, device none. Target
context, steady/total rates, startup fraction, witness/proof/serialization/
verification clocks unmeasured. No prefill,resident series or decode ran.
Larger workloads remain allowed; attention can grow quadratically with context.
Complete private8B >=50 proved tokens/s on5090/namedhigh-endGPU unchanged and
unachieved. Only research files changed; runtime/production/Git/receipts/
calibration/safety/instructions/reviewer files untouched.
