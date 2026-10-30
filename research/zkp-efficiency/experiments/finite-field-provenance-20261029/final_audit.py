import os,resource,signal,time,json,hashlib,datetime,re
from pathlib import Path
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_CPU,(30,30))
resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2));signal.alarm(35)
t=time.perf_counter();E=Path(__file__).resolve().parent;R=E.parent.parent
checks=0
def check(v):
    global checks
    checks+=1
    assert v,checks
def sha(b):return hashlib.sha256(b).hexdigest()
prior=(E/'startup/sources.jsonl').read_bytes();current=(R/'sources.jsonl').read_bytes()
check(current.startswith(prior))
sources=[json.loads(l) for l in current.splitlines()]
check(len(sources)==882 and len(sources[873:])==9)
for row in sources[873:]:
    check(row['prior_exact_url_records']==sum(x.get('url')==row['url'] for x in sources[:873]))
check((R/'FINDINGS.md').read_bytes().startswith((E/'startup/FINDINGS.md').read_bytes()))
old=json.loads((E/'prior-hypotheses.json').read_text())
new=json.loads((E/'hypotheses.json').read_text())
check(len(old)==len(new)==51)
check(old[:50]==new[:50]);check(new[50]['refined_in_cycle']=='0134')
check([x['rank'] for x in old]==[x['rank'] for x in new])
direction=[]
for row in json.loads((E/'startup-manifest.json').read_text()):
    p=Path(row['path'])
    if p.name not in ('AGENDA.md','CLAUDE.md','MVP_STATUS.md','ZK60_DECISIONS.md',
                       'ZK60_CODEX_FABLE_COORDINATION.md','ZK60_THROUGHPUT_TARGET.md'):continue
    b=p.read_bytes();same=sha(b)==row['sha256'];check(same)
    direction.append(dict(path=str(p),unchanged=same,sha256=sha(b)))
(E/'final-direction-check.json').write_text(json.dumps(direction,indent=2)+'\n')
for group in ('native-pins.json','startup/prior-native-pins.json'):
    for row in json.loads((E/group).read_text()):check(sha(Path(row['path']).read_bytes())==row['sha256'])
result=json.loads((E/'result.json').read_text())
for f,h in result['source_hashes'].items():check(sha((E/f).read_bytes())==h)
check(json.loads((E/'audit-result.json').read_text())['status']=='PASS_SOURCE_AND_PROVENANCE_AUDIT_ONLY')
check((E/'audit-initial-failure.json').is_file())
account=json.loads((E/'target-accounting.json').read_text())
for key in ('startup_s','prefill_s','startup_fraction','witness_s','proof_s','serialization_s',
            'verification_s','steady_state_positions_s','total_workload_positions_s','proof_latency_s','proof_bytes','context_length'):
    check(account[key] is None)
for key in ('independently_verified_full_stack_proofs','passes','countable_positions'):check(account[key]==0)
reports=[R/'STATE.md',R/'PROGRESS.md',R/'progress/20261029T035649Z-8ea509dd.md',E/'README.md',
         R/'handoffs/20261029-finite-field-provenance-negative.md']
for p in reports:
    s=p.read_text();check(len(s)>100)
    for target in re.findall(r'\]\(([^)]+)\)',s):
        if target.startswith('https://'):continue
        check((p.parent/target).resolve().is_file())
    check('04: 16' not in s and 'https: //' not in s)
check(datetime.datetime.now(datetime.timezone.utc)<datetime.datetime(2026,10,29,4,16,49,tzinfo=datetime.timezone.utc))
stamp=datetime.datetime.now(datetime.timezone.utc).isoformat()
out=dict(status='PASS_FINAL_CHECKPOINT_PROVENANCE_ONLY',checks=checks,
 elapsed_s=time.perf_counter()-t,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 prior_findings_preserved=True,prior_source_records_preserved=873,total_source_records=882,
 prior_hypotheses_preserved=51,refined_hypothesis=51,required_directions_unchanged=True,
 native_pins_unchanged=True,checkpoint_utc=stamp)
(E/'final-audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
line=f'\nFinal checkpoint audit: {checks} checks PASS, {out["elapsed_s"]:.6f} s / {out["max_rss_kib"]:,} KiB RSS. Prior findings, 873 source records and 51 hypotheses preserved; native pins and required direction unchanged. Final checkpoint: {stamp}.\n'
for p in [R/'STATE.md',R/'PROGRESS.md',R/'FINDINGS.md',R/'progress/20261029T035649Z-8ea509dd.md']:
    with p.open('a') as f:f.write(line)
completion=json.loads((E/'completion.json').read_text());completion['final_checkpoint_utc']=stamp;completion['final_audit_checks']=checks
(E/'completion.json').write_text(json.dumps(completion,indent=2)+'\n')
files=[p for p in E.rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.name!='artifact-manifest.json']+reports[:3]+[reports[4]]
manifest=[dict(path=str(p.relative_to(R)),sha256=sha(p.read_bytes()),bytes=p.stat().st_size) for p in sorted(set(files))]
(E/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(out))
