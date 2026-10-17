#!/usr/bin/env python3
"""Write the authorized research-only checkpoint, using retained results."""
from pathlib import Path
import datetime,hashlib,json

P=Path(__file__).resolve().parent
R=P.parent.parent
d=json.loads((P/'result.json').read_text())
a=json.loads((P/'audit-result.json').read_text())
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
run=d['run_id']
base=dict(access_date='2026-10-17',access_timezone='UTC',recorded_at_utc=now,
          cycle='0061',run_id=run,inspected_commit_id=None,reproduced_performance=False,
          evidence_kind='Native LIVE primary search/inspection; source text untrusted; no foreign code executed')
records=[
dict(id='cycle61-hybridspartan-october14-proof-size-cost-correction',title='SubLogarithmic Linear Time SNARKs from Improved Sumcheck',url='https://eprint.iacr.org/2025/908',published='2025-05-21',updated='2026-10-14',date_evidence='Primary receivedMay21,2025; last of17 revisionsOct14,2026; CCS2026 to-appear label.',implementation_license=None,paper_license='CC0 metadata label',author_claim='Sublogarithmic proof size with linear prover; revised abstract corrects previously unaccounted proof-size costs.',assessment='New source and recent verified revision. Alternative PCS/setup/composition architecture; smaller messages are not native masked proof or complete-model speed. No implementation inspected or reproduced.',access_issues=[]),
dict(id='cycle61-new-older-sublinear-space-merkle-transcript-boundary',title='Zero-Knowledge Proofs in Sublinear Space v2',url='https://arxiv.org/abs/2509.05326',supporting_urls=['https://arxiv.org/html/2509.05326v2'],published='2025-08-30',updated='2025-09-17',date_evidence='Primary v1Aug30,2025 23:22:54UTC;v2Sep17,2025 17:25:28UTC.',implementation_license=None,author_claim='Block/tree-evaluation memory compression; linearPCS transcript preservation is conditional; Merkle/FRI transcripts can differ.',assessment='New older lead; claim not independently established. Native hashPCS, arithmetic, masks, state binding and privacy require their own review. Not a blanket same-proof transformation; no performance reproduced.',access_issues=[]),
dict(id='cycle61-new-hc-stark-resource-bounds-and-version-scope',title='hc-stark resource-bounded Plonky3 backend and retired KZG prototype',url='https://github.com/logannye/hc-stark',supporting_urls=['https://github.com/logannye/space-efficient-zero-knowledge-proofs','https://github.com/logannye/hc-stark/commits/main/','https://github.com/logannye/hc-stark/blob/main/LICENSE','https://github.com/logannye/hc-stark/releases'],published=None,updated=None,date_evidence='No repository update/release date established. README retirement date2026-07-17 does not date current code.',implementation_license='MIT README/repository claim only; full LICENSE fetch Cache miss; separate commercial supervisor outside proof-engine scope.',author_claim='Current README pinsPlonky3 0.6.1, bounded SSD/checkpoint orchestration pre-production; legacy companion README claims5.9-6.2x lessRAM at2.4-3.1xCPU cost.',assessment='New implementation lead, architecture reference only. No release status, author benchmark or native privacy/performance independently established. Charge scratchIO and state persistence; never persist real witness/RNG here.',access_issues=['hc-stark history,LICENSE,releases:Cache miss','legacy repository history:Cache miss']),
dict(id='cycle61-epfl-unreleased-rewrite-and-rate-limited-pin',title='Efficient Sumcheck current streaming design and unreleased rewrite',url='https://github.com/compsec-epfl/efficient-sumcheck',supporting_urls=['https://github.com/compsec-epfl/efficient-sumcheck/blob/main/CHANGELOG.md','https://github.com/compsec-epfl/efficient-sumcheck/blob/main/docs/design.md','https://github.com/compsec-epfl/efficient-sumcheck/commits/main/'],published=None,updated=None,date_evidence='HistoryJun24,2026 merge; rewriteUnreleased; older0.0.2Feb11,2026. Current source update date not established.',implementation_license='Apache-2.0/MIT repository labels only this cycle; both license texts Internal Error; older inspections retain separate scope.',exposed_uninspected_commit_id='9e55dc3a020fe9e94a7617628587685eb39b32ce',author_claim='Streaming schedules/Goldilocks extensions; rewrite changesAPI,transcript andEvalsInfty wire.',assessment='Known refresh, not native masked-polynomial/PCS/transcript parity. Final oracle binding and order remain obligations; no performance reproduced.',access_issues=['Resolved full commit target429 Too Many Requests,then Internal Error; no diff inspected','LICENSE-MIT/APACHE:Internal Error']),
dict(id='cycle61-cuda-ntt-invalid-hierarchy-negative-preserved',title='cuda-zkp-ntt displayed release and invalid hierarchical transform',url='https://github.com/Artemarius/cuda-zkp-ntt/releases',supporting_urls=['https://github.com/Artemarius/cuda-zkp-ntt','https://github.com/Artemarius/cuda-zkp-ntt/blob/main/LICENSE'],published=None,updated=None,date_evidence='v5UI16Mar21:42 no year;copyright2026 not release date.',implementation_license='MIT main full text inspected; not pinned tag license.',exposed_uninspected_commit_id='7b1e6b9 (abbreviated release target)',author_claim='Hierarchical GEMM-NTT output invalid despite attractive timing; v4TensorCore2-12x slower.',assessment='Known rejection refreshed. Incomplete full transform disqualified; stage/full ratios and author3060Laptop figures not native end-to-end evidence.',access_issues=[]),
dict(id='cycle61-october-algebraic-geometry-primary-access-blocked',title='Speeding up Sumcheck using Algebraic Geometry discovery, primary unavailable',url='https://eprint.iacr.org/2026/2494',supporting_urls=['https://eprint.iacr.org/2026/2494.pdf'],published=None,updated=None,date_evidence='Mirror discovery saysOct15,2026; primary page/PDF inaccessible, so no date accepted.',implementation_license=None,author_claim=None,assessment='Recent search attempted; primary content/date unverified. No technical/performance conclusion. Independent local experiment proceeded.',access_issues=['Primary abstract/PDF:Internal Error'])]

