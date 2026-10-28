"""Persist cycle0092 evidence, ranked questions and review handoff."""
import datetime, hashlib, json, pathlib
HERE=pathlib.Path(__file__).resolve().parent
RESEARCH=HERE.parent.parent
RUN='20261020T001854Z-f39e44f4'
NOW=datetime.datetime.now(datetime.timezone.utc).isoformat()
result=json.loads((HERE/'result.json').read_text())
model=json.loads((HERE/'model-result.json').read_text())
by={s['name']:s for s in result['summaries']}
rows=[by['mixed-rows-drain0'],by['mixed-rows-drain1'],by['mixed-rows-retain-next']]

def source(title,url,published,updated,date_evidence,assessment,**kw):
    return dict(title=title,url=url,published=published,updated=updated,date_evidence=date_evidence,
        assessment=assessment,cycle='0092',run_id=RUN,access_date='2026-10-20',access_timezone='UTC',
        recorded_at_utc=NOW,evidence_kind='Native LIVE web search/open/find/click; primary sources; no foreign code executed',
        reproduced_performance=False,external_execution=False,implementation_license=None,inspected_commit_id=None,**kw)

sources=[
source('CUDA current guide: reserved/used watermarks and release-completion obligations',
 'https://docs.nvidia.com/cuda/cuda-programming-guide/04-special-topics/stream-ordered-memory-allocation.html',None,None,
 'Official live guide is undated; page version/crawl recency is not a verified update date.',
 'Used and reserved bytes, current and high-water marks differ. Synchronization precedes trimming; stream dependencies govern safe reuse. Native CudaSlice pool is a custom pool, so CUDA async-pool APIs are an analogy, not an implemented replacement. Capacity model is not actual driver page accounting.'),
source('NEW older source screened: NVIDIA2021 stream-ordered allocation',
 'https://developer.nvidia.com/blog/using-cuda-stream-ordered-memory-allocator-part-1/','2021-07-27',None,
 'Primary blog header explicitly Jul27,2021; no update date established.',
 'Allocation/free can follow stream order; pooling trades allocation overhead against retention. Native exact/best-fit reuse and drains already exist. Changing allocator API would need cudarc compatibility and stream-completion review, so no API migration or published speed factor is imported.',
 inspected_urls=['https://developer.nvidia.com/blog/using-cuda-stream-ordered-memory-allocator-part-2/']),
source('NEW repository screen: cuCascade public reservations versus pool capacity',
 'https://github.com/NVIDIA/cuCascade',None,None,
 'Root/docs undated. Served commit-history page ends at Mar17,2026 but is an older cached view, not proof of latest repository update. Releases page says no releases in served view.',
 'Docs describe global/per-stream reservations, allocated-byte tracking, memory limits and retry policies. Useful distinction for proposed telemetry, not a drop-in Rust/CUDA backend. No implementation code executed or adopted.',
 license_claim='Apache-2.0 README/badge only; LICENSE.md actual text opens failed',
 inspected_urls=['https://github.com/NVIDIA/cuCascade/blob/main/docs/memory-management.md','https://github.com/NVIDIA/cuCascade/commits/main/','https://github.com/NVIDIA/cuCascade/releases'],
 access_issues=['https://github.com/NVIDIA/cuCascade/blob/main/LICENSE: Internal Error','https://github.com/NVIDIA/cuCascade/blob/main/LICENSE.md: Internal Error','https://github.com/NVIDIA/cuCascade/raw/refs/heads/main/LICENSE.md: Cache miss','commit-history aaf1a9a link: Internal Error; no full commit inspected']),
source('zkLLMPoT v2 lookup/softmax and benchmark-scope refresh',
 'https://arxiv.org/abs/2610.08258','2026-10-06','2026-10-11',
 'Primary arXiv history v1 Oct6 12:35:49UTC, v2 Oct11 04:45:08UTC.',
 'Authors aggregate A10040GB operator timings, interpolate nonlinear costs and fit opening preparation; weight commitments are separate. Audit sequences/objective are public. This differs from required private IO and is not independently verified complete private8B evidence. Implementation promised after review, so no implementation/license verified.',
 inspected_urls=['https://arxiv.org/html/2610.08258v2'],
 author_claim='Forward certificates use sumcheck, public lookup tables and blinded commitments; softmax is a large operator cost.'),
source('SP1 v6.9.0 October release and exact inspected release-commit scope',
 'https://github.com/succinctlabs/sp1/releases/tag/v6.9.0','2026-10-10',None,
 'Primary release shows Oct10 01:20; version6.9.0 date independently appears in docs.rs version listing. Commit page itself did not expose a date.',
 'Release notes include NTT reorder removal and zerocheck evaluation work. Inspected full release commit only changes the supported CLI toolchain tag v2 to v3; it is not the GPU optimization diff. No native gain inferred.',
 inspected_release_commit='b8387fa61e1361d90ee7de49f551863418ca0f08',
 inspected_urls=['https://github.com/succinctlabs/sp1/commit/b8387fa61e1361d90ee7de49f551863418ca0f08'],
 access_issues=['https://docs.rs/crate/sp1-gpu-logup-gkr/6.9.0: not accessible','https://github.com/succinctlabs/sp1/blob/v6.9.0/LICENSE-MIT: Internal Error','https://github.com/succinctlabs/sp1/blob/v6.9.0/LICENSE-APACHE: Internal Error']),
source('SP1 NTT reorder PR diff: explicit input/output ordering tests',
 'https://github.com/succinctlabs/sp1/pull/2990/files','2026-09-29','2026-09-30',
 'Primary conversation opens/comments Sep29, merges Sep30,2026. Inspected aggregated diff labels head5f795ba; full commit endpoint failed.',
 'Diff selects direct bit-reversed output to avoid reorder passes and tests shifts, orderings and input preservation. Native commitments require their own column-order/encoding checks and already use split NTT kernels. No compatible removal or speedup established.',
 inspected_commit_ids_short=['5f795ba'],
 access_issues=['PR commit5f795ba link: Internal Error; full SHA not recovered']),
source('SP1 zerocheck PR diff: public-constant simplification and assertion retention',
 'https://github.com/succinctlabs/sp1/pull/2993/files','2026-09-30','2026-10-05',
 'Primary conversation Sep30, merge Oct5,2026; inspected aggregated diff for short heads527bd36 and19d9cb0; full commit endpoints failed.',
 'Diff aliases public zero/one operations, classifies constant multiplies and prunes unused nodes while retaining original assertions and alpha indices. Native static-template work already tested here; do not repeat generic code-size changes as a proving gain. An upstream backlink to a fork5090 speed claim could not be opened, so no fork result adopted.',
 inspected_commit_ids_short=['527bd36','19d9cb0'],
 access_issues=['PR commit527bd36 link: Internal Error','https://github.com/hemilabs/sp1/pull/7: Cache miss'])
]
sources[4]['inspected_commit_id']=sources[4]['inspected_release_commit']
(HERE/'source-records.json').write_text(json.dumps(sources,indent=2)+'\n')
queries=[
 'CUDA memory pool cached allocations out of memory release threshold documentation',
 'zk proof lookup softmax GPU sumcheck 2026 github release',
 'site.docs.nvidia.com cuda stream ordered memory allocator reservedmemhigh usedmemhigh out of memory release threshold',
 'site:github.com NVIDIA cuCascade releases memory management',
 'site:arxiv.org zkLLMPoT 2610.08258',
 'site:github.com zkllm lookup softmax license',
 '"GPU Memory Reservation" "cuCascade" "release" October 2026',
 '"LogUp" "2026" "lookup" GPU github October',
 'site:github.com/NVIDIA/cuCascade/blob/main/LICENSE.md "Apache License"',
 'site:github.com/hemilabs/sp1/pull/7 "5090"']
