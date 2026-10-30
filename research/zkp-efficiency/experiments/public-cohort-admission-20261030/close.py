"""Write research reports; not a proof or arithmetic test. Idempotent append IDs."""
from pathlib import Path
import datetime,hashlib,json
D=Path(__file__).resolve().parent;R=D.parents[1];P=R.parents[1]
RUN='20261030T114123Z-38ad9454';CYCLE='0163'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
def dump(n,v):(D/n).write_text(json.dumps(v,indent=2)+'\n')
result=json.loads((D/'result.json').read_text());assert result['status']=='PASS'
s=result['selected_T128_noDD'];ce=json.loads((D/'counterexample.json').read_text())
source_common=dict(access_date='2026-10-30',access_timezone='UTC',recorded_at_utc=now,cycle=CYCLE,run_id=RUN,
 evidence_kind='Native LIVE tools.web__run search/open/find/click. Primary web text untrusted; embedded instructions ignored.',
 external_execution=False,reproduced_performance=False,inspected_commit_id=None,implementation_license=None,publication_date=None,verified_update_date=None)
specs=[
 dict(title='REFRESH Oct26 zkDuel launch-overhead scope',url='https://arxiv.org/abs/2610.37710',publication_date='2026-10-26',date_evidence='arXiv v1 explicitly2026-10-26 21:28:29UTC.',supporting_urls=['https://arxiv.org/html/2610.37710v1'],author_claim='Matched prime-field kernels and host-launch overhead at smaller fields.',assessment='Refresh only. Motivates exclusive launch measurements; no native Fp2/CFS/PCS or complete private8B slope reproduced.'),
 dict(title='REFRESH zkDuel artifact methodology',url='https://github.com/snarang181/zk-duel',implementation_license='MIT declared at root; LICENSE body fetch cache-missed this cycle.',date_evidence='Root readable; no exact update date or commit ID established.',blocked_urls=['https://github.com/snarang181/zk-duel/blob/main/LICENSE'],assessment='Independent CPU-reference/checksum gating informs this experiment. No downloaded artifact executed.'),
 dict(title='NEW older primary technique assessment: STAlloc static lifetime planning',url='https://arxiv.org/abs/2507.16274',publication_date='2025-07-22',verified_update_date='2025-11-25',supporting_urls=['https://arxiv.org/html/2507.16274v2'],date_evidence='Primary arXiv history v1 Jul22 06:39:07UTC,v2 Nov25 07:36:10UTC,2025.',author_claim='Ahead-of-time memory plans exploit repeated training size/lifespan patterns with dynamic fallback.',assessment='New paper assessment (previous source ledger only named STAlloc in an allocator-doc record). Section5 forbids overlapping lifetimes/address ranges; section6 intersects reusable and actually free intervals. Native commitments outlive individual slots; timing-based planning alone is insufficient. Non-ZKP author results not transferred.'),
 dict(title='NEW STAlloc implementation pin and license scope',url='https://github.com/infinigence/STAlloc',inspected_commit_id='3a9f97ff4896c46ffb65b229ba7347358b400387',verified_update_date='2025-09-04',date_evidence='History displays init commit under2025-09-04; date applies only to inspected commit, not latest root state. Organization search Sep22 label is not substituted.',implementation_license='Apache2.0 declared at root and copyright2025 Infinigence headers inspected in Allocator/Allocator.hpp and BestFitAllocator.hpp diff. Full LICENSE fetch blocked; THIRD_PARTY_NOTICES/THIRD_PARTY_LICENSES listed, not audited.',supporting_urls=['https://github.com/infinigence/STAlloc/commits/main/','https://github.com/infinigence/STAlloc/commit/3a9f97ff4896c46ffb65b229ba7347358b400387'],blocked_urls=['https://github.com/infinigence/STAlloc/blob/main/LICENSE','https://raw.githubusercontent.com/infinigence/STAlloc/main/LICENSE','https://github.com/infinigence/STAlloc/blob/3a9f97ff4896c46ffb65b229ba7347358b400387/LICENSE'],assessment='Inspect-only source headers and best-fit interface. PyTorch allocator is not a drop-in Rust/CUDA private proof scheduler. No code adopted or executed.'),
 dict(title='REFRESH MegaZK compressed memory and verifier caveat',url='https://github.com/THU-HAS/MegaZK',date_evidence='README identifies ICS2026 DOI10.1145/3797905.3807842. Exact paper publication/root update date and commit not established.',implementation_license='Root declares MIT OR Apache2.0; LICENSE,LICENSE-MIT,LICENSE-APACHE and NOTICE fetches cache-missed. Bodies not inspected.',blocked_urls=['https://github.com/THU-HAS/MegaZK/blob/main/LICENSE','https://github.com/THU-HAS/MegaZK/blob/main/NOTICE','https://github.com/THU-HAS/MegaZK/blob/main/LICENSE-MIT','https://github.com/THU-HAS/MegaZK/blob/main/LICENSE-APACHE','https://github.com/THU-HAS/MegaZK/commits/main/','https://github.com/THU-HAS/MegaZK/releases','https://raw.githubusercontent.com/THU-HAS/MegaZK/main/LICENSE','https://github.com/THU-HAS/MegaZK/blob/main/plonky2/plonky2/src/integration/gpu_prover.rs','https://dl.acm.org/doi/10.1145/3797905.3807842'],assessment='README compressed-memory profile and CPU verifier policies inspected; documented Ed25519 known verification failure excludes those receipts from any target. Plonky2 relation differs. No performance or fit reproduced; ACM403 and code/history cache misses retained.'),
 dict(title='REFRESH official CUDA completion and pool ownership semantics',url='https://docs.nvidia.com/cuda/cuda-programming-guide/04-special-topics/stream-ordered-memory-allocation.html',date_evidence='Current official guide readable; exact publication/update date unknown.',assessment='All cross-stream uses must complete before free; pool return need not release backing. Public model counts all recorded last-use events and distinguishes live/idle/free capacity. It models neither actual CUDA pages nor native event failures.'),
 dict(title='Official Rust Vec truncate capacity guarantee',url='https://doc.rust-lang.org/std/vec/struct.Vec.html#method.truncate',date_evidence='Page displays std1.99.1(build58cf8f9c3,2026-10-13). This is a documentation build date, not independently verified publication/update date; local experiment compiler1.75.0.',assessment='truncate/clear preserve allocated capacity. Exact local small Vec observation agrees. Native ClosureRounds and GroupedEqRounds use truncate; tail lengths alone cannot admit a new proof.'),
 dict(title='REFRESH observed recent gnarkv0.16.4 release',url='https://github.com/Consensys-Incorporated/gnark/releases/tag/v0.16.4',inspected_commit_id='e974abb44722dd201a7f1949baeabca0fef5866e',date_evidence='Rendered release07Oct10:17 omits year in this refresh; prior cycle date evidence retained separately. Full release-bump commit inspected, not GKR implementation.',supporting_urls=['https://github.com/Consensys-Incorporated/gnark/commit/e974abb44722dd201a7f1949baeabca0fef5866e'],assessment='Public GKR/WebGPU release metadata does not establish native separate-proof Fp2 batch capacity or privacy. No dependency adopted; current cycle license body not inspected.')
]
old_records=[json.loads(l) for l in (R/'sources.jsonl').read_text().splitlines() if l.strip()]
sources=[]
for i,spec in enumerate(specs,1):
 rec={**source_common,**spec,'id':f'cycle{CYCLE}-source-{i}'}
 rec['prior_exact_url_records']=sum(x.get('url')==rec['url'] for x in old_records)
 sources.append(rec)
