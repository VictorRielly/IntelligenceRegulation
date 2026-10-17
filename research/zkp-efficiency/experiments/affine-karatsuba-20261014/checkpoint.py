"""Finalize this bounded research cycle; write only research artifacts."""
import datetime,difflib,hashlib,json,pathlib

HERE=pathlib.Path(__file__).resolve().parent;ROOT=HERE.parents[1]
RUN='20261014T203626Z-4afb917a'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
r=json.loads((HERE/'result.json').read_text())
assert r['status']=='passed' and r['run_id']==RUN
assert json.loads((HERE/'execution.json').read_text())['exit_code']==0
cmd=json.loads((HERE/'command.json').read_text())
for name,sha in cmd['source_sha256'].items():
    assert hashlib.sha256((HERE/name).read_bytes()).hexdigest()==sha,name
prior=ROOT/'experiments/public-axis-row-factory-20261013'
oldcmd=json.loads((prior/'command.json').read_text())
for name,sha in oldcmd['source_sha256'].items():
    assert hashlib.sha256((prior/name).read_bytes()).hexdigest()==sha,name
for pin in json.loads((HERE/'native-pins.json').read_text()):
    assert hashlib.sha256((HERE/pin['snapshot']).read_bytes()).hexdigest()==pin['sha256']
    assert hashlib.sha256(pathlib.Path(pin['path']).read_bytes()).hexdigest()==pin['sha256']
(HERE/'source-diff.patch').write_text(''.join(difflib.unified_diff(
    (prior/'coefficients.py').read_text().splitlines(True),(HERE/'coefficients.py').read_text().splitlines(True),
    fromfile='cycle49/coefficients.py',tofile='cycle50/coefficients.py')))
sources=json.loads((HERE/'sources-cycle50.json').read_text())
all_sources=[json.loads(l) for l in (ROOT/'sources.jsonl').read_text().splitlines()]
known={x.get('id') for x in all_sources}
for s in sources:
    s.update(access_date='2026-10-14',access_timezone='UTC',recorded_at_utc=now,
        cycle='0050',run_id=RUN,reproduced_performance=False,
        evidence_kind='Native LIVE primary search/inspection; source instructions ignored; no foreign code executed')
    if s['id'] not in known:
        with (ROOT/'sources.jsonl').open('a') as out:out.write(json.dumps(s,sort_keys=True)+'\n')
(HERE/'sources-cycle50.json').write_text(json.dumps(sources,indent=2)+'\n')

