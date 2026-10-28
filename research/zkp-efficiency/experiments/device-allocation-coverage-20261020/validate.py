"""Final provenance, resource, source-record and checkpoint consistency gate."""
import datetime,hashlib,json,os,pathlib,resource,time
HERE=pathlib.Path(__file__).resolve().parent
R=HERE.parent.parent
ROOT=R.parent.parent
RUN='20261020T011854Z-224b9b69'
t=time.perf_counter();checks=0
def check(v,msg):
    global checks
    checks+=1
    if not v:raise AssertionError(msg)
def read(n):return json.loads((HERE/n).read_text())
input_manifest=read('input-manifest.json')
for x in input_manifest:
    check(hashlib.sha256((HERE/'startup'/x['snapshot']).read_bytes()).hexdigest()==x['sha256'],'startup snapshot')
source_manifest=read('source-manifest.json');changed=[]
for x in source_manifest:
    check(hashlib.sha256((HERE/'source'/x['snapshot']).read_bytes()).hexdigest()==x['sha256'],'source snapshot')
    if hashlib.sha256(pathlib.Path(x['path']).read_bytes()).hexdigest()!=x['sha256']:changed.append(x['path'])
before=(HERE/'startup/research__zkp-efficiency__sources.jsonl').read_text()
now=(R/'sources.jsonl').read_text()
check(now.startswith(before),'old source ledger preserved')
rows=[json.loads(s) for s in now[len(before):].splitlines()]
check(rows==read('source-records.json'),'exact source records')
check(len(rows)==7,'seven sources')
for row in rows:
    check(row['access_date']=='2026-10-20' and row['run_id']==RUN,'source date/run')
    check(row['url'].startswith('https://'),'exact URL')
    check(bool(row['date_evidence']),'date evidence/unknown')
    check('implementation_license' in row and 'inspected_commit_id' in row,'license/commit scope')
    check(not row['reproduced_performance'] and not row['external_execution'],'source evidence scope')
aud=read('result.json');model=read('staging-result.json');census=read('census-result.json');measure=read('measurements.json')
check(aud['status']=='PASS' and aud['fixtures']==144,'differential audit')
check(aud['allocation_sites']==sum(census['sites'].values())==298,'census totals')
check(aud['checks']==27301 and aud['negative_controls']==292 and aud['corruption_controls']==1299,'final audit counts')
for x in [aud,model,census]:
    check(x['threads']==1 and len(x['affinity'])==1,'one thread/CPU')
    check(x['rss_kib']<512*1024 and x['wall_seconds']<60,'resource usage')
commands=read('commands.json')
for cmd in commands:
    check(cmd['limits']['cpu_seconds']==59 and cmd['limits']['wall_alarm_seconds']==59,'time caps')
    check(cmd['limits']['address_space_bytes']==512*1024**2,'memory cap')
    check((HERE/cmd['stdout']).exists() and (HERE/cmd['stderr']).exists(),'retained logs')
for name in ['census.py','staging.py','audit.py']:
    last=[c for c in commands if c['argv'][-1].endswith('/'+name)][-1]
    check(last['exit_code']==0,'leaf completion')
    check(last['sha256']==hashlib.sha256((HERE/name).read_bytes()).hexdigest(),'tested source pin')
for name in ['STATE.md','PROGRESS.md',f'progress/{RUN}.md']:
    s=(R/name).read_text()
    check(RUN in s,'checkpoint run')
    check('0/0/0' in s,'proof count scope')
    check('unmeasured' in s,'unknown clocks explicit')
check(measure['new_proved_positions']==0 and measure['new_complete_passes']==0,'no counted proof tokens')
check(all(measure[n] is None for n in ['steady_state_proved_positions_per_second','total_workload_proved_positions_per_second','startup_fraction','witness_seconds','proof_seconds','serialization_seconds','verification_seconds']),'proof metrics unknown')
hyp=read('hypotheses.json');check(len(hyp)>=3 and [h['rank'] for h in hyp]==list(range(1,len(hyp)+1)),'ranked queue')
for h in hyp:
    check(all(key in h for key in ['baseline','eliminated_work','added_costs','prerequisites','integration_cost','exactness','privacy_soundness','compatibility','end_to_end_ceiling','falsification']),'hypothesis obligations')
patch=read('patch-manifest.json')
check(patch['status']=='UNBUILT_UNAPPLIED_REVIEW_ONLY','patch status')
check(hashlib.sha256((HERE/'review-only-host-stage-reuse.patch').read_bytes()).hexdigest()==patch['patch_sha256'],'patch hash')
check(hashlib.sha256((HERE/'candidate-cuda.rs').read_bytes()).hexdigest()==patch['candidate_sha256'],'candidate hash')
done=read('completion.json');check(done['status']=='COMPLETE','completion')
check(datetime.datetime.now(datetime.timezone.utc)<datetime.datetime.fromisoformat(done['deadline'].replace('Z','+00:00')),'deadline')
direction=[]
for p in [R/'AGENDA.md',ROOT/'CLAUDE.md']+[ROOT/'docs/zkmatrix-poc'/n for n in ['ZK60_THROUGHPUT_TARGET.md','MVP_STATUS.md','ZK60_DECISIONS.md','ZK60_CODEX_FABLE_COORDINATION.md']]:
    b=p.read_bytes();prior=next(x for x in input_manifest if x['path']==str(p))
    direction.append(dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),changed_since_startup=hashlib.sha256(b).hexdigest()!=prior['sha256']))
(HERE/'final-direction-manifest.json').write_text(json.dumps(direction,indent=2)+'\n')
check(all(not x['changed_since_startup'] for x in direction),'directions changed; re-read before completion')
artifacts=[]
for p in sorted(HERE.rglob('*')):
    if p.is_file() and p.name not in ['artifact-manifest.json','validation-result.json','commands.json'] and not p.name.startswith('10-validate'):
        artifacts.append(dict(path=str(p.relative_to(HERE)),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size))
(HERE/'artifact-manifest.json').write_text(json.dumps(artifacts,indent=2)+'\n')
r=dict(status='PASS',checks=checks,input_pins=len(input_manifest),source_pins=len(source_manifest),artifact_pins=len(artifacts),source_records_before=524,source_records_after=531,changed_live_source_paths=changed,wall_seconds=time.perf_counter()-t,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=len(list(pathlib.Path('/proc/self/task').iterdir())),affinity=sorted(os.sched_getaffinity(0)),checked_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),scope='provenance/resource/report consistency only; no native proof')
(HERE/'validation-result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
