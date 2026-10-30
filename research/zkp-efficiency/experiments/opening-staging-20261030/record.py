import datetime,hashlib,json,pathlib
D=pathlib.Path(__file__).resolve().parent;R=D.parent.parent
RUN='20261030T015649Z-fd1dbb78';CYCLE='0156'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
def dump(name,obj):(D/name).write_text(json.dumps(obj,indent=2)+'\n')
def sha(b):return hashlib.sha256(b).hexdigest()
result=json.loads((D/'result.json').read_text());assert result['status']=='PASS'
hist=json.loads((D/'history-pins.json').read_text())
for h in hist:assert sha((R/h['path']).read_bytes()[:h['prefix_bytes']])==h['prefix_sha256']
prior=json.loads((D/'prior-hypotheses.json').read_text());assert len(prior)==82
tested={**prior[-1],'rank':83,'title':'TESTED opening-local max4 staging: bounded allocation reuse versus full-transfer batching',
 'baseline':'Root and held R14 bodies match: PCS has all rhos, chunks4; dev_fold_rows creates flat/rho/output buffers each call. Rho H2D bytes absent from its local byte counter; secs_fold begins after GPU mutex acquisition.',
 'eliminated_work':'Synthetic serial reuse takes device scratch allocation requests2B->2 per opening; full staging also takes H2D/D2H submissions B->1. Matrix scans,kernel launches,MACs,all rho/output payload bytes and pad folds unchanged. No actual native work removed.',
 'added_costs':'Opening-local capacity and wider mutex lifetime; full staging scratch k/min(k,4) times current maximum, later error observation and host staging/output coexistence. Serial reuse keeps requested max4 device scratch, but requires safe copy into preallocated buffers. Async rings require event edges,drain and cancellation ownership; their cost remains charged.',
 'prerequisites':'Actual current groups and exclusive host flatten/driver allocation/H2D/kernel/D2H/conversion/mutex-wait clocks with enclosing complete workload. Owner locks,current source/profile/privacy review and native byte/refusal gates. No GPU/native build here.',
 'integration_cost':'Moderate optional EncodedStore::fold_rows_opening default chunks4 plus CUDA override with fresh opening-local scratch. Research-only additive hook patch and exact extracted Sync trait compile; no native override implemented/applied.',
 'exactness':'436 synthetic Rust fixtures x3modes,175772scalar limbs/mode including3pad columns;42injected synchronous failures;143controls.16vectors/1344Pythonbigint limbs.130564Python assertions. Exhaustive4batch threeFIFO-engine schedules:89safe ring2orders,225/462unguarded orders corrupt. Not CUDA/FS/PCS/privacy/receipts.',
 'privacy_soundness':'Public shape/rho scheduling only. Same ordered supplied vectors including synthetic last proximity position; fresh native masks/pads/proximity/RNG/FS draws untouched because no native proof ran. Never retain private-derived scratch across openings/proofs; no output on failure. Native async lifetime and privacy acceptance remain untested.',
 'compatibility':'Held actual-working-tree and root field identical; hostfold,ZKwrapper,dev_fold_rows,kernel bodies identical despite whole-file differences. Hook defaults retain max4 call order/error propagation; overrides preflight earlier and can alter failure timing. Production source holds remain.',
 'end_to_end_ceiling':'N/(T-C_removed_exclusive+A_added); free removal<=1/(1-f) for measured exclusive fraction f, currentlyunknown. Conditional historical T128fe9 A57 uses30->2allocation requests with serial scratch1273664B;full18149712B. API counts do not predict GPU8B tokens/s.',
 'falsification':'No material exclusive allocator/submission cost; actual groups insufficient; buffer/shape/order/limb/native refusal mismatch; early overwrite/free; peak or wider-lock/enclosing-time regression; GPU errors/receipt/privacy mismatch.',
 'disposition':'Prefer bounded serial reuse for owner measurement; full staging not promoted on call counts. Exact research model and review-only default hook are not native prover improvement.'}
next_h={**tested,'rank':84,'title':'NEW public-budget hybrid: one rho upload plus bounded max4 output scratch',
 'baseline':'Tested serial needsB rho uploads; full needs1 but retainsk output vectors. In historical A T128fe9 n16384 exceeds rows3517, so full output dominates extra scratch.',
 'eliminated_work':'Potential H2D submissions B->1 within one opening; output remains boundedmax4 with Bdownloads. Two device allocations,unchanged bytes/scans/launches/MACs. Untested.',
 'added_costs':'Full rho staging and offset slices plus bounded output ownership; public budget selector and host flat growth. Conditional A57 requested scratch16*(57*3517+4*16384)=4256080B versus18149712Bfull or1273664Bserial. This is capacity arithmetic only.',
 'prerequisites':'First independently validate source-derived offsets,length overflow,cap-based selection,partial failure and fresh opening cleanup; owner exclusive H2D submission clocks determine usefulness.',
 'exactness':'Untested hybrid. Next bounded CPU experiment adds hybrid plan to the existing field/reference/lifetime harness, with public scratch budget and output-slice controls.',
 'falsification':'H2D submission cost negligible; cap rejects hybrid; offset/lifetime/cancellation mismatch; full-prover capacity/time regression.',
 'disposition':'Next small local experiment if no newer native bottleneck evidence supersedes it; global GPU/workload/phase-clock priorities remain higher.'}