recovery='''## Cycle0049 — recovered public-axis result, reported2026-10-14

Run `20261013T073440Z-ac1df939` completed its experiment on2026-10-13
07:43:25UTC but left STATE in progress and no final findings/progress report.
Cycle50 recovered its original result/exit/source hashes without rerunning or
editing evidence. Original source hashes all recheck. No uncheckpointed LIVE
search or delivery is inferred; sources remained253records at cycle50 startup.

Baseline cycle48 weighted coefficients. Public immutable mask/support axis
dependencies remove structurally zero slope carriers while retaining all
five output slots, original samples/folds/finals and private-valued slopes.
52fixtures/312schedules pass3,240independent cube samples,8,640direct finals,
40arbitrary full-clause extension values,84conservative dependency checks,
4native logical-head enumerations and8value-independent schedule checks.
Five negative controls reject forced-constant causal mask,swappedHt/S axes,
bit-order reversal,private-role metadata and contiguous-head-prefix layout.
546recoveries/354zero-factor fallbacks.7.537997s,20,508KiB,one nice19
CoreUltra9CPU thread,59s/512MiB caps. This is synthetic algebra, not proof time.
Illustrative hp16/kv4/qh12/T512/3limb count removes6.931212% base products and
5.284612% field API versus cycle48; charge12,582,909public axis tests,
fixed-output zero assignments,metadata and unknown native scratch/spills/time.

Recovered report: `progress/20261013T073440Z-ac1df939.md`. Cycle50 handoff
includes this prerequisite. No native performance or privacy gain established.
Accepted complete private8B proofs/passes/tokens0;rates,context,startup,
witness/proof/serialization/independent verification unmeasured;CPU only.

'''
finding=f'''## Cycle0050 — 2026-10-14 — fixed affine Karatsuba and an API-cost negative

Run `{RUN}`; checkpoint{now}. AGENDA/current throughput target,
required durable/project memory and latest three results inspected/snapshotted;
all253starting source records parsed; four LIVE source records appended.
Ten current native/measurement pins match cycle49; earlier negative findings
and interrupted CLI state remain preserved. No job liveness is inferred.

Baseline cycle49 public-axis row factory. For public coefficient width2x2,
replace schoolbook4mul+1add with3mul+2add+2sub. This exact ring identity
retains declared widths,original samples,recovery/fallback,folds and finals.
Selection uses public expression widths only; no private-value tests,degree
pruning,mask/opening reuse or protocol/PCS/transcript/RNG change. The tested
global switch is single-thread harness scaffolding, not a native interface.

100fixtures/600schedules pass5,832independent cube samples,16,272ordered
direct-MLE finals,300independent convolution values,40full-clause arbitrary
extension values,600executed row-census checks and8zero/random schedule checks.
876recoveries/672explicit zero-factor fallbacks.75public width cases include
1..5coefficients,zeros,boundaries and full extension values; even/odd lookups,
ragged parts,debug/release recovery,padded/unpadded fallback and logical-head
fixtures remain. Four deliberate arithmetic mutation detections and a
value-independent schedule assertion pass. Executed delta:17,340fewerFp2mul,
17,340moreFp2add,34,680moreFp2sub. Runtime8.321726s,peakRSS21,972KiB,one
nice19CoreUltra9CPU thread;59s/512MiB caps,64MiB estimate. No native/GPU proof.

**Useful negative:** illustrative hp16/kv4/qh12/T512/3limb count drops
51,904,500Fp2mul but adds51,904,500adds and103,809,000subs. Base-product
API calls5,121,506,608to4,861,984,108(-5.067308%); total field API
3,035,147,955to3,138,956,955(+3.420229%).226,492,362generic public width
tests are charged separately. Across six shape/limb cases base-product saving
4.9514–5.1328%,API increase3.3342–3.4859%. Five-productFp2 baseline includes
the constant7 product; compiler lowering and prior unintegrated4-reduction
arithmetic can alter real benefit. Output80logical bytes unchanged; temporary
liveness,code size,carriers/registers/spills,peak and enclosing clocks unknown.
Reject unconditional promotion from lower products. Break even requires
`C_Fp2mul > C_Fp2add + 2*C_Fp2sub + marginal dispatch/scratch`.

[Experiment](experiments/affine-karatsuba-20261014/README.md) and
[handoff](handoffs/20261014-affine-karatsuba.md) retain command,seed,source/
native/result hashes,controls,per-round census and review-only Rust sketch.
Actual Rust seam is SC_SZC argument.rs1699/groups1783/bracket1788,helper894,
and grouped.rs part93/sample107/reduction121/recovery132. It first needs the
optional fixed-array factory/weighted-driver/compiled-plan chain translated
and reviewed. Python passed; Rust sketch uncompiled. Native masked/frozen/
refusal/final/extension/RNG/PCS/fresh-independent-verifier,compiler/peak and
guarded enclosing A/B gates remain. Main/Claude reviews/integrates; no merge.

Historical one-block125M/T512/onepass RTX4070Laptop:SC_SZC7.794s,
prove16.864s,witness5.77s,encode0.028s,decode0.013s,in-processverify0.806s,
whole-test27.523873s,40,783,352B. Encode is not full serialization; startup
boundary/fraction and both recurring witness paths remain unmeasured.
EntireSC_SZC removal caps that historical whole wall saving28.317%, not an8B
rate or a scaling factor for these counts. Synthetic12blockT5124070 run:
408.609226s total,318.22s prove,12.15s in-processverify,484,107,456B;
fresh-processverification=false,trained=false,privacyaccepted=false. LaterCLI
saved nonterminal state is not a completed proof or liveness evidence. Actual
complete ceiling `N/(T_complete-C_products+C_add_sub_dispatch_scratch)` is
unmeasured because accepted8B critical-path and affected phase clocks absent.

Ranked hypotheses after this cycle:

|Rank|Expected end-to-end impact, cost/compatibility and falsification|
|---|---|
|1 owner|GPU dominantSC_SZC plus both recurring witness paths; highest measured phase opportunity,high CUDA/memory integration. Require exact masked/final/refusal/receipt/independent verification and measured peak/enclosing gain. Reject mismatch or enclosing regression.|
|2 tested conditional|Fixed2x2Karatsuba within reviewed row-factory chain; modest count opportunity,moderate translation,extra adds/subs/dispatch/scratch. Reject native exactness/privacy/bytes/RNG/PCS mismatch or cost inequality/enclosing regression. Count savings alone insufficient.|
|3 NEW local refinement|Public static multiplication schedule,including3x2blockedKaratsuba: remove repeated width tests and possibly another product; charge fixed-plan construction/code size,combination adds/subs,scratch. Prerequisite current factory; no hidden-value dispatch. Reject extension/cube mismatch or worse weighted cost.|
|4 owner|ExactfullKsplit-int16down; packing/two products/i64/requant/refusal/transfer/workspace. Native affected clock unknown; require full integer/profile/privacy/receipt and enclosing parity/gain.|
|5 workload|Fresh resident complete-pass slope,context/pass/concurrency,startup fraction,latency/lag/drain/serialization/independent verification and fresh masks. Recurring complete cost>20ms/new proved position rejects50/s for that schedule. Long context also charges quadratic attention.|
|6 architecture|GKR/MLElookup/PCS composition,high relation/field/quantization/setup/final-oracle/joint-hiding/soundness migration cost. Reject operator aggregates or public-input proofs as target evidence.|

LIVE search adds older HyperPlonk receivedOct10,2022/revisedDec21,2023 with
author-slide coefficientKaratsuba technique (slide date unknown; PDF fetch
failed). Plonky3Oct11rc exact release/Cargo version diff now inspectable at
5b23a4fbf7768136797f52263e4ae0bef3841dfe; PR2305Sep23 equality-table
traffic and PR2260Sep20 cryptographic mask-sampler bounds refine next gates.
Release commit is inspected manifest scope,not entire implementation. MIT
text on main and workspaceMIT/Apache declaration inspected; pinned license
and two merge-commit fetches InternalError. Matched-hardwareJune15 paper is
255-bit simulator/synthesized-engine work,not5090 performance. ICICLELatest
displayedv4July11 year unverified;mainMIT inspected. All source author runtime,
test/security claims remain unreproduced;foreign code not downloaded/executed.
Rotation next:memory/batching/GPUcommitments,lookup/softmax,quantization,
composition. Preserve earlier slower native fusion and denominator-count negatives.

Accepted independently verified complete private8B proofs/passes/tokens0.
Proof contextnull,CPU only. Steady/total rates,startup duration/fraction,
witness/proof/serialization/independent verification,latency/lag/drain
unmeasured. No long-contextprefill,resident pass or decodeproof. Larger
workloads permitted with quadratic attention,fresh masks and full privacy/
coverage;>=50/s unchanged/unachieved. Saved reports do not prove delivery.
NextLOCAL: static public multiplication plan3x2with independent convolution/
full-clause/cube controls and weighted costs. NextOWNER: native fixedarrays,
masked/frozen/refusal/fresh-verifier gates,then guarded subphase/peak/enclosing
A/B. No production/runtime/Git writes,build/GPU,install,external action or job queued.

'''
old_findings=(ROOT/'FINDINGS.md').read_text()
with (ROOT/'FINDINGS.md').open('a') as f:
    if '## Cycle0049 — recovered' not in old_findings:f.write('\n\n'+recovery)
    if '## Cycle0050 —' not in old_findings:f.write('\n'+finding)