(HERE/'search-log.json').write_text(json.dumps(dict(access_date='2026-10-20',engine='native LIVE web',queries=queries,
  blockers=[b for s in sources for b in s.get('access_issues',[])]+['https://github.com/zkllm/zkllm: Internal Error; no implementation inspected'],
  rotation_current=['memory traffic','batching/amortization','lookup/softmax','GPU NTT/commitments','sumcheck/GKR'],
  rotation_next=['quantization/arithmetic','proof composition','GPU source allocation census'],
  external_code_executed=False),indent=2)+'\n')

hypotheses=[
 dict(rank=1,title='Owner whole-prover GPU and verified fixed-context resident workload sweep',status='highest impact; owner required',
  baseline='R8 CPU8B T128 one pass total478.737s; existing one-slot GPU evidence is not the whole prover.',
  eliminated_work='Recurring CPU sumcheck/commitment work and truly one-time setup in fixed-context1/2/4/8 passes.',
  added_costs='Transfers, complete witness/proof work, fresh masking, serialization, pipeline drain and independent verification.',
  prerequisites='Supported high-end device, native correctness/privacy pins and exclusive shared resource locks.',
  integration_cost='Large; owned native GPU work, no local GPU authority.',exactness='All original arithmetic/refusals retained.',
  privacy_soundness='No mask/opening reuse; full receipt verification and current whole-run security/privacy acceptance.',
  compatibility='Existing native GPU lane; distinct prefill/resident/decode workloads.',
  end_to_end_ceiling='Unknown without complete GPU phase clocks; kernel/CPU model ratios cannot establish50/s.',
  falsification='Sustained complete-proof slope, transfers or fit remain below50/s after all recurring work.'),
 dict(rank=2,title='NEW public next-request multiset retention at existing pool drain boundaries',status='synthetic policy PASS; no native speed or fit result',
  baseline='Exact and smallest-fit pool reuse;64-entry cache;full drains and reserve-hard retry already implemented.',
  eliminated_work='At a known public shape transition evict irrelevant idle capacity while preserving distinct buffers needed by the next exact/min requests.',
  added_costs='Search up to64 candidates per request, keep bookkeeping, free completion/synchronization, lost reuse for omitted later phases and first-touch costs.',
  prerequisites='Actual source-derived request horizon, all concurrent live/raw/cache capacity, stream completion and full-write-before-read.',
  integration_cost='Small pure planner; broad lifetime/whole-proof review before changing any drain. Native patch not supplied/applied.',
  exactness='Storage allocation decisions only; no field/kernel/transcript change authorized.',
  privacy_soundness='Public sizes only; never retain private masks/openings for reuse; stale storage completely overwritten before reads.',
  compatibility='Pinned root/R8/GPU pool policy matches; keyed R8 request body includes an uncounted32-byte key upload. Other callers remain unmodeled.',
  end_to_end_ceiling='Only potential allocation/sync/fallback work; no measured exclusive native share, so no speed bound or50/s forecast. Partial-trace603304480B is not full-stack fit.',
  falsification='Actual drains already see no useful reusable idle buffers,request planning loses reuse or increases end-to-end time,or any bytes/refusal/receipt/privacy gate changes.'),
 dict(rank=3,title='Owner exact DD per-row division dictionary (D30)',status='admitted specification; unbuilt owner work',
  baseline='Current per-score exact division planes, dominant softmax work at larger contexts.',
  eliminated_work='D30 counted20.8% committed-layout reduction at8B T512; no elapsed result.',
  added_costs='Dictionary construction and bound row/E/P lookup with all six D30 conditions and B1..B8 bindings.',
  prerequisites='Native implementation and security-owner review; profile/calibration/fidelity/privacy gates.',integration_cost='Medium/high owner integration.',
  exactness='Retain same integer function; no changed relation without review.',privacy_soundness='D27 whole-run lookup budget and fresh masking still required.',
  compatibility='Existing row/E/P softmax seam, not public-table approximation.',
  end_to_end_ceiling='Counted bytes do not predict latency; cannot add directly to other layout/kernel factors.',
  falsification='Native overhead or other phases erase complete-workload gain,or cardinality/binding conditions fail.'),
 dict(rank=4,title='Checked public constructor ownership and shorter decode overlap',status='prior bounded evidence retained; native measurement pending',
  baseline='Prior Vec/System scalar tests;full/reload public loader overlap.',eliminated_work='Avoid public array copies/overlap from prior handoffs only.',
  added_costs='Move/lifetime plumbing and all checked-digest/refusal gates.',prerequisites='Owner native loader review and exclusive memory/time probes.',
  integration_cost='Small/medium;unbuilt prior patches.',exactness='No changes to bytes,first refusal or ownership checks.',
  privacy_soundness='Cache public model material only,with original guards;no private witness state cached.',compatibility='TrainedExport::load_layer_mode.',
  end_to_end_ceiling='Prior overbroad all-load deletion CPU bound1.103104x;this candidate is narrower,not GPU projection.',
  falsification='Compiler already removes overlap,native peak unchanged,or elapsed regresses.'),
 dict(rank=5,title='NTT direct output-order adaptation',status='recent upstream diff screened;low priority until native phase/order census',
  baseline='Native split NTT and natural-column commitment/opening contracts.',eliminated_work='Only an explicit redundant reorder if one exists.',
  added_costs='Consumer remapping,all transform shifts/orders/input-immutability checks,possible worse access locality.',
  prerequisites='Locate actual reorder in current native kernels;do not duplicate earlier NTT layout work.',integration_cost='Unknown until source audit.',
  exactness='Same codeword/column order and receipt bytes mandatory.',privacy_soundness='Hiding pad/coset and challenge-column identity unchanged.',
  compatibility='Upstream uses another field/backend;no source imported.',end_to_end_ceiling='Zero if native has no redundant reorder;otherwise unknown enclosing NTT fraction.',
  falsification='Native pipeline already consumes its produced order or required remapping cancels benefit.')]
