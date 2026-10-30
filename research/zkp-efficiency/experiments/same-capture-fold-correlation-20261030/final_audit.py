import datetime, hashlib, json, pathlib
D=pathlib.Path(__file__).resolve().parent;R=D.parents[1]
checks=0
def ck(x):
 global checks
 assert x
 checks+=1
original_findings=(D/'startup/research__zkp-efficiency__FINDINGS.md').read_bytes()
original_sources=(D/'startup/research__zkp-efficiency__sources.jsonl').read_bytes()
ck((R/'FINDINGS.md').read_bytes().startswith(original_findings))
ck((R/'sources.jsonl').read_bytes()==original_sources+(D/'source-records.jsonl').read_bytes())
old=json.loads((R/'experiments/fold-timer-attribution-20261030/hypotheses.json').read_text())
new=json.loads((D/'hypotheses.json').read_text())
ck(len(old)==90 and new[:90]==old and len(new)==93)
records=[json.loads(x) for x in (D/'source-records.jsonl').read_text().splitlines()]
ck(len(records)==6)
for r in records:
 for k in ['access_date','publication_date','verified_update_date','url','implementation_license','inspected_commit_id','assessment']:
  ck(k in r)
 ck(r['access_date']=='2026-10-30' and r['reproduced_performance'] is False)
for pin in json.loads((D/'source-pins.json').read_text()):
 ck(hashlib.sha256(pathlib.Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'])
 ck(hashlib.sha256((D/pin['snapshot']).read_bytes()).hexdigest()==pin['sha256'])
for stage in ['prepare','compile','audit','close']:
 e=json.loads((D/(stage+'-execution.json')).read_text())
 ck(e['exit_code']==0);ck(e['wall_s']<60);ck(e['max_rss_kib']<512*1024);ck(e['cpu_affinity_count']==1)
r=json.loads((D/'result.json').read_text())
ck(r['status']=='PASS' and r['fixtures']==225 and r['ordinary_valid']==182 and r['known_limitation_accepted']==1 and r['invalid']==42)
ck(r['reference_numeric_fields']==37238 and r['joined_activities']==6495)
ck(r['full_stack_proofs']==r['passes']==r['positions']==0)
ck(len(r['negative_controls'])==42)
counter=json.loads((D/'counterexamples.json').read_text())
ck(counter['overlap_summed_activity_ticks']==42 and counter['overlap_device_union_ticks']==21)
ck(counter['whole_call_and_roster_and_manifest_coherent_deletion'].startswith('ACCEPTED'))
for name in ['STATE.md','PROGRESS.md','progress/20261030T084123Z-931751cb.md','handoffs/20261030-same-capture-fold-correlation.md']:
 t=(R/name).read_text();ck('No measured proving improvement' in t);ck('unmeasured' in t);ck('coherent' in t)
drift=[]
for pin in json.loads((D/'startup/index.json').read_text()):
 p=pathlib.Path(pin['path'])
 if p.name in ['CLAUDE.md','AGENDA.md','MVP_STATUS.md','ZK60_DECISIONS.md','ZK60_CODEX_FABLE_COORDINATION.md','ZK60_THROUGHPUT_TARGET.md']:
  if hashlib.sha256(p.read_bytes()).hexdigest()!=pin['sha256']:drift.append(str(p))
manifest=[]
volatile={'artifact-manifest.json','final-audit-result.json','final-audit.stdout.log','final-audit.stderr.log','final-audit-execution.json','commands.jsonl'}
for p in sorted(D.rglob('*')):
 if p.is_file() and p.name not in volatile:
  b=p.read_bytes();manifest.append({'path':str(p.relative_to(D)),'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()})
(D/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
out={'status':'PASS','checks':checks,'time_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'all90prior_hypotheses_preserved':True,'prior_findings_sources_preserved':True,'production_pins_unchanged':True,'mandatory_doc_drift':drift,'source_count':len((R/'sources.jsonl').read_text().splitlines()),'artifacts':len(manifest),'full_stack_proofs':0,'passes':0,'positions':0,'target_achieved':False}
(D/'final-audit-result.json').write_text(json.dumps(out,indent=2)+'\n'); print(json.dumps(out))
