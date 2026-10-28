"""Final provenance/consistency gate; no production writes or proof execution."""
import datetime,hashlib,json,os,resource,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
RUN='20261019T231854Z-28e6b36b'
t=time.perf_counter();checks=0
def check(c,m):
 global checks
 checks+=1
 assert c,m
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
r=json.loads((HERE/'result.json').read_text())
check(r['status']=='PASS' and r['checks']==1389,'audit result')
for key in ['new_full_stack_proofs','new_passes','new_proved_positions']:check(r[key]==0,key)
for key in ['device','proof_context','steady_rate','total_rate','startup_fraction','witness_seconds',
            'proof_seconds','serialization_seconds','verification_seconds']:check(r[key] is None,key)
check(r['observed_regions']==80 and r['byte_vector_comparisons']==720,'scope')
check(r['output_corruption_controls']==720 and r['allocation_event_controls']==240 and r['masquerade_controls']==32,'controls')
commands=json.loads((HERE/'commands.json').read_text())
for cmd in commands:
 if cmd['name']=='validate.py' and cmd['exit_code']!=0:
  known={'05-validate.py.stderr.log':'AssertionError: directions unchanged',
         '06-validate.py.stderr.log':'AssertionError: evidence limits'}
  check(cmd['stderr'] in known and known[cmd['stderr']] in (HERE/cmd['stderr']).read_text(),'preserved identified gate failures')
 else:check(cmd['exit_code']==0,cmd['name']+' exit')
 check(cmd['wall_seconds']<60 and cmd['child_maxrss_kib']<512*1024,'bounded leaf')
 check((HERE/cmd['stdout']).exists() and (HERE/cmd['stderr']).exists(),'logs')
 check(cmd['limits']['address_space_bytes']==512*1024**2 and cmd['limits']['single_cpu_affinity'],'leaf caps')
 if cmd['name'].startswith(('compile','probe')):
  check(cmd['source_sha256']==sha(HERE/'probe.rs'),'compiled source unchanged')
 if cmd['name'].startswith('probe'):
  check(cmd['binary_sha256']==sha(Path(cmd['argv'][0])),'binary unchanged')
 if cmd['name']=='audit.py':check(cmd['source_sha256']==sha(HERE/'audit.py'),'audit unchanged')
pins=json.loads((HERE/'input-pins.json').read_text())
for pin in pins:
 check(sha(Path(pin['path']))==pin['sha256'],'current source/evidence pin')
 check(sha(HERE/pin['copy'])==pin['sha256'],'copied source/evidence pin')
manifest=json.loads((HERE/'startup-manifest.json').read_text())
for row in manifest:
 check(sha(HERE/'startup'/Path(row['path']).name)==row['sha256'],'startup bytes')
final_directions=json.loads((HERE/'final-direction-manifest.json').read_text())
for row in final_directions:check(sha(Path(row['path']))==row['sha256'],'reviewed directions unchanged')
updates=json.loads((HERE/'reviewed-direction-updates.json').read_text())
check(len(updates)==1 and Path(updates[0]['path']).name=='MVP_STATUS.md','owner update reviewed')
check(sha(HERE/'final-MVP_STATUS.md')==updates[0]['after'],'changed status preserved')
original=(HERE/'startup/sources.jsonl').read_bytes()
updated=(ROOT/'sources.jsonl').read_bytes()
check(updated.startswith(original),'source prefix preserved')
new=[json.loads(s) for s in updated[len(original):].splitlines()]
check(new==json.loads((HERE/'source-records.json').read_text()),'source append exact')
check(len(new)==10 and len(updated.splitlines())==517,'source counts')
for s in new:
 check(s['access_date']=='2026-10-19' and s['run_id']==RUN and s['url'].startswith('https://'),'source provenance')
 check(s['external_execution'] is False and s['reproduced_performance'] is False,'no author reproduction')
 check('published' in s and 'updated' in s and 'implementation_license' in s and 'inspected_commit_id' in s,'date/license scope')
expected=json.loads((HERE/'prior-payload-ledger.json').read_text())
check(expected['pad_saving_bytes']==117444608,'carried model saving')
check(expected['before']['peak_bytes']==638116864 and expected['after']['peak_bytes']==520672256,'carried pad envelope')
check(any(row['saving_bytes']==0 for row in expected['rows']),'preserve whole-loader negatives')
for path in [ROOT/'PROGRESS.md',ROOT/'STATE.md',ROOT/'FINDINGS.md',ROOT/'progress'/f'{RUN}.md',HERE/'README.md',ROOT/'handoffs/20261019-vec-allocation-scopes.md']:
 text=path.read_text()
 check(RUN in text,'report identity')
 check(any(word in text.lower() for word in ['unmeasured','unknown','limits:']),'evidence limits')
check((ROOT/'FINDINGS.md').read_bytes().startswith((HERE/'startup/FINDINGS.md').read_bytes()),'prior findings preserved')
check('Cycle0090 COMPLETE' in (HERE/'startup/STATE.md').read_text(),'early previous-state snapshot')
queue=json.loads((HERE/'hypotheses.json').read_text())
check(len(queue)>=3 and [h['rank'] for h in queue]==list(range(1,len(queue)+1)),'ranked queue')
for h in queue:
 for k in ['baseline','eliminated_work','added_costs','end_to_end_ceiling','prerequisites','integration_cost','exactness','privacy_soundness','compatibility','falsification']:
  check(bool(h.get(k)),f'{h["id"]}/{k}')
# Recheck reduced proxy values, not target geometry or RSS.
proxy={s['mode']:s for s in r['summaries'] if s['opt']==3 and s['case']==7}
check(proxy[0]['peak_requested_bytes']==419200 and proxy[1]['peak_requested_bytes']==304384,'observed region peaks')
check(proxy[0]['allocated_bytes']==proxy[1]['allocated_bytes']==482848,'no work removed')
check(proxy[0]['allocation_count']==proxy[1]['allocation_count']==36,'same allocation count')
check(proxy[2]['peak_requested_bytes']==460288 and proxy[4]['peak_requested_bytes']==475648,'negative peaks')
check(proxy[3]['allocation_count']==27 and proxy[3]['peak_requested_bytes']==247040,'direct control')
assert time.perf_counter()-t<59
result=dict(status='PASS',checks=checks,input_pins=len(pins),final_direction_documents=len(final_directions),reviewed_owner_updates=1,
 sources_before=507,sources_after=517,new_source_records=10,wall_seconds=time.perf_counter()-t,
 rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,
 affinity=sorted(os.sched_getaffinity(0)),nice=os.nice(0),checked_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
 scope='Source/evidence provenance,limits,reported values,append-only durable memory and direction freshness;no native loader/proof')
(HERE/'validation-result.json').write_text(json.dumps(result,indent=2)+'\n')
files=[]
for path in sorted(HERE.rglob('*')):
 if path.is_file() and path.name not in ['artifact-manifest.json','validation-result.json','commands.json'] and '-validate.py.' not in path.name:
  files.append(dict(path=str(path.relative_to(HERE)),bytes=path.stat().st_size,sha256=sha(path)))
(HERE/'artifact-manifest.json').write_text(json.dumps(files,indent=2)+'\n')
print(json.dumps(result,indent=2))
