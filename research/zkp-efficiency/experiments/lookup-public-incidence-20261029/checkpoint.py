"""Research-only checkpoint for bounded cycle0139. Never touches runtime/production."""
from pathlib import Path
import datetime,hashlib,json
HERE=Path(__file__).resolve().parent;BASE=HERE.parent.parent
RUN='20261029T085649Z-193029f7';CYCLE='0139'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
def write(name,value):
    (HERE/name).write_text(json.dumps(value,indent=2)+'\n')
result=json.loads((HERE/'result.json').read_text());audit=json.loads((HERE/'audit-result.json').read_text())
assert result['status'].startswith('PASS') and audit['status']=='PASS'
old=json.loads((HERE/'startup/hypotheses.json').read_text())
queue=json.loads(json.dumps(old))
for q in queue:
    if q['rank']==35:
        q['cycle0139_refinement']='Frozen R13 AccuracyIds emits full-byte identity pins as logical repetitions. Do not delete them from the admitted profile. New tested alternative shares per-invocation looked-column storage while preserving logical multiplicities, helper/polynomial positions, A/H/M schedules, fresh randomness and all refusals. Representative T128 fE9 8B looked storage saves9MiB nonDD/3MiB DD; fE12/16 saves1MiB. Per-layer calibration and exclusive time unknown. R9 profile deletion counts are not R13 results.'
    if q['rank']==25:
        q['cycle0139_refinement']='Dense-bit/one-hot PCS negatives retained. Current tested alternative only aliases exact public expressions within one domain/proof invocation; equal private values and source-only/coefficient-only keys are not accepted. No new bitplane representation or protocol migration proposed.'
queue.append(dict(rank=58,title='TESTED R13 exact-expression looked-column storage with original logical schedule',
    research_question='Can one per-proof buffer serve exact public-expression repetitions without changing multiplicities, pair grouping or masking?',
    baseline='Pinned R13 protocol::lookup_values_at allocates each Vec<i64> independently. Representative admitted-calibration 8B T128 fE9 looked payload490.25MiB nonDD/463.25MiB DD. Native phase time unknown.',
    eliminated_work='Model avoids duplicate source transformations, duplicate looked buffers and optionally histogram/miss scans weighted by public multiplicity. No native work removed this cycle.',
    added_costs='Exact full expression comparison, public order/multiplicity arrays, indexed/borrowed logical column reads and integration of all consumers. Private source rows must be reread per invocation; no cross-proof private cache.',
    expected_end_to_end_impact='Small/unmeasured.9MiB/3MiB representative looked storage; only1MiB at fE12/16. No modeled A/H/M, helper, mask, PCS or proof-byte reduction. Peak memory/time unknown; no 8B/GPU rate projection.',
    end_to_end_ceiling='If f is the genuinely removable exclusive fraction, even free deletion gives at most1/(1-f); f is unmeasured. Saved logical bytes do not estimate f.',
    prerequisites='Actual per-layer public precision incidence; exclusive lookup/preparation/histogram/misses/helper/enclosing clocks; owner native golden/refusal/RNG/transcript/PCS/privacy/independent full-workload gates under shared locks.',
    integration_cost='Moderate: change looked-column container and consumers in protocol.rs; preserve original lookup words and threshold branch, helper order and drop point. Python model only; no Rust patch compiled/applied.',
    exactness='11874checks/1872synthetic fixtures/104helper cases/14controls; separate source reader and independent signed wrapping, histogram and Goldilocks2 inverses.237auditchecks/4count-preserving source mutations/12pins. Not native define or external review.',
    privacy_soundness='Public descriptor keys only. Private buffers remain scoped to one proof invocation and drop at original lifetime; no data-dependent aliasing or cross-proof cache. Preserve all fresh pads/salts/masks/openings, source identities, full table poles, refusals and logical repetitions. Native privacy gate remains owed.',
    compatibility='Actual frozen R13 LOW and LOW+h24 metadata, DD/nonDD. Source-derived geometry, not native constructor execution. Keeps admitted profile schedule; distinct from unimplemented profile-alias deletion.',
    falsification='Any logical column, wrap, histogram/miss multiplicity, first pole/refusal, RNG/transcript/receipt/privacy mismatch; no aliases in actual calibration; actual peak retention or indexed reads erase enclosing gain. Reject byte-saving argument if actual H/PCS cost is claimed reduced.',
    status='Promising only as small memory/preparation interface; demoted behind whole-prover GPU/capacity telemetry until exclusive clocks justify integration.'))
