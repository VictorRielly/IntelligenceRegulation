"""Checkpoint this authorized research cycle, never production or runtime."""
from pathlib import Path
import datetime,hashlib,json
P=Path(__file__).resolve().parent;B=P.parent.parent
RUN='20261021T071854Z-0fa6988f'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
r=json.loads((P/'result.json').read_text());a=json.loads((P/'audit-result.json').read_text())
prior_sources=(P/'startup/research__zkp-efficiency__sources.jsonl').read_bytes()
prior_findings=(P/'startup/research__zkp-efficiency__FINDINGS.md').read_bytes()
assert (B/'sources.jsonl').read_bytes().startswith(prior_sources)
assert (B/'FINDINGS.md').read_bytes().startswith(prior_findings)

sources=[]
def add(title,url,published,updated,claim,assessment,license=None,commit=None,dates=None,issues=None):
    sources.append(dict(run_id=RUN,cycle='0123',access_date='2026-10-21',access_timezone='UTC',
        recorded_at_utc=now,title=title,url=url,publication_date=published,verified_update_date=updated,
        date_evidence=dates or 'Unknown exact date; no crawl date substituted',
        implementation_license=license,inspected_commit_id=commit,author_claim=claim,
        assessment=assessment,reproduced_performance=False,external_execution=False,
        evidence_kind='Native LIVE web search/open/find/click; external text treated as untrusted',
        access_issues=issues or []))
add('BLAKE3 older incremental-stack and memory-sizing technique',
    'https://github.com/BLAKE3-team/BLAKE3-specs/blob/master/blake3.tex',None,None,
    'CV stack follows completed subtrees; final root handling differs from intermediate chaining values.',
    'Incremental/hash-tree reasoning assessed locally; row-bound capacity and no stale reads tested against an independent installed library. Native PDF search excerpt also discusses maximum-size-limited storage; current tex view truncates at memory section.',
    issues=[{'url':'https://raw.githubusercontent.com/BLAKE3-team/BLAKE3-specs/master/blake3.pdf','error':'400 unsupported application/octet-stream'}])
add('BLAKE3 official implementation license and current release',
    'https://github.com/BLAKE3-team/BLAKE3/releases/tag/1.8.7',None,None,
    'Release 1.8.7 removes arrayref dependency.',
    'Current release inspected, no install or dependency change. Release displays Aug20 09:06 but year was not exposed; do not infer it. Root license alternatives inspected.',
    'CC0-1.0 OR Apache-2.0 OR Apache-2.0 with LLVM exceptions',
    dates='Release display Aug20 09:06, year unknown')
add('BLAKE3 1.8.7 commit diff inspected',
    'https://github.com/BLAKE3-team/BLAKE3/commit/f3149ec5bb5449af877ba20377a11008ff499fa2',None,None,
    'Version bump to 1.8.7 in five files.',
    'Inspected commit body/version diff, not a GPU implementation. Local independent reference is preinstalled Python blake3 1.0.9 and its own pinned binary, not this release.',
    'CC0-1.0 OR Apache-2.0 OR Apache-2.0 with LLVM exceptions',
    'f3149ec5bb5449af877ba20377a11008ff499fa2')
add('MARS2026 author repository, newly assessed scheduling technique',
    'https://github.com/yaoyunzhou/MARS','2026',None,
    'Profile-guided warp/register/shared-memory multi-tree scheduling improves FORS throughput.',
    'Different SPHINCS+ FORS workload; no claimed rate or security reproduced. Only README/license label inspected, no CUDA body/commit. Use measurement methodology only; not a drop-in BLAKE3 PCS.',
    'MIT label on repository; separate license body unavailable',
    dates='Author BibTeX says DATE2026; precise publication/update date unknown',
    issues=[{'url':'https://github.com/yaoyunzhou/MARS/blob/main/LICENSE','error':'Cache miss'},
            {'url':'https://github.com/yaoyunzhou/MARS/commits/main/','error':'Cache miss'},
            {'url':'https://past.date-conference.com/proceedings-archive/2026/DATA/644.pdf','error':'404'}])
add('BatchZK throughput and dynamic-loading precedent refreshed',
    'https://eprint.iacr.org/2024/1862','2024-11-14',None,
    'Batch pipelining across sumcheck, encoding and Merkle modules with dynamic loading and transfer overlap.',
    'Supports charging full batches and drain; author proof rates are different workload and not private8B performance.',
    dates='Primary History received2024-11-14, approved2024-11-15; no revision shown')
