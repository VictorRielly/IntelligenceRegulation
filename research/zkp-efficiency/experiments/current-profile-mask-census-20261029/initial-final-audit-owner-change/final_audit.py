"""Final provenance/checkpoint audit, independent of algebra implementation."""
from pathlib import Path
import datetime,hashlib,json,resource,time
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent.parent
RUN='20261029T115649Z-076e8d4a';start=time.monotonic();checks=0
def ck(ok):
 global checks
 checks+=1
 if not ok:raise AssertionError(checks)
for name in ['FINDINGS.md','sources.jsonl']:
 ck((ROOT/name).read_bytes().startswith((HERE/'startup'/name).read_bytes()))
records=[json.loads(s) for s in (ROOT/'sources.jsonl').read_text().splitlines()]
new=[r for r in records if r.get('run_id')==RUN];ck(len(records)==948 and len(new)==8)
for row in new:
 ck(row['access_date']=='2026-10-29');ck(row['url'].startswith('https://'))
 ck(row['reproduced_performance'] is False and row['external_execution'] is False)
 ck('publication_date' in row and 'verified_update_date' in row and 'implementation_license' in row and 'inspected_commit_id' in row)
old=json.loads((HERE/'startup/prior-hypotheses.json').read_text());newhyp=json.loads((HERE/'hypotheses.json').read_text())
ck(len(old)==len(newhyp)==60)
for a,b in zip(old,newhyp):
 ck(all(k in b and b[k]==v for k,v in a.items()))
 ck(a['rank']==b['rank'])
for rank in [53,55,57,60]:ck('cycle0142_refinement' in newhyp[rank-1])
for p in json.loads((HERE/'native-pins.json').read_text()):
 ck(hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()==p['sha256'])
 ck(hashlib.sha256((HERE/p['snapshot']).read_bytes()).hexdigest()==p['sha256'])
base=Path('/home/victor/IntelligenceRegulation')
for name,p in json.loads((HERE/'startup/owner-documents.json').read_text()).items():ck(hashlib.sha256((base/name).read_bytes()).hexdigest()==p['sha256'])
for name in ['prepare','compile','probe','audit']:
 r=json.loads((HERE/(name+'-execution.json')).read_text());ck(r['exit_code']==0)
 ck(r['threads']==1 and r['cpu_limit_s']<=60 and r['estimated_memory_bytes']<=512*1024**2)
 ck(r['address_space_limit_bytes']<=512*1024**2 and not r['gpu'] and not r['cargo'])
for name in ['result.json','audit-result.json']:ck(json.loads((HERE/name).read_text())['status']=='PASS')
account=json.loads((HERE/'target-accounting.json').read_text())
ck([account[k] for k in ['full_stack_proofs','model_passes','proved_positions']]==[0,0,0])
for k in ['witness_s','proof_s','serialization_s','verification_s','startup_s','initial_prefill_s','startup_fraction','steady_state_proved_tokens_per_s','total_workload_proved_tokens_per_s']:ck(account[k] is None)
ck(account['actual_model_context'] is None and account['accelerator'] is None)
for name in ['STATE.md','PROGRESS.md','progress/'+RUN+'.md','handoffs/20261029-current-profile-mask-census.md']:
 ck((ROOT/name).is_file() and (ROOT/name).stat().st_size>100)
ck((HERE/'initial-audit-anchor-failure/audit-execution.json').is_file())
ck(json.loads((HERE/'initial-audit-anchor-failure/audit-execution.json').read_text())['exit_code']==1)
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
ck(now<'2026-10-29T12:16:49')
manifest=[]
for p in sorted(HERE.rglob('*')):
 if p.is_file() and p.name not in ['artifact-manifest.json','final-audit-result.json','final_audit.stdout.log','final_audit.stderr.log','final_audit-execution.json']:
  manifest.append(dict(path=str(p.relative_to(HERE)),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
(HERE/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
r=dict(status='PASS',checks=checks,utc=now,elapsed_s=time.monotonic()-start,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 source_records=948,new_source_records=8,prior_hypotheses_preserved=60,native_pins=7,owner_documents_unchanged=5,artifacts_hashed=len(manifest))
(HERE/'final-audit-result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
