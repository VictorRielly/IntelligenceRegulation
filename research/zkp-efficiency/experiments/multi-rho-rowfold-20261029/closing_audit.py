from pathlib import Path
import json,hashlib,datetime,resource,os,signal
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_AS,(384*1024**2,384*1024**2));resource.setrlimit(resource.RLIMIT_CPU,(40,40));signal.alarm(45)
D=Path(__file__).resolve().parent;R=D.parent.parent;checks=0
def check(x):
 global checks
 assert x;checks+=1
old=(D/'startup/03-sources.jsonl').read_bytes();ledger=(R/'sources.jsonl').read_bytes();new=(D/'sources-cycle.jsonl').read_bytes()
check(ledger==old+new);check(len(ledger.splitlines())==987);check(len(new.splitlines())==9)
check((R/'FINDINGS.md').read_bytes().startswith((D/'startup/02-FINDINGS.md').read_bytes()))
a=json.loads((D/'hypotheses.json').read_text());b=json.loads((D/'startup/05-hypotheses.json').read_text());check(a[:64]==b);check(len(a)==66)
for x in a[-2:]:
 for k in ['baseline','eliminated_work','added_costs','prerequisites','integration_cost','exactness','privacy_soundness','compatibility','end_to_end_ceiling','falsification']:check(bool(x[k]))
for x in json.loads(new.decode().splitlines()[0]) if False else [json.loads(l)for l in new.splitlines()]:
 for k in ['access_date','url','publication_date','verified_update_date','implementation_license','inspected_commit_id']:check(k in x)
check(all(x['unchanged']for x in json.loads((D/'owner-document-recheck.json').read_text())['documents']))
for x in json.loads((D/'native-pins.json').read_text()):
 check(hashlib.sha256((D/x['snapshot']).read_bytes()).hexdigest()==x['sha256'])
 if not x.get('mutable_owner_report'):check(hashlib.sha256(Path(x['path']).read_bytes()).hexdigest()==x['sha256'])
for name in ['result.json','cpp-result.json','account-result.json','audit-result.json']:check(json.loads((D/name).read_text())['status']=='PASS')
x=json.loads((D/'target-accounting.json').read_text());check(x['independently_verified_full_stack_proofs']==x['completed_model_passes']==x['proved_positions']==0)
for k in ['witness_seconds','proof_seconds','serialization_seconds','verification_seconds','startup_fraction','steady_state_proved_tokens_per_second','total_workload_proved_tokens_per_second']:check(x[k]is None)
for p in [R/'STATE.md',R/'PROGRESS.md',R/'progress/20261029T165649Z-7b8b834a.md',R/'handoffs/20261029-public-rho-rowfold.md',D/'README.md']:
 check(p.is_file());check('No native proving' in p.read_text()or'No native proving'in p.read_text().replace('**',''))
now=datetime.datetime.now(datetime.timezone.utc);check(now<datetime.datetime(2026,10,29,17,16,49,tzinfo=datetime.timezone.utc))
entries=[]
for p in sorted(D.rglob('*')):
 if p.is_file()and p.name not in ['artifact-manifest.json','closing-audit-result.json']:
  v=p.read_bytes();entries.append(dict(path=str(p.relative_to(D)),bytes=len(v),sha256=hashlib.sha256(v).hexdigest()))
(D/'artifact-manifest.json').write_text(json.dumps(entries,indent=2)+'\n')
result=dict(status='PASS',checks=checks,utc=now.isoformat(),artifact_files_hashed=len(entries),prior_hypotheses_preserved=64,prior_source_records_preserved=978,source_records_added=9,source_records_total=987,prior_findings_prefix_preserved=True,model_work=0)
(D/'closing-audit-result.json').write_text(json.dumps(result,indent=2)+'\n')
with (R/'STATE.md').open('a')as f:f.write('\nClosing audit '+now.isoformat()+f': {checks} checks PASS; {len(entries)} experiment files hashed. Prior history/source records/hypotheses preserved; zero new model work.\n')
print(json.dumps(result))
