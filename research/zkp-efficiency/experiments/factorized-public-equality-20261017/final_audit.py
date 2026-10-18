"""Small final retained-artifact/accounting audit; no native proof work."""
from pathlib import Path
import datetime,hashlib,json,os,resource,signal,time
H=Path(__file__).resolve().parent;R=H.parents[1]
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_AS,(512*2**20,512*2**20));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
start=time.perf_counter();checks=0
def J(n):return json.loads((H/n).read_text())
for n in ['result.json','audit-result.json','causality-result.json','accounting.json','source-append-audit.json']:
 assert J(n)['status']=='PASS';checks+=1
result=J('result.json');assert result['counts']['fixtures']==84 and len(result['negative_controls'])==22;checks+=2
assert hashlib.sha256((H/'fixtures.json').read_bytes()).hexdigest()==result['fixture_sha256'];checks+=1
assert J('audit-result.json')['checks']==4768 and J('causality-result.json')['unchanged_prior_round_checks']==1699;checks+=2
source=(R/'sources.jsonl').read_bytes();prefix=(H/'startup/sources.jsonl').read_bytes()
assert source.startswith(prefix)and len(source.splitlines())==371;checks+=2
findings=(R/'FINDINGS.md').read_bytes();assert findings.startswith((H/'startup/FINDINGS.md').read_bytes());checks+=1
prior=json.loads((H.parent/'ragged-logup-rounds-20261017/accounting.json').read_text());account=J('accounting.json')
for old,new in zip(prior['groups'],account['groups']):
 for k in ['rows','columns','padded_columns']:assert old[k]==new[k];checks+=1
 assert old['row_first_pairs']==new['row_first_pairs'];checks+=1
 assert new['old_index_three_factor_payload_B']==56*old['queries'];checks+=1
 assert new['new_value_payload_B']==16*old['queries'];checks+=1
assert sum(g['new_value_payload_B']for g in account['groups'])==187432960;checks+=1
assert account['aggregate_payload_only']['new_small_payload_B']==35584;checks+=1
assert account['aggregate_payload_only']['new_conservative_payload_B']==187468544;checks+=1
assert max(g['new_conservative_payload_B']for g in account['groups'])==int(account['aggregate_payload_only']['max_group_payload_MiB']*2**20);checks+=1
base=J('baseline.json');events=J('owner/events.json');proved=next(e['event']for e in events if e['event']['event']=='proved');verified=next(e['event']for e in events if e['event']['event']=='verified')
assert base['app_total_s']==proved['total_seconds']==191.755;checks+=1
assert base['seal_s']==37.214 and base['seal_fraction']==37.214/191.755;checks+=2
assert base['seal_witness_sum_s']==32.584 and base['sealing_load_sum_s']==35.798;checks+=2
assert base['inclusive_prove_s']-base['prove_reload_s']==base['proof_serialization_sink_remainder_s']==135.375;checks+=1
assert base['fresh_verify_s']==verified['verify_seconds']==32.248;checks+=1
assert base['receipt_bytes']==proved['receipt_bytes']==verified['receipt_bytes']==465815776;checks+=1
assert J('owner/prove.guard.json')['exit']==0 and J('owner/verify.guard.json')['exit']==0;checks+=2
bound=account['direct_phase_deletion_bound'];assert abs(bound['charged_s']-21.568)<1e-10;checks+=1
assert abs(bound['zero_cost_deletion_speedup']-191.755/(191.755-21.568))<1e-12;checks+=1
for p in J('native-pins.json'):
 assert hashlib.sha256((H/p['capture']).read_bytes()).hexdigest()==p['sha256'];checks+=1
for p in J('owner-pins.json'):
 if not p['capture'].startswith('only '):assert hashlib.sha256((H/p['capture']).read_bytes()).hexdigest()==p['sha256'];checks+=1
for p in [R/'STATE.md',R/'PROGRESS.md',R/'progress/20261017T232105Z-d713e393.md',R/'handoffs/20261017-factorized-public-equality.md']:
 assert p.is_file()and '20261017T232105Z-d713e393'in p.read_text();checks+=1
out=dict(status='PASS',checks=checks,wall_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,native_proofs_generated=0,target_compliant_positions=0,scope='Artifact/source-prefix/counted-payload/owner-event consistency only; not cryptographic verification.',completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(H/'final-audit.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
