from pathlib import Path
import json,hashlib,re,datetime

exp=Path(__file__).resolve().parent
base=exp.parent.parent
run='20261020T181854Z-27090273'
checks=0
for r in json.loads((exp/'source-pins.json').read_text()):
    assert hashlib.sha256(Path(r['path']).read_bytes()).hexdigest()==r['sha256']
    assert hashlib.sha256((exp/r['snapshot']).read_bytes()).hexdigest()==r['sha256'];checks+=2
for r in json.loads((exp/'research-code-manifest.json').read_text()):
    assert hashlib.sha256((exp/r['path']).read_bytes()).hexdigest()==r['sha256'];checks+=1
rows=[json.loads(s) for s in (base/'sources.jsonl').read_text().splitlines()]
assert len(rows)==670
assert sum(x.get('run_id')==run for x in rows)==9;checks+=2
for p in [base/'STATE.md',base/'PROGRESS.md',base/'progress'/f'{run}.md',exp/'README.md',base/'handoffs/20261020-reversible-fraction-tree.md']:
    text=p.read_text()
    assert run in text
    assert 'No proving speed' in text or 'no native' in text.lower() or 'capacity negative' in text;checks+=2
    for m in re.finditer(r'\]\(([^)]+)\)',text):
        target=m.group(1)
        if not target.startswith(('http:','https:','#')):
            assert (p.parent/target).exists(),(str(p),target)
            checks+=1
cycle=json.loads((exp/'cycle-result.json').read_text())
assert cycle['status']=='COMPLETE'
assert cycle['new_verified_full_stack']['positions']==0;checks+=2
assert len(json.loads((exp/'hypotheses.json').read_text()))==22;checks+=1
startup_drift=[]
for r in json.loads((exp/'startup/manifest.json').read_text()):
    p=Path(r['path'])
    if '/research/zkp-efficiency/' not in str(p) and hashlib.sha256(p.read_bytes()).hexdigest()!=r['sha256']:
        startup_drift.append(str(p))
assert not startup_drift;checks+=1
out=dict(status='PASS',checks=checks,source_records=670,cycle_records=9,
         ranked_hypotheses=22,native_and_reference_pins=16,
         production_doc_changes_since_start=startup_drift,
         checkpoint_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
         scope='Artifact hashes, relative report links, counts and scope fields; no proof verification')
(exp/'checkpoint-validation.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out))