src=R/'sources.jsonl'; prefix=(P/'startup/sources.jsonl').read_bytes()
assert src.read_bytes().startswith(prefix)
existing=[json.loads(x) for x in src.read_text().splitlines()]
ids={x.get('id') for x in existing}
with src.open('a') as f:
 for x in records:
  if x['id'] not in ids:f.write(json.dumps(dict(base,**x),sort_keys=True)+'\n')
assert len(src.read_text().splitlines())==315
(P/'sources-added.json').write_text(json.dumps([dict(base,**x) for x in records],indent=2)+'\n')

accounting='''Accepted independently verified complete private **8B** proofs / passes / positions: **0 / 0 / 0**. Its context, steady-state and total-workload rates, startup seconds/fraction, witness/proof/serialization/independent-verification clocks, proof latency/lag and drain are **unmeasured**. Local device: one Intel Core Ultra9 185H CPU thread, CPU0, nice19; no GPU. Owner diagnostics: trained TinyLlama1.1B,22 linked blocks, T32/T64/T128, one cold pass per CPU or RTX4070Laptop-assisted arm,16 Rayon threads,n=1; fresh-verifier logs inspected,not rerun, no privacy acceptance at that shape. No resident sweep or decode ran here; no new prefill proof ran. Larger workloads remain allowed with fresh masks; dense attention grows approximately quadratically with context. The >=50 proved-token/s target remains unchanged and unachieved.'''

rows=[]
for x in sorted(d['retained_owner_samples'],key=lambda x:(x['context'],x['name'])):
 mode='GPU-assisted' if x['name'].endswith('-gpu') else 'CPU'
 rows.append(f"|{x['context']}|{mode}|{x['total_wall_s']:.6f}|{x['diagnostic_positions_per_second']:.6f}|{x['witness_and_extraction_s']:.3f}|{x['proof_including_sink_excluding_witness_s']:.3f}|{x['fresh_verification_s']:.3f}|{x['receipt_bytes']}|")