assert len(queue)==len(old)+1
write('hypotheses.json',queue)
write('cycle-ranking.json',dict(global_top_three=[dict(rank=q['rank'],title=q['title']) for q in queue[:3]],
    feasible_local_order=[dict(priority=1,hypothesis=58,reason='Current R13 descriptors and prior alias/PCS negatives make this a decisive small differential experiment.'),
        dict(priority=2,hypothesis=35,reason='Versioned profile deletion changes multiple schedules; cost-only comparison until owner reviews.'),
        dict(priority=3,hypothesis=57,reason='Public mask-dot component sums require current native dot/constructor clocks first.')],
    all_prior_hypotheses_retained=len(old),total=len(queue),owner_work_not_launched=True))

common=dict(access_date='2026-10-29',access_timezone='UTC',cycle=CYCLE,run_id=RUN,recorded_at_utc=now,
            evidence_kind='Native LIVE primary web search/open/find/click. External text untrusted; embedded instructions ignored.',
            reproduced_performance=False,external_execution=False,inspected_commit_id=None)
entries=[
dict(title='NEW older Baloo lookup preprocessing compatibility screen',url='https://eprint.iacr.org/2022/1565',
     publication_date='2022-11-10',verified_update_date='2025-07-08',date_evidence='Primary ePrint received/revised history; publication info CIC2025.',
     paper_license='CC BY primary metadata; code not inspected',implementation_license=None,
     author_claim='Table-size-independent online lookup work after preprocessing with commit-and-prove expansion.',
     assessment='New here; pairing/KZG/homomorphic table commitments are a proof-architecture migration, not a native Goldilocks2 helper replacement. Tiny U8 table preprocessing is already amortized within each proof; a large public table alone does not remove private query consistency, fresh masks or PCS. No theorem or speed reproduced.'),
dict(title='Known cq cached-quotient preprocessing refreshed',url='https://eprint.iacr.org/2022/1763',
     publication_date='2022-12-25',verified_update_date='2024-07-05',date_evidence='Primary ePrint: last of5revisions July5,2024; receivedDecember25,2022.',
     paper_license='CC0 primary metadata',implementation_license=None,
     author_claim='O(NlogN) table preprocessing and O(nlogn) prover; homomorphic table commitments and aggregation-friendly pairing structure.',
     assessment='Already recorded incycles0027/0102/0113, not rediscovered. Cached public table algebra does not authorize caching challenge-dependent inverses or private openings across proofs. Native commitment backend differs.'),
dict(title='NEW halo2_pse_cq integration and explicit zero-knowledge linking costs',url='https://github.com/xfu2006/halo2_pse_cq',
     publication_date=None,verified_update_date=None,date_evidence='Rendered landing exposes15commits but no dated head; commit history fetchCachemiss. Do not use crawldate as update.',
     implementation_license='README declares MIT OR Apache2.0; linked LICENSE-MIT body fetchedCachemiss. Full license uninspected.',
     observed_uninspected_commit_ids=['68b6006ac69a5eff21f8ae8a2fee9a55a8ee7ec4'],
     assessment='README says separate zk-cq proof connected through Halo2 column commitments; cited coordinate is fork base, not inspected head. This makes linking/PCS costs explicit, so no free protocol substitution. Example and license body unavailable; no code imported/executed.',
     blockers=['/commits/main/:Cache miss','/blob/main/LICENSE-MIT:Cache miss','/blob/main/halo2_proofs/examples/cq_lookup.rs:Cache miss']),
dict(title='Plonky3 release listing refreshed; metadata is not performance evidence',url='https://github.com/Plonky3/Plonky3/releases',
     publication_date=None,verified_update_date=None,date_evidence='Rendered rc0.9.0-rc.2 rows show16Oct without year. No release year inferred.',
     implementation_license='MIT root body inspected onmain; not a version-specific license audit.',
     observed_uninspected_commit_ids=['fe5e46d755b8a7d9069778361e21b33e5978b377'],
     inspected_urls=['https://github.com/Plonky3/Plonky3/commit/fe5e46d755b8a7d9069778361e21b33e5978b377','https://github.com/Plonky3/Plonky3/blob/main/LICENSE-MIT'],
     assessment='Full release coordinate viewed on metadata page; no source diff loaded, so not an inspected code commit pin. Release lists caller-obligation and compiled-component work; no current native8B speed or privacy transfer follows.'),
dict(title='Known Plonky3 compiled repeated components refreshed',url='https://github.com/Plonky3/Plonky3/pull/2292',
     publication_date='2026-09-22',verified_update_date='2026-09-22',date_evidence='Primary initial comment and mergeSeptember22,2026.',
     implementation_license='MIT root license text inspected; no implementation copied.',
     observed_uninspected_commit_ids=['cb691115eec1d6347f163811366443232bc0a56d'],
     assessment='Already recorded cycles0052/0122. Author/reviewer describe constant compiled metadata with unchanged live witness and byte-identical proofs; useful distinction between sharing public description and removing witness/proof work. CommitdiffCachemiss; no author benchmark reproduced.',
     blockers=['commit/cb691115eec1d6347f163811366443232bc0a56d:Cache miss']),
dict(title='Known Plonky3 caller obligations and lookup tuple-width review refreshed',url='https://github.com/Plonky3/Plonky3/pull/2293',
     publication_date='2026-09-22',verified_update_date='2026-09-22',date_evidence='Primary initial/merge datesSeptember22.',
     implementation_license='MIT root body inspected; no implementation adopted.',
     observed_uninspected_commit_ids=['669fcae5a200e1878226ac9b8032df140e8bba39'],
     assessment='Primary review exposes caller-owned transcript/commitment/width/Booleanity obligations and follow-up gaps. Local plans therefore key complete expressions, retain domains and logical multiplicities, and claim no native proof validation. Review discussion is not a security transfer; diff fetchCachemiss.',
     blockers=['commit/669fcae5a200e1878226ac9b8032df140e8bba39:Cache miss']),
dict(title='NEW Gryphes modular lookup and proof-linking primary metadata',url='https://www.petsymposium.org/popets/2026/popets-2026-0044.php',
     publication_date=None,publication_year=2026,publication_issue=2,verified_update_date=None,
     date_evidence='Primary proceedings search metadata verifies2026volume/issue2/pages198–214; exact publication day not verified. Direct page timed out; alternate host inaccessible.',
     paper_license='Primary proceedings metadataCCBY4.0',implementation_license=None,
     author_claim='Hybrid matrix lookup+Plonk linked to specialized commit-and-prove SNARKs; proceedings lists available/functional/reproduced artifact badges.',
     assessment='New architectural lead, no primary artifact/code inspected. Artifact badges are venue evidence, not a reproduction here. No native private8B integration, timing or protocol claim follows.',
     blockers=['primary www page:400 Timeout fetching','alternate petsymposium.org page:not accessible']),
dict(title='Known zkLLM tensor lookup/attention CUDA evidence refreshed',url='https://arxiv.org/abs/2404.16109',
     publication_date='2024-04-24',verified_update_date=None,date_evidence='Primary history v1April24,2024 18:04:50UTC; onlyv1listed.',
     implementation_license=None,paper_license='Landing links a license; body not inspected thiscycle.',
     author_claim='Parallel tlookup and zkAttn; authors report13B inference proof under15minutes and small proof size.',
     assessment='Known baseline family, not a new measured gain. Author arithmetic/approximation/privacy scope is not native frozen R13 exactness. No implementation executed or author throughput reproduced.')]
