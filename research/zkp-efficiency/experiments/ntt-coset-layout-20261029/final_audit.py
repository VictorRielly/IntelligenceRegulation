import os,resource,signal,time,json,hashlib,datetime,re
from pathlib import Path
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_CPU,(30,30))
resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2));signal.alarm(35)
H=Path(__file__).resolve().parent;R=H.parent.parent;t0=time.perf_counter()
checks=0
def check(ok):
    global checks
    checks+=1
    assert ok,checks
def sha(b):return hashlib.sha256(b).hexdigest()
check((R/'FINDINGS.md').read_bytes().startswith((H/'startup/FINDINGS.md').read_bytes()))
prior=(H/'startup/sources.jsonl').read_bytes();current=(R/'sources.jsonl').read_bytes()
check(current.startswith(prior))
rows=[json.loads(x) for x in current.splitlines()]
check(len(rows)==891 and len(rows[882:])==9)
for row in rows[882:]:
    check(row['prior_exact_url_records']==sum(r.get('url')==row['url'] for r in rows[:882]))
    for key in ('access_date','date_evidence','publication_date','verified_update_date',
                'implementation_license','inspected_commit_id','url','assessment'):
        check(key in row)
    check(row['access_date']=='2026-10-29' and not row['reproduced_performance'])
old=json.loads((H/'startup/prior-hypotheses.json').read_text())
new=json.loads((H/'hypotheses.json').read_text())
check(len(old)==51 and len(new)==52 and old==new[:51])
for row in json.loads((H/'native-pins.json').read_text()):
    for p in (Path(row['path']),H/row['snapshot']):check(sha(p.read_bytes())==row['sha256'])
direction=[]
for row in json.loads((H/'startup-manifest.json').read_text()):
    p=Path(row['path'])
    if p.name in ('STATE.md','FINDINGS.md','PROGRESS.md','sources.jsonl'):continue
    b=p.read_bytes();same=sha(b)==row['sha256'];check(same)
    direction.append(dict(path=str(p),sha256=sha(b),unchanged=same))
(H/'final-direction-check.json').write_text(json.dumps(direction,indent=2)+'\n')
a=json.loads((H/'target-accounting.json').read_text())
for key in ('startup_s','prefill_s','startup_fraction','witness_s','proof_s',
            'serialization_s','verification_s','proof_latency_s','proof_bytes',
            'steady_state_positions_s','total_workload_positions_s','context_length'):check(a[key] is None)
for key in ('independently_verified_full_stack_proofs','passes','countable_positions'):check(a[key]==0)
check(json.loads((H/'audit-result.json').read_text())['status']=='PASS')
reports=[R/'STATE.md',R/'PROGRESS.md',R/'FINDINGS.md',
 R/'progress/20261029T045649Z-6e004a83.md',
 R/'handoffs/20261029-split-coset-hiding-rows.md',H/'README.md',H/'interface.md']
for p in reports:
    body=p.read_text();check(len(body)>500)
    # Prior FINDINGS contains historical remote/anchor links, so check only new entry.
    if p.name=='FINDINGS.md':body=body.split('## Cycle 0135 —',1)[1]
    for target in re.findall(r'\]\(([^)]+)\)',body):
        if target.startswith(('http:','https:','#')):continue
        check((p.parent/target.split('#')[0]).resolve().is_file())
for row in json.loads((H/'commands.json').read_text()):check(row['returncode']==0 and row['parent_timeout_s']<=60)
stamp=datetime.datetime.now(datetime.timezone.utc).isoformat()
check(datetime.datetime.now(datetime.timezone.utc)<datetime.datetime(2026,10,29,5,16,49,tzinfo=datetime.timezone.utc))
out=dict(status='PASS_FINAL_PROVENANCE_ONLY',checks=checks,elapsed_s=time.perf_counter()-t0,
 peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 prior_findings_preserved=True,prior_source_records_preserved=882,total_source_records=891,
 prior_hypotheses_preserved=51,new_hypothesis=52,native_pins_unchanged=8,
 direction_files_unchanged=len(direction),checkpoint_utc=stamp)
(H/'final-audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
line=f'\nFinal checkpoint: {stamp}. Provenance audit: {checks} checks PASS; all prior findings, 882 source records and 51 hypotheses preserved; eight native pins and required direction unchanged.\n'
for p in reports[:4]:
    with p.open('a') as f:f.write(line)
completion=json.loads((H/'completion.json').read_text());completion.update(final_checkpoint_utc=stamp,final_audit_checks=checks)
(H/'completion.json').write_text(json.dumps(completion,indent=2)+'\n')
files=[p for p in H.rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.name!='artifact-manifest.json']+reports
manifest=[dict(path=str(p.relative_to(R)),sha256=sha(p.read_bytes()),bytes=p.stat().st_size) for p in sorted(set(files))]
(H/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(out))