source_text=''.join(json.dumps(x,sort_keys=True)+'\n' for x in sources)
(D/'source-records.jsonl').write_text(source_text)
old_ids={x.get('id') for x in old_records}
with (R/'sources.jsonl').open('a') as f:
 for x in sources:
  if x['id'] not in old_ids:f.write(json.dumps(x,sort_keys=True)+'\n')
dump('search-log.json',dict(method='Native LIVE tools.web__run',queries=[
 'GPU zero knowledge sumcheck memory batching prover October 2026 repository',
 'memory admission GPU asynchronous buffer lifetime cudaMallocAsync stream ordered allocator',
 'MegaZK memory efficient GPU system June 2026 ICS Li Yu memory allocator',
 'site:github.com GPU sumcheck October 2026 release memory',
 '"MegaZK" "2026" "June"','"STAlloc" github'],
 raw_responses='web-1.json through web-11.json; initial search response remains in tool conversation',
 rule='Search snippets are discovery only; primary pages inspected. No downloaded scripts executed.'))
ledger=json.loads((D/'hypotheses.json').read_text())
for h in ledger:
 if h.get('rank')==95:
  h.update(title='TESTED public capacity admission for separate-proof cohorts; no throughput gain established',
   baseline='Sequential separate proofs; frozen R13 slot uses full allocated Vec capacity until drop. A/H/M and endpoints remain live for later openings.',
   eliminated_work='No field operations or fresh masking removed. Hypothetical launch/dispatch/idle-barrier work only; this experiment prevents unsafe admission.',
   added_costs='Distinct live commitments/witnesses,table capacity,events,generation tokens,public reserves,ready routing,failure isolation and pipeline drain.',
   exactness=f"216 metadata cases/2160 comparisons;20 small Vec probes;9+150 admission boundary cases;{result['checks']} assertions/{result['negative_controls']} controls. Not native define/prover/cryptographic equivalence.",
   compatibility='22 unchanged R13 metadata bodies plus source-screened Legacy/LowH24 SC_SZC tables; no native GPU path port. CPU-encoded subtotal cannot be assigned to VRAM.',
   privacy_soundness='Public geometry only, fresh storage contents per job. Owner/generation labels are trusted-driver checks,not authentication. All downstream consumers and actual device completion need owner evidence; no mask reuse,privacy theorem or changed profile.',
   end_to_end_ceiling='Unknown N/(T-C_dispatch_critical+A_admit); necessary50/s condition T-C_dispatch_critical+A_admit<=N/50. No measured exclusive native phase fraction.',
   falsification='False admission from logical lengths,missing live PCS owners,unknown reserve,early/stale completion,wrong generation,actual capacity cliff or added costs exceeding measured exclusive launch benefit.',
   disposition='Park scheduler/native performance promotion pending complete phase/capacity evidence. Partial payload and synthetic event prerequisite only.')
