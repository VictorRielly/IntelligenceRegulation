import hashlib
import json
from pathlib import Path
D=Path(__file__).resolve().parent
R=D.parent.parent
checks=0


def check(x):
    global checks
    checks+=1
    assert x,checks


def read(p):return json.loads(p.read_text())


old=(D/'startup/FINDINGS.md').read_bytes()
check((R/'FINDINGS.md').read_bytes().startswith(old))
old_sources=(D/'startup/sources.jsonl').read_bytes()
new_sources=(D/'source-records.jsonl').read_bytes()
check((R/'sources.jsonl').read_bytes()==old_sources+new_sources)
check(len((R/'sources.jsonl').read_text().splitlines())==1104)
old_h=read(D/'prior-hypotheses.json'); new_h=read(D/'hypotheses.json')
check(len(old_h)==97 and len(new_h)==98)
for before,after in zip(old_h,new_h):
    if before['rank']!=97:check(before==after)
    else:
        check(all(before[k]==after[k] for k in before if k!='disposition'))
for pin in read(D/'native-pins.json'):
    check(hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'])
    check(hashlib.sha256((D/pin['snapshot']).read_bytes()).hexdigest()==pin['sha256'])
check(all(x['unchanged'] for x in read(D/'owner-document-recheck.json')))
for name in ['result.json','audit-result.json']:
    check(read(D/name)['status']=='PASS')
for name in ['experiment-execution.json','audit-execution.json']:
    x=read(D/name)
    check(x['exit_code']==0 and x['wall_s']<60 and x['max_rss_kib']<512*1024)
    check(x['cpu_affinity_count']==1 and not x['gpu'])
for name in ['STATE.md','PROGRESS.md','progress/20261030T134123Z-9551f712.md']:
    t=(R/name).read_text()
    for literal in ['unmeasured','0 / 0 / 0','20261030T134123Z-9551f712']:
        check(literal in t)
for row in read(D/'sources-cycle.json'):
    check(row['access_date']=='2026-10-30')
    check(row['external_execution'] is False and row['reproduced_performance'] is False)
    check(row['inspected_commit_id'] is None)
    check(row['url'].startswith('https://'))
check(read(D/'completion.json')['target_achieved'] is False)
check(read(D/'target-accounting.json')['new_proved_positions']==0)

# The root compatibility seam is separately pinned rather than mixed into
# the active backend roster. It was read, never executed.
supp=[]
for path in ['zkp-core/src/pcs/backend.rs','hashline/src/pcs.rs']:
    p=Path('/home/victor/IntelligenceRegulation')/path
    b=p.read_bytes();name='compatibility__'+path.replace('/','__')
    (D/'native'/name).write_bytes(b)
    supp.append(dict(path=str(p),snapshot='native/'+name,sha256=hashlib.sha256(b).hexdigest(),bytes=len(b)))
(D/'supplementary-pins.json').write_text(json.dumps(supp,indent=2)+'\n')
manifest=[]
for p in sorted(D.rglob('*')):
    if p.is_file() and not p.is_symlink() and p.name not in ['artifact-manifest.json','final-audit-result.json']:
        b=p.read_bytes();manifest.append(dict(path=str(p.relative_to(D)),bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
(D/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
out=dict(status='PASS',checks=checks,artifacts=len(manifest),prior_findings_prefix_bytes=len(old),
         prior_sources=1095,new_sources=9,all_prior_hypotheses_preserved=True,
         active_native_pins=10,compatibility_pins=2,owner_document_drift=False)
(D/'final-audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out))
