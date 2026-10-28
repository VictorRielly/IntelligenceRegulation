"""Final provenance, resource, scope and report-consistency gate."""
import datetime, hashlib, json, os, pathlib, resource, time
HERE=pathlib.Path(__file__).resolve().parent
RESEARCH=HERE.parent.parent
RUN='20261020T001854Z-f39e44f4'
checks=0
def ensure(v,msg):
    global checks
    checks+=1;assert v,msg
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def load(n):return json.loads((HERE/n).read_text())

t=time.perf_counter(); manifest=load('input-manifest.json');immutable=0;directions=[]
for row in manifest:
    p=pathlib.Path(row['path'])
    if p.name in ['STATE.md','PROGRESS.md','FINDINGS.md','sources.jsonl'] and p.parent==RESEARCH:
        continue
    ensure(sha(p)==row['sha256'],'input changed;read/review and record before final: '+str(p))
    immutable+=1
    if p.suffix=='.md': directions.append(dict(path=str(p),sha256=sha(p)))
(HERE/'final-direction-manifest.json').write_text(json.dumps(directions,indent=2)+'\n')
old_findings=HERE/'startup/research__zkp-efficiency__FINDINGS.md'
old_sources=HERE/'startup/research__zkp-efficiency__sources.jsonl'
ensure((RESEARCH/'FINDINGS.md').read_bytes().startswith(old_findings.read_bytes()),'findings history replaced')
ensure((RESEARCH/'sources.jsonl').read_bytes().startswith(old_sources.read_bytes()),'source history replaced')
sources=[json.loads(s) for s in (RESEARCH/'sources.jsonl').read_text().splitlines()]
new=[s for s in sources if s.get('run_id')==RUN]
ensure(len(sources)==524 and len(new)==7,'source ledger count')
ensure(new==load('source-records.json'),'source records differ')
for row in new:
    for key in ['url','access_date','published','updated','implementation_license','inspected_commit_id','assessment','date_evidence']:
        ensure(key in row,'missing source metadata '+key)
    ensure(row['access_date']=='2026-10-20' and row['reproduced_performance'] is False,'source evidence scope')
    ensure(row['external_execution'] is False,'foreign code execution')
ensure(new[4]['inspected_commit_id']=='b8387fa61e1361d90ee7de49f551863418ca0f08','inspected release commit')
r=load('result.json');m=load('model-result.json');e=load('events.json');clocks=load('measurements.json')
ensure(r['status']=='PASS','audit not passing')
ensure(r['source_cases']==59 and r['events']==4602 and r['checks']==45703 and r['corruption_controls']==590,'reported audit counts')
ensure(len(e['cases'])==r['source_cases'],'case census')
ensure(sum(len(c['events']) for c in e['cases'])==r['events'],'event census')
for leaf in [r,m]:
    ensure(leaf['threads']==1 and leaf['affinity']==[0] and leaf['nice']==19,'CPU limits')
    ensure(leaf['wall_seconds']<60 and leaf['rss_kib']<512*1024,'runtime/memory limit')
ensure(r['seed']==2026102092 and r['seed']==e['seed']==m['seed'],'seed pin')
for k in ['new_independently_verified_complete_proofs','new_complete_passes','new_proved_positions']:
    ensure(clocks[k]==0,'unsupported complete-proof count')
for k in ['context_length','steady_state_proved_positions_per_second','total_workload_proved_positions_per_second','startup_fraction','startup_seconds','witness_seconds','proof_seconds','serialization_seconds','verification_seconds']:
    ensure(clocks[k] is None,'unmeasured clock/rate must be null')
for k in ['long_context_prefill','resident_complete_pass_series','decode']:
    ensure(clocks[k] is False,'unsupported workload claim')
ensure(clocks['carried_owner_cpu_diagnostic']['reverified_by_researcher'] is False,'owner result counted as new')
by={s['name']:s for s in r['summaries']}
ensure(by['mixed-rows-drain0']['peak_bytes']==1794484768,'mixed no-drain peak')
for k,n in [('mixed-rows-drain1',20),('mixed-rows-retain-next',8)]:
    ensure(by[k]['peak_bytes']==603304480 and by[k]['fresh_attempts']==n,'selective/full modeled result')
for pair in r['geometry_pairs']:
    ensure(pair['no_drain_peak_bytes']==pair['drain_peak_bytes'],'lost fixed-shape negative')
    ensure(pair['no_drain_fresh']==5 and pair['drain_fresh']==20,'fixed-shape allocation count')
ensure(len(r['geometry_pairs'])==14,'fixed-shape pair count')
questions=load('hypotheses.json')
ensure(len(questions)>=3,'hypothesis queue')
for i,q in enumerate(questions):
    ensure(q['rank']==i+1,'queue rank')
    for k in ['baseline','eliminated_work','added_costs','prerequisites','integration_cost','exactness','privacy_soundness','compatibility','end_to_end_ceiling','falsification']:
        ensure(bool(q.get(k)),'missing hypothesis obligation '+k)
commands=load('commands.json')
for row in commands:
    ensure(row['exit_code']==0 and row['wall_seconds']<60 and row['maxrss_kib']<512*1024,'failed/overbudget experiment')
for name in ['capacity_model.py','audit.py']:
    latest=next(c for c in reversed(commands) if c['argv'][-1].endswith('/'+name))
    ensure(latest['source_sha256']==sha(HERE/name),'latest executed source changed')
old=load('before-selective-retention/result.json')
ensure(old['source_cases']==57 and old['checks']==44829,'prior result preserved')
report_paths=[HERE/'README.md',RESEARCH/'STATE.md',RESEARCH/'PROGRESS.md',RESEARCH/'progress'/f'{RUN}.md',RESEARCH/'handoffs/20261020-public-request-pool-retention.md']
for p in report_paths:
    text=p.read_text();ensure(RUN in text,'report identity '+str(p))
    ensure('603304480' in text,'reported capacity '+str(p))
    ensure('unmeasured' in text or 'No native speed' in text or 'No proving speed' in text,'scope missing '+str(p))
ensure((RESEARCH/'PROGRESS.md').read_text().count('\n')<=40,'progress not concise')
outputs=[]
for p in sorted(HERE.rglob('*')):
    if p.is_file() and p.name not in ['artifact-manifest.json','validation-result.json','commands.json','final-direction-manifest.json']:
        outputs.append(dict(path=str(p.relative_to(HERE)),sha256=sha(p),bytes=p.stat().st_size))
for p in report_paths[1:]+[RESEARCH/'FINDINGS.md',RESEARCH/'sources.jsonl']:
    outputs.append(dict(path=str(p),sha256=sha(p),bytes=p.stat().st_size))
(HERE/'artifact-manifest.json').write_text(json.dumps(outputs,indent=2)+'\n')
out=dict(status='PASS',checks=checks,input_pins=immutable,direction_pins=len(directions),
    source_records_before=517,source_records_after=len(sources),new_source_records=len(new),
    experiment_cases=r['source_cases'],experiment_checks=r['checks'],corruption_controls=r['corruption_controls'],
    artifact_pins=len(outputs),wall_seconds=time.perf_counter()-t,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    threads=len(list(pathlib.Path('/proc/self/task').iterdir())),affinity=sorted(os.sched_getaffinity(0)),nice=os.nice(0),
    checked_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),scope='provenance/resource/report consistency only;no native/GPU/proof')
(HERE/'validation-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
