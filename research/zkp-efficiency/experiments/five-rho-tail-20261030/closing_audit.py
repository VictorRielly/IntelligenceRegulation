from pathlib import Path
import json,hashlib,datetime,re
D=Path(__file__).resolve().parent;R=D.parent.parent
checks=0
def check(x):
 global checks
 assert x
 checks+=1
for n,x in json.loads((D/'history-pins.json').read_text()).items():
 b=(R/n).read_bytes();check(hashlib.sha256(b[:x['bytes']]).hexdigest()==x['sha256'])
p=json.loads((D/'prior-hypotheses.json').read_text());h=json.loads((D/'hypotheses.json').read_text());check(h[:len(p)]==p and len(h)==82)
for p in json.loads((D/'native-pins.json').read_text()):check(hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()==p['sha256'])
sources=[json.loads(l) for l in (R/'sources.jsonl').read_text().splitlines()]
check(len(sources)==1032);check(sum(x.get('run_id')=='20261030T005649Z-506c4db2' for x in sources)==5)
for n in ['result.json','cost-study.json','target-accounting.json','web-provenance.json','leading-hypothesis.json','ranking-current.json','rotation.json','completion.json','field-filter.json']:json.loads((D/n).read_text());checks+=1
check(len((D/'web-response-hashes.jsonl').read_text().splitlines())==9)
check(json.loads((D/'result.json').read_text())['new_proved_positions']==0)
check((R/'AGENDA.md').read_bytes()==(D/'prior-AGENDA.md').read_bytes())
for stage in ['prepare','compile','probe','compile-cpp','probe-cpp','audit']:
 x=json.loads((D/(stage+'-execution.json')).read_text());check(x['exit_code']==0);check(x['wall_s']<60);check(x['max_rss_kib']<512*1024)
for p in [D/'README.md',R/'handoffs/20261030-five-rho-tail.md',R/'STATE.md',R/'PROGRESS.md',R/'progress/20261030T005649Z-506c4db2.md']:
 for target in re.findall(r'\]\(([^)]+)\)',p.read_text()):
  if target.startswith('http'):continue
  check((p.parent/target).exists())
result=dict(status='PASS',checks=checks,utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),history_prefixes_preserved=True,hypotheses_preserved=80,source_records=1032,new_full_stack_proofs=0,target_reached=False,
 corrections='Initial closing script printed three broken dated-report links without asserting failure. Links repaired; this audit asserts every local link. Initial result retained; no arithmetic result changed.')
(D/'closing-audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