table='''|Context|Device arm|Whole process s|Diagnostic positions/s|Witness/extraction s|Prove-run minus witness s|Fresh verify s|Proof bytes|
|---:|---|---:|---:|---:|---:|---:|---:|
'''+ '\n'.join(rows)

ranks='''1. **OWNER, largest recurring-time opportunity:** obtain trained slot/commitment clocks, then move the largest measured phase to the GPU. T128GPU prove_run minus witness is107.079/142.783s but includes boundary/serialization/sink. The old synthetic SC_SZC share cannot be transplanted. High CUDA integration; charge launches/transfers/scratch/drain. Exact masked polynomial, terminal oracle, RNG, bytes, fresh verifier and privacy gates remain owed. Any mismatch or unchanged complete time falsifies a gain.
2. **OWNER, refined resident question:** after one-pass witness construction, which public model/NTT/digest setup survives repeated fresh complete proofs? Fixed-context pass sweeps with valid identities, fresh inputs/masks, recurring clocks/verification and lag/drain are needed. Cold load fractions5.76–17.26%CPU/6.58–15.05%GPU are not startup fractions. Costs are retained memory and recurring work; a recurring budget above20ms/new completed position falsifies50/s for that schedule. No endpoint-root reuse or decode inference.
3. **NEW/TESTED, demoted as speed priority:** defer46 initial i64 planes replaced by owned producers. Low/moderate initialization integration;103.754MiB aggregate allocation avoided atTinyLlamaT128, final217.816MiB unchanged. Added public flag vector/marks and catalog maintenance; physical allocator traffic unknown.8B ceilingN/(T-M+C), unknown. Native value/pad/first-refusal/RNG/bytes divergence or unchanged actual peak/workload rejects the corresponding claim. Deleting the entire T128GPU witness clock gives only1.09908x.
4. **NEXT LOCAL, capacity question:** reconcile cycles17/18 lazy/typed lookup readers with current R3/R4 lookup_values_at, byte_histogram_at and H-helper retention. Capture actual public Lk catalogs and count borrowed single-term versus computed affine/multi-term columns at trained geometries; retain wrapping-i64 and whole-table zero-denominator controls. This transfers earlier evidence to the new seam. Charge repeated scans, dispatch and lost Rayon parallelism in owner measurements; preserve indexed order and padded words.
5. **Deferred architecture leads:** Oct14 HybridSpartan correction, new older sublinear-space paper and hc-stark SSD orchestration need substantial PCS/composition or adapter work. Charge scratchIO, masks/state binding and verification; no author performance reproduced. Invalid hierarchical TensorCore NTT remains rejected; old fusion/CSE/quantization negatives preserved.'''

result_text=f'''The new Python experiment passes72 synthetic fixtures,5928 planes,293384
word comparisons and7 controls. Local run{d['experiment_wall_seconds']:.6f}s,
{d['peak_rss_kib']}KiB; independent audit{a['checks']}checks,
{a['wall_seconds']:.6f}s/{a['peak_rss_kib']}KiB. One nice19 CPU0 thread,
seed2026101761,59s wall/CPU,512MiB AS,96MiB estimate. No native compile/proof,
transcript/RNG execution, GPU or fresh receipt verification.'''

