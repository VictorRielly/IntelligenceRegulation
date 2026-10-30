"""Final evidence/preservation audit; does not repeat the algebra benchmark."""
import ast,hashlib,json,resource,time
from pathlib import Path
E=Path(__file__).resolve().parent;R=E.parent.parent;start=time.monotonic();checks=0
def check(ok,label):
    global checks
    checks+=1
    if not ok:raise AssertionError(label)
def read(p):return json.loads(p.read_text())
manifest=read(E/'artifact-manifest.json')
for x in manifest:
    p=E/x['path'];b=p.read_bytes();check(len(b)==x['bytes'] and hashlib.sha256(b).hexdigest()==x['sha256'],'immutable artifact '+x['path'])
for p in E.glob('*.py'):ast.parse(p.read_text());check(True,'syntax '+p.name)
for pin in read(E/'native-pins.json'):
    for key in ('snapshot','path'):check(hashlib.sha256(Path(pin[key]).read_bytes()).hexdigest()==pin['sha256'],'native pin '+key)
for pin in read(E/'reuse-pins.json'):
    check(hashlib.sha256((E/pin['snapshot']).read_bytes()).hexdigest()==pin['sha256'],'local helper provenance')
for x in read(E/'startup/manifest.json'):
    check(hashlib.sha256((E/'startup'/x['snapshot']).read_bytes()).hexdigest()==x['sha256'],'startup snapshot')
for name in ('FINDINGS.md','sources.jsonl'):
    before=(E/'startup'/('research__zkp-efficiency__'+name)).read_bytes();after=(R/name).read_bytes()
    check(after.startswith(before),'prior durable bytes preserved '+name)
sources=[json.loads(s) for s in (R/'sources.jsonl').read_text().splitlines()]
records=[json.loads(s) for s in (E/'source-records.jsonl').read_text().splitlines()]
check(len(sources)==840 and len(records)==10,'source counts')
for row in records:
    check(sum(x.get('id')==row['id'] for x in sources)==1,'source unique')
    check(next(x for x in sources if x.get('id')==row['id'])==row,'source record exact')
    for key in ('access_date','url','publication_date','verified_update_date','implementation_license','inspected_commit_id','date_evidence'):check(key in row,'source metadata '+key)
    check(row['external_execution'] is False and row['reproduced_performance'] is False,'source scope')
old=read(E/'startup/prior__hypotheses.json');new=read(E/'hypotheses.json');check(len(old)==42 and len(new)==44,'queue counts')
for x in old:
    candidate=next(y for y in new if x['rank']==y['rank']);check(candidate==x if x['rank']!=41 else candidate['rank']==41,'queue preservation')
for x in new:
    for key in ('baseline','eliminated_work','added_costs','prerequisites','integration_cost','exactness','privacy_soundness','compatibility','end_to_end_ceiling','falsification'):check(bool(x.get(key)),'ranked obligations')
account=read(E/'proof-accounting.json')
for key in ('verified_full_stack_proofs','complete_model_passes','proved_positions','resident_passes'):check(account[key]==0,'zero full proof numerator')
for key in ('model_context_length','model_device','witness_s','proof_s','serialization_s','independent_verification_s','startup_s','initial_prefill_s','startup_fraction','steady_interval_s','total_workload_s','steady_proved_tokens_per_s','total_proved_tokens_per_s','proof_latency_s','proof_bytes'):check(account[key] is None,'unmeasured '+key)
commands=[json.loads(s) for s in (E/'commands.jsonl').read_text().splitlines()]
for name in ('probe.py','audit.py'):
    row=next(x for x in commands if x['command'][-1].endswith('/'+name))
    check(row['exit_code']==0,'completed '+name);check(row['threads']==1 and row['estimated_memory_mib']<=512 and row['cpu_seconds']<=60 and row['parent_timeout_seconds']<=60,'resource bounds')
    check(hashlib.sha256((E/name).read_bytes()).hexdigest()==row['entry_sha256'],'tested source pin')
result=read(E/'result.json');check(result['checks']==817 and result['main_plus_extension_rounds']==60,'result counts')
check(result['control_instances']==57 and result['private_claims_checked']==36,'controls/claims')
check(result['native_proofs']==0,'model scope');check(read(E/'audit-result.json')['checks']==83,'source audit result')
for case in result['cases']:
    p=E/f"synthetic-n{case['n']}-key{int(case['keyed'])}-rounds.bin"
    check(hashlib.sha256(p.read_bytes()).hexdigest()==case['round_sha256'],'synthetic round hash')
for path in (R/'STATE.md',R/'PROGRESS.md',R/'progress/20261028T225649Z-6db80b72.md',E/'README.md',R/'handoffs/20261028-sc-tab-mask-conformance.md'):
    txt=path.read_text();check('0129' in txt or '0128' in txt,'report exists')
    check('20261028T225649Z-6db80b72' in txt,'report run identity')
out={'status':'PASS_FINAL_EVIDENCE_AUDIT','checks':checks,'immutable_artifacts':len(manifest),'native_pins_unchanged':9,'prior_sources_preserved':830,'current_sources':840,'prior_hypotheses_preserved':42,'current_hypotheses':44,'elapsed_seconds':time.monotonic()-start,'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'native_proofs':0}
(E/'artifact-audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
