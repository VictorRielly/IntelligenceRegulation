"""Record cycle0093 without modifying production or previous findings."""
import datetime,hashlib,json,pathlib,platform
HERE=pathlib.Path(__file__).resolve().parent
R=HERE.parent.parent
ROOT=R.parent.parent
RUN='20261020T011854Z-224b9b69'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
audit=json.loads((HERE/'result.json').read_text())
model=json.loads((HERE/'staging-result.json').read_text())
census=json.loads((HERE/'census-result.json').read_text())
def write(n,v):(HERE/n).write_text(json.dumps(v,indent=2)+'\n')
previous=json.loads((R/'experiments/pool-live-capacity-20261020/hypotheses.json').read_text())
gpu=previous[0];gpu['rank']=1
dd=previous[2];dd['rank']=2
pool=previous[1];pool['rank']=3
pool.update(title='REFINED actual private-path capacity/phase census before pool policy changes',status='prior retention model insufficient for trained path; telemetry specification only',baseline='94 R8 /113 activeGPU /91 root selected allocation API sites;10 direct drain/reservation call sites outside cuda.rs. Private production has no direct drain/reserve calls in the inspected trees.',prerequisites='Actual public shape/lifetime trace, pool backing capacity, concurrent A/M/H/endpoints/boundaries, twiddle growth, FZC public-cache transient, all raw scratch and pinned-host memory.',end_to_end_ceiling='Unknown; this is prerequisite accounting, not an optimization. Legacy drains cannot simply be removed/replaced in a different private path.',falsification='Actual native trace already supplies full capacity coverage; no avoidable idle capacity or any policy worsens whole-proof time.')
fallback=dict(rank=5,title='NEW lazy two-buffer host-backed FZC staging storage reuse',status='144 synthetic byte fixtures PASS; UNBUILT/UNAPPLIED; demoted after resident-path source test',baseline='DevFzcRounds::new retains11 base plus6 two-component helper uploads until final build sync when A/H sources are host-backed.',eliminated_work='All-host source allocations23->2; staging capacity184*l->16*l bytes. A-only11->1; H-only12->2. Device-resident sources:0 eliminated allocations or bytes.',added_costs='Small Vec ownership and mutable borrow plumbing; same H2D volume and same23 existing copy synchronizations plus1 final explicit sync in all-host case. Raw allocation failure sites/order change; native allocator/stream/time effects unmeasured.',prerequisites='Observe real nonresident A/H sources in the relevant full proof; same device/stream, pinned cudarc0.13.9 synchronization contract, full overwrite and lifetime review. All original byte/refusal/receipt/privacy gates and exclusive owner locks.',integration_cost='Small constructor patch supplied for owner review only; no Rust/CUDA build, no merge.',exactness='Synthetic destination bytes only; eq/support/derived tables, masked polynomials, transcripts and receipts untested natively.',privacy_soundness='Reuse storage only inside one build; no mask/opening/challenge reuse. Every read must follow a complete current upload. Existing commitments/terminals and all refusals remain obligations.',compatibility='Active GPU candidate DevFzcRounds::new host-backed Base/Pair None branches only. Successful GPU A/H commitments yield resident sources and avoid both branches.',end_to_end_ceiling='0 eliminated work when A/H resident. Mixed/host-backed path: at most its exclusive allocation/staging/fallback share, unknown until profiled;168MiB at l=2^20 is symbolic source capacity, not native VRAM/time or8B fit.',falsification='A/H always resident on measured workload (observed source precondition gives zero opportunity), existing source lifetimes already shortened, copy stream/order differs, any native bytes/refusal changes, or full enclosing time regresses.')
loader=previous[3];loader['rank']=4
composition=dict(rank=6,title='NEW composition queue: contiguous same-degree zero-check batching with complete binding',status='gnark October release screened; no native implementation',baseline='Native23 slots have distinct masks, domains, dependencies and terminal commitments.',eliminated_work='Potential shared scheduling/round overhead only if native compatible slots exist; none identified this cycle.',added_costs='Batch randomness, retained tables, changed schedule/transcript and terminal binding proof; source-claim obligations are explicit upstream.',prerequisites='Native dependency/degree/domain census and separately versioned soundness/privacy review. Same degree alone is insufficient.',integration_cost='High protocol change; not in this patch.',exactness='Original integer function preserved only after separate proof; current frozen profile stays reproducible.',privacy_soundness='Fresh per-proof masking, whole-run soundness and all terminal/source-claim bindings.',compatibility='Go GKR API/proof format is not the native Rust masked-slot wire.',end_to_end_ceiling='Unknown; no native overhead profile or compatible batch established.',falsification='Dependencies forbid batching, retained-memory cost dominates, or new proof overhead erases full-stack benefit.')
write('hypotheses.json',[gpu,dd,pool,loader,fallback,composition,dict(previous[4],rank=7)])
metrics=dict(run_id=RUN,scope='source census and synthetic table construction only',new_completed_independently_verified_full_stack_proofs=0,new_complete_passes=0,new_proved_positions=0,device='CPU-only Python on Intel Core Ultra9 185H,WSL2; no accelerator',token_context=None,passes=0,steady_state_proved_positions_per_second=None,total_workload_proved_positions_per_second=None,startup_fraction=None,startup_seconds=None,witness_seconds=None,proof_seconds=None,serialization_seconds=None,verification_seconds=None,long_context_prefill=False,resident_complete_proof_series=False,decode=False,synthetic_seed=2026102093,hardware=dict(cpu='Intel(R) Core(TM) Ultra 9 185H',platform=platform.platform(),python=platform.python_version(),threads=1,nice=19,affinity=[0]),carried_owner_transformer_diagnostic=dict(model='8B',context=128,blocks=32,passes=1,cpu_threads=16,gpu='off',total_seconds=478.737,diagnostic_positions_per_second=128/478.737,prove_run_seconds=393.785,nested_witness_seconds=98.348,nested_block_load_seconds=17.595,sealing_seconds=84.824,sealing_nested_load_seconds=27.151,sealing_nested_witness_seconds=80.897,receipt_bytes=922711264,fresh_verify_seconds=42.709,fresh_verify_initial_load_seconds=13.681,recheck_verify_seconds=34.395,recheck_load_seconds=10.739,guard_seconds_including_controls=165.982,reverified_by_researcher=False,warning='Nested/overlapping clocks; steady/startup/isolated serialization unknown'),new_owner_document_report=dict(scope='next-token milestone, distinct workload; MVP_STATUS read this cycle',model='Llama3-8B',context=128,passes=1,device='laptop CPU as owner described',total_seconds_b7voc0=501.6,total_seconds_dg=529.2,approx_verify_seconds=57,approx_receipt_MB=928,independent_receipt_evidence_inspected=False,reverified_by_researcher=False,warning='Documentation-only update, no tokens counted by this cycle'))
write('measurements.json',metrics)
headline=f'''**No proving speed improvement measured.** The tested staging reuse saves
**zero work when A/H are already device-resident**, which is the source path
after successful GPU commitments. A fallback-only capacity option is preserved.
'''
scope=f'''New independently verified complete proofs/passes/positions **0/0/0**;
GPU device/token context none; CPU-only synthetic experiment,0 proof passes.
New witness/proof/serialization/verification clocks, steady-state and
total-workload proved rates and startup fraction **unmeasured**. No long-context
prefill,resident complete-proof series or decode ran. Larger workloads remain
allowed; attention may grow quadratically. Complete private8B >=50 proved
tokens/s on RTX5090/another named high-end GPU remains unchanged and unachieved.
No mask/opening reuse or privacy weakening.
'''
evidence=f'''144 synthetic fixtures,seed2026102093,n in1/2/3/4/6/8,
all four A/H residency combinations,both support flags,three seeds.
The independent destination-byte/event oracle passes **{audit['checks']} checks**,
{audit['negative_controls']} ordering/lifetime/alias/lexical controls and
{audit['corruption_controls']} corrupted hash/capacity/completion/site records.
These are authored single-agent checks,not an external review or native proof.
36 all-resident cases allocate0 staging buffers before and after.

Largest synthetic fixture has256 entries/table: original host staging47656B
with23 allocations versus4144B with2; the+3u64 tail per buffer is deliberate.
H2D47104B,23 copy syncs+1 final explicit sync are unchanged by ordered reuse.
The conservative variant adds17 extra explicit syncs and is retained under
before-copy-order-refinement/. The unsafe no-order and aliased-pair controls
fail,as does use after release. These model hazards are not native failures.

[MODEL] At l=2^20,all-host source staging184->16MiB (168MiB less),
split/support tables368MiB unchanged. n20 is a cube dimension,not a token
context. This excludes other tables,eq scratch,live commitments,caches,
driver/module allocations,granularity and host/pinned memory. No model-size
or actual-device-fit claim. No inference of speed from allocated bytes.
'''
census_text=f'''Selected allocation API census independently agrees on298 sites:
R8 94 (52 raw/39 pooled requests/2 backing/1 host-pinned),
activeGPU113 (67/41/2/3),root91 (49/39/2/1). It includes probes/tests and
branches; it is not a runtime trace or complete CUDA-driver allocation count.
All source pins and exact line/function/arguments are in census.json.
The scanner's initial char-literal and array-signature bugs are fixed;
failed runs remain in commands/logs. No Rust parser/compiler was run.

10 direct drain/reservation call sites outside cuda.rs are indexed. Production
sites occur in legacy layer.rs/zk.rs; the private GPU test helper adds one
drain. No direct production call occurs in inspected private_block files.
This is a source census,not proof of whole-program reachability through macros.
The prior synthetic layer-drain schedule is therefore not an actual trained
private-stack trace. dev_pool_drain clears only idle POOL storage; it does not
clear monotonic twiddles,FZC_PUB,live commitments or raw scratch.

Twiddle growth retains old plus newly uploaded forward/inverse pairs until
assignment:16*((2^old-1)+(2^new-1)) symbolic bytes. FZC public-cache insertion
uploads before evicting,so a four-entry cache can transiently coexist with a
fifth table (80MiB for five equal2^20-entry Fp2 tables). These are partial
source-derived envelopes,not simultaneous full-proof peaks or new bugs.
New FZC raw allocations are outside commitment/opening RAW_ALLOC_SCOPE by
its documented design; counters were never claimed as whole-prover capacity.
'''
dependency='''The pinned local cudarc0.13.9 Cargo.lock checksum and .cargo_vcs_info
match release e12b2d96877d0bae7266c01df14f257e95bb0020. Its htod_sync_copy
allocates then calls htod_sync_copy_into; the latter uses the device stream
and synchronizes. Same-stream storage reuse can retain existing synchronization
counts. Native CudaDevice::new,mutex and source consumers were inspected.
The full release commit changes only the version; allocation semantics are
from the inspected package/tag. MIT/Apache texts pinned; no dependency executed.
'''
seam='''Seam: active GPU candidate hashline/src/gpu/cuda.rs,DevFzcRounds::new,
host-backed FzcSrc::Base/Pair None branches (~4351/4381 before patch).
review-only-host-stage-reuse.patch and candidate-cuda.rs are UNBUILT/UNAPPLIED.
Lazy local raw buffers replace only temporary uploads and drop after the
existing build synchronize. Reuse storage,never private values or randomness.
Fully resident sources allocate nothing on this branch. H2D volume,kernel
arguments,table order and st.bytes_h2d stay the same. Constructor allocation
failure order/site changes and Rust borrow/type correctness remain untested.

Owner must first establish nonresident sources in the intended workload.
If useful,review/rebase under existing lane ownership; shared build/heavy
locks govern all native builds/device work. Run host/mixed/resident differential
tables,shadow masked rounds+next challenge,full receipt bytes+independent
verify,refusal/failure/strict GPU,CS/H-1 and current privacy gates. Measure
actual allocation capacity/HWM and enclosing prove/witness/serialization/verify.
Do not build this just to claim a speed gain on an all-resident path. No merge.
'''
sources='''LIVE sources searched: [Bits Under ZK-LLM](https://arxiv.org/abs/2609.36437),
[Efficient Sumcheck](https://github.com/compsec-epfl/efficient-sumcheck/blob/main/docs/design.md),
[gnark0.16.4](https://github.com/Consensys-Incorporated/gnark/releases/tag/v0.16.4)
and [batching PR1828](https://github.com/Consensys-Incorporated/gnark/pull/1828),
[cudarc0.13.9](https://github.com/chelsea0x3b/cudarc/blob/v0.13.9/src/driver/safe/alloc.rs),
[NVIDIA2015 stream ordering](https://developer.nvidia.com/blog/gpu-pro-tip-cuda-7-streams-simplify-concurrency/),
and [SumCATS](https://tanvirarafin.github.io/assets/pdf/DATE_2026.pdf).
DeepProve README/license/history also screened. Seven primary records appended
524->531. Exact access dates,verified/unknown publication/update dates,licenses,
full/resolved/uninspected commit distinctions and fetch failures are retained
in source-records.json and search-log.json. No author timings reproduced.
New gnark composition lead is lower priority: batching changes source-claim
binding/proof schedule and cannot be imported by matching degrees alone.
'''
carried='''[CARRIED owner diagnostic,not reverified here] CPU8B T128,32blocks,
one16-thread pass,GPUoff,total478.737s=0.267370 positions/s. prove_run393.785s
contains witness98.348s and block-load17.595s; sealing84.824s overlaps
load27.151/witness80.897s. Commit121.32s/~31% of summed block walls remains a
larger measured target. Receipt922711264B; fresh verify42.709s+13.681s initial
load,recheck34.395s+10.739s load;guard165.982s includes controls. Do not add
nested clocks or label sealing pure startup. Startup/steady/serialization
unknown. Today's MVP_STATUS also reports a newer next-token T128 CPU workload
at501.6/529.2s,~57s verification and~928MB receipt. Only documentation was read;
it is a different workload,not a new verified receipt in this cycle.
'''
next_action='''Next local experiment: derive the PRIVATE stage's actual commitment/opening
lifetimes from run.rs/protocol.rs (A,M,H,previous/current boundary and endpoints)
and combine symbolic requested capacity with raw/cache categories. Independently
check early-release and prior-boundary controls. Identify an actual peak phase;
do not replay the synthetic legacy four-commit schedule or infer device fit.
Highest-priority owner action remains whole-prover high-endGPU clocks and
independently verified fixed-context resident1/2/4/8 complete workloads.
'''
resource=f'''Final leaf clocks:census{census['wall_seconds']:.6f}s/
{census['rss_kib']}KiB,model{model['wall_seconds']:.6f}s/{model['rss_kib']}KiB,
audit{audit['wall_seconds']:.6f}s/{audit['rss_kib']}KiB. One thread,nice19,CPU0,
Intel CoreUltra9 185H/WSL2/Python{platform.python_version()}. Every experiment
leaf59s CPU/wall alarm and512MiB AS; no native build/compiler/GPU/install.
These are validation-process clocks,not staging/proof speed measurements.
'''
limits='''D33 acceptance remains scoped to TinyLlama T32 pg_rot1 CPU R7; the token-tree
re-pin note and D34 refusal-distance accounting do not themselves accept R8,
GPU,8B or next-token privacy. D27 whole-run security,D30 unbuilt and D32
fidelity threshold stand. Production,Git,runtime/,receipts,calibration,safety,
instructions and reviewer files untouched. No external writes/messages,
purchases,escalation or downloaded-script execution. Saved reports imply no
message delivery. Current chat commentary/final are separate progress updates.
'''
report=f'# Cycle0093 — allocation coverage and host-backed staging\n\nRun `{RUN}`,2026-10-20 UTC. Checkpoint {now}.\n\n'+headline+'\n'+evidence+'\n'+census_text+'\n'+dependency+'\n'+resource+'\n'+carried+'\n'+scope+'\n'+seam+'\n'+sources+'\nRanked queue:1 owner whole-proverGPU/resident sweep;2 exactDD D30;3 private-path capacity census;4 checked public-loader ownership/scopes;5 fallback staging reuse (demoted);6 reviewed composition batching lead;7 prior NTT order census. Full baseline/eliminated work/new costs/prerequisites/compatibility/privacy/ceiling/falsifiers in hypotheses.json.\n\n'+next_action+'\n'+limits
(R/'progress'/f'{RUN}.md').write_text(report)
readme=f'# Device allocation coverage — cycle0093\n\n'+headline+'\n'+evidence+'\n'+census_text+'\n'+dependency+'\n'+seam+'\nCommands from research root:\n\n```\npython3 -B experiments/device-allocation-coverage-20261020/run_bounded.py census.py\npython3 -B experiments/device-allocation-coverage-20261020/run_bounded.py staging.py\npython3 -B experiments/device-allocation-coverage-20261020/prepare_review_patch.py\npython3 -B experiments/device-allocation-coverage-20261020/run_bounded.py audit.py\n```\n\n'+resource+'\n'+scope+'\n'+sources+'\n'+next_action
(HERE/'README.md').write_text(readme)
handoff=f'# Optional host-backed slot18 staging reuse; all-resident opportunity is zero\n\nRun `{RUN}`,{now}.\n\n'+headline+'\n'+seam+'\n'+dependency+'\n'+evidence+'\nBaseline/eliminated work/added costs/ceiling: 23->2 all-host raw source allocations,184*l->16*l requested staging bytes,unchanged H2D and23 copy+1 explicit synchronizations. No entire table/proof work removed; no benefit for device-resident A/H. At most the exclusive allocation/staging/fallback time can be removed on mixed/host sources,which is unmeasured. Falsify promotion on always-resident sources or native byte/refusal/time regression.\n\n'+census_text+'\n'+scope+'\n'+next_action+'\nFull [experiment](../experiments/device-allocation-coverage-20261020/README.md),source/patch hashes,commands,resource caps and failure logs retained. Owner reviews/integrates; no merge by explorer.\n'
(R/'handoffs/20261020-host-backed-fzc-staging.md').write_text(handoff)
progress=f'''# ZKP efficiency progress

Cycle0093 complete — `{RUN}` —2026-10-20 UTC.

{headline}
144 synthetic fixtures pass an independent table-byte/lifetime audit:
{audit['checks']} checks,{audit['negative_controls']} negative controls,
{audit['corruption_controls']} corruptions rejected. A host-backed-only
prototype reduces symbolic staging184->16MiB at2^20 entries,with unchanged
H2D and existing copy synchronizations. This is no measured VRAM/time gain.
Source census covers298 selected allocation sites and exposes raw/cache costs
outside the prior partial pool model. Legacy drains are not direct production
calls in the inspected trained private path. Review-only patch remains unbuilt.

{scope}
Carried owner CPU8B T128 one16-thread pass,GPUoff,total478.737s;
fresh verify42.709s+13.681s load;not reverified here. Startup/steady/isolated
serialization unknown. Newer next-token CPU timing is a separate owner report.

LIVE sources:quantization study,EfficientSumcheck,October gnark release/batching,
pinned cudarc copy semantics,NVIDIA2015 streams,SumCATS. Seven records saved.
Next: derive private-stage commitment/opening lifetimes and an actual peak
phase; owner whole-proverGPU and verified resident workloads remain first.

[Experiment](experiments/device-allocation-coverage-20261020/README.md),
[handoff](handoffs/20261020-host-backed-fzc-staging.md),
[dated report](progress/{RUN}.md). Only research changed; no delivery implied.
Checkpoint {now}.
'''
(R/'PROGRESS.md').write_text(progress)
section='## Cycle0093 — allocation coverage and host-backed staging,2026-10-20\n\n'+f'Run `{RUN}`.\n\n'+headline+'\n'+evidence+'\n'+census_text+'\n'+dependency+'\n'+carried+'\n'+scope+'\n'+resource+'\n'+seam+'\n'+sources+'\n'+next_action+'\n'+limits
f=R/'FINDINGS.md';old=f.read_text();marker='## Cycle0093 — '
if marker in old:old=old[:old.index(marker)]
f.write_text(old.rstrip()+'\n\n'+section)
(R/'STATE.md').write_text(f'''# ZKP efficiency explorer — durable state

Cycle0093 COMPLETE:`{RUN}`,checkpoint {now}.
Next cycle no earlier2026-10-20 02:18:54 UTC;this deadline01:38:54 UTC.
Evidence:experiments/device-allocation-coverage-20261020/.

No proving speed improvement measured. Source census298 allocation API sites
(R8 94,GPU113,root91),10 direct drain/reservation callers outside cuda.rs.
Private production has no direct calls in inspected trees;legacy four-commit
drain model is not the trained private trace. Includes test/probe sites;
no runtime reachability/native peak inferred. Pool drain leaves raw scratch,
live commitments,monotonic twiddles and FZC public cache untouched.

NEW host-backed FZC two-buffer storage reuse:144 synthetic fixtures,
{audit['checks']} independent byte/event/source checks,
{audit['negative_controls']} negatives,{audit['corruption_controls']} corruptions
rejected;seed2026102093. All-host staging23->2 allocations,184*l->16*lB;
at2^20 entries168MiB symbolic saving. H2D and23copy+1explicit syncs unchanged.
Pinned cudarc0.13.9 copy_into already synchronizes same device stream.
Review-only patch UNBUILT/UNAPPLIED. EQ/support/derived/masks/receipts untested
natively. IMPORTANT NEGATIVE:successful GPU A/H commitments feed resident
sources;36 resident fixtures eliminate0B/0allocs. Fallback candidate demoted.
No native speed/VRAM or8B-fit claim. Model/audit under1s,<29MiB;scanner<5s,
one nice19 CPU0 thread,59s leaf CPU/wall and512MiB AS limits.

Carried CPU8B T128,32blocks,one16-thread pass,GPUoff,total478.737s=>0.267370
positions/s;prove_run393.785s contains witness98.348/load17.595;sealing84.824
overlaps witness/load. Receipt922711264B;fresh verify42.709+13.681load,recheck
34.395+10.739load. Not reverified. New MVP docs report next-token T128CPU
501.6/529.2s,~57sverify/~928MB,a distinct owner workload,not verified here.
Startup/steady/isolated serialization unknown;do not sum nested clocks.

New independently verified complete proofs/passes/positions0/0/0;
device/context none. New witness/proof/serialization/verification clocks,
steady/total proved rates and startup fraction unmeasured. No long-context,
resident complete-proof series or decode. Larger workloads allowed;attention
may grow quadratically. Private8B >=50/s RTX5090/high-endGPU unchanged/unmet.
No mask/opening reuse or privacy weakening.

Ranked:1 owner whole-proverGPU+verified fixed-context resident1/2/4/8;
2 exactDD D30 unbuilt;3 private-stage capacity/lifetime coverage;
4 prior checked public loader;5 fallback staging (demoted);6 composition
same-degree batching lead requires binding review;7 NTT ordering.
Baseline/eliminated work/new costs/ceiling/falsifiers:hypotheses.json.
Handoff:handoffs/20261020-host-backed-fzc-staging.md.

Next local:derive actual private run/protocol commitment/opening lifetimes
for A,M,H,previous/current boundary and endpoints;combine raw/cache capacity
categories and independently audit early-release/prior-boundary controls.
Locate an actual peak phase;do not repeat legacy synthetic drain schedules.
Owner native clocks,actual device fit/full receipts/privacy gates and shared
locks remain necessary. Do not spend native work on fallback patch without
observed nonresident A/H;all-resident opportunity is zero.

LIVE sources:BitsUnderZK-LLM,EfficientSumcheck,gnarkOct7release+Sep23batchPR,
cudarc0.13.9 exact source+full release commit,NVIDIA2015 stream-ordering,
SumCATS;seven records appended524->531. Dates/license/commit-scope and fetch
failures saved. cudarc release commit only bumps version;copy semantics
inspected from tag+local matching package. No author performance reproduced.
Next rotation GPU NTT/commitments and lookup/softmax;retain memory,
amortization,arithmetic/composition and sumcheck/GKR queue.

D33 R7 narrow scope,D34 accounting only,D27/D30/D32 persist. No production,
Git,runtime,receipts,calibration,safety,instruction/reviewer writes;no GPU,
install,external message/write,purchase/escalation. Reports imply no delivery.
''')
write('completion.json',dict(status='COMPLETE',run_id=RUN,checkpoint=now,deadline='2026-10-20T01:38:54Z',next_cycle_not_before='2026-10-20T02:18:54Z',new_verified_full_stack_proofs=0,source_records=7,local_experiment_status=audit['status'],native_patch_status='UNBUILT_UNAPPLIED'))
print(json.dumps(dict(status='checkpointed',at=now,checks=audit['checks'],findings_lines=len(f.read_text().splitlines()))))
