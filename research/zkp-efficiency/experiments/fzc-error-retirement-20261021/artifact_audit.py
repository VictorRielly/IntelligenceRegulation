"""Bounded evidence-integrity checks. No production or runtime writes."""
from pathlib import Path
import hashlib,json,resource,time
ROOT=Path(__file__).resolve().parent
RESEARCH=ROOT.parent.parent
t0=time.monotonic(); checks=0
def check(ok,msg):
    global checks
    checks+=1
    if not ok: raise AssertionError(msg)
old=(ROOT/'startup/sources.jsonl').read_bytes()
check((RESEARCH/'sources.jsonl').read_bytes().startswith(old),'source history changed')
rows=[json.loads(l) for l in (RESEARCH/'sources.jsonl').read_text().splitlines() if l.strip()]
new=[json.loads(l) for l in (ROOT/'source-records.jsonl').read_text().splitlines() if l.strip()]
check(len(rows)==751 and rows[-7:]==new,'source ledger append mismatch')
prior=(ROOT/'startup/FINDINGS.md').read_bytes()
check((RESEARCH/'FINDINGS.md').read_bytes().startswith(prior),'findings history changed')
old_h=json.loads((RESEARCH/'experiments/fzc-scratch-leases-20261021/hypotheses.json').read_text())
new_h=json.loads((ROOT/'hypotheses.json').read_text())
check(len(old_h)==len(new_h)==34,'hypothesis removed')
check([h['rank'] for h in new_h]==[h['rank'] for h in old_h],'rank changed')
for a,b in zip(old_h,new_h):
    check(a==b if a['rank']!=34 else a!=b,'wrong hypothesis changed')
for pin in json.loads((ROOT/'source-pins.json').read_text()):
    check(hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'],'live source drift')
    check(hashlib.sha256((RESEARCH/pin['copy']).read_bytes()).hexdigest()==pin['sha256'],'copied source drift')
for x in json.loads((ROOT/'startup/manifest.json').read_text())['files']:
    check(hashlib.sha256((ROOT/'startup'/x['snapshot']).read_bytes()).hexdigest()==x['sha256'],'startup snapshot drift')
execution=json.loads((ROOT/'execution-manifest.json').read_text())
for x in execution['source_hashes']+execution['result_hashes']:
    check(hashlib.sha256((ROOT/x['path']).read_bytes()).hexdigest()==x['sha256'],'final execution pin drift')
commands=[json.loads(l) for l in (ROOT/'commands.jsonl').read_text().splitlines() if l.strip()]
check(all(x['exit_code']==0 and x['elapsed_seconds']<35 for x in commands),'launch failed or over budget')
probe=json.loads((ROOT/'result.json').read_text()); audit=json.loads((ROOT/'source-audit-result.json').read_text())
check(probe['status']=='PASS_SYNTHETIC_RETIREMENT_ONLY' and probe['checks']==5037,'probe')
check(audit['checks']==61 and probe['topological_interleavings']==audit['interleavings']==105,'audit')
check(len(audit['role_error_paths'])==36,'role path table')
check(len(probe['controls'])==23,'control count changed; inspect')
for name in ['STATE.md','PROGRESS.md','progress/20261021T031854Z-a1dbfeef.md']:
    s=(RESEARCH/name).read_text()
    for phrase in ['0 / 0 / 0','unmeasured','20261021T031854Z-a1dbfeef']:
        check(phrase in s, name+' missing scope')
    check('50 proved tokens/s remains unachieved' in s or '50 proved tokens/s remains unachieved' in s.replace('\n',' '),name+' target')
check('imports neither' in (ROOT/'README.md').read_text(),'reference scope')
out={'status':'PASS','checks':checks,'prior_sources_preserved':744,'new_sources':7,'hypotheses_preserved':34,'changed_ranks':[34],
     'native_source_pins':4,'wall_seconds':time.monotonic()-t0,'rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss}
(ROOT/'artifact-audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out))
