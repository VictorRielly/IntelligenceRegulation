from pathlib import Path
import json,datetime,hashlib
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
RUN='20261020T191854Z-93bbe548';now=datetime.datetime.now(datetime.timezone.utc).isoformat()
def read(name):return json.loads((HERE/name).read_text())
probe,audit,account=read('result.json'),read('validation-result.json'),read('forest-result.json')
assert all(x['status']=='PASS' for x in [probe,audit,account])
rows=[r for r in account['profiles'] if r['model']=='8B' and r['T']==128 and r['fmax']==16]
nondd=next(r for r in rows if not r['dd']);dd=next(r for r in rows if r['dd'])
def arm(r,m,k):return r['arms'][m]['counts'][k]
new_sources=[json.loads(s) for s in (ROOT/'sources.jsonl').read_text().splitlines() if json.loads(s).get('run_id')==RUN]
assert len(new_sources)==12
table='''| One 8B T128 block forest, frontier depth 16 | non-DD | DD |
|---|---:|---:|
'''
fields=[('Source leaf generations, every arm','direct','source_reads'),
 ('Direct build Fp2 multiplications','direct','build_muls'),
 ('Disposable tile build multiplications','batch','build_muls'),
 ('Tile recovery multiplications','batch','restore_muls'),
 ('Tile recovery inversions','batch','inversions'),
 ('Cached recovery multiplications','cached','restore_muls'),
 ('Cached recovery inversions','cached','inversions'),
 ('Additional cache-key source reads','cached','cache_key_reads')]