prior=(HERE/'startup/sources.jsonl').read_bytes()
assert (BASE/'sources.jsonl').read_bytes()==prior,'source log changed concurrently; preserve/reconcile before append'
old_records=[json.loads(x) for x in prior.decode().splitlines() if x.strip()]
records=[]
for i,e in enumerate(entries,1):
    x={**common,**e,'id':f'cycle{CYCLE}-source-{i}'}
    x['prior_exact_url_records']=sum(r.get('url')==x['url'] for r in old_records)
    records.append(x)
(HERE/'sources-cycle.jsonl').write_text(''.join(json.dumps(x,ensure_ascii=False,sort_keys=True)+'\n' for x in records))
with (BASE/'sources.jsonl').open('a') as f:f.write((HERE/'sources-cycle.jsonl').read_text())
write('rotation.json',dict(cycle_focus=['lookup arguments/softmax','batching/amortization','public descriptor preparation'],
    next=['GPU NTT/commitments','memory traffic','proof composition'],
    rotating_queue=['GPU NTT/commitments','sumcheck/GKR','lookup arguments/softmax','memory traffic','batching/amortization','quantization/arithmetic','proof composition']))
write('target-accounting.json',dict(run_id=RUN,full_stack_proofs=0,independently_verified_receipts=0,
    model_passes=0,proved_positions=0,actual_model_context=None,actual_accelerator=None,
    research_device='one Intel Core Ultra9 185H CPU thread',witness_s=None,proof_s=None,serialization_s=None,
    verification_s=None,startup_s=None,startup_fraction=None,initial_prefill_s=None,
    steady_state_positions_per_s=None,total_workload_positions_per_s=None,proof_latency_s=None,proof_bytes=None,
    long_context_prefill_executed=False,resident_model_pass_series_executed=False,decode_executed=False,
    target='complete private8B >=50proved positions/s onRTX5090 or another named high-endGPU; unachieved',
    actual_workloads='None; T128 and other dimensions are public/source metadata and tiny synthetic arrays. Larger workloads allowed; attention may grow quadratically.'))

