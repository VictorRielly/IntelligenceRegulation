import datetime, hashlib, json, pathlib, shutil
D=pathlib.Path(__file__).resolve().parent
R=D.parent.parent
P=R.parent.parent
OLD=R/'experiments/five-rho-tail-20261030'
def sha(b):return hashlib.sha256(b).hexdigest()
def dump(name,obj):(D/name).write_text(json.dumps(obj,indent=2)+'\n')
pins=[]
for name in ['STATE.md','PROGRESS.md','AGENDA.md']:
 b=(R/name).read_bytes();(D/('prior-'+name)).write_bytes(b)
for name in ['hypotheses.json','ranking-current.json','rotation.json','target-accounting.json']:
 shutil.copyfile(OLD/name,D/('prior-'+name))
for rec in json.loads((OLD/'native-pins.json').read_text()):
 p=pathlib.Path(rec['path']);b=p.read_bytes(); dest=D/'context'/rec['snapshot'];dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(b)
 pins.append({'path':str(p),'snapshot':str(dest.relative_to(D)),'bytes':len(b),'sha256':sha(b),'matches_previous':sha(b)==rec['sha256']})
docs=['CLAUDE.md','docs/zkmatrix-poc/START_HERE.md','docs/zkmatrix-poc/MVP_STATUS.md','docs/zkmatrix-poc/ZK60_DECISIONS.md','docs/zkmatrix-poc/ZK60_CODEX_FABLE_COORDINATION.md','docs/zkmatrix-poc/ZK60_THROUGHPUT_TARGET.md']
for name in docs:
 p=P/name;b=p.read_bytes();dest=D/'documents'/p.name;dest.parent.mkdir(exist_ok=True);dest.write_bytes(b);pins.append({'path':str(p),'snapshot':str(dest.relative_to(D)),'bytes':len(b),'sha256':sha(b)})
dump('source-pins.json',pins)
history=[]
for name in ['FINDINGS.md','sources.jsonl']:
 b=(R/name).read_bytes();history.append({'path':name,'prefix_bytes':len(b),'prefix_sha256':sha(b),'lines':len(b.splitlines())})
dump('history-pins.json',history)
src=[json.loads(s) for s in (R/'sources.jsonl').read_text().splitlines()]
dump('source-memory-index.json',[{'id':s.get('id'),'title':s.get('title'),'url':s.get('url'),'publication_date':s.get('publication_date')} for s in src])
shutil.copyfile(OLD/'field.rs',D/'field.rs');shutil.copyfile(OLD/'native_host.rs',D/'native_host.rs')
dump('preparation.json',{'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'prior_sources':len(src),'prior_hypotheses':len(json.loads((D/'prior-hypotheses.json').read_text())),'changed_native_pins':[x['path'] for x in pins if x.get('matches_previous') is False]})
(R/'STATE.md').write_text('''# ZKP efficiency explorer — durable state

Cycle0156 IN PROGRESS: `20261030T015649Z-fd1dbb78`.
Started2026-10-30T01:56:49Z; deadline02:16:49Z. AGENDA read.
Early checkpoint: previous STATE/PROGRESS, complete hypothesis queue,
history prefix hashes, project docs and native/owner snapshots are retained
in experiments/opening-staging-20261030/. Prior findings remain unchanged.

Testing hypothesis82: opening-local public-rho/output staging versus
per-max4-chunk allocation/submission. Compare full staging and bounded
serial reuse; independent descriptor/offset, output-order, peak accounting,
partial-failure cleanup and fresh-call controls. No matrix scans, upload/
download bytes, randomness, pads or proximity are eliminated. Full staging
adds peak scratch; no native/GPU speed is implied by fewer API calls.
Baseline dev_fold_rows allocates rho/output per call; PCS already has every
opening rho and chunks4. Optional opening hook requires owner review.

Global priorities: verified complete high-endGPU resident1/2/4/8 workloads,
admitted context/DD/fidelity scaling, exclusive native phase clocks.
CPU-light only: one pinned nice19 worker,<=40sCPU/45salarm/50sparent,
384MiB address cap. No production/runtime/Git changes, GPU, native build,
installs, external writes/messages, privilege escalation or merge.
New independently verified full-stack proofs/passes/positions:0/0/0.
Witness/proof/serialization/verification/startup/initial-prefill clocks,
startup fraction,steady-state and total-workload rates unmeasured.
Actual model context/accelerator:none. Private8B >=50/s unachieved.
Next: complete bounded synthetic differential and cost/lifetime study,
LIVE primary search, checkpoint ranked hypotheses and dated progress.
''')
print(json.dumps({'status':'prepared','pins':len(pins),'changed_native_pins':[x['path'] for x in pins if x.get('matches_previous') is False],'sources':len(src)}))
