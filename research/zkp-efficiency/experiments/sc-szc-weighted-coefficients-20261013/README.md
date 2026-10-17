# Suffix-weighted SC_SZC coefficients before original samples

Cycle0048, run `20261013T052555Z-bb2755b6`, 2026-10-13 UTC.
**Exact synthetic arithmetic candidate; no native proving speed measured.**

Question: after constructing a padded zero-check row's five coefficients,
can the driver sum suffix-weighted coefficients before evaluating samples?
For each unchanged integer sample t, linearity gives
`sum_i w_i * H_i(t) = (sum_i w_i * coefficients(H_i))(t)`.
The suffix weight does not depend on t; the active-coordinate group factor
still multiplies the resulting samples outside the sum. No public/private
coefficient value determines degree or scheduling.

The baseline is cycle47's selective padded row factory with the two host
brackets retained. The candidate keeps that construction and all data scans,
interpolation, folds, group weights, original sample coordinates, sample1
recovery and zero-factor fallback. Group0's five part slots hold weighted
coefficients instead of samples. Their reductions have the same width; only
after reduction are the coefficients evaluated. For the final one-row round,
public shape selects the baseline. Unpadded profiles also retain the baseline.
Coefficients remain internal private scratch; they are never serialized.

## Experiment and independent checks

128 fixtures / 1536 schedules pass
13,824 independent original-cube samples
and 41,472 ordered direct-MLE finals.
The oracle expands the original clause and uses a separate tuple field with
schoolbook extension multiplication; it has no coefficient/folding/cache code.
Every schedule also agrees with the retained cycle47 driver and identical row
construction counters. Ragged chunks1/3/7 and forward/reverse part reductions,
cube log n0..3, limb counts2/3, padded/unpadded, odd/even helper lists, arbitrary
extension/base/zero/Boolean data and challenges, and debug/release are covered.
There are 2,124 recoveries and 1,332 explicit
zero-factor fallbacks; debug checks computed versus recovered sample1.

Another60 arbitrary weighted-polynomial values cover full-extension sample
points, zero/Boolean/near-p values, and row counts1/2/3/7/16.
144 executed counter checks cover
nonzero recovery and zero-factor fallback against the analytic census.
Seven mutation/lifecycle controls detect omitted suffix weights, reversed
coefficients, lost parts, lost ragged tails, unfinished finals, fold before
round and double round. These are synthetic clauses, not honest native witnesses.

Final runtime **10.936208s**, peak RSS **20,788KiB**;
wrapper11.047126s; seed2026101348; one CPU0 nice19 thread on Intel Core Ultra9
185H. Wall/CPU59s and address-space512MiB caps, estimate64MiB. Commands, executed
source hashes and raw log are retained in command.json/execution.json/run.log.
Initial passing result and exact original source are retained under
initial-before-recovery-counter/. The final revision adds full-mode recovery
counter checks and an actual singleton regression; initial source hash matches.
No installation, downloaded execution, native build, GPU, masks, proof or
fresh independent receipt verifier ran. Experiment runtime is a shared-host
correctness/resource clock, not a kernel benchmark.

Reproduce from research directory:

```text
python3 -B experiments/sc-szc-weighted-coefficients-20261013/experiment.py
```

## Eliminated work, new costs and useful negative

Illustrative n23/ls3/padded/release/nonzero-recovery, part chunk1024:

| Counted operation | Cycle47 row samples | Weighted coefficients |
|---|---:|---:|
| Full Fp2 multiply | 2,118,123,271 | 2,122,317,573 |
| Fp2 by base multiply | 314,572,765 | 197,132,545 |
| Fp2 add | 2,957,073,930 | 2,843,828,012 |
| Fp2 subtract | 1,245,708,155 | 1,245,708,155 |

Native full multiplication uses five base products; mul_base uses two.
The candidate removes **1.906537%** of counted
base products and **3.413346%** of field API operations
relative to cycle47. Combined with that prior factory, counted base products
fall 16.565974% against
cycle33 compiled denominators. Combined counts do not establish compounding
time gains or a full-model speed.

Group0 Horner base products fall from117,440,500 to280. This includes the
final baseline row. Added cost is4,194,302 full coefficient-weight products
and corresponding accumulation additions; all row construction remains paid
again in every round. The census charges89,958 identical part-reduction adds
in each arm. P-1 binary merges are modeled; native rayon identity additions,
compiler simplification, instructions/traffic/parallel scheduling are unknown.
All384 census cases and their public schedules are in result.json. Selected
unpadded cases have zero saving. Debug/no-recovery savings may differ and
cannot substitute for release measurements.

Actual singleton regression: the unconditional policy emits the same values
but adds one full multiplication and one addition when sample1 is recovered.
That is five extra counted base products. The public half>=2 policy avoids
it; no secret coefficient is tested to prune degree. The negative is retained
in result.json rather than silently counting only favorable rounds.

Group0's output remains five Fp2 words (80 logical bytes) per part; no added
logical output slots versus the baseline. The existing row factory's five
scratch words remain. This excludes expression carriers, allocator overhead,
flags/type wrappers, registers/spills, thread scratch and actual peak RAM/VRAM.
The Python implementation stores small part arrays for validation; it is not
a proposed native memory allocator. Fixed arrays and reduce-owned scratch are
required in the owner translation.

## End-to-end ceiling and workloads