readme=f'''# R13 exact-expression looked-column storage

Run `{RUN}`, cycle0139. Checkpoint {now}.
No native proving improvement measured. This is a source-derived metadata,
synthetic differential and logical storage study, not an implemented Rust/GPU path.

The frozen R13 source (tree digest bb9eb212…, not a Git commit) has a new
`AccuracyIds::lookups` emitter. Unlike the earlier R9 census, full-byte pins
are emitted even when their coefficient is1. The public expression repeats;
its logical occurrence is still part of the admitted profile. The tested model
builds one private looked vector per exact `(domain,source,coefficient,constant)`
and retains an ordered index per original occurrence. Weighted histograms and
miss counts retain every occurrence; helpers retain the original pairs.
Prepared private values are reconstructed for every invocation and not retained
in the public Plan. Masks, openings and per-proof challenges are never cached.

| 8B T128 representative public class | Baseline looked MiB | Prepared MiB | Avoided MiB |
|---|---:|---:|---:|
| fE9, no DD |490.25|481.25|9.00|
| fE9, DD32 |463.25|460.25|3.00|
| fE12 or16, no DD |498.25|497.25|1.00|
| fE12 or16, DD32 |465.25|464.25|1.00|

Source `NATIVE_LAYOUT_CENSUS.json` public query totals agree for all six selected
classes. These are per-block logical looked-buffer bytes, excluding existing
A/H/M, codewords, scratch and new public plan metadata. Model-sized arrays were
never allocated. Precision is the source's representative BASE fixture:
q/k15, v16, pv12, score18, ao21, down20, up12, gate18. It is not an observed
8B layer calibration. Native derive's permitted v10..16 and pv12..16 sensitivity
is separate in `sensitivity-result.json`: aliases disappear when v<16; pv16
adds a Q-domain alias. Actual per-layer incidence and memory high-water are unknown.

The native source already prepares256 byte inverses once per proof. This
experiment does not rediscover that cache. It shares only exact source-vector
materialization within the same invocation. All A/H/M rows, helper planes,
fresh masks, PCS claims and logical schedule remain by construction. A proof
byte identity result remains untested. Profile-level alias deletion is a
different unimplemented protocol change and receives no speed credit.

Probe: {result['checks']:,}checks, {result['fixtures']:,}fixtures,
{result['helper_cases']}helper cases and {len(result['negative_controls'])}controls,
{result['elapsed_s']:.6f}s / {result['max_rss_kib']:,}KiB RSS. Source/accounting audit:
{audit['checks']}checks,4count-preserving source mutations and12pins,
{audit['elapsed_s']:.6f}s / {audit['max_rss_kib']:,}KiB. Seed202610290139.
References are independent implementations by this researcher, not external
review. CPU-light checks pinned one nice19 worker,40sCPU/45salarm/50sparent,
256MiB address space,96MiB estimated memory. Two initial reader bugs and their
corrections are retained under `initial-*-failure/`. No foreign code executed.

Commands from research directory:

```
python3 experiments/lookup-public-incidence-20261029/run_bounded.py probe.py
python3 experiments/lookup-public-incidence-20261029/run_bounded.py audit.py
```

Baseline/elimination/new costs/ceiling/falsification are in hypothesis58 and
the handoff. Numeric end-to-end improvement is unknown: deleting a genuinely
exclusive fraction f gives at most1/(1-f), before costs. The saved byte fraction
is not f. The selected savings are small; whole-prover GPU and exclusive phase/
capacity telemetry remain ahead of this integration.

LIVE primary literature/GitHub search: Baloo, cq and its Halo2-PSE fork;
Plonky3 current release/components/caller obligations; Gryphes; zkLLM. No author
performance reproduced. Dates, license scope, observed versus inspected commit
coordinates and exact access blockers are in `sources-cycle.jsonl` and web logs.
Baloo is a newly assessed older technique here. Pairing/KZG/zk-cq linkage is
an architectural cost, not an existing native helper replacement.

New independently verified full-stack proofs/passes/positions:0/0/0.
Witness/proof/serialization/verification/startup/initial-prefill clocks and
startup fraction, steady-state/total-workload rates, proof latency/bytes:
unmeasured. Actual model context/accelerator:none. No long prefill, resident
model pass series or decode ran. Larger workloads are allowed; increasing
attention context can increase work quadratically. Private8B >=50proved
tokens/s onRTX5090 or another named high-endGPU remains unachieved.
'''
(HERE/'README.md').write_text(readme)