ledger.append(dict(rank=96,title='NEW reserve whole proof-lifecycle peaks before starting independent resident work',
 baseline='The tested gate reserves only a known single-slot payload. Real witnesses,commit construction scratch,pads/salts/trees,public model,NTT tables,pools and pending frees are absent.',
 eliminated_work='Potentially avoid wasted witness/commit work from late capacity refusal; no field work removed for successful proofs.',
 added_costs='Public phase envelopes,conservative reserved capacity and reduced concurrency; staging or reencoding would add transfers/compute and separate ownership review.',
 prerequisites='Pin current owner source,public admitted geometry and actual allocation/completion evidence. Keep host/device ledgers separate. Native whole-proof clocks first.',
 integration_cost='Research source-derived lifecycle envelope first; native admission/counters owned by main agent under shared locks.',
 exactness='Not tested this cycle. Next bounded source-count test compares serial vs staggered two-proof public phase envelopes with simultaneous construction/quarantine controls; no invented timing schedule.',
 privacy_soundness='No private data-dependent public admission/refusal disclosure,mask reuse,opening reuse or weaker coverage; public worst-case reservations only.',
 compatibility='prove_core commitment constructors and SumcheckRounds boundary; must repin newer R14 separately; it is a different3B scope.',
 end_to_end_ceiling='Unknown; capacity validity is prerequisite,not a50/s prediction.',
 falsification='Envelope omits an owner/transient/pool or actual peak exceeds it; all capacity fits serially and there is no measured exclusive scheduler benefit.',
 disposition='Next local source/cost screen only if no native exclusive capacity/phase evidence arrives; do not repeat toy round batches.'))
dump('hypotheses.json',ledger)
dump('ranking-current.json',dict(owner_priorities=[
 dict(rank=1,title='Independently verified complete high-end-GPU fixed-context resident1/2/4/8 workloads',expected_impact='Highest: measure recurring full prover cost and startup amortization.',prerequisites='Actual admitted8B path/device,source/profile/calibration pins,all proofs independently verified; fresh masks.',integration_cost='Native owner heavy/GPU locks; not launched here.'),
 dict(rank=2,title='Admitted context/DD/fidelity scaling',expected_impact='Potential attention/commitment reduction; larger context may increaseT-squared work.',prerequisites='Exact relation and refusal/calibration review,full-stack receipts,peak capacity.',integration_cost='Owner profile/security validation; no new profile admitted.'),
 dict(rank=3,title='Exclusive phase and capacity evidence',expected_impact='Resolve whether launch,transfer,commitment or witness dominates.',prerequisites='Complete source/call roster,actual live+idle+quarantined bytes,nested-clock reconciliation.',integration_cost='Small owner observer plus controlled full workloads; no instrumentation applied.')],tested_local_hypothesis=95,next_local_hypothesis=96))