add('Chimera latest October16 revision refreshed',
    'https://eprint.iacr.org/2026/1388','2026-07-07','2026-10-16',
    'Hybrid GPU sumcheck scheduling.',
    'Current primary metadata checked; phase/incidence and end-to-end accounting still precede helper optimization. No author benchmark reproduced.',
    dates='Primary History received2026-07-07,revised2026-10-16')
add('MORPH2026 architecture/dataflow filter',
    'https://arxiv.org/abs/2604.17808','2026-04-20','2026-04-20',
    'Uses AI-ASIC arithmetic/dataflow for proof kernels.',
    'TPU/extended-RNS and NTT methodology is not a native Goldilocks/BLAKE3 GPU plug-in; no constants or rates transferred.',
    dates='Primary arXiv submission v1 2026-04-20 05:00:47UTC')
add('Poseidon older hash-circuit applicability filter',
    'https://eprint.iacr.org/2019/458','2019-05-10','2023-07-05',
    'Prime-field hash instances reduce constraints when hashing is inside an arithmetic circuit.',
    'Native Merkle hashing is external BLAKE3 code, not that circuit cost. A hash replacement changes frozen digests/security and is not authorized as a performance substitution.',
    dates='Primary History received2019-05-10,last of11 revisions2023-07-05')
existing=[json.loads(x) for x in (B/'sources.jsonl').read_text().splitlines()]
for s in sources:s['prior_exact_url_records']=sum(x.get('url')==s['url'] for x in existing)
(P/'source-records.jsonl').write_text(''.join(json.dumps(s,sort_keys=True)+'\n' for s in sources))
if not any(x.get('run_id')==RUN for x in existing):
    with (B/'sources.jsonl').open('a') as f:f.write((P/'source-records.jsonl').read_text())
queries=['2026 GPU BLAKE3 Merkle tree zero knowledge proof memory coalescing',
 'GPU polynomial commitment Merkle tree hashing streaming 2026 paper',
 'site.github.com BLAKE3 GPU cuda tree hash',
 'site.github.com BLAKE3-team BLAKE3 releases 1.8.3 2026',
 '"MARS" "Merkle" GPU 2026','GPU BLAKE3 incremental CV stack streaming hash column',
 '"MARS: A General GPU Optimization Framework" Merkle',
 '"blake3" "CV stack" "maximum input"',
 '"GPU" "polynomial commitment" "2026" "October"']
(P/'search-log.json').write_text(json.dumps(dict(native_live_queries=queries,primary_records=len(sources),
    rotation_this_cycle=['GPU commitments','memory traffic','batching/amortization','sumcheck/composition filters'],
    next_rotation=['proof composition','lookup/softmax fidelity','quantization exactness'],
    failures_recorded=True,no_external_code_executed=True),indent=2)+'\n')

account=dict(proofs=0,passes=0,positions=0,actual_model_context=None,actual_accelerator=None,
    research_device='Intel Core Ultra 9 185H, one CPU worker',witness_s=None,proof_s=None,
    serialization_s=None,verification_s=None,startup_s=None,startup_fraction=None,
    steady_rate=None,total_workload_rate=None,long_context_prefill=False,
    resident_model_proof_series=False,decode=False,counted_contexts=[128,512],
    T512_admitted=False,counted_profile='Frozen R9 A/H geometry; current LOW/HIGH excluded')
(P/'target-accounting.json').write_text(json.dumps(account,indent=2)+'\n')