handoff=f'''# R13 looked-column alias storage — reviewable interface, no native patch

Cycle0139 `{RUN}`. {now}. Main/Claude reviews and integrates; no merge here.

Candidate `experiments/lookup-public-incidence-20261029/candidate.py` is a
synthetic interface model. There is no compiled/applied Rust patch.
Pinned seam: frozen R13 `hashline/src/private_block/protocol.rs`:
`lookup_values_at` (line394), `byte_histogram_at`, `u8_misses_of`, helper loop
(line1159) and `drop(looked)` (line1228). `accuracy_layout.rs::lookups` (line109)
emits original descriptor order; `argument.rs::lk_tables/helper_sum` remains
the original relation. Twelve source hashes in the experiment manifest.

Proposed Rust container, scoped to one domain and one proof invocation:
`LookupColumns {{ unique: Vec<Vec<i64>>, order: Vec<usize>, multiplicities: Vec<usize> }}`.
`column(logical_index)->&[i64]` resolves the original position through `order`.
Plan construction keys the complete public `Lk` expression plus domain; source
ids are SHAPED ids. Do not key only source, length, coefficient or private values.
Keep every logical occurrence, including full-byte identity pins. Callers keep
the original lookup_words, public threshold branches, helper count/order and
table helper construction. Weighted histogram/miss scans use public checked
multiplicities; keep bin0 handling of invalid words. Maintain wrapping i64
arithmetic exactly. Release private buffers at the original lifetime; prepare
new private vectors for every proof/witness. No cross-proof private cache.

Model {result['checks']:,}checks/{result['fixtures']:,}fixtures/{result['helper_cases']}helper cases
and14controls pass; separate audit {audit['checks']}checks/4source mutations/12pins.
Logical data match includes arbitrary signed endpoints, overflow, alias multiplicity,
new private sources, helper grouping, equal-pair poles and out-of-table fallback
poles. Native full table poles/refusal order, constructors, RNG draw order,
transcripts, PCS, receipts and privacy are unexecuted and remain acceptance gates.

Representative source-derived8B T128 fE9 looked490.25->481.25MiB noDD,
463.25->460.25MiB DD; fE12/16 saves1MiB each. Counts match the owner's public
census, not actual per-layer calibration. v16 yields one Kv alias; wrho16
yields two S or Dd aliases. pv16 can add one Q alias; sensitivity is labelled
separately. No modeled A/H/M/helper/mask/PCS reduction. Actual peak, source
traffic and enclosing time unknown; metadata and indexing cost are added.
Do not represent these counts as a native proof-byte or memory measurement.

First owner measurement: actual admitted layer precision descriptor incidence
and exclusive lookup generation/histogram/miss/helper/enclosing clocks, plus
overlap/peak owners. Only if useful, implement original vs container A/B under
current shared locks. Preserve old path as oracle and run golden/refusal,
RNG/transcript/PCS/privacy and independent complete-workload verification.
Any mismatch or enclosing regression falsifies promotion. With removable f
unknown there is no numeric end-to-end ceiling; even free deletion is1/(1-f).
Whole-prover GPU/resident1/2/4/8 and admitted context scaling retain priority.

No new complete proof or positions counted. Target unchanged/unachieved.
'''
(BASE/'handoffs/20261029-r13-lookup-column-views.md').write_text(handoff)

