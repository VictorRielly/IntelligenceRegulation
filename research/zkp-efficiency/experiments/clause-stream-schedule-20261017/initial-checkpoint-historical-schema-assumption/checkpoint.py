"""Bounded checkpoint/integrity validation; does not execute any native code."""
import datetime,hashlib,json,os,resource,signal
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
RUN='20261017T062624Z-e471348a'
signal.alarm(59);resource.setrlimit(resource.RLIMIT_CPU,(59,59))
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
checks=0
original=(HERE/'startup/sources.jsonl').read_bytes()
current=(ROOT/'sources.jsonl').read_bytes()
assert current.startswith(original);checks+=1
rows=[json.loads(x) for x in current.splitlines() if x.strip()]
new=[json.loads(x) for x in current[len(original):].splitlines() if x.strip()]
assert len(rows)==288 and len(new)==6;checks+=1
assert new==json.loads((HERE/'sources-cycle56.json').read_text());checks+=1
assert len({x['id'] for x in rows})==len(rows);checks+=1
assert all(x['run_id']==RUN and x['access_date']=='2026-10-17' for x in new);checks+=1
assert (ROOT/'FINDINGS.md').read_bytes().startswith((HERE/'startup/FINDINGS.md').read_bytes());checks+=1
for name in ['STATE.md','FINDINGS.md','PROGRESS.md',f'progress/{RUN}.md','handoffs/20261017-clause-stream-schedule.md']:
    text=(ROOT/name).read_text()
    assert RUN in text and '0/0/0' in text and 'unmeasured' in text;checks+=3
assert (ROOT/'PROGRESS.md').read_bytes()==(ROOT/f'progress/{RUN}.md').read_bytes();checks+=1
r=json.loads((HERE/'result.json').read_text());metrics=r['proof_accounting']
assert r['status']=='passed' and r['run_id']==RUN;checks+=1
for name in ['accepted_complete_private_8b_proofs','proved_tokens','passes']:
    assert metrics[name]==0;checks+=1
for name,value in metrics.items():
    if name not in ['accepted_complete_private_8b_proofs','proved_tokens','passes']:
        assert value is None;checks+=1
assert r['counts']['full_schedules']==2790 and r['counts']['fixtures']==93;checks+=1
assert len(r['controls'])==5 and r['hardware']['threads']==1;checks+=1
assert r['wall_seconds']<60 and r['max_rss_kib']<512*1024;checks+=1
assert json.loads((HERE/'execution.json').read_text())['exit_code']==0;checks+=1
assert r['output_sha256']==json.loads((HERE/'before-independent-dag-audit/result.json').read_text())['output_sha256'];checks+=1
assert (HERE/'initial-audit-source-pin-refusal/failure.json').exists();checks+=1
a=json.loads((HERE/'audit.json').read_text())
assert a['status']=='passed' and a['checks']==34514;checks+=1
assert not a['target_16_met'] and not a['optimality_claim'];checks+=1
assert all(x['unchanged'] for x in a['owner_memory']);checks+=1
for pin in json.loads((HERE/'native-current-comparison.json').read_text()):
    assert hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'];checks+=1
for rec in json.loads((HERE/'startup-manifest.json').read_text()):
    p=Path(rec['path'])
    if ROOT not in p.parents:assert hashlib.sha256(p.read_bytes()).hexdigest()==rec['sha256'];checks+=1
baseline=json.loads((HERE/'baseline-result.json').read_text())
for old,new_shape in zip(baseline['generated_shapes'],r['generated_shapes']):
    for mode in ('ssa','recycled'):
        b=old['generated'][mode];n=new_shape['generated'][mode]
        assert b['field_ops']==n['field_ops'];checks+=1
        assert n['peak_live_logical_temporaries']<b['peak_live_logical_temporaries'];checks+=1
        assert n['peak_live_logical_temporaries']>16;checks+=1
        assert n['public_schedule']['candidate_count']==102;checks+=1
for item in r['generated_shapes'][-2:]:
    n=item['generated']['recycled'];target=20 if item['mask_active'] else 18
    assert n['peak_live_logical_temporaries']==n['allocated_reusable_slots']==target;checks+=1
projection=r['unchanged_scoped_field_census']['results']
assert projection['prepared_scalar']['sum_api_ops']==3527474753;checks+=1
assert projection['cubic_round0']['sum_api_ops']==3280010835;checks+=1
out=dict(status='passed',checks=checks,run_id=RUN,cycle='0056',
         checkpoint_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
         sources_total=len(rows),sources_appended=len(new),historical_prefixes_preserved=True,
         native_proof_or_performance_gate=False)
(HERE/'checkpoint-audit.json').write_text(json.dumps(out,indent=2)+'\n')
checkpoint=json.loads((HERE/'checkpoint.json').read_text())
checkpoint.update(checkpoint_utc=out['checkpoint_utc'],checkpoint_audit_checks=checks)
(HERE/'checkpoint.json').write_text(json.dumps(checkpoint,indent=2)+'\n')
manifest={str(p.relative_to(HERE)):hashlib.sha256(p.read_bytes()).hexdigest()
          for p in sorted(HERE.rglob('*')) if p.is_file() and p.name!='final-manifest.json'}
(HERE/'final-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(out))