metrics=f'''Hash/state model: **{r['checks']:,} checks, 27 synthetic matrix shapes and 11 control types PASS**.
Independent labelled-subtree/source/cost audit: **{a['checks']:,} checks, 1,024 chunk counts,
seven native source pins PASS**. This researcher authored both models; the cryptographic
reference is independently implemented in the already-installed `blake3` 1.0.9 package,
one thread. Final checker clocks/RSS: {r['wall_seconds']:.6f}s/{r['rss_kib']:,}KiB and
{a['wall_seconds']:.6f}s/{a['rss_kib']:,}KiB. These are diagnostic clocks, not proof clocks.
Every leaf has one-core affinity, nice19, 30s CPU/alarm, 35s parent timeout,
256MiB address-space limit and 64MiB estimated experiment memory.
'''
target='''New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Device: one Intel Core Ultra 9 185H CPU
worker. Witness, proof, serialization, verification and startup clocks, startup fraction,
steady-state and total-workload rates: **unmeasured**. No long-context prefill,
resident-model proof series or decode ran. T128/T512 are counted geometry only;
T512 is unregistered and LOW/HIGH fidelity layouts are excluded. Larger workloads
remain allowed; attention can grow quadratically. The complete private8B / >=50
proved tokens/s target on RTX5090 or a named high-end GPU remains unachieved.
'''
body=f'''## Cycle 0123 — streaming BLAKE3 state: exact CPU model, native benefit unknown

Run `{RUN}`, checkpoint {now}. **No proving speedup measured.**
AGENDA, prior state/findings, all782 prior source records, required project notes and
latest results read/snapshotted. Current D37–D41 media/classifier work does not amend
this research target. Old MVP_STATUS section2 five-second language is historical;
the current throughput-target document governs. All35 prior hypotheses remain;
rank36 adds the tested state candidate and rank37 the MARS scheduling screen.
Owner ranks1–4 remain whole-GPU plus verified resident1/2/4/8; DD larger-context
fidelity; complete phase/capacity clocks; native all-eleven FZC A/B.

Baseline: `commit_zk_chunked`, `commit_chunked` and `commit_chunked_upload` reserve
193 u32 words per encoded column (24 CV levels plus length) and zero their entire
pooled state backing. `Pooled::get_mut` returns full capacity; a best-fit allocation
can be larger than requested. The stream already avoids downloading full encodings;
there is no such transfer to eliminate in this path.

Tested changes: D=ceil(log2(ceil(rows/128))) CV levels suffice for the existing lazy
merge schedule; initialize only the count, or set local count=0 on public row0==0
and remove all explicit state clearing. Every CV read must follow a write in the
same proof. Poisoned bytes, fresh proof contents, 128/256/384-row launches, row/block/
chunk boundaries, global counters, root flags and little-endian words were tested.
All compared compression inputs and calls match. No compression or active CV
traffic is eliminated. Depth0 is needed for single-chunk columns. Zero/overflow
rows are excluded from the model, not newly admitted or refused by production.

{metrics}
| Frozen8B per-commit geometry | Rows A/H | CV depth A/H | Old state request MiB | New state request MiB A/H | Request saved MiB A/H |
|---|---|---|---:|---|---|
|T128 nonDD|3405/3790|5/5|48.25|10.25/10.25|38/38|
|T128 DD|3283/3634|5/5|48.25|10.25/10.25|38/38|
|T512 nonDD|9185/11056|7/7|96.50|28.50/28.50|68/68|
|T512 DD|7303/8724|6/7|96.50|24.50/28.50|72/68|

These are **one temporary state request per commitment**, not total model memory or
simultaneous A+H peak. With exact-sized backing, first-launch initialization removes
48.25/96.50MiB of explicit clearing per such call; actual pooled clearing can be
larger. Length-only clearing needs0.25/0.50MiB instead. Retained best-fit backing can
erase capacity savings completely. No actual allocator/HWM/device timing was measured.
No masks, salts, opening schedule, encoded values or lookup relation change.

Added costs: a public first-launch conditional; optional host/device depth agreement,
offset checks and original fallback. Native branch/register/driver/error behavior
and current privacy/refusal gates remain untested. Removed clear-API errors are
infrastructure behavior to review, not evidence of original failure equivalence.
If f is the unknown removable critical-path fraction, even free deletion gives
at most1/(1-f), before added costs. Byte fractions do not give f or a GPU speed.
Falsify on stale reads, wrong ordered hash/root/salt/path, RNG/transcript/receipt or
privacy drift, absent native incidence, no actual fit benefit, or slower enclosing
verified workload. A narrower uncompiled first-launch/no-memset patch is retained;
dynamic-depth compaction is model only. Native owner/Claude reviews and integrates.

Two source-audit anchor failures were corrected and retained (a comment-style
rate anchor and upload's enumerated loop), without changing production. All hash
experiments passed. Source records distinguish inspected full BLAKE3 commit
f3149ec5bb5449af877ba20377a11008ff499fa2, unknown release year and MARS history/license
cache misses. Nine native LIVE queries, eight primary records. New MARS2026
FORS scheduling and older BLAKE3 stack sizing were assessed; BatchZK, Chimera
October16, MORPH and Poseidon were filtered by actual backend/statement scope.
No author rate, external implementation or security claim was reproduced.

{target}
Carried historical baseline (not rerun/reverified): nonDD8B T128/L32, one16-thread
CPU pass, GPU off, total478.737s =0.267370 positions/s. prove_run393.785s includes
witness98.348s/load17.595s; seal84.824s overlaps. Receipt922,711,264B; fresh
verify42.709s+load13.681s; recheck34.395s+load10.739s. Isolated serialization,
startup fraction and steady slope unknown; not high-endGPU or8B privacy acceptance.

Next local: derive the lazy stack length from public launch row0 instead of a
stored per-column count; independently test all chunk schedules, reuse/failure
restarts and memory addresses, charging popcount/index costs. Owner next: native
poisoned hash/complete-receipt gates, then exposed memset/state incidence, capacity
and enclosing verified fixed-context1/2/4/8 clocks under shared locks. No native,
GPU, install, Git, production/runtime write, external message or escalation here.
Saved reports do not establish delivery or supervisor liveness.
'''
(P/'README.md').write_text(body+'''
Reproduce (each command enforces leaf limits):

```
python3 experiments/commitment-leaf-buffer-20261021/run_bounded.py probe.py
python3 experiments/commitment-leaf-buffer-20261021/run_bounded.py audit.py
```

The patch is `state-memset-elision.patch`; source/hash pins and commands are adjacent.
It is uncompiled and unapplied. `candidate.py::hash_columns` models both state choices;
`audit.py` imports neither candidate nor probe. Initial artifacts/failures are retained.
''')
if f'Run `{RUN}`' not in (B/'FINDINGS.md').read_text():
    with (B/'FINDINGS.md').open('a') as f:f.write('\n'+body)
