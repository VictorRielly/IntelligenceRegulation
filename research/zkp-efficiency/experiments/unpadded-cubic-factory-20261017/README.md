# Unpadded cubic round-zero factory — cycle0054

Run `20261017T042624Z-0f7bf604`; checkpoint 2026-10-17T04:37:37.221578+00:00.

**Promising counted arithmetic; no native speed improvement established.**
The broad factory passes algebra but loses useful cost properties after h1
recovery. A public round-zero-only policy lowers all four counted field API
categories versus prepared scalar evaluation on the full-head T512 shape.

The final bounded run passes 1,890 schedules over63 fixtures,
19,650 independently computed round samples,
43,920 final values,144 arbitrary-extension clause
checks,12 zero/random value-independent row censuses,20 concrete-versus-
allocation-free counter checks and3 padded-factory refusals. Five mutation
controls detect dropped cubic coefficients,reversed coefficients,missing suffix
weights,dropped reduction parts and ragged tails. There are732 recovered
samples and708 zero-factor fallbacks in baseline schedules; all five modes
agree on per-group pending outputs,claims,finals and folding/equality work.
Wall 10.054167s,RSS22,184KiB;wrapper exit0. These are
synthetic CPU correctness clocks,not proving clocks.

Reproduce only the bounded local experiment:

```bash
python3 -B /home/victor/IntelligenceRegulation/research/zkp-efficiency/experiments/unpadded-cubic-factory-20261017/run.py
```

Seed2026101754. Standard library only;one thread,nice19,59s alarm/CPU cap,
512MiB address-space limit;estimated experiment memory64MiB. No model-sized
arrays. Fixtures cover cube logs0–4 plus a32-cell executed census,2/3 limbs,
7/8/full lookup counts,zero/Boolean/full-extension data,causal public masks,
chunk lengths1/3/7 and the source-policy chunk model,debug/release recovery.
`prior-result.json` retains accounting only. Code/logs/input pins are local.

## What changed and what stays to validate

`cubic_factory.py` provides `CubicPlan` and `CubicRounds`. Only public
`pad_on=false`,round index0 and row count>=2 select the factory. Mask slope
width comes from public coordinate dependencies. There is no witness-dependent
zero/degree pruning. Four bracket coefficients are suffix-weighted and reduced,
then evaluated at the original0,1,2,3;the original five outer samples remain.
Later rounds and the two hosted groups use prepared scalar brackets. Native
masking,Fiat-Shamir,RNG,PCS,constructor and verifier were not executed.

Baseline round0 computes4 expensive brackets per row;later rounds compute3
when h1 recovery is valid. A blanket factory ignores that break-even change.
For three limbs,constant-mask axes after round0,Karatsuba adds22 Fp2mul,
saves10 mul_base,and adds31 add/13 sub per row versus prepared scalar.
Round0 instead saves17 mul,20 mul_base,5 add and17 sub per row,then pays
one final Horner evaluation. These are field API counts,including literal
unit/zero operations;LLVM may already remove some of that work.

## Allocation-free full-head census

hp32/kv8/qh32/T512,no S lift,three limbs,cube log23. The scope is scalar or
coefficient bracket construction + suffix-weighted accumulation + modeled
part reduction + Horner + denominator preparation. It excludes common
Eq/interpolation/recovery/folds,PCS/masks,witnesses,transfers and serialization.
The source `small` threshold and1024-row chunk rule are modeled with port
carrier count;8 part words are common to every mode. Native Rayon identity-fold
adds are not fixed by part count and are uncounted. This is no native timing.

|Mode|Fp2 mul|Fp2 mul_base|Fp2 add|Fp2 sub|API total|
|---|---:|---:|---:|---:|---:|
|literal|1,220,542,341|629,145,536|1,518,403,310|922,746,786|4,290,837,973|
|prepared_scalar|1,220,542,341|306,184,161|1,107,361,575|893,386,676|3,527,474,753|
|cubic_schoolbook|1,345,060,651|180,617,338|1,118,633,842|676,069,316|3,320,381,147|
|cubic_karatsuba|1,244,397,379|180,617,338|1,219,297,114|877,395,860|3,521,707,691|
|cubic_round0|1,149,239,173|222,298,090|1,086,390,064|822,083,508|3,280,010,835|

