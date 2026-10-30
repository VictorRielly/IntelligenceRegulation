"""Final evidence/provenance consistency check; no native build or rerun."""
from pathlib import Path
import datetime,hashlib,json,re
D=Path(__file__).resolve().parent;R=D.parents[1]
checks=0
def check(b,msg):
 global checks
 checks+=1
 if not b:raise AssertionError(msg)
def sha(b):return hashlib.sha256(b).hexdigest()
result=json.loads((D/'result.json').read_text());check(result['status']=='PASS','result')
check((result['geometry_cases'],result['metadata_numeric_comparisons'],result['negative_controls'])==(216,2160,55),'counts')
pins=json.loads((D/'native-pins.json').read_text())
for p in pins:
 check(sha((D/p['snapshot']).read_bytes())==p['sha256'],'snapshot pin')
 check(sha(Path(p['path']).read_bytes())==p['sha256'],'native source changed')
metadata=(D/'metadata.rs').read_text()
for item in json.loads((D/'extraction.json').read_text())['methods']:
 name=item['name'];m=re.search(r'(?m)^\s*(?:pub(?:\([^)]*\))? )?fn '+name+r'\(',metadata)
 check(m is not None,'method missing')
 op=metadata.index('{',m.end());depth=0
 for end in range(op,len(metadata)):
  if metadata[end]=='{':depth+=1
  elif metadata[end]=='}':
   depth-=1
   if depth==0:break
 check(sha(metadata[m.start():end+1].encode())==item['sha256'],'extracted method drift')
startup=json.loads((D/'startup-manifest.json').read_text())
old_by_name={Path(p['path']).name:p for p in startup}
for name in ['FINDINGS.md','sources.jsonl']:
 p=old_by_name[name];snap=D/'startup'/str(Path(p['path']).relative_to(R.parents[1])).replace('/','__')
 check(sha(snap.read_bytes())==p['sha256'],'startup hash')
 check((R/name).read_bytes().startswith(snap.read_bytes()),'historical evidence changed')
for p in json.loads((D/'owner-document-recheck.json').read_text()):
 check(p['sha256_at_start']==p['sha256_now'] or bool(p.get('reviewed_change')),'owner doc changed: read latest before closing')
 check(sha(Path(p['path']).read_bytes())==p['sha256_now'],'owner doc changed since close')
sources=[json.loads(x) for x in (R/'sources.jsonl').read_text().splitlines()]
mine=[s for s in sources if s.get('run_id')=='20261030T114123Z-38ad9454']
check(len(mine)==8 and len(sources)==1087,'source append count')
check(len({s['id'] for s in mine})==len(mine),'duplicate cycle source IDs')
for s in mine:
 for key in ['access_date','publication_date','verified_update_date','inspected_commit_id','implementation_license','date_evidence']:
  check(key in s,'source metadata omitted')
 check(s['external_execution'] is False and s['reproduced_performance'] is False,'author reproduction mislabeled')
projection=result['selected_T128_noDD'];check((projection['a_rows'],projection['h_rows'],projection['slot_tables'])==(4577,4390,28),'selected geometry')
check(projection['round_capacity_bytes']==28*(2**19)*16,'round bytes')
for c in projection['cohorts']:
 check(c['data_plus_round_lower_bound_bytes']==c['jobs']*(projection['systematic_commitment_data_bytes']+projection['round_capacity_bytes']),'cohort lower bound')
 check(c['cpu_store_payload_subtotal_bytes']==c['jobs']*(projection['systematic_commitment_data_bytes']+projection['cpu_encoding_payload_bytes']+projection['round_capacity_bytes']),'CPU payload')
counter=json.loads((D/'counterexample.json').read_text())
check(counter['naive_underestimate']==112*2**20,'negative undercount')
check(counter['naive_second_admission_total']<=counter['budget']<counter['actual_second_admission_total'],'false admission')
check(counter['actual_fit_claim'] is False,'fit claim')
accounting=json.loads((D/'target-accounting.json').read_text())
for k in ['new_full_stack_proofs','new_passes','new_positions']:
 check(accounting[k]==0,'token accounting')
for k in ['actual_context','witness_s','proof_s','serialization_s','verification_s','startup_s','startup_fraction','steady_state_proved_tokens_s','total_workload_proved_tokens_s']:
 check(accounting[k] is None,'unmeasured clock')
for n in ['STATE.md','PROGRESS.md','progress/20261030T114123Z-38ad9454.md']:
 text=(R/n).read_text();check('No measured proving improvement' in text,'report outcome');check('unmeasured' in text,'clock scope');check('unachieved' in text,'target status')
check((D/'initial-dd-reference-omission/audit-execution.json').exists(),'initial failure omitted')
check(json.loads((D/'initial-dd-reference-omission/audit-execution.json').read_text())['exit_code']!=0,'initial failure status')
check(len(json.loads((D/'hypotheses.json').read_text()))==96,'hypotheses')
for n in ['prepare','compile','audit','close']:
 ex=json.loads((D/(n+'-execution.json')).read_text());check(ex['exit_code']==0,'stage failed');check(ex['max_rss_kib']<512*1024 and ex['wall_s']<60,'resource cap');check(ex['cpu_affinity_count']==1 and ex['gpu'] is False,'resources')
out=dict(status='PASS',checks=checks,native_pins=len(pins),source_records=len(sources),cycle_sources=len(mine),historical_prefixes_preserved=True,checked_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),scope='Evidence/provenance consistency only; no new proof,CPU/GPU performance,fit or security claim.')
(D/'final-audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
# Exclude mutable run wrapper logs/self-referential manifest. Hash all code,
# fixtures,source snapshots,web records and finalized reports deterministically.
manifest=[]
for p in sorted(D.rglob('*')):
 if p.is_file() and not any(s in p.parts for s in ['__pycache__']) and p.name not in ['artifact-manifest.json','final-audit.stdout.log','final-audit.stderr.log','final-audit-execution.json','commands.jsonl']:
  manifest.append(dict(path=str(p.relative_to(R)),bytes=p.stat().st_size,sha256=sha(p.read_bytes())))
for p in [R/'STATE.md',R/'PROGRESS.md',R/'progress/20261030T114123Z-38ad9454.md',R/'handoffs/20261030-public-cohort-admission.md']:
 manifest.append(dict(path=str(p.relative_to(R)),bytes=p.stat().st_size,sha256=sha(p.read_bytes())))
(D/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(out))
