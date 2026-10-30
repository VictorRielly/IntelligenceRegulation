"""Final evidence integrity; no performance or proving work."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib,json,time,resource
H=Path(__file__).resolve().parent;R=H.parent.parent
start=time.monotonic();checks=0
def check(x):
 global checks
 assert x;checks+=1
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for f in ['FINDINGS.md','sources.jsonl']:
 check((R/f).read_bytes().startswith((H/'startup'/f).read_bytes()))
old=[json.loads(x) for x in (H/'startup/sources.jsonl').read_text().splitlines()]
new=[json.loads(x) for x in (R/'sources.jsonl').read_text().splitlines()]
cycle=[json.loads(x) for x in (H/'sources-cycle.jsonl').read_text().splitlines()]
check(len(old)==932);check(len(new)==940);check(new[-8:]==cycle)
for x in cycle:
 for k in ['access_date','url','publication_date','verified_update_date','implementation_license','inspected_commit_id','assessment']:
  check(k in x)
 check(x['access_date']=='2026-10-29');check(x['external_execution'] is False)
prior=json.loads((H/'startup/prior-hypotheses.json').read_text());current=json.loads((H/'hypotheses.json').read_text())
check(len(current)==60);check([x['rank'] for x in current]==list(range(1,61)))
for a,b in zip(prior,current):
 if a['rank'] not in [1,57]:check(a==b)
check('PARKED' in current[56]['disposition'])
for x in json.loads((H/'native-pins.json').read_text()):
 check(sha(Path(x['path']))==x['sha256']);check(sha(H/x['snapshot'])==x['sha256'])
comp=json.loads((H/'compile-execution.json').read_text())
for name,digest in comp['rust_source_sha256'].items():check(sha(H/name)==digest)
check(sha(H/'probe')==comp['binary_sha256'])
for x in json.loads((H/'copied-research-pins.json').read_text()):check(sha(H/x['snapshot'])==x['sha256'])
for name in ['result.json','audit-result.json']:
 x=json.loads((H/name).read_text());check(x['status']=='PASS');check(x['proved_positions']==0);check(x['model_passes']==0)
for name in ['MVP_STATUS.md','ZK60_DECISIONS.md','ZK60_CODEX_FABLE_COORDINATION.md','START_HERE.md']:
 check(not (H/'startup'/name).exists())
check(not (H/'web-search-6.json').exists())
for name in ['STATE.md','PROGRESS.md','progress/20261029T105649Z-8532a02d.md']:
 s=(R/name).read_text()
 for term in ['0 / 0 / 0','unmeasured','unachieved','resident','decode','serialization','verification','startup']:
  check(term in s)
report=json.loads((H/'checkpoint-final.json').read_text());check(report['proved_positions']==0)
check(datetime.now(timezone.utc)<datetime(2026,10,29,11,16,49,tzinfo=timezone.utc))
paths=[p for p in H.rglob('*') if p.is_file() and p.name not in ['artifact-manifest.json','final-audit-result.json','final_audit.stdout.log','final_audit.stderr.log','final_audit-execution.json']]
paths += [R/x for x in ['STATE.md','PROGRESS.md','FINDINGS.md','sources.jsonl','progress/20261029T105649Z-8532a02d.md','handoffs/20261029-public-mask-component-sums.md']]
manifest=[dict(path=str(p.relative_to(R)),sha256=sha(p),bytes=p.stat().st_size) for p in sorted(paths)]
(H/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
result=dict(status='PASS',checks=checks,manifest_entries=len(manifest),prior_research_prefixes_unchanged=True,
            owner_decisions_concurrent_update='R16b fix-scope only; source hashes and safe status note retained',
            full_stack_proofs=0,model_passes=0,proved_positions=0,
            elapsed_s=time.monotonic()-start,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            completed_at_utc=datetime.now(timezone.utc).isoformat())
(H/'final-audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
