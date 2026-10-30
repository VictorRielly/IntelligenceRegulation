"""Provenance and accounting audit; does not repeat passed experiments."""
from pathlib import Path
import datetime,hashlib,json,difflib
D=Path(__file__).resolve().parent;R=D.parent.parent
checks=0
def check(x,msg):
 global checks
 checks+=1
 if not x:raise AssertionError(msg)
def sha(b):return hashlib.sha256(b).hexdigest()
result=json.loads((D/'result.json').read_text());check(result['status']=='PASS','result pass')
check(result['checks']==4600 and result['negative_controls']==249,'counters')
check(result['native_constructors'] is False and result['gpu'] is False,'scope')
for pin in json.loads((D/'native-pins.json').read_text()):
 check(sha(Path(pin['path']).read_bytes())==pin['sha256'],'native source unchanged')
 check(sha((D/pin['snapshot']).read_bytes())==pin['sha256'],'snapshot unchanged')
old=(D/'startup/research__zkp-efficiency__sources.jsonl').read_bytes();new=(R/'sources.jsonl').read_bytes()
check(new.startswith(old),'prior source bytes preserved')
extra=new[len(old):];check(extra==(D/'source-records.jsonl').read_bytes(),'append exact')
records=[json.loads(s) for s in extra.splitlines()];check(len(records)==8,'source count')
for s in records:
 check(s['access_date']=='2026-10-30','source access date');check(s['run_id']=='20261030T124123Z-126f56e8','source run');check(not s['reproduced_performance'] and not s['external_execution'],'source performance scope');check(s['url'].startswith('https://'),'exact source URL')
oldf=(D/'startup/research__zkp-efficiency__FINDINGS.md').read_bytes();check((R/'FINDINGS.md').read_bytes().startswith(oldf),'prior findings preserved')
previous=json.loads((D/'prior-hypotheses.json').read_text());current=json.loads((D/'hypotheses.json').read_text())
check(len(current)==97,'hypothesis97');check(previous[:95]==current[:95],'prior95 unchanged');check(previous[-1]['rank']==96 and current[-1]['rank']==97,'refinement/new IDs')
account=json.loads((D/'target-accounting.json').read_text())
for k in ['new_full_stack_proofs','new_passes','new_positions','gpu_count','resident_model_passes']:check(account[k]==0,k)
for k in ['actual_context','witness_s','proof_s','serialization_s','verification_s','startup_s','startup_fraction','steady_state_proved_tokens_s','total_workload_proved_tokens_s']:check(account[k] is None,k)
for stage in ['prepare','compile','audit']:
 e=json.loads((D/(stage+'-execution.json')).read_text());check(e['exit_code']==0,stage+' exit');check(e['wall_s']<60,stage+' time');check(e['max_rss_kib']<512*1024,stage+' memory');check(e['cpu_affinity_count']==1 and e['address_space_mib']==384,stage+' caps')
check(result['selected']['max_known_payload']==6205943536,'selected payload')
check(result['counterexample']['excess_bytes']==5242880,'counterexample')
check(len(json.loads((D/'phase-projections.json').read_text()))==648,'projection cases')
for name in ['STATE.md','PROGRESS.md','progress/20261030T124123Z-126f56e8.md']:
 s=(R/name).read_text();check('20261030T124123Z-126f56e8' in s,'report run');check('unmeasured' in s and '0 / 0 / 0' in s,'report target scope')
# Confirm reused extraction bodies against the freshly pinned native sources.
ex=json.loads((D.parent/'public-cohort-admission-20261030/extraction.json').read_text())
md=(D/'metadata.rs').read_text();shape=(D/'native/hashline__src__private_block__shape.rs').read_text()
for m in ex['methods']:
 name=m['name'];start=md.index('fn '+name+'(');a=md.index('{',start);depth=0
 for i in range(a,len(md)):
  if md[i]=='{':depth+=1
  if md[i]=='}':
   depth-=1
   if depth==0:break
 body=md[start:i+1]
 check(body in shape,'unchanged metadata body '+name)
start=md.index('fn domain_log_at(');a=md.index('{',start);depth=0
for i in range(a,len(md)):
 if md[i]=='{':depth+=1
 if md[i]=='}':
  depth-=1
  if depth==0:break
check(md[start:i+1] in (D/'native/hashline__src__private_block__layout.rs').read_text(),'unchanged domain_log_at body')
# Documents owned by others may change; retain and describe drift,never fail
# a research result for unrelated owner updates or overwrite those documents.
drift=[]
for p in json.loads((D/'startup-manifest.json').read_text()):
 path=Path(p['path'])
 if '/research/zkp-efficiency/' in p['path']:continue
 b=path.read_bytes();changed=sha(b)!=p['sha256'];drift.append(dict(path=p['path'],startup_sha256=p['sha256'],closing_sha256=sha(b),changed=changed))
 if changed:
  (D/('closing-'+path.name)).write_bytes(b)
  diff=''.join(difflib.unified_diff((D/p['snapshot']).read_text().splitlines(True),b.decode().splitlines(True),fromfile='startup',tofile='closing'))
  (D/('closing-'+path.name+'.diff')).write_text(diff)
(D/'owner-document-recheck.json').write_text(json.dumps(drift,indent=2)+'\n')
manifest=[]
for p in sorted(D.rglob('*')):
 if p.is_file() and p.name not in ['artifact-manifest.json','final-audit-result.json','final-audit.stdout.log','final-audit.stderr.log','final-audit-execution.json','commands.jsonl']:
  b=p.read_bytes();manifest.append(dict(path=str(p.relative_to(D)),bytes=len(b),sha256=sha(b)))
(D/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
out=dict(status='PASS',checks=checks,checkpoint_utc=now,source_pins=10,new_sources=8,prior_source_records=1087,artifact_files=len(manifest),owner_documents_changed=[p['path'] for p in drift if p['changed']],target_achieved=False)
(D/'final-audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
