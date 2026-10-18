"""Checkpoint consistency audit; no arithmetic benchmark rerun."""
from pathlib import Path
import datetime,hashlib,json,os,resource,signal,time
H=Path(__file__).resolve().parent;R=H.parent.parent
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_AS,(512*2**20,512*2**20));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
start=time.perf_counter();checks=0
def check(x):
 global checks
 assert x;checks+=1
r=json.loads((H/'result.json').read_text());a=json.loads((H/'audit-result.json').read_text());o=json.loads((H/'operations.json').read_text());ac=json.loads((H/'accounting.json').read_text())
for x in [r,a,o,ac]:check(x['status']=='PASS')
check(r['counts']['fixtures']==a['fixtures']==o['fixtures']==132)
check(r['counts']['round_values']==3020 and a['original_table_rounds']==755)
check(len(r['negative_controls'])==23 and all(r['negative_controls'].values()))
check(hashlib.sha256((H/'fixtures.json').read_bytes()).hexdigest()==r['fixture_sha256'])
check(hashlib.sha256((H/'counted.rs').read_bytes()).hexdigest()==o['counted_source_sha256'])
for x in json.loads((H/'source-pins.json').read_text()):check(hashlib.sha256((H/x['capture']).read_bytes()).hexdigest()==x['sha256'])
for x in json.loads((H/'baseline-pins.json').read_text()):check(hashlib.sha256((H/x['capture']).read_bytes()).hexdigest()==x['sha256'])
old=(H/'startup/sources.jsonl').read_bytes();new=(R/'sources.jsonl').read_bytes();check(new.startswith(old))
records=[json.loads(x)for x in new.splitlines()];check(len(records)==377)
check(len([x for x in records if x.get('run_id')==r['run_id']])==6)
check((R/'FINDINGS.md').read_bytes().startswith((H/'startup/FINDINGS.md').read_bytes()))
for p in [R/'STATE.md',R/'PROGRESS.md',R/'FINDINGS.md',R/'progress/20261018T002105Z-32d7e4fc.md',R/'handoffs/20261018-pending-fold-weighted-round.md']:
 check(r['run_id'] in p.read_text())
b=ac['baseline'];check(b['passes']==1 and b['context']==128 and b['steady_state_positions_per_s'] is None)
check(b['serialization_s'] is None and b['controls']['refused']==11)
check(abs(b['sealing_fraction']-105.287/606.598)<1e-15)
check(ac['aggregate_core_row_census']['row_reads_saved']==11714394)
check(ac['aggregate_core_row_census']['extra_column_subs']==330)
state=(R/'STATE.md').read_text();check('01:21:05' in state and '0/0/0' in state and 'COMPLETE' in state)
out=dict(status='PASS',checks=checks,scope='Artifact consistency and preserved-history audit only; no cryptographic verification or speed measurement.',wall_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(H/'final-audit.json').write_text(json.dumps(out,indent=2)+'\n');(H/'final-audit.log').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
