"""Final integrity only; no repeated proving/benchmark work."""
import datetime,hashlib,json,pathlib,resource,time
H=pathlib.Path(__file__).resolve().parent;R=H.parent.parent
start=time.monotonic();checks=0
def check(x):
 global checks
 assert x
 checks+=1
source_before=(H/'startup/sources.jsonl').read_bytes();new=(H/'sources-cycle.jsonl').read_bytes()
check((R/'sources.jsonl').read_bytes()==source_before+new)
records=[json.loads(l) for l in (R/'sources.jsonl').read_text().splitlines() if l.strip()]
check(len(records)==932);check(len({r['id'] for r in records[-8:]})==8)
for r in records[-8:]:
 check(r['access_date']=='2026-10-29');check(r['run_id']=='20261029T095649Z-50135f2e');check(not r['reproduced_performance']);check(r['inspected_commit_id'] is None)
check((R/'FINDINGS.md').read_bytes().startswith((H/'startup/FINDINGS.md').read_bytes()))
check((R/'FINDINGS.md').read_text().count('Run `20261029T095649Z-50135f2e`')==1)
old=json.loads((H/'startup/prior-hypotheses.json').read_text());newh=json.loads((H/'hypotheses.json').read_text());check(len(old)==58);check(len(newh)==59)
check({x['rank'] for x in old}<={x['rank'] for x in newh})
for x in old:check(x['title']==next(y for y in newh if y['rank']==x['rank'])['title'])
check(json.loads((H/'cycle-ranking.json').read_text())['new']==[59])
compiled=json.loads((H/'compile-execution.json').read_text());probe=json.loads((H/'probe-execution.json').read_text())
for name,digest in compiled['rust_source_sha256'].items():check(hashlib.sha256((H/name).read_bytes()).hexdigest()==digest)
binary=hashlib.sha256((H/'probe').read_bytes()).hexdigest();check(binary==compiled['binary_sha256']==probe['binary_sha256'])
for pin in json.loads((H/'native-pins.json').read_text()):check(hashlib.sha256(pathlib.Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'])
acct=json.loads((H/'target-accounting.json').read_text())
for k in ['witness_s','proof_s','serialization_s','verification_s','startup_s','startup_fraction','steady_tokens_per_s','total_workload_tokens_per_s']:check(acct[k] is None)
check(acct['proved_positions']==acct['model_passes']==acct['complete_independently_verified_proofs']==0)
for p in [R/'STATE.md',R/'PROGRESS.md',R/'progress/20261029T095649Z-50135f2e.md',R/'handoffs/20261029-cpu-encode-prefix-scratch.md',H/'README.md']:
 text=p.read_text();check('20261029T095649Z-50135f2e' in text);check('unachieved' in text)
manifest=[]
for p in sorted(H.rglob('*')):
 if not p.is_file() or p.name in ['artifact-manifest.json','final-audit-result.json','final_audit.stdout.log','final_audit.stderr.log','final_audit-execution.json']:continue
 b=p.read_bytes();manifest.append({'path':str(p.relative_to(H)),'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b)})
(H/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
out={'status':'PASS_FINAL_INTEGRITY','checks':checks,'artifact_count':len(manifest),'elapsed_s':time.monotonic()-start,'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'full_stack_proofs':0,'proved_positions':0}
(H/'final-audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