The round-zero policy removes **7.0153%** of that API total versus prepared
scalar;the larger23.5578% drop versus literal includes denominator preparation
benefits and must not be attributed to the cubic factory. Candidate-versus-
prepared deltas are -71,303,168 Fp2mul,-83,886,071 mul_base,-20,971,511 add,
-71,303,168 sub. Literal native `Fp2` API expansion gives -524,287,982 base mul,
-184,549,358 base add,-142,606,336 base sub;this is an unoptimized source-call
expansion,not machine instructions or cycle estimates. T1024 work is roughly4x,
not an amortization win. Two-limb and hp16 variants are retained separately.

Added costs:15 prepared denominator offsets (30 charged field ops and15 public
classifications),four output coefficients/64 logical bytes per row,additional
polynomial temporaries,public policy/dependency tests and dynamic width dispatch.
The T512 round-zero path records159,383,552 public width tests and50,331,648
2x2 Karatsuba products in the harness. Denominator dispatch is explicitly
charged per scalar sample/coefficient carrier. The per-part8-word accumulator
has the same128 logical bytes in each mode. Native registers,peak scratch,
allocation,code size and affected/enclosing runtime remain unknown. The local
Python interpreter's bounded RSS cannot establish native device memory.

## Baseline, ceiling and hypotheses

Historical measured baseline, not re-run: one synthetic125M block,T512,
one pass,RTX4070Laptop; SC_SZC7.794s,proof16.864s,witness5.77s,encode0.028s,
decode0.013s,in-process verification0.806s,enclosing test27.523873s,
40,783,352B. Startup and both recurring witness clocks are not separated.
Removing the entire SC_SZC phase would save at most28.317% of that enclosing
measurement. This is not an8B estimate; a7.0153% API-count reduction does not
imply that fraction of phase time. Complete8B ceiling remains
`N/(T_complete - saved_recurring_scalar_time + added_factory_dispatch_scratch_time)`.
Round0 recurs on **every proof**; it is not amortizable process startup.
The historical synthetic12-block/T512/one-pass GPU-arm test is408.609226s
whole,318.22s prove,12.15s in-process verify,484,107,456B (~1.253 complete
synthetic positions/s over enclosing test);trained=false,privacy accepted=false,
fresh-process verification=false. No accepted private8B token credit follows.


|Rank|Hypothesis, baseline / eliminated work / added costs / falsifier|
|---|---|
|1 owner|Move dominant SC_SZC and both recurring witness paths to GPU. Baseline native synthetic measurements below; remove CPU recurrence, add CUDA transfers/device storage/dispatch. Require native exact/masked/final/RNG/PCS/refusal and fresh-verifier gates; reject mismatch,overflow,peak or enclosing-time regression. Full8B ceiling unknown.|
|2 local, refined and tested|Use four coefficients only for unpadded group0 at round0; scalar evaluation after h1 recovery. Eliminates four repeated scalar brackets on that round; adds four-word construction/weighting,Horner,denominator setup and public dispatch/scratch. Counted scoped gain7.0153% versus prepared scalar at full-head T512,not time. Next: fixed straight-line factory to remove dynamic width dispatch. Reject native parity/refusal/RNG change or added costs erasing arithmetic savings.|
|3 workload owner|Measure resident complete passes at fixed context with fresh masks and full coverage. Baseline startup/slope unmeasured. Eliminate only actually reusable model/public setup; add residency/cache validation,all per-proof masks,lag/drain and verifier costs. Recurring wall above20ms/new proved position rejects50/s for that schedule. Long prefill and decode require separate measurements and state binding.|
|4 owner|Exact full-K split-int16 FFN-down witness. Remove slow scalar products; add packing,two products,i64 recombination,exact requant/refusal,transfer and scratch. Require integer/native receipt parity and lower enclosing time; affected fraction/8B ceiling unknown.|
|5 conditional owner|Existing padded fixed-array/weighted/denominator chain; useful only where native supports exist. Charge added adds/subs/code/scratch. Require native masked/refusal/RNG/PCS/privacy/fresh-verifier gates and lower elapsed time. No padded gain transferred to full-domain8B.|
|Demoted|Blanket unpadded cubic construction after recovery: on three-limb full-head axes it adds22 Fp2mul per row versus prepared scalar (33 on moving mask axes),while saving10/9 mul_base and adding other work. Keep negative. Prior native fold fusion was1.66% slower mean prove/10.38% slower softmax; prior CSE,twiddle,memory and arithmetic negatives remain. Dory/Fold-DCS/binary-field architectures need new relation/hiding/composition work.|


