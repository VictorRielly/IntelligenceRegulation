"""Final artifact integrity. Does not reverify any production receipt."""
import datetime,hashlib,json,os,resource,signal
from pathlib import Path
H=Path(__file__).resolve().parent;R=H.parent.parent
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
checks=0
for name in ['sources.jsonl','FINDINGS.md']:
    assert (R/name).read_bytes().startswith((H/'startup'/name).read_bytes());checks+=1
assert (R/'AGENDA.md').read_bytes()==(H/'startup/AGENDA.md').read_bytes();checks+=1
sources=[json.loads(x) for x in (R/'sources.jsonl').read_text().splitlines()]
new=json.loads((H/'source-records.json').read_text())
assert len(sources)==442 and sources[-7:]==new and len({r['id'] for r in new})==7;checks+=1
assert all(r['access_date']=='2026-10-19' and r['inspected_commit_id'] is None and not r['reproduced_performance'] for r in new);checks+=1
for pin in json.loads((H/'source-pins.json').read_text())+json.loads((H/'owner-evidence-pins.json').read_text()):
    assert hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'];checks+=1
native=[q for q in json.loads((H/'source-pins.json').read_text()) if q['path'].endswith('/field.rs')]
assert len(native)==1 and hashlib.sha256((H/'native-field.rs').read_bytes()).hexdigest()==native[0]['sha256'];checks+=1
for name in ['execution.json','audit-execution.json']:
    q=json.loads((H/name).read_text());assert q['returncode']==0 and 0<q['wall_seconds']<60;checks+=1
r=json.loads((H/'result.json').read_text());a=json.loads((H/'audit-result.json').read_text());b=json.loads((H/'bench-result.json').read_text())
assert r['status']==a['status']==b['status']=='PASS';checks+=1
assert r['seed']==b['seed']==2026101981 and r['N']==[2,8,32] and len(r['profiles'])==2;checks+=1
assert r['checks']==dict(compiled_coefficients=780,value_independent_runtime_binding=36,captured_rust_grid_values=390,captured_rust_offgrid_values=78,round_messages=18,original_finals=354,final_relations=6,fixtures=6);checks+=1
assert len(r['controls'])==7 and all(r['controls'].values());checks+=1
assert a['checks']==1465 and len(a['controls'])==4 and all(a['controls'].values());checks+=1
qs=json.loads((H/'scalar-dags.json').read_text());assert qs['baseline']==qs['driven'];checks+=1
p=json.loads((H/'group-plan.json').read_text());assert len(p['groups'])==19 and p['capacity']==13 and p['max_group_ops']==78;checks+=1
assert [a['assembly'][n]['call_count'] for n in ['baseline','driven']]==[884,19];checks+=1
assert [a['assembly'][n]['call_chain_span_below_entry_rsp_bytes'] for n in ['baseline','driven']]==[424,504];checks+=1
assert [a['baseline_logical_requested_bytes'],a['candidate_logical_requested_bytes']]==[4320,8528];checks+=1
assert [a['baseline_code_bytes'],a['candidate_code_bytes']]==[33543,145739];checks+=1
assert b['median_ns_per_row']['grouped']>b['median_ns_per_row']['baseline'] and sum(x<1 for x in b['paired_speedups'])==7;checks+=1
assert len(b['rows'])==16 and all(q['rows']==8192 for q in b['rows']);checks+=1
for rep in range(8):
    pairs=[q for q in b['rows'] if q['rep']==rep]
    assert len(pairs)==2 and pairs[0]['checksum']==pairs[1]['checksum'];checks+=1
for q in [r,a,b]:
    assert q['threads']==1 and q['cpu_affinity']==[0] and q['wall_seconds']<60 and q['rss_kib']<512*1024;checks+=1
assert r['compiler_rss_kib']<512*1024 and b['child_peak_rss_kib']<512*1024;checks+=1
census=json.loads((H/'template-census.json').read_text())
assert census['groups']==19 and census['normalized_shape_classes']==10 and sorted(sum(census['classes'],[]))==list(range(19));checks+=1
t=json.loads((H/'target-accounting.json').read_text())['new_target_work']
for k in ['completed_independently_verified_full_stack_proofs','complete_model_passes','proved_token_positions']:
    assert t[k]==0;checks+=1
for k in ['context_tokens','steady_proved_tokens_per_second','total_workload_proved_tokens_per_second','startup_seconds','startup_fraction','witness_seconds','proof_seconds','serialization_seconds','verification_seconds']:
    assert t[k] is None;checks+=1
for name in ['STATE.md','PROGRESS.md','progress/20261019T131854Z-168a653c.md','handoffs/20261019-dzc-helper-groups-negative.md']:
    assert (R/name).is_file() and len((R/name).read_text())>400;checks+=1
assert (R/'STATE.md').read_bytes()==(H/'final-state.md').read_bytes();checks+=1
assert (R/'PROGRESS.md').read_bytes()==(H/'final-progress.md').read_bytes();checks+=1
now=datetime.datetime.now(datetime.timezone.utc)
assert now<datetime.datetime(2026,10,19,13,38,54,tzinfo=datetime.timezone.utc);checks+=1
out=dict(status='PASS',checks=checks,checked_utc=now.isoformat(),source_records=442,
    prior_findings_and_source_prefixes_preserved=True,native_and_carried_owner_pins_unchanged=True,
    completed_target_proofs=0,completed_model_passes=0,proved_positions=0,
    scope='Source/artifact integrity and retained synthetic controls; no native receipt verification or privacy acceptance.',
    limits='One nice19 CPU,59sCPU/wall,512MiBAS')
(H/'validation.json').write_text(json.dumps(out,indent=2)+'\n')
manifest=[]
for pth in sorted(H.rglob('*')):
    if not pth.is_file() or pth.name=='artifact-sha256.json':continue
    raw=pth.read_bytes();manifest.append(dict(path=str(pth.relative_to(H)),bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest()))
for name in ['STATE.md','PROGRESS.md','progress/20261019T131854Z-168a653c.md','handoffs/20261019-dzc-helper-groups-negative.md']:
    pth=R/name;raw=pth.read_bytes();manifest.append(dict(path=str(pth),bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest()))
(H/'artifact-sha256.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(out,indent=2))