(HERE/'hypotheses.json').write_text(json.dumps(hypotheses,indent=2)+'\n')

measurements=dict(run_id=RUN,cycle='0092',new_independently_verified_complete_proofs=0,
  new_complete_passes=0,new_proved_positions=0,device='none;CPU-only symbolic capacity model',context_length=None,
  partial_commit_iterations=4,proof_workload='none',steady_state_proved_positions_per_second=None,
  total_workload_proved_positions_per_second=None,startup_fraction=None,startup_seconds=None,
  witness_seconds=None,proof_seconds=None,serialization_seconds=None,verification_seconds=None,
  long_context_prefill=False,resident_complete_pass_series=False,decode=False,
  model_wall_seconds=model['wall_seconds'],audit_wall_seconds=result['wall_seconds'],
  source_semantics='Python model of pinned Rust functions;Rust/CUDA not executed',
  required_target='complete private8B >=50 proved tokens/s RTX5090 or named high-endGPU;larger workloads allowed',
  privacy_changes='none;no mask/opening reuse',carried_owner_cpu_diagnostic=dict(model='8B',context=128,blocks=32,passes=1,
   device='CPU16threads,GPUoff',total_seconds=478.737,diagnostic_positions_per_second=128/478.737,
   prove_run_seconds=393.785,witness_nested_seconds=98.348,sealing_pass_seconds=84.824,
   fresh_verification_seconds=42.709,verification_initial_load_seconds=13.681,receipt_bytes=922711264,
   startup_fraction=None,steady_state_rate=None,serialization_seconds=None,reverified_by_researcher=False))