dump('rotation-queue.json',dict(current=['memory traffic','batching/amortization','sumcheck/GKR'],next=['lookup arguments and softmax','GPU NTT/commitments'],retained=['quantization/arithmetic','proof composition'],note='Rotate by actual measured bottlenecks; no paper-list-only cycle.'))
accounting=dict(run_id=RUN,new_full_stack_proofs=0,new_passes=0,new_positions=0,actual_context=None,
 metadata_contexts=[17,32,64,127,128,256,512],synthetic_vec_variables=[3,6,9,12],synthetic_vec_entries=[8,64,512,4096],
 device='One CPU affinity on Intel Core Ultra 9 185H; no GPU',gpu_count=0,
 witness_s=None,proof_s=None,serialization_s=None,verification_s=None,startup_s=None,initial_prefill_s=None,
 startup_fraction=None,steady_interval_s=None,total_workload_s=None,steady_state_proved_tokens_s=None,
 total_workload_proved_tokens_s=None,proof_latency_s=None,proof_bytes=None,workload_kinds_run=[],
 prefill_run=False,resident_model_passes=0,decode_run=False,target_achieved=False,
 exclusion='All metadata,Vec and capacity models excluded from proved-token numerator.',
 ceiling='Unknown N/(T-C_dispatch_critical+A_admit); capacity accounting alone saves no proof work.')
