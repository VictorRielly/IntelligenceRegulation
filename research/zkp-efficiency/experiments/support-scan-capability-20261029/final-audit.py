from pathlib import Path
import json,hashlib,resource,signal,os,time,datetime
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
resource.setrlimit(resource.RLIMIT_CPU,(20,20));resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2));signal.alarm(25)
start=time.monotonic();base=Path.cwd();ex=base/'experiments/support-scan-capability-20261029';checks=0
def ck(x,s):
 global checks
 checks+=1
 assert x,s
for name,snapshot in [('FINDINGS.md','02-FINDINGS.md'),('sources.jsonl','03-sources.jsonl')]:
 ck((base/name).read_bytes().startswith((ex/'startup'/snapshot).read_bytes()),'prior bytes preserved '+name)
prior=json.loads((ex/'startup/14-hypotheses.json').read_text());new=json.loads((ex/'hypotheses.json').read_text())
ck(len(prior)==49 and len(new)==51,'hypothesis count')
for old,now in zip(prior,new):
 ck(old['rank']==now['rank'],'rank preserved')
 if old['rank'] not in [7,28]:ck(old==now,'prior hypothesis unchanged')
ck([r['rank'] for r in new]==list(range(1,52)),'rank uniqueness')
rr=json.loads((ex/'result.json').read_text());audit=json.loads((ex/'audit-result.json').read_text())
ck(rr['checks']==23112 and rr['fixtures']==32 and rr['single_byte_mutations']==11040,'result')
ck(audit['checks']==201,'source audit')
for name,sha in rr['hashes'].items():ck(hashlib.sha256((ex/name).read_bytes()).hexdigest()==sha,'executed source preserved')
for pin in json.loads((ex/'native-pins.json').read_text()):
 ck(hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'],'native unchanged')
 ck(hashlib.sha256((ex/pin['snapshot']).read_bytes()).hexdigest()==pin['sha256'],'native snapshot')
direction=[]
for row in json.loads((ex/'startup-manifest.json').read_text()):
 ck(hashlib.sha256((ex/row['snapshot']).read_bytes()).hexdigest()==row['sha256'],'startup snapshot')
 if 'zkp-efficiency' in row['path']:continue
 p=Path(row['path']);h=hashlib.sha256(p.read_bytes()).hexdigest()
 if h!=row['sha256']:
  ck(p.name=='ZK60_DECISIONS.md','only known concurrent direction change')
  ck((ex/('final-'+p.name)).read_bytes()==p.read_bytes(),'final direction reread saved')
 direction.append(dict(path=str(p),sha256=h,changed_since_start=h!=row['sha256']))
sources=[json.loads(l) for l in (base/'sources.jsonl').read_text().splitlines() if l.strip()]
records=json.loads((ex/'sources-cycle.json').read_text());ck(len(sources)==873,'source count')
ck(sources[-8:]==records,'exact appended records')
for rec in records:
 for key in ['access_date','publication_date','verified_update_date','inspected_commit_id','implementation_license','url','assessment','evidence_kind']:
  ck(key in rec,'source qualification '+key)
 ck(rec['reproduced_performance']==False and rec['external_execution']==False,'no external reproduction')
for i in range(1,10):
 ck(any((ex/'web').glob(f'{i:02}-*.json')),'web response retained')
p=rr['proof_accounting'];ck(p['independently_verified_full_stack_proofs']==p['passes']==p['countable_positions']==0,'proof count')
for key in ['context_length','startup_s','prefill_s','startup_fraction','witness_s','proof_s','serialization_s','verification_s','proof_latency_s','proof_bytes','steady_state_positions_s','total_workload_positions_s']:
 ck(p[key] is None,'unmeasured '+key)
for path in ['STATE.md','PROGRESS.md','progress/20261029T025649Z-b1039010.md','handoffs/20261029-support-checked-borrow.md']:
 ck((base/path).is_file(),'required report')
ck(hashlib.sha256((base/'AGENDA.md').read_bytes()).hexdigest()==json.loads((ex/'startup-manifest.json').read_text())[0]['sha256'],'agenda unchanged')
out=dict(status='PASS_PROVENANCE_ACCOUNTING_ONLY',checks=checks,elapsed_s=time.monotonic()-start,
 peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,final_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
 native_pins=8,prior_sources_preserved=865,sources_now=873,prior_hypotheses_preserved=49,hypotheses_now=51,direction=direction)
(ex/'final-audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({k:out[k] for k in ['status','checks','elapsed_s','peak_rss_kib','final_utc']}))
