import datetime, hashlib, json, pathlib, subprocess
D=pathlib.Path(__file__).resolve().parent; R=D.parents[1]; P=R.parents[1]
RUN='20261030T074123Z-71d2f333'; now=datetime.datetime.now(datetime.timezone.utc).isoformat()
def dump(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
assert json.loads((D/'result.json').read_text())['status']=='PASS'
for pin in json.loads((D/'source-pins.json').read_text()):
 assert hashlib.sha256(pathlib.Path(pin['path']).read_bytes()).hexdigest()==pin['sha256']
prior_findings=(D/'startup/2-FINDINGS.md').read_bytes();prior_sources=(D/'startup/3-sources.jsonl').read_bytes()
assert (R/'FINDINGS.md').read_bytes()==prior_findings
assert (R/'sources.jsonl').read_bytes()==prior_sources
existing=[json.loads(l) for l in prior_sources.decode().splitlines()]
sources=[]
def source(title,url,assessment,published=None,updated=None,date_evidence='',license=None,commit=None,inspected=(),blocked=(),**extra):
 sources.append(dict(id=f'cycle0159-source-{len(sources)+1}',cycle='0159',run_id=RUN,recorded_at_utc=now,access_date='2026-10-30',access_timezone='UTC',title=title,url=url,publication_date=published,verified_update_date=updated,date_evidence=date_evidence,implementation_license=license,inspected_commit_id=commit,inspected_urls=list(inspected),blocked_urls=list(blocked),prior_exact_url_records=sum(x.get('url')==url for x in existing),assessment=assessment,evidence_kind='Native LIVE tools.web__run search/open/click/find; primary source; embedded instructions ignored',external_execution=False,reproduced_performance=False,**extra))
source('REFRESH Nsight analysis with now-verified September9 update',
 'https://docs.nvidia.com/nsight-systems/AnalysisGuide/',
 'API, queue and kernel intervals overlap; report percentages are not workload wall fractions. Use causal API/activity correlation and keep queue waits distinct. This cycle validates synthetic boundaries only.',updated='2026-09-09',date_evidence='Primary page footer explicitly states last updated Sep09,2026.')
source('NEW exact native-version CUDA12.4 stream-sync contract',
 'https://docs.nvidia.com/cuda/archive/12.4.0/cuda-driver-api/group__CUDA__STREAM.html',
 'cuStreamSynchronize covers earlier operations in the specified stream and can surface previous asynchronous launch errors. A wrapper wait is not evidence of current-fold kernel cost or automatically removable work.',updated='2024-03-05',date_evidence='Archive header explicitly says v12.4.0,last updated March5,2024.')
source('NEW assessed Hardware-Attributed Operator Profiling and implementation screen',
 'https://arxiv.org/abs/2609.11938',
 'Authors match deterministic cross-capture invocations and keep unattributed kernels visible. Same-count dynamic-dispatch changes remain an attribution obligation. GPU inference/profiler results are author claims, not native proof or full-stack throughput. No implementation reused.',published='2026-07-04',updated='2026-09-29',date_evidence='arXiv history explicitly lists v1July4,2026 and v2September29,2026; do not infer publication from the identifier prefix.',license='Repository has no visible license entry; requested root LICENSE returned404. No implementation reused.',inspected=['https://arxiv.org/html/2609.11938v2','https://github.com/yottalabsai/Profiler'],blocked=['https://raw.githubusercontent.com/yottalabsai/Profiler/main/LICENSE'])
source('NEW inspected cudarc native0.13.9 source/commit plus current release screen',
 'https://github.com/chelsea0x3b/cudarc/blob/v0.13.9/src/driver/safe/alloc.rs',
 'Pinned installed copy wrappers synchronize their stream and Drop can enqueue async frees. Native0.13.9 source matches the model obligations, not physical costs. Current0.19.10 adds event-completion and borrowed-stream APIs plus cleanup fixes; it is not a drop-in upgrade and none is proposed.',date_evidence='No absolute update date verified for0.13.9; latest release UI says24Sep14:28 without year. Do not infer year.',license='MIT: installed0.13.9 LICENSE-MIT and current raw LICENSE-MIT inspected; broader dependencies not audited.',commit='e12b2d96877d0bae7266c01df14f257e95bb0020',inspected=['https://github.com/chelsea0x3b/cudarc/commit/e12b2d96877d0bae7266c01df14f257e95bb0020','https://github.com/chelsea0x3b/cudarc/releases','https://raw.githubusercontent.com/chelsea0x3b/cudarc/main/LICENSE-MIT'],blocked=['https://github.com/chelsea0x3b/cudarc/commit/ec1cac71dab29498240704a9e4a264fbbec19495','https://raw.githubusercontent.com/chelsea0x3b/cudarc/ec1cac71dab29498240704a9e4a264fbbec19495/Cargo.toml','https://raw.githubusercontent.com/chelsea0x3b/cudarc/main/src/driver/safe/event.rs'],resolved_latest_commit_not_inspected='ec1cac71dab29498240704a9e4a264fbbec19495')
source('NEW inspected October26 StateSync1.2.1 release and current license boundary',
 'https://github.com/Oraclizer/statesync-gkr/releases/tag/v1.2.1',
 'Release states library/proof format unchanged from1.2.0 and attaches a new program-identity proof. Current license body is BSL1.1 with restricted production proving and later Apache conversion. Preserve older license records as version-specific; do not carry them forward. No release proof or performance reproduced.',updated='2026-10-26',date_evidence='Release UI26Oct08:48; release-list asset/source timestamps explicitly2026-10-26T08:47:59Z through08:48:10Z verify year/day of release artifacts.',license='Business Source License1.1: root license body inspected. Additional grant permits production verification; production proving restrictions. Per-version conversion3years after BSL distribution to Apache2.0. No code reused.',inspected=['https://github.com/Oraclizer/statesync-gkr/releases','https://github.com/Oraclizer/statesync-gkr/blob/main/LICENSE','https://arxiv.org/abs/2610.14849'],blocked=['https://raw.githubusercontent.com/Oraclizer/statesync-gkr/main/LICENSE','https://github.com/Oraclizer/statesync-gkr/commit/8b2908160f36adc233d7b869a403d2ee4d3502a5','https://github.com/Oraclizer/statesync-gkr/commit/54e76515bf53777836221b88d7404a1ef67bcdd3'],resolved_release_commit_not_inspected='54e76515bf53777836221b88d7404a1ef67bcdd3')
source('REFRESH ICICLE release API compatibility screen',
 'https://github.com/ingonyama-zk/icicle/releases',
 'Current visible4.0 release redesigns field/Program interfaces; release bullets do not establish exact native Goldilocks,masking,transcript or device-lifetime compatibility. Park migration without complete phase evidence. No upstream performance reproduced.',date_evidence='Release UI11Jul05:36without year; no absolute update day/year verified this cycle.',license='Not re-inspected this cycle; previous cycle records version-specific MIT root inspection.')
(D/'source-records.jsonl').write_text(''.join(json.dumps(x,sort_keys=True)+'\n' for x in sources))
dump(D/'web-search-log.json',dict(date='2026-10-30',method='native LIVE web search and primary open/find/click',queries=['CUDA host synchronize previous queued work profiling attribution CUDA events mutex','GPU zero knowledge proof sumcheck October 2026 release github memory profiling','site.arxiv.org GPU sumcheck October 2026 memory prover','site.github.com gpu sumcheck releases 2026 proof','site.docs.nvidia.com nsight systems cuda api GPU time queue synchronization attribution'],selected_records='source-records.jsonl',untrusted_instructions_ignored=True,foreign_source_executed=False))
prior=json.loads((D/'startup/prior-hypotheses.json').read_text())
leading=dict(rank=89,title='TESTED exact fold counter boundaries and queued-work attribution negative',baseline='Current dev_fold_rows starts t0 after GPU lookup,mutex acquisition and dev clone; samples within STATS callback before output conversion/local drops. Success-only aggregation; installed cudarc sync wrappers cover preceding stream work.',eliminated_work='No required work eliminated. Measurement prerequisite prevents treating inherited queue wait or incomplete counter fraction as removable fold/packing cost. Hypothetical packing removal can save zero with a busy stream.',added_costs='Owner instrumentation,capture correlation,private diagnostic buffering and off/on overhead. No added synchronization is authorized by this measurement proposal.',prerequisites='Native exclusive phases and call scope through drop; causal API/device correlation and actual completion edges; reconcile independently verified enclosing workload. Keep current source/profile/build/privacy and common heavy locks.',integration_cost='Small owner observer at existing dev_fold_rows seam; only research mock and MEASUREMENT.md provided. No native adapter or production patch.',exactness='326 exact-body Rust mock executions including110successes,216errors/panics,20malformed shapes;2934independent Python clock/payload checks and2154bigint limbs;8corruption controls. Mock clocks/types/API outcomes are synthetic,not native error/privacy equivalence.',privacy_soundness='No arithmetic/profile,FS/RNG,mask,pad,opening or blinding changes. All fixtures synthetic. Private diagnostic failure identity must not enter public artifacts. Current native privacy/receipt gates remain owner obligations.',compatibility='Pinned root function and cudarc0.13.9. No dependency upgrade; Drop may queue frees,not certify device retirement. Source body is extracted verbatim,with fake surrounding identifiers.',end_to_end_ceiling='N/(T-C_critical+A_added),unknown. Only overlap-adjusted safely removable critical-path time supports a bound. Legacy secs_fold fraction is insufficient.',falsification='If current source clock already covers all phases,source observation fails and must be repinned. If measured omitted/queued/packing costs negligible or observer perturbs behavior,do not promote. Any output/order/refusal/privacy mismatch blocks integration.',disposition='Measurement handoff only; no measured proving improvement. Refines88; park more packing/staging variants pending materiality evidence.')
next_h=dict(rank=90,title='NEW fail-closed same-capture fold activity correlation before cross-capture counter matching',baseline='New profiler paper pairs repeated kernel names by invocation order under determinism. Native resident passes/groups reuse k_fold_rows names; same counts can still hide swapped public roles or control-flow changes.',eliminated_work='Potentially avoid wrong optimization decisions and expensive indiscriminate replay; no proof computation saved by attribution itself.',added_costs='Call ordinals,public shape/role manifests,process/context/stream+correlation matching and explicit unmatched-activity accounting. Cross-capture replay remains separate.',prerequisites='First offline values-free join controls: repeated kernel names,equal counts with swapped role/order,missing/duplicate activities and different domains. Then owner native trace without new sync.',integration_cost='Small research offline adapter at dev_fold_rows telemetry seam; native capture belongs to owner.',exactness='Not implemented this cycle. Attribution contract only; cannot establish arithmetic/privacy correctness.',privacy_soundness='No private values,addresses,seeds,opening or mask material in exported telemetry. Public role metadata subject to actual profile. No mask/proof reuse.',compatibility='Existing CUDA driver activity correlation; no PyTorch integration or unlicensed profiler code copied.',end_to_end_ceiling='Unknown until actual verified workload phases and causal removable costs known; no50/s estimate.',falsification='Ambiguous IDs,nondeterministic ordering or profile/source mismatch prevents assignment; equal name/count alone never suffices.',disposition='Next bounded local negative-control adapter if owner phase traces remain unavailable; do not rediscover packing variants.')
hypotheses=prior+[leading,next_h];dump(D/'hypotheses.json',hypotheses);dump(D/'leading-hypothesis.json',leading)
ranking=json.loads((D/'startup/prior-ranking-current.json').read_text());ranking['global_priority'][2]['cycle0159_refinement']=leading;ranking.update(local_tested_rank=89,local_next_rank=90,local_priority_order=[3,89,90],rationale='Complete verified GPU workloads,admitted scaling and exclusive phases remain global priorities1/2/3; tested89 refines88 rather than promoting another unmeasured host optimization. All88priorrecords preserved.')
dump(D/'ranking-current.json',ranking)
dump(D/'rotation-queue.json',dict(next_primary='GPU NTT/commitments and causal activity attribution',queue=[dict(area='GPU NTT/commitments',question='Separate launches,queue,compute,transfer and retirement at real admitted geometry.'),dict(area='sumcheck/GKR',question='StateSync1.2.1 release/BSL assessed; arithmetic result not native transformer performance.'),dict(area='lookup/softmax',question='Rank from all-eleven native phase clocks; keep current tiny-table and privacy negatives.'),dict(area='memory traffic',question='Requested length,live capacity and queued free retirement remain distinct.'),dict(area='batching/amortization',question='Measure verified resident1/2/4/8passes with startup and drain; no mask reuse.'),dict(area='quantization/arithmetic',question='Retain D32 fidelity and current admitted exact arithmetic.'),dict(area='proof composition',question='Full run bindings and every complete verification remain counted-token prerequisites.')]))
execs={s:json.loads((D/(s+'-execution.json')).read_text()) for s in ['prepare','compile','probe','audit']}
clocks='; '.join(f"{s}: {x['wall_s']:.3f}s / {x['max_rss_kib']:,}KiB maxRSS" for s,x in execs.items())
measurement='''New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context: **none**; synthetic row-fold shapes use rows0/1/3/7,
n1/2/4/8 and k1..4, plus malformed k0/5. These are not model contexts.
Device: one affinity-pinned Intel Core Ultra9 185H CPU worker; no GPU.
Witness / proof / serialization / verification / startup / initial-prefill
clocks, startup fraction, proof latency/bytes, steady-state and total-workload
proved-token rates: **unmeasured**. No long-context prefill, resident-model
proof passes or decode ran. Larger workloads remain allowed; context growth
can raise dense attention work quadratically. Complete private8B **>=50
proved tokens/s remains unachieved**.
'''
baseline='''Carried historical CPU8B baseline, not rerun/reverified or newly counted:
T128,32layers,one16-thread pass,GPUoff,total478.737s,0.267370positions/s.
prove_run393.785s includes witness98.348s/load17.595s; preceding sealing84.824s
includes overlapping load27.151s/witness80.897s. Receipt922711264B;
verify42.709s plus13.681sload. Serialization,startup fraction and steady-state
rate unknown. Never sum nested or overlapping clocks. Shared-host one-block
RTX4070 results and current3B classifier receipts do not establish private8B
high-endGPU throughput. No high-endGPU workload evidence was added here.
'''
next_action='''Next: owner measures complete verified high-endGPU workloads and fixed-context
resident1/2/4/8passes, with current admitted profile, exclusive phases, actual
capacity and startup/drain. For this seam, measure GPUinit,mutex wait/hold,
packing,allocation,H2D,kernel,D2H,STATS wait,conversion,drop submission and
actual retirement. Reconcile with an enclosing independently verified workload;
do not insert synchronizations just to separate timers. If owner traces are
absent next cycle, test a values-free same-capture correlation adapter with
equal-count shuffled-role and missing/duplicate-ID controls (hypothesis90).
No more packing/staging variants without measured materiality.
'''
readme=f'''# Fold timer attribution — cycle0159

Run `{RUN}`, checkpoint {now}. **No measured proving improvement.**

The extracted native `dev_fold_rows` body passes326 synthetic Rust executions
against an independently authored Python closed-form clock and bigint payload
reference:110successes,216injected errors/panics,20malformed shape fixtures,
2934field checks and2154output limbs. Eight corruption controls reject.
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

The leading hypothesis refines88 with tested89. All88priorhypotheses are
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
384MiBaddress cap per stage; estimated compile300MiB/other64MiB. Auxiliary
compiler thread count is unmeasured; affinity permits one CPU at a time.
Correctness-execution clocks: {clocks}. These are not proof or GPU benchmarks.

{measurement}
{baseline}
{next_action}
Owner D46 safeguards and D47/D48 funding/release direction do not amend the
private8B target or this research lane's permissions. No job liveness inferred
or owner heavy run duplicated. Only research outside runtime written; no
production/Git/receipt/calibration/instruction/safety/reviewer modification,
GPU/native build/dependency install/foreign script/external write/message/
privilege escalation or merge. Saved reports do not establish user delivery.
'''
(D/'README.md').write_text(readme)
handoff=f'''# Cycle0159: fold phase measurement prerequisite

{RUN} — {now}. **No measured proving improvement.**

Review [experiment](../experiments/fold-timer-attribution-20261030/README.md)
and [measurement interface](../experiments/fold-timer-attribution-20261030/MEASUREMENT.md).
The existing seam is `hashline/src/gpu/cuda.rs::dev_fold_rows` with unchanged
`(&DevCommit,&[Vec<Fp2>])->Result<Vec<Vec<Fp2>>,String>`.
Research code is `mock.rs`,verbatim extracted `native_fold.rs`,and independent
`reference.py`; no production patch or native observer was implemented.

326fixtures pass:110successes,216errors/panics,20malformed shapes,2934clock/
payload comparisons,2154bigint payload limbs and8corruption controls. This is
source-boundary evidence under synthetic APIs and clocks,not native error,
driver,device,receipt,privacy or elapsed-performance evidence.

The legacy fold counter omits pre-timer GPUinit/mutex/clone and post-sample
conversion/drop; STATS wait is included before its sample; errors skip the
counter. Copy wrappers synchronize earlier stream work. With the same32tick
packing reduction, explicit mock schedules save either0or32ticks. Those
arbitrary units are not a workload speed claim. A queued free is not retired
capacity. Keep enclosing verified workload clocks and actual completion edges.

No mask,pad,opening,FS/RNG,arithmetic or profile changes. Owner instrumentation
must retain error/refusal/publication behavior,private diagnostics only,
current gates,byte/refusal checks and independent full verification. Assess
instrumentation overhead and causal correlation before attribution. Do not
move locks,upgrade dependencies or add timing synchronizations from this result.

{next_action}
Ceiling unknown: `N/(T-C_critical+A_added)`; park if safely removable costs are
negligible. Main/Claude owns review and integration; nothing merged.
'''
(R/'handoffs/20261030-fold-timer-attribution.md').write_text(handoff)
progress=f'''# ZKP efficiency progress

Cycle0159 complete — `{RUN}`, October30,2026UTC.
Checkpoint {now}.

**No measured proving improvement.** The exact native fold function was tested
with synthetic Rust device/clock bindings:326cases pass,including216injected
errors/panics. Independent Python references check2934clock/payload fields and
2154bigint output limbs;8corruption controls reject. Six explicit Rust fixtures
show a32tick simulated packing reduction saving either0or32ticks depending on
prior queued work. Arbitrary ticks are not physical latency or proof gains.

The fold counter starts after initialization/mutex/clone and samples before
conversion/drop; errors skip aggregation. It includes STATS wait and copy
wrapper stream waits. No native measurement magnitude is known. A measurement
handoff targets `hashline/src/gpu/cuda.rs::dev_fold_rows`; no production patch.

Six LIVE primary records cover CUDA/Nsight, a newly assessed attribution paper,
cudarc,StateSync1.2.1 and ICICLE. Dates,licenses,commit/fetch limits saved.
All88priorhypotheses preserved;89tests88and90adds correlation controls.

{measurement}
{next_action}
[Experiment](experiments/fold-timer-attribution-20261030/README.md) ·
[Handoff](handoffs/20261030-fold-timer-attribution.md) ·
[Dated report](progress/{RUN}.md).
Saved reports do not establish user delivery or supervisor liveness.
'''
(R/'PROGRESS.md').write_text(progress)
(R/'progress'/f'{RUN}.md').write_text(progress.replace('# ZKP efficiency progress',f'# ZKP efficiency cycle0159 — {RUN}',1)+'\n'+baseline+'\nCorrectness execution: '+clocks+'.\n')
findings=f'''\n\n## Cycle0159 — fold counter boundaries and queued-work attribution — {now}

Run `{RUN}`. **No measured proving improvement.**

326Rust mock cases pass against independently authored Python clock/payload
references:110successes,216errors/panics,20malformed-shape fixtures,2934checks,
2154bigint output limbs,and8corruption controls. Seed202610300741. Native
`dev_fold_rows` body is byte-for-byte extracted; all surrounding clocks/types/
driver operations are synthetic. No device/native/proof/privacy test ran.

The current fold counter begins after GPUlookup/init,mutex acquisition and
device clone. STATS lock wait precedes its elapsed sample,so is included.
Conversion and local drops follow the sample; early errors skip aggregation.
Installed cudarc0.13.9 synchronizes its copy wrappers; Drop may enqueue frees.
These do not establish a material omission from enclosing proof clocks.

Six explicit Rust examples: packing40→8arbitraryticks with prior stream busy
until100leaves helper109unchanged; idle stream gives49→17. Adding30ticks
mutexwait or96ticksconversion leaves counter17unchanged while scope grows.
These are synthetic scheduling negatives,not measured phase savings. General
nested-interval/DAG accounting already exists in cycle0120; this cycle adds
the exact current fold function's source boundaries,error/drop paths,STATS
wait and cudarc sync/asyncfree scope. Python-only >2^53case is not validation
of native floating counters or device clock alignment.

No required proof work eliminated. Instrumentation adds observer/correlation/
buffering cost. Bound remains `N/(T-C_critical+A_added)`,unknown; only actual
safely removable critical-path time may be subtracted. Falsify on repinned
source covering all boundaries,negligible missing/removable costs,perturbation
or any output/order/refusal/privacy mismatch. Do not infer contention or move
locks. Global ranks1/2/3unchanged;all88priorrecords preserved.89refines88;
90asks fail-closed same-capture activity attribution before cross-capture
matching. No extra packing/staging variant promoted.

Interface: `hashline/src/gpu/cuda.rs::dev_fold_rows`; existing signature unchanged.
Research prototypes: `experiments/fold-timer-attribution-20261030/mock.rs`,
`native_fold.rs`,`reference.py`; owner interface `MEASUREMENT.md`. No native
observer or production patch exists. Main/Claude reviews/integrates;no merge.
Preserve initialization/error/publication order and all fresh masks,pads,
proximity/private openings,FS/RNG/receipt bytes and P1/P3 gates. Actual driver
lifetime/error/cancel/drain/capacity/privacy behavior remains untested.

LIVE search appends6primaryrecords ({len(existing)}→{len(existing)+len(sources)}).
New attribution paper v2September29 and exact CUDA12.4stream contract assessed;
Nsight updatedSeptember9verified. cudarc e12b2d96877d0bae7266c01df14f257e95bb0020
commit inspected; current release year unverified. October26StateSync1.2.1
release/license inspected: version-specific BSL1.1terms must not inherit older
MIT/Apache conclusions. Profiler LICENSE404and commit Cachemisses retained;
no code copied/executed from web and no upstream timing reproduced.

Reproduce prepare/compile/probe/audit with `run_bounded.py`,as listed in README.
Clocks: {clocks}. OneaffinityCPU,nice19,30sCPU/40salarm/45sparent,384MiBcap;
compileestimate300MiB,other64MiB. These are correctness-execution clocks.

{measurement}
{baseline}
{next_action}
Startup memory/sourcepins,commands,seed,hardware,logs,fixtures and limits are
retained under the experiment. D46/D47/D48do not change target/permissions.
Only research outside runtime written;no production/Git/receipts/calibration/
safety/instructions/reviewer edits,GPU/nativebuild/install/externalwrite/
message/escalation/merge. Saved reports are not notifications or liveness.
'''
with (R/'FINDINGS.md').open('a') as f:f.write(findings)
with (R/'sources.jsonl').open('a') as f:f.write((D/'source-records.jsonl').read_text())
state=f'''# ZKP efficiency explorer — durable state

Cycle0159 COMPLETE: `{RUN}`.
Started2026-10-30T07:41:23Z; checkpoint{now}.
Deadline08:01:23Z; next cycle no earlier than08:41:23Z.
Read AGENDA.md EVERY cycle.

**No measured proving improvement.** Current native fold body passes326mock
Rust fixtures with synthetic device/clock/types,110successes and216errors/
panics. Independent Python closed-form timing/bigint reference checks2934
fields and2154output limbs;8corruption controls reject. Six explicit mock
cases show32arbitraryticks packing savings yielding0or32helper savings.
This is source-boundary evidence,not native/proof/device/privacy performance.

The legacy counter omits GPUinit/mutex/clone before t0and conversion/local
drops after sample; STATS wait is included; pre-sample errors do not aggregate.
cudarc sync wrappers cover earlier stream work; asyncfree may remain queued.
No source finding establishes a material omission from enclosing proof clocks.
No locks,dependencies,FS/RNG,masks,pads,private openings or profiles changed.

Global ranking:(1)verified complete high-endGPUresident1/2/4/8workloads;
(2)admitted context/DD/fidelity;(3)exclusive phase/capacity measurements.
All88priorhypotheses preserved;89tests88;90newcorrelation obligation. Ceiling
N/(T-C_critical+A_added),unknown; no secs_fold-fraction Amdahl claim.

{next_action}
{measurement}
{baseline}
Six LIVE source records {len(existing)}→{len(existing)+len(sources)}. See
source-records.jsonl/web-search-log.json for exact dates/URLs/licenses/errors.
NewProfilerpaper assessed; cudarc0.13.9commit e12b2d96877d0bae7266c01df14f257e95bb0020
inspected. Current StateSync1.2.1 BSLlicense is version-specific; no reuse.
No upstream timing reproduced. Current native pins match at checkpoint.
OwnerD46safeguards,D47fundinghold,D48release direction do not amend this target
or research permissions. No job liveness inferred or heavy run duplicated.

OneCPUaffinity,nice19,30sCPU/40salarm/45sparent/384MiBcap perstage;
compileestimate300MiB,other64MiB; auxiliary compilerthreads unmeasured.
Correctness execution: {clocks}.

[Experiment](experiments/fold-timer-attribution-20261030/README.md) ·
[Handoff](handoffs/20261030-fold-timer-attribution.md) ·
[Dated report](progress/{RUN}.md).
Startup snapshots/index retained; previous findings and sources append-only.
Only research outside runtime written;no production/Git/receipt/calibration/
safety/instructions/reviewer edits,GPU/nativebuild/install/externalwrites/
messages/escalation/merge. Saved reports do not establish delivery.
'''
(R/'STATE.md').write_text(state)
dump(D/'checkpoint.json',dict(status='COMPLETE',time_utc=now,run_id=RUN,source_count=len(existing)+len(sources),hypotheses=len(hypotheses),new_full_stack_proofs=0,passes=0,positions=0,target_achieved=False))
print(json.dumps(dict(status='PASS',checkpoint_utc=now,appended_sources=len(sources),hypotheses=len(hypotheses),full_stack_proofs=0,passes=0,positions=0)))