progress=f'''# ZKP efficiency progress

Cycle 0061 — `{run}`, completed 2026-10-17 UTC.

**No native speedup established.** A Python experiment passed 72 synthetic
fixtures, 5,928 plane checks, 293,384 word comparisons and seven negative
controls. It took {d['experiment_wall_seconds']:.3f} seconds and {d['peak_rss_kib']:,} KiB
RSS on one CPU thread. A separate {a['checks']}-check audit passed.

The [review-only patch](experiments/witness-plane-lifetimes-20261017/witness-candidate.patch)
defers 46 initial allocations that owned vectors later replace. At TinyLlama
T128 this avoids 103.75 MiB of aggregate initial allocation; final witness
storage is unchanged. Actual peak and time savings are unknown. This does
not establish that T256 fits in memory.
[Handoff](handoffs/20261017-deferred-witness-planes.md) identifies native gates.

Six R3 owner diagnostics match successful fresh-verifier logs. TinyLlama
T128 with GPU assistance took 142.783 seconds overall, including 12.872
seconds for witness/parity/extraction. Prove-run minus witness took 107.079
seconds and still includes boundary, serialization and sink work. Fresh
verification took 8.451 seconds, excluding its model load. Diagnostic rate:
0.89646 positions/s; receipt: 497,665,904 bytes. Logs were inspected, not rerun.
Startup, serialization and steady-state throughput remain unmeasured separately.
Deleting all witness time yields at most 1.099×. R2/R3 exports differ, so the
old 529-second/new 56-second comparison is not a controlled optimization A/B.

Six LIVE source records were appended, including the October 14 HybridSpartan
revision, older sublinear-space work and a backend with bounded storage.
Blocked primary/history/license fetches are recorded. Next local experiment:
inspect which current trained lookup columns can borrow existing planes.
The owner needs trained proof-phase clocks and resident fresh-proof slopes.

{accounting}

Research only; no native build/proof/GPU/install/foreign execution, production,
runtime, Git or external messages. Saved reports do not imply user delivery.
'''
(R/'PROGRESS.md').write_text(progress)
(R/'progress').mkdir(exist_ok=True)
(R/'progress'/f'{run}.md').write_text(progress+'\n'+table+'\n\n'+ranks+'\n')

details=f'''Source-pinned R3 build_shaped eagerly initializes78 non-table i64
planes and replaces30 direct outputs plus16 norm-limb vectors. Candidate
leaves only those46 slots empty. Every scatter domain keeps its zero fill;
full owned producer vectors, padded words, E's second pass, arithmetic and
control flow remain unchanged. Three histograms stay empty. This differs
from cycle20's Fp A-matrix assembly and cycles17/18's lookup-reader work.
There is no clone removal in the patch. Independent family catalogs and
source first-use checks supplement the separate sparse last-write oracle;
variable two/three score/probability limb IDs test remapping, not new profiles.

AtTinyLlamaT32/T128/T256(count-only), aggregate initial allocation avoided is
24.438/103.754/223.508MiB; final raw planes46.204/217.816/555.633MiB unchanged.
Llama3-8B T32/f_e9 count avoids49.126MiB, final90.392MiB; T512 count avoids
906.016MiB, final2234.266MiB. Final four-limb/f_e9 census uses source row
widths; larger contexts are count-only continuations, not admitted results.
Aggregate allocation is not concurrent peak or physical zero traffic;
calloc/compiler may avoid touching pages. Actual peak can be at A/H/lookup
construction after the builder returns. This patch does not establishT256 fit.
TinyLlamaT128's three D clones6MiB and score-support indices4MiB stay unchanged.

Baseline is pinned R3 initial plane construction. Eliminated work is46
redundant initial vector allocations, not final storage or relation work.
Added cost: small public flags vector,46 ID marks, existing-map branches and
catalog maintenance. Candidate uses initialized safe Vec operations, no value
dispatch, unsafe reads, mask reuse or skipped constraint.8B ceiling remains
N/(T_complete-saved_native_time+added_cost), all times unknown. Falsify any
native plane/pad/first-refusal/RNG/transcript/byte difference, unchanged actual
peak for capacity, or enclosing regression for speed. Deleting ENTIRE T128
witness clock leaves155.781/129.911sCPU/GPU, only1.08237/1.09908x, arithmetic
~0.8217/0.9853diagnosticpositions/s. This is a parent-phase upper bound, not a
candidate prediction or8B bound. No actual physical saving measured.

All six owner diagnostic pairs have matching22blocks,statement identities,
bytes, successful guards and0completion markers. n=1,one cold pass,16Rayon
threads per arm;GPU isRTX4070Laptop8.6GB label,not5090. T128CPU/GPU sampled
processHWM4.82/3.03GiB;GPU VRAM3105MiB. GPU load9.393s is6.5785% of wall,
NOT isolated startup. Fresh verifier8.451s plus11.307s model load; in-process
verify8.742s. Prove_run minus witness includes boundary work,segment encoding
and sink; witness includes parity/extraction. Pure proving/serialization and
steady slope remain unknown. R2/R3 identities differ, so529s->56s is not a
controlled A/B. No trained-shape privacy acceptance is claimed.

Initial named-vs-unnamed-limb catalog assertion and a diagnostic f_e10/generic
8B-width census are retained and superseded. Final run source is hashed.
The independent162-check audit reconstructs the exact one-hunk patch,checks
12closed-form payload rows and retained source/log hashes. Seven native files
had no live drift at audit. Native gates remain unrun; owner must recompare
pins, guarded-build, all-plane/pad/first-refusal/reference check, exact native
RNG/transcript/frozen bytes and fresh verifiers, then phase/HWM/workload clocks.
Research does not integrate or merge. No real private data was copied.'''

