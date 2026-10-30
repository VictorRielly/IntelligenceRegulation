import datetime, hashlib, json, pathlib
D=pathlib.Path(__file__).resolve().parent
R=D.parent.parent
run='20261030T064123Z-6637fd3d'
checks=0
def check(x):
    global checks
    assert x
    checks+=1
index=json.loads((D/'startup-index.json').read_text())
for p in index:check(hashlib.sha256((D/p['snapshot']).read_bytes()).hexdigest()==p['sha256'])
old_findings=(D/'startup/01-FINDINGS.md').read_bytes()
check((R/'FINDINGS.md').read_bytes()==old_findings+(D/'findings-append.md').read_bytes())
old_sources=(D/'startup/04-sources.jsonl').read_bytes()
check((R/'sources.jsonl').read_bytes().startswith(old_sources))
sources=[json.loads(s) for s in (R/'sources.jsonl').read_text().splitlines()]
new=json.loads((D/'sources-cycle.json').read_text())
check(len(sources)==1049);check(sources[-4:]==new)
for s in new:
    check(s['access_date']=='2026-10-30');check(s['reproduced_performance'] is False)
    check(all(k in s for k in ['publication_date','verified_update_date','inspected_commit_id','implementation_license']))
h=json.loads((D/'hypotheses.json').read_text());old=json.loads((D/'prior-hypotheses.json').read_text())
check(h[:86]==old);check(len(h)==88)
check(len(json.loads((D/'ranking-current.json').read_text())['global_priority'])>=3)
for p in json.loads((D/'source-pins.json').read_text()):
    check(hashlib.sha256((D/p['snapshot']).read_bytes()).hexdigest()==p['sha256'])
    check(hashlib.sha256(pathlib.Path(p['path']).read_bytes()).hexdigest()==p['sha256'])
for name in ['compile','probe','audit','record','close']:
    x=json.loads((D/(name+'-execution.json')).read_text());check(x['exit_code']==0);check(x['wall_s']<60);check(x['max_rss_kib']<512*1024)
result=json.loads((D/'result.json').read_text());check(result['status']=='PASS')
account=json.loads((D/'target-accounting.json').read_text())
for k in ['witness_s','proof_s','serialization_s','verification_s','startup_s','startup_fraction','steady_state_proved_tokens_per_s','total_workload_proved_tokens_per_s']:check(account[k] is None)
for path in [R/'STATE.md',R/'PROGRESS.md',R/'progress'/f'{run}.md',R/'handoffs'/'20261030-direct-limb-packing.md']:
    text=path.read_text();check(run in text);check('unmeasured' in text or 'unmeasured' in text.lower())
check('IN PROGRESS' not in (R/'STATE.md').read_text())
now=datetime.datetime.now(datetime.timezone.utc)
check(now<datetime.datetime(2026,10,30,7,1,23,tzinfo=datetime.timezone.utc))
for p in json.loads((D/'artifact-manifest.json').read_text()):
    if p['path']=='run_bounded.py':continue # Added this final-audit stage after close.
    check(hashlib.sha256((D/p['path']).read_bytes()).hexdigest()==p['sha256'])
audit=dict(status='PASS',checks=checks,finished_utc=now.isoformat(),prior_findings_and_sources_preserved=True,all86prior_hypotheses_exactly_preserved=True,
    full_stack_proofs=0,passes=0,positions=0,target_achieved=False,source_count=1049,hypotheses=88,production_source_pins_unchanged=True)
(D/'final-audit-result.json').write_text(json.dumps(audit,indent=2)+'\n')
excluded={'artifact-manifest.json','final-audit.stdout.log','final-audit.stderr.log','final-audit-execution.json'}
manifest=[dict(path=str(p.relative_to(D)),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in sorted(D.rglob('*')) if p.is_file() and p.name not in excluded]
(D/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(audit))