(B/'progress'/f'{RUN}.md').write_text(body)
summary=f'''# ZKP efficiency progress

Cycle0123 complete — `{RUN}` — 2026-10-21 UTC.

**No proving speedup measured.** A CPU model preserves BLAKE3 column hashes while
reducing temporary hash-state requests by38MiB per frozen T128 commitment or68–72MiB
at counted T512. Pooled backing may stay allocated. Initializing the logical stack
in its first launch also removes the explicit full-state clear in the model;
actual GPU benefit remains unknown. Masks and salts are unchanged.

{metrics}
Nine LIVE queries/eight primary records retained. All35 prior hypotheses preserved;
two added. An uncompiled no-memset patch and review handoff are saved. Native
hash/receipt/privacy gates, actual capacity and complete GPU timing remain blocked
by this research lane's CPU-only scope; they are owner work.

{target}
Next: test public launch-position-derived stack length locally. Owner priority
remains complete GPU phases/capacity and verified resident1/2/4/8 workloads.

[Experiment](experiments/commitment-leaf-buffer-20261021/README.md),
[dated report](progress/{RUN}.md),
[handoff](handoffs/20261021-streaming-blake3-state.md).
Saved reports do not establish message delivery or supervisor liveness.
'''
(B/'PROGRESS.md').write_text(summary)
state=f'''# ZKP efficiency explorer — durable state

Cycle0123 COMPLETE: `{RUN}`. Checkpoint UTC: {now}.
Started07:18:54UTC; hard deadline07:38:54UTC; next cycle no earlier than
2026-10-21T08:18:54Z. AGENDA read at startup and checkpoint. Required prior memory,
782 sources and project notes snapshotted in
`experiments/commitment-leaf-buffer-20261021/startup/`.

No proving gain measured. StreamingBLAKE3 model passes {r['checks']:,} checks/27
synthetic shapes/11control types against installed independent blake3 1.0.9.
Independent labelled-subtree/source/cost audit passes {a['checks']:,} checks,
1024chunk counts/seven source pins. Diagnostic clocks/RSS and hard limits in
result.json/audit-result.json/commands.jsonl: one CPU, <5s/<30MiB RSS each.

193u32/column current state can be modelled with ceil(log2(ceil(rows/128))) CV
levels+count; capacity request saves38MiB at frozenT128 and68–72MiB at countedT512
per A/H commitment. Active CV traffic/compressions identical. First-launch local
count0 removes all state memset in model; length-only init also tested.
Full pooled backing may be larger than request; request reduction can saveZERO
backing. No native/CUDA execution, allocator/HWM/time or private receipt evidence.
Uncompiled first-launch/no-memset patch is narrower than dynamic-depth model.
No masks/salts/openings reused or original refusal/profile changed.

All35prior hypotheses retained;36 tested state candidate,37 new MARS screen.
Owner top4 unchanged: wholeGPU+verified resident1/2/4/8; DD/fidelity larger-context;
complete private phase/capacity clocks; native all-elevenFZC A/B. Prior dense bits,
NTT-cache, scratch-pool and other negatives retained. D37–D41 product direction
does not alter8B target; LOW/HIGH excluded from frozen geometry census.

{target}
Next local: derive lazy count from public first chunk index and independently
test chunk schedules, poisoned reuse/failure restart and address bounds; count
popcount/index costs. Owner next: native poisoned hash+receipt/privacy gates,
actual removed memset critical-path time/capacity and verified resident sweep.
Handoff `handoffs/20261021-streaming-blake3-state.md`; main/Claude reviews/integrates.

NineLIVEqueries/eightprimaryrecords appended. MARS2026 newly assessed, olderBLAKE3
stack sizing tested; BatchZK/ChimeraOct16/MORPH/Poseidon scope filtered. BLAKE3
fullcommit inspected; releaseAug20 yearunknown. MARSLICENSE/history cachemiss and
paper404,BLAKE3PDF unsupportedtype retained. No foreign code executed/installed.

Carried historical CPU nonDD8BT128L32: total478.737s=0.267370positions/s;
prove_run393.785s incl witness98.348s/load17.595s; seal84.824s overlaps.
Receipt922711264B; freshverify42.709s+load13.681s; recheck34.395s+load10.739s.
Not rerun/reverified; startup fraction/serialization isolation/steady slopeunknown.
No complete high-endGPU or8B privacy acceptance inferred.

Only research outside runtime written; no production/Git/receipt/calibration/
instruction/reviewer edits, build/GPU/install, external write/message or escalation.
Saved reports do not establish delivery/liveness. Final artifact audit follows.
'''
(B/'STATE.md').write_text(state)
handoff=f'''# Review handoff — streaming BLAKE3 scratch state — 2026-10-21

Candidate only; no native performance claim or production modification.

Interface: current `Gpu::commit_zk_chunked`, `commit_chunked`,
`commit_chunked_upload` in `hashline/src/gpu/cuda.rs`; shared
`k_hash_cols_stream` in `hashline/src/gpu/kernels.cu`. Seven pins in the
[source manifest](../experiments/commitment-leaf-buffer-20261021/source-manifest.json).

[Uncompiled patch](../experiments/commitment-leaf-buffer-20261021/state-memset-elision.patch)
sets stack_len=0 at public row0==0 and removes three whole-state clears.
It retains the existing24-level capacity and every compression. The stronger
dynamic-depth memory reduction is a separate model, NOT in the patch.
Every plan starts0, nonfinal boundaries align128rows, and launches are ordered.
Every consumed CV must have been written in the same proof; prior-proof bytes
and post-final stack lengths are never trusted. No extra kernel or sync proposed.

{metrics}
The model tested up to11056 rows, partial tails, multi-launch plans, poisoned
entire storage including count and fresh contents on reused backing. Endian,
root/counter, stale count, short depth/input and shape-growth controls fire.
The installed independent blake3 binary/version is pinned in hardware.json;
not the separately inspected upstream release. No native masks/proof ran.

Optional public depth ceil(log2(ceil(rows/128))) needs host/kernel offset agreement
and native arithmetic guards; single chunk uses0CVlevels. Request savings38MiB
T128 /68–72MiB T512 per commit are conditional frozenR9 inventories. T512 is not
admitted and LOW/HIGH are excluded. Pooled::get_mut returns FULL best-fit backing,
so actual clear bytes can exceed193*nn*4; physical savings may be zero even with
smaller requests. Do not sum sequential A/H requests as one peak or convert bytes
into elapsed savings. Added public conditional may have nonzero device cost.

Owner gates before integration: inspect current tree/pins; failing-first poisoned
buffer/native hashes for all three entrypoints, 1/2/3/many chunks and tails; salted
leaves, Merkle roots/paths, exact full receipt and fresh independent verify;
mask/RNG/transcript/privacy/refusal gates; allocation/launch/download failures,
resident fallback and non-ZK callers. The removed memset API's own error no longer
exists; infrastructure-failure behavior needs explicit review. No stale data may
be exported or consumed. Do not carry a TinyLlamaCPU acceptance to8B/GPU.

Then under owner shared build/heavy locks record native incidence, actual
capacity, clear/request sizes, exposed device/host clear time and enclosing
verified workloads at fixed context1/2/4/8 passes. Unknown removable fractionf
gives free-deletion bound1/(1-f), not a forecast. Falsify on any mismatch/stale
read/privacy drift or enclosing regression; deprioritize if measured effect
is immaterial. This handoff is saved locally, not a delivered external message.
'''
(B/'handoffs/20261021-streaming-blake3-state.md').write_text(handoff)
(P/'completion.json').write_text(json.dumps(dict(run_id=RUN,status='COMPLETE_PENDING_FINAL_ARTIFACT_AUDIT',
    checkpoint_utc=now,new_proofs=0,source_records_added=len(sources),hypotheses=37),indent=2)+'\n')
print(json.dumps(dict(checkpoint=now,source_records=len(sources),hypotheses=37,hash_checks=r['checks'],audit_checks=a['checks'])))