for label,mode,key in fields:table+=f'|{label}|{arm(nondd,mode,key):,}|{arm(dd,mode,key):,}|\n'
clocks=f'''Main probe: {probe['elapsed_s']:.6f} s / {probe['maxrss_KiB']:,} KiB RSS.
Symbolic accounting: {account['elapsed_s']:.6f} s / {account['maxrss_KiB']:,} KiB.
Independent audit: {audit['elapsed_s']:.6f} s / {audit['maxrss_KiB']:,} KiB.
Intel Core Ultra 9 185H, Linux/WSL2; one worker on first allowed CPU core,
nice19; each leaf has 59 s CPU/alarm, 60 s parent timeout and 512 MiB address
space cap. Estimated experiment memory64MiB. No native build, GPU job,
dependency installation or external code execution. These clocks time research
checking, not witness/proof phases or an old/new native benchmark.
'''
metrics='''New completed independently verified full-stack proofs / passes / positions:
**0 / 0 / 0**. Actual model context and accelerator: **none**. Research device:
**Intel Core Ultra 9 185H CPU, no GPU**. Witness, proof, serialization and
verification clocks: **unmeasured**. Startup duration/fraction, steady-state and
total-workload proved rates: **unmeasured**. No long-context prefill, repeated
resident-model pass or decode was run. Symbolic T32/T64/T128/T512 fixtures are
cost studies, and T512 is counted geometry, not an admitted proof result.
Longer workloads remain allowed; dense attention may grow quadratically with
context. The complete private8B >=50 proved positions/s target on RTX5090 or
another named high-endGPU remains unachieved.
'''
historical='''Historical diagnostic carried from the prior checkpoint, not rerun or
independently reverified here: non-DD 8B T128, L32, one 16-thread CPU pass,
GPU off; total478.737s =0.267370positions/s. prove_run393.785s includes
witness98.348s/load17.595s; seal84.824s includes overlapping subwork.
Receipt922,711,264B; fresh verify42.709s + public load13.681s; recheck34.395s
+load10.739s. Isolated serialization, startup fraction and steady slope remain
unknown. This is a historical CPU result, not a high-endGPU result.
'''
next_local='''Next local experiment: independently enumerate exact public exponential-table
outputs versus score resolution/f_e and include0 in the DD cardinality. Pin the
owner's r11 public table/count definitions; distinguish F_P output precision
from S12/finer exponential inputs. Check the cited32-entry cap and cost any
larger dictionary domain/limbs/lookups without admitting a new profile.
The owner already models S12 as DD-infeasible; reproduce the actual public
cardinality before carrying DD savings to a D32 fidelity configuration.
Avoid duplicating native implementation or model-quality/calibration jobs.
'''
next_owner='''Owner next: whole-prover GPU phase/capacity clocks and independently verified
fixed-context resident1/2/4/8 workloads, DD context scaling and all-elevenFZC
compiler A/B under shared build/heavy locks. No such job was launched here.
'''
body=f'''Cycle0111 — `{RUN}` — 2026-10-20 UTC; checkpoint{now}.

**No proving speed improvement found.** The disposable reversible-subtree
schedule passes exact arithmetic and ordered-consumer checks. At matched
frontier/consumer settings it has the same source rereads and the same selected
peak as direct subtree reduction, with extra build/recovery arithmetic. Demote
this schedule. This is a bounded operation/payload negative, not a universal
GPU timing result or a new private protocol.

The baseline is frozenR9 U8 helper payload420.25MiB non-DD /390.25MiB DD for one
8B T128 block layout. A prospective replacement already has a direct adaptive
frontier/tiled consumer at36.022216796875MiB of selected arrays. The last cycle's
whole-column reversible buffer requires80–128MiB selected storage at2^21 leaves.
No native helper, commitment or proof work has been removed in either study.

`Frontier(read,n,f,mode,leaf_inverse).layer(d)` retains immutable upper levels
through depthf. Belowf, direct mode reduces only the source subtrees required
for that layer. Batch mode builds a disposable leaf tile ofB=n/2^f, then reverses
it back to the requested layer. Every global message precedes its challenge;
discarded tiles must be rebuilt on the next scan. Cached mode uses current-
attempt U8 inverses only for original right leaves at the last expansion and
charges a separate original-source key evaluation per such inverse.

For one below-frontier scan at depthd, direct mode mixes n-2^d internal nodes.
Disposable tiles mix n-2^f nodes first, then recover2^d-2^f nodes. Thus the
extra construction alone is3(2^d-2^f)Fp2 multiplications, besides positive
recovery costs, while the source scan is identical. Smaller scratch is not
evidence of a saved scan. This tests natural-order strided storage; OpenVM's
bit-reversed/coalesced GPU layout is a separate untested implementation.

{table}
Both non-DD/DD cases include84 columns, one global table and the preliminary
root-forest source pass. They model one block's lookup forest, **not32 complete
model passes or a32-layer execution**. Consumer folds/equality work is shared
between the three arms and is additional to these source-service counts.
The cache also adds unknown key evaluation, checking and lookup costs; it is
not fresh proof randomness and is never retained across alpha/gamma attempts.

All three arms peak at36.022216796875MiB selected payload at frontier16,
including immutable frontier/root forest, full resident capacities/inactive
tails, source tile, batch-prefix scratch, consumer tile, equality factors and
the prior scalar allowance. The largest column has2^21 leaves andB32. At
frontier15/B64, peak34.022216796875MiB in every arm, but source reads rise to
364,970,496 /341,377,536; the smaller frontier is available to direct reduction
too. Forty profiles (10 input geometries times4 frontier caps) compare all
three arms. Counts are symbolic; exact-capacity backing/release is assumed.
Original A/source owners, histogram/cache allocation, private masks/CFS/PCS,
allocator pools, driver memory and transfer costs remain excluded. No fit,
actual-device peak or enclosing runtime saving is established.

Even free deletion of an unknown exclusive affected fractionf of complete
proving has ceiling1/(1-f); this candidate adds costs and removes no measured
native work. There is no numerical complete high-endGPU forecast. Falsification
of the proposed scan-saving benefit is already observed: identical source
counts plus extra arithmetic at an equal peak. Revisit only a materially
different retention/algorithm or a measured GPU access effect. Cross-tile
batch inversion and alternative protocol scheduling are not tested here.

Validation: {probe['checks']:,}main checks,45synthetic fixtures over2..64leaves,
{probe['consumer_cases']}unmasked cubic consumers, {probe['layer_cases']}layers
and63negative controls. U8 affine leaves, table-style multiplicities including0,
full-extension fractions, zero/one/non-base challenges, ordered layer MLEs and
both numerator/denominator components are covered. Root-preserving swaps change
the ordered children; stale-attempt inverse reuse fails the reference; zero
denominators refuse even at zero numerator or absent looked-table value.
No native refusal/RNG/transcript order or private view has been validated.

Independent audit: {audit['checks']:,}checks,354consumers/444layers, Boolean MLE
and native MSB point reversal,528allocation events,22source pins and all10prior
profile counts. Expected values use tuple polynomial convolution and immutable
trees, with a separate cubic round evaluator and enumerated operation graph.
The direct arm exactly reproduces prior source and tree-work counts.
One initial audit failed on imported-snapshot pin bookkeeping: the local runner
was adapted at the pinned path and prior outputs had been renamed. Arithmetic
checks had passed. Original snapshots were preserved under corrected paths;
source hashes stayed unchanged and the rerun passes. Initial stderr and the
failed command are retained in `initial-audit-failure.json` and `commands.json`.

{clocks}
12native LIVE queries /12source records appended670->682. Source scopes,
verified histories, exact URLs and access/license/commit limits are retained
in source-records.json and the append-only ledger. OpenVM release and streaming
sumcheck source were refreshed; current code timestamps/full commits were not
established. Two older leads first enter the ledger: NeutronNova group folding
(received2024-10-09,revised2026-08-18) and the Scorpius/Orion correction
(2024-07-18,revised2025-02-14). They motivate source-binding/repaired-PCS checks,
not a drop-in backend. Nova's MIT body was inspected; its NeutronNova source
fetch failed, and no commit was inspected. Hobbit's chunk-folding input-
consistency discussion was revisited. No author speed is reproduced.

The detailed September29 quantization paper separates QDQ utility simulation
and actual small-model proving; some attention/RoPE/reduction operators remain
floating in its utility evaluator. This sharpens the D32 exactness screen;
its large-model projection numbers are not complete private8B evidence.
Owner r11 already distinguishes F_P9->12 from finer S12 and models the latter
as incompatible with DD's cap. The next local question is to reproduce exact
public-table/cardinality counts, complementing the owned fidelity lane.

23ranked hypotheses retained. Top3 are completeGPU+resident workloads, DD
context/fidelity scaling and exclusive phase/capacity telemetry. All-elevenFZC
A/B remains ahead of lookup protocol redesign. Rank21 now includes this
disposable-tile negative; rank23 adds exact D32/DD public-cardinality work.
Rotation this cycle emphasizes memory, sumcheck/GKR, batching, quantization,
source binding and composition. Next emphasis: public arithmetic/cardinality,
then GPU NTT/commitment freshness and the owner whole-prover evidence.

{metrics}
{historical}
{next_local}
{next_owner}
Only research excluding runtime written. No production/reviewer/instruction/
Git edits, GPU/build/install/external writes or messages, purchases, escalation
or merge. D32 and narrow D33/D34/D35 scopes, DDprivacy gate and R9N-r9-a/b
remain binding. No mask reuse, repeated private opening, weaker privacy or
changed native refusal/transcript/RNG schedule is authorized. Main/Claude
reviews any integration; saved reports are not evidence of message delivery
or supervisor liveness.
'''
(HERE/'README.md').write_text('# Disposable reversible subtrees and immutable frontier\n\n'+body+'''

Reproduce from the research directory (stdlib only):

```
python3 experiments/reversible-subtree-frontier-20261020/run_bounded.py probe.py
python3 experiments/reversible-subtree-frontier-20261020/run_bounded.py account.py
python3 experiments/reversible-subtree-frontier-20261020/run_bounded.py validate.py
```

Seed20261020111. Source pins, input geometry, synthetic fixtures, allocation
events, hardware, commands and research-code hashes are retained alongside.
Do not rerun init.py/record_research.py/checkpoint.py for benchmark reproduction;
they create cycle bookkeeping and reports.
''')
(ROOT/'progress'/f'{RUN}.md').write_text('# ZKP efficiency cycle0111\n\n'+body)
marker='## Cycle0111 — disposable reversible tiles: matched-budget cost negative (2026-10-20)'
with (ROOT/'FINDINGS.md').open('a') as f:f.write('\n'+marker+'\n\n'+body+'\n[Experiment](experiments/reversible-subtree-frontier-20261020/README.md).\n')
short=f'''# ZKP efficiency progress

Cycle0111 complete — `{RUN}` — 2026-10-20 UTC.

**No proving improvement found.** Disposable reversible tiles match direct
subtree reduction's ordered arithmetic but save no source scans. At the frozen
8B T128 count geometry, both use36.022MiB selected payload; tiles add field
operations and inversions. Existing leaf reciprocals reduce some inversions
but add source-key reads. This schedule is demoted.

Main3,470checks/472unmasked consumers and independent6,280checks/354consumers
pass. One initial snapshot-pin audit failure was corrected; failure evidence
is retained. Probe0.313s, audit0.349s, accounting0.296s; one CPU worker, no GPU.
These are synthetic algebra and symbolic one-block cost studies.

12LIVE queries/12records saved: OpenVM, streaming sumcheck, quantization,
Hobbit and newly screened older NeutronNova/Scorpius. No author gain reproduced.
23ranked hypotheses retained; top3 remain fullGPU+verified resident passes,
DDscaling/fidelity and complete phase/capacity clocks.

{metrics}
Next local: exact public exponential-table cardinality versus DD's32-entry cap
under proposed fidelity precision. Owner: verified resident1/2/4/8,DDscaling,
GPU clocks and all-elevenFZC A/B. No private mask/opening reuse authorized.

[Experiment](experiments/reversible-subtree-frontier-20261020/README.md),
[dated report](progress/{RUN}.md),
[review note](handoffs/20261020-reversible-subtree-frontier.md).
Research-only writes; saved reports do not establish external delivery.
'''
(ROOT/'PROGRESS.md').write_text(short)
(ROOT/'STATE.md').write_text(f'''# ZKP efficiency explorer — durable state

Cycle0111 COMPLETE: `{RUN}`. CheckpointUTC {now}.
Deadline19:38:54UTC; next cycle no earlier than20:18:54UTC.
Evidence: experiments/reversible-subtree-frontier-20261020/.
AGENDA/durable memory,670starting source records,latest0110 results and required
project instructions/status/decisions/coordination/target read; hashes retained.
Source ledger682records. Prior findings/negative evidence preserved.

No proving improvement. Disposable reversible tiles plus immutable frontier
have identical source scans to direct reduction and extra field work. One8B
T128block lookup forest, nonDD/DD:313065984/293011968source generations;
allarms36.022216796875MiB selected peak at frontier16/B32 for max2^21leaves.
Batch adds287834112/270139392build and467140608/440598528recovery Fp2mults,
36175872/33226752inversions. Current-attempt leafcache still adds35389440/
33619968keyreads and30277632/27328512inversions. No native work removed.
Matched schedule cost negative only; cross-tilebatch/coalescedGPU not tested.

Main3470checks/45fixtures/472consumers/592layers/63controls; independent
6280checks/354consumers/444layers/528capacityevents/22pins/10priorcounts pass.
Probe0.313116s/12896KiB; audit0.349016s/16696KiB; account0.296347s/16904KiB.
Seed20261020111,oneCPUworker/nice19,59sCPU/alarm,60sparent,512MiBAS,
64MiBestimate. IntelCoreUltra9 185H/WSL2. Initial pin-bookkeeping auditfailure
preserved; corrected original-snapshot paths pass without changing sourcehashes.

12LIVEqueries/12records; refreshedOpenVM/streaming/quantization/Hobbit, newly
assessed olderNeutronNova+Scorpius. NovaMITbody inspected; no algorithmcommit
inspected. GitHubcache/license/source/date limits recorded; no author gain
reproduced.23rankedhypotheses; rank21tile negative,rank23D32/DDcardinality new.
Top3 wholeGPU+verifiedresident1/2/4/8,DDcontext/fidelity,completeclocks/capacity.
Ownerall-elevenFZC A/B remains ahead of lookup protocol redesign.

{next_local}
{next_owner}
{metrics}
{historical}
Onlyresearchexcludingruntimewritten. No production/reviewer/instruction/Git
changes,GPU/build/install/externalwrites/messages/purchases/escalation/merge.
Fresh masks/currentprivacy scopes/R9conditions remain; no native refusal/RNG/
transcript changes authorized. Reports do not establish delivery or liveness.
''')
handoff=f'''# Disposable reversible tiles — negative integration note

Cycle0111, `{RUN}`. **Do not port this schedule as a saving.**
Research patch/interface: [frontier.py](../experiments/reversible-subtree-frontier-20261020/frontier.py),
`Frontier(read,n,f,mode,leaf_inverse).layer(d)` and `consume(...)`.
Read returns the original ordered `(numerator,denominator)` native-field pair.
Modes: direct reduction, per-tile batch recovery, final-leaf reciprocal cache.
The last callback reads the current attempt's original source key; this read
is charged and cannot be reused across proof attempts.

At the matched8B T128one-block schedule, allarms36.022MiB selected peak and
identical313.066M/293.012M nonDD/DDsourcegenerations. Tiles add construction,
recovery and inversions; cached leaf recovery adds35.389M/33.620M keyreads.
No native work removed. Whole-column capacity negative and earlier naive
per-intermediate-mask negative remain. Per-tile inversion is tested; cross-tile
batch inversion or coalesced GPU layouts would be different experiments.

Main3470checks/472consumers/63controls; independent6280checks/354consumers,
528capacityevents,22pins,10prior count profiles pass. Source hashes,commands,
seed,source/refusal/order controls and corrected pin-bookkeeping failure are
retained in the [experiment](../experiments/reversible-subtree-frontier-20261020/README.md).

Native eventual seams remain frozenR9 `protocol::lookup_values_at` (line394),
`u8_denominator_inverses` (712), `helper_one` (764), `write_h` (850), and
`argument::helper_sum` (934)/SC_TAB. This supplies no production patch or private
GKR, CFS, original-A input-consistency, commitment or PCS adapter. Publishing
the unmasked rows/roots would reveal data. Native refusal/RNG/transcript order,
numeric Id/point mapping, whole-proof security and current privacy gates must
be reviewed independently. No mask/opening reuse or profile change authorized.

Next local: exact public LUT/cardinality census for D32 versus DD, avoiding
duplicate owned fidelity/native jobs. Owner's GPU/resident/phase work and
all-elevenFZC A/B take priority. Main/Claude reviews any integration; no merge.
'''
(ROOT/'handoffs/20261020-reversible-subtree-frontier.md').write_text(handoff)
metrics_json=dict(proofs=0,passes=0,positions=0,context_length=None,accelerator=None,research_device='Intel Core Ultra9 185H CPU; no GPU',witness_s=None,proof_s=None,serialization_s=None,verification_s=None,startup_s=None,startup_fraction=None,steady_rate=None,total_rate=None)
(HERE/'cycle-result.json').write_text(json.dumps(dict(status='COMPLETE',cycle='0111',run_id=RUN,checkpoint_utc=now,probe=probe,audit=audit,accounting={k:v for k,v in account.items() if k!='profiles'},source_records=12,source_ledger=682,ranked_hypotheses=23,new_verified_full_stack=metrics_json,next_local=next_local,next_owner=next_owner),indent=2)+'\n')
manifest=[]
for p in sorted(HERE.rglob('*.py')):
    b=p.read_bytes();manifest.append(dict(path=str(p.relative_to(HERE)),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b)))
(HERE/'research-code-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(dict(status='checkpointed',run_id=RUN,utc=now,probe_checks=probe['checks'],audit_checks=audit['checks'],source_records=len(new_sources),research_python_files=len(manifest))))