Historical native b2-gpu is a synthetic one-block125M/T512/one-pass diagnostic
on RTX4070Laptop8188MiB, driver566.14, two CPU threads, shared host:
witness5.77s, internal prove16.864s, SC_SZC7.794s, encode0.028s,
decode0.013s, in-process verify0.806s (from bytes~0.82s),
whole-test27.523873s and receipt40,783,352B. Encode is not the entire
serialization clock; startup boundary/fraction is absent. Both recurring
witness paths need attribution. No independent verification was run here.
Deleting that entire SC_SZC phase caps historical whole-wall savings at28.317%.
The 1.91% operation count cannot be converted to that many seconds.

The twelve-block synthetic125M/T512 one-pass RTX4070 diagnostic remains
408.609226s total,318.22s run prove,12.15s in-process verification,
484,107,456B and1.253diagnostic positions/s; fresh-process verification false.
The later CLI report is nonterminal and does not establish current liveness.
Neither is accepted private8B performance evidence.

For an actual complete workload the ceiling is
`N/(T - C_per_row_sample_Horner_and_weight + C_weighted_coefficients + C_round_Horner + C_changed_reduction_and_scratch)`.
Accepted8B total T and the affected critical-path costs are unmeasured; no
numeric ceiling or >=50/s inference follows. Witness/PCS/transfers and all
unaffected phases remain. Increasing prefill context may increase dense
attention quadratically; fixed-context resident passes and authenticated
later decode require separate measurements, fresh masks and complete coverage.

Accepted independently verified complete private8B proofs/passes/tokens:0.
Proof context null, deviceCPU only this cycle. Steady-state/total-workload rates,
startup seconds/fraction, witness/proof/serialization/independent-verification,
proof latency/lag/drain are unmeasured. No prefill/resident/decode proof ran.
The >=50 proved-token/s goal remains unchanged and unachieved. Larger workloads
remain permitted; no masking/opening reuse or weaker privacy is authorized.

## Integration, falsification and ranked queue

Read-only native seam: argument.rs SC_SZC1699, grouped definition1783,
GroupedEqRounds adapter553; grouped.rs part93, sample107, reduction121,
recovery132. Snapshots and SHA256 pins are in native-pins.json. Research patch:
weighted_rounds.py and uncompiled weighted_accumulator.rs; prerequisite is the
reviewed cycle47 fixed-array row factory and compiled denominator plan.
The existing GroupPoly callback only returns samples, so add an optional
immutable row-coefficient factory without exposing scratch to transcript code.
This cycle does not alter production source or merge anything.

Falsification: any native original sample/final/refusal/extension/byte mismatch,
changed RNG/challenge/PCS behavior, private degree-dependent dispatch, larger
peak/spills that cancel savings, compiler already eliminating the opportunity,
or slower enclosing complete workload rejects the candidate. A native phase
time without complete independently verified workload clocks is insufficient.

| Rank | Hypothesis, expected impact and prerequisites | Added costs and rejection condition |
|---|---|---|
|1 owner|GPU dominant SC_SZC plus recurring witness; largest measured scope, CUDA/memory integration high.|Both witness paths, row/fold/weight/recovery and enclosing clocks; native exact/privacy/peak/receipt/fresh-verifier gates. Reject mismatch or enclosing regression.|
|2 tested chain|Selective row factory plus weighted coefficient reduction; moderate Rust adaptation, prior compiled plan required.|Convolution/extra coefficient weights/part scratch/round Horner; benefit counted only. Reject native bytes/refusals/finals/masks, spill/peak or complete-time regression.|
|3 NEW local next|Public-axis specialization of row factory: mask and support are constant on some leading axes, so public metadata may remove convolution factors.|Derive actual current coordinate/support mapping, immutable per-round public dependency; do not infer degree from private values or alter samples. Charge factory dispatch/carriers/reduction. Reject generic extension-oracle mismatch, hidden-value branch or setup/count regression.|
|4 owner|Exact full-K split-int16down addresses recurring witness arithmetic; native affected share unknown.|Packing, two products, i64/requant/refusal/transfer/workspace; integer/profile/privacy/receipt/enclosing gain required.|
|5 workload|Fresh fixed-context resident complete-pass slope may amortize setup.|Context/pass/concurrency, startup fraction, fresh masks, latency/lag/drain/serialization/independent verification. Complete recurring cost>20ms/new proved position falsifies50/s for that schedule.|
|6 architecture|GKR/MLE lookup/PCS composition might remove larger costs; high migration cost.|Relation, quantization, joint hiding, setup, final oracle and full-proof soundness; public-input author operator aggregates cannot establish target.|

LIVE sources: coefficient reduction/wire boundary; NEWOctober11 Plonky3
release-candidate metadata (source failed, stable0.8 inspected); full-text
zkLLMPoT composition and public-input/operator-aggregation filter; NEWolder
May2013 Allspice static cost selection and protocol-specific batching.
Dates, exact URLs, licenses, unknown commit IDs and Internal Error blockers
are in source-records.json and search-log.json. No author's speed/security
claim reproduced. Rotation next: memory/batching, GPU commitments,
lookup/softmax, arithmetic; follow measured sumcheck bottleneck.

Next local: public dependency/axis-specialized row coefficients with unchanged
samples and fixed public output width, including head padding, full-extension
challenges and counter gates. Next owner: native factory plus typed coefficient
reduction, masked/frozen/refusal/final/extension/RNG/PCS and fresh verifier first;
then shared-lock peak/enclosing A/B with both witness paths and SC_SZC clocks.
No heavy job queued. Saved reports/handoffs are not delivery evidence.