source_text='''LIVE review found a new recent [HybridSpartan revision](https://eprint.iacr.org/2025/908),
receivedMay21,2025/revisedOct14,2026; its abstract corrects proof-size costs.
New older [Nye2025](https://arxiv.org/abs/2509.05326),Aug30/Sep17,2025, qualifies
linearPCS transcript identity separately from changed Merkle/FRI transcripts.
[hc-stark](https://github.com/logannye/hc-stark) is a new boundedSSD reference,
current READMEPlonky3 0.6.1/pre-production; legacy companion claims not reproduced.
History/license/releases blocked; MIT only README/repository claim this cycle.
Known [EPFL rewrite](https://github.com/compsec-epfl/efficient-sumcheck/blob/main/CHANGELOG.md)
is Unreleased and changes wire/transcript. Jun24,2026 history resolves full
merge target9e55dc3a020fe9e94a7617628587685eb39b32ce, but inspection returned429
thenInternal Error; it is exposed/uninspected, not a source pin. Known
[NTT release](https://github.com/Artemarius/cuda-zkp-ntt/releases) still labels
hierarchical output invalid; main MIT text inspected,release year unverified.
New ePrint2026/2494 primary/PDF blocked,so mirror date/content not accepted.
Six appended records retain exact dates,URLs,license and commit limits.
Search queries/access errors are in the experiment search log. No source was
executed,installed or treated as instructions. No author speed reproduced.'''

entry=f'''\n\n## Cycle0061 — deferred witness planes after R3 moves the bottleneck ({run})

Checkpoint{now}. AGENDA/current target,durable/project memory,source ledger
and latest3 experiment results read/snapshotted.309records read;6LIVE sources
appended,315total. Historical findings/negative prefixes preserved.

{result_text}

{details}

{table}

{ranks}

{source_text}

{accounting}

[Experiment](experiments/witness-plane-lifetimes-20261017/README.md),
[handoff](handoffs/20261017-deferred-witness-planes.md). Next local is current
R3/R4 Lk capture/borrowability census; owner needs trained phase clocks before
an end-to-end estimate. Rotation:memory/NTT ->lookup/softmax/GKR ->batching/
composition ->arithmetic. Production/runtime/Git/calibration/gates/instructions/
reviewer files untouched; no heavy jobqueued or external message/write.
Saved reports are durable files,not delivery or liveness evidence.
'''
find=R/'FINDINGS.md';old=(P/'startup/FINDINGS.md').read_bytes()
assert find.read_bytes().startswith(old)
if f'## Cycle0061 —' not in find.read_text():
 with find.open('a') as f:f.write(entry)