dump('target-accounting.json',accounting)
completion=dict(cycle=CYCLE,run_id=RUN,status='COMPLETE',started_at_utc='2026-10-30T11:41:23Z',checkpoint_utc=now,deadline_utc='2026-10-30T12:01:23Z',next_cycle_not_before_utc='2026-10-30T12:41:23Z',result='No measured proving improvement; public admission prerequisite and false-fit negative.',full_stack_proofs=0,passes=0,positions=0)
dump('completion.json',completion)
scope='''New independently verified full-stack proofs / complete-model passes / proved positions: **0 / 0 / 0**.
Actual model context: **none**. Device: one CPU affinity on Intel Core Ultra 9
185H, no GPU. Witness / proof / serialization / verification / startup /
initial-prefill clocks, startup fraction, proof latency/bytes, steady-state and
total-workload proved-token rates: **unmeasured**. No long-context prefill,
resident-model proof passes or decode ran. Metadata contexts17/32/64/127/128/
256/512 and synthetic cohort counts1/2/4 are not model runs or proved passes.
Larger workloads remain allowed; increased context can increase attention
quadratically. Complete private8B **>=50 proved tokens/s remains unachieved**.
No masks, pads, openings or private values reused for amortization.
'''
short=f'''# ZKP efficiency progress

Cycle0163 COMPLETE — `{RUN}`, checkpoint {now}.

**No measured proving improvement.** A public capacity gate passes216 source
metadata cases,20 small Rust Vec probes,159 admission boundaries and55 controls.
Frozen R13 H24 T128 SC_SZC has28 tables /224MiB payload per proof. Counting
half-length tables as released capacity wrongly admits a second proof and
undercounts112MiB in the synthetic counterexample. Correct admission retains
capacity through every last-use event and keeps commitments until openings.

{scope}
Next: native owner measures complete verified fixed-context resident1/2/4/8
workloads, exclusive phase clocks and actual host/device capacity. Local next
screen reserves whole proof-construction peaks before admission; unknown
components currently prevent any actual-fit conclusion. Further toy batches
are parked. LIVE sources: zkDuel, STAlloc, MegaZK, CUDA/Rust docs and gnark.

[Experiment](experiments/public-cohort-admission-20261030/README.md) ·
[Dated report](progress/{RUN}.md).
Saved reports do not establish user-message delivery.
'''
report=f'''# Cycle0163 — public cohort capacity admission

Run `{RUN}`; started2026-10-30T11:41:23Z; checkpoint{now}.

**No measured proving improvement.** The most useful local question was:
can independent ready-round cohorts be admitted safely while other commitment
owners remain live? The answer is conditional on complete capacity reserves;
round lengths alone give an unsafe admission decision.

The authored independent Python row-count oracle matches22 unchanged native
metadata bodies in216 Legacy/LowH24 and DD/nonDD public cases (2,160 numeric
comparisons). Native constructors, define, prover, transcript, PCS arithmetic,
privacy gates and GPU were not executed. The SC_SZC table inventory is a
source-screened use of private-site counts plus three equality tables, causal
mask and applicable supports, checked in both argument files; native define
was not run.20 small Rust Vec probes produce190 length/capacity observations;
truncate and clear preserve original capacity. Initial Python DD oracle omitted
the dictionary TABLE helper; native mismatch caught it. The failed reference
and corrected pass are retained; this was an experiment-oracle error, not a
production defect. Earlier allocation/pool/lifetime negatives remain binding.

The R13 H24 T128 metadata agrees with prior A4577/H4390 row counts. Its
SC_SZC cube has2^19 entries and28 Fp2 tables:224MiB per proof. All shapes
are metadata-only; no calibration/profile admission or actual workload is
inferred. In a SINGLE BLOCK with two endpoint owners, the following partial
requested-payload counts apply:

| Simultaneous proof jobs | A/H/endpoint systematic data + round tables | Plus complete CPU encoding payloads (including M encoding) |
|---:|---:|---:|
|1|1.322388GiB|5.738464GiB|
|2|2.644775GiB|11.476929GiB|
|4|5.289551GiB|22.953857GiB|

These columns are lower bounds/subtotals, **not actual fit, RSS or VRAM**.
The latter uses CPU Store::Host semantics and must never be assigned to GPU
residency. Excluded: public/resident model and other blocks, witnesses,
constructor/encode/open scratch, pads, salts, trees, remaining M/CFS buffers,
proof/serialization output, NTT caches, pools/oversizing, allocator/driver,
reserved quarantine and other processes. A whole32-block run has additional
boundary owners and lifecycle peaks. Missing measured/public reserves make
actual admission indeterminate, including on an RTX5090.

The symbolic gate and an independent offline allocation replay pass9 exact
cohort budget boundaries plus150 seeded randomized boundaries:4,560 assertions,
55 negative controls,10 retained traces. Controls cover premature retirement,
two outstanding stream-event tokens, stale owner/generation, invalid completion,
live-buffer free, duplicate proof owner, unknown reserve, corrupted capacity
and missing completion. After a slot finishes, table storage returns to an
idle pool without releasing capacity; a later proof may reuse that storage
only with a new generation. Its commitments are distinct and stay live until
the trusted driver certifies all downstream opening uses. Labels and events
are consistency checks, not authenticated completion or privacy proofs.

The decisive negative has background4,096B, known partial persistent payload
{ce['persistent_payload']:,}B per proof and table capacity{ce['table_capacity']:,}B.
After one fold, the naïve length ledger admits proof2 at
{ce['naive_second_admission_total']:,}B. Actual modeled allocated capacity would
be{ce['actual_second_admission_total']:,}B:112MiB over its synthetic budget.
The correct gate refuses until completion/retirement permits safe reuse.
No actual large buffers were allocated for these projected values.

Baseline: sequential separate proofs, one admitted job. Eliminated work:
**zero field operations, zero fresh masking**; potentially amortizable native
launch/dispatch/idle barriers remain unmeasured. Added costs: simultaneous
PCS/witness state, routing, events, generations, reserves, failure isolation
and drain. End-to-end ceiling remains unknown N/(T-C_dispatch_critical+A_admit);
even free dispatch deletion is bounded by N/(T-C_dispatch_critical). A necessary
50/s condition is T-C_dispatch_critical+A_admit<=N/50. Falsify on any source/field/
transcript difference, incomplete owner/reserve, stale completion, actual
capacity cliff, or added cost exceeding exclusive launch savings.

Rank1 remains independently verified high-end-GPU fixed-context resident1/2/4/8
workloads. Rank2: admitted context/DD/fidelity scaling. Rank3: exclusive native
phase/capacity evidence. Local hypothesis95 is refined/tested; new96 asks for
whole-lifecycle reservation BEFORE witness/commit construction. If native data
remains absent, next local screen counts two-proof public phase envelopes with
simultaneous commit scratch, pooled idle and pending-release controls; it must
not invent timing or claim actual fit. Do not repeat toy batching variants.

Integration seam: frozen R13 `SumcheckRounds`, called from
`zk.rs::masked_prove_rounds` and `private_block/argument.rs::run_slot`.
Admission surrounds table construction and requires lifetime evidence from
`protocol.rs::prove_core` and each backend's allocation/completion API. Both
ClosureRounds and GroupedEqRounds truncate without shrinking. The owner
reviews and ports; no production patch or merge is supplied.

LIVE primary literature/repositories refreshed zkDuel (Oct26), MegaZK, gnark
v0.16.4 and CUDA/Rust docs. Newly assessed older STAlloc (v1Jul22/v2Nov25,2025)
requires non-overlapping address/lifetime intervals and actually free space;
its training results are not native proof evidence. Inspected implementation
commit3a9f97ff4896c46ffb65b229ba7347358b400387 has Apache2 headers; full license
body blocked and third-party notices unaudited. gnark release pin
e974abb44722dd201a7f1949baeabca0fef5866e is a release bump, not a tested GKR port.
Eight source records append to1,079 prior records. Exact/unknown dates, license
scope, pins, ACM403 and cache-miss URLs are in source-records.jsonl. No author
performance reproduced or downloaded code executed.

{scope}
Carried historical CPU8B baseline, not rerun/reverified/newly counted: T128/L32,
one16-thread GPU-off pass; total478.737s=0.267370positions/s. prove_run393.785s
includes witness98.348s/load17.595s. Preceding sealing84.824s contains overlapping
load27.151s/witness80.897s; never sum nested clocks. Receipt922,711,264B;
verify42.709s plus13.681s load. Startup fraction, serialization and steady slope
unknown. Current R18 classifier3B batch1418s vs singles1453s is a different
scope and is not private8B/high-end-GPU evidence; none counted here.

Each experiment stage: CPU affinity1,nice19,30s CPU/40s alarm/45s parent timeout,
384MiB address cap; audit estimate64MiB,compile300MiB. Final standalone Rust
compile1.278s/158,376KiB; audit0.171s/18,228KiB. Correctness execution clocks,
not proof clocks. Rustc1.75.0,one codegen unit; compiler helper-thread count
unobserved; one CPU affinity enforced. No dependency/native build or GPU run.
Commands,seed20261030163,input/source/artifact hashes and raw logs retained.

Only research outside runtime written. Production/Git/receipts/calibration/
safety/instructions/reviewer files untouched. No installation,foreign-code
execution,external write/message,purchase,escalation,merge or liveness claim.
Native owner/Claude reviews any integration. Reports do not establish delivery.
'''
(D/'README.md').write_text(report+'''
Reproduce sequentially from the research directory (prepare resets the local
hypothesis copy; use a fresh copy to preserve finalized reports):

```text
python3 experiments/public-cohort-admission-20261030/run_bounded.py prepare
python3 experiments/public-cohort-admission-20261030/run_bounded.py compile
python3 experiments/public-cohort-admission-20261030/run_bounded.py audit
```
`close.py` writes reports, not tests. See INTEGRATION.md for the interface.
''')
(D/'INTEGRATION.md').write_text('''# Research admission interface — not a production patch

`admission.py::Arena.admit(owner,persistent,round_bytes)` reserves requested
capacity atomically or refuses. Required descriptor adds public profile/source
pins,backend/device,site,round,generation,known reserve and live owner handles.
`use/complete` represents every backend last use; `finish_slot/retire` makes a
table idle only after completion; idle bytes still count. Reassignment increments
generation and never preserves private contents. `open_complete` requires the
trusted driver to certify all later consumers; this one-slot model cannot
derive that fact. Unknown reserve refuses even if toy payload fits.

Actual seam: R13 `argument.rs::build_tables_at/run_slot`, `zk.rs::masked_prove_rounds`,
`SumcheckRounds::{round,fold,finals}`. Both evaluators truncate without shrinking.
`protocol.rs::prove_core` retains A/H/M through all slots, opens M/A/H, then
drops each. Endpoint and later-block lifetimes need the run/boundary owner.
Legacy GPU zerocheck functions are not the actual inspected R13 slot route.

Patch/prototype location: admission.py and probe.rs/metadata.rs in this directory.
Validation: result.json,events.json,counterexample.json and reference.py;
216 metadata cases/2160 numbers,20 small Vec probes,159 budget boundaries,
55 controls. Single-author independently expressed oracle, not external review.
No field/transcript/PCS/GPU test or native merge. Native pins in native-pins.json.

Do not turn CPU encoding payload into a VRAM estimate. Need actual independent
host/device counters for all live/idle/quarantined allocations,PCS/witness and
constructor/open peaks,model and pools. Need actual backend failure/completion
semantics and source/profile/calibration/security/privacy review. Tokens count
only after complete-stack independent verification; fresh masks/pads/openings
remain mandatory. Preserve every per-proof original transcript and refusal.

Owner-first experiment: fixed admitted context, resident1/2/4/8 passes, named
high-end GPU,source/build pins,public setup versus per-proof fresh work,exclusive
witness/proof/serialization clocks,separate verification,startup/drain,actual
capacity,all attempts. Use existing shared heavy/GPU locks. No native promotion
until measured exclusive dispatch savings exceed added costs. Ceiling unknown
N/(T-C_dispatch_critical+A_admit); no native batch or fit claim follows here.
''')
(R/'PROGRESS.md').write_text(short)
(R/'progress'/f'{RUN}.md').write_text(report)
findings=R/'FINDINGS.md';old=findings.read_text()
if f'## Cycle0163 — {RUN}' not in old:
 with findings.open('a') as f:f.write(f'\n\n## Cycle0163 — {RUN}\n\n'+report.split('\n\n',2)[2])
