import datetime, hashlib, json, pathlib
D=pathlib.Path(__file__).resolve().parent;R=D.parents[1]
checks=0
def check(x):
 global checks
 assert x
 checks+=1
prior_findings=(D/'startup/2-FINDINGS.md').read_bytes()
prior_sources=(D/'startup/3-sources.jsonl').read_bytes()
check((R/'FINDINGS.md').read_bytes().startswith(prior_findings))
check((R/'sources.jsonl').read_bytes()==prior_sources+(D/'source-records.jsonl').read_bytes())
old=json.loads((D/'startup/prior-hypotheses.json').read_text());new=json.loads((D/'hypotheses.json').read_text())
check(len(old)==88 and new[:88]==old and len(new)==90)
records=[json.loads(x) for x in (D/'source-records.jsonl').read_text().splitlines()]
check(len(records)==6)
for row in records:
 for key in ['access_date','publication_date','verified_update_date','url','implementation_license','inspected_commit_id','assessment']:
  check(key in row)
 check(row['access_date']=='2026-10-30' and row['reproduced_performance'] is False)
for pin in json.loads((D/'source-pins.json').read_text()):
 check(hashlib.sha256(pathlib.Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'])
 check(hashlib.sha256((D/pin['snapshot']).read_bytes()).hexdigest()==pin['sha256'])
cuda=(D/'native/project/hashline/src/gpu/cuda.rs').read_text();a=cuda.index('pub fn dev_fold_rows(');z=cuda.index('\n}',a)+2
check((D/'native_fold.rs').read_text()==cuda[a:z]+'\n')
for name in ['prepare','compile','probe','audit','close']:
 e=json.loads((D/(name+'-execution.json')).read_text());check(e['exit_code']==0);check(e['wall_s']<60);check(e['max_rss_kib']<512*1024);check(e['cpu_affinity_count']==1)
r=json.loads((D/'result.json').read_text());check(r['status']=='PASS');check(r['fixtures']==326 and r['successful']==110 and r['errors_or_panics']==216);check(r['payload_limbs']==2154);check(r['reference_checks']==2934);check(len(r['negative_controls'])==8)
check(r['full_stack_proofs']==r['passes']==r['positions']==0)
for f in [R/'STATE.md',R/'PROGRESS.md',R/'progress/20261030T074123Z-71d2f333.md',R/'handoffs/20261030-fold-timer-attribution.md',D/'README.md',D/'MEASUREMENT.md']:
 t=f.read_text();check('No measured proving improvement' in t or f.name=='MEASUREMENT.md');check(len(t)>100)
# Report current durable-doc drift without treating old status as new evidence.
drift=[]
for p in json.loads((D/'startup-index.json').read_text()):
 if '/docs/zkmatrix-poc/' in p['path'] or p['path'].endswith('/CLAUDE.md') or p['path'].endswith('/AGENDA.md'):
  if hashlib.sha256(pathlib.Path(p['path']).read_bytes()).hexdigest()!=p['sha256']:drift.append(p['path'])
manifest=[]
volatile={'artifact-manifest.json','final-audit-result.json','final-audit.stdout.log','final-audit.stderr.log','final-audit-execution.json','commands.jsonl'}
for f in sorted(D.rglob('*')):
 if f.is_file() and f.name not in volatile:
  b=f.read_bytes();manifest.append(dict(path=str(f.relative_to(D)),bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
(D/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
result=dict(status='PASS',checks=checks,time_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),all88prior_hypotheses_preserved=True,prior_findings_sources_preserved=True,production_pins_unchanged=True,mandatory_doc_drift=drift,source_count=len((R/'sources.jsonl').read_text().splitlines()),artifacts=len(manifest),full_stack_proofs=0,passes=0,positions=0,target_achieved=False)
(D/'final-audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