dump('hypotheses.json',prior+[tested,next_h]);dump('leading-hypothesis.json',tested)
ranking=json.loads((D/'prior-ranking-current.json').read_text());ranking.update(local_tested_rank=83,local_next_rank=84)
ranking['global_priority'][0]['cycle0156_owner_update']='MVP01:54 reports3verified r16b CPU classifier-policy receipts on17public-token post,not independently reproduced/counted here. Decisions02:03 reports gate22 draftv2 checks with real-block TS1partial; explicitly no privacy acceptance. No private8BGPU target amendment.'
dump('ranking-current.json',ranking)
dump('rotation.json',{'current':['sumcheck/GKR','lookup arguments and softmax','batching/amortization','proof composition'],'next':['GPU NTT/commitments','memory traffic','quantization/arithmetic'],'queue':['GPU NTT/commitments','sumcheck/GKR','lookup arguments and softmax','memory traffic','batching/amortization','quantization/arithmetic','proof composition'],'tested':83,'next_local':84})
metrics={'new_independently_verified_full_stack_proofs':0,'new_full_stack_passes':0,'new_proved_positions':0,'actual_model_context':None,'modeled_context':128,'actual_accelerator':None,'device_count':0,'cpu':'Intel Core Ultra9 185H,one pinned nice19 worker','workload_kind':'synthetic field/buffer/lifetime model only','witness_s':None,'proof_s':None,'serialization_s':None,'verification_s':None,'startup_s':None,'initial_prefill_s':None,'startup_fraction':None,'proof_latency_s':None,'proof_bytes':None,'steady_state_proved_tokens_s':None,'total_workload_proved_tokens_s':None,'long_context_prefill_run':False,'resident_model_series_run':False,'decode_run':False,'target_reached':False,'larger_workloads_allowed':True,'attention_warning':'Longer dense context can grow attention quadratically. Independent resident passes do not establish decode.','carried_baseline_not_rerun_or_newly_counted':{'model':'8B','context':128,'layers':32,'passes':1,'threads':16,'gpu':False,'total_s':478.737,'positions_per_total_s':128/478.737,'prove_run_s':393.785,'witness_nested_s':98.348,'load_nested_s':17.595,'preceding_sealing_s':84.824,'sealing_load_nested_s':27.151,'sealing_witness_nested_s':80.897,'receipt_bytes':922711264,'verify_s':42.709,'verify_load_s':13.681,'serialization_s':None,'startup_fraction':None,'steady_state_slope':None,'note':'Nested clocks overlap; do not sum as exclusive phases or transfer toGPU.'}}
dump('target-accounting.json',metrics)
rows=[
 {'title':'NEW older2012 CUDA overlap: ordering and transfer prerequisites','url':'https://developer.nvidia.com/blog/how-overlap-data-transfers-cuda-cc/','publication_date':'2012-12-13','verified_update_date':None,'date_evidence':'Article displays Dec13,2012; primary article body inspected below its AI-generated summary.','implementation_license':None,'inspected_commit_id':None,'assessment':'Independent streams and pinned host buffers are prerequisites for real transfer overlap. The native seam uses synchronous copies. Reuse alone does not establish overlap or saved payload; no example downloaded/executed.'},
 {'title':'NEW September2026 cross-stream lifetime and bounded event dependencies','url':'https://docs.pytorch.org/devlogs/eager/2026-09-29-cross-stream-memory-without-record-stream/','publication_date':'2026-09-29','verified_update_date':None,'date_evidence':'Author WeiFeng and September29,2026 displayed.','implementation_license':None,'inspected_commit_id':None,'assessment':'Explains why ownership must outlive side-stream consumers and why allocator polling can change peak memory. Motivates generation-tagged ring/error controls. PyTorch-specific allocator behavior is not assumed for native cudarc; no author GPU performance reproduced.'},
 {'title':'NEW inspected CUDA Rust0.4 changelog: launch allocation and asynchronous resource retention','url':'https://github.com/NVIDIA/cuda-rust/releases/tag/cutile-rs/v0.4.0','publication_date':None,'verified_update_date':'2026-09-25','date_evidence':'Inspected commit changelog labels0.4.0 2026-09-25; GitHub release displays12Oct17:38withoutyear. Keep distinct; exact release year unverified.','implementation_license':'Apache-2.0: repository raw main LICENSE inspected; not separately inspected at release commit.','inspected_commit_id':'a6f1706cd832f0919b981cf61c86010c6c7c0c64','commit_scope':'Changelog/tutorial diff only; no arithmetic kernel source or device performance reproduced.','inspected_urls':['https://github.com/NVlabs/cuda-oxide','https://github.com/NVIDIA/cuda-rust','https://github.com/NVIDIA/cuda-rust/releases','https://github.com/NVIDIA/cuda-rust/commit/a6f1706cd832f0919b981cf61c86010c6c7c0c64','https://raw.githubusercontent.com/NVIDIA/cuda-rust/main/LICENSE'],'assessment':'Repository redirected from cuda-oxide to NVIDIA/cuda-rust. Release reports fewer launcher allocations and retained resources through asynchronous errors/panics. These are separate source claims, not native PCS evidence; do not upgrade/switch runtime from headline numbers. A fitting lead is completion-owned scratch and narrow public launch metadata.'},
 {'title':'REFRESH SumCATS2026: binary-field algorithm and unavailable exact update date','url':'https://tanvirarafin.github.io/assets/pdf/DATE_2026.pdf','publication_date':None,'publication_year':2026,'verified_update_date':None,'date_evidence':'Author publications page lists DATE2026; paper PDF has no verified exact publicationdate.','implementation_license':'No LICENSE displayed in inspected sum_cats root; nested implementation licenses not inspected.','inspected_commit_id':None,'inspected_urls':['https://tanvirarafin.github.io/assets/pdf/DATE_2026.pdf','https://tanvirarafin.github.io/publications/','https://github.com/SPIRE-GMU/sum_cats'],'assessment':'Binary tower-field challenge-product reconstruction reduces author-counted global accesses. It is not a GoldilocksFp2 replacement or PCS rowfold implementation. Retain independent algebraic/whole-workload gates; no reported performance reproduced.'},
 {'title':'REFRESH October2026 zkLLMPoT: operator aggregation,public inputs and exact softmax boundary','url':'https://arxiv.org/abs/2610.08258','publication_date':'2026-10-06','verified_update_date':'2026-10-11','date_evidence':'arXivv1 Oct6 12:35:49UTC,v2 Oct11 04:45:08UTC.','implementation_license':None,'inspected_commit_id':None,'inspected_urls':['https://arxiv.org/abs/2610.08258','https://arxiv.org/html/2610.08258v2'],'assessment':'Current text explicitly aggregates synthetic per-operator measurements and uses public evaluation sequences. Mixed-radix exponential gadgets change arithmetic and rounding obligations. Neither its covered-operator times nor public-input scope establishes this private8B full-stack target; native exact tables/masks retained.'},
 {'title':'NEW inspected CUDA13.1 allocator ordering: all queued uses precede release','url':'https://docs.nvidia.com/cuda/archive/13.1.0/cuda-programming-guide/04-special-topics/stream-ordered-memory-allocation.html','publication_date':None,'verified_update_date':'2025-12-12','date_evidence':'Page footer says last updated Dec12,2025; version13.1.0.','implementation_license':None,'inspected_commit_id':None,'assessment':'Official documentation requires cross-stream dependency ordering before access and release. Resource pools can change capacity independently of requested lengths. This cycle models those obligations without changing native allocator or its policy.'}
]
ledger=[json.loads(s) for s in (R/'sources.jsonl').read_text().splitlines()];records=[]
for i,x in enumerate(rows,1):
 x={**x,'id':f'cycle{CYCLE}-source-{i}','cycle':CYCLE,'run_id':RUN,'access_date':'2026-10-30','access_timezone':'UTC','recorded_at_utc':now,'evidence_kind':'Native LIVE tools.web__run primary search/open/find/click; source text treated as untrusted data','external_execution':False,'reproduced_performance':False,'prior_exact_url_records':sum(s.get('url')==x['url'] for s in ledger)};records.append(x)