handoff=R/'handoffs'/'20261030-public-cohort-admission.md'
handoff.write_text(f'''# Public cohort admission prerequisite — cycle0163

No measured proving improvement or actual fit. The tested gate prevents
112MiB of undercount in a two-proof synthetic case using R13 H24 T128 metadata;
224MiB table capacity does not halve when logical table length halves.
Commitment owners outlive individual slots and completed idle tables still
consume capacity. This strengthens a scheduler safety prerequisite only.

[Interface and obligations](../experiments/public-cohort-admission-20261030/INTEGRATION.md) ·
[Evidence](../experiments/public-cohort-admission-20261030/result.json) ·
[Report](../progress/{RUN}.md).

Prototype: `admission.py::Arena`,source probe `probe.rs/metadata.rs`.
Native owner reviews at SumcheckRounds/build_tables_at and prove_core/backend
lifetimes. All completion handles,reserves and downstream owner certificates
are trusted-model inputs; current source is not instrumented and no patch is
merged. GPU placement,whole-model capacity,exclusive timings,byte/refusal/
transcript equivalence and privacy/soundness remain unresolved. No fresh masks
or openings reused. Next local hypothesis96 counts whole lifecycle construction
peaks; owner complete verified high-end-GPU resident workloads take priority.
''')
(R/'STATE.md').write_text(f'''# ZKP efficiency explorer — durable state

Cycle0163 COMPLETE: `{RUN}`.
Started2026-10-30T11:41:23Z;checkpoint{now};deadline12:01:23Z.
Next cycle no earlier than12:41:23Z. Read AGENDA.md EVERY cycle.

**No measured proving improvement.** Tested public cohort admission with
216 metadata cases/2160 numbers,20 small Rust Vec probes,159 budget boundaries,
4560 assertions/55 controls.22 native metadata bodies copied unchanged;
SC_SZC inventory source-screened in Legacy/LowH24 argument files,not executed
native define. Both evaluators truncate without shrinking; A/H/M retain data
through all slots and open/drop afterward. Initial independent Python DD oracle
omitted a TABLE helper; native row mismatch caught it,corrected,failed evidence
retained. Prior allocation,pool,lifetime and batching negatives preserved.

R13 H24 T128 metadata:A4577/H4390,SC_SZC28 Fp2 tables at2^19 entries=224MiB
per proof. Single-block systematic commitment-data+table lower bounds for
cohorts1/2/4:1.322388/2.644775/5.289551GiB. Adding CPU Store::Host encoding
payloads gives5.738464/11.476929/22.953857GiB. These exclude witnesses,model,
other blocks,boundaries,constructor/open scratch,pads,salts,trees,remaining
M/CFS,proof/serialization,NTT,pools/oversizing/allocator/driver and quarantine.
They do NOT establish CPU or GPU fit; CPU encoded storage is not VRAM.

Synthetic two-proof counterexample: counting half-length arrays as freed
undercounts112MiB and falsely admits proof2. Correct gate retains capacity
until every recorded last-use event completes; idle pool capacity still counts
and reuse increments generation. Commitments remain until trusted downstream
opening completion. Unknown reserve refuses. Trusted tags/events are not
authentication; no cryptographic,privacy or native-error result established.

Baseline: serial separate proofs. Eliminated work:0 field operations/0 fresh
masking; potential dispatch/launch/barrier savings unmeasured. Added:distinct
live PCS/witness/table sets,routing,events,reserves,failure isolation,drain.
Ceiling unknown N/(T-C_dispatch_critical+A_admit); necessary50/s condition
T-C_dispatch_critical+A_admit<=N/50. Falsify on omitted owners/reserves,
length-vs-capacity error,early/stale completion or added costs exceeding
measured exclusive savings. Native integration is owner review only.

Rank1:complete independently verified high-end-GPU fixed-context resident
1/2/4/8 workloads,exclusive phases,startup/drain,actual capacity,all failures.
Rank2:admitted context/DD/fidelity scaling. Rank3:exclusive phase/capacity
evidence. H95 tested/refined; NEW H96 reserves whole lifecycle peaks before
witness/commit construction. No further toy batch variants. If native data
remains absent,next bounded local screen pins constructor scratch and compares
two-proof public phase envelopes with simultaneous commit/quarantine controls;
no invented schedule timings or actual-fit claim. Prior95 hypotheses retained.

{scope}
Historical CPU8B baseline carried,not rerun/reverified/counted:T128/L32,
one16-thread CPU pass,GPUoff,total478.737s=0.267370positions/s. prove_run
393.785s includes witness98.348/load17.595s. Sealing84.824s overlaps
load27.151/witness80.897s. Receipt922711264B;verify42.709+13.681s load.
Startup fraction,serialization,steady slope unknown;do not sum nested clocks.
R18 classifier3B batch/singles1418/1453s is a different scope,not8B/GPU evidence.

LIVE sources:zkDuelOct26,MegaZK,gnarkrelease,CUDA/Rust docs;newly assessed
older STAlloc2025 primary paper(v2Nov25),implementation commit
3a9f97ff4896c46ffb65b229ba7347358b400387. Apache2 headers inspected,full
license body blocked/third-party notices unaudited. Eight records append to
1079 prior sources;unknown dates/license/pins and exact403/cache misses kept.
No author performance reproduced. Rotation next:lookup/softmax,NTT/commitments;
retain memory/batching,sumcheck/GKR,quantization/arithmetic,composition.

Resource:oneCPU affinity,nice19,30sCPU/40salarm/45sparent,384MiB AS;
compile estimate300MiB,audit64MiB. Rustc1.75.0;one codegen unit,compiler helper
thread count unobserved. Finalcompile1.278s/158376KiB;audit0.171s/18228KiB.
Correctness process clocks only;no native/dependency build or GPU.

[Experiment](experiments/public-cohort-admission-20261030/README.md) ·
[Handoff](handoffs/20261030-public-cohort-admission.md) ·
[Dated report](progress/{RUN}.md).
Only research outside runtime written. No production/Git/receipts/calibration/
safety/instructions/reviewer edits,installs,foreign-code execution,external
write/message,purchase,escalation,merge or liveness claim. Saved reports do
not establish delivery. Main agent/Claude reviews any integration.
''')
dump('owner-document-recheck.json',[dict(path=x['path'],sha256_at_start=x['sha256'],sha256_now=hashlib.sha256(Path(x['path']).read_bytes()).hexdigest()) for x in json.loads((D/'startup-manifest.json').read_text()) if not x['path'].startswith(str(R))])
print(json.dumps(dict(status='CHECKPOINTED',cycle=CYCLE,checkpoint_utc=now,new_sources=len(sources),hypotheses=len(ledger))))
