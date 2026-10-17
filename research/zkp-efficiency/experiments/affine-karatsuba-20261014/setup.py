"""Research-only startup snapshot and source provenance; no production writes."""
import hashlib,json,pathlib,shutil,datetime

HERE=pathlib.Path(__file__).resolve().parent
ROOT=HERE.parents[1]
PROJECT=ROOT.parents[1]
prior=ROOT/'experiments/public-axis-row-factory-20261013'
for name in ('field_support.py','oracle.py','fixtures.py','source_port.py','baseline.py',
             'prepared.py','coefficients.py','polynomial_clause.py','polynomial_ir.py',
             'candidate.py','axis_factory.py','row_rounds.py','weighted_rounds.py',
             'weighted_experiment.py','prior_experiment.py'):
    shutil.copyfile(prior/name,HERE/name)
shutil.copyfile(prior/'experiment.py',HERE/'prior_axis_experiment.py')
records=[]
for p in sorted(HERE.glob('*.py')):
    if p.name=='setup.py':continue
    records.append(dict(source=str(prior/('experiment.py' if p.name=='prior_axis_experiment.py' else p.name)),
                        destination=p.name,sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
(HERE/'copy-provenance.json').write_text(json.dumps(records,indent=2)+'\n')
snap=HERE/'startup';snap.mkdir(exist_ok=True)
paths=[ROOT/n for n in ('AGENDA.md','STATE.md','FINDINGS.md','sources.jsonl','PROGRESS.md')]
paths += [PROJECT/'CLAUDE.md']
paths += [PROJECT/'docs/zkmatrix-poc'/n for n in ('MVP_STATUS.md','ZK60_DECISIONS.md',
            'ZK60_CODEX_FABLE_COORDINATION.md','ZK60_THROUGHPUT_TARGET.md')]
pins=[]
for p in paths:
    data=p.read_bytes();(snap/p.name).write_bytes(data)
    pins.append(dict(path=str(p),sha256=hashlib.sha256(data).hexdigest(),bytes=len(data)))
(HERE/'startup-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
sr=[json.loads(l) for l in (ROOT/'sources.jsonl').read_text().splitlines()]
latest=[]
for dirname in ('public-axis-row-factory-20261013','sc-szc-weighted-coefficients-20261013','sc-szc-row-polynomial-20261013'):
    p=ROOT/'experiments'/dirname/'result.json';d=json.loads(p.read_text())
    latest.append(dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),status=d.get('status'),
                       counts=d.get('counts'),controls=d.get('controls'),wall_seconds=d.get('wall_seconds'),
                       max_rss_kib=d.get('max_rss_kib'),proof_accounting=d.get('proof_accounting'),
                       projections=[{k:v for k,v in x.items() if k!='schedule'} for x in d.get('projections',[])]))
(HERE/'prior-results-read.json').write_text(json.dumps(latest,indent=2)+'\n')
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
(ROOT/'STATE.md').write_text(f'''# ZKP efficiency explorer — durable state

Cycle 0050 IN PROGRESS: `20261014T203626Z-4afb917a`.
Early checkpoint {now}; deadline 2026-10-14T20:56:26 UTC.
AGENDA, current target, required project/durable memory read/scanned; latest
three results and all {len(sr)} source records inspected and snapshotted.
Cycle49 has a passing synthetic result but no final report; preserve original
files and explicitly recover its evidence in this cycle's report.

Chosen question: replace public-shape length2 x length2 coefficient convolution
with three-product Karatsuba inside the tested SC_SZC row factory. Baseline
cycle49 public-axis factory; charge added sums/subtractions, dispatch and scratch.
Keep declared width, all original samples/folds/finals, masks and private data.
Falsification: any independent cube/MLE/extension mismatch, secret-dependent
schedule, larger weighted cost, native spill/enclosing regression.

Ranked: 1 owner dominant GPU SC_SZC plus recurring witness; 2 local fixed-affine
Karatsuba over tested factory chain; 3 owner exact fullK split-int16 down;
4 fresh resident complete-pass slope; 5 composition/lookup/PCS redesign.
Accepted complete8B ceiling unmeasured; entire historical one-block SC_SZC
removal bounds whole-test savings28.317%, not an8B throughput estimate.

Accepted independently verified complete private8B proofs/passes/tokens0.
CPU only, proof context null. Steady/total/startup fraction/witness/proof/
serialization/independent-verification clocks unmeasured. No prefill/resident/
decode proof. Target>=50/s unchanged; larger workloads allowed with quadratic
attention accounting and fresh masks. One cycle/hour; one thread/59s/512MiB.
No production/runtime/Git writes, builds/GPU/install/external actions.
Next: differential affine multiplication plus full synthetic round oracle;
record source search, counts, controls and owner integration gates.
''')
print(json.dumps(dict(snapshot_count=len(pins),source_records_read=len(sr),prior_results=[{k:v for k,v in r.items() if k not in ('projections','proof_accounting')} for r in latest]),indent=2))