progress=f'''# ZKP efficiency progress

Cycle 0139 complete — `{RUN}`, 2026-10-29 UTC.

**No native proving improvement measured.** The synthetic model shares storage
for exact repeated R13 lookup expressions while retaining every logical
occurrence, helper pair and fresh-mask schedule. For representative 8B T128
parameters, looked-column payload falls from 490.25 to 481.25 MiB without DD,
or 463.25 to 460.25 MiB with DD. These are logical per-block counts, not
measured peak memory, physical traffic or runtime savings.

Validation: {result['checks']:,} checks, {result['fixtures']:,} synthetic fixtures,
{result['helper_cases']} helper cases and 14 controls pass; {result['elapsed_s']:.6f} s,
{result['max_rss_kib']:,} KiB RSS. The separate source/accounting audit passes
{audit['checks']} checks, including four mutations and 12 source pins. No native
Rust, proof or GPU job ran. Eight primary source records were appended. All
57 prior hypotheses remain; 25 and 35 were refined, and 58 was added.

The remaining questions are actual per-layer alias incidence and exclusive
preparation, histogram, helper and enclosing clocks. Container ownership and
indexed reads add costs. Commitments and proof data do not shrink in this
model; native refusal, RNG, transcript, PCS, receipt and privacy gates remain.

Next: measure the admitted catalog and exclusive clocks before deciding on a
native container A/B under shared locks. Complete-prover GPU measurements and
independently verified resident-model workloads remain the first priority.
The next local rotation checks R13 widths and lifetimes against the owner's
split-width design before proposing another memory experiment.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: none; research used one Core Ultra 9 CPU
thread. Witness, proof, serialization, verification, startup and initial-prefill
clocks, startup fraction, proof latency/bytes, steady-state and total-workload
rates: **unmeasured**. No long prefill, resident-model proof series or decode
ran. Larger workloads remain allowed; longer attention can grow quadratically.
The complete private 8B >=50 proved-token/s target remains unachieved.

[Experiment](experiments/lookup-public-incidence-20261029/README.md) ·
[Handoff](handoffs/20261029-r13-lookup-column-views.md) ·
[Dated report](progress/{RUN}.md). Checkpoint: {now}.
Saved reports do not imply message delivery or supervisor liveness.
'''
(BASE/'PROGRESS.md').write_text(progress)
(BASE/'progress'/f'{RUN}.md').write_text(progress+'\n'+handoff)

