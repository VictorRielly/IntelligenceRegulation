"""Produce research reports from retained local evidence; no native mutations."""
from pathlib import Path
import datetime,difflib,hashlib,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
run='20261017T042624Z-0f7bf604';now=datetime.datetime.now(datetime.timezone.utc).isoformat()
r=json.loads((HERE/'result.json').read_text());e=json.loads((HERE/'execution.json').read_text());assert e['exit_code']==0
p=next(p for p in r['projections'] if p['limbs']==3 and p['shape']['head_pad']==32 and p['shape']['tokens']==512)
b=p['results']['prepared_scalar'];c=p['results']['cubic_round0'];pct=100*(b['sum_api_ops']-c['sum_api_ops'])/b['sum_api_ops']
rows=[]
for m in ('literal','prepared_scalar','cubic_schoolbook','cubic_karatsuba','cubic_round0'):
 q=p['results'][m];cc=q['all_field_ops'];rows.append('|'+m+'|'+ '|'.join(f"{cc.get(k,0):,}" for k in ('mul','mul_base','add','sub'))+f"|{q['sum_api_ops']:,}|" )
table='|Mode|Fp2 mul|Fp2 mul_base|Fp2 add|Fp2 sub|API total|\n|---|---:|---:|---:|---:|---:|\n'+'\n'.join(rows)
account='''Accepted independently verified complete private 8B proofs/passes/tokens: **0/0/0**.
Proof context length is null. Current device: one Intel Core Ultra 9 185H CPU
thread, nice19, affinity CPU0; no GPU job. Steady-state and total-workload rates,
startup seconds/fraction, witness/proof/serialization/independent-verification
clocks, proof latency/lag/drain are **unmeasured**. No long-context prefill,
resident-model pass or decode proof ran. Synthetic cube tests use up to32 cells;
T512/T1024 rows below are allocation-free arithmetic, not accepted profiles or
proofs. Doubling context quadruples the modeled attention cube work. Larger
workloads remain allowed; no mask reuse, privacy weakening or target change.
'''
queue='''|Rank|Hypothesis, baseline / eliminated work / added costs / falsifier|
|---|---|
|1 owner|Move dominant SC_SZC and both recurring witness paths to GPU. Baseline native synthetic measurements below; remove CPU recurrence, add CUDA transfers/device storage/dispatch. Require native exact/masked/final/RNG/PCS/refusal and fresh-verifier gates; reject mismatch,overflow,peak or enclosing-time regression. Full8B ceiling unknown.|
|2 local, refined and tested|Use four coefficients only for unpadded group0 at round0; scalar evaluation after h1 recovery. Eliminates four repeated scalar brackets on that round; adds four-word construction/weighting,Horner,denominator setup and public dispatch/scratch. Counted scoped gain7.0153% versus prepared scalar at full-head T512,not time. Next: fixed straight-line factory to remove dynamic width dispatch. Reject native parity/refusal/RNG change or added costs erasing arithmetic savings.|
|3 workload owner|Measure resident complete passes at fixed context with fresh masks and full coverage. Baseline startup/slope unmeasured. Eliminate only actually reusable model/public setup; add residency/cache validation,all per-proof masks,lag/drain and verifier costs. Recurring wall above20ms/new proved position rejects50/s for that schedule. Long prefill and decode require separate measurements and state binding.|
|4 owner|Exact full-K split-int16 FFN-down witness. Remove slow scalar products; add packing,two products,i64 recombination,exact requant/refusal,transfer and scratch. Require integer/native receipt parity and lower enclosing time; affected fraction/8B ceiling unknown.|
|5 conditional owner|Existing padded fixed-array/weighted/denominator chain; useful only where native supports exist. Charge added adds/subs/code/scratch. Require native masked/refusal/RNG/PCS/privacy/fresh-verifier gates and lower elapsed time. No padded gain transferred to full-domain8B.|
|Demoted|Blanket unpadded cubic construction after recovery: on three-limb full-head axes it adds22 Fp2mul per row versus prepared scalar (33 on moving mask axes),while saving10/9 mul_base and adding other work. Keep negative. Prior native fold fusion was1.66% slower mean prove/10.38% slower softmax; prior CSE,twiddle,memory and arithmetic negatives remain. Dory/Fold-DCS/binary-field architectures need new relation/hiding/composition work.|
'''
baseline='''Historical measured baseline, not re-run: one synthetic125M block,T512,
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
'''
source_summary='''LIVE search covered GPU NTT/commitments and memory overlap,coefficient
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
'''
readme=f'''# Unpadded cubic round-zero factory — cycle0054

Run `{run}`; checkpoint {now}.

**Promising counted arithmetic; no native speed improvement established.**
The broad factory passes algebra but loses useful cost properties after h1
recovery. A public round-zero-only policy lowers all four counted field API
categories versus prepared scalar evaluation on the full-head T512 shape.

The final bounded run passes {r['counts']['full_schedules']:,} schedules over63 fixtures,
{r['counts']['independent_round_samples']:,} independently computed round samples,
{r['counts']['independent_final_values']:,} final values,144 arbitrary-extension clause
checks,12 zero/random value-independent row censuses,20 concrete-versus-
allocation-free counter checks and3 padded-factory refusals. Five mutation
controls detect dropped cubic coefficients,reversed coefficients,missing suffix
weights,dropped reduction parts and ragged tails. There are732 recovered
samples and708 zero-factor fallbacks in baseline schedules; all five modes
agree on per-group pending outputs,claims,finals and folding/equality work.
Wall {r['wall_seconds']:.6f}s,RSS{r['max_rss_kib']:,}KiB;wrapper exit0. These are
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

{table}

The round-zero policy removes **{pct:.4f}%** of that API total versus prepared
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

{baseline}

{queue}

{source_summary}

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

{account}

Only research artifacts changed. No production/runtime/Git/receipt/calibration/
instruction/reviewer mutation,installation,external message or merge. Saved
reports do not establish user delivery or job liveness.
'''
(HERE/'README.md').write_text(readme)
handoff=f'''# Review handoff: unpadded SC_SZC round0 coefficients

Run `{run}`,{now}. Research arithmetic candidate only;no native speed claim.

The complete local validation and source census are in
[the experiment](../experiments/unpadded-cubic-factory-20261017/README.md).
All1,890 schedules,19,650 independent samples,43,920 finals,144 extension
checks,12 value-independent censuses,20 counter cross-checks and five mutation
controls pass. Final run {r['wall_seconds']:.6f}s,{r['max_rss_kib']:,}KiB RSS,one CPU thread.

Actual candidate seam (read-only here):
`ops/zkp-mvp/candidate/hashline/src/private_block/argument.rs:1783/1788` and
`ops/zkp-mvp/candidate/zkp-core/src/sumcheck/grouped.rs:93/107/121/132`.
Hashes match sonnet-hardening snapshots in the experiment;root main differs.

Proposed interface: definition-local prepared lookup offsets plus a
`begin_row(round,cur,dif) -> Option<[Fp2;4]>` factory for group0. Derive
public shape/dependency metadata inside the native constructor. Select only
unpadded round0 with at least2 rows;scalar fallback everywhere else. Weight
and reduce4 coefficients,then evaluate original bracket samples0..3,retain
five outer outputs and existing hosted groups/claims/finals. No protocol,
masking,challenge sampling or cross-proof private cache changes.

Research patch: `experiments/unpadded-cubic-factory-20261017/cubic_factory.py`
and `experiment.py`;`research-source-diff.patch` is research-only. Do not
integrate the Python interpreter or dynamic polynomial allocations. Proposed
next local work is fixed straight-line Rust-style generation/liveness;no
native source was modified or native build launched.

Counted hp32/kv8/qh32/T512/three-limb scope falls3,527,474,753 to3,280,010,835
API ops ({pct:.4f}%) versus prepared scalar. Every API category drops in this
round-zero policy. The23.5578% comparison versus literal additionally includes
denominator preprocessing and is not cubic-only. Blanket all-round construction
is demoted:after claim recovery it adds22 general multiplications per row on
constant-mask axes. Round0 recurs each proof;it is not startup amortization.

Charge15 offsets/30 field setup ops/15 classifications,4 coefficient words,
unknown extra temporaries/native scratch/dispatch/code and retained public
width tests159,383,552 in the T512 interpreter. Per-part8 words are unchanged.
The census omits common Eq/interpolation/recovery/folds/PCS/masks/witness work,
plus native Rayon identity-fold additions. Compiler optimizations may erase
counted literal work. Counts and Python clocks establish no native rate.

Owner gates before promotion: native scalar/constructor parity across profiles,
zero-factor and malformed/refusal preservation;all five masked messages,
transcript/challenges/RNG continuation/finals;fresh masks and all commitments;
old/new receipts and independent verifier/tampering;new-shape privacy acceptance.
Then guarded3-arm phase and enclosing measurements,including both witnesses,
serialization,independent verification,peak memory and resident startup/slope.
Falsify on any mismatch or if dispatch/setup/scratch erases saved arithmetic.

End-to-end private8B ceiling unknown. Historical complete SC_SZC-removal ceiling
is28.317% of one synthetic block's27.523873s enclosing test,not8B. Target remains
>=50 proved tokens/s;accepted full private8B proofs/passes/tokens0/0/0. All
required target clocks and rates unmeasured. No heavy job or merge requested.
'''
(ROOT/'handoffs/20261017-unpadded-cubic-round0.md').write_text(handoff)
progress=f'''# ZKP efficiency progress

Cycle0054 — `{run}`,checkpoint {now}.

**No native improvement established.** A public round-zero-only cubic factory
passed1,890 synthetic schedules,19,650 independent round samples,43,920 finals,
144 extension checks and20 operation-census cross-checks. Five mutations were
caught;zero-factor fallbacks and zero/random-value operation counts agree.
CPU run:{r['wall_seconds']:.2f}s,{r['max_rss_kib']:,}KiB RSS,one low-priority thread.

At full heads/T512,three-limb factory arithmetic counts fall **{pct:.2f}%**
versus scalar evaluation with prepared lookup denominators. This measures a
limited field-operation scope,not proving time. Applying coefficients to every
round adds costly multiplications after claim recovery,so that policy is
 demoted. Round0 is paid for every proof;it is not reusable startup.

The candidate adds coefficient construction/Horner work,64 logical output
bytes per row,public dispatch and unknown native temporary/register costs.
Next local step:generate a fixed factory and audit lifetimes. Main/Claude:
review native masked/refusal/RNG/PCS/independent-verifier gates,then guarded
three-arm timings and complete resident workload clocks. Candidate seam:
`argument.rs` SC_SZC and `grouped.rs` row/part/sample/recovery;candidate and
sonnet-hardening source pins match. No native/GPU/build job ran.

LIVE sources searched:Dory2020 with its August2026 release,EPFL concrete
coefficient source,Fold-DCS,ICICLE,NVIDIA carryless arithmetic and October16
Plonky3 hash metadata. October FAEST primary/PDF and several license/commit
fetches failed;exact blockers retained. Seven source records appended,276 total.
Author performance/security claims were not reproduced.

[Experiment](experiments/unpadded-cubic-factory-20261017/README.md) and
[review handoff](handoffs/20261017-unpadded-cubic-round0.md) retain commands,
seed,source hashes,dimensions,controls,counts and limits.

{account}

No production/runtime/Git/heavy/GPU/install/external actions. Saved reports
are not evidence that a message was delivered or a job is live.
'''.replace('\n demoted','\ndemoted')
(ROOT/'PROGRESS.md').write_text(progress);(ROOT/'progress'/f'{run}.md').write_text(progress)
find=f'''\n## Cycle0054 — 2026-10-17 — only round0 repays unpadded cubic construction

Run `{run}`;checkpoint {now}. **Promising arithmetic count;no native speed
improvement.** Current agenda,target and durable/project memory were read/
snapshotted;all269 starting source records parsed;whole historical findings
indexed for negative/next evidence. Latest three experiment results read.
Native status remains no new trained proof,D24 proposed.11 retained source/
measurement pins match;current candidate argument/grouped files also match
sonnet-hardening (root main differs). Native/profile/privacy lane stays owned.

**Question refined from cycle53:** does a four-word unpadded factory repay
construction when native h1 recovery removes a scalar sample? Baseline group0
needs4 samples on round0 and3 after nonzero-factor recovery. Broad coefficient
construction passes exact algebra but adds22 Fp2mul per later constant-mask row
(33 when mask moves) versus prepared scalar. It saves10/9 mul_base while adding
other work;the blanket policy is demoted. A public round-zero-only selection
instead saves17 mul,20 mul_base,5 add,17 sub per row plus a final Horner charge.
No private value or zero slope controls dispatch;round0 recurs every proof.

Final experiment:63 fixtures,1,890 complete synthetic schedules,19,650
independent round samples,43,920 final values,144 extension clause checks,
12 value-independent row censuses,20 concrete-versus-allocation-free counters,
3 padded-factory refusals. Five material mutations caught.732 recoveries and
708 zero-factor fallbacks agree across five modes. Source-declared widths,
per-group pending samples,claims,finals,fold and equality work agree with the
separate original-cube tuple oracle. CPU{r['wall_seconds']:.6f}s,RSS{r['max_rss_kib']:,}KiB,
one nice19 CoreUltra9 thread,exit0;59s/512MiB caps. No native constructor,
transcript,RNG,PCS,verifier,receipt or GPU execution.

hp32/kv8/qh32/T512,three limbs,no lift: scoped arithmetic follows.\n
{table}

Round0-only versus prepared scalar removes{pct:.4f}% of the stated API scope;
versus literal removes23.5578%,which includes denominator preparation savings.
Native field-source expansion gives524,287,982 fewer base multiplies,
184,549,358 fewer adds,142,606,336 fewer subs versus prepared scalar;these are
literal API expansions,not instructions or timings. The scope includes bracket
construction/evaluation,weighted sums,modeled part reductions,Horner and
preparation;omits common Eq/interpolation/recovery/folds,PCS/masks,witnesses,
transfers and serialization. Model uses source1024/small chunk policy with
port carrier count;Rayon identity-fold additions are not specified and are
uncounted. Part width8 is unchanged. T1024 work is roughly4x,not automatic
amortization. Two-limb/hp16 rows retained. No native speedup inferred.

Added costs:15 denominator offsets (30 charged field ops),15 classifications,
4 coefficient output words/64 logical bytes per row,unknown polynomial
 temporaries/registers,policy/axis tests and159,383,552 dynamic width tests in
T512 round0 replay. Denominator dispatch charged per actual scalar sample or
coefficient carrier. Native scratch/code/allocation/affected and enclosing
clocks unmeasured. Initial passing all-round attempt used512-row count chunks;
retained with its superseded accounting. Later1024/small-policy,value-independence,
dispatch and self-contained-input refinements all remain separately retained.

{queue}

{baseline}

{source_summary}

Concrete seam:candidate argument.rs1699/1783/1788 and grouped.rs93/107/121/132.
Next LOCAL:fixed public straight-line unpadded round0 factory with independent
sample/counter/lifetime checks. Next OWNER:native/profile/privacy/refusal/RNG/
mask/PCS/independent-verifier gates,then guarded3-arm clocks (literal/prepared/
prepared+round0),both witness paths,peak and complete resident startup/slope.
[Experiment](experiments/unpadded-cubic-factory-20261017/README.md) and
[handoff](handoffs/20261017-unpadded-cubic-round0.md) retain exact interface,
research patch,pins,commands,seed,dimensions,hardware and risks.

{account}

No production/runtime/Git/build/GPU/install/external action or heavy job queued.
Reports do not imply delivery or liveness. Prior findings and negatives retained.
'''.replace('\n temporaries','\ntemporaries')
with (ROOT/'FINDINGS.md').open('a') as out:out.write(find)
state=f'''# ZKP efficiency explorer — durable state

Cycle0054 COMPLETE:`{run}`;checkpoint {now}.
Agenda/current target/durable and project memory snapshotted/read;269 starting
sources parsed,7 LIVE dispositions appended,276 total. Historical findings
negative/next index retained.11 old native/measurement pins match. Current
candidate argument/grouped hashes match sonnet-hardening;root main differs.
No native trained proof/privacy ruling changed. D24 remains proposed.

Unpadded cubic factory passes1,890 schedules/63 fixtures,19,650 independent
samples,43,920 finals,144 extension checks,12 value-independent censuses,
20 executed/census comparisons,3 padded-factory refusals and5 mutations.
732 recoveries/708 zero-factor fallbacks. Final CPU{r['wall_seconds']:.6f}s,
RSS{r['max_rss_kib']:,}KiB,one nice19 CoreUltra9 thread,exit0. No native proof.

Useful refinement:coefficients only on unpadded group0 round0 (>=2rows),
then prepared scalar after h1 recovery. Broad factory adds22 Fp2mul/row on
later constant-mask axes,33 when mask moves;demote it. Round0 saves17 mul,
20 mul_base,5 add,17 sub per row,plus final Horner cost. Fixed original5
outer samples,pending groups/claims/finals remain. Round0 recurs per proof,
not startup. hp32/kv8/qh32/T512/3limbs scope3,527,474,753->3,280,010,835
API ops versus prepared scalar ({pct:.4f}% counted drop),not native timing.
Literal comparison23.5578% includes denominator optimization. T1024~4x work.
Scope omits common Eq/fold/PCS/masks/witness/transfers/serialization and native
Rayon identity-fold adds. No8B rate prediction. Candidate charges15 offsets,
30 setup ops,15 classifications,4 output words64B per row,public dispatch;
native scratch/register/code costs unknown. Dynamic width tests159,383,552
must not be assumed free. All superseded local runs retained.

Ranked queue:
1 OWNER:dominant GPU SC_SZC and both recurring witnesses;native/privacy gates.
2 LOCAL NEW/refined:fixed straight-line unpadded round0 factory;remove width
  dispatch and audit lifetimes. Compare literal/prepared/fixed outputs and
  counters;falsify mismatch/refusal/RNG change or added costs erasing savings.
3 OWNER:resident complete-workload startup/slope with fresh masks,full clocks,
  latency/lag/drain. Recurring>20ms/proved position rejects50/s for schedule.
4 OWNER:exact full-K split-int16 down witness;all integer/refusal/receipt gates.
5 CONDITIONAL OWNER:padded chain only when native supports exist;no padded
  projection imported into full8B. Preserve fusion/CSE/NTT/memory negatives.

Next LOCAL:generate fixed4-word factory from the exact unpadded expression;
public immutable layout/axis metadata only. Independent extension/direct-cube
oracle,actual API counts and liveness;no protocol/mask reuse changes.
Next OWNER:native profile/privacy/refusal/masked/RNG/final/PCS/fresh-verifier,
then guarded3-arm clocks and full resident workloads,both witness paths/peak.
No heavy job queued. Handoff:handoffs/20261017-unpadded-cubic-round0.md.
Experiment:experiments/unpadded-cubic-factory-20261017.

LIVE:Dory older2020/2021 plus August2026 release/pinned commit;EPFL concrete
coefficient source,Fold-DCS,NVIDIA binary-field and ICICLE transfer refreshes;
Oct16 Plonky3 BLAKE2s metadata. New OctFAEST primary/PDF blocked. Actual
Dory/EPFL license terms unavailable;labels only. All exact URLs,verified versus
unknown dates,failed fetches and unreproduced claims in sources-cycle54.json.
Next rotation:lookup/softmax table traffic,public specialization,composition.

Accepted independently verified complete private8B proofs/passes/tokens0/0/0.
Proof context null;CPU only. Steady/total rates,startup duration/fraction,
witness/proof/serialization/independent verification,latency/lag/drain all
unmeasured. No long-context prefill,resident-pass or decode proof. >=50/s
unchanged/unachieved;larger workloads allowed with quadratic attention,fresh
masks and complete coverage/privacy. No production/runtime/Git/build/GPU/
install/external action. Reports do not establish delivery or liveness.
Next cycle not before2026-10-17T05:26:24Z.
'''
(ROOT/'STATE.md').write_text(state)
patch=[]
for q in sorted(HERE.glob('*.py')):
 prior=HERE.parent/'optional-support-port-20261017'/q.name
 if prior.exists():patch.extend(difflib.unified_diff(prior.read_text().splitlines(True),q.read_text().splitlines(True),fromfile=str(prior),tofile=str(q)))
 else:patch.extend(difflib.unified_diff([],q.read_text().splitlines(True),fromfile='/dev/null',tofile=str(q)))
(HERE/'research-source-diff.patch').write_text(''.join(patch))
(HERE/'checkpoint.json').write_text(json.dumps(dict(run_id=run,checkpoint_utc=now,cycle='0054',result_sha256=hashlib.sha256((HERE/'result.json').read_bytes()).hexdigest()),indent=2)+'\n')
print('Checkpointed README,handoff,PROGRESS,dated progress,FINDINGS,STATE;scope count decrease',pct)