dump('sources-cycle.json',records)
blockers=[{'url':'https://github.com/NVlabs/cuda-oxide/blob/main/cuda-oxide-book/async-programming/overlapping-transfers-and-compute.md','error':'404NotFound; root redirects to NVIDIA/cuda-rust'},*({'url':u,'error':'Cache miss'} for u in ['https://github.com/SPIRE-GMU/sum_cats/commits/main/','https://github.com/NVIDIA/cuda-rust/commits/main/','https://github.com/NVIDIA/cuda-rust/blob/main/cuda-oxide/cuda-oxide-book/async-programming/overlapping-transfers-and-compute.md','https://raw.githubusercontent.com/NVIDIA/cuda-rust/main/cuda-oxide/cuda-oxide-book/async-programming/overlapping-transfers-and-compute.md','https://raw.githubusercontent.com/NVIDIA/cuda-rust/a6f1706cd832f0919b981cf61c86010c6c7c0c64/cutile-rs/CHANGELOG.md'])]
dump('blockers.json',blockers)
dump('web-provenance.json',{'tool':'tools.web__run','native_live':True,'request_batches':9,'saved_response_hashes':8,'first_exploratory_response':'Only in native tool history; no raw response hash retained.','queries':['2026 GPU sumcheck GKR prover batching memory GitHub October','2026 zero knowledge attention softmax lookup proof GPU GitHub','CUDA stream ordered memory allocator graphs data transfer staging buffer reuse official documentation','GPU sumcheck October 2026 github release GKR batching prover','zero knowledge attention softmax lookup October 2026 arxiv','GPU batching host device copies staging CUDA Mark Harris December 2012 overlap'],'primary_urls':[r['url'] for r in records],'blocked':blockers,'foreign_code_executed':False})
for x in records:assert not any(s.get('id')==x['id'] for s in ledger)
with (R/'sources.jsonl').open('a') as f:
 for x in records:f.write(json.dumps(x,sort_keys=True)+'\n')