finding=f'''
## Cycle 0139 — exact R13 lookup storage: small logical savings, native gain unknown

Run `{RUN}`; checkpoint {now}. AGENDA, current target, durable state,
prior U8 alias/PCS negatives, latest results and required project documents were
read. The actual frozen R13 tree (digest bb9eb212…, not a Git commit) supplies
its own accuracy emitter. The older trained-1b path still has an earlier layout;
follow-up studies must select the current owner baseline explicitly.

**No native proving improvement measured.** New hypothesis 58 asks whether exact
public expressions can share one private looked buffer per invocation while
retaining every original logical occurrence. The public Plan owns descriptors
and indices; Prepared reconstructs all private data for each invocation. Equal
private values never decide aliasing. Original helper pairs, table multiplicities,
miss counts and fresh masking remain. Native code already prepares the 256 byte
inverses once per proof; this does not rediscover that existing optimization.

| Representative 8B T128 class | Baseline looked MiB | Prepared MiB | Avoided MiB |
|---|---:|---:|---:|
| fE9, no DD |490.25|481.25|9.00|
| fE9, DD32 |463.25|460.25|3.00|
| fE12/16, no DD |498.25|497.25|1.00|
| fE12/16, DD32 |465.25|464.25|1.00|

All six totals match the pinned owner's public census. These are per-block
looked-column bytes at the source's representative BASE precision (q/k15, v16,
pv12, score18, ao21, down20, up12, gate18), not actual 8B layer calibration.
The separate 210-class sensitivity varies v10–16 and pv12–16: v<16 removes
the Kv alias; pv16 adds a Q alias; wrho16 adds two S or Dd aliases. Model-sized
arrays were not allocated. Actual peak memory, physical traffic, per-layer
incidence and enclosing time remain unknown. A/H/M rows, helper planes and fresh
masks remain by construction; native receipt byte identity is untested.
Profile-level alias deletion is a separate unimplemented schedule change.

The model passes {result['checks']:,} checks, {result['fixtures']:,} fixtures,
{result['helper_cases']} helper cases and 14 controls in {result['elapsed_s']:.6f} s /
{result['max_rss_kib']:,} KiB RSS. Separate source/accounting audit: {audit['checks']}
checks, four count-preserving mutations and 12 pins pass in
{audit['elapsed_s']:.6f} s / {audit['max_rss_kib']:,} KiB. References were independently
written by this researcher; this is not external review or native execution.
Controls cover full expression keys, equal private values, logical order,
multiplicities, changed witnesses, nonfull top pins, signed wrapping, equal-pair
poles and out-of-table fallback poles. Full table helpers and native constructor,
refusal, RNG, transcript, PCS, receipt and privacy gates remain unexecuted.
Two initial source-reader errors and their corrections are retained. Seed:
202610290139. One pinned nice19 Core Ultra 9 185H CPU worker; 40 s CPU cap,
45 s alarm, 50 s parent timeout, 256 MiB address-space cap, 96 MiB estimate.

Baseline: each lookup independently allocates a Vec<i64> in lookup_values_at.
Potential eliminated work: duplicate source transforms, looked buffers and
weighted histogram/miss scans. Added costs: exact public descriptor comparisons,
order/multiplicity metadata, indexed reads and consumer/lifetime integration.
With removable exclusive fraction f unknown, even free deletion gives at most
1/(1-f) before costs; saved logical byte fraction is not f. Falsify promotion on
any value, wrap, order, histogram, miss, helper, pole, refusal, RNG, transcript,
receipt or privacy mismatch, absent real aliases, or slower enclosing workloads.
No numeric native or high-end GPU ceiling follows.

All 57 prior hypotheses remain; 25/35 were refined and 58 was added. Global
priorities remain complete-prover high-end GPU plus verified resident 1/2/4/8,
admitted DD/fidelity context scaling, and exclusive phase/capacity clocks.
Hypothesis 58 was the leading feasible local experiment for this rotation.

Eight primary records append 916→924. Newly assessed older Baloo and the
Halo2-PSE cq fork make public preprocessing versus private query/linking costs
explicit. KZG/pairing migration is not a native helper substitution. Known cq,
Plonky3 compiled components/caller obligations and zkLLM were refreshed. Gryphes
primary proceedings metadata was available in LIVE search; direct fetch timed
out. Dates, license scope, observed versus inspected commit coordinates and
access failures are retained. Known TenseUp primary pages were inaccessible.
No author performance was reproduced and no foreign code was executed.

Owner next: actual admitted per-layer catalog incidence and exclusive lookup,
histogram, miss, helper and enclosing clocks before native integration, followed
by golden, refusal, RNG, transcript, PCS, privacy and independently verified
complete-workload gates under shared locks. Local next: GPU commitments/memory
rotation; inspect R13 widths/lifetimes against the owner's split-width design.
No heavy job queued or owner lane duplicated. Main/Claude reviews and integrates.
Handoff: `handoffs/20261029-r13-lookup-column-views.md`.

New independently verified full-stack proofs / passes / positions: 0 / 0 / 0.
Actual model context and accelerator: none. Witness, proof, serialization,
verification, startup and initial-prefill clocks, startup fraction, proof
latency/bytes, steady-state and total-workload rates: unmeasured. No long
prefill, resident-model proof series or decode ran. Larger workloads remain
allowed; longer attention can grow quadratically. The complete private 8B
>=50 proved-token/s target on an RTX 5090 or another named high-end GPU is unachieved.

Historical CPU 8B T128/L32, one 16-thread pass, GPU off, carried only: total
478.737 s = 0.267370 positions/s; prove_run 393.785 s includes witness 98.348 s /
load 17.595 s. Sealing 84.824 s precedes prove_run (internal load 27.151 s and
witness 80.897 s overlap). Receipt 922,711,264 B; verify 42.709 s + load 13.681 s.
Not rerun/reverified. Isolated serialization, startup fraction and steady slope
are unknown; no historical positions are newly counted.

Only research outside runtime was written. No production, Git, receipts,
calibration, instructions, safety or reviewer files changed. No build, GPU,
installation, external write/message, purchase or escalation occurred.
Saved reports do not imply message delivery or supervisor liveness.
'''
prior_findings=(HERE/'startup/FINDINGS.md').read_bytes()
assert (BASE/'FINDINGS.md').read_bytes()==prior_findings,'findings changed concurrently'
with (BASE/'FINDINGS.md').open('a') as f:f.write(finding)

