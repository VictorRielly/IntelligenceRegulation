"""Final preservation/provenance audit; does not rerun an experiment."""
import hashlib,json,time
from pathlib import Path
E=Path(__file__).resolve().parent;ROOT=E.parent.parent
checks=0
def check(v):
    global checks
    checks+=1
    assert v,checks
def sha(b):return hashlib.sha256(b).hexdigest()
start=time.monotonic()
startup=json.loads((E/'startup/read-manifest.json').read_text())
drift=[]
for pin in startup:
    p=Path(pin['path'])
    if p.name in ['STATE.md','PROGRESS.md']:
        check(sha((E/'startup'/p.name).read_bytes())==pin['sha256']);continue
    data=p.read_bytes();check(sha(data[:pin['bytes']])==pin['sha256'])
    if p.name not in ['FINDINGS.md','sources.jsonl']:check(len(data)==pin['bytes'])
prior=json.loads((E/'prior-hypotheses.json').read_text());new=json.loads((E/'hypotheses.json').read_text())
check(len(prior)==98);check(new[:98]==prior);check(len(new)==100)
check([x['rank'] for x in new][-2:]==[99,100])
source_lines=(ROOT/'sources.jsonl').read_text().splitlines();check(len(source_lines)==1113)
source=[json.loads(x) for x in source_lines];added=json.loads((E/'sources-cycle.json').read_text())
check(source[-9:]==added);check(len({x['id'] for x in added})==9)
for row in added:
    check(row['access_date']=='2026-10-30');check(row['inspected_commit_id'] is None)
    check(row['external_execution'] is False and row['reproduced_performance'] is False);check(row['url'].startswith('https://'))
pins=json.loads((E/'native-pins.json').read_text())
for pin in pins:
    check(sha((E/pin['snapshot']).read_bytes())==pin['sha256'])
    check(sha(Path(pin['path']).read_bytes())==pin['sha256'])
result=json.loads((E/'result.json').read_text());audit=json.loads((E/'audit-result.json').read_text())
check((result['checks'],result['negative_controls'])==(3012,861));check(audit['checks']==448)
for x in ['experiment','audit']:
    p=json.loads((E/(x+'-execution.json')).read_text());check(p['returncode']==0);check(p['wall_s']<=60);check(p['child_maxrss_kib']<512*1024)
acct=json.loads((E/'target-accounting.json').read_text());check(acct['new_proved_positions']==0);check(acct['private8B_50_proved_tokens_s_achieved'] is False)
for name in ['STATE.md','PROGRESS.md','progress/20261030T144123Z-85c19624.md','handoffs/20261030-receipt-sink-lifetimes.md']:
    txt=(ROOT/name).read_text();check('0166' in txt);check('No measured proving improvement' in txt or 'No native speed' in txt)
for i in range(1,14):check((E/f'web-{i}.json').exists())
files=[]
for p in sorted(E.rglob('*')):
    if p.is_file() and p.name not in ['artifact-manifest.json','final-audit-result.json','final-audit-execution.json']:
        data=p.read_bytes();files.append(dict(path=str(p.relative_to(E)),bytes=len(data),sha256=sha(data)))
(E/'artifact-manifest.json').write_text(json.dumps(files,indent=2)+'\n')
for pin in files:check(sha((E/pin['path']).read_bytes())==pin['sha256'])
out=dict(status='PASS',checks=checks,artifacts=len(files),prior_source_records_preserved=1104,prior_hypotheses_preserved=98,prior_findings_prefix_preserved=True,owner_document_drift=drift,active_source_pins=len(pins),wall_s=time.monotonic()-start)
(E/'final-audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