(HERE/'measurements.json').write_text(json.dumps(measurements,indent=2)+'\n')

readme=f'''# Pool live-capacity study — cycle0092

Run `{RUN}`. **No proving speed improvement measured.** This is a source-pinned,
one-thread Python capacity model and an independent offline policy/interval
audit. Rust/CUDA and tensor contents are never executed or allocated.

The existing implementation already has exact matching, smallest fitting
reuse, a64-buffer count limit, full drain+synchronize and reserve-hard retry.
Seven pool/gate/drain function hashes match root, frozen R8 and active GPU
sources. The R8 keyed chunked body differs from root and was inspected
separately; its32-byte key upload has no RAW_ALLOC note. Historical layer-fail
comments in zk.rs are explicitly marked hypotheses, not reproduced evidence.

Public requests derived from frozen R8 `commit_zk_chunked`: r=min(rows,128),
data rows*n*8, pads rows*q*8, powers nn*8, coefficient r*n*8, padded
coefficient r*pw*8, encoded r*nn*8, hash state ceil(193*nn/2)*8, leaves32*nn,
optional key32 bytes; pw=nn or n+q. Every modeled schedule drops its commit
before the next. It excludes openings,previous live commitments,twiddle
caches,other proof phases,allocator granularity/fragmentation,and concurrency.
The rows/n/q values are synthetic public fixtures,not an admitted profile or
a reconstruction of historical device logs. No token context is assigned.

The source policy maps to effects in `capacity_model.py`; `audit.py` imports
no model code. It independently checks request choices, multiplicity, gates,
owner sets and allocation lifetime intervals, then rejects corrupted records.
Final: {result['source_cases']} scenarios, {result['events']} events,
{result['checks']} checks, {result['corruption_controls']} corruption controls,
seed {result['seed']}. Returned resident-buffer capacity, exact/min ties,
count versus byte cap,raw bypass,one-shot failure,size-cap-before-counter,
reuse-disable,and deferred-free/synchronization controls are included.

Synthetic four-commit row-churn example (rows3033/3028/3031/3029,n16384,q64,
nn65536,chunk128,noncompact,keyed):

| Policy | Peak modeled allocation capacity (B) | Fresh pooled allocations |
|---|---:|---:|
| Existing reuse, no intervening drain | {rows[0]['peak_bytes']} | {rows[0]['fresh_attempts']} |
| Existing full drain before each iteration | {rows[1]['peak_bytes']} | {rows[1]['fresh_attempts']} |
| Proposed next-request multiset retention | {rows[2]['peak_bytes']} | {rows[2]['fresh_attempts']} |

Selective retention assigns each idle buffer at most once to the next public
exact request(s),then to minimum-capacity scratch requests,and frees only
unselected idle buffers. It never inspects private contents or frees live
buffers. Actual native usefulness is unknown. All14 fixed-geometry pairs
have identical peak with/without full drains,but fresh allocations rise5->20.
This is evidence against adding indiscriminate drains,not authority to remove
existing production drains. This partial capacity result says nothing
about complete8B device fit. No time estimate is derived from allocation counts.

`physical_bytes` in the event schema is a symbolic sum of owned allocation
capacities including modeled deferred releases. It is NOT GPU physical page
usage,RSS,VRAM,or allocation volume. The64-entry count case retains
17179885312 modeled bytes; only small Python records exist in RAM. Another
control accumulates40960 fresh bytes at just1024 peak; requested24 bytes can
occupy2048 reused capacity. Dropping idle storage without completion can leave
an OOM in the deferred-release bracket. These controls reject misleading
peak estimates; they are not measurements of CUDA allocator behavior.

Commands (working directory research root):

```
python3 experiments/pool-live-capacity-20261020/run_bounded.py capacity_model.py
python3 experiments/pool-live-capacity-20261020/run_bounded.py audit.py
python3 experiments/pool-live-capacity-20261020/run_bounded.py validate.py
```

Every experiment leaf is one observed thread,CPU0,nice19,59s wall/CPU cap,
512MiB AS cap. Host {model['cpu_model']},WSL2,Python{model['python']}.
Final model {model['wall_seconds']:.6f}s/{model['rss_kib']}KiB;
audit {result['wall_seconds']:.6f}s/{result['rss_kib']}KiB. Initial existing-policy
results and sources are preserved under before-selective-retention/;run logs
retain subsequent refinement. No compiler/dependency/native build was run.

Baseline/eliminated work/added costs/prerequisites/ceiling/falsifiers are in
hypotheses.json. Native seam: cuda.rs pool_take/take_min/put, dev_pool_drain,
dev_reserve_hard and keyed commit_zk_chunked. Tested prototype patch location:
capacity_model.py's retain branch; no production Rust patch,application or merge.
Owner must obtain actual public request/lifetime traces and test all current
CPU/GPU codeword,first-refusal,receipt,CS/H-1,one-shot-failure and privacy gates
under the shared locks before any native change or device run.

New completed independently verified full-stack proofs/passes/positions0/0/0;
device/context none. New witness/proof/serialization/verification clocks,
steady-state/total-workload proved rates and startup fraction unmeasured.
No long-context prefill,resident proof series or decode ran;attention can grow
quadratically. Larger workloads remain allowed. The complete private8B
>=50 proved-token/s target on RTX5090/high-endGPU remains unachieved.
Carried owner CPU8B T128,one16-thread pass,GPUoff,total478.737s is0.267370
positions/s,not reverified here. prove_run393.785s contains witness98.348s;
sealing84.824s overlaps witness/load;fresh verify42.709s+13.681s initial load.
Receipt922711264B. Startup/steady/isolated serialization remain unknown.

LIVE search covered NVIDIA allocation semantics/cuCascade,October SP1
NTT/zerocheck releases/diffs,and lookup/softmax zkLLMPoT v2. Dates,licenses,
inspected full/short commit scopes and cache errors are in source-records.json
and search-log.json. Author performance is not reproduced or imported.

Only research written;runtime/,production,Git,receipts,calibration,safety,
instructions/reviewer files untouched. No GPU/install/external write/message/
purchase/escalation. Fresh masks and complete proof coverage remain mandatory.
Checkpoint {NOW}.
'''
(HERE/'README.md').write_text(readme)