state=f'''# ZKP efficiency explorer — durable state

Cycle 0139 COMPLETE: `{RUN}`.
Started 2026-10-29 08:56:49 UTC; checkpoint {now}.
Deadline 09:16:49 UTC. Next cycle no earlier than 09:56:49 UTC.

No native proving improvement measured. The synthetic model shares storage for
exact repeated frozen R13 lookup expressions while retaining all logical
occurrences and helper positions. Representative 8B T128 fE9 looked payload:
490.25→481.25 MiB without DD, 463.25→460.25 MiB with DD; fE12/16 saves 1 MiB.
All six totals agree with the owner's public census. Actual per-layer precision,
incidence, physical peak/traffic and enclosing runtime remain unknown.
A/H/M rows, helper planes and fresh masks remain; native byte identity is untested.

Only the public descriptor plan is reusable. Private columns are reconstructed
for each invocation, never compared to decide aliasing or cached across proofs.
Preserve all fresh masks, openings, challenges, table poles, original sources,
logical order, multiplicities and refusals. Native gates remain owed.

Model: {result['checks']:,} checks / {result['fixtures']:,} fixtures /
{result['helper_cases']} helper cases / 14 controls PASS; {result['elapsed_s']:.6f} s /
{result['max_rss_kib']:,} KiB RSS. Separate audit: {audit['checks']} checks / four
mutations / 12 source pins PASS; {audit['elapsed_s']:.6f} s /
{audit['max_rss_kib']:,} KiB. Restricted source reader, not native constructors,
define, refusal execution or external review. Two initial reader failures are
retained. One pinned nice19 Core Ultra 9 CPU thread; 40 s CPU, 45 s alarm,
50 s parent, 256 MiB address-space cap, 96 MiB estimate. No native build/GPU.

All 57 prior hypotheses remain; 25/35 refined, 58 added. Top three remain
complete-prover high-end GPU with verified resident 1/2/4/8 workloads,
admitted DD/fidelity context scaling, and exclusive phase/capacity clocks.
Eight LIVE primary records append 916→924: Baloo, cq, Halo2-PSE cq,
Plonky3 release/components/caller obligations, Gryphes and zkLLM. Dates,
license scope, observed versus inspected commits and fetch blockers are saved.
No author performance reproduced or foreign code executed.

Use the actual frozen R13 tree for follow-up: the older trained-1b path has an
earlier descriptor layout. R13 soundness acceptance and classifier proofs do
not amend the private 8B throughput target. Confirm the current owner baseline.

Owner next: actual admitted per-layer descriptor incidence and exclusive lookup,
histogram, miss, helper and enclosing clocks; then decide whether a native
container A/B is justified under current locks. Golden, refusal, RNG, transcript,
PCS, receipt, privacy and independently verified full-workload gates remain.
Whole-prover GPU and resident workloads retain priority. Local next: GPU
commitments/memory rotation, checking R13 widths/lifetimes against the owner's
split-width design. Main/Claude reviews and integrates; no heavy job queued.

Experiment: experiments/lookup-public-incidence-20261029/README.md.
Handoff: handoffs/20261029-r13-lookup-column-views.md.
Dated report: progress/{RUN}.md.

New independently verified full-stack proofs / passes / positions: 0 / 0 / 0.
Actual model context and accelerator: none; research used one CPU thread.
Witness, proof, serialization, verification, startup and initial-prefill clocks,
startup fraction, proof latency/bytes, steady-state and total-workload rates:
unmeasured. No long prefill, resident-model proof series or decode ran.
Larger workloads remain allowed; longer attention can grow quadratically.
Private 8B >=50 proved tokens/s on an RTX 5090 or another named high-end GPU
remains unachieved.

Historical CPU 8B T128/L32, one 16-thread pass, GPU off, carried only: total
478.737 s = 0.267370 positions/s; prove_run 393.785 s includes witness 98.348 s /
load 17.595 s. Sealing 84.824 s precedes prove_run (internal load 27.151 s and
witness 80.897 s overlap). Receipt 922,711,264 B; verify 42.709 s + load 13.681 s.
Not rerun/reverified. Isolated serialization, startup fraction and steady slope
are unknown; no historical positions are newly counted.

Prior STATE is preserved in startup; FINDINGS and sources are append-only.
Only research outside runtime was written. No production, Git, receipt,
calibration, instruction, safety or reviewer files changed. No build, GPU,
installation, external write/message, purchase or escalation occurred.
Saved reports do not imply message delivery or supervisor liveness.
'''
(BASE/'STATE.md').write_text(state)
write('completion.json',dict(run_id=RUN,cycle=CYCLE,completed_utc=now,source_records_before=len(old_records),
    source_records_after=len(old_records)+len(records),new_full_stack_proofs=0,source_claims_reproduced=False))
print(json.dumps(dict(completed_utc=now,source_records=len(old_records)+len(records),hypotheses=len(queue))))
