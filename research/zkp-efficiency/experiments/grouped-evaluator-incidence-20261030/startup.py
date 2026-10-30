"""Read/pin durable inputs without touching production or runtime."""
from pathlib import Path
import hashlib, json, datetime, re
E=Path(__file__).resolve().parent
R=E.parents[1]
P=R.parents[1]
files=[R/x for x in ['AGENDA.md','STATE.md','FINDINGS.md','sources.jsonl','PROGRESS.md']]
files += [P/'CLAUDE.md']+[P/'docs/zkmatrix-poc'/x for x in ['START_HERE.md','MVP_STATUS.md','ZK60_DECISIONS.md','ZK60_CODEX_FABLE_COORDINATION.md','ZK60_THROUGHPUT_TARGET.md']]
out=E/'startup';out.mkdir(exist_ok=True)
manifest=[]
for i,p in enumerate(files):
    b=p.read_bytes();s=b.decode();name=f'{i:02}-{p.name}'
    (out/name).write_bytes(b)
    headings=[{'line':j,'text':v} for j,v in enumerate(s.splitlines(),1) if v.startswith('#')]
    (out/(name+'.read-index.json')).write_text(json.dumps(headings,indent=2)+'\n')
    manifest.append(dict(path=str(p),snapshot='startup/'+name,bytes=len(b),sha256=hashlib.sha256(b).hexdigest(),lines=len(s.splitlines())))
sources=[json.loads(x) for x in (R/'sources.jsonl').read_text().splitlines() if x.strip()]
prior=R/'experiments/arithmetic-intensity-screen-20261030'
for name in ['hypotheses.json','ranking-current.json','result.json','audit-result.json','target-accounting.json']:
    b=(prior/name).read_bytes();(out/('prior-'+name)).write_bytes(b)
    v=json.loads(b);print(name, (str(v)[:700] if name!='hypotheses.json' else f'{len(v)} prior hypotheses loaded'))
(E/'startup-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(E/'durable-read-summary.json').write_text(json.dumps(dict(source_records=len(sources),findings_headings=len(json.loads((out/'02-FINDINGS.md.read-index.json').read_text())),source_categories=[x.get('title') for x in sources[-9:]]),indent=2)+'\n')
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
(R/'STATE.md').write_text(f'''# ZKP efficiency explorer — durable state

Cycle0168 IN PROGRESS: `20261030T164123Z-9635c75b`.
Started2026-10-30T16:41:23Z; early checkpoint{now}; deadline17:01:23Z.
Read AGENDA.md every cycle. Prior complete state and all durable inputs pinned
under experiments/grouped-evaluator-incidence-20261030/startup/.

Baseline: cycle0167 found zero direct legacy CUDA reducer incidence in current
private slots. No measured proving improvement or new proved position.
Now inspect actual GroupedEqRounds round arithmetic/traffic and public slot
descriptors; compare existing equality and liveness negatives before choosing
one bounded differential experiment. No owner R14 work duplicated.

Top priorities remain complete independently verified high-end GPU resident
1/2/4/8 workloads; admitted context/DD/fidelity scaling; exclusive native
phase clocks and actual capacities. All101 prior hypotheses preserved.
No GPU/build/install/Git/external write/private data/mask reuse authorized.
Witness/proof/serialization/verification/startup/initial-prefill clocks,
startup fraction and steady-state/total-workload target rates unmeasured.
New full-stack proofs / complete-model passes / proved positions:0/0/0.
Actual context:none; one low-priority CPU affinity, no GPU. Private8B>=50
proved tokens/s on RTX5090 or another named high-end GPU remains unachieved.

Next: source-backed incidence/cost accounting with independent shape and
arithmetic controls. Final checkpoint and progress report due before deadline.
''')
print(json.dumps(dict(files=len(manifest),source_records=len(sources),checkpoint=now)))
