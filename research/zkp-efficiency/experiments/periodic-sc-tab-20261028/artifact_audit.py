"""Read-only final evidence audit. May write only this experiment's result."""
import hashlib,json,resource,time
from pathlib import Path
E=Path(__file__).resolve().parent;R=E.parent.parent;start=time.monotonic();checks=0
def check(ok,label):
    global checks
    checks+=1
    assert ok,label
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((E/'artifact-manifest.json').read_text())
for item in manifest:
    p=Path(item['path']);check(p.is_file(),'artifact exists');check(sha(p)==item['sha256'],'immutable artifact hash')
pins=json.loads((E/'native-pins.json').read_text())
for p in pins:
    check(sha(Path(p['snapshot']))==p['sha256'],'native snapshot')
    check(sha(Path(p['path']))==p['sha256'],'tested native source unchanged')
old=(E/'startup/sources.jsonl').read_bytes();new=(R/'sources.jsonl').read_bytes();extra=(E/'source-records.jsonl').read_bytes()
check(new==old+extra,'all 821 old sources preserved byte-for-byte; nine append')
check(len(new.splitlines())==830,'source ledger length')
check((R/'FINDINGS.md').read_bytes().startswith((E/'startup/FINDINGS.md').read_bytes()),'old findings preserved')
prior=json.loads((E/'startup/prior-hypotheses.json').read_text());h=json.loads((E/'hypotheses.json').read_text())
check(len(prior)==41 and len(h)==42,'prior hypotheses retained plus one')
check([x['rank'] for x in h]==list(range(1,43)),'rank identifiers retained')
for x,y in zip(prior,h):
    check(set(x)<=set(y),'prior hypothesis fields retained')
    if x['rank'] not in (1,41):check(x==y,'unrelated hypothesis unchanged')
res=json.loads((E/'result.json').read_text());cyc=json.loads((E/'cycle-result.json').read_text())
check(cyc['experiment']==res,'summary matches final model')
check(res['checks']==50042 and len(res['controls'])==24,'final check/control counts')
check(res['native_proofs']==0,'no synthetic proof count')
for key in ('witness_seconds','proof_seconds','serialization_seconds','verification_seconds','startup_fraction','steady_state_rate','total_workload_rate','context_length','device'):
    check(cyc['target'][key] is None,'unmeasured target field '+key)
check(cyc['target']['passes']==0 and cyc['target']['new_proved_positions']==0,'no proved positions/passes')
for rel in ('README.md','candidate-periodic.rs','periodic.py','reference.py','probe.py','audit.py','run_bounded.py','hardware.json','commands.jsonl','hypotheses.json','cycle-result.json'):
    check((E/rel).is_file(),'required artifact '+rel)
for rel in ('PROGRESS.md','STATE.md','progress/20261028T215649Z-43c1f18d.md','handoffs/20261028-periodic-sc-tab.md'):
    p=R/rel;check(p.is_file(),'required report '+rel);check('20261028T215649Z-43c1f18d' in p.read_text(),'report run identity')
commands=[json.loads(x) for x in (E/'commands.jsonl').read_text().splitlines()]
for name in ('probe.py','audit.py'):
    last=next(c for c in reversed(commands) if Path(c['command'][-1]).name==name)
    check(last['exit_code']==0 and last['entry_sha256']==sha(E/name),'last command result/source '+name)
for p in E.rglob('*'):
    check(not p.is_symlink(),'no artifact symlink')
out={'status':'PASS_FINAL_EVIDENCE_AUDIT','checks':checks,'immutable_artifacts':len(manifest),'native_pins':len(pins),'preserved_source_records':821,'appended_source_records':9,'hypotheses':42,'elapsed_seconds':time.monotonic()-start,'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss}
(E/'artifact-audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
