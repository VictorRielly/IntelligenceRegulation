"""Final evidence integrity; read-only outside this research experiment."""
from pathlib import Path
import datetime,hashlib,json,resource,time

E=Path(__file__).resolve().parent
R=E.parents[1]
start=time.monotonic(); checks=0
def check(b):
    global checks
    checks+=1
    assert b

old_sources=(E/'startup/research__zkp-efficiency__sources.jsonl').read_bytes()
old_findings=(E/'startup/research__zkp-efficiency__FINDINGS.md').read_bytes()
check((R/'sources.jsonl').read_bytes()==old_sources+(E/'source-records.jsonl').read_bytes())
check((R/'FINDINGS.md').read_bytes().startswith(old_findings))
sources=[json.loads(x) for x in (R/'sources.jsonl').read_text().splitlines()]
check(len(sources)==744)
for s in sources[-7:]:
    check(s['access_date']=='2026-10-21')
    check(s['run_id']=='20261021T021854Z-dc9711cc')
    check(s['url'].startswith('https://'))
    check(not s['external_execution'] and not s['reproduced_performance'])

pins=json.loads((E/'source-pins.json').read_text())
for s in pins:
    check(hashlib.sha256(Path(s['path']).read_bytes()).hexdigest()==s['sha256'])
    check(hashlib.sha256((R/s['copy']).read_bytes()).hexdigest()==s['sha256'])

old=json.loads((R/'experiments/fzc-tail-boundary-20261021/hypotheses.json').read_text())
new=json.loads((E/'hypotheses.json').read_text())
check(len(new)==len(old)==34)
for a,b in zip(old,new):
    check(a['rank']==b['rank'])
    if a['rank'] not in [1,2,34]: check(a==b)

p=json.loads((E/'result.json').read_text()); c=json.loads((E/'census-result.json').read_text())
a=json.loads((E/'audit/independent_audit.json').read_text())
check(p['checks']==1418 and p['cases']==96 and p['messages']==320)
check(len(p['negative_control_types'])==17)
check(p['varying_trace']['lease_allocations']==a['counts']['bounded_growth_cache_native_allocation_events']==6)
check(p['varying_trace']['lease_cumulative_allocated_bytes']==a['counts']['bounded_growth_cache_cumulative_allocated_bytes']==32112)
check(p['varying_trace']['lease_peak_host_bytes']==31944)
check(c['total_interleavings']==120 and c['same_stream_post_sync_failures']==0)
check(all(a['checks'].values()))
for cmd in [json.loads(x) for x in (E/'commands.jsonl').read_text().splitlines()]:
    check(cmd['exit_code']==0 and cmd['elapsed_s']<60)
for f in [R/'STATE.md',R/'PROGRESS.md',R/'progress/20261021T021854Z-dc9711cc.md',E/'README.md']:
    t=f.read_text()
    check('0 / 0 / 0' in t)
    check('unmeasured' in t and 'unachieved' in t)
    check('20261021T021854Z-dc9711cc' in t)

changed_durable=[]
for s in json.loads((E/'startup/read-index.json').read_text()):
    path=Path(s['path'])
    if str(path).startswith(str(R)) and path.name in ['STATE.md','PROGRESS.md','FINDINGS.md','sources.jsonl']:
        continue
    if hashlib.sha256(path.read_bytes()).hexdigest()!=s['sha256']:
        changed_durable.append(str(path))

excluded={'artifact-manifest.json','artifact-audit-result.json','artifact_audit.py.stdout','artifact_audit.py.stderr'}
manifest=[]
for f in sorted(E.rglob('*')):
    if f.is_file() and f.name not in excluded:
        manifest.append({'path':str(f.relative_to(R)),'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'bytes':f.stat().st_size})
(E/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
checkpoint=json.loads((E/'checkpoint-updates.json').read_text())
for item in checkpoint:
    check(hashlib.sha256(Path(item['path']).read_bytes()).hexdigest()==item['sha256'])
report={'status':'PASS','checks':checks,'artifact_hashes':len(manifest),'source_pins':len(pins),'prior_sources_preserved':737,'new_sources':7,'prior_hypotheses_preserved':34,'changed_prior_ranks':[1,2,34],'concurrent_durable_changes':changed_durable,'concurrent_changes_read_and_snapshotted':True,'wall_seconds':time.monotonic()-start,'rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'audit_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
(E/'artifact-audit-result.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