text='''# Opening-local fold staging — cycle0156

No native proving improvement was measured. Opening-local serial scratch
reuse is the first candidate for owner measurement: it removes repeated
allocation requests without increasing requested device scratch. Full
staging also batches transfers but retains all output vectors. Neither
reduces matrix scans, kernel launches, arithmetic, payload bytes or pads.

The root and held R14 files differ, but extracted `fold_rows_host`,
`fold_rows_multi_zk`, `dev_fold_rows`, `k_fold_rows`, and the whole scalar
field are identical. See `source-pins.json` and `held-seam-comparison.json`.
All source snapshots are read-only evidence; no native source was changed.

For B=ceil(k/4), requested rho/output device scratch is
16*min(k,4)*(rows+n) bytes for baseline/serial; full staging uses
16*k*(rows+n). Baseline requests2Bdevice allocations;serial/full request2.
Baseline/serial submitBuploads andBdownloads;full submits1each. All modes
launchBunchanged max4kernels and carry16*k*rowsH2D and16*k*nD2H bytes.
These are API/requested-capacity counts, not physical allocator traffic or
elapsed savings. The simulator's sentinels/output clones are correctness
instrumentation only; none are GPU work or timing predictions.

Conditional historical R14 T128/f_e9 standalone A/H groups, including
fresh proximity, not current full-run/8B groups:

| Role | k / chunks | alloc requests baseline→serial | baseline/serial scratch B | full scratch B |
|---|---:|---:|---:|---:|
| A nonDD |57 /15|30→2|1,273,664|18,149,712|
| H nonDD |12 /3|6→2|1,257,984|3,773,952|
| A DD |59 /15|30→2|1,265,856|18,671,376|
| H DD |13 /4|8→2|1,248,000|4,056,000|

Full staging is14.25x or14.75x the current maximum requested A scratch.
A two-slot ring reserves twice the serial scratch and still submits all
transfers. No overlap is claimed. Peak host flat/download/conversion
capacity, actual allocator high-water, broader GPU mutex ownership and
delayed error observation must be measured, including pipeline drain.
Existing `secs_fold` starts after mutex acquisition and conflates flatten,
allocation, upload, kernel, download and conversion; local H2D bytes omit
rho uploads. It cannot establish an exclusive removable phase.

Validation uses436seeded synthetic Rust fixtures x3modes and175,772scalar
limbs per mode including3synthetic pad columns;42injected synchronous
allocation/copy/launch errors release all simulated scratch.143controls
cover130default-hook counts0..129,1error stop,6shape/overflow and6value/
order/proximity-position/protected-row/fresh-call checks. The exact patched
native `EncodedStore: Sync` trait compiles in the standalone harness;
Mutex-based mock stores validate its default max4schedule/error propagation.
The patch itself and enclosing native crate are not built here.

Rows0/1/3/33,columns1/7/17,rhos0/1/4/5/9/12/13/57/59,dense,boundary,
protected-tail and pure-imaginary fixtures are used; actual row counts
3517/3272/3395/3116 use3columns, not full matrices. Zero/odd primitive
edges are not admitted native profiles. Real mask generation,proximity,
PCS encoding,FS/transcript,receipt byte parity,CUDA arithmetic/ABI/races,
privacy and independent native verification remain unrun.

Python independently checks16exported synthetic vectors/1,344bigint limbs,
with full-dot-product reduction, plus descriptor/source/cost controls:
130,564assertions. References are authored here, not externally reviewed.
The threeFIFO-engine lifetime model enumerates every4batch completion
order. One guarded slot has1safe order;two guarded slots have89safe orders.
Without the reuse dependency,454/462(one-slot) or225/462(two-slot) orders
corrupt generation tags. Six error cutpoints require pending uses to drain
before release. This is a bounded abstract model, not a CUDA race proof.

An optional `EncodedStore::fold_rows_opening` default plus the ZKwrapper
call is saved in `opening-hook-review-only.patch`. It preserves existing
max4default calls and error strings. No optimized CUDA override exists.
Overrides may validate shape earlier, hold the mutex longer, and observe
device errors later; exact native failure/refusal/publication behavior must
be checked. Never retry a failed launch as a fallback. Use a shape-only
preflight selector and keep per-opening resources alive until all uses end.
No cross-proof scratch content, masks, openings or randomness is reused.

Reproduce one stage at a time from the research directory:

```sh
python3 experiments/opening-staging-20261030/run_bounded.py prepare
python3 experiments/opening-staging-20261030/run_bounded.py pin-held
python3 experiments/opening-staging-20261030/run_bounded.py compile
python3 experiments/opening-staging-20261030/run_bounded.py probe
python3 experiments/opening-staging-20261030/run_bounded.py audit
```

Use a fresh experiment copy before preparation: it snapshots current
evidence and writes the early STATE checkpoint. Do not rerun `record.py`;
it appends this cycle's ledger. Pin/source drift must be reviewed first.
Each leaf has40sCPU/45salarm/50sparent timeout,384MiBaddress cap,oneCPU
affinity,nice19. Estimates300MiBcompile/96MiBother. Compiler auxiliary
threads are not individually measured; oneaffinity/codegen unit is set.
Seed202610300156;IntelCoreUltra9 185H;CPU correctness clocks are in
`*-execution.json`, not prover/GPU performance. A failed first audit assumed
the field copy omitted tests; corrected to whole-file equality. Another
audit stopped on a legitimate concurrent decisions update. Failed logs are
retained; native arithmetic/output results did not change.

Six LIVE source records and eight response hashes are saved. New older
[CUDA2012](https://developer.nvidia.com/blog/how-overlap-data-transfers-cuda-cc/),
September2026 [PyTorch lifetime guidance](https://docs.pytorch.org/devlogs/eager/2026-09-29-cross-stream-memory-without-record-stream/)
and inspected [CUDA Rust0.4 changelog](https://github.com/NVIDIA/cuda-rust/commit/a6f1706cd832f0919b981cf61c86010c6c7c0c64)
inform transfer/lifetime obligations. Refreshed
[SumCATS](https://tanvirarafin.github.io/assets/pdf/DATE_2026.pdf) and
[zkLLMPoT](https://arxiv.org/abs/2610.08258) remain different-field or
different-privacy/operator-aggregation leads. Official
[allocator ordering](https://docs.nvidia.com/cuda/archive/13.1.0/cuda-programming-guide/04-special-topics/stream-ordered-memory-allocation.html)
supplies the release dependency. Dates/nulls,release/changelog disagreement,
license boundaries,inspected changelog commit and404/Cachemiss blockers are
recorded. No external implementation or author performance was reproduced.

All82prior hypotheses are retained exactly;83records this result and84
adds full-rho/bounded-output hybrid staging. Conditional A57hybrid scratch
is4,256,080B,between serial1,273,664B andfull18,149,712B;this hybrid is
untested. Global priorities stay1owner verified high-endGPU resident1/2/4/8
workloads,2admitted context/DD/fidelity scaling,3exclusive phase clocks.
Complete ceiling remainsN/(T-C_removed_exclusive+A_added),free deletion
<=1/(1-f)withunknown exclusivef. No numerical private8BGPU forecast.

New independently verified full-stack proofs/passes/positions:0/0/0.
Actual context/accelerator:none;modeledT128;oneCPUworker. Witness,proof,
serialization,verification,startup/initial-prefill clocks,startup fraction,
proof latency/bytes,steady-state and total-workload rates:unmeasured.
No long-context prefill,resident-model series or decode ran. Larger
workloads remain allowed;longer attention can grow quadratically.
Complete private8B>=50provedtokens/s remains unachieved.

Owner MVP01:54 reports3verified CPUclassifier-policy receipts on a17token
public post;not reproduced/newlycounted here. Decisions02:03 reports
gate22draftv2checks with real-block TS1partial and explicitly no privacy
acceptance. No target amendment. Only research outside runtime written;
no production/Git/receipts/calibration/instructions/safety/reviewer edits,
GPU/nativebuild,installs,downloadedscript,externalwrites/messages,purchases,
privilege escalation or merge. Main/Claude reviews/integrates. Saved
reports do not establish user delivery or supervisor liveness.
'''
(D/'README.md').write_text(text)
handoff='''# Opening-local max4 fold staging — review only, 2026-10-30

No native proving speedup measured. Start with bounded serial scratch reuse
only if exclusive allocation clocks justify it. Full staging increases peak
requested scratch14.25x for historical A57 while saving no scans/payload.

Interface: add `EncodedStore::fold_rows_opening(rhos)` with default ordered
chunks4and unchanged `fold_rows`/`columns`; replace only the device arm of
`fold_rows_multi_zk`. CUDA may override with two fresh opening-local buffers
and copy each max4slice into them. Keep the existing kernel,max4contract,
row-weight order,all mask/proximity rows and pad fold. Default hook alone
has no performance benefit. Do not apply while owner source holds persist.

Patch: [review-only diff](../experiments/opening-staging-20261030/opening-hook-review-only.patch).
Candidate/reference: [staging.rs](../experiments/opening-staging-20261030/staging.rs),
[exact patched trait](../experiments/opening-staging-20261030/opening_trait.rs),
[result](../experiments/opening-staging-20261030/result.json),
[costs](../experiments/opening-staging-20261030/cost-study.json),
[lifetime model](../experiments/opening-staging-20261030/lifetime-study.json).
Root and heldR14field/fold bodies match;whole-filepins differ. Full source
pins and body hashes are retained. No production diff applied/native build.

Validation:436syntheticRustfixtures x3modes,175772limbs/mode includingpad;
42synchronousfailures,143controls;16independentPythonvectors/1344limbs;
130564Pythonassertions. Patched nativeSynctrait compiles in standalone
mock. Default0..129counts retain max4 and first-error propagation. Ring2
generation model has89safe guarded orders;225/462unguarded orders corrupt.
No real CUDA/FS/PCS/receipt/refusal/privacy acceptance. All references here
are researcher-authored,not independent external/native receipt review.

Owner measurement before implementation: public opening role,rows,n,k,
real group/source pins,requested AND allocated capacities;exclusive mutex
wait,flatten,allocation,H2D,kernel,D2H,conversion,destruction/error drain;
actual peak and enclosing workload. Currentsecs_fold mixes most phases
and excludes lock wait;rhoH2Dbytes are missing locally. All recurring work
and added synchronization stay charged. Build/GPU use current sharedlocks.

Risks: copy-into-preallocated API/ABI untested;storage must outlivequeued
uses,includingerror/panic/cancel. RealGPUfaults can be reported by a later
API;retain/drainresources safely beforefailure returns. Fullstagingchanges
error cadence and earlier validation/widerlock lifetime;publishnothing on
failure andnever retry a failed launch. No persistent private-derived
contents or blinding/opening reuse. Use publicpreflight capacity to choose
mode. Exact proof bytes,order,refusals,soundness/privacy and independent
verification must pass ownergates before promotion. Falsify on no material
exclusive removablecost,peak/lock/workload regression or any parityfault.

Next local question: fullrho plus boundedoutput hybrid;potential1upload
with4,256,080BhistoricalA57scratch versus18,149,712Bfull,untested. Actual
native clocks can supersede this question. Complete8Bceilingunknown;
N/(T-C_removed_exclusive+A_added),notAPI-countthroughput. No target claim.
'''
(R/'handoffs/20261030-opening-staging.md').write_text(handoff)
short='''# ZKP efficiency progress

Cycle0156 complete — `20261030T015649Z-fd1dbb78`, October30,2026UTC.

**No measured proving improvement.** Opening-local serial scratch reuse
passed436syntheticRustfixtures across3modes;42injected synchronousfailures
releasedscratch. IndependentPythonbigint and lifetimemodel controls pass.
Conditional historicalA57allocationrequests fall30→2 at the same1.27MB
requestedscratch;fulltransferstaging grows it to18.15MB. No scans,arithmetic,
payloadbytes,masks,pads or proximity removed. No CUDA/nativeproofran.

Saved review-only openinghook and handoff;owner measures exclusivephases
beforeintegration. Next local experiment:fullrho/boundedoutput hybrid.
Six LIVE primarysources;olderCUDA2012 plusrecentlifetime/runtimeleads.
All82priorhypothesesretained;83tested,84next. Ownerclassifier progress does
not amend theprivate8BGPUtarget or establishprivacyacceptance.

New independently verified full-stack proofs/passes/positions: **0/0/0**.
Actualcontext/accelerator:none;modeledT128;onepinnedCoreUltra9CPUworker.
Witness,proof,serialization,verification,startup/initial-prefillclocks,
startupfraction,prooflatency/bytes,steady-state andtotal-workloadrates:
**unmeasured**. No long-contextprefill,residentseries ordecode ran. Larger
workloadsallowed;attentioncan growquadratically. Completeprivate8B
**>=50provedtokens/s remainsunachieved**.

[Experiment](experiments/opening-staging-20261030/README.md) ·
[Handoff](handoffs/20261030-opening-staging.md) ·
[Dated report](progress/20261030T015649Z-fd1dbb78.md).
Savedreports do notestablishuserdelivery orsupervisorliveness.
'''
(R/'PROGRESS.md').write_text(short)
dated=short.replace('(experiments/','(../experiments/').replace('(handoffs/','(../handoffs/').replace('(progress/','(../progress/')+'\n'
dated+='''Measured scope: synthetic exactGoldilocksFp2 scalarfolds plus simulated
synchronousbuffers and exhaustive bounded threeFIFOengine schedules.
Guardedring2:89safeorders;unguarded:225/462corrupt. Nativeasynchronous
errors,hardwarelifetimes,drivercapacity and elapsedbenefit remainunknown.
Source bodies match heldR14;optionaldefaulthookcompiledstandalone only.

Limits/resources:seed202610300156;nice19,oneCPUaffinity/codegenunit;
40sCPU/45salarm/50sparenttimeout and384MiBaddresscap perleaf. Estimated
300MiBcompile/96MiBothers. Compilerauxiliarythreadsnotindividuallymeasured.
Finalcompile1.526s/169476KiB;probe0.116s/8908KiB;audit0.116s/15408KiB.
Sharedhostcorrectnessclocks,notthroughput. Firstauditincorrectlyassumed
atruncatedfieldcopy;fixedwholefileassertion. Anotherstoppedonconcurrent
decisionsupdate;bothfailedlogsretained,nativepinsunchanged.

OwnerMVP01:54 reports3CPUclassifierpolicyproofs on17publictokens,
independentlyverifiedbyowner,n=1,notreproduced/newlycountedhere.
Decisions02:03 saysdraftv2/gate22checksadvanced,realblockTS1partial,
explicitlynotprivacyacceptance. Sourcesremainheld;nolivenessclaim.

Globalrank:1verifiedhighendGPUresident1/2/4/8workloads;2admittedcontext/
DD/fidelityscaling;3exclusivephase/capacityclocks. All82oldhypotheses
unchanged. Tested83retainsmax4andsafeopening-localreuse;new84proposes
hybridupload/outputstaging. ExpectedcompleteceilingN/(T-C_removed+A_added),
exclusivefractionfunknown;free-removalbound1/(1-f). No8BGPUforecast.

CarriedolderCPU8Bbaseline,notrerun/reverified/newlycounted:T128/L32,
one16threadpass,GPUoff,total478.737s=0.267370positions/s;prove_run393.785s
includeswitness98.348/load17.595;sealing84.824sprecedesitwithoverlapping
load27.151/witness80.897;receipt922711264B;verify42.709+load13.681s.
Serialization,startupfraction,steadyslopeunknown. Neveraddnestedclocks.

Onlyresearchoutsideruntimewritten;noproduction/Git/receipts/calibration/
instructions/safety/reviewerchanges,GPU/nativebuild,installs,downloaded
scripts,externalwrites/messages,purchases,escalationormerge. Main/Claude
reviewsandintegrates. Finishbefore02:16:49Z;nextcycle>=02:56:49Z.
'''
(R/f'progress/{RUN}.md').write_text(dated)
state=f'''# ZKP efficiency explorer — durable state

Cycle0156 COMPLETE: `{RUN}`.
Started2026-10-30T01:56:49Z;checkpoint{now};deadline02:16:49Z.
Nextcycle noearlierthan2026-10-30T02:56:49Z.ReadAGENDAeverycycle.
PriorSTATE/PROGRESS/AGENDA,all82hypotheses,historyprefixhashes,project
docsandnative/heldR14snapshotsinexperiments/opening-staging-20261030/.

No nativeprovingimprovement. Testopening-localmax4scratchreusefirst:
436Rustfixtures x3modes,175772limbs/modeincluding3syntheticpadcolumns;
42injectedsynchronousfailures/143controls.16Pythonbigintvectors/1344limbs,
130564Pythonassertions. ExactadditiveEncodedStore:Syncdefaulttrait
compiledstandalone;max4callorder/firsterrorretained. NotnativeCUDA/FS/PCS/
receipt/refusal/privacyacceptance. Zero/oddshapesareprimitiveedgesonly.
Ring2lifetimegenerationmodel:89guardedsafeorders,225/462unguardedcorrupt.

HistoricalconditionalstandaloneR14T128/fe9A57:serialscratch1273664B,
allocationrequests30->2;fullscratch18149712B,uploads/downloads15->1.
Samebytes/scans/launches/MACs/pads/freshstate. FullA59scratch18671376B.
Groupsarehistorical;currentfullrungroups/internalendpointunmeasured.
WholefilesdifferbutrootandheldR14field/hostfold/ZKwrapper/devfold/kernel
bodiesmatch. Review-onlydefaultopeninghookpatchandhandoffsaved,notapplied.
Currentsecs_foldconflatesphases,excludesmutexwaitandlocalH2Dbytecounter
omitsrhouploads. Actualallocatedcapacityandnativeerrordrainremainunknown.

All82priorhypothesesretainedexactly;83tested,84next:fullrho/boundedoutput
hybridtoavoidBuploadswithoutretainingalloutputs. ConditionalA57scratch
4256080B,untested. Nextboundedlocalexperiment:hybridpublicbytecapselection,
independentdescriptor/overflow/order/pad/freshcall/errorcleanupcontrols.
OwnerexclusiveH2D/allocation/clocksdetermineusefulness;newnativeevidence
mayredirect. Globalpriorities1verifiedhighendGPUresident1/2/4/8workloads,
2admittedcontext/DD/fidelityscaling,3exclusivephase/capacityclocks.
CompleteceilingN/(T-C_removed_exclusive+A_added);free-removal<=1/(1-f)
withexclusivefunknown.No8BGPUrateforecast.

SixLIVEprimarysourcerecords1032->1038;eightresponsehashes,ninerequest
batches(firstexploratoryresponseonlyinnativetoolhistory). NewolderCUDA
2012andSeptember2026PyTorchlifetimes;NVIDIAcuda-rustredirect/releases/
changelogcommita6f1706cd832f0919b981cf61c86010c6c7c0c64inspected(diffonly).
Apache2rawmainlicenseinspected;release12Octdisplayhasnoyear,changelog
labels2026-09-25,keptdistinct.RefreshSumCATSandzkLLMPoT;binaryfield/
publicinput/operatoraggregationlimitsretained.OfficialCUDA13.1ordering
footer2025-12-12.404/Cachemisseslogged,noforeigncodeexecuted/performancereproduced.
NextrotationGPUcommitments/NTT,memorytraffic,quantization/arithmetic.

OwnerMVP01:54reports3CPUclassifierpolicyproofson17publictokens,n=1,
notreproduced/newlycountedhere.Decisions02:03advancesgate22draftv2with
realblockTS1partial,explicitlynotprivacyacceptance.Noprivate8Btarget
amendment.Sourceholdsremain,owner00:28:47staterecoveryintentnotliveness.
Concurrentdecisiondocupdateisretained,separatefromnativesourcepins.

Onepinnednice19IntelCoreUltra9 185Hworker,seed202610300156.Finalcompile
1.526s/169476KiB;probe0.116s/8908KiB;audit0.116s/15408KiB.Perleaf40sCPU/
45salarm/50sparenttimeout,384MiBaddresscap,estimates300/96MiB.Compiler
auxiliarythreadsunmeasured;oneaffinity/codegenunit.Failedfieldcopyaudit
andconcurrentdocdriftlogsretained;nativearithmeticresultsunchanged.

Newindependentlyverifiedfull-stackproofs/passes/positions:**0/0/0**.
Actualcontext/accelerator:none;modeledT128.Witness,proof,serialization,
verification,startup/initial-prefillclocks,startupfraction,prooflatency/
bytes,steady-stateandtotal-workloadrates:**unmeasured**.Nolongcontext
prefill,residentseriesordecoderan.Largerworkloadsallowed;attentioncan
growquadratically.Private8B>=50provedtokens/sremainsunachieved.

CarriedolderCPU8Bbaseline,notrerun/reverified/newlycounted:T128/L32,
one16threadpass,GPUoff,total478.737s=0.267370positions/s;prove_run393.785s
includeswitness98.348/load17.595;precedingsealing84.824swithoverlapping
load27.151/witness80.897.Receipt922711264B;verify42.709+load13.681s.
Serialization,startupfraction,steadyslopeunknown.Neveraddnestedclocks.

[Experiment](experiments/opening-staging-20261030/README.md) ·
[Handoff](handoffs/20261030-opening-staging.md) ·
[Datedreport](progress/{RUN}.md).
Onlyresearchoutsideruntimewritten.Noproduction/Git/receipts/calibration/
instructions/safety/reviewerchanges,GPU/nativebuild,installs,downloaded
scripts,externalwrites/messages,purchases,escalationormerge.Main/Claude
reviewsandintegrates.Savedreportsdonotestablishdeliveryorsupervisorliveness.
'''
(R/'STATE.md').write_text(state)
append='\n## Cycle0156 — opening-local staging and scratch lifetime\n\n'+text.split('\n',1)[1]
(D/'findings-append.md').write_text(append)
with (R/'FINDINGS.md').open('a') as f:f.write(append)
dump('completion.json',{'run_id':RUN,'cycle':CYCLE,'checkpoint_utc':now,'sources_before':1032,'sources_after':1038,'hypotheses_before':82,'hypotheses_after':84,'native_proving_improvement':False,'full_stack_proofs':0,'passes':0,'positions':0,'target_reached':False})
print(json.dumps({'status':'recorded','utc':now,'sources':1038,'hypotheses':84}))