handoff=f'''# Public request retention candidate — 2026-10-20

Run `{RUN}`; research-only,unbuilt/unapplied. No native speed result.

Interface: take the pool's public capacity vector plus an ordered MULTISET of
next exact requests followed by next minimum-capacity requests. Assign each
idle buffer at most once,using the existing first-smallest-fit semantics;
retain selected buffers in their original order,free only unselected idle
buffers,and observe stream/free completion before relying on reclaimed bytes.
Never inspect values,free a live lease,or reuse private masks/openings.

Patch location: tested Python `capacity_model.py` retain branch in
experiments/pool-live-capacity-20261020/. No production patch exists. Native
seam: frozen R8 hashline/src/gpu/cuda.rs pool_take441,pool_put455,
pool_take_min465,commit_zk_chunked1817,dev_pool_drain3146,
dev_reserve_hard3183;owner must re-pin/rebase. Existing drains/retry are already
present,including legacy zk.rs layer-top/after-H;do not add a redundant drain.

Validation: {result['source_cases']} synthetic scenarios,{result['events']} events,
{result['checks']} independent request/lifetime checks,{result['corruption_controls']}
evidence corruptions rejected. Mixed public row schedule: no-drain peak
1794484768B/8 fresh;full-drain603304480B/20 fresh;selective603304480B/8 fresh.
Fixed-geometry full drain saves0 peak bytes and raises fresh5->20 over four
partial commits. These are modeled allocation capacities and counts,not VRAM,
CUDA clocks,full-layer/full-stack fit or complete-model passes.

Limits: synthetic dimensions and known-next-commit horizon;all previous
commitments dropped between iterations;no openings,caches,other phases or
concurrent leases;immediate/deferred release brackets do not reproduce the
driver. Rust policy was transcribed into Python,not executed. R8 optional
32-byte key upload is outside the current RAW_ALLOC note count;this alone is
not a meaningful speed lever. No native timing/receipt/privacy gate passed
in this cycle. D33 does not cover8B/R8/GPU/next-token merely by this study.

Owner next: source/request census at actual current trained/GPU call sites,
then native telemetry that distinguishes live pooled,idle pooled,raw,cache
and completed/pending releases. Compare original full drains with public
retention only where pressure and reuse coexist. Preserve exact/min choices,
one-shot/cap/refusal behavior and complete CPU/GPU bytes/receipt/CS/H-1/privacy
gates under shared build/heavy locks. Measure end-to-end allocations,sync,
witness,proof,serialization,verification and fixed-context1/2/4/8 resident
complete workloads with fresh masks. No GPU/build/merge authority here.

Falsify on absent avoidable idle,unmodeled live state or stale contents,
request-planner overhead/first-touch causing enclosing regression,or any gate
divergence. Target complete private8B >=50/s remains unchanged/unachieved.
'''
(RESEARCH/'handoffs/20261020-public-request-pool-retention.md').write_text(handoff)

