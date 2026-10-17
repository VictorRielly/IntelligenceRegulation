#!/usr/bin/env python3
"""Audit captured artifacts; record live owner drift without replacing pins."""
import datetime
import hashlib
import json
from pathlib import Path
import re

X=Path(__file__).resolve().parent
R=X.parent.parent


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    checks=0
    for name in ['FINDINGS.md','sources.jsonl']:
        assert (R/name).read_bytes().startswith((X/'startup'/name).read_bytes());checks+=1
    records=[json.loads(l) for l in (R/'sources.jsonl').read_text().splitlines()]
    assert len(records)==325;checks+=1
    for d in records[-5:]:
        assert d['run_id']=='20261017T132624Z-393ef603' and d['access_date']=='2026-10-17' and d['url'].startswith('https://');checks+=1
    assert len({d['id'] for d in records[-5:]})==5;checks+=1
    drift=[]
    for f,pin in json.loads((X/'native-pins.json').read_text()).items():
        f=Path(f);assert sha(X/'native'/f.name)==pin;checks+=1
        current=sha(f)
        if current!=pin:drift.append(dict(path=str(f),expected=pin,current=current))
        else:checks+=1
    retained=json.loads((X/'pin-drift.json').read_text())['drift']
    assert drift==retained;checks+=1
    for d in drift:
        assert sha(X/'owner-drift'/Path(d['path']).name)==d['current'];checks+=1
    for d in json.loads((X/'owner-evidence-pins.json').read_text()):
        assert sha(Path(d['path']))==d['sha256'];checks+=1
    for name,source in [('result.json','run.py'),('audit-result.json','audit.py')]:
        d=json.loads((X/name).read_text());assert d['status']=='pass' and d['source_sha256']==sha(X/source);checks+=1
        assert d['wall_seconds']<60 and d['child_peak_rss_kib']<512*1024 and d['threads']==1;checks+=1
    for d in json.loads((X/'owner-accounting.json').read_text()):
        assert d['context']==32 and d['passes']==1 and d['target_credited_positions']==0;checks+=1
        assert d['serialization_s'] is d['steady_state_rate'] is d['full_startup_fraction'] is None;checks+=1
    for f in ['STATE.md','PROGRESS.md','progress/20261017T132624Z-393ef603.md','handoffs/20261017-fzc-public-constants.md']:
        assert '20261017T132624Z-393ef603' in (R/f).read_text();checks+=1
    for p in [R/'PROGRESS.md',R/'progress/20261017T132624Z-393ef603.md',R/'handoffs/20261017-fzc-public-constants.md',X/'README.md']:
        for target in re.findall(r'\]\(([^)]+)\)',p.read_text()):
            if not target.startswith('http'):
                assert (p.parent/target).resolve().exists(),(p,target);checks+=1
    now=datetime.datetime.now(datetime.timezone.utc).isoformat()
    output=dict(status='pass-with-live-source-drift',checks=checks,utc=now,live_owner_drift=drift,
                scope='captured snapshot, source-prefix, public log/guard pins and report links; no native acceptance or privacy gate; initial failed live-pin assertion preserved')
    (X/'artifact-audit.json').write_text(json.dumps(output,indent=2)+'\n')
    manifest=[]
    for p in sorted(X.rglob('*')):
        if p.is_file() and p.name!='artifact-manifest.json':manifest.append(dict(path=str(p.relative_to(X)),bytes=p.stat().st_size,sha256=sha(p)))
    (X/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    with (R/'STATE.md').open('a') as f:f.write(f'\nFinal artifact checkpoint {now}: {checks} checks passed against captured snapshots; {len(manifest)} experiment files pinned. Two live owner-file drifts explicitly retained; initial failed audit preserved. No native acceptance/privacy gate executed.\n')
    print(json.dumps(output))


if __name__=='__main__':main()
