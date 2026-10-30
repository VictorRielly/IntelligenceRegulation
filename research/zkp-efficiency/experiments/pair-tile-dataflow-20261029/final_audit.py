"""Check report provenance, owner pins, retained negatives and target accounting."""
from pathlib import Path
import datetime,hashlib,json,time
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent.parent
start=time.monotonic();checks=0
def ck(x,label=''):
 global checks
 checks+=1
 if not x:raise AssertionError(label)
def sha(b):return hashlib.sha256(b).hexdigest()
startup=json.loads((HERE/'required-reading-index.json').read_text());owner=[]
for row in startup:
 b=(HERE/row['snapshot']).read_bytes();ck(sha(b)==row['sha256'],'startup snapshot')
 if '/docs/zkmatrix-poc/'in row['path'] or row['path'].endswith('/CLAUDE.md'):
  current=Path(row['path']).read_bytes();owner.append(dict(path=row['path'],startup_sha256=row['sha256'],final_sha256=sha(current),unchanged=sha(current)==row['sha256']))
(HERE/'owner-document-recheck.json').write_text(json.dumps(owner,indent=2)+'\n')
ck(all(x['unchanged']for x in owner),'owner direction changed;explicit reread required')
priorfind=(HERE/'startup/research__zkp-efficiency__FINDINGS.md').read_text();currentfind=(ROOT/'FINDINGS.md').read_text();ck(currentfind.startswith(priorfind));ck('Cycle0143' in currentfind[len(priorfind):])
priorsrc=(HERE/'startup/research__zkp-efficiency__sources.jsonl').read_text();current=(ROOT/'sources.jsonl').read_text();new=(HERE/'sources-cycle.jsonl').read_text();ck(current==priorsrc+new)
records=[json.loads(x)for x in current.splitlines()if x.strip()];ck(len(records)==955)
for row in records[-7:]:
 for key in ('url','access_date','publication_date','verified_update_date','implementation_license','inspected_commit_id','date_evidence'):ck(key in row,key)
 ck(row['run_id']=='20261029T125649Z-54c94436');ck(not row['external_execution']and not row['reproduced_performance'])
prior=json.loads((HERE/'startup/research__zkp-efficiency__experiments__current-profile-mask-census-20261029__hypotheses.json').read_text());hyp=json.loads((HERE/'hypotheses.json').read_text());ck(len(prior)==len(hyp)==60)
for p,h in zip(prior[:-1],hyp[:-1]):ck(p==h,'older hypothesis preserved')
ck(hyp[-1]['prior_cycle0142']==prior[-1],'previous60 retained')
a=json.loads((HERE/'target-accounting.json').read_text())
for k in ('full_stack_proofs','model_passes','proved_positions','device_count'):ck(a[k]==0,k)
for k in ('witness_s','proof_s','serialization_s','verification_s','startup_s','initial_prefill_s','startup_fraction','steady_state_proved_tokens_per_s','total_workload_proved_tokens_per_s'):ck(a[k]is None,k)
for name in ('STATE.md','PROGRESS.md','progress/20261029T125649Z-54c94436.md'):
 text=(ROOT/name).read_text();ck('0 / 0 / 0'in text);ck('unmeasured'in text);ck('unachieved'in text);ck('20261029T125649Z-54c94436'in text)
for row in json.loads((HERE/'native-pins.json').read_text()):ck(sha(Path(row['path']).read_bytes())==row['sha256'],'native source unchanged')
ck(json.loads((HERE/'audit-result.json').read_text())['status']=='PASS')
summary=json.loads((HERE/'diagnostic-summary.json').read_text());ck(summary['final_slower']==39 and summary['initial_slower']==42)
ck(datetime.datetime.now(datetime.timezone.utc)<datetime.datetime.fromisoformat('2026-10-29T13:16:49+00:00'),'deadline')
result=dict(status='PASS',checks=checks,owner_document_pins=len(owner),prior_source_records_preserved=948,prior_hypotheses_preserved=60,native_source_pins=9,full_stack_proofs=0,proved_positions=0,deadline_met=True,elapsed_s=time.monotonic()-start)
(HERE/'final-audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
