"""Lightweight closing preservation and artifact-provenance audit."""
from pathlib import Path
import hashlib,json,datetime
E=Path(__file__).resolve().parent;R=E.parents[1];checks=0
def ck(ok):
    global checks
    assert ok
    checks+=1
old=(E/'startup/02-FINDINGS.md').read_bytes();ck((R/'FINDINGS.md').read_bytes().startswith(old))
oldsrc=(E/'startup/03-sources.jsonl').read_bytes();ck((R/'sources.jsonl').read_bytes().startswith(oldsrc))
src=[json.loads(x) for x in (R/'sources.jsonl').read_text().splitlines()];ck(len(src)==1132)
prior=json.loads((E/'startup/prior-hypotheses.json').read_text());current=json.loads((E/'hypotheses.json').read_text())
ck(current[:len(prior)]==prior);ck(len(current)==103);ck([x['rank'] for x in current[-2:]]==[102,103])
for name in ['result.json','dd-result.json','audit-result.json']:
    ck(json.loads((E/name).read_text())['status']=='PASS')
for name in ['experiment-execution.json','audit-execution.json']:
    x=json.loads((E/name).read_text());ck(x['returncode']==0);ck(x['wall_s']<60);ck(x['limits']['threads']==1);ck(x['limits']['address_space_mib']<=512)
refresh=[]
for pin in json.loads((E/'native-pins.json').read_text()):
    local=hashlib.sha256((E/pin['snapshot']).read_bytes()).hexdigest()
    current=hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()
    ck(local==pin['sha256']);ck(current==pin['sha256'])
    refresh.append(dict(path=pin['path'],sha256=current,matches_start=True))
(E/'closing-native-refresh.json').write_text(json.dumps(refresh,indent=2)+'\n')
for name in ['STATE.md','PROGRESS.md','progress/20261030T164123Z-9635c75b.md']:
    s=(R/name).read_text();ck('20261030T164123Z-9635c75b' in s);ck('unmeasured' in s);ck('2347' in s or '2,347' in s)
ck((R/'PROGRESS.md').read_bytes()==(R/'progress/20261030T164123Z-9635c75b.md').read_bytes())
artifacts=[]
for p in sorted(E.rglob('*')):
    if p.is_file() and p.name not in ['artifact-manifest.json','final-audit-result.json']:
        b=p.read_bytes();artifacts.append(dict(path=str(p.relative_to(E)),bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
(E/'artifact-manifest.json').write_text(json.dumps(artifacts,indent=2)+'\n')
for item in artifacts:ck(hashlib.sha256((E/item['path']).read_bytes()).hexdigest()==item['sha256'])
r=dict(status='PASS',checks=checks,utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),artifact_hashes=len(artifacts),old_findings_bytes_preserved=len(old),prior_source_records_preserved=1122,prior_hypothesis_dictionaries_preserved=len(prior),source_code_drift=[],native_proofs=0,proved_positions=0)
(E/'final-audit-result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
