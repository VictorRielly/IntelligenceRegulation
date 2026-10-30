import os,resource,signal,time
resource.setrlimit(resource.RLIMIT_CPU,(40,40));resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2))
signal.alarm(45);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
from pathlib import Path
import json,hashlib,datetime
T=time.perf_counter();E=Path(__file__).resolve().parent;B=E.parents[1];checks=0
def ck(x):
 global checks
 checks+=1
 if not x:raise AssertionError(checks)
sha=lambda b:hashlib.sha256(b).hexdigest()
startup=json.loads((E/'startup-manifest.json').read_text())
for p in startup:ck(sha((E/p['snapshot']).read_bytes())==p['sha256'])
old_find=(E/'startup/02-FINDINGS.md').read_bytes();ck((B/'FINDINGS.md').read_bytes().startswith(old_find))
old=(E/'startup/03-sources.jsonl').read_bytes();current=(B/'sources.jsonl').read_bytes();ck(current.startswith(old))
rows=[json.loads(l) for l in current.splitlines()];ck(len(rows)==865)
own=json.loads((E/'sources-cycle.json').read_text());ck(len(own)==8);ck(rows[-8:]==own)
for p in own:
 ck(p['access_date']=='2026-10-29');ck(p['reproduced_performance'] is False);ck(p['url'].startswith('https://'));ck('date_evidence' in p);ck('implementation_license' in p);ck('inspected_commit_id' in p)
prior=json.loads((E/'startup/13-hypotheses.json').read_text());new=json.loads((E/'hypotheses.json').read_text());ck(len(prior)==48);ck(len(new)==49)
for x in prior:
 y=next(y for y in new if y['rank']==x['rank'])
 ck(x==y if x['rank']!=7 else all(x[k]==y[k] for k in x if k not in ('title','prerequisites')))
for p in json.loads((E/'native-pins.json').read_text()):ck(sha(Path(p['path']).read_bytes())==p['sha256']);ck(sha((E/p['snapshot']).read_bytes())==p['sha256'])
direction=json.loads((E/'final-direction-check.json').read_text())
for p in direction['documents']:ck(p['unchanged']);ck(sha(Path(p['path']).read_bytes())==p['now'])
r=json.loads((E/'result.json').read_text());a=json.loads((E/'audit-result.json').read_text())
for n,h in r['source_hashes'].items():ck(sha((E/n).read_bytes())==h)
ck(r['checks']==5150);ck(r['negative_controls']==2584);ck(a['checks']==97)
for k in ('passes','countable_positions','independently_verified_full_stack_proofs'):ck(r['proof_accounting'][k]==0)
for k in ('context_length','startup_s','prefill_s','startup_fraction','witness_s','proof_s','serialization_s','verification_s','steady_state_positions_s','total_workload_positions_s'):ck(r['proof_accounting'][k] is None)
for c in json.loads((E/'commands.json').read_text()):ck(c['exit_code']==0);ck(sha((E/Path(c['argv'][-1]).name).read_bytes())==c['script_sha256'])
for f in ('STATE.md','PROGRESS.md','progress/20261029T015649Z-e607e256.md','handoffs/20261029-layer-identity-sha.md'):
 b=(B/f).read_text();ck('20261029T015649Z-e607e256' in b);ck('50' in b);ck('unachieved' in b)
now=datetime.datetime.now(datetime.timezone.utc);ck(now<datetime.datetime(2026,10,29,2,16,49,tzinfo=datetime.timezone.utc))
out={'status':'PASS_FINAL_PROVENANCE_ONLY','checks':checks,'checked_at_utc':now.isoformat(),'elapsed_s':time.perf_counter()-T,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'sources':865,'prior_hypotheses_preserved':48,'hypotheses':49,'native_pins_unchanged':6,'direction_documents_unchanged':7,'no_native_or_GPU_execution':True}
(E/'final-audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