report=f'''# ZKP efficiency progress

Cycle0092 complete — `{RUN}` —2026-10-20 UTC.

**No proving speed improvement measured.** A source-pinned CPU capacity
model suggests preserving useful idle GPU buffers at public shape changes.
In one synthetic four-commit row schedule,selective retention matches full
drain peak603304480B while reducing fresh pooled allocations20->8.
No-drain peak1794484768B;fixed-geometry full drains save0 peak and raise
allocations5->20. These are partial-commit models,not measured VRAM or time.
Independent audit:{result['checks']} checks,{result['events']} events,
{result['corruption_controls']} corruptions rejected;one thread,under2s per leaf,
under31MiB observed RSS. Existing drain/retry already exist;no native patch.

New independently verified complete proofs/passes/positions **0/0/0**;
device/context none. Witness/proof/serialization/verification clocks,
steady/total proved rates and startup fraction unmeasured. Carried owner
CPU8B T128 one16-thread pass,GPUoff:478.737s(0.267370 positions/s),fresh
verify42.709s+13.681s load;researcher did not reverify. No long-context
prefill,resident proof series or decode. Complete private8B >=50 proved
tokens/s on RTX5090/high-endGPU remains unachieved;larger workloads allowed,
attention may grow quadratically. No mask/opening reuse or privacy change.

LIVE sources:NVIDIA allocation guide/2021 blog,cuCascade public reservations,
SP1 October release+NTT/zerocheck diffs,zkLLMPoT v2 lookup/softmax scope.
Source/date/license/commit limits and fetch blockers saved. Seam:cuda.rs
pool/drain/reservation/keyed chunked commit. Next:complete public allocation
and caller/drain census;owner native event traces and full GPU/resident
workloads remain the largest missing evidence.

[Experiment](experiments/pool-live-capacity-20261020/README.md),
[handoff](handoffs/20261020-public-request-pool-retention.md),
[dated report](progress/{RUN}.md). Only research changed;no delivery implied.
Checkpoint {NOW}.
'''
(RESEARCH/'PROGRESS.md').write_text(report)
(RESEARCH/'progress'/f'{RUN}.md').write_text(report.replace('# ZKP efficiency progress',f'# Cycle0092 — {NOW}',1))

