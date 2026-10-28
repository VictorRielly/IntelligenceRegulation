from pathlib import Path
import datetime,json,hashlib
H=Path(__file__).resolve().parent
R=H.parents[1]
run='20261020T031854Z-e03e28dc'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
a=json.loads((H/'audit-result.json').read_text());l=json.loads((H/'layout-result.json').read_text());m=json.loads((H/'model-result.json').read_text())
# Keep prose synchronized with the last bounded, source-pinned passes.
for p in [H/'README.md',R/'handoffs/20261020-mixed-fzc-arena.md']:
 s=p.read_text().replace('410988 checks','535848 checks').replace('90 controls','121 controls').replace('with90 negative controls','with121 negative controls')
 s=s.replace('and omitted\nfull-length derived initialization','omitted\nfull-length derived initialization, overlapping offsets and mixed-without-raw eligibility')
 p.write_text(s)
find=f'''\n# Cycle0095 — private transients and mixed FZC arena\n
Run `{run}`, checkpoint {now}. **No proving speed improvement measured.**
Read the current agenda,durable state/findings/source ledger,prior results,
projectCLAUDE,MVP_STATUS,DECISIONS,coordination and throughput target. Early
STATE checkpoint saved; no source promotion or native/GPU work.

New question:can the already-raw slot18 source path reserve less storage,
and would that lower backing at the private stage's real peak? The existing
code still reserves uniform-stride `kd*l` Fp2 tables. Raw tables3..19 borrow
original A/H rows for rounds0/1; the first fused fold writes HALF length.
Eq/public tables need full constructor input; raw-round0 derived tables are
written at FULL length. A mixed layout reserves17 tables at l/2 and all others
at l. A global half stride or quarter raw buffer is invalid.

**Synthetic result:**{l['fixtures']} fixtures,n3/4/5/6/8,support on/off,three
seeds,2-lane mod101 values and base-scalar challenges. Random-order in-place
folds match direct Boolean-weight multilinear evaluation of immutable
originals. {l['checks']} checks/{l['negative_controls']} controls pass,including
naivehalf,unsafequarter,missingderived,offsetalias and mixed-without-raw.
This is an independent authored reference algorithm,not an independent review,
native Goldilocks Fp2,actual fzc polynomial,masked rounds,transcript or receipt.

**New partial source accounting:**{m['cases']} traces/{m['events']} events
combine private previous+current B and OUT owners,A/H commits and slot18.
The separate lifetime-interval oracle agrees on {a['checks']} checks and
{a['negative_controls']} corruptions,80random traces,64idle-limit andoversize
controls. R8 f_e9 8B T32/64/128 geometry is applied to separately pinned active
GPU allocator source; this is hypothetical,not a supported native workload.
Repetitions1/2/4/8 repeat a partial allocation slice,not complete model passes.
No raw or pooled allocation counter is silently promoted to full-proverHWM.

At illustrativeT128,F2^21,support,kd23,the mixed request is736->464MiB
(-272MiB,36.9565%). A source-order allocation projection,one partial repetition:

| Commitment mode | Baseline backing MiB | Mixed backing MiB | Saving MiB |
|---|---:|---:|---:|
| Resident |9097.779842|9097.779842|0|
| Chunked/fullpad |1890.932186|1618.932186|272|
| Chunked/compactpad |1843.182186|1571.182186|272|

These are integers,not observedVRAM,fit,time or complete proof peaks. The
resident pool already owns larger eligible slabs; lower request savesZERO
backing. In selected chunked cases a fresh table buffer shrinks. Other actual
phases can erase the effect. Raw-source mode by itself changes neither this
baseline reservation nor the logical owner lifetime. Earlier release-only,
OUT-only eviction and all-resident host staging remain negative/demoted.

The model distinguishes requested/livecapacity/idlebacking/rawlifetimes and
cumulative allocation traffic. Idle pooled bytes remain allocated. Across
partialrepetitions4->8 backingHWMplateaus while rawallocationtrafficgrows;
cumulativebytes are notpeak. Omitted:seedownercommithistory,Hhelperconstruction,
opening scratch,other slots,failedattempts,twiddles,multiplepubliccaches,
driver/modules/granularity,pendingphysicalfrees and host/pinned/mappedmemory.
Rawfreesareimmediate inthismodel. ActualwholeGPUHWM/peakphase stillunknown.
SC_DZC in the active argument source has no deviceFzc descriptor; legacy
CUDA zerocheckscratch must not be added as if it ran in this private slot.

Eliminatedwork:storage forunusedrawinitialtails,no arithmetic or proofwork.
Addedcosts:offsetmetadata/upload,addressindirection/registerpressure,constructor
and every stride consumer,fallback/refusal/streamcompletion handling. No
end-to-end time ceiling is justified without exclusive native phase costs.
The target implication is only a possible capacity improvement in a particular
allocation route; no>=50/sprojection. Falsify on native out-of-bounds/uninitialized
or alias/round/final/proof mismatch,rawunavailable,changedrefusal/privacy,
noactualHWMbenefit or enclosing regression. No mask/opening reuse.

Seam:`cuda.rs::DevFzcRounds::new` and all later stride consumers;
`fzc_kernels.cu::fzs_ld/fzs_impl`,derivedwriters,fold/finals/hosttail.
Toy patch:layout_probe.py widths/run_fixture;projection:model.py fzc packed.
No native candidate exists. Source hashes/copies,commands,seed2026102095,
results and limits retained. Handoff:`handoffs/20261020-mixed-fzc-arena.md`.
Owner must establish usefulness then require nativeGoldilocksF2,actualpolynomial,
shadowmaskedrounds+nextchallenge,fullreceiptbyteidentity/independentverify,
fallback/refusal/strictGPU and CS/H-1/currentprivacy gates under sharedlocks.

New independently verified full-stack proofs/passes/positions**0/0/0**.
No actualtokencontext/GPU; new witness/proof/serialization/verification clocks,
steady/total rates,startupfraction**unmeasured**. No long-context prefill,
complete resident-pass series or decode. Larger workloads authorized; attention
may growT^2. Private8B >=50/s RTX5090/highendGPU unchanged/unachieved.
Carried ownerCPU8B T128,L32,one16-threadpass,GPUoff:total478.737s=>0.267370
promptpositions/s;prove_run393.785s includeswitness98.348/load17.595;
sealing84.824overlapswitness/load. Receipt922711264B;freshverify42.709+
13.681load,recheck34.395+10.739load. Not reverified. Startup/steadyslope/
isolatedserializationunknown. Ownernext-token501.6/529.2s aredistinctworkloads.

Final leaves:model{m['wall_seconds']:.6f}s/{m['rss_kib']}KiB,
audit{a['wall_seconds']:.6f}s/{a['rss_kib']}KiB,
layout{l['wall_seconds']:.6f}s/{l['rss_kib']}KiB. These are validationprocess
clocks. One nice19 CPU0 thread,CoreUltra9 185H,WSL2,Python3.10.12;
59s CPU/wall alarm and512MiBAS perleaf. Initial sourcearm extraction failures
and interim hi/lofix remain recorded;final passes usecorrectsourceorder.

LIVEsources: new [StateSync-GKR](https://arxiv.org/abs/2610.14849) and formal
companion/release, [SP1GKRPR3005](https://github.com/succinctlabs/sp1/pull/3005),
SP1Oct10release,olderSP1-zorch55composedOOM,INT4toyFFN,Sumcheck201,
BitsUnderZKLLM andefficient-sumcheck. Tenrecords538->548;exactURLs,
verified/unknowndates,scopedlicenses/unresolvedcommits andfetchfailures in
source-records.json/search-log.json. Noauthorspeedreproduced. StateSyncformal
abstract excludes multiroundFS; currentBSLdistribution differsfromhistorical
MIT/Apacheversion. INT4 8->16->8ReLUFFN isnotfullattention. Sumcheck201
primaryfullread verifiesFeb2,2024; newlyappendedbatch date refined,initialbatch
retained andprior538records byte-identical. No foreigncodeexecuted.

Ranked:1ownercompleteGPU+verifiedresident1/2/4/8;2ownerexactDDprototype;
3NEWmixedrawarena;4actualphase/capacitytelemetry;5priorpublicloader;
6OUTevictiondemoted;7earlyrelease rejected;8NTTcomposition;9publicmetadata.
Nextlocal:actualGoldilocksF2/fzcpolynomial toy+completeaddressconsumer census,
coverrawround0derived,firstfusedfold,hosttail/finals anddensefallback. Owner
measurement ofactualraweligibility/peakbacking precedes native implementation.
D27,D30,D32,D33R7scope/D34accounting preserved. Onlyresearch(excludingruntime)
written;noGPU/build/install/Git/production/receipt/calibration/safety/instruction/
reviewer/externalmessage-write/purchase/escalation. Savedreportsimplynodelivery.
'''
with (R/'FINDINGS.md').open('a') as f:f.write(find)
report=f'''# ZKP efficiency progress

Cycle0095 complete — `{run}` — {now}.

**No proving speed improvement measured.** A new mixed slot18 layout passes
30 toy fold/address fixtures and121 negative controls. At illustrative8B T128,
its table request falls736->464MiB. A partial allocation projection saves
272MiB backing with chunked commitments and **zero** with resident commitments,
where suitable pooled capacity already exists. This is synthetic memory
accounting,not nativeVRAM,fullproofmemory,fit or speed. ActualGPUpeak unknown.

72source-derived allocation traces distinguish live/requested/idle/raw/cumulative
bytes; an independent interval oracle passes646591checks/441corruptions.
Toyvalues aretwo independent residuesmod101/basechallenges,not nativeFp2 or
maskedproofs. No nativepatch,build orGPUjob.

New independently verified full-stack proofs/passes/positions**0/0/0**;
actualcontext/device none. Newwitness/proof/serialization/verificationclocks,
steady/totalrates andstartupfraction**unmeasured**. No longcontextprefill,
completeresidentpassseries ordecode. Private8B >=50provedtokens/s onRTX5090/
highendGPU remainsunchanged/unachieved. No mask/openingreuse/privacyweakening.
CarriedCPU8B T128,L32,one16-threadpass,GPUoff,total478.737s(0.267370positions/s),
notreverified; detailednestedclocks/scope inexperimentREADME/datedreport.

LIVE:StateSync-GKR Octpapers/release,SP1GKRPR/release,SP1-zorch55,olderINT4
FFN/Sumcheck201,BitsUnderZKLLM,efficient-sumcheck;10records538->548.
Dates/license/commitfetchlimits retained;noauthorperformance reproduced.

Next:extend the toy to nativeGoldilocksFp2+actualfzc polynomial and inventory
allmixed-layout readers/writers. Owner must measure actualraweligibility and
fresh/reusedbacking beforebuilding. Seam:DevFzcRounds::new andFZCkernels,
includinglatefold/finals/hosttail;allcurrentproof/privacygatesrequired.

[Experiment](experiments/private-transient-capacity-20261020/README.md),
[handoff](handoffs/20261020-mixed-fzc-arena.md),
[dated report](progress/{run}.md). Reports implyno message delivery.
'''
(R/'PROGRESS.md').write_text(report)
(R/'progress'/f'{run}.md').write_text(report+'\n'+find)
state=f'''# ZKP efficiency explorer — durable state

Cycle0095 COMPLETE `{run}`, checkpoint{now}.
Deadline03:38:54UTC;nextcycle noearlier2026-10-20T04:18:54Z.
Evidence:experiments/private-transient-capacity-20261020/.

No proving speed improvement. NEWmixedFZCarena toy:17rawtables3..19 halfL,
Eq/public/derivedfullL;rawround0writesderivedfull,firstfusedfoldwriteshalf.
Naiveallhalf/quarterinvalid.30two-lanemod101/basechallengefixtures,
535848checks/121controls pass;notnativeGoldilocksF2/fzcpolynomial/masks/proof.
T128,F2^21,support,kd23 request736->464MiB(-272). Partialallocationprojection
chunkedbacking1890.932186->1618.932186MiB;resident9097.779842unchanged.
Pooledbacking alreadyexists,reservingsmallerdoesnotfreeit. NoVRAM/fit/time.

72partialprivate-owner+A/Hcommit+slot18traces,23094events;independentinterval
oracle646591checks/441corruptions,80randomtraces,oversize/64idlecontrols.
R8geometryT32/64/128+separateactiveGPUallocator: hypotheticalversionmix.
1/2/4/8allocationrepetitionsNOTcompletepasses. Otherphases,opening/Hhelper
scratch,seedhistory,retries,caches/driver/granularity/physicalfree delay omitted.
ActualGPUpeakstillunknown. ActiveprivateDZC hasnodeviceFZCdescriptor;
legacyCUDAzero-checkscratchisnotanactualprivateDZCdeviceinvocation.

CarriedCPU8B T128,L32,one16-threadpass,GPUoff,total478.737s=>0.267370
positions/s;prove_run393.785includeswitness98.348/load17.595;sealing84.824
overlapswitness/load. Receipt922711264B;freshverify42.709+13.681load,
recheck34.395+10.739load.Notreverified.Startup/steady/serializationunknown.
Ownernext-token501.6/529.2s distinct. Newverifiedproofs/passes/positions0/0/0;
actualcontext/device none;newwitness/proof/serialization/verifyclocks,
steady/totalrates/startupfractionunmeasured.No longcontext/residentcomplete
passes/decode. >=50/s completeprivate8B highendGPU unchanged/unachieved.
Largerworkloadsallowed,attentionT^2,no masks/openingsreuse/privacyweakening.

Ranked:1ownerwholeGPU+verifiedresident1/2/4/8;2ownerDDprototype;
3NEWmixedrawarena;4actualcapacity/phase;5publicloader;6OUTevictiondemoted;
7earlyrelease rejected;8NTTcomposition;9preparedpublicmetadata.
Fullbaseline/elimination/cost/ceiling/falsification inhypotheses.json.
Nextlocal:extendmixedlayouttoytonativeGoldilocksF2/actualfzcpolynomial;
sourceenumerateALLconstructor/rawround0/firstfold/latefold/finals/hosttail
consumersanddensefallback. Beforeanativebuild,ownertelemetrymustshowraw
eligibilityandfresh/lowerbackingatrealpeak. Fullreceipt/shadow/privacygates
andsharedlocksrequired.NoRustpatch/build/GPUcandidatevalidated.
Handoff:handoffs/20261020-mixed-fzc-arena.md.

LIVE538->548:StateSyncOct10/Oct4papers+Oct10release,SP1Oct9GKRPR+Oct10
release,olderzorch55,INT4toyFFN,Sumcheck201(Feb2,2024),BitsUnderZKLLM,
efficientsumcheck.ExactURLs/dates/license-scope/unresolvedcommits/failures
saved.Noauthorperformance reproduced. NextrotationGPU-NTT/commitments,
lookup/softmax,composition/amortization;keepquantization,memory,sumcheck.
D33onlyR7TinyLlamaT32;D34accountingnotacceptance.D27/D30/D32remain.
Onlyresearch(excludingruntime)written;noproduction/Git/build/install/GPU/
externalmessage-write/purchase/escalation.Reportssavedimplynodelivery.
'''
(R/'STATE.md').write_text(state)
(H/'completion.json').write_text(json.dumps(dict(run_id=run,cycle='0095',checkpoint=now,status='complete',source_records_appended=10,new_verified_full_stack_proofs=0,countable_positions=0,native_build=False,gpu_job=False,production_patch=None,next_cycle_not_before='2026-10-20T04:18:54Z'),indent=2)+'\n')
(H/'result.json').write_text(json.dumps(dict(status='PASS_SYNTHETIC_ONLY',model=m,audit=a,layout=l,new_verified_full_stack_proofs=0,proving_speed_improvement_measured=False),indent=2)+'\n')
print(json.dumps(dict(checkpoint=now,run_id=run,source_count=len((R/'sources.jsonl').read_text().splitlines()),hypotheses=len(json.loads((H/'hypotheses.json').read_text())))))