state=f'''# ZKP efficiency explorer — durable state

Cycle0061 COMPLETE: `{run}`; checkpoint{now}.
AGENDA/current target,durable/project memory and latest3results snapshotted
in experiments/witness-plane-lifetimes-20261017/startup/.309source records
read;6LIVE records appended,315total. Historical prefixes preserved.

New ownerR3: trainedTinyLlama1.1B,22linked blocks,T32/64/128;6cold n=1 samples,
16Rayon threads,CPU/RTX4070Laptop assistance. Matching fresh-verifier logs
inspected,not rerun. T128CPU/GPU wholeprocess168.612/142.783s;diagnostic
0.75914/0.89646positions/s. Witness/parity/extraction12.831/12.872s;
prove_run minus witness136.177/107.079s includes boundary/serialization/sink.
Fresh verify11.100/8.451s plusload10.584/11.307s. Receipt497665904B.
Pure startup,serialization/steady slope unknown. GPU load9.393s/6.5785% is
NOT isolated startup. Deleting entire witness only1.08237/1.09908x.
R2/R3 calibration identities differ;529s->56s is not controlled A/B.
D24 accepted withconditions in current register,no trained privacy acceptance.

Local experiment72synthetic fixtures,5928plane/293384word checks,7controls,
{d['experiment_wall_seconds']:.6f}s/{d['peak_rss_kib']}KiB. Independent audit
{a['checks']}checks,{a['wall_seconds']:.6f}s/{a['peak_rss_kib']}KiB. CPU0nice19,
seed2026101761,one thread,59s/512MiB. Candidate defers46initial i64planes
replaced by owned producers; all scatter/full producer/E-pad words retained.
AtTinyLlamaT128 avoid103.754MiB aggregate initial payload;final217.816MiB
unchanged. Not measured peak/physical traffic/time savings orT256fit.
Added publicflags/ID maintenance. Clones/support only counted,unchanged.
Patchuncompiled/unapplied. Seven source pins stableat audit; recompare before
owner build. Handoff handoffs/20261017-deferred-witness-planes.md.
Prior six-int8 projection patch needs rebase against R3,not blind application.

Ranked queue:
1 OWNER trained proof slot/commitment clocks thenlargest recurring GPU phase;
 old syntheticSC_SZC share does not establishtrained share.
2 OWNER resident fixed-context complete-pass slopes;public setup reuse only,
 fresh masks,identity,parity,refusals,independent verify and lag/drain clocks.
3 TESTED low-priority selective initial allocations;native parity/allocator/
 HWM/time gates,final witness unchanged,atmost parentwitness ceilingabove.
4 NEW NEXT LOCAL source-capture currentR3/R4 Lk catalogs atlookup_values_at,
 byte_histogram_at,H helpers. Count borrowed single-term versuscomputed affine/
 multiterm columns;reconcile cycles17/18 withtrained4limb/f_e9 geometry and
 indexed parallel order. Synthetic wrapping-i64/full-table-refusal controls;
 owner must charge repeatedscans/dispatch/lostRayon,not infer speed frombytes.
5 ARCHITECTURE Oct14HybridSpartan correction,newolderNye2025/hc-stark bounded
 SSD. HighPCS/composition/privacycost;no authorperformance reproduced.
 EPFL wire rewrite notdrop-in;invalidhierarchicalTCNTT remainsrejected.

Next OWNER: recompare narrow candidate pins,sharedguard build,all-plane/pad/
 first-refusal parity thenRNG/transcript/frozenbytes/freshverifier gates;
 allocation/phase/actualHWM andwholeworkload measurements. Do not equate
 aggregate103.75MiB allocationremoval withpeak saving. No heavyjobqueued.
Next LOCAL asrank4:publicmetadata+synthetic values only;never real private
 witnesses or persisted privateRNG/scratch. Searchrotationlookup/softmax/GKR.

{accounting}

Researchonly:production/runtime/Git/calibration/gates/instructions/reviewer
files untouched.No nativebuild/proof/GPU/install/foreignexecution/external
message/write/merge. Reportsdo notestablishdelivery orsupervisorliveness.
Nextcycle notbefore2026-10-17T12:26:24Z.
'''
(R/'STATE.md').write_text(state)
(P/'checkpoint-summary.json').write_text(json.dumps(dict(checkpoint_utc=now,
 source_records_before=309,source_records_after=315,
 source_prefix_sha256=hashlib.sha256(prefix).hexdigest(),
 findings_prefix_sha256=hashlib.sha256(old).hexdigest(),
 new_source_ids=[x['id'] for x in records]),indent=2)+'\n')
print('Checkpoint saved: STATE/FINDINGS/PROGRESS/dated progress;315source records.')