recovered_report=f'''# Cycle0049 recovered progress

Original run `20261013T073440Z-ac1df939`; report recovered {now}.
This report was not saved during the original cycle and is not evidence of
earlier notification or completed literature search. Source/exit/result hashes
were verified in cycle50 without rerunning or editing the prior evidence.

The public-axis row factory passed52synthetic fixtures/312schedules,
3,240independent samples and8,640finals,40full-clause extension values and
five mutation controls. Original runtime7.538s,20,508KiB,one nice19CPU thread.
Illustrative3limbT512 counted base products fall6.93%,field API5.28% versus
cycle48,with added public metadata/dispatch/assignments. Native runtime,
scratch/spills/peak and complete-stack clocks remain unknown.

No complete private8B proof/pass/token;proof contextnull,CPU only. Steady/total
rates,startup fraction,witness/proof/serialization/independent verification
unmeasured. No prefill,resident or decode proof. >=50/s remains unachieved.
Next original action was final reporting and native fixed-array/fresh-verifier
gates. Cycle50 completed this recovery and tests affine multiplication next.
See [owner handoff](../handoffs/20261014-affine-karatsuba.md).
'''
(ROOT/'progress/20261013T073440Z-ac1df939.md').write_text(recovered_report)
progress=f'''# ZKP efficiency progress

Cycle0050 — `{RUN}`, checkpoint {now}.

**A softmax arithmetic candidate passed synthetic checks; no native speedup is
established.** Three-product affine multiplication removes about5.1% of counted
base products versus the previous public-axis factory in an illustrativeT512
case, but adds about3.4% total field API operations. Public dispatch and
temporary/register costs could outweigh the saving. Keep it conditional.

100fixtures/600schedules pass5,832independent round samples,16,272final values,
300convolution values,40full-clause extension values and operation-schedule/
mutation controls. CPU-only one nice19CoreUltra9thread:8.322s/21,972KiB;
no native or GPU proof. The previously unfinished cycle49 report is recovered
and its original source/result/exit evidence preserved and rechecked.
[Experiment](experiments/affine-karatsuba-20261014/README.md) and
[owner handoff](handoffs/20261014-affine-karatsuba.md) retain commands,seed,
source pins,costs,negative findings and the actual Rust seam.

LIVE sources: older HyperPlonk coefficient multiplication,October11Plonky3
release/equality-traffic/mask-sampler changes,matched NTT/sumcheck hardware
methodology and ICICLE release scope. Four source records saved with dates,
license/commit scope and exact fetch failures. Author claims unreproduced.

Next owner gate: fixed-array SC_SZC translation,unchanged original samples,
masked/frozen/refusal/final/RNG/PCS checks and fresh independent verification,
then guarded subphase/peak/enclosing A/B including both witness paths. Next
local question: a public static multiplication plan with3x2blockedKaratsuba,
charging plan/code size,added operations and scratch against this baseline.

Accepted independently verified complete private8B proofs/passes/tokens: **0**.
Proof contextnull;CPU only this cycle. Steady-state and total-workload rates,
startup seconds/fraction,witness/proof/serialization/independent verification,
latency/lag/drain are unmeasured. No long-context prefill,resident-model pass
or decode proof. >=50/s remains unchanged/unachieved; larger workloads remain
allowed with quadratic attention,fresh masks and complete coverage/privacy.
No production/runtime/Git writes,build/GPU/install/external action or heavy job
queued. Saved reports do not establish message delivery.
'''
(ROOT/'PROGRESS.md').write_text(progress)
(ROOT/'progress'/f'{RUN}.md').write_text(progress+'\n'+finding)
(ROOT/'STATE.md').write_text(f'''# ZKP efficiency explorer — durable state

Cycle0050 COMPLETE: `{RUN}`; checkpoint {now}.
AGENDA/current target,required durable/project memory and latest three results
read/scanned/snapshotted;10current native/measurement pins all unchanged.
sources.jsonl253to257records. Prior incomplete cycle49 result/exit/source
hashes rechecked; recovery report explicitly datedOctober14,not prior delivery.

Tested fixed public width2x2Karatsuba within cycle49 public-axis SC_SZC row
factory.100fixtures/600schedules,5,832independent samples,16,272direct finals,
300convolution values,40full-clause extension values,600counter checks and
8value-independent schedules pass;four arithmetic mutation detections plus
schedule assertion.8.322s/21,972KiB,one nice19CoreUltra9CPU thread. Synthetic
only;Rust sketch uncompiled. No native/GPU proof or demonstrated runtime gain.

IllustrativeT512/3limb base products-5.0673%,field API+3.4202% versus cycle49;
charge226,492,362public width tests and unknown temps/code size/spills/peak.
Promote only if saved product cost exceeds added add+2subs+dispatch/scratch
and native enclosing gates pass. Entire historicalSC_SZC-removal ceiling
28.317%oneblock whole wall,not8B-rate or operation-count speed prediction.

Ranked hypotheses:1owner GPUdominantSC_SZC+bothwitness paths;2conditional
fixedaffineKaratsuba/factory chain;3NEWlocal public static multiplication
plan3x2blockedKaratsuba;4owner exactfullKint16down;5fresh resident complete
startup/slope;6GKR/lookup/PCS composition. See FINDINGS for costs/falsifiers.

Next LOCAL bounded experiment: use public expression widths/axis patterns to
build a static multiplication schedule; test3x2blockedKaratsuba versus current
2x2only,charge plan/code size,all combination adds/subs,scratch; independent
tuple convolution/full-clause/cube/final and private-value-independent counters.
Reject mismatch or worse weighted cost. Next OWNER: translate fixedarrays,
masked/frozen/refusal/RNG/PCS/fresh-verifier gates,then shared-guard row/fold/
equality/reduction,bothwitness,peak/enclosing A/B. No native job queued here.
Handoff: handoffs/20261014-affine-karatsuba.md.

LIVE sources:NEWolderHyperPlonk2022/2023 coefficientKaratsuba;October11
Plonky3rc release+manifest at5b23a4fbf7768136797f52263e4ae0bef3841dfe,
Sep23equality traffic/Sep20mask sampler PRs;June15matched-hardware methodology;
ICICLEv4Latest displayedJuly11yearunverified. Licenses/scope/fetch errors
retained;authorclaims unreproduced. Rotation:memory/batching,GPUcommitments,
lookup/softmax,quantization,composition. Preserve native-fusion negative.

Accepted independently verified complete private8B proofs/passes/tokens0.
CPU only;proof contextnull;steady/total rates,startup seconds/fraction,
witness/proof/serialization/independent verification,latency/lag/drain
unmeasured. No longprefill,residentpass or decode proof.>=50/s unchanged;
larger workloads allowed,quadraticattention,fresh masks,fullcoverage/privacy.
No production/runtime/Git write,build/GPU/install/external action. One cycle
per hour;do not start another cycle before2026-10-14T21:36:26UTC. Saved
reports do not establish user-message delivery or supervisor/job liveness.
''')
audit=dict(status='passed',checkpoint_utc=now,run_id=RUN,run_source_hashes_checked=len(cmd['source_sha256']),
    prior49_source_hashes_checked=len(oldcmd['source_sha256']),native_pins_checked=10,
    source_records=len((ROOT/'sources.jsonl').read_text().splitlines()),
    result_sha256=hashlib.sha256((HERE/'result.json').read_bytes()).hexdigest(),
    completed_proof_tokens=0,production_writes=False,runtime_writes=False)
(HERE/'checkpoint-audit.json').write_text(json.dumps(audit,indent=2)+'\n')
print(json.dumps(audit,indent=2))
