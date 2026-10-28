"""Final bounded integrity check. Never updates any production file."""
from pathlib import Path
import datetime,hashlib,json,resource,time
P=Path(__file__).resolve().parent;B=P.parent.parent;start=time.monotonic();checks=0
def check(v):
    global checks
    checks+=1
    assert v
items=json.loads((P/'artifact-manifest.json').read_text())
for x in items:
    f=P/x['path'];check(f.is_file());check(f.stat().st_size==x['bytes'])
    check(hashlib.sha256(f.read_bytes()).hexdigest()==x['sha256'])
manifest=json.loads((P/'source-manifest.json').read_text())
for x in manifest:check(hashlib.sha256(Path(x['path']).read_bytes()).hexdigest()==x['sha256'])
for x in json.loads((P/'startup/read-index.json').read_text()):
    if x['path'].startswith('research/'):continue
    check(hashlib.sha256((Path('/home/victor/IntelligenceRegulation')/x['path']).read_bytes()).hexdigest()==x['sha256'])
oldsrc=(P/'startup/research__zkp-efficiency__sources.jsonl').read_bytes()
oldfind=(P/'startup/research__zkp-efficiency__FINDINGS.md').read_bytes()
check((B/'sources.jsonl').read_bytes().startswith(oldsrc))
check((B/'FINDINGS.md').read_bytes().startswith(oldfind))
prior=json.loads((P/'prior-hypotheses.json').read_text());new=json.loads((P/'hypotheses.json').read_text())
check(new[:len(prior)]==prior);check(len(new)==37)
records=[json.loads(x) for x in (B/'sources.jsonl').read_text().splitlines()]
check(len(records)==790);check(sum(x.get('run_id')=='20261021T071854Z-0fa6988f' for x in records)==8)
for x in records[-8:]:
    for key in ['url','access_date','publication_date','verified_update_date','implementation_license','inspected_commit_id']:
        check(key in x)
    check(x['external_execution']==False);check(x['reproduced_performance']==False)
scope=json.loads((P/'patch-scope.json').read_text())
check(hashlib.sha256((P/'state-memset-elision.patch').read_bytes()).hexdigest()==scope['patch_sha256'])
check(scope['capacity_compaction_in_patch']==False);check(scope['native_validation']==False)
for n in ['result.json','audit-result.json']:
    d=json.loads((P/n).read_text());check(d['status'].startswith('PASS'));check(d['wall_seconds']<30);check(d['rss_kib']<64*1024)
acc=json.loads((P/'target-accounting.json').read_text())
for k in ['proofs','passes','positions']:check(acc[k]==0)
for k in ['actual_model_context','actual_accelerator','witness_s','proof_s','serialization_s','verification_s','startup_s','startup_fraction','steady_rate','total_workload_rate']:check(acc[k] is None)
for k in ['long_context_prefill','resident_model_proof_series','decode']:check(acc[k]==False)
for x in json.loads((P/'hardware.json').read_text())['blake3_pins']:
    check(hashlib.sha256(Path(x['path']).read_bytes()).hexdigest()==x['sha256'])
for n in ['PROGRESS.md','STATE.md','progress/20261021T071854Z-0fa6988f.md','handoffs/20261021-streaming-blake3-state.md']:
    check((B/n).is_file());check((B/n).stat().st_size>100)
result=dict(status='PASS_FINAL_INTEGRITY',checks=checks,immutable_artifacts=len(items),
    source_pins=len(manifest),prior_sources=len(oldsrc.splitlines()),prior_findings_lines=len(oldfind.splitlines()),
    prior_hypotheses=len(prior),utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
    wall_seconds=time.monotonic()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)
(P/'artifact-audit-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
