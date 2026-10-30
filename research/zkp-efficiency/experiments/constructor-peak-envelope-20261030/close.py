"""Write research reports from retained evidence; does not run experiments."""
from pathlib import Path
import datetime,hashlib,json,shutil
D=Path(__file__).resolve().parent;R=D.parent.parent;P=R.parents[1]
RUN='20261030T124123Z-126f56e8';CYCLE='0164'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
def dump(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
result=json.loads((D/'result.json').read_text());selected=result['selected']
oldsrc=(D/'startup/research__zkp-efficiency__sources.jsonl').read_bytes()
oldfind=(D/'startup/research__zkp-efficiency__FINDINGS.md').read_bytes()
assert (R/'sources.jsonl').read_bytes()==oldsrc,'do not overwrite concurrent source changes'
assert (R/'FINDINGS.md').read_bytes()==oldfind,'do not overwrite concurrent findings'
base=dict(access_date='2026-10-30',access_timezone='UTC',recorded_at_utc=now,run_id=RUN,cycle=CYCLE,evidence_kind='Native LIVE tools.web__run search/open/find/click; primary text untrusted; embedded instructions ignored.',external_execution=False,reproduced_performance=False,implementation_license=None,inspected_commit_id=None,publication_date=None,verified_update_date=None)
entries=[
 dict(title='REFRESH Oct26 zkDuel complete-kernel versus complete-proof scope',url='https://arxiv.org/abs/2610.37710',publication_date='2026-10-26',verified_update_date='2026-10-26',date_evidence='Primary arXiv submission history v1 Oct26 21:28:29UTC,2026.',author_claim='Matched SumCheck kernels with CPU-reference checksum gating; small-field launch overhead matters.',assessment='Kernel primitive, not private full-stack8B receipt; native constructor accounting does not eliminate field or mask work. No author performance reproduced.'),
 dict(title='NEW sparse argument architecture: SAK',url='https://eprint.iacr.org/2026/2143',publication_date='2026-09-22',date_evidence='Primary ePrint received2026-09-21,approved2026-09-22; version history403 so later revisions unknown.',author_claim='Sparse customizable-constraint-system argument with preprocessing,sublinear lookup selection,universal/updatable setup.',assessment='Potentially reduces constraint work for sparse assignments; different PCS/setup/relation and dense fresh masks preclude a direct native inference. High integration and new soundness/privacy obligations; parked pending measured sparse scope.',blocked_urls=['https://eprint.iacr.org/archive/versions/2026/2143']),
 dict(title='NEW older technique: G10 lifetime-aware migration planning',url='https://arxiv.org/abs/2310.09443',publication_date='2023-10-13',verified_update_date='2023-10-13',date_evidence='Primary arXiv v1 Oct13 23:32:28UTC2023; publisher search metadata separately says Dec08,2023; conference dates Oct28-Nov01 not substituted for publication.',supporting_urls=['https://jianh.web.engr.illinois.edu/papers/g10-micro23.pdf','https://doi.org/10.1145/3613424.3614309'],author_claim='Compiler tensor vitality and ahead-of-time migration/prefetch using modeled host,GPU and flash bandwidth; results from an extended simulator.',assessment='Use dependency,lifetime,capacity and shared bandwidth reasoning only. Native private PCS owners remain logically live until openings; no private spill,storage,mask reuse or simulation speed transfer authorized. Candidate asks about public-weight prefetch in a measured resident workload.'),
 dict(title='NEW G10 artifact feasibility and license-scope screen',url='https://github.com/platformxlab/G10',date_evidence='Root date and commit unavailable; commits/main UnexpectedStatusCode then Cache miss. No freshness inferred from crawl date.',implementation_license='README/root declare Apache2.0; correctly spelled LICENCE body Cache miss; dependencies and inherited simulator licenses not audited.',assessment='README and src directory inspected,not implementation bodies. Artifact declares >=30GB RAM and120GB disk,about28.5GB per simulation: excluded from this bounded lane. No install,downloaded script execution or simulation attempted.',blocked_urls=['https://github.com/platformxlab/G10/commits/main/','https://github.com/platformxlab/G10/blob/main/LICENSE','https://github.com/platformxlab/G10/blob/main/LICENCE']),
 dict(title='REFRESH Blackwell NTT locality and transfer scope',url='https://github.com/ingonyama-zk/icicle/issues/1046',publication_date='2026-05-29',verified_update_date='2026-07-02',date_evidence='Primary issue openedMay29,2026,author discussionJul2,2026; not repository HEAD or report revision.',implementation_license='Linked harness root declares MIT; LICENSE body and history Cache miss; no code adopted.',supporting_urls=['https://github.com/pscamillo/icicle-blackwell-ntt'],author_claim='BabyBear standalone reorder and coalesced permutation prototype on RTX5070; host-input NTT includes large transfer share.',assessment='Already assessed cycles0101/0140; not new. Native frozen CUDA p1 already fuses bit-reversed gather with DIT and padding,so a separate reorder share cannot be transferred. No upstream performance reproduced.',blocked_urls=['https://github.com/pscamillo/icicle-blackwell-ntt/blob/main/LICENSE','https://raw.githubusercontent.com/pscamillo/icicle-blackwell-ntt/main/LICENSE','https://github.com/pscamillo/icicle-blackwell-ntt/commits/main/','https://github.com/pscamillo/icicle-blackwell-ntt/blob/main/REPORT.md','https://raw.githubusercontent.com/pscamillo/icicle-blackwell-ntt/main/REPORT.md']),
 dict(title='REFRESH ICICLE displayed release and immutable version diff',url='https://github.com/ingonyama-zk/icicle/releases',inspected_commit_id='6c77775961b0e4dc2be359feec1ac11536c18043',date_evidence='Release renders11Jul05:36 without year in this refresh; version diff does not expose a date. Exact publication/update year not re-established.',supporting_urls=['https://github.com/ingonyama-zk/icicle/commit/6c77775961b0e4dc2be359feec1ac11536c18043'],assessment='v4.0.0 still displayed Latest. Inspected commit is Cargo version bump,not backend implementation. No dependency adopted; API/release label does not establish native field/proof/privacy compatibility.'),
 dict(title='REFRESH official Rust lexical drop-scope semantics',url='https://doc.rust-lang.org/reference/destructors.html',date_evidence='Current reference accessed; exact publication/update date unknown; small skeleton compiled with local Rust1.75.0.',assessment='Local variables remain tied to enclosing drop scope; returned owners move while leaves/powers drop. Small requested-allocation skeleton confirms the resource pattern only. Borrow last-use and automatic allocator/RSS release are different evidence.'),
 dict(title='REFRESH older ZKProphet primitive bottleneck warning',url='https://arxiv.org/abs/2509.22684',publication_date='2025-09-17',verified_update_date='2025-09-17',date_evidence='Primary arXiv history v1Sep17 22:52:19UTC,2025.',author_claim='After optimized MSM,NTT can dominate selected GPU ZK workloads; 32-bit integer pipeline and representation choices matter.',assessment='Does not identify the native private8B dominant phase. Preserve exclusive phase and total-workload measurement requirement; do not assume NTT dominance here.'),
]
prior=[json.loads(x) for x in oldsrc.splitlines()]
records=[]
for i,e in enumerate(entries,1):
 x=dict(base,**e);x['id']=f'cycle{CYCLE}-source-{i}';x['prior_exact_url_records']=sum(y.get('url')==x['url'] for y in prior);records.append(x)
newbytes=''.join(json.dumps(x,sort_keys=True)+'\n' for x in records).encode()
(D/'source-records.jsonl').write_bytes(newbytes)
(R/'sources.jsonl').write_bytes(oldsrc+newbytes)
dump(D/'search-log.json',dict(tool='tools.web__run LIVE',initial_queries=['site.eprint.iacr.org 2026 zero knowledge GPU memory commitment lookup October','site.github.com GPU zero knowledge lookup NTT releases 2026 Icicle'],followup_queries=['site.arxiv.org zkDuel October 26 2026','SAK Sparse Arguments github','icicle-blackwell-ntt commit','zkDuel GPU proving','SAK: Sparse Arguments of Knowledge implementation','Carter Gatlin Towards an optimal bit reversal permutation program COBRA 1998','site.arxiv.org zero knowledge GPU memory October 2026 proving','Checkmate breaking memory wall optimal tensor rematerialization 2019 2020 github license','site.github.com ingonyama icicle issue 1046 Blackwell','G10 Enabling Efficient Unified GPU Memory Storage Architecture Smart Tensor Migrations arxiv github'],retained_responses='web-1.json through web-12.json; initial discovery responses not separately captured,exact selected pages reopened',primary_only_for_claims=True,foreign_code_executed=False))
priorh=json.loads((D/'hypotheses.json').read_text());dump(D/'prior-hypotheses.json',priorh)
assert priorh[-1]['rank']==96
priorh[-1].update(title='REFINED/TESTED partial constructor phase envelopes before admission',exactness='216 six-field native metadata comparisons;24 small Rust allocation skeletons/240 snapshots;4600 assertions/249 accounting controls. No native constructor/prover or GPU execution.',disposition='Selected partial CPU phase peak remains SC_SZC; constructor staggering has weak support. Missing witness/backend/whole-run capacities forbid actual admission. Stop toy cohort variants; owner phase and capacity evidence first.',baseline='Serial independent proofs; previous partial data+encoding+tables counted neither pads/salts/trees nor construction scratch.',eliminated_work='Zero arithmetic,zero fresh masks; potential late-allocation failure or idle overlap only,unmeasured.',added_costs='Full lifecycle manifests,reserved idle/quarantined capacity,and any scheduling delay.',end_to_end_ceiling='Unknown N/(T-C_exclusive+A); even free deletion bounded by N/(T-C_exclusive). Necessary50/s condition T-C_exclusive+A<=N/50; no measured native C_exclusive.',falsification='An omitted owner/scratch/capacity exceeds the partial ledger; constructor timing is negligible or serialized dependencies leave no critical-path saving.')
priorh.append(dict(rank=97,title='NEW G10-inspired public weight prefetch under actual shared-bandwidth and capacity bounds',baseline='Native owner has one-block authenticated public weight streaming/caching; complete8B GPU transfer/compute exclusivity still unmeasured.',eliminated_work='Potential exposed public-weight transfer or reload wait; no private proof arithmetic,mask or opening work removed.',added_costs='Extra public weight staging capacity,shared PCIe/memory bandwidth,prefetch routing/drain and retained owner lifetimes.',prerequisites='Pin current backend offer/fallback path and actual read/compute dependency roster,public weights only underP1; complete independently verified resident1/2/4/8 workloads with exclusive phases.',integration_cost='Source-only owner/traffic study now; native backend observer and actual-device A/B require owner heavy/GPU locks.',exactness='Untested new hypothesis; retain same public bytes,binding,refusal,field arithmetic and transcript.',privacy_soundness='No private-state spill,mask reuse or extra private openings; P3 weights need separate review. Scheduling and resource reporting must use public geometry.',compatibility='Potential adapter/prove_core/public-block streaming seam; G10 simulator and storage modifications are not a drop-in library.',end_to_end_ceiling='Unknown; at best remove measured exposed transfer critical time,not summed overlapping kernel counters.',falsification='No dependency slack; native caching already removes reload cost; added staging/traffic increases peak or critical elapsed time.',disposition='Next bounded source/traffic prerequisite if native exclusive measurements remain unavailable; no simulator/GPU execution here.'))
dump(D/'hypotheses.json',priorh)
dump(D/'ranking-current.json',dict(owner_priorities=[dict(rank=1,title='Complete independently verified high-end-GPU fixed-context resident1/2/4/8 workloads',impact='Highest: discover recurring complete cost and startup slope; unknown ceiling',prerequisites='Admitted8B path,trained/calibration/profile pins,fresh masks,all receipts verify',integration='Owner locks/device work; not authorized in explorer'),dict(rank=2,title='Admitted context/DD/fidelity scaling',impact='Potentially reduce quadratic attention/PCS cost; no new shape accepted',prerequisites='Exactness,refusal,privacy/calibration and full receipt review',integration='High protocol/profile review cost'),dict(rank=3,title='Exclusive phase/capacity evidence; H96 source prerequisite',impact='Prevents optimizing nested clocks or incomplete buffers; no measured speedup',prerequisites='Actual host/device live/idle/quarantined capacity and source roster',integration='Native observer; source model local only'),dict(rank=4,title='H97 public prefetch with lifetime and shared-bandwidth constraints',impact='Unknown until exposed transfer fraction measured',prerequisites='Current adapter source pins and public dependency slack',integration='Medium/high native scheduling effort; no drop-in G10 port')],tested_local_hypothesis=96,new_hypothesis=97))
dump(D/'rotation-queue.json',dict(next=['lookup/softmax:SAK sparse-selection boundary and native helper capacity','GPU NTT/commitments:backend offer,fallback,public transfer/lifetime roster'],retained=['memory traffic','batching/amortization','sumcheck/GKR','quantization/arithmetic','proof composition'],assessed_this_cycle=['memory constructor payload','lookup architecture SAK','older G10 migration planning','known NTT locality refresh','recent zkDuel/ICICLE release refresh']))
account=dict(run_id=RUN,new_full_stack_proofs=0,new_passes=0,new_positions=0,actual_context=None,metadata_contexts=sorted({c['v'][0] for c in json.loads((D/'geometry.json').read_text())}),device='One CPU affinity on Intel Core Ultra 9 185H; no GPU',gpu_count=0,witness_s=None,proof_s=None,serialization_s=None,verification_s=None,startup_s=None,initial_prefill_s=None,startup_fraction=None,steady_interval_s=None,total_workload_s=None,steady_state_proved_tokens_s=None,total_workload_proved_tokens_s=None,proof_latency_s=None,proof_bytes=None,prefill_run=False,resident_model_passes=0,decode_run=False,workload_kinds_run=[],target_achieved=False,ceiling='Unknown; capacity study eliminates no proof arithmetic or fresh masking.')
dump(D/'target-accounting.json',account)
account_text='''New independently verified full-stack proofs / complete-model passes / proved positions: **0 / 0 / 0**.
Actual model context: **none**. Device: one CPU affinity on Intel Core Ultra 9
185H; no GPU. Witness / proof / serialization / verification / startup /
initial-prefill clocks, startup fraction, proof bytes/latency, steady-state and
total-workload proved-token rates: **unmeasured**. No long-context prefill,
resident-model proof passes or decode ran. Public metadata contexts17/32/64/
127/128/256/512 and modeled worker counts1/8/16 are not actual proof workloads.
Larger workloads remain allowed; increased context can increase attention
quadratically. Complete private8B **>=50 proved tokens/s remains unachieved**.
No masks, pads, private openings or private values reused for amortization.
'''
baseline='''Historical CPU8B baseline carried, not rerun/reverified/newly counted:
T128/L32, one16-thread GPU-off pass, total478.737s=0.267370positions/s.
prove_run393.785s includes witness98.348s/load17.595s. Sealing84.824s
overlaps load27.151s/witness80.897s; do not sum nested clocks. Receipt922711264B;
verification42.709s plus13.681s load. Startup fraction,serialization and steady
slope unknown. Current R18/R19 classifier3B and R14 one-layer diagnostics are
different scopes, not private8B high-end-GPU evidence.
'''
report=f'''# Cycle0164 — constructor payload versus full-lifecycle admission

Run `{RUN}`; started2026-10-30T12:41:23Z; checkpoint{now}; deadline13:01:23Z.

**No measured proving improvement.** The source-derived constructor study
refines H96: admission before witness/PCS construction requires the whole
lifecycle. Constructor-only serialization has weak support in the selected
partial CPU model. This is a cost-accounting prerequisite, not a proof result.

The new caller evaluates22 previously extracted unchanged native metadata
bodies over216 public Legacy/LowH24,DD/nonDD geometries; six new scalar
measurements per case agree with an independent formula (1,296 comparisons).
It does not run native Shape construction/admission,define,PCS constructors,
prover,hashes,NTT,RNG,transcript or GPU. The independently authored Rust resource
skeleton executes24 tiny allocation patterns and240 snapshots. Its global
allocator records requested live bytes; a separate interval-summing Python
reference agrees after separately retaining Vec headers. It does not measure
RSS,physical allocator realloc-copy overlap,device pages or CUDA pools.
Final accounting:4,600 checks and249 controls,seed20261030164.

The frozen R13 g79 public metadata is T128,n16384,A4577/H4390,q256,rate4,
two endpoint owners of37 rows. Its constructor `pows` and original unsalted
leaves remain scoped until return. The returned H field/digest owner is
2,892,312,544B; tree construction reaches2,894,933,984B:2.5MiB extra.
Two simultaneous H constructors exceed a returned-owner-only budget by5MiB.
Staggering one constructor beside one retained owner still needs2.5MiB extra.
This symbolic counterexample creates no large buffers and is not an executable
proof schedule, actual failure or complete capacity bound.

Including returned pads/salts/trees and retained M payload adds42.261459MiB
to the previous5.738464GiB single-block CPU data+encoding+tables subtotal.
The selected known-payload phase counts (one modeled worker) are:

| Phase | Known requested payload | Additional unknown witness |
|---|---:|---|
| A tree construction |3.350302GiB|live|
| H helpers before S2 drops |3.948364GiB|live|
| H tree construction |5.563427GiB|released|
| SC_SZC tables and retained commitments |5.779735GiB|released|

These are partial phase sums, not safe admission limits, actual RAM fit or
VRAM. The H-helper phase would overtake the selected SC_SZC count if its
unmodeled witness and relative additional reserves exceeded1,966,419,936B.
Other omitted terms can also change the ordering. Across648 symbolic cases
(216 geometries times workers1/8/16),SC_SZC is the known-payload maximum619
times and H_hash29 times; worker counts8/16 are not executions or profiles.
Unknown witness/model/whole-run boundaries,backend offers/fallback,remaining
helper/DD/accuracy temporaries,Vec capacity excess,NTT caches,pools,pending
free/quarantine,proof/open/serialization,allocator/driver and other-process
reserves prevent any actual-fit result. CPU Store::Host is not VRAM.

Self-review found the initial M_hash accounting included the future Merkle
tree before allocation. Corrected it and added a separate phase-specific
reference; the original code/PASS/logs remain underinitial-m-hash-overcount.
SC_SZC totals and the constructor counterexample did not change. This was
a research accounting error; no production defect is claimed. Prior capacity,
ownership,pool and batching negatives are preserved.

Baseline: serial independent proofs. Eliminated work:zero field operations,
zero fresh masks. Potentially avoid late capacity failure or exposed wait,
both unmeasured. Added costs:public manifests,conservative reserves,possible
reduced concurrency,events,failure isolation and drain. End-to-end ceiling
unknown N/(T-C_exclusive+A), bounded even with free deletion by
N/(T-C_exclusive). Necessary50/s condition T-C_exclusive+A<=N/50.
Falsify on an omitted owner/capacity,lifetime mistake,real peak beyond the
model,or negligible measured critical time. No speed estimate is justified.

Rank1 remains complete independently verified high-end-GPU resident1/2/4/8
workloads with exclusive clocks and capacity; rank2 admitted context/DD/
fidelity scaling; rank3 native phase/capacity evidence. H96 is locally tested
and demoted as a speed lead. New H97 asks whether authenticated public-weight
prefetch can exploit measured dependency slack without greater backing
capacity or shared-bandwidth contention. G10 (new older assessment,2023)
motivates lifetime/bandwidth planning but evaluates a simulator; its>=30GB
artifact is excluded from this lane. No private spill or mask reuse follows.
SAK (new,Sep22,2026) has a sparse lookup/setup architecture requiring a new
relation/PCS/privacy review; dense fresh masking is still owed here.

LIVE primary sources:recent [zkDuel](https://arxiv.org/abs/2610.37710),
[ICICLE releases](https://github.com/ingonyama-zk/icicle/releases),
[SAK](https://eprint.iacr.org/2026/2143),
[G10](https://arxiv.org/abs/2310.09443) and its
[artifact](https://github.com/platformxlab/G10),plus Rust reference,
ZKProphet and known Blackwell locality work. The Blackwell/COBRA leads were
already assessed,not new; native CUDA p1 already fuses its bit-reversed
gather with DIT/padding. Exact publication/update evidence,unknown fields,
blocked URLs,license scope and inspected version-bump commit are retained
in source-records.jsonl. Eight records append to1,087 prior records. No author
performance is reproduced,no foreign implementation is executed or adopted.

{account_text}
{baseline}
Each experiment stage uses one CPU affinity,nice19,30sCPU/40salarm/45s parent,
384MiB address cap; compile estimated300MiB,audit64MiB. Standalone compile
0.872s/159,960KiB; final audit execution0.118s/30,432KiB. Rustc1.75.0,
one codegen unit; compiler helper-thread count unobserved,one affinity enforced.
These are process/correctness clocks,not proof clocks. No dependency/native
build,installation or GPU work ran.

Integration seam:PCS tagged constructor/encode_rows/hash_columns,
zk::mask_commit_tagged andprotocol::prove_core. Research code and precise
interface are in[INTEGRATION.md](INTEGRATION.md); no production patch/merge.
Main agent/Claude owns review/integration. Next local action:pin the current
backend offer/decline and public block streaming ownership/transfer roster;
derive which transfer dependencies actually have overlap slack. Require
native complete-workload measurements before further toy admission variants.

Only research outside runtime written. No production/Git/receipts/calibration/
safety/instructions/reviewer changes,private artifacts,external writes/messages,
purchases,escalation or liveness claim. Saved reports do not establish delivery.

Reproduce in a fresh copy from research directory:
`python3 experiments/constructor-peak-envelope-20261030/run_bounded.py prepare`,
then `compile`,then `audit`. Commands,source and artifact hashes,seed,dimensions,
hardware,raw observations and limitations retained. close.py only writes reports.
'''
(D/'README.md').write_text(report)
(R/'FINDINGS.md').write_bytes(oldfind+f'\n\n## Cycle0164 — {RUN}\n\n'.encode()+report.encode())
short=f'''# ZKP efficiency progress

Cycle0164 COMPLETE — `{RUN}`, checkpoint{now}.

**No measured proving improvement.** Source-derived constructor accounting
passes216 public metadata cases and240 tiny Rust allocation observations;
4,600 checks/249 accounting controls. Frozen T128/H24 H construction has
2.5MiB extra temporary payload; two overlapping H constructors need5MiB
beyond their returned owners. Selected SC_SZC retains224MiB tables and remains
the larger known phase:5.779735GiB single-block CPU partial payload.
Missing witness/backend/whole-run capacities prevent a fit decision.
Constructor-only staggering is a weak lead; no production patch.

{account_text}
Next:owner measures complete verified high-end-GPU resident1/2/4/8 workloads,
exclusive clocks and actual capacity. Local next:public-weight/backend transfer
ownership and dependency slack. New literature leads:SAK and olderG10;
zkDuel,ICICLE,Rust and known Blackwell work refreshed. G10 simulation gains
are not native evidence; no foreign code executed.

[Experiment](experiments/constructor-peak-envelope-20261030/README.md) ·
[Dated report](progress/{RUN}.md) ·
[Handoff](handoffs/20261030-constructor-peak-envelope.md).
Saved reports do not establish message delivery.
'''
(R/'PROGRESS.md').write_text(short);(R/'progress'/f'{RUN}.md').write_text(report.replace('(INTEGRATION.md)','(../experiments/constructor-peak-envelope-20261030/INTEGRATION.md)'))
state=f'''# ZKP efficiency explorer — durable state

Cycle0164 COMPLETE: `{RUN}`.
Started2026-10-30T12:41:23Z;checkpoint{now};deadline13:01:23Z.
Next cycle no earlier than13:41:23Z. Read AGENDA.md EVERY cycle.

**No measured proving improvement.** H96 constructor/capacity study passes
216 public metadata cases/1296 scalar comparisons,24 small Rust resource
skeletons/240 observations,4600 checks/249 accounting controls. Ten native
source pins;22 prior unchanged metadata bodies reused. Native constructors,
hashes,NTT,RNG,prover,privacy gates and GPU not run.

Frozen R13 g79 T128/H24:n16384,A4577/H4390,q256,rate4. Returned H field/digest
payload2892312544B;constructor peak2894933984B:2.5MiB extra powers/leaves.
Two overlapping H constructors need5MiB beyond final-owner-only subtotal.
With pads/salts/trees/M retained,known single-block CPU SC_SZC subtotal is
6205943536B=5.779735GiB (42.261459MiB above previous partial figure).
H tree5.563427GiB;H helpers3.948364GiB plus unmodeled witness.
619/648 symbolic known-payload maxima are SC_SZC,29 H_hash;workers1/8/16 are
metadata models,not executions. CPU Store::Host is not VRAM. All missing
witness/model/whole-run/backend/allocator/pool/quarantine/proof reserves still
prevent actual admission. No actual fit or scheduling-time claim.

Self-review corrected initial M_hash future-tree overcount;original code,
PASS and logs retained. No selected SC_SZC change. Prior allocation,ownership,
pool,event,batching negatives and all96 prior hypotheses preserved.

Rank1:complete independently verified named high-end-GPU resident1/2/4/8
workloads,exclusive phases,startup/drain,actual capacities,all failures.
Rank2:admitted context/DD/fidelity scaling. Rank3:native exclusive phase and
capacity evidence. H96 refined/tested but weak as speed lead. NEW H97:
public-weight prefetch with measured dependency slack,shared bandwidth and
whole-capacity reservations. Baseline serial independent proofs;eliminated
field/mask work0;added reserve/scheduling/transfer costs unmeasured. Ceiling
unknown N/(T-C_exclusive+A);necessary50/s T-C_exclusive+A<=N/50.
Falsify on omitted owner/capacity,wrong lifetime,no actual slack or added
cost exceeding exclusive savings. No more toy cohort variants.

NEXT bounded local experiment if native data absent:pin current Rust/CUDA
backend offer/decline,fallback and authenticated public-block streaming
allocation/transfer roster;identify dependency slack with an independent
public byte/traffic count. No private spill,mask reuse or unapproved P3 cache.
Main agent/Claude reviews/ports;no production patch supplied.

{account_text}
{baseline}
LIVE primary sources:eight records append to1087 prior. New SAK(Sep22,2026)
sparse lookup architecture and olderG10(Oct13,2023) lifetime/migration study.
G10 is simulator evidence;artifact>=30GB excluded. Known COBRA/Blackwell
and ZKProphet refreshed;not rediscovered. ICICLE displayedv4 stillLatest;
inspected6c77775961b0e4dc2be359feec1ac11536c18043 is version bump,not kernel.
License bodies/history cache misses and ePrint403 retained;unknown dates/pins
remain unknown. No author performance reproduced or foreign code executed.
Rotation next:lookup/softmax,NTT/commitments;retain all other queues.

Resource:oneCPUaffinity,nice19,30sCPU/40salarm/45sparent,384MiBAS;
compile0.872s/159960KiB,audit0.118s/30432KiB. Rust1.75.0,onecodegenunit,
compiler helper-thread count unobserved. Process clocks only,no GPU/nativebuild.

[Experiment](experiments/constructor-peak-envelope-20261030/README.md) ·
[Handoff](handoffs/20261030-constructor-peak-envelope.md) ·
[Dated report](progress/{RUN}.md).
Only research outside runtime written. No production/Git/receipts/calibration/
safety/instructions/reviewer/foreign-code/installation/external-write/message/
purchase/escalation/merge or liveness action. Reports do not establish delivery.
'''
(R/'STATE.md').write_text(state)
dump(D/'completion.json',dict(cycle=CYCLE,run_id=RUN,checkpoint_utc=now,status='COMPLETE',target_achieved=False,new_source_records=len(records),prior_source_records=len(prior),full_stack_proofs=0,proved_positions=0))
print(json.dumps(dict(status='REPORTS_WRITTEN',checkpoint=now,new_sources=len(records),checks=result['checks'])))