finding=f'''\n\n## Cycle0092 — public request pool retention, 2026-10-20

Run `{RUN}`. No proving speed improvement measured. Source-pinned capacity
model plus independent offline request/lifetime oracle,not Rust/CUDA execution.
Read current agenda,state,findings/source indexes,latest prior results and
project directions;startup pins saved. Early STATE checkpoint persisted.

Exact matching,smallest fitting take_min,64-entry cache,drain+synchronize and
reserve-hard retry already exist. Seven policy/gate/drain function hashes match
root,frozen R8 and GPU owner sources. R8 keyed commit body was separately
read:optional32-byte key upload has no RAW_ALLOC note. This tiny omission is
accounting scope,not a speed lever. Legacy zk.rs warns its historical-failure
comments are hypotheses;they are not newly reproduced measurements.

{result['source_cases']} scenarios,{result['events']} events,{result['checks']}
independent request/interval/conservation checks,{result['corruption_controls']}
corruption controls;seed{result['seed']}. Public chunked allocation formulas
include data,pads,powers,four scratch buffers,leaves and key. Fixtures include
ties,tail capacity,64-count limit,one-shot/cap/reuse-disable/raw behavior,
returned resident capacity,and explicit immediate/deferred-release brackets.
Only tiny Python records allocated. Final model{model['wall_seconds']:.6f}s/
{model['rss_kib']}KiB;audit{result['wall_seconds']:.6f}s/{result['rss_kib']}KiB;
one observed thread,CPU0,nice19,CoreUltra9 185H,WSL2,Python{model['python']}.
Each leaf59s CPU/wall,512MiB AS;no compiler,dependencies or GPU.

NEW refined hypothesis:at a public shape boundary retain a MULTISET of next
exact/min requests rather than clearing all idle buffers. Baseline already
does reuse/drain/retry. Eliminates only irrelevant idle capacity and avoidable
scratch reacquisition. Added costs:searching <=64 candidates/request,release synchronization,
lost later-phase reuse,bookkeeping and first-touch. Synthetic mixed row
3033/3028/3031/3029,n16384,q64,nn65536,chunk128,four commit/drop iterations:
no drain peak1794484768B,8 fresh;full drain603304480B,20 fresh;selective
603304480B,8 fresh. All14 fixed-geometry pairs have identical peak across
full/no drains but fresh5->20. Negative finding:indiscriminate extra draining
can throw away useful reuse. This does not authorize removing existing drains.

The model uses actual source formulas but synthetic public dimensions and
constructed partial-commit order. Previous commits are dropped;openings,
other live commitments,twiddle/cache state,other phases,fragmentation and
concurrency are excluded. Event physical_bytes means symbolic owned capacity,
not VRAM. Device-time/fit gain is unknown. End-to-end ceiling has no numeric
estimate because allocation/sync/fallback exclusive share is unmeasured.
Falsify on absent avoidable idle,incorrect public horizon,stream/stale-value
or refusal/receipt divergence,or enclosing elapsed regression after overhead.

Carried owner R8 CPU diagnostic:8B T128,32blocks,one16-thread pass,GPUoff,
total478.737s=>0.267370positions/s;prove_run393.785s contains witness98.348s
and load17.595s;sealing84.824s overlaps witness80.897s/load27.151s. Commit
121.32s/31% summed block walls is a larger priority. Receipt922711264B;
fresh verify42.709s+13.681s load,recheck34.395s+10.739s load,guard165.982s
includes controls. Researcher did not reverify. Startup,steady slope and
isolated serialization unmeasured. Do not sum nested/overlapping clocks.

New independently verified full-stack proofs/passes/positions0/0/0;device/
context none. New witness/proof/serialization/verification clocks,steady/
total proved rates and startup fraction unmeasured. No long-context prefill,
resident complete-proof series or decode. Larger workloads allowed;attention
can grow quadratically. Complete private8B >=50/s RTX5090/high-endGPU
unchanged/unachieved. No mask/opening reuse or weakened privacy. D33 narrow
TinyLlamaT32 pg_rot1 CPU R7 scope and D27/D30/D32 obligations remain.

Ranked hypotheses in experiment/hypotheses.json:1 owner whole-prover GPU+
verified resident1/2/4/8;2 public-request pool retention/actual capacity census;
3 exact DD owner integration;4 prior public-loader ownership/scopes;5 NTT
output-order census. Actual native measurements outrank modeled memory wins.
Prototype patch location:capacity_model.py retain branch,no Rust patch or
integration. Handoff:handoffs/20261020-public-request-pool-retention.md.

LIVE seven primary records:CUDA guide,previously unassessed2021 allocator
blog,cuCascade reservations/release view,zkLLMPoT v2,SP1 October10 release
and its NTT/zerocheck PR diffs. Author results not reproduced. The inspected
full release commitb8387fa61e1361d90ee7de49f551863418ca0f08 is a CLI toolchain
tag change,not the GPU change. PR diff short IDs and full-SHA/license fetch
errors are explicit. No license inferred from a badge;source-records and
search-log retain dates/URLs/access blockers. No foreign code executed.

Next local:source-only census of all pooled/raw/cache allocations and current
trained/GPU caller/drain sites,especially raw key/twiddles and zerocheck/fold
scratch outside current counters. Build a public request-horizon coverage
table before proposing native retention. Do not repeat this synthetic schedule
as a benchmark or assume legacy drains cover every trained path. Owner owes
actual device telemetry/complete receipt gates and high-end GPU workload sweep.
Only research written;runtime/,production,Git,receipts,calibration,safety,
instructions/reviewer files untouched;no GPU/install/external write/message/
purchase/escalation. Saved reports imply no delivery. Checkpoint {NOW}.
'''
f=RESEARCH/'FINDINGS.md'
if f'## Cycle0092 —' not in f.read_text():
    with f.open('a') as out: out.write(finding)
ledger=RESEARCH/'sources.jsonl'
existing=[json.loads(s) for s in ledger.read_text().splitlines()]
if not any(s.get('run_id')==RUN for s in existing):
    with ledger.open('a') as out:
        for s in sources: out.write(json.dumps(s,sort_keys=True)+'\n')

