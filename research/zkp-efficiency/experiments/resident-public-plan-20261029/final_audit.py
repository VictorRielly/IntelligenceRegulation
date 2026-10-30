"""Final bounded consistency/provenance audit; no proof execution."""
from pathlib import Path
import datetime,hashlib,json,os,resource,signal,time
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_CPU,(20,20));resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2));signal.alarm(25)
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent.parent;start=time.monotonic();checks=0
def ck(x,msg):
 global checks
 checks+=1
 if not x:raise AssertionError(msg)
def sha(b):return hashlib.sha256(b).hexdigest()
for row in json.loads((HERE/'native-pins.json').read_text()):
 ck(sha(Path(row['path']).read_bytes())==row['sha256'],'native source pin')
 ck(sha((HERE/row['snapshot']).read_bytes())==row['sha256'],'native snapshot pin')
for row in json.loads((HERE/'owner-document-recheck.json').read_text()):ck(sha(Path(row['path']).read_bytes())==row['after_sha256'],'owner document pin')
for name in ['sources.jsonl','FINDINGS.md']:ck((ROOT/name).read_bytes().startswith((HERE/'startup'/name).read_bytes()),'all old ledger/findings bytes preserved')
prior=json.loads((HERE/'startup/prior-hypotheses.json').read_text());current=json.loads((HERE/'hypotheses.json').read_text())
ck(current[:60]==prior and len(current)==61,'all prior hypotheses plus one new')
src=[json.loads(x)for x in (HERE/'sources-cycle.jsonl').read_text().splitlines()];ledger=[json.loads(x)for x in (ROOT/'sources.jsonl').read_text().splitlines()]
ck(len(src)==9 and len(ledger)==964,'source counts');byid={s.get('id'):s for s in ledger}
for s in src:
 ck(byid[s['id']]==s,'cycle source equals ledger')
 ck(s['access_date']=='2026-10-29'and s['inspected_commit_id']is None,'date/commit unknown explicit')
 ck(not s['external_execution']and not s['reproduced_performance'],'no foreign execution/performance adoption')
r=json.loads((HERE/'result.json').read_text());t=json.loads((HERE/'target-accounting.json').read_text());c=json.loads((HERE/'completion.json').read_text())
ck(r['status']=='PASS'and r['comparisons']==9450 and r['negative_controls']==10,'probe evidence')
ck(r['model_passes']==r['full_stack_proofs']==r['proved_positions']==0,'zero new proofs')
ck(t['completed_model_passes']==t['new_proved_positions']==t['new_independently_verified_full_stack_proofs']==0,'target evidence')
for k in ['witness_s','proof_s','serialization_s','verification_s','startup_fraction','steady_state_tokens_per_s','total_workload_tokens_per_s']:ck(t[k]is None,'unmeasured model clock '+k)
run='20261029T135649Z-1526011b'
for f in [ROOT/'PROGRESS.md',ROOT/'STATE.md',ROOT/'progress'/f'{run}.md',HERE/'README.md',ROOT/'handoffs/20261029-resident-public-map-plan.md']:
 s=f.read_text();ck(run in s,'intact run id '+f.name)
 ck('unachieved'in s or 'target remains unachieved'in s,'no target claim '+f.name)
 ck('0 / 0 / 0'in s or '0new proofs'in s,'zero proof scope '+f.name)
 ck('20261029 T'not in s and 'bc0332 e'not in s,'identifiers intact '+f.name)
ck('bc0332e39904ca881d26c255581aa1ab6a0e73899141689960ec2262f8561830'in (ROOT/'handoffs/20261029-resident-public-map-plan.md').read_text(),'native SHA in handoff')
ck('https://arxiv.org/abs/2604.06664'in (HERE/'README.md').read_text(),'primary URL intact')
for row in json.loads((HERE/'artifact-manifest.json').read_text()):
 ck(sha((HERE/row['path']).read_bytes())==row['sha256'],'research artifact '+row['path'])
now=datetime.datetime.now(datetime.timezone.utc);ck(now<datetime.datetime(2026,10,29,14,16,49,tzinfo=datetime.timezone.utc),'deadline')
out={'status':'PASS','checks':checks,'utc':now.isoformat(),'elapsed_s':time.monotonic()-start,'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'native_pins':9,'owner_documents':6,'prior_source_records':955,'final_source_records':964,'hypotheses':61,'independently_verified_full_stack_proofs':0,'model_passes':0,'proved_positions':0,'external_review':False}
(HERE/'final-audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
