"""Retain public-only startup evidence and establish an early checkpoint."""
import datetime, hashlib, json, pathlib, shutil
HERE=pathlib.Path(__file__).resolve().parent
ROOT=HERE.parent.parent
PROJECT=ROOT.parent.parent
PRIOR=ROOT/'experiments/current-profile-mask-census-20261029'
def sha(b): return hashlib.sha256(b).hexdigest()
def write(name,obj): (HERE/name).write_text(json.dumps(obj,indent=2)+'\n')
(HERE/'startup').mkdir(exist_ok=True)
paths=[ROOT/x for x in ('AGENDA.md','STATE.md','FINDINGS.md','sources.jsonl','PROGRESS.md')]
paths += [PROJECT/x for x in ('CLAUDE.md','docs/zkmatrix-poc/START_HERE.md','docs/zkmatrix-poc/MVP_STATUS.md','docs/zkmatrix-poc/ZK60_DECISIONS.md','docs/zkmatrix-poc/ZK60_CODEX_FABLE_COORDINATION.md','docs/zkmatrix-poc/ZK60_THROUGHPUT_TARGET.md')]
paths += [PRIOR/x for x in ('result.json','audit-result.json','final-audit-result.json','counts.json','hypotheses.json','cycle-ranking.json','native-pins.json','target-accounting.json')]
manifest=[]
for p in paths:
 b=p.read_bytes(); name=str(p.relative_to(PROJECT)).replace('/','__')
 (HERE/'startup'/name).write_bytes(b)
 lines=b.decode().splitlines()
 manifest.append(dict(path=str(p),snapshot='startup/'+name,sha256=sha(b),bytes=len(b),lines=len(lines),headings=[dict(line=i+1,text=s) for i,s in enumerate(lines) if s.startswith('#')]))
write('required-reading-index.json',manifest)
sources=[json.loads(x) for x in (ROOT/'sources.jsonl').read_text().splitlines() if x.strip()]
write('prior-source-index.json',[dict(id=x.get('id'),url=x.get('url'),title=x.get('title')) for x in sources])
write('hypotheses.json',json.loads((PRIOR/'hypotheses.json').read_text()))
pins=json.loads((PRIOR/'native-pins.json').read_text())
(HERE/'native').mkdir(exist_ok=True)
for row in pins:
 b=pathlib.Path(row['path']).read_bytes(); assert sha(b)==row['sha256']
 (HERE/row['snapshot']).write_bytes(b)
write('native-pins.json',pins)
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
(ROOT/'STATE.md').write_text(f'''# ZKP efficiency explorer — durable state

Cycle0143 IN PROGRESS: `20261029T125649Z-54c94436`.
Started2026-10-29 12:56:49UTC; early checkpoint {now}.
Deadline13:16:49UTC; next cycle no earlier than13:56:49UTC.

Read current agenda, target, durable state, prior results and owner direction.
Prior full findings, sources and all60 hypotheses retained under
experiments/pair-tile-dataflow-20261029/startup and hypotheses.json.
Current question: can K2/4 pair tiling share current-call public equality
loads/sums without extra public-sum buffers, retaining all fresh private reads?
Use R13 census, independent schoolbook/MSB-fold references and negative
controls. Test logical traffic/accumulator cost and bounded CPU diagnostics;
no native GPU, full proof or speed claim. Global priorities unchanged:
whole-prover named high-endGPU and verified resident1/2/4/8 workloads;
admitted context/DD fidelity scaling; exclusive phase/capacity clocks.

No newly verified full-stack proofs/passes/positions:0/0/0. Witness/proof/
serialization/verification clocks,startup fraction,steady/total rates unknown.
No actual model context, accelerator, prefill, resident series or decode ran.
Target remains complete private8B >=50 proved tokens/s. Prior results and
negative findings preserved. Only research outside runtime may be written.
''')
print(json.dumps(dict(startup_files=len(manifest),prior_sources=len(sources),native_pins=len(pins),early_checkpoint=now)))