LIVE search covered GPU NTT/commitments and memory overlap,coefficient
sumcheck,lookup/softmax interfaces and composition. New older Dory paper
(received2020-10-14,revised2021-11-18) and v0.4.2(Aug20,2026) release inspection
add a PCS/state-binding filter; release commit5246da503c3e2c6baa40ec00d714987c73a3e6eb
was inspected. EPFL's concrete coefficient source uses EvalsInfty and plain
non-ZK sumcheck,so it cannot replace native samples/masking directly. Fold-DCS's
PCS instantiation explicitly does not require hiding. NVIDIA's July15 clmad
article concerns characteristic-two fields. ICICLE transfer overlap charges
two device vectors. October16 Plonky3 BLAKE2s metadata is not keyed BLAKE3
compatibility. New October FAEST discovery could not be primary-inspected:
eprint2026/2489 and its PDF were not accessible; no claim adopted. Seven
records retain exact URLs,verified versus unknown dates,failed license/commit/
package/PDF fetches and unreproduced author claims. Actual Dory/EPFL license
terms were unavailable; repository license labels are not a verified license.
No foreign code was copied/executed,installed or benchmarked. Next rotation:
lookup/softmax table traffic,public dependency-specialized kernels,composition.


## Reviewable seam and next action

`ops/zkp-mvp/candidate/hashline/src/private_block/argument.rs` SC_SZC1699,
groups1783,bracket1788 and `zkp-core/src/sumcheck/grouped.rs` row/part93,
samples107,reduction121,recovery132. These two candidate files hash-identically
to the sonnet-hardening pinned copies;root main has a different older argument.
All11 old source/measurement pins match. `active-seam-comparison.json`,
`native-current-comparison.json`,`copy-provenance.json`,`command.json`,
`execution.json`,`sources-cycle54.json` and `research-source-diff.patch`
retain provenance. Initial successful broad-factory and later accounting
refinements remain in named subdirectories;none is a native proof.

Next LOCAL: generate a fixed straight-line unpadded round0 factory,selected
only by public metadata,then audit liveness and eliminate dynamic width tests.
Compare every output and actual API census against literal/prepared/fixed
factories;do not transplant padded estimates. Next OWNER: native profile/privacy/
refusal/masked/RNG/finals/PCS/fresh-verifier gates,then guarded three-arm timing
(literal,prepared scalar,prepared+round0) with both witnesses,peak memory and
resident complete workload clocks. No build/heavy/GPU job is queued here.

Accepted independently verified complete private 8B proofs/passes/tokens: **0/0/0**.
Proof context length is null. Current device: one Intel Core Ultra 9 185H CPU
thread, nice19, affinity CPU0; no GPU job. Steady-state and total-workload rates,
startup seconds/fraction, witness/proof/serialization/independent-verification
clocks, proof latency/lag/drain are **unmeasured**. No long-context prefill,
resident-model pass or decode proof ran. Synthetic cube tests use up to32 cells;
T512/T1024 rows below are allocation-free arithmetic, not accepted profiles or
proofs. Doubling context quadruples the modeled attention cube work. Larger
workloads remain allowed; no mask reuse, privacy weakening or target change.


Only research artifacts changed. No production/runtime/Git/receipt/calibration/
instruction/reviewer mutation,installation,external message or merge. Saved
reports do not establish user delivery or job liveness.

Final evidence audit: 445 integrity/accounting checks pass (2026-10-17T04:38:46.046132+00:00); no owner memory file changed during this cycle. The initial auditor incorrectly required an id on every historical source record; five old records omit it. That failure is retained, and the corrected check preserves the historical ledger and verifies seven new unique ids. No native proof or performance gate is implied.
