"""Bounded final checkpoint audit; no native work or production writes."""
import datetime,hashlib,json,os,resource,signal
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
signal.alarm(59);resource.setrlimit(resource.RLIMIT_CPU,(59,59))
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
checks=0
original=(HERE/'startup/sources.jsonl').read_bytes()
current=(ROOT/'sources.jsonl').read_bytes()
assert current.startswith(original);checks+=1
rows=[json.loads(x) for x in current.decode().splitlines() if x.strip()]
new=[json.loads(x) for x in current[len(original):].decode().splitlines() if x.strip()]
assert len(rows)==282 and len(new)==6;checks+=1
assert new==json.loads((HERE/'sources-cycle55.json').read_text());checks+=1
old_ids={x.get('id') for x in rows[:-6]}
assert len({x['id'] for x in new})==6 and not any(x['id'] in old_ids for x in new);checks+=1
assert (ROOT/'FINDINGS.md').read_bytes().startswith((HERE/'startup/FINDINGS.md').read_bytes());checks+=1
for name in ['PROGRESS.md','STATE.md','FINDINGS.md','progress/20261017T052624Z-c8881557.md','handoffs/20261017-fixed-round0-factory.md']:
    text=(ROOT/name).read_text()
    assert '20261017T052624Z-c8881557' in text and '0/0/0' in text
    checks+=2
r=json.loads((HERE/'result.json').read_text());metrics=r['proof_accounting']
for name in ['accepted_complete_private_8b_proofs','proved_tokens','passes']:
    assert metrics[name]==0;checks+=1
for name in ['context_length','steady_tokens_per_second','total_workload_tokens_per_second','startup_seconds','startup_fraction','witness_seconds','proof_seconds','serialization_seconds','independent_verification_seconds','proof_latency_seconds','proof_lag_seconds','pipeline_drain_seconds','prefill','resident_passes','decode']:
    assert metrics[name] is None;checks+=1
assert r['counts']['full_schedules']==2790 and r['counts']['fixtures']==93;checks+=1
assert len(r['controls'])==5 and r['hardware']['threads']==1;checks+=1
assert r['wall_seconds']<60 and r['max_rss_kib']<512*1024;checks+=1
assert json.loads((HERE/'execution.json').read_text())['exit_code']==0;checks+=1
audit=json.loads((HERE/'audit.json').read_text());assert audit['status']=='passed';checks+=1
assert all(x['unchanged'] for x in audit['owner_memory']);checks+=1
for pin in json.loads((HERE/'native-current-comparison.json').read_text()):
    assert hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'];checks+=1
projection=r['unchanged_scoped_field_census']['results']
base=projection['prepared_scalar']['sum_api_ops'];candidate=projection['cubic_round0']['sum_api_ops']
assert base==3527474753 and candidate==3280010835;checks+=1
gain=(base-candidate)/base
assert .07015<gain<.07016;checks+=1
out=dict(status='passed',checks=checks,run_id=r['run_id'],cycle='0055',
         checkpoint_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
         sources_total=len(rows),sources_appended=len(new),historical_prefixes_preserved=True,
         native_proof_or_performance_gate=False,scoped_api_fraction=gain)
(HERE/'checkpoint-audit.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out))
