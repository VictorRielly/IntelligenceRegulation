import hashlib,json,pathlib,resource,time
from cost_audit import audit
ROOT=pathlib.Path(__file__).resolve().parent
W=ROOT.parent.parent
t0=time.monotonic()
checks=audit(ROOT)
manifest=json.loads((ROOT/'artifact-manifest.json').read_text())
for x in manifest:
    assert hashlib.sha256((W/x['path']).read_bytes()).hexdigest()==x['sha256'];checks+=1
old_sources=(ROOT/'startup/research__zkp-efficiency__sources.jsonl').read_bytes()
old_findings=(ROOT/'startup/research__zkp-efficiency__FINDINGS.md').read_bytes()
assert (W/'sources.jsonl').read_bytes().startswith(old_sources);checks+=1
assert (W/'FINDINGS.md').read_bytes().startswith(old_findings);checks+=1
sources=[json.loads(x) for x in (W/'sources.jsonl').read_text().splitlines()]
new=[json.loads(x) for x in (ROOT/'source-records.jsonl').read_text().splitlines()]
assert sources[-len(new):]==new;checks+=1
assert all(x['run_id']=='20261021T051854Z-3d9d2756' for x in new);checks+=1
old=json.loads((ROOT/'prior-hypotheses.json').read_text());now=json.loads((ROOT/'hypotheses.json').read_text())
assert [x['rank'] for x in old]==[x['rank'] for x in now];checks+=1
assert all(x==y for x,y in zip(old,now) if x['rank'] not in (2,25));checks+=1
assert len(old)==len(now)==34;checks+=1
for name in ['STATE.md','PROGRESS.md','progress/20261021T051854Z-3d9d2756.md']:
    s=(W/name).read_text();assert '20261021T051854Z-3d9d2756' in s;checks+=1
    assert 'unmeasured' in s;checks+=1
for pin in json.loads((ROOT/'source-manifest.json').read_text()):
    assert pathlib.Path(pin['path']).read_bytes()==(ROOT/pin['snapshot']).read_bytes();checks+=1
result=dict(status='PASS_COST_AND_ARTIFACT_AUDIT',checks=checks,
            immutable_artifacts=len(manifest),prior_sources=len(old_sources.splitlines()),
            appended_sources=len(new),prior_findings_lines=len(old_findings.splitlines()),
            hypotheses_retained=len(now),live_source_pins=6,
            wall_seconds=time.monotonic()-t0,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)
(ROOT/'artifact-audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