state=f'''# ZKP efficiency explorer — durable state

Cycle0092 COMPLETE: `{RUN}`,2026-10-20 UTC;checkpoint {NOW}.
Next cycle no earlier2026-10-20 01:18:54 UTC;deadline00:38:54 UTC.
Startup/input/findings/source indexes:experiments/pool-live-capacity-20261020/.

**No proving speed improvement measured.** Source-pinned Python pool-capacity
model:{result['source_cases']} scenarios,{result['events']} events,
{result['checks']} independent policy/interval checks,{result['corruption_controls']}
corruptions rejected;seed{result['seed']}. Seven pool/gate/drain function
hashes match root/R8/GPU. Exact/smallest-fit reuse,64-count limit,full drain+
sync and reserve-hard retry already exist. Legacy failure comments are marked
hypotheses. R8 optional32-byte key upload outside RAW_ALLOC count is tiny.

NEW public next-request MULTISET retention prototype:synthetic four-commit
mixed-row schedule no-drain1794484768B/8 fresh,full-drain603304480B/20 fresh,
selective603304480B/8 fresh. All14 fixed-shape pairs full-drain saves0 peak
bytes and raises fresh5->20. Modeled capacities only,not VRAM/time/native fit.
No openings/prior live commitments/caches/other phases/concurrency. Model
{model['wall_seconds']:.6f}s/{model['rss_kib']}KiB,audit{result['wall_seconds']:.6f}s/
{result['rss_kib']}KiB;1thread,CPU0,nice19,CoreUltra9 185H,WSL2,Python{model['python']}.
Every leaf59s wall/CPU,512MiB AS.No compiler/native/GPU/dependency execution.

Carried R8 owner diagnostic only:8B T128,32blocks,one16-thread CPU pass,GPUoff,
total478.737s=0.267370positions/s. Prove_run393.785s contains witness98.348s
and load17.595s;sealing84.824s overlaps load27.151/witness80.897s. Commit
121.32s/31% summed block walls. Receipt922711264B;fresh verify42.709s+
13.681s initial load,recheck34.395s+10.739s load;guard165.982s includes controls.
Researcher did not reverify. Startup,steady and isolated serialization unknown.

New independently verified full-stack proofs/passes/positions **0/0/0**;
device/context none. New witness/proof/serialization/verification clocks,
steady/total proved rates and startup fraction unmeasured. No long-context,
resident complete-proof series or decode. Larger workloads allowed;attention
can grow quadratically. Complete private8B >=50/s RTX5090/high-endGPU
unchanged/unachieved. No mask/opening reuse or privacy weakening.

Ranked:1 owner whole-proverGPU+verified fixed-context resident1/2/4/8;
2 public request pool retention and actual live/idle/raw census;3 exact DD
D30 unbuilt;4 prior checked public loader ownership/scopes;5 NTT output-order
census. Costs/prerequisites/ceilings/falsifiers:hypotheses.json in experiment.
Tested prototype location capacity_model.py retain branch,no Rust patch.
Seam:cuda.rs pool_take/take_min/put,dev_pool_drain,dev_reserve_hard,keyed
commit_zk_chunked. Handoff:handoffs/20261020-public-request-pool-retention.md.

Next local:pin all pooled/raw/cache allocation sites and actual trained/GPU
callers/drain sites;derive public request-horizon coverage including raw keys,
twiddles,zerocheck/fold scratch outside current counters. No invented full-stage
trace or repeated synthetic benchmark. Owner actual native/device peak/time,
first-refusal/CPU-GPU bytes/receipts/CS/H-1/privacy gates and shared locks owed.
Falsify retention on no useful idle,incorrect horizon,lost reuse or enclosing
regression. Previous public-loader and helper negative findings remain in
FINDINGS.md and startup snapshots;do not rebrand existing reuse/drains as new.

LIVE sources:CUDA guide/2021 blog,cuCascade,zkLLMPoT v2,SP1 Oct10 release and
NTT/zerocheck diffs. Seven primary records appended517->524;exact date/license/
full/short commit scope and cache failures saved. Full inspected release
commit is CLI tag fix,not GPU change.No foreign code/author performance reproduced.
Next rotation quantization/arithmetic,composition;retain lookup/softmax,
memory/amortization,NTT/commitments and sumcheck/GKR in queue.

D33 accepted TinyLlama T32 pg_rot1 CPU R7 only;R8/8B/GPU/next-token require
own scope/re-pin. D27/D30/D32 stand. Only research written;runtime/,production,
Git,receipts,calibration,safety,instructions/reviewer files untouched. No GPU/
installs/external writes/messages/purchases/escalation. Reports imply no delivery.
'''
(RESEARCH/'STATE.md').write_text(state)
print(json.dumps(dict(checkpoint=NOW,sources_before=len(existing),sources_added=len(sources),status='written',checks=result['checks'])))
