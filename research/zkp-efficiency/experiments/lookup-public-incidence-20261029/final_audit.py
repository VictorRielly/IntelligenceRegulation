"""One bounded final provenance/scope check; does not rerun synthetic experiments."""
from pathlib import Path
import hashlib,json,resource,time
HERE=Path(__file__).resolve().parent;BASE=HERE.parent.parent;start=time.monotonic();checks=0
def check(ok):
    global checks
    checks+=1
    if not ok:raise AssertionError(checks)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for x in json.loads((HERE/'native-pins.json').read_text()):
    check(sha(Path(x['path']))==x['sha256']);check(sha(HERE/x['snapshot'])==x['sha256'])
for x in json.loads((HERE/'owner-document-recheck.json').read_text()):
    check(sha(Path(x['path']))==x['sha256'])
for name in ['FINDINGS.md','sources.jsonl']:
    before=(HERE/'startup'/name).read_bytes();after=(BASE/name).read_bytes()
    check(after.startswith(before));check(len(after)>len(before))
sources=[json.loads(x) for x in (BASE/'sources.jsonl').read_text().splitlines()]
check(len(sources)==924)
check(sources[-8:]==[json.loads(x) for x in (HERE/'sources-cycle.jsonl').read_text().splitlines()])
old=json.loads((HERE/'startup/hypotheses.json').read_text());new=json.loads((HERE/'hypotheses.json').read_text())
check(len(old)==57 and len(new)==58)
for i,q in enumerate(old):
    check(all(new[i].get(k)==v for k,v in q.items()))
check([q['rank'] for q in new]==list(range(1,59)))
for name in ['probe','audit']:
    run=json.loads((HERE/(name+'-execution.json')).read_text())
    check(run['exit_code']==0 and run['elapsed_s']<60)
    check(run['threads']==1 and run['estimated_memory_bytes']<=512*1024**2)
    check(run['native_build'] is False and run['gpu'] is False)
    check((HERE/(name+'.stderr.log')).read_text()=='')
account=json.loads((HERE/'target-accounting.json').read_text())
check(account['proved_positions']==account['full_stack_proofs']==account['model_passes']==0)
for k in ['witness_s','proof_s','serialization_s','verification_s','startup_s','startup_fraction',
          'steady_state_positions_per_s','total_workload_positions_per_s']:
    check(account[k] is None)
check('COMPLETE' in (BASE/'STATE.md').read_text())
check('No native proving improvement measured.' in (BASE/'PROGRESS.md').read_text())
check((BASE/'progress/20261029T085649Z-193029f7.md').is_file())
check((BASE/'handoffs/20261029-r13-lookup-column-views.md').is_file())
manifest=json.loads((HERE/'artifact-manifest.json').read_text())
for x in manifest:
    check(sha(BASE/x['path'])==x['sha256'])
result=dict(status='PASS',checks=checks,immutable_artifacts=len(manifest),
    prior_findings_and_916_sources_preserved=True,all_57_prior_hypotheses_preserved=True,
    elapsed_s=time.monotonic()-start,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    new_proofs=0,native_work_executed=False)
(HERE/'final-audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
